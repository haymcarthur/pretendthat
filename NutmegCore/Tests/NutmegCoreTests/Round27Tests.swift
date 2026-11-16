import Foundation
import Testing
@testable import NutmegCore

/// Round 27 (Haylee): every kit page in BOTH styles, the choice on the Print screen, and a text-free bookshelf cover.
@MainActor
struct Round27Tests {
    let a = Fallback.airplane

    func game(plain: PrintStyle?, art: [String]) -> SavedGame {
        SavedGame(createdAt: Date(timeIntervalSince1970: 1_800_000_000), title: "Airplane to the Beach", roles: a.plan.roles,
                  props: a.props.props.map(SavedProp.init), kit: a.kit, printStyle: plain, art: art, voiceID: VoiceConfig.nutmeg.voiceID)
    }

    // MARK: The both-style kit

    @Test func everyPageIsDrawnInBothStylesWithTheSameKeysAndTheSafetySuffix() {
        let items = a.kit.items
        let color = KitArtPlan.jobs(items: items, title: "Airplane", style: .fullColor, settled: [], roles: a.plan.roles)
        let outline = KitArtPlan.jobs(items: items, title: "Airplane", style: .colorIn, settled: [], roles: a.plan.roles)
        // Two separate image calls per page: the same pages (keys, sizes, sheet counts), a different look.
        #expect(color.map(\.key) == outline.map(\.key) && color.map(\.size) == outline.map(\.size) && color.map(\.count) == outline.map(\.count))
        #expect(!color.isEmpty)
        for (c, o) in zip(color, outline) {
            #expect(c.prompt != o.prompt)
            #expect(c.prompt.contains("Full-color") && o.prompt.contains("Black and white only"))
            #expect(c.prompt.hasSuffix(ImageSafety.suffix) && o.prompt.hasSuffix(ImageSafety.suffix))
        }
        // A game's images: both sets + the cover.
        #expect(color.count + outline.count + 1 == 2 * color.count + 1)
        #expect(PrintStyle.sets == [.fullColor, .colorIn] && PrintStyle.defaultSet == .fullColor)
    }

    @Test func styledArtKeysParseAndOldSavesKeepTheirOneStyle() {
        #expect(ArtKey.image("sign", style: .fullColor) == "img:sign" && ArtKey.image("sign", style: .colorIn) == "oimg:sign")
        #expect(ArtKey.cutout("cut", 2, style: .fullColor) == "cut:cut:2" && ArtKey.cutout("cut", 2, style: .colorIn) == "ocut:cut:2")
        let o = ArtKey.parse("ocut:badges:4", plain: .fullColor)
        #expect(o?.itemID == "badges" && o?.index == 4 && o?.style == .colorIn)
        let p = ArtKey.parse("img:sign", plain: .fullColor)
        #expect(p?.itemID == "sign" && p?.index == nil && p?.style == .fullColor)
        // A game saved before round 27 (coloring pages, plain keys) has only the outline set.
        let old = game(plain: .colorIn, art: ["img:sign", "cut:badges:0"])
        #expect(old.artSets == [.colorIn])
        #expect(ArtKey.parse("img:sign", plain: old.plainArtStyle)?.style == .colorIn)
        #expect(game(plain: nil, art: ["img:sign"]).artSets == [.colorIn])
        #expect(game(plain: .fullColor, art: ["img:sign"]).artSets == [.fullColor])
        // A round 27 save: plain = color, o-prefixed = outline.
        #expect(game(plain: .fullColor, art: ["img:sign", "oimg:sign"]).artSets == [.fullColor, .colorIn])
        #expect(ArtKey.fileName("oimg:sign") != ArtKey.fileName("img:sign"))
    }

    // MARK: Choosing the set

    @Test func voiceChoiceWordsMapToTheRightSet() {
        #expect(PrintStyle(choice: "color") == .fullColor && PrintStyle(choice: "in color") == .fullColor)
        #expect(PrintStyle(choice: "the color ones") == .fullColor && PrintStyle(choice: "full_color") == .fullColor)
        #expect(PrintStyle(choice: "outline") == .colorIn && PrintStyle(choice: "we'll color them") == .colorIn)
        #expect(PrintStyle(choice: "the outline ones") == .colorIn && PrintStyle(choice: "plain") == .colorIn)
        #expect(PrintStyle(choice: "coloring pages") == .colorIn && PrintStyle(choice: "") == nil && PrintStyle(choice: "pizza") == nil)
        #expect(PlanningCall.decode(name: "choose_print_set", arguments: #"{"set":"outline"}"#) == .choosePrintSet(.colorIn))
        #expect(PlanningCall.decode(name: "choose_print_set", arguments: #"{"set":"color"}"#) == .choosePrintSet(.fullColor))
        #expect(PlanningCall.decode(name: "choose_print_set", arguments: "{}") == nil)
        // The tool is in the one cached tools array and offered on Print (first plays and replays).
        #expect(Realtime.tools.compactMap { $0["name"] as? String }.contains("choose_print_set"))
        #expect(Realtime.afterHuntTools(.kitReady)?.contains("choose_print_set") == true)
        #expect(ReplayLines.tools(.kitReady)?.contains("choose_print_set") == true)
        #expect(Realtime.instructions.contains("choose_print_set"))
    }

