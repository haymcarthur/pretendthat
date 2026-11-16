import Foundation

/// Brand colors as sRGB hex, plus a WCAG 2.x contrast check. The app's `Theme` builds its Colors from these,
/// so the text/background pairs it uses can be unit-tested here (see BrandPaletteTests).
public enum BrandPalette {
    // Brand (Haylee, brand-visual-style-and-layout.md)
    public static let coral: UInt32 = 0xFF6B5B        // curtains, decoration (not a text background)
    public static let coralStrong: UInt32 = 0xEE5242  // primary button face: white label ≥ 3:1 (large text)
    public static let coralShade: UInt32 = 0xC23B2D   // 3D bottom edge under coral
    public static let purple: UInt32 = 0x5B2A86       // backstage / play mode
    public static let purpleShade: UInt32 = 0x3F1A60
    public static let yellow: UInt32 = 0xFFC93C       // spotlight, "kit ready"
    public static let yellowShade: UInt32 = 0xE0A100
    public static let lime: UInt32 = 0x8BD346         // success, checks
    public static let limeShade: UInt32 = 0x67A82A
    public static let limeTint: UInt32 = 0xE3F5D0     // checked rows/cards
    public static let nutmeg: UInt32 = 0xA0623A       // Nutmeg's fur, warm accents
    public static let cream: UInt32 = 0xFFE9CF
    public static let creamShade: UInt32 = 0xF2CFA6
    public static let ink: UInt32 = 0x2A1846          // dark purple-navy text
    public static let inkMuted: UInt32 = 0x6E5D8A     // secondary text on white/cream (≥ 4.5:1)
    public static let white: UInt32 = 0xFFFFFF
    public static let line: UInt32 = 0xE8E2F0         // soft card border / quiet button edge (not text)
    public static let disabled: UInt32 = 0xE8E4EE
    public static let disabledInk: UInt32 = 0x585270

    /// Player (role) colors, always paired with a role symbol. White symbol on each ≥ 3:1. Round C1: 6 ranked roles,
    /// so R5 and R6 get two brand colors (Claude's call): the button coral and Nutmeg's warm brown.
    public static let players: [UInt32] = [0x2F6FD6, 0xD9650B, 0x0E8A75, 0xB8338F, coralStrong, nutmeg]
    public static let playerShades: [UInt32] = [0x1F52A8, 0xA84C05, 0x096656, 0x8A2269, coralShade, 0x7A4526]

    /// (foreground, background, minimum ratio) for every text pairing the app draws.
    /// 4.5 = WCAG AA body text; 3.0 = AA large text (≥ 24 px regular or ≥ 18.5 px bold; our buttons are 22–28 pt heavy).
    public static let textPairs: [(name: String, fg: UInt32, bg: UInt32, min: Double)] = [
        ("ink on white", ink, white, 4.5),
        ("ink on cream", ink, cream, 4.5),
        ("ink on yellow", ink, yellow, 4.5),
        ("ink on lime", ink, lime, 4.5),
        ("ink on limeTint", ink, limeTint, 4.5),
        ("inkMuted on limeTint", inkMuted, limeTint, 4.5),
        ("ink on coral", ink, coral, 4.5),
        ("inkMuted on white", inkMuted, white, 4.5),
        ("inkMuted on cream", inkMuted, cream, 4.5),
        ("white on purple", white, purple, 4.5),
        ("cream on purple", cream, purple, 4.5),
        ("yellow on purple", yellow, purple, 4.5),
        ("white on coralStrong (large)", white, coralStrong, 3.0),
        ("disabledInk on disabled", disabledInk, disabled, 4.5),
    ] + players.enumerated().map { ("white on player \($0.offset) (large)", white, $0.element, 3.0) }

    public static func relativeLuminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF) + 0.7152 * channel((hex >> 8) & 0xFF) + 0.0722 * channel(hex & 0xFF)
    }

    public static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (relativeLuminance(a), relativeLuminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
