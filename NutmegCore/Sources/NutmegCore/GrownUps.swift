import Foundation

// Round D2: the Grown-ups corner (design 2026-11-15 §D6, Haylee's gate answer §10.3).
// The gate logic, the Saved games rows and copy, and the section flags E switches on later.

// MARK: - Spelled numbers

/// English words for 1–99 ("forty-seven"), for the grown-up gate's question.
public enum NumberWords {
    static let ones = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                       "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
    static let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

    /// "seven", "thirteen", "forty", "forty-seven". nil outside 1–99.
    public static func spell(_ n: Int) -> String? {
        guard (1...99).contains(n) else { return nil }
        if n < 20 { return ones[n] }
        let t = tens[n / 10], o = n % 10
        return o == 0 ? t : "\(t)-\(ones[o])"
    }
}

// MARK: - The gate

/// The parental gate (Haylee: hold a button for 2 seconds, then tap the number that's spelled out in words, from a
/// grid of numbers with random distractors). A wrong answer is a gentle reset: back to the hold, with a new number.
/// No voice: Nutmeg stays quiet. Reusable for purchases and outside links (section E).
public struct GrownUpGate: Equatable, Sendable {
    public enum Step: Equatable, Sendable {
        /// Hold the button for `holdSeconds`.
        case hold
        /// Tap `target` (shown as words) among `options` (numerals).
        case question(target: Int, options: [Int])
        /// Through: the caller opens what was behind the gate.
        case passed
    }

    public static let holdSeconds: TimeInterval = 2
    /// The number grid: 2 rows of 3.
    public static let optionCount = 6
    public static let range = 21...99   // two-word numbers ("forty-seven"): harder to sound out than "five"

    public private(set) var step: Step = .hold
    /// Wrong answers so far (the gate shows "Let's try again" after one).
    public private(set) var misses = 0
    private var rng: SeededGenerator
    private var lastTarget: Int?

    public init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) { rng = SeededGenerator(seed: seed) }

    /// The words of the number to tap, while asking.
    public var words: String? {
        if case .question(let t, _) = step { return NumberWords.spell(t) }
        return nil
    }

    /// The hold's fill (0…1) after `elapsed` seconds of holding.
    public static func holdProgress(_ elapsed: TimeInterval) -> Double { min(max(elapsed / holdSeconds, 0), 1) }

    /// The finger lifted (or the long press completed) after `elapsed` seconds. A full hold moves on to the question;
    /// a short one stays on the hold. Returns true when it moved on.
    @discardableResult
    public mutating func holdEnded(after elapsed: TimeInterval) -> Bool {
        guard step == .hold, elapsed >= Self.holdSeconds else { return false }
        step = Self.makeQuestion(&rng, avoiding: lastTarget)
        if case .question(let t, _) = step { lastTarget = t }
        return true
    }

    /// A number was tapped. Right: passed. Wrong: back to the hold with a new number.
    @discardableResult
    public mutating func answer(_ n: Int) -> Bool {
        guard case .question(let target, _) = step else { return false }
        if n == target { step = .passed; return true }
        misses += 1
        step = .hold   // the next hold asks a different number (lastTarget is avoided)
        return false
    }

    /// Starts over (the sheet closed).
    public mutating func reset() { step = .hold; misses = 0 }

    static func makeQuestion(_ rng: inout SeededGenerator, avoiding last: Int?) -> Step {
        var target = Int.random(in: range, using: &rng)
        while target == last { target = Int.random(in: range, using: &rng) }
        // Distractors: the swapped digits and same-tens numbers first (the ones a guess would pick), then random.
        var pool: [Int] = []
        let swapped = (target % 10) * 10 + target / 10
        if range.contains(swapped), swapped != target { pool.append(swapped) }
        let sameTens = (0...9).map { target / 10 * 10 + $0 }.filter { range.contains($0) && $0 != target }.shuffled(using: &rng)
        pool.append(contentsOf: sameTens.prefix(2))
        var options = [target]
        for n in pool where !options.contains(n) && options.count < optionCount { options.append(n) }
        while options.count < optionCount {
            let n = Int.random(in: range, using: &rng)
            if !options.contains(n) { options.append(n) }
        }
        return .question(target: target, options: options.shuffled(using: &rng))
    }
}

