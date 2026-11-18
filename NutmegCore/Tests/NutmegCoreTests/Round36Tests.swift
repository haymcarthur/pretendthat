import Foundation
import Testing
@testable import NutmegCore

/// Round 36 (Haylee): Print → story → setup scene → 3 play scenes → clean-up scene → The End. Every found / swapped prop
/// and every printed page is used on purpose: named by a setup task (badges: the setup's opening), or by a play task the
/// same players see. Missing jobs are asked once more, then written by the app. Old saved games replay as they were.
@MainActor struct Round36Tests {
    let a = Fallback.airplane
    var roles: [Role] { a.plan.roles }
    var props: [Prop] { a.props.props }

    func items(_ ps: [Prop]) -> [CoverItem] { Bookends.coverItems(items: a.kit.items, props: ps) }

    // MARK: The arc and the coverage rule, at every count

    @Test func everyCountUsesEveryPropAndEveryPage() {
        for n in 1...6 {
            let view = PlayCast.kit(a.kit, roles: roles, players: n, props: props)
            #expect(view.scenes.map(\.arc) == [.story, .setup, .play, .play, .play, .cleanup], "n=\(n)")
            let all = items(props)
            #expect(all.count == 10)   // 6 pages + 4 props
            let missing = SetupCoverage.missing(view.scenes, items: all, roles: roles)
            #expect(missing.isEmpty, "n=\(n): \(SetupCoverage.log(view.scenes, items: all, roles: roles))")
            let setup = view.scenes[1]
            // Round 37: every playing role has at least one row, in role order; a role may have several rows.
            var seenRoles: [SceneOwner] = []
            for st in setup.steps where seenRoles.last != st.role { seenRoles.append(st.role) }
            #expect(seenRoles == RoleID.allCases.prefix(n).map { SceneOwner($0) }, "n=\(n)")
            #expect(setup.nutmegSays.hasPrefix("Pretend that") && setup.nutmegSays.contains("badge"))
            for st in setup.steps {
                let name = roles[st.role.role!.index].roleName
                #expect(st.text.hasPrefix(name + ", ") && st.text.hasSuffix("!"), "\(st.text)")
                let w = (st.short ?? "").split(separator: " ").count
                #expect(w >= 2 && w <= 7 && !(st.short ?? "").contains("and more"), "\(st.short ?? "-")")
            }
            // Clean-up: every playing role has a job, and every real prop goes back.
            let clean = view.scenes[5]
            #expect(Set(clean.steps.map(\.role)).count == n && PretendLine.has(clean.nutmegSays))
            for it in all where it.prop != nil {
                #expect(clean.steps.contains { Bookends.mentions($0.text, it) }, "n=\(n) \(it.id) not put away")
            }
            // With 6 kids (10 items, 9 for setup) everything fits in the setup scene, at most 2 items a role.
            if n == 6 { #expect(SetupCoverage.notInSetup(view.scenes, items: all, roles: roles).isEmpty) }
        }
    }

    @Test func aRoleGetsTwoItemsBeforeAnythingIsLeftToThePlayScenes() {
        let all = Bookends.setupItems(items: a.kit.items, props: props)
        var jobs: [String: ItemJob] = [:]
        for j in a.kit.setup!.jobs { jobs[j.item] = j }
        for n in 2...6 {
            let plan = Bookends.setupAssignment(items: all, jobs: jobs, play: PlayCast.kit(a.kit, roles: roles, players: n).playScenes, roles: roles, players: n)
            #expect(plan.allSatisfy { !$0.items.isEmpty })                 // one task per role, never empty
            #expect(plan.allSatisfy { $0.items.count <= 3 }, "\(plan.map(\.items))")
            // Round 37: whatever a role gets, no ROW names more than 2 items.
            #expect(plan.allSatisfy { Bookends.rows($0.items, players: n).allSatisfy { $0.count <= 2 } })
            let fits = all.count <= 2 * n
            if fits { #expect(plan.flatMap(\.items).count == all.count) }  // everything is set up when it fits
        }
    }

    @Test func anItemNoPlayTaskNamesIsAlwaysSetUpEvenPastTheTarget() {
        // Play tasks that name nothing: every item must then be in a setup task (a solo kid gets them all).
        var k = a.kit
        k.scenes = k.scenes.map { s in var s = s; s.steps = s.steps.map { var st = $0; st.text = "Do a happy dance!"; st.short = "Dance"; return st }; return s }
        for n in [1, 3, 6] {
            let view = PlayCast.kit(k, roles: roles, players: n, props: props)
            let all = items(props)
            #expect(SetupCoverage.missing(view.scenes, items: all, roles: roles).isEmpty, "n=\(n)")
            #expect(SetupCoverage.notInSetup(view.scenes, items: all, roles: roles).isEmpty, "n=\(n)")
        }
    }

    // MARK: Repair (deterministic) and the re-ask merge

    @Test func aGuideWithNoArcJobsIsRepairedAndStillUsesEverything() {
        var k = a.kit
        k.story = ""; k.setup = .empty; k.cleanup = .empty
        let r = Bookends.repair(k, props: props, roles: roles, title: "Airplane")
        #expect(r.repaired.contains("story") && r.repaired.contains("setup title") && r.repaired.contains("setup page:sign"))
        #expect(r.repaired.contains("clean-up prop:chair") && !r.repaired.contains("setup page:badges"))
        #expect(Bookends.repair(r.kit, props: props, roles: roles, title: "Airplane").repaired.isEmpty)   // idempotent
        #expect(Bookends.isValidStory(r.kit.story ?? "") && PretendLine.has(r.kit.setup!.nutmegSays) && PretendLine.has(r.kit.cleanup!.nutmegSays))
        for n in 1...6 {
            let view = PlayCast.kit(r.kit, roles: roles, players: n, props: props)
            #expect(SetupCoverage.missing(view.scenes, items: items(props), roles: roles).isEmpty, "n=\(n)")
        }
        // An old kit (no arc) is never given one.
        let old = Kit(nutmegSays: "", items: a.kit.items, scenes: a.kit.scenes)
        #expect(Bookends.repair(old, props: props, roles: roles, title: "Airplane").kit == old)
    }

    @Test func aJobThatDoesNotNameItsItemIsReaskedThenMerged() {
        var k = Bookends.ensure(Kit(nutmegSays: "", items: a.kit.items, scenes: a.kit.scenes))
        k.setup?.put(ItemJob(item: "page:sign", short: "Do it", say: "make everything nice and tidy", role: .R1))   // names no sign
        let again = Bookends.toReask(k, props: props).map(\.id)
        #expect(again.contains("page:sign") && again.contains("prop:chair") && again.contains("page:badges"))   // badges: clean-up only
        let answer = [ItemJobs.Job(item: "page:sign", role: "R1", setupShort: "Hang up the sign", setupSay: "hang the Gate 3 sign by the door",
                                   cleanupShort: "Take down the sign", cleanupSay: "take down the sign for the night"),
                      ItemJobs.Job(item: "chair", role: "R2", setupShort: "Line up the seats", setupSay: "line up the airplane seats in two rows",
                                   cleanupShort: "Chairs back", cleanupSay: "put the chairs back at the table"),
                      ItemJobs.Job(item: "plate", role: "R1", setupShort: "Wheel", setupSay: "make it spin", cleanupShort: "x", cleanupSay: "go away")]   // unusable
        let merged = Bookends.merge(answer, into: k, props: props)
        #expect(merged.setup?.job("page:sign")?.say == "hang the Gate 3 sign by the door")
        #expect(merged.setup?.job("prop:chair")?.householdItem == "Chair" && merged.cleanup?.job("prop:chair")?.role == .R2)
        #expect(merged.setup?.job("prop:plate") == nil)   // a job that doesn't name its item is never taken
        // The weave answer shape carries the props' jobs too.
        let weave = PropWeave(uses: [], jobs: [answer[1]])
        #expect(weave.safetyTexts.contains("line up the airplane seats in two rows"))
    }

    // MARK: Skips and swaps (applied when the rows are put together)

    @Test func aSkippedPropIsACutOutAndASwapNamesTheNewItem() {
        var ps = props
        ps[1].skipped = true                          // the plate: a printed cut-out (the cut-outs page covers it)
        ps[3].householdItem = "Duffel bag"; ps[3].swapped = true   // the backpack → a duffel bag
        let all = items(ps)
        #expect(!all.contains { $0.id == "prop:plate" } && all.contains { $0.id == "prop:backpack" })
        for n in [1, 4] {
            let view = PlayCast.kit(a.kit, roles: roles, players: n, props: ps)
            #expect(SetupCoverage.missing(view.scenes, items: all, roles: roles).isEmpty, "n=\(n)")
            let clean = view.scenes.last!
            #expect(!clean.steps.contains { $0.text.lowercased().contains("plastic plate") })
            #expect(clean.steps.contains { $0.text.contains("duffel bag") }, "\(clean.steps.map(\.text))")
        }
    }

    // MARK: The guide's answer shape

    @Test func theGuideDecodesTheStoryAndThePageJobs() throws {
        func task(_ r: String) -> String { #""\#(r)":{"short":"Do the job","say":"\#(r), do the job!"}"# }
        let scene = "{" + #""title":"Boarding","nutmegSays":"Pretend that we fly!","# + (["R1", "R2", "R3", "R4", "R5", "R6", "solo"].map(task).joined(separator: ",")) + "}"
        func job(_ r: String) -> String {
            #""\#(r)":{"role":"R2","setupShort":"Set up","setupSay":"set out the \#(r) by the door","cleanupShort":"Tidy","cleanupSay":"stack the \#(r) in a pile"}"#
        }
        let json = "{" + #""scene1":\#(scene),"scene2":\#(scene),"scene3":\#(scene),"story":"Welcome aboard! You are the crew. Let's fly!","#
            + #""setupScene":{"title":"Get Ready","nutmegSays":"Pretend that the plane leaves soon!"},"#
            + #""cleanupScene":{"title":"Landing","nutmegSays":"Pretend that we landed!"},"#
            + #""pageJobs":{"# + KitRecipe.original.map { job($0.rawValue) }.joined(separator: ",") + "}}"
        let g = try JSONDecoder().decode(KitScenesSix.self, from: Data(json.utf8))
        #expect(g.scenes.count == 3 && g.story == "Welcome aboard! You are the crew. Let's fly!")
        #expect(g.setup?.title == "Get Ready" && g.setup?.jobs.count == 6 && g.cleanup?.jobs.count == 6)
        #expect(g.setup?.job("page:sign")?.say == "set out the sign by the door" && g.setup?.job("page:sign")?.role == .R2)
        #expect(g.safetyTexts.contains("stack the menu in a pile"))
        // The schema asks for all of it (strict: every field required).
        let schema = KitScenesSix.schema()
        let pages = ((schema["properties"] as? [String: Any])?["pageJobs"] as? [String: Any])?["required"] as? [String]
        #expect(pages?.sorted() == KitRecipe.original.map(\.rawValue).sorted())
        // Kit pages are written with a purpose, and the guide's prompt receives it.
        let item = ((Schemas.kitPages()["properties"] as? [String: Any])?["items"] as? [String: Any])?["items"] as? [String: Any]
        #expect((item?["required"] as? [String])?.contains("purpose") == true)
        var pagesWithPurpose = a.kit.items
        pagesWithPurpose[1].purpose = "Hang it at the gate so passengers know where to board."
        let prompt = Prompts.kitScenes(ctx: AdventureContext(gameTitle: "Airplane", playerCount: 2), items: pagesWithPurpose, huntPending: true)
        #expect(prompt.contains("passengers know where to board") && prompt.contains("pageJobs") && prompt.contains("story"))
        #expect(Prompts.kitPages(ctx: AdventureContext(gameTitle: "Airplane", playerCount: 2)).contains("purpose"))
    }

    // MARK: What she says

    @Test func theStoryIsToldThenTheSetupSaysHowToMoveOn() async {
        let store = await storeWithKit(owners: [], players: 3)
        store.beginPlay()
        #expect(store.phase == .scene(0) && store.inStory)
        #expect(store.nutmegLine == PlayCast.endSentence(a.kit.story!))           // the story as written, no cue
        #expect(!store.nutmegLine.contains(HandOffLines.taskCue))
        store.nextScene()
        #expect(store.kit!.scenes[1].arc == .setup && !store.inStory)
        #expect(store.nutmegLine.hasPrefix("Pretend that the plane leaves in five minutes!") && store.nutmegLine.contains("put on your badge"))
        #expect(store.nutmegLine.contains(HandOffLines.taskCue) && store.nutmegLine.hasSuffix(HandOffLines.nextSceneHowTo))
        store.nextScene()
        #expect(!(store.sceneLine(2) ?? "").contains(HandOffLines.nextSceneHowTo))   // only the first scene with rows
        // read_job works in the setup scene too.
        store.debugSetPhase(.scene(1))
        let passengerRow = store.kit!.scenes[1].steps.firstIndex { $0.role == SceneOwner(.R2) }   // round 37: a role may have 2+ rows
        #expect(await store.apply(.readJob("Passenger")).contains("Say nothing") && store.lastReadJobRow == passengerRow)
        // The story has no step tab and uses the talking close-up.
        #expect(PTStepTab.forPhase(.scene(0), replay: false, propsShown: 0, papersOut: false, arc: .story) == nil && PTStepTab.forPhase(.scene(5), replay: false, propsShown: 0, papersOut: false, arc: .cleanup) == .cleanup)
        #expect(PTStepTab.forPhase(.scene(1), replay: false, propsShown: 0, papersOut: false, arc: .setup) == .setup && PTChatTabState.cardKey(for: .setup, phase: .scene(1)) == "scene-1")
        #expect(PTStepTab.forPhase(.scene(2), replay: false, propsShown: 0, papersOut: false) == .scene && store.currentArc == .setup)
        #expect(PTStageDirector.preset(phase: .scene(0), conversation: false, conversationShot: .closeUp, cards: 0, hunt: false,
                                       kitBeat: .papers, chatOpen: false, story: true) == .talk)
        // The End's Play step reopens the clean-up scene.
        for _ in 0..<6 where store.phase != .end { store.nextScene() }
        #expect(store.phase == .end && store.goTo(.play) && store.kit!.scenes[store.kit!.scenes.count - 1].arc == .cleanup)
    }

    // MARK: Saved games: schema 3 keeps the arc; schema 2 games replay as they were

    @Test func newGamesSaveTheArcAndReplayTheSameWords() async throws {
        let store = await storeWithKit(owners: [], players: 3)
        let first = store.kit!.scenes
        #expect(first.map(\.arc) == [.story, .setup, .play, .play, .play, .cleanup])
        let g = try #require(store.savedGame(now: Date(timeIntervalSince1970: 1_800_000_000), art: [], cover: nil))
        #expect(g.schemaVersion == SavedGame.currentSchema && g.kit.setup != nil && g.kit.cleanup != nil && !(g.kit.story ?? "").isEmpty)
        let back = try SavedGame.decode(SavedGame.encoder().encode(g))
        #expect(back == g)
        let json = String(decoding: try SavedGame.encoder().encode(g), as: UTF8.self)
        #expect(!json.contains("playerCount") && !json.contains("transcript"))   // still game content only
        // Replay with the same count and the same answers: identical scenes, word for word (her clips are reused).
        let replay = AdventureStore(service: nil)
        replay.loadReplay(back)
        replay.replayPick(3)
        replay.replayAllFound()
        #expect(replay.kit!.scenes.map(\.nutmegSays) == first.map(\.nutmegSays))
        #expect(replay.kit!.scenes.map { $0.steps.map(\.text) } == first.map { $0.steps.map(\.text) })
        #expect(replay.kit!.scenes.map { $0.steps.map(\.short) } == first.map { $0.steps.map(\.short) })
    }

    @Test func aSchemaTwoGameStillReplaysItsThreeScenes() throws {
        var g = SavedGame(createdAt: Date(timeIntervalSince1970: 1_800_000_000), title: "Airplane", roles: roles,
                          props: props.map(SavedProp.init), kit: Kit(nutmegSays: "", items: a.kit.items, scenes: a.kit.scenes),
                          printStyle: .fullColor, art: [], voiceID: VoiceConfig.nutmeg.voiceID)
        g.schemaVersion = 2
        let back = try SavedGame.decode(SavedGame.encoder().encode(g))
        #expect(back.schemaVersion == 2 && !back.kit.hasBookends)
        let store = AdventureStore(service: nil)
        store.loadReplay(back)
        store.replayPick(2)
        store.replayAllFound()
        #expect(store.kit?.scenes.map(\.arc) == [.play, .play, .play])
        store.beginPlay()
        #expect(store.phase == .scene(0) && !store.inStory && store.nutmegLine == HandOffLines.sceneOpen(store.kit!.scenes[0], first: true))
        // A schema this build doesn't know is still refused.
        g.schemaVersion = 6   // round 46: 5 is the AI-drawn whole-page kit
        #expect(throws: (any Error).self) { try SavedGame.decode(SavedGame.encoder().encode(g)) }
    }

    @Test func theArcIsCheckedForKidSafety() {
        let texts = Bookends.safetyTexts(a.kit)
        #expect(texts.contains(a.kit.story!) && texts.contains("Get the Plane Ready") && texts.contains("put the backpack back in your room"))
    }
}
