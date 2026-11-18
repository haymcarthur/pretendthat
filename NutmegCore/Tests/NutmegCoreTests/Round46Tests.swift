import Foundation
import Testing
@testable import NutmegCore

/// Round 46 (Haylee, decisions/2026-11-17-ai-drawn-printables.md): the image model draws every WHOLE printable page from
/// the approved recipes (design/printables-ai-test/scripts/recipes.py); the app draws nothing on it and only fits it on
/// the paper. One picture-only character sheet per kit for the in-app pictures. A forgiving on-device word check.
@MainActor struct Round46Tests {
    let a = Fallback.airplane(playerCount: 4)
    var roles: [Role] { a.plan.roles }

    /// An AI page item of a type and layout, shaped like the sanitizer leaves it.
    func page(_ t: KitRecipe, _ v: KitVariant? = nil, title: String, lines: [String] = [], pictures: [String]? = nil) -> KitItem {
        var i = PrintDefaults.item(t, title: title)
        i.lines = lines; i.pictures = pictures; i.variant = v ?? t.variants[0]; i.wholePage = true
        i.copies = PrintLibrary.copies(i)
        return i
    }
    func pirates(_ n: Int) -> [Role] {
        RoleCast.rank([Role(id: .R1, roleName: "Captain", emoji: "", symbol: "star", job: "pirate hat and a treasure chest key"),
                       Role(id: .R2, roleName: "Map Reader", emoji: "", symbol: "star", job: "holding a rolled map"),
                       Role(id: .R3, roleName: "Clue Finder", emoji: "", symbol: "star", job: "holding a magnifying glass"),
                       Role(id: .R4, roleName: "Lookout", emoji: "", symbol: "star", job: "holding a spyglass, parrot on shoulder"),
                       Role(id: .R5, roleName: "First Mate", emoji: "", symbol: "star", job: "holding a rope"),
                       Role(id: .R6, roleName: "Ship's Cook", emoji: "", symbol: "star", job: "holding a big spoon")])
    }
    /// Every type and layout with fixture words (the round 45 gallery's).
    var everyPage: [KitItem] {
        var out: [KitItem] = []
        for v in KitRecipe.badges.variants { out.append(page(.badges, v, title: "Rainbow Crew")) }
        for v in KitRecipe.sign.variants { out.append(page(.sign, v, title: "Captain Coral's Ship", lines: ["All aboard!"], pictures: ["a pirate ship"])) }
        for v in KitRecipe.money.variants { out.append(page(.money, v, title: "Sea Bucks", pictures: ["a seashell"])) }
        out.append(page(.tickets, .boarding, title: "Boarding Pass", lines: ["Trip to Treasure Island"], pictures: ["a ship"]))
        out.append(page(.tickets, .admission, title: "Big Top Show", lines: ["Front row fun"], pictures: ["a circus tent"]))
        out.append(page(.tickets, .keycard, title: "Room Key", pictures: ["a key"]))
        out.append(page(.tickets, .keycard, title: "Appointment Card", lines: ["Paw Check-up"], pictures: ["a puppy"]))
        out.append(page(.menu, .menuCard, title: "Galley Menu", lines: ["Fish Tacos $3", "Coconut Milk $2", "Sea Salad $2"], pictures: ["fish tacos", "a coconut", "a salad"]))
        out.append(page(.menu, .chalkboard, title: "Lemonade", lines: ["Pink Lemonade $1", "Ice Pop $2"]))
        out.append(page(.menu, .program, title: "Circus Spectacular", lines: ["Juggling Bears", "Clown Car"]))
        out.append(page(.cutouts, title: "Pirate Cut-outs", lines: ["Spyglass", "Gold coin", "Parrot", "Anchor", "Compass", "Key"]))
        out.append(page(.orderSlips, title: "Order Up!", lines: ["Pizza", "Juice", "Salad"]))
        out.append(page(.map, title: "Treasure Map", lines: ["Big Rock", "Palm Tree", "Bridge", "Cave"], pictures: ["a sunny little island"]))
        out.append(page(.clueCards, title: "Clue Cards", lines: ["Look under something soft", "Find the big rock", "Peek by the door"]))
        out.append(page(.missionCards, title: "Hero Missions", lines: ["Rescue the kitten", "Stop the rain"]))
        out.append(page(.log, .ruled, title: "Captain's Log", lines: ["Islands we saw", "Treasure found"]))
        out.append(page(.log, .chart, title: "Patient Chart", lines: ["Temperature", "Ate dinner"]))
        out.append(page(.medals, title: "Medals", lines: ["Bravest Pirate", "Best Lookout"]))
        out.append(page(.stickers, title: "Stickers", lines: ["Brave!", "Wow!", "Super!"]))
        out.append(page(.passport, title: "Sky Passport", lines: ["Paris", "The Moon", "Jungle"]))
        out.append(page(.labels, title: "Price Tags", lines: ["Apples $2", "Bread $3"]))
        out.append(page(.controlPanel, title: "Rocket Controls", lines: ["Launch", "Lights", "Boost"], pictures: ["stars and a moon"]))
        return out
    }

