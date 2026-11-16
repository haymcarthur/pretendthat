import Foundation
import Testing
@testable import NutmegCore

/// Round 24 (Haylee): props must make sense (a bowl is never a pirate map), and "Do you have a printer?" with the
/// no-printer "Draw it!" path.
@MainActor struct Round24Tests {

    // MARK: 1. Props that make sense

    @Test(arguments: [
        ("bowl", "the pirate map", false),
        ("bowl", "captain hat", true),
        ("bowl", "the captain's hat", true),
        ("towel", "cape", true),
        ("pillowcase", "treasure map", true),
        ("chair", "airplane seats", true),
        ("plate", "the steering wheel", true),
        ("spoon", "the big stirrer", true),
        ("blanket", "the big blue ocean", true),
        ("cardboard-box", "the rocket ship", true),
        ("cup", "the pirate map", false),
        ("broom", "the captain's hat", false),
        ("hat", "the superhero cape", false),
        ("spoon", "the airplane seats", false),
        ("stuffed-animal", "the treasure chest", false),
        ("plate", "the magic wand", false),
        ("bowl", "the treasure", true),          // an unrecognized use is allowed (no false rejections)
    ])
    func pairTable(item: String, becomes: String, ok: Bool) {
        #expect(PropFit.fits(itemID: item, becomes: becomes) == ok, "\(item) → \(becomes)")
    }

    @Test func everyLibraryItemHasTagsAndSensibleCuratedUses() {
        for id in PropLibrary.ids {
            #expect(PropLibrary.tags[id] != nil, "\(id) has no tags")
            let uses = PropLibrary.uses[id] ?? []
            #expect(!uses.isEmpty, "\(id) has no curated use")
            for u in uses {
                #expect(PropFit.fits(itemID: id, becomes: u.becomes), "\(id) → \(u.becomes)")
                #expect(u.reason.hasSuffix("!") && u.reason.split(separator: " ").count <= 14)
                #expect(Sanitizer.kidSafety(u.reason) == nil)
            }
        }
    }

