import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-21 (Haylee, decisions/2026-11-21-one-scene-music-beats.md): a setup checklist, ONE ~10 minute scene with
/// music and Nutmeg's events, then a clean-up checklist. The guide's event pool, fair calls at every count, the
/// timeline and its clock, the clean-up rule, the store's flow, resume, schema 7, the mic staying off in Play.
@MainActor
struct OneSceneTests {
    let a = Fallback.oneSceneAirplane(playerCount: 6)
    var roles: [Role] { a.plan.roles }
    var props: [Prop] { a.props.props }

    /// The one-scene airplane kit, repaired the way the store repairs every guide.
    func kit(props: [Prop]? = nil) -> Kit {
        var k = a.kit
        k.scenes = GuideRepair.repair(k.scenes, roles: roles, props: props ?? self.props, title: "Airplane", items: k.items)
        return Bookends.repair(k, props: props ?? self.props, roles: roles, title: "Airplane").kit
    }

    /// A store on the bundled (one-scene) game, at the setup checklist.
    func storeAtSetup(players: Int = 2) async -> AdventureStore {
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

    func event(_ mood: BeatMood, _ roles: [RoleID], _ line: String, calm: String? = nil) -> BeatEvent {
        BeatEvent(mood: mood, roles: roles, line: line, calmAgain: calm)
    }

    // MARK: The guide call

    @Test func theGuideAnswerDecodesIntoOneScene() throws {
        let json = #"""
        {"story":"Welcome aboard the rocket! You are the crew. Let's fly to the Moon today!","setupTitle":"Get the Rocket Ready",
         "setup":{"R1":["Put on your badge","Set up the control panel"],"R2":["Put on your badge"],"R3":[],"R4":["Put on your badge"],"R5":["Put on your badge"],"R6":["Put on your badge"]},
         "opener":"Pretend that the rocket is blasting off!","finale":"We made it to the Moon! Everyone, celebrate!","music":"space-adventure",
         "events":[{"mood":"calm","roles":["R1"],"line":"Captain, start the engines!","calmAgain":""},
                   {"mood":"tense","roles":["R1","R2"],"line":"Space rocks ahead! Captain, steer around them, and Passenger, hold on tight!","calmAgain":"Phew, the rocks are behind us."},
                   {"mood":"weird","roles":["R9","r2"],"line":"Passenger, wave!","calmAgain":""}],
         "cleanupTitle":"Back on Earth"}
        """#
        let g = try JSONDecoder().decode(OneSceneGuide.self, from: Data(json.utf8))
        #expect(g.scene.beats != nil && g.scene.isChecklist && g.scene.id == "s1" && g.scene.title == "Get the Rocket Ready")
        #expect(g.scene.steps.filter { $0.role == .R1 }.compactMap(\.short) == ["Put on your badge", "Set up the control panel"])
        let b = try #require(g.scene.beats)
        #expect(b.music == .spaceAdventure && b.events.count == 3 && b.events[1].isTense && b.events[0].calmAgain == nil)
        #expect(b.events[2].mood == .calm && b.events[2].roles == [.R2])   // unknown mood → calm, unknown role dropped
        #expect(g.story?.hasPrefix("Welcome") == true && g.cleanupTitle == "Back on Earth")
        let k = g.kit(items: a.kit.items)
        #expect(k.isOneScene && k.isChecklist && k.cleanup?.title == "Back on Earth" && k.setup == nil)
        #expect(g.safetyTexts.contains("We made it to the Moon! Everyone, celebrate!") && g.safetyTexts.contains("Phew, the rocks are behind us."))
        // A tolerant music tag (and a guess when it's unknown).
        #expect(MusicFamily.parse("Under the sea") == .underTheSea && MusicFamily.parse("SPOOKY_SILLY") == .spookySilly)
        #expect(MusicFamily.guess("Pirate Ship Treasure Hunt") == .pirateAdventure && MusicFamily.guess("Moon Crumbs Bakery") == .spaceAdventure)
        #expect(MusicFamily.guess("Sunny Bakery") == .cozyShop && MusicFamily.allCases.count == 14)
        let bad = try JSONDecoder().decode(SceneBeats.self, from: Data(#"{"opener":"x","events":[],"finale":"y","music":"polka"}"#.utf8))
        #expect(bad.music == MusicFamily.fallback)
        // The schema: story, setup (R1–R6), opener, the event pool, finale, music (a fixed list), clean-up title.
        let schema = OneScene.schema()
        #expect((schema["required"] as? [String])?.sorted() == ["cleanupTitle", "events", "finale", "music", "opener", "setup", "setupTitle", "story"])
        let p = schema["properties"] as? [String: Any]
        #expect(((p?["music"] as? [String: Any])?["enum"] as? [String])?.count == 14)
        let ev = ((p?["events"] as? [String: Any])?["items"] as? [String: Any])?["required"] as? [String]
        #expect(ev?.sorted() == ["calmAgain", "line", "mood", "roles"])
        // The prompt: the pool works for every group size, calm-again never credits the kids, no household props yet.
        let prompt = OneScene.prompt(ctx: AdventureContext(gameTitle: "Rocket", playerCount: 2), items: a.kit.items)
        #expect(prompt.contains("call ONLY R1") && prompt.contains("WITHOUT saying the kids fixed it") && prompt.contains("no household things"))
        #expect(prompt.contains("space-adventure") && prompt.contains("EVERY OBJECT HAS ONE OWNER") && prompt.contains("Make a silly wobbly face") && !prompt.contains("scene4"))
        #expect(Validate.scenes([g.scene], roles: 6) == nil)
        var none = g.scene; none.beats?.events = []
        #expect(Validate.scenes([none], roles: 6)?.fatal == false)
    }

    // MARK: Repair

    @Test func theRepairMakesThePoolUsableAndIsIdempotent() {
        var sc = a.kit.scenes[0]
        sc.title = "x"
        sc.steps.removeAll { $0.role == .R4 }
        var b = sc.beats!
        b.opener = "The plane is ready"
        b.finale = "We landed"
        b.events = [
            event(.calm, [.R2], "Captain, wave to everyone!"),                                        // names R1, lists R2 → R1
            event(.tense, [.R3], "Uh-oh, the snack cart is rolling away! Grab it quick!", calm: "You fixed it, great job!"),
            event(.tense, [.R1], "Captain, Passenger, Co-Pilot and Snack Chef, everyone jump!"),     // 4 roles → dropped
            event(.calm, [], "Do a happy dance in your seats!"),                                      // everyone
            event(.calm, [.R5, .R6], "VIP Passenger, ask for a snack, and Snack Chef, make it!"),
            event(.calm, [.R1], "\"Captain\", wave to everyone!"),                                   // a duplicate
        ]
        sc.beats = b
        let fixed = OneScene.repair(sc, roles: roles, props: props, title: "Airplane", items: a.kit.items)
        #expect(fixed.isChecklist && !GuideRepair.isPlaceholderTitle(fixed.title))
        #expect(RoleID.allCases.allSatisfy { r in (1...3).contains(fixed.steps.filter { $0.role.role == r }.count) })
        let fb = fixed.beats!
        #expect(fb.opener.hasPrefix("Pretend that") && fixed.nutmegSays == fb.opener)
        #expect(fb.finale.lowercased().contains("everyone"))
        #expect(fb.events.count == 4)
        #expect(fb.events[0].roles == [.R1] && fb.events[0].appWritten == true && fb.events[0].line.hasPrefix("Captain, "))   // a wave is no scenario
        #expect(fb.events[1].roles == [.R3] && fb.events[1].line.hasPrefix("Flight Attendant, "))
        #expect(OneScene.calmAgainLines.contains(fb.events[1].calmAgain ?? ""))   // never "you fixed it"
        #expect(fb.events[2].isEveryone && fb.events[2].line.hasPrefix("Everyone, "))
        #expect(fb.events[3].roles == [.R5, .R6])
        #expect(fb.events.filter { !$0.isTense }.allSatisfy { $0.calmAgain == nil })
        #expect(OneScene.repair(fixed, roles: roles, props: props, title: "Airplane", items: a.kit.items) == fixed)
        // GuideRepair sends a one-scene guide here (one scene out).
        #expect(GuideRepair.repair([sc], roles: roles, props: props, title: "Airplane", items: a.kit.items) == [fixed])
        // "VIP Passenger" doesn't also count as "Passenger".
        #expect(OneScene.named("VIP Passenger, ask for a snack!", roles: roles) == [.R6])
        #expect(OneScene.named("Passenger and VIP Passenger, dance!", roles: roles) == [.R2, .R6])
        // A tense event with no calm-again gets one.
        let t = OneScene.repairEvent(event(.tense, [.R1], "Captain, bumpy clouds! Hold on!"), roles: roles)
        #expect(t?.calmAgain?.hasPrefix("Phew") == true)
    }

    // MARK: Fair calls (Haylee: max difference 1, counted in code)

    @Test func theBundledPoolCallsEveryRoleFairlyAtEveryCountWithNoAppEvents() {
        let pool = kit().scenes[0].beats!.events
        for n in 1...6 {
            let plan = OneScene.pick(pool: pool, roles: roles, players: n)
            let playing = Array(RoleID.allCases.prefix(n))
            #expect(plan.count == OneScene.eventCount(players: n))
            #expect(OneScene.isFair(plan, playing: playing), "count \(n): \(OneScene.calls(plan, playing: playing))")
            #expect(plan.allSatisfy { $0.appWritten != true }, "count \(n) needed app events")
            #expect(plan.allSatisfy { $0.roles.allSatisfy(playing.contains) })   // never a role that isn't playing
            #expect(zip(plan, OneScene.cadence(plan.count)).allSatisfy { $0.0.mood == $0.1 })   // calm → tense → calm …
        }
        #expect(OneScene.eventCount(players: 1) == 3 && OneScene.eventCount(players: 4) == 4 && OneScene.eventCount(players: 6) == 5)
        #expect(OneScene.cadence(5) == [.calm, .tense, .calm, .tense, .calm])
    }

    @Test func aPoolThatCantBeFairIsRepairedWithAppEvents() {
        let onlyCaptain = [event(.calm, [.R1], "Captain, wave!"), event(.tense, [.R1], "Captain, bumpy clouds!", calm: "Phew."),
                           event(.calm, [.R1], "Captain, smile!"), event(.calm, [.R1], "Captain, look out the window!")]
        let lopsided = onlyCaptain + [event(.calm, [.R1, .R2, .R3], "Captain, Passenger and Flight Attendant, wave!")]
        for pool in [[], onlyCaptain, lopsided, kit().scenes[0].beats!.events.filter { !$0.roles.contains(.R5) && !$0.roles.contains(.R6) }] {
            for n in 1...6 {
                let plan = OneScene.pick(pool: pool, roles: roles, players: n)
                let playing = Array(RoleID.allCases.prefix(n))
                #expect(plan.count == OneScene.eventCount(players: n))
                #expect(OneScene.isFair(plan, playing: playing), "count \(n): \(OneScene.calls(plan, playing: playing))")
                #expect(plan.allSatisfy { e in e.roles.count <= OneScene.maxRolesPerEvent && !e.line.isEmpty })
                for e in plan where e.appWritten == true {
                    // An app event names its role(s) first; a tense one has a calm-again line.
                    #expect(e.line.hasPrefix(OneScene.names(e.roles, roles: roles) + ", "))
                    #expect(!e.isTense || e.calmAgain?.hasPrefix("Phew") == true)
                }
            }
        }
        // One kid with only Captain events uses them (no app event needed).
        #expect(OneScene.pick(pool: onlyCaptain, roles: roles, players: 1).allSatisfy { $0.appWritten != true })
        // The rotation is always fair.
        for n in 1...6 {
            let playing = Array(RoleID.allCases.prefix(n))
            #expect(OneScene.isFair(OneScene.rotation(playing: playing, roles: roles, count: OneScene.eventCount(players: n)), playing: playing))
        }
        // An "everyone" event calls every playing role.
        #expect(OneScene.calls([event(.calm, [], "Everyone, dance!")], playing: [.R1, .R2]) == [.R1: 1, .R2: 1])
    }

    // MARK: Composing what N kids see

    @Test func theArcIsSetupThenTheSceneThenCleanUpAtEveryCount() {
        var skipped = props; skipped[1].skipped = true
        var swapped = props
        swapped[2].householdItem = "Baking sheet"; swapped[2].libraryID = "baking-sheet"; swapped[2].swapped = true
        for list in [props, skipped, swapped, []] {
            let k = kit(props: list)
            for n in 1...6 {
                let scenes = PlayCast.kit(k, roles: roles, players: n, props: list).scenes
                #expect(scenes.map(\.arc) == [.story, .setup, .play, .cleanup])
                let setup = scenes[1], play = scenes[2]
                #expect(setup.isChecklist && setup.nutmegSays.isEmpty && !play.isChecklist && play.isBeatScene)
                #expect(ChecklistScenes.cards(setup).map(\.role) == Array(RoleID.allCases.prefix(n)))
                // 2026-11-21: every printed page and every prop the kids have is in EXACTLY one setup item the playing
                // kids see (one owner per object); 2 to 3 items per card (a solo kid may need more rows).
                let items = Bookends.coverItems(items: k.items, props: list)
                #expect(OneSceneCoverage.exactlyOnce(scenes, items: items),
                        "count \(n): missing \(OneSceneCoverage.missing(scenes, items: items)) repeated \(OneSceneCoverage.repeated(scenes, items: items)) \(setup.steps.map { "\($0.role.rawValue): \($0.short ?? "")" })")
                for card in ChecklistScenes.cards(setup) {
                    #expect(card.rows.count >= 2 && (card.rows.count <= 3 || n == 1), "count \(n) \(card.role): \(card.rows.count)")
                }
                // The scene: the picked events (fair), no role that isn't playing named anywhere.
                let b = play.beats!
                #expect(b.events == OneScene.pick(pool: k.scenes[0].beats!.events, roles: roles, players: n))
                let away = roles.filter { $0.id.rank > n }
                for line in b.texts { #expect(!away.contains { OneScene.named(line, roles: roles).contains($0.id) }, "\(n): \(line)") }
                #expect(b.opener.hasPrefix("Pretend that") && b.music == .spaceAdventure)
            }
        }
        // An older kit (no beats) is never composed this way.
        #expect(!Fallback.checklistAirplane(playerCount: 2).kit.isOneScene)
    }

    @Test func cleanUpHasEveryPropPlusThePrintMessSpreadFairly() {
        var skipped = props; skipped[0].skipped = true; skipped[3].skipped = true
        var many = props
        many.append(contentsOf: [Prop(id: "pillow", householdItem: "Pillow", becomes: "Cloud cushion", forRole: .R4, safetyOK: true),
                                 Prop(id: "spoon", householdItem: "Spoon", becomes: "Snack scoop", forRole: .R5, safetyOK: true)])
        for list in [props, skipped, many, []] {
            let k = kit(props: list)
            for n in 1...6 {
                let c = PlayCast.kit(k, roles: roles, players: n, props: list).scenes.last!
                #expect(c.arc == .cleanup && c.isChecklist && c.nutmegSays.isEmpty)
                let found = list.filter { !$0.isSkipped }
                let mess = c.steps.filter { $0.short == OneScene.printMessShort }
                #expect(mess.count == 1, "count \(n)")
                let propRows = c.steps.filter { $0.short != OneScene.printMessShort && $0.short != "Give high fives" }
                #expect(propRows.count == found.count, "count \(n): \(c.steps.map { $0.short ?? "" })")
                // Fair: no role has more than one item more than another (counted over the clean-up items).
                let per = RoleID.allCases.prefix(n).map { r in c.steps.filter { $0.role.role == r && $0.short != "Give high fives" }.count }
                #expect((per.max() ?? 0) - (per.min() ?? 0) <= 1, "count \(n): \(per)")
                // Every playing role has a card; only playing roles.
                #expect(ChecklistScenes.cards(c).map(\.role) == Array(RoleID.allCases.prefix(n)))
                for st in c.steps {
                    let name = roles.first { $0.id == st.role.role }!.roleName
                    #expect(st.text.hasPrefix(name + ", ") && st.text.hasSuffix("!"))
                }
            }
        }
    }

    // MARK: Timeline, run and clock

    @Test func theTimelineIsAboutTenMinutesWithEventsAMinuteAndAHalfToThreeApart() {
        for count in 3...5 {
            let events = OneScene.cadence(count).enumerated().map { i, m in event(m, [.R1], "Captain, go \(i)!", calm: m == .tense ? "Phew." : nil) }
            let cues = BeatTimeline.cues(events)
            let times = cues.compactMap { c -> TimeInterval? in if case .event = c.kind { return c.at } else { return nil } }
            #expect(times.count == count && cues.first?.kind == .opener && cues.first?.at == 0)
            for (x, y) in zip(times, times.dropFirst()) { #expect((90...180).contains(y - x), "\(count): \(y - x)") }
            #expect(times[0] >= 60)
            for (i, e) in events.enumerated() {
                let t = BeatTimeline.eventAt(i, count: count)
                #expect(cues.contains { $0.kind == .event(i) && $0.at == t })
                if e.isTense {
                    let calm = try! #require(cues.first { $0.kind == .calmAgain(i) })
                    #expect((30...60).contains(calm.at - t))
                    #expect(i == count - 1 || calm.at < BeatTimeline.eventAt(i + 1, count: count))
                }
            }
            let finale = cues.first { $0.kind == .finale }!.at, clean = cues.first { $0.kind == .cleanup }!.at
            #expect(finale >= BeatTimeline.total - 60 && finale < BeatTimeline.total && clean - finale == 20)
            #expect(cues.map(\.at) == cues.map(\.at).sorted())
            #expect(BeatTimeline.dots(count: count).allSatisfy { $0 > 0 && $0 < 1 })
        }
    }

    @Test func theRunFiresEachCueOnceAndKnowsWhatToShowAndPlay() {
        let events = [event(.calm, [.R1], "Captain, wave!"), event(.tense, [.R1, .R2], "Clouds! Captain, steer! Passenger, hold on!", calm: "Phew, smooth again."),
                      event(.calm, [.R2], "Passenger, look out the window!")]
        var run = BeatRun(events: events)
        #expect(run.due(at: 0).map(\.kind) == [.opener])
        #expect(run.due(at: 1).isEmpty)
        let e1 = run.eventAt(1)
        #expect(run.due(at: run.eventAt(0)).map(\.kind) == [.event(0)])
        #expect(run.due(at: run.eventAt(0) + 15).isEmpty)   // 2026-11-21: no automatic repeat
        #expect(run.due(at: e1 + 1).map(\.kind) == [.event(1)])
        #expect(run.display(at: e1 + 1) == .event(1) && run.music(at: e1 + 1) == .tense && run.face(at: e1 + 1) == .alarmed)
        #expect(run.display(at: e1 + 46) == .calmAgain(1) && run.music(at: e1 + 46) == .calm && run.face(at: e1 + 46) == .phew)
        #expect(run.display(at: e1 + 44) == .event(1))   // the tense card stays up until its calm-again
        #expect(run.display(at: e1 + 70) == .playing && run.face(at: e1 + 70) == .happyBob)
        #expect(run.display(at: e1 - 1) == .event(0))   // a calm card stays up until the next event
        #expect(run.display(at: run.eventAt(0) + 2) == .event(0) && run.face(at: run.eventAt(0) + 2) == .talkingPerked)
        #expect(run.music(at: 10) == .calm && run.display(at: 10) == .playing)
        #expect(run.display(at: run.finaleAt) == .finale && run.music(at: run.finaleAt) == .win && run.face(at: run.finaleAt) == .celebrate)
        // A hold-up: both events fire (no repeats any more).
        var late = BeatRun(events: events)
        _ = late.due(at: 0)
        let burst = late.due(at: e1 + 1).map(\.kind)
        #expect(burst == [.event(0), .event(1)])
        // A resume: everything up to the saved time has fired; nothing is said again.
        var back = BeatRun(events: events)
        back.restore(elapsed: e1 + 20)
        #expect(back.due(at: e1 + 20).isEmpty)
        #expect(back.due(at: e1 + 45).map(\.kind) == [.calmAgain(1)])
        #expect(back.progress(at: back.finaleAt / 2) == 0.5 && back.firedEvents(at: e1) == 2)
        var end = BeatRun(events: events)
        end.restore(elapsed: 0)
        let all = end.due(at: 10_000).map(\.kind)
        #expect(all.contains(.finale) && all.last == .cleanup && !all.contains(.opener))
    }

    @Test func theClockOnlyRunsWhilePlayingAndTheFastClockIsTenTimes() {
        var c = BeatClock()
        #expect(c.elapsed(now: 100) == 0 && !c.isRunning)
        c.start(now: 100)
        #expect(c.elapsed(now: 130) == 30)
        c.pause(now: 130)
        #expect(c.elapsed(now: 500) == 30 && !c.isRunning)
        c.start(now: 500); c.start(now: 600)   // a second start is ignored
        #expect(c.elapsed(now: 510) == 40)
        var fast = BeatClock(elapsed: 0, speed: BeatClock.fastSpeed)
        fast.start(now: 0)
        #expect(fast.elapsed(now: 60) == 600)   // the whole scene in about a minute
        var resumed = BeatClock(elapsed: 250)
        resumed.start(now: 7)
        #expect(resumed.elapsed(now: 8) == 251)
    }

    @Test func theMusicMixDucksAboutTwelveDecibelsAndHasABundleLayout() {
        let db = 20 * log10(Double(MusicMix.gain(speaking: true, chime: false) / MusicMix.gain(speaking: false, chime: false)))
        #expect(abs(db + 12) < 0.01)
        #expect(MusicMix.gain(speaking: false, chime: true) < MusicMix.base)
        #expect(MusicMix.file(.spaceAdventure, .calm) == "Music/space-adventure/calm.m4a")
        #expect(MusicMix.file(.cozyShop, .win) == "Music/cozy-shop/win.m4a" && MusicMix.file(.magical, .silent) == nil)
        #expect(MusicMix.chime == "Music/chime.m4a" && MusicMix.loops(.calm) && MusicMix.loops(.tense) && !MusicMix.loops(.win))
        #expect(MusicFamily.allCases.map(\.label).allSatisfy { !$0.isEmpty })
    }

    // MARK: The mic stays off for the whole Play phase (Haylee)

    @Test func theMicIsNeverAllowedDuringPlayOrTheEnd() {
        #expect(!PlayMic.allowed(.scene(0)) && !PlayMic.allowed(.scene(3)) && !PlayMic.allowed(.end))
        #expect(PlayMic.allowed(.pickGame) && PlayMic.allowed(.props) && PlayMic.allowed(.kitReady) && PlayMic.allowed(.players))
    }

    // MARK: The store's flow

    @Test func theStorePlaysSetupThenTheSceneThenCleanUp() async {
        let store = await storeAtSetup(players: 3)
        #expect(store.isOneSceneGame && store.currentArc == .setup && store.oneSceneChecklist == .setup)
        #expect(store.nutmegLine.hasSuffix(ChecklistScenes.tapHint) && store.nutmegLine.hasPrefix("Get the Plane Ready!"))
        // Voice "we're ready" before every card is done: not yet (the button is grey too).
        #expect(store.nutmegLine.contains(OneScene.badgeCue))   // the badges: everyone, once, in the cue
        // 2026-11-21 (Haylee): the big button is never blocked: what's left gets checked, then it goes on.
        let setup = store.currentChecklist!
        _ = store.toggleCheck(0)
        #expect(store.uncheckedRows == Array(setup.steps.indices.dropFirst()))
        store.checkAllRemaining()
        #expect(store.uncheckedRows.isEmpty && store.currentSceneDone && store.scenarioLine(1) == nil)   // no scenario on the setup
        store.nextScene()
        #expect(store.currentBeatScene != nil && store.currentChecklist == nil && store.beatTime == 0)
        #expect(store.sceneLine({ if case .scene(let i) = store.phase { return i } else { return 0 } }()) == nil)   // the clock says the opener
        #expect((await store.apply(.nextScene)) == AdventureStore.beatSceneToolOutput && store.currentBeatScene != nil)
        #expect((await store.apply(.previousScene)).hasPrefix("There's no scene before this one"))
        #expect(Realtime.afterHuntTools(store.phase, oneScene: true)?.contains("previous_scene") == false)
        #expect(Realtime.afterHuntTools(store.phase)?.contains("previous_scene") == true)   // older saved games
        #expect(ReplayLines.tools(store.phase, oneScene: true) == Realtime.afterHuntTools(store.phase, oneScene: true))
        store.nextScene()   // the finale's end opens the clean-up
        #expect(store.currentArc == .cleanup && store.oneSceneChecklist == .cleanup && store.nutmegLine.hasPrefix("Clean-up time"))
        // Voice "we're done" with nothing checked: the same as ▶ The End (it checks what's left and goes on).
        #expect(!store.currentSceneDone)
        _ = await store.apply(.nextScene)
        #expect(store.phase == .end)
    }

    @Test func resumeKeepsTheSceneTimeAndSchemaSevenSavesAndReplays() async throws {
        let store = await storeAtSetup(players: 4)
        store.markSaved(store.gameID)
        for k in store.currentChecklist!.steps.indices { _ = store.toggleCheck(k) }
        store.nextScene()
        store.beatTime = 222
        let point = try #require(store.resumePoint(now: Date(timeIntervalSince1970: 1_800_000_000)))
        #expect(point.sceneTime == 222)
        let json = try JSONSerialization.jsonObject(with: ResumePoint.encoder().encode(point)) as! [String: Any]
        #expect(Set(json.keys) == ResumePoint.allowedKeys)   // game content only
        let g = try #require(store.savedGame(id: store.gameID, art: [], cover: nil))
        #expect(g.schemaVersion == 7 && g.kit.isOneScene)
        let back = try SavedGame.decode(SavedGame.encoder().encode(g))
        #expect(back.kit == g.kit && back.id == g.id && back.schemaVersion == 7)
        let again = AdventureStore(service: nil)
        again.resumeReplay(back, at: try ResumePoint.decoder().decode(ResumePoint.self, from: ResumePoint.encoder().encode(point)))
        #expect(again.currentBeatScene != nil && again.beatTime == 222 && again.playerCount == 4)
        #expect(again.currentBeatScene?.beats == store.currentBeatScene?.beats)   // the same events on the replay
        // Outside the scene a resume point has no scene time.
        let s2 = await storeAtSetup(players: 2)
        s2.markSaved(s2.gameID)
        #expect(s2.resumePoint()?.sceneTime == nil)
        // An older resume point (no scene time) still decodes.
        let old = #"{"gameID":"\#(UUID().uuidString)","players":2,"scene":1,"progress":{"checked":{}},"savedAt":"2026-11-20T10:00:00Z"}"#
        #expect(try ResumePoint.decoder().decode(ResumePoint.self, from: Data(old.utf8)).sceneTime == nil)
        // A schema 6 checklist game still replays its own path.
        var six = g
        six.kit = Fallback.checklistAirplane(playerCount: 6).kit
        six.schemaVersion = 6
        let sixBack = try SavedGame.decode(SavedGame.encoder().encode(six))
        let r = AdventureStore(service: nil)
        r.loadReplay(sixBack)
        #expect(!r.isOneSceneGame && r.fullKit?.isChecklist == true)
    }

    @Test func theSafetyCheckSeesTheEventLines() {
        let sc = kit().scenes[0]
        #expect(sc.spokenTexts.contains(sc.beats!.finale) && sc.spokenTexts.contains(sc.beats!.events[1].calmAgain!))
        #expect(sc.spokenTexts.contains(sc.beats!.events[0].line))
    }
}