    @Test func selectionDefaultsToColorAndMovesOnlyOnPrint() async {
        let store = AdventureStore(service: nil)
        #expect(store.printSet == .fullColor && store.availableSets == [.fullColor, .colorIn])
        store.loadReplay(game(plain: .fullColor, art: ["img:sign", "oimg:sign"]))
        #expect(store.printSet == .fullColor && store.availableSets == [.fullColor, .colorIn])
        // Not on Pick.
        #expect(await store.apply(.choosePrintSet(.colorIn)) == PrintSetLines.notNowOutput && store.printSet == .fullColor)
        _ = await store.apply(.setPlayerCount(3))
        store.replayAllFound()
        #expect(store.phase == .kitReady)
        let out = await store.apply(.choosePrintSet(.colorIn))
        #expect(out == PrintSetLines.chosenOutput(.colorIn) && store.printSet == .colorIn)
        #expect(out.contains("Say exactly this"))
        #expect(store.choosePrintSet(.fullColor) && store.printSet == .fullColor)   // a tap
        // A new game starts on color again.
        store.newGame()
        #expect(store.printSet == .fullColor)
    }

    @Test func anOldOneStyleSaveOffersOnlyItsSet() async {
        let store = AdventureStore(service: nil)
        store.loadReplay(game(plain: .colorIn, art: ["img:sign"]))
        #expect(store.availableSets == [.colorIn] && store.printSet == .colorIn)
        _ = await store.apply(.setPlayerCount(2))
        store.replayAllFound()
        #expect(await store.apply(.choosePrintSet(.fullColor)) == PrintSetLines.onlyOneOutput(.colorIn))
        #expect(!store.choosePrintSet(.fullColor) && store.printSet == .colorIn)
    }

    @Test func printLineMentionsTheChoiceBriefly() {
        let l = HandOffLines.printReady
        #expect(l.contains("Want them in color, or plain to color yourself? Tap the ones you like, then the printer!"))
        #expect(!TurnCheck.mentionsGoPlay(l) && CommonLines.all.contains(l))
    }

    // MARK: The cover

    @Test func coverPromptIsSquareFullColorAndTextFree() {
        let p = CoverArt.prompt(title: "Moon Bakery", setting: "a bakery on the moon")
        #expect(CoverArt.size == "1024x1024")
        #expect(p.contains("\"Moon Bakery\"") && p.contains("a bakery on the moon") && p.contains("full-color"))
        #expect(p.contains("No words, no letters") && p.contains("no text of any kind"))
        #expect(!p.contains("Spell") && !p.contains("Title at the top") && p.hasSuffix(ImageSafety.suffix))
        // The setting isn't repeated when it's the title.
        #expect(!CoverArt.prompt(title: "Moon Bakery", setting: "Moon Bakery").contains("(Moon Bakery)"))
    }

    @Test func coverFallsBackToTheColorSignThenTheOutlineSign() {
        #expect(CoverArt.pick(cover: "cover", colorSign: "color", outlineSign: "outline") == "cover")
        #expect(CoverArt.pick(cover: nil, colorSign: "color", outlineSign: "outline") == "color")
        #expect(CoverArt.pick(cover: nil, colorSign: nil, outlineSign: "outline") == "outline")
        #expect(CoverArt.pick(cover: String?.none, colorSign: nil, outlineSign: nil) == nil)
    }

    // MARK: Saving both sets + the cover

    @Test func savedGameRoundTripsBothSetsAndTheCover() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pt-r27-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = SavedGameStore(root: root)
        let art: [String: Data] = [
            ArtKey.image("sign", style: .fullColor): Data([1]), ArtKey.image("sign", style: .colorIn): Data([2]),
            ArtKey.cutout("badges", 0, style: .fullColor): Data([3]), ArtKey.cutout("badges", 0, style: .colorIn): Data([4]),
        ]
        let g = game(plain: .fullColor, art: [])
        try disk.save(g, art: art, cover: Data([9, 9]))
        let back = try #require(disk.game(g.id))
        #expect(back.printStyle == .fullColor && back.artSets == [.fullColor, .colorIn])
        #expect(Set(back.art) == Set(art.keys) && disk.art(for: back) == art)
        #expect(back.cover == "cover.jpg" && disk.cover(for: back) == Data([9, 9]))
        // Split back into the two sets by style.
        var sets: [PrintStyle: [String: Data]] = [:]
        for (k, d) in disk.art(for: back) { if let p = ArtKey.parse(k, plain: back.plainArtStyle) { sets[p.style, default: [:]][k] = d } }
        #expect(sets[.fullColor]?.count == 2 && sets[.colorIn]?.count == 2)
        // The JSON keys are unchanged (no new field: the privacy test's set holds).
        let top = try JSONSerialization.jsonObject(with: SavedGame.encoder().encode(back)) as! [String: Any]
        #expect(Set(top.keys).isSubset(of: SavedGame.allowedKeys))
    }

    // MARK: Measurements

    @Test func peakPerMinuteCountsTheBusiestWindow() {
        let t = Date(timeIntervalSince1970: 0)
        let d = [0, 5, 10, 59, 61, 62, 130].map { t.addingTimeInterval(Double($0)) }
        #expect(ImageUsageLog.peakPerMinute(d) == 5)   // 5…62 s
        #expect(ImageUsageLog.peakPerMinute([]) == 0)
        let s = ImageUsageLog.Snapshot(requests: 13, rateLimited: 0, inputTokens: 1_000_000, outputTokens: 1_000_000, peakPerMinute: 13)
        #expect(abs(s.dollars - 35) < 0.001)
    }
}
