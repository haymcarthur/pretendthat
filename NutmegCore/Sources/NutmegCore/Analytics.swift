import Foundation

// Anonymous usage counts (decisions/2026-11-16-analytics-telemetrydeck.md, 2026-11-17-analytics-build.md).
//
// The hard rule: NOTHING about kids. Every event below is a fixed name, and every parameter value is the raw value of a
// small fixed enum (`AnalyticsValue`). No event can carry a String, a number or a date the app made up at runtime:
// no names, voices, transcripts, generated text (titles, roles, story), free text or device identifiers. The game's
// theme is reduced ON THE iPad to one of 8 coarse categories (`GameCategory.from(title:)`); the title never leaves.
// The app's `Analytics` wrapper is the only caller of TelemetryDeck and it only sends `AnalyticsEvent.signal`.

/// A parameter value: a fixed, finite list of short ASCII words. The only kind of value an event can hold.
public protocol AnalyticsValue: RawRepresentable, CaseIterable, Sendable where RawValue == String {}

public enum OnboardingPageValue: String, AnalyticsValue {
    case hello, howItWorks, needs, privacy, plans, handOff
    public init(_ screen: OnboardingScreen) { self = OnboardingPageValue(rawValue: screen.rawValue) ?? .hello }
}

public enum OnboardingExitValue: String, AnalyticsValue {
    case firstGame, home
    public init(_ exit: OnboardingExit) { self = OnboardingExitValue(rawValue: exit.rawValue) ?? .home }
}

public enum AnswerValue: String, AnalyticsValue { case yes, no }

/// The 4 steps on the step rail.
public enum StepValue: String, AnalyticsValue {
    case pick, props, print, play
    public init(_ step: JourneyStep) {
        switch step { case .game: self = .pick; case .getReady: self = .props; case .print: self = .print; case .play: self = .play }
    }
}

/// Where a scene sits in the show (play scenes by number; a 4th or later play scene is `playMore`).
public enum SceneValue: String, AnalyticsValue {
    case story, setup, play1, play2, play3, playMore, cleanup
    public static func from(arc: SceneKind, playNumber: Int) -> SceneValue {
        switch arc {
        case .story: .story
        case .setup: .setup
        case .cleanup: .cleanup
        case .play: playNumber <= 1 ? .play1 : playNumber == 2 ? .play2 : playNumber == 3 ? .play3 : .playMore
        }
    }
}

/// How many kids: 1, 2–3, 4 or more (0 = not known yet).
public enum PlayersValue: String, AnalyticsValue {
    case unknown, one, twoToThree, fourPlus
    public init(count: Int) {
        switch count { case ...0: self = .unknown; case 1: self = .one; case 2...3: self = .twoToThree; default: self = .fourPlus }
    }
}

/// A coarse length of time.
public enum DurationValue: String, AnalyticsValue {
    case under1m, from1to5m, from5to15m, from15to30m, from30to60m, over60m
    public init(seconds: TimeInterval) {
        switch seconds {
        case ..<60: self = .under1m
        case ..<300: self = .from1to5m
        case ..<900: self = .from5to15m
        case ..<1800: self = .from15to30m
        case ..<3600: self = .from30to60m
        default: self = .over60m
        }
    }
}

public enum GameKindValue: String, AnalyticsValue { case new, replay }

public enum PrintSetValue: String, AnalyticsValue {
    case fullColor, colorIn
    public init(_ style: PrintStyle) { self = style == .fullColor ? .fullColor : .colorIn }
}

/// The game's theme as one of 8 fixed categories, decided on the iPad from the title. The title is never sent.
public enum GameCategory: String, AnalyticsValue {
    case food, shop, care, travel, adventure, community, show, other

    /// Keywords per category (from `Suggestions.games` plus a few common words). First match wins, in this order.
    static let keywords: [(GameCategory, [String])] = [
        (.care, ["vet", "doctor", "hospital", "dentist", "nurse", "clinic", "animal rescue"]),
        (.food, ["restaurant", "bakery", "pizza", "ice cream", "lemonade", "cooking", "tea party", "cafe", "café", "diner",
                 "kitchen", "snack", "food truck", "donut", "cupcake", "chef"]),
        (.shop, ["grocery", "toy shop", "toy store", "flower", "hair salon", "salon", "groomer", "car wash", "post office",
                 "hotel", "mail", "shop", "store", "market", "bank"]),
        (.travel, ["airplane", "plane", "train", "bus", "rocket", "space", "submarine", "ship", "boat", "camping", "road trip",
                   "trip", "moon", "mars", "cruise"]),
        (.adventure, ["treasure", "dinosaur", "detective", "mystery", "knight", "castle", "bird", "safari", "jungle",
                      "explorer", "pirate", "dragon", "quest"]),
        (.community, ["firefight", "fire station", "library", "school", "museum", "construction", "farm", "zoo", "weather",
                      "police", "garden", "aquarium"]),
        (.show, ["circus", "puppet", "band", "orchestra", "concert", "show", "dance", "theater", "theatre", "magic"]),
    ]

