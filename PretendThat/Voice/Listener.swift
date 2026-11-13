import AVFoundation
import Observation
import Speech

/// Hold-to-talk, on-device speech-to-text. Kids' audio never leaves the iPad.
@Observable @MainActor
final class Listener {
    private(set) var transcript = ""
    private(set) var isListening = false
    /// False when permission is denied or recognition isn't usable (choices and typing still work).
    private(set) var available = false
    /// Why the mic is off, or which recognizer it uses, in words for the Grown-ups screen.
    private(set) var status = "Checking..."
    /// True only in a DEBUG simulator build where on-device recognition is missing: Apple's server
    /// recognizer is used instead so the demo mic works. Never true on a real iPad.
    private(set) var usesServerRecognition = false

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var isFinal = false

    func requestAuth() async {
        let speech = await Self.speechAuth()
        let mic = await AVAudioApplication.requestRecordPermission()
        let decision = Self.decide(speech: speech, mic: mic, recognizerExists: recognizer != nil,
                                   recognizerAvailable: recognizer?.isAvailable ?? false,
                                   onDevice: recognizer?.supportsOnDeviceRecognition ?? false,
                                   allowServerFallback: Self.isDebugSimulator)
        available = decision.available
        usesServerRecognition = decision.server
        status = decision.status
    }

    /// Simulators report no on-device speech model, so on-device-only recognition is never available there.
    static var isDebugSimulator: Bool {
        #if DEBUG && targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    /// Pure decision so each case is easy to reason about (see thinking/decisions/mic-simulator-fallback.md).
    nonisolated static func decide(speech: SFSpeechRecognizerAuthorizationStatus, mic: Bool, recognizerExists: Bool,
                                   recognizerAvailable: Bool, onDevice: Bool, allowServerFallback: Bool)
        -> (available: Bool, server: Bool, status: String) {
        switch speech {
        case .denied: return (false, false, "Off: speech permission denied (Settings > Privacy > Speech Recognition)")
        case .restricted: return (false, false, "Off: speech recognition is restricted on this iPad")
        case .notDetermined: return (false, false, "Off: speech permission not answered yet")
        case .authorized: break
        @unknown default: return (false, false, "Off: unknown speech permission")
        }
        guard mic else { return (false, false, "Off: microphone permission denied") }
        guard recognizerExists else { return (false, false, "Off: no English speech recognizer") }
        if onDevice { return (true, false, "On-device ✓ (audio never leaves the iPad)") }
        if allowServerFallback && recognizerAvailable {
            return (true, true, "Simulator demo: Apple server speech (no on-device model in the simulator)")
        }
        return (false, false, "Off: on-device speech isn't supported here. Typing works instead.")
    }

    func startListening(stopping voice: NutmegVoice) {
        voice.stop()   // Nutmeg never hears herself
        guard available, !isListening, let recognizer else { return }
        transcript = ""; isFinal = false
        AudioSessionSetup.activate()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = !usesServerRecognition
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
