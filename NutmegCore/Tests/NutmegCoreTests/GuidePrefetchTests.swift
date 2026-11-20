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
        .init(propID: "bowl", scene: 0, step: 2, text: "Passenger, grab a snack from the snack bowl!"),
        .init(propID: "pot", scene: 1, step: 3, text: "Passenger, peek in the cauldron!"),
    ])

    /// 2026-11-21: the weave for the one-scene guide (ONE guide scene: R1's items are 0…2, R2's 3…5).
    static let oneWeave = PropWeave(uses: [
        .init(propID: "bowl", scene: 0, step: 0, text: "Captain, hand out snacks from the snack bowl!"),
        .init(propID: "bowl", scene: 0, step: 2, text: "Captain, grab a snack from the snack bowl!"),
        .init(propID: "pot", scene: 0, step: 4, text: "Passenger, peek in the cauldron!"),
    ])

    private func hunting(_ store: AdventureStore, title: String = "Airplane to the Beach") async {
        store.beginConversation()
        _ = await store.apply(.setGame("Airplane")); _ = await store.apply(.setTheme(title))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
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
        let props = [Prop(id: "pot", householdItem: "Pot", becomes: "the cauldron", forRole: .all, safetyOK: true, libraryID: "pot"),
                     Prop(id: "bowl", householdItem: "Bowl", becomes: "the snack bowl", forRole: .all, safetyOK: true, libraryID: "bowl")]
        let woven = GuideWeave.apply(Self.weave, to: scenes, props: props, taken: [])
        scenes = woven.scenes
        #expect(woven.uses.count == 3)                       // bowl ×2 (cap), pot ×1
        #expect(scenes[1].steps[3].picture == .prop("pot") && scenes[0].steps[0].picture == .prop("bowl"))
        // The hunt ends: the pot was skipped.
        var final = props; final[0].skipped = true
        let items = KitDraft.finalItems(a.kit.items, props: Props(nutmegSays: "", props: final))
        let cut = items.first { $0.recipe == .cutouts }!
        let out = GuideWeave.finalize(scenes, uses: woven.uses, props: Props(nutmegSays: "", props: final), items: items)
        #expect(out[1].steps[3].text == "Passenger, peek in the pretend cauldron!")
        #expect(out[1].steps[3].picture == .kit("cutout:\(cut.lines.firstIndex(of: "cauldron")!)"))
        #expect(out[0].steps[0] == scenes[0].steps[0])       // found: unchanged
        #expect(out[1].steps[3].role == a.kit.scenes[1].steps[3].role)   // same role: hand-offs and coverage unchanged
        // Never "pretend pretend"; the household item's name is replaced too.
        #expect(GuideWeave.pretend("Everyone, peek in the pretend cauldron!", item: "Pot", becomes: "the cauldron", label: "cauldron")
                == "Everyone, peek in the pretend cauldron!")
        #expect(GuideWeave.pretend("Captain, stir the pot!", item: "Pot", becomes: "the cauldron", label: "cauldron")
                == "Captain, stir the pretend cauldron!")
        // A swap: the bowl became a cup (same use): its step shows the cup.
        var swapped = props; swapped[1].libraryID = "cup"; swapped[1].householdItem = "Cup"
        let sw = GuideWeave.finalize(scenes, uses: woven.uses, props: Props(nutmegSays: "", props: swapped), items: items)
        #expect(sw[0].steps[0].picture == .prop("cup") || sw[0].steps[0].picture == .point)
        #expect(sw[0].steps[0].text == scenes[0].steps[0].text)   // named by what it becomes: still true
        // A prop that's gone: the picture falls back, the text stays.
        let gone = GuideWeave.finalize(scenes, uses: woven.uses, props: Props(nutmegSays: "", props: [props[1]]), items: items)
        #expect(gone[1].steps[3].picture == .point)
    }

    @Test func weaveAnswersAreChecked() {
        let scenes = Fallback.airplane.kit.scenes
        let props = [Prop(id: "pot", householdItem: "Pot", becomes: "the cauldron", forRole: .all, safetyOK: true, libraryID: "pot")]
        let bad = PropWeave(uses: [
            .init(propID: "pot", scene: 9, step: 0, text: "Captain, open the cauldron!"),           // no such scene
            .init(propID: "lamp", scene: 0, step: 0, text: "Captain, turn on the lamp!"),           // not asked for
            .init(propID: "pot", scene: 0, step: 2, text: String(repeating: "word ", count: 60)),   // too long
            .init(propID: "pot", scene: 0, step: 3, text: "Everyone, peek in the cauldron!"),       // taken
            .init(propID: "pot", scene: 2, step: 4, text: "Passenger, smell the cauldron!"),        // fine
        ])
        let taken = [PropUse(propID: "bowl", scene: 0, step: 3, libraryID: "bowl", item: "Bowl", becomes: "the bowl")]
        let r = GuideWeave.apply(bad, to: scenes, props: props, taken: taken)
        #expect(r.uses.map { "\($0.scene).\($0.step)" } == ["2.4"])
        // The prompt lists only the playing roles to pick from and marks taken steps.
        let p = GuideWeave.prompt(scenes: scenes, props: props, taken: taken, roles: Fallback.airplane.plan.roles, players: 2)
        #expect(p.contains("(R1, R2)") && p.contains("s0.3 [") && p.contains("(taken)") && p.contains("becomes the cauldron"))
    }

    @Test func theEarlyGuideHasAFixedShape() throws {
        // Round 29 (ensemble scenes): 3 scenes, each with ONE task string per role (R1 … R6) and a solo task; no
        // pictures, no ids, no top-level line.
        let schema = KitScenesSix.schema()
        let req = (schema["required"] as? [String]) ?? []
        #expect(req.sorted() == ["cleanupScene", "pageJobs", "scene1", "scene2", "scene3", "setupScene", "story"])   // round 36: + the arc
        let def = (schema["$defs"] as? [String: Any])?["scene"] as? [String: Any]
        let scene = def?["required"] as? [String]
        #expect(Set(scene ?? []) == Set(["title", "nutmegSays", "R1", "R2", "R3", "R4", "R5", "R6", "solo"]))
        #expect(((def?["properties"] as? [String: Any])?["R3"] as? [String: Any])?["type"] as? String == "object")   // round 34: {short, say}
        let keys = RoleID.allCases.map(\.rawValue) + ["solo"]
        let one = #"{"title":"Liftoff","nutmegSays":"Pretend that we fly!","# + keys.map { #""\#($0)":"\#($0) task""# }.joined(separator: ",") + "}"
        let json = "{" + (1...3).map { #""scene\#($0)":"# + one }.joined(separator: ",") + "}"
        let three = try JSONDecoder().decode(KitScenesSix.self, from: Data(json.utf8))
        let roles = RoleID.allCases.map { SceneOwner($0) } + [.solo]
        #expect(three.scenes.count == 3 && three.scenes.allSatisfy { $0.steps.map(\.role) == roles })
        #expect(three.scenes.map(\.id) == ["s1", "s2", "s3"] && three.nutmegSays.isEmpty)
        #expect(Validate.scenes(three.scenes, roles: 6) == nil)
    }

    // MARK: The store

    @Test func theGuideIsWrittenDuringTheHuntAndASkipMakesNoCall() async {
        let llm = FakeLLM(responses: ["PropWeave": Self.oneWeave])
        let store = AdventureStore(service: PhaseService(llm: llm))
        await hunting(store)
        await waitFor { store.guideWrittenAt != nil }
        #expect(guidePrompts(llm).count == 1 && store.phase == .players)   // still hunting
        #expect(guidePrompts(llm)[0].contains("use NO household props"))
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the snack bowl", forRole: "all")))
        _ = await store.apply(.markFound("bowl"))
        _ = await store.apply(.showNextProp(.init(itemID: "pot", becomes: "the cauldron", forRole: "all")))
        await waitFor { weavePrompts(llm).count == 2 }
        try? await Task.sleep(for: .milliseconds(50))
        let calls = llm.calls
        _ = await store.apply(.skipProp("pot"))
        _ = await store.apply(.finishPlanning)
        await waitFor { store.phase == .kitReady && !store.guidePending }
        #expect(llm.calls == calls)                                          // no regeneration on the skip
        #expect(guidePrompts(llm).count == 1 && store.guideCalls == 1)
        let steps = store.fullKit?.scenes.flatMap(\.steps) ?? []
        // 2026-11-20: checklist items (the role title the weave wrote is taken off: the card shows the role).
        #expect(steps.contains { $0.short == "Peek in the pretend cauldron" && $0.picture.kind == .kit })
        #expect(steps.contains { $0.picture == .prop("bowl") })
        // Round 29: the playing roles are Captain + the customer counterpart (Passenger); every scene shows both cards.
        #expect(store.playingRoles.map(\.roleName) == ["Captain", "Passenger"])
        #expect(store.kit?.playScenes.count == 1)   // 2026-11-21: the one scene (setup and clean-up are checklists)
        #expect(store.kit?.scenes.filter(\.isChecklist).allSatisfy { Set($0.steps.map(\.role)) == [.R1, .R2] } == true)
    }

    @Test func aCorrectionRestartsTheGuide() async {
        // Round 28 (Haylee): after the yes the game and theme can't change, so a mid-hunt theme fix is refused and the
        // guide written for this game stays (no new guide call).
        let llm = FakeLLM(responses: ["PropWeave": Self.oneWeave])
        let store = AdventureStore(service: PhaseService(llm: llm))
        await hunting(store)
        await waitFor { store.guideWrittenAt != nil }
        let out = await store.apply(.setTheme("Airplane to the Moon"))
        #expect(out.contains("Refused") && out.contains("Our game stays Airplane to the Beach!"))
        #expect(store.guideWrittenAt != nil && store.gameTitle == "Airplane to the Beach" && store.plan != nil)
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the snack bowl", forRole: "all")))
        _ = await store.apply(.finishPlanning)
        await waitFor { store.phase == .kitReady && !store.guidePending }
        #expect(guidePrompts(llm).count == 1 && (store.fullKit?.scenes.count ?? 0) == 1)   // 2026-11-21: one guide scene
    }

    @Test func paperGoesAheadAndPlayWaitsForTheGuide() async {
        let fake = FakeLLM(responses: ["PropWeave": Self.oneWeave])
        let store = AdventureStore(service: PhaseService(llm: SlowLLM(fake, slow: "OneSceneGuide", delay: .milliseconds(600))))
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
        #expect(store.phase == .scene(0))   // play started by itself
        #expect(!store.playQueued && (store.kit?.playScenes.count ?? 0) == 1)   // 2026-11-21: the one scene
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
        let props = [Prop(id: "pot", householdItem: "Pot", becomes: "the cauldron", forRole: .all, safetyOK: true, libraryID: "pot")]
        await #expect(throws: ClaudeError.refusal) {
            _ = try await weaving.weaveProps(scenes: Fallback.airplane.kit.scenes, props: props, taken: [],
                                             ctx: AdventureContext(gameTitle: "Airplane", plan: Fallback.airplane.plan, playerCount: 2))
        }
    }
}
