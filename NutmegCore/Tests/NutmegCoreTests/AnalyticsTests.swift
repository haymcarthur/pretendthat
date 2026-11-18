import Foundation
import Testing
@testable import NutmegCore

/// Anonymous analytics (2026-11-17-analytics-build.md): every event maps to a fixed name and fixed-word parameters, so
/// nothing about kids (names, voices, transcripts, generated text, free text, device ids) can ever be sent.
@Suite struct AnalyticsTests {

    // MARK: No free text can be sent

    @Test func everyEventHasAKnownNameAndOnlyFixedWords() {
        let all = AnalyticsEvent.everyEvent
        #expect(all.count > 500)   // the whole space, every combination
        for e in all {
            let s = e.signal
            #expect(AnalyticsEvent.signalNames.contains(s.name), "unknown signal \(s.name)")
            for (k, v) in s.parameters {
                let allowed = AnalyticsEvent.allowedValues[k]
                #expect(allowed != nil, "unknown key \(k)")
                #expect(allowed?.contains(v) == true, "\(k)=\(v) is not a fixed word")
                // Short ASCII words only: no spaces, punctuation or digits-only ids.
                #expect(v.count <= 24 && v.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } && v.first!.isLetter)
            }
        }
        // Every name is reachable, and parameter keys never collide with TelemetryDeck's reserved keys.
        #expect(Set(all.map(\.signal.name)) == AnalyticsEvent.signalNames)
        let reserved: Set<String> = ["type", "clientuser", "appid", "sessionid", "floatvalue", "platform", "locale", "region",
                                     "modelname", "appversion", "buildnumber"]
        #expect(AnalyticsEvent.allowedValues.keys.allSatisfy { !reserved.contains($0.lowercased()) && !$0.hasPrefix("TelemetryDeck.") })
    }

    /// The type system is the guarantee: an event's associated values are fixed enums only, never a String or number.
    @Test func eventsHoldOnlyFixedEnumsByReflection() {
        for e in AnalyticsEvent.everyEvent {
            guard let payload = Mirror(reflecting: e).children.first?.value else { continue }   // no-parameter cases
            let parts = Mirror(reflecting: payload).displayStyle == .tuple ? Mirror(reflecting: payload).children.map(\.value) : [payload]
            for v in parts {
                #expect(v is any AnalyticsValue, "\(e) holds \(type(of: v)), not a fixed enum")
                #expect(!(v is String) && !(v is Int) && !(v is Double) && !(v is Date) && !(v is UUID))
            }
        }
    }

