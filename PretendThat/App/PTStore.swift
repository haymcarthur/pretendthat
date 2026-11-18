import StoreKit
import UIKit
import NutmegCore

/// Round 32 + round 38: the StoreKit 2 bridge. Products, purchases, the current entitlement (Transaction.currentEntitlements
/// plus a Transaction.updates listener), Restore (AppStore.sync) and Apple's Manage sheet. The rules and the words are
/// NutmegCore's (`StoreProducts`, `PlanEntitlement`, `ShowAllowance`, `PurchaseOutcome`, `PriceText`), tested there.
/// Nothing about kids: product IDs, dates and a transaction's JWS (sent to the relay for counting, never stored).
@Observable @MainActor
final class PTPurchases {
    /// The four plans, by product ID (empty until the App Store answers).
    private(set) var products: [String: Product] = [:]
    private(set) var loadingProducts = false
    private(set) var productsFailed = false
    /// The active plan (nil = the Free Preview).
    private(set) var entitlement: PlanEntitlement?
    /// Intro offer eligibility per subscription group (one group: one answer).
    private(set) var introEligible = true
    /// A purchase waiting on Ask to Buy / a bank check.
    private(set) var pendingProductID: String?
    /// A Buy is in flight.
    private(set) var buying: String?
    /// Called when the entitlement changes (AppModel refreshes the plan status).
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var updates: Task<Void, Never>?

    var status: PlanStatus { entitlement?.status ?? .none }

    /// At launch: listen for updates (renewals, Ask to Buy approvals, refunds, purchases on other devices), then load.
    func start() {
        guard updates == nil else { return }
        updates = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let t) = result {
                    rtLog("STORE update: \(t.productID) \(t.revocationDate == nil ? "" : "revoked ")\(t.expirationDate.map { "until \($0)" } ?? "")")
                    if t.productID == self.pendingProductID { self.pendingProductID = nil }
                    await t.finish()
                } else {
                    rtLog("STORE update: unverified transaction ignored")
                }
                await self.refresh()
            }
        }
        Task { await loadProducts(); await refresh() }
    }

    func loadProducts() async {
        guard !loadingProducts else { return }
        loadingProducts = true; productsFailed = false
        do {
            let list = try await Product.products(for: StoreProducts.all)
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            if let any = list.first(where: { $0.subscription != nil }), let sub = any.subscription {
                introEligible = await sub.isEligibleForIntroOffer
            }
            productsFailed = list.isEmpty
            rtLog("STORE products: \(list.count) loaded, intro eligible \(introEligible)")
        } catch {
            productsFailed = true
            rtLog("STORE products failed: \(error)")
        }
        loadingProducts = false
    }

    /// Reads Transaction.currentEntitlements: the best verified, unrevoked, unexpired plan.
    func refresh() async {
        var list: [PlanEntitlement] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result else { continue }
            if let e = PlanEntitlement.from(productID: t.productID, purchaseDate: t.purchaseDate, expirationDate: t.expirationDate,
                                            revoked: t.revocationDate != nil, jws: result.jwsRepresentation) {
                list.append(e)
            }
        }
        let best = PlanEntitlement.best(list)
        if best != entitlement {
            rtLog("STORE entitlement: \(best.map { "\($0.tier.name) (\($0.productID))" } ?? "none (Free Preview)")")
            entitlement = best
            onChange?()
        }
        if let s = products.values.first(where: { $0.subscription != nil })?.subscription {
            introEligible = await s.isEligibleForIntroOffer
        }
    }

    /// Buy a plan. Shows Apple's purchase sheet; pending (Ask to Buy) arrives later through `Transaction.updates`.
    func purchase(_ productID: String) async -> PurchaseOutcome {
        // Anonymous counts: the plan name and period only (fixed words), then the outcome's category.
        let plan = PlanValue(productID: productID), period = PeriodValue(productID: productID)
        Analytics.send(.purchaseStarted(plan, period))
        let outcome = await purchaseNow(productID)
        Analytics.send(.purchaseFinished(plan, period, PurchaseResultValue(outcome)))
        return outcome
    }

    private func purchaseNow(_ productID: String) async -> PurchaseOutcome {
        guard AppStore.canMakePayments else { return .failed(.notAvailable) }
        if products[productID] == nil { await loadProducts() }
        guard let product = products[productID] else { return .failed(.productMissing) }
        buying = productID
        defer { buying = nil }
        do {
            let result = try await product.purchase(options: Self.purchaseOptions())
            switch result {
            case .success(let verification):
                guard case .verified(let t) = verification else {
                    rtLog("STORE purchase unverified: \(productID)")
                    return .failed(.unverified)
                }
                await t.finish()
                pendingProductID = nil
                await refresh()
                rtLog("STORE purchased \(productID)")
                return .purchased(StoreProducts.tier(for: productID) ?? .showPass)
            case .pending:
                pendingProductID = productID
                rtLog("STORE purchase pending (Ask to Buy): \(productID)")
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed(.other)
            }
        } catch {
            rtLog("STORE purchase failed: \(error)")
            return .failed(Self.purchaseFailure(error))
        }
    }

    /// Purchase options. No app account token: nothing ties a purchase to a person here.
    private static func purchaseOptions() -> Set<Product.PurchaseOption> { [] }

    static func purchaseFailure(_ error: Error) -> PurchaseFailure {
        if let e = error as? StoreKitError {
            switch e {
            case .networkError: return .network
            case .notAvailableInStorefront, .notEntitled: return .notAvailable
            default: return .other
            }
        }
        if let p = error as? Product.PurchaseError {
            switch p {
            case .purchaseNotAllowed: return .notAvailable
            case .productUnavailable: return .productMissing
            default: return .other
            }
        }
        if (error as NSError).domain == NSURLErrorDomain { return .network }
        return .other
    }

    /// The Free Preview's proof for the relay: the AppTransaction JWS (no purchase needed).
    func appTransactionJWS() async -> String? {
        guard let r = try? await AppTransaction.shared else { return nil }
        return r.jwsRepresentation
    }
}

