import Foundation
import Testing
@testable import NutmegCore

/// Round 37 compliance: the AI-content report (App Store 1.2), the AI disclosure, the privacy manifest and the export
/// compliance key. The report carries only a game's title and one part's AI-made text, never anything about the kids.
@Suite struct Round37ComplianceTests {
    let a = Fallback.airplane

    var arcKit: Kit {
        Bookends.repair(Bookends.ensure(a.kit), props: a.props.props, roles: a.plan.roles, title: "Airplane").kit
    }

    @Test func everyPartOfAGameCanBeReported() {
        let parts = ContentReport.parts(arcKit)
        let ids = parts.map(\.id)
        #expect(ids.filter { $0.hasPrefix("page:") }.count == a.kit.items.count)
        #expect(ids.contains("story") && ids.contains("setup") && ids.contains("cleanup"))
        #expect(ids.filter { $0.hasPrefix("scene:") } == ["scene:1", "scene:2", "scene:3"])
        #expect(parts.allSatisfy { !$0.label.isEmpty && !$0.text.isEmpty })
        // An older kit (no arc) still has its pages and scenes.
        let old = ContentReport.parts(Kit(nutmegSays: "", items: a.kit.items, scenes: a.kit.scenes))
        #expect(!old.contains { $0.id == "story" || $0.id == "setup" } && old.contains { $0.id == "scene:1" })
    }

    @Test func theEmailCarriesOnlyTheGameText() throws {
        let part = try #require(ContentReport.parts(arcKit).first { $0.id == "scene:2" })
        let body = ContentReport.body(game: "Sky Airlines", part: part, appVersion: "1.0 (1)")
        #expect(body.contains("Game: Sky Airlines") && body.contains("Part: scene:2") && body.contains(part.text))
        #expect(body.contains("Nothing about your child is included."))
        for word in ["player", "transcript", "kid said", "name:", "device", "UUID"] {
            #expect(!body.lowercased().contains(word.lowercased()), "\(word)")
        }
        let url = try #require(ContentReport.mailURL(game: "Sky Airlines", part: part, appVersion: "1.0 (1)"))
        #expect(url.scheme == "mailto" && url.absoluteString.hasPrefix("mailto:support@pretendthat.app?subject="))
        let c = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(c.queryItems?.first { $0.name == "body" }?.value == body)
        #expect(ContentReport.subject(game: "Sky Airlines", part: part) == "Report a problem: Sky Airlines (scene:2)")
        // Long text is capped.
        let long = ContentReport.Part(id: "story", label: "Story", text: String(repeating: "a", count: 5000))
        #expect(ContentReport.body(game: "x", part: long, appVersion: "1").count < 2200)
    }

    @Test func reportIsAGrownUpsRowBehindTheGate() {
        #expect(GrownUpsSection.visible().contains(.reportProblem))
        #expect(GrownUpsSection.reportProblem.webPage == nil && GrownUpsSection.reportProblem.group == 3)
        #expect(ReportCopy.intro.contains("made by AI") && ReportCopy.intro.contains("nothing about your child"))
    }

    @Test func nutmegSaysSheIsAComputerHelper() {
        #expect(GameGreeting.firstIntro.contains("made by a computer"))
        let about = GrownUpsCopy.about.map { $0.title + " " + $0.body }.joined(separator: " ")
        #expect(about.contains("Nutmeg is an AI helper") && about.contains("made by AI") && about.contains("Report a problem"))
        #expect(OnboardingCopy.consentScreenBody.contains("OpenAI and Anthropic"))
    }

    /// The app's own files (the test runs from the package; the app folder is next to it).
    static var appResources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("PretendThat/Resources")
    }

    @Test func thePrivacyManifestDeclaresWhatTheAppUses() throws {
        let data = try Data(contentsOf: Self.appResources.appendingPathComponent("PrivacyInfo.xcprivacy"))
        let p = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(p["NSPrivacyTracking"] as? Bool == false)
        #expect((p["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
        let apis = try #require(p["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let byType = Dictionary(uniqueKeysWithValues: apis.map { ($0["NSPrivacyAccessedAPIType"] as! String, $0["NSPrivacyAccessedAPITypeReasons"] as! [String]) })
        #expect(byType["NSPrivacyAccessedAPICategoryUserDefaults"] == ["CA92.1"])
        let collected = try #require(p["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        #expect(collected.allSatisfy { $0["NSPrivacyCollectedDataTypeLinked"] as? Bool == false && $0["NSPrivacyCollectedDataTypeTracking"] as? Bool == false })
        let info = try Data(contentsOf: Self.appResources.appendingPathComponent("Info.plist"))
        let plist = try #require(try PropertyListSerialization.propertyList(from: info, format: nil) as? [String: Any])
        #expect(plist["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }
}
