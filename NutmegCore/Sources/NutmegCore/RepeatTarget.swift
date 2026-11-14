import Foundation

/// Round 17 (Haylee): the control pill's Repeat button ("Hear it again"). During the play step's checklist it reads the
/// checklist (`HandOffLines.repeatText`); in every other step Nutmeg says her last spoken line again, word for word.
public enum RepeatTarget: Equatable, Sendable {
    /// Nothing to repeat yet, or she's busy (speaking, a reply on the way, the kid holding the mic): dimmed.
    case none
    /// The play step's checklist: the scene title + the steps left (round 16's read-aloud).
    case checklist
    /// Her last spoken line, said again exactly.
    case lastLine(String)

    public var isAvailable: Bool { self != .none }

    /// `transcriptLast` is her latest chat bubble (live voice); `appLast` the last line the app gave her to say (the
    /// fallback when there's no chat, e.g. the device voice). Whitespace-only lines count as nothing.
    public static func choose(inChecklist: Bool, busy: Bool, transcriptLast: String?, appLast: String?) -> RepeatTarget {
        guard !busy else { return .none }
        if inChecklist { return .checklist }
        for candidate in [transcriptLast, appLast] {
            if let t = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { return .lastLine(t) }
        }
        return .none
    }

    /// Taps closer together than this are ignored (one repeat per tap, no spam).
    public static let debounce: TimeInterval = 2.5
}
