import Foundation

// Round D1 (saved games, design 2026-11-15 §D1–D3, Haylee): a game is saved at The End ("Save it to play again") and
// can be replayed from My games. It lives ONLY on this iPad (Application Support/SavedGames; iCloud is round D4).
// Only GAME CONTENT is stored, never anything about kids (CLAUDE.md rule 6): no names (the app never asks), no player
// count from any play, no chat transcript (Nutmeg's side included), no kid audio or text, no moderation results, no
// device ids, no timing. `SavedGamePrivacyTests` locks the exact key set and checks a live-like store's JSON.

/// One prop of a saved game: what the replay's "Do you still have these?" list shows.
public struct SavedProp: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var libraryID: String?
    public var householdItem: String
    public var becomes: String
    public var reason: String?
    public var alternates: [String]
    /// The kids didn't have it on the first play (the saved play guide says "pretend …" for it).
    public var pretendOnFirstPlay: Bool
    public init(id: String, libraryID: String?, householdItem: String, becomes: String, reason: String?, alternates: [String],
                pretendOnFirstPlay: Bool) {
        self.id = id; self.libraryID = libraryID; self.householdItem = householdItem; self.becomes = becomes
        self.reason = reason; self.alternates = alternates; self.pretendOnFirstPlay = pretendOnFirstPlay
    }
    public init(_ p: Prop) {
        self.init(id: p.id, libraryID: p.libraryID, householdItem: p.householdItem, becomes: p.becomes, reason: p.reason,
                  alternates: p.alternates ?? [], pretendOnFirstPlay: p.isSkipped)
    }
    /// The prop as the replay starts it: every card starts as "Got it" (Haylee), the first play's pretend undone.
    public var replayProp: Prop {
        Prop(id: id, householdItem: householdItem, becomes: becomes, forRole: .all, safetyOK: true,
             libraryID: libraryID, alternates: alternates, skipped: false, reason: reason)
    }
}

/// A recorded Nutmeg line (round D3b fills these; D1 saves none). Her app-authored lines only, never the kid.
public struct SavedClip: Codable, Equatable, Sendable {
    public var key: String; public var text: String; public var kind: String; public var role: String?
    public var duration: Double; public var file: String
    public init(key: String, text: String, kind: String, role: String?, duration: Double, file: String) {
        self.key = key; self.text = text; self.kind = kind; self.role = role; self.duration = duration; self.file = file
    }
}

/// A saved game, schema version 1 (design §D2: exactly these fields).
public struct SavedGame: Codable, Equatable, Sendable, Identifiable {
    public static let currentSchema = 1
    public var id: UUID
    public var schemaVersion: Int
    /// Device usage for the shelf order (newest first), not about a kid.
    public var createdAt: Date
    public var lastPlayedAt: Date
    public var title: String
    /// The 6 ranked roles (title, job, symbol).
    public var roles: [Role]
    public var props: [SavedProp]
    /// The kit as written for all 6 roles: the 6 recipe pages + the play guide (role-tagged steps).
    public var kit: Kit
    public var hasPrinter: Bool
    public var printStyle: PrintStyle?
    /// The Draw it! guide (no-printer games); counts are computed from the replay's count.
    public var drawGuide: DrawGuide?
    /// The stored page art keys (`ArtKey`), files under art/ as HEIC. The PDF is always rebuilt, never stored.
    public var art: [String]
    /// A no-printer game made "Save printables for later": its pages are stored too and Paper can print them.
    public var printablesMade: Bool
    /// The printables' pages (no-printer games with `printablesMade`).
    public var printables: [KitItem]?
    /// cover.jpg (a 600 px card picture for the shelf), when the game had sign art.
    public var cover: String?
    /// Nutmeg's recorded lines (round D3b). Empty in D1: every replay line is said live.
    public var clips: [SavedClip]
    /// The voice the clips were (will be) recorded in.
    public var voiceID: String

    public init(id: UUID = UUID(), createdAt: Date, title: String, roles: [Role], props: [SavedProp], kit: Kit,
                hasPrinter: Bool, printStyle: PrintStyle?, drawGuide: DrawGuide?, art: [String], printablesMade: Bool = false,
                printables: [KitItem]? = nil, cover: String? = nil, clips: [SavedClip] = [], voiceID: String) {
        self.id = id; self.schemaVersion = Self.currentSchema; self.createdAt = createdAt; self.lastPlayedAt = createdAt
        self.title = title; self.roles = roles; self.props = props; self.kit = kit; self.hasPrinter = hasPrinter
        self.printStyle = printStyle; self.drawGuide = drawGuide; self.art = art; self.printablesMade = printablesMade
        self.printables = printables; self.cover = cover; self.clips = clips; self.voiceID = voiceID
    }

