import Foundation
import Testing
import CloudKit
@testable import NutmegCore

// MARK: - A fake iCloud (no CloudKit, no network)

/// The private database's zone as the sync sees it: one record per game with a change tag, plus a change feed.
final class FakeCloud: @unchecked Sendable {
    struct Record { var tag: Int; var schema: Int; var modifiedAt: Date; var json: Data; var files: [String: Data] }
    var records: [UUID: Record] = [:]
    private(set) var feed: [(seq: Int, id: UUID)] = []
    private var seq = 0
    private var nextTag = 0
    /// Every outgoing game the devices sent (the privacy test reads them).
    var sent: [OutgoingGame] = []
    var jsonUploads = 0, fileUploads = 0

    func bump(_ id: UUID) { seq += 1; feed.append((seq, id)) }
    var cursor: Int { seq }

    func save(_ out: OutgoingGame) -> Int {
        nextTag += 1
        let files = out.files.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.name, try! Data(contentsOf: $0.url)) }) }
            ?? records[out.id]?.files ?? [:]   // left out = unchanged: the server keeps the last files
        records[out.id] = Record(tag: nextTag, schema: out.schemaVersion, modifiedAt: out.modifiedAt,
                                 json: try! Data(contentsOf: out.gameJSON), files: files)
        jsonUploads += 1
        fileUploads += out.files?.count ?? 0
        bump(out.id)
        return nextTag
    }

    func delete(_ id: UUID) { if records.removeValue(forKey: id) != nil { bump(id) } }

    /// The record as files on disk (CloudKit hands assets over as temporary files).
    func materialize(_ id: UUID, in dir: URL) -> IncomingGame? {
        guard let r = records[id] else { return nil }
        let base = dir.appendingPathComponent("dl-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let json = base.appendingPathComponent("game-asset")
        try! r.json.write(to: json)
        let files = r.files.keys.sorted().enumerated().map { i, name -> SyncFile in
            let u = base.appendingPathComponent("asset-\(i)"); try! r.files[name]!.write(to: u); return SyncFile(name: name, url: u)
        }
        return IncomingGame(id: id, schemaVersion: r.schema, modifiedAt: r.modifiedAt, gameJSON: json, files: files)
    }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var t: Double
    init(_ start: Double) { t = start }
    func advance(_ s: Double) { lock.withLock { t += s } }
    var now: Date { lock.withLock { Date(timeIntervalSince1970: t) } }
}

/// One device: its own store, ledger and pending queue, talking to the shared fake cloud like CKSyncEngine would.
final class FakeDevice: GameSyncTransport, @unchecked Sendable {
    let dir: URL
    let store: SavedGameStore
    var sync: GameSync
    let cloud: FakeCloud
    let clock: TestClock
    var pendingSaves: Set<UUID> = []
    var pendingDeletes: Set<UUID> = []
    var knownTags: [UUID: Int] = [:]
    var cursor = 0
    var remoteChanges = 0

    init(cloud: FakeCloud, clock: TestClock, dir: URL? = nil, attach: Bool = true) {
        self.cloud = cloud; self.clock = clock
        self.dir = dir ?? FileManager.default.temporaryDirectory.appendingPathComponent("pt-d4-\(UUID().uuidString)", isDirectory: true)
        store = SavedGameStore(root: self.dir.appendingPathComponent("SavedGames"))
        sync = GameSync(store: store, stateDirectory: self.dir.appendingPathComponent("SavedGamesSync"), clock: { [clock] in clock.now })
        if attach { connect() }
    }

    func connect() {
        sync.onRemoteChange = { [weak self] in self?.remoteChanges += 1 }
        sync.attach(self)
    }

    func enqueueSave(_ id: UUID) { pendingSaves.insert(id); pendingDeletes.remove(id) }
    func enqueueDelete(_ id: UUID) { pendingDeletes.insert(id); pendingSaves.remove(id) }

