import Foundation

// Round 38: StoreKit subscriptions (decisions/2026-11-17-storekit-subscriptions.md). StoreKit calls live in the app
// (App/PTPurchases.swift); the product IDs, the plan → allowance rules, the on-device period counter, the price wording
// and the relay show-start protocol live here so they're tested. Nothing about kids: product IDs, dates and counts.

// MARK: - Products (THE one place for product IDs; Haylee creates the same IDs in App Store Connect)

public enum PlanTier: String, CaseIterable, Sendable, Codable {
    case freePreview, showPass, seasonPass

    public var name: String {
        switch self {
        case .freePreview: "Free Preview"
        case .showPass: "Show Pass"
        case .seasonPass: "Season Pass"
        }
    }

    /// New shows: Free Preview 2 in total; Show Pass 10 a month; Season Pass 30 a month. Replays are always free.
    public var allowance: Int {
        switch self {
        case .freePreview: PlanCatalog.freePreviewShows
        case .showPass: PlanCatalog.showPassShows
        case .seasonPass: PlanCatalog.seasonPassShows
        }
    }

    /// Paid plans count per month; the Free Preview counts once, ever.
    public var isPaid: Bool { self != .freePreview }
}

public enum StoreProducts {
    /// The one subscription group (App Store Connect → Subscriptions). Season Pass is level 1 (the higher plan),
    /// Show Pass level 2, so moving between them is an upgrade / downgrade, never two subscriptions at once.
    public static let groupName = "PretendThat Passes"

    public static let showPassMonthly = "app.pretendthat.showpass.monthly"
    public static let showPassYearly = "app.pretendthat.showpass.yearly"
    public static let seasonPassMonthly = "app.pretendthat.seasonpass.monthly"
    public static let seasonPassYearly = "app.pretendthat.seasonpass.yearly"
    public static let all = [showPassMonthly, showPassYearly, seasonPassMonthly, seasonPassYearly]

    public static func productID(_ tier: PlanTier, _ period: BillingPeriod) -> String? {
        switch (tier, period) {
        case (.showPass, .monthly): showPassMonthly
        case (.showPass, .yearly): showPassYearly
        case (.seasonPass, .monthly): seasonPassMonthly
        case (.seasonPass, .yearly): seasonPassYearly
        case (.freePreview, _): nil
        }
    }

    /// The App Store display name and description of each product (the same words in StoreKit/PretendThat.storekit
    /// and App Store Connect). Round 44: "game", never "show"; the IDs never change.
    public static let groupDescription = "New pretend-play games with Nutmeg every month"
    public static func displayName(_ productID: String) -> String? {
        guard let tier = tier(for: productID), let period = period(for: productID) else { return nil }
        return period == .yearly ? "\(tier.name) (Yearly)" : tier.name
    }
    public static func storeDescription(_ productID: String) -> String? {
        guard let tier = tier(for: productID) else { return nil }
        return "\(tier.allowance) new games a month. Saved games are free to play again."
    }

    public static func tier(for productID: String) -> PlanTier? {
        switch productID {
        case showPassMonthly, showPassYearly: .showPass
        case seasonPassMonthly, seasonPassYearly: .seasonPass
        default: nil
        }
    }

    public static func period(for productID: String) -> BillingPeriod? {
        switch productID {
        case showPassMonthly, seasonPassMonthly: .monthly
        case showPassYearly, seasonPassYearly: .yearly
        default: nil
        }
    }
}

// MARK: - Entitlement and the monthly window

/// The active plan, from the newest verified, unrevoked, unexpired entitlement (StoreKit `Transaction`).
public struct PlanEntitlement: Equatable, Sendable {
    public let productID: String
    public let tier: PlanTier
    /// The current billing period's start (each renewal is a new transaction with its own purchase date).
    public let purchaseDate: Date
    public let expirationDate: Date?
    /// StoreKit's JWS of the transaction (sent to the relay for server-side counting; never stored).
    public let jws: String?

    public init(productID: String, tier: PlanTier, purchaseDate: Date, expirationDate: Date?, jws: String? = nil) {
        self.productID = productID; self.tier = tier; self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate; self.jws = jws
    }

