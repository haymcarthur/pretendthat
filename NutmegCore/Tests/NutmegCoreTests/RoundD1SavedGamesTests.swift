import Foundation
import Testing
@testable import NutmegCore

/// Round D1 (saved games on this iPad + the replay flow, design 2026-11-15 §D1–D5 with Haylee's answers).
@MainActor
struct RoundD1SavedGamesTests {
    let a = Fallback.airplane

    /// A saved airplane game (printer, 6 ranked roles, the bundled play guide), as if saved at The End.
    func fixture(created: Date = Date(timeIntervalSince1970: 1_800_000_000), pretend: Set<String> = []) -> SavedGame {
        let props = a.props.props.map { p -> SavedProp in
            var s = SavedProp(p); s.pretendOnFirstPlay = pretend.contains(p.id)
            if p.id == "plate" { s.alternates = ["bowl"] }
            return s
        }
        return SavedGame(createdAt: created, title: "Airplane to the Beach", roles: a.plan.roles, props: props, kit: a.kit,
                         printStyle: .colorIn, art: [], voiceID: VoiceConfig.nutmeg.voiceID)
    }

    func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pt-saved-\(UUID().uuidString)", isDirectory: true)
    }

    // MARK: The model

    @Test func savedGameRoundTripsAndV1Decodes() throws {
        let g = fixture()
        let data = try SavedGame.encoder().encode(g)
        let back = try SavedGame.decode(data)
        #expect(back == g)
        #expect(back.schemaVersion == 1 && back.roles.count == 6 && back.kit.scenes.count == g.kit.scenes.count)
        #expect(g.voiceID == "coral@gpt-realtime-2.1")
        // A newer schema than this build knows is refused (never half-read).
        var future = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        future["schemaVersion"] = 99
        #expect(throws: (any Error).self) { try SavedGame.decode(try JSONSerialization.data(withJSONObject: future)) }
    }

    @Test func artKeysParseAndMakeSafeFileNames() {
        #expect(ArtKey.parse(ArtKey.image("sign"))?.itemID == "sign" && ArtKey.parse("img:sign")?.index == nil)
        #expect(ArtKey.parse("cut:badge:3")?.itemID == "badge" && ArtKey.parse("cut:badge:3")?.index == 3)
        #expect(ArtKey.parse("img:")  == nil && ArtKey.parse("cut:x:y") == nil && ArtKey.parse("nope") == nil)
        #expect(ArtKey.fileName("cut:badge:3") == "cut_badge_3.heic")
        #expect(ArtKey.fileName("img:../../etc") == "img_______etc.heic")
    }

    // MARK: The local store

    @Test func localStoreSavesListsNewestFirstAndKeepsArt() throws {
        let root = tempRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SavedGameStore(root: root)
        #expect(store.list().isEmpty && store.count == 0)
        let old = fixture(created: Date(timeIntervalSince1970: 1_800_000_000))
        var new = fixture(created: Date(timeIntervalSince1970: 1_800_000_500)); new.title = "Pirates on the Moon"
        try store.save(old, art: [ArtKey.image("sign"): Data([1, 2, 3])], cover: Data([9]))
        try store.save(new, art: [ArtKey.cutout("badge", 0): Data([4])], cover: nil)
        // A half-written folder is never listed.
        try FileManager.default.createDirectory(at: root.appendingPathComponent(UUID().uuidString + ".tmp"), withIntermediateDirectories: true)
        let list = store.list()
        #expect(list.map(\.title) == ["Pirates on the Moon", "Airplane to the Beach"])
        #expect(list[1].art == ["img:sign"] && list[1].cover == "cover.jpg" && list[0].cover == nil)
        #expect(store.art(for: list[1]) == ["img:sign": Data([1, 2, 3])])
        #expect(store.cover(for: list[1]) == Data([9]) && store.cover(for: list[0]) == nil)
        #expect(store.size(of: old.id) > 0)
        // A replay only moves lastPlayedAt; the content stays.
        store.touch(old.id, at: Date(timeIntervalSince1970: 1_900_000_000))
        let touched = store.game(old.id)!
        #expect(touched.lastPlayedAt == Date(timeIntervalSince1970: 1_900_000_000) && touched.kit == old.kit && touched.title == old.title)
        store.delete(new.id)
        #expect(store.list().map(\.id) == [old.id])
    }

    // MARK: Privacy (CLAUDE.md rule 6: never anything about kids)

    @Test func savedGameHoldsOnlyGameContentNeverAnythingAboutKids() async throws {
        let llm = FakeLLM()
        let store = AdventureStore(service: PhaseService(llm: llm))
        store.beginConversation()
        _ = await store.apply(.setGame("Airplane")); _ = await store.apply(.setTheme("Airplane to the Beach"))
        _ = await store.apply(.setPlayerCount(4)); _ = await store.confirmYes(); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles(a.plan.roles.map { .init(roleName: $0.roleName, job: $0.job) }))
        _ = await store.apply(.showNextProp(.init(itemID: "plate", becomes: "the steering wheel", forRole: "Captain", alternates: ["bowl"], reason: "A plate is round like a wheel!")))
        _ = await store.apply(.markFound("plate"))
        _ = await store.apply(.finishPlanning)
        for _ in 0..<400 where store.phase != .kitReady || store.guidePending { try? await Task.sleep(for: .milliseconds(10)) }
        // Kid text and her chat line are in memory (a typed turn that went through the tap path), plus the count.
        let kidText = "My name is Zelda Quokkabottom and I live on Maple Street"
        await store.kidSaid(kidText)
        #expect(store.playerCount == 4 && !store.nutmegLine.isEmpty)
        let game = try #require(store.savedGame(art: [ArtKey.image("sign")], cover: "cover.jpg"))
        let data = try SavedGame.encoder().encode(game)
        let json = String(decoding: data, as: UTF8.self)
        let top = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // Exactly the design's fields (a new field is a decision, not an accident).
        #expect(Set(top.keys).isSubset(of: SavedGame.allowedKeys))
        // Never: the count, a transcript or chat, kid text or audio, names, moderation, device ids, timing.
        for key in ["playerCount", "players", "kids", "transcript", "chat", "kidSaid", "kidText", "nutmegLine", "audio",
                    "name", "names", "moderation", "safety", "device", "deviceID", "timing", "foundProps", "checkedSteps"] {
            #expect(!json.contains("\"\(key)\""), "saved JSON has key \(key)")
        }
        #expect(!json.contains("Zelda") && !json.contains("Maple"))
        #expect(!json.contains(store.nutmegLine))   // her chat line is never kept
        // What IS kept: the game content.
        #expect(game.title == "Airplane to the Beach" && game.roles.count == 6 && game.props.map(\.id) == ["plate"])
        #expect(game.props[0].reason == "A plate is round like a wheel!" && game.props[0].alternates == ["bowl"])
        #expect(game.kit == store.fullKit && game.printStyle == .colorIn && game.clips.isEmpty)
    }

    // MARK: Save at The End

    @Test func onlyAFinishedFirstPlayCanBeSavedOnce() async {
        let store = AdventureStore(service: nil)
        #expect(!store.canSave)
        store.loadReplay(fixture())
        store.replayPick(2); store.replayPickDone(); store.replayPropsDone(); store.replayPaper(.skip)
        store.autoCheckStep = .zero; store.autoCheckHold = .zero
        await finishPlay(store)
        #expect(store.phase == .end && !store.canSave)   // a replay is already saved
        // A first play (bundled game) at The End: saveable, once.
        let first = AdventureStore(service: nil)
        await first.start(); await first.chooseGame("Airplane"); first.setPlayerCount(2)
        await first.confirmPlayers(); await first.confirmRoles(); await first.confirmProps()
        first.autoCheckStep = .zero; first.autoCheckHold = .zero
        first.beginPlay(); await finishPlay(first)
        #expect(first.phase == .end && first.canSave)
        first.markSaved(UUID())
        #expect(!first.canSave)
        first.newGame()
        #expect(first.savedAs == nil && !first.isReplay)
    }

    func finishPlay(_ store: AdventureStore) async {
        for _ in 0..<40 {
            switch store.phase {
            case .handoff(let i): if let r = store.kit?.scenes[i].owner.role { store.badgeTapped(r) }
            case .scene: await store.sceneDone()
            default: return
            }
        }
    }

    // MARK: The replay flow (no AI calls)

    @Test func replayRunsPickPropsPaperPlayWithNoAICalls() async {
        let llm = FakeLLM()
        let store = AdventureStore(service: PhaseService(llm: llm))
        let ledger = CountingLedger(); store.ledger = ledger
        let g = fixture()
        store.loadReplay(g)
        #expect(store.isReplay && store.phase == .players && store.playerCount == 0 && store.phase.step == .game)
        #expect(store.nutmegLine == "Airplane to the Beach! How many friends are playing this time?")
        #expect(store.reachedStep == .game && store.currentTitle == "Airplane to the Beach")
        #expect(ledger.replays == [g.id] && ledger.newGames.isEmpty)
        // Pick: counts 1 → 6 → 2, no call; the checklists follow the count.
        for n in [1, 6, 2] {
            store.replayPick(n)
            #expect(store.playerCount == n && store.phase == .players)
            #expect(store.kit?.scenes.allSatisfy { $0.steps.compactMap(\.role.role).count == n } == true)
        }
        #expect(store.nutmegLine == "Two friends! Our crew is a Captain and a Flight Attendant!")
        // Voice works too (set_player_count), and nothing about the game can change.
        let voice = await store.apply(.setPlayerCount(3))
        #expect(store.playerCount == 3 && voice.contains("Nothing is remade"))
        let theme = await store.apply(.setTheme("Pirates instead"))
        #expect(theme == ReplayLines.savedGameOutput && store.currentTitle == "Airplane to the Beach")
        #expect(await store.apply(.finishPlanning) == ReplayLines.savedGameOutput && store.phase == .players)
        // Props: the whole list at once, all Got it.
        store.replayPickDone()
        #expect(store.phase == .props && store.foundProps.count == g.props.count)
        #expect(store.nutmegLine.hasPrefix("Do you still have these? A chair for the Airplane seats"))
        // Don't have it → a pretend swap (no call): its steps say "pretend".
        store.replayProp("plate", have: false)
        #expect(store.nutmegLine == "No problem, we'll pretend the steering wheel!" && store.props?.props.first { $0.id == "plate" }?.isSkipped == true)
        #expect(store.fullKit?.scenes[0].steps[0].text == "Captain, hold the pretend Steering wheel")
        // The saved alternate in one tap.
        #expect(store.replayAlternate(for: "plate") == "bowl")
        store.replayUseAlternate("plate")
        let plate = store.props?.props.first { $0.id == "plate" }
        #expect(plate?.libraryID == "bowl" && plate?.isSkipped == false && store.foundProps.contains("plate"))
        #expect(store.fullKit?.scenes[0].steps[0].text == "Captain, hold the steering wheel" || store.fullKit?.scenes[0].steps[0].text == "Captain, hold the Steering wheel")
        // Paper: the choices; just the badges = only badge pages for the count.
        store.replayPropsDone()
        #expect(store.phase == .kitReady && store.nutmegLine == ReplayLines.paperQuestion)
        store.replayPaper(.badges)
        #expect(store.replayPrinted == .badges && store.phase == .kitReady)
        let pages = KitLayout.pages(for: store.kit!, roles: store.plan!.roles, playerCount: store.playerCount)
        let badges = ReplayProps.pages(pages, for: .badges)
        #expect(!badges.isEmpty && badges.allSatisfy { $0.item.recipe == .badges } && badges.flatMap(\.slots).count == 3)
        #expect(ReplayProps.pages(pages, for: .everything) == pages && ReplayProps.pages(pages, for: .skip).isEmpty)
        // Play: the saved scenes, hand-offs rotating through the 3 playing roles.
        store.beginPlay()
        #expect(store.phase == .handoff(sceneIndex: 0))   // the first holder (R1) gets the iPad
        store.autoCheckStep = .zero; store.autoCheckHold = .zero
        await finishPlay(store)
        #expect(store.phase == .end)
        // Back to Pick on the rail, a new count: still no call.
        #expect(store.goTo(.game) && store.phase == .players)
        store.replayPick(5)
        #expect(store.kit?.scenes.allSatisfy { $0.steps.compactMap(\.role.role).count == 5 } == true)
        #expect(llm.calls == 0)
        #expect(ledger.newGames.isEmpty && ledger.replays == [g.id])
    }

    @Test func aFirstPlayPretendPropIsRealAgainWhenTheKidsHaveIt() {
        // The saved guide said "pretend" for the plate (skipped on the first play, with its cut-out picture).
        var g = fixture(pretend: ["plate"])
        var k = g.kit
        k.scenes[0].steps[0].text = "Captain, hold the pretend Steering wheel"
        k.scenes[0].steps[0].picture = .kit("cutout:2")
        g.kit = k
        let store = AdventureStore(service: nil)
        store.loadReplay(g)
        #expect(store.fullKit?.scenes[0].steps[0].text == "Captain, hold the Steering wheel")
        #expect(store.fullKit?.scenes[0].steps[0].picture == .prop("plate"))
        store.replayPick(1); store.replayPickDone()
        store.replayProp("plate", have: false)
        #expect(store.fullKit?.scenes[0].steps[0].text.contains("pretend") == true)
    }

    @Test func replayNoteIsASystemNoteWithTheSavedGame() {
        let note = ReplayLines.note(title: "Airplane", roles: a.plan.roles, players: 2, props: a.props.props, step: .getReady,
                                    scenes: a.kit.scenes.map(\.title))
        #expect(note.contains("REPLAY") && note.contains("playing now: Captain, Flight Attendant") && note.contains("Current step: Props"))
        #expect(note.contains(ReplayLines.savedGame))
        #expect(ReplayLines.stillHave([]).contains("All set"))
    }

    // MARK: The GameLedger hook (section E later)

    @Test func ledgerCountsANewGameOnceAtTheConfirmYesAndNeverAReplay() async {
        let store = AdventureStore(service: PhaseService(llm: FakeLLM()))
        let ledger = CountingLedger(); store.ledger = ledger
        store.beginConversation()
        _ = await store.apply(.setGame("Airplane")); _ = await store.apply(.setTheme("Airplane to the Beach"))
        _ = await store.apply(.setPlayerCount(2))
        #expect(ledger.newGames.isEmpty)
        _ = await store.apply(.confirmPlan)
        #expect(ledger.newGames == [store.gameID])
        // A correction re-opens the recap; the second yes is the same game.
        _ = await store.apply(.setPlayerCount(3)); _ = await store.apply(.confirmPlan)
        #expect(ledger.newGames.count == 1)
        store.loadReplay(fixture())
        #expect(ledger.newGames.count == 1 && ledger.replays.count == 1)
        #expect(NoOpLedger() is GameLedger)
    }
}

@MainActor
final class CountingLedger: GameLedger {
    var newGames: [UUID] = [], replays: [UUID] = [], paid: [PaidAICall] = []
    func newGameStarted(id: UUID) { newGames.append(id) }
    func replayStarted(id: UUID) { replays.append(id) }
    func paidAICall(kind: PaidAICall) { paid.append(kind) }
}

@Test func replayToolsAreTheExistingSessionToolsByStep() {
    #expect(ReplayLines.tools(.players) == ["set_player_count", "go_to_step", "just_talk"])
    #expect(ReplayLines.tools(.props) == ["go_to_step", "just_talk"])
    #expect(ReplayLines.tools(.kitReady) == Realtime.afterHuntTools(.kitReady))
    let names = Set(Realtime.tools.compactMap { $0["name"] as? String })
    for phase in [Phase.players, .props, .kitReady, .handoff(sceneIndex: 0), .scene(0), .end] {
        #expect(Set(ReplayLines.tools(phase) ?? []).isSubset(of: names))
    }
}
