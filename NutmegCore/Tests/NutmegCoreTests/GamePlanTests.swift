import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-21 (Haylee, decisions/2026-11-21-one-game-plan.md; build: decisions/2026-11-21-round-game-plan-build.md):
/// one game plan (areas, every object's life cycle), printout play jobs, the props placed in one call, area setup and
/// clean-up cards, calm-stretch ideas, the traceability check, schema 8.
@MainActor
struct GamePlanTests {
    let a = Fallback.gamePlanAirplane(playerCount: 6)
    var roles: [Role] { a.plan.roles }
    var props: [Prop] { a.props.props }

    func kit(props: [Prop]? = nil) -> Kit {
        var k = a.kit
        k.scenes = GuideRepair.repair(k.scenes, roles: roles, props: props ?? self.props, title: "Sky Airlines", items: k.items)
        return Bookends.repair(k, props: props ?? self.props, roles: roles, title: "Sky Airlines").kit
    }
    func arc(_ k: Kit, _ n: Int, props: [Prop]? = nil) -> [Scene] {
        PlayCast.kit(k, roles: roles, players: n, props: props ?? self.props).scenes
    }

    // MARK: The plan

    @Test func theBundledPlanIsWholeAndTheRepairIsIdempotent() throws {
        let k = kit()
        #expect(k.hasGamePlan && k.isOneScene)
        let plan = try #require(k.scenes[0].plan)
        #expect(plan.areas.map(\.name) == ["the cockpit", "the passenger cabin", "the snack galley", "the gate"])
        #expect(Set(plan.areas.map(\.owner)).count == 4)
        // Every page (badges aside) and every found prop: exactly one life cycle with every part.
        let ids = ObjectOwners.objects(Bookends.coverItems(items: k.items, props: props)).map(\.id)
        #expect(plan.objects.map(\.id).sorted() == ids.sorted())
        #expect(plan.objects.allSatisfy { !$0.setup.isEmpty && !$0.idea.isEmpty && !$0.putAway.isEmpty && plan.area($0.area) != nil })
        #expect(plan.objects.filter(\.isProp).allSatisfy { $0.pretend != nil })
        #expect(plan.objects.allSatisfy { $0.appWritten != true }, "the bundled plan is all its own words: \(plan.objects.filter { $0.appWritten == true }.map(\.id))")
        // The events point at real objects and areas.
        for e in k.scenes[0].beats!.events {
            #expect((e.objects ?? []).allSatisfy { plan.object($0) != nil } && plan.area(e.area) != nil, "\(e.line)")
        }
        // Repairing again changes nothing.
        let again = GuideRepair.repair(k.scenes, roles: roles, props: props, title: "Sky Airlines", items: k.items)
        #expect(again == k.scenes)
    }

    @Test func everyPrintoutTypeHasAPlayJob() {
        for r in KitRecipe.allCases {
            let j = PrintPlayJobs.job(r)
            #expect(!j.use.isEmpty && !j.placeVerb.isEmpty && j.idea.contains("{it}") || r == .badges, "\(r)")
            let line = PlayPlans.ideaLine(PrintPlayJobs.idea(r, label: "the Moon Page"), who: "Captain")
            #expect(Speakable.isSpeakable(line) && !EventScenario.isGestureOnly(line, roles: roles), "\(line)")
        }
        #expect([KitRecipe.badges, .sign, .labels].allSatisfy { PrintPlayJobs.setupIsUse($0) })
        #expect(!PrintPlayJobs.setupIsUse(.log) && !PrintPlayJobs.setupIsUse(.passport) && !PrintPlayJobs.setupIsUse(.missionCards))
        // The plan prompt carries each page's play job; the kit prompt carries the whole library's.
        let prompt = PlayPlans.prompt(ctx: AdventureContext(gameTitle: "Rocket", playerCount: 2), items: a.kit.items)
        #expect(prompt.contains("page:menu") && prompt.contains(PrintPlayJobs.job(.menu).use) && !prompt.contains("page:badges"))
        #expect(prompt.contains("AREAS") && prompt.contains("GOOD events") && prompt.contains("PRETEND"))
        #expect(Prompts.kitPages(ctx: AdventureContext(gameTitle: "Rocket", playerCount: 2)).contains("in play: " + PrintPlayJobs.job(.passport).use))
        let schema = PlayPlans.schema(items: a.kit.items)
        let p = schema["properties"] as? [String: Any]
        #expect(p?["areas"] != nil && p?["objects"] != nil && p?["setup"] == nil)
    }