    /// The exact JSON keys a saved game may have (the privacy test compares against this; a new field is a decision).
    public static let allowedKeys: Set<String> = ["id", "schemaVersion", "createdAt", "lastPlayedAt", "title", "roles", "props",
                                                  "kit", "hasPrinter", "printStyle", "drawGuide", "art", "printablesMade",
                                                  "printables", "cover", "clips", "voiceID"]

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys]; return e
    }
    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }
    /// Decodes any known schema version (only v1 exists).
    public static func decode(_ data: Data) throws -> SavedGame {
        let g = try decoder().decode(SavedGame.self, from: data)
        guard g.schemaVersion <= currentSchema else { throw CocoaError(.coderReadCorrupt) }
        return g
    }

    /// The prop pictures on the shelf card of a game with no sign art (up to 3 library props).
    public var coverProps: [String] { Array(props.compactMap(\.libraryID).prefix(3)) }
}

/// Stored art keys: `img:<itemID>` (one page image) or `cut:<itemID>:<n>` (a cut-out or a badge slice).
public enum ArtKey {
    public static func image(_ itemID: String) -> String { "img:\(itemID)" }
    public static func cutout(_ itemID: String, _ n: Int) -> String { "cut:\(itemID):\(n)" }
    /// (itemID, cut-out index or nil) for a key.
    public static func parse(_ key: String) -> (itemID: String, index: Int?)? {
        let parts = key.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 2, parts[0] == "img", !parts[1].isEmpty { return (parts[1], nil) }
        if parts.count == 3, parts[0] == "cut", !parts[1].isEmpty, let n = Int(parts[2]) { return (parts[1], n) }
        return nil
    }
    /// A safe file name for a key (letters, digits, - and _ only).
    public static func fileName(_ key: String) -> String {
        let safe = key.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? Character($0) : "_" }
        return String(safe) + ".heic"
    }
}

extension AdventureStore {
    /// The game as it can be saved (The End of a first play), or nil. Built ONLY from game content: the current title,
    /// the 6 ranked roles, the props, the kit for 6, the printer/color choices and the Draw it! guide. Never the count,
    /// the chat, kid text or anything else the store holds in memory.
    public func savedGame(id: UUID = UUID(), now: Date = Date(), art: [String], cover: String?, printables: [KitItem]? = nil,
                          voiceID: String = VoiceConfig.nutmeg.voiceID) -> SavedGame? {
        guard let full = fullKit, let roles = plan?.roles, !roles.isEmpty, !full.scenes.isEmpty else { return nil }
        return SavedGame(id: id, createdAt: now, title: currentTitle, roles: roles,
                         props: (props?.props ?? []).map(SavedProp.init), kit: full,
                         hasPrinter: hasPrinter ?? true, printStyle: printStyle, drawGuide: drawGuide, art: art,
                         printablesMade: printables != nil, printables: printables, cover: cover, voiceID: voiceID)
    }
}

extension VoiceConfig {
    /// "coral@gpt-realtime-…": the voice + model a clip is recorded in (design §D4.5).
    public var voiceID: String { "\(voice)@\(Realtime.model)" }
}

// MARK: - The local store (this iPad only)

/// Saved games on disk: `<root>/<uuid>/game.json`, `art/<key>.heic`, `cover.jpg`. Writes are atomic (a `.tmp` folder,
/// then a rename). A half-written folder is never listed.
public final class SavedGameStore: @unchecked Sendable {
    public let root: URL
    private let fm = FileManager.default
    private let lock = NSLock()

    public init(root: URL) { self.root = root }

