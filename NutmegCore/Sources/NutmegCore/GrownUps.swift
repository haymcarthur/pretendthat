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

// MARK: - The Grown-ups menu (round 32)

/// The Grown-ups menu's rows, in order. Each one opens its own screen (the two web pages open in an in-app Safari
/// view). Round 32 (Haylee's spec, queued as "round 29"): Saved games, Manage subscription, Restore purchases, Privacy
/// policy, About what we save, Terms of use, Help & contact, and Replay the intro (hidden until round 33 builds the
/// parent onboarding).
public enum GrownUpsSection: String, CaseIterable, Hashable, Sendable {
    // Round 37: reportProblem (App Store 1.2: report AI-made content), in the help group.
    case savedGames, subscription, restorePurchases, aiPartners, privacyPolicy, aboutWhatWeSave, termsOfUse, help, reportProblem, replayIntro

    public var title: String {
        switch self {
        case .savedGames: "Saved games"
        case .subscription: "Manage subscription"
        case .restorePurchases: "Restore purchases"
        case .aiPartners: OnboardingCopy.consentRowTitle
        case .privacyPolicy: "Privacy policy"
        case .aboutWhatWeSave: "About what we save"
        case .termsOfUse: "Terms of use"
        case .help: "Help & contact"
        case .reportProblem: "Report a problem"
        case .replayIntro: "Replay the intro"
        }
    }

    /// The row's second line.
    public var subtitle: String {
        switch self {
        case .savedGames: "See, sort and delete the games saved on this iPad"
        case .subscription: "Change or cancel your plan with Apple"
        case .restorePurchases: "Bought a plan before? Bring it to this iPad"
        case .aiPartners: "Turn Nutmeg's AI partners on or off"
        case .privacyPolicy: "Opens pretendthat.app/privacy"
        case .aboutWhatWeSave: "What stays on this iPad, in plain words"
        case .termsOfUse: "Opens pretendthat.app/terms"
        case .help: "Get help, and where billing questions go"
        case .reportProblem: "Something odd or not OK in a game? Tell us"
        case .replayIntro: "Watch the grown-ups introduction again"
        }
    }

    /// SF Symbol for the row.
    public var systemImage: String {
        switch self {
        case .savedGames: "books.vertical.fill"
        case .subscription: "creditcard.fill"
        case .restorePurchases: "arrow.clockwise.circle.fill"
        case .aiPartners: "sparkles"
        case .privacyPolicy: "hand.raised.fill"
        case .aboutWhatWeSave: "lock.shield.fill"
        case .termsOfUse: "doc.text.fill"
        case .help: "questionmark.circle.fill"
        case .reportProblem: "flag.fill"
        case .replayIntro: "play.rectangle.fill"
        }
    }

    /// A web page the row opens in an in-app Safari view (behind the gate), or nil for an app screen.
    public var webPage: URL? {
        switch self {
        case .privacyPolicy: GrownUpsLinks.privacy
        case .termsOfUse: GrownUpsLinks.terms
        default: nil
        }
    }

    /// The menu groups: games · plan · privacy and terms · help.
    public var group: Int {
        switch self {
        case .savedGames: 0
        case .subscription, .restorePurchases: 1
        case .aiPartners, .privacyPolicy, .aboutWhatWeSave, .termsOfUse: 2
        case .help, .reportProblem, .replayIntro: 3
        }
    }

    /// The rows to show, in order. `replayIntro` stays hidden until the parent onboarding exists (round 33).
    public static func visible(replayIntro: Bool = GrownUpsFeatures.replayIntro) -> [GrownUpsSection] {
        allCases.filter { replayIntro || $0 != .replayIntro }
    }

    /// The visible rows split into the menu's groups (empty groups dropped).
    public static func groups(replayIntro: Bool = GrownUpsFeatures.replayIntro) -> [[GrownUpsSection]] {
        let rows = visible(replayIntro: replayIntro)
        return (0...3).map { g in rows.filter { $0.group == g } }.filter { !$0.isEmpty }
    }
}