    /// From one transaction's fields. nil for a product that isn't a plan, a revoked one or an expired one.
    public static func from(productID: String, purchaseDate: Date, expirationDate: Date?, revoked: Bool,
                            now: Date = Date(), jws: String? = nil) -> PlanEntitlement? {
        guard let tier = StoreProducts.tier(for: productID), !revoked else { return nil }
        if let e = expirationDate, e <= now { return nil }
        return PlanEntitlement(productID: productID, tier: tier, purchaseDate: purchaseDate, expirationDate: expirationDate, jws: jws)
    }

    /// The best of several entitlements (Season Pass over Show Pass, then the newest).
    public static func best(_ list: [PlanEntitlement]) -> PlanEntitlement? {
        list.max { a, b in
            if a.tier != b.tier { return a.tier == .showPass }
            return a.purchaseDate < b.purchaseDate
        }
    }

    /// The month the allowance counts in: monthly windows anchored on the period's purchase date (a yearly plan still
    /// gets its shows per month). The window's key is the tier + its start, so a renewal or an upgrade starts fresh.
    public func window(now: Date = Date(), calendar: Calendar = ShowWindow.calendar) -> ShowWindow {
        ShowWindow.containing(now, anchor: purchaseDate, tier: tier, calendar: calendar)
    }

    public var status: PlanStatus { .active(name: tier.name) }
}

public struct ShowWindow: Equatable, Sendable {
    public let tier: PlanTier
    public let start: Date
    public let end: Date
    public var key: String { "\(tier.rawValue)@\(Int(start.timeIntervalSince1970))" }

    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }

    /// The monthly window [start, end) that holds `now`, counting whole months from `anchor`.
    public static func containing(_ now: Date, anchor: Date, tier: PlanTier, calendar: Calendar = calendar) -> ShowWindow {
        guard now > anchor else {
            return ShowWindow(tier: tier, start: anchor, end: calendar.date(byAdding: .month, value: 1, to: anchor) ?? anchor)
        }
        var months = max(calendar.dateComponents([.month], from: anchor, to: now).month ?? 0, 0)
        var start = calendar.date(byAdding: .month, value: months, to: anchor) ?? anchor
        // dateComponents can land one month early or late around month ends: settle so start <= now < end.
        while start > now, months > 0 { months -= 1; start = calendar.date(byAdding: .month, value: months, to: anchor) ?? anchor }
        var end = calendar.date(byAdding: .month, value: months + 1, to: anchor) ?? now
        while end <= now { months += 1; start = end; end = calendar.date(byAdding: .month, value: months + 1, to: anchor) ?? now }
        return ShowWindow(tier: tier, start: start, end: end)
    }
}

// MARK: - The on-device counter (a window key and a number; nothing about kids)

public enum ShowCountKeys {
    /// The window the count belongs to (`ShowWindow.key`, a tier name and a timestamp).
    public static let window = "pt.shows.window"
    /// NEW shows started in that window (replays never count).
    public static let used = "pt.shows.used"
}

public final class PlanShowCounter {
    let defaults: OnboardingDefaults
    public init(defaults: OnboardingDefaults) { self.defaults = defaults }

    /// New shows started in `window` (0 when the stored count is for another window).
    public func used(in window: ShowWindow) -> Int {
        defaults.string(forKey: ShowCountKeys.window) == window.key ? defaults.integer(forKey: ShowCountKeys.used) : 0
    }

    /// A game started in `window`. Only a NEW game counts. Returns the window's count.
    @discardableResult
    public func gameStarted(in window: ShowWindow, isReplay: Bool) -> Int {
        guard !isReplay else { return used(in: window) }
        let n = used(in: window) + 1
        defaults.set(window.key, forKey: ShowCountKeys.window)
        defaults.set(n, forKey: ShowCountKeys.used)
        return n
    }

    public func reset() {
        defaults.removeObject(forKey: ShowCountKeys.window)
        defaults.removeObject(forKey: ShowCountKeys.used)
    }
}

// MARK: - The allowance

/// What's left right now: the Free Preview (2 in total) or the plan's monthly shows.
public struct ShowAllowance: Equatable, Sendable {
    public let tier: PlanTier
    public let used: Int
    /// When the plan's next shows arrive (the window's end); nil for the Free Preview.
    public let refillsAt: Date?

    public init(tier: PlanTier, used: Int, refillsAt: Date?) {
        self.tier = tier; self.used = used; self.refillsAt = refillsAt
    }

    public var allowance: Int { tier.allowance }
    public var remaining: Int { max(allowance - used, 0) }
    public var exhausted: Bool { remaining == 0 }

