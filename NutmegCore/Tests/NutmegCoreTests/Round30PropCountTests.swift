import Testing
@testable import NutmegCore

/// Round 30 (Haylee): a firm 4 props for 1–2 kids and 5 for 3 or more.
@MainActor
struct Round30PropCountTests {
    private func hunt(players: Int) async -> AdventureStore {
        let store = AdventureStore(service: nil)
        store.holdsEarlyFinish = true
        store.beginConversation()
        _ = await store.apply(.setGame("Castle")); _ = await store.apply(.setTheme("Castle with Friendly Monsters"))
        _ = await store.apply(.setPlayerCount(players))
        _ = await store.confirmYes()
        _ = await store.apply(.setRoles([.init(roleName: "Knight", job: "guards"), .init(roleName: "Monster Guide", job: "guides"),
                                         .init(roleName: "Castle Helper", job: "helps")]))
        return store
    }
    private let items: [(String, String)] = [("pillow", "the shield"), ("blanket", "the castle floor"), ("bowl", "the knight's helmet"),
                                             ("cardboard-box", "the treasure chest"), ("spoon", "the magic wand"), ("towel", "the cape")]

    @Test func targetByPlayers() {
        #expect(PropLibrary.target(players: 1) == 4)
        #expect(PropLibrary.target(players: 2) == 4)
        #expect(PropLibrary.target(players: 3) == 5)
        #expect(PropLibrary.target(players: 6) == 5)
    }

    @Test func twoKidsGetExactlyFourProps() async {
        let store = await hunt(players: 2)
        #expect(store.propTarget == 4)
        for (i, it) in items.prefix(3).enumerated() {
            let out = await store.apply(.showNextProp(.init(itemID: it.0, becomes: it.1, forRole: "all")))
            #expect(out.contains("prop \(i + 1) of 4"))
            let found = await store.apply(.markFound(it.0))
            #expect(found.contains("show_next_prop") && !found.contains("finish_planning"))
        }
        // An early finish is held: the next prop comes first.
        let early = await store.apply(.finishPlanning)
        #expect(early.contains("Not yet") && store.planningStep == .props)
        let fourth = await store.apply(.showNextProp(.init(itemID: items[3].0, becomes: items[3].1, forRole: "all")))
        #expect(fourth.contains("LAST prop"))
        let fifth = await store.apply(.showNextProp(.init(itemID: items[4].0, becomes: items[4].1, forRole: "all")))
        #expect(fifth.contains("finish_planning") && store.props?.props.count == 4)   // no fifth card
        let found = await store.apply(.markFound(items[3].0))
        #expect(found.contains("finish_planning"))
        _ = await store.apply(.finishPlanning)
        #expect(store.planningStep == .finish)
    }

    @Test func threeKidsGetFiveProps() async {
        let store = await hunt(players: 3)
        #expect(store.propTarget == 5)
        for it in items.prefix(4) {
            _ = await store.apply(.showNextProp(.init(itemID: it.0, becomes: it.1, forRole: "all")))
            _ = await store.apply(.markFound(it.0))
        }
        let skipped = await store.apply(.showNextProp(.init(itemID: items[4].0, becomes: items[4].1, forRole: "all")))
        #expect(skipped.contains("prop 5 of 5"))
        let skip = await store.apply(.skipProp(items[4].0))
        #expect(skip.contains("finish_planning"))
        #expect(store.props?.props.count == 5)
    }

    @Test func aStuckModelNeverHoldsTheKit() async {
        let store = await hunt(players: 3)
        _ = await store.apply(.showNextProp(.init(itemID: "pillow", becomes: "the shield", forRole: "all")))
        _ = await store.apply(.finishPlanning); _ = await store.apply(.finishPlanning)
        #expect(store.planningStep == .props)
        _ = await store.apply(.finishPlanning)   // the third time it goes through
        #expect(store.planningStep == .finish)
    }

    @Test func coachingFollowsTheTarget() {
        #expect(TurnCheck.review("Yay!", step: .props, rolesSet: true, propsShown: 3, currentPropDone: true, propTarget: 4)?.note.contains("prop 4 of 4") == true)
        #expect(TurnCheck.review("Yay!", step: .props, rolesSet: true, propsShown: 4, currentPropDone: true, propTarget: 4)?.note.contains("finish_planning") == true)
        #expect(Realtime.instructions.contains("Exactly 4 props for 1 or 2 kids, 5 props for 3 or more"))
        #expect(Prompts.props(ctx: AdventureContext(playerCount: 3)).contains("Pick exactly 5"))
        #expect(Prompts.props(ctx: AdventureContext(playerCount: 2)).contains("Pick exactly 4"))
    }
}