public enum GrownUpsFeatures {
    /// Round 33 built the parent onboarding: the row shows and replays it (from How it works; the gate was just passed).
    public static let replayIntro = true
}

/// The outside pages (all opened behind the gate, in an in-app Safari view).
public enum GrownUpsLinks {
    public static let privacy = URL(string: "https://pretendthat.app/privacy")!
    public static let terms = URL(string: "https://pretendthat.app/terms")!
    public static let support = URL(string: "https://pretendthat.app/support")!
    public static let reportAProblem = URL(string: "https://reportaproblem.apple.com")!
    public static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let all = [privacy, terms, support, reportAProblem, appleEULA]
}

// MARK: - Saved games sort

/// The Saved games screen's sort (newest first is the default).
public enum SavedGameSort: String, CaseIterable, Identifiable, Sendable {
    case newest, name
    public var id: String { rawValue }
    public var label: String { self == .newest ? "Newest" : "Name" }

    /// Newest first (ties A to Z), or A to Z ignoring case and accents, numbers in number order (ties newest first).
    public func apply(_ rows: [SavedGameRow]) -> [SavedGameRow] {
        switch self {
        case .newest:
            return rows.sorted { a, b in a.savedAt != b.savedAt ? a.savedAt > b.savedAt : Self.compare(a.title, b.title) == .orderedAscending }
        case .name:
            return rows.sorted { a, b in
                let c = Self.compare(a.title, b.title)
                return c != .orderedSame ? c == .orderedAscending : a.savedAt > b.savedAt
            }
        }
    }

    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive, .numeric], locale: Locale(identifier: "en_US"))
    }
}

// MARK: - Plans and restore (StoreKit calls live in the app; the mapping lives here so it's testable)

/// What the Manage subscription screen shows.
public enum PlanStatus: Equatable, Sendable {
    case none
    case active(name: String)

    /// From the product IDs of the current entitlements (StoreKit `Transaction.currentEntitlements`). The products
    /// don't exist yet: an ID with "seasonpass" is Season Pass, "showpass" Show Pass, anything else "your plan".
    public static func from(productIDs: [String]) -> PlanStatus {
        let ids = productIDs.map { $0.lowercased().replacingOccurrences(of: "_", with: "") }
        if ids.contains(where: { $0.contains("seasonpass") }) { return .active(name: "Season Pass") }
        if ids.contains(where: { $0.contains("showpass") }) { return .active(name: "Show Pass") }
        if !ids.isEmpty { return .active(name: "Your plan") }
        return .none
    }

    public var headline: String {
        switch self {
        case .none: "No active plan yet"
        case .active(let name): "\(name) is active"
        }
    }

    public var detail: String {
        switch self {
        case .none: "When you choose Show Pass or Season Pass, it will show up here. Plans are billed by Apple to your Apple ID."
        case .active: "Billed by Apple to your Apple ID. It renews on its own until you cancel."
        }
    }
}

/// Why a restore failed (the app maps StoreKit's errors to these).
public enum RestoreFailure: Error, Equatable, Sendable {
    case userCancelled, network, notAvailable, other
}

/// The Restore purchases result.
public enum RestoreOutcome: Equatable, Sendable {
    case restored(count: Int)
    case nothingToRestore
    case cancelled
    case offline
    case unavailable
    case failed

    /// `AppStore.sync()` and then the count of current entitlements (or the mapped error) → the outcome.
    public static func after(_ result: Result<Int, RestoreFailure>) -> RestoreOutcome {
        switch result {
        case .success(let n): n > 0 ? .restored(count: n) : .nothingToRestore
        case .failure(.userCancelled): .cancelled
        case .failure(.network): .offline
        case .failure(.notAvailable): .unavailable
        case .failure(.other): .failed
        }
    }

