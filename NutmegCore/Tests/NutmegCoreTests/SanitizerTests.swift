import Testing
@testable import NutmegCore

@Test func sanitizerClampsKit() {
    let k = Sanitizer.clean(Fixture.oversizedKit, playerCount: 2)
    #expect(k.items.count == 1)   // six ticket-sized items fill only the one tickets slot of the recipe
    #expect(k.items[0].recipe == .tickets)
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

@Test func kitRecipeOrderAndShape() {
    func item(_ id: String, _ r: KitRecipe?, size: KitSize = .fullPage) -> KitItem {
        KitItem(id: id, recipe: r, kind: .sheet, size: size, title: id, symbol: "star", lines: ["x"], bigNumber: "9", perPlayer: false, copies: 5, colorMe: true)
    }
    let shuffled = [item("cut", .cutouts), item("menu", .menu), item("money", .money), item("money2", .money),
                    item("badge", .badges), item("sign", .sign), item("ticket", .tickets, size: .keycard)]
    let k = Sanitizer.clean(Kit(nutmegSays: "", items: shuffled, scenes: []), playerCount: 2)
    #expect(k.items.map(\.id) == ["badge", "sign", "money", "ticket", "menu", "cut"])
    #expect(k.items[0].size == .badge && k.items[0].perPlayer && k.items[0].bigNumber == nil)
    #expect(k.items[2].size == .bill && k.items[2].copies == 8)
    #expect(k.items[3].size == .keycard && k.items[3].perPlayer)       // keycards allowed for tickets
    #expect(k.items[5].size == .fullPage && !k.items[5].perPlayer)
    #expect(Validate.kit(Kit(nutmegSays: "", items: Array(k.items.prefix(3)), scenes: [])).map(\.fatal) == false)   // missing types → corrective retry
}
