import Foundation
import Testing
@testable import NutmegCore

/// Round 30 (Haylee): prop anti-repeat across the last ~5 games (prop IDs only, UserDefaults).
@MainActor
struct Round30RecentPropsTests {
    private func memory() -> RecentPropMemory {
        let d = UserDefaults(suiteName: "pt.test.recentProps.\(UUID().uuidString)")!
        return RecentPropMemory(defaults: d)
    }

    @Test func remembersOnlyLibraryIDsOfTheLastFiveGames() {
        let m = memory()
        m.record(["pillow", "blanket", "Mia", "pillow", "custom0"])   // a name or free text is never stored
        #expect(m.games == [["pillow", "blanket"]])
        for g in [["bowl"], ["spoon"], ["towel"], ["chair"], ["hat"]] { m.record(g) }
        #expect(m.games.count == RecentPropMemory.gameCount)
        #expect(!m.recent.contains("pillow") && m.recent.contains("hat") && m.recent.contains("bowl"))
        m.record([])   // nothing to remember: unchanged
        #expect(m.games.first == ["hat"])
    }

    @Test func fresherPicksAFittingUnusedAlternate() {
        let recent: Set<String> = ["pillow", "cushion"]
        // pillow (recent) as a shield: cushion is recent too, plate fits (round), so plate.
        #expect(RecentProps.fresher(itemID: "pillow", becomes: "the shield", alternates: ["cushion", "plate"], recent: recent, used: []) == "plate")
        // Not recent: keep it.
        #expect(RecentProps.fresher(itemID: "plate", becomes: "the shield", alternates: ["tray"], recent: recent, used: []) == nil)
        // No alternate fits the use: keep it (never a misfit just to be new).
        #expect(RecentProps.fresher(itemID: "pillow", becomes: "the shield", alternates: ["spoon"], recent: recent, used: []) == nil)
        // Already a card this hunt: not offered again.
        #expect(RecentProps.fresher(itemID: "pillow", becomes: "the shield", alternates: ["plate"], recent: recent, used: ["plate"]) == nil)
    }

    @Test func theStoreSteersAwayAndRecordsTheHunt() async {
        let m = memory()
        m.record(["pillow", "blanket"])
        let store = AdventureStore(service: nil)
        store.propMemory = m
        store.beginConversation()
        #expect(store.recentProps == ["pillow", "blanket"])
        _ = await store.apply(.setGame("Castle")); _ = await store.apply(.setTheme("Castle with Friendly Monsters"))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
        let roles = await store.apply(.setRoles([.init(roleName: "Knight", job: "guards"), .init(roleName: "Guide", job: "guides")]))
        #expect(roles.contains("PROPS USED IN RECENT GAMES") && roles.contains("blanket, pillow"))
        let out = await store.apply(.showNextProp(.init(itemID: "pillow", becomes: "the shield", forRole: "Knight", alternates: ["plate"])))
        #expect(store.props?.props.first?.libraryID == "plate")
        #expect(store.props?.props.first?.alternates?.first == "pillow")   // the recent item stays as the backup
        #expect(out.contains("recent game"))
        _ = await store.apply(.markFound(store.currentPropID ?? ""))
        _ = await store.apply(.showNextProp(.init(itemID: "towel", becomes: "the cape", forRole: "all")))
        _ = await store.apply(.finishPlanning)
        #expect(m.games.first == ["plate", "towel"])
        #expect(m.games.count == 2)
    }

    @Test func noMemoryMeansNoSteering() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Castle")); _ = await store.apply(.setPlayerCount(1)); _ = await store.confirmYes()
        let roles = await store.apply(.setRoles([.init(roleName: "Knight", job: "guards")]))
        #expect(!roles.contains("RECENT"))
    }
}