/// A small deterministic generator (SplitMix64) so the gate is testable; seeded randomly in the app.
public struct SeededGenerator: RandomNumberGenerator, Equatable, Sendable {
    var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - The Grown-ups screen

/// The Grown-ups corner's sections. Only the saved-games ones show now; section E switches the rest on.
public enum GrownUpsSection: String, CaseIterable, Sendable {
    case savedGames, aboutSavedGames
    // Section E (paid app), hidden until `GrownUpsFeatures.storeSections` is on.
    case subscription, restorePurchases, privacyPolicy, help

    public var title: String {
        switch self {
        case .savedGames: "Saved games"
        case .aboutSavedGames: "About saved games"
        case .subscription: "Manage subscription"
        case .restorePurchases: "Restore purchases"
        case .privacyPolicy: "Privacy policy"
        case .help: "Help"
        }
    }

    public var isStoreSection: Bool { ![.savedGames, .aboutSavedGames].contains(self) }

    /// The sections to show, in order.
    public static func visible(storeSections: Bool = GrownUpsFeatures.storeSections) -> [GrownUpsSection] {
        allCases.filter { storeSections || !$0.isStoreSection }
    }
}

public enum GrownUpsFeatures {
    /// Section E turns this on (Manage subscription, Restore purchases, Privacy policy, Help). Off: not shown to users.
    public static let storeSections = false
}

/// The Grown-ups words (plain, for parents).
public enum GrownUpsCopy {
    public static func deleteTitle(_ gameTitle: String) -> String { "Delete \(gameTitle)?" }
    public static let deleteMessage = "This can't be undone."
    /// "Delete Moon Crumbs Bakery? This can't be undone."
    public static func deleteConfirm(_ gameTitle: String) -> String { "\(deleteTitle(gameTitle)) \(deleteMessage)" }
    public static let emptySavedGames = "No saved games yet. Tap the star at the end of a game to keep it here."
    /// From the design's §D7, for this iPad only (D1/D2; iCloud is D4).
    public static let about: [(title: String, body: String)] = [
        ("Saved on this iPad", "Saved games stay on this iPad. There are no accounts, and we don't have servers that store your games."),
        ("Game content only", "A saved game keeps its title, roles, props, play guide and printable pages. Nothing else."),
        ("Nothing about your kids", "PretendThat never saves your child's name, voice, words or picture. Nutmeg listens only while the mic button is held."),
        ("You're in charge", "Delete any game here. Unsaved games are gone when you leave them."),
    ]
}

/// One row of the Saved games list.
public struct SavedGameRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let savedAt: Date
    public let bytes: Int

    public var sizeText: String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }
    public func dateText(locale: Locale = .current) -> String {
        let f = DateFormatter(); f.locale = locale; f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: savedAt)
    }
    public var accessibilityLabel: String { "\(title), saved \(dateText()), \(sizeText)" }
}

extension SavedGameStore {
    /// The Saved games rows, newest first.
    public func rows() -> [SavedGameRow] {
        list().map { SavedGameRow(id: $0.id, title: $0.title, savedAt: $0.createdAt, bytes: size(of: $0.id)) }
    }

    /// The start screen's My games button shows only while at least one game is saved.
    public var showsMyGames: Bool { !list().isEmpty }

    /// Grown-ups delete: removes the game's folder (game.json, art, cover). True when it's gone from disk.
    @discardableResult
    public func deleteGame(_ id: UUID) -> Bool {
        delete(id)
        return !FileManager.default.fileExists(atPath: folder(id).path)
    }
}
