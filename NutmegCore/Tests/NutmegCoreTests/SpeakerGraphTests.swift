@preconcurrency import AVFAudio
import Foundation
import Testing
@testable import NutmegCore

/// Round 25 (Haylee: "it doesn't sound as high as before"): every source path plays through the same
/// player → Varispeed → mixer → output graph, and the effective rate is 1.20 whatever the output hardware rate.
/// Rendered offline through `SpeakerGraph.wire` (the app's own wiring), measured by how long a 2 s tone lasts.
struct SpeakerGraphTests {

    /// 2 s of a 220 Hz tone at 24 kHz, as each source would hand it to the speaker.
    static let tone: [Float] = (0..<48_000).map { sin(2 * .pi * 220 * Float($0) / 24_000) * 0.5 }
    static var tonePCM16: Data {
        var d = Data(capacity: tone.count * 2)
        for s in tone { var v = Int16(s * 32767).littleEndian; withUnsafeBytes(of: &v) { d.append(contentsOf: $0) } }
        return d
    }

    /// Renders the source offline at `outputRate` and returns (heard seconds, zero-crossing frequency).
    func render(_ source: VoiceSource, outputRate: Double, config: VoiceConfig = .nutmeg) throws -> (seconds: Double, hz: Double) {
        let engine = AVAudioEngine(), player = AVAudioPlayerNode()
        let pitch = SpeakerGraph.makePitchUnit(config)
        engine.attach(player); if let pitch { engine.attach(pitch) }
        let out = AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 2)!
        try engine.enableManualRenderingMode(.offline, format: out, maximumFrameCount: 4096)
        SpeakerGraph.wire(engine, player: player, pitchUnit: pitch)
        try engine.start()
        let buffers: [AVAudioPCMBuffer]
        switch source {
        case .live, .appLine:
            // Live deltas arrive in ~100 ms pieces.
            let d = Self.tonePCM16
            buffers = stride(from: 0, to: d.count, by: 4800).compactMap { SpeakerGraph.pcm16Buffer(d.subdata(in: $0..<min($0 + 4800, d.count))) }
        case .clip, .bundledClip:
            buffers = SpeakerGraph.clipBuffers(Self.tone)
        }
        for b in buffers { player.scheduleBuffer(b) }
        player.play()
        let ob = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
        var all: [Float] = []
        for _ in 0..<Int(outputRate * 3 / 4096) {
            _ = try engine.renderOffline(4096, to: ob)
            all += UnsafeBufferPointer(start: ob.floatChannelData![0], count: Int(ob.frameLength))
        }
        engine.stop()
        guard let first = all.firstIndex(where: { abs($0) > 0.05 }), let last = all.lastIndex(where: { abs($0) > 0.05 }) else { return (0, 0) }
        let seg = all[first...last]
        var zc = 0; var prev = seg.first!
        for v in seg.dropFirst() { if prev < 0 && v >= 0 { zc += 1 }; prev = v }
        let secs = Double(last - first) / outputRate
        return (secs, Double(zc) / secs)
    }

    @Test(arguments: VoiceSource.allCases)
    func everyPathIsHeardAtTheVarispeedRate(_ source: VoiceSource) throws {
        #expect(SpeakerGraph.effectiveRate(source) == 1.20)
        #expect(VoiceConfig.nutmeg.method == .varispeed && VoiceConfig.nutmeg.rate == 1.20)
        let flat = try render(source, outputRate: 48_000, config: VoiceConfig(method: .off))
        for rate in [48_000.0, 44_100.0] {
            let r = try render(source, outputRate: rate)
            // 2 s of audio at 1.20 lasts 1.667 s, and the tone is 1.20 × higher than the unshifted render.
            #expect(abs(2.0 / r.seconds - 1.20) < 0.03, "\(source) @\(rate): rate \(2.0 / r.seconds)")
            #expect(abs(r.hz / flat.hz - 1.20) < 0.04, "\(source) @\(rate): pitch ×\(r.hz / flat.hz)")
        }
    }

    /// Round 33 (Haylee: "her voice sounds changed again"): a link left at an old rate after the hardware rate moved
    /// (the mic's input starting, a route change) is detected and re-linked, and every path is heard at 1.20 again.
    /// (An offline engine can't run a live input node, so the "input running" case is modelled as the hardware rate
    /// moving under an already-wired graph, which is what an input start or route change does to the output.)
    @Test(arguments: VoiceSource.allCases)
    func aStaleLinkIsRelinkedAndHeardAtTheVarispeedRate(_ source: VoiceSource) throws {
        for (stale, hw) in [(44_100.0, 48_000.0), (48_000.0, 44_100.0), (48_000.0, 24_000.0)] {
            let engine = AVAudioEngine(), player = AVAudioPlayerNode()
            let pitch = SpeakerGraph.makePitchUnit(.nutmeg)
            engine.attach(player); if let pitch { engine.attach(pitch) }
            try engine.enableManualRenderingMode(.offline, format: AVAudioFormat(standardFormatWithSampleRate: hw, channels: 2)!, maximumFrameCount: 4096)
            SpeakerGraph.wire(engine, player: player, pitchUnit: pitch)
            // The hardware moved after wiring: the link is stale.
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: AVAudioFormat(standardFormatWithSampleRate: stale, channels: 2)!)
            #expect(SpeakerGraph.linkMismatch(engine)?.link == stale)
            #expect(SpeakerGraph.relinkIfNeeded(engine, player: player, pitchUnit: pitch) == stale)
            #expect(SpeakerGraph.linkMismatch(engine) == nil)
            #expect(SpeakerGraph.relinkIfNeeded(engine, player: player, pitchUnit: pitch) == nil)   // nothing to do twice
            #expect(engine.outputNode.inputFormat(forBus: 0).sampleRate == hw)
        }
        // And the rendered rate after a re-link is 1.20 at each hardware rate.
        for hw in [48_000.0, 44_100.0] {
            let r = try render(source, outputRate: hw)
            #expect(abs(2.0 / r.seconds - 1.20) < 0.03, "\(source) @\(hw): rate \(2.0 / r.seconds)")
        }
    }

    @Test func theMixerToOutputLinkIsAtTheOutputRate() throws {
        for rate in [44_100.0, 48_000.0] {
            let engine = AVAudioEngine(), player = AVAudioPlayerNode()
            let pitch = SpeakerGraph.makePitchUnit(.nutmeg)
            engine.attach(player); if let pitch { engine.attach(pitch) }
            try engine.enableManualRenderingMode(.offline, format: AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!, maximumFrameCount: 1024)
            SpeakerGraph.wire(engine, player: player, pitchUnit: pitch)
            #expect(engine.mainMixerNode.outputFormat(forBus: 0).sampleRate == rate)
            #expect(engine.outputNode.inputFormat(forBus: 0).sampleRate == rate)
        }
    }
}
