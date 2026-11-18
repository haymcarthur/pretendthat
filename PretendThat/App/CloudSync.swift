import CloudKit
import UIKit
import NutmegCore

/// Round D4 (decisions/2026-11-17-icloud-sync-before-launch.md): saved games sync through the family's own private
/// iCloud with CKSyncEngine (private database, zone "SavedGames", one `SavedGame` record per game; the mapping is
/// `GameRecordMapper`, the merge and delete rules are `GameSync`, both unit-tested in NutmegCore).
///
/// Silent and optional: no switch, no messages. With no iCloud account (signed out, iCloud Drive off for the app,
/// restricted) the engine is never created and the app works on this device exactly as before; when an account appears
/// (`CKAccountChanged`) every local game uploads. A build without the container (the personal-team `.dev` device build,
/// which has no iCloud entitlement: `PTCloudKitContainer` is empty) never touches CloudKit at all.
final class CloudGameSync: CKSyncEngineDelegate, GameSyncTransport, @unchecked Sendable {
    let sync: GameSync
    let containerID: String
    /// A game came down or was deleted on another device (called on the main actor).
    var onRemoteChange: (@MainActor () -> Void)?

    private let lock = NSLock()
    private var engine: CKSyncEngine?
    private var checking = false
    private var accountObserver: NSObjectProtocol?
    private let stateDir: URL
    private let outboxDir: URL

    /// The container from Info.plist (`PTCloudKitContainer`, set by project.yml only for the company team), or nil.
    static func containerID(info: [String: Any]) -> String? {
        guard let id = info["PTCloudKitContainer"] as? String, id.hasPrefix("iCloud."), !id.contains("$(") else { return nil }
        return id
    }

