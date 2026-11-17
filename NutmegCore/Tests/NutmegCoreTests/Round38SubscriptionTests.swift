import Foundation
import Testing
@testable import NutmegCore

/// Round 38: StoreKit subscriptions (product IDs, entitlements, the monthly window and counter, the New game gate,
/// purchase wording, price text, the relay show-start protocol and ticket).
@Suite(.serialized) struct Round38SubscriptionTests {
    let utc = ShowWindow.calendar
    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func productIDsAreOneGroupOfFourAndMapBack() throws {
        #expect(StoreProducts.all.count == 4 && Set(StoreProducts.all).count == 4)
        for id in StoreProducts.all {
            let tier = try #require(StoreProducts.tier(for: id))
            let period = try #require(StoreProducts.period(for: id))
            #expect(StoreProducts.productID(tier, period) == id)
            #expect(id.hasPrefix("app.pretendthat."))
        }
        #expect(StoreProducts.tier(for: "app.pretendthat.other") == nil)
        #expect(StoreProducts.productID(.freePreview, .monthly) == nil)
        #expect(PlanStatus.from(productIDs: [StoreProducts.seasonPassYearly]) == .active(name: "Season Pass"))
        #expect(PlanStatus.from(productIDs: [StoreProducts.showPassMonthly]) == .active(name: "Show Pass"))
    }

    @Test func allowancesAndPricesMatchTheDecision() {
        #expect(PlanTier.freePreview.allowance == 2)
        #expect(PlanTier.showPass.allowance == 10)
        #expect(PlanTier.seasonPass.allowance == 30)
        // PlanCatalog keeps the prices as the fallback text before StoreKit loads (and the .storekit file's values).
        #expect(PlanCatalog.showPass.monthlyIntro == Decimal(string: "9.99") && PlanCatalog.showPass.monthly == Decimal(string: "14.99"))
        #expect(PlanCatalog.seasonPass.monthlyIntro == Decimal(string: "19.99") && PlanCatalog.seasonPass.monthly == Decimal(string: "29.99"))
        #expect(PlanCatalog.showPass.yearly == Decimal(string: "149.99") && PlanCatalog.seasonPass.yearly == Decimal(string: "299.99"))
        #expect(PlanCatalog.introMonths == 12)
    }

    @Test func entitlementSkipsRevokedExpiredAndUnknown() {
        let now = date(2026, 11, 17)
        #expect(PlanEntitlement.from(productID: StoreProducts.showPassMonthly, purchaseDate: date(2026, 11, 1), expirationDate: date(2026, 12, 1), revoked: false, now: now)?.tier == .showPass)
        #expect(PlanEntitlement.from(productID: StoreProducts.showPassMonthly, purchaseDate: date(2026, 11, 1), expirationDate: date(2026, 12, 1), revoked: true, now: now) == nil)
        #expect(PlanEntitlement.from(productID: StoreProducts.showPassMonthly, purchaseDate: date(2026, 10, 1), expirationDate: date(2026, 11, 1), revoked: false, now: now) == nil)
        #expect(PlanEntitlement.from(productID: "x", purchaseDate: now, expirationDate: nil, revoked: false, now: now) == nil)
        let a = PlanEntitlement(productID: StoreProducts.showPassMonthly, tier: .showPass, purchaseDate: date(2026, 11, 10), expirationDate: nil)
        let b = PlanEntitlement(productID: StoreProducts.seasonPassMonthly, tier: .seasonPass, purchaseDate: date(2026, 11, 1), expirationDate: nil)
        #expect(PlanEntitlement.best([a, b]) == b)
        #expect(PlanEntitlement.best([]) == nil)
    }

