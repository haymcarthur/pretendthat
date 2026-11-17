import Accelerate
import Foundation
import SignalsmithShift

// Voice pitch build (decisions/2026-11-17-voice-pitch-build.md, Haylee 2026-11-17: "Signalsmith +2, sounds perfect").
// Nutmeg's live voice is coral → Signalsmith Stretch +2 semitones (formant preservation OFF) → Varispeed 1.20.
// The shift runs on the 24 kHz audio BEFORE the player (NutmegSpeaker.schedule), so the lip-sync analyzer and the
// speaker timeline see exactly what is heard, and Varispeed stays the graph's one unit.
// - Live lines: one streaming shifter (`VoicePitchShifter`), flushed at the end of each line and reset on a barge-in.
// - Clips (bundled and recorded, stored before Varispeed AND before the shift) get their OWN shift toward the live
//   voice's pitch (`ClipPitch`), so a clip is never raised twice and the bright greeting clip lands near the live voice.

/// The pitch raise's settings (part of `VoiceConfig`). `semitones == 0` means no processing at all (live or clips).
public struct PitchShift: Equatable, Sendable, CustomStringConvertible {
    public var semitones: Double
    /// Signalsmith's formant preservation ("vowels kept"). OFF in Haylee's pick (plain +2).
    public var preserveFormants: Bool
    public init(semitones: Double = Realtime.defaultPitchShiftSemitones, preserveFormants: Bool = false) {
        self.semitones = semitones; self.preserveFormants = preserveFormants
    }
    public static let off = PitchShift(semitones: 0)
    public var isOn: Bool { abs(semitones) > 0.001 }

    /// The STFT block and hop as HEARD (Varispeed plays the 24 kHz audio faster): 60 ms / 15 ms, the config on the
    /// listening page (design/voice-pitch-test-2, "speech" config). In source samples that's 60 ms × rate.
    public static let heardBlockSeconds = 0.060
    public static let heardIntervalSeconds = 0.015
    public static func blockSamples(sampleRate: Double, playbackRate: Double) -> Int {
        Int((heardBlockSeconds * playbackRate * sampleRate).rounded())
    }
    public static func intervalSamples(sampleRate: Double, playbackRate: Double) -> Int {
        Int((heardIntervalSeconds * playbackRate * sampleRate).rounded())
    }

    /// The formant setting the live voice uses: nil = formants move with the pitch (plain), 0 = kept (preserved).
    public var liveFormantSemitones: Double? { preserveFormants ? 0 : nil }

    public var description: String { isOn ? String(format: "%+.1f st%@", semitones, preserveFormants ? " (formants kept)" : "") : "off" }
}

extension Realtime {
    /// Haylee 2026-11-17: +2 semitones (Signalsmith Stretch, formants not preserved).
    public static let defaultPitchShiftSemitones: Double = 2
}

/// How a clip is brought to the live voice's pitch (clips are stored before the shift, so they never get the live +2
/// on top of their own pitch).
public enum ClipPitch {
    /// The live voice's typical RAW median F0 (coral, full model, before any processing), measured with
    /// `PitchTracker` on the eight A/B v2 full-model captures: 243, 234, 276, 386, 249, 280, 262, 270 Hz → median 266
    /// (the drift recording's live lines were 245–287 raw).
    public static let liveRawMedianHz = 266.0
    /// The most a clip is moved either way (beyond this the shift itself would be the problem: re-record the clip).
    public static let maxAdjustSemitones = 6.0
    /// The "sane range" check is half a semitone inside the clamp, so a flagged clip is flagged before it's clamped.
    public static let saneSemitones = 5.5
    /// Below this the clip's shift counts as "the same as live" (no separate formant handling).
    public static let sameAsLiveSemitones = 0.25

    /// The raw pitch a clip should have after its shift: the live voice after the raise.
    public static func targetHz(_ shift: PitchShift) -> Double { liveRawMedianHz * pow(2, shift.semitones / 12) }

    /// Raw clip pitches within `saneSemitones` of the target (the "sane range" every bundled clip is checked against,
    /// and recorded clips are logged against). At +2: ≈ 217–410 Hz. (The bundled clips measure 224–395 Hz.)
    public static func saneRange(_ shift: PitchShift = PitchShift()) -> ClosedRange<Double> {
        let t = targetHz(shift)
        return (t * pow(2, -saneSemitones / 12))...(t * pow(2, saneSemitones / 12))
    }

    public enum Check: Equatable, Sendable { case ok, outOfRange, unmeasured }
    public static func check(_ hz: Double?, shift: PitchShift = PitchShift()) -> Check {
        guard let hz, hz > 0 else { return .unmeasured }
        return saneRange(shift).contains(hz) ? .ok : .outOfRange
    }