    public static func current(entitlement: PlanEntitlement?, freeUsed: Int, counter: PlanShowCounter, now: Date = Date()) -> ShowAllowance {
        guard let e = entitlement else { return ShowAllowance(tier: .freePreview, used: freeUsed, refillsAt: nil) }
        let w = e.window(now: now)
        return ShowAllowance(tier: e.tier, used: counter.used(in: w), refillsAt: w.end)
    }

    /// "7 of 10 new games left this month" / "1 of 2 free new games left".
    public var summary: String {
        tier.isPaid ? "\(remaining) of \(allowance) new games left this month" : "\(remaining) of \(allowance) free new games left"
    }

    /// "More new games arrive Dec 3." (paid plans only).
    public func refillText(locale: Locale = .current) -> String? {
        guard tier.isPaid, let r = refillsAt else { return nil }
        let f = DateFormatter(); f.locale = locale; f.setLocalizedDateFormatFromTemplate("MMMd")
        return "More new games arrive \(f.string(from: r))."
    }
}

extension NewGameGate {
    /// Round 38: New game with the real allowance. No consent → the explanation; shows left → start; Free Preview
    /// used up → the plans; a paid plan's month used up → `.outOfShows` (the grown-up's plans screen says when more
    /// arrive). Replays never come here (they're always free).
    public static func newGame(consent: Bool, allowance: ShowAllowance) -> NewGameGate {
        guard consent else { return .needsConsent }
        if !allowance.exhausted { return .start }
        return allowance.tier.isPaid ? .outOfShows : .needsPlan
    }
}

// MARK: - Purchases

public enum PurchaseFailure: Error, Equatable, Sendable {
    case network, notAvailable, unverified, productMissing, other
}

/// What a Buy tap ended in (StoreKit's `Product.PurchaseResult` and errors, mapped by the app).
public enum PurchaseOutcome: Equatable, Sendable {
    case purchased(PlanTier)
    /// Ask to Buy or a bank check: nothing to do until it's approved (it then arrives through Transaction.updates).
    case pending
    case cancelled
    case failed(PurchaseFailure)

    public var message: String {
        switch self {
        case .purchased(let t): "Thank you! \(t.name) is active. \(t.allowance) new games a month, and playing a saved game again is always free."
        case .pending: "Waiting for approval. If Ask to Buy is on, the family organizer can approve it. The plan starts as soon as it's approved."
        case .cancelled: "No problem. Nothing was bought."
        case .failed(.network): "Couldn't reach the App Store. Check the Wi-Fi and try again."
        case .failed(.notAvailable): "Purchases aren't available on this \(DeviceWord.noun) right now. Check Screen Time's purchase settings."
        case .failed(.unverified): "The App Store couldn't confirm that purchase. Nothing was charged here. Try Restore purchases."
        case .failed(.productMissing): "This plan can't be loaded right now. Please try again in a moment."
        case .failed(.other): "Something went wrong. Please try again in a moment."
        }
    }

    public var succeeded: Bool { if case .purchased = self { true } else { false } }
}

// MARK: - Price wording (localized prices come from StoreKit's displayPrice)

public enum PriceText {
    /// "/month" or "/year".
    public static func unit(_ period: BillingPeriod) -> String { period == .monthly ? "month" : "year" }

    /// The price billed first, the most prominent number (3.1.2): the intro price when eligible, else the regular one.
    public static func billed(regular: String, intro: String?, eligible: Bool, period: BillingPeriod) -> String {
        "\(eligible ? (intro ?? regular) : regular)/\(unit(period))"
    }

    /// The line under it, with the renewal price visible: "for 12 months, then $14.99/month", or nil with no offer.
    public static func introThen(regular: String, intro: String?, introPeriods: Int, eligible: Bool, period: BillingPeriod) -> String? {
        guard eligible, intro != nil, introPeriods > 0 else { return nil }
        let u = unit(period)
        let n = introPeriods == 1 ? "1 \(u)" : "\(introPeriods) \(u)s"
        return "for \(n), then \(regular)/\(u)"
    }

    /// VoiceOver / one-line form: "$9.99/month for 12 months, then $14.99/month".
    public static func full(regular: String, intro: String?, introPeriods: Int, eligible: Bool, period: BillingPeriod) -> String {
        let b = billed(regular: regular, intro: intro, eligible: eligible, period: period)
        guard let t = introThen(regular: regular, intro: intro, introPeriods: introPeriods, eligible: eligible, period: period) else { return b }
        return "\(b) \(t)"
    }

