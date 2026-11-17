import AVFoundation
import NutmegCore

// Round 35 prep: what was left of the old text-to-speech file once the system-voice fallback was removed. Nutmeg never uses
// system TTS: every line is her recorded clip or her live Realtime voice through NutmegSpeaker, or nothing.

struct UncheckedSendable<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

/// The tap-fallback listener's session: the same one setup as Nutmeg's speaker (`NutmegAudioSession`).
enum AudioSessionSetup {
    @MainActor static func activate() { try? NutmegAudioSession.nutmeg.apply() }
}