    public static func from(title: String?) -> GameCategory {
        guard let t = title?.lowercased(), !t.isEmpty else { return .other }
        for (category, words) in keywords where words.contains(where: { t.contains($0) }) { return category }
        return .other
    }
}

public enum PaywallSourceValue: String, AnalyticsValue {
    /// The kid card's "Grown-ups" button after the Free Preview or the month's shows ran out (behind the gate).
    case showsUsedUp
    /// Grown-ups → Plans.
    case grownUps
    /// Onboarding page 6.
    case onboarding
}

public enum PlanValue: String, AnalyticsValue {
    case freePreview, showPass, seasonPass, unknown
    public init(_ tier: PlanTier?) {
        switch tier { case .freePreview?: self = .freePreview; case .showPass?: self = .showPass; case .seasonPass?: self = .seasonPass; case nil: self = .unknown }
    }
    public init(productID: String) { self.init(StoreProducts.tier(for: productID)) }
}

public enum PeriodValue: String, AnalyticsValue {
    case monthly, yearly, unknown
    public init(productID: String) {
        switch StoreProducts.period(for: productID) { case .monthly?: self = .monthly; case .yearly?: self = .yearly; case nil: self = .unknown }
    }
}

public enum PurchaseResultValue: String, AnalyticsValue {
    case succeeded, pending, cancelled, failedNetwork, failedNotAllowed, failedUnverified, failedProductMissing, failedOther
    public init(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .purchased: self = .succeeded
        case .pending: self = .pending
        case .cancelled: self = .cancelled
        case .failed(.network): self = .failedNetwork
        case .failed(.notAvailable): self = .failedNotAllowed
        case .failed(.unverified): self = .failedUnverified
        case .failed(.productMissing): self = .failedProductMissing
        case .failed(.other): self = .failedOther
        }
    }
}

public enum RestoreResultValue: String, AnalyticsValue {
    case restored, nothingToRestore, cancelled, offline, unavailable, failed
    public init(_ outcome: RestoreOutcome) {
        switch outcome {
        case .restored: self = .restored
        case .nothingToRestore: self = .nothingToRestore
        case .cancelled: self = .cancelled
        case .offline: self = .offline
        case .unavailable: self = .unavailable
        case .failed: self = .failed
        }
    }
}

/// Error categories (never the error's text).
public enum ErrorValue: String, AnalyticsValue {
    /// Claude / the relay didn't answer: the game fell back to the built-in airplane game.
    case aiUnavailable
    /// Nutmeg's voice session couldn't connect at the start of a game (the tap screens took over).
    case voiceConnectFailed
    /// On-device speech isn't available (the kids type instead).
    case speechUnavailable
    /// Saving a game to this iPad failed.
    case saveFailed
}

/// Every event the app can send. Associated values are `AnalyticsValue` enums ONLY (tested by reflection).
public enum AnalyticsEvent: Equatable, Sendable {
    case onboardingPageReached(OnboardingPageValue)
    case onboardingFinished(OnboardingExitValue, DurationValue)
    case consentAnswered(AnswerValue)
    case micAnswered(AnswerValue)
    case newGameStarted
    case stepReached(StepValue, GameKindValue, PlayersValue)
    case kitPrinted(PrintSetValue, PlayersValue)
    case sceneReached(SceneValue, GameKindValue, PlayersValue)
    case gameFinished(GameKindValue, PlayersValue, GameCategory, DurationValue)
    case gameSaved(PlayersValue, GameCategory)
    case replayStarted(GameCategory)
    case paywallShown(PaywallSourceValue)
    case purchaseStarted(PlanValue, PeriodValue)
    case purchaseFinished(PlanValue, PeriodValue, PurchaseResultValue)
    case restoreFinished(RestoreResultValue)
    case reportProblemOpened
    case error(ErrorValue)

