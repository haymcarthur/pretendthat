import Foundation
import Testing
@testable import NutmegCore

/// Guide prefetch (2026-11-15, Haylee: "fix it first"): the play guide is written during the hunt, each prop is woven
/// in as its card comes up, and the hunt's skips and swaps are applied with no new call. Paper never waits for it.
@MainActor struct GuidePrefetchTests {
    /// Delays one answer type (the play guide), so the hunt can end before it lands.
    final class SlowLLM: LLM, @unchecked Sendable {
        let inner: FakeLLM; let slow: String; let delay: Duration
        init(_ inner: FakeLLM, slow: String, delay: Duration) { self.inner = inner; self.slow = slow; self.delay = delay }
        func structured<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, schema: JSONSchema, effort: Effort) async throws -> T {
            if String(describing: T.self) == slow { try? await Task.sleep(for: delay) }
            return try await inner.structured(type, system: system, user: user, schema: schema, effort: effort)
        }
    }

    static let weave = PropWeave(uses: [
        .init(propID: "bowl", scene: 0, step: 0, text: "Captain, hand out snacks from the snack bowl!"),
        .init(propID: "bowl", scene: 0, step: 1, text: "Flight Attendant, fill the snack bowl!"),
        .init(propID: "pot", scene: 1, step: 1, text: "Flight Attendant, bake treats in the big oven!"),
    ])

    private func hunting(_ store: AdventureStore, title: String = "Airplane to the Beach") async {
        store.beginConversation()
        _ = await store.apply(.setGame("Airplane")); _ = await store.apply(.setTheme(title))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes(); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles([.init(roleName: "Captain", job: "fly the plane"), .init(roleName: "Flight Attendant", job: "serve snacks")]))
    }
    private func waitFor(_ cond: () -> Bool) async {
        for _ in 0..<400 where !cond() { try? await Task.sleep(for: .milliseconds(10)) }
    }
    private func guidePrompts(_ llm: FakeLLM) -> [String] { llm.users.filter { $0.contains("Phase: the play guide") } }
    private func weavePrompts(_ llm: FakeLLM) -> [String] { llm.users.filter { $0.contains("Phase: add household props") } }

    // MARK: Deterministic substitution (pure)

    @Test func skipsAndSwapsAreAppliedWithNoCall() {
        let a = Fallback.airplane
        var scenes = a.kit.scenes
        let props = [Prop(id: "pot", householdItem: "Pot", becomes: "the big oven", forRole: .all, safetyOK: true, libraryID: "pot"),
                     Prop(id: "bowl", householdItem: "Bowl", becomes: "the snack bowl", forRole: .all, safetyOK: true, libraryID: "bowl")]
        let woven = GuideWeave.apply(Self.weave, to: scenes, props: props, taken: [])
        scenes = woven.scenes
        #expect(woven.uses.count == 3)                       // bowl ×2 (cap), pot ×1
        #expect(scenes[1].steps[1].picture == .prop("pot") && scenes[0].steps[0].picture == .prop("bowl"))
        // The hunt ends: the pot was skipped.
        var final = props; final[0].skipped = true
        let items = KitDraft.finalItems(a.kit.items, props: Props(nutmegSays: "", props: final))
        let cut = items.first { $0.recipe == .cutouts }!
        let out = GuideWeave.finalize(scenes, uses: woven.uses, props: Props(nutmegSays: "", props: final), items: items)
        #expect(out[1].steps[1].text == "Flight Attendant, bake treats in the pretend big oven!")
        #expect(out[1].steps[1].picture == .kit("cutout:\(cut.lines.firstIndex(of: "big oven")!)"))
        #expect(out[0].steps[0] == scenes[0].steps[0])       // found: unchanged
        #expect(out[1].steps[1].role == a.kit.scenes[1].steps[1].role)   // same role: hand-offs and coverage unchanged
        // Never "pretend pretend"; the household item's name is replaced too.
        #expect(GuideWeave.pretend("Everyone, peek in the pretend big oven!", item: "Pot", becomes: "the big oven", label: "big oven")
                == "Everyone, peek in the pretend big oven!")
        #expect(GuideWeave.pretend("Captain, stir the pot!", item: "Pot", becomes: "the big oven", label: "big oven")
                == "Captain, stir the pretend big oven!")
        // A swap: the bowl became a cup (same use): its step shows the cup.
        var swapped = props; swapped[1].libraryID = "cup"; swapped[1].householdItem = "Cup"
        let sw = GuideWeave.finalize(scenes, uses: woven.uses, props: Props(nutmegSays: "", props: swapped), items: items)
        #expect(sw[0].steps[0].picture == .prop("cup") || sw[0].steps[0].picture == .point)
        #expect(sw[0].steps[0].text == scenes[0].steps[0].text)   // named by what it becomes: still true
        // A prop that's gone: the picture falls back, the text stays.
        let gone = GuideWeave.finalize(scenes, uses: woven.uses, props: Props(nutmegSays: "", props: [props[1]]), items: items)
        #expect(gone[1].steps[1].picture == .point)
    }

    @Test func weaveAnswersAreChecked() {
        let scenes = Fallback.airplane.kit.scenes
        let props = [Prop(id: "pot", householdItem: "Pot", becomes: "the big oven", forRole: .all, safetyOK: true, libraryID: "pot")]
        let bad = PropWeave(uses: [
            .init(propID: "pot", scene: 9, step: 0, text: "Captain, open the big oven!"),           // no such scene
            .init(propID: "lamp", scene: 0, step: 0, text: "Captain, turn on the lamp!"),           // not asked for
            .init(propID: "pot", scene: 0, step: 2, text: String(repeating: "word ", count: 20)),   // too long
            .init(propID: "pot", scene: 0, step: 3, text: "Everyone, peek in the big oven!"),       // taken
            .init(propID: "pot", scene: 2, step: 4, text: "Passenger, smell the big oven!"),        // fine
        ])
        let taken = [PropUse(propID: "bowl", scene: 0, step: 3, libraryID: "bowl", item: "Bowl", becomes: "the bowl")]
        let r = GuideWeave.apply(bad, to: scenes, props: props, taken: taken)
        #expect(r.uses.map { "\($0.scene).\($0.step)" } == ["2.4"])
        // The prompt lists only the playing roles to pick from and marks taken steps.
        let p = GuideWeave.prompt(scenes: scenes, props: props, taken: taken, roles: Fallback.airplane.plan.roles, players: 2)
        #expect(p.contains("(R1, R2)") && p.contains("s0.3 [") && p.contains("(taken)") && p.contains("becomes the big oven"))
    }

    @Test func theEarlyGuideHasAFixedShape() throws {
        let schema = KitScenesSix.schema()
        let req = (schema["required"] as? [String]) ?? []
        #expect(req == ["nutmegSays", "scene1", "scene2", "scene3", "scene4", "scene5", "scene6"])
        let scene = ((schema["$defs"] as? [String: Any])?["scene"] as? [String: Any])?["required"] as? [String]
        #expect(scene?.contains("R6") == true && scene?.contains("all2") == true)
        // No prop pictures before the props are known.
        let pic = ((schema["$defs"] as? [String: Any])?["picture"] as? [String: Any]).flatMap { ($0["properties"] as? [String: Any])?["kind"] as? [String: Any] }
        #expect((pic?["enum"] as? [String]) == ["action", "kit"])
        let one = #"{"id":"s","title":"Liftoff","picture":{"kind":"action","id":"wave"},"nutmegSays":"Pretend that we fly!","#
            + (["all1", "all2"] + RoleID.allCases.map(\.rawValue)).map { #""\#($0)":{"picture":{"kind":"action","id":"cheer"},"text":"\#($0) step"}"# }.joined(separator: ",") + "}"
        let json = #"{"nutmegSays":"Hi!","# + (1...6).map { #""scene\#($0)":"# + one }.joined(separator: ",") + "}"
        let six = try JSONDecoder().decode(KitScenesSix.self, from: Data(json.utf8))
        #expect(six.scenes.count == 6 && six.scenes.allSatisfy { $0.steps.map(\.role) == [.R1, .R2, .R3, .R4, .R5, .R6, .all, .all] })
        #expect(Validate.scenes(six.scenes, roles: 6) == nil)
    }

    // MARK: The store

    @Test func theGuideIsWrittenDuringTheHuntAndASkipMakesNoCall() async {
        let llm = FakeLLM(responses: ["PropWeave": Self.weave])
        let store = AdventureStore(service: PhaseService(llm: llm))
        await hunting(store)
        await waitFor { store.guideWrittenAt != nil }
        #expect(guidePrompts(llm).count == 1 && store.phase == .players)   // still hunting
        #expect(guidePrompts(llm)[0].contains("use NO household props"))
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the snack bowl", forRole: "all")))
        _ = await store.apply(.markFound("bowl"))
        _ = await store.apply(.showNextProp(.init(itemID: "pot", becomes: "the big oven", forRole: "all")))
        await waitFor { weavePrompts(llm).count == 2 }
        try? await Task.sleep(for: .milliseconds(50))
        let calls = llm.calls
        _ = await store.apply(.skipProp("pot"))
        _ = await store.apply(.finishPlanning)
        await waitFor { store.phase == .kitReady && !store.guidePending }
        #expect(llm.calls == calls)                                          // no regeneration on the skip
        #expect(guidePrompts(llm).count == 1 && store.guideCalls == 1)
        let steps = store.fullKit?.scenes.flatMap(\.steps) ?? []
        #expect(steps.contains { $0.text == "Flight Attendant, bake treats in the pretend big oven!" && $0.picture.kind == .kit })
        #expect(steps.contains { $0.picture == .prop("bowl") })
        // Every playing role still has its own step in every scene; the hand-offs still rotate.
        #expect(store.kit?.scenes.allSatisfy { Set($0.steps.compactMap(\.role.role)) == [.R1, .R2] } == true)
        #expect(store.kit?.scenes.map(\.owner) == [.R1, .R2, .R1, .R2, .R1, .R2])
    }

    @Test func aCorrectionRestartsTheGuide() async {
        let llm = FakeLLM(responses: ["PropWeave": Self.weave])
        let store = AdventureStore(service: PhaseService(llm: llm))
        await hunting(store)
        await waitFor { store.guideWrittenAt != nil }
        _ = await store.apply(.setTheme("Airplane to the Moon"))           // mid-hunt fix: roles cleared, guide dropped
        #expect(store.guideWrittenAt == nil && store.guideStartedAt == nil)
        _ = await store.apply(.confirmPlan)
        _ = await store.apply(.setRoles([.init(roleName: "Captain", job: ""), .init(roleName: "Moon Guide", job: "")]))
        await waitFor { store.guideWrittenAt != nil }
        #expect(guidePrompts(llm).count == 2 && guidePrompts(llm).last?.contains("Airplane to the Moon") == true)
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the snack bowl", forRole: "all")))
        _ = await store.apply(.finishPlanning)
        await waitFor { store.phase == .kitReady && !store.guidePending }
        #expect(guidePrompts(llm).count == 2 && (store.fullKit?.scenes.count ?? 0) >= 4)
    }

    @Test func paperGoesAheadAndPlayWaitsForTheGuide() async {
        let fake = FakeLLM(responses: ["PropWeave": Self.weave])
        let store = AdventureStore(service: PhaseService(llm: SlowLLM(fake, slow: "KitScenesSix", delay: .milliseconds(600))))
        await hunting(store)
        await waitFor { store.draftItems != nil }
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the snack bowl", forRole: "all")))
        _ = await store.apply(.finishPlanning)
        await waitFor { store.phase == .kitReady }
        #expect(store.guidePending && store.kit?.items.count == 6 && store.kit?.scenes.isEmpty == true)   // the pages are out
        store.beginPlay()
        #expect(store.playQueued && store.phase == .kitReady)
        #expect(await store.apply(.startPlay) == AdventureStore.playQueuedOutput)
        await waitFor { !store.guidePending }
        #expect(store.phase == .handoff(sceneIndex: 0) || store.phase == .scene(0))   // play started by itself
        #expect(!store.playQueued && (store.kit?.scenes.count ?? 0) == 6)
        #expect(store.fullKit?.scenes.flatMap(\.steps).contains { $0.picture == .prop("bowl") } == true)
    }

    @Test func theFinalTextStillPassesTheSafetyCheck() async {
        let svc = PhaseService(llm: FakeLLM())
        var scenes = Fallback.airplane.kit.scenes
        #expect(await svc.guideIsSafe(scenes))
        scenes[0].steps[0].text = "Captain, grab the real knife!"
        #expect(await svc.guideIsSafe(scenes) == false)
        // An unsafe weave answer is asked once more, then dropped (the guide keeps its own steps).
        let bad = PropWeave(uses: [.init(propID: "pot", scene: 0, step: 0, text: "Captain, wave the bloody knife!")])
        let weaving = PhaseService(llm: FakeLLM(responses: ["PropWeave": bad]))
        let props = [Prop(id: "pot", householdItem: "Pot", becomes: "the big oven", forRole: .all, safetyOK: true, libraryID: "pot")]
        await #expect(throws: ClaudeError.refusal) {
            _ = try await weaving.weaveProps(scenes: Fallback.airplane.kit.scenes, props: props, taken: [],
                                             ctx: AdventureContext(gameTitle: "Airplane", plan: Fallback.airplane.plan, playerCount: 2))
        }
    }
}
