import Foundation
import Testing
@testable import NutmegCore

/// Round 45 (Haylee, decisions/2026-11-17-printables-library.md): picture-only art (the app draws every word and frame),
/// a library of 17 printable types with app-drawn layout variants, per-game shortlists, and the wiring (sanitizer,
/// setup / clean-up coverage, the no-printed-props rule, saved-game schema 4).
@MainActor struct Round45PrintablesTests {
    let a = Fallback.airplane
    var roles: [Role] { a.plan.roles }

    /// A model-like answer: the given types with plausible content, ids and no variants (as Claude returns them).
    func answer(_ types: [KitRecipe], title: String = "Treasure Hunt") -> [KitItem] {
        types.enumerated().map { n, t in
            var i = PrintDefaults.item(t, title: "\(title) \(t.spokenName)")
            i.id = "item\(n)"; i.variant = nil
            i.pictures = t == .badges || t == .cutouts || t == .decoder ? nil : PrintDefaults.lines(t).map { "a picture of \($0)" }
            if i.pictures?.isEmpty == true { i.pictures = ["a shiny thing"] }
            return i
        }
    }
    func libraryKit(_ game: String, recent: [[String]] = []) -> [KitItem] {
        let picks = PrintPicks.make(game: [game], recent: recent)
        return Sanitizer.clean(Kit(nutmegSays: "", items: answer(picks.shortlist), scenes: []), picks: picks).items
    }

    // MARK: 1. Picture-only art

