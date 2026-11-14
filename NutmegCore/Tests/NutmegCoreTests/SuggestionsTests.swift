import Foundation
import Testing
@testable import NutmegCore

/// Round 7: fresh suggestions every session, open player count, no permission checks, spoken-only reminder.
struct SuggestionsTests {
    /// Deterministic RNG for repeatable samples.
    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }

    @Test func curatedListsAreBigAndUnique() {
        #expect(Suggestions.games.count >= 40)
        #expect(Suggestions.twists.count >= 30)
        #expect(Set(Suggestions.games.map(\.id)).count == Suggestions.games.count)
        #expect(Set(Suggestions.twists.map(\.id)).count == Suggestions.twists.count)
    }

    @Test func samplerReturnsThreeDistinctAndAvoidsLastPicks() {
        for seed in UInt64(1)...200 {
            var rng = SeededRNG(state: seed)
            let first = Suggestions.sample(Suggestions.games, using: &rng)
            #expect(first.count == 3 && Set(first).count == 3)
            let second = Suggestions.sample(Suggestions.games, avoiding: Set(first.map(\.id)), using: &rng)
            #expect(second.count == 3 && Set(second).count == 3)
            #expect(Set(first).isDisjoint(with: second))
            let twists = Suggestions.sample(Suggestions.twists, using: &rng)
            let next = Suggestions.sample(Suggestions.twists, avoiding: Set(twists.map(\.id)), using: &rng)
            #expect(Set(twists).count == 3 && Set(twists).isDisjoint(with: next))
        }
        // A tiny pool still returns 3 distinct items (topped up from the avoided ones).
        let tiny = [Suggestion("a", "a"), Suggestion("b", "b"), Suggestion("c", "c"), Suggestion("d", "d")]
        let p = Suggestions.sample(tiny, avoiding: ["a", "b"])
        #expect(p.count == 3 && Set(p).count == 3)
    }

    @Test func samplesVaryAcrossSessions() {
        var seen = Set<String>()
        for seed in UInt64(1)...30 { var rng = SeededRNG(state: seed); Suggestions.sample(Suggestions.games, using: &rng).forEach { seen.insert($0.id) } }
        #expect(seen.count > 20)
    }

    @Test func memoryStoresOnlyLastPickIDsAndAvoidsThem() throws {
        let suite = "pt.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let memory = SuggestionMemory(defaults: defaults)
        for _ in 0..<50 {
            let last = memory.lastGames
            let games = memory.pickGames()
            #expect(games.count == 3 && Set(last).isDisjoint(with: games.map(\.id)))
            #expect(memory.lastGames == Set(games.map(\.id)))
            let lastT = memory.lastTwists
            let twists = memory.pickTwists()
            #expect(Set(lastT).isDisjoint(with: twists.map(\.id)))
        }
        // Only the two ID lists are written.
        let keys = defaults.persistentDomain(forName: suite)?.keys.sorted() ?? []
        #expect(keys == ["pt.lastGamePicks", "pt.lastTwistPicks"])
    }

    @Test func instructionsCarryTodaysGames() {
        let games = [Suggestions.games[1], Suggestions.games[3], Suggestions.games[6]]
        let text = Realtime.instructions(todayGames: games)
        for g in games { #expect(text.contains(g.text)) }
        #expect(text.contains("suggest ONLY"))
        #expect(text.contains("If a kid says ANY other idea, happily take it"))
        let session = Realtime.sessionUpdate(voice: "coral", speed: 1, instructions: text)
        #expect(((session["session"] as? [String: Any])?["instructions"] as? String) == text)
        #expect(Realtime.instructions(todayGames: []) == Realtime.instructions)
    }

    @MainActor @Test func setGameResultCarriesTodaysThemes() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        let twists = [Suggestions.twists[0], Suggestions.twists[4], Suggestions.twists[9]]
        store.themeIdeas = twists
        let out = await store.apply(.setGame("Vet Clinic"))
        for t in twists { #expect(out.contains(t.text)) }
        #expect(out.contains("ONLY"))
        #expect(out.contains("their own theme, take it"))
    }

    @MainActor @Test func playerCountIsOpenAndRolesFlowIntoFirstProp() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Bakery"))
        let theme = await store.apply(.setTheme("Bakery on the Moon"))
        #expect(theme.contains("How many friends are playing today?"))
        #expect(theme.contains("never a list of numbers"))
        _ = await store.apply(.setPlayerCount(2))
        let roles = await store.apply(.setRoles([.init(roleName: "Baker", job: "bakes"), .init(roleName: "Customer", job: "buys")]))
        #expect(roles.contains("call show_next_prop for the FIRST prop"))
        #expect(!roles.contains("end with a quick"))
        #expect(!Realtime.instructions.contains("end with a quick \"Sound good?\""))
        #expect(!Realtime.instructions.contains("Is it just you, or two, or three friends?\"). Call"))
        #expect(Realtime.instructions.contains("How many friends are playing today?"))
        #expect(PlanningStep.players.goal.contains("How many friends are playing today?"))
        #expect(!PlanningStep.roles.goal.contains("end with"))
    }

    @Test func permissionChecksAreCaught() {
        #expect(TurnCheck.isPermissionCheck("sound good"))
        #expect(TurnCheck.isPermissionCheck("ready"))
        #expect(TurnCheck.isPermissionCheck("okay"))
        #expect(TurnCheck.isPermissionCheck("does that sound fun"))
        #expect(!TurnCheck.isPermissionCheck("can you find a plate"))
        #expect(!TurnCheck.isPermissionCheck("how many friends are playing today"))
        #expect(TurnCheck.nudge(for: "Captain and Pilot, yay! Ready?", step: .props) != nil)
        #expect(TurnCheck.nudge(for: "What should we play: a zoo, a farm, or a train? Okay?", step: .game) != nil)
        // The roles flowing straight into the first prop is fine.
        #expect(TurnCheck.nudge(for: "Our crew is a Baker and a Customer! First, can you find a bowl? It'll be our mixing bowl! Say 'found it' when you have it, or tell me if you don't.", step: .props) == nil)
    }

    @Test func rolesWithoutAPropContinueRightAway() {
        // Roles announced, no prop card yet: continue the SAME turn with the first prop (no waiting on the kid).
        let r = TurnCheck.review("You're the Baker and the Customer!", step: .props, rolesSet: true, propsShown: 0)
        #expect(r?.complete == true && r?.note.contains("show_next_prop") == true)
        let r2 = TurnCheck.review("You're the Baker and the Customer! Sound good?", step: .props, rolesSet: true, propsShown: 0)
        #expect(r2?.complete == true)
        // Once the prop is out, the normal checks apply.
        #expect(TurnCheck.review("Next, a stirrer! Can you find a spoon?", step: .props, rolesSet: true, propsShown: 2) == nil)
    }

    @Test func silenceReminderIsTheFixedSpokenLine() {
        #expect(TurnCheck.silenceLine == "Hold the red button whenever you're ready!")
        #expect(TurnCheck.silenceNudge(step: .theme) == TurnCheck.silenceLine)
        // Spoken out of band: not part of the conversation.
        let event = Realtime.sayExactly(TurnCheck.silenceLine)
        #expect(((event["response"] as? [String: Any])?["conversation"] as? String) == "none")
    }

    @Test func toolFlowRolesThenFirstPropBeforeSpeaking() {
        // start_planning (beat) → set_roles → show_next_prop → ONE spoken turn, with no kid turn in between.
        var g = ResponseGate()
        g.newTurn(); _ = g.request(); g.created()
        let r1 = g.done(allowFollowUp: false); #expect(!r1)      // start_planning: the beat holds the result
        g.forceFollowUp(); _ = g.request(); g.created()           // after the beat: set_roles (silent)
        let r2 = g.done(); #expect(r2)                            // still owes a spoken reply → follow-up
        g.created()                                               // show_next_prop (silent)
        let r3 = g.done(); #expect(r3)                            // still owes → follow-up
        g.created(); g.spoke()                                    // roles + first prop, spoken once
        let r4 = g.done(); #expect(!r4)
    }

    // MARK: Coordinator follow-ups (Haylee's live test of the first round-7 build)

    @Test func spokeThenStepToolGetsOneFollowUpWhenUnfinished() {
        // "Nice, that's perfect—let me grab the next prop." + mark_found, then nothing: must continue once.
        var g = ResponseGate()
        g.newTurn(); _ = g.request(); g.created(); g.spoke(); g.toolCalled()
        let r = g.done(spokenTurnIncomplete: true); #expect(r)
        g.created(); g.spoke()                      // the continuation: show_next_prop + the prop question
        let r2 = g.done(spokenTurnIncomplete: false); #expect(!r2)
        // Spoke a finished turn, then a tool: no repeat.
        var h = ResponseGate()
        h.newTurn(); _ = h.request(); h.created(); h.spoke(); h.toolCalled()
        let r3 = h.done(spokenTurnIncomplete: false); #expect(!r3)
        // Expression-only after speaking (no step tool): never a follow-up.
        var e = ResponseGate()
        e.newTurn(); _ = e.request(); e.created(); e.spoke()
        let r4 = e.done(spokenTurnIncomplete: true); #expect(!r4)
    }

    @MainActor @Test func countAnswerFlowsIntoRolesAndFirstPropCard() async {
        // count answer → set_player_count → (writing beat) → set_roles + show_next_prop → card on screen, then ONE spoken turn.
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Camping")); _ = await store.apply(.setTheme("Camping in a Toy Box"))
        var g = ResponseGate()
        g.newTurn(); _ = g.request(); g.created()
        _ = await store.apply(.setPlayerCount(3)); g.toolCalled()
        let afterCount = g.done(); #expect(afterCount)                       // nothing spoken yet → follow-up
        g.created()
        let roles = await store.apply(.setRoles([.init(roleName: "Lead Camper", job: "leads"), .init(roleName: "Story Camper", job: "tells"),
                                                 .init(roleName: "Gear Camper", job: "packs")])); g.toolCalled()
        #expect(roles.contains("show_next_prop"))
        // Roles set, no card yet: if she spoke now, the app continues with the first prop.
        #expect(TurnCheck.review("You're the Lead Camper, the Story Camper and the Gear Camper!", step: store.planningStep,
                                 rolesSet: store.plan != nil, propsShown: 0)?.complete == true)
        let r1 = await store.apply(.showNextProp(.init(itemID: "plate", becomes: "campfire ring", forRole: "all"))); g.toolCalled()
        #expect(r1.contains("FIRST prop") && store.props?.props.count == 1 && store.currentPropID == "plate")
        let afterTools = g.done(); #expect(afterTools)                       // outputs sent, then ONE follow-up
        g.created(); g.spoke()
        let end = g.done(); #expect(!end)
    }

    @MainActor @Test func foundItFlowsIntoNextPropCard() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setPlayerCount(1)); _ = await store.apply(.setRoles([.init(roleName: "Captain", job: "steer")]))
        _ = await store.apply(.showNextProp(.init(itemID: "plate", becomes: "wheel", forRole: "all")))
        #expect(!store.currentPropDone)
        _ = await store.apply(.markFound("plate"))
        #expect(store.currentPropDone)
        // She cheered and stopped ("let me grab the next prop."): the app continues with show_next_prop.
        let r = TurnCheck.review("Nice, that's perfect for our campfire—let me grab the next prop.", step: .props,
                                 rolesSet: true, propsShown: 1, currentPropDone: store.currentPropDone)
        #expect(r?.complete == true && r?.note.contains("show_next_prop") == true)
        _ = await store.apply(.showNextProp(.init(itemID: "pillow", becomes: "seat", forRole: "all")))
        #expect(store.props?.props.count == 2 && store.currentPropID == "pillow" && !store.currentPropDone)
    }

    @Test func narrationIsNeverAnEnding() {
        #expect(TurnCheck.isNarration("let me think about the theme choices next"))
        #expect(TurnCheck.isNarration("ooh, the toy box twist—let me set that up for our story"))
        #expect(TurnCheck.isNarration("awesome, let's keep the camp magic going—next prop coming up"))
        #expect(TurnCheck.needsCompletion(for: "Nice, that's perfect for our campfire—let me grab the next prop.", step: .props))
        #expect(TurnCheck.needsCompletion(for: "Ooh, the first one, got it—let me think about the theme choices next.", step: .theme))
        #expect(!TurnCheck.needsCompletion(for: "Ooh, a camping trip! Should it be for teddy bears, in a toy box, or in a cookie kingdom?", step: .theme))
        #expect(Realtime.instructions.contains("NEVER NARRATE"))
        #expect(Realtime.instructions.contains("the first one!"))
        #expect(Realtime.instructions.contains("Never name a prop out loud unless you called"))
    }

    @Test func outOfBandLinesHaveNoConversationContext() {
        let r = Realtime.sayExactly(TurnCheck.silenceLine)["response"] as? [String: Any]
        #expect((r?["input"] as? [Any])?.isEmpty == true)
        #expect(Realtime.json(Realtime.sayExactly("hi")).contains("\"input\":[]"))
    }

    @Test func leadInBeforeBeatStillGetsTheRolesAndPropReply() {
        // Seen live: "Okay, three friends..." + set_player_count → continuation → start_planning (beat) → set_roles →
        // show_next_prop, and then NOTHING was spoken (the lead-in had closed the turn).
        var g = ResponseGate()
        g.newTurn(); _ = g.request(); g.created(); g.spoke(); g.toolCalled()
        let a = g.done(spokenTurnIncomplete: true); #expect(a)          // continuation
        g.continueTurn(); g.created()                                   // start_planning
        let b = g.done(allowFollowUp: false); #expect(!b)               // the beat holds it
        g.forceFollowUp(); _ = g.request(); g.created(); g.toolCalled() // set_roles
        let c = g.done(); #expect(c)
        g.created(); g.toolCalled()                                     // show_next_prop (silent)
        let d = g.done(); #expect(d)                                    // still owes the spoken reply
        g.created(); g.spoke()
        let e = g.done(); #expect(!e)
        // A continuation that only calls show_next_prop still gets one spoken follow-up.
        var h = ResponseGate()
        h.newTurn(); _ = h.request(); h.created(); h.spoke(); h.toolCalled()
        let f = h.done(spokenTurnIncomplete: true); #expect(f)
        h.continueTurn(); h.created(); h.toolCalled()
        let k = h.done(); #expect(k)
    }

    @Test func narrationPhrasesSeenLiveAreCaught() {
        for line in ["Okay, we'll set this up for three players and then jump right into roles and our first prop.",
                     "Yay, perfect—let me line up the next piece of our castle setup.",
                     "Awesome, we're almost ready—one last moment while I wrap up your play kit.",
                     "Ooh, the first one, got it—let me think about the theme choices next.",
                     "Nice, that's perfect for our campfire—let me grab the next prop."] {
            #expect(TurnCheck.needsCompletion(for: line, step: .props), "\(line)")
            #expect(TurnCheck.nudge(for: line, step: .props) != nil, "\(line)")
        }
        #expect(Realtime.instructions.contains("one last moment while I wrap up your play kit"))
        #expect(Realtime.instructions.contains("Never say the kit is done"))
    }

    /// The whole planning tail: count → writing beat → set_roles + show_next_prop → ONE spoken roles + prop 1 turn with
    /// the card set → found it → prop 2 card + speech → found it → finish_planning → she stops (the app speaks the
    /// kit line, and the ready line only when the kit lands).
    @MainActor @Test func fullPlanningTail() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Castle")); _ = await store.apply(.setTheme("Castle with Friendly Monsters"))
        var g = ResponseGate()
        // Kid: "Three friends". Her first response: set_player_count (silent).
        g.newTurn(); _ = g.request(); g.created()
        let count = await store.apply(.setPlayerCount(3)); g.toolCalled()
        #expect(count.contains("start_planning"))
        let d1 = g.done(); #expect(d1)
        g.created()                                                    // start_planning → the writing beat
        let d2 = g.done(allowFollowUp: false); #expect(!d2)
        g.forceFollowUp(); _ = g.request(); g.created()                // after the beat
        _ = await store.apply(.setRoles([.init(roleName: "Knight", job: "guards"), .init(roleName: "Monster Guide", job: "guides"),
                                         .init(roleName: "Castle Helper", job: "helps")])); g.toolCalled()
        _ = await store.apply(.showNextProp(.init(itemID: "pillow", becomes: "the shield", forRole: "Knight"))); g.toolCalled()
        #expect(store.props?.props.count == 1 && store.currentPropID == "pillow")   // card state is set before she speaks
        // Choreography: this turn speaks ONLY the roles; the card + point + prop line come after it finishes playing.
        let first = AdventureStore.nextPropOutput(id: "pillow", item: "Pillow", becomes: "the shield", n: 1)
        #expect(first.contains("Speak ONLY the roles") && first.contains("Do NOT mention props, cards or the hunt"))
        let d3 = g.done(); #expect(d3)                                              // → the ONE spoken turn
        g.created(); g.spoke()                                         // "You're the Knight, the Monster Guide and the Castle Helper!"
        let rolesDone = g.done(allowFollowUp: false); #expect(!rolesDone)   // playback ends + 1 s → card shows, point
        g.forceFollowUp(); _ = g.request(); g.created(); g.spoke()      // the prop line, its own response
        #expect(AdventureStore.firstPropLine(item: "Pillow", becomes: "the shield").contains("First, can you find a pillow?"))
        #expect(TurnCheck.review("Our crew is a Knight, a Monster Guide and a Castle Helper! First, can you find a pillow? It'll be the shield! Say 'found it' when you have it, or tell me if you don't.",
                                 step: store.planningStep, rolesSet: true, propsShown: 1, currentPropDone: store.currentPropDone) == nil)
        let d4 = g.done(); #expect(!d4)
        // Kid: "Found it!" → mark_found + show_next_prop → speech.
        g.newTurn(); _ = g.request(); g.created()
        let found = await store.apply(.markFound("pillow")); g.toolCalled()
        #expect(found.contains("show_next_prop") && found.contains("FIRST"))
        _ = await store.apply(.showNextProp(.init(itemID: "blanket", becomes: "the castle floor", forRole: "all"))); g.toolCalled()
        #expect(store.props?.props.count == 2 && store.currentPropID == "blanket" && !store.currentPropDone)
        let d5 = g.done(); #expect(d5)
        g.created(); g.spoke(); let d6 = g.done(); #expect(!d6)
        // Kid: "Found it!" → mark_found + finish_planning: she stops; no follow-up.
        g.newTurn(); _ = g.request(); g.created()
        _ = await store.apply(.markFound("blanket")); g.toolCalled()
        let fin = await store.apply(.finishPlanning); g.endTurn()
        #expect(fin.contains("Say nothing"))
        let d7 = g.done(); #expect(!d7)
        #expect(store.planningStep == .finish)
    }

    @Test func goPlayOnlyInThePlayStep() {
        for line in ["All set! I'm making your play kit now—go have your submarine island adventure!",
                     "Heehee, you can dive into your submarine island adventure now!",
                     "We already wrapped the kit, so you can hop into the story now. Go play!"] {
            #expect(TurnCheck.mentionsGoPlay(line), "\(line)")
            #expect(TurnCheck.nudge(for: line, step: .props) != nil)
        }
        #expect(!TurnCheck.mentionsGoPlay(AdventureStore.kitReadyLine))
        #expect(AdventureStore.kitReadyLine.contains("Print"))
        #expect(Realtime.instructions.contains("NEVER say \"go play\""))
    }

    @Test func soundEffectsAsWordsAreFlagged() {
        for line in ["Hi, I'm Nutmeg, your tiny stage manager friend, giggle. What should we play: a zoo, a farm, or a bus ride?",
                     "Squeak! What should we play: a zoo, a farm, or a bus ride?",
                     "Eee! What should we play: a zoo, a farm, or a bus ride?",
                     "Friendly monsters, eep, so cute! How many friends are playing today?",
                     "Heehee, you're speedy! How many friends are playing today?",
                     "Teehee! How many friends are playing today?",
                     "*laughs* How many friends are playing today?"] {
            #expect(TurnCheck.hasSoundEffect(line), "\(line)")
            #expect(TurnCheck.nudge(for: line, step: .players) != nil, "\(line)")
        }
        for ok in ["Ooh! How many friends are playing today?", "Yay! Should it be on the moon, under the sea, or in a castle?",
                   "Can you find a sheet? It'll be the sail!", "Let's keep a steering wheel ready!"] {
            #expect(!TurnCheck.hasSoundEffect(ok), "\(ok)")
        }
        #expect(!Realtime.instructions.lowercased().contains("giggly"))
        #expect(!Realtime.instructions.contains("playful giggles"))
        #expect(Realtime.instructions.contains("NEVER SAY SOUND EFFECTS"))
    }

    @Test func kitProgressLines() {
        // Round 15: the picker lives in Round15LinesTests; here, the pool's wording rules.
        #expect(!KitProgress.allLines.contains { $0.lowercased().contains("roles") })
        for line in KitProgress.allLines {
            #expect(!TurnCheck.mentionsGoPlay(line) && !line.lowercased().contains("all set") && !line.lowercased().contains("ready"), "\(line)")
            #expect(!TurnCheck.hasSoundEffect(line), "\(line)")
        }
    }

    @Test func onePlanningLineIsAllowedOtherNarrationIsNot() {
        #expect(!TurnCheck.isNarration("great, let me put some plans together"))
        #expect(TurnCheck.isNarration("the first prop card is coming up next, so get ready to hunt for it"))
        #expect(TurnCheck.isNarration("alright, let's start the hunt with the very first prop"))
        #expect(TurnCheck.isNarration("nice, let me think about the next thing you'll hunt for"))
        #expect(Realtime.instructions.contains("let me put some"))
        #expect(Realtime.instructions.contains("You can pick anything!"))
        #expect(Realtime.instructions(todayGames: [Suggestions.games[0], Suggestions.games[1], Suggestions.games[2]]).contains("You can pick anything! Maybe"))
    }

    @Test func huntAnswersAreToolFirst() {
        let r = Realtime.responseCreate(requiring: Realtime.huntTools)["response"] as? [String: Any]
        #expect(r?["tool_choice"] as? String == "required")
        let names = (r?["tools"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        #expect(Set(names) == Set(Realtime.huntTools))
        #expect(!names.contains("set_expression"))
    }

    @Test func pretendThatPhraseIsInTheInstructions() {
        #expect(Realtime.instructions.contains("pretend that it's the treasure map"))
        #expect(Realtime.instructions.contains("about 1 prop in 3"))
        #expect(Prompts.system.contains("Pretend that a hungry customer just walked in!"))
    }

    @Test func everyKidTurnOnAStepIsToolFirst() {
        #expect(Realtime.kidTurnTools(step: .game, huntActive: false) == ["set_game", "show_game_ideas", "just_talk"])
        #expect(Realtime.kidTurnTools(step: .theme, huntActive: false)?.contains("set_theme") == true)
        #expect(Realtime.kidTurnTools(step: .players, huntActive: false) == ["set_player_count", "just_talk"])
        #expect(Realtime.kidTurnTools(step: .props, huntActive: true)?.contains("mark_found") == true)
        #expect(Realtime.kidTurnTools(step: .props, huntActive: false) == nil)
        for step in PlanningStep.allCases {
            #expect(!(Realtime.kidTurnTools(step: step, huntActive: true) ?? []).contains("set_expression"))
            #expect(!(Realtime.kidTurnTools(step: step, huntActive: true) ?? []).contains("start_planning"))
        }
        #expect(PlanningCall.decode(name: "just_talk", arguments: "{}") == .justTalk)
    }

    @MainActor @Test func printStepVoiceTools() async {
        #expect(PlanningCall.decode(name: "start_play", arguments: "{}") == .startPlay)
        #expect(PlanningCall.decode(name: "print_kit", arguments: "{}") == .printKit)
        let store = AdventureStore(service: nil)
        store.beginConversation()
        let early = await store.apply(.startPlay)
        #expect(early.contains("Almost ready") && store.phase == .pickGame)     // never before the kit exists
        #expect(AdventureStore.kitReadyLine == "Your kit is ready! Tap Print, or tell me when you're ready to play!")
        #expect(Realtime.instructions.contains("call start_play"))
        #expect(Realtime.instructions.contains("call print_kit"))
    }

    @Test func rolesAreSharedPartsNotAllForOneKid() {
        #expect(TurnCheck.assignsAllRolesToOne("You're the Train Driver, the Conductor, and the Passenger!"))
        #expect(TurnCheck.assignsAllRolesToOne("You’re the Captain and the Flight Attendant!"))
        #expect(!TurnCheck.assignsAllRolesToOne("Our crew is a Train Driver, a Conductor, and a Passenger! Pick who's who!"))
        #expect(!TurnCheck.assignsAllRolesToOne("You'll be the Train Driver!"))
        #expect(TurnCheck.nudge(for: "You're the Train Driver, the Conductor, and the Passenger! Can you find a box?", step: .props) != nil)
        #expect(TurnCheck.isNarration("all set! our crew is ready"))
        #expect(!Realtime.instructions.contains("It'll be our steering wheel"))
        #expect(Realtime.instructions.contains("Pick who's who!"))
        #expect(AdventureStore.nextPropOutput(id: "box", item: "Box", becomes: "the train", n: 1).contains("Pick who's who!"))
    }
}
