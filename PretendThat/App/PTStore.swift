import StoreKit
import UIKit
import NutmegCore

/// Round 32: the thin StoreKit 2 bridge for the Grown-ups menu (Manage subscription, Restore purchases). No products
/// exist yet, so the entitlements are empty and the screens say "No active plan yet" / "Nothing to restore yet". The
/// plan and result wording is NutmegCore's (`PlanStatus`, `RestoreOutcome`), tested there. Purchases come later.
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