    /// The signal as TelemetryDeck gets it: a fixed name and fixed-word parameters.
    public var signal: (name: String, parameters: [String: String]) {
        switch self {
        case .onboardingPageReached(let p): ("Onboarding.pageReached", ["page": p.rawValue])
        case .onboardingFinished(let e, let d): ("Onboarding.finished", ["exit": e.rawValue, "duration": d.rawValue])
        case .consentAnswered(let a): ("Onboarding.aiConsent", ["answer": a.rawValue])
        case .micAnswered(let a): ("Onboarding.microphone", ["answer": a.rawValue])
        case .newGameStarted: ("Game.started", [:])
        case .stepReached(let s, let k, let p): ("Game.stepReached", ["step": s.rawValue, "kind": k.rawValue, "players": p.rawValue])
        case .kitPrinted(let s, let p): ("Game.kitPrinted", ["set": s.rawValue, "players": p.rawValue])
        case .sceneReached(let s, let k, let p): ("Game.sceneReached", ["scene": s.rawValue, "kind": k.rawValue, "players": p.rawValue])
        case .gameFinished(let k, let p, let c, let d):
            ("Game.finished", ["kind": k.rawValue, "players": p.rawValue, "category": c.rawValue, "duration": d.rawValue])
        case .gameSaved(let p, let c): ("Game.saved", ["players": p.rawValue, "category": c.rawValue])
        case .replayStarted(let c): ("Replay.started", ["category": c.rawValue])
        case .paywallShown(let s): ("Paywall.shown", ["source": s.rawValue])
        case .purchaseStarted(let p, let per): ("Purchase.started", ["plan": p.rawValue, "period": per.rawValue])
        case .purchaseFinished(let p, let per, let r): ("Purchase.finished", ["plan": p.rawValue, "period": per.rawValue, "result": r.rawValue])
        case .restoreFinished(let r): ("Purchase.restore", ["result": r.rawValue])
        case .reportProblemOpened: ("GrownUps.reportProblemOpened", [:])
        case .error(let e): ("Error.occurred", ["category": e.rawValue])
        }
    }

    /// Every signal name the app can send.
    public static let signalNames: Set<String> = [
        "Onboarding.pageReached", "Onboarding.finished", "Onboarding.aiConsent", "Onboarding.microphone", "Game.started",
        "Game.stepReached", "Game.kitPrinted", "Game.sceneReached", "Game.finished", "Game.saved", "Replay.started",
        "Paywall.shown", "Purchase.started", "Purchase.finished", "Purchase.restore", "GrownUps.reportProblemOpened", "Error.occurred",
    ]

    /// Every parameter key, with every value it may hold.
    public static let allowedValues: [String: Set<String>] = [
        "page": raw(OnboardingPageValue.self), "exit": raw(OnboardingExitValue.self), "duration": raw(DurationValue.self),
        "answer": raw(AnswerValue.self), "step": raw(StepValue.self), "kind": raw(GameKindValue.self),
        "players": raw(PlayersValue.self), "set": raw(PrintSetValue.self), "scene": raw(SceneValue.self),
        "category": raw(GameCategory.self).union(raw(ErrorValue.self)), "source": raw(PaywallSourceValue.self),
        "plan": raw(PlanValue.self), "period": raw(PeriodValue.self),
        "result": raw(PurchaseResultValue.self).union(raw(RestoreResultValue.self)),
    ]

    static func raw<T: AnalyticsValue>(_: T.Type) -> Set<String> { Set(T.allCases.map(\.rawValue)) }

    /// Every event the app can send, with every combination of values (for the tests: proves the whole space is fixed).
    public static var everyEvent: [AnalyticsEvent] {
        func all<T: AnalyticsValue>(_: T.Type) -> [T] { Array(T.allCases) }
        var e: [AnalyticsEvent] = [.newGameStarted, .reportProblemOpened]
        e += all(OnboardingPageValue.self).map { .onboardingPageReached($0) }
        for x in all(OnboardingExitValue.self) { for d in all(DurationValue.self) { e.append(.onboardingFinished(x, d)) } }
        for a in all(AnswerValue.self) { e += [.consentAnswered(a), .micAnswered(a)] }
        for k in all(GameKindValue.self) {
            for p in all(PlayersValue.self) {
                e += all(StepValue.self).map { .stepReached($0, k, p) }
                e += all(SceneValue.self).map { .sceneReached($0, k, p) }
                for c in all(GameCategory.self) { for d in all(DurationValue.self) { e.append(.gameFinished(k, p, c, d)) } }
            }
        }
        for p in all(PlayersValue.self) {
            e += all(PrintSetValue.self).map { .kitPrinted($0, p) }
            e += all(GameCategory.self).map { .gameSaved(p, $0) }
        }
        e += all(GameCategory.self).map { .replayStarted($0) }
        e += all(PaywallSourceValue.self).map { .paywallShown($0) }
        for p in all(PlanValue.self) {
            for per in all(PeriodValue.self) {
                e.append(.purchaseStarted(p, per))
                e += all(PurchaseResultValue.self).map { .purchaseFinished(p, per, $0) }
            }
        }
        e += all(RestoreResultValue.self).map { .restoreFinished($0) }
        e += all(ErrorValue.self).map { .error($0) }
        return e
    }
}

