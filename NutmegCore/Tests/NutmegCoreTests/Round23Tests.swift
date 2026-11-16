import Foundation
import Testing
@testable import NutmegCore

/// Round 23 (Haylee): players capped at 6, exactly one badge per kid, $1 money + small prices, back-navigation,
/// the rail's "Props" step.
struct Round23Tests {
    // MARK: A1 players capped at 6

    @Test func capIsSixEverywhere() {
        #expect(Players.max == 6)
        let tools = Realtime.json(["t": Realtime.tools])
        #expect(tools.contains("1 to 6 kids can play"))
        #expect(Realtime.instructions.contains("1 to 6 kids can play"))
        #expect(!Realtime.instructions.contains("Any number works"))
    }

    @MainActor @Test func moreThanSixGetsTheCapLineAndNothingChanges() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Bakery")); _ = await store.apply(.setTheme("Bakery on the Moon"))
        #expect(PlanningCall.decode(name: "set_player_count", arguments: #"{"count":8}"#) == .setPlayerCount(8))
        let over = await store.apply(.setPlayerCount(8))
        #expect(over.contains(Players.overCapLine) && over.contains("Say exactly"))
        #expect(store.playerCount == 0 && store.planningStep == .players)
        // Realtime adds nothing to a "Say exactly" output (no generic reaction suffix).
        #expect(Realtime.outputSuffix(name: "set_player_count", output: over, spokeFirst: false) == "")
        // They agree: six.
        let six = await store.apply(.setPlayerCount(6))
        #expect(store.playerCount == 6 && store.planningStep == .confirm && six.contains("for six friends"))
        // A correction over the cap at the confirm step keeps six.
        let again = await store.apply(.setPlayerCount(10))
        #expect(again.contains(Players.overCapLine) && store.playerCount == 6 && store.planningStep == .confirm)
        // The tap path clamps too.
        store.setPlayerCount(9)
        #expect(store.playerCount == 6)
    }

    // MARK: A2 badges = exact player count

    @Test func badgesAreExactlyThePlayerCount() {
        var badge = kitItem("badge", size: .badge, perPlayer: true); badge.recipe = .badges
        for n in 1...Players.max {
            let pages = KitLayout.pages(for: Kit(nutmegSays: "", items: [badge], scenes: []), roles: cast(n), playerCount: n)
            #expect(pages.count == 1)
            #expect(pages[0].slots.count == n, "\(n) kids")
        }
        let two = KitLayout.pages(for: Kit(nutmegSays: "", items: [badge], scenes: []), roles: cast(2), playerCount: 2)[0].slots
        #expect(two.compactMap(\.role) == ["Captain", "Flight Attendant"])
    }

    @MainActor @Test func twoPlayerKitPrintsTwoBadges() async {
        let store = await storeWithKit(owners: [.R1, .R2, .all, .all], players: 2)
        let kit = try! #require(store.kit)
        let badges = KitLayout.pages(for: kit, roles: store.plan?.roles ?? [], playerCount: store.playerCount)
            .filter { $0.item.recipe == .badges }
        #expect(badges.flatMap(\.slots).count == 2)
    }

    // MARK: A3 money = one $1 bill, small whole-dollar prices

    @Test func moneyIsAlwaysOneDollar() {
        var money = kitItem("money", size: .bill, copies: 8); money.recipe = .money; money.bigNumber = "$10"
        money.lines = ["Moon Bucks $5", "10 dollars"]
        let cleaned = Sanitizer.clean(Kit(nutmegSays: "", items: [money], scenes: []), roleCount: 2).items[0]
        #expect(cleaned.bigNumber == "$1")
        #expect(cleaned.lines == ["Moon Bucks $1", "1 dollar"])
        #expect(cleaned.copies == 8)
        let p = KitArtPrompt.prompt(for: cleaned, gameTitle: "Bakery")
        #expect(p.contains("ONE-dollar bill") && p.contains("\"$1\""))
        #expect(KitRecipe.money.guide.contains("$1"))
        #expect(KitLayout.pages(for: Kit(nutmegSays: "", items: [cleaned], scenes: []), roles: cast(2), playerCount: 2).count == 1)
    }

    @Test func menuPricesAreSmallWholeDollars() {
        #expect(Money.smallPrices("Moon Pie $12") == "Moon Pie $5")
        #expect(Money.smallPrices("Star Cookie $2.50") == "Star Cookie $3")
        #expect(Money.smallPrices("Milk $0.25") == "Milk $1")
        #expect(Money.smallPrices("Cake $ 4") == "Cake $4")
        #expect(Money.smallPrices("Free hugs") == "Free hugs")
        var menu = kitItem("menu", size: .fullPage); menu.recipe = .menu; menu.lines = ["Rocket Toast $7.99", "Comet Juice $3"]
        let cleaned = Sanitizer.clean(Kit(nutmegSays: "", items: [menu], scenes: []), roleCount: 2).items[0]
        #expect(cleaned.lines == ["Rocket Toast $5", "Comet Juice $3"])
        #expect(cleaned.lines.flatMap(Money.amounts).allSatisfy { a in (1...5).contains(Int(a.dropFirst()) ?? 0) })
        #expect(KitRecipe.menu.guide.contains("$1 to $5"))
        #expect(Prompts.kitPages(ctx: AdventureContext(playerCount: 2)).contains("$1 to $5"))
    }

    // MARK: B back-navigation

    @Test func railPicturesAndMarks() {
        #expect(JourneyStep.allCases.map(\.label) == ["Pick", "Props", "Paper", "Play"])   // round 23 renames
        #expect(JourneyStep.allCases.map(BackNav.symbol) == ["theatermasks.fill", "shippingbox.fill", "doc", "play.fill"])
        #expect(BackNav.overlay(.print) == "pencil" && BackNav.overlay(.game) == nil)
        #expect(BackNav.mark(.game, current: .print) == "arrow.counterclockwise")
        #expect(BackNav.mark(.play, current: .print) == "arrow.clockwise")
        #expect(BackNav.arrivalLine(.print) == "Back to Paper! Tap Print to print it again.")
        #expect(BackNav.arrivalLine(.game).hasPrefix("Back to Pick!"))
        #expect(BackNav.output(moved: true, to: .print, current: .play).contains("Moved to the Paper step"))
    }

    @MainActor @Test func voiceGoesBackThroughTheSameNavigation() async {
        let store = await storeWithKit(owners: [.R1, .all, .all, .all], players: 2)
        store.beginPlay()
        if case .handoff = store.phase { store.badgeTapped(.R1) }
        let playPhase = store.phase
        #expect(PlanningCall.decode(name: "go_to_step", arguments: #"{"step":"props"}"#) == .goToStep(.getReady))
        #expect(PlanningCall.decode(name: "go_to_step", arguments: #"{"step":"paper"}"#) == .goToStep(.print))
        #expect(PlanningCall.decode(name: "go_to_step", arguments: #"{"step":"pick"}"#) == .goToStep(.game))
        #expect(PlanningCall.decode(name: "go_to_step", arguments: #"{"step":"nowhere"}"#) == nil)
        let props = await store.apply(.goToStep(.getReady))
        #expect(store.phase == .props && props.contains(BackNav.arrivalLine(.getReady)))
        let print = await store.apply(.goToStep(.print))
        #expect(store.phase == .kitReady && print.contains("Say exactly") && print.contains("Tap Print to print it again"))
        let same = await store.apply(.goToStep(.print))
        #expect(same.contains("Already") && store.phase == .kitReady)
        _ = await store.apply(.goToStep(.play))
        #expect(store.phase == playPhase)
        // "Print it again" said as print_kit during play also goes back to the Print step.
        let again = await store.apply(.printKit)
        #expect(store.phase == .kitReady && again.contains(BackNav.arrivalLine(.print)))
        // A step not reached yet is refused.
        store.newGame()
        let ahead = await store.apply(.goToStep(.print))
        #expect(ahead.contains("Can't") && store.phase == .hello)
        #expect(Realtime.json(["t": Realtime.tools]).contains("go_to_step"))
        #expect(BackNav.playNote.contains("go_to_step") && BackNav.playNote.contains("print it again"))
        // Tool-first after the hunt, so a voice "print it again" always moves.
        #expect(Realtime.afterHuntTools(.scene(0))?.contains("go_to_step") == true)
        #expect(Realtime.afterHuntTools(.end) == ["go_to_step", "just_talk"])
        #expect(Realtime.afterHuntTools(.kitReady)?.contains("start_play") == true)
        #expect(Realtime.afterHuntTools(.props) == nil)
        #expect(Realtime.outputSuffix(name: "go_to_step", output: print, spokeFirst: false) == "")
        #expect(SpeculativeTools.mayRunBeforeModeration(.goToStep(.print), step: .finish, huntActive: false))
    }

    @MainActor @Test func canGoToMatchesTheRail() async {
        let store = await storeWithKit(owners: [.R1, .all, .all, .all], players: 2)
        #expect(store.canGoTo(.game) && store.canGoTo(.getReady))
        #expect(!store.canGoTo(.print))   // current
        #expect(!store.canGoTo(.play))    // not reached
        #expect(store.goTo(.getReady) && !store.goTo(.getReady))
    }
}

/// Round 23 (Haylee): she pointed at the empty card zone after a prop moved to the done stack.
struct Round23PointTests {
    @Test func noVisibleCardNoPoint() {
        #expect(PoseRules.holdsPoint(huntActive: true, cardShown: true, cardDone: false))
        #expect(!PoseRules.holdsPoint(huntActive: true, cardShown: false, cardDone: false))   // no visible card → no point
        #expect(!PoseRules.holdsPoint(huntActive: true, cardShown: true, cardDone: true))     // found / pretend: moved aside
        #expect(!PoseRules.holdsPoint(huntActive: false, cardShown: true, cardDone: false))   // the hunt ended
    }
}
