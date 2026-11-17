@preconcurrency import AVFAudio
import Foundation
import Testing
@testable import NutmegCore

/// Voice pitch build (decisions/2026-11-17-voice-pitch-build.md): Signalsmith Stretch +2 semitones on the live voice,
/// per-clip adjustment toward the live voice, the config, and the pitch check on every bundled clip.
@Suite struct VoicePitchTests {
    static let sr = Realtime.sampleRate

    static func tone(_ hz: Double, seconds: Double = 2, amp: Float = 0.5) -> [Float] {
        (0..<Int(seconds * sr)).map { Float(sin(2 * .pi * hz * Double($0) / sr)) * amp }
    }

    /// A glottal-like pulse train: sharp periodic pulses at `hz` (a raised cosine to the 12th power), mean removed.
    static func pulses(_ hz: Double, seconds: Double = 2) -> [Float] {
        let x = (0..<Int(seconds * sr)).map { Float(pow(0.5 + 0.5 * cos(2 * .pi * hz * Double($0) / sr), 12)) }
        let m = x.reduce(0, +) / Float(x.count)
        return x.map { ($0 - m) * 0.8 }
    }

    static func zeroCrossingHz(_ x: ArraySlice<Float>) -> Double {
        var zc = 0, prev = x.first ?? 0
        for v in x.dropFirst() { if prev < 0 && v >= 0 { zc += 1 }; prev = v }
        return Double(zc) / (Double(x.count) / sr)
    }

    // MARK: Config

    @Test func theVoiceIsPlusTwoSemitonesWithFormantsOff() {
        let c = VoiceConfig.nutmeg
        #expect(c.pitchShift.semitones == 2 && c.pitchShift.preserveFormants == false && c.pitchShift.isOn)
        #expect(c.rate == 1.20 && c.method == .varispeed)   // the rate is unchanged
        #expect(c.description.contains("shift +2.0 st"))
        #expect(c.pitchShift.liveFormantSemitones == nil)
        #expect(PitchShift(semitones: 2, preserveFormants: true).liveFormantSemitones == 0)
    }

    @Test func zeroMeansNoProcessing() {
        #expect(!PitchShift.off.isOn && PitchShift.off.description == "off")
        #expect(!PitchShift(semitones: 0, preserveFormants: true).isOn)
        // Clips aren't processed either.
        for hz in [nil, 200.0, 300, 389] {
            #expect(!ClipPitch.plan(clipHz: hz, shift: .off).isOn)
        }
        // The voice ID (clip keys) doesn't depend on the shift: bundled clips keep their keys.
        #expect(VoiceConfig(pitchShift: .off).voiceID == VoiceConfig.nutmeg.voiceID)
    }

    @Test func theBlockIs60msHeardAtTheRate() {
        // 60 ms / 15 ms as heard = 72 ms / 18 ms of 24 kHz source at Varispeed 1.20.
        #expect(PitchShift.blockSamples(sampleRate: Self.sr, playbackRate: 1.2) == 1728)
        #expect(PitchShift.intervalSamples(sampleRate: Self.sr, playbackRate: 1.2) == 432)
        let s = VoicePitchShifter(semitones: 2)
        // About 60 ms heard before she starts (the decision's budget).
        let heardMs = Double(s.latencySamples) / Self.sr / 1.2 * 1000
        #expect(heardMs > 40 && heardMs < 75, "latency \(heardMs) ms")
    }

    // MARK: Clip adjustment math

    @Test func clipsAreMovedToTheLiveVoiceAfterTheRaise() {
        let shift = PitchShift()
        let target = ClipPitch.targetHz(shift)
        #expect(abs(target - 266 * pow(2, 2.0 / 12)) < 0.01)   // ≈ 298.6 Hz raw
        // A clip at the live voice's raw pitch gets the same +2 as live (plain, no formant handling).
        let live = ClipPitch.plan(clipHz: 266, shift: shift)
        #expect(abs(live.semitones - 2) < 0.01 && live.formantSemitones == nil)
        // A clip already at the target isn't moved.
        #expect(abs(ClipPitch.plan(clipHz: target, shift: shift).semitones) < 0.01)
        // The bright greeting clip (0adc8906, ~389 Hz raw) comes DOWN to the live voice, formants placed like live's.
        let greet = ClipPitch.plan(clipHz: 389, shift: shift)
        #expect(abs(greet.semitones - 12 * log2(target / 389)) < 0.01 && greet.semitones < -4)
        #expect(greet.formantSemitones == 2)
        #expect(ClipPitch.plan(clipHz: 389, shift: shift, matchLiveFormants: false).formantSemitones == nil)
        // Clamped both ways.
        #expect(ClipPitch.plan(clipHz: 600, shift: shift).semitones == -ClipPitch.maxAdjustSemitones)
        #expect(ClipPitch.plan(clipHz: 120, shift: shift).semitones == ClipPitch.maxAdjustSemitones)
        // Unmeasured: treated like a live take.
        #expect(ClipPitch.plan(clipHz: nil, shift: shift) == ClipPitch.Plan(semitones: 2, formantSemitones: nil))
        // Formants kept (if the setting ever flips): clips keep theirs too.
        #expect(ClipPitch.plan(clipHz: 389, shift: PitchShift(semitones: 2, preserveFormants: true)).formantSemitones == 0)
    }

