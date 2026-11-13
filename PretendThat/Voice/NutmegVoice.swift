import AVFoundation
import Observation

/// Nutmeg's text-to-speech with a live 0…1 loudness level that drives her mouth.
/// Synthesizes to PCM buffers, plays them through an AVAudioEngine, and taps the mixer for RMS.
@Observable @MainActor
final class NutmegVoice {
    private(set) var level: Float = 0
    private(set) var isSpeaking = false
    private(set) var lastLine: String?

    // Livelier than the spec's 1.2 / 0.48: Nutmeg is a bouncy, excitable kid (Haylee, 2026-11-13).
    static let pitch: Float = 1.35
    static let rate: Float = 0.53

    @ObservationIgnored private let synth = AVSpeechSynthesizer()
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    @ObservationIgnored private var connectedFormat: AVAudioFormat?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var pending: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var fakeLevelTask: Task<Void, Never>?

    init() {
        engine.attach(player)
    }

    static let voice: AVSpeechSynthesisVoice? = {
        let en = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        return en.first { $0.quality == .premium } ?? en.first { $0.quality == .enhanced } ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    /// Speaks a line and returns when playback finishes (or when interrupted by `stop()`/another `say`).
    func say(_ text: String) async {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        stop()
        generation += 1
        let gen = generation
        lastLine = line
        isSpeaking = true
        AudioSessionSetup.activate()

        let utterance = AVSpeechUtterance(string: line)
        utterance.voice = Self.voice
        utterance.pitchMultiplier = Self.pitch
        utterance.rate = Self.rate

        let buffers = await synthesize(utterance)
        guard gen == generation else { return }

        if buffers.isEmpty || !play(buffers, gen: gen) {
            await speakDirectly(utterance, gen: gen)   // simulator/edge cases: plain speech with a fake mouth level
        } else {
            await withCheckedContinuation { pending = $0 }
        }
        if gen == generation { finish() }
    }

    func stop() {
        generation += 1
        player.stop()
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        fakeLevelTask?.cancel(); fakeLevelTask = nil
        finish()
    }

    private func finish() {
        isSpeaking = false
        level = 0
        if let p = pending { pending = nil; p.resume() }
    }

    // MARK: Engine playback

    private func play(_ buffers: [AVAudioPCMBuffer], gen: Int) -> Bool {
        guard let format = buffers.first?.format else { return false }
        if connectedFormat != format {
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.removeTap(onBus: 0)
            Self.installLevelTap(on: engine.mainMixerNode) { [weak self] rms in
                Task { @MainActor in self?.update(rms: rms) }
            }
            connectedFormat = format
        }
        do { if !engine.isRunning { try engine.start() } } catch { return false }
        for (i, b) in buffers.enumerated() {
            let last = i == buffers.count - 1
            player.scheduleBuffer(b, completionCallbackType: .dataPlayedBack,
                                  completionHandler: last ? Self.doneHandler { [weak self] in if self?.generation == gen { self?.finish() } } : nil)
        }
        player.play()
        return true
    }

    private func update(rms: Float) {
        guard isSpeaking else { level = 0; return }
        let target = min(1, rms * 9)
        // Fast attack, ~120 ms release (tap fires ~every 23 ms).
        level = target > level ? target : level + (target - level) * 0.18
    }

    private func speakDirectly(_ u: AVSpeechUtterance, gen: Int) async {
        synth.speak(u)
        fakeLevelTask = Task { @MainActor [weak self] in
            var t: Double = 0
            while let self, !Task.isCancelled, self.generation == gen {
                if !self.synth.isSpeaking && t > 0.3 { break }
                self.level = Float(abs(sin(t * 11)) * 0.7)
                t += 0.05
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        await fakeLevelTask?.value
    }

    // MARK: Off-main helpers (closures must not inherit MainActor isolation)

    private func synthesize(_ u: AVSpeechUtterance) async -> [AVAudioPCMBuffer] {
        let box = BufferBox()
        return await withCheckedContinuation { (c: CheckedContinuation<[AVAudioPCMBuffer], Never>) in
            synth.write(u, toBufferCallback: Self.bufferCallback(box: box, c: c))
            // Safety net: if the synthesizer never signals the end, give up after 4 s.
            DispatchQueue.global().asyncAfter(deadline: .now() + 4) { box.finish(c) }
        }
    }

    nonisolated private static func bufferCallback(box: BufferBox, c: CheckedContinuation<[AVAudioPCMBuffer], Never>) -> (AVAudioBuffer) -> Void {
        { buffer in
            if let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 { box.append(pcm) } else { box.finish(c) }
        }
    }

    /// Built off the main actor so the audio thread never trips a MainActor isolation check.
    nonisolated private static func doneHandler(_ onMain: @escaping @MainActor @Sendable () -> Void) -> AVAudioPlayerNodeCompletionHandler {
        { _ in Task { @MainActor in onMain() } }
    }

    nonisolated private static func installLevelTap(on node: AVAudioMixerNode, report: @escaping @Sendable (Float) -> Void) {
        node.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            guard let data = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            guard n > 0 else { return }
            var sum: Float = 0
            for i in 0..<n { sum += data[i] * data[i] }
            report((sum / Float(n)).squareRoot())
        }
    }
}

final class BufferBox: @unchecked Sendable {
    private var buffers: [AVAudioPCMBuffer] = []
    private var done = false
    private let lock = NSLock()
    func append(_ b: AVAudioPCMBuffer) { lock.withLock { if !done { buffers.append(b) } } }
    func finish(_ c: CheckedContinuation<[AVAudioPCMBuffer], Never>) {
        let result: [AVAudioPCMBuffer]? = lock.withLock { if done { return nil }; done = true; return buffers }
        if let result { c.resume(returning: result) }
    }
}

struct UncheckedSendable<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

enum AudioSessionSetup {
    @MainActor static func activate() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? s.setActive(true)
    }
}
