import Testing
@testable import NutmegCore

/// Round C1: every game has 6 ranked roles; `n` kids play the first n.
func cast(_ n: Int) -> [Role] {
    RoleCast.rank(["Captain", "Flight Attendant", "Co-Pilot", "Passenger"].enumerated().map {
        Role(id: RoleID.allCases[$0.offset], roleName: $0.element, emoji: "", symbol: "star", job: "")
    })
}

func kitItem(_ id: String, size: KitSize, perPlayer: Bool = false, copies: Int = 1) -> KitItem {
    KitItem(id: id, kind: size == .fullPage ? .sheet : .card, size: size, title: id, symbol: "star", lines: [], bigNumber: nil, perPlayer: perPlayer, copies: copies, colorMe: true)
}

@Test func perKidTicketsHaveBlankNamesAndFillTheSheet() {
    let kit = Kit(nutmegSays: "", items: [kitItem("t", size: .ticket, perPlayer: true)], scenes: [])
    let pages = KitLayout.pages(for: kit, roles: cast(3), playerCount: 3)
    #expect(pages.count == 1)
    // Tickets belong to no one (kids write their own names); seats keep counting into the spares.
    #expect(pages[0].slots.allSatisfy { $0.roleID == nil && $0.role == nil })
    #expect(pages[0].slots.map(\.index) == Array(0..<8))
}

@Test func smallItemsFillEveryPageExceptBadges() {
    for r in KitRecipe.allCases {
        var item = kitItem(r.rawValue, size: r.size, perPlayer: r.perPlayer, copies: r == .money ? 8 : 1)
        item.recipe = r
        for n in 1...Players.max {
            let roles = cast(n)
            let pages = KitLayout.pages(for: Kit(nutmegSays: "", items: [item], scenes: []), roles: roles, playerCount: n)
            let cap = KitLayout.grid(for: r.size).capacity
            if r == .badges {
                // Round 23: exactly one badge per kid (never spares).
                #expect(pages.flatMap(\.slots).count == n, "badges with \(n) kids")
                #expect(pages.flatMap(\.slots).compactMap(\.roleID) == Array(RoleID.allCases.prefix(n)))
            } else {
                #expect(pages.allSatisfy { $0.slots.count == cap }, "\(r) with \(n) kids")
            }
        }
    }
}

@Test func moneyPromptHasNoNameField() {
    var item = kitItem("money", size: .bill, copies: 8); item.recipe = .money
    let p = KitArtPrompt.prompt(for: item, gameTitle: "Cafe").lowercased()
    #expect(p.contains("no name field"))
    #expect(!p.contains("blank white rounded banner"))
}

@Test func badgesSixPerPage() {
    let kit = Kit(nutmegSays: "", items: [kitItem("b", size: .badge, copies: 8)], scenes: [])
    let pages = KitLayout.pages(for: kit, roles: cast(1), playerCount: 1)
    #expect(pages.map(\.slots.count) == [6, 6])
}

@Test func capsAtSevenPages() {
    let items = [kitItem("a", size: .ticket, copies: 20), kitItem("b", size: .badge, copies: 20),
                 kitItem("c", size: .bill, copies: 20), kitItem("d", size: .keycard, copies: 20)]
    let pages = KitLayout.pages(for: Kit(nutmegSays: "", items: items, scenes: []), roles: cast(1), playerCount: 1)
    #expect(pages.count == KitLayout.maxPages && KitLayout.maxPages == 7)
    #expect(Set(pages.map(\.item.id)) == ["a", "b", "c", "d"])
}

@Test func badgesAreTheFirstNRankedRolesOneEach() {
    // Round C1: 6 ranked roles; N kids print the first N badges, slot k = role Rk (its slice of the badge sheet).
    var badge = kitItem("badge", size: .badge, perPlayer: true); badge.recipe = .badges
    let roles = cast(6)
    #expect(roles.count == 6 && roles.allSatisfy { $0.count == 1 })
    for n in 1...6 {
        let slots = KitLayout.pages(for: Kit(nutmegSays: "", items: [badge], scenes: []), roles: roles, playerCount: n).flatMap(\.slots)
        #expect(slots.compactMap(\.role) == roles.prefix(n).map(\.roleName))
        #expect(slots.compactMap(\.roleID?.index) == Array(0..<n))
    }
}