    /// One clip's shift: pitch semitones (toward the target, clamped) and the formant setting. Off when the live shift
    /// is off (0 = no processing anywhere). An unmeasured clip gets the live shift (it's treated like a live take).
    /// `matchLiveFormants` [Claude's call]: a clip moved by a different amount than the live voice gets its formants
    /// placed where the live voice's are (+2 with Haylee's plain shift), so a lowered bright clip doesn't turn darker
    /// than her live voice; false = plain shift (formants follow the clip's own pitch move).
    public struct Plan: Equatable, Sendable {
        public var semitones: Double
        public var formantSemitones: Double?
        public var isOn: Bool { abs(semitones) > 0.001 || formantSemitones.map { abs($0) > 0.001 } ?? false }
    }

    public static func plan(clipHz: Double?, shift: PitchShift, matchLiveFormants: Bool = true) -> Plan {
        guard shift.isOn else { return Plan(semitones: 0, formantSemitones: nil) }
        guard let hz = clipHz, hz > 0 else { return Plan(semitones: shift.semitones, formantSemitones: shift.liveFormantSemitones) }
        let raw = 12 * log2(targetHz(shift) / hz)
        let st = min(max(raw, -maxAdjustSemitones), maxAdjustSemitones)
        if shift.preserveFormants { return Plan(semitones: st, formantSemitones: 0) }
        if !matchLiveFormants || abs(st - shift.semitones) < sameAsLiveSemitones { return Plan(semitones: st, formantSemitones: nil) }
        return Plan(semitones: st, formantSemitones: shift.semitones)
    }
}

/// A streaming Signalsmith Stretch pitch shifter for one mono stream (a line). Output is ALIGNED with the input
/// (sample i out is sample i in, shifted) and the same length; it is held back by `latencySamples` until `finish()`.
/// - First `inputLatency` samples prime the shifter (`seek`), the first `outputLatency` output samples are dropped.
/// - `finish()` (end of a line) pushes the rest out and resets; `reset()` (barge-in) drops everything.
/// Not thread-safe (one per stream, used on the main actor).
public final class VoicePitchShifter {
    public let semitones: Double
    public let formantSemitones: Double?
    private let handle: OpaquePointer
    private let inLat: Int, outLat: Int
    private var primed = false
    private var priming: [Float] = []
    private var toDrop: Int
    /// Samples taken in / given out since the line started.
    public private(set) var inCount = 0, outCount = 0

    public init(semitones: Double, formantSemitones: Double? = nil, sampleRate: Double = Realtime.sampleRate,
                playbackRate: Double = Realtime.defaultVarispeedRate) {
        self.semitones = semitones; self.formantSemitones = formantSemitones
        handle = pt_shifter_create(Int32(PitchShift.blockSamples(sampleRate: sampleRate, playbackRate: playbackRate)),
                                   Int32(PitchShift.intervalSamples(sampleRate: sampleRate, playbackRate: playbackRate)))
        pt_shifter_set(handle, Float(semitones), Float(formantSemitones ?? -1000))
        inLat = Int(pt_shifter_input_latency(handle)); outLat = Int(pt_shifter_output_latency(handle))
        toDrop = outLat
    }

    public convenience init(_ plan: ClipPitch.Plan, sampleRate: Double = Realtime.sampleRate, playbackRate: Double) {
        self.init(semitones: plan.semitones, formantSemitones: plan.formantSemitones, sampleRate: sampleRate, playbackRate: playbackRate)
    }

    deinit { pt_shifter_destroy(handle) }

    /// How long the start of a line is held back (source samples): input + output latency.
    public var latencySamples: Int { inLat + outLat }
    /// Nothing of a line is in flight.
    public var isIdle: Bool { inCount == 0 }

    /// Feeds part of a line; returns the shifted audio that is ready (possibly empty while priming).
    public func process(_ input: [Float]) -> [Float] {
        guard !input.isEmpty else { return [] }
        inCount += input.count
        var x = input
        if !primed {
            priming += input
            guard priming.count >= inLat else { return [] }
            priming.withUnsafeBufferPointer { pt_shifter_seek(handle, $0.baseAddress, Int32(inLat)) }
            x = Array(priming[inLat...]); priming = []; primed = true
            if x.isEmpty { return [] }
        }
        var y = [Float](repeating: 0, count: x.count)
        x.withUnsafeBufferPointer { xi in y.withUnsafeMutableBufferPointer { yo in
            pt_shifter_process(handle, xi.baseAddress, yo.baseAddress, Int32(x.count))
        } }
        return emit(y)
    }

