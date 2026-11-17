import Foundation
import Testing
@testable import NutmegCore

/// Round 28 (Haylee): customers are roles too (1), one role per checklist (4a), props must be real (4b), and after the
/// confirm "yes" the game and theme stay, only the count changes (6).
@MainActor struct Round28Tests {
    static func role(_ name: String, _ job: String = "") -> Role { Role(id: .R1, roleName: name, emoji: "", symbol: "star", job: job) }

    // MARK: 1. Customers are roles too

    @Test(arguments: ["Customer", "VIP Customer", "Pet Owner", "Passengers", "Hotel Guest", "Zoo Visitor", "Patient",
                      "Audience Member", "Hungry Diner"])
    func customerTitlesAreCustomers(_ t: String) { #expect(CustomerRoles.isCustomer(t)) }

    @Test(arguments: ["Stand Manager", "Recipe Mixer", "Cup Filler", "Sign Artist", "Shop Owner", "Pilot", "Vet", "Mail Carrier"])
    func workerTitlesAreNotCustomers(_ t: String) { #expect(!CustomerRoles.isCustomer(t)) }

    @Test func gamesFindTheirCustomerKind() {
        #expect(CustomerRoles.kind(forGame: "Lemonade Stand on the Moon")?.primary.name == "Customer")
        #expect(CustomerRoles.kind(forGame: "Animal Doctor")?.primary.name == "Pet Owner")
        #expect(CustomerRoles.kind(forGame: "Pet Shop")?.primary.name == "Customer")
        #expect(CustomerRoles.kind(forGame: "Airplane to the Beach")?.primary.name == "Passenger")
        #expect(CustomerRoles.kind(forGame: "Post Office in a Fairy Forest")?.primary.name == "Customer")
        #expect(CustomerRoles.kind(forGame: "Bug Movie Theater")?.primary.name == "Audience Member")
        #expect(CustomerRoles.kind(forGame: "Pirate Ship") == nil)
    }

    @Test func aWorkersOnlyShopGetsACustomerAtR2AndInTheExtras() {
        // Haylee's bug: Stand Manager, Recipe Mixer, Cup Filler, Sign Artist… and no customers.
        let ranked = RoleCast.rank(["Stand Manager", "Recipe Mixer", "Cup Filler", "Sign Artist", "Ice Chipper", "Lemon Squeezer"].map { Self.role($0) })
        let out = CustomerRoles.arrange(ranked, game: "Lemonade Stand")
        #expect(out.map(\.id) == RoleID.allCases)
        #expect(out[0].roleName == "Stand Manager" && out[1].roleName == "Customer")
        #expect(out.filter { CustomerRoles.isCustomer($0.roleName) }.count >= 2)          // the extras mix workers and customers
        #expect(out.dropFirst(2).contains { !CustomerRoles.isCustomer($0.roleName) })
        #expect(Set(out.map { $0.roleName.lowercased() }).count == 6)
        #expect(CustomerRoles.arrange(out, game: "Lemonade Stand") == out)                // idempotent
    }

    @Test func aCustomerTheModelRankedLowMovesUpToR2() {
        let ranked = RoleCast.rank(["Pilot", "Flight Attendant", "Co-Pilot", "Passenger", "Snack Chef", "VIP Passenger"].map { Self.role($0) })
        let out = CustomerRoles.arrange(ranked, game: "Airplane")
        #expect(out.map(\.roleName) == ["Pilot", "Passenger", "Flight Attendant", "Co-Pilot", "Snack Chef", "VIP Passenger"])
        // A vet's counterpart.
        let vet = CustomerRoles.arrange(RoleCast.rank(["Vet", "Nurse", "Receptionist"].map { Self.role($0) }), game: "Vet Clinic")
        #expect(vet[1].roleName == "Pet Owner")
        // A game with no customers keeps its roles.
        let pirates = RoleCast.rank(["Captain", "Navigator", "Cook"].map { Self.role($0) })
        #expect(CustomerRoles.arrange(pirates, game: "Pirate Ship") == pirates)
    }

    @Test func setRolesInTheStoreAnnouncesTheCustomer() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Lemonade Stand")); _ = await store.apply(.setTheme("Lemonade Stand on the Moon"))
        _ = await store.apply(.setPlayerCount(3)); _ = await store.confirmYes()
        let out = await store.apply(.setRoles(["Stand Manager", "Recipe Mixer", "Cup Filler", "Sign Artist"].map { .init(roleName: $0, job: "") }))
        #expect(store.playingRoles.map(\.roleName) == ["Stand Manager", "Customer", "Recipe Mixer"])
        #expect(out.contains("We need a Stand Manager, a Customer and a Recipe Mixer!"))
    }

    @Test func thePromptsAskForCustomers() {
        #expect(Prompts.system.contains("customers, visitors, guests, passengers, patients and pet owners are roles too"))
        #expect(Prompts.system.contains("Shopkeeper + Customer, Pilot + Passenger, Vet + Pet Owner"))
        #expect(Prompts.plan(game: "Shop", ctx: AdventureContext(gameTitle: "Shop", playerCount: 2)).contains("customer counterpart of R1"))
        #expect(Realtime.instructions.contains("CUSTOMERS ARE ROLES TOO"))
        #expect(Realtime.json(["t": Realtime.tools]).contains("Pilot + Passenger"))
        #expect(ConfirmStep.confirmedOutput(playerCount: 2).contains("Shopkeeper + Customer"))
        #expect(Prompts.sceneRules.contains("Customers, visitors, guests, passengers and patients get real things to do"))
    }

    // MARK: 4a. One role per checklist

    @Test func eachSceneEveryPlayingRoleGetsAHandOffAndOnlyItsOwnSteps() async {
        let a = Fallback.airplane
        for n in 1...6 {
            let view = PlayCast.kit(a.kit, roles: a.plan.roles, players: n)
            for (si, scene) in a.kit.scenes.enumerated() {
                let turns = Array(view.scenes[(si * n)..<(si * n + n)])
                #expect(turns.map(\.owner.role) == Array(RoleID.allCases.prefix(n)))      // every playing role, every scene
                #expect(turns.allSatisfy { $0.title == scene.title })
                for t in turns {
                    #expect(t.steps.count == 2 && t.steps.allSatisfy { $0.role == t.owner })
                    #expect(!t.steps.contains { $0.text.hasPrefix("Everyone") })
                }
            }
        }
        // In the store: a hand-off before every turn (3 players), never two turns in a row for the same role.
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setPlayerCount(3)); _ = await store.confirmYes()
        _ = await store.apply(.setRoles(a.plan.roles.map { .init(roleName: $0.roleName, job: $0.job) }))
        _ = await store.apply(.finishPlanning)
        for _ in 0..<100 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(10)) }
        store.autoCheckStep = .zero; store.autoCheckHold = .zero
        store.beginPlay()
        var holders: [RoleID] = []
        for _ in 0..<40 where store.phase != .end {
            guard case .handoff(let i) = store.phase, let o = store.kit?.scenes[i].owner.role else { Issue.record("no hand-off: \(store.phase)"); break }
            _ = await store.apply(.confirmHandoff)
            guard case .scene(let j) = store.phase, let sc = store.kit?.scenes[j] else { break }
            #expect(sc.steps.allSatisfy { $0.role.role == o })
            holders.append(o)
            await store.sceneDone()
        }
        #expect(store.phase == .end && holders.count == a.kit.scenes.count * 3)
        #expect(zip(holders, holders.dropFirst()).allSatisfy { $0 != $1 })
    }

    @Test func laterTurnsOfASceneStartAtTheRolesFirstStep() {
        let a = Fallback.airplane
        let turns = PlayCast.turns(a.kit.scenes[0], index: 0, roles: a.plan.roles, players: 2)
        #expect(PretendLine.has(turns[0].nutmegSays) && turns[1].nutmegSays.isEmpty)
        let line = HandOffLines.checklist(sceneLine: turns[1].nutmegSays, firstScene: false, firstStep: turns[1].steps.first?.text)
        #expect(line.hasPrefix("First, ") && !line.contains("Pretend that"))
        // The role title keeps its capitals (seen live: "First, stand Manager, put on your badge!").
        #expect(ChecklistCheers.phrase("Stand Manager, put on your badge!") == "Stand Manager, put on your badge")
        #expect(ChecklistCheers.phrase("Everyone, wave!") == "everyone, wave")
    }

    // MARK: 4b. Props must be real

    static let props: [Prop] = [
        Prop(id: "box", householdItem: "Cardboard box", becomes: "Lemonade stand", forRole: .R1, safetyOK: true, libraryID: "cardboard-box"),
        Prop(id: "cup", householdItem: "Plastic cup", becomes: "Lemonade cups", forRole: .R2, safetyOK: true, libraryID: "cup", skipped: true),
    ]
    static var items: [KitItem] {
        var items = Fallback.airplane.kit.items
        if let m = items.firstIndex(where: { $0.recipe == .menu }) { items[m].lines = ["Lemonade $2", "Ice pop $1"] }
        return items
    }
    static let roles = RoleCast.rank(["Stand Manager", "Customer", "Bell Ringer"].map { Round28Tests.role($0) })
    var allowed: Set<String> { GuideRepair.allowedWords(props: Self.props, items: Self.items) }

    @Test func aStepNamingAMissingObjectBecomesAPretendAction() {
        // Haylee's bug: "ring the bell" when no bell was ever a prop.
        #expect(GuideRepair.missingObjects("Stand Manager, ring the bell!", allowed: allowed, roles: Self.roles) == ["bell"])
        let step = Step(picture: .action("ring-bell"), text: "Stand Manager, ring the bell!", role: .R1)
        let fixed = GuideRepair.realStep(step, allowed: allowed, allowedPropIDs: ["box", "cardboard-box"], roles: Self.roles)
        #expect(fixed.text == "Stand Manager, ring the pretend bell!")
        #expect(fixed.picture == .point && fixed.role == .R1)
        #expect(GuideRepair.realStep(fixed, allowed: allowed, allowedPropIDs: [], roles: Self.roles) == fixed)   // idempotent
        // Plurals and several at once.
        let two = GuideRepair.realStep(Step(picture: .point, text: "Customer, count the coins into a basket", role: .R2),
                                       allowed: allowed, allowedPropIDs: [], roles: Self.roles)
        #expect(two.text == "Customer, count the pretend coins into a pretend basket")
    }

    @Test func realThingsAndBodyActionsAreLeftAlone() {
        let ok = ["Stand Manager, set up the lemonade stand!",          // a found prop, by what it becomes
                  "Customer, sip from the pretend lemonade cups!",       // a ✗ prop's pretend stand-in
                  "Customer, pay with the money!", "Customer, show your ticket!", "Customer, read the menu!",
                  "Stand Manager, pour the lemonade!",                   // printed on the menu
                  "Bell Ringer, wave hello!",                            // a role title is not an object
                  "Customer, stamp your feet!", "Stand Manager, pretend to ring a bell!",
                  "Customer, hold up the cake menu!"]                    // a modifier of a printed page
        for t in ok { #expect(GuideRepair.missingObjects(t, allowed: allowed, roles: Self.roles).isEmpty, "\(t)") }
    }

    @Test func aPropPictureOfSomethingTheKidsDontHaveIsDropped() {
        let ids: Set<String> = ["box", "cardboard-box"]
        let a = GuideRepair.realStep(Step(picture: .prop("cup"), text: "Customer, take a pretend lemonade cup", role: .R2),
                                     allowed: allowed, allowedPropIDs: ids, roles: Self.roles)
        #expect(a.picture == .point)
        let b = GuideRepair.realStep(Step(picture: .prop("cardboard-box"), text: "Stand Manager, open the lemonade stand", role: .R1),
                                     allowed: allowed, allowedPropIDs: ids, roles: Self.roles)
        #expect(b.picture == .prop("cardboard-box"))
    }

    @Test func theRepairFixesEveryGuideThatLandsAndReplays() {
        var scenes = Fallback.airplane.kit.scenes
        scenes[1].steps[0] = Step(picture: .action("ring-bell"), text: "Captain, ring the bell for takeoff!", role: .R1)
        let a = Fallback.airplane
        let fixed = GuideRepair.repair(scenes, roles: a.plan.roles, props: a.props.props, title: "Airplane", items: a.kit.items)
        #expect(fixed[1].steps[0].text == "Captain, ring the pretend bell for takeoff!" && fixed[1].steps[0].picture == .point)
        #expect(GuideRepair.repair(fixed, roles: a.plan.roles, props: a.props.props, title: "Airplane", items: a.kit.items) == fixed)
        // The bundled game names only real things.
        #expect(GuideRepair.repair(a.kit.scenes, roles: a.plan.roles, props: a.props.props, title: "Airplane", items: a.kit.items) == a.kit.scenes)
        // A replay's saved guide is checked at load (no AI call).
        let store = AdventureStore(service: nil)
        let g = SavedGame(createdAt: Date(), title: "Airplane", roles: a.plan.roles, props: a.props.props.map(SavedProp.init),
                          kit: Kit(nutmegSays: "", items: a.kit.items, scenes: scenes), printStyle: .fullColor, art: [], voiceID: VoiceConfig.nutmeg.voiceID)
        store.loadReplay(g)
        #expect(store.fullKit?.scenes[1].steps[0].text == "Captain, ring the pretend bell for takeoff!")
    }

    @Test func theGuidePromptsSayOnlyRealProps() {
        #expect(Prompts.sceneRules.contains("ONLY REAL PROPS"))
        #expect(Prompts.sceneRules.contains("No steps for everyone"))
        #expect(Prompts.system.contains("Steps name ONLY objects the kids really have"))
    }

    // MARK: 6. After the yes: the game stays, only the count changes

    private func confirmed(_ store: AdventureStore) async {
        store.beginConversation()
        _ = await store.apply(.setGame("Post Office")); _ = await store.apply(.setTheme("Post Office in a Fairy Forest"))
        _ = await store.apply(.setPlayerCount(2))
    }

    @Test func beforeTheYesCorrectionsStillWork() async {
        let store = AdventureStore(service: nil)
        await confirmed(store)
        #expect(store.planningStep == .confirm && !store.gameLocked)
        let out = await store.apply(.setTheme("Post Office on the Moon"))
        #expect(!out.contains("Refused") && store.gameTitle == "Post Office on the Moon")
    }

    @Test func afterTheYesTheGameAndThemeAreRefused() async {
        let store = AdventureStore(service: nil)
        await confirmed(store)
        _ = await store.confirmYes()
        #expect(store.gameLocked)
        for call in [PlanningCall.setGame("Pirate Ship"), .setTheme("Make it a pirate ship")] {
            let out = await store.apply(call)
            #expect(out.contains("Refused") && out.contains("\"Our game stays Post Office in a Fairy Forest! But you can change how many friends are playing.\""))
            #expect(store.gameTitle == "Post Office in a Fairy Forest")
        }
        #expect(Realtime.instructions.contains("AFTER THE KIDS SAY YES"))
    }

    @Test func backToPickNamesTheGameAndTheCountChangesWithNoAICall() async {
        let llm = FakeLLM()
        let store = AdventureStore(service: PhaseService(llm: llm))
        await confirmed(store)
        _ = await store.confirmYes()
        _ = await store.apply(.setRoles(["Mail Carrier", "Customer", "Stamp Sorter"].map { .init(roleName: $0, job: "") }))
        _ = await store.apply(.finishPlanning)
        for _ in 0..<300 where store.phase != .kitReady || store.guidePending { try? await Task.sleep(for: .milliseconds(10)) }
        let calls = llm.calls
        // Voice "back to pick": she names the game and asks the count.
        let out = await store.apply(.goToStep(.game))
        #expect(store.phase == .players)
        #expect(out.contains("\"We're playing Post Office in a Fairy Forest! How many friends are playing now?\""))
        #expect(store.arrivalLine(.game) == "We're playing Post Office in a Fairy Forest! How many friends are playing now?")
        #expect(BackNav.tapNote(.game, line: store.arrivalLine(.game)).contains("call set_player_count"))
        // "We have four now": the count changes, nothing is remade.
        let four = await store.apply(.setPlayerCount(4))
        #expect(four.contains("Nothing is remade") && four.contains("Four friends!") && store.playerCount == 4)
        // "Make it a pirate ship": refused.
        let pirate = await store.apply(.setGame("Pirate Ship"))
        #expect(pirate.contains("Refused") && store.currentTitle == "Post Office in a Fairy Forest")
        #expect(llm.calls == calls)
        #expect(Realtime.pickBackTools.contains("set_player_count") && Realtime.pickBackTools.contains("set_game"))
    }
}
