import AVFoundation
import Observation
import Speech

/// Hold-to-talk, on-device speech-to-text. Kids' audio never leaves the iPad.
@Observable @MainActor
final class Listener {
    private(set) var transcript = ""
    private(set) var isListening = false
    /// False when permission is denied or on-device recognition isn't supported (choices still work).
    private(set) var available = false

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var isFinal = false

    func requestAuth() async {
        let speech = await Self.speechAuth()
        let mic = await AVAudioApplication.requestRecordPermission()
        available = speech == .authorized && mic && (recognizer?.supportsOnDeviceRecognition ?? false)
    }

    func startListening(stopping voice: NutmegVoice) {
        voice.stop()   // Nutmeg never hears herself
        guard available, !isListening, let recognizer else { return }
        transcript = ""; isFinal = false
        AudioSessionSetup.activate()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true
        req.shouldReportPartialResults = true
        request = req
        let input = engine.inputNode
        Self.installInputTap(on: input, request: req)
        engine.prepare()
        do { try engine.start() } catch { input.removeTap(onBus: 0); return }
        isListening = true
        task = Self.recognize(recognizer, req) { [weak self] text, final in
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text }
                if final { self.isFinal = true }
            }
        }
    }

    /// Stops listening and returns the final text ("" if nothing was heard).
    func stopListening() async -> String {
        guard isListening else { return "" }
        isListening = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        for _ in 0..<12 where !isFinal { try? await Task.sleep(for: .milliseconds(60)) }
        task?.cancel(); task = nil; request = nil
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func speechAuth() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
    }

    nonisolated private static func installInputTap(on input: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) {
        let req = UncheckedSendable(request)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            req.value.append(buffer)
        }
    }

    nonisolated private static func recognize(_ r: SFSpeechRecognizer, _ req: SFSpeechAudioBufferRecognitionRequest,
                                              update: @escaping @Sendable (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        r.recognitionTask(with: req) { result, error in
            update(result?.bestTranscription.formattedString, (result?.isFinal ?? false) || error != nil)
        }
    }
}
