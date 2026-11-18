import Foundation
import Testing
@testable import NutmegCore

/// Round 43 (the prop audit, thinking/research/2026-11-17-prop-audit.md; Haylee approved every fix): head-word parsing,
/// vocabulary, tighter tags, identity items, the swap bug, no repeats on every path, the bundled game, replay
/// alternates, prompts without copied examples, and the per-game prop shortlist (variety).
@MainActor
struct Round43PropAuditTests {

    // MARK: 1. The pair table (about 60 rows: item, use, verdict, and for some the rule that decided it)

    @Test(arguments: [
        // The audit's own rows.
        ("stuffed-animal", "the pet drying cloth", false), ("stuffed-animal", "the patient", true),
        ("stuffed-animal", "the pet bed", false), ("stuffed-animal", "the puppy's leash", false),
        ("stuffed-animal", "the patient's bandage", false), ("stuffed-animal", "the pet shampoo", false),
        ("pillow", "the pet's food", false), ("sneakers", "the knight's helmet", false), ("mittens", "the crown", false),
        ("egg-carton", "the rocket ship", false), ("paper", "the cape", false), ("pillow", "the moon counter", false),
        ("plastic-cups", "the lookout scope", false), ("cup", "the lookout scope", false), ("towel", "the drying cloth", true),
        ("cardboard-box", "the control panel", true), ("paper-towel-tube", "the lookout scope", true),
        // More rejected.
        ("ball", "the crown", false), ("books", "the boat", false), ("tray", "the check-in desk", false),
        ("paper", "the tent", false), ("rug", "the superhero cape", false), ("sticky-notes", "the shop counter", false),
        ("towel", "the cooling rack", false), ("bowl", "the robot repair tray", false), ("lamp-off", "the sword", false),
        ("jump-rope", "the magic wand", false), ("jump-rope", "the puppy's leash", false), ("hula-hoop", "the crown", false),
        ("ball", "the steering wheel", false), ("sock", "the steering wheel", false), ("toy-keys", "the treasure chest", false),
        ("crayons", "the boat", false), ("flashlight", "the sword", false), ("umbrella", "the tent", false),
        ("sunglasses", "the crown", false), ("plate", "the snowball", false), ("hula-hoop", "the planet", false),
        ("paper", "the pirate sail", false), ("scarf", "the boat", false), ("couch", "the telescope", false),
        ("stuffed-animal", "the treasure chest", false),
        // More accepted.
        ("stuffed-animal", "our pet", true), ("stuffed-animal", "the baby dinosaur", true), ("stuffed-animal", "the passenger", true),
        ("towel", "the pet bed", true), ("bowl", "the captain's hat", true), ("colander", "the space helmet", true),
        ("headband", "the crown", true), ("blanket", "the superhero cape", true), ("pillowcase", "the royal sash", true),
        ("sheet", "the tent", true), ("table", "the cozy cave", true), ("chair", "the airplane seats", true),
        ("laundry-basket", "the boat", true), ("table", "the check-in desk", true), ("stool", "the stage", true),
        ("plate", "the steering wheel", true), ("baking-sheet", "the steering wheel", true), ("hula-hoop", "the magic portal", true),
        ("jump-rope", "the river", true), ("sock", "the snowball", true), ("ball", "the planet", true),
        ("mittens", "the polar gloves", true), ("sneakers", "the moon boots", true), ("sunglasses", "the spy goggles", true),
        ("toy-keys", "the castle keys", true), ("flashlight", "the lighthouse light", true), ("umbrella", "the walking cane", true),
        ("bowl", "the robot repair hub", true),   // a flexible item keeps a creative unknown use
        ("blanket", "the castle walls", true), ("bucket", "the knight's helmet", true), ("pot", "the drum", true),
        ("pillow", "the shield", true), ("paper", "the snowballs", false),   // 2026-11-17: plain paper retired
    ])
    func pairTable(item: String, becomes: String, ok: Bool) {
        #expect(PropFit.fits(itemID: item, becomes: becomes) == ok, "\(item) → \(becomes)")
    }