    /// Application Support/SavedGames on this device (never iCloud in D1).
    public static func defaultRoot() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SavedGames", isDirectory: true)
    }

    func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }

    /// Writes a game with its art (key → HEIC data), cover (JPEG data) and (round D3b) its recorded clips
    /// (clip key → AAC data, ADTS `.aac`; `game.clips` lists them).
    public func save(_ game: SavedGame, art: [String: Data], cover: Data?, clips: [String: Data] = [:]) throws {
        try lock.withLock {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let tmp = root.appendingPathComponent(game.id.uuidString + ".tmp", isDirectory: true)
            try? fm.removeItem(at: tmp)
            try fm.createDirectory(at: tmp.appendingPathComponent("art", isDirectory: true), withIntermediateDirectories: true)
            var g = game
            g.art = art.keys.sorted()
            g.cover = cover == nil ? nil : "cover.jpg"
            for (key, data) in art { try write(data, to: tmp.appendingPathComponent("art").appendingPathComponent(ArtKey.fileName(key))) }
            if !clips.isEmpty { try fm.createDirectory(at: tmp.appendingPathComponent("clips", isDirectory: true), withIntermediateDirectories: true) }
            g.clips = g.clips.filter { clips[$0.key] != nil }.map { var c = $0; c.file = SavedGame.clipFile($0.key); return c }
            for c in g.clips { try write(clips[c.key]!, to: tmp.appendingPathComponent(SavedGame.clipFile(c.key))) }
            if let cover { try write(cover, to: tmp.appendingPathComponent("cover.jpg")) }
            try write(SavedGame.encoder().encode(g), to: tmp.appendingPathComponent("game.json"))
            let dest = folder(game.id)
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.moveItem(at: tmp, to: dest)
        }
    }

    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    /// Every fully saved game, newest first (Haylee: the shelf is newest first).
    public func list() -> [SavedGame] {
        lock.withLock {
            guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
            return dirs.filter { !$0.lastPathComponent.hasSuffix(".tmp") }
                .compactMap { try? Data(contentsOf: $0.appendingPathComponent("game.json")) }
                .compactMap { try? SavedGame.decode($0) }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    public var count: Int { list().count }

    public func game(_ id: UUID) -> SavedGame? {
        lock.withLock { (try? Data(contentsOf: folder(id).appendingPathComponent("game.json"))).flatMap { try? SavedGame.decode($0) } }
    }

    /// Every stored art file of a game (key → data).
    public func art(for game: SavedGame) -> [String: Data] {
        var out: [String: Data] = [:]
        for key in game.art {
            if let d = try? Data(contentsOf: folder(game.id).appendingPathComponent("art").appendingPathComponent(ArtKey.fileName(key))) { out[key] = d }
        }
        return out
    }

    public func cover(for game: SavedGame) -> Data? {
        guard game.cover != nil else { return nil }
        return try? Data(contentsOf: folder(game.id).appendingPathComponent("cover.jpg"))
    }

    /// A replay started: only `lastPlayedAt` changes (the content is immutable after saving).
    public func touch(_ id: UUID, at date: Date = Date()) {
        lock.withLock {   // read and write under the lock (round D3b: a clip may be added at the same moment)
            let json = folder(id).appendingPathComponent("game.json")
            guard let d = try? Data(contentsOf: json), var g = try? SavedGame.decode(d) else { return }
            g.lastPlayedAt = date
            if let data = try? SavedGame.encoder().encode(g) { try? write(data, to: json) }
        }
    }

    // MARK: Clips (round D3b)

    /// A clip recorded on a later play (or after the save) joins the saved game: append-only, the first one saved for a
    /// key wins (both are her real voice saying the same line). Returns false when the game is gone or the key exists.
    @discardableResult
    public func addClip(_ clip: SavedClip, data: Data, to id: UUID) -> Bool {
        lock.withLock {
            let json = folder(id).appendingPathComponent("game.json")
            guard let d = try? Data(contentsOf: json), var g = try? SavedGame.decode(d) else { return false }
            guard !g.clips.contains(where: { $0.key == clip.key }) else { return false }
            do {
                try fm.createDirectory(at: folder(id).appendingPathComponent("clips", isDirectory: true), withIntermediateDirectories: true)
                var c = clip; c.file = SavedGame.clipFile(clip.key)
                try write(data, to: folder(id).appendingPathComponent(c.file))
                g.clips.append(c)
                try write(SavedGame.encoder().encode(g), to: json)
                return true
            } catch { return false }
        }
    }

    /// A stored clip's audio file.
    public func clipURL(_ clip: SavedClip, in id: UUID) -> URL { folder(id).appendingPathComponent(SavedGame.clipFile(clip.key)) }

    /// Removes a game (Grown-ups delete is round D2; used by tests now).
    public func delete(_ id: UUID) { lock.withLock { try? fm.removeItem(at: folder(id)) } }

    /// The game's folder size in bytes (Grown-ups shows it in D2; logged in D1).
    public func size(of id: UUID) -> Int {
        guard let e = fm.enumerator(at: folder(id), includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return e.compactMap { ($0 as? URL).flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } }.reduce(0, +)
    }
}
