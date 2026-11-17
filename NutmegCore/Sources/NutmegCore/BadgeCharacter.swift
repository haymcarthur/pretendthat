import Foundation

/// Round 29 (Haylee, ensemble scenes): each scene row shows the role's CHARACTER, cropped from its slice of the color
/// badge sheet: only the illustration between the two blank name banners (the badge prompt draws a blank banner across
/// the top quarter and another across the bottom fifth), with no badge frame and no blank fields. Pure (grayscale
/// pixels in, a pixel rectangle out) so it is unit-tested; the app crops the image and falls back to the role color chip.
public enum BadgeCharacter {
    /// A pixel this bright counts as white (the blank banners and the page).
    static let white: UInt8 = 232
    /// A row is "blank banner" when this much of its middle strip is white.
    static let blankRow = 0.9

    /// The character's rectangle in a badge slice (x, y, width, height in pixels). Finds the top banner's bottom edge
    /// and the bottom banner's top edge by scanning the middle strip (20%–80% of the width); a banner that isn't found
    /// uses the prompt's layout (26% from the top, 80% down). The frame is trimmed by 11% on each side.
    public static func rect(gray: [UInt8], width w: Int, height h: Int) -> (x: Int, y: Int, width: Int, height: Int) {
        guard w > 10, h > 10, gray.count >= w * h else { return (0, 0, w, h) }
        let x0 = w / 5, x1 = w - w / 5
        func whiteFraction(_ y: Int) -> Double {
            var n = 0
            for x in x0..<x1 where gray[y * w + x] >= white { n += 1 }
            return Double(n) / Double(x1 - x0)
        }
        // Top banner: the last blank row of the first blank run that starts in the top 40%.
        var top = Int(Double(h) * 0.26)
        var y = Int(Double(h) * 0.06)
        while y < Int(Double(h) * 0.40), whiteFraction(y) < blankRow { y += 1 }
        if y < Int(Double(h) * 0.40) {
            while y < h / 2, whiteFraction(y) >= blankRow { y += 1 }
            if y < h / 2 { top = y }
        }
        // Bottom banner: scanning up from the bottom, the first blank run that ends below 60%.
        var bottom = Int(Double(h) * 0.80)
        y = Int(Double(h) * 0.96)
        while y > Int(Double(h) * 0.60), whiteFraction(y) < blankRow { y -= 1 }
        if y > Int(Double(h) * 0.60) {
            while y > h / 2, whiteFraction(y) >= blankRow { y -= 1 }
            if y > h / 2 { bottom = y }
        }
        if bottom - top < h / 5 { top = Int(Double(h) * 0.26); bottom = Int(Double(h) * 0.80) }   // implausible: the layout
        let inset = Int(Double(w) * 0.11)
        return (inset, top, w - 2 * inset, bottom - top)
    }
}
