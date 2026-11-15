import Foundation
import Testing
@testable import NutmegCore

/// Round 21: the remote moderation runs in parallel with her reply; a late flag undoes and steers.
@MainActor
struct Round21SafetyGateTests {
    /// Answers after `delay` ms with the given verdict (a slow network round-trip).
    struct SlowModerator: Moderating {
        var flagged: Bool
        var delay: Int
        func check(_ texts: [String]) async -> ModerationResult {
            try? await Task.sleep(for: .milliseconds(delay))
            return flagged ? .flagged(categories: ["violence"]) : .clear
        }
    }

    @Test func localFilterIsInstantAndBlocksFirst() {
        let gate = SafetyGate(check: KidSafetyCheck(moderator: SlowModerator(flagged: false, delay: 500)))
        let r = gate.screen(["guns and kill people"], kind: .kidText)
        #expect(r.local != nil)
        #expect(r.ticket == nil)
        #expect(!gate.isPending)   // nothing sent to moderation: it was already blocked
    }

    @Test func screenReturnsAtOnceWhileModerationRuns() async {
        let gate = SafetyGate(check: KidSafetyCheck(moderator: SlowModerator(flagged: false, delay: 300)))
        let t0 = Date()
        let r = gate.screen(["Let's do a bakery!"], kind: .kidText)
        #expect(r.local == nil)
        #expect(r.ticket != nil)
        #expect(Date().timeIntervalSince(t0) < 0.05)   // the reply is never held by the network
        #expect(gate.isPending)
        var cleared = false
        gate.onAllClear = { cleared = true }
        #expect(await gate.cleared())
        #expect(!gate.isPending)
        for _ in 0..<10 where !cleared { await Task.yield() }
        #expect(cleared)
    }

    @Test func lateFlagFiresOnceAndClearedIsFalse() async {
        let gate = SafetyGate(check: KidSafetyCheck(moderator: SlowModerator(flagged: true, delay: 100)))
        var flags: [SafetyGate.Ticket] = []
        gate.onFlag = { _, t in flags.append(t) }
        let r = gate.screen(["something moderation flags"], kind: .toolText, pretend: true)
        #expect(r.local == nil)
        #expect(await gate.cleared() == false)   // anything waiting (Claude, kit, images) must not use it
        #expect(flags.count == 1)
        #expect(flags.first?.kind == .toolText)
        #expect(await gate.cleared())            // a later wait with nothing new pending goes ahead
    }

    @Test func noModeratorMeansLocalOnly() async {
        let gate = SafetyGate(check: KidSafetyCheck(moderator: nil))
        let r = gate.screen(["a bakery"], kind: .kidText)
        #expect(r.local == nil && r.ticket == nil)
        #expect(await gate.cleared())
    }

    @Test func onlyStateOnlyToolsRunAhead() {
        let prop = PlanningCall.PropDraft(itemID: "bowl", becomes: "mixing bowl", forRole: "Baker")
        #expect(SpeculativeTools.mayRunBeforeModeration(.setGame("Bakery"), step: .game, huntActive: false))
        #expect(SpeculativeTools.mayRunBeforeModeration(.setTheme("Moon"), step: .theme, huntActive: false))
        // A late fix can remake the kit: it waits.
        #expect(!SpeculativeTools.mayRunBeforeModeration(.setGame("Pirates"), step: .props, huntActive: true))
        #expect(SpeculativeTools.mayRunBeforeModeration(.showNextProp(prop), step: .props, huntActive: true))
        // Roles start the kit pages (Claude) and finish starts the play guide: both wait for every check.
        #expect(!SpeculativeTools.mayRunBeforeModeration(.setRoles([]), step: .roles, huntActive: false))
        #expect(!SpeculativeTools.mayRunBeforeModeration(.finishPlanning, step: .props, huntActive: true))
        #expect(SpeculativeTools.texts(.showNextProp(prop)) == ["mixing bowl"])
    }

    @Test func snapshotRestoreUndoesARanAheadTool() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        let snap = store.safeSnapshot()
        _ = await store.apply(.setGame("Bakery"))
        #expect(store.planningStep == .theme && store.gameTitle == "Bakery")
        store.restore(snap)
        #expect(store.planningStep == .game && store.gameTitle == nil)
        #expect(store.safeSnapshot() == snap)
    }

    @Test func flaggedGateKeepsTheKitPagesFromClaude() async {
        // The store asks the gate before Claude writes the kit pages; a flagged gate drops the call.
        let llm = FakeLLM()
        let store = AdventureStore(service: PhaseService(llm: llm))
        var asked = 0
        store.outboundGate = { asked += 1; return false }
        store.beginConversation()
        _ = await store.apply(.setGame("Bakery")); _ = await store.apply(.setTheme("Bakery on the Moon"))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.apply(.confirmPlan)
        _ = await store.apply(.setPrintStyle(.fullColor))
        _ = await store.apply(.setRoles([.init(roleName: "Baker", job: ""), .init(roleName: "Customer", job: "")]))
        for _ in 0..<50 where asked == 0 { try? await Task.sleep(for: .milliseconds(10)) }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(asked >= 1)
        #expect(!llm.users.contains { $0.contains("Phase: printable kit pages") })
        #expect(store.draftItems == nil)
    }

    @Test func flaggedTypedLineLeavesTheChat() {
        var chat = RealtimeTranscript()
        chat.kidTyped("hello")
        chat.kidTyped("bad words")
        chat.apply(.transcriptDone("Ooh, let's…"))
        chat.retractKid("bad words")
        #expect(chat.lines.map(\.text) == ["hello"])
        let item = Realtime.userText("hi", id: "kid_abc")
        #expect((item["item"] as? [String: Any])?["id"] as? String == "kid_abc")
    }
}
