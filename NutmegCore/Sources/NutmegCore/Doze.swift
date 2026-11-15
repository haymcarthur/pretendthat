import Foundation

/// Sleepy Nutmeg (round 9, Haylee): when nobody answers during the conversation steps (game, theme, how many, prop
/// hunt), after the ONE silence reminder has finished playing plus `afterReminder` more seconds of quiet, she sits
/// down (eyes open), then her eyes droop (slow heavy blinks), then she falls asleep (nap face, slow deep breathing).
/// No text. The mic or typing wakes her (`wake()`), and the clock waits for the next reminder.
/// Pure state on wall-clock times, unit-tested (DozeTests); `AppModel` feeds it and maps the stage to her look.
public struct DozeClock: Equatable, Sendable {
    public enum Stage: Int, Comparable, Sendable {
        case awake, sitting, drowsy, asleep
        public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    /// Quiet after the reminder finished before she sits down.
    public static let afterReminder: TimeInterval = 30
    /// Sitting with her eyes open, then drooping, before she's asleep.
    public static let sittingFor: TimeInterval = 3
    public static let drowsyFor: TimeInterval = 4.5

    /// When the silence reminder finished playing (nil: no reminder yet for this question, or she was woken).
    public private(set) var quietSince: Date?
    /// Scales the wait after the reminder for DEBUG runs (1 = the real 30 s; the sit and droop beats never scale).
    public var scale: Double

    public init(scale: Double = 1) { self.scale = scale }

    /// The one "Hold the red button whenever you're ready!" reminder has finished playing.
    public mutating func reminderFinished(at date: Date) { quietSince = date }

    /// The kid pressed the mic or typed: she's awake, and stays awake until the next reminder.
    public mutating func wake() { quietSince = nil }

    /// Where she is at `now`. `eligible` is false outside the conversation steps, during the writing moment, kit making,
    /// print and play, and whenever she or the kid is talking: then she's always awake.
    public func stage(at now: Date, eligible: Bool) -> Stage {
        guard eligible, let since = quietSince else { return .awake }
        let t = now.timeIntervalSince(since), wait = Self.afterReminder * scale
        if t < wait { return .awake }
        if t < wait + Self.sittingFor { return .sitting }
        if t < wait + Self.sittingFor + Self.drowsyFor { return .drowsy }
        return .asleep
    }

    /// Only these planning steps can get sleepy (not roles = the writing moment, not finish = kit making).
    public static func sleepyStep(_ step: PlanningStep) -> Bool {
        switch step { case .game, .theme, .players, .confirm, .props: true; case .roles, .finish: false }
    }

    /// The silent note before the kid's turn when she was woken from drowsy/asleep: a tiny wake-up line is OK, then she
    /// carries on where she left off (no greeting, no repeated question).
    public static let wakeNote = "(Silent coaching, don't mention it.) You had dozed off waiting, and the kid just woke "
        + "you up. You may start with a tiny \"Oh! I'm awake!\", then answer them and carry on exactly where you left off. "
        + "Don't greet them again and don't repeat your whole question."
}