    /// Sends the queue (what CKSyncEngine's nextRecordZoneChangeBatch + sentRecordZoneChanges do).
    func push() {
        var loops = 0
        while (!pendingSaves.isEmpty || !pendingDeletes.isEmpty) && loops < 10 {
            loops += 1
            let saves = pendingSaves; pendingSaves = []
            for id in saves.sorted(by: { $0.uuidString < $1.uuidString }) {
                let staging = dir.appendingPathComponent("outbox/\(id.uuidString)")
                guard let out = sync.outgoing(id, staging: staging) else { continue }
                cloud.sent.append(out)
                if let server = cloud.records[id], knownTags[id] != server.tag {   // serverRecordChanged
                    knownTags[id] = server.tag
                    sync.conflict(server: cloud.materialize(id, in: dir)!)
                    continue
                }
                if cloud.records[id] == nil, knownTags[id] != nil {   // unknownItem: deleted elsewhere
                    knownTags[id] = nil
                    sync.remoteDeleted(id)
                    continue
                }
                knownTags[id] = cloud.save(out)
                sync.didSend(id)
            }
            let deletes = pendingDeletes; pendingDeletes = []
            for id in deletes { cloud.delete(id); knownTags[id] = nil; sync.didDelete(id) }
        }
    }

    /// Fetches the zone's changes since the last fetch (fetchedRecordZoneChanges).
    func pull() {
        var latest: [UUID] = []
        for e in cloud.feed where e.seq > cursor { latest.removeAll { $0 == e.id }; latest.append(e.id) }
        cursor = cloud.cursor
        for id in latest {
            if let r = cloud.records[id] {
                knownTags[id] = r.tag
                sync.incoming(cloud.materialize(id, in: dir)!)
            } else {
                knownTags[id] = nil
                sync.remoteDeleted(id)
            }
        }
    }

    func cleanup() { try? FileManager.default.removeItem(at: dir) }
}

// MARK: - Tests

/// Round D4: saved games sync through the family's own private iCloud (decisions/2026-11-17-icloud-sync-before-launch.md).
@MainActor
struct RoundD4CloudSyncTests {
    let a = Fallback.airplane

    func game(_ title: String = "Airplane to the Beach", created: Double = 1_800_000_000) -> SavedGame {
        SavedGame(createdAt: Date(timeIntervalSince1970: created), title: title, roles: a.plan.roles,
                  props: a.props.props.map(SavedProp.init), kit: a.kit, printStyle: .fullColor, art: [],
                  voiceID: VoiceConfig.nutmeg.voiceID)
    }
    let clip = SavedClip(key: "0123456789abcdef0123456789abcdef", text: "Pretend that the couch is a plane!", kind: "scene",
                         role: nil, duration: 1.5, file: "")

    func pair() -> (FakeCloud, TestClock, FakeDevice, FakeDevice) {
        let cloud = FakeCloud(); let clock = TestClock(1_800_000_000)
        return (cloud, clock, FakeDevice(cloud: cloud, clock: clock), FakeDevice(cloud: cloud, clock: clock))
    }

    // MARK: File names

    @Test func onlyTheSavedGameFilesMaySync() {
        for ok in ["game.json", "cover.jpg", "art/img_sign.heic", "art/ocut_badge_3.heic", "clips/0123abcd.aac"] {
            #expect(SyncFileName.isAllowed(ok), "\(ok)")
        }
        for bad in ["../game.json", "art/../../x.heic", "art/a/b.heic", "art/.heic", "art/x.jpg", "clips/x.heic",
                    "sync.json", "art/ünï.heic", "/etc/passwd", "art/x y.heic", "ledger.json", "chat.txt"] {
            #expect(!SyncFileName.isAllowed(bad), "\(bad)")
        }
    }

    // MARK: Two devices

    @Test func aGameMadeOnOneDeviceAppearsOnTheOther() throws {
        let (cloud, clock, ipad, iphone) = pair(); defer { ipad.cleanup(); iphone.cleanup() }
        let g = game()
        var withClip = g; withClip.clips = [clip]
        try ipad.store.save(withClip, art: ["img:sign": Data([1, 2, 3]), "cut:badge:0": Data([4])], cover: Data([9]),
                            clips: [clip.key: Data([7, 7])])
        #expect(ipad.pendingSaves == [g.id])
        ipad.push()
        #expect(cloud.records[g.id] != nil && ipad.sync.snapshotLedger.dirty.isEmpty)
        clock.advance(10)
        iphone.pull()
        let there = try #require(iphone.store.game(g.id))
        #expect(there.title == "Airplane to the Beach" && there.kit == g.kit && there.roles == g.roles && there.props == g.props)
        #expect(iphone.store.art(for: there) == ["img:sign": Data([1, 2, 3]), "cut:badge:0": Data([4])])
        #expect(iphone.store.cover(for: there) == Data([9]))
        #expect(there.clips.map(\.key) == [clip.key] && (try? Data(contentsOf: iphone.store.clipURL(clip, in: g.id))) == Data([7, 7]))
        #expect(iphone.store.list().map(\.id) == [g.id] && iphone.remoteChanges == 1)
        // A game that came down is not sent back up (no echo).
        #expect(iphone.pendingSaves.isEmpty)
        // The device that made it gets its own upload back from the fetch: nothing is rewritten.
        ipad.pull()
        #expect(ipad.remoteChanges == 0)
    }