    @Test func theSaneRangeIsFiveAndAHalfSemitonesAroundTheTarget() {
        let r = ClipPitch.saneRange()
        #expect(abs(r.lowerBound - 217.4) < 0.5 && abs(r.upperBound - 410.2) < 0.5)
        #expect(ClipPitch.check(389) == .ok && ClipPitch.check(300) == .ok)
        #expect(ClipPitch.check(430) == .outOfRange && ClipPitch.check(205) == .outOfRange)
        #expect(ClipPitch.check(nil) == .unmeasured && ClipPitch.check(0) == .unmeasured)
    }

    // MARK: Pitch tracker

    @Test func theTrackerFindsThePitch() throws {
        for hz in [180.0, 250, 300, 389, 450] {
            let t = try #require(PitchTracker.medianHz(Self.tone(hz)))
            #expect(abs(12 * log2(t / hz)) < 0.1, "tone \(hz) → \(t)")
            let p = try #require(PitchTracker.medianHz(Self.pulses(hz)))
            #expect(abs(12 * log2(p / hz)) < 0.15, "pulses \(hz) → \(p)")
        }
        #expect(PitchTracker.medianHz([Float](repeating: 0, count: 24_000)) == nil)
    }

    // MARK: Streaming shifter

    @Test(arguments: [480, 2400, 977, 4800])
    func aLineKeepsItsLengthAndAlignment(chunk: Int) {
        // Silence, then a tone burst from 0.5 s to 1.5 s, then silence.
        var x = [Float](repeating: 0, count: Int(2 * Self.sr))
        let a = Int(0.5 * Self.sr), b = Int(1.5 * Self.sr)
        for i in a..<b { x[i] = Float(sin(2 * .pi * 220 * Double(i) / Self.sr)) * 0.5 }
        let s = VoicePitchShifter(semitones: 2)
        var y: [Float] = []
        for r in ClipAudio.chunks(count: x.count, size: chunk) { y += s.process(Array(x[r])) }
        #expect(y.count == x.count - s.latencySamples || y.count < x.count)   // held back while streaming
        y += s.finish()
        #expect(y.count == x.count)
        // The burst starts and ends where it did (within one 15 ms hop).
        let on = y.firstIndex { abs($0) > 0.1 }!, off = y.lastIndex { abs($0) > 0.1 }!
        #expect(abs(on - a) < 500 && abs(off - b) < 500, "on \(on) vs \(a), off \(off) vs \(b)")
        // +2 semitones.
        let hz = Self.zeroCrossingHz(y[(a + 2400)..<(b - 2400)])
        #expect(abs(12 * log2(hz / 220) - 2) < 0.1, "\(hz) Hz")
        #expect(s.isIdle)   // finish() leaves it ready for the next line
    }

    @Test func aCutLineNeverLeaksIntoTheNext() {
        let s = VoicePitchShifter(semitones: 2)
        _ = s.process(Self.tone(300, seconds: 0.5))   // half a line, then a barge-in
        s.reset()
        let next = s.process([Float](repeating: 0, count: 4800)) + s.finish()
        #expect(next.count == 4800)
        #expect(next.allSatisfy { abs($0) < 1e-4 }, "peak \(next.map { abs($0) }.max() ?? 0)")
    }

    @Test func aVeryShortLineStillComesOut() {
        let s = VoicePitchShifter(semitones: 2)
        let x = Self.tone(250, seconds: 0.03)   // shorter than the priming length
        let y = s.process(x) + s.finish()
        #expect(y.count == x.count)
        #expect(y.contains { abs($0) > 0.05 })
        #expect(s.finish().isEmpty)   // nothing in flight: finishing twice is harmless
    }

