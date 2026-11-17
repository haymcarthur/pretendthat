import Foundation

// Round 39 (Haylee, decisions/2026-11-17-autosave-and-count-at-kit.md, queue "Auto-save round"): every NEW game saves
// itself when the kit is made (free and paid alike) and the show counts only then; the save is kept up to date as play
// goes. No Save button, no "save?" question. Still game content only (rule 6: nothing about kids).

/// Nutmeg's lines about saved games. Round 41 (Haylee, decisions/2026-11-17-no-shelf-moment.md): no bookshelf moment
/// when the kit is made (the game saves itself silently), and kids never hear "bookshelf" (or "shelf"): she says the
/// game is saved.
public enum ShelfLines {
    /// "Sounds like a game you have" at the Pick confirm (said live: it names the saved game).
    public static func soundsLike(title: String) -> String {
        "We already have \(title) saved! Want to play that one?"
    }
    /// The model's tool output while the kids choose (they tap a picture; she says nothing more).
    public static let soundsLikeOutput = "(Silent coaching, don't mention it.) The app is showing the kids a game they already "
        + "already saved and asking if they want to play it instead. Say NOTHING now. If the kids talk before "
        + "they tap, say ONLY: \"Tap the one you want!\""
    /// The note after the kids picked a NEW game (the yes to the recap stands; carry on to the roles).
    public static func newGameNote(playerCount: Int) -> String {
        "(Silent coaching, don't mention it.) The kids chose to make a NEW game (not the saved one). The plan is "
            + "ALREADY confirmed: don't call confirm_plan. " + ConfirmStep.confirmedOutput(playerCount: playerCount)
    }
}

/// "Sounds like a game you have" (Haylee): an on-device match of the new game's type + theme against the saved games'
/// titles. No AI call. A saved game only has its title (game + twist in one), so the rule is word based:
/// - the game type's words (set_game, e.g. "Pizza Restaurant") must all be in the saved title, and
/// - the twist (the theme's other words, e.g. "Jungle") must match too: both have the same twist word, or neither has one.
/// Small place words ("shop", "clinic", "café"…) and little words ("the", "on"…) never count. Plural "s" is ignored.
/// Suggest only: the kids can always make the new game.
public enum GameMatch {
    static let stopWords: Set<String> = ["the", "a", "an", "in", "on", "at", "of", "to", "and", "with", "for", "our", "my",
                                         "by", "under", "over", "into", "from", "up", "under", "inside", "outside", "around",
                                         "your", "big", "little", "super", "fun", "pretend", "game", "time", "day", "s"]
    /// Words that name the kind of place, not the game or the twist ("Pet Vet" = "Pet Vet Clinic").
    static let placeWords: Set<String> = ["shop", "store", "restaurant", "cafe", "clinic", "hospital", "office", "house",
                                          "place", "party", "show", "adventure", "station", "stand", "land", "world",
                                          "center", "centre", "club", "company", "co", "school", "palace", "kitchen"]

    /// Content words of a title: lowercased, accents folded, letters/digits only, little words dropped, plural "s" off.
    public static func words(_ s: String) -> Set<String> {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        let raw = folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return Set(raw.compactMap { w -> String? in
            guard !stopWords.contains(w) else { return nil }
            var x = w
            if x.count > 3, x.hasSuffix("s"), !x.hasSuffix("ss") { x.removeLast() }
            return stopWords.contains(x) ? nil : x
        })
    }

    /// True when `saved` sounds like the new game (`gameType` from set_game, `title` the themed title).
    public static func isClose(gameType: String?, title: String, saved: String) -> Bool {
        let s = words(saved).subtracting(placeWords)
        let t = words(title).subtracting(placeWords)
        var g = words(gameType ?? "").subtracting(placeWords)
        if g.isEmpty { g = t }   // no separate game type: the whole title is the game
        guard !g.isEmpty, g.isSubset(of: s) else { return false }
        let twist = t.subtracting(g), savedTwist = s.subtracting(g)
        if twist.isEmpty && savedTwist.isEmpty { return true }
        return !twist.isDisjoint(with: savedTwist)
    }

    /// The closest saved game (most recently played first among the close ones), or nil.
    public static func closest(gameType: String?, title: String, in games: [SavedGame]) -> SavedGame? {
        games.sorted { $0.lastPlayedAt > $1.lastPlayedAt }
            .first { isClose(gameType: gameType, title: title, saved: $0.title) }
    }
}

/// The leave dialog (X): before the kit nothing is counted or saved; after it the game is on the shelf.
public enum LeaveDialogMode: Equatable, Sendable {
    case beforeKit
    case onShelf

    public static func current(isReplay: Bool, savedAs: UUID?) -> LeaveDialogMode {
        isReplay || savedAs != nil ? .onShelf : .beforeKit
    }
    public var title: String { "Leave the game?" }
}

/// Grown-ups → Saved games search (by name; grown-ups only, the kids' shelf stays pictures + arrows).
public enum SavedGameSearch {
    public static func filter(_ rows: [SavedGameRow], query: String) -> [SavedGameRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        return rows.filter { $0.title.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}

/// When a NEW game's kit is made (round 39): the show counts and the game saves itself, once per game.
public struct KitMadeLatch: Equatable, Sendable {
    private var claimed: UUID?
    public init() {}
    /// True exactly once per game id, only for a new game (never a replay) whose kit exists.
    public mutating func claim(gameID: UUID, isReplay: Bool, kitExists: Bool) -> Bool {
        guard !isReplay, kitExists, claimed != gameID else { return false }
        claimed = gameID
        return true
    }
    public func claimed(_ id: UUID) -> Bool { claimed == id }
    public mutating func reset() { claimed = nil }
}