    @Test func theRuleIsTheHeadNounNotADescribingWord() {
        #expect(PropFit.check(itemID: "stuffed-animal", becomes: "the pet drying cloth").rule == "cloth")
        #expect(PropFit.check(itemID: "pillow", becomes: "the pet's food").rule == "food")
        #expect(PropFit.check(itemID: "bowl", becomes: "the robot repair hub").rule == nil)
        #expect(PropFit.check(itemID: "bowl", becomes: "the robot repair hub").unknown)
        #expect(PropFit.check(itemID: "stuffed-animal", becomes: "the pet drying cloth").why?.contains("only ever a creature") == true)
        #expect(PropWords.head("the pet drying cloth") == "cloth")
        #expect(PropWords.head("the pirate ship sail") == "sail")
        #expect(PropWords.head("the soap mixing bowl") == "bowl")
        #expect(PropWords.head("the captain's hat") == "hat")
        #expect(PropWords.head("the pet's food") == "food")
        #expect(PropWords.head("the check-in desk") == "desk")
        #expect(PropWords.head("the treasure map of the island") == "map")
        #expect(PropWords.head("a hat for the captain") == "hat")
        #expect(PropWords.head("the jet-pack") == "pack")
        #expect(PropWords.head("the kids’ boat") == "boat")
    }

    @Test func pluralsFoldToSingular() {
        for (plural, single) in [("boxes", "box"), ("brushes", "brush"), ("puppies", "puppy"), ("benches", "bench"),
                                 ("cookies", "cookie"), ("leaves", "leaf"), ("passes", "pass"), ("tickets", "ticket"),
                                 ("glasses", "glasses"), ("buses", "bus"), ("shelves", "shelf")] {
            #expect(PrintedProps.singular(plural) == single, "\(plural)")
        }
        #expect(PropFit.need(for: "the treasure boxes")?.name == "chest")
        #expect(PropFit.need(for: "the paint brushes")?.name == "long")
        #expect(PropFit.need(for: "the puppies")?.name == "creature")
        #expect(PropFit.need(for: "the park benches")?.name == "seat")
        #expect(PropFit.need(for: "the cookies")?.name == "disc")
        #expect(PropFit.need(for: "the giant leaves")?.name == "bits")
    }

    // MARK: 2. Real pairs from the logs still pass (good, creative pairs are never turned away)

