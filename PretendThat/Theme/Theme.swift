import SwiftUI

/// Every color, font, radius, spacing and shadow in PretendThat lives here.
/// Nothing else in the app may hard-code one (components-first rule).
enum Theme {
    // MARK: Palette (brand: coral / deep purple / sunny yellow / lime)
    static let coral = Color(hex: 0xFF5A4E)
    static let purple = Color(hex: 0x3A1F6B)
    static let yellow = Color(hex: 0xFFC83D)
    static let lime = Color(hex: 0x9BDB3F)
    static let white = Color(hex: 0xFFFFFF)
    static let cream = Color(hex: 0xFFF7EA)

    // MARK: Semantic tokens
    static let background = white
    static let backgroundBrand = purple
    static let surface = cream
    static let ink = Color(hex: 0x24123F)
    static let inkOnBrand = white
    static let inkMuted = Color(hex: 0x6E5D8A)
    static let primary = coral
    static let accent = yellow
    static let success = lime
    static let scrim = Color.black.opacity(0.45)
    static let outline = ink.opacity(0.12)

    /// Colorblind-safe-ish set; always paired with a role symbol so color is never the only cue.
    static let playerColors: [Color] = [
        Color(hex: 0x2F7DE1), // blue
        Color(hex: 0xF08A24), // orange
        Color(hex: 0x14A38B), // teal
        Color(hex: 0xC2409A)  // magenta
    ]
    static func playerColor(_ index: Int) -> Color { playerColors[((index % 4) + 4) % 4] }

    // Printables are black line art on white paper (colorable).
    static let printInk = Color.black
    static let printPaper = Color.white
    static func printFont(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }

    // MARK: Type (heavy rounded; SF Rounded until a brand font is chosen)
    static func displayFont(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func bodyFont(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func emojiFont(_ size: CGFloat) -> Font { .system(size: size) }

    enum TextSize {
        static let hero: CGFloat = 56
        static let title: CGFloat = 40
        static let headline: CGFloat = 28
        static let body: CGFloat = 22
        static let caption: CGFloat = 16
    }

    // MARK: Shape, spacing, shadow
    static let cornerRadius: CGFloat = 28
    static let smallRadius: CGFloat = 16
    static let outlineWidth: CGFloat = 4

    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 12
        static let m: CGFloat = 20
        static let l: CGFloat = 32
        static let xl: CGFloat = 48
    }

    enum Size {
        static let minHit: CGFloat = 88
        static let mic: CGFloat = 120
        static let choiceTile: CGFloat = 200
        static let countTile: CGFloat = 124
        static let badge: CGFloat = 140
        static let thumbnail: CGFloat = 110
    }

    struct Shadow { let color: Color; let radius: CGFloat; let y: CGFloat }
    static let shadow = Shadow(color: Color.black.opacity(0.18), radius: 0, y: 6)   // flat "sticker" drop

    // MARK: Nutmeg
    /// Neck point on the HEAD canvas (where the head meets the body; also its rotation pivot).
    static let nutmegHeadNeck = UnitPoint(x: 0.5, y: 0.80)

    // MARK: Motion (bouncy: Nutmeg is excitable)
    static let springy = Animation.spring(response: 0.35, dampingFraction: 0.55)
    static let gentle = Animation.easeInOut(duration: 0.3)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
