import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-18 round (props, copy, onboarding): props can come in multiples, always "up to N" (Haylee), stored as a
/// RULE so replays scale with the player count; the new tagline and no "off the screen" in app strings; short game
/// titles for the shelf.
@MainActor struct Round1118PropQuantityTests {
    func prop(_ id: String, _ item: String, _ becomes: String, q: PropQuantity? = nil, skipped: Bool = false) -> Prop {
        Prop(id: id, householdItem: item, becomes: becomes, forRole: .all, safetyOK: true, libraryID: id, alternates: [],
             skipped: skipped, reason: nil, quantity: q)
    }

    @Test func theToolValueIsClamped() {
        #expect(PropQuantity(toolValue: "one") == .one)
        #expect(PropQuantity(toolValue: nil) == .one)
        #expect(PropQuantity(toolValue: "per_player") == .perPlayer)
        #expect(PropQuantity(toolValue: "3") == .fixed(3))
        #expect(PropQuantity(toolValue: 3) == .fixed(3))
        #expect(PropQuantity(toolValue: "40") == .fixed(6))   // fixed max 6
        #expect(PropQuantity(toolValue: "1") == .one)
        #expect(PropQuantity(toolValue: "lots") == .one)
        #expect(PropQuantity.fixed(9).count(players: 2) == 6)
    }

    @Test func perPlayerScalesWithThePlayerCount() {
        let cups = prop("cup", "Plastic cup", "the tea cups", q: .perPlayer)
        #expect(cups.count(players: 1) == 1)
        #expect(cups.count(players: 4) == 4)
        #expect(cups.count(players: 9) == Players.max)   // max = player count, capped at 6
        let pets = prop("stuffed-animal", "Stuffed animal", "the patients", q: .fixed(3))
        #expect(pets.count(players: 1) == 3 && pets.count(players: 6) == 3)
        #expect(prop("chair", "Chair", "seats").count(players: 5) == 1)   // default one
    }

    @Test func bigOrOneOfAKindItemsAreAlwaysOne() {
        #expect(prop("couch", "Couch", "the boat", q: .perPlayer).count(players: 4) == 1)
        #expect(prop("wagon", "Wagon", "the ambulance", q: .fixed(3)).count(players: 4) == 1)
        #expect(prop("crayons", "Crayons", "the paint", q: .fixed(3)).cardTitle(players: 4) == "Crayons")
    }

    @Test func theCardSaysUpToN() {
        let cups = prop("cup", "Plastic cup", "tea cups for everyone", q: .perPlayer)
        #expect(cups.cardTitle(players: 4) == "Up to 4 plastic cups")
        #expect(cups.cardTitle(players: 1) == "Plastic cup")
        #expect(prop("stuffed-animal", "Stuffed animal", "the patients", q: .fixed(3)).cardTitle(players: 2) == "Up to 3 stuffed animals")
        #expect(prop("scarf", "Scarf", "capes", q: .perPlayer).cardTitle(players: 2) == "Up to 2 scarves")
        #expect(PropCount.plural("Umbrella (closed)") == "umbrellas")
        #expect(PropCount.plural("Plastic cups") == "plastic cups")
        #expect(PropCount.plural("Box") == "boxes")
    }