    @Test func theGameTitleNeverLeavesOnlyItsCategory() {
        let title = "Emma and Liam's Sparkly Unicorn Bakery"
        let e = AnalyticsEvent.gameFinished(.new, PlayersValue(count: 2), GameCategory.from(title: title), DurationValue(seconds: 1300))
        let s = e.signal
        #expect(s.parameters == ["kind": "new", "players": "twoToThree", "category": "food", "duration": "from15to30m"])
        let wire = ([s.name] + s.parameters.keys + s.parameters.values).joined(separator: " ").lowercased()
        for word in ["emma", "liam", "sparkly", "unicorn", "bakery"] { #expect(!wire.contains(word)) }
    }

    @Test func categoriesComeFromTheFixedList() {
        #expect(GameCategory.from(title: "Sunny Bakery") == .food)
        #expect(GameCategory.from(title: "Paws Vet Clinic") == .care)
        #expect(GameCategory.from(title: "Sky Airlines Airplane Trip") == .travel)
        #expect(GameCategory.from(title: "The Great Dinosaur Dig") == .adventure)
        #expect(GameCategory.from(title: "Puppet Show Night") == .show)
        #expect(GameCategory.from(title: "Corner Grocery") == .shop)
        #expect(GameCategory.from(title: "Station 9 Firefighters") == .community)
        #expect(GameCategory.from(title: "Zorblax") == .other)
        #expect(GameCategory.from(title: nil) == .other && GameCategory.from(title: "") == .other)
        // Every suggested game lands in a real category (not "other").
        for g in Suggestions.games { #expect(GameCategory.from(title: g.text) != .other, "\(g.id)") }
    }

    // MARK: Buckets

    @Test func bucketsAreCoarse() {
        #expect(PlayersValue(count: 0) == .unknown && PlayersValue(count: 1) == .one)
        #expect(PlayersValue(count: 2) == .twoToThree && PlayersValue(count: 3) == .twoToThree)
        #expect(PlayersValue(count: 4) == .fourPlus && PlayersValue(count: 9) == .fourPlus)
        #expect(DurationValue(seconds: 30) == .under1m && DurationValue(seconds: 61) == .from1to5m)
        #expect(DurationValue(seconds: 600) == .from5to15m && DurationValue(seconds: 1000) == .from15to30m)
        #expect(DurationValue(seconds: 2000) == .from30to60m && DurationValue(seconds: 9000) == .over60m)
        #expect(SceneValue.from(arc: .play, playNumber: 1) == .play1 && SceneValue.from(arc: .play, playNumber: 5) == .playMore)
        #expect(PlanValue(productID: StoreProducts.seasonPassYearly) == .seasonPass)
        #expect(PeriodValue(productID: StoreProducts.seasonPassYearly) == .yearly)
        #expect(PlanValue(productID: "something.else") == .unknown && PeriodValue(productID: "x") == .unknown)
        #expect(PurchaseResultValue(.failed(.network)) == .failedNetwork && PurchaseResultValue(.purchased(.showPass)) == .succeeded)
        #expect(RestoreResultValue(.restored(count: 3)) == .restored)
        for s in OnboardingScreen.allCases { #expect(OnboardingPageValue(s).rawValue == s.rawValue) }
    }

    // MARK: The per-game tracker

    @Test func aGameSendsEachStepAndSceneOnceThenTheEnd() {
        var t = AnalyticsGameTracker()
        let kinds: [SceneKind] = [.story, .setup, .play, .play, .play, .cleanup]
        let start = Date(timeIntervalSince1970: 1000)
        #expect(t.phase(.pickGame, sceneKinds: [], players: 0, title: nil, now: start).isEmpty)   // not begun: nothing
        t.begin(kind: .new, at: start)
        var sent: [AnalyticsEvent] = []
        let phases: [Phase] = [.pickGame, .players, .props, .makingKit, .kitReady, .scene(0), .scene(1), .scene(2), .scene(3),
                               .scene(2), .scene(4), .scene(5), .end, .end]
        for ph in phases { sent += t.phase(ph, sceneKinds: kinds, players: 3, title: "Pizza Party", now: start.addingTimeInterval(700)) }
        #expect(sent == [
            .stepReached(.pick, .new, .twoToThree), .stepReached(.props, .new, .twoToThree), .stepReached(.print, .new, .twoToThree),
            .stepReached(.play, .new, .twoToThree), .sceneReached(.story, .new, .twoToThree), .sceneReached(.setup, .new, .twoToThree),
            .sceneReached(.play1, .new, .twoToThree), .sceneReached(.play2, .new, .twoToThree), .sceneReached(.play3, .new, .twoToThree),
            .sceneReached(.cleanup, .new, .twoToThree), .gameFinished(.new, .twoToThree, .food, .from5to15m),
        ])
        #expect(t.printed(.fullColor, players: 3) == .kitPrinted(.fullColor, .twoToThree))
        #expect(t.printed(.colorIn, players: 3) == nil)   // once per game
        #expect(t.error(.voiceConnectFailed) == .error(.voiceConnectFailed) && t.error(.voiceConnectFailed) == nil)
        t.begin(kind: .replay, at: start)   // a fresh slate
        #expect(t.phase(.pickGame, sceneKinds: [], players: 1, title: nil, now: start) == [.stepReached(.pick, .replay, .one)])
        #expect(t.printed(.colorIn, players: 1) == .kitPrinted(.colorIn, .one))
    }

    // MARK: Always on (round 44: no switch), the install id and the app ID

    @Test func countsAreAlwaysOnWithARandomInstallID() {
        let d = FakeDefaults()
        let s = AnalyticsSettings(defaults: d)
        #expect(s.share)   // no switch: always on
        let id = s.installID
        #expect(UUID(uuidString: id) != nil && s.installID == id)   // random, stable
        #expect(d.values.values.allSatisfy { $0 is String })   // only the random id is stored
    }

    @Test func existingInstallsMoveToOn() {
        // An install where a grown-up left the old switch OFF (no id), and one where it was ON (an id).
        let off = FakeDefaults(); off.values[AnalyticsKeys.legacyShare] = false
        let s = AnalyticsSettings(defaults: off)
        s.migrateToAlwaysOn()
        #expect(off.values[AnalyticsKeys.legacyShare] == nil && s.share)
        #expect(UUID(uuidString: s.installID) != nil)   // a fresh id, like a new install
        let on = FakeDefaults(); on.values[AnalyticsKeys.legacyShare] = true
        on.values[AnalyticsKeys.installID] = "6F1C2A7E-0000-4000-8000-000000000001"
        let t = AnalyticsSettings(defaults: on)
        t.migrateToAlwaysOn()
        #expect(on.values[AnalyticsKeys.legacyShare] == nil)
        #expect(t.installID == "6F1C2A7E-0000-4000-8000-000000000001")   // kept: same install
        t.migrateToAlwaysOn()   // idempotent
        #expect(on.values.count == 1)
    }

    @Test func aboutSaysItInOneLineAndThereIsNoSwitchCopy() {
        let line = GrownUpsCopy.analyticsLine
        #expect(GrownUpsCopy.about.contains { $0.body == line })
        #expect(line.contains("anonymous counts") && line.contains("never anything about your child"))
        #expect(line.split(separator: ".").count <= 1)   // one sentence
        #expect(!GrownUpsCopy.creditsFooter.contains("turn them on"))
    }

    @Test func anEmptyAppIDMeansNoAnalytics() {
        #expect(AnalyticsSettings.appID(info: nil) == nil)
        #expect(AnalyticsSettings.appID(info: [:]) == nil)
        #expect(AnalyticsSettings.appID(info: ["TelemetryDeckAppID": ""]) == nil)
        #expect(AnalyticsSettings.appID(info: ["TelemetryDeckAppID": "  "]) == nil)
        #expect(AnalyticsSettings.appID(info: ["TelemetryDeckAppID": "$(TELEMETRYDECK_APP_ID)"]) == nil)
        #expect(AnalyticsSettings.appID(info: ["TelemetryDeckAppID": " ABC-123 "]) == "ABC-123")
    }

    /// The app's Info.plist reads the ID from the build setting, and the privacy manifest declares the analytics.
    @Test func appFilesDeclareTheAnalytics() throws {
        let res = Round37ComplianceTests.appResources
        let info = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: res.appendingPathComponent("Info.plist")), format: nil) as? [String: Any])
        #expect(info["TelemetryDeckAppID"] as? String == "$(TELEMETRYDECK_APP_ID)")
        let man = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: res.appendingPathComponent("PrivacyInfo.xcprivacy")), format: nil) as? [String: Any])
        #expect(man["NSPrivacyTracking"] as? Bool == false)
        let collected = try #require(man["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let pi = try #require(collected.first { $0["NSPrivacyCollectedDataType"] as? String == "NSPrivacyCollectedDataTypeProductInteraction" })
        #expect(pi["NSPrivacyCollectedDataTypeLinked"] as? Bool == false && pi["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
        #expect(pi["NSPrivacyCollectedDataTypePurposes"] as? [String] == ["NSPrivacyCollectedDataTypePurposeAnalytics"])
    }
}
