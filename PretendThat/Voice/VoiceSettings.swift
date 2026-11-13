import Foundation
import Observation
import NutmegCore

/// Grown-ups tuning for Nutmeg's Realtime voice (D7, conversation-voice.md). Device settings only; nothing about
/// kids is stored. Keys are versioned (v2) so the old +350-cent TimePitch default doesn't carry over.
@Observable @MainActor
final class VoiceSettings {
    var voice: String { didSet { defaults.set(voice, forKey: Keys.voice) } }
    var method: Realtime.PitchMethod { didSet { defaults.set(method.rawValue, forKey: Keys.method) } }
    /// TimePitch cents (TimePitch method only).
    var pitchCents: Double { didSet { defaults.set(pitchCents, forKey: Keys.pitch) } }
    /// Varispeed rate (Varispeed method only): pitch and speed together.
    var rate: Double { didSet { defaults.set(rate, forKey: Keys.rate) } }
    var speed: Double { didSet { defaults.set(speed, forKey: Keys.speed) } }
    /// Voice-processing echo cancellation (also processes the output, so off by default).
    var echoCancel: Bool { didSet { defaults.set(echoCancel, forKey: Keys.echo) } }

    var shape: VoiceShape { VoiceShape(method: method, cents: pitchCents, rate: rate) }

    @ObservationIgnored private let defaults: UserDefaults
    private enum Keys {
        static let voice = "nutmeg.v2.voice", method = "nutmeg.v2.method", pitch = "nutmeg.v2.pitchCents"
        static let rate = "nutmeg.v2.rate", speed = "nutmeg.v2.speed", echo = "nutmeg.v2.echo"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        voice = defaults.string(forKey: Keys.voice).flatMap { Realtime.voices.contains($0) ? $0 : nil } ?? Realtime.defaultVoice
        method = defaults.string(forKey: Keys.method).flatMap(Realtime.PitchMethod.init(rawValue:)) ?? Realtime.defaultPitchMethod
        pitchCents = defaults.object(forKey: Keys.pitch) as? Double ?? Realtime.defaultPitchCents
        rate = defaults.object(forKey: Keys.rate) as? Double ?? Realtime.defaultVarispeedRate
        speed = defaults.object(forKey: Keys.speed) as? Double ?? Realtime.defaultSpeed
        echoCancel = defaults.object(forKey: Keys.echo) as? Bool ?? false
    }

    func reset() {
        voice = Realtime.defaultVoice; method = Realtime.defaultPitchMethod; pitchCents = Realtime.defaultPitchCents
        rate = Realtime.defaultVarispeedRate; speed = Realtime.defaultSpeed; echoCancel = false
    }
}