    @Test func herLineSaysUpToNSpelledOut() {
        let first = PropLines.ask(item: "Plastic cup", becomes: "the tea cups", reason: nil, n: 1, count: 4, perPlayer: true)
        #expect(first == "First, can you find up to four plastic cups? One for each player, if you have them! They'll be the tea cups! "
                + PropLines.howToMany)
        let later = PropLines.ask(item: "Stuffed animal", becomes: "the patients", reason: nil, n: 2, count: 3, perPlayer: false)
        #expect(later.contains("up to three stuffed animals") && !later.contains("each player") && !later.contains("3"))
        #expect(PropLines.ask(item: "Chair", becomes: "the seats", reason: nil, n: 3, count: 2, perPlayer: true).contains("pretend that"))
        // Every multiple line says "up to" (Haylee: a family with fewer can still play).
        for n in 1...6 {
            #expect(PropLines.ask(item: "Bowl", becomes: "the hats", reason: nil, n: n, count: 5, perPlayer: true).contains("up to five bowls"))
        }
        // A single prop is the exact same line as before.
        #expect(PropLines.ask(item: "Pot", becomes: "the hat", reason: nil, n: 2, count: 1, perPlayer: false)
                == PropLines.ask(item: "Pot", becomes: "the hat", reason: nil, n: 2))
    }

    @Test func theToolDecodesHowMany() {
        let call = PlanningCall.decode(name: "show_next_prop",
                                       arguments: #"{"item_id":"cup","becomes":"tea cups","for_role":"all","alternates":[],"reason":"","how_many":"per_player"}"#)
        guard case .showNextProp(let d)? = call else { Issue.record("no call"); return }
        #expect(d.quantity == .perPlayer)
        let tool = Realtime.sessionUpdate(voice: "coral", speed: 1, instructions: "")
        let json = String(data: (try? JSONSerialization.data(withJSONObject: tool)) ?? Data(), encoding: .utf8) ?? ""
        #expect(json.contains("how_many"))
    }

    @Test func theStoreKeepsTheRuleAndAReplayScales() async {
        let store = AdventureStore(service: nil)
        store.appSaysPropLines = true
        store.beginConversation()
        _ = await store.apply(.setGame("Tea Party"))
        _ = await store.apply(.setPlayerCount(3))
        _ = await store.apply(.setRoles([.init(roleName: "Host", job: "pour tea"), .init(roleName: "Guest", job: "sip"),
                                         .init(roleName: "Baker", job: "bake")]))
        _ = await store.apply(.showNextProp(.init(itemID: "pot", becomes: "the teapot", forRole: "Host")))
        _ = await store.apply(.markFound("pot"))
        let out = await store.apply(.showNextProp(.init(itemID: "cup", becomes: "the tea cups", forRole: "all", quantity: .perPlayer)))
        let cup = store.props?.props.last
        #expect(cup?.quantity == .perPlayer, "\(out)")
        guard let cup, cup.quantity == .perPlayer else { return }
        #expect(cup.count(players: store.playerCount) == 3)
        let line = store.takePendingPropLine() ?? ""
        #expect(line.contains("up to three"), "\(line)")
        // Saved as the RULE, never a count.
        let saved = SavedProp(cup)
        let json = String(data: try! JSONEncoder().encode(saved), encoding: .utf8)!
        #expect(json.contains("\"quantity\":\"perPlayer\"") && !json.contains("\"count\""))
        let back = try! JSONDecoder().decode(SavedProp.self, from: Data(json.utf8))
        #expect(back.replayProp.count(players: 5) == 5)   // a replay with 5 kids asks for up to 5
        #expect(back.replayProp.count(players: 2) == 2)
        #expect(PropLines.line(for: [back.replayProp], index: 0, players: 5)?.contains("up to five") == true)
        // A single prop encodes exactly as before (no quantity key).
        let one = String(data: try! JSONEncoder().encode(SavedProp(prop("pot", "Pot", "the teapot"))), encoding: .utf8)!
        #expect(!one.contains("quantity"))
    }

    @Test func rowsAndGuideSayThePlural() {
        let cups = prop("cup", "Plastic cup", "the tea cups", q: .perPlayer)
        #expect(cups.itemWords == "plastic cups")
        #expect(prop("pot", "Pot", "hat").itemWords == "pot")
        let p = GuideWeave.prompt(scenes: [], props: [cups], taken: [], roles: [], players: 3)
        #expect(p.contains("several plastic cups (one for each player)") && p.contains("the plastic cups"))
    }

    /// Coordinator follow-up: a demo hunt's fresh-prop swap turned "the tea cups" into a pot / basket. A cup you drink
    /// from is only ever cup-like (cups, a measuring cup, a small bowl).
    @Test func cupsAreOnlyCupLikeItems() {
        for use in ["the tea cups", "the snack cups", "tea cup", "the mugs", "the goblet", "lemonade cups"] {
            for id in ["pot", "basket", "bucket", "cardboard-box", "laundry-basket", "bag", "plastic-container", "colander"] {
                #expect(!PropFit.fits(itemID: id, becomes: use), "\(id) as \(use)")
            }
            for id in ["cup", "plastic-cups", "measuring-cup", "bowl"] {
                #expect(PropFit.fits(itemID: id, becomes: use), "\(id) as \(use)")
            }
        }
        // The swap candidates for cups are cup-like only.
        let c = PropFit.candidates(for: "the tea cups")
        #expect(!c.isEmpty && Set(c).isSubset(of: ["cup", "plastic-cups", "measuring-cup", "bowl"]), "\(c)")
        // The fresh-prop swap never picks a pot or basket for cups.
        #expect(RecentProps.fresher(itemID: "cup", becomes: "the tea cups", alternates: ["pot", "basket", "plastic-cups"],
                                    recent: ["cup"], used: []) == "plastic-cups")
        // Other container uses still work (a pot is still a cauldron, a basket a treasure chest).
        #expect(PropFit.fits(itemID: "pot", becomes: "the cauldron") && PropFit.fits(itemID: "basket", becomes: "the treasure chest"))
    }
}

