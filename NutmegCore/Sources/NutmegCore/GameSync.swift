import Foundation
import CryptoKit

// Round D4 (decisions/2026-11-17-icloud-sync-before-launch.md): saved games sync through the family's own private
// iCloud (CloudKit private database, CKSyncEngine in the app). The files on this device stay the source of truth for
// playing; sync only mirrors them. This file is the CloudKit-free part: which files of a saved game are sent, the
// last-writer-wins merge, deletes, and the bookkeeping (`GameSyncLedger`). The app's CKSyncEngine delegate
// (PretendThat/App/CloudSync.swift) only moves records; `GameRecordMapper` turns them into CKRecords.
//
// What is sent is exactly the saved game's folder: game.json (the privacy-tested `SavedGame`, game content only),
// art/*.heic, cover.jpg and clips/*.aac (Nutmeg's own recorded lines). Nothing about kids, no device ids, no counts.
// Merge rule (Claude's call): the newest save wins for the whole game (games are rarely edited after their first
// play); a delete on any device deletes everywhere and beats an edit.

// MARK: - The files of a saved game

/// The only file names a synced game may have (relative to its folder). Anything else is never sent and never written.
public enum SyncFileName {
    public static let gameJSON = "game.json"
    public static let cover = "cover.jpg"

    public static func isAllowed(_ name: String) -> Bool {
        if name == gameJSON || name == cover { return true }
        let parts = name.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { return false }
        let (dir, file) = (parts[0], parts[1])
        let ext = dir == "art" ? ".heic" : dir == "clips" ? ".aac" : nil
        guard let ext, file.hasSuffix(ext) else { return false }
        let stem = file.dropLast(ext.count)
        return !stem.isEmpty && stem.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
            && stem.unicodeScalars.allSatisfy(\.isASCII)
    }
}

/// One file of a synced game: its name in the folder and where its bytes are now.
public struct SyncFile: Equatable, Sendable {
    public let name: String
    public let url: URL
    public init(name: String, url: URL) { self.name = name; self.url = url }
}

/// A game as it goes up: game.json always; the other files only when they changed since the last upload
/// (`files == nil`: the server keeps the files it has, so a replay's new "last played" sends only game.json).
public struct OutgoingGame: Equatable, Sendable {
    public let id: UUID
    public let schemaVersion: Int
    /// The last-writer-wins stamp: when this device last changed the game.
    public let modifiedAt: Date
    public let gameJSON: URL
    public let files: [SyncFile]?
}

/// A game as it comes down from iCloud (the files are wherever the backend put them; they are copied in at once).
public struct IncomingGame: Equatable, Sendable {
    public let id: UUID
    public let schemaVersion: Int
    public let modifiedAt: Date
    public let gameJSON: URL
    public let files: [SyncFile]
    public init(id: UUID, schemaVersion: Int, modifiedAt: Date, gameJSON: URL, files: [SyncFile]) {
        self.id = id; self.schemaVersion = schemaVersion; self.modifiedAt = modifiedAt; self.gameJSON = gameJSON; self.files = files
    }
}

/// Where the sync sends its record changes (the app's CKSyncEngine, or a fake cloud in the tests).
public protocol GameSyncTransport: AnyObject, Sendable {
    func enqueueSave(_ id: UUID)
    func enqueueDelete(_ id: UUID)
}

// MARK: - The local store's sync hooks

public enum SavedGameChange: Equatable, Sendable { case saved, deleted }

