import Foundation
import Testing
@testable import NutmegCore

/// Round 19 (Haylee): a correction updates EVERYTHING (one source of truth), and the recap/confirm step.
struct Round19ConfirmTests {
    @Test func recapText() {
        #expect(ConfirmStep.recap(title: "Bug Movie Theater", playerCount: 3)
                == "So it's a bug movie theater for three friends! Ready, or want to change something?")
        #expect(ConfirmStep.recap(title: "Ice Cream Truck", playerCount: 2).hasPrefix("So it's an ice cream truck for two friends!"))
        #expect(ConfirmStep.recap(title: "Pirate Ship", playerCount: 1) == "So it's a pirate ship, just for you! Ready, or want to change something?")
        #expect(ConfirmStep.recap(title: "Dinosaur Explorers", playerCount: 4).hasPrefix("So it's dinosaur explorers for four friends!"))
        #expect(ConfirmStep.recap(title: "Castle with Friendly Monsters", playerCount: 3).hasPrefix("So it's a castle with friendly monsters"))
        #expect(ConfirmStep.recap(title: "The Great Bake Off", playerCount: 12).hasPrefix("So it's the great bake off for 12 friends!"))
        #expect(ConfirmStep.recap(title: "Circus on the Moon", playerCount: 2).hasPrefix("So it's a circus on the moon"))
        #expect(ConfirmStep.recap(title: "UFO Rescue", playerCount: 2).hasPrefix("So it's a UFO rescue"))
        // One short sentence + the one question; the turn check accepts it on the confirm step (not a "permission check").
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
        // Yes → the color question (round 20) → roles.
        let yes = await store.apply(.confirmPlan)
        #expect(store.planningStep == .color && yes.contains(ColorChoice.question))
        let again = await store.apply(.confirmPlan)
        #expect(again.contains("Already confirmed") && store.planningStep == .color)
        let color = await store.apply(.setPrintStyle(.colorIn))
        #expect(store.planningStep == .roles && color.contains("start_planning") && color.contains("exactly 2 roles"))
        #expect(PlanningCall.decode(name: "confirm_plan", arguments: "{}") == .confirmPlan)
        #expect(ConfirmStep.yesTapNote(playerCount: 2).contains("don't call confirm_plan"))
        #expect(Realtime.kidTurnTools(step: .confirm, huntActive: false) == ["confirm_plan", "set_game", "set_theme", "set_player_count", "set_print_style", "just_talk"])
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
        _ = await store.apply(.confirmPlan); _ = await store.apply(.setPrintStyle(.colorIn))
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

    /// A fix after the roles and props were made: they're cleared, the count is kept, and the recap comes again.
    @MainActor @Test func lateFixRedoesRolesAndProps() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Train")); _ = await store.apply(.setTheme("Snowy Train"))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.apply(.confirmPlan); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles([.init(roleName: "Conductor", job: ""), .init(roleName: "Passenger", job: "")]))
        _ = await store.apply(.showNextProp(.init(itemID: "hat", becomes: "conductor's cap", forRole: "Conductor")))
        #expect(store.huntActive)
        #expect(Realtime.kidTurnTools(step: .props, huntActive: true)?.contains("set_theme") == true)
        let out = await store.apply(.setTheme("Jungle Train"))
        #expect(store.plan == nil && store.props == nil && store.playerCount == 2 && !store.huntActive)
        #expect(store.planningStep == .confirm && store.presenting == .none)
        #expect(out.contains("redo the roles and props") && out.contains("So it's a jungle train for two friends!"))
        // Even a plan made from a stale title stays in step with the current one.
        _ = await store.apply(.confirmPlan); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles([.init(roleName: "Explorer", job: ""), .init(roleName: "Driver", job: "")]))
        #expect(store.context.plan?.gameTitle == "Jungle Train" && store.context.gameTitle == "Jungle Train")
    }

    /// A fix while the kit waits to print: the kit is remade for the new title (and said out loud); after play starts
    /// the adventure stays as printed.
    @MainActor @Test func fixAtPrintStepRemakesTheKit() async {
        let llm = FakeLLM(responses: ["Kit": Fallback.airplane.kit])
        let store = AdventureStore(service: PhaseService(llm: llm))
        store.beginConversation()
        _ = await store.apply(.setGame("Shop")); _ = await store.apply(.setTheme("Toy Shop"))
        _ = await store.apply(.setPlayerCount(1)); _ = await store.apply(.confirmPlan); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles([.init(roleName: "Shopkeeper", job: "")]))
        _ = await store.apply(.finishPlanning)
        for _ in 0..<100 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(store.phase == .kitReady)
        let remakes = store.kitRemakes
        let out = await store.apply(.setTheme("Candy Shop"))
        #expect(out.contains("remaking the kit") && out.contains("Say nothing"))
        #expect(store.kitRemakes == remakes + 1 && store.kit == nil)
        for _ in 0..<100 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(store.phase == .kitReady && store.kit != nil)
        #expect(store.nutmegLine == AdventureStore.remakeLine("Candy Shop") && store.nutmegLine.contains("a candy shop"))
        #expect(llm.users.last?.contains("Candy Shop") == true)
        let count = await store.apply(.setPlayerCount(3))
        #expect(count.contains("New game") && store.playerCount == 1)
        store.beginPlay()
        let late = await store.apply(.setTheme("Pet Shop"))
        #expect(late.contains("New game") && store.gameTitle == "Candy Shop")
    }

    @Test func outputSuffixNeverFightsAWordForWordLine() {
        #expect(Realtime.outputSuffix(name: "set_theme", output: ConfirmStep.recapAgainOutput(what: "x", recap: "r"), spokeFirst: false) == "")
        #expect(Realtime.outputSuffix(name: "confirm_plan", output: "Confirmed", spokeFirst: false) == "")
        #expect(Realtime.outputSuffix(name: "set_game", output: "Game set: Zoo.", spokeFirst: false).contains("Speak once now"))
        #expect(Realtime.outputSuffix(name: "set_roles", output: "", spokeFirst: false).contains("show_next_prop"))
        #expect(Realtime.instructions.contains("CORRECTIONS AT ANY POINT"))
        #expect(Realtime.instructions.contains("3b. CONFIRM"))
        let desc = Realtime.json(["t": Realtime.tools])
        #expect(desc.contains("If the kid corrects it at ANY point later"))
    }
}
