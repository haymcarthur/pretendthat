#if canImport(CloudKit)
import Foundation
import CloudKit

/// Round D4: a saved game as one CloudKit record in the private database's "SavedGames" zone. The record name is the
/// game's UUID. Fields (the whole schema; `allFields` is locked by the privacy test):
/// - `schemaVersion` (Int64): the SavedGame schema, so an older app version can tell a game it can't read yet.
/// - `modifiedAt` (Date/Time): the last-writer-wins stamp.
/// - `game` (Asset): game.json, the privacy-tested SavedGame (game content only).
/// - `fileNames` (String list) + `files` (Asset list), in the same order: art/*.heic, cover.jpg, clips/*.aac. Left out
///   of a save when unchanged (the server keeps the last ones).
public enum GameRecordMapper {
    public static let recordType = "SavedGame"
    public static let zoneName = "SavedGames"
    public enum Field {
        public static let schemaVersion = "schemaVersion"
        public static let modifiedAt = "modifiedAt"
        public static let game = "game"
        public static let fileNames = "fileNames"
        public static let files = "files"
    }
    public static let allFields: Set<String> = [Field.schemaVersion, Field.modifiedAt, Field.game, Field.fileNames, Field.files]

    public static var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName) }

    public static func recordID(_ id: UUID) -> CKRecord.ID { CKRecord.ID(recordName: id.uuidString, zoneID: zoneID) }

    public static func gameID(_ recordID: CKRecord.ID) -> UUID? {
        recordID.zoneID.zoneName == zoneName ? UUID(uuidString: recordID.recordName) : nil
    }

    /// A fresh record (no system fields known yet).
    public static func newRecord(_ id: UUID) -> CKRecord { CKRecord(recordType: recordType, recordID: recordID(id)) }

    /// Writes an outgoing game into a record (a fresh one, or one rebuilt from its cached system fields: only the keys
    /// set here are sent).
    public static func fill(_ record: CKRecord, with game: OutgoingGame) {
        record[Field.schemaVersion] = Int64(game.schemaVersion) as NSNumber
        record[Field.modifiedAt] = game.modifiedAt as NSDate
        record[Field.game] = CKAsset(fileURL: game.gameJSON)
        if let files = game.files {
            record[Field.fileNames] = files.map(\.name) as [String] as NSArray
            record[Field.files] = files.map { CKAsset(fileURL: $0.url) } as NSArray
        }
    }

    /// Reads a fetched (or conflicting server) record. nil = not one of ours or incomplete (ignored).
    public static func incoming(_ record: CKRecord) -> IncomingGame? {
        guard record.recordType == recordType, let id = gameID(record.recordID),
              let modifiedAt = record[Field.modifiedAt] as? Date,
              let json = (record[Field.game] as? CKAsset)?.fileURL else { return nil }
        let schema = (record[Field.schemaVersion] as? NSNumber)?.intValue ?? SavedGame.currentSchema
        let names = record[Field.fileNames] as? [String] ?? []
        let assets = record[Field.files] as? [CKAsset] ?? []
        guard names.count == assets.count else { return nil }
        let files = zip(names, assets).compactMap { name, asset -> SyncFile? in
            guard SyncFileName.isAllowed(name), name != SyncFileName.gameJSON, let url = asset.fileURL else { return nil }
            return SyncFile(name: name, url: url)
        }
        return IncomingGame(id: id, schemaVersion: schema, modifiedAt: modifiedAt, gameJSON: json, files: files)
    }

    /// The cached system fields of a record (change tag etc., no values), to rebuild it for the next save.
    public static func systemFields(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    public static func record(systemFields data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        defer { coder.finishDecoding() }
        return CKRecord(coder: coder)
    }
}
#endif