    @Test func monthlyWindowsFollowThePurchaseDateEvenForYearly() {
        let anchor = date(2026, 1, 31)
        let w1 = ShowWindow.containing(date(2026, 2, 15), anchor: anchor, tier: .showPass)
        #expect(w1.start == anchor && w1.end > date(2026, 2, 15))
        let w2 = ShowWindow.containing(date(2026, 3, 5), anchor: anchor, tier: .showPass)
        #expect(w2.start <= date(2026, 3, 5) && date(2026, 3, 5) < w2.end && w2.key != w1.key)
        // A whole year of windows: each holds its day and they never overlap.
        var last: ShowWindow?
        for day in stride(from: 0, to: 365, by: 3) {
            let t = anchor.addingTimeInterval(Double(day) * 86_400 + 3600)
            let w = ShowWindow.containing(t, anchor: anchor, tier: .seasonPass)
            #expect(w.start <= t && t < w.end)
            if let last, last.key != w.key { #expect(w.start >= last.end) }
            last = w
        }
        // Before the anchor (clock skew): the first window.
        #expect(ShowWindow.containing(date(2026, 1, 1), anchor: anchor, tier: .showPass).start == anchor)
    }

    @Test func counterCountsNewShowsPerWindowOnly() {
        let d = FakeDefaults()
        let c = PlanShowCounter(defaults: d)
        let e = PlanEntitlement(productID: StoreProducts.showPassMonthly, tier: .showPass, purchaseDate: date(2026, 11, 3), expirationDate: date(2026, 12, 3))
        let w = e.window(now: date(2026, 11, 17))
        #expect(c.used(in: w) == 0)
        c.gameStarted(in: w, isReplay: false)
        c.gameStarted(in: w, isReplay: true)   // replays are free
        #expect(c.used(in: w) == 1)
        let next = e.window(now: date(2026, 12, 4))
        #expect(c.used(in: next) == 0)   // a new month starts fresh
        // Only a window key and a number are stored.
        #expect(Set(d.values.keys) == [ShowCountKeys.window, ShowCountKeys.used])
        c.reset(); #expect(d.values.isEmpty)
    }

    @Test func gateUsesTheRealAllowance() {
        let d = FakeDefaults(); let c = PlanShowCounter(defaults: d)
        let now = date(2026, 11, 17)
        // Free Preview: 2 new shows, then the plans.
        #expect(NewGameGate.newGame(consent: true, allowance: .current(entitlement: nil, freeUsed: 1, counter: c, now: now)) == .start)
        #expect(NewGameGate.newGame(consent: true, allowance: .current(entitlement: nil, freeUsed: 2, counter: c, now: now)) == .needsPlan)
        #expect(NewGameGate.newGame(consent: false, allowance: .current(entitlement: nil, freeUsed: 0, counter: c, now: now)) == .needsConsent)
        // Show Pass: 10 a month, then out of shows until the window ends.
        let e = PlanEntitlement(productID: StoreProducts.showPassMonthly, tier: .showPass, purchaseDate: date(2026, 11, 3), expirationDate: date(2026, 12, 3))
        var a = ShowAllowance.current(entitlement: e, freeUsed: 2, counter: c, now: now)
        #expect(a.remaining == 10 && a.summary == "10 of 10 new shows left this month" && a.refillsAt == e.window(now: now).end)
        for _ in 0..<10 { c.gameStarted(in: e.window(now: now), isReplay: false) }
        a = .current(entitlement: e, freeUsed: 2, counter: c, now: now)
        #expect(a.exhausted && NewGameGate.newGame(consent: true, allowance: a) == .outOfShows)
        #expect(a.refillText(locale: Locale(identifier: "en_US"))?.hasPrefix("More new shows arrive Dec") == true)
        // Replays never need an allowance.
        #expect(NewGameGate.replay(consent: true) == .start)
        // Season Pass: 30.
        let s = PlanEntitlement(productID: StoreProducts.seasonPassYearly, tier: .seasonPass, purchaseDate: date(2026, 11, 3), expirationDate: date(2027, 11, 3))
        #expect(ShowAllowance.current(entitlement: s, freeUsed: 2, counter: c, now: now).remaining == 30)
    }

    @Test func purchaseMessagesAreForGrownUps() {
        #expect(PurchaseOutcome.purchased(.showPass).message.contains("10 new shows a month"))
        #expect(PurchaseOutcome.pending.message.contains("Ask to Buy"))
        #expect(PurchaseOutcome.cancelled.message == "No problem. Nothing was bought.")
        for f in [PurchaseFailure.network, .notAvailable, .unverified, .productMissing, .other] {
            #expect(!PurchaseOutcome.failed(f).message.isEmpty && !PurchaseOutcome.failed(f).succeeded)
        }
        #expect(PurchaseOutcome.purchased(.seasonPass).succeeded)
    }

    @Test func priceTextShowsTheIntroAndTheRenewalPrice() {
        #expect(PriceText.billed(regular: "$14.99", intro: "$9.99", eligible: true, period: .monthly) == "$9.99/month")
        #expect(PriceText.billed(regular: "$14.99", intro: "$9.99", eligible: false, period: .monthly) == "$14.99/month")
        #expect(PriceText.introThen(regular: "$14.99", intro: "$9.99", introPeriods: 12, eligible: true, period: .monthly) == "for 12 months, then $14.99/month")
        #expect(PriceText.introThen(regular: "$14.99", intro: "$9.99", introPeriods: 12, eligible: false, period: .monthly) == nil)
        #expect(PriceText.full(regular: "$29.99", intro: "$19.99", introPeriods: 12, eligible: true, period: .monthly) == "$19.99/month for 12 months, then $29.99/month")
        #expect(PriceText.full(regular: "$149.99", intro: nil, introPeriods: 0, eligible: true, period: .yearly) == "$149.99/year")
        #expect(PriceText.buyLabel(.showPass, billed: "$9.99/month") == "Get Show Pass · $9.99/month")
    }

    @Test func relayShowStartRequestAndDecisions() throws {
        let relay = RelayConfig(url: URL(string: "https://relay.example.dev")!, token: "tok")
        let r = RelayShows.request(relay: relay, proof: .subscription(jws: "a.b.c"))
        #expect(r.url?.absoluteString == "https://relay.example.dev/v1/shows/start" && r.httpMethod == "POST")
        #expect(r.value(forHTTPHeaderField: "X-PT-Token") == "tok")
        let body = try #require(JSONSerialization.jsonObject(with: r.httpBody!) as? [String: String])
        #expect(body == ["kind": "subscription", "jws": "a.b.c"])
        let p = try #require(JSONSerialization.jsonObject(with: RelayShows.request(relay: relay, proof: .preview(jws: "x")).httpBody!) as? [String: String])
        #expect(p["kind"] == "preview")
        #expect(RelayShows.decode(data: Data(#"{"ticket":"t1","remaining":4}"#.utf8), status: 200) == .allowed(ticket: "t1", remaining: 4))
        #expect(RelayShows.decode(data: Data(#"{"error":"limit_reached"}"#.utf8), status: 402) == .limitReached)
        #expect(RelayShows.decode(data: Data(#"{"error":{"type":"limit_reached","message":"m"}}"#.utf8), status: 402) == .limitReached)
        #expect(RelayShows.decode(data: Data(#"{"error":{"type":"show_ticket_required"}}"#.utf8), status: 402) == .allowUnknown)
        #expect(RelayShows.decode(data: Data(#"{"error":"not_found"}"#.utf8), status: 404) == .allowUnknown)   // not deployed: allow
        #expect(RelayShows.decode(data: nil, status: nil) == .allowUnknown)   // offline: allow
        #expect(RelayShows.decode(data: Data(), status: 500) == .allowUnknown)
        #expect(RelayShows.enabled(info: [:]) == false)
        #expect(RelayShows.enabled(info: ["RELAY_SHOW_LIMITS": "$(RELAY_SHOW_LIMITS)"]) == false)
        #expect(RelayShows.enabled(info: ["RELAY_SHOW_LIMITS": "NO"]) == false)
        #expect(RelayShows.enabled(info: ["RELAY_SHOW_LIMITS": "YES"]) == true)
    }

    @Test func ticketRidesOnRelayGuideAndKitCallsOnly() throws {
        ShowTicket.set("tick")
        defer { ShowTicket.set(nil) }
        let schema = JSONSchema(Schemas.turn())
        let relayClaude = ClaudeClient(config: .init(mode: .relay(url: URL(string: "https://r.dev")!, token: "t")))
        #expect(try relayClaude.makeRequest(system: "s", user: "u", schema: schema, effort: .low).value(forHTTPHeaderField: "X-PT-Show") == "tick")
        let direct = ClaudeClient(config: .init(mode: .direct(apiKey: "k")))
        #expect(try direct.makeRequest(system: "s", user: "u", schema: schema, effort: .low).value(forHTTPHeaderField: "X-PT-Show") == nil)
        let img = ImageClient(mode: .relay(url: URL(string: "https://r.dev")!, token: "t"))
        #expect(try img.request(prompt: "p", size: "1024x1024", model: "m").value(forHTTPHeaderField: "X-PT-Show") == "tick")
        ShowTicket.set(nil)
        #expect(try img.request(prompt: "p", size: "1024x1024", model: "m").value(forHTTPHeaderField: "X-PT-Show") == nil)
    }
}
