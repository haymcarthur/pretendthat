import Testing
@testable import NutmegCore

@Test func sanitizerClampsKit() {
    let k = Sanitizer.clean(Fixture.oversizedKit, playerCount: 2)
    #expect(k.items.count == 4)
    #expect(k.scenes.count == 6)
    #expect(k.scenes.allSatisfy { $0.steps.count <= 5 })
    #expect(k.items.allSatisfy { (1...8).contains($0.copies) })
    #expect(k.items[0].symbol == "star")
    #expect(k.scenes.allSatisfy { $0.owner == .all || $0.owner == .P1 || $0.owner == .P2 })
}

@Test func propsDropUnsafe() {
    let p = Sanitizer.clean(Fixture.propsWithUnsafe)
    #expect(p.props.allSatisfy { $0.safetyOK })
    #expect(p.props.count == 2)
}

@Test func planKeepsOneRolePerPlayer() {
    let roles = PlayerToken.allCases.map { Role(player: $0, roleName: "R", emoji: "⭐️", symbol: "bogus", job: "j") }
    let plan = Sanitizer.clean(GamePlan(gameTitle: "Airplane", gameEmoji: "✈️", setting: "sky", roles: roles + roles, nutmegSays: "Hi"), playerCount: 3)
    #expect(plan.roles.map(\.player) == [.P1, .P2, .P3])
    #expect(plan.roles.allSatisfy { $0.symbol == "star" })
}

@Test func ideasCappedAtThree() {
    let ideas = (0..<5).map { GameIdea(id: "\($0)", title: "t", emoji: "⭐️", pitch: "p") }
    #expect(Sanitizer.clean(GameIdeas(nutmegSays: "Hi", ideas: ideas)).ideas.count == 3)
}

@Test func turnChoicesCappedAtFour() {
    let c = (0..<6).map { Choice(id: "\($0)", label: "l", emoji: "⭐️") }
    #expect(Sanitizer.clean(NutmegTurn(nutmegSays: "Hi", choices: c, understood: true)).choices.count == 4)
}
