import Foundation
import Testing
@testable import NutmegCore

/// Round 26 (Haylee's button audit, decisions/2026-11-16-button-audit.md): voice-only steps say what to SAY, the
/// play buttons are pictures she names, The End's star / house, and a replay reuses the first play's flows.
@MainActor struct Round26Tests {
    // MARK: Voice-only steps (decisions 1, 2, 8)

    @Test func voiceOnlyLinesSayWhatToSayAndPassTheTurnCheck() {
        #expect(ConfirmStep.question == "Say yes, or tell me what to change!")
        let recap = ConfirmStep.recap(title: "Magic Bakery", playerCount: 2)
        #expect(recap == "So it's a magic bakery for two friends! Say yes, or tell me what to change!")
        #expect(TurnCheck.nudge(for: recap, step: .confirm) == nil)
        #expect(TurnCheck.nudge(for: "Ooh, a moon bakery! How many friends are playing? Tell me!", step: .players) == nil)
        #expect(TurnCheck.nudge(for: "Ooh, a moon bakery!", step: .players) != nil)
        #expect(ReplayLines.howMany == "How many friends are playing this time? Tell me!")
        #expect(Realtime.instructions.contains("How many friends are playing? Tell me!"))
        // Decision 2 (changed by Haylee mid-round): no color question at all; coloring pages by default.
        #expect(!PlanningStep.allCases.map { "\($0)" }.contains("color"))
        #expect(!Realtime.tools.contains { $0["name"] as? String == "set_print_style" })
    }

    @Test func confirmYesByVoiceGoesStraightToTheRoles() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Bakery")); _ = await store.apply(.setTheme("Magic Bakery"))
        _ = await store.apply(.setPlayerCount(2))
        #expect(PlanningCall.decode(name: "confirm_plan", arguments: "{}") == .confirmPlan)
        let yes = await store.apply(.confirmPlan)
        #expect(store.planningStep == .roles && yes.contains("start_planning") && store.currentPrintStyle == .colorIn)
        #expect(Realtime.kidTurnTools(step: .confirm, huntActive: false)?.first == "confirm_plan")
    }

    // MARK: Picture buttons she names (decisions 3, 4, 5, 7)

    @Test func linesNameThePictureButtons() {
        #expect(HandOffLines.printReady == "Your kit is ready! Want them in color, or plain to color yourself? Tap the ones you like, then the printer! Tap the green play button when you're set!")
        #expect(HandOffLines.nextSceneHowTo == "Tap the green play button for the next scene!")
        // Round 39: no star (every game is already on the bookshelf): the arrow plays it again, the house goes home.
        #expect(HandOffLines.end() == "The end! What a show! Take a bow! It's on your bookshelf. Tap the arrow to play again, or the house to go home!")
        #expect(HandOffLines.end(replay: true) == HandOffLines.end())
        #expect(BackNav.arrivalLine(.print) == "Back to Print! Tap the printer to print it again.")
        #expect(AdventureStore.firstPropLine(item: "bowl", becomes: "the mixing bowl").contains("tap the green check"))
        // No line names a button that's gone.
        let all = [HandOffLines.printReady, HandOffLines.nextSceneHowTo, HandOffLines.end(), HandOffLines.end(replay: true),
                   ReplayLines.greeting(title: "X"), ReplayLines.savedGame, GrownUpsCopy.emptySavedGames] + CommonLines.all
        for l in all {
            for gone in ["Done", "Let's play", "I'm the", "Save it to play again", "New game", "All set", "Don't have it", "Play it again"] {
                #expect(!l.contains(gone), "\(l) names \(gone)")
            }
        }
    }

    @Test func theEndKeepsTheAutoSaveOfAFirstPlay() async {
        let store = await storeWithKit(owners: [.R1, .R2], players: 2)
        store.beginPlay()
        for _ in 0..<12 where store.phase != .end { store.nextScene() }
        #expect(store.phase == .end && store.nutmegLine.hasSuffix(HandOffLines.end()))
        // Round 39: no star; the first play stays saveable (its auto-save is kept up to date) to The End.
        #expect(store.canAutoSave)
        store.markSaved(UUID())
        #expect(store.canAutoSave && store.savedAs != nil)
    }

    // MARK: Replays reuse the first-play flows (decisions 8, 9, 10)

    @Test func replayCardNoteAndArticles() {
        let books = Prop(id: "books", householdItem: "Books", becomes: "the display stand", forRole: .all, safetyOK: true, libraryID: "books")
        #expect(ReplayLines.propAsk(books, n: 4) == "Ooh, some books would make a great display stand! Can you find some?")   // round 34
        #expect(ReplayLines.useInstead("Books") == "Some books work too! Do you have some?")
        #expect(ReplayLines.useInstead("Pot") == "A pot works too! Do you have one?")
        #expect(ReplayLines.useInstead("Apron") == "An apron works too! Do you have one?")
        // Seen live: her app lines aren't in the conversation, so each move tells the session which card is up.
        let note = ReplayLines.stepNote(step: .getReady, players: 3, playing: ["Head Baker"], card: books, cardNumber: 4, cards: 4)
        #expect(note.contains("card 4 of 4: the books") && note.contains("mark_found") && note.contains("skip_prop"))
        #expect(ReplayLines.stepNote(step: .print, players: 3, playing: [], card: nil, cardNumber: 0, cards: 4).contains("print_kit"))
    }

    @Test func replayHuntAnswersByVoiceAndTapsAreTheSameState() async {
        let store = AdventureStore(service: nil)
        let a = Fallback.airplane
        var props = a.props.props.map(SavedProp.init)
        props[0].alternates = []
        let g = SavedGame(createdAt: Date(), title: "Airplane", roles: a.plan.roles, props: props, kit: a.kit, printStyle: .colorIn, art: [],
                          voiceID: VoiceConfig.nutmeg.voiceID)
        store.loadReplay(g)
        // Off-step answers change nothing (a "found it" at Pick).
        #expect(await store.apply(.markFound("x")) == ReplayLines.savedGameOutput && store.phase == .players)
        _ = await store.apply(.setPlayerCount(2))
        #expect(store.phase == .props && store.replayCurrentProp?.id == props[0].id)
        // ✗ with no saved alternate: pretend at once, then the next card.
        store.replayHunt(found: false)
        #expect(store.props?.props[0].isSkipped == true && store.replayCurrentProp?.id == props[1].id)
        #expect(store.nutmegLine.hasPrefix("No problem, we'll pretend") && !store.nutmegLine.contains("still have"))   // round 34
        #expect(ClipMeta.kind(of: store.nutmegLine) == .replay)
        store.replayAllFound()
        #expect(store.phase == .kitReady && store.nutmegLine == HandOffLines.printReady)
        #expect(ReplayLines.tools(.kitReady) == ["start_play", "print_kit", "choose_print_set", "go_to_step", "just_talk"])
    }
}