// MARK: - The anonymous install id (round 44: no switch; counts are always on)

public enum AnalyticsKeys {
    /// Before round 44: a boolean for the grown-up's "Share anonymous usage counts" switch. The switch is gone
    /// (Haylee, decisions/2026-11-17-onboarding-v3-feedback.md, follow-up 2); the migration removes the stored answer.
    public static let legacyShare = "pt.analytics.share"
    /// A random UUID made on this iPad the first time counts are sent. Not the device's identifierForVendor
    /// (TelemetryDeck would otherwise use it); TelemetryDeck hashes it again before sending.
    public static let installID = "pt.analytics.installID"
    /// Info.plist key with the TelemetryDeck app ID (from the TELEMETRYDECK_APP_ID build setting; empty = no analytics).
    public static let appIDInfoKey = "TelemetryDeckAppID"
}

/// The random install id. Round 44: anonymous counts are always on whenever the build has a TelemetryDeck app ID
/// (no switch in onboarding or Grown-ups; disclosed in the privacy policy and in About what we save).
public final class AnalyticsSettings {
    let defaults: OnboardingDefaults
    public init(defaults: OnboardingDefaults) { self.defaults = defaults }

    /// Counts are always on (there's no switch). Kept so callers read one place.
    public var share: Bool { true }

    /// Existing installs move to ON: the old switch's stored answer (on or off) is removed. An install that had it
    /// off has no install id, so it gets a fresh random one on first use, like a new install.
    public func migrateToAlwaysOn() {
        defaults.removeObject(forKey: AnalyticsKeys.legacyShare)
    }

    /// The random install id (made on first use).
    public var installID: String {
        if let id = defaults.string(forKey: AnalyticsKeys.installID), UUID(uuidString: id) != nil { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: AnalyticsKeys.installID)
        return id
    }

    /// The TelemetryDeck app ID from the Info.plist, or nil (empty, missing or an unexpanded build setting) = no-op.
    public static func appID(info: [String: Any]?) -> String? {
        guard let raw = info?[AnalyticsKeys.appIDInfoKey] as? String else { return nil }
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !id.contains("$(") else { return nil }
        return id
    }
}

// MARK: - Per-game tracking (each step and scene counted once per game)

/// Turns the game's phase changes into events: each step and scene once per game, The End once, with coarse buckets.
public struct AnalyticsGameTracker: Sendable {
    public private(set) var kind: GameKindValue = .new
    public private(set) var startedAt: Date?
    var steps: Set<StepValue> = []
    var scenes: Set<SceneValue> = []
    var finished = false
    var didPrint = false
    var reportedErrors: Set<ErrorValue> = []

    public init() {}

    /// A new game or a replay began (a fresh slate).
    public mutating func begin(kind: GameKindValue, at now: Date = Date()) {
        self = AnalyticsGameTracker()
        self.kind = kind
        startedAt = now
    }

    /// The phase changed. `scenes` = the kit's scene kinds in order (to number the play scenes).
    public mutating func phase(_ phase: Phase, sceneKinds: [SceneKind], players: Int, title: String?,
                               now: Date = Date()) -> [AnalyticsEvent] {
        guard startedAt != nil else { return [] }
        let p = PlayersValue(count: players)
        var out: [AnalyticsEvent] = []
        if let step = phase.step.map(StepValue.init), steps.insert(step).inserted {
            out.append(.stepReached(step, kind, p))
        }
        if case .scene(let i) = phase, sceneKinds.indices.contains(i) {
            let playNumber = sceneKinds[...i].filter { $0 == .play }.count
            let s = SceneValue.from(arc: sceneKinds[i], playNumber: playNumber)
            if scenes.insert(s).inserted { out.append(.sceneReached(s, kind, p)) }
        }
        if phase == .end, !finished, let start = startedAt {
            finished = true
            out.append(.gameFinished(kind, p, GameCategory.from(title: title), DurationValue(seconds: now.timeIntervalSince(start))))
        }
        return out
    }

    /// The kit went to the printer (counted once per game).
    public mutating func printed(_ set: PrintStyle, players: Int) -> AnalyticsEvent? {
        guard !didPrint else { return nil }
        didPrint = true
        return .kitPrinted(PrintSetValue(set), PlayersValue(count: players))
    }

    /// An error category, once per game.
    public mutating func error(_ e: ErrorValue) -> AnalyticsEvent? {
        reportedErrors.insert(e).inserted ? .error(e) : nil
    }
}
