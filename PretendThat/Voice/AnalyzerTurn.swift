import AVFoundation
import Foundation
import Speech

/// Round 34: one push-to-talk turn through iPadOS 26's SpeechAnalyzer + DictationTranscriber, the on-device model the
/// app downloads itself (`SpeechModelInstaller`). Used only when that model is installed and the older
/// SFSpeechRecognizer can't recognize on the device (its Dictation asset isn't there), so the round 31 path is
/// unchanged wherever it already works. Same privacy rule: on the iPad only, the audio is dropped after the turn.
/// NOT verifiable in the simulator (its speech models can't load): needs the real iPad.
@available(iOS 26, *)
final class AnalyzerTurn: @unchecked Sendable {
    private let lock = NSLock()
    private let transcriber = DictationTranscriber(locale: SpeechModelInstallerLocale.value, preset: .shortDictation)
    private var analyzer: SpeechAnalyzer?
    private let stream: AsyncStream<AnalyzerInput>
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private var format: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var pending: [AVAudioPCMBuffer] = []
    private var text = ""
    private var results: Task<Void, Never>?
    private var startTask: Task<Void, Never>?

    init() {
        (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        startTask = Task { [weak self] in await self?.start() }
    }

    private func start() async {
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let queued: [AVAudioPCMBuffer] = lock.withLock {
            self.format = format; self.analyzer = analyzer
            let q = pending; pending = []; return q
        }
        results = Task { [weak self, transcriber] in
            do {
                for try await r in transcriber.results {
                    let piece = String(r.text.characters)
                    self?.lock.withLock { self?.text += piece }
                }
            } catch { rtLog("speech (analyzer): results ended with \(error.localizedDescription)") }
        }
        for b in queued { feed(b) }
        do { try await analyzer.start(inputSequence: stream) }
        catch { rtLog("speech (analyzer): start failed: \(error.localizedDescription)") }
    }

    /// Audio thread: one chunk (converted to the analyzer's format once it's known; queued before that).
    func append(_ buffer: AVAudioPCMBuffer) {
        let ready = lock.withLock { () -> Bool in
            if format == nil { if let c = buffer.copy() as? AVAudioPCMBuffer { pending.append(c) }; return false }
            return true
        }
        if ready { feed(buffer) }
    }

    private func feed(_ buffer: AVAudioPCMBuffer) {
        guard let out = convert(buffer) else { return }
        input.yield(AnalyzerInput(buffer: out))
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let format = lock.withLock({ self.format }) else { return nil }
        if buffer.format == format { return buffer }
        let conv: AVAudioConverter? = lock.withLock {
            if converter == nil || converter?.inputFormat != buffer.format { converter = AVAudioConverter(from: buffer.format, to: format) }
            return converter
        }
        guard let conv else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let cap = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: cap) else { return nil }
        var fed = false
        var err: NSError?
        conv.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true; status.pointee = .haveData; return buffer
        }
        return err == nil ? out : nil
    }

    /// Release: end the audio, finalize, return the words (bounded by the caller's timeout).
    func finish() async -> String {
        await startTask?.value
        input.finish()
        try? await lock.withLock({ analyzer })?.finalizeAndFinishThroughEndOfInput()
        await results?.value
        return lock.withLock { text }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancel() {
        input.finish()
        results?.cancel()
        let a = lock.withLock { analyzer }
        Task { await a?.cancelAndFinishNow() }
    }
}

enum SpeechModelInstallerLocale { static let value = Locale(identifier: "en-US") }
