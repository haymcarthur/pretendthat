import Foundation

// MARK: - Placing a page image on paper

/// Round 46: the model ignores margin requests (its pages run to the image edge), so the app places each 2:3 page image
/// fitted whole inside the printable area of the paper (never cropped, never stretched), centered. On US Letter (612 ×
/// 792 pt) with a half-inch margin that is 480 × 720 pt: about 6.7 × 10 inches.
public enum PageFit {
    /// Half an inch: inside every home printer's unprintable edge.
    public static let margin: Double = 36

    public static func rect(image: CGSize, page: CGSize, margin: Double = margin) -> CGRect {
        let box = CGRect(x: margin, y: margin, width: max(0, page.width - 2 * margin), height: max(0, page.height - 2 * margin))
        guard image.width > 0, image.height > 0, box.width > 0, box.height > 0 else { return box }
        let s = min(box.width / image.width, box.height / image.height)
        let w = image.width * s, h = image.height * s
        return CGRect(x: box.minX + (box.width - w) / 2, y: box.minY + (box.height - h) / 2, width: w, height: h)
    }
}
