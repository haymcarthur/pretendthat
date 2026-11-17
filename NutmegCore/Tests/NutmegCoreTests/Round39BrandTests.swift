import Foundation
import Testing
@testable import NutmegCore

/// Round 39 brand: Poppins on the grown-up side (bundled + registered + the OFL text shipped), credits in About.
struct Round39BrandTests {
    /// The app folder (NutmegCore/Tests/NutmegCoreTests/<this file> → repo/PretendThat).
    static let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("PretendThat")

    @Test func poppinsIsBundledRegisteredAndLicensed() throws {
        let fonts = Self.app.appendingPathComponent("Resources/Fonts")
        let plist = try String(contentsOf: Self.app.appendingPathComponent("Resources/Info.plist"), encoding: .utf8)
        #expect(plist.contains("<key>UIAppFonts</key>"))
        for face in ["Poppins-Regular", "Poppins-Medium", "Poppins-SemiBold"] {
            let data = try Data(contentsOf: fonts.appendingPathComponent("\(face).ttf"))
            #expect(data.count > 100_000 && data.prefix(4) == Data([0, 1, 0, 0]), "\(face) is a TrueType font")
            #expect(plist.contains("<string>\(face).ttf</string>"))
        }
        let ofl = try String(contentsOf: fonts.appendingPathComponent("Poppins-OFL.txt"), encoding: .utf8)
        #expect(ofl.contains("SIL Open Font License, Version 1.1") && ofl.contains("The Poppins Project Authors"))
    }

    @Test func kidScreensKeepTheRoundedSystemFont() throws {
        // The kid-side Theme fonts stay SF Rounded; Poppins is only reached through GrownUpFont.
        let theme = try String(contentsOf: Self.app.appendingPathComponent("Theme/Theme.swift"), encoding: .utf8)
        #expect(!theme.contains("Poppins"))
        let grownUp = try String(contentsOf: Self.app.appendingPathComponent("Theme/GrownUpFont.swift"), encoding: .utf8)
        #expect(grownUp.contains("relativeTo") && grownUp.contains("-0.02"))
    }

    @Test func creditsNameEveryLibraryAndTheFont() {
        let names = GrownUpsCopy.credits.map(\.name)
        #expect(names == ["Signalsmith Stretch", "Signalsmith Linear", "TelemetryDeck SwiftSDK", "Poppins"])
        #expect(GrownUpsCopy.credits.first { $0.name == "Poppins" }?.license == GrownUpsCopy.oflLicenseName)
        #expect(GrownUpsCopy.credits.first { $0.name.hasPrefix("TelemetryDeck") }?.license == GrownUpsCopy.mitLicenseName)
        #expect(GrownUpsCopy.about.contains { $0.body.contains("saves itself") })
    }
}
