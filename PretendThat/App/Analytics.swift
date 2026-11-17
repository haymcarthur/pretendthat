import Foundation
import NutmegCore
import TelemetryDeck

/// Anonymous usage counts (decisions/2026-11-17-analytics-build.md). The ONLY place in the app that talks to
/// TelemetryDeck, and it only sends `AnalyticsEvent` (NutmegCore: fixed names, fixed-word parameters; tested).
///
/// - No app ID (`TELEMETRYDECK_APP_ID` in Analytics.xcconfig empty): a no-op; the SDK is never started.
/// - Sharing OFF (the default, until a grown-up turns it on): a no-op; the SDK is never started (or is stopped).
/// - The user id TelemetryDeck hashes is a RANDOM per-install UUID (`AnalyticsSettings.installID`), never the device's
///   identifierForVendor; it's deleted when sharing is turned off. Session stats (retention counters) are off.
/// - Debug builds send in TelemetryDeck's Test mode (the SDK's default for DEBUG; set explicitly here).
@MainActor
enum Analytics {
    static let settings = AnalyticsSettings(defaults: UserDefaults.standard)
    private(set) static var appID: String?
    private(set) static var running = false

    /// At launch: read the app ID and start the SDK only if a grown-up turned sharing on.
    static func configure(info: [String: Any]? = Bundle.main.infoDictionary) {
        appID = AnalyticsSettings.appID(info: info)
        #if DEBUG
        // `-PTAnalyticsAppID <id>`: a dummy ID for a simulator run (Test mode); `-PTAnalyticsOn`: the switch on.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-PTAnalyticsAppID"), i + 1 < args.count { appID = args[i + 1] }
        if args.contains("-PTAnalyticsOn") { settings.share = true }
        if args.contains("-PTAnalyticsOff") { settings.share = false }
        #endif
        rtLog("ANALYTICS \(appID == nil ? "no app ID: off (no-op)" : "app ID set"), sharing \(settings.share ? "on" : "off")")
        if settings.share { start() }
    }

    /// The grown-up's switch (onboarding's privacy page, Grown-ups → About what we save).
    static func setSharing(_ on: Bool) {
        guard on != settings.share || on != running else { return }
        settings.share = on
        rtLog("ANALYTICS sharing \(on ? "on" : "off")")
        if on { start() } else { stop() }
    }

    static var sharing: Bool { settings.share }

    static func send(_ event: AnalyticsEvent) {
        let s = event.signal
        guard running else {
            #if DEBUG
            rtLog("ANALYTICS (not sent: \(appID == nil ? "no app ID" : "sharing off")) \(s.name) \(s.parameters.sorted { $0.key < $1.key })")
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

    private static func stop() {
        guard running else { return }
        TelemetryDeck.terminate()
        running = false
        rtLog("ANALYTICS stopped")
    }
}