    /// The C++ is built optimized even in Debug (Package.swift): 10 s of audio in well under a second.
    @Test func theShifterIsFastInEveryConfiguration() {
        let x = Self.pulses(267, seconds: 10)
        let t0 = Date()
        _ = VoicePitchShifter.shiftAll(x, semitones: 2)
        let speed = 10 / Date().timeIntervalSince(t0)
        print(String(format: "SHIFTER %.0fx real time", speed))
        #expect(speed > 100, "\(speed)x real time")
    }

    @Test func theCreditsNameBothLibrariesWithTheirLicense() throws {
        #expect(GrownUpsCopy.credits.map(\.line) == ["Signalsmith Stretch 1.4.0 · MIT License", "Signalsmith Linear 0.6.6 · MIT License"])
        // The shipped notice matches the vendored LICENSE files (whitespace aside).
        let vendor = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/SignalsmithShift/vendor")
        func words(_ s: String) -> String { s.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        for (dir, credit) in zip(["signalsmith-stretch", "signalsmith-linear"], GrownUpsCopy.credits) {
            let text = try String(contentsOf: vendor.appendingPathComponent("\(dir)/LICENSE.txt"), encoding: .utf8)
            #expect(words(text).contains(words(credit.copyright)))
            #expect(words(text).contains(words(GrownUpsCopy.mitLicense)))
        }
    }

    @Test func pulsesComeOutTwoSemitonesHigher() throws {
        let y = VoicePitchShifter.shiftAll(Self.pulses(267), semitones: 2)
        let hz = try #require(PitchTracker.medianHz(y))
        #expect(abs(12 * log2(hz / 267) - 2) < 0.15, "\(hz)")
    }

    // MARK: The app's graph, offline (shifter → player → Varispeed 1.20 → 48 kHz)

    /// Renders source samples through the speaker's chain: `shift` (nil = off) in ~`chunk` pieces before the player,
    /// then `SpeakerGraph`'s Varispeed and output link. Returns the 48 kHz mono output.
    static func renderThroughGraph(_ x: [Float], plan: ClipPitch.Plan?, chunk: Int = 2400, outputRate: Double = 48_000) throws -> [Float] {
        let engine = AVAudioEngine(), player = AVAudioPlayerNode()
        let pitch = SpeakerGraph.makePitchUnit(.nutmeg)
        engine.attach(player); if let pitch { engine.attach(pitch) }
        try engine.enableManualRenderingMode(.offline, format: AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 2)!, maximumFrameCount: 4096)
        SpeakerGraph.wire(engine, player: player, pitchUnit: pitch)
        try engine.start()
        let shifter = plan.flatMap { $0.isOn ? VoicePitchShifter($0, playbackRate: VoiceConfig.nutmeg.playbackRate) : nil }
        var total = 0
        func schedule(_ s: [Float]) {
            guard !s.isEmpty else { return }
            for b in SpeakerGraph.clipBuffers(s) { player.scheduleBuffer(b) }
            total += s.count
        }
        for r in ClipAudio.chunks(count: x.count, size: chunk) {
            let piece = Array(x[r])
            schedule(shifter.map { $0.process(piece) } ?? piece)
        }
        if let shifter { schedule(shifter.finish()) }
        player.play()
        let ob = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
        var all: [Float] = []
        let frames = Int(Double(total) / Self.sr / VoiceConfig.nutmeg.playbackRate * outputRate) + 8192
        while all.count < frames {
            _ = try engine.renderOffline(4096, to: ob)
            all += UnsafeBufferPointer(start: ob.floatChannelData![0], count: Int(ob.frameLength))
        }
        engine.stop()
        return all
    }

    @Test func theLiveVoiceIsHeardAtTheRateAndTwoSemitonesUp() throws {
        let x = Self.tone(220)
        let flat = try Self.renderThroughGraph(x, plan: nil)
        let up = try Self.renderThroughGraph(x, plan: ClipPitch.plan(clipHz: nil, shift: PitchShift()))
        func span(_ y: [Float]) -> (Double, Double) {
            let f = y.firstIndex { abs($0) > 0.05 }!, l = y.lastIndex { abs($0) > 0.05 }!
            var zc = 0; var prev = y[f]
            for v in y[f...l].dropFirst() { if prev < 0 && v >= 0 { zc += 1 }; prev = v }
            let secs = Double(l - f) / 48_000
            return (secs, Double(zc) / secs)
        }
        let (fs, fhz) = span(flat), (us, uhz) = span(up)
        #expect(abs(2.0 / fs - 1.20) < 0.03 && abs(2.0 / us - 1.20) < 0.03, "rate \(2 / fs), \(2 / us)")   // timing unchanged
        #expect(abs(fhz / 220 - 1.20) < 0.04)
        #expect(abs(12 * log2(uhz / fhz) - 2) < 0.15, "shift \(12 * log2(uhz / fhz)) st")
    }