    @Test func deletingOnOneDeviceDeletesEverywhere() throws {
        let (cloud, _, ipad, iphone) = pair(); defer { ipad.cleanup(); iphone.cleanup() }
        let g = game()
        try ipad.store.save(g, art: [:], cover: nil)
        ipad.push(); iphone.pull()
        #expect(iphone.store.exists(g.id))
        #expect(iphone.store.deleteGame(g.id))   // Grown-ups delete on the iPhone
        #expect(iphone.pendingDeletes == [g.id])
        iphone.push()
        #expect(cloud.records[g.id] == nil && iphone.sync.snapshotLedger.tombstones.isEmpty)
        ipad.pull()
        #expect(!ipad.store.exists(g.id) && ipad.store.list().isEmpty && ipad.remoteChanges == 1)
        #expect(ipad.pendingDeletes.isEmpty && ipad.pendingSaves.isEmpty)   // a remote delete isn't sent back
    }

    @Test func aDeleteBeatsAnEditOnTheOtherDevice() throws {
        let (cloud, clock, ipad, iphone) = pair(); defer { ipad.cleanup(); iphone.cleanup() }
        let g = game()
        try ipad.store.save(g, art: [:], cover: nil)
        ipad.push(); iphone.pull()
        // The iPad deletes it; meanwhile the iPhone replays it (a later stamp) before hearing about the delete.
        ipad.store.delete(g.id); ipad.push()
        clock.advance(60)
        iphone.store.touch(g.id)
        iphone.push()   // its record is gone on the server: unknownItem → the delete wins
        #expect(!iphone.store.exists(g.id) && cloud.records[g.id] == nil)
        // And an incoming copy never resurrects a game deleted here while its delete is still pending.
        let other = FakeDevice(cloud: cloud, clock: clock); defer { other.cleanup() }
        let h = game("Dino Dig")
        try ipad.store.save(h, art: [:], cover: nil); ipad.push()
        other.pull(); #expect(other.store.exists(h.id))
        other.store.delete(h.id)                       // not pushed yet
        clock.advance(5); ipad.store.touch(h.id); ipad.push()
        other.pull()                                   // the iPad's newer copy arrives
        #expect(!other.store.exists(h.id))
        other.push(); ipad.pull()
        #expect(!ipad.store.exists(h.id) && cloud.records[h.id] == nil)
    }

    @Test func theNewestSaveWinsWhenBothDevicesChangeAGame() throws {
        let (cloud, clock, ipad, iphone) = pair(); defer { ipad.cleanup(); iphone.cleanup() }
        let g = game()
        try ipad.store.save(g, art: ["img:sign": Data([1])], cover: nil)
        ipad.push(); iphone.pull()
        // Both change it offline: the iPad first, the iPhone a minute later (newer).
        var onIPad = g; onIPad.title = "Airplane to the Moon"
        ipad.store.update(onIPad, art: ["img:sign": Data([2])], keep: ["img:sign"], cover: nil)
        clock.advance(60)
        var onPhone = g; onPhone.title = "Airplane to the Jungle"
        iphone.store.update(onPhone, art: ["img:sign": Data([3])], keep: ["img:sign"], cover: nil)
        // The older edit reaches the server first; the newer one conflicts, wins and is resent.
        ipad.push()
        iphone.push()
        #expect(cloud.records[g.id].map { try! SavedGame.decode($0.json).title } == "Airplane to the Jungle")
        ipad.pull()
        #expect(ipad.store.game(g.id)?.title == "Airplane to the Jungle")
        #expect(ipad.store.art(for: ipad.store.game(g.id)!) == ["img:sign": Data([3])])
        // The other order: the newer edit lands first; the older one conflicts and takes the server's copy.
        var newer = g; newer.title = "Newer"
        var older = g; older.title = "Older"
        iphone.pull()
        iphone.store.update(older, art: [:], keep: ["img:sign"], cover: nil)   // older stamp
        clock.advance(60)
        ipad.store.update(newer, art: [:], keep: ["img:sign"], cover: nil)
        ipad.push(); iphone.push()
        #expect(iphone.store.game(g.id)?.title == "Newer" && cloud.records[g.id].map { try! SavedGame.decode($0.json).title } == "Newer")
        ipad.pull(); iphone.pull()
        #expect(ipad.store.game(g.id)?.title == "Newer" && iphone.store.game(g.id)?.title == "Newer")
    }

