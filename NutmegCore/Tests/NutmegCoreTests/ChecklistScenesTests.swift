import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-20 (Haylee, decisions/2026-11-20-checklist-then-scenario-scenes.md): scenes are checklists, then a short
/// scenario. 4 scenes written in the one guide call, shown by player count; every page and prop in an item the kids
/// see at every count; a clean-up checklist; checks, ◀ Previous, the reading queue, skip and resume.
@MainActor
struct ChecklistScenesTests {
    let a = Fallback.checklistAirplane(playerCount: 6)
    var roles: [Role] { a.plan.roles }
    var props: [Prop] { a.props.props }

    /// The checklist airplane kit, repaired the way the store repairs every guide.
    func kit(props: [Prop]? = nil) -> Kit {
        var k = a.kit
        k.scenes = GuideRepair.repair(k.scenes, roles: roles, props: props ?? self.props, title: "Airplane", items: k.items)
        return Bookends.repair(k, props: props ?? self.props, roles: roles, title: "Airplane").kit
    }

    /// A store on the bundled (checklist) game, at its first checklist scene.
    func storeAtChecklist(players: Int = 2) async -> AdventureStore {
        let store = AdventureStore(service: nil)
        await store.start()
        await store.chooseGame("Airplane")
        store.setPlayerCount(players)
        await store.confirmPlayers()
        await store.confirmRoles()
        await store.confirmProps()
        store.beginPlay()
        if store.inStory { store.nextScene() }
        return store
    }

    // MARK: Scenes by count

    @Test func scenesByPlayerCountKeepTheFirstAndTheLast() {
        #expect(ChecklistScenes.visible(players: 1) == [0, 1, 2, 3])
        #expect(ChecklistScenes.visible(players: 2) == [0, 1, 2, 3])
        #expect(ChecklistScenes.visible(players: 3) == [0, 1, 3])
        #expect(ChecklistScenes.visible(players: 4) == [0, 1, 3])
        #expect(ChecklistScenes.visible(players: 5) == [0, 3])
        #expect(ChecklistScenes.visible(players: 6) == [0, 3])
        #expect(ChecklistScenes.visible(players: 9) == [0, 3])   // capped at 6
        #expect(ChecklistScenes.visible(players: 3, total: 2) == [0, 1])
        #expect(ChecklistScenes.visible(players: 1, total: 0).isEmpty)
        for n in 1...6 {
            let k = PlayCast.kit(kit(), roles: roles, players: n, props: props)
            #expect(k.playScenes.count == ChecklistScenes.sceneCount(players: n))
            #expect(k.scenes.first?.arc == .story && k.scenes.last?.arc == .cleanup)
            // Only the playing roles show (a card each, rank order).
            for sc in k.scenes where sc.isChecklist {
                #expect(ChecklistScenes.cards(sc).map(\.role) == Array(RoleID.allCases.prefix(n)))
            }
        }
    }

    // MARK: The guide call

    @Test func theGuideAnswerDecodesIntoChecklistScenes() throws {
        let sc = #"{"title":"Get the Rocket Ready","scenario":"Pretend that the rocket is ready... uh-oh, the panel is beeping! Everyone, do your job to blast off!","R1":["Put on your badge","Set up the control panel"],"R2":["Put on your badge","Hang the sign","Count the money"],"R3":["Put on your badge"],"R4":[],"R5":["Put on your badge","Wave"],"R6":["Put on your badge","Line up"]}"#
        let json = #"{"scene1":\#(sc),"scene2":\#(sc),"scene3":\#(sc),"scene4":\#(sc),"story":"Welcome aboard the rocket! You are the crew. Let's fly to the moon!","cleanupTitle":"Back on Earth"}"#
        let g = try JSONDecoder().decode(KitScenesSix.self, from: Data(json.utf8))
        #expect(g.scenes.count == 4 && g.scenes.map(\.id) == ["s1", "s2", "s3", "s4"] && g.scenes.allSatisfy(\.isChecklist))
        #expect(g.scenes[0].steps.filter { $0.role == .R2 }.compactMap(\.short) == ["Put on your badge", "Hang the sign", "Count the money"])
        #expect(g.scenes[0].nutmegSays.hasPrefix("Pretend that") && g.setup == nil && g.cleanup?.title == "Back on Earth")
        #expect(Validate.scenes(g.scenes, roles: 6)?.fatal != true)
        // The schema: 4 scenes, the story, the clean-up title; no setup scene, no goals, no page jobs, no spoken texts.
        let schema = KitScenesSix.checklistSchema()
        #expect((schema["required"] as? [String])?.sorted() == ["cleanupTitle", "scene1", "scene2", "scene3", "scene4", "story"])
        let def = (schema["$defs"] as? [String: Any])?["scene"] as? [String: Any]
        #expect((def?["required"] as? [String])?.sorted() == ["R1", "R2", "R3", "R4", "R5", "R6", "scenario", "title"])
        // The prompt asks for the shape and the rules (no props yet, every page used, the everyone action).
        let p = Prompts.checklistScenes(ctx: AdventureContext(gameTitle: "Rocket", playerCount: 2), items: a.kit.items)
        #expect(p.contains("Phase: the play guide") && p.contains("still hunting") && p.contains("use NO household props"))
        #expect(p.contains("2 or 3 SHORT items") && p.contains("ALWAYS ends with an action for everyone") && p.contains("Put on your badge"))
        #expect(!p.contains("setupScene") && !p.contains("goals"))
    }

