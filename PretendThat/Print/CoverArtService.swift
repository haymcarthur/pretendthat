import SwiftUI
import UIKit
import NutmegCore

/// Round 27 (Haylee): the game's bookshelf cover. ONE full-color, wide (3:2), text-free picture of the game's scene,
/// drawn during the prop hunt (queued after both kit sets on the same limiter, so it never slows the pages) and kept
/// only if the game is saved (`AppModel.tapSave`). Same safety suffix and moderation as every kit image.
@Observable @MainActor
final class CoverArtService {
    private(set) var image: UIImage?
    @ObservationIgnored private let client: ImageClient?
    @ObservationIgnored private let limiter: AsyncLimiter
    @ObservationIgnored private var drawnFor: String?
    @ObservationIgnored private var generation = 0
    /// DEBUG timing: when the cover landed (or failed).
    @ObservationIgnored private(set) var settledAt: Date?
    private(set) var failed = false

    init(client: ImageClient?, limiter: AsyncLimiter) { self.client = client; self.limiter = limiter }

    func reset() { generation += 1; image = nil; drawnFor = nil; settledAt = nil; failed = false }

    /// Starts the cover for this title (a corrected title starts over; the same one is never drawn twice).
    func start(title: String, setting: String?) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTFakeArt") { return }
        #endif
        guard let client, !title.isEmpty, drawnFor != title else { return }
        if drawnFor != nil { reset() }
        drawnFor = title
        let gen = generation, limiter = limiter
        let prompt = CoverArt.prompt(title: title, setting: setting)
        NSLog("[RT] cover art: started")
        Task { @MainActor in
            let data = try? await RetryOnce.run { try await limiter.run { try await client.generate(prompt: prompt, size: CoverArt.size, quality: ImageQuality.kit) } }
            let img = await Task.detached(priority: .utility) { data.flatMap(UIImage.init(data:))?.preparedForDisplay() }.value
            guard gen == self.generation else { return }
            self.image = img; self.failed = img == nil; self.settledAt = Date()
            NSLog("[RT] cover art: %@", img == nil ? "failed (the shelf uses the color sign)" : "landed")
        }
    }

    /// The finished cover as a 600 × 400 JPEG, the same 3:2 shape as the drawn cover (the shelf card and the
    /// Grown-ups thumbnail aspect-fill it). Any other shape is centre-cropped to 3:2.
    nonisolated static func jpeg(_ image: UIImage) -> Data? {
        let out = CGSize(width: CoverArt.jpegWidth, height: CoverArt.jpegHeight)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: out, format: format).image { _ in
            let s = image.size, k = max(out.width / max(s.width, 1), out.height / max(s.height, 1))
            let w = s.width * k, h = s.height * k
            image.draw(in: CGRect(x: (out.width - w) / 2, y: (out.height - h) / 2, width: w, height: h))
        }.jpegData(compressionQuality: 0.82)
    }
}
