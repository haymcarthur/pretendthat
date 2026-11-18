import Foundation
import Testing
@testable import NutmegCore

/// Round 47 (Haylee, decisions/2026-11-17-round47.md): the per-player pages (badges, tickets) are drawn ONCE for all 6
/// players as a strict grid; the app cuts out the first N pieces for the count the kids chose (`SheetCells`), so a
/// replay with any count reuses the same art. An outline page's words are read only when its color page missed.
@MainActor struct Round47Tests {
    let a = Fallback.airplane(playerCount: 4)
    var roles: [Role] { a.plan.roles }

    func page(_ t: KitRecipe, _ v: KitVariant? = nil, title: String, lines: [String] = [], pictures: [String]? = nil) -> KitItem {
        var i = PrintDefaults.item(t, title: title)
        i.lines = lines; i.pictures = pictures; i.variant = v ?? t.variants[0]; i.wholePage = true
        i.copies = PrintLibrary.copies(i)
        return i
    }

    // MARK: A synthetic drawn sheet

    /// A white sheet with `columns` × `rows` pieces: each a thick frame with a "character" inside, a dashed cut line
    /// around it (`dashed`), or a solid gray cut line (`solidCut`). `touch`: pieces 0 and 1 are joined by a bar.
    struct Sheet {
        var w = 1024, h = 1536
        var gray: [UInt8]
        var pieces: [CutoutSheet.Rect] = []
        init(columns: Int, rows: Int, count: Int? = nil, dashed: Bool = true, solidCut: Bool = false, touch: Bool = false,
             sizes: [Double]? = nil) {
            gray = [UInt8](repeating: 255, count: w * h)
            let cw = w / columns, ch = h / rows
            for k in 0..<(count ?? columns * rows) {
                let c = k % columns, r = k / columns
                let s = sizes.map { $0[k] } ?? 1
                let pw = Int(Double(cw - 70) * s), ph = Int(Double(ch - 70) * s)
                let x = c * cw + (cw - pw) / 2, y = r * ch + (ch - ph) / 2
                let p = CutoutSheet.Rect(x: x, y: y, width: pw, height: ph)
                pieces.append(p)
                frame(p, thick: 5, value: 60)
                fill(CutoutSheet.Rect(x: x + pw / 4, y: y + ph / 4, width: pw / 2, height: ph / 3), value: 120)   // the character
                let cut = CutoutSheet.Rect(x: x - 14, y: y - 14, width: pw + 28, height: ph + 28)
                if solidCut { frame(cut, thick: 2, value: 170) } else if dashed { dashes(cut, value: 170) }
            }
            if touch, pieces.count > 1 {
                let a = pieces[0], b = pieces[1]
                fill(CutoutSheet.Rect(x: a.x + a.width - 2, y: a.y + a.height / 2, width: b.x - (a.x + a.width) + 4, height: 6), value: 60)
            }
        }
        mutating func fill(_ r: CutoutSheet.Rect, value: UInt8) {
            for y in max(0, r.y)..<min(h, r.y + r.height) { for x in max(0, r.x)..<min(w, r.x + r.width) { gray[y * w + x] = value } }
        }
        mutating func frame(_ r: CutoutSheet.Rect, thick: Int, value: UInt8) {
            fill(CutoutSheet.Rect(x: r.x, y: r.y, width: r.width, height: thick), value: value)
            fill(CutoutSheet.Rect(x: r.x, y: r.y + r.height - thick, width: r.width, height: thick), value: value)
            fill(CutoutSheet.Rect(x: r.x, y: r.y, width: thick, height: r.height), value: value)
            fill(CutoutSheet.Rect(x: r.x + r.width - thick, y: r.y, width: thick, height: r.height), value: value)
        }
        mutating func dashes(_ r: CutoutSheet.Rect, value: UInt8) {
            for x in stride(from: r.x, to: r.x + r.width, by: 16) {
                fill(CutoutSheet.Rect(x: x, y: r.y, width: 8, height: 2), value: value)
                fill(CutoutSheet.Rect(x: x, y: r.y + r.height - 2, width: 8, height: 2), value: value)
            }
            for y in stride(from: r.y, to: r.y + r.height, by: 16) {
                fill(CutoutSheet.Rect(x: r.x, y: y, width: 2, height: 8), value: value)
                fill(CutoutSheet.Rect(x: r.x + r.width - 2, y: y, width: 2, height: 8), value: value)
            }
        }
        func find(_ expected: Int = 6) -> SheetCells.Grid? { SheetCells.find(gray: gray, width: w, height: h, expected: expected) }
    }

