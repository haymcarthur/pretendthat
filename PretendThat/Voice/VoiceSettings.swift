import Foundation
import Observation
import NutmegCore

/// Grown-ups tuning for Nutmeg's Realtime voice (D7). Device settings only; nothing about kids is stored.
@Observable @MainActor
final class VoiceSettings {
    var voice: String { didSet { defaults.set(voice, forKey: Keys.voice) } }
    /// AVAudioUnitTimePitch cents (+350 ≈ a bit more than a minor third up: squeaky mouse).
    var pitchCents: Double { didSet { defaults.set(pitchCents, forKey: Keys.pitch) } }
    var speed: Double { didSet { defaults.set(speed, forKey: Keys.speed) } }

    @ObservationIgnored private let defaults: UserDefaults
    private enum Keys { static let voice = "nutmeg.voice", pitch = "nutmeg.pitchCents", speed = "nutmeg.speed" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        voice = defaults.string(forKey: Keys.voice).flatMap { Realtime.voices.contains($0) ? $0 : nil } ?? Realtime.defaultVoice
        pitchCents = defaults.object(forKey: Keys.pitch) as? Double ?? Realtime.defaultPitchCents
        speed = defaults.object(forKey: Keys.speed) as? Double ?? Realtime.defaultSpeed
    }

    func reset() { voice = Realtime.defaultVoice; pitchCents = Realtime.defaultPitchCents; speed = Realtime.defaultSpeed }
}
