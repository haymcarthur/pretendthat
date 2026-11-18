import Foundation
import Testing
@testable import NutmegCore

/// Round 44 (decisions/2026-11-17-round44.md): "game", never "show", in what grown-ups and kids read; the .storekit
/// file matches StoreProducts.
@Suite struct Round44Tests {
    static let storeKitURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("StoreKit/PretendThat.storekit")

    /// Every plan / allowance / purchase line a grown-up or kid reads.
    static var planWords: [String] {
        let e = PlanEntitlement(productID: StoreProducts.showPassMonthly, tier: .showPass, purchaseDate: Date(), expirationDate: nil)
        let a = ShowAllowance.current(entitlement: e, freeUsed: 0, counter: PlanShowCounter(defaults: FakeDefaults()))
        let free = ShowAllowance(tier: .freePreview, used: 1, refillsAt: nil)
        var w = [OnboardingCopy.plansBody, OnboardingCopy.replaysLine, OnboardingCopy.plansGrownUpsBody,
                 OnboardingCopy.planOutTitle(.showPass), OnboardingCopy.planOutBody(.showPass, refill: nil),
                 OnboardingCopy.planOutBody(.seasonPass, refill: nil), OnboardingCopy.outOfShowsBody,
                 OnboardingCopy.kidOutOfShows, OnboardingCopy.plansV3Title, OnboardingCopy.plansV3Lead,
                 OnboardingCopy.freeGamesButton, a.summary, a.refillText() ?? "", free.summary,
                 PurchaseOutcome.purchased(.showPass).message, PurchaseOutcome.purchased(.seasonPass).message,
                 GrownUpsSection.plans.subtitle, StoreProducts.groupDescription]
        w += PlanCatalog.offers.map(\.showsText)
        w += StoreProducts.all.compactMap(StoreProducts.storeDescription)
        return w
    }

    @Test func planWordsSayGameNeverShowOrReplay() {
        for line in Self.planWords {
            // "Show Pass" is the plan's name; any other "show" is the old word.
            let l = line.replacingOccurrences(of: "Show Pass", with: "").lowercased()
            #expect(!l.contains("show"), "\(line)")
            #expect(!l.contains("replay"), "\(line)")
        }
        #expect(OnboardingCopy.kidOutOfShows == "That's all the new games for now! Ask a grown-up.")
        #expect(OnboardingCopy.plansBody.contains("Playing a saved game again is always free"))
        #expect(PlanCatalog.seasonPass.showsText == "30 new games a month")
    }

    @Test func productIDsAreUnchanged() {
        #expect(StoreProducts.all == ["app.pretendthat.showpass.monthly", "app.pretendthat.showpass.yearly",
                                      "app.pretendthat.seasonpass.monthly", "app.pretendthat.seasonpass.yearly"])
        #expect(StoreProducts.displayName(StoreProducts.showPassYearly) == "Show Pass (Yearly)")
        #expect(StoreProducts.displayName(StoreProducts.seasonPassMonthly) == "Season Pass")
        #expect(StoreProducts.storeDescription(StoreProducts.seasonPassYearly) == "30 new games a month. Saved games are free to play again.")
    }

    @Test func chatOpenKeepsTheTalkingCloseUpWhenCardsArePresented() {
        typealias D = PTStageDirector
        // Chat closed: the legacy presented cards get the wide shot beside her.
        #expect(D.preset(phase: .pickGame, conversation: true, conversationShot: .wide, cards: 3, hunt: false,
                         kitBeat: .coloring, chatOpen: false) == .presentedCards)
        // Chat open: the cards are only in the panel's tab; she keeps the talking close-up (no camera move).
        let open = D.preset(phase: .pickGame, conversation: true, conversationShot: .wide, cards: 3, hunt: false,
                            kitBeat: .coloring, chatOpen: true)
        #expect(open == .propCardChat)
        let g = PTStageGeometry(size: CGSize(width: 1194, height: 834), leadingInset: 0, bottomInset: 0,
                                floor: .zero, chatOpen: true)
        #expect(D.frame(open, curtainInset: 80, g) == D.frame(.talk, curtainInset: 80, g))
        // Every other chat-open card step is the same framing.
        for phase in [Phase.makingKit, .kitReady, .scene(0), .end] {
            let p = D.preset(phase: phase, conversation: false, conversationShot: .closeUp, cards: 0, hunt: false,
                             kitBeat: .papers, chatOpen: true)
            #expect(p == .propCardChat || p == .talk)
        }
    }

    @Test func storeKitFileMatchesStoreProducts() throws {
        let data = try Data(contentsOf: Self.storeKitURL)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let group = try #require((root["subscriptionGroups"] as? [[String: Any]])?.first)
        let groupLoc = try #require((group["localizations"] as? [[String: Any]])?.first)
        #expect(groupLoc["description"] as? String == StoreProducts.groupDescription)
        let subs = try #require(group["subscriptions"] as? [[String: Any]])
        #expect(Set(subs.compactMap { $0["productID"] as? String }) == Set(StoreProducts.all))
        for s in subs {
            let id = try #require(s["productID"] as? String)
            let loc = try #require((s["localizations"] as? [[String: Any]])?.first)
            #expect(loc["displayName"] as? String == StoreProducts.displayName(id), "\(id)")
            #expect(loc["description"] as? String == StoreProducts.storeDescription(id), "\(id)")
            #expect(!(loc["description"] as? String ?? "").lowercased().contains("show"))
        }
    }
}
