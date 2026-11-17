import XCTest
import StoreKitTest
import StoreKit

/// Round 38: the StoreKit flows on the simulator with StoreKit/PretendThat.storekit (SKTestSession). The app runs with
/// `-PTNoAI` (no AI calls: New game falls back to the bundled tap game), so only the counting and the store are tested.
/// Screenshots: /tmp/pt-round38/ (the simulator shares the Mac's /tmp).
@MainActor
final class StoreKitFlowTests: XCTestCase {
    var session: SKTestSession!
    let out = "/tmp/pt-round38"

    override func setUpWithError() throws {
        continueAfterFailure = false
        session = try SKTestSession(configurationFileNamed: "PretendThat")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
    }

    // MARK: Helpers

    @discardableResult
    func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-PTNoAI"] + args
        app.launch()
        return app
    }

    func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); a.name = name; a.lifetime = .keepAlways
        add(a)
    }

    func text(_ app: XCUIApplication, containing s: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    func button(_ app: XCUIApplication, beginningWith s: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", s)).firstMatch
    }

    func waitFor(_ e: XCUIElement, _ timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        let ok = e.waitForExistence(timeout: timeout)
        if !ok { shot("fail-line\(line)"); print("TREE:\n" + XCUIApplication().debugDescription) }
        XCTAssertTrue(ok, "missing: \(e)", file: file, line: line)
    }

    static let words: [String: Int] = {
        let ones = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        let tens = ["twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90]
        var m: [String: Int] = [:]
        for (t, v) in tens {
            m[t] = v
            for (i, o) in ones.enumerated() { m["\(t)-\(o)"] = v + i + 1 }
        }
        return m
    }()

    /// The grown-up gate: hold 2 s, then tap the spelled number.
    func passGate(_ app: XCUIApplication) {
        let hold = app.buttons["Grown-ups: hold for 2 seconds"]
        waitFor(hold)
        hold.press(forDuration: 2.6)
        let q = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Tap the number '")).firstMatch
        waitFor(q, 5)
        let w = q.label.replacingOccurrences(of: "Tap the number ", with: "").trimmingCharacters(in: .whitespaces)
        let n = try! XCTUnwrap(Self.words[w], "unknown number words \(w)")
        app.buttons["\(n)"].tap()
    }

    func tapNewGame(_ app: XCUIApplication) {
        let b = app.buttons["New game"]
        waitFor(b, 20)
        sleep(2)   // the start screen's opening
        b.tap()
    }

    func buyWithSession(_ id: String) async throws {
        try await session.buyProduct(identifier: id, options: [])
    }

    // MARK: 1. Free Preview: 2 new shows, then the paywall; buy Show Pass (intro price) → 10 a month

    func test1_FreePreviewRunsOutThenShowPass() throws {
        var app = launch(["-PTConsent", "-PTResetFreePreview"])
        tapNewGame(app)
        XCTAssertFalse(text(app, containing: "That's all the new shows").waitForExistence(timeout: 3))
        shot("01-free-show-1-started")
        app.terminate()

        app = launch(["-PTConsent"])
        tapNewGame(app)
        XCTAssertFalse(text(app, containing: "That's all the new shows").waitForExistence(timeout: 3))
        app.terminate()

        app = launch(["-PTConsent"])
        tapNewGame(app)
        waitFor(text(app, containing: "That's all the new shows for now! Ask a grown-up."))
        shot("02-kid-card-free-preview-used")
        app.buttons["kidCard.grownUps"].tap()
        passGate(app)
        waitFor(text(app, containing: "Your Free Preview is used up"))
        waitFor(text(app, containing: "for 12 months, then $14.99/month"))
        waitFor(text(app, containing: "0 of 2 free new shows left"))
        shot("03-paywall-free-preview-used-intro-price")

        button(app, beginningWith: "Get Show Pass").tap()
        waitFor(text(app, containing: "Thank you! Show Pass is active."), 20)
        waitFor(text(app, containing: "10 of 10 new shows left this month"))
        shot("04-bought-show-pass-10-left")
        app.buttons["Close"].tap()

        tapNewGame(app)
        XCTAssertFalse(text(app, containing: "That's all the new shows").waitForExistence(timeout: 3))
        app.terminate()

        app = launch(["-PTGrownUps", "plans"])
        waitFor(text(app, containing: "9 of 10 new shows left this month"))
        waitFor(text(app, containing: "Your plan: Show Pass"))
        shot("05-grownups-plans-9-of-10")
        app.terminate()
    }

    // MARK: 2. Show Pass month used up → the grown-up paywall suggests Season Pass

    func test2_PlanMonthUsedUp() async throws {
        try await buyWithSession("app.pretendthat.showpass.monthly")
        let app = await launch(["-PTConsent", "-PTPlanUsed", "10"])
        await tapNewGame(app)
        await waitFor(text(app, containing: "That's all the new shows for now! Ask a grown-up."))
        await app.buttons["kidCard.grownUps"].tap()
        await passGate(app)
        await waitFor(text(app, containing: "This month's new shows are used up"))
        await waitFor(text(app, containing: "0 of 10 new shows left this month"))
        await shot("06-paywall-show-pass-month-used-up")
        await app.terminate()
    }

    // MARK: 3. Restore, then expire

    func test3_RestoreThenExpire() async throws {
        try await buyWithSession("app.pretendthat.showpass.monthly")
        var app = await launch(["-PTGrownUps", "restorePurchases"])
        let restore = await app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Restore purchases'")).firstMatch
        await waitFor(restore, 20)
        await restore.tap()
        await waitFor(text(app, containing: "Restored. Your plan is active"), 20)
        await shot("07-restore-restored")
        await app.terminate()

        // The grown-up cancels (auto-renew off), then the period ends.
        let t = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == "app.pretendthat.showpass.monthly" })
        try session.disableAutoRenewForTransaction(identifier: t.identifier)
        try session.expireSubscription(productIdentifier: "app.pretendthat.showpass.monthly")
        app = await launch(["-PTGrownUps", "plans"])
        await waitFor(text(app, containing: "Your plan: Free Preview"), 20)
        await shot("08-after-expire-free-preview")
        await app.terminate()
    }

    // MARK: 4. Ask to Buy: pending, then approved

    func test4_AskToBuyPendingThenApproved() async throws {
        session.askToBuyEnabled = true
        let app = await launch(["-PTGrownUps", "plans"])
        await waitFor(button(app, beginningWith: "Get Show Pass"))
        await button(app, beginningWith: "Get Show Pass").tap()
        await waitFor(text(app, containing: "Waiting for approval"), 20)
        await shot("09-ask-to-buy-pending")
        let pending = try session.allTransactions().first { $0.productIdentifier == "app.pretendthat.showpass.monthly" }
        let id = try XCTUnwrap(pending).identifier
        try session.approveAskToBuyTransaction(identifier: id)
        await waitFor(text(app, containing: "Your plan: Show Pass"), 30)
        await shot("10-ask-to-buy-approved")
        await app.terminate()
    }

    // MARK: 5. Refund → revoked → back to the Free Preview

    func test5_RefundRevokes() async throws {
        try await buyWithSession("app.pretendthat.seasonpass.monthly")
        let app = await launch(["-PTGrownUps", "plans"])
        await waitFor(text(app, containing: "Your plan: Season Pass"), 20)
        await waitFor(text(app, containing: "30 of 30 new shows left this month"))
        await shot("11-season-pass-active")
        let t = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == "app.pretendthat.seasonpass.monthly" })
        try session.refundTransaction(identifier: t.identifier)
        await waitFor(text(app, containing: "Your plan: Free Preview"), 30)
        await shot("12-after-refund-free-preview")
        await app.terminate()
    }

    // MARK: 6. Replays are always free (never counted, never blocked)

    func test6_ReplaysStayFree() async throws {
        var app = await launch(["-PTDemo", "seed2"])
        try await Task.sleep(nanoseconds: 12_000_000_000)
        await app.terminate()
        app = await launch(["-PTConsent", "-PTFreeUsed", "2"])
        let saved = await app.buttons["Saved games"]
        await waitFor(saved, 20)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await saved.tap()
        let game = await app.buttons.matching(identifier: "shelf.game").firstMatch
        await waitFor(game)
        await game.tap()
        let blocked = await text(app, containing: "That's all the new shows").waitForExistence(timeout: 4)
        XCTAssertFalse(blocked, "a replay must never be blocked")
        await shot("13-replay-free-with-preview-used")
        await app.terminate()
        app = await launch(["-PTGrownUps", "plans"])
        await waitFor(text(app, containing: "0 of 2 free new shows left"))   // still 2 used: the replay didn't count
        await app.terminate()
    }

    // MARK: 7. Onboarding page 6: real prices, buy without the gate → the hand-off page

    func test7_OnboardingPlansPage() throws {
        let app = launch(["-PTResetOnboarding", "-PTOnboarding", "plans"])
        waitFor(text(app, containing: "for 12 months, then $14.99/month"), 20)
        waitFor(text(app, containing: "for 12 months, then $29.99/month"))
        shot("14-onboarding-plans-real-prices")
        button(app, beginningWith: "Get Show Pass").tap()
        waitFor(text(app, containing: "Hand the \(UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad") to your child"), 20)
        shot("15-onboarding-bought-hand-off")
        app.terminate()
    }
}