    @Test func artPromptsNeverAskForTextFramesOrBoxes() {
        let banned = ["Spell", "BLANK", "blank white", "Title at the top", "big number", "Name:", "rounded letters", "$"]
        for g in PrintShortlist.games {
            let items = libraryKit(g.id)
            for style in PrintStyle.sets {
                let jobs = KitArtPlan.jobs(items: items, title: "Our Game", style: style, settled: [], roles: roles)
                #expect(!jobs.isEmpty)
                for j in jobs {
                    for b in banned { #expect(!j.prompt.contains(b), "\(g.id) \(j.key): '\(b)'") }
                    #expect(j.prompt.hasSuffix(ImageSafety.suffix))
                    let cutout = j.key.hasPrefix("cutouts")
                    if !cutout { #expect(j.prompt.contains(KitArtPrompt.pictureOnlyRule), "\(g.id) \(j.key)") }
                    // Never the printable's own words (its title or a line to print).
                    for it in items where !cutout && it.recipe != .menu && it.recipe != .orderSlips && it.recipe != .labels {
                        if it.recipe == .badges { continue }
                        #expect(!j.prompt.contains("\"\(it.title)\""), "\(g.id) \(j.key) quotes the title")
                    }
                }
            }
        }
        // The character sheet draws characters only, never badge shapes.
        let badges = libraryKit("restaurant")[0]
        let sheet = KitArtPrompt.badgeSheetPrompt(badges, roles: roles, gameTitle: "Café", style: .fullColor)
        #expect(sheet.contains("characters") && !sheet.contains("name badges") && !sheet.contains("clip hole"))
    }

    @Test func olderKitsKeepTheirOldArtPath() {
        // A schema-3 item (no variant) is untouched: its prompt is the old one (a reprint never makes new images anyway).
        var old = a.kit.items[3]; old.variant = nil; old.pictures = nil; old.bigNumber = "1A"
        #expect(!old.pictureOnly)
        #expect(KitArtPrompt.prompt(for: old, gameTitle: "Sky", style: .colorIn).contains("BLANK"))
        #expect(KitLayout.copyNumber(for: old, slot: KitSlot(index: 2)) == nil)
        #expect(KitLayout.grid(for: old) == KitLayout.grid(for: .ticket))
    }

    @Test func everyTicketCopyHasItsOwnNumber() {
        for v in KitRecipe.tickets.variants {
            var t = PrintDefaults.item(.tickets, title: "Pass"); t.variant = v
            let kit = Kit(nutmegSays: "", items: [t], scenes: [])
            let page = KitLayout.pages(for: kit, roles: roles, playerCount: 3)
            #expect(page.count == 1 && page[0].slots.count == 8)
            let numbers = page[0].slots.compactMap { KitLayout.copyNumber(for: t, slot: $0) }
            #expect(numbers.count == 8 && Set(numbers).count == 8, "\(v): \(numbers)")
        }
        var clue = PrintDefaults.item(.clueCards, title: "Clues"); clue.variant = .standard; clue.copies = PrintLibrary.copies(clue)
        let slots = KitLayout.pages(for: Kit(nutmegSays: "", items: [clue], scenes: []), roles: roles, playerCount: 2)[0].slots
        #expect(slots.compactMap { KitLayout.copyNumber(for: clue, slot: $0) } == ["1", "2", "3", "4"])
    }

    @Test func theBadgeSheetSlicerDropsANeighborsSliver() {
        // 3 × 2 sheet, 300 × 200 px: a drawing in each cell, and the 2nd drawing leans 6 px over into the 3rd cell.
        let w = 300, h = 200
        var g = [UInt8](repeating: 255, count: w * h)
        func ink(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) { for y in y0..<y1 { for x in x0..<x1 { g[y * w + x] = 0 } } }
        for c in 0..<3 { for r in 0..<2 { ink(c * 100 + 30, r * 100 + 20, c * 100 + 70, r * 100 + 80) } }
        ink(196, 30, 202, 60)    // a sliver of cell 2's drawing past the 200 px edge, over in cell 3
        let cells = BadgeSheet.cells(gray: g, width: w, height: h)
        #expect(cells.count == 6)
        let third = cells[2]
        #expect(third.x >= 200 + 20, "the third badge's crop starts at its own drawing, not the sliver: \(third)")
        // A drawing in two parts (a pair of shoes) keeps both parts.
        var two = [UInt8](repeating: 255, count: 100 * 100)
        for y in 30..<70 { for x in 10..<35 { two[y * 100 + x] = 0 }; for x in 65..<90 { two[y * 100 + x] = 0 } }
        let r = CutoutSheet.cells(gray: two, width: 100, height: 100, count: 1)[0]
        #expect(r.x <= 10 && r.x + r.width >= 89)
    }

    // MARK: 2. The library and its layouts

    @Test func theLibraryHasSeventeenTypesWithVariants() {
        #expect(KitRecipe.allCases.count == 17 && KitRecipe.original.count == 6)
        for t in [KitRecipe.badges, .sign, .money, .tickets, .menu] { #expect(t.variants.count == 3) }
        #expect(KitRecipe.log.variants.count == 2)
        for t in KitRecipe.allCases {
            #expect(!PrintLibrary.guide(t).isEmpty && !PrintLibrary.nouns(t).isEmpty && !PrintLibrary.verbs(t).isEmpty)
            for v in t.variants {
                var i = PrintDefaults.item(t, title: "X"); i.variant = v
                let pages = KitLayout.pages(for: Kit(nutmegSays: "", items: [i], scenes: []), roles: roles, playerCount: 6)
                #expect(pages.count == 1, "\(t) \(v)")
            }
        }
        // The decoder needs no image; every other type at most one per style.
        var d = PrintDefaults.item(.decoder, title: "Code"); d.variant = .standard
        #expect(PrintLibrary.art(d) == .none)
    }

    @Test func layoutsRotateAwayFromTheLastGames() {
        var memory: [[String]] = []
        var seen: [KitVariant] = []
        for _ in 0..<3 {
            let items = libraryKit("pirate-ship", recent: memory)
            let badge = items.first { $0.recipe == .badges }!.variant!
            seen.append(badge)
            memory = Array(([PrintVariants.ids(items)] + memory).prefix(RecentPrintMemory.gameCount))
        }
        #expect(Set(seen).count == 3, "three pirate games, three badge layouts: \(seen)")
        #expect(seen.first == .pin)   // the adventure default comes first
        // Deterministic.
        #expect(libraryKit("pirate-ship", recent: memory) == libraryKit("pirate-ship", recent: memory))
        // A ticket that says what it is keeps that layout; a show's list is a program.
        var t = PrintDefaults.item(.tickets, title: "Boarding Pass")
        #expect(PrintVariants.pick(t, family: .show, prefer: [], recent: [["tickets.boarding"]]) == .boarding)
        t.title = "Room Key"
        #expect(PrintVariants.pick(t, family: .travel, prefer: [], recent: []) == .keycard)
        var m = PrintDefaults.item(.menu, title: "Tonight's Acts"); m.lines = ["Juggling", "Clowns"]
        #expect(PrintVariants.pick(m, family: .food, prefer: [], recent: []) == .program)
        // The memory keeps only type.variant ids, 3 games.
        let suite = UserDefaults(suiteName: "r45-\(UUID().uuidString)")!
        let mem = RecentPrintMemory(defaults: suite)
        for g in ["restaurant", "zoo", "spy", "camping"] { mem.record(libraryKit(g)) }
        #expect(mem.games.count == 3 && mem.games.joined().allSatisfy { $0.split(separator: ".").count == 2 })
    }

    // MARK: 3. Shortlists per game

    @Test func everySuggestedGameHasAShortlist() {
        for s in Suggestions.games { #expect(PrintShortlist.game(id: s.id) != nil, "\(s.id)") }
        #expect(PrintShortlist.game(id: "spy") != nil && PrintShortlist.game(id: "superheroes") != nil)
        for g in PrintShortlist.games {
            #expect((4...6).contains(g.types.count), "\(g.id)")
            #expect(g.types.first == .badges, "\(g.id): badges first")
            #expect(Set(g.types).count == g.types.count)
            if !g.place { #expect(!g.types.contains(.sign), "\(g.id): no place, no sign") }
        }
        for id in ["treasure-hunt", "spy", "detective", "mail-carrier", "weather-station", "bird-watchers"] {
            #expect(PrintShortlist.game(id: id)?.place == false)
        }
    }

    @Test func gamesAreMatchedFromTheKidsWords() {
        let cases: [(String, String?)] = [("Pirates in Space", "pirate-ship"), ("Bakery on the Moon", "bakery"),
                                          ("Spy Gear Shop", "spy"), ("Vet Clinic for Sea Animals", "vet"),
                                          ("ice cream truck", "ice-cream-truck"), ("Treasure Hunt in the Jungle", "treasure-hunt"),
                                          ("Super Hero Rescue", "superheroes"), ("Rocket Ship", "rocket"),
                                          ("Snail Disco Party", nil)]
        for (text, id) in cases { #expect(PrintShortlist.game(for: [text])?.id == id, "\(text)") }
        // set_game's game type wins over the themed title.
        #expect(PrintShortlist.game(for: ["restaurant", "Dinosaur Diner"])?.id == "restaurant")
    }

    // MARK: 4. The sanitizer

    @Test func theSanitizerShapesALibraryKit() {
        let picks = PrintPicks.make(game: ["treasure hunt"])
        // Duplicates, a sign (no place here), three off-list types, no badges.
        let raw = answer([.map, .map, .sign, .clueCards, .menu, .passport, .stickers, .money, .log])
        let items = Sanitizer.clean(Kit(nutmegSays: "", items: raw, scenes: []), picks: picks).items
        let types = items.compactMap(\.recipe)
        #expect(types.first == .badges)
        #expect(Set(types).count == types.count && (4...6).contains(types.count))
        #expect(!types.contains(.sign))
        #expect(types.filter { !picks.shortlist.contains($0) }.count <= PrintPicks.maxSwaps, "\(types)")
        #expect(items.allSatisfy { $0.pictureOnly && $0.id == $0.recipe?.rawValue })
        #expect(KitArtPlan.imageCount(items, roles: roles) <= PrintLibrary.imageBudgetPerStyle)
        #expect(KitLayout.pages(for: Kit(nutmegSays: "", items: items, scenes: []), roles: roles, playerCount: 6).count <= KitLayout.maxPages)
        // Idempotent.
        let again = Sanitizer.clean(Kit(nutmegSays: "", items: items, scenes: []), picks: picks).items
        for (x, y) in zip(items, again) where x != y { Issue.record("not idempotent: \(x) → \(y)") }
        #expect(again == items)
        // Too few: topped up to 4 from the shortlist; money is $1, words are few.
        let few = Sanitizer.clean(Kit(nutmegSays: "", items: answer([.map]), scenes: []), picks: picks).items
        #expect(few.count == 4 && few[0].recipe == .badges && few.contains { $0.recipe == .map })
        var long = PrintDefaults.item(.clueCards, title: "Clues")
        long.lines = ["Look under the big soft pillow in the living room now please"]
        let shaped = Sanitizer.clean(Kit(nutmegSays: "", items: [long], scenes: []), picks: picks).items.first { $0.recipe == .clueCards }!
        #expect(shaped.lines[0].split(separator: " ").count <= PrintLibrary.lineLimits(.clueCards).words)
        // Validation asks once for the badges, the type count and the shortlist.
        let problem = Validate.pages(KitPages(nutmegSays: "", items: raw), picks: picks)
        #expect(problem?.message.contains("badges") == true && problem?.message.contains("no sign") == true && problem?.fatal == false)
    }

    @Test func aMadeUpGamePicksFreely() {
        let picks = PrintPicks.make(game: ["Snail Disco Party"])
        #expect(picks.isMadeUp && picks.shortlist == KitRecipe.allCases && !picks.noSign)
        let items = Sanitizer.clean(Kit(nutmegSays: "", items: answer([.badges, .controlPanel, .decoder, .medals, .sign]), scenes: []), picks: picks).items
        #expect(items.compactMap(\.recipe) == [.badges, .controlPanel, .decoder, .medals, .sign])
        let prompt = Prompts.kitPages(ctx: AdventureContext(gameTitle: "Snail Disco Party", playerCount: 2), picks: picks)
        #expect(prompt.contains("made up") && prompt.contains("Only include a sign if the game has a place"))
    }

    @Test func theKitPromptCarriesTheShortlistAndTheRules() {
        let picks = PrintPicks.make(game: ["treasure hunt"])
        let p = Prompts.kitPages(ctx: AdventureContext(gameTitle: "Treasure Hunt", playerCount: 2), picks: picks)
        #expect(p.contains("THIS GAME'S SHORTLIST: badges, map, clueCards, money, log, cutouts"))
        #expect(p.contains("NO sign") && p.contains("badges is ALWAYS first") && p.contains("ART IS A PICTURE ONLY"))
        #expect(p.contains("reads the words on clue cards"))
        for t in KitRecipe.allCases { #expect(p.contains("- \(t.rawValue): ")) }
        // The schema asks for the pictures, not the shape fields the app fixes.
        let item = ((Schemas.kitPages()["properties"] as? [String: Any])?["items"] as? [String: Any])?["items"] as? [String: Any]
        let keys = Set((item?["properties"] as? [String: Any])?.keys.map { $0 } ?? [])
        #expect(keys.contains("pictures") && !keys.contains("size") && !keys.contains("copies"))
    }

    // MARK: 5. Every item is used; props are never printed things

    @Test func everyPrintedItemIsInTheSetupAndTheCleanUpRows() {
        for game in ["treasure-hunt", "restaurant", "spy", "space-station", "vet", "museum"] {
            var k = a.kit
            k.items = libraryKit(game)
            k.setup?.jobs = []; k.cleanup?.jobs = []   // nothing written for these pages: the app's own jobs
            let fixed = Bookends.repair(k, props: a.props.props, roles: roles, title: game).kit
            let items = Bookends.coverItems(items: fixed.items, props: a.props.props)
            #expect(items.filter { $0.recipe != nil }.count == fixed.items.count)
            for n in 1...6 {
                let v = PlayCast.kit(fixed, roles: roles, players: n, props: a.props.props).scenes
                #expect(SetupCoverage.setupMissing(v, items: items).isEmpty, "\(game) n=\(n) \(SetupCoverage.setupMissing(v, items: items))")
                #expect(SetupCoverage.cleanupMissing(v, items: items).isEmpty, "\(game) n=\(n) \(SetupCoverage.cleanupMissing(v, items: items))")
                #expect(SetupCoverage.missing(v, items: items, roles: roles).isEmpty, "\(game) n=\(n)")
            }
        }
        // A play task naming a new printable counts as using it (by its kind's words).
        let clue = Bookends.coverItems(items: libraryKit("treasure-hunt"), props: []).first { $0.recipe == .clueCards }!
        #expect(clue.id == "page:clueCards")
        #expect(Bookends.mentions("Captain, read clue 2 out loud and run to the door!", clue))
        // Tasks may name the kit's new printables (not turned into "pretend" things).
        let ok = GuideRepair.allowedWords(props: [], items: libraryKit("treasure-hunt"))
        #expect(GuideRepair.missingObjects("Hide the clue cards and follow the map to the coins", allowed: ok, roles: roles).isEmpty)
    }

    @Test func propsAreNeverThisKitsPrintedThings() {
        for g in PrintShortlist.games {
            let items = libraryKit(g.id)
            for it in items {
                guard let t = it.recipe, t != .badges, t != .sign, t != .cutouts else { continue }
                for noun in PrintLibrary.nouns(t) where !noun.contains(" ") && !(noun == "program" && it.variant != .program) {
                    #expect(PrintedProps.clash("the \(noun)", kit: items) != nil, "\(g.id): a prop can't be the \(noun)")
                }
            }
        }
        // A control panel is a fine prop in a game whose kit doesn't print one…
        #expect(PrintedProps.clash("the control panel", kit: libraryKit("restaurant")) == nil)
        // …but never when the kit prints it.
        #expect(PrintedProps.clash("the control panel", kit: libraryKit("rocket")) != nil)
        #expect(PrintedProps.clash("the gold medal") != nil && PrintedProps.clash("the order slip") != nil)
        let retry = PrintedProps.retryOutput(itemID: "box", becomes: "the map", clash: "map", kit: libraryKit("treasure-hunt"))
        #expect(retry.contains("clue cards") && retry.contains("map"))
    }

    // MARK: 6. Saved games

    @Test func schemaFourDecodesUnknownNamesTolerantly() throws {
        let json = #"{"id":"x","recipe":"hologram","variant":"sparkly","title":"Mystery","lines":["a"],"bigNumber":null}"#
        let i = try JSONDecoder().decode(KitItem.self, from: Data(json.utf8))
        #expect(i.recipe == nil && i.variant == nil && i.title == "Mystery" && !i.pictureOnly)
        // A library kit round-trips in a schema-4 game.
        var k = a.kit; k.items = libraryKit("treasure-hunt")
        let g = SavedGame(createdAt: Date(), title: "Treasure", roles: roles, props: [], kit: k, printStyle: .fullColor, art: [], voiceID: "v")
        #expect(g.schemaVersion == 4)
        let back = try SavedGame.decode(SavedGame.encoder().encode(g))
        #expect(back.kit.items == k.items && back.kit.items.allSatisfy(\.pictureOnly))
        // A newer app's type in a saved game: the game still opens.
        var data = try JSONSerialization.jsonObject(with: SavedGame.encoder().encode(g)) as! [String: Any]
        var kit = data["kit"] as! [String: Any]
        var items = kit["items"] as! [[String: Any]]
        items[1]["recipe"] = "jetpack"; items[1]["variant"] = "holo"
        kit["items"] = items; data["kit"] = kit
        let odd = try SavedGame.decode(JSONSerialization.data(withJSONObject: data))
        #expect(odd.kit.items[1].recipe == nil && odd.kit.items.count == k.items.count)
    }

    @Test func schemaThreeGamesReplayUnchanged() throws {
        // A round-44 game: the fixed six, no variants or pictures (encoded exactly as round 44 wrote it).
        var k = a.kit
        k.items = k.items.map { var i = $0; i.variant = nil; i.pictures = nil; return i }
        var g = SavedGame(createdAt: Date(), title: "Sky", roles: roles, props: [], kit: k, printStyle: .fullColor,
                          art: ["img:sign", "cut:badges:0"], voiceID: "v")
        g.schemaVersion = 3
        let data = try SavedGame.encoder().encode(g)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("\"variant\"") && !text.contains("\"pictures\""))
        let back = try SavedGame.decode(data)
        #expect(back.schemaVersion == 3 && back.kit == k && back.kit.items.allSatisfy { !$0.pictureOnly })
        // Its pages lay out exactly as before (the old grids) and the replay needs no new images: its art is all saved.
        let pages = KitLayout.pages(for: back.kit, roles: roles, playerCount: 3)
        #expect(pages.map(\.item.recipe) == KitRecipe.original.map { Optional($0) })
        #expect(pages.allSatisfy { KitLayout.grid(for: $0.item) == KitLayout.grid(for: $0.item.size) })
        let store = AdventureStore(service: nil)
        store.loadReplay(back)
        #expect(store.isReplay && store.kit?.items == back.kit.items)
    }

    // MARK: 7. Cost

    /// Per game, both sets + the cover. Today's fixed kit is 13 (6 a set + 1).
    @Test func everyShortlistKitStaysWithinTodaysImageBudget() {
        var report: [String] = []
        for g in PrintShortlist.games {
            let items = libraryKit(g.id)
            let perSet = KitArtPlan.imageCount(items, roles: roles)
            #expect(perSet <= PrintLibrary.imageBudgetPerStyle, "\(g.id) \(perSet)")
            report.append("\(g.id) \(perSet * 2 + 1)")
        }
        let today = KitArtPlan.imageCount(a.kit.items, roles: roles) * 2 + 1
        #expect(today == 13)
        print("R45 images per game (both sets + cover): " + report.joined(separator: ", "))
    }
}
