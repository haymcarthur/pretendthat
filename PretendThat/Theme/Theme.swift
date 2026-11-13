import SwiftUI
import NutmegCore

/// Every color, font, radius, spacing, motion curve and shadow in PretendThat lives here.
/// Nothing else in the app may hard-code one (components-first rule).
/// Hex values come from `BrandPalette` (NutmegCore), where the text pairings are WCAG-tested.
enum Theme {
    // MARK: Palette (brand: coral / deep purple / sunny yellow / lime, plus nutmeg brown and cream)
    static let coral = Color(hex: BrandPalette.coral)
    static let coralStrong = Color(hex: BrandPalette.coralStrong)
    static let coralShade = Color(hex: BrandPalette.coralShade)
    static let purple = Color(hex: BrandPalette.purple)
    static let purpleShade = Color(hex: BrandPalette.purpleShade)
    static let yellow = Color(hex: BrandPalette.yellow)
    static let yellowShade = Color(hex: BrandPalette.yellowShade)
    static let lime = Color(hex: BrandPalette.lime)
    static let limeShade = Color(hex: BrandPalette.limeShade)
    static let nutmeg = Color(hex: BrandPalette.nutmeg)
    static let cream = Color(hex: BrandPalette.cream)
    static let creamShade = Color(hex: BrandPalette.creamShade)
    static let white = Color(hex: BrandPalette.white)
    static let limeTint = Color(hex: BrandPalette.limeTint)

    // MARK: Semantic tokens
    static let background = white
    static let backgroundBrand = purple
    static let surface = white
    static let ink = Color(hex: BrandPalette.ink)
    static let inkOnBrand = white
    static let inkMuted = Color(hex: BrandPalette.inkMuted)
    static let primary = coralStrong
    static let accent = yellow
    static let success = lime
    static let line = Color(hex: BrandPalette.line)
    static let disabled = Color(hex: BrandPalette.disabled)
    static let disabledInk = Color(hex: BrandPalette.disabledInk)
    static let scrim = Color.black.opacity(0.45)
    static let outline = line

    /// Always paired with a role symbol so color is never the only cue.
    static let playerColors: [Color] = BrandPalette.players.map { Color(hex: $0) }
    static func playerColor(_ index: Int) -> Color { playerColors[((index % 4) + 4) % 4] }
    static let playerShades: [Color] = BrandPalette.playerShades.map { Color(hex: $0) }
    static func playerShade(_ index: Int) -> Color { playerShades[((index % 4) + 4) % 4] }

    // Printables are black line art on white paper (colorable).
    static let printInk = Color.black
    static let printPaper = Color.white
    static func printFont(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }

    // MARK: Type (SF Rounded: black for display, heavy for headlines, bold for body)
    static func displayFont(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func headlineFont(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func bodyFont(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func emojiFont(_ size: CGFloat) -> Font { .system(size: size) }

    enum TextSize {
        static let hero: CGFloat = 64
        static let title: CGFloat = 40
        static let headline: CGFloat = 28
        static let button: CGFloat = 26
        static let body: CGFloat = 22
        static let caption: CGFloat = 17
    }

    // MARK: Shape, spacing, depth
    static let cornerRadius: CGFloat = 28
    static let buttonRadius: CGFloat = 24
    static let smallRadius: CGFloat = 16
    /// Soft border on white cards and quiet buttons (no thick dark outlines).
    static let borderWidth: CGFloat = 3
    static let outlineWidth: CGFloat = borderWidth
    /// The chunky "3D" bottom edge on buttons and cards; presses push the face down by this much.
    static let depth: CGFloat = 6
    static let cardDepth: CGFloat = 5

    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 12
        static let m: CGFloat = 20
        static let l: CGFloat = 32
        static let xl: CGFloat = 48
    }

    enum Size {
        static let minHit: CGFloat = 88
        static let mic: CGFloat = 112
        static let choiceTile: CGFloat = 200
        static let countTile: CGFloat = 124
        static let badge: CGFloat = 140
        static let thumbnail: CGFloat = 110
        static let check: CGFloat = 56
    }

    struct Shadow { let color: Color; let radius: CGFloat; let y: CGFloat }
    static let shadow = Shadow(color: Color.black.opacity(0.12), radius: 0, y: 4)

    // MARK: Nutmeg
    /// Neck point on the HEAD canvas (where the head meets the body; also its rotation pivot).
    static let nutmegHeadNeck = UnitPoint(x: 0.5, y: 0.80)
    /// Share of the screen width Nutmeg gets: bigger when she's the hero of the screen.
    static let nutmegColumn: CGFloat = 0.3
    static let nutmegHeroColumn: CGFloat = 0.4

    // MARK: Motion (bouncy, not chaotic: Nutmeg is excitable)
    static let springy = Animation.spring(response: 0.35, dampingFraction: 0.55)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.68)
    static let press = Animation.spring(response: 0.2, dampingFraction: 0.6)
    static let gentle = Animation.easeInOut(duration: 0.3)
    static let stagger: Double = 0.07
    /// Slow ambient loops for stage props.
    static let swayPeriod: Double = 4.2
    static let pulsePeriod: Double = 2.6
}

/// One solid background per phase (brand rule: solid fills, no scene art). Carries the text colors that read on it.
enum PTBackdrop: CaseIterable {
    case white, cream, backstage, spotlight

    var color: Color {
        switch self {
        case .white: Theme.white
        case .cream: Theme.cream
        case .backstage: Theme.purple
        case .spotlight: Theme.yellow
        }
    }
    var ink: Color { self == .backstage ? Theme.white : Theme.ink }
    var inkMuted: Color { self == .backstage ? Theme.cream : (self == .spotlight ? Theme.ink : Theme.inkMuted) }
    /// Spotlight glow behind Nutmeg.
    var glow: Color { self == .spotlight ? Theme.white : Theme.yellow }
    var glowOpacity: Double { self == .backstage ? 0.42 : 0.55 }
    /// Card edge under white cards on this backdrop.
    var cardEdge: Color {
        switch self {
        case .backstage: Theme.purpleShade
        case .spotlight: Theme.yellowShade
        case .cream: Theme.creamShade
        case .white: Theme.line
        }
    }
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
