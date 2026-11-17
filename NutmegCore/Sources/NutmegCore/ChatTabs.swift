import Foundation

/// Round 14 (Haylee): the chat panel shows tabs at the top, "<step>" | "Chat". Round 30: every step that has
/// something to show gets its own step tab (Props, Print, Scene, and the cover on a replay's Pick); Chat shows the
/// transcript.
public enum PTChatTab: String, CaseIterable, Sendable { case step, chat }

/// Round 30 (Haylee): what the panel's step tab shows on this step.
public enum PTStepTab: String, CaseIterable, Sendable {
    /// The hunt's props as a live list (current one with ✓ / ✗, found ones checked, missing ones pretend).
    case props
    /// The full print panel: both sets, the selection, the pages, the printer and the ▶.
    case print
    /// The round 29 scene card (a row per role, 🔊, Next scene).
    case scene
    /// A saved game's cover on a replay's Pick (a first play's Pick is Chat only).
    case cover

    /// Which step tab this moment has (nil = Chat only). `propsShown`: hunt cards on screen; `papersOut`: the kit
    /// papers have landed (the print panel has something to show).
    public static func forPhase(_ phase: Phase, replay: Bool, propsShown: Int, papersOut: Bool) -> PTStepTab? {
        switch phase {
        case .players where replay: .cover
        case .props where propsShown > 0: .props
        case .makingKit, .kitReady: papersOut ? .print : nil
        case .scene: .scene
        default: nil
        }
    }
}

/// Which tab the panel shows. Opening the panel, and each new step card (a new step, or the next scene), go to the
/// step tab; within one card the tab stays where the kid put it.
public struct PTChatTabState: Equatable, Sendable {
    public private(set) var tab: PTChatTab = .step
    public private(set) var cardKey: String?
    public init() {}

    /// The step card on screen now (nil = no tabs). A different card resets to the step tab.
    public mutating func show(cardKey key: String?) {
        guard key != cardKey else { return }
        cardKey = key
        tab = .step
    }

    /// Round 30: the panel just opened: it always starts on the step tab (the transcript is one tap away).
    public mutating func panelOpened() { tab = .step }

    public mutating func select(_ t: PTChatTab) { tab = t }

    /// The tabbed card's key: one per step tab, and one per scene (the next scene starts on its card again).
    public static func cardKey(for tab: PTStepTab?, phase: Phase) -> String? {
        guard let tab else { return nil }
        if case .scene(let i) = phase, tab == .scene { return "scene-\(i)" }
        return tab.rawValue
    }

    /// Round 14 / 29 shape (scene cards only), kept for callers that only know the phase.
    public static func cardKey(for phase: Phase) -> String? {
        switch phase {
        case .scene(let i): "scene-\(i)"
        default: nil
        }
    }
}
