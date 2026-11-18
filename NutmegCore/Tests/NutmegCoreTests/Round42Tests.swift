import Foundation
import Testing
@testable import NutmegCore

/// Round 42 (Haylee's fresh-install test): no bookshelf moment and a new End line; props are never things the kit
/// prints; Nutmeg offers exactly the 3 games and 3 twists the app sampled, and the samples avoid the last 3 sessions.
@MainActor struct Round42Tests {

    // MARK: 7. No bookshelf moment; the End line says the game is saved

    @Test func theEndLineIsExactlyHaylees() {
        #expect(HandOffLines.end() == "The end! What a game! Take a bow! This game is saved, so you can play it again later. Tap the arrow to play it again, or the house to go home!")
        #expect(HandOffLines.end(replay: true) == HandOffLines.end())
        #expect(CommonLines.all.contains(HandOffLines.end()))   // a bundled clip (recorded with -PTRecordCommon)
        #expect(ClipMeta.kind(of: HandOffLines.end()) == .end)
        #expect(Sanitizer.kidSafety(HandOffLines.end()) == nil)
    }

    @Test func kidsNeverHearBookshelf() {
        // Every fixed line she says (bundled lines, the End, the saved-game lines) and the coaching that could be echoed.
        let lines = CommonLines.all + [HandOffLines.end(), ShelfLines.soundsLike(title: "Pet Vet"), ShelfLines.soundsLikeOutput,
                                       ShelfLines.newGameNote(playerCount: 3), ReplayLines.savedGame, Realtime.instructions]
        for l in lines { #expect(!l.lowercased().contains("bookshelf") && !l.lowercased().contains("shelf"), "\(l.prefix(60))") }
    }

    @Test func theStoreEndsWithTheNewLine() async {
        let store = AdventureStore(service: nil)
        await store.start(); await store.chooseGame("Airplane"); store.setPlayerCount(2)
        await store.confirmPlayers(); await store.confirmRoles(); await store.confirmProps()
        store.beginPlay()
        while case .scene = store.phase { store.nextScene() }
        #expect(store.phase == .end && store.nutmegLine.hasSuffix(HandOffLines.end()))
    }

    // MARK: 8. Props are never things the kit prints

    @Test(arguments: [
        ("boarding passes", true), ("the boarding passes", true), ("the tickets", true), ("the train ticket", true),
        ("the money", true), ("the gold coins", true), ("Sky Bucks", true), ("the menu", true), ("the pirate map", true),
        ("the treasure map of the island", true), ("the sign", true), ("the name badges", true), ("the room keycards", true),
        ("the secret letter", true), ("the price list", true), ("the passports", true),
        ("the snack cart", false), ("the captain's hat", false), ("the ticket booth", false), ("the money box", false),
        ("the steering wheel", false), ("the treasure chest", false), ("the pirate sail", false), ("the menu board stand", false),
    ])
    func printedThingsByWord(becomes: String, printed: Bool) {
        #expect((PrintedProps.clash(becomes) != nil) == printed, "\(becomes)")
    }

    @Test func paperAsBoardingPassesIsRejected() {
        #expect(!PropFit.fits(itemID: "paper", becomes: "boarding passes"))
        #expect(!PropFit.fits(itemID: "sticky-notes", becomes: "the tickets"))
        #expect(!PropFit.fits(itemID: "plate", becomes: "the gold coin"))
        #expect(!PropFit.fits(itemID: "towel", becomes: "the treasure map"))
        #expect(!PropFit.fits(itemID: "paper", becomes: "the fan"))   // 2026-11-17: plain paper is never a prop at all
    }

    @Test func noCuratedOrFallbackPairIsAPrintedThing() {
        for (id, uses) in PropLibrary.uses {
            for u in uses { #expect(PrintedProps.clash(u.becomes) == nil, "\(id) → \(u.becomes)") }
        }
        let f = PropFit.fallback(becomes: "boarding passes", preferring: ["paper"])
        #expect(PrintedProps.clash(f.becomes) == nil && PropFit.fits(itemID: f.itemID, becomes: f.becomes))
    }

    @Test func theKitsOwnPrintedThingsCountToo() {
        let kit = [
            KitItem(id: "t", recipe: .tickets, kind: .card, size: .ticket, title: "Sky Airlines Boarding Pass", symbol: "airplane",
                    lines: [], bigNumber: nil, perPlayer: true, copies: 1, colorMe: false),
            KitItem(id: "m", recipe: .money, kind: .card, size: .bill, title: "Cloud Bucks", symbol: "dollarsign.circle",
                    lines: [], bigNumber: "$1", perPlayer: false, copies: 8, colorMe: false),
            KitItem(id: "c", recipe: .cutouts, kind: .sheet, size: .fullPage, title: "Snacks and Bags", symbol: "bag",
                    lines: ["Pretzel Pack", "Suitcase", "Juice Boxes"], bigNumber: nil, perPlayer: false, copies: 1, colorMe: false),
            KitItem(id: "s", recipe: .sign, kind: .sheet, size: .fullPage, title: "Sky Airlines Gate 3", symbol: "airplane",
                    lines: [], bigNumber: nil, perPlayer: false, copies: 1, colorMe: false),
        ]
        #expect(PrintedProps.clash("the suitcase", kit: kit) == "suitcase")       // a printed cut-out
        #expect(PrintedProps.clash("the juice boxes", kit: kit) == "box")
        #expect(PrintedProps.clash("the suitcase") == nil)                         // fine when the kit doesn't print one
        #expect(PrintedProps.clash("the airplane seats", kit: kit) == nil)        // the sign's place name doesn't count
        #expect(PrintedProps.clash("the gate", kit: kit) == nil)
    }

    private func hunting(_ store: AdventureStore) async {
        store.beginConversation()
        _ = await store.apply(.setGame("Airplane")); _ = await store.apply(.setTheme("Airplane to the Beach"))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
        _ = await store.apply(.setRoles([.init(roleName: "Pilot", job: ""), .init(roleName: "Passenger", job: "")]))
    }

    @Test func showNextPropRejectsPaperAsBoardingPassesThenFallsBack() async {
        let store = AdventureStore(service: nil)
        await hunting(store)
        let first = await store.apply(.showNextProp(.init(itemID: "sticky-notes", becomes: "boarding passes", forRole: "all", alternates: ["tape"])))
        #expect(first.contains("Not shown") && first.contains("printed kit") && store.props == nil)   // one retry, no card
        let second = await store.apply(.showNextProp(.init(itemID: "sticky-notes", becomes: "boarding passes", forRole: "all", alternates: ["tape"])))
        let p = store.props?.props.first
        #expect(p != nil && second.contains("didn't fit"))
        #expect(PrintedProps.clash(p?.becomes ?? "x map") == nil && PropFit.fits(itemID: p?.libraryID ?? "", becomes: p?.becomes ?? ""))
        // A good prop afterwards is shown at once.
        _ = await store.apply(.markFound(p!.id))
        let next = await store.apply(.showNextProp(.init(itemID: "chair", becomes: "the airplane seats", forRole: "all")))
        #expect(!next.contains("Not shown") && store.props?.props.last?.libraryID == "chair")
    }

    @Test func aSwapIntoAPrintedThingIsRejected() async {
        let store = AdventureStore(service: nil)
        await hunting(store)
        _ = await store.apply(.showNextProp(.init(itemID: "chair", becomes: "the airplane seats", forRole: "all")))
        let retry = await store.apply(.swapProp(oldID: "chair", newID: "sticky-notes", becomes: "the tickets"))
        #expect(retry.contains("Not shown") && store.props?.props.first?.libraryID == "chair")
        _ = await store.apply(.swapProp(oldID: "chair", newID: "sticky-notes", becomes: "the tickets"))
        let p = store.props?.props.first
        #expect(PrintedProps.clash(p?.becomes ?? "x map") == nil && PropFit.fits(itemID: p?.libraryID ?? "", becomes: p?.becomes ?? ""))
    }

    @Test func claudesPropListNeverKeepsAPrintedThing() {
        let bad = Props(nutmegSays: "", props: [
            Prop(id: "paper", householdItem: "Paper", becomes: "boarding passes", forRole: .all, safetyOK: true, libraryID: "paper"),
            Prop(id: "chair", householdItem: "Chair", becomes: "the plane seats", forRole: .all, safetyOK: true, libraryID: "chair"),
        ])
        #expect(Validate.props(bad) != nil)
        let fixed = PropFit.repair(bad)
        #expect(fixed.props.allSatisfy { PrintedProps.clash($0.becomes) == nil })
    }

    @Test func thePromptsSayPropsAreNeverPrintedThings() {
        #expect(Realtime.instructions.contains("PROPS ARE NEVER PRINTED THINGS"))
        #expect(!Realtime.instructions.contains("a map is flat"))
        #expect(Prompts.props(ctx: AdventureContext(gameTitle: "Airplane", playerCount: 2)).contains("NEVER something the printed kit makes"))
    }

    // MARK: 9. Fresh suggestions: exactly the sampled 3, not the instructions' examples, no repeats over 3 sessions

    @Test func theInstructionsHaveNoFixedExampleIdeas() {
        let i = Realtime.instructions
        for old in ["a hotel, a pirate ship, or a pet", "teddy bears, a pirate island, or up in the clouds", "in a cookie kingdom",
                    "in a dragon's castle", "How about a bakery, a zoo, or a pirate ship", "Pancake Restaurant on the Moon"] {
            #expect(!i.contains(old), "\(old)")
        }
        #expect(i.contains("<idea 1>, <idea 2>, or <idea 3>") && i.contains("<twist 1>, <twist 2>, or <twist 3>"))
        // Placeholders only: none of the sampled games or twists is named in the fixed instructions as an example idea.
        let today = Realtime.todaysIdeas([Suggestions.games[0], Suggestions.games[1], Suggestions.games[2]])
        #expect(today.contains("EXACTLY these 3") && !today.contains("bakeries"))
    }

    @Test func bothGreetingsOfferAllThreeGames() {
        let games = [Suggestion("zoo", "a zoo"), Suggestion("farm", "a farm"), Suggestion("hotel", "a hotel")]
        let ideas = Suggestions.spoken(games)
        for returning in [true, false] {
            let note = GameGreeting.kickOffNote(ideas: ideas, returning: returning)
            #expect(note.contains("a zoo, a farm, or a hotel") && note.contains("word for word"), "returning \(returning)")
        }
    }

    @Test func setGameOffersExactlyTheThreeSampledTwists() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        store.themeIdeas = [Suggestion("moon", "on the moon"), Suggestion("jungle", "in the jungle"), Suggestion("robots", "with robots")]
        let out = await store.apply(.setGame("Bakery"))
        #expect(out.contains("on the moon, in the jungle, or with robots") && out.contains("EXACTLY these 3"))
    }

    @Test func memoryAvoidsTheLastThreeSessions() throws {
        let suite = "pt.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let memory = SuggestionMemory(defaults: defaults)
        var games: [[String]] = [], twists: [[String]] = []
        for _ in 0..<40 {
            games.append(memory.pickGames().map(\.id)); twists.append(memory.pickTwists().map(\.id))
        }
        for k in 1..<games.count {
            #expect(games[k].count == 3 && Set(games[k]).count == 3 && twists[k].count == 3)
            for back in 1...min(3, k) {
                #expect(Set(games[k]).isDisjoint(with: games[k - back]), "games repeat after \(back) sessions")
                #expect(Set(twists[k]).isDisjoint(with: twists[k - back]), "twists repeat after \(back) sessions")
            }
        }
        #expect(memory.recentGames.count == 9 && memory.recentTwists.count == 9)
        // Still only the two id lists (nothing about kids).
        #expect(defaults.persistentDomain(forName: suite)?.keys.sorted() == ["pt.lastGamePicks", "pt.lastTwistPicks"])
    }

    @Test func anOlderOneSessionMemoryStillWorks() throws {
        let suite = "pt.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["zoo", "farm", "hotel"], forKey: "pt.lastGamePicks")   // round 7's format: the last 3 only
        let picks = SuggestionMemory(defaults: defaults).pickGames().map(\.id)
        #expect(Set(picks).isDisjoint(with: ["zoo", "farm", "hotel"]))
        #expect(SuggestionMemory(defaults: defaults).recentGames.count == 6)
    }
}
