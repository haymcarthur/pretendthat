import Foundation
import NutmegCore
import TelemetryDeck

/// Anonymous usage counts (decisions/2026-11-17-analytics-build.md). The ONLY place in the app that talks to
/// TelemetryDeck, and it only sends `AnalyticsEvent` (NutmegCore: fixed names, fixed-word parameters; tested).
///
/// - Round 44 (Haylee): there's no switch. Counts are always on whenever the build has an app ID
///   (`TELEMETRYDECK_APP_ID` in Analytics.xcconfig); they're disclosed in the privacy policy and in Grown-ups → About
///   what we save. Existing installs move to on (the old switch's stored answer is removed at launch).
/// - No app ID: a no-op; the SDK is never started.
/// - The user id TelemetryDeck hashes is a RANDOM per-install UUID (`AnalyticsSettings.installID`), never the device's
///   identifierForVendor. Session stats (retention counters) are off.
/// - Debug builds send in TelemetryDeck's Test mode (the SDK's default for DEBUG; set explicitly here).
@MainActor
enum Analytics {
    static let settings = AnalyticsSettings(defaults: UserDefaults.standard)
    private(set) static var appID: String?
    private(set) static var running = false

    /// At launch: drop the old switch's answer, read the app ID and start the SDK.
    static func configure(info: [String: Any]? = Bundle.main.infoDictionary) {
        settings.migrateToAlwaysOn()
        appID = AnalyticsSettings.appID(info: info)
        var off = false
        #if DEBUG
        // `-PTAnalyticsAppID <id>`: a dummy ID for a simulator run (Test mode). `-PTAnalyticsOff`: this run sends
        // nothing (agents' screenshot and UI-test runs; DEBUG only, not a setting).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-PTAnalyticsAppID"), i + 1 < args.count { appID = args[i + 1] }
        off = args.contains("-PTAnalyticsOff")
        #endif
        rtLog("ANALYTICS \(appID == nil ? "no app ID: off (no-op)" : (off ? "off for this debug run (-PTAnalyticsOff)" : "app ID set: on"))")
        if !off { start() }
    }

    static func send(_ event: AnalyticsEvent) {
        let s = event.signal
        guard running else {
            #if DEBUG
            rtLog("ANALYTICS (not sent: \(appID == nil ? "no app ID" : "off for this run")) \(s.name) \(s.parameters.sorted { $0.key < $1.key })")
            #endif
            return
        }
        TelemetryDeck.signal(s.name, parameters: s.parameters)
        #if DEBUG
        rtLog("ANALYTICS sent \(s.name) \(s.parameters.sorted { $0.key < $1.key })")
        #endif
    }

    private static func start() {
        guard !running, let appID else { return }
        let config = TelemetryDeck.Config(appID: appID)
        config.defaultUser = settings.installID   // random per install, never identifierForVendor
        config.sessionStatsEnabled = false        // no retention counters kept on the iPad
        #if DEBUG
        config.testMode = true
        #else
        config.testMode = false
        #endif
        TelemetryDeck.initialize(config: config)
        running = true
        rtLog("ANALYTICS started (\(config.testMode ? "test mode" : "live"))")
    }
}