extension SavedGameStore {
    /// The IDs of every game folder on disk (finished ones only; a newer-schema game counts too).
    public func folderIDs() -> [UUID] {
        withStoreLock {
            ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
                .filter { !$0.lastPathComponent.hasSuffix(".tmp") }
                .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent(SyncFileName.gameJSON).path) }
                .compactMap { UUID(uuidString: $0.lastPathComponent) }
        }
    }

    public func exists(_ id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: folder(id).appendingPathComponent(SyncFileName.gameJSON).path)
    }

    /// Copies a game's files (the allowed names only) into `dir`, read under the store's lock so the set is consistent.
    /// Returns name → copy, or nil when the game isn't on disk.
    public func snapshot(_ id: UUID, into dir: URL) -> [String: URL]? {
        withStoreLock {
            let fm = FileManager.default
            let src = folder(id)
            guard fm.fileExists(atPath: src.appendingPathComponent(SyncFileName.gameJSON).path) else { return nil }
            try? fm.removeItem(at: dir)
            var out: [String: URL] = [:]
            for name in Self.relativeFiles(in: src) where SyncFileName.isAllowed(name) {
                let to = dir.appendingPathComponent(name)
                do {
                    try fm.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.copyItem(at: src.appendingPathComponent(name), to: to)
                    out[name] = to
                } catch { return nil }
            }
            return out[SyncFileName.gameJSON] == nil ? nil : out
        }
    }

    static func relativeFiles(in dir: URL) -> [String] {
        let fm = FileManager.default
        var names: [String] = []
        for top in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.appendingPathComponent(top).path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                for f in (try? fm.contentsOfDirectory(atPath: dir.appendingPathComponent(top).path)) ?? [] { names.append(top + "/" + f) }
            } else {
                names.append(top)
            }
        }
        return names.sorted()
    }

    /// A game from iCloud replaces the local folder (atomically, like `save`). Only allowed names are written; the
    /// game.json must be a JSON object with this id. A newer schema than this build reads is still written (the shelf
    /// skips it until the app is updated). Does NOT tell the sync (it came from the sync).
    public func applyRemote(id: UUID, files: [SyncFile]) throws {
        guard let json = files.first(where: { $0.name == SyncFileName.gameJSON }),
              let data = try? Data(contentsOf: json.url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (obj["id"] as? String).flatMap(UUID.init(uuidString:)) == id else { throw CocoaError(.coderReadCorrupt) }
        try withStoreLock {
            let fm = FileManager.default
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let tmp = root.appendingPathComponent(id.uuidString + ".tmp", isDirectory: true)
            try? fm.removeItem(at: tmp)
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
            for f in files where SyncFileName.isAllowed(f.name) {
                let to = tmp.appendingPathComponent(f.name)
                try fm.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                try writeFile(try Data(contentsOf: f.url), to: to)
            }
            let dest = folder(id)
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.moveItem(at: tmp, to: dest)
        }
    }

    /// A game deleted on another device: its folder goes (does NOT tell the sync).
    public func removeRemote(_ id: UUID) {
        withStoreLock { try? FileManager.default.removeItem(at: folder(id)) }
    }
}

// MARK: - The ledger (sync bookkeeping, on this device)

/// What the sync remembers between launches: game ids, stamps and file hashes only (never game content, never
/// anything about kids). Application Support/SavedGamesSync/ledger.json.
public struct GameSyncLedger: Codable, Equatable, Sendable {
    /// When this device last changed (or received) each game: the last-writer-wins stamp.
    public var stamps: [UUID: Date] = [:]
    /// Games changed here and not yet confirmed uploaded.
    public var dirty: Set<UUID> = []
    /// Games deleted here whose delete isn't confirmed yet (an incoming copy never brings them back).
    public var tombstones: Set<UUID> = []
    /// The non-JSON files (name → SHA-256) last confirmed on the server, so unchanged pictures aren't re-sent.
    public var uploaded: [UUID: [String: String]] = [:]
    /// The local games were queued for upload for the current iCloud account.
    public var seeded = false
    public init() {}
}

// MARK: - The sync logic

/// The CloudKit-free sync of the saved-game store: what goes up, what comes down, and who wins.
public final class GameSync: @unchecked Sendable {
    public enum IncomingResult: Equatable, Sendable { case applied, unchanged, keptLocal, ignoredDeleted, rejected }
    public enum ConflictResult: Equatable, Sendable { case resend, tookServer, ignoredDeleted }

    public let store: SavedGameStore
    public let stateDirectory: URL
    private let clock: @Sendable () -> Date
    private let lock = NSLock()
    private var ledger: GameSyncLedger
    private weak var transport: (any GameSyncTransport)?
    /// Bumped on every local change (memory only), so a change made while an upload is in flight is sent again.
    private var generation: [UUID: Int] = [:]
    private var inFlight: [UUID: (manifest: [String: String], generation: Int)] = [:]
    /// A game came down or was deleted elsewhere: the shelf should re-read the store (called off the main thread).
    public var onRemoteChange: (@Sendable () -> Void)?