    @Test func reasonsAreShortAndKidFriendly() {
        #expect(PropFit.reason(itemID: "bowl", becomes: "the captain's hat") == "A bowl is round like a captain's hat!")
        #expect(PropFit.reason(itemID: "towel", becomes: "a cape") == "A towel is big and floppy like a cape!")
        #expect(PropFit.reason(itemID: "chair", becomes: "airplane seats") == "A chair is just right for sitting, like a seat on a plane!")   // curated
        #expect(PropFit.reason(itemID: "stool", becomes: "the airplane seats") == "A step stool is just right for sitting, like airplane seats!")
        #expect(PropFit.reason(itemID: "books", becomes: "the spell book") == "Books have flat pages like a spell book!"
                || PropFit.reason(itemID: "books", becomes: "the spell book").hasPrefix("Books "))
        // The model's own reason is kept when it's short; a long or unsafe one is replaced.
        #expect(PropFit.keptReason("A bowl fits on your head!", itemID: "bowl", becomes: "the captain's hat") == "A bowl fits on your head!")
        #expect(PropFit.keptReason("", itemID: "bowl", becomes: "the captain's hat") == "A bowl is round like a captain's hat!")
        #expect(PropFit.keptReason(String(repeating: "word ", count: 30), itemID: "bowl", becomes: "the captain's hat") == "A bowl is round like a captain's hat!")
    }

    @Test func fallbackPicksAnItemThatFitsTheUse() {
        let f = PropFit.fallback(becomes: "the pirate map", preferring: ["cup", "towel"])
        #expect(f.itemID == "towel" && f.becomes == "the pirate map" && PropFit.fits(itemID: f.itemID, becomes: f.becomes))
        let g = PropFit.fallback(becomes: "the pirate map", avoiding: ["towel", "blanket", "rug", "sheet", "table", "plate", "tray", "books", "pillow", "teddy-bed", "cushion", "stool"])
        #expect(PropFit.fits(itemID: g.itemID, becomes: g.becomes))
    }

    private func hunting(_ store: AdventureStore) async {
        store.beginConversation()
        _ = await store.apply(.setGame("Pirate Ship")); _ = await store.apply(.setTheme("Pirate Ship on the Moon"))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmWithPrinter()
        _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles([.init(roleName: "Captain", job: ""), .init(roleName: "Navigator", job: "")]))
    }

    @Test func aMisfitGetsOneRetryThenACuratedPair() async {
        let store = AdventureStore(service: nil)
        await hunting(store)
        let first = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the pirate map", forRole: "all", alternates: ["towel"])))
        #expect(first.contains("Not shown") && first.contains("towel") && store.props == nil)     // the retry, no card
        let second = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the pirate map", forRole: "all", alternates: ["towel"])))
        let p = store.props?.props.first
        #expect(p?.libraryID == "towel" && p?.becomes == "the pirate map" && second.contains("didn't fit"))
        #expect(p.map { PropFit.fits(itemID: $0.libraryID!, becomes: $0.becomes) } == true)
        #expect((p?.reason ?? "").contains("towel"))
    }

    @Test func aGoodPairKeepsItsReasonAndSaysItInTheLine() async {
        let store = AdventureStore(service: nil)
        await hunting(store)
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the captain's hat", forRole: "all", alternates: ["pot", "spoon"],
                                                  reason: "A bowl is round like a captain's hat!")))
        _ = await store.apply(.markFound("bowl"))
        let next = await store.apply(.showNextProp(.init(itemID: "towel", becomes: "the pirate flag", forRole: "all", reason: "")))
        #expect(store.props?.props.first?.reason == "A bowl is round like a captain's hat!")
        #expect(store.props?.props.first?.alternates == ["pot"])                   // a spoon can't be a hat: dropped
        #expect(next.contains("why it works") && next.contains("towel is"))
        #expect(AdventureStore.firstPropLine(item: "Bowl", becomes: "the captain's hat", reason: "A bowl is round like a captain's hat!")
            .contains("round like a captain's hat"))
    }

    @Test func aSwapMustFitTheUseToo() async {
        let store = AdventureStore(service: nil)
        await hunting(store)
        _ = await store.apply(.showNextProp(.init(itemID: "towel", becomes: "the pirate map", forRole: "all")))
        let retry = await store.apply(.swapProp(oldID: "towel", newID: "bowl", becomes: ""))
        #expect(retry.contains("Not shown") && store.props?.props.first?.libraryID == "towel")
        _ = await store.apply(.swapProp(oldID: "towel", newID: "bowl", becomes: ""))
        let p = store.props?.props.first
        #expect(p?.libraryID != "bowl" && PropFit.fits(itemID: p?.libraryID ?? "", becomes: "the pirate map"))
    }

    @Test func claudesPropListIsRepaired() async throws {
        let bad = Props(nutmegSays: "Go find these!", props: [
            Prop(id: "bowl", householdItem: "Bowl", becomes: "the pirate map", forRole: .all, safetyOK: true, libraryID: "bowl"),
            Prop(id: "towel", householdItem: "Towel", becomes: "the cape", forRole: .all, safetyOK: true, libraryID: "towel"),
            Prop(id: "chair", householdItem: "Chair", becomes: "the ship's seats", forRole: .all, safetyOK: true, libraryID: "chair"),
        ])
        #expect(Validate.props(bad)?.message.contains("Bowl as the pirate map") == true)
        let llm = FakeLLM(responses: ["Props": bad])
        let made = try await PhaseService(llm: llm).props(ctx: AdventureContext(gameTitle: "Pirates", playerCount: 2))
        #expect(llm.calls == 2)                                                     // one retry
        #expect(made.props.allSatisfy { PropFit.fits(itemID: $0.libraryID ?? $0.id, becomes: $0.becomes) })
        #expect(made.props.allSatisfy { !($0.reason ?? "").isEmpty })
        #expect(Fallback.airplane.props.props.allSatisfy { PropFit.fits(itemID: $0.libraryID ?? $0.id, becomes: $0.becomes) })
    }

    @Test func showNextPropDecodesTheReason() {
        let call = PlanningCall.decode(name: "show_next_prop", arguments: #"{"item_id":"bowl","becomes":"the captain's hat","for_role":"all","alternates":[],"reason":"A bowl is round!"}"#)
        if case .showNextProp(let d) = call { #expect(d.reason == "A bowl is round!") } else { Issue.record("no decode") }
        let tool = Realtime.tools.first { $0["name"] as? String == "show_next_prop" }
        let req = (tool?["parameters"] as? [String: Any])?["required"] as? [String]
        #expect(req?.contains("reason") == true)
    }

    // MARK: 2. Printer question + Draw it!

    private func confirmed(_ store: AdventureStore, kids: Int = 3) async {
        store.beginConversation()
        _ = await store.apply(.setGame("Pirate Ship")); _ = await store.apply(.setTheme("Pirate Ship on the Moon"))
        _ = await store.apply(.setPlayerCount(kids))
    }

    @Test func thePrinterQuestionComesRightAfterTheYes() async {
        let store = AdventureStore(service: nil)
        await confirmed(store)
        let yes = await store.apply(.confirmPlan)
        #expect(store.planningStep == .printer && yes.contains(PrinterChoice.question) && !yes.contains(ColorChoice.question))
        let early = await store.apply(.setRoles([.init(roleName: "Captain", job: "")]))
        #expect(early.contains("printer question") && store.plan == nil)
        // Yes: the color question (round 20), then the roles.
        let printer = await store.apply(.setPrinter(true))
        #expect(store.hasPrinter == true && store.planningStep == .color && printer.contains(ColorChoice.question))
        _ = await store.apply(.setPrintStyle(.fullColor))
        #expect(store.planningStep == .roles)
        #expect(Realtime.kidTurnTools(step: .printer, huntActive: false)?.first == "set_printer")
        #expect(TurnCheck.nudge(for: "Ooh, pirates on the moon!", step: .printer) != nil)
        #expect(TurnCheck.nudge(for: "Do you have a printer?", step: .printer) == nil)
    }

    @Test func noPrinterSkipsTheColorQuestionAndNeverWritesPages() async {
        let llm = FakeLLM(responses: ["DrawGuide": Self.guide])
        let store = AdventureStore(service: PhaseService(llm: llm))
        await confirmed(store)
        _ = await store.apply(.confirmPlan)
        let no = await store.apply(.setPrinter(false))
        #expect(store.drawMode && store.planningStep == .roles && !no.contains(ColorChoice.question) && no.contains("start_planning"))
        _ = await store.apply(.setRoles([.init(roleName: "Captain", job: ""), .init(roleName: "Navigator", job: ""), .init(roleName: "Lookout", job: "")]))
        #expect(store.draftStartedAt == nil)                                       // no printable pages, no art
        _ = await store.apply(.showNextProp(.init(itemID: "towel", becomes: "the pirate map", forRole: "all")))
        _ = await store.apply(.markFound("towel"))
        _ = await store.apply(.finishPlanning)
        for _ in 0..<300 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(store.phase == .kitReady && store.drawing)
        #expect(!llm.users.contains { $0.contains("Phase: printable kit pages") || $0.contains("Phase: printable kit and scenes") })
        #expect(llm.users.filter { $0.contains("DRAW their own play kit") }.count == 1)    // written during the hunt
        #expect(llm.users.last?.contains("the kids DREW these kit pieces") == true)
        #expect(store.kit?.items.allSatisfy { $0.id.hasPrefix("draw-") } == true)
        // Draw it!: one piece at a time, Next, again, then Play.
        let g = store.drawGuide!
        #expect(store.drawIndex == 0 && store.drawLine?.hasPrefix("Let's draw your kit!") == true && store.drawLine?.contains("Tap Next") == true)
        #expect(store.drawLine?.contains("Make three, one for each friend.") == true)              // badges = players
        let again = await store.apply(.drawStep(next: false))
        #expect(again.contains(store.drawLine!) && store.drawIndex == 0)
        let next = await store.apply(.drawStep(next: true))
        #expect(store.drawIndex == 1 && next.contains(DrawIt.line(g, 1)))
        while store.drawIndex < g.pieces.count - 1 { store.drawNext() }
        #expect(store.drawLine?.contains("Then tap Let's play!") == true)
        let play = await store.apply(.drawStep(next: true))
        #expect(play.contains("Play started") && store.phase.step == .play && !store.drawing)
        // Back to Paper starts the drawing again from the first piece.
        #expect(store.goTo(.print) && store.drawing && store.drawIndex == 0)
        #expect(Realtime.afterHuntTools(.kitReady, drawing: true) == ["draw_step", "start_play", "go_to_step", "just_talk"])
        // Changing the printer answer after the hunt changes nothing.
        let late = await store.apply(.setPrinter(true))
        #expect(store.drawMode && late.contains(DrawIt.saveLabel))
        // Save printables for later: the normal pages (coloring pages), made on demand.
        let printables = await store.makePrintables()
        #expect(printables?.items.count == 6 && llm.users.last?.contains("Phase: printable kit pages") == true)
    }

    @Test func aPrinterAnswerMidHuntSwitchesTheKit() async {
        let store = AdventureStore(service: nil)
        await confirmed(store, kids: 1)
        _ = await store.apply(.confirmPlan); _ = await store.apply(.setPrinter(false))
        _ = await store.apply(.setRoles([.init(roleName: "Captain", job: "")]))
        let change = await store.apply(.setPrinter(true))
        #expect(store.hasPrinter == true && store.printStyle == .colorIn && change.contains("print the kit") && store.planningStep == .props)
        #expect(PlanningCall.decode(name: "set_printer", arguments: #"{"has_printer":false}"#) == .setPrinter(false))
        #expect(PlanningCall.decode(name: "draw_step", arguments: #"{"action":"again"}"#) == .drawStep(next: false))
    }

    @Test func withoutClaudeTheBundledDrawGuideIsUsed() async {
        let store = AdventureStore(service: nil)
        await confirmed(store, kids: 8)                   // over the cap: stays at the question
        _ = await store.apply(.setPlayerCount(6))
        _ = await store.apply(.confirmPlan); _ = await store.apply(.setPrinter(false))
        _ = await store.apply(.setRoles((0..<6).map { .init(roleName: "Pirate \($0)", job: "") }))
        _ = await store.apply(.finishPlanning)
        for _ in 0..<300 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(store.drawing && store.drawGuide?.pieces.first?.kind == .badges && store.drawGuide?.pieces.first?.count == 6)
        #expect(store.drawGuide?.pieces.first { $0.kind == .money }?.instruction == DrawIt.moneyInstruction)
    }

    // MARK: The simple guide's limits

    static let guide = DrawGuide(nutmegSays: "Let's draw!", pieces: [
        DrawPiece(id: "1", kind: .badges, title: "Pirate badges", symbol: "star", instruction: "Draw a big star. Write your job in the middle."),
        DrawPiece(id: "2", kind: .money, title: "Gold money", symbol: "banknote", instruction: "Draw a rectangle. Write $1 inside."),
        DrawPiece(id: "3", kind: .thing, title: "Treasure map", symbol: "map", instruction: "Draw a big square. Draw an X on it."),
    ])

    @Test func cleanEnforcesTheLimits() {
        let long = DrawGuide(nutmegSays: "", pieces: [
            DrawPiece(id: "a", kind: .money, title: "Big shiny gold money bills", symbol: "rocket.fill",
                      instruction: "Draw a rectangle. Write $5 in it. Then color it green. Then cut it out.", count: 9),
            DrawPiece(id: "b", kind: .badges, title: "Badges", symbol: "star", instruction: "Draw a star.", count: 2),
            DrawPiece(id: "c", kind: .badges, title: "More badges", symbol: "star", instruction: "Draw a heart."),
            DrawPiece(id: "d", kind: .thing, title: "Coin", symbol: "star", instruction: "Draw a circle. Color it gold."),
            DrawPiece(id: "e", kind: .thing, title: "Key", symbol: "key", instruction: "Draw a circle and a long line with little bumps on the end of it for the teeth of the key."),
            DrawPiece(id: "f", kind: .sign, title: "Sign", symbol: "flag", instruction: "Draw a big rectangle."),
            DrawPiece(id: "g", kind: .menu, title: "Menu", symbol: "fork.knife", instruction: "Draw a box."),
            DrawPiece(id: "h", kind: .tickets, title: "Tickets", symbol: "ticket", instruction: "Draw a ticket."),
        ])
        #expect(DrawIt.problem(long) != nil)
        let c = DrawIt.clean(long, playerCount: 9)
        #expect(c.pieces.count == DrawIt.maxPieces)
        #expect(c.pieces.first?.kind == .badges && c.pieces.first?.count == Players.max)          // badges first, capped at 6
        #expect(c.pieces.filter { $0.kind == .badges }.count == 1)
        let money = c.pieces.first { $0.kind == .money }
        #expect(money?.instruction == DrawIt.moneyInstruction && money?.count == DrawIt.moneyCount && money?.symbol == "banknote")
        #expect(money?.title == "Big shiny gold")
        for p in c.pieces {
            #expect(DrawIt.sentences(p.instruction).count <= DrawIt.maxSentences, "\(p.instruction)")
            #expect(DrawIt.words(p.instruction).count <= DrawIt.maxWords, "\(p.instruction)")
            #expect(DrawIt.symbols.contains(p.symbol) && PrintSymbols.allowlist.contains(p.symbol))
        }
        #expect(DrawIt.problem(Self.guide) == nil)
        #expect(DrawIt.problem(DrawGuide(nutmegSays: "", pieces: [])).map(\.fatal) == true)
        #expect(DrawIt.moneyOK("Draw a rectangle. Write $1 in the middle.") && !DrawIt.moneyOK("Write $5 on it."))
    }

    @Test func drawnPiecesBecomeKitItemsThePlayGuideCanPointAt() {
        let g = DrawIt.clean(Self.guide, playerCount: 2)
        let items = DrawIt.kitItems(g)
        let kit = Kit(nutmegSays: "", items: items, scenes: [])
        let roles = [Role(id: .R1, roleName: "Captain", emoji: "", symbol: "star", job: "")]
        #expect(PictureResolver.resolve(.kit("money"), kit: kit, roles: roles) == .kitItem(itemID: "draw-money", recipe: .money, role: nil))
        #expect(PictureResolver.resolve(.kit("cutout:0"), kit: kit, roles: roles) == .cutout(itemID: "draw-things", index: 0, label: "Treasure map"))
        #expect(DrawIt.symbol(forItem: "draw-things", cutout: 0, in: g) == "map")
        #expect(DrawIt.line(g, 0).contains("Make two, one for each friend."))
        #expect(DrawIt.line(g, 1).hasPrefix("Next, gold money!") && DrawIt.line(g, 1).contains("Make five of them."))
    }

    @Test func printerStepIsInTheRealtimeInstructions() {
        #expect(Realtime.instructions.contains("3c. PRINTER") && Realtime.instructions.contains(PrinterChoice.question))
        #expect(Realtime.tools.contains { $0["name"] as? String == "set_printer" })
        #expect(Realtime.tools.contains { $0["name"] as? String == "draw_step" })
        #expect(BackNav.arrivalLine(.print, drawing: true).contains("draw"))
    }
}