// MARK: - One plan's localized price (from the StoreKit product; PlanCatalog's numbers until it loads)

struct PlanPrice {
    let tier: PlanTier
    let period: BillingPeriod
    let productID: String
    let regular: String
    let intro: String?
    let introPeriods: Int
    let eligible: Bool
    let loaded: Bool

    @MainActor init(_ tier: PlanTier, _ period: BillingPeriod, purchases: PTPurchases) {
        self.tier = tier; self.period = period
        productID = StoreProducts.productID(tier, period) ?? ""
        let offer = tier == .seasonPass ? PlanCatalog.seasonPass : PlanCatalog.showPass
        if let p = purchases.products[productID] {
            loaded = true
            regular = p.displayPrice
            if let o = p.subscription?.introductoryOffer, o.paymentMode == .payAsYouGo || o.paymentMode == .payUpFront {
                intro = o.displayPrice
                introPeriods = o.paymentMode == .payAsYouGo ? o.periodCount : 1
            } else { intro = nil; introPeriods = 0 }
        } else {
            loaded = false
            regular = PlanCatalog.dollarsText(period == .monthly ? offer.monthly : offer.yearly)
            // Round 44: yearly has an intro too (the first year, paid up front).
            intro = PlanCatalog.dollarsText(period == .monthly ? offer.monthlyIntro : offer.yearlyIntro)
            introPeriods = period == .monthly ? offer.introMonths : 1
        }
        eligible = purchases.introEligible
    }

    var billed: String { PriceText.billed(regular: regular, intro: intro, eligible: eligible, period: period) }
    /// The big number alone ("$9.99").
    var billedAmount: String { eligible ? (intro ?? regular) : regular }
    var introThen: String? { PriceText.introThen(regular: regular, intro: intro, introPeriods: introPeriods, eligible: eligible, period: period) }
    var full: String { PriceText.full(regular: regular, intro: intro, introPeriods: introPeriods, eligible: eligible, period: period) }
    /// Onboarding v3's plan row: ("$9.99/mo", "for 12 months, then $14.99/mo").
    var row: (amount: String, then: String?) {
        PriceText.rowParts(regular: regular, intro: intro, introPeriods: introPeriods, eligible: eligible, period: period)
    }
}

/// Round 32: Restore and Manage (static; used by the Grown-ups screens and the plans).
@MainActor
enum PTStore {
    /// The product IDs of the verified, unrevoked current entitlements.
    static func entitlementProductIDs() async -> [String] {
        var ids: [String] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.revocationDate == nil { ids.append(t.productID) }
        }
        return ids
    }

    static func planStatus() async -> PlanStatus { PlanStatus.from(productIDs: await entitlementProductIDs()) }

    /// `AppStore.sync()` (may ask the grown-up to sign in to their Apple ID), then the entitlement count.
    static func restore() async -> RestoreOutcome {
        let outcome = await restoreNow()
        Analytics.send(.restoreFinished(RestoreResultValue(outcome)))
        return outcome
    }

    private static func restoreNow() async -> RestoreOutcome {
        guard AppStore.canMakePayments else { return .after(.failure(.notAvailable)) }
        do {
            try await AppStore.sync()
            let n = await entitlementProductIDs().count
            rtLog("grown-ups: restore synced, \(n) entitlement(s)")
            return .after(.success(n))
        } catch {
            rtLog("grown-ups: restore failed: \(error)")
            return .after(.failure(failure(error)))
        }
    }

    static func failure(_ error: Error) -> RestoreFailure {
        if let e = error as? StoreKitError {
            switch e {
            case .userCancelled: return .userCancelled
            case .networkError: return .network
            case .notAvailableInStorefront, .notEntitled: return .notAvailable
            default: return .other
            }
        }
        if (error as NSError).domain == NSURLErrorDomain { return .network }
        return .other
    }

    /// Apple's subscription management sheet over the active window scene. False when it couldn't be shown.
    static func showManageSubscriptions() async -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return false }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            return true
        } catch {
            rtLog("grown-ups: manage subscriptions failed: \(error)")
            return false
        }
    }
}