    /// End of the line: the held-back audio, then the shifter is ready for a new line.
    public func finish() -> [Float] {
        defer { reset() }
        guard inCount > 0 else { return [] }
        if !primed {
            // A line shorter than the priming length: pad with silence after it.
            var p = priming; p += [Float](repeating: 0, count: max(0, inLat - p.count))
            p.withUnsafeBufferPointer { pt_shifter_seek(handle, $0.baseAddress, Int32(inLat)) }
            primed = true; priming = []
        }
        let zeros = [Float](repeating: 0, count: inLat)
        var y = [Float](repeating: 0, count: inLat + outLat)
        zeros.withUnsafeBufferPointer { z in y.withUnsafeMutableBufferPointer { yo in
            pt_shifter_process(handle, z.baseAddress, yo.baseAddress, Int32(inLat))
            pt_shifter_flush(handle, yo.baseAddress! + inLat, Int32(outLat))
        } }
        var out = emit(y)
        let left = max(0, inCount - (outCount - out.count))   // the line is exactly as long as its input
        if out.count > left { out.removeLast(out.count - left) }
        return out
    }

    /// Barge-in / cancel: drops everything in flight (a cut line never leaks into the next).
    public func reset() {
        pt_shifter_reset(handle)
        primed = false; priming = []; toDrop = outLat; inCount = 0; outCount = 0
    }

    private func emit(_ y: [Float]) -> [Float] {
        var y = y
        if toDrop > 0 { let d = min(toDrop, y.count); y.removeFirst(d); toDrop -= d }
        outCount += y.count
        return y
    }

    /// A whole buffer at once (offline renders and tests): same length as the input.
    public static func shiftAll(_ x: [Float], semitones: Double, formantSemitones: Double? = nil,
                                sampleRate: Double = Realtime.sampleRate, playbackRate: Double = Realtime.defaultVarispeedRate,
                                chunk: Int = 2400) -> [Float] {
        let s = VoicePitchShifter(semitones: semitones, formantSemitones: formantSemitones, sampleRate: sampleRate, playbackRate: playbackRate)
        var out: [Float] = []
        out.reserveCapacity(x.count)
        for r in ClipAudio.chunks(count: x.count, size: chunk) { out += s.process(Array(x[r])) }
        return out + s.finish()
    }
}

/// A clip's raw median F0 (normalized autocorrelation, 40 ms frames, 20 ms hop, frames within 30 dB of the loudest,
/// 100–700 Hz, the shortest lag within 10% of the best so an octave-down lag doesn't win). The same method as the voice
/// drift and pitch test notes. Looks at most `maxSeconds` of audio (a few ms on device for a whole clip).
public enum PitchTracker {
    public static func medianHz(_ x: [Float], sampleRate: Double = Realtime.sampleRate, maxSeconds: Double = 8) -> Double? {
        let frame = Int(0.040 * sampleRate), hop = Int(0.020 * sampleRate)
        let n = min(x.count, Int(maxSeconds * sampleRate))
        guard n > frame else { return nil }
        let minLag = Int(sampleRate / 700), maxLag = Int(sampleRate / 100)
        guard frame > maxLag else { return nil }
        return x.withUnsafeBufferPointer { buf -> Double? in
            let p = buf.baseAddress!
            var rms: [Float] = []
            var i = 0
            while i + frame <= n { var r: Float = 0; vDSP_rmsqv(p + i, 1, &r, vDSP_Length(frame)); rms.append(r); i += hop }
            guard let peak = rms.max(), peak > 1e-4 else { return nil }
            let floor = peak * 0.0316   // −30 dB
            var f0s: [Double] = []
            var corr = [Float](repeating: 0, count: maxLag + 1)
            for (k, r) in rms.enumerated() where r > floor {
                let s = p + k * hop
                var e0: Float = 0; vDSP_svesq(s, 1, &e0, vDSP_Length(frame))
                guard e0 > 0 else { continue }
                var best: Float = 0
                for lag in minLag...maxLag {
                    var c: Float = 0
                    let len = frame - lag
                    vDSP_dotpr(s, 1, s + lag, 1, &c, vDSP_Length(len))
                    let v = c / e0 * Float(frame) / Float(len)
                    corr[lag] = v; best = max(best, v)
                }
                guard best > 0.5 else { continue }
                // The first local peak within 10% of the best (avoids octave-down picks).
                for lag in minLag...maxLag where corr[lag] >= best * 0.9
                    && (lag == minLag || corr[lag] >= corr[lag - 1]) && (lag == maxLag || corr[lag] >= corr[lag + 1]) {
                    // Parabolic refinement.
                    var l = Double(lag)
                    if lag > minLag && lag < maxLag {
                        let a = Double(corr[lag - 1]), b = Double(corr[lag]), c = Double(corr[lag + 1])
                        let d = a - 2 * b + c
                        if d < 0 { l += 0.5 * (a - c) / d }
                    }
                    f0s.append(sampleRate / l)
                    break
                }
            }
            guard f0s.count >= 3 else { return nil }
            f0s.sort()
            return f0s[f0s.count / 2]
        }
    }
}
