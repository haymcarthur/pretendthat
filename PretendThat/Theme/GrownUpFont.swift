import SwiftUI
import UIKit

/// Round 39 (Haylee, decisions/2026-11-17-brand-font-poppins.md): the grown-up side (onboarding, Grown-ups, the plans
/// sheet) uses Poppins, bundled (SIL Open Font License 1.1; the license ships as Fonts/Poppins-OFL.txt and is credited in
/// Grown-ups → About). Headings Poppins SemiBold 600 with slightly tight letter spacing (about -0.02em, `headingKerning`),
/// body Poppins Regular / Medium. Every size is relative to a text style, so Dynamic Type scales it. Kid screens keep
/// SF Rounded (`Theme`).
enum GrownUpFont {
    enum Weight: String {
        case regular = "Poppins-Regular", medium = "Poppins-Medium", semiBold = "Poppins-SemiBold"
    }

    /// The bundled faces registered (UIAppFonts). If not, the system rounded font stands in (never a missing glyph).
    static let available: Bool = UIFont(name: Weight.semiBold.rawValue, size: 12) != nil

    /// Poppins at `size` (the default Dynamic Type size), scaled relative to `style`.
    static func font(_ weight: Weight, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        guard available else {
            let w: Font.Weight = weight == .semiBold ? .semibold : (weight == .medium ? .medium : .regular)
            return .system(size: size, weight: w, design: .rounded)
        }
        return .custom(weight.rawValue, size: size, relativeTo: style)
    }

    /// A heading (SemiBold 600).
    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font { font(.semiBold, size: size, relativeTo: style) }

    /// About -0.02em at `size` (apply with `.kerning(_:)` on heading text).
    static func headingKerning(_ size: CGFloat) -> CGFloat { -0.02 * size }

    /// The text style a fixed design size scales with.
    static func style(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 30...: .largeTitle
        case 24..<30: .title
        case 20..<24: .title3
        case 16..<20: .body
        case 14..<16: .subheadline
        default: .footnote
        }
    }

    /// Maps the old rounded weights onto Poppins: black / heavy / semibold = headings (SemiBold), bold = Medium, the
    /// rest Regular.
    static func weight(for w: Font.Weight) -> Weight {
        switch w {
        case .black, .heavy, .semibold: .semiBold
        case .bold: .medium
        default: .regular
        }
    }

    /// Navigation bars on the grown-up screens (Grown-ups, the plans sheet, Report a problem): Poppins SemiBold titles,
    /// scaled with Dynamic Type, slightly tight. Only grown-up screens have navigation bars.
    static func styleNavigationBars() {
        guard available, let large = UIFont(name: Weight.semiBold.rawValue, size: 34),
              let inline = UIFont(name: Weight.semiBold.rawValue, size: 17) else { return }
        let a = UINavigationBar.appearance()
        a.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large), .kern: headingKerning(34)]
        a.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline), .kern: headingKerning(17)]
    }
}