    // MARK: Step 1: whole-page prompts

    @Test func everyTypeAndLayoutHasAWholePagePromptWithItsExactWords() {
        let ctx = KitArtContext(title: "Pirate Treasure Hunt", roles: pirates(6), players: 4)
        var covered = Set<KitRecipe>()
        for item in everyPage {
            for style in PrintStyle.sets {
                guard let p = KitPagePrompt.prompt(for: item, ctx: ctx, style: style) else {
                    Issue.record("no prompt for \(item.recipe!) \(item.variant!)"); continue
                }
                covered.insert(item.recipe!)
                #expect(p.prompt.hasPrefix(KitPagePrompt.page + " The game is \"Pirate Treasure Hunt\". " + KitPagePrompt.style(style)))
                #expect(p.prompt.contains(" The ONLY words on the page, spelled exactly letter for letter: "))
                #expect(p.prompt.hasSuffix(KitPagePrompt.safe) && p.prompt.contains(ImageSafety.suffix))
                #expect(!p.words.isEmpty, "\(item.recipe!) \(item.variant!)")
                // Every word is quoted exactly, and nothing outside the item's words and the app's own (Name:, Order…).
                for w in Set(p.words) { #expect(p.prompt.contains("\"\(w)\""), "\(item.recipe!) \(item.variant!): \(w)") }
                // The app draws nothing: no request for a blank box the app would fill.
                #expect(!p.prompt.contains("BLANK") && !p.prompt.contains("printed there later"))
            }
        }
        #expect(covered == Set(KitRecipe.allCases).subtracting([.decoder]))
        // The decoder stays app-drawn (its symbols must be exact); an older kit's item never gets a page prompt.
        #expect(KitPagePrompt.prompt(for: page(.decoder, title: "Secret Code", lines: ["GOLD"]), ctx: ctx, style: .fullColor) == nil)
        var old = page(.sign, title: "Cafe"); old.wholePage = nil
        #expect(KitPagePrompt.prompt(for: old, ctx: ctx, style: .fullColor) == nil)
    }

    @Test func theOutlineSetOnlySwapsTheStyleLineAndUsesBubbleLetters() {
        let ctx = KitArtContext(title: "Cozy Café", roles: roles, players: 3)
        for item in everyPage {
            let c = KitPagePrompt.prompt(for: item, ctx: ctx, style: .fullColor)!, o = KitPagePrompt.prompt(for: item, ctx: ctx, style: .colorIn)!
            #expect(c.prompt.replacingOccurrences(of: KitPagePrompt.style(.fullColor), with: KitPagePrompt.style(.colorIn)) == o.prompt)
            #expect(c.words == o.words)
        }
        #expect(KitPagePrompt.style(.colorIn).contains("bubble letters"))
    }

    /// The port is word for word the approved test's recipe (design/printables-ai-test/*.json), up to the safety block
    /// (now the app's own suffix plus friendly pirates).
    @Test func theApprovedRecipesArePortedWordForWord() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../design/printables-ai-test")
        let oldSafe = " Kid-friendly and gentle, for ages 4 to 8: no guns, no knives, no real weapons (a toy sword is fine), no blood, nothing scary, no real people, no brands, no logos."
        let pirate = KitArtContext(title: "Pirate Treasure Hunt", roles: pirates(6), players: 4)
        let cafe = KitArtContext(title: "Cozy Café", roles: roles, players: 3)
        let cases: [(String, KitItem, KitArtContext)] = [
            ("pirate-badges", page(.badges, .lanyard, title: "Crew"), pirate),
            ("pirate-coins", page(.money, .coins, title: "Island Gold", pictures: ["a palm tree"]), pirate),
            ("pirate-map", page(.map, title: "Treasure Map", lines: ["Big Rock", "Palm Tree", "Cave", "Treasure"], pictures: ["a sunny little island"]), pirate),
            ("pirate-clues", page(.clueCards, title: "Clues", lines: ["Look under a pillow", "Peek behind a chair", "Check inside a box", "Find the teddy bear"],
                                  pictures: ["a pillow", "a chair", "a cardboard box", "a teddy bear"]), pirate),
            ("pirate-cutouts", page(.cutouts, title: "Hunt Gear", lines: ["a treasure chest", "a spyglass", "a shovel", "a parrot", "a pirate hat", "a golden key"]), pirate),
            ("cafe-sign", page(.sign, .door, title: "Cozy Café", lines: ["Now Open"], pictures: ["a little café with a striped awning and flower pots"]), cafe),
            ("cafe-slips", page(.orderSlips, title: "Orders", lines: ["Pancakes", "Pizza", "Soup", "Cupcake"],
                                pictures: ["a stack of pancakes", "a slice of pizza", "a bowl of soup", "a cupcake"]), cafe),
            ("cafe-bills", page(.money, .bills, title: "Cozy Bucks", pictures: ["a smiling cupcake"]), cafe),
        ]
        for (name, item, ctx) in cases {
            let data = try Data(contentsOf: dir.appendingPathComponent("\(name).json"))
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let approved = (json["prompt"] as! String).replacingOccurrences(of: oldSafe, with: "")
            let mine = KitPagePrompt.prompt(for: item, ctx: ctx, style: .fullColor)!
            #expect(mine.prompt.replacingOccurrences(of: KitPagePrompt.safe, with: "") == approved, "\(name)")
            #expect(mine.words == json["words"] as! [String], "\(name)")
        }
    }

