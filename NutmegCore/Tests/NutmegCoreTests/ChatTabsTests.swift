import Testing
@testable import NutmegCore

/// Round 14: step | Chat tabs in the chat panel. Round 30: a step tab on Props, Print, Play (and a replay's Pick).
struct ChatTabsTests {
    @Test func defaultsToTheStepTabAndResetsOnEachNewScene() {
        var s = PTChatTabState()
        #expect(s.tab == .step)
        s.show(cardKey: PTChatTabState.cardKey(for: .scene(0)))
        #expect(s.tab == .step)
        s.select(.chat)
        s.show(cardKey: PTChatTabState.cardKey(for: .scene(0)))   // same scene: stays where the kid put it
        #expect(s.tab == .chat)
        s.show(cardKey: PTChatTabState.cardKey(for: .scene(1)))   // the next scene: back to the scene card
        #expect(s.tab == .step)
    }

    @Test func openingThePanelGoesToTheStepTab() {
        var s = PTChatTabState()
        s.show(cardKey: "props")
        s.select(.chat)
        s.show(cardKey: "props")   // the next prop: the same Props tab, still on Chat
        #expect(s.tab == .chat)
        s.panelOpened()
        #expect(s.tab == .step)
    }

    @Test func eachStepHasItsTab() {
        #expect(PTStepTab.forPhase(.pickGame, replay: false, propsShown: 0, papersOut: false) == nil)   // Chat only
        #expect(PTStepTab.forPhase(.players, replay: false, propsShown: 0, papersOut: false) == nil)
        #expect(PTStepTab.forPhase(.players, replay: true, propsShown: 0, papersOut: false) == .cover)
        #expect(PTStepTab.forPhase(.props, replay: false, propsShown: 0, papersOut: false) == nil)   // no card yet
        #expect(PTStepTab.forPhase(.props, replay: false, propsShown: 2, papersOut: false) == .props)
        #expect(PTStepTab.forPhase(.props, replay: true, propsShown: 1, papersOut: false) == .props)
        #expect(PTStepTab.forPhase(.makingKit, replay: false, propsShown: 4, papersOut: false) == nil)   // still drawing
        #expect(PTStepTab.forPhase(.kitReady, replay: false, propsShown: 4, papersOut: true) == .print)
        #expect(PTStepTab.forPhase(.scene(1), replay: false, propsShown: 4, papersOut: false) == .scene)
        #expect(PTStepTab.forPhase(.end, replay: false, propsShown: 4, papersOut: false) == nil)
        #expect(PTStepTab.forPhase(.hello, replay: false, propsShown: 0, papersOut: false) == nil)
    }

    @Test func cardKeys() {
        #expect(PTChatTabState.cardKey(for: .scene, phase: .scene(2)) == "scene-2")
        #expect(PTChatTabState.cardKey(for: .props, phase: .props) == "props")
        #expect(PTChatTabState.cardKey(for: .print, phase: .kitReady) == "print")
        #expect(PTChatTabState.cardKey(for: nil, phase: .pickGame) == nil)
        #expect(PTChatTabState.cardKey(for: .scene(2)) == "scene-2")
        for p: Phase in [.hello, .pickGame, .props, .makingKit, .kitReady, .end] { #expect(PTChatTabState.cardKey(for: p) == nil) }
    }
}