    @Test func theRepairMakesEveryGuideUsableAndIsIdempotent() {
        var bad = a.kit.scenes
        bad[0].title = "x"
        bad[0].nutmegSays = "The rocket is beeping"              // no "Pretend that", no everyone action
        bad[0].steps.removeAll { $0.role == .R4 }                  // a role with no items
        bad[0].steps.append(Step(picture: .point, text: "Captain, check the \"big\" map, then wave to the crew and count to ten slowly.", role: .R1))
        bad[1].steps.append(contentsOf: (1...3).map { Step(picture: .point, text: "Extra \($0)", role: .R2, short: "Extra \($0)") })
        bad.removeLast()                                            // only 3 scenes
        let fixed = ChecklistScenes.repair(bad, roles: roles, props: props, title: "Airplane", items: a.kit.items)
        #expect(fixed.count == 4 && fixed.allSatisfy(\.isChecklist) && Set(fixed.map(\.id)).count == 4)
        #expect(!GuideRepair.isPlaceholderTitle(fixed[0].title))
        #expect(fixed[0].nutmegSays.hasPrefix("Pretend that") && fixed[0].nutmegSays.lowercased().contains("everyone"))
        #expect(fixed.allSatisfy { sc in RoleID.allCases.allSatisfy { r in (1...3).contains(sc.steps.filter { $0.role.role == r }.count) } })
        #expect(fixed[0].steps.filter { $0.role == .R4 }.count == 2)            // the app's two items from its job
        #expect(fixed[1].steps.filter { $0.role == .R2 }.count == 3)            // capped at 3
        #expect(fixed.flatMap(\.steps).allSatisfy { !($0.short ?? "").contains("\"") && !($0.short ?? "").hasSuffix(".") })
        #expect(fixed.flatMap(\.steps).allSatisfy { ($0.short ?? "").split(separator: " ").count <= ChecklistScenes.maxItemWords })
        #expect(!fixed[0].steps.contains { ($0.short ?? "").hasPrefix("Captain,") })   // the card shows the role
        #expect(ChecklistScenes.repair(fixed, roles: roles, props: props, title: "Airplane", items: a.kit.items) == fixed)
        // GuideRepair sends checklist guides here; an older guide keeps the old repair.
        #expect(GuideRepair.repair(bad, roles: roles, props: props, title: "Airplane", items: a.kit.items) == fixed)
        let old = Fallback.airplane.kit.scenes
        #expect(GuideRepair.repair(old, roles: roles, props: props, title: "Airplane", items: a.kit.items).allSatisfy { !$0.isChecklist })
    }

    @Test func theScenarioAlwaysEndsWithAnActionForEveryone() {
        let s = ChecklistScenes.scenario("Pretend that the panel is beeping!", index: 1)
        #expect(s.hasPrefix("Pretend that the panel is beeping!") && s.contains("Everyone,"))
        #expect(ChecklistScenes.scenario(s, index: 1) == s)
        let ok = "Pretend that the rocket is blasting off... uh-oh! Everyone, do your job to get the rocket into space!"
        #expect(ChecklistScenes.scenario(ok, index: 0) == ok)
        #expect(ChecklistScenes.scenario("", index: 0).hasPrefix("Pretend that"))
    }

    // MARK: Every page and prop is used, at every count

