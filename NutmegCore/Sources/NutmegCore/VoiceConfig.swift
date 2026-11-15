import Foundation

/// Round 13: everything that decides how Nutmeg sounds, built in ONE place for every connect (first connect,
/// pre-connect, silent reconnect). The connect path takes only this, so a reconnect can't pick a
/// different voice, pitch method, rate or server speed.
public struct VoiceConfig: Equatable, Sendable, CustomStringConvertible {
    public var voice: String
    public var method: Realtime.PitchMethod
    public var rate: Double
    public var cents: Double
    public var requestedSpeed: Double

    public init(voice: String = Realtime.defaultVoice, method: Realtime.PitchMethod = Realtime.defaultPitchMethod,
                rate: Double = Realtime.defaultVarispeedRate, cents: Double = Realtime.defaultPitchCents,
                requestedSpeed: Double = Realtime.defaultSpeed) {
        self.voice = Realtime.voices.contains(voice) ? voice : Realtime.defaultVoice
        self.method = method; self.rate = rate; self.cents = cents; self.requestedSpeed = requestedSpeed
    }

    /// Round 20 (Haylee): Nutmeg's one fixed voice (the Grown-ups settings were removed): coral, Varispeed 1.20.
    public static let nutmeg = VoiceConfig()

    /// Server speed: forced to 1.0 under Varispeed so the two never stack.
    public var apiSpeed: Double { Realtime.apiSpeed(method: method, requested: requestedSpeed) }
    /// The on-device playback rate of her audio.
    public var playbackRate: Double { method == .varispeed ? rate : 1 }

    public func sessionUpdate(instructions: String) -> [String: Any] {
        Realtime.sessionUpdate(voice: voice, speed: apiSpeed, instructions: instructions)
    }

    public var description: String {
        "voice \(voice), method \(method.rawValue), rate \(rate), cents \(cents), api speed \(apiSpeed)"
    }
}