@Test func fullPageSheetIsOnePageEach() {
    let kit = Kit(nutmegSays: "", items: [kitItem("m", size: .fullPage, copies: 2)], scenes: [])
    #expect(KitLayout.pages(for: kit, roles: cast(1), playerCount: 1).count == 2)
}

@Test func gridShapes() {
    #expect(KitLayout.grid(for: .ticket) == .init(columns: 2, rows: 4))
    #expect(KitLayout.grid(for: .badge) == .init(columns: 3, rows: 2))
    #expect(KitLayout.grid(for: .fullPage) == .init(columns: 1, rows: 1))
}

@Test func fallbackKitFitsSixPages() {
    let a = Fallback.airplane
    #expect(KitLayout.pages(for: a.kit, roles: cast(4), playerCount: 4).count <= 6)
}

@Test func artPromptNeverCarriesTokensOrNames() {
    var item = kitItem("pass", size: .ticket, perPlayer: true)
    item.lines = ["Passenger: {P1}", "Flight: Ocean Express"]
    let p = KitArtPrompt.prompt(for: item, gameTitle: "Airplane")
    #expect(!p.contains("{P"))
    #expect(p.contains("Ocean Express"))
    #expect(p.lowercased().contains("blank"))
}

@Test func seatsDifferPerPlayer() {
    var item = kitItem("pass", size: .ticket, perPlayer: true)
    item.bigNumber = "1A"
    let kit = Kit(nutmegSays: "", items: [item], scenes: [])
    let slots = KitLayout.pages(for: kit, roles: cast(3), playerCount: 3)[0].slots
    #expect(slots.prefix(3).map { KitLayout.bigNumber(for: item, slot: $0) } == ["1A", "1B", "1C"])
    var shared = kitItem("money", size: .bill, copies: 3); shared.bigNumber = "5"
    #expect(KitLayout.bigNumber(for: shared, slot: KitSlot(index: 2)) == "5")
}

@Test func nameLinesAreNotRepeatedOnCards() {
    var item = kitItem("pass", size: .ticket, perPlayer: true)
    item.lines = ["Passenger: {P1}", "{P1}", "Flight: Ocean Express"]
    #expect(KitLayout.printedLines(for: item) == ["Flight: Ocean Express"])
}

@Test func recipeKitFitsSevenPages() {
    let pages = KitLayout.pages(for: Fallback.airplane.kit, roles: cast(4), playerCount: 4)
    #expect(pages.count <= 7)
    #expect(pages.map(\.item.recipe) == KitRecipe.original.map { Optional($0) })   // one page each, in recipe order
}

@Test func oneBadgePerRoleWithItsTitle() {
    var badge = kitItem("badge", size: .badge, perPlayer: true); badge.recipe = .badges
    for n in 1...4 {
        let roles = cast(n)
        let slots = KitLayout.pages(for: Kit(nutmegSays: "", items: [badge], scenes: []), roles: roles, playerCount: n).flatMap(\.slots)
        // The first N badges are the N playing roles, each printed with its own title; never blank names.
        #expect(slots.prefix(n).map(\.role) == roles.prefix(n).map { Optional($0.roleName) })
        #expect(slots.allSatisfy { s in s.role == roles.first { $0.id == s.roleID }?.roleName })
    }
}

@Test func badgeArtIsRoleNeutral() {
    var badge = kitItem("badge", size: .badge, perPlayer: true); badge.recipe = .badges
    badge.lines = ["Crew", "Sky Crew"]
    let p = KitArtPrompt.prompt(for: badge, gameTitle: "Airplane")
    #expect(!p.contains("Sky Crew"))
    #expect(p.contains("no words"))
}