    /// nil = this build can't use iCloud (no container) or a debug demo/test run (never uploads demo games).
    static func make(store: SavedGameStore, info: [String: Any]) -> CloudGameSync? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        // `-PTSync` keeps it on in a demo run (the signed-out check on a simulator: no account, so nothing uploads).
        if !args.contains("-PTSync"), DemoDriver.requestedPhase != nil || args.contains("-PTNoAI") || args.contains("-PTNoSync") {
            rtLog("icloud: off for this debug run")
            return nil
        }
        #endif
        guard let id = containerID(info: info) else {
            rtLog("icloud: no container in this build (saved games stay on this device)")
            return nil
        }
        return CloudGameSync(store: store, containerID: id)
    }

    init(store: SavedGameStore, containerID: String) {
        self.containerID = containerID
        stateDir = GameSync.defaultStateDirectory()
        let caches = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        outboxDir = caches.appendingPathComponent("SavedGamesSyncOutbox", isDirectory: true)
        try? FileManager.default.removeItem(at: outboxDir)   // copies left from an earlier run
        sync = GameSync(store: store, stateDirectory: stateDir)
        sync.onRemoteChange = { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.onRemoteChange?() }
        }
    }

    // MARK: Starting (only with an iCloud account)

    /// Checks the account; starts the engine when one is available, else waits quietly for `CKAccountChanged`.
    func start() {
        if accountObserver == nil {
            accountObserver = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: nil) { [weak self] _ in
                self?.checkAccount()
            }
        }
        checkAccount()
    }

    private func checkAccount() {
        let go: Bool = lock.withLock {
            guard engine == nil, !checking else { return false }
            checking = true
            return true
        }
        guard go else { return }
        Task {
            let status = try? await CKContainer(identifier: containerID).accountStatus()
            lock.withLock { checking = false }
            switch status {
            case .available?:
                startEngine()
            default:
                rtLog("icloud: no account available (\(Self.describe(status))): saved games stay on this device")
            }
        }
    }

    private func startEngine() {
        let fresh: Bool = lock.withLock {
            guard engine == nil else { return false }
            let saved = (try? Data(contentsOf: stateFile)).flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
            var config = CKSyncEngine.Configuration(database: CKContainer(identifier: containerID).privateCloudDatabase,
                                                    stateSerialization: saved, delegate: self)
            config.automaticallySync = true
            engine = CKSyncEngine(config)
            return true
        }
        guard fresh else { return }
        sync.attach(self)
        if !sync.snapshotLedger.seeded { addZone() }
        sync.resume()   // the first time for this account: every local game is queued
        rtLog("icloud: sync started")
        Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
    }

    /// The app came to the front: pick up changes made on other devices (pushes can be missed).
    func appBecameActive() {
        guard let engine = lock.withLock({ engine }) else { checkAccount(); return }
        Task { try? await engine.fetchChanges() }
    }

    // MARK: GameSyncTransport

    func enqueueSave(_ id: UUID) {
        lock.withLock { engine }?.state.add(pendingRecordZoneChanges: [.saveRecord(GameRecordMapper.recordID(id))])
    }

    func enqueueDelete(_ id: UUID) {
        lock.withLock { engine }?.state.add(pendingRecordZoneChanges: [.deleteRecord(GameRecordMapper.recordID(id))])
    }

    private func addZone() {
        lock.withLock { engine }?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: GameRecordMapper.zoneID))])
    }

    // MARK: CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let e):
            if let data = try? JSONEncoder().encode(e.stateSerialization) {
                try? FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
                try? data.write(to: stateFile, options: .atomic)
            }

        case .accountChange(let e):
            switch e.changeType {
            case .signIn:
                rtLog("icloud: signed in: uploading the local games")
                resetForNewAccount(seed: true)
            case .switchAccounts:
                rtLog("icloud: switched accounts: local games kept, uploading them to this account")
                resetForNewAccount(seed: true)
            case .signOut:
                rtLog("icloud: signed out: local games kept, on this device only")
                resetForNewAccount(seed: false)
            @unknown default:
                break
            }

        case .fetchedDatabaseChanges(let e):
            if e.deletions.contains(where: { $0.zoneID == GameRecordMapper.zoneID }) {
                // The zone was deleted (or reset): the games on this device are the source of truth, so they go up again.
                rtLog("icloud: the saved-games zone was reset: uploading the local games again")
                resetForNewAccount(seed: true)
            }

        case .fetchedRecordZoneChanges(let e):
            for m in e.modifications {
                guard let game = GameRecordMapper.incoming(m.record) else { continue }
                saveFields(m.record)
                let result = sync.incoming(game)
                rtLog("icloud: fetched a game (\(result))")
            }
            for d in e.deletions {
                guard let id = GameRecordMapper.gameID(d.recordID) else { continue }
                removeFields(id)
                sync.remoteDeleted(id)
                rtLog("icloud: a game was deleted on another device")
            }

        case .sentRecordZoneChanges(let e):
            for record in e.savedRecords {
                guard let id = GameRecordMapper.gameID(record.recordID) else { continue }
                saveFields(record)
                sync.didSend(id)
                clearOutbox(id)
            }
            for failure in e.failedRecordSaves {
                guard let id = GameRecordMapper.gameID(failure.record.recordID) else { continue }
                clearOutbox(id)
                handleSaveFailure(id, failure.error)
            }
            for id in e.deletedRecordIDs.compactMap(GameRecordMapper.gameID) {
                removeFields(id)
                sync.didDelete(id)
            }
            for (recordID, error) in e.failedRecordDeletes {
                guard let id = GameRecordMapper.gameID(recordID) else { continue }
                if error.code == .unknownItem { removeFields(id); sync.didDelete(id) }   // already gone
                else { rtLog("icloud: delete failed (\(error.code.rawValue)), will retry") }
            }
            if !e.savedRecords.isEmpty || !e.deletedRecordIDs.isEmpty {
                rtLog("icloud: sent \(e.savedRecords.count) game(s), deleted \(e.deletedRecordIDs.count)")
            }

        case .sentDatabaseChanges(let e):
            for f in e.failedZoneSaves { rtLog("icloud: zone save failed (\(f.error.code.rawValue))") }

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [self] recordID in
            guard let id = GameRecordMapper.gameID(recordID) else {
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
            let cached = loadFields(id)
            guard let game = sync.outgoing(id, staging: outboxDir.appendingPathComponent(id.uuidString), forceFiles: cached == nil) else {
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])   // gone, or deleted here
                return nil
            }
            let record = cached ?? GameRecordMapper.newRecord(id)
            GameRecordMapper.fill(record, with: game)
            return record
        }
    }

    // MARK: Failures

    private func handleSaveFailure(_ id: UUID, _ error: CKError) {
        switch error.code {
        case .serverRecordChanged:
            // Another device saved this game: the newest save wins (GameSync decides; a resend is queued if it's ours).
            guard let server = error.serverRecord, let game = GameRecordMapper.incoming(server) else { sync.sendFailed(id); enqueueSave(id); return }
            saveFields(server)
            rtLog("icloud: save conflict (\(sync.conflict(server: game)))")
        case .unknownItem:
            // The record we were updating is gone: it was deleted on another device, and a delete beats an edit.
            removeFields(id)
            sync.remoteDeleted(id)
        case .zoneNotFound, .userDeletedZone:
            rtLog("icloud: the zone is missing: recreating it and uploading the local games")
            resetForNewAccount(seed: true)
        default:
            // Network, quota, rate limits, busy: the engine keeps the change and retries later.
            sync.sendFailed(id)
            rtLog("icloud: save failed (\(error.code.rawValue)), will retry")
        }
    }

    // MARK: Bookkeeping

    /// A new account, a reset zone, or signed out: forget the server's records (never the local games).
    private func resetForNewAccount(seed: Bool) {
        try? FileManager.default.removeItem(at: fieldsDir)
        sync.accountReset()
        if seed {
            addZone()
            sync.seedAll()
        }
    }

    private var stateFile: URL { stateDir.appendingPathComponent("engine-state.json") }
    private var fieldsDir: URL { stateDir.appendingPathComponent("fields", isDirectory: true) }
    private func fieldsFile(_ id: UUID) -> URL { fieldsDir.appendingPathComponent(id.uuidString) }

    private func saveFields(_ record: CKRecord) {
        guard let id = GameRecordMapper.gameID(record.recordID) else { return }
        try? FileManager.default.createDirectory(at: fieldsDir, withIntermediateDirectories: true)
        try? GameRecordMapper.systemFields(record).write(to: fieldsFile(id), options: .atomic)
    }
    private func loadFields(_ id: UUID) -> CKRecord? {
        (try? Data(contentsOf: fieldsFile(id))).flatMap(GameRecordMapper.record(systemFields:))
    }
    private func removeFields(_ id: UUID) { try? FileManager.default.removeItem(at: fieldsFile(id)) }
    private func clearOutbox(_ id: UUID) { try? FileManager.default.removeItem(at: outboxDir.appendingPathComponent(id.uuidString)) }

    private static func describe(_ status: CKAccountStatus?) -> String {
        switch status {
        case .noAccount?: "no account"
        case .restricted?: "restricted"
        case .couldNotDetermine?: "could not determine"
        case .temporarilyUnavailable?: "temporarily unavailable"
        case .available?: "available"
        default: "unknown"
        }
    }
}
