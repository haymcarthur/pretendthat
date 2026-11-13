import Testing
@testable import NutmegCore

func kitItem(_ id: String, size: KitSize, perPlayer: Bool = false, copies: Int = 1) -> KitItem {
    KitItem(id: id, kind: size == .fullPage ? .sheet : .card, size: size, title: id, symbol: "star", lines: [], bigNumber: nil, perPlayer: perPlayer, copies: copies, colorMe: true)
}

@Test func perPlayerTickets3Players() {
    let kit = Kit(nutmegSays: "", items: [kitItem("t", size: .ticket, perPlayer: true)], scenes: [])
    let pages = KitLayout.pages(for: kit, players: [.P1, .P2, .P3], directorMode: false)
    #expect(pages.count == 1)
    // Fills the sheet: every player, then spares cycling the players; each keeps their seat index.
    #expect(pages[0].slots.map(\.player) == [.P1, .P2, .P3, .P1, .P2, .P3, .P1, .P2])
    #expect(pages[0].slots.map(\.index) == [0, 1, 2, 0, 1, 2, 0, 1])
}

@Test func smallItemsFillEveryPage() {
    for r in KitRecipe.allCases {
        var item = kitItem(r.rawValue, size: r.size, perPlayer: r.perPlayer, copies: r == .money ? 8 : 1)
        item.recipe = r
        for players in [[PlayerToken.P1], [.P1, .P2], [.P1, .P2, .P3], [.P1, .P2, .P3, .P4]] {
            let pages = KitLayout.pages(for: Kit(nutmegSays: "", items: [item], scenes: []), players: players, directorMode: false)
            let cap = KitLayout.grid(for: r.size).capacity
            #expect(pages.allSatisfy { $0.slots.count == cap }, "\(r) with \(players.count) players")
            if r.perPlayer { #expect(Set(pages.flatMap(\.slots).compactMap(\.player)) == Set(players)) }
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
    let pages = KitLayout.pages(for: kit, players: [.P1], directorMode: false)
    #expect(pages.map(\.slots.count) == [6, 6])
}

@Test func capsAtSevenPages() {
    let items = [kitItem("a", size: .ticket, copies: 20), kitItem("b", size: .badge, copies: 20),
                 kitItem("c", size: .bill, copies: 20), kitItem("d", size: .keycard, copies: 20)]
    let pages = KitLayout.pages(for: Kit(nutmegSays: "", items: items, scenes: []), players: [.P1], directorMode: false)
    #expect(pages.count == KitLayout.maxPages && KitLayout.maxPages == 7)
    #expect(Set(pages.map(\.item.id)) == ["a", "b", "c", "d"])
}

@Test func directorModeBlankSlots() {
    let kit = Kit(nutmegSays: "", items: [kitItem("t", size: .ticket, perPlayer: true, copies: 8)], scenes: [])
    let pages = KitLayout.pages(for: kit, players: [.P1, .P2, .P3, .P4], directorMode: true)
    #expect(pages.flatMap(\.slots).count == 8)
    #expect(pages.flatMap(\.slots).allSatisfy { $0.player == nil })
}

@Test func fullPageSheetIsOnePageEach() {
    let kit = Kit(nutmegSays: "", items: [kitItem("m", size: .fullPage, copies: 2)], scenes: [])
    #expect(KitLayout.pages(for: kit, players: [.P1], directorMode: false).count == 2)
}

@Test func gridShapes() {
    #expect(KitLayout.grid(for: .ticket) == .init(columns: 2, rows: 4))
    #expect(KitLayout.grid(for: .badge) == .init(columns: 3, rows: 2))
    #expect(KitLayout.grid(for: .fullPage) == .init(columns: 1, rows: 1))
}

@Test func fallbackKitFitsSixPages() {
    let a = Fallback.airplane
    #expect(KitLayout.pages(for: a.kit, players: [.P1, .P2, .P3, .P4], directorMode: false).count <= 6)
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
    let slots = KitLayout.pages(for: kit, players: [.P1, .P2, .P3], directorMode: false)[0].slots
    #expect(slots.prefix(3).map { KitLayout.bigNumber(for: item, slot: $0) } == ["1A", "1B", "1C"])
    var shared = kitItem("money", size: .bill, copies: 3); shared.bigNumber = "5"
    #expect(KitLayout.bigNumber(for: shared, slot: KitSlot(player: nil, index: 2)) == "5")
}

@Test func nameLinesAreNotRepeatedOnCards() {
    var item = kitItem("pass", size: .ticket, perPlayer: true)
    item.lines = ["Passenger: {P1}", "{P1}", "Flight: Ocean Express"]
    #expect(KitLayout.printedLines(for: item) == ["Flight: Ocean Express"])
}

@Test func directorModeFillsAPageOfBlankPerPlayerItems() {
    var badge = Fixture.item("badge"); badge.size = .badge; badge.perPlayer = true; badge.copies = 1
    let kit = Kit(nutmegSays: "", items: [badge], scenes: [])
    let pages = KitLayout.pages(for: kit, players: [.P1, .P2, .P3, .P4], directorMode: true)
    #expect(pages.count == 1)
    #expect(pages[0].slots.count == KitLayout.grid(for: .badge).capacity)
    #expect(pages[0].slots.allSatisfy { $0.player == nil })
}

@Test func recipeKitFitsSevenPages() {
    let pages = KitLayout.pages(for: Fallback.airplane.kit, players: [.P1, .P2, .P3, .P4], directorMode: false)
    #expect(pages.count <= 7)
    #expect(pages.map(\.item.recipe) == KitRecipe.allCases.map { Optional($0) })   // one page each, in recipe order
}
