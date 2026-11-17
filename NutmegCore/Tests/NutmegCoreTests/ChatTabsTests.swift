import Testing
@testable import NutmegCore

/// Round 14: Checklist | Chat tabs in the chat panel during play.
struct ChatTabsTests {
    @Test func defaultsToChecklistAndResetsOnEachNewScene() {
        var s = PTChatTabState()
        #expect(s.tab == .checklist)
        s.show(cardKey: PTChatTabState.cardKey(for: .scene(0)))
        #expect(s.tab == .checklist)
        s.select(.chat)
        s.show(cardKey: PTChatTabState.cardKey(for: .scene(0)))   // same scene: stays where the kid put it
        #expect(s.tab == .chat)
        s.show(cardKey: PTChatTabState.cardKey(for: .scene(1)))   // the next scene: back to the scene card
        #expect(s.tab == .checklist)
    }

    @Test func onlySceneIsTabbed() {
        #expect(PTChatTabState.cardKey(for: .scene(2)) == "scene-2")
        for p: Phase in [.hello, .pickGame, .props, .makingKit, .kitReady, .end] { #expect(PTChatTabState.cardKey(for: p) == nil) }
    }
}