    @Test func realPairsFromTheLogsStillFit() {
        let fine: [(String, String)] = [
            ("sheet", "the pirate sail"), ("cardboard-box", "the treasure chest"), ("chair", "the airplane seats"),
            ("hat", "the captain's hat"), ("tray", "the snack cart"), ("towel", "the pet bed"), ("apron", "the baker's apron"),
            ("baking-sheet", "the cookie tray"), ("flashlight", "the guard's flashlight"), ("stuffed-animal", "the baby dinosaur"),
            ("blanket", "the dino nest"), ("bag", "the animal carrier"), ("basket", "the pet carrier"), ("table", "the grooming table"),
            ("bowl", "the feeding dish"), ("bowl", "the mixing bowl"), ("spoon", "the big stirrer"), ("cardboard-box", "the rocket ship"),
            ("couch", "the big boat"), ("plate", "the steering wheel"), ("blanket", "the big blue ocean"), ("cushion", "the throne"),
            ("paper-towel-tube", "the telescope"), ("pot", "the soup pot"), ("wooden-spoon", "the microphone"),
            ("towel", "decorating cloth"), ("bowl", "the robot repair hub"), ("tray", "the sorting station"),
            ("basket", "the supply sorter"), ("cardboard-box", "the cash register"), ("blanket", "the castle walls"),
        ]
        for (id, use) in fine { #expect(PropFit.fits(itemID: id, becomes: use), "\(id) → \(use) should still fit") }
    }

    // MARK: 3. Every curated use is a known head word (and fits); reasons explain something

    @Test func everyCuratedUseHasAKnownHeadWord() {
        for (id, uses) in PropLibrary.uses {
            for u in uses {
                #expect(PropFit.need(for: u.becomes) != nil, "\(id) → \(u.becomes): unknown head \(PropWords.head(u.becomes) ?? "-")")
                #expect(PropFit.fitsKnown(itemID: id, becomes: u.becomes), "\(id) → \(u.becomes)")
                #expect(!PropFit.parrots(u.reason, itemID: id, becomes: u.becomes), "\(id): \(u.reason) only repeats the pair")
            }
        }
    }

    @Test func aParrotedReasonIsReplaced() {
        #expect(PropFit.parrots("A stuffed animal can be a pet drying cloth!", itemID: "stuffed-animal", becomes: "the pet drying cloth"))
        #expect(PropFit.parrots("It'll be the perfect treasure chest!", itemID: "cardboard-box", becomes: "the treasure chest"))
        #expect(!PropFit.parrots("A bowl is round like a captain's hat!", itemID: "bowl", becomes: "the captain's hat"))
        #expect(PropFit.keptReason("A stuffed animal can be our pet!", itemID: "stuffed-animal", becomes: "our pet")
            == "A stuffed animal can be our furry pet!")
        #expect(PropFit.keptReason("A box can hold all the gold!", itemID: "cardboard-box", becomes: "the treasure chest")
            == "A box can hold all the gold!")
    }

    // MARK: 4. Library changes (Haylee)

    @Test func theLampIsGoneAndTheJumpRopeIsOnlyAFloorShape() {
        #expect(!PropLibrary.contains("lamp-off") && !PropLibrary.ids.contains("lamp-off"))
        #expect(PropLibrary.name("lamp-off") != nil && PropLibrary.hasArt("lamp-off"))   // an older saved game still shows it
        #expect(!Realtime.tools.description.contains("lamp-off"))
        for use in ["the river", "the finish line", "the road lines", "the pond"] { #expect(PropFit.fits(itemID: "jump-rope", becomes: use), "\(use)") }
        for use in ["the leash", "the magic wand", "the fishing rod", "the snake", "the treasure"] {
            #expect(!PropFit.fits(itemID: "jump-rope", becomes: use), "\(use)")
        }
    }

    @Test func everydayThingsComeFirstForFallbacks() {
        let order = PropFit.everydayFirst
        for toy in PropFit.toyish { #expect(order.firstIndex(of: toy)! > order.firstIndex(of: "towel")!) }
        // A wheel: the plate comes before the hula hoop.
        let c = PropFit.candidates(for: "the steering wheel")
        #expect(c.firstIndex(of: "plate")! < c.firstIndex(of: "hula-hoop")!)
    }

    // MARK: 5. The store: swaps, repeats, the first prop, the fallbacks

    private func hunting(_ store: AdventureStore, game: String = "Vet Clinic", theme: String = "Vet Clinic for Sea Animals",
                         roles: [String] = ["Vet", "Pet Owner"]) async {
        store.beginConversation()
        _ = await store.apply(.setGame(game)); _ = await store.apply(.setTheme(theme))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
        _ = await store.apply(.setRoles(roles.map { .init(roleName: $0, job: "helps") }))
    }

    @Test func aSwapWithNothingThatFitsBecomesPretendNeverARandomPair() async {
        let store = AdventureStore(service: nil)
        await hunting(store)
        _ = await store.apply(.showNextProp(.init(itemID: "stuffed-animal", becomes: "the patient", forRole: "all")))
        let retry = await store.apply(.swapProp(oldID: "stuffed-animal", newID: "pillow", becomes: ""))
        #expect(retry.contains("Not shown") && retry.contains("only a stuffed animal can be a creature"))
        let out = await store.apply(.swapProp(oldID: "stuffed-animal", newID: "pillow", becomes: ""))
        let card = store.props?.props.first
        #expect(card?.isSkipped == true && card?.libraryID == "stuffed-animal" && card?.becomes == "the patient")
        #expect(out.contains("pretend prop") && out.contains("show_next_prop"))
        #expect(card?.householdItem != "Pillow")
    }

    @Test func aSwapFallsBackToAnItemForTheSameUse() async {
        let store = AdventureStore(service: nil)
        await hunting(store)
        _ = await store.apply(.showNextProp(.init(itemID: "towel", becomes: "the drying cloth", forRole: "all")))
        _ = await store.apply(.swapProp(oldID: "towel", newID: "bowl", becomes: ""))
        _ = await store.apply(.swapProp(oldID: "towel", newID: "bowl", becomes: ""))
        let card = store.props?.props.first
        #expect(card?.becomes == "the drying cloth" && card?.isSkipped == false)
        #expect(card.map { $0.libraryID != "towel" && PropFit.fits(itemID: $0.libraryID!, becomes: $0.becomes) } == true)
    }

    @Test func theSameItemNeverTwiceInOneHunt() async {
        let store = AdventureStore(service: nil)
        await hunting(store, game: "Pirate Ship", theme: "Pirate Ship", roles: ["Captain", "Navigator"])
        _ = await store.apply(.showNextProp(.init(itemID: "sheet", becomes: "the pirate sail", forRole: "all")))
        _ = await store.apply(.markFound("sheet"))
        let retry = await store.apply(.showNextProp(.init(itemID: "sheet", becomes: "the tent", forRole: "all")))
        #expect(retry.contains("Not shown") && retry.contains("already a card") && store.props?.props.count == 1)
        _ = await store.apply(.showNextProp(.init(itemID: "sheet", becomes: "the tent", forRole: "all", alternates: ["blanket"])))
        let ids = store.props?.props.compactMap(\.libraryID) ?? []
        #expect(ids.count == 2 && Set(ids).count == 2 && ids.last == "blanket")
    }

    @Test func theSameUseNeverTwiceInOneHunt() async {
        let store = AdventureStore(service: nil)
        await hunting(store, game: "Pirate Ship", theme: "Pirate Ship", roles: ["Captain", "Navigator"])
        _ = await store.apply(.showNextProp(.init(itemID: "cardboard-box", becomes: "the treasure chest", forRole: "all")))
        _ = await store.apply(.markFound("cardboard-box"))
        let retry = await store.apply(.showNextProp(.init(itemID: "basket", becomes: "a treasure chest", forRole: "all")))
        #expect(retry.contains("Not shown") && retry.contains("never there twice"))
        _ = await store.apply(.showNextProp(.init(itemID: "basket", becomes: "the gold chest", forRole: "all")))
        let uses = store.props?.props.map { PropWords.useKey($0.becomes) } ?? []
        #expect(uses.count == 2 && Set(uses).count == 2)
        // A swap into an item already in the hunt: retried, then a different item.
        _ = await store.apply(.markFound(store.currentPropID ?? ""))
        _ = await store.apply(.showNextProp(.init(itemID: "hat", becomes: "the captain's hat", forRole: "Captain")))
        let swapRetry = await store.apply(.swapProp(oldID: "hat", newID: "cardboard-box", becomes: ""))
        #expect(swapRetry.contains("already a card"))
        _ = await store.apply(.swapProp(oldID: "hat", newID: "cardboard-box", becomes: ""))
        let all = store.props?.props.compactMap { $0.isSkipped ? nil : $0.libraryID } ?? []
        #expect(Set(all).count == all.count)
    }

    @Test func aToyishFirstPropGivesWayToAnEverydayThing() async {
        let store = AdventureStore(service: nil)
        await hunting(store, game: "Train Ride", theme: "Train Ride", roles: ["Driver", "Passenger"])
        let out = await store.apply(.showNextProp(.init(itemID: "wagon", becomes: "the train", forRole: "all", alternates: ["laundry-basket"])))
        #expect(store.props?.props.first?.libraryID == "laundry-basket" && out.contains("everyday"))
        #expect(store.props?.props.first?.alternates?.first == "wagon")
    }

    @Test func unknownUsesOfFlexibleItemsAreLogged() async {
        var log: [String] = []
        let store = AdventureStore(service: nil)
        store.propLog = { log.append($0) }
        await hunting(store, game: "Robot Shop", theme: "Robot Shop", roles: ["Mechanic", "Customer"])
        _ = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the robot repair hub", forRole: "all")))
        #expect(store.props?.props.first?.libraryID == "bowl")
        #expect(log.contains { $0.hasPrefix("PROP unknown use") && $0.contains("bowl") })
    }

    @Test func claudesListNeverRepeatsAnItemOrAUse() async throws {
        let p = Props(nutmegSays: "", props: [
            Prop(id: "cardboard-box", householdItem: "Cardboard box", becomes: "the treasure chest", forRole: .all, safetyOK: true, libraryID: "cardboard-box"),
            Prop(id: "basket", householdItem: "Basket", becomes: "a treasure chest", forRole: .all, safetyOK: true, libraryID: "basket"),
            Prop(id: "sheet", householdItem: "Bedsheet", becomes: "the pirate sail", forRole: .all, safetyOK: true, libraryID: "sheet"),
        ])
        #expect(Validate.props(p)?.message.contains("there twice") == true)
        let fixed = PropFit.repair(p)
        let uses = fixed.props.map { PropWords.useKey($0.becomes) }
        let ids = fixed.props.compactMap(\.libraryID)
        #expect(Set(uses).count == 3 && Set(ids).count == 3)
        #expect(fixed.props.allSatisfy { PropFit.fits(itemID: $0.libraryID!, becomes: $0.becomes) })
    }

    // MARK: 6. Bundled game and replays

    @Test func theBundledAirplaneGamePassesThePrintedAndFitChecks() {
        let a = Fallback.airplane
        for p in a.props.props {
            #expect(PropFit.fits(itemID: p.libraryID ?? p.id, becomes: p.becomes), "\(p.householdItem) → \(p.becomes)")
            #expect(PrintedProps.clash(p.becomes, kit: a.kit.items) == nil, "\(p.becomes) clashes with the kit")
        }
        #expect(a.props.props.first { $0.libraryID == "backpack" }?.becomes == "Carry-on bag")
        let uses = a.props.props.map { PropWords.useKey($0.becomes) }
        #expect(Set(uses).count == uses.count && Set(a.props.props.compactMap(\.libraryID)).count == a.props.props.count)
    }

    @Test func aReplayOffersOnlyAnAlternateThatStillFits() async {
        let a = Fallback.airplane
        // A saved alternate that no longer fits (a bowl is not a wheel) and one that's another card's item (the chair).
        let props = a.props.props.map { p -> SavedProp in
            var s = SavedProp(p)
            if p.id == "plate" { s.alternates = ["bowl"] }
            if p.id == "tray" { s.alternates = ["chair"] }
            return s
        }
        let game = SavedGame(createdAt: Date(), title: "Airplane", roles: a.plan.roles, props: props, kit: a.kit,
                             printStyle: .colorIn, art: [], voiceID: VoiceConfig.nutmeg.voiceID)
        let store = AdventureStore(service: nil)
        store.loadReplay(game)
        _ = await store.apply(.setPlayerCount(2))
        #expect(store.replayHuntActive)
        for _ in 0..<8 where store.replayHuntActive {
            let cur = store.replayCurrentProp!
            if cur.id == "plate" || cur.id == "tray" {
                store.replayHunt(found: false)
                let after = store.props?.props.first { $0.id == cur.id }
                #expect(after?.isSkipped == true, "\(cur.id) should go straight to pretend")
                #expect(after?.libraryID == cur.libraryID)
            } else {
                store.replayHunt(found: true)
            }
        }
    }

    // MARK: 7. Prompts: no copied prop examples; the stuffed animal guidance

    @Test func thePromptsHaveNoCopiedPropExamples() {
        let i = Realtime.instructions
        for old in ["a bakery: \na bowl", "a bowl for the mixing bowl", "a vet clinic: a towel", "a castle: a pillow for the shield",
                    "Can you find a blanket?", "Can you find a spoon?", "Can you find a towel?", "I see a tray"] {
            #expect(!i.contains(old), "\(old)")
        }
        #expect(i.contains("SHORTLIST") && i.contains("the stuffed animal is the animal or patient, never a thing for it"))
        #expect(i.contains("NEVER the same item twice and NEVER the same pretend use twice"))
        let tool = Realtime.tools.first { $0["name"] as? String == "show_next_prop" }?["description"] as? String ?? ""
        #expect(!tool.contains("(bowl, pot, hat)") && !tool.contains("A bowl is round") && tool.contains("shortlist"))
        let claude = Prompts.props(ctx: AdventureContext(gameTitle: "Pet Groomer", playerCount: 2))
        #expect(!claude.contains("bowl, pot, hat") && !claude.contains("A bowl is round") && claude.contains("IS the animal or patient"))
    }

    // MARK: 8. The shortlist (variety)

    private func memory() -> RecentPropMemory {
        RecentPropMemory(defaults: UserDefaults(suiteName: "pt.test.r43mem.\(UUID().uuidString)")!)
    }

    @Test func theShortlistIsRepeatableWithASeedAndEveryPickFits() {
        var a = SeededGenerator(seed: 7), b = SeededGenerator(seed: 7)
        let s1 = PropShortlist.make(game: ["Bakery", "Bakery on the Moon"], recent: [], using: &a)
        let s2 = PropShortlist.make(game: ["Bakery", "Bakery on the Moon"], recent: [], using: &b)
        #expect(s1 == s2)
        #expect(s1.picks.count == PropShortlist.size && s1.backups.count == PropShortlist.backupCount)
        #expect(Set(s1.allIDs).count == s1.allIDs.count)
        for p in s1.picks + s1.backups {
            #expect(PropFit.fitsKnown(itemID: p.itemID, becomes: p.use), "\(p.itemID) → \(p.use)")
            #expect(s1.uses.contains(p.use), "\(p.use) is one of this game's uses")
        }
        // Both halves of the game count: bakery things and moon things.
        #expect(s1.uses.contains("the baker's apron") && s1.uses.contains("the rocket ship"))
    }

    @Test func anItemUsedInEachOfTheLastTwoGamesIsExcludedUnlessNothingElseFits() {
        let recent = [["towel", "tray", "chair", "stuffed-animal"], ["towel", "stuffed-animal", "bowl", "hat"]]
        for seed in 0..<30 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let s = PropShortlist.make(game: ["Pirate Ship", "Pirate Ship on a Tropical Island"], recent: recent, using: &rng)
            #expect(!s.allIDs.contains("towel") && !s.allIDs.contains("stuffed-animal"), "seed \(seed)")
            var r2 = SeededGenerator(seed: UInt64(seed))
            // A vet game's core use is the patient: only the stuffed animal can be it, so it comes back.
            let vet = PropShortlist.make(game: ["Vet Clinic"], recent: recent, using: &r2)
            #expect(vet.allIDs.contains("stuffed-animal") && !vet.allIDs.contains("towel"), "vet seed \(seed)")
        }
    }

    @Test func recentItemsAreLessLikely() {
        let recent = [["sheet", "hat", "plate", "cardboard-box"]]
        var with = 0, without = 0
        for seed in 0..<200 {
            var a = SeededGenerator(seed: UInt64(seed)), b = SeededGenerator(seed: UInt64(seed))
            if PropShortlist.make(game: ["Pirate Ship"], recent: recent, using: &a).picks.contains(where: { $0.itemID == "sheet" }) { with += 1 }
            if PropShortlist.make(game: ["Pirate Ship"], recent: [], using: &b).picks.contains(where: { $0.itemID == "sheet" }) { without += 1 }
        }
        #expect(with < without / 2, "sheet: \(with) with recency vs \(without) without")
    }

    @Test func madeUpGamesGetUsesFromTheirWords() {
        let laundromat = PropNeeds.uses(game: ["Spaceship Laundromat"], roles: ["Sock Sorter", "Captain"])
        #expect(laundromat.contains("the spaceship") && laundromat.contains("the rocket ship"))
        let nonsense = PropNeeds.uses(game: ["Zibble Zabble"])
        #expect(nonsense.count >= 6 && nonsense.contains("the treasure chest"))   // the generic uses
        var rng = SeededGenerator(seed: 3)
        let s = PropShortlist.make(game: ["Zibble Zabble"], recent: [], using: &rng)
        #expect(s.picks.count == PropShortlist.size)
        // Roles count when the game words don't say much: a "Zookeeper" brings the zoo uses.
        #expect(PropNeeds.uses(game: ["Fun Place"], roles: ["Zookeeper"]).contains("the animal cage"))
    }

    @Test func theStoreUsesTheShortlistOnEveryPath() async {
        let store = AdventureStore(service: nil)
        store.propShortlistOn = true; store.shortlistSeed = 11; store.propMemory = memory()
        await hunting(store, game: "Pirate Ship", theme: "Pirate Ship", roles: ["Captain", "Navigator"])
        let s = store.propShortlist!
        // The set_roles result carries it (checked by re-running set_roles output).
        let roles = await store.apply(.setRoles([.init(roleName: "Captain", job: "steers"), .init(roleName: "Navigator", job: "maps")]))
        #expect(roles.contains("PROP SHORTLIST") && s.picks.allSatisfy { roles.contains($0.itemID) })
        let s2 = store.propShortlist!
        let off = PropLibrary.ids.first { !s2.contains($0) && PropFit.fits(itemID: $0, becomes: "the treasure chest") }!
        let retry = await store.apply(.showNextProp(.init(itemID: off, becomes: "the treasure chest", forRole: "all")))
        #expect(retry.contains("isn't on this game's prop shortlist") && store.props == nil)
        _ = await store.apply(.showNextProp(.init(itemID: off, becomes: "the treasure chest", forRole: "all")))
        let card = store.props!.props[0]
        #expect(s2.contains(card.libraryID!) && PropFit.fits(itemID: card.libraryID!, becomes: card.becomes))
        #expect((card.alternates ?? []).allSatisfy(s2.contains))
        // A good shortlist pick goes straight through.
        _ = await store.apply(.markFound(card.id))
        let next = s2.picks.first { $0.itemID != card.libraryID && PropWords.useKey($0.use) != PropWords.useKey(card.becomes) }!
        let ok = await store.apply(.showNextProp(.init(itemID: next.itemID, becomes: next.use, forRole: "all")))
        #expect(!ok.contains("Not shown") && store.props?.props.last?.libraryID == next.itemID)
        // A swap off the shortlist: retried.
        let swapOff = PropLibrary.ids.first { !s2.contains($0) }!
        let swapRetry = await store.apply(.swapProp(oldID: next.itemID, newID: swapOff, becomes: ""))
        #expect(swapRetry.contains("shortlist"))
        // The tap path's context carries it, and Claude's list is held to it.
        #expect(store.context.propShortlist == s2)
        let bad = Props(nutmegSays: "", props: [
            Prop(id: off, householdItem: PropLibrary.name(off)!, becomes: "the treasure chest", forRole: .all, safetyOK: true, libraryID: off),
        ])
        #expect(Validate.props(bad, shortlist: s2) != nil)
        #expect(PropFit.repair(bad, shortlist: s2).props.allSatisfy { s2.contains($0.libraryID!) })
        #expect(Prompts.props(ctx: store.context).contains("prop shortlist"))
    }

    @Test func boxAndBowlNoLongerDominateOver50Games() {
        let m = memory()
        var rng = SeededGenerator(seed: 2026)
        let games = Suggestions.games, twists = Suggestions.twists
        var count: [String: Int] = [:]
        for g in 0..<50 {
            let game = games[g % games.count].text, twist = twists[(g * 7) % twists.count].text
            let s = PropShortlist.make(game: [game, "\(game) \(twist)"], recent: m.games, using: &rng)
            // The model takes 4 or 5 of the shortlist (here: the first ones, its most iconic-first order).
            let hunt = Array(s.picks.prefix(g % 2 == 0 ? 4 : 5).map(\.itemID))
            m.record(hunt)
            for id in hunt { count[id, default: 0] += 1 }
            // The hard cap: nothing in each of the last 2 games' hunts gets a third game in a row (unless nothing fits).
            if m.games.count >= 3 {
                let streak = Set(m.games[0]).intersection(m.games[1]).intersection(m.games[2])
                #expect(streak.isEmpty || streak == ["stuffed-animal"], "game \(g): \(streak)")
            }
        }
        let box = count["cardboard-box", default: 0], bowl = count["bowl", default: 0]
        #expect(box <= 12 && bowl <= 12, "box \(box), bowl \(bowl) of 50 games")
        #expect(count.keys.count >= 35, "only \(count.keys.count) different items over 50 games")
        // The stuffed animal is the one item many games truly need (the patient, the dinosaur, the parrot: Haylee's
        // "it IS the animal" rule), so it may come up more; every other item stays rare.
        let top = count.filter { $0.key != "stuffed-animal" }.values.max() ?? 0
        #expect(top <= 12, "the most used item is in \(top) of 50 games")
        #expect(count["stuffed-animal", default: 0] <= 25)
        let ranked = count.sorted { $0.value > $1.value }.prefix(8).map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        print("ROUND43 distribution over 50 games: box \(box), bowl \(bowl), blanket \(count["blanket", default: 0]), "
              + "pillow \(count["pillow", default: 0]); \(count.keys.count) different items; top: \(ranked)")
    }
}