    static func inside(_ a: CutoutSheet.Rect, _ b: CutoutSheet.Rect) -> Bool { SheetCells.contains(a, b) }
    static func overlap(_ a: CutoutSheet.Rect, _ b: CutoutSheet.Rect) -> Bool { SheetCells.intersects(a, b) }

    // MARK: 1. Cutting the sheet apart

    @Test func aStrictGridIsCutIntoItsPiecesInReadingOrder() throws {
        for (cols, rows) in [(3, 2), (2, 3)] {
            let s = Sheet(columns: cols, rows: rows)
            let g = try #require(s.find())
            #expect(g.cells.count == 6 && g.columns == cols && g.rows == rows)
            for (k, cell) in g.cells.enumerated() {
                // Never clips a piece: its whole frame is inside the crop (reading order = the order drawn).
                #expect(Self.inside(cell.rect, s.pieces[k]), "\(cols)x\(rows) piece \(k)")
                // Never reaches another piece.
                for (j, other) in s.pieces.enumerated() where j != k { #expect(!Self.overlap(cell.rect, other)) }
                // Keeps a little paper around it (most of its own cut line), within the gutter.
                #expect(cell.rect.width <= s.pieces[k].width + 40 && cell.rect.height <= s.pieces[k].height + 40)
            }
        }
    }

    @Test func aSolidCutLineAroundEachPieceStillCutsApart() throws {
        let s = Sheet(columns: 2, rows: 3, solidCut: true)
        let g = try #require(s.find())
        #expect(g.cells.count == 6)
        for (k, cell) in g.cells.enumerated() { #expect(Self.inside(cell.rect, s.pieces[k])) }
    }

    @Test func aNeighborsDashesInsideACropArePaintedWhite() throws {
        // Narrow gutters: each crop's paper margin takes in the neighbor's cut line, which is erased.
        var s = Sheet(columns: 3, rows: 2, dashed: false)
        let p0 = s.pieces[0], p1 = s.pieces[1]
        let mid = (p0.x + p0.width + p1.x) / 2
        for y in stride(from: p1.y, to: p1.y + p1.height, by: 16) { s.fill(CutoutSheet.Rect(x: mid + 3, y: y, width: 2, height: 8), value: 170) }
        let g = try #require(s.find())
        let cell0 = g.cells[0]
        if cell0.rect.x + cell0.rect.width > mid + 3 {
            #expect(cell0.erase.contains { $0.x <= mid + 3 && $0.x + $0.width >= mid + 5 })
        }
        for e in cell0.erase { #expect(!Self.overlap(e, p0)) }   // never erases the piece itself
    }

    /// The live boarding passes (round 47): each ticket's stub is drawn as its own frame, and the seat number in it sits
    /// about as close to the NEXT ticket as to its own body. The stub joins its ticket first, so the number stays.
    @Test func aTicketsSeparateStubAndItsNumberStayWithTheTicket() throws {
        var s = Sheet(columns: 2, rows: 3, dashed: false)
        var stubs: [CutoutSheet.Rect] = []
        var numbers: [CutoutSheet.Rect] = []
        for k in s.pieces.indices {
            // Shrink the main ticket to its left 70% and draw the stub frame and its number to the right.
            let p = s.pieces[k]
            let main = CutoutSheet.Rect(x: p.x, y: p.y, width: p.width * 7 / 10, height: p.height)
            s.fill(CutoutSheet.Rect(x: p.x + p.width * 7 / 10, y: p.y, width: p.width - p.width * 7 / 10, height: p.height), value: 255)
            s.frame(main, thick: 5, value: 60)
            let stub = CutoutSheet.Rect(x: main.x + main.width + 4, y: p.y, width: p.width - main.width - 4, height: p.height)
            s.frame(stub, thick: 4, value: 60)
            let number = CutoutSheet.Rect(x: stub.x + stub.width - 22, y: stub.y + 30, width: 30, height: 40)   // pokes past the stub
            s.fill(number, value: 40)
            stubs.append(stub); numbers.append(number)
        }
        let g = try #require(s.find())
        for (k, cell) in g.cells.enumerated() {
            #expect(Self.inside(cell.rect, stubs[k]), "stub \(k)")
            #expect(Self.inside(cell.rect, numbers[k]), "number \(k)")
            for e in cell.erase { #expect(!Self.overlap(e, numbers[k]), "number \(k) erased") }
        }
    }

    @Test func anythingDoubtfulPrintsTheWholePage() {
        #expect(Sheet(columns: 3, rows: 2, touch: true).find() == nil)            // two pieces drawn touching
        #expect(Sheet(columns: 3, rows: 2, count: 5).find() == nil)               // 5 pieces drawn for 6
        #expect(Sheet(columns: 2, rows: 3).find(4) == nil)                        // more pieces than asked for
        #expect(Sheet(columns: 3, rows: 2, sizes: [1, 1, 1, 1, 1, 0.5]).find() == nil)   // not a grid of equal pieces
        #expect(SheetCells.find(gray: [UInt8](repeating: 255, count: 1024 * 1536), width: 1024, height: 1536, expected: 6) == nil)
        #expect(SheetCells.find(gray: [], width: 0, height: 0, expected: 6) == nil)
    }

    // MARK: 2. Laying the first N pieces on the paper

    @Test func theFirstNPiecesPrintInsideTheMarginsAtThePagesOwnScale() throws {
        let letter = CGSize(width: 612, height: 792)
        let box = CGRect(x: 36, y: 36, width: 540, height: 720)
        let fit = PageFit.rect(image: CGSize(width: 1024, height: 1536), page: letter)
        let scale = fit.width / 1024
        for (cols, rows) in [(3, 2), (2, 3)] {
            let g = try #require(Sheet(columns: cols, rows: rows).find())
            let sizes = g.cells.map { CGSize(width: $0.rect.width, height: $0.rect.height) }
            for n in 1...6 {
                let r = SheetCells.layout(sizes: Array(sizes.prefix(n)), columns: g.columns, scale: scale, box: box)
                #expect(r.count == n)
                for (k, rect) in r.enumerated() {
                    #expect(box.insetBy(dx: -0.01, dy: -0.01).contains(rect), "\(cols)x\(rows) n=\(n) piece \(k)")
                    #expect(abs(rect.width - sizes[k].width * scale) < 0.01)   // same size as on the whole page
                    for other in r[(k + 1)...] { #expect(!rect.intersects(other)) }
                }
                #expect(abs(r[0].minY - box.minY) < 0.01)                       // from the top of the printable area
                #expect(r.prefix(min(n, g.columns)).map(\.minX) == r.prefix(min(n, g.columns)).map(\.minX).sorted())   // reading order
            }
        }
        // Pieces too big for the paper shrink evenly and still fit.
        let big = SheetCells.layout(sizes: Array(repeating: CGSize(width: 900, height: 900), count: 4), columns: 2, scale: 1, box: box)
        #expect(big.allSatisfy { box.insetBy(dx: -0.01, dy: -0.01).contains($0) } && Set(big.map { Int($0.width) }).count == 1)
    }

    // MARK: 3. The pages are drawn for 6 and print N

    func pirates() -> [Role] {
        RoleCast.rank(["Captain", "Map Reader", "Clue Finder", "Lookout", "First Mate", "Ship's Cook"].enumerated().map { i, n in
            Role(id: RoleID.allCases[i], roleName: n, emoji: "", symbol: "star", job: "a pirate job")
        })
    }

    @Test func badgesAreDrawnOnceForAllSixRolesInRankOrderAsAStrictGrid() {
        let six = pirates()
        for v in KitRecipe.badges.variants {
            let item = page(.badges, v, title: "Crew")
            var prompts = Set<String>()
            for n in 1...6 {
                let p = KitPagePrompt.prompt(for: item, ctx: KitArtContext(title: "Treasure", roles: six, players: n), style: .fullColor)!
                prompts.insert(p.prompt)
                #expect(p.words == six.map(\.roleName) + Array(repeating: "Name:", count: 6))
                let g = KitPagePrompt.badgeGrid(v)
                #expect(p.prompt.contains("strict grid of \(g.columns) columns and \(g.rows) rows"))
                #expect(p.prompt.contains("equal wide plain white gutters") && p.prompt.contains("dashed cut lines"))
                // In rank order, reading order.
                let at = six.map { p.prompt.range(of: "title \"\($0.roleName)\"")!.lowerBound }
                #expect(at == at.sorted() && p.prompt.contains("left to right, top to bottom"))
            }
            #expect(prompts.count == 1)   // the count never changes the page
        }
        #expect(KitPagePrompt.badgeGrid(.lanyard) == (3, 2) && KitPagePrompt.badgeGrid(.pin) == (2, 3) && KitPagePrompt.badgeGrid(.idCard) == (2, 3))
    }

    @Test func ticketsAreDrawnOnceForSixPlayersAsAStrictGrid() {
        let item = page(.tickets, .boarding, title: "Boarding Pass", lines: ["Sky Trip"], pictures: ["a plane"])
        let p = KitPagePrompt.prompt(for: item, ctx: KitArtContext(title: "Sky", roles: roles, players: 2), style: .fullColor)!
        #expect(p.prompt.contains("exactly 6 passes in a strict grid of 2 columns and 3 rows"))
        #expect(KitPagePrompt.ticketNumbers(item) == ["1A", "1B", "1C", "1D", "2A", "2B"])
        // The fallback page numbers its first N copies the same way.
        #expect((0..<6).map { PrintLibrary.copyNumber(item, index: $0) } == KitPagePrompt.ticketNumbers(item))
    }

    @Test func onlyBadgesAndTicketsArePerPlayer() {
        // The library's per-player types (one per kid): everything else prints its own entries, whatever the count.
        #expect(KitRecipe.allCases.filter(\.perPlayer) == [.badges, .tickets])
        for t in KitRecipe.allCases {
            let item = page(t, title: "X", lines: ["One", "Two"])
            #expect(KitArtPlan.perPlayerSheet(item) == t.perPlayer)
            #expect(KitArtPlan.pieces(item) == (t.perPlayer ? 6 : 0))
        }
    }

    @Test func everyCountPrintsItsFirstNPiecesOfTheSameArt() {
        let items = [page(.badges, .lanyard, title: "Crew"), page(.tickets, .admission, title: "Show", pictures: ["a tent"]),
                     page(.sign, title: "Sky", lines: ["Open"])]
        let kit = Kit(nutmegSays: "", items: items, scenes: [])
        for n in 1...6 {
            let pages = KitLayout.pages(for: kit, roles: roles, playerCount: n)
            #expect(pages.map(\.artKey) == ["badges@all", "tickets@all", "sign"])
            #expect(pages.map(\.pieces) == [n, n, nil])
            #expect(pages[0].slots.map(\.role) == RoleCast.playing(roles, kids: n).map(\.roleName))   // the first N ranked roles
            #expect(pages.map(\.legacyArtKey) == ["badges@\(n)", "tickets", nil])
        }
        // The jobs never depend on the count, and a new count draws nothing.
        let ctx = KitArtContext(title: "Sky", roles: roles, players: 2)
        let jobs = KitArtPlan.jobs(items: items, ctx: ctx, style: .colorIn, settled: [])
        #expect(jobs.map(\.key) == ["badges@all", "tickets@all", "sign"] && jobs.map(\.pieces) == [6, 6, 0])
        for n in 1...6 {
            var c = ctx; c.players = n
            #expect(KitArtPlan.jobs(items: items, ctx: c, style: .colorIn, settled: Set(jobs.map(\.key))).isEmpty)
            #expect(KitArtPlan.jobs(items: items, ctx: c, style: .colorIn, settled: []).map(\.prompt) == jobs.map(\.prompt))
        }
        #expect(KitArtPlan.isPerPlayerKey("badges@all") && !KitArtPlan.isPerPlayerKey("badges@3") && !KitArtPlan.isPerPlayerKey("tickets"))
    }

    @Test func aSixPrintableKitDrawsNoMoreImagesThanRound46() {
        // Round 46: one page per printable per set (+ the character sheet and the cover per game). Round 47: the same,
        // and a count change no longer adds a badge page.
        let items = Sanitizer.clean(Kit(nutmegSays: "", items: a.kit.items, scenes: []), picks: PrintPicks.make(game: ["airplane"])).items
        #expect(items.count == 6)
        let ctx = KitArtContext(title: "Sky", roles: roles, players: 3)
        for style in PrintStyle.sets { #expect(KitArtPlan.jobs(items: items, ctx: ctx, style: style, settled: []).count == 6) }
        #expect(KitArtPlan.jobs(items: items, ctx: ctx, style: .fullColor, settled: [], characters: true).count == 7)
    }

    // MARK: 4. Saved games

    @Test func round46GamesStillReplayWithTheirOwnPages() throws {
        var k = a.kit
        k.items = Sanitizer.clean(Kit(nutmegSays: "", items: a.kit.items, scenes: []), picks: PrintPicks.make(game: ["airplane"])).items
        // A round 46 game: its badge page saved for 3 kids, its ticket page under the item id.
        let r46 = SavedGame(createdAt: Date(), title: "Sky", roles: roles, props: [], kit: k, printStyle: .fullColor,
                            art: ["img:badges@3", "img:tickets", "oimg:badges@3", "cut:characters:0"], voiceID: "v")
        let back = try SavedGame.decode(SavedGame.encoder().encode(r46))
        #expect(back.schemaVersion == SavedGame.currentSchema && SavedGame.currentSchema == 5)   // no schema bump needed
        let keys = Set(back.art.compactMap { ArtKey.parse($0, plain: .fullColor) }.filter { $0.style == .fullColor && $0.index == nil }.map(\.itemID))
        let pages3 = KitLayout.pages(for: back.kit, roles: roles, playerCount: 3)
        let badge3 = try #require(pages3.first { $0.item.recipe == .badges })
        // The new key isn't there; the round 46 page is found under its own key and prints whole.
        #expect(!keys.contains(badge3.artKey) && keys.contains(badge3.legacyArtKey!))
        if let ticket = pages3.first(where: { $0.item.recipe == .tickets }) { #expect(keys.contains(ticket.legacyArtKey!)) }
        // A replay never draws (the art service is only restored; KitArtPlan isn't asked).
        // A round 47 game's keys round-trip.
        #expect(ArtKey.parse("img:badges@all", plain: .fullColor)! == ("badges@all", nil, .fullColor))
        #expect(ArtKey.parse("oimg:tickets@all", plain: .fullColor)! == ("tickets@all", nil, .colorIn))
    }

    // MARK: 5. The outline word check (Haylee's option b)

    @Test func anOutlinePageIsReadOnlyWhenItsColorPageMissed() {
        typealias A = OutlineWordCheck.Action
        // The color set always reads its pages.
        for missed in [nil, true, false] as [Bool?] {
            #expect(OutlineWordCheck.action(style: .fullColor, colorMissed: missed, colorSettled: false) == .check)
        }
        #expect(OutlineWordCheck.action(style: .colorIn, colorMissed: true, colorSettled: false) == A.check)
        #expect(OutlineWordCheck.action(style: .colorIn, colorMissed: false, colorSettled: false) == A.keep)
        #expect(OutlineWordCheck.action(style: .colorIn, colorMissed: nil, colorSettled: false) == A.wait)
        #expect(OutlineWordCheck.action(style: .colorIn, colorMissed: nil, colorSettled: true) == A.keep)   // color failed: no check
    }
}