    @Test func everyPageAndPropIsInAnItemTheKidsSeeAtEveryCount() {
        // Found, swapped and skipped props (a skipped prop is a printed cut-out: the cut-outs page covers it).
        var swapped = props
        swapped[2].householdItem = "Baking sheet"; swapped[2].libraryID = "baking-sheet"; swapped[2].swapped = true
        var skipped = props
        skipped[1].skipped = true
        for list in [props, swapped, skipped, []] {
            let k = kit(props: list)
            for n in 1...6 {
                let scenes = PlayCast.kit(k, roles: roles, players: n, props: list).scenes
                let items = Bookends.coverItems(items: k.items, props: list)
                #expect(ChecklistCoverage.missing(scenes, items: items).isEmpty, "count \(n): \(ChecklistCoverage.log(scenes, items: items))")
                // Every playing role puts on its badge in the first scene.
                let first = scenes.first { $0.arc == .play }!
                #expect(RoleID.allCases.prefix(n).allSatisfy { r in first.steps.contains { $0.role.role == r && ($0.short ?? "").lowercased().contains("badge") } })
                // Each item says its role first, then the item ("Captain, put on your badge!").
                for sc in scenes where sc.arc == .play {
                    for st in sc.steps {
                        let name = roles.first { $0.id == st.role.role }!.roleName
                        #expect(st.text.hasPrefix(name + ", ") && st.text.hasSuffix("!"))
                    }
                }
            }
        }
    }

    @Test func aMissingPageIsAddedForTheRoleWithRoom() {
        var k = kit()
        // Nobody names the menu in the guide any more.
        k.scenes = k.scenes.map { sc in var sc = sc; sc.steps.removeAll { ($0.short ?? "").lowercased().contains("menu") }; return sc }
        let scenes = PlayCast.kit(k, roles: roles, players: 5, props: props).scenes
        let items = Bookends.coverItems(items: k.items, props: props)
        #expect(ChecklistCoverage.missing(scenes, items: items).isEmpty)
        #expect(scenes.flatMap(\.steps).contains { $0.short == "Set out the menu" })
        // Deterministic: the same count gives the same scenes.
        #expect(PlayCast.kit(k, roles: roles, players: 5, props: props).scenes == scenes)
    }

    @Test func theCleanUpChecklistPutsEveryPropBack() {
        let k = kit()
        for n in 1...6 {
            let c = PlayCast.kit(k, roles: roles, players: n, props: props).scenes.last!
            #expect(c.arc == .cleanup && c.isChecklist && c.nutmegSays.isEmpty)
            #expect(ChecklistScenes.cards(c).map(\.role) == Array(RoleID.allCases.prefix(n)))
            for p in props {
                let item = Bookends.coverItems(items: k.items, props: props).first { $0.prop?.id == p.id }!
                #expect(c.steps.contains { Bookends.mentions($0.short ?? "", item) || Bookends.mentions($0.text, item) }, "count \(n) \(p.id)")
            }
            #expect(c.steps.allSatisfy { ($0.short ?? "").split(separator: " ").count <= Bookends.maxRowShortWords })
        }
        #expect(ChecklistScenes.cue(PlayCast.kit(k, roles: roles, players: 2, props: props).scenes.last!, number: 5).hasPrefix("Clean-up time: "))
    }

    // MARK: The store: checks, scenario, ◀ Previous