    @Test func ideaLinesPutTheOwnersTitleIn() {
        #expect(PlayPlans.ideaLine("While we fly, write in the captain's log what you saw!", who: "Captain")
                == "While we fly, Captain, write in the captain's log what you saw!")
        #expect(PlayPlans.ideaLine("count the Sky Dollars and pay for a treat", who: "Passenger")
                == "Passenger, count the Sky Dollars and pay for a treat!")
        #expect(PlayPlans.stripRoles("Captain, write in the log!", roles: roles) == "write in the log!")
        #expect(PlayPlans.stripRoles("While we fly, Captain, write in the log!", roles: roles) == "While we fly, write in the log!")
    }

    // MARK: The traceability check at every count

    @Test func everyObjectIsPlacedUsedAndPutAwayAtEveryCount() {
        let k = kit()
        let skip: [Prop] = props.enumerated().map { i, p in var q = p; if i == 1 { q.skipped = true }; return q }
        let extra = props + [Prop(id: "pillow", householdItem: "Pillow", becomes: "Cloud", forRole: .all, safetyOK: true, libraryID: "pillow")]
        for list in [props, skip, extra, []] {
            for n in 1...6 {
                let scenes = arc(k, n, props: list)
                let issues = PlayPlans.trace(scenes, kit: k, roles: roles, players: n, props: list)
                #expect(issues.isEmpty, "\(n) kids, \(list.count) props: \(issues)")
                // Fair calls still hold, and every line on a card is speakable.
                let play = scenes.first { $0.isBeatScene }!
                #expect(OneScene.isFair(play.beats!.events, playing: RoleCast.playing(roles, kids: n).map(\.id)))
                for st in scenes.filter(\.isChecklist).flatMap(\.steps) {
                    #expect(Speakable.isSpeakable(st.short ?? st.text) && Speakable.isSpeakable(st.text), "\(st.text)")
                }
                for idea in play.beats!.ideas ?? [] { #expect(Speakable.isSpeakable(idea.line), "\(idea.line)") }
            }
        }
    }

    @Test func aPlanThatLeftAPageUnusedIsRepairedByTheApp() {
        // The plan as the AI might write it: one area, the menu and the money with no life cycle, an idea that's a
        // gesture, a setup item that doesn't name its page.
        var k = a.kit
        var sc = Fallback.gamePlanScenes[0]
        var plan = sc.beats!.plan!
        plan.areas = [plan.areas[0], PlanArea(id: "A2", name: "", owner: .R2, job: "")]
        plan.objects = plan.objects.filter { $0.id != "page:menu" && $0.id != "page:money" && !$0.isProp }
        plan.objects[0].idea = "wave to everyone"
        plan.objects[1].setup = "Do it"
        plan.propsPlaced = nil
        sc.beats!.plan = plan
        k.scenes = [sc]
        k.scenes = GuideRepair.repair(k.scenes, roles: roles, props: props, title: "Sky Airlines", items: k.items)
        let fixed = k.scenes[0].plan!
        #expect(fixed.areas.count == 1)   // the nameless area is dropped
        #expect(fixed.object("page:menu")?.appWritten == true && fixed.object("page:money")?.appWritten == true)
        #expect(fixed.objects[0].idea != "wave to everyone" && fixed.objects[1].setup != "Do it")
        // The props come in when the hunt ends (the app places them when there's no answer).
        k.scenes[0] = PlayPlans.placeProps(nil, into: k.scenes[0], props: props, items: k.items, roles: roles)
        k.scenes = GuideRepair.repair(k.scenes, roles: roles, props: props, title: "Sky Airlines", items: k.items)
        #expect(k.scenes[0].plan!.objects.filter(\.isProp).count == props.count)
        for n in 1...6 {
            let issues = PlayPlans.trace(arc(k, n), kit: k, roles: roles, players: n, props: props)
            #expect(issues.isEmpty, "\(n): \(issues)")
        }
    }

    // MARK: The props call

    @Test func thePropsAnswerIsCheckedAndTheRestIsWrittenByTheApp() throws {
        var sc = Fallback.gamePlanScenes[0]
        sc.beats!.plan!.objects.removeAll(where: \.isProp)
        sc.beats!.plan!.propsPlaced = nil
        sc.beats!.events[2].line = "We're flying over the ocean! Captain, tell everyone what you can see down below!"
        let answer = PlanPropsAnswer(props: [
            .init(item: "prop:plate", area: "A1", owner: "R1", setup: "Set the steering wheel at the front of the cockpit", idea: "While we fly, steer us with the steering wheel!",
                  putAway: "Put the plate back", event: 2, eventLine: "We're flying over the ocean! Captain, steer with the steering wheel and tell everyone what you see!"),
            // A rewrite that names another role is refused; a household word becomes the pretend name.
            .init(item: "prop:tray", area: "A3", owner: "R3", setup: "Load the tray with snacks", idea: "push the snack cart down the aisle",
                  putAway: "Put the tray away", event: 5, eventLine: "Captain, roll the snack cart down the aisle!"),
            // A hazard is refused (the app's line instead).
            .init(item: "prop:chair", area: "A2", owner: "R2", setup: "Climb on the airplane seats", idea: nil, putAway: nil),
        ])
        let out = PlayPlans.placeProps(answer, into: sc, props: props, items: a.kit.items, roles: roles)
        let plan = try #require(out.plan)
        #expect(plan.propsPlaced == true && plan.objects.filter(\.isProp).count == props.count)
        let plate = try #require(plan.object("prop:plate"))
        #expect(plate.setup == "Set the steering wheel at the front of the cockpit" && plate.appWritten == nil && plate.pretend == "the steering wheel")
        #expect(out.beats!.events[2].line.contains("steering wheel") && out.beats!.events[2].objects == ["prop:plate"])
        #expect(out.beats!.events[5].line == sc.beats!.events[5].line)   // refused: it named the Captain
        #expect(plan.object("prop:tray")!.setup.contains("snack cart") && plan.object("prop:tray")!.idea == "push the snack cart down the aisle!")
        #expect(plan.object("prop:chair")!.setup != "Climb on the airplane seats")
        #expect(plan.object("prop:backpack")!.appWritten == true)   // no answer for it
        // A skipped prop has no object (its printed cut-out is on the cut-outs page).
        let skip = props.map { p -> Prop in var q = p; if p.id == "tray" { q.skipped = true }; return q }
        let out2 = PlayPlans.placeProps(answer, into: sc, props: skip, items: a.kit.items, roles: roles)
        #expect(out2.plan!.object("prop:tray") == nil)
        // The schema and prompt name every prop and the numbered events.
        let prompt = PlayPlans.propsPrompt(scene: sc, props: props, roles: roles, players: 4)
        #expect(prompt.contains("prop:plate") && prompt.contains("0 [calm; R1]") && prompt.contains("pretend name"))
        #expect(PlanPropsAnswer(props: []).safetyTexts.isEmpty && !answer.safetyTexts.isEmpty)
    }

    // MARK: Area cards

    @Test func setupCardsAreBuiltByArea() {
        let k = kit()
        for n in 1...6 {
            let setup = arc(k, n).first { $0.arc == .setup }!
            let cards = ChecklistScenes.cards(setup)
            #expect(cards.count == n)
            for c in cards {
                let job = setup.areaJob(c.role)
                #expect(job != nil && !(job ?? "").isEmpty, "\(n): \(c.role)")
                #expect(c.rows.count >= 2 && (c.rows.count <= 3 || n == 1), "\(n): \(c.rows.count) rows")
                for r in c.rows {
                    let st = setup.steps[r]
                    #expect(st.text == "\(roles[c.role.index].roleName), \(PlayCast.lowerFirst(st.short!))!" || n > 1 && st.text.hasSuffix("!"))
                    if st.objects != nil { #expect(st.picture != .point) }
                }
            }
        }
        // 4 kids: each owns its area. 2 kids: the cockpit + the snack galley / the cabin + the gate (merged).
        let four = arc(k, 4).first { $0.arc == .setup }!
        #expect(four.areaJob(.R1) == "Build the cockpit" && four.areaJob(.R4) == "Get the gate ready")
        let two = arc(k, 2).first { $0.arc == .setup }!
        #expect(two.areaJob(.R1)?.hasPrefix("Set up the cockpit and") == true, "\(two.areaJobs ?? [:])")
        // 6 kids: the two roles with no area help where their objects live.
        let six = arc(k, 6).first { $0.arc == .setup }!
        #expect(six.areaJob(.R5)?.hasPrefix("Help set up") == true && six.areaJob(.R6)?.hasPrefix("Help set up") == true)
        // The chips: a prop's art and a page's thumbnail.
        #expect(four.steps.contains { $0.picture == .prop("plate") } && four.steps.contains { $0.picture == .kit("page:tickets") })
        #expect(PictureResolver.resolve(.kit("page:tickets"), kit: k, roles: roles) != PictureResolver.fallback)
        // Clean-up by the same owners: each prop put away once, one print-mess item, area words on top.
        let clean = arc(k, 3).first { $0.arc == .cleanup }!
        #expect(clean.steps.filter { $0.objects == [OneScene.printMessID] }.count == 1)
        for p in props { #expect(clean.steps.filter { $0.objects?.contains("prop:\(p.id)") == true }.count == 1) }
        #expect(clean.areaJobs?["R1"] == "Tidy up the cockpit")
        #expect(ChecklistScenes.cards(clean).allSatisfy { $0.rows.count <= 3 })
    }

    // MARK: Ideas and the timeline

    @Test func ideasFillTheCalmGapsWithNoChimeOrDuck() throws {
        let k = kit()
        for n in 1...6 {
            let play = arc(k, n).first { $0.isBeatScene }!
            let b = play.beats!
            let ideas = b.ideas ?? []
            #expect(!ideas.isEmpty, "\(n)")
            let run = BeatRun(events: b.events, ideas: ideas)
            // At most 2 ideas a gap, each in a calm gap: never on a tense event's card or before its calm-again card is done.
            for g in 0...b.events.count { #expect(ideas.filter { $0.gap == g }.count <= BeatTimeline.maxIdeasPerGap) }
            for (k2, t) in run.ideaTimes.enumerated() {
                #expect(t > 0 && t < run.finaleAt)
                #expect(run.display(at: t + 1) == .idea(k2), "\(n): idea \(k2) at \(t)")
                #expect(run.music(at: t + 1) == .calm)   // no tense music, no chime: the music goes on
                #expect(run.face(at: t + 1) == .happyBob)
                #expect(run.ideaEnds(k2) <= t + BeatTimeline.ideaShows)
                #expect(run.display(at: run.ideaEnds(k2) + 0.5) != .idea(k2))
                if let i = run.events.indices.last(where: { run.eventAt($0) <= t }), run.events[i].isTense {
                    #expect(t >= run.eventAt(i) + BeatTimeline.calmAgainAfter + BeatRun.calmAgainShows)
                }
            }
            // The cues: one per idea, in time order; a calm event's card goes down at its gap's idea.
            #expect(run.cues.filter { if case .idea = $0.kind { return true } else { return false } }.count == ideas.count)
            #expect(run.cues.map(\.at) == run.cues.map(\.at).sorted())
            for i in run.events.indices where !run.events[i].isTense {
                #expect(run.eventEnds(i) <= (i + 1 < run.events.count ? run.eventAt(i + 1) : run.finaleAt))
            }
        }
        // A run with no ideas is exactly the older timeline.
        let ev = arc(k, 3).first { $0.isBeatScene }!.beats!.events
        #expect(BeatRun(events: ev).cues == BeatTimeline.cues(ev) && BeatRun(events: ev).ideaTimes.isEmpty)
        // End scene skips the ideas left.
        let b = arc(k, 2).first { $0.isBeatScene }!.beats!
        var run = BeatRun(events: b.events, ideas: b.ideas ?? [])
        let t = run.endEarly(at: 10)
        #expect(run.due(at: t + 0.1).allSatisfy { $0.kind == .finale })
    }

    // MARK: Saves

    @Test func schemaEightRoundTripsAndSchemaSevenKeepsItsPath() throws {
        let k = kit()
        let g = SavedGame(createdAt: Date(), title: "Sky Airlines", roles: roles, props: [], kit: k, printStyle: .fullColor, art: [], voiceID: "v")
        #expect(g.schemaVersion == 8 && SavedGame.readableSchemas.contains(7) && SavedGame.readableSchemas.contains(8))
        let back = try SavedGame.decode(SavedGame.encoder().encode(g))
        #expect(back.kit == k && back.kit.hasGamePlan)
        // A schema 7 one-scene kit: no plan, no area jobs, no ideas (its own path).
        var seven = Fallback.oneSceneAirplane(playerCount: 6).kit
        seven.scenes = GuideRepair.repair(seven.scenes, roles: roles, props: props, title: "Sky Airlines", items: seven.items)
        let scenes = PlayCast.kit(seven, roles: roles, players: 3, props: props).scenes
        #expect(!seven.hasGamePlan && scenes.allSatisfy { $0.areaJobs == nil } && scenes.first { $0.isBeatScene }?.beats?.ideas == nil)
        // Older JSON (no objects / area / plan / ideas / areaJobs keys) decodes.
        let old = #"{"mood":"calm","roles":["R1"],"line":"Captain, check the map!"}"#
        let e = try JSONDecoder().decode(BeatEvent.self, from: Data(old.utf8))
        #expect(e.objects == nil && e.area == nil)
        let enc = String(decoding: try JSONEncoder().encode(e), as: UTF8.self)
        #expect(!enc.contains("objects") && !enc.contains("area"))
    }

    @Test func thePlanAnswerDecodesIntoOneGuideScene() throws {
        let json = #"""
        {"story":"Welcome aboard!","setupTitle":"Get the Rocket Ready","cleanupTitle":"Landing Time","music":"space-adventure",
         "opener":"Pretend that our rocket is ready to blast off! Everyone, take your places!","finale":"We made it! Everyone, celebrate!",
         "areas":[{"name":"the cockpit","owner":"R1","job":"Build the cockpit"},{"name":"the engine room","owner":"R2","job":"Build the engine room"}],
         "objects":[{"item":"page:menu","area":"A2","owner":"R2","setup":"Put the snack menu by the engine","idea":"While we fly, read the snack menu out loud!","putAway":"Fold up the snack menu"}],
         "events":[{"mood":"calm","roles":["R1"],"line":"Captain, read the snack menu to the crew and pick a snack!","calmAgain":"","objects":["page:menu"],"area":"A1"}]}
        """#
        let g = try JSONDecoder().decode(GamePlanGuide.self, from: Data(json.utf8))
        let plan = try #require(g.scene.plan)
        #expect(plan.areas.map(\.id) == ["A1", "A2"] && plan.areas[1].owner == .R2)
        #expect(plan.objects.first?.id == "page:menu" && g.scene.steps.first?.short == "Put the snack menu by the engine")
        #expect(g.scene.beats?.events.first?.objects == ["page:menu"] && g.scene.beats?.events.first?.area == "A1")
        #expect(g.safetyTexts.contains("Build the engine room") && g.kit(items: a.kit.items).hasGamePlan)
        #expect(Validate.scenes([g.scene], roles: 6) == nil || Validate.scenes([g.scene], roles: 6)?.fatal == false)
    }

    // MARK: The bundled game in the store (demo mode)

    @Test func theDemoGamePlaysThePlan() async {
        let store = AdventureStore(service: nil)
        await store.start()
        await store.chooseGame("Airplane")
        store.setPlayerCount(3)
        await store.confirmPlayers()
        await store.confirmRoles()
        await store.confirmProps()
        store.beginPlay()
        if store.inStory { store.nextScene() }
        #expect(store.fullKit?.hasGamePlan == true)
        let setup = store.currentChecklist
        #expect(setup?.arc == .setup && setup?.areaJobs?.count == 3)
        let issues = PlayPlans.trace(store.kit!.scenes, kit: store.fullKit!, roles: store.plan!.roles, players: 3, props: store.props?.props ?? [])
        #expect(issues.isEmpty, "\(issues)")
    }

    // MARK: Review pass (replays with other props; Play never waits forever)

    @Test func aReplayWithoutAPropNeverAsksForItAndASwapPutsTheNewItemAway() throws {
        let k = kit()
        // The plate (the steering wheel) skipped on this replay: lines that name it say "the pretend steering wheel".
        let skip: [Prop] = props.map { p in var q = p; if p.id == "plate" { q.skipped = true }; return q }
        for n in [1, 3, 6] {
            let play = try #require(arc(k, n, props: skip).first { $0.isBeatScene }?.beats)
            for e in play.events where e.line.lowercased().contains("steering wheel") {
                #expect(e.line.lowercased().contains("pretend steering wheel"), "\(e.line)")
            }
            #expect(!play.events.contains { ($0.objects ?? []).contains("prop:plate") })
        }
        // The plate swapped for a pan: the steering wheel stays, the put-away names the pan's item (not the plate).
        let swap: [Prop] = props.map { p in
            var q = p
            if p.id == "plate" { q.householdItem = "Pan"; q.libraryID = "pan"; q.swapped = true }
            return q
        }
        let cleanup = try #require(arc(k, 6, props: swap).first { $0.arc == .cleanup })
        let row = try #require(cleanup.steps.first { $0.objects == ["prop:plate"] })
        #expect(!row.text.lowercased().contains("plate"), "\(row.text)")
        #expect(PlayPlans.trace(arc(k, 3, props: swap), kit: k, roles: roles, players: 3, props: swap).isEmpty)
    }

    @Test func aDeadlineAnswersOrGivesUpInTime() async {
        let fast = await Deadline.run(seconds: 5) { 7 }
        #expect(fast == 7)
        let started = Date()
        let slow = await Deadline.run(seconds: 0.3) { () -> Int in
            try await Task.sleep(for: .seconds(30)); return 1
        }
        #expect(slow == nil && Date().timeIntervalSince(started) < 5)
        let failed = await Deadline.run(seconds: 5) { () -> Int in throw ClaudeError.decoding("no") }
        #expect(failed == nil)
    }
}
