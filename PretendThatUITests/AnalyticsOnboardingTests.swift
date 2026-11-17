import XCTest

/// Anonymous analytics (2026-11-17-analytics-build.md): one first-launch onboarding with a dummy TelemetryDeck app ID
/// (Debug = TelemetryDeck Test mode). The grown-up turns "Share anonymous usage counts" on on the privacy page (it starts
/// OFF). The events are read from the app's console (`ANALYTICS` lines), e.g.
/// `xcrun simctl spawn <udid> log stream --predicate 'eventMessage CONTAINS "ANALYTICS"'`.
/// `-PTNoAI`: no AI calls; the onboarding ends on "Go to the home page".
@MainActor
final class AnalyticsOnboardingTests: XCTestCase {
    func testOnboardingWithSharingTurnedOn() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PTNoAI", "-PTResetOnboarding", "-PTAnalyticsOff", "-PTAnalyticsAppID", "00000000-0000-0000-0000-00000000DEAD"]
        // The mic page's system prompts: "Don't Allow" (no permission is granted to the simulator by this test).
        addUIInterruptionMonitor(withDescription: "permissions") { alert in
            for label in ["Don’t Allow", "Don't Allow"] where alert.buttons[label].exists { alert.buttons[label].firstMatch.tap(); return true }
            return false
        }
        app.launch()
        func tap(_ label: String, timeout: TimeInterval = 20) {
            let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            XCTAssertTrue(b.waitForExistence(timeout: timeout), "missing \(label)")
            b.tap()
        }
        tap("Let's get started")
        tap("Next")
        tap("Next")
        let toggle = app.switches["analyticsToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "0")   // OFF until the grown-up turns it on
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        tap("I agree")
        tap("Continue")
        sleep(2)
        app.tap()   // lets the interruption monitor answer the system prompts
        sleep(2)
        app.tap()
        let next = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Next")).firstMatch
        if next.waitForExistence(timeout: 8) { next.tap() }   // the mic-denied note's Next
        tap("Start my Free Preview", timeout: 30)
        tap("Go to the home page")
        sleep(3)
        app.terminate()
    }
}