    @Test func checkingEveryItemFinishesTheSceneAndPreviousKeepsTheChecks() async {
        let store = await storeAtChecklist(players: 2)
        guard case .scene(let i) = store.phase, let sc = store.currentChecklist else { Issue.record("not in a checklist scene"); return }
        #expect(store.nutmegLine == "Scene 1: Get the Plane Ready! Tap your picture to hear your jobs.")
        #expect(!store.canGoBack && store.playNumber(i) == 1)
        for k in sc.steps.indices.dropLast() { #expect(store.toggleCheck(k) == false) }
        #expect(!store.currentSceneDone)
        #expect(store.toggleCheck(sc.steps.count - 1))                 // the last tick finishes it
        #expect(store.currentSceneDone && store.scenarioLine(i)?.hasPrefix("Pretend that") == true)
        #expect(store.toggleCheck(0) == false && !store.currentSceneDone)   // untick
        _ = store.toggleCheck(0)
        store.nextScene()
        #expect(store.canGoBack && store.nutmegLine.hasPrefix("Scene 2: "))
        _ = store.toggleCheck(0)
        store.previousScene()
        #expect(store.phase == .scene(i) && store.currentSceneDone)    // the checks as they were
        #expect(store.nutmegLine == store.scenarioLine(i))             // a finished scene says its scenario again
        store.nextScene()
        #expect(store.isChecked(0))
        // Voice: previous_scene does what the button does; on the first scene it says so.
        #expect(await store.apply(.previousScene).contains("Say nothing") && store.phase == .scene(i))
        #expect(await store.apply(.previousScene).contains("first scene"))
        #expect(PlanningCall.decode(name: "previous_scene", arguments: "{}") == .previousScene)
        #expect(Realtime.tools.contains { $0["name"] as? String == "previous_scene" })
        // A count change clears the checks (the rows were for the old crew).
        store.changePlayerCount(3)
        #expect(store.progress == ChecklistProgress())
    }

    @Test func theCleanUpChecklistHasNoScenarioAndGoesOnToTheEnd() async {
        let store = await storeAtChecklist(players: 6)
        while store.currentArc != .cleanup, case .scene = store.phase { store.nextScene() }
        guard case .scene(let i) = store.phase, let sc = store.currentChecklist else { Issue.record("no clean-up"); return }
        #expect(store.nutmegLine.hasPrefix("Clean-up time: ") && store.scenarioLine(i) == nil)
        for k in sc.steps.indices { _ = store.toggleCheck(k) }
        #expect(store.currentSceneDone)
        store.nextScene()
        #expect(store.phase == .end)
    }

    // MARK: The reading queue

    @Test func tapsWhileSheTalksQueueAndOnlyTheReadRowIsHighlighted() {
        var r = ChecklistReader()
        #expect(r.tap(.row(2), busy: false) == .row(2) && r.highlighted == 2)
        #expect(r.tap(.row(0), busy: true) == nil && r.tap(.row(1), busy: true) == nil)
        #expect(r.tap(.row(0), busy: true) == nil && r.queue == [.row(0), .row(1)])   // a repeat tap isn't queued twice
        #expect(r.tap(.row(2), busy: true) == nil && r.queue.count == 2)              // the row being read isn't queued
        #expect(r.finished() == .row(0) && r.highlighted == 0)
        _ = r.tap(.line("Pretend that…"), busy: true)
        r.dropQueuedRows()
        #expect(r.queue == [.line("Pretend that…")])
        #expect(r.finished() == .line("Pretend that…") && r.highlighted == nil)
        #expect(r.finished() == nil && r.isIdle)
        _ = r.tap(.row(1), busy: true); r.clear()
        #expect(r.isIdle)
    }

    // MARK: Saved games: schema 6, and older schemas keep their path

    @Test func aChecklistGameSavesAsSchemaSixAndReplaysTheSameWords() async throws {
        let store = await storeAtChecklist(players: 3)
        let first = store.kit!.scenes
        let g = try #require(store.savedGame(now: Date(timeIntervalSince1970: 1_800_000_000), art: [], cover: nil))
        #expect(g.schemaVersion == 6 && g.kit.isChecklist && g.kit.setup == nil)
        let back = try SavedGame.decode(SavedGame.encoder().encode(g))
        #expect(back == g)
        let replay = AdventureStore(service: nil)
        replay.loadReplay(back)
        replay.replayPick(3)
        replay.replayAllFound()
        #expect(replay.kit!.scenes.map(\.nutmegSays) == first.map(\.nutmegSays))
        #expect(replay.kit!.scenes.map { $0.steps.map(\.text) } == first.map { $0.steps.map(\.text) })
        #expect(replay.kit!.scenes.map { $0.steps.map(\.short) } == first.map { $0.steps.map(\.short) })
    }

    @Test func olderSchemasStillLoadAndReplayTheWayTheyDid() throws {
        let old = Fallback.airplane
        for schema in [2, 3, 4, 5] {
            let kit = schema == 2 ? Kit(nutmegSays: "", items: old.kit.items, scenes: old.kit.scenes) : old.kit
            var g = SavedGame(createdAt: Date(timeIntervalSince1970: 1_800_000_000), title: "Airplane", roles: old.plan.roles,
                              props: old.props.props.map(SavedProp.init), kit: kit, printStyle: .fullColor, art: [],
                              voiceID: VoiceConfig.nutmeg.voiceID)
            g.schemaVersion = schema
            let back = try SavedGame.decode(SavedGame.encoder().encode(g))
            #expect(back.schemaVersion == schema && !back.kit.isChecklist)
            let store = AdventureStore(service: nil)
            store.loadReplay(back)
            store.replayPick(2)
            store.replayAllFound()
            let arcs = store.kit!.scenes.map(\.arc)
            #expect(store.kit!.scenes.allSatisfy { !$0.isChecklist })
            #expect(arcs == (schema == 2 ? [.play, .play, .play] : [.story, .setup, .play, .play, .play, .cleanup]))
        }
    }

    // MARK: Skip (replays only) and resume

    @Test func aReplayCanSkipStraightToTheScenesAndANewGameCannot() async throws {
        let store = await storeAtChecklist(players: 2)
        store.debugSetPhase(.kitReady)
        #expect(!store.canSkipToScenes)                        // a new game: the checklists use what they found
        let g = try #require(store.savedGame(art: [], cover: nil))
        let replay = AdventureStore(service: nil)
        replay.loadReplay(g)
        #expect(!replay.canSkipToScenes)                       // Pick: the count first
        replay.replayPick(2)
        #expect(replay.phase == .props && replay.canSkipToScenes)
        replay.skipToScenes()
        #expect(replay.phase == .scene(0) && replay.inStory && !replay.replayHuntActive)
    }

    @Test func resumeOpensTheSavedGameAtItsSceneWithItsChecks() async throws {
        let store = await storeAtChecklist(players: 4)
        store.markSaved(store.gameID)
        _ = store.toggleCheck(0); _ = store.toggleCheck(1)
        store.nextScene()
        _ = store.toggleCheck(2)
        let point = try #require(store.resumePoint(now: Date(timeIntervalSince1970: 1_800_000_000)))
        let g = try #require(store.savedGame(id: store.gameID, art: [], cover: nil))
        // Only game content: an id, the count, the scene and the checks.
        let json = try JSONSerialization.jsonObject(with: ResumePoint.encoder().encode(point)) as! [String: Any]
        #expect(Set(json.keys) == ResumePoint.allowedKeys)
        let back = try ResumePoint.decoder().decode(ResumePoint.self, from: ResumePoint.encoder().encode(point))
        #expect(back == point && back.isFresh(now: Date(timeIntervalSince1970: 1_800_000_000 + 3600)))
        #expect(!back.isFresh(now: Date(timeIntervalSince1970: 1_800_000_000 + ResumePoint.maxAge + 1)))
        let again = AdventureStore(service: nil)
        again.resumeReplay(g, at: back)
        #expect(again.isReplay && again.playerCount == 4 && again.phase == store.phase)
        #expect(again.isChecked(2) && again.progress == store.progress)
        #expect(again.nutmegLine.hasPrefix("Scene 2: ") && again.replayFollowUp == nil)
        // Never back into the story on a resume.
        let story = ResumePoint(gameID: g.id, players: 2, scene: 0, progress: ChecklistProgress(), savedAt: Date())
        let s2 = AdventureStore(service: nil)
        s2.resumeReplay(g, at: story)
        #expect(!s2.inStory && s2.currentChecklist != nil)
        // Nothing to resume outside a scene, or before a new game is saved.
        let fresh = await storeAtChecklist(players: 2)
        #expect(fresh.resumePoint() == nil)
    }

    // MARK: Weave, voice, cue

    @Test func theWeaveRewritesAChecklistItem() {
        let k = kit()
        let w = PropWeave(uses: [.init(propID: "chair", scene: 0, step: 0, text: "Captain, set up the airplane seats!"),
                                 .init(propID: "plate", scene: 1, step: 0, text: "Hold the steering wheel high, then turn it left and right and wave to everyone on board")])
        let out = GuideWeave.apply(w, to: k.scenes, props: props, taken: [], roles: roles)
        #expect(out.scenes[0].steps[0].short == "Set up the airplane seats" && out.scenes[0].steps[0].picture == .prop("chair"))
        #expect(out.uses.count == 1)   // the long one is dropped
        let prompt = GuideWeave.prompt(scenes: k.scenes, props: props, taken: [], roles: roles, players: 2)
        #expect(prompt.contains("Phase: add household props") && prompt.contains("2 to 6 words") && !prompt.contains("setupSay"))
        let schema = GuideWeave.schema(propIDs: ["chair"], checklist: true)
        let job = (((schema["properties"] as? [String: Any])?["jobs"] as? [String: Any])?["items"] as? [String: Any])?["properties"] as? [String: Any]
        #expect(job?["setupSay"] == nil && job?["cleanupSay"] != nil)
        // A checklist kit asks for nothing more after the guide (its clean-up jobs are the app's when missing).
        #expect(Bookends.toReask(k, props: props).isEmpty)
    }

    @Test func aRoleLineReadsTheWholeChecklist() {
        let sc = PlayCast.kit(kit(), roles: roles, players: 2, props: props).scenes.first { $0.arc == .play }!
        let line = ChecklistScenes.roleLine(sc, role: .R1, roles: roles)
        #expect(line?.hasPrefix("Captain, put on your badge") == true && line?.hasSuffix("!") == true)
        #expect(ChecklistScenes.cleanItem("  Pilot, put on your \"helmet\".  ", roles: [Role(id: .R1, roleName: "Pilot", emoji: "", symbol: "", job: "")]) == "Put on your helmet")
        #expect(ChecklistScenes.say("Put on your badge", role: roles[0]) == "Captain, put on your badge!")
    }
}
