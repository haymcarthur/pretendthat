@preconcurrency import AVFAudio
import Foundation

// Round 25 (Haylee: "the voice changed again, it doesn't sound as high as before"). Nutmeg's sound is coral played
// through Varispeed at 1.20. Measured on the simulator (mixer taps, `-PTTapOut`): the engine's IMPLICIT mixer → output
// link was 44.1 kHz while the audio session and hardware ran at 48 kHz, and the effective rate came out
// 1.20 × 44.1/48 ≈ 1.10 (about 1.5 semitones lower, and slower) on the pre-D3a build and HEAD alike. The graph is now
// built here, in one place, with the mixer → output link made at the output's hardware format, and every source path
// (live audio deltas, live app lines, recorded clips, bundled clips) goes through the same player → Varispeed chain.
// `SpeakerGraphTests` renders each path offline and locks the effective rate at 1.20.

/// Where a piece of Nutmeg's audio comes from. All of them play through the same chain at the same rate.
public enum VoiceSource: String, CaseIterable, Sendable {
    /// Her live Realtime replies (PCM16 deltas).
    case live
    /// A scripted app line said live (`sayExactly`): PCM16 deltas too.
    case appLine
    /// A line recorded in this game (stored before Varispeed, played as float chunks).
    case clip
    /// One of the bundled common lines (recorded the same way).
    case bundledClip
}

public enum SpeakerGraph {
    /// The 24 kHz mono format everything is scheduled in (the Realtime output rate).
    public static var playFormat: AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: Realtime.sampleRate, channels: 1)! }

    /// The rate she's heard at, per source: the same Varispeed rate for every one (clips are stored pre-Varispeed).
    public static func effectiveRate(_ source: VoiceSource, config: VoiceConfig = .nutmeg) -> Double { config.playbackRate }

    public static func makePitchUnit(_ config: VoiceConfig) -> AVAudioUnit? {
        switch config.method {
        case .off: return nil
        case .varispeed: let u = AVAudioUnitVarispeed(); u.rate = Float(config.rate); return u
        case .timePitch: let u = AVAudioUnitTimePitch(); u.pitch = Float(config.cents); u.rate = 1; return u
        }
    }

    /// player → [pitch unit] → mixer at the 24 kHz play format; mixer → output at the output's hardware format (never
    /// the engine's implicit default, which can differ from the hardware rate and shift her pitch and pace).
    public static func wire(_ engine: AVAudioEngine, player: AVAudioPlayerNode, pitchUnit: AVAudioUnit?) {
        let play = playFormat
        if let pitchUnit {
            engine.connect(player, to: pitchUnit, format: play)
            engine.connect(pitchUnit, to: engine.mainMixerNode, format: play)
        } else {
            engine.connect(player, to: engine.mainMixerNode, format: play)
        }
        let hw = engine.isInManualRenderingMode ? engine.manualRenderingFormat : engine.outputNode.outputFormat(forBus: 0)
        if hw.sampleRate > 0, hw.channelCount > 0,
           let out = AVAudioFormat(standardFormatWithSampleRate: hw.sampleRate, channels: hw.channelCount) {
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: out)
        }
    }

    /// Live audio and live app lines: a PCM16 delta as one float buffer.
    public static func pcm16Buffer(_ data: Data) -> AVAudioPCMBuffer? {
        let frames = data.count / 2
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: playFormat, frameCapacity: AVAudioFrameCount(frames)),
              let out = buf.floatChannelData?[0] else { return nil }
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Int16.self)
            for i in 0..<frames { out[i] = Float(Int16(littleEndian: src[i])) / 32768 }
        }
        buf.frameLength = AVAudioFrameCount(frames)
        return buf
    }

    /// Clips and bundled clips: float samples in ~100 ms chunks.
    public static func clipBuffers(_ samples: [Float]) -> [AVAudioPCMBuffer] {
        ClipAudio.chunks(count: samples.count).compactMap { r in
            guard let buf = AVAudioPCMBuffer(pcmFormat: playFormat, frameCapacity: AVAudioFrameCount(r.count)),
                  let out = buf.floatChannelData?[0] else { return nil }
            samples.withUnsafeBufferPointer { src in out.update(from: src.baseAddress! + r.lowerBound, count: r.count) }
            buf.frameLength = AVAudioFrameCount(r.count)
            return buf
        }
    }
}
