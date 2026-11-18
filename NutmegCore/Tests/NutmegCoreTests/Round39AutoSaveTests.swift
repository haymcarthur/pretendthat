import Foundation
import Testing
@testable import NutmegCore

/// Round 39: auto-save at the kit, the show counted then, the bookshelf moment's lines, "sounds like a game you have",
/// the leave dialog, the shelf order and Grown-ups → Saved games (Last played sort, search).
@MainActor
struct Round39AutoSaveTests {
    let a = Fallback.airplane

    func game(_ title: String, created: Double = 1_800_000_000, played: Double? = nil) -> SavedGame {
        var g = SavedGame(createdAt: Date(timeIntervalSince1970: created), title: title, roles: a.plan.roles,
                          props: a.props.props.map(SavedProp.init), kit: a.kit, printStyle: .fullColor, art: [],
                          voiceID: VoiceConfig.nutmeg.voiceID)
        if let played { g.lastPlayedAt = Date(timeIntervalSince1970: played) }
        return g
    }
    func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pt-r39-\(UUID().uuidString)", isDirectory: true)
    }

    // MARK: Count + save when the kit is made

    @Test func kitMadeLatchFiresOncePerNewGameOnlyWithAKit() {
        var l = KitMadeLatch()
        let id = UUID()
        let c1 = l.claim(gameID: id, isReplay: false, kitExists: false); #expect(!c1)   // closed before the kit: free, nothing saved
        let c2 = l.claim(gameID: id, isReplay: false, kitExists: true); #expect(c2)
        let c3 = l.claim(gameID: id, isReplay: false, kitExists: true); #expect(!c3)    // a remade kit or back to Print: not again
        let c4 = l.claim(gameID: UUID(), isReplay: true, kitExists: true); #expect(!c4) // a replay never counts
        let c5 = l.claim(gameID: UUID(), isReplay: false, kitExists: true); #expect(c5) // the next new game
    }

    @Test func aNewGameIsSaveableFromTheKitOnAndRemembersItsGameType() async {
        let s = AdventureStore(service: nil)
        await s.start(); await s.chooseGame("Airplane"); s.setPlayerCount(2)
        await s.confirmPlayers(); await s.confirmRoles()
        #expect(!s.canAutoSave)
        await s.confirmProps()
        #expect(s.phase == .kitReady && s.canAutoSave)
        let g = s.savedGame(art: [], cover: nil)
        #expect(g != nil && g!.kit.scenes.isEmpty == false)
        s.newGame()
        #expect(s.gameType == nil && !s.canAutoSave)
    }

    @Test func gameTypeIsKeptThroughTheTheme() async {
        let s = AdventureStore(service: nil)
        _ = await s.apply(.setGame("Pizza Restaurant"))
        _ = await s.apply(.setTheme("Pizza Restaurant in the Jungle"))
        #expect(s.gameType == "Pizza Restaurant" && s.currentTitle == "Pizza Restaurant in the Jungle")
    }

    @Test func updateKeepsClipsAndDatesAndReplacesArt() throws {
        let root = tempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SavedGameStore(root: root)
        var g = game("Airplane to the Beach")
        // First write (the moment the kit is made): no art yet.
        #expect(store.update(g, art: [:], keep: [], cover: nil))
        // A line recorded during play joins the game.
        let clip = SavedClip(key: "k1", text: "Hi", kind: "scene", role: nil, duration: 1, file: "")
        #expect(store.addClip(clip, data: Data([1]), to: g.id))
        store.touch(g.id, at: Date(timeIntervalSince1970: 1_900_000_000))
        // The art lands and the cover is drawn: the save is updated, the clip and the dates stay.
        g.title = "Airplane to the Beach"
        #expect(store.update(g, art: ["img:sign": Data([7]), "img:old": Data([8])], keep: ["img:sign", "img:old"], cover: Data([9])))
        var back = store.game(g.id)!
        #expect(back.clips.map(\.key) == ["k1"] && back.art == ["img:old", "img:sign"] && back.cover == "cover.jpg")
        #expect(back.lastPlayedAt == Date(timeIntervalSince1970: 1_900_000_000) && back.createdAt == g.createdAt)
        // The kit is remade: an old page's art goes, the cover stays when none is given.
        #expect(store.update(g, art: [:], keep: ["img:sign"], cover: nil))
        back = store.game(g.id)!
        #expect(back.art == ["img:sign"] && back.cover == "cover.jpg" && store.art(for: back).count == 1)
        #expect(store.cover(for: back) == Data([9]))
    }

    // MARK: Bookshelf order + Grown-ups

    @Test func shelfIsMostRecentlyPlayedFirst() throws {
        let root = tempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SavedGameStore(root: root)
        let old = game("Old Favorite", created: 1_800_000_000, played: 1_900_000_000)
        let new = game("Brand New", created: 1_850_000_000)
        try store.save(old, art: [:], cover: nil)
        try store.save(new, art: [:], cover: nil)
        #expect(store.list().map(\.title) == ["Old Favorite", "Brand New"])
        // Grown-ups: Newest is by save date, Last played by play date, and every row has its size.
        let rows = store.rows()
        #expect(SavedGameSort.newest.apply(rows).map(\.title) == ["Brand New", "Old Favorite"])
        #expect(SavedGameSort.lastPlayed.apply(rows).map(\.title) == ["Old Favorite", "Brand New"])
        #expect(rows.allSatisfy { $0.bytes > 0 && !$0.sizeText.isEmpty })
        #expect(SavedGameSort.allCases.map(\.label) == ["Newest", "Last played", "Name"])
    }

    @Test func grownUpsSearchFindsByName() {
        let rows = ["Moon Crumbs Bakery", "Pirate Ship on the Moon", "Pet Vet", "Café Olé"].enumerated().map {
            SavedGameRow(id: UUID(), title: $1, savedAt: Date(timeIntervalSince1970: Double($0)), bytes: 1)
        }
        #expect(SavedGameSearch.filter(rows, query: "moon").map(\.title) == ["Moon Crumbs Bakery", "Pirate Ship on the Moon"])
        #expect(SavedGameSearch.filter(rows, query: "  ").count == 4)
        #expect(SavedGameSearch.filter(rows, query: "cafe ole").map(\.title) == ["Café Olé"])
        #expect(SavedGameSearch.filter(rows, query: "zzz").isEmpty)
    }

    // MARK: "Sounds like a game you have"

    @Test func soundsLikeMatchesGameTypeAndTheme() {
        func close(_ type: String?, _ title: String, _ saved: String) -> Bool { GameMatch.isClose(gameType: type, title: title, saved: saved) }
        #expect(close("Pizza Restaurant", "Pizza Restaurant in the Jungle", "Jungle Pizza Restaurant"))
        #expect(close("Pizza Restaurant", "Pizza Restaurants in the Jungle", "Pizza Restaurant in the jungle"))
        #expect(close("Pet Vet", "Pet Vet", "Pet Vet Clinic"))                       // a place word isn't a twist
        #expect(close("Airplane", "Airplane to the Beach", "Airplane to the Beach"))
        #expect(!close("Airplane", "Airplane to the Beach", "Airplane to the Moon"))  // same game, other twist
        #expect(!close("Pizza Restaurant", "Pizza Restaurant in the Jungle", "Pizza Restaurant"))
        #expect(!close("Bakery", "Bakery on the Moon", "Pirate Ship on the Moon"))    // same twist, other game
        #expect(!close("Pet Vet", "Pet Vet", "Pet Shop"))
        #expect(close(nil, "Cozy Café", "Cozy Cafe"))                                  // no game type: the whole title
    }

    @Test func closestPrefersTheMostRecentlyPlayed() {
        let a1 = game("Airplane to the Beach", created: 1, played: 10)
        let a2 = game("Beach Airplane", created: 2, played: 20)
        let other = game("Bug Theater", created: 3, played: 30)
        #expect(GameMatch.closest(gameType: "Airplane", title: "Airplane to the Beach", in: [a1, other, a2])?.id == a2.id)
        #expect(GameMatch.closest(gameType: "Pet Vet", title: "Pet Vet in Space", in: [a1, a2, other]) == nil)
        #expect(GameMatch.closest(gameType: "Airplane", title: "Airplane to the Beach", in: []) == nil)
    }

    @Test func shelfLinesAreKidSafeAndShort() {
        // Round 41/42: no bookshelf moment and no "shelf" in her words; the End line is a bundled line now.
        #expect(ShelfLines.soundsLike(title: "Pet Vet") == "We already have Pet Vet saved! Do you want to play that one, or make a new game?")
        #expect(CommonLines.all.contains(HandOffLines.end()))
        #expect(ShelfLines.newGameNote(playerCount: 3).contains("don't call confirm_plan"))
        for l in [ShelfLines.soundsLike(title: "Pet Vet"), ShelfLines.soundsLikeAgain, HandOffLines.end()] {
            #expect(Sanitizer.kidSafety(l) == nil, "\(l)")
        }
    }

    // MARK: The leave dialog

    @Test func leaveDialogBeforeAndAfterTheKit() {
        #expect(LeaveDialogMode.current(isReplay: false, savedAs: nil) == .beforeKit)
        #expect(LeaveDialogMode.current(isReplay: false, savedAs: UUID()) == .onShelf)
        #expect(LeaveDialogMode.current(isReplay: true, savedAs: nil) == .onShelf)
    }
}
