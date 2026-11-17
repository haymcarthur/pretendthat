@preconcurrency import AVFAudio
import Foundation
import Testing
@testable import NutmegCore

/// Voice pitch build (decisions/2026-11-17-voice-pitch-build.md): Signalsmith Stretch +2 semitones on the live voice,
/// clips get the same processing (voice clips match), the config, and the pitch check on every bundled clip.
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
        #expect(!ClipPitch.plan(.off).isOn)
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

    @Test func clipsGetExactlyTheLiveProcessing() {
        // Voice clips match (2026-11-17): every clip, whatever its own pitch, gets the live +2 plain, nothing else.
        let live = ClipPitch.plan(PitchShift())
        #expect(live == ClipPitch.Plan(semitones: 2, formantSemitones: nil))
        #expect(VoicePitchShifter(live, playbackRate: 1.2).semitones == 2)
        // Formants kept (if the setting ever flips): clips follow the live setting.
        #expect(ClipPitch.plan(PitchShift(semitones: 2, preserveFormants: true)).formantSemitones == 0)
    }

    @Test func thePitchBandsSitAroundTheLiveVoice() {
        let m = ClipPitch.matchRange, k = ClipPitch.keepRange
        #expect(abs(m.lowerBound - 230.2) < 0.5 && abs(m.upperBound - 307.3) < 0.5, "\(m)")
        #expect(abs(k.lowerBound - 211.1) < 0.5 && abs(k.upperBound - 335.1) < 0.5, "\(k)")
        #expect(ClipPitch.check(266) == .ok && ClipPitch.check(300) == .ok)
        // The old bright greeting takes (376, 395 Hz raw) and the low "saved game" take (224) are out: re-record them.
        #expect(ClipPitch.check(376) == .outOfRange && ClipPitch.check(395) == .outOfRange && ClipPitch.check(224) == .outOfRange)
        #expect(ClipPitch.check(nil) == .unmeasured && ClipPitch.check(0) == .unmeasured)
        // A game take is kept inside ±4 st (or unmeasured), dropped outside it (a replay says it live again).
        #expect(ClipPitch.keeps(266) && ClipPitch.keeps(320) && ClipPitch.keeps(nil))
        #expect(!ClipPitch.keeps(386) && !ClipPitch.keeps(200))
        #expect(ClipPitch.distance(266) == 0 && ClipPitch.distance(nil) == .infinity)
        #expect(ClipPitch.distance(290) < ClipPitch.distance(240))
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
        #expect(GrownUpsCopy.credits.map(\.line).prefix(2) == ["Signalsmith Stretch 1.4.0 · MIT License", "Signalsmith Linear 0.6.6 · MIT License"])
        // Round 39: TelemetryDeck (MIT) and Poppins (OFL) are credited too.
        #expect(GrownUpsCopy.credits.map(\.line).dropFirst(2) == ["TelemetryDeck SwiftSDK 2.14.2 · MIT License", "Poppins 4.004 · SIL Open Font License 1.1"])
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
        let up = try Self.renderThroughGraph(x, plan: ClipPitch.plan(PitchShift()))
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

    /// Every bundled clip's raw pitch is in the live voice's band (clips get exactly the live +2, so a take outside it
    /// would be heard brighter or lower than her live lines). A future clip outside it fails here: re-record it with
    /// `-PTRecordCommon all` (decisions/2026-11-17-voice-clips-match.md).
    @Test func everyBundledClipIsInTheLiveBand() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.commonClips, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "aac" }
        #expect(files.count == CommonLines.all.count)
        for f in files {
            let hz = PitchTracker.medianHz(try Self.decodeAAC(f))
            #expect(ClipPitch.check(hz) == .ok, "\(f.lastPathComponent): \(hz ?? 0) Hz raw, live band \(ClipPitch.matchRange)")
        }
    }

    /// The greeting clip (the first thing a New game says) is heard within a semitone or so of a live line through
    /// the app's chain, with the same processing (the seam Haylee heard).
    @Test func theGreetingClipSoundsLikeTheLiveVoice() throws {
        let url = Self.commonClips.appendingPathComponent("common-0adc890610789fbdb033ec1173261358.aac")
        let hz = try #require(PitchTracker.medianHz(try Self.decodeAAC(url)))
        #expect(abs(12 * log2(hz / ClipPitch.liveRawMedianHz)) < ClipPitch.matchSemitones, "greeting \(hz) Hz raw")
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
            let plan = ClipPitch.plan(PitchShift())   // clips and live lines alike
            let name = url.deletingPathExtension().lastPathComponent
            for (tag, p) in [("today", nil as ClipPitch.Plan?), ("new", plan)] {
                let y = try Self.renderThroughGraph(x, plan: p, chunk: isClip ? 2400 : 1200)
                try y.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-\(tag).f32"))
            }
            if env["PT_RENDER_RAW"] != nil {   // the shifter's own 24 kHz output (before Varispeed), for A/B checks
                let y = VoicePitchShifter.shiftAll(x, semitones: plan.semitones, formantSemitones: plan.formantSemitones, chunk: 1200)
                try y.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-shift24.f32"))
            }
            print(String(format: "RENDER %@ raw %.1f Hz plan %+.2f st formant %@", name, hz ?? 0, plan.semitones, plan.formantSemitones.map { String(format: "%+.1f", $0) } ?? "follows"))
        }
    }
}