    @Test func aReplaySendsOnlyTheGameJSONAndKeepsThePictures() throws {
        let (cloud, clock, ipad, iphone) = pair(); defer { ipad.cleanup(); iphone.cleanup() }
        let g = game()
        try ipad.store.save(g, art: ["img:sign": Data(repeating: 5, count: 1000), "cut:badge:0": Data([4])], cover: Data([9]))
        ipad.push()
        #expect(cloud.fileUploads == 3)
        clock.advance(3600)
        ipad.store.touch(g.id, at: Date(timeIntervalSince1970: 1_800_000_000 + 3600))   // a replay: only "last played" changes
        ipad.push()
        #expect(cloud.sent.last?.files == nil && cloud.fileUploads == 3 && cloud.jsonUploads == 2)
        iphone.pull()
        let there = try #require(iphone.store.game(g.id))
        #expect(there.lastPlayedAt == Date(timeIntervalSince1970: 1_800_000_000 + 3600))
        #expect(iphone.store.art(for: there).count == 2 && iphone.store.cover(for: there) == Data([9]))
        // A new picture changes the file set: the files go up again.
        ipad.store.update(g, art: ["img:map": Data([8])], keep: ["img:sign", "cut:badge:0", "img:map"], cover: nil)
        ipad.push()
        #expect(cloud.sent.last?.files?.map(\.name) == ["art/cut_badge_0.heic", "art/img_map.heic", "art/img_sign.heic", "cover.jpg"])
    }

    @Test func aRecordedLineAddedLaterSyncs() throws {
        let (_, _, ipad, iphone) = pair(); defer { ipad.cleanup(); iphone.cleanup() }
        let g = game()
        try ipad.store.save(g, art: [:], cover: nil)
        ipad.push(); iphone.pull()
        #expect(ipad.store.addClip(clip, data: Data([1, 2]), to: g.id))
        ipad.push(); iphone.pull()
        #expect(iphone.store.game(g.id)?.clips.map(\.key) == [clip.key])
    }

    // MARK: Signed out / iCloud later

    @Test func signedOutWorksOnDeviceAndUploadsWhenICloudArrives() throws {
        let cloud = FakeCloud(); let clock = TestClock(1_800_000_000)
        let ipad = FakeDevice(cloud: cloud, clock: clock, attach: false); defer { ipad.cleanup() }
        // No iCloud: saving, the shelf, replays and deletes work exactly as before; nothing is queued.
        let g = game(), h = game("Dino Dig", created: 1_800_000_100)
        try ipad.store.save(g, art: ["img:sign": Data([1])], cover: Data([2]))
        try ipad.store.save(h, art: [:], cover: nil)
        ipad.store.touch(g.id)
        #expect(ipad.store.list().count == 2 && ipad.pendingSaves.isEmpty && cloud.records.isEmpty)
        // iCloud becomes available: every local game goes up.
        ipad.connect(); ipad.sync.resume()
        #expect(ipad.pendingSaves == [g.id, h.id] && ipad.sync.snapshotLedger.seeded)
        ipad.push()
        #expect(Set(cloud.records.keys) == [g.id, h.id])
        let iphone = FakeDevice(cloud: cloud, clock: clock); defer { iphone.cleanup() }
        iphone.pull()
        #expect(Set(iphone.store.list().map(\.id)) == [g.id, h.id])
        // Signing out keeps every local game.
        ipad.sync.accountReset(); ipad.sync.detach()
        #expect(ipad.store.list().count == 2 && !ipad.sync.snapshotLedger.seeded)
        try ipad.store.save(game("Space Picnic"), art: [:], cover: nil)
        #expect(ipad.store.list().count == 3)
    }

