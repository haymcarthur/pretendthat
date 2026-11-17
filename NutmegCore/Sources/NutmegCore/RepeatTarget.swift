import Foundation

/// Round 17 (Haylee): the control pill's Repeat button ("Hear it again"). During a play scene it re-reads the whole scene
/// (round 29: the setup and every playing role's task, `HandOffLines.sceneOpen`); in every other step Nutmeg says her
/// last spoken line again, word for word.
public enum RepeatTarget: Equatable, Sendable {
    /// Nothing to repeat yet, or she's busy (speaking, a reply on the way, the kid holding the mic): dimmed.
    case none
    /// A play scene: the setup + every playing role's task (round 29).
    case scene
    /// Her last spoken line, said again exactly.
    case lastLine(String)

    public var isAvailable: Bool { self != .none }

    /// `transcriptLast` is her latest chat bubble (live voice); `appLast` the last line the app gave her to say (the
    /// fallback when there's no chat, e.g. the device voice). Whitespace-only lines count as nothing.
    public static func choose(inScene: Bool, busy: Bool, transcriptLast: String?, appLast: String?) -> RepeatTarget {
        guard !busy else { return .none }
        if inScene { return .scene }
        for candidate in [transcriptLast, appLast] {
            if let t = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { return .lastLine(t) }
        }
        return .none
    }

    /// Taps closer together than this are ignored (one repeat per tap, no spam).
    public static let debounce: TimeInterval = 2.5
}