    // MARK: The pitch check on every bundled clip

    static var commonClips: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("PretendThat/Resources/CommonClips")
    }

    static func decodeAAC(_ url: URL) throws -> [Float] {
        let f = try AVAudioFile(forReading: url)
        let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length))!
        try f.read(into: b)
        #expect(f.processingFormat.sampleRate == Self.sr)
        let n = Int(b.frameLength), skip = min(2112, n)   // ADTS priming (ClipStore.primingFrames)
        return Array(UnsafeBufferPointer(start: b.floatChannelData![0] + skip, count: n - skip))
    }

    /// Every bundled clip's raw pitch is in the range its adjustment can bring to the live voice. A future clip outside
    /// it fails here: re-record it nearer the live voice (decisions/2026-11-17-voice-pitch-build.md).
    @Test func everyBundledClipIsInTheSanePitchRange() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.commonClips, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "aac" }
        #expect(files.count == CommonLines.all.count)
        for f in files {
            let hz = PitchTracker.medianHz(try Self.decodeAAC(f))
            #expect(ClipPitch.check(hz) == .ok, "\(f.lastPathComponent): \(hz ?? 0) Hz raw, sane \(ClipPitch.saneRange())")
        }
    }

    /// The bright greeting clip ends up close to the live voice after the raise (not higher), measured.
    @Test func theGreetingClipLandsOnTheLiveVoice() throws {
        let url = Self.commonClips.appendingPathComponent("common-0adc890610789fbdb033ec1173261358.aac")
        let x = try Self.decodeAAC(url)
        let before = try #require(PitchTracker.medianHz(x))
        #expect(before > 360)   // the bright one
        let plan = ClipPitch.plan(clipHz: before, shift: PitchShift())
        let y = VoicePitchShifter.shiftAll(x, semitones: plan.semitones, formantSemitones: plan.formantSemitones)
        let after = try #require(PitchTracker.medianHz(y))
        let target = ClipPitch.targetHz(PitchShift())
        #expect(abs(12 * log2(after / target)) < 0.75, "greeting \(before) → \(after) Hz raw, live target \(target)")
    }

    // MARK: Offline renders for the listening page (only with PT_RENDER_DIR set; no API, no simulator)

    /// PT_RENDER_DIR=<dir> PT_RENDER_IN=a.caf,b.caf,clip.aac: writes <name>-today.f32 and <name>-new.f32 (48 kHz mono
    /// float) rendered through the app's chain. .aac inputs are clips (per-clip plan), others live lines (+2 streamed in
    /// ~50 ms deltas, like Realtime's).
    @Test func renderForListening() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["PT_RENDER_DIR"], let ins = env["PT_RENDER_IN"] else { return }
        for path in ins.split(separator: ",").map(String.init) {
            let url = URL(fileURLWithPath: path)
            let isClip = url.pathExtension == "aac"
            let x: [Float]
            if isClip { x = try Self.decodeAAC(url) } else {
                let f = try AVAudioFile(forReading: url)
                let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length))!
                try f.read(into: b)
                x = Array(UnsafeBufferPointer(start: b.floatChannelData![0], count: Int(b.frameLength)))
            }
            let hz = PitchTracker.medianHz(x)
            let plan = isClip ? ClipPitch.plan(clipHz: hz, shift: PitchShift()) : ClipPitch.plan(clipHz: nil, shift: PitchShift())
            let name = url.deletingPathExtension().lastPathComponent
            for (tag, p) in [("today", nil as ClipPitch.Plan?), ("new", plan)] {
                let y = try Self.renderThroughGraph(x, plan: p, chunk: isClip ? 2400 : 1200)
                try y.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-\(tag).f32"))
            }
            if env["PT_RENDER_RAW"] != nil {   // the shifter's own 24 kHz output (before Varispeed), for A/B checks
                let y = VoicePitchShifter.shiftAll(x, semitones: plan.semitones, formantSemitones: plan.formantSemitones, chunk: 1200)
                try y.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-shift24.f32"))
            }
            if isClip {
                let alt = ClipPitch.plan(clipHz: hz, shift: PitchShift(), matchLiveFormants: false)
                let y = try Self.renderThroughGraph(x, plan: alt)
                try y.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-plain.f32"))
            }
            print(String(format: "RENDER %@ raw %.1f Hz plan %+.2f st formant %@", name, hz ?? 0, plan.semitones, plan.formantSemitones.map { String(format: "%+.1f", $0) } ?? "follows"))
        }
    }
}
