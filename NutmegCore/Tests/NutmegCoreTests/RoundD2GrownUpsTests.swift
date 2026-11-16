import Foundation
import Testing
@testable import NutmegCore

/// Round D2: the Grown-ups corner (gate + Saved games delete), design 2026-11-15 §D6 and Haylee's §10.3.
@MainActor
struct RoundD2GrownUpsTests {
    // MARK: Spelled numbers

    @Test func spellsEveryNumberFrom1To99() {
        #expect(NumberWords.spell(1) == "one")
        #expect(NumberWords.spell(7) == "seven")
        #expect(NumberWords.spell(13) == "thirteen")
        #expect(NumberWords.spell(19) == "nineteen")
        #expect(NumberWords.spell(20) == "twenty")
        #expect(NumberWords.spell(40) == "forty")
        #expect(NumberWords.spell(47) == "forty-seven")
        #expect(NumberWords.spell(81) == "eighty-one")
        #expect(NumberWords.spell(99) == "ninety-nine")
        #expect(NumberWords.spell(0) == nil && NumberWords.spell(100) == nil && NumberWords.spell(-3) == nil)
        let all = (1...99).compactMap(NumberWords.spell)
        #expect(all.count == 99 && Set(all).count == 99)               // every number, all different
        #expect(all.allSatisfy { $0.range(of: "^[a-z]+(-[a-z]+)?$", options: .regularExpression) != nil })
        #expect(!all.contains { $0.contains("fourty") })                 // forty, not fourty
        // Hyphen exactly when the number has tens and ones (21–99, not a multiple of 10).
        for n in 1...99 { #expect(NumberWords.spell(n)!.contains("-") == (n > 20 && n % 10 != 0)) }
    }

    // MARK: The gate

    @Test func holdMustLastTwoSeconds() {
        var g = GrownUpGate(seed: 42)
        #expect(g.step == .hold && GrownUpGate.holdSeconds == 2)
        do { let r = g.holdEnded(after: 0.3); #expect(!r) }
        do { let r = g.holdEnded(after: 1.99); #expect(!r) }
        #expect(g.step == .hold && g.words == nil)
        do { let r = g.holdEnded(after: 2.0); #expect(r) }
        guard case .question = g.step else { Issue.record("expected the question"); return }
        // The hold fill.
        #expect(GrownUpGate.holdProgress(0) == 0 && GrownUpGate.holdProgress(1) == 0.5)
        #expect(GrownUpGate.holdProgress(3) == 1 && GrownUpGate.holdProgress(-1) == 0)
        // A second hold during the question does nothing.
        do { let r = g.holdEnded(after: 5); #expect(!r) }
    }

    @Test func questionHasTheTargetOnceAmongDistinctDistractors() {
        for seed in UInt64(1)...200 {
            var g = GrownUpGate(seed: seed)
            g.holdEnded(after: 2)
            guard case .question(let target, let options) = g.step else { Issue.record("no question"); return }
            #expect(options.count == GrownUpGate.optionCount)
            #expect(Set(options).count == options.count)
            #expect(options.filter { $0 == target }.count == 1)
            #expect(options.allSatisfy { GrownUpGate.range.contains($0) })
            #expect(g.words == NumberWords.spell(target))
        }
    }

    @Test func rightAnswerPassesWrongAnswerResetsWithANewNumber() {
        var g = GrownUpGate(seed: 7)
        g.holdEnded(after: 2.4)
        guard case .question(let first, let options) = g.step else { Issue.record("no question"); return }
        let wrong = options.first { $0 != first }!
        do { let r = g.answer(wrong); #expect(!r) }
        #expect(g.step == .hold && g.misses == 1)                       // gentle reset: back to the hold
        do { let r = g.answer(first); #expect(!r) }                                        // no answering from the hold
        g.holdEnded(after: 2)
        guard case .question(let second, _) = g.step else { Issue.record("no question"); return }
        #expect(second != first)                                         // the number changes
        do { let r = g.answer(second); #expect(r) }
        #expect(g.step == .passed)
        do { let r = g.holdEnded(after: 3); #expect(!r) }                                  // passed stays passed
        g.reset()
        #expect(g.step == .hold && g.misses == 0)
    }

    @Test func wrongAnswersAlwaysChangeTheNumber() {
        var g = GrownUpGate(seed: 99)
        var last: Int?
        for _ in 0..<50 {
            g.holdEnded(after: 2)
            guard case .question(let t, let o) = g.step else { Issue.record("no question"); return }
            if let last { #expect(t != last) }
            last = t
            g.answer(o.first { $0 != t }!)
        }
        #expect(g.misses == 50)
    }

    // MARK: Sections and copy

    @Test func onlySavedGamesSectionsShowUntilSectionE() {
        #expect(GrownUpsFeatures.storeSections == false)
        #expect(GrownUpsSection.visible() == [.savedGames, .aboutSavedGames])
        #expect(GrownUpsSection.visible(storeSections: true) == [.savedGames, .aboutSavedGames, .subscription,
                                                                  .restorePurchases, .privacyPolicy, .help])
        #expect(GrownUpsCopy.deleteConfirm("Moon Crumbs Bakery") == "Delete Moon Crumbs Bakery? This can't be undone.")
        let about = GrownUpsCopy.about.map { $0.title + " " + $0.body }.joined(separator: " ")
        #expect(about.contains("this iPad") && about.contains("no accounts") && about.contains("never saves your child"))
    }

    // MARK: Deleting from the store

    func game(_ title: String, at t: TimeInterval) -> SavedGame {
        let a = Fallback.airplane
        return SavedGame(createdAt: Date(timeIntervalSince1970: t), title: title, roles: a.plan.roles,
                         props: a.props.props.map(SavedProp.init), kit: a.kit, hasPrinter: true, printStyle: .colorIn,
                         drawGuide: nil, art: [], voiceID: VoiceConfig.nutmeg.voiceID)
    }

    @Test func deleteRemovesTheFilesAndMyGamesFollowsTheStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pt-d2-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SavedGameStore(root: root)
        #expect(!store.showsMyGames && store.rows().isEmpty)

        let bakery = game("Moon Crumbs Bakery", at: 1_800_000_000)
        let pirates = game("Pirate Ship on the Moon", at: 1_800_000_900)
        try store.save(bakery, art: [ArtKey.image("sign"): Data(repeating: 1, count: 2048), ArtKey.cutout("badge", 0): Data([2])],
                       cover: Data(repeating: 9, count: 512))
        try store.save(pirates, art: [ArtKey.image("map"): Data([3])], cover: nil)
        #expect(store.showsMyGames)

        let rows = store.rows()
        #expect(rows.map(\.title) == ["Pirate Ship on the Moon", "Moon Crumbs Bakery"])   // newest first
        #expect(rows[1].bytes > 2048 + 512 && !rows[1].sizeText.isEmpty)
        #expect(rows[1].dateText(locale: Locale(identifier: "en_US")).contains("2027"))
        #expect(rows[1].accessibilityLabel.hasPrefix("Moon Crumbs Bakery, saved "))

        let folder = root.appendingPathComponent(bakery.id.uuidString)
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("art/img_sign.heic").path))
        #expect(store.deleteGame(bakery.id))
        #expect(!FileManager.default.fileExists(atPath: folder.path))   // game.json, art and cover all gone
        #expect(store.game(bakery.id) == nil && store.rows().map(\.title) == ["Pirate Ship on the Moon"])
        #expect(store.showsMyGames)                                      // one left: My games stays

        #expect(store.deleteGame(pirates.id))
        #expect(!store.showsMyGames && store.count == 0)                 // the last one: My games goes away
        let left = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(left.isEmpty)
        #expect(store.deleteGame(UUID()))                                // deleting a missing game is harmless
    }
}