    @Test func theBadgePageIsDrawnForExactlyThePlayingRoles() {
        let six = pirates(6)
        for n in 1...6 {
            let ctx = KitArtContext(title: "Treasure", roles: six, players: n)
            let p = KitPagePrompt.prompt(for: page(.badges, .pin, title: "Crew"), ctx: ctx, style: .fullColor)!
            #expect(p.prompt.contains("exactly \(n) round name badges"))
            #expect(p.words == six.prefix(n).map(\.roleName) + Array(repeating: "Name:", count: n))
            for r in six.dropFirst(n) { #expect(!p.prompt.contains("\"\(r.roleName)\""), "\(n) players: \(r.roleName)") }
            // Its art key is per count, so a new count draws its own page; the printed page has exactly those badges.
            #expect(KitArtPlan.pageKey(page(.badges, title: "Crew"), players: n) == "badges@\(n)")
            let pages = KitLayout.pages(for: Kit(nutmegSays: "", items: [page(.badges, title: "Crew")], scenes: []), roles: six, playerCount: n)
            #expect(pages.count == 1 && pages[0].slots.count == n && pages[0].artKey == "badges@\(n)")
        }
    }

    @Test func ticketsCarryADifferentNumberOnEveryCopyInThePrompt() {
        let ctx = KitArtContext(title: "Sky", roles: roles, players: 2)
        let expected: [String: [String]] = [
            "Boarding Pass": ["1A", "1B", "1C", "1D", "2A", "2B", "2C", "2D"],
            "Big Top Show": (1...8).map { String(format: "%03d", $0) },
            "Room Key": (101...108).map(String.init),
            "Appointment Card": (1...8).map(String.init),
        ]
        for item in everyPage where item.recipe == .tickets {
            let numbers = KitPagePrompt.ticketNumbers(item)
            #expect(numbers == expected[item.title], "\(item.title)")
            let p = KitPagePrompt.prompt(for: item, ctx: ctx, style: .fullColor)!
            #expect(p.prompt.contains("in this order left to right, top to bottom: " + numbers.map { "\"\($0)\"" }.joined(separator: ", ")))
            for n in numbers { #expect(p.words.filter { $0 == n }.count == 1) }
            #expect(p.words.filter { $0 == item.title }.count == 8)
        }
        #expect(KitPagePrompt.prompt(for: everyPage.first { $0.title == "Appointment Card" }!, ctx: ctx, style: .fullColor)!.words.contains("Time:"))
    }

    @Test func wordsAreShortAndQuotedExactlyNeverWithStrayQuotes() {
        let ctx = KitArtContext(title: "The \"Best\" Café", roles: roles, players: 2)
        let sign = page(.sign, title: "Joe's \"Diner\"", lines: ["Open  now"])
        let p = KitPagePrompt.prompt(for: sign, ctx: ctx, style: .fullColor)!
        #expect(p.words == ["Joe's Diner", "Open now"])
        #expect(p.prompt.contains("The game is \"The Best Café\"") && p.prompt.contains("\"Joe's Diner\""))
        // The sanitizer keeps lines short (round 45's limits), so every quoted word stays short.
        let picks = PrintPicks.make(game: ["treasure hunt"])
        var clue = PrintDefaults.item(.clueCards, title: "Clues")
        clue.lines = ["Look under the big soft pillow in the living room now please"]
        let kit = Sanitizer.clean(Kit(nutmegSays: "", items: [clue], scenes: []), picks: picks)
        let shaped = kit.items.first { $0.recipe == .clueCards }!
        let words = KitPagePrompt.prompt(for: shaped, ctx: ctx, style: .fullColor)!.words
        #expect(words.allSatisfy { $0.split(separator: " ").count <= PrintLibrary.lineLimits(.clueCards).words })
    }

    @Test func noSkullsFriendlyPirates() {
        #expect(KitPagePrompt.safe.contains("No skulls, no crossbones"))
        #expect(CharacterSheet.prompt(roles: pirates(6), things: [], title: "Pirates").contains("No skulls, no crossbones"))
    }

    @Test func oneSharedStyleLinePerKit() {
        let k = Sanitizer.clean(Kit(nutmegSays: "", items: a.kit.items, scenes: []), picks: PrintPicks.make(game: ["airplane"]))
        let ctx = KitArtContext(title: "Sky Trip", setting: "a sunny airport", roles: roles, players: 3)
        for style in PrintStyle.sets {
            let jobs = KitArtPlan.jobs(items: k.items, ctx: ctx, style: style, settled: [])
            let head = KitPagePrompt.page + " The game is \"Sky Trip\" (a sunny airport). " + KitPagePrompt.style(style)
            #expect(!jobs.isEmpty && jobs.allSatisfy { $0.prompt.hasPrefix(head) })
        }
    }

    // MARK: Step 1: the app only places the page

    @Test func aPageIsFittedWholeInsideTheMargins() {
        let letter = CGSize(width: 612, height: 792)
        let r = PageFit.rect(image: CGSize(width: 1024, height: 1536), page: letter)
        #expect(r == CGRect(x: 66, y: 36, width: 480, height: 720))            // 6.7 × 10 in, centered, half-inch margins
        // Any shape fits whole (never cropped or stretched), centered, inside the margin.
        for s in [CGSize(width: 1536, height: 1024), CGSize(width: 1024, height: 1024), CGSize(width: 10, height: 2000)] {
            let f = PageFit.rect(image: s, page: letter)
            #expect(abs(f.width / f.height - s.width / s.height) < 0.001)
            #expect(f.minX >= 36 - 0.001 && f.minY >= 36 - 0.001 && f.maxX <= 576 + 0.001 && f.maxY <= 756 + 0.001)
            #expect(abs((f.minX - 36) - (576 - f.maxX)) < 0.001 && abs((f.minY - 36) - (756 - f.maxY)) < 0.001)
        }
        #expect(PageFit.rect(image: .zero, page: letter) == CGRect(x: 36, y: 36, width: 540, height: 720))
    }

    @Test func anAIKitPrintsOnePagePerPrintableAndTheSkippedPropsPage() {
        let items = Sanitizer.clean(Kit(nutmegSays: "", items: a.kit.items, scenes: []), picks: PrintPicks.make(game: ["airplane"])).items
        #expect(items.allSatisfy { $0.aiPage })
        let kit = Kit(nutmegSays: "", items: items, scenes: [])
        let pages = KitLayout.pages(for: kit, roles: roles, playerCount: 3)
        #expect(pages.map(\.item.id) == items.map(\.id) && pages.allSatisfy { $0.pageIndex == 0 })
        #expect(pages.map(\.artKey) == items.map { KitArtPlan.pageKey($0, players: 3) })
        // A skipped prop: the cut-outs get a second page (its own art key), the themed page keeps its lines.
        let skip = Props(nutmegSays: "", props: [Prop(id: "x", householdItem: "Pot", becomes: "the rocket", forRole: .all, safetyOK: true, skipped: true)])
        let final = KitDraft.finalItems(items, props: skip)
        let cut = final.first { $0.recipe == .cutouts }!
        #expect(cut.pageLines == 6 && cut.lines.last == "rocket")
        let more = KitLayout.pages(for: Kit(nutmegSays: "", items: final, scenes: []), roles: roles, playerCount: 3).filter { $0.item.recipe == .cutouts }
        #expect(more.count == 2 && more[0].item.lines.count == 6 && more[1].item.lines == ["rocket"] && more[1].artKey == "cutouts#more")
        let extra = KitPagePrompt.prompt(for: cut, ctx: KitArtContext(title: "Sky"), style: .fullColor, part: 1)!
        #expect(extra.prompt.contains("1. rocket") && extra.words == ["More \(cut.title)"])
        #expect(KitLayout.pages(for: Kit(nutmegSays: "", items: final, scenes: []), roles: roles, playerCount: 6).count <= KitLayout.maxPages)
    }

    // MARK: Step 4: schema compatibility

    @Test func newGamesAreSchemaFiveAndOlderGamesReplayUnchanged() throws {
        // A new game: schema 5, whole pages, its art keys round-trip.
        var k = a.kit; k.items = Sanitizer.clean(Kit(nutmegSays: "", items: a.kit.items, scenes: []), picks: PrintPicks.make(game: ["airplane"])).items
        let art = ["img:badges@3", "img:cutouts#more", "oimg:sign", "cut:characters:0", "cut:characters:7"]
        let g = SavedGame(createdAt: Date(), title: "Sky", roles: roles, props: [], kit: k, printStyle: .fullColor, art: art, voiceID: "v")
        #expect(g.schemaVersion == 5 && SavedGame.readableSchemas == [2, 3, 4, 5])
        let back = try SavedGame.decode(SavedGame.encoder().encode(g))
        #expect(back.kit.items == k.items && back.kit.items.allSatisfy { $0.aiPage })
        #expect(ArtKey.parse("img:badges@3", plain: .fullColor)! == ("badges@3", nil, .fullColor))
        #expect(ArtKey.parse("oimg:cutouts#more", plain: .fullColor)! == ("cutouts#more", nil, .colorIn))
        #expect(ArtKey.parse("cut:characters:7", plain: .fullColor)! == ("characters", 7, .fullColor))
        // A round 45 game (schema 4): its items stay app-drawn, encode exactly as before, and never draw.
        var r45 = k; r45.items = r45.items.map { var i = $0; i.wholePage = nil; return i }
        var old = SavedGame(createdAt: Date(), title: "Sky", roles: roles, props: [], kit: r45, printStyle: .fullColor, art: [], voiceID: "v")
        old.schemaVersion = 4
        let text = String(decoding: try SavedGame.encoder().encode(old), as: UTF8.self)
        #expect(!text.contains("wholePage") && !text.contains("pageLines"))
        let back45 = try SavedGame.decode(SavedGame.encoder().encode(old))
        #expect(back45.schemaVersion == 4 && back45.kit.items.allSatisfy { $0.pictureOnly && !$0.aiPage })
        #expect(KitArtPlan.jobs(items: back45.kit.items, ctx: KitArtContext(title: "Sky", roles: roles), style: .fullColor, settled: [], characters: true).isEmpty)
        #expect(KitLayout.pages(for: back45.kit, roles: roles, playerCount: 3).allSatisfy { $0.artKey == $0.item.id })
        // A schema 3 game too.
        var r44 = a.kit; r44.items = r44.items.map { var i = $0; i.variant = nil; i.pictures = nil; return i }
        #expect(KitArtPlan.jobs(items: r44.items, ctx: KitArtContext(title: "Sky", roles: roles), style: .fullColor, settled: [], characters: true).isEmpty)
        let store = AdventureStore(service: nil)
        store.loadReplay(back45)
        #expect(store.isReplay && store.kit?.items == back45.kit.items)
    }
}
