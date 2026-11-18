import XCTest

/// Anonymous analytics (2026-11-17-analytics-build.md): one first-launch onboarding with a dummy TelemetryDeck app ID
/// (Debug = TelemetryDeck Test mode). Round 44: counts are always on (no switch); every onboarding event is sent. The
/// events are read from the app's console (`ANALYTICS` lines), e.g.
/// `xcrun simctl spawn <udid> log stream --predicate 'eventMessage CONTAINS "ANALYTICS"'`.
/// `-PTNoAI`: no AI calls; the onboarding ends on "Go to the home page".
@MainActor
final class AnalyticsOnboardingTests: XCTestCase {
    func testOnboardingSendsCountsWithNoSwitch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-PTNoAI", "-PTResetOnboarding", "-PTAnalyticsAppID", "00000000-0000-0000-0000-00000000DEAD"]
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
        tap("Get started")
        tap("Next")
        tap("Next")
        tap("I agree")   // v3: consent and the mic in one step (the system prompts come next)
        sleep(2)
        app.tap()   // lets the interruption monitor answer the system prompts
        sleep(2)
        app.tap()
        let next = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Next")).firstMatch
        if next.waitForExistence(timeout: 8) { next.tap() }   // the mic-denied state's Next
        tap("Start with 2 free games", timeout: 30)
        tap("Go to the home page")
        sleep(3)
        app.terminate()
    }
}
