import Testing
@testable import NutmegCore

@Suite struct BrandPaletteTests {
    @Test func contrastMathMatchesKnownValues() {
        #expect(abs(BrandPalette.contrast(0x000000, 0xFFFFFF) - 21) < 0.01)
        #expect(abs(BrandPalette.contrast(0x777777, 0xFFFFFF) - 4.48) < 0.02)
    }

    @Test func everyTextPairMeetsWCAG() {
        for pair in BrandPalette.textPairs {
            let ratio = BrandPalette.contrast(pair.fg, pair.bg)
            #expect(ratio >= pair.min, "\(pair.name): \(ratio) < \(pair.min)")
        }
    }

    @Test func plainCoralIsNotUsedUnderWhiteText() {
        // Documents why buttons use coralStrong: white on the brand coral is only ~2.8:1.
        #expect(BrandPalette.contrast(0xFFFFFF, BrandPalette.coral) < 3)
    }
}
