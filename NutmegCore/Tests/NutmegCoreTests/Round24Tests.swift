import Foundation
import Testing
@testable import NutmegCore

/// Round 24 (Haylee): props must make sense (a bowl is never a pirate sail). (The printer question and the no-printer
/// "Draw it!" path were removed in round 25, Haylee; their tests went with them.)
@MainActor struct Round24Tests {

    // MARK: 1. Props that make sense

    @Test(arguments: [
        ("bowl", "the pirate sail", false),
        ("bowl", "captain hat", true),
        ("bowl", "the captain's hat", true),
        ("towel", "cape", true),
        ("pillowcase", "the pirate sail", true),
        ("chair", "airplane seats", true),
        ("plate", "the steering wheel", true),
        ("spoon", "the big stirrer", true),
        ("blanket", "the big blue ocean", true),
        ("cardboard-box", "the rocket ship", true),
        ("cup", "the pirate sail", false),
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
        let f = PropFit.fallback(becomes: "the pirate sail", preferring: ["cup", "towel"])
        #expect(f.itemID == "towel" && f.becomes == "the pirate sail" && PropFit.fits(itemID: f.itemID, becomes: f.becomes))
        let g = PropFit.fallback(becomes: "the pirate sail", avoiding: ["towel", "blanket", "rug", "sheet", "table", "plate", "tray", "books", "pillow", "teddy-bed", "cushion", "stool"])
        #expect(PropFit.fits(itemID: g.itemID, becomes: g.becomes))
    }

    private func hunting(_ store: AdventureStore) async {
        store.beginConversation()
        _ = await store.apply(.setGame("Pirate Ship")); _ = await store.apply(.setTheme("Pirate Ship on the Moon"))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
        _ = await store.apply(.setRoles([.init(roleName: "Captain", job: ""), .init(roleName: "Navigator", job: "")]))
    }

    @Test func aMisfitGetsOneRetryThenACuratedPair() async {
        let store = AdventureStore(service: nil)
        await hunting(store)
        let first = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the pirate sail", forRole: "all", alternates: ["towel"])))
        #expect(first.contains("Not shown") && first.contains("towel") && store.props == nil)     // the retry, no card
        let second = await store.apply(.showNextProp(.init(itemID: "bowl", becomes: "the pirate sail", forRole: "all", alternates: ["towel"])))
        let p = store.props?.props.first
        #expect(p?.libraryID == "towel" && p?.becomes == "the pirate sail" && second.contains("didn't fit"))
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
        _ = await store.apply(.showNextProp(.init(itemID: "towel", becomes: "the pirate sail", forRole: "all")))
        let retry = await store.apply(.swapProp(oldID: "towel", newID: "bowl", becomes: ""))
        #expect(retry.contains("Not shown") && store.props?.props.first?.libraryID == "towel")
        _ = await store.apply(.swapProp(oldID: "towel", newID: "bowl", becomes: ""))
        let p = store.props?.props.first
        #expect(p?.libraryID != "bowl" && PropFit.fits(itemID: p?.libraryID ?? "", becomes: "the pirate sail"))
    }

    @Test func claudesPropListIsRepaired() async throws {
        let bad = Props(nutmegSays: "Go find these!", props: [
            Prop(id: "bowl", householdItem: "Bowl", becomes: "the pirate sail", forRole: .all, safetyOK: true, libraryID: "bowl"),
            Prop(id: "towel", householdItem: "Towel", becomes: "the cape", forRole: .all, safetyOK: true, libraryID: "towel"),
            Prop(id: "chair", householdItem: "Chair", becomes: "the ship's seats", forRole: .all, safetyOK: true, libraryID: "chair"),
        ])
        #expect(Validate.props(bad)?.message.contains("Bowl as the pirate sail") == true)
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
}
