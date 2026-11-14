import Foundation

/// Round 14 (Haylee): during play the chat panel shows tabs at the top, "Checklist" | "Chat", whenever the play step
/// has a checklist or a hand-off card. Checklist shows the full-size card; Chat shows the transcript.
public enum PTChatTab: String, CaseIterable, Sendable { case checklist, chat }

/// Which tab the panel shows. A new card (each hand-off and each scene is its own card) opens on Checklist; within one
/// card the tab stays where the kid put it.
public struct PTChatTabState: Equatable, Sendable {
    public private(set) var tab: PTChatTab = .checklist
    public private(set) var cardKey: String?
    public init() {}

    /// The play card on screen now (nil = no tabs). A different card resets to Checklist.
    public mutating func show(cardKey key: String?) {
        guard key != cardKey else { return }
        cardKey = key
        tab = .checklist
    }

    public mutating func select(_ t: PTChatTab) { tab = t }

    /// The tabbed card's key for a phase: hand-off and scene cards only (prop / kit / finale stay pinned as before).
    public static func cardKey(for phase: Phase) -> String? {
        switch phase {
        case .handoff(let i): "handoff-\(i)"
        case .scene(let i): "scene-\(i)"
        default: nil
        }
    }
}
