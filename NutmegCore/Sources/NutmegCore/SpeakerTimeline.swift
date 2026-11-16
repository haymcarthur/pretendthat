import Foundation

/// Round D3a: the pure bookkeeping of Nutmeg's speaker (`NutmegSpeaker` in the app), moved out of `RealtimeSession`
/// unchanged so it can be unit-tested and so a recorded clip (D3b) can go through exactly the same rules as live audio.
///
/// - **Speaking state:** she starts speaking with the first scheduled buffer. `speakingUntil` is kept from the clock
///   (not completion callbacks: an engine reconfiguration can drop scheduled buffers without calling them back): each
///   buffer adds its length divided by the playback rate (Varispeed 1.20 plays faster). She stops speaking when an end
///   check `endTail` after the last audio finds the clock `doneSlack` past it (the short tail lets room echo die before
///   anything reacts).
/// - **Placement (lip sync):** each buffer starts where the last one ended (or where the player is now, if that's later),
///   and the moment its first sample is heard is the player's host time plus the source-sample distance divided by the
///   rate, plus the output latency.
/// - **Barge-in:** what was heard of an item = the player's position (capped at what was scheduled) minus the item's
///   start. `clear()` is the stop: not speaking, the clock reset, the schedule back to 0 (the player restarts at 0).
public struct SpeakerTimeline: Equatable, Sendable {
    /// The end check runs this long after the scheduled audio ends.
    public static let endTail: TimeInterval = 0.45
    /// ...and only finishes her line once the clock is this far past it (a later buffer pushes it out).
    public static let doneSlack: TimeInterval = 0.4
    /// The shortest end-check wait.
    public static let minEndWait: TimeInterval = 0.05

    public let sampleRate: Double
    /// How fast the queued audio plays (Varispeed's rate, else 1).
    public var playbackRate: Double
    public private(set) var isSpeaking = false
    public private(set) var speakingUntil = Date.distantPast
    /// End of the scheduled audio, in player (source) samples.
    public private(set) var scheduledEnd: Double = 0

    public init(sampleRate: Double = Realtime.sampleRate, playbackRate: Double = 1) {
        self.sampleRate = sampleRate
        self.playbackRate = playbackRate
    }

    /// A buffer of `frames` source samples is about to be scheduled. Returns true when this starts her speaking.
    @discardableResult
    public mutating func willSchedule(frames: Int, now: Date = Date()) -> Bool {
        let started = !isSpeaking
        isSpeaking = true
        speakingUntil = max(now, speakingUntil).addingTimeInterval(Double(frames) / sampleRate / playbackRate)
        return started
    }

    /// Places a buffer of `frames` on the player's timeline and returns the host time (seconds) its first sample is
    /// heard. `player` is the player's current (sample, host time) when it is rendering, else nil (`hostNow` is used).
    public mutating func place(frames: Int, player: (sample: Double, hostTime: Double)?, hostNow: Double,
                               latency: Double) -> Double {
        let nowSample = player?.sample ?? scheduledEnd
        let nowTime = player?.hostTime ?? hostNow
        let start = max(scheduledEnd, nowSample)
        scheduledEnd = start + Double(frames)
        return nowTime + (start - nowSample) / sampleRate / playbackRate + latency
    }

    /// How long the end check waits from `now`.
    public func endCheckDelay(now: Date = Date()) -> TimeInterval {
        max(Self.minEndWait, speakingUntil.timeIntervalSince(now) + Self.endTail)
    }

    /// The end check: true when her audio has really ended (no later buffer pushed the clock out).
    public func hasFinished(now: Date = Date()) -> Bool { now >= speakingUntil.addingTimeInterval(Self.doneSlack) }

    /// Her line ended normally (the schedule is kept: the player keeps counting from where it is).
    public mutating func finish() { isSpeaking = false }

    /// Barge-in / stop: she stops at once and the player starts again from sample 0.
    public mutating func clear() {
        isSpeaking = false
        speakingUntil = .distantPast
        scheduledEnd = 0
    }

    /// Where a new conversation item's audio starts (player samples): after what's queued, or where the player is now.
    public func itemStart(playerSample: Double?) -> Double { max(scheduledEnd, playerSample ?? scheduledEnd) }

    /// How much of an item starting at `itemStart` was heard, in ms (the truncate point after a barge-in).
    public func heardMs(itemStart: Double, playerSample: Double?) -> Int {
        let heard = playerSample ?? itemStart
        return Int(max(0, min(heard, scheduledEnd) - itemStart) / sampleRate * 1000)
    }
}

/// Round D3a: the speaker's memory of the last app line she was given to say (round 17's Repeat fallback when there's
/// no chat transcript, e.g. the device voice). Whitespace-only lines are not remembered.
public struct LastLineMemory: Equatable, Sendable {
    public private(set) var line: String?
    public init() {}
    public mutating func remember(_ text: String) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { line = text }
    }
}

/// Round D3a seam for D3b (not used yet): where a line she says comes from. Live = the Realtime session's `sayExactly`;
/// clip = a recorded clip of the same line, played through the same speaker (same Varispeed, lip sync and barge-in).
public enum SpeechSource: Equatable, Sendable {
    case live
    case clip(key: String)

    /// D3b (D4.4): the line is played from a clip when the game has one for it, else said live (and recorded).
    public static func choose(clipKey: String?) -> SpeechSource { clipKey.map { .clip(key: $0) } ?? .live }
}