    /// "mo" or "yr" (onboarding v3's compact plan rows).
    public static func shortUnit(_ period: BillingPeriod) -> String { period == .monthly ? "mo" : "yr" }

    /// Onboarding v3's plan row, the renewal price in plain words: ("$9.99/mo", "for 12 months, then $14.99/mo"), or
    /// ("$14.99/mo", nil) with no offer (the bold amount is the price billed first).
    public static func rowParts(regular: String, intro: String?, introPeriods: Int, eligible: Bool,
                                period: BillingPeriod) -> (amount: String, then: String?) {
        let u = shortUnit(period)
        guard eligible, let intro, introPeriods > 0 else { return ("\(regular)/\(u)", nil) }
        let long = unit(period)
        let n = introPeriods == 1 ? "1 \(long)" : "\(introPeriods) \(long)s"
        return ("\(intro)/\(u)", "for \(n), then \(regular)/\(u)")
    }

    /// The buy button: "Subscribe · $9.99/month".
    public static func buyLabel(_ tier: PlanTier, billed: String) -> String { "Get \(tier.name) · \(billed)" }
}

// MARK: - Relay show counts (anonymous server-side enforcement; off until the relay is deployed with it)

/// The relay's `POST /v1/shows/start`: the app sends StoreKit's signed proof (the plan's transaction JWS, or the
/// AppTransaction JWS for the Free Preview); the relay verifies it against Apple's root, counts the new show under a
/// one-way hash, and returns a short-lived show ticket that the guide and kit calls carry (`X-PT-Show`).
public enum RelayShows {
    public static let path = "v1/shows/start"
    public static let ticketHeader = "X-PT-Show"
    /// Info.plist key (Relay.xcconfig `RELAY_SHOW_LIMITS = YES`): the app asks the relay before a new show.
    public static let flagKey = "RELAY_SHOW_LIMITS"

    public static func enabled(info: [String: Any]) -> Bool {
        guard let v = InfoValue.string(info, flagKey)?.lowercased() else { return false }
        return v == "yes" || v == "true" || v == "1"
    }

    public enum Proof: Equatable, Sendable {
        case subscription(jws: String)
        case preview(jws: String)
    }

    public static func request(relay: RelayConfig, proof: Proof) -> URLRequest {
        var req = URLRequest(url: relay.url.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.timeoutInterval = 6
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(relay.token, forHTTPHeaderField: RelayConfig.tokenHeader)
        let body: [String: String]
        switch proof {
        case .subscription(let jws): body = ["kind": "subscription", "jws": jws]
        case .preview(let jws): body = ["kind": "preview", "jws": jws]
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return req
    }

    public enum Decision: Equatable, Sendable {
        /// Counted: carry the ticket on this show's guide and kit calls.
        case allowed(ticket: String?, remaining: Int?)
        /// The relay says this plan's shows are used up (HTTP 402 with `limit_reached`).
        case limitReached
        /// The relay doesn't know the endpoint (404, not deployed yet) or couldn't answer: allow (fail open).
        case allowUnknown
    }

    public static func decode(data: Data?, status: Int?) -> Decision {
        guard let status else { return .allowUnknown }
        let obj = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        if (200..<300).contains(status) {
            return .allowed(ticket: obj?["ticket"] as? String, remaining: obj?["remaining"] as? Int)
        }
        // The relay's errors are {"error": {"type": …, "message": …}}; a bare string is accepted too.
        let type = (obj?["error"] as? [String: Any])?["type"] as? String ?? obj?["error"] as? String
        if status == 402, type == "limit_reached" { return .limitReached }
        return .allowUnknown
    }
}

/// The current new show's relay ticket (set when a show starts, cleared at home). Relay-mode guide and kit requests
/// carry it. A game-content token only: an opaque string from the relay, nothing about kids.
public enum ShowTicket {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var value: String?
    public static var current: String? { lock.withLock { value } }
    public static func set(_ t: String?) { lock.withLock { value = t } }

    /// Adds the ticket header to a relay request (no-op without a ticket).
    public static func attach(to req: inout URLRequest) {
        if let t = current { req.setValue(t, forHTTPHeaderField: RelayShows.ticketHeader) }
    }
}