    public var message: String {
        switch self {
        case .restored: "Restored. Your plan is active on this iPad."
        case .nothingToRestore: "Nothing to restore yet. This Apple ID has no PretendThat purchases."
        case .cancelled: "Restore was cancelled. Nothing changed."
        case .offline: "Couldn't reach the App Store. Check the Wi-Fi and try again."
        case .unavailable: "The App Store isn't available on this iPad right now. Check Screen Time's purchase settings, then try again."
        case .failed: "Something went wrong. Please try again in a moment."
        }
    }

    /// The check finished (restored, or there was nothing to restore), as opposed to an error or a cancel.
    public var finished: Bool {
        switch self {
        case .restored, .nothingToRestore: true
        default: false
        }
    }
}

/// The Grown-ups words (plain, for parents).
public enum GrownUpsCopy {
    public static let menuFooter = "Only grown-ups can open this corner. Nutmeg stays quiet in here."
    public static func deleteTitle(_ gameTitle: String) -> String { "Delete \(gameTitle)?" }
    public static let deleteMessage = "This can't be undone."
    /// "Delete Moon Crumbs Bakery? This can't be undone."
    public static func deleteConfirm(_ gameTitle: String) -> String { "\(deleteTitle(gameTitle)) \(deleteMessage)" }
    public static let emptySavedGames = "No saved games yet. Tap the star at the end of a game to keep it here."
    public static let savedGamesFooter = "Saved on this iPad. Kids can't delete games; only you can, here."
    public static let subscriptionIntro = "PretendThat plans are subscriptions through Apple. To change your plan, see when it renews, or cancel, use Apple's subscription settings. Cancel at least a day before it renews to avoid the next charge."
    public static let manageButton = "Open Apple's subscription settings"
    public static let manageFailed = "Couldn't open Apple's subscription settings here. You can also open Settings, tap your name, then Subscriptions."
    public static let restoreIntro = "Bought a plan on another iPad, or before reinstalling? Restore it here. It uses the Apple ID signed in on this iPad."
    public static let restoreButton = "Restore purchases"
    public static let restoring = "Checking with the App Store…"
    public static let helpIntro = "Questions, ideas or a problem with a game? Our help page has answers and a way to reach us."
    public static let helpButton = "Open the help page"
    public static let billingNote = "Billing and refunds go through Apple."
    public static let billingLink = "Report a purchase problem to Apple"
    public static let webFailed = "This page couldn't be opened."

    /// About what we save (round 31: kids' voices become words on the iPad and are never sent).
    public static let about: [(title: String, body: String)] = [
        ("Voices stay on this iPad", "Nutmeg listens only while the mic button is held. Your child's voice is turned into words right on this iPad. The sound of their voice is never sent anywhere and never saved."),
        ("Only words go to our AI partners", "Those words go to our AI partners (OpenAI and Anthropic) so Nutmeg can answer and write the game. Names are removed first, and the words are checked for kid safety."),
        ("Saved games are game content only", "A saved game keeps its title, roles, props, play guide, printable pages and Nutmeg's recorded lines. Nothing about your child: no names, voices or pictures."),
        ("Saved on this iPad", "Saved games stay on this iPad. We don't have servers that store your games."),
        // Round 37 (Anthropic's rule for products used by minors + App Store 1.2 / 5.1.2(i)): say plainly that Nutmeg is AI.
        ("Nutmeg is an AI helper", "Nutmeg is a computer character, not a person. Her words, the story and the printed pages are made by AI and checked for kid safety. The first time your child plays, she tells them she's a pretend helper made by a computer. AI can get things wrong: if something seems off, use Report a problem in Grown-ups."),
        ("No accounts, ads or tracking", "There's nothing to sign up for. PretendThat has no ads and doesn't track you or your child."),
        ("You're in charge", "Delete any game in Saved games. Unsaved games are gone when you leave them."),
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
