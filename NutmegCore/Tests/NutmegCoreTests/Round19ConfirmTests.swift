import Foundation
import Testing
@testable import NutmegCore

/// Round 19 (Haylee): a correction updates EVERYTHING (one source of truth), and the recap/confirm step.
struct Round19ConfirmTests {
    @Test func recapText() {
        #expect(ConfirmStep.recap(title: "Bug Movie Theater", playerCount: 3)
                == "So it's a bug movie theater for three friends! Say yes, or tell me what to change!")
        #expect(ConfirmStep.recap(title: "Ice Cream Truck", playerCount: 2).hasPrefix("So it's an ice cream truck for two friends!"))
        #expect(ConfirmStep.recap(title: "Pirate Ship", playerCount: 1) == "So it's a pirate ship, just for you! Say yes, or tell me what to change!")
        #expect(ConfirmStep.recap(title: "Dinosaur Explorers", playerCount: 4).hasPrefix("So it's dinosaur explorers for four friends!"))
        #expect(ConfirmStep.recap(title: "Castle with Friendly Monsters", playerCount: 3).hasPrefix("So it's a castle with friendly monsters"))
        #expect(ConfirmStep.recap(title: "The Great Bake Off", playerCount: 12).hasPrefix("So it's the great bake off for 12 friends!"))
        #expect(ConfirmStep.recap(title: "Circus on the Moon", playerCount: 2).hasPrefix("So it's a circus on the moon"))
        #expect(ConfirmStep.recap(title: "UFO Rescue", playerCount: 2).hasPrefix("So it's a UFO rescue"))
        // Round 26: voice only, so the recap ends by saying what to SAY; the turn check accepts it on the confirm step (not a "permission check").
        let r = ConfirmStep.recap(title: "Bug Movie Theater", playerCount: 3)
        #expect(TurnCheck.nudge(for: r, step: .confirm) == nil)
        #expect(TurnCheck.nudge(for: "So it's a bug movie theater for three friends!", step: .confirm) != nil)
        #expect(!TurnCheck.mentionsGoPlay(r))
    }

    @MainActor @Test func confirmStateMachine() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Movie Theater")); _ = await store.apply(.setTheme("Bus Movie Theater"))
        let count = await store.apply(.setPlayerCount(3))
        #expect(store.planningStep == .confirm && store.phase == .players)
        #expect(count.contains("So it's a bus movie theater for three friends!"))
        #expect(store.recapLine.hasPrefix("So it's a bus movie theater"))
        // Roles can't start before a yes.
        let early = await store.apply(.setRoles([.init(roleName: "Usher", job: "")]))
        #expect(early.contains("Not yet") && store.plan == nil && store.planningStep == .confirm)
        // A change at the confirm step: applied, recap again, still confirming.
        let fix = await store.apply(.setTheme("Bug Movie Theater"))
        #expect(store.gameTitle == "Bug Movie Theater" && store.planningStep == .confirm && store.playerCount == 3)
        #expect(fix.contains("So it's a bug movie theater for three friends!"))
        let fewer = await store.apply(.setPlayerCount(2))
        #expect(fewer.contains("for two friends") && store.planningStep == .confirm)
        let game = await store.apply(.setGame("Pirate Ship"))
        #expect(game.contains("So it's a pirate ship for two friends!") && store.planningStep == .confirm)
        // Yes → roles (round 26, Haylee: the color question is gone; coloring pages by default).
        let yes = await store.confirmYes()
        #expect(store.planningStep == .roles && yes.contains("start_planning") && yes.contains("exactly 6 ranked roles"))
        let again = await store.apply(.confirmPlan)
        #expect(again.contains("Already confirmed") && store.planningStep == .roles && store.currentPrintStyle == .colorIn)
        #expect(!Realtime.tools.contains { $0["name"] as? String == "set_print_style" } && PlanningCall.decode(name: "set_print_style", arguments: "{}") == nil)
        #expect(!Realtime.instructions.contains("3c.") && !Realtime.instructions.lowercased().contains("color question"))
        #expect(PlanningCall.decode(name: "confirm_plan", arguments: "{}") == .confirmPlan)
        #expect(Realtime.kidTurnTools(step: .confirm, huntActive: false) == ["confirm_plan", "set_game", "set_theme", "set_player_count", "just_talk"])
    }

    /// The real test: the kid fixed the theme WHILE answering the player count. Every later request uses the fix.
    @MainActor @Test func themeFixDuringPlayerCountReachesTheKit() async {
        let llm = FakeLLM(responses: ["Kit": Fallback.airplane.kit])
        let store = AdventureStore(service: PhaseService(llm: llm))
        store.beginConversation()
        _ = await store.apply(.setGame("Movie Theater")); _ = await store.apply(.setTheme("Bus Movie Theater"))
        // The model can call set_theme on the players step now (and its silent pass offers it).
        #expect(Realtime.kidTurnTools(step: .players, huntActive: false)?.contains("set_theme") == true)
        let fix = await store.apply(.setTheme("Bug Movie Theater"))
        #expect(store.planningStep == .players && fix.contains("how many friends"))
        _ = await store.apply(.setPlayerCount(3))
        #expect(store.recapLine.contains("bug movie theater"))
        _ = await store.confirmYes()
        _ = await store.apply(.setRoles([.init(roleName: "Usher", job: ""), .init(roleName: "Projectionist", job: ""), .init(roleName: "Snack Seller", job: "")]))
        _ = await store.apply(.showNextProp(.init(itemID: "box", becomes: "the ticket booth", forRole: "all")))
        #expect(store.plan?.gameTitle == "Bug Movie Theater" && store.currentTitle == "Bug Movie Theater")
        _ = await store.apply(.finishPlanning)
        for _ in 0..<100 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(10)) }
        let kitPrompt = llm.users.last ?? ""
        // Round 20: the pages were written during the hunt, the play guide when it ended: both for the fixed title.
        let pagesPrompt = llm.users.first { $0.contains("Phase: printable kit pages") } ?? ""
        #expect(pagesPrompt.contains("Bug Movie Theater") && !pagesPrompt.contains("Bus Movie"))
        #expect(kitPrompt.contains("Phase: the play guide") && kitPrompt.contains("Bug Movie Theater") && !kitPrompt.contains("Bus Movie"))
        #expect(store.context.plan?.gameTitle == "Bug Movie Theater")
    }

    /// Round 28 (Haylee): after the yes, the game and theme can't change (the roles and props stay); only the count can.
    @MainActor @Test func lateFixRedoesRolesAndProps() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Train")); _ = await store.apply(.setTheme("Snowy Train"))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
        _ = await store.apply(.setRoles([.init(roleName: "Conductor", job: ""), .init(roleName: "Passenger", job: "")]))
        _ = await store.apply(.showNextProp(.init(itemID: "hat", becomes: "conductor's cap", forRole: "Conductor")))
        #expect(store.huntActive)
        let out = await store.apply(.setTheme("Jungle Train"))
        #expect(out.contains("Refused") && out.contains("Our game stays Snowy Train! But you can change how many friends are playing."))
        #expect(store.plan != nil && store.props != nil && store.huntActive && store.gameTitle == "Snowy Train")
        let game = await store.apply(.setGame("Pirate Ship"))
        #expect(game.contains("Refused") && store.gameTitle == "Snowy Train")
        // The count still changes, with no remake.
        let count = await store.apply(.setPlayerCount(3))
        #expect(count.contains("Nothing is remade") && store.playerCount == 3 && store.plan != nil)
    }

    /// Round 28: at the print step and in play too, the game stays (no remake); the count changes with no AI call.
    @MainActor @Test func fixAtPrintStepRemakesTheKit() async {
        let llm = FakeLLM(responses: ["Kit": Fallback.airplane.kit])
        let store = AdventureStore(service: PhaseService(llm: llm))
        store.beginConversation()
        _ = await store.apply(.setGame("Shop")); _ = await store.apply(.setTheme("Toy Shop"))
        _ = await store.apply(.setPlayerCount(1)); _ = await store.confirmYes()
        _ = await store.apply(.setRoles([.init(roleName: "Shopkeeper", job: "")]))
        _ = await store.apply(.finishPlanning)
        for _ in 0..<100 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(store.phase == .kitReady)
        let remakes = store.kitRemakes, calls = llm.calls
        let out = await store.apply(.setTheme("Candy Shop"))
        #expect(out.contains("Refused") && out.contains("Our game stays Toy Shop!"))
        #expect(store.kitRemakes == remakes && store.kit != nil && store.gameTitle == "Toy Shop" && llm.calls == calls)
        let count = await store.apply(.setPlayerCount(3))
        #expect(count.contains("Nothing is remade") && store.playerCount == 3 && llm.calls == calls && store.phase == .kitReady)
        store.beginPlay()
        let late = await store.apply(.setTheme("Pet Shop"))
        #expect(late.contains("Refused") && store.gameTitle == "Toy Shop")
    }

    @Test func outputSuffixNeverFightsAWordForWordLine() {
        #expect(Realtime.outputSuffix(name: "set_theme", output: ConfirmStep.recapAgainOutput(what: "x", recap: "r"), spokeFirst: false) == "")
        #expect(Realtime.outputSuffix(name: "confirm_plan", output: "Confirmed", spokeFirst: false) == "")
        #expect(Realtime.outputSuffix(name: "set_game", output: "Game set: Zoo.", spokeFirst: false).contains("Speak once now"))
        #expect(Realtime.outputSuffix(name: "set_roles", output: "", spokeFirst: false).contains("show_next_prop"))
        #expect(Realtime.instructions.contains("CORRECTIONS (before the yes)"))
        #expect(Realtime.instructions.contains("3b. CONFIRM"))
        let desc = Realtime.json(["t": Realtime.tools])
        #expect(desc.contains("If the kid corrects it at ANY point later"))
    }
}