    @Test func pendingWorkSurvivesARelaunch() throws {
        let cloud = FakeCloud(); let clock = TestClock(1_800_000_000)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pt-d4-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = FakeDevice(cloud: cloud, clock: clock, dir: dir)
        first.sync.seedAll()
        let g = game(), h = game("Dino Dig")
        try first.store.save(g, art: [:], cover: nil)
        try first.store.save(h, art: [:], cover: nil); first.push()
        try first.store.save(g, art: ["img:sign": Data([1])], cover: nil)   // changed, not sent
        first.store.delete(h.id)                                             // deleted, not sent
        // Relaunch: a new GameSync reads the ledger and queues both again.
        let again = FakeDevice(cloud: cloud, clock: clock, dir: dir)
        again.knownTags = first.knownTags
        again.sync.resume()
        #expect(again.pendingSaves == [g.id] && again.pendingDeletes == [h.id])
        again.push()
        #expect(cloud.records[h.id] == nil && cloud.records[g.id]?.files.keys.sorted() == ["art/img_sign.heic"])
    }

    // MARK: Schema and safety

    @Test func aGameFromANewerAppVersionWaitsOnDiskAndIsNeverReuploaded() throws {
        let (cloud, _, ipad, iphone) = pair(); defer { ipad.cleanup(); iphone.cleanup() }
        let g = game()
        try ipad.store.save(g, art: [:], cover: nil); ipad.push()
        var obj = try JSONSerialization.jsonObject(with: cloud.records[g.id]!.json) as! [String: Any]
        obj["schemaVersion"] = 99
        cloud.records[g.id]!.json = try JSONSerialization.data(withJSONObject: obj)
        cloud.records[g.id]!.schema = 99
        cloud.bump(g.id)
        iphone.pull()
        #expect(iphone.store.exists(g.id) && iphone.store.list().isEmpty)   // kept, skipped by the shelf (as before)
        #expect(iphone.pendingSaves.isEmpty)
    }

    @Test func aBrokenOrForeignRecordIsRejected() throws {
        let (cloud, _, ipad, iphone) = pair(); defer { ipad.cleanup(); iphone.cleanup() }
        let g = game(), other = UUID()
        try ipad.store.save(g, art: [:], cover: nil); ipad.push()
        // A record whose game.json names a different game is never written.
        cloud.records[other] = cloud.records[g.id]; cloud.bump(other)
        // And a file name outside the allowed set is dropped.
        cloud.records[g.id]!.files["../../evil.heic"] = Data([6])
        cloud.records[g.id]!.files["art/ok.heic"] = Data([7])
        cloud.bump(g.id)
        iphone.pull()
        #expect(!iphone.store.exists(other))
        let files = SavedGameStore.relativeFiles(in: iphone.store.root.appendingPathComponent(g.id.uuidString))
        #expect(files == ["art/ok.heic", "game.json"])
        #expect(!FileManager.default.fileExists(atPath: iphone.store.root.deletingLastPathComponent().appendingPathComponent("evil.heic").path))
    }

    // MARK: The CloudKit record

    @Test func theRecordMappingRoundTrips() throws {
        let (_, _, ipad, _) = pair(); defer { ipad.cleanup() }
        let g = game()
        try ipad.store.save(g, art: ["img:sign": Data([1])], cover: Data([2]))
        let out = try #require(ipad.sync.outgoing(g.id, staging: ipad.dir.appendingPathComponent("stage")))
        let record = GameRecordMapper.newRecord(g.id)
        GameRecordMapper.fill(record, with: out)
        #expect(record.recordType == "SavedGame" && record.recordID.recordName == g.id.uuidString)
        #expect(record.recordID.zoneID.zoneName == "SavedGames")
        #expect(Set(record.allKeys()) == GameRecordMapper.allFields)
        let back = try #require(GameRecordMapper.incoming(record))
        #expect(back.id == g.id && back.modifiedAt == out.modifiedAt && back.schemaVersion == SavedGame.currentSchema)
        #expect(back.gameJSON == out.gameJSON && back.files == out.files)
        // Unchanged files are left out of the record (the server keeps them).
        ipad.sync.didSend(g.id)
        ipad.store.touch(g.id)
        let touched = try #require(ipad.sync.outgoing(g.id, staging: ipad.dir.appendingPathComponent("stage2")))
        let fields = try #require(GameRecordMapper.record(systemFields: GameRecordMapper.systemFields(record)))
        #expect(fields.allKeys().isEmpty && fields.recordID == record.recordID)
        GameRecordMapper.fill(fields, with: touched)
        #expect(Set(fields.changedKeys()) == ["schemaVersion", "modifiedAt", "game"])
        // Someone else's record (another type or zone) is ignored.
        #expect(GameRecordMapper.incoming(CKRecord(recordType: "Other", recordID: record.recordID)) == nil)
        #expect(GameRecordMapper.gameID(CKRecord.ID(recordName: g.id.uuidString)) == nil)
    }

