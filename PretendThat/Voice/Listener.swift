import AVFoundation
import Observation
import Speech
import NutmegCore

/// Round 31 (decisions/2026-11-16-on-device-speech.md): whether the iPad can listen ON THE DEVICE, and the hold-to-talk
/// path for when there's no live voice session. Kids' audio never leaves the iPad: recognition is on-device only
/// (`KidSpeechCapture`), and when that isn't possible the mic shows a grown-up note and typing takes over. There is no
/// server fallback of any kind (the old DEBUG simulator use of Apple's server recognizer is gone).
@Observable @MainActor
final class Listener {
    private(set) var isListening = false
    /// On-device listening is possible (permission given, English (US) on-device speech present).
    var available: Bool { readiness.canListen }
    private(set) var readiness: SpeechReadiness = .notAskedYet
    /// Why the mic is off, or that it's on, in words for the Grown-ups screen.
    var status: String { readiness.status }

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    /// The no-session path's own capture (the live session's capture rides on the speaker's engine).
    @ObservationIgnored let capture = KidSpeechCapture()
    @ObservationIgnored private var heldSince: Date?

    func requestAuth() async {
        let speech = await Self.speechAuth()
        let mic = await AVAudioApplication.requestRecordPermission()
        refresh(speech: speech, mic: mic)
    }

    /// Re-reads the state without asking (or marks on-device speech missing after a recognition error said so).
    func refresh(speech: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus(),
                 mic: Bool = AVAudioApplication.shared.recordPermission == .granted, forceUnavailable: Bool = false) {
        let permission: SpeechReadiness.Permission = switch speech {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        default: .notDetermined
        }
        readiness = forceUnavailable ? .onDeviceUnavailable
            : SpeechReadiness.decide(speech: permission, mic: mic, recognizerExists: recognizer != nil,
                                     supportsOnDevice: recognizer?.supportsOnDeviceRecognition ?? false)
        rtLog("speech: \(readiness) (on-device supported: \(recognizer?.supportsOnDeviceRecognition ?? false))")
    }

    /// A recognition error said on-device speech can't run (asset missing): typing from now on, with the note.
    func markUnavailable() { if readiness != .onDeviceUnavailable { refresh(forceUnavailable: true) } }

    // MARK: No live session (the tap fallback): its own engine, the same on-device capture

    func startListening(stopping voice: NutmegVoice, touchHost: Double) {
        voice.stop()   // Nutmeg never hears herself
        guard available, !isListening else { return }
        AudioSessionSetup.activate()
        let input = engine.inputNode
        Self.installInputTap(on: input, capture: capture)
        engine.prepare()
        do { try engine.start() } catch { input.removeTap(onBus: 0); return }
        capture.begin(touchHost: touchHost)
        heldSince = Date()
        isListening = true
    }

    /// Stops listening and returns the final words ("" if nothing was heard). The audio is gone after this.
    func stopListening() async -> (words: String, held: Double) {
        guard isListening else { return ("", 0) }
        isListening = false
        let held = heldSince.map { Date().timeIntervalSince($0) } ?? 0
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        return (await capture.finish(), held)
    }

    nonisolated static func speechAuth() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
    }

    nonisolated private static func installInputTap(on input: AVAudioInputNode, capture: KidSpeechCapture) {
        input.installTap(onBus: 0, bufferSize: 2400, format: input.outputFormat(forBus: 0)) { buffer, when in
            capture.push(buffer, host: when.isHostTimeValid ? AVAudioTime.seconds(forHostTime: when.hostTime) : nil)
        }
    }
}