    public init(store: SavedGameStore, stateDirectory: URL, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.stateDirectory = stateDirectory
        self.clock = clock
        let url = stateDirectory.appendingPathComponent("ledger.json")
        ledger = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(GameSyncLedger.self, from: $0) } ?? GameSyncLedger()
    }

    /// Application Support/SavedGamesSync (beside SavedGames, never inside it).
    public static func defaultStateDirectory() -> URL {
        SavedGameStore.defaultRoot().deletingLastPathComponent().appendingPathComponent("SavedGamesSync", isDirectory: true)
    }

    public var snapshotLedger: GameSyncLedger { lock.withLock { ledger } }

    /// Connects the transport and starts listening to the store. Local changes made while no transport is attached
    /// (signed out of iCloud) are not recorded: when iCloud becomes available, `seedAll` uploads every local game.
    public func attach(_ transport: any GameSyncTransport) {
        lock.withLock { self.transport = transport }
        store.onLocalChange = { [weak self] id, change in
            switch change {
            case .saved: self?.localChanged(id)
            case .deleted: self?.localDeleted(id)
            }
        }
    }

    /// Stops listening (signed out): the store keeps working on this device only.
    public func detach() {
        store.onLocalChange = nil
        lock.withLock { transport = nil }
    }

    // MARK: Local changes → up

    func localChanged(_ id: UUID) {
        let t: (any GameSyncTransport)? = lock.withLock {
            ledger.stamps[id] = max(clock(), (ledger.stamps[id] ?? .distantPast).addingTimeInterval(0.001))
            ledger.dirty.insert(id)
            ledger.tombstones.remove(id)
            generation[id, default: 0] += 1
            persist()
            return transport
        }
        t?.enqueueSave(id)
    }

    func localDeleted(_ id: UUID) {
        let t: (any GameSyncTransport)? = lock.withLock {
            ledger.tombstones.insert(id)
            ledger.dirty.remove(id)
            inFlight[id] = nil
            persist()
            return transport
        }
        t?.enqueueDelete(id)
    }

    /// Queues every local game for upload (iCloud just became available for this account, or its zone was reset).
    /// Games already on the server with an older stamp are overwritten; newer ones come down instead (the merge).
    public func seedAll() {
        let ids = store.folderIDs()
        let t: (any GameSyncTransport)? = lock.withLock {
            for id in ids {
                if ledger.stamps[id] == nil { ledger.stamps[id] = store.game(id)?.lastPlayedAt ?? Date(timeIntervalSince1970: 0) }
                ledger.dirty.insert(id)
            }
            ledger.seeded = true
            persist()
            return transport
        }
        for id in ids { t?.enqueueSave(id) }
    }

    /// At launch with a known account: re-queues what the ledger says is still pending (the engine usually has it too;
    /// queuing twice is harmless). Seeds instead when this account was never seeded.
    public func resume() {
        let (seeded, dirty, deletes, t) = lock.withLock { (ledger.seeded, ledger.dirty, ledger.tombstones, transport) }
        guard seeded else { seedAll(); return }
        for id in dirty where store.exists(id) { t?.enqueueSave(id) }
        for id in deletes { t?.enqueueDelete(id) }
    }

    /// The record to send for a queued save, built from a copy of the game's files in `staging` (kept until the send
    /// finishes). nil = nothing to send (the game is gone or was deleted here): drop the queued save. `forceFiles`: send
    /// every file even if unchanged (the backend has no record of this game yet).
    public func outgoing(_ id: UUID, staging: URL, forceFiles: Bool = false) -> OutgoingGame? {
        guard !lock.withLock({ ledger.tombstones.contains(id) }) else { return nil }
        guard let snap = store.snapshot(id, into: staging), let json = snap[SyncFileName.gameJSON] else { return nil }
        let schema = (try? Data(contentsOf: json)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["schemaVersion"] as? Int
            ?? SavedGame.currentSchema
        let others = snap.filter { $0.key != SyncFileName.gameJSON }
        let manifest = others.mapValues { url in (try? Data(contentsOf: url)).map(Self.hash) ?? "" }
        return lock.withLock {
            let stamp = ledger.stamps[id] ?? store.game(id)?.lastPlayedAt ?? Date(timeIntervalSince1970: 0)
            ledger.stamps[id] = stamp
            let sendFiles = forceFiles || ledger.uploaded[id] != manifest
            inFlight[id] = (manifest, generation[id, default: 0])
            let files = sendFiles ? others.map { SyncFile(name: $0.key, url: $0.value) }.sorted { $0.name < $1.name } : nil
            return OutgoingGame(id: id, schemaVersion: schema, modifiedAt: stamp, gameJSON: json, files: files)
        }
    }

    /// The server confirmed a save.
    public func didSend(_ id: UUID) {
        let resend: (any GameSyncTransport)? = lock.withLock {
            guard let f = inFlight.removeValue(forKey: id) else { return nil }
            ledger.uploaded[id] = f.manifest
            let changedSince = generation[id, default: 0] != f.generation
            if !changedSince { ledger.dirty.remove(id) }
            persist()
            return changedSince ? transport : nil
        }
        resend?.enqueueSave(id)
    }

    /// A save failed for a reason the backend will retry (network, quota, …): the next attempt rebuilds the record.
    public func sendFailed(_ id: UUID) { lock.withLock { _ = inFlight.removeValue(forKey: id) } }

    /// The server confirmed a delete (or the record was already gone).
    public func didDelete(_ id: UUID) {
        lock.withLock {
            ledger.tombstones.remove(id)
            ledger.stamps[id] = nil
            ledger.uploaded[id] = nil
            persist()
        }
    }

    // MARK: Remote changes → down

    /// A game came down from iCloud (a fetch). Newest stamp wins; a game deleted here never comes back.
    @discardableResult
    public func incoming(_ remote: IncomingGame) -> IncomingResult {
        enum Plan { case ignoreDeleted, unchanged, keepLocal, apply }
        let plan: Plan = lock.withLock {
            if ledger.tombstones.contains(remote.id) { return .ignoreDeleted }
            guard store.exists(remote.id), let stamp = ledger.stamps[remote.id] else { return .apply }
            if stamp == remote.modifiedAt { return .unchanged }   // this version is already here (our own upload)
            return stamp > remote.modifiedAt ? .keepLocal : .apply
        }
        switch plan {
        case .ignoreDeleted: return .ignoredDeleted
        case .unchanged:
            lock.withLock {
                if !ledger.dirty.contains(remote.id) { ledger.uploaded[remote.id] = Self.manifest(remote.files); persist() }
            }
            return .unchanged
        case .keepLocal:
            let t: (any GameSyncTransport)? = lock.withLock {
                ledger.uploaded[remote.id] = nil   // the server has other pictures: send ours in full
                ledger.dirty.insert(remote.id)
                persist()
                return transport
            }
            t?.enqueueSave(remote.id)
            return .keptLocal
        case .apply:
            return apply(remote) ? .applied : .rejected
        }
    }

    /// A save was refused because the server has a newer version (another device saved the same game).
    @discardableResult
    public func conflict(server: IncomingGame) -> ConflictResult {
        enum Plan { case ignoreDeleted, resend, take }
        let plan: Plan = lock.withLock {
            inFlight[server.id] = nil
            if ledger.tombstones.contains(server.id) { return .ignoreDeleted }
            guard store.exists(server.id), let stamp = ledger.stamps[server.id] else { return .take }
            return stamp >= server.modifiedAt ? .resend : .take
        }
        switch plan {
        case .ignoreDeleted: return .ignoredDeleted
        case .resend:
            let t: (any GameSyncTransport)? = lock.withLock {
                ledger.uploaded[server.id] = nil
                ledger.dirty.insert(server.id)
                persist()
                return transport
            }
            t?.enqueueSave(server.id)
            return .resend
        case .take:
            _ = apply(server)
            return .tookServer
        }
    }

    private func apply(_ remote: IncomingGame) -> Bool {
        let all = [SyncFile(name: SyncFileName.gameJSON, url: remote.gameJSON)] + remote.files
        do { try store.applyRemote(id: remote.id, files: all) } catch { return false }
        lock.withLock {
            ledger.stamps[remote.id] = remote.modifiedAt
            ledger.uploaded[remote.id] = Self.manifest(remote.files)
            ledger.dirty.remove(remote.id)
            inFlight[remote.id] = nil
            persist()
        }
        onRemoteChange?()
        return true
    }

    /// A game was deleted on another device (or the record we tried to update is gone): it goes here too. A delete
    /// beats an edit, so a game deleted anywhere is deleted everywhere.
    public func remoteDeleted(_ id: UUID) {
        let had = store.exists(id)
        store.removeRemote(id)
        lock.withLock {
            ledger.stamps[id] = nil; ledger.uploaded[id] = nil; ledger.dirty.remove(id); ledger.tombstones.remove(id)
            inFlight[id] = nil
            persist()
        }
        if had { onRemoteChange?() }
    }

    /// The iCloud account signed out or switched: forget what the server has (local games stay, untouched).
    public func accountReset() {
        lock.withLock {
            ledger.dirty = []; ledger.tombstones = []; ledger.uploaded = [:]; ledger.seeded = false
            inFlight = [:]
            persist()
        }
    }

    // MARK: Helpers

    private func persist() {
        try? FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(ledger) { try? d.write(to: stateDirectory.appendingPathComponent("ledger.json"), options: .atomic) }
    }

    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    static func manifest(_ files: [SyncFile]) -> [String: String] {
        Dictionary(files.filter { $0.name != SyncFileName.gameJSON }
            .map { ($0.name, (try? Data(contentsOf: $0.url)).map(hash) ?? "") }, uniquingKeysWith: { a, _ in a })
    }
}