    // MARK: Privacy (CLAUDE.md rule 6): what goes to iCloud is game content only

    @Test func whatIsSentToICloudIsGameContentOnly() async throws {
        let llm = FakeLLM()
        let adventure = AdventureStore(service: PhaseService(llm: llm))
        adventure.beginConversation()
        _ = await adventure.apply(.setGame("Airplane")); _ = await adventure.apply(.setTheme("Airplane to the Beach"))
        _ = await adventure.apply(.setPlayerCount(4)); _ = await adventure.confirmYes()
        _ = await adventure.apply(.setRoles(a.plan.roles.map { .init(roleName: $0.roleName, job: $0.job) }))
        _ = await adventure.apply(.showNextProp(.init(itemID: "plate", becomes: "the steering wheel", forRole: "Captain", alternates: ["paper-plate"], reason: "A plate is round like a wheel!")))
        _ = await adventure.apply(.markFound("plate"))
        _ = await adventure.apply(.finishPlanning)
        for _ in 0..<400 where adventure.phase != .kitReady || adventure.guidePending { try? await Task.sleep(for: .milliseconds(10)) }
        let kidText = "My name is Zelda Quokkabottom and I live on Maple Street"
        await adventure.kidSaid(kidText)
        #expect(adventure.playerCount == 4 && !adventure.nutmegLine.isEmpty)
        var saved = try #require(adventure.savedGame(art: [], cover: nil))
        saved.clips = [clip]

        let (cloud, _, ipad, _) = pair(); defer { ipad.cleanup() }
        try ipad.store.save(saved, art: ["img:sign": Data([1, 2])], cover: Data([3]), clips: [clip.key: Data([4])])
        ipad.push()
        let out = try #require(cloud.sent.last)
        // The record: exactly the mapper's fields.
        let record = GameRecordMapper.newRecord(saved.id)
        GameRecordMapper.fill(record, with: out)
        #expect(Set(record.allKeys()).isSubset(of: GameRecordMapper.allFields))
        // The files: only the saved game's own files.
        let names = (out.files ?? []).map(\.name)
        #expect(names.allSatisfy(SyncFileName.isAllowed) && names == ["art/img_sign.heic", "clips/\(clip.key).aac", "cover.jpg"])
        // game.json: the D1 key set, no count, chat, kid text or her chat line.
        let data = try Data(contentsOf: out.gameJSON)
        let top = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(Set(top.keys).isSubset(of: SavedGame.allowedKeys))
        let json = String(decoding: data, as: UTF8.self)
        for key in ["playerCount", "players", "kids", "transcript", "chat", "kidSaid", "kidText", "nutmegLine", "audio",
                    "name", "names", "moderation", "safety", "device", "deviceID", "timing"] {
            #expect(!json.contains("\"\(key)\""), "synced JSON has key \(key)")
        }
        // No byte of anything sent, nor the sync's own ledger, holds the kid's words or her chat line.
        var everything = [data] + (out.files ?? []).map { try! Data(contentsOf: $0.url) }
        everything.append(try Data(contentsOf: ipad.sync.stateDirectory.appendingPathComponent("ledger.json")))
        for blob in everything {
            let s = String(decoding: blob, as: UTF8.self)
            #expect(!s.contains("Zelda") && !s.contains("Maple") && !s.contains(adventure.nutmegLine))
        }
    }
}

/// Round D4: Grown-ups → About what we save says saved games sync through the family's own iCloud.
struct RoundD4CopyTests {
    @Test func aboutSaysGamesSyncThroughTheFamilysICloud() {
        let about = GrownUpsCopy.about.map { $0.title + " " + $0.body }.joined(separator: " ")
        #expect(about.contains("your family's own private iCloud") && about.contains("We don't have servers"))
        #expect(about.contains("removed from your other devices too"))
        #expect(GrownUpsCopy.savedGamesFooter.contains("family's iCloud"))
    }
}
