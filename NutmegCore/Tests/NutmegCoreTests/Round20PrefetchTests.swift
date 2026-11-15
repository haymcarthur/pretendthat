import Foundation
import Testing
@testable import NutmegCore

/// Round 20 (Haylee): the kit is made during the prop hunt. The pages start as soon as the color and the roles are set;
/// the play guide and the skipped props' cut-outs wait for the hunt's end; a correction restarts the dependent work.
@MainActor struct Round20PrefetchTests {
    private func hunting(_ store: AdventureStore, style: PrintStyle? = .fullColor, kids: Int = 2) async {
        store.beginConversation()
        _ = await store.apply(.setGame("Bakery")); _ = await store.apply(.setTheme("Bakery on the Moon"))
        _ = await store.apply(.setPlayerCount(kids)); _ = await store.apply(.confirmPlan)
        if let style { _ = await store.apply(.setPrintStyle(style)) }
        _ = await store.apply(.setRoles((0..<kids).map { .init(roleName: ["Baker", "Customer", "Cashier"][$0 % 3], job: "") }))
    }
    private func waitFor(_ cond: () -> Bool) async {
        for _ in 0..<300 where !cond() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func pagesStartAtTheRolesAndTheGuideWaitsForTheHuntsEnd() async {
        let llm = FakeLLM()
        let store = AdventureStore(service: PhaseService(llm: llm))
        await hunting(store)
        #expect(store.planningStep == .props && store.draftStartedAt != nil)
        await waitFor { store.draftItems != nil }
        #expect(store.draftItems?.count == 6 && store.phase == .players)          // still hunting: nothing else changed
        #expect(llm.users.filter { $0.contains("Phase: printable kit pages") }.count == 1)
        #expect(!llm.users.contains { $0.contains("Phase: the play guide") })
        // The hunt: one found, one skipped (no Claude calls for those).
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the mixing bowl", forRole: "all")))
        _ = await store.apply(.markFound("bowl"))
        _ = await store.apply(.showNextProp(.init(itemID: "pot", becomes: "the big oven", forRole: "all")))
        _ = await store.apply(.skipProp("pot"))
        let calls = llm.calls
        #expect(store.draftItems != nil)                                         // the hunt never restarts the pages
        _ = await store.apply(.finishPlanning)
        await waitFor { store.phase == .kitReady }
        #expect(llm.calls == calls + 1)                                          // only the play guide
        let guide = llm.users.last ?? ""
        #expect(guide.contains("Phase: the play guide") && guide.contains("big oven") && guide.contains("skipped"))
        let cut = store.kit?.items.first { $0.recipe == .cutouts }
        #expect(cut?.lines.count == 7 && cut?.lines.last == "big oven")            // the skipped prop's cut-out, appended
        #expect(store.kit?.items.map(\.id) == store.draftItems?.map(\.id))        // same pages: their art carries over
        #expect((store.kit?.scenes.count ?? 0) >= 4)
    }

    @Test func noPagesBeforeTheColorOrWithoutClaude() async {
        let store = AdventureStore(service: PhaseService(llm: FakeLLM()))
        store.beginConversation()
        _ = await store.apply(.setGame("Bakery")); _ = await store.apply(.setPlayerCount(2)); _ = await store.apply(.confirmPlan)
        #expect(store.planningStep == .color && store.draftStartedAt == nil)
        let offline = AdventureStore(service: nil)
        await hunting(offline)
        #expect(offline.draftStartedAt == nil && offline.wantedDraft == nil)
        #expect(KitDraft.inputs(title: "X", playerCount: 2, plan: Fallback.airplane.plan, printStyle: nil, step: .props) == nil)
        #expect(KitDraft.inputs(title: "X", playerCount: 2, plan: nil, printStyle: .colorIn, step: .props) == nil)
        #expect(KitDraft.inputs(title: "X", playerCount: 2, plan: Fallback.airplane.plan, printStyle: .colorIn, step: .props) != nil)
    }

    @Test func aCorrectionCancelsAndNewRolesRestartButTheColorDoesNot() async {
        let llm = FakeLLM()
        let store = AdventureStore(service: PhaseService(llm: llm))
        await hunting(store)
        await waitFor { store.draftItems != nil }
        let gen = store.draftGeneration
        // The color only changes the art (the app redraws it): the pages' text stays.
        _ = await store.apply(.setPrintStyle(.colorIn))
        #expect(store.draftGeneration == gen && store.draftItems != nil)
        // A theme fix mid-hunt: the roles are cleared, so the pages for them are dropped.
        _ = await store.apply(.setTheme("Bakery Under the Sea"))
        #expect(store.draftItems == nil && store.draftGeneration > gen && store.draftStartedAt == nil)
        _ = await store.apply(.confirmPlan)                                       // the color is kept: straight to roles
        _ = await store.apply(.setRoles([.init(roleName: "Baker", job: ""), .init(roleName: "Diver", job: "")]))
        await waitFor { store.draftItems != nil }
        #expect(store.draftItems != nil)
        let pages = llm.users.filter { $0.contains("Phase: printable kit pages") }
        #expect(pages.count == 2 && pages.last?.contains("Bakery Under the Sea") == true)
        // A new game drops everything.
        store.newGame()
        #expect(store.draftItems == nil && store.draftStartedAt == nil)
    }

    @Test func pagesThatFailTwiceFallBackToTheOneCallKit() async {
        let llm = FakeLLM(failures: 2)                     // the pages call and its one retry both fail
        let store = AdventureStore(service: PhaseService(llm: llm))
        await hunting(store)
        await waitFor { llm.calls >= 2 }
        try? await Task.sleep(for: .milliseconds(1200))
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the mixing bowl", forRole: "all")))
        _ = await store.apply(.finishPlanning)
        await waitFor { store.phase == .kitReady }
        #expect(store.draftItems == nil && store.kit != nil)
        #expect(llm.users.last?.contains("Phase: printable kit and scenes") == true)   // the whole kit, as before
    }

    @Test func artJobsDuringTheHuntAndAfterIt() {
        let draft = Fallback.airplane.kit.items
        let hunt = KitArtPlan.jobs(items: draft, title: "Sky", style: .fullColor, settled: [])
        #expect(hunt.count == 11)                                                // 5 pages + 6 themed cut-outs
        #expect(hunt.contains { $0.key == "cutouts#0" } && hunt.contains { $0.key == "badge" })
        #expect(hunt.allSatisfy { $0.prompt.contains("Full-color") && $0.prompt.hasSuffix(ImageSafety.suffix) })
        // Hunt over with one skip: only the skipped prop's cut-out is new.
        let props = Props(nutmegSays: "", props: [Prop(id: "pot", householdItem: "Pot", becomes: "the big oven", forRole: .all, safetyOK: true, skipped: true),
                                                   Prop(id: "bowl", householdItem: "Bowl", becomes: "the mixing bowl", forRole: .all, safetyOK: true)])
        let final = KitDraft.finalItems(draft, props: props)
        let after = KitArtPlan.jobs(items: final, title: "Sky", style: .fullColor, settled: Set(hunt.map(\.key)))
        #expect(after.map(\.key) == ["cutouts#6"] && after[0].prompt.contains("big oven"))
        #expect(KitArtPlan.keys(items: final).count == 12)
        // Labels and limits.
        #expect(KitDraft.cutoutLabel(becomes: "The steering wheel.") == "steering wheel")
        #expect(KitDraft.cutoutLabel(becomes: "a pirate map") == "pirate map")
        #expect(KitDraft.finalItems(draft, props: nil) == draft)
        var eight = draft; eight[5].lines = (1...8).map { "thing \($0)" }
        let three = (1...3).map { Prop(id: "p\($0)", householdItem: "Pot", becomes: "skip \($0)", forRole: .all, safetyOK: true, skipped: true) }
        let capped = KitDraft.finalItems(eight, props: Props(nutmegSays: "", props: three))[5].lines
        #expect(capped.count == PictureResolver.maxCutouts && capped.suffix(2) == ["skip 1", "skip 2"] && capped[0] == "thing 1")
    }

    @Test func progressOnlyMentionsWhatIsStillInProgress() {
        #expect(KitProgress.inProgress(pagesWritten: false, scenesWritten: false, pendingPages: []) == KitProgress.Topic.allCases)
        #expect(KitProgress.inProgress(pagesWritten: true, scenesWritten: false, pendingPages: []) == [.checklists])
        #expect(KitProgress.inProgress(pagesWritten: true, scenesWritten: true, pendingPages: [.cutouts]) == [.cutouts])
        #expect(KitProgress.inProgress(pagesWritten: true, scenesWritten: true, pendingPages: []).isEmpty)
    }

    @Test func limiterCapsConcurrencyAtThree() async {
        let limiter = AsyncLimiter(limit: 3)
        actor Counter { var now = 0, peak = 0; func enter() { now += 1; peak = max(peak, now) }; func leave() { now -= 1 } }
        let c = Counter()
        await withTaskGroup(of: Void.self) { g in
            for _ in 0..<10 {
                g.addTask { await limiter.run { await c.enter(); try? await Task.sleep(for: .milliseconds(20)); await c.leave() } }
            }
        }
        #expect(await c.peak == 3)
        #expect(await limiter.peak <= 3)
    }

    @Test func retryOnceThenGiveUp() async throws {
        final class Box: @unchecked Sendable { var n = 0 }
        let once = Box()
        let v = try await RetryOnce.run(delay: .milliseconds(1)) { once.n += 1; if once.n == 1 { throw ClaudeError.transport }; return 7 }
        #expect(v == 7 && once.n == 2)
        let always = Box()
        await #expect(throws: ClaudeError.self) {
            try await RetryOnce.run(delay: .milliseconds(1)) { always.n += 1; throw ClaudeError.transport }
        }
        #expect(always.n == 2)
    }
}
