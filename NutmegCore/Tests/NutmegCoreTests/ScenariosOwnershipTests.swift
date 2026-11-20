import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-21 (Haylee, decisions/2026-11-21-events-are-scenarios-and-ownership.md; build:
/// decisions/2026-11-21-round-scenarios-ownership-build.md): events are scenarios, the event card stays up with a
/// hear-again (no automatic repeat), one owner per object, prop stand-ins, the pretend name in items, the new music
/// families, End scene, never-blocked checklist buttons, speakable lines, the music on/off level.
@MainActor
struct ScenariosOwnershipTests {
    let a = Fallback.oneSceneAirplane(playerCount: 6)
    var roles: [Role] { a.plan.roles }
    var props: [Prop] { a.props.props }

    func kit(props: [Prop]? = nil) -> Kit {
        var k = a.kit
        k.scenes = GuideRepair.repair(k.scenes, roles: roles, props: props ?? self.props, title: "Sky Airlines", items: k.items)
        return Bookends.repair(k, props: props ?? self.props, roles: roles, title: "Sky Airlines").kit
    }

    // MARK: 1. Events are scenarios

    @Test func gestureOnlyEventsAreCaughtAndScenariosPass() {
        for bad in ["Pilot, point your hand forward and zoom the ship!", "Captain, make a silly wobbly face!",
                    "Navigator, wiggle your finger to draw a path!", "Captain, wave to everyone!", "Everyone, clap your hands!",
                    "Co-Pilot, give a thumbs-up!", "Passenger, nod and smile!"] {
            #expect(EventScenario.isGestureOnly(bad, roles: roles), "\(bad)")
        }
        for good in ["A space cloud is in the way! Navigator, use the map to help the Captain find a new path.",
                     "The ship is wobbly! Everyone, make everything secure!",
                     "There's a big lunch rush! Quick, Waiter, take the new people to their seats, and Cook, get ready to make more food!",
                     "Engineer, use the Space Stuff to give the engine a pretend fix!",
                     "Captain, wave to the people below, then tell everyone how high we are!"] {
            #expect(!EventScenario.isGestureOnly(good, roles: roles), "\(good)")
        }
        // Every app-written scenario passes both checks, for every mood and index.
        for mood in BeatMood.allCases {
            for i in 0..<6 {
                let line = EventScenario.appLine(mood: mood, who: "Captain", index: i)
                #expect(!EventScenario.isGestureOnly(line, roles: roles) && Speakable.isSpeakable(line), "\(line)")
            }
        }
        // The repair swaps a gesture-only event for the app's scenario event for the same role (calm-again unchanged).
        let fixed = OneScene.repairEvent(BeatEvent(mood: .tense, roles: [.R4], line: "Co-Pilot, make a silly wobbly face!",
                                                   calmAgain: "Phew, the plane is steady again."), roles: roles)
        #expect(fixed?.roles == [.R4] && fixed?.appWritten == true && fixed?.line.hasPrefix("Co-Pilot, ") == true)
        #expect(fixed.map { !EventScenario.isGestureOnly($0.line, roles: roles) } == true)
        #expect(fixed?.calmAgain == "Phew, the plane is steady again.")
        // The bundled pool is all scenarios (demo data), and the prompt carries good and bad examples.
        let pool = kit().scenes[0].beats!.events
        #expect(pool.count == 12 && pool.allSatisfy { !EventScenario.isGestureOnly($0.line, roles: roles) && $0.appWritten != true })
        let prompt = OneScene.prompt(ctx: AdventureContext(gameTitle: "Rocket", playerCount: 2), items: a.kit.items)
        #expect(prompt.contains("GOOD events") && prompt.contains("BAD events") && prompt.contains("Point your hand forward"))
    }

    @Test func theOpenerSetsTheScene() {
        for generic in ["Get ready!", "Pretend that the game is starting!", "Okay, let's go!", "", "Pretend that it's the big moment!"] {
            #expect(EventScenario.isGenericOpener(generic), "\(generic)")
        }
        #expect(!EventScenario.isGenericOpener("Pretend that the plane is taking off over the big blue ocean!"))
        #expect(EventScenario.opener(story: "Welcome to Sky Airlines, the friendliest airline! You are the crew.", title: "x")
                == "Pretend that we're at Sky Airlines! Everyone, take your places!")
        #expect(EventScenario.opener(story: nil, title: "Moon Bakery") == "Pretend that we're at the Moon Bakery! Everyone, take your places!")
        // The repair makes a generic opener a real one (from the game title), idempotently.
        var sc = a.kit.scenes[0]
        sc.beats?.opener = "Get ready, everyone!"
        let fixed = OneScene.repair(sc, roles: roles, props: props, title: "Sky Airlines", items: a.kit.items)
        #expect(fixed.beats?.opener == "Pretend that we're at the Sky Airlines! Everyone, take your places!")
        #expect(OneScene.repair(fixed, roles: roles, props: props, title: "Sky Airlines", items: a.kit.items) == fixed)
    }

    // MARK: 2. No automatic repeat; the card stays up; End scene

    @Test func theCardStaysUpUntilTheNextCueAndThereIsNoRepeat() {
        let events = [BeatEvent(mood: .calm, roles: [.R1], line: "Captain, check the map and plan the trip!"),
                      BeatEvent(mood: .tense, roles: [.R2], line: "Uh-oh, Passenger, things are wobbly! Make everything secure!", calmAgain: "Phew."),
                      BeatEvent(mood: .calm, roles: [.R1, .R2], line: "Captain and Passenger, serve the snacks!")]
        var run = BeatRun(events: events)
        let kinds = run.cues.map(\.kind)
        #expect(kinds == [.opener, .event(0), .event(1), .calmAgain(1), .event(2), .finale, .cleanup])
        let e0 = run.eventAt(0), e1 = run.eventAt(1), e2 = run.eventAt(2)
        #expect(run.display(at: e0) == .event(0) && run.display(at: e1 - 0.1) == .event(0))   // calm: until the next event
        #expect(run.display(at: e1 + BeatTimeline.calmAgainAfter - 0.1) == .event(1))         // tense: until its calm-again
        #expect(run.display(at: e1 + BeatTimeline.calmAgainAfter) == .calmAgain(1))
        #expect(run.display(at: e1 + BeatTimeline.calmAgainAfter + BeatRun.calmAgainShows) == .playing)
        #expect(run.display(at: run.finaleAt - 0.1) == .event(2) && run.eventEnds(2) == run.finaleAt)   // the last: until the finale
        #expect(run.display(at: e2) == .event(2))
        // Each cue once.
        #expect(run.due(at: e0 + 30).map(\.kind) == [.event(0)])   // the opener is dropped once an event is due
        #expect(run.due(at: e0 + 60).isEmpty)
    }

    @Test func endSceneJumpsToTheFinaleAndSurvivesAResume() {
        let events = OneScene.cadence(4).enumerated().map { i, m in
            BeatEvent(mood: m, roles: [.R1], line: "Captain, check the map and plan trip \(i)!", calmAgain: m == .tense ? "Phew." : nil)
        }
        var run = BeatRun(events: events)
        _ = run.due(at: 200)
        let t = run.endEarly(at: 200)
        #expect(t == run.finaleAt)
        // Nothing before the finale is said any more; the finale fires now, then the clean-up 20 s later.
        #expect(run.due(at: t).map(\.kind) == [.finale])
        #expect(run.display(at: t) == .finale && run.music(at: t) == .win && run.face(at: t) == .celebrate)
        #expect(run.due(at: t + 19).isEmpty && run.due(at: t + 20).map(\.kind) == [.cleanup])
        // Past the finale it changes nothing.
        var late = BeatRun(events: events)
        #expect(late.endEarly(at: late.finaleAt + 5) == late.finaleAt + 5)
        // A relaunch after End scene (the resume point keeps the finale's time) lands at the finale and goes on.
        var back = BeatRun(events: events)
        back.restore(elapsed: t)
        #expect(back.display(at: t) == .finale && back.due(at: t + 20).map(\.kind) == [.cleanup])
    }

    // MARK: 3. One owner per object

    @Test func everyObjectHasExactlyOneOwnerAtEveryCount() {
        var skipped = props; skipped[1].skipped = true
        let extra = props + [Prop(id: "ball", householdItem: "Ball", becomes: "the planet", forRole: .R5, safetyOK: true, libraryID: "ball"),
                             Prop(id: "sock", householdItem: "Sock", becomes: "the sock puppet", forRole: .R6, safetyOK: true, libraryID: "sock")]
        for list in [props, skipped, extra, []] {
            let k = kit(props: list)
            let items = Bookends.coverItems(items: k.items, props: list)
            for n in 1...6 {
                let scenes = PlayCast.kit(k, roles: roles, players: n, props: list).scenes
                let setup = scenes[1]
                #expect(OneSceneCoverage.exactlyOnce(scenes, items: items),
                        "\(n): \(OneSceneCoverage.counts(scenes, items: items)) \(setup.steps.map { "\($0.role.rawValue): \($0.short ?? "")" })")
                // No job twice across cards; 2 to 3 items per card (a solo kid may need more rows, pairs).
                let shorts = setup.steps.map { ($0.short ?? "").lowercased() }
                #expect(Set(shorts).count == shorts.count, "\(n): \(shorts)")
                for card in ChecklistScenes.cards(setup) { #expect(card.rows.count >= 2 && (n == 1 || card.rows.count <= 3), "\(n)") }
                // The owners are fair: objects per role differ by at most one, and props per role too.
                let owners = ObjectOwners.assign(items, guideSteps: k.scenes[0].steps, roles: roles, players: n)
                let playing = Array(RoleID.allCases.prefix(n))
                let per = playing.map { r in owners.values.filter { $0 == r }.count }
                let propsPer = playing.map { r in owners.filter { $0.key.hasPrefix("prop:") && $0.value == r }.count }
                #expect((per.max() ?? 0) - (per.min() ?? 0) <= 1 && (propsPer.max() ?? 0) - (propsPer.min() ?? 0) <= 1, "\(n): \(per) \(propsPer)")
                #expect(owners.values.allSatisfy(playing.contains) && owners["page:badges"] == nil)
                // Clean-up: each prop put away by its owner; the print mess once.
                let clean = scenes[3]
                for it in items where it.prop != nil {
                    let row = clean.steps.first { $0.picture == .prop(it.prop!.libraryID ?? it.prop!.id) }
                    #expect(row?.role.role == owners[it.id], "\(n): \(it.id)")
                }
                #expect(clean.steps.filter { $0.short == OneScene.printMessShort }.count == 1)
                // Every line on a card or read aloud is speakable.
                for sc in scenes { for line in sc.spokenTexts { #expect(Speakable.isSpeakable(line), "\(n): \(line)") } }
            }
        }
    }

    @Test func jobsWrittenForHiddenRolesFoldIntoVisibleCardsOnce() {
        // The guide gives R5 and R6 the menu and the money, and R1 ALSO names the menu (the duplicate Haylee saw).
        var k = kit()
        k.scenes[0].steps.append(Step(picture: .point, text: "Set out the snack menu", role: .R1, short: "Set out the snack menu"))
        let items = Bookends.coverItems(items: k.items, props: props)
        for n in 1...4 {
            let scenes = PlayCast.kit(k, roles: roles, players: n, props: props).scenes
            #expect(OneSceneCoverage.exactlyOnce(scenes, items: items), "\(n): \(OneSceneCoverage.counts(scenes, items: items))")
            let menu = scenes[1].steps.filter { ($0.short ?? "").lowercased().contains("menu") }
            #expect(menu.count == 1 && (menu.first?.role.role?.rank ?? 9) <= n, "\(n)")
            #expect(scenes[1].steps.allSatisfy { ($0.role.role?.rank ?? 9) <= n })
        }
        // The guide's own owner is kept when it's fair (6 kids: the menu stays with the Snack Chef).
        let six = ObjectOwners.assign(Bookends.coverItems(items: kit().items, props: props), guideSteps: kit().scenes[0].steps, roles: roles, players: 6)
        #expect(six["page:menu"] == .R5 && six["page:sign"] == .R1 && six["prop:plate"] == .R1 && six["prop:backpack"] == .R6)
        // The badges are said once, to everyone, in the setup cue.
        #expect(OneScene.setupCue(kit().scenes[0]).contains(OneScene.badgeCue))
        #expect(!OneScene.setupCue(kit().scenes[0], badges: false).contains("badge"))
    }

    // MARK: 4. Prop stand-ins

    @Test func everyPropHasBelievableStandInsAndTheCuratedPairsPass() {
        #expect(Set(PropStandIns.table.map(\.id)) == Set(PropLibrary.ids) && PropStandIns.table.count == PropLibrary.ids.count)
        for row in PropStandIns.table { #expect((10...15).contains(row.standIns.count), "\(row.id)") }
        for (id, uses) in PropLibrary.uses { for u in uses { #expect(PropStandIns.allows(id, u.becomes), "\(id) → \(u.becomes)") } }
        #expect(PropStandIns.allows("sock", "the sock puppet") && PropStandIns.allows("ball", "the planet") && PropStandIns.allows("bowl", "the captain's hat"))
        #expect(!PropStandIns.allows("sock", "the planet") && !PropStandIns.allows("books", "the planet"))
        #expect(PropStandIns.betterProps(for: "the planet").first == "ball")
        // The hunt: a sock as a planet becomes the ball (when allowed), else the sock's closest stand-in (a snowball).
        let better = PropStandIns.settle(itemID: "sock", becomes: "the planet", avoiding: [])
        #expect(better?.itemID == "ball" && better?.becomes == "the planet")
        let own = PropStandIns.settle(itemID: "sock", becomes: "the planet", avoiding: Set(PropStandIns.betterProps(for: "the planet")))
        #expect(PropStandIns.settle(itemID: "sock", becomes: "the planet", avoiding: ["ball"])?.itemID == "paper-plate")   // the next prop that lists it
        #expect(own?.itemID == "sock" && own.map { PropStandIns.allows("sock", $0.becomes) } == true)
        #expect(PropStandIns.settle(itemID: "sock", becomes: "the sock puppet", avoiding: []) == nil)
        #expect(PropStandIns.settle(itemID: "free-text-thing", becomes: "the planet", avoiding: []) == nil)
        // The guide's item: "Hold up the planet" for a sock puppet becomes the prop's own pretend name.
        let sock = Prop(id: "sock", householdItem: "Sock", becomes: "the sock puppet", forRole: .R1, safetyOK: true, libraryID: "sock")
        #expect(PropStandIns.itemText("Hold up the planet", prop: sock) == "Hold up the sock puppet")
        #expect(PropStandIns.itemText("Wiggle the sock puppet", prop: sock) == "Wiggle the sock puppet")
        #expect(PropStandIns.promptNote(sock).contains("snake"))
        let weave = GuideWeave.prompt(scenes: kit().scenes, props: [sock], taken: [], roles: roles, players: 2)
        #expect(weave.contains("ONLY allowed pretend uses") && weave.contains("never the word pretend"))
        // The review file is generated from the table (checked where the design folder is next to the package).
        let md = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../design/prop-stand-ins.md")
        if let text = try? String(contentsOf: md, encoding: .utf8) { #expect(text == PropStandIns.markdown()) }
    }

    // MARK: 5. Wording

    @Test func itemsUseThePretendNameOnly() {
        let sock = Prop(id: "sock", householdItem: "Sock", becomes: "the planet", forRole: .R1, safetyOK: true, libraryID: "sock")
        #expect(PropWording.clean("Hold up your sock pretend planet", props: [sock]) == "Hold up the planet")
        #expect(PropWording.clean("Put on the pretend crown", props: []) == "Put on the crown")
        #expect(PropWording.clean("Hold your sock as a puppet", props: [sock]) == "Hold the puppet")
        #expect(PropWording.clean("Set up sock pretend planet", props: [sock]) == "Set up planet")
        #expect(PropWording.clean("Put on your badge", props: [sock]) == "Put on your badge")
        let once = PropWording.clean("Hold up your sock pretend planet", props: [sock])
        #expect(PropWording.clean(once, props: [sock]) == once)
        // A skipped prop's guide wording ("pretend snack cart") reads as the pretend name in the setup card.
        var skipped = props; skipped[2].skipped = true
        let k = kit(props: skipped)
        for n in 1...6 {
            let setup = PlayCast.kit(k, roles: roles, players: n, props: skipped).scenes[1]
            #expect(setup.steps.allSatisfy { !($0.short ?? "").lowercased().contains("pretend") && !$0.text.lowercased().contains("pretend") }, "\(n)")
        }
    }

    // MARK: 6. Music families and the on/off level

    @Test func theNewMusicFamiliesAndTheMuteLevel() {
        #expect(MusicFamily.allCases.count == 10)
        #expect(MusicFamily.parse("superhero-city") == .superheroCity && MusicFamily.parse("Pirate adventure") == .pirateAdventure
                && MusicFamily.parse("rescue_team") == .rescueTeam)
        #expect(MusicFamily.guess("Superhero City Patrol") == .superheroCity && MusicFamily.guess("Treasure Island") == .pirateAdventure)
        #expect(MusicFamily.guess("Fire Truck Rescue") == .rescueTeam && MusicFamily.guess("Mermaid Lagoon") == .underTheSea)
        #expect(MusicFamily.guess("Pirate Cove") == .pirateAdventure)   // "pirate" moved off Under the sea
        #expect(MusicFamily.superheroCity.label == "Superhero city" && MusicFamily.pirateAdventure.label == "Pirate adventure"
                && MusicFamily.rescueTeam.label == "Rescue team")
        #expect(OneScene.rules.contains("superhero-city") && OneScene.rules.contains("rescue-team"))
        #expect(MusicMix.file(.pirateAdventure, .calm) == "Music/pirate-adventure/calm.m4a")
        // Music off: silent, whatever else is going on (her voice and the chime are separate players).
        #expect(MusicMix.gain(speaking: false, chime: false, muted: true) == 0 && MusicMix.gain(speaking: true, chime: true, muted: true) == 0)
        #expect(MusicMix.gain(speaking: false, chime: false) == MusicMix.base && !MusicMix.musicOnKey.isEmpty)
    }

    // MARK: 10. Speakable

    @Test func everyLineOnACardIsSpeakable() {
        #expect(!Speakable.isSpeakable("Pick up paper scraps, crayons and scissors") && Speakable.isSpeakable(OneScene.printMessShort))
        #expect(Speakable.repair("Pick up paper scraps, crayons and scissors") == "Pick up paper scraps and crayons")
        #expect(Speakable.repair("Put away the crayons and scissors") == "Put away the crayons")
        #expect(Speakable.repair("Put the scissors and glue away") == "Put the glue away")
        #expect(Speakable.repair("Chef, cut it with the knife!") == "Chef, cut it with the spoon!")
        #expect(Speakable.repair("Knight, hold up your sword!") == "Knight, hold up your wand!")
        #expect(Speakable.isSpeakable("Firefighter, drive the fire truck to the rescue!"))
        let fixed = Speakable.repair("Pick up paper scraps, crayons and scissors")
        #expect(Speakable.repair(fixed) == fixed && Speakable.isSpeakable(fixed))
        // Every app-written template passes.
        var app: [String] = [OneScene.printMessShort, OneScene.printMessSay, OneScene.badgeCue, ChecklistScenes.tapHint,
                             "Put on your badge", "Get in your spot", "Give high fives"] + OneScene.calmAgainLines
        app += EventScenario.calmTemplates + EventScenario.tenseTemplates
        for r in KitRecipe.allCases {
            let it = CoverItem(id: "page:\(r.rawValue)", label: "the thing", names: [], purpose: nil, recipe: r)
            app += [Bookends.fallbackSetup(it).short, Bookends.fallbackSetup(it).say, Bookends.fallbackCleanup(it).short, Bookends.fallbackCleanup(it).say]
        }
        for line in app { #expect(Speakable.isSpeakable(line), "\(line)") }
        // An unsafe guide line is repaired before it's shown (the card and the voice say the same words).
        var sc = a.kit.scenes[0]
        sc.beats?.events[0].line = "The control tower is calling! Captain, grab the scissors and fix the steering wheel!"
        let rep = OneScene.repair(sc, roles: roles, props: props, title: "Sky Airlines", items: a.kit.items)
        #expect(rep.spokenTexts.allSatisfy(Speakable.isSpeakable))
    }
}