/// 2026-11-18 copy (decisions/2026-11-18-tagline-and-play-wording.md): the new tagline, and never "off the screen" or
/// "steps back" in anything the app shows or Nutmeg says.
struct Round1118CopyTests {
    @Test func onboardingPageOneHasTheNewTagline() {
        #expect(OnboardingCopy.tagline == "Plan it, print it, play it")
        #expect(OnboardingCopy.helloBody == OnboardingCopy.tagline)
    }

    @Test func theFlowStepsAreParallel() {
        let bodies = OnboardingCopy.steps.map(\.body)
        #expect(bodies == ["Plan a game by talking with Nutmeg", "Hunt for props around the house",
                           "Print a kit made for your game", "Act it out together, scene by scene"])
        // Each starts with a plain verb (no "Play … off the screen").
        #expect(bodies.map { $0.split(separator: " ").first.map(String.init) ?? "" } == ["Plan", "Hunt", "Print", "Act"])
    }

    static let banned = ["off the screen", "off-screen play", "steps back", "step back so"]

    @Test func noOffTheScreenInSpokenOrShownLines() {
        let lines = CommonLines.all + [Prompts.system, OnboardingCopy.tagline, OnboardingCopy.nutmegIntro, OnboardingCopy.greetKid,
                                       OnboardingCopy.handOffBody] + OnboardingCopy.steps.map(\.body)
        for l in lines { for b in Self.banned { #expect(!l.lowercased().contains(b), "\(l)") } }
    }

    /// Every string literal in the app and NutmegCore sources (comments are skipped).
    @Test func noOffTheScreenInAnyAppString() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        var hits: [String] = []
        var files = 0
        for dir in ["PretendThat", "NutmegCore/Sources"] {
            guard let e = FileManager.default.enumerator(at: root.appendingPathComponent(dir), includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in e where ["swift", "plist", "strings", "json"].contains(url.pathExtension) {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                files += 1
                for line in text.split(separator: "\n") {
                    let code = line.components(separatedBy: "//").first ?? ""   // drop comments (good enough: no URLs here)
                    let quoted = code.split(separator: "\"", omittingEmptySubsequences: false).enumerated()
                        .filter { $0.offset % 2 == 1 }.map { $0.element.lowercased() }
                    for q in quoted where Self.banned.contains(where: q.contains) { hits.append("\(url.lastPathComponent): \(line)") }
                }
            }
        }
        #expect(files > 50)
        #expect(hits.isEmpty, "\(hits)")
    }
}

/// 2026-11-18 (Haylee: "the titles on saved games are too long, I can't read them at all on the bookshelf"): saved
/// game titles are 1–3 words, 18 characters at most; older long titles show a short cut on the shelf.
@MainActor struct Round1118ShortTitleTests {
    @Test func shortTitlesFit() {
        for t in ["Pet Hotel", "Moon Bakery", "Sea Vet Clinic", "Moon Crumbs Bakery"] { #expect(GameTitles.isShort(t), "\(t)") }
        #expect(!GameTitles.isShort("Pancake Restaurant on the Moon"))
        #expect(!GameTitles.isShort("Super Space Pizza Party"))   // 4 words
        #expect(!GameTitles.isShort(""))
    }

    @Test func theAIsShortTitleIsCheckedAndTidied() {
        #expect(GameTitles.cleanShort("\"Moon Pancakes!\"") == "Moon Pancakes")
        #expect(GameTitles.cleanShort("  Pet   Hotel ") == "Pet Hotel")
        #expect(GameTitles.cleanShort("The Pancake Restaurant on the Moon") == nil)
        #expect(GameTitles.cleanShort(nil) == nil && GameTitles.cleanShort("") == nil)
    }

    @Test func longTitlesAreCutNeverMidWord() {
        #expect(GameTitles.shelf("Pancake Restaurant on the Moon") == "Pancake Restaurant")
        #expect(GameTitles.shelf("Pirate Ship on the Moon") == "Pirate Ship")
        #expect(GameTitles.shelf("The Royal Ball") == "The Royal Ball")   // already short: unchanged
        #expect(GameTitles.shelf("The Great Big Underwater Dinosaur Museum") == "Great Big")
        #expect(GameTitles.shelf("A Bakery for Hungry Dragons") == "Bakery")
        #expect(GameTitles.shelf("Supercalifragilisticexpialidocious") == "Supercalifragilisticexpialidocious")   // one word stays whole
        for t in ["Pancake Restaurant on the Moon", "Super Space Pizza Party Adventure", "Ice Cream Truck at the Beach",
                  "Treasure Island Pirate Adventure", "Spooky Haunted Castle and Friends"] {
            let s = GameTitles.shelf(t)
            #expect(GameTitles.isShort(s), "\(t) → \(s)")
            #expect(s.split(separator: " ").allSatisfy { w in t.split(separator: " ").contains(w) }, "never mid-word: \(s)")
            #expect(!["and", "on", "the", "of"].contains(s.split(separator: " ").last.map { $0.lowercased() } ?? ""), "\(s)")
        }
    }

    @Test func setThemeCarriesTheShortTitle() {
        let call = PlanningCall.decode(name: "set_theme", arguments: #"{"title":"Pancake Restaurant on the Moon","short_title":"Moon Pancakes"}"#)
        #expect(call == .setTheme("Pancake Restaurant on the Moon", short: "Moon Pancakes"))
        #expect(PlanningCall.decode(name: "set_theme", arguments: #"{"title":"Zoo in Space"}"#) == .setTheme("Zoo in Space"))
        let tool = Realtime.sessionUpdate(voice: "coral", speed: 1, instructions: "")
        let json = String(data: (try? JSONSerialization.data(withJSONObject: tool)) ?? Data(), encoding: .utf8) ?? ""
        #expect(json.contains("short_title"))
    }

    @Test func aNewSavedGameGetsTheShortTitleAndTheKitKeepsTheFullOne() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Restaurant"))
        _ = await store.apply(.setTheme("Pancake Restaurant on the Moon", short: "Moon Pancakes"))
        #expect(store.currentTitle == "Pancake Restaurant on the Moon")   // the kit and pages keep the full title
        #expect(store.shortTitle == "Moon Pancakes")
        #expect(GameTitles.saved(full: store.currentTitle, short: store.shortTitle) == "Moon Pancakes")
        // No (or a bad) short title: the shelf cut of the full one.
        #expect(GameTitles.saved(full: "Pancake Restaurant on the Moon", short: "A Very Long Pancake Restaurant Title") == "Pancake Restaurant")
        // A new game clears it.
        _ = await store.apply(.setGame("Airplane"))
        #expect(store.shortTitle == nil)
    }

    @Test func theSavedGameUsesTheShortTitle() async {
        let a = Fallback.airplane
        let store = AdventureStore(service: nil)
        store.loadReplay(SavedGame(createdAt: Date(), title: "Airplane Trip to the Sunny Beach", roles: a.plan.roles,
                                   props: a.props.props.map(SavedProp.init), kit: a.kit, printStyle: .colorIn, art: [],
                                   voiceID: VoiceConfig.nutmeg.voiceID))
        let g = store.savedGame(art: [], cover: nil)
        #expect(g.map { GameTitles.isShort($0.title) } == true, "\(g?.title ?? "nil")")
    }
}
