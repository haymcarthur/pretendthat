import CoreImage
import SwiftUI
import UIKit
import NutmegCore

/// Generates one line-art image per kit item with OpenAI (in parallel). There are no names anywhere (the app prints
/// blank name lines and role titles). The cut-outs page is generated as ONE IMAGE PER CUT-OUT (checklist-pictures.md),
/// tiled onto the page by the app, so each item can also be a checklist picture. Without a key, pages are app-drawn.
@Observable @MainActor
final class KitArtService {
    private(set) var images: [String: UIImage] = [:]
    /// Per-cut-out images: item id → index → image.
    private(set) var cutouts: [String: [Int: UIImage]] = [:]
    private(set) var isGenerating = false
    /// Every page's art has landed or definitively failed (or there's no image service): the kit is final.
    private(set) var finished = false
    /// Pages drawn so far / pages asked for, for the progress bar.
    private(set) var progress: Double = 0
    @ObservationIgnored private let client: ImageClient?

    init(client: ImageClient?) { self.client = client }

    var isAvailable: Bool { client != nil }
    /// Set after OpenAI says this account can't make images this run (no credits, unverified org, bad key).
    var unavailableReason: String? { client?.unavailableReason }

    /// Round 19: a remade kit (corrected theme) starts a new generation; results from an older one are dropped.
    @ObservationIgnored private var generation = 0
    func reset() {
        generation += 1; images = [:]; cutouts = [:]; isGenerating = false; progress = 0; finished = false
        drawnFor = nil; inFlight = []; failed = []; retriedAfterAway = []; finalItems = nil; landedAt = [:]
        plan = nil; landedSheets = []
    }

    func cutout(_ itemID: String, _ index: Int) -> UIImage? { cutouts[itemID]?[index] }
    /// The cut-out images of an item in order (nil where not drawn yet).
    #if DEBUG
    /// `-PTFakeArt`: test images at the real AI sizes (an off-white sheet with a soft shadow, a red edge frame and a
    /// label touching the bottom edge), so the print path can be checked for clipping without paid image calls.
    private func fakeArt(_ kit: Kit) {
        func make(_ size: String, _ label: String) -> UIImage {
            let p = size.split(separator: "x").compactMap { Double($0) }
            let s = CGSize(width: p.first ?? 1024, height: p.last ?? 1024)
            return PaperWhite.normalize(UIGraphicsImageRenderer(size: s).image { c in
                UIColor(white: 0.95, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: s))
                UIColor(white: 0.86, alpha: 1).setFill(); c.fill(CGRect(x: s.width * 0.2, y: s.height * 0.3, width: s.width * 0.6, height: s.height * 0.4))
                UIColor.red.setStroke(); c.cgContext.setLineWidth(12); c.cgContext.stroke(CGRect(origin: .zero, size: s).insetBy(dx: 6, dy: 6))
                let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: s.width / 9), .foregroundColor: UIColor.black]
                let t = NSAttributedString(string: label, attributes: a); let ts = t.size()
                t.draw(at: CGPoint(x: (s.width - ts.width) / 2, y: s.height - ts.height - 14))
            })
        }
        for item in kit.items {
            if item.recipe == .cutouts, !KitArtPrompt.cutoutLabels(item).isEmpty {
                for n in KitArtPrompt.cutoutLabels(item).indices { cutouts[item.id, default: [:]][n] = make("1024x1024", "BOTTOM") }
            } else { images[item.id] = make(KitArtPrompt.size(for: item), "BOTTOM") }
        }
        finished = true
    }
    #endif

    func cutoutImages(_ item: KitItem) -> [UIImage?] { KitArtPrompt.cutoutLabels(item).indices.map { cutouts[item.id]?[$0] } }

    /// Round 20: what the art in hand was drawn for (title + style). A different one starts over.
    @ObservationIgnored private var drawnFor: String?
    /// Jobs running or settled this generation (landed, or given up after one retry: the page is app-drawn).
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private var failed: Set<String> = []
    @ObservationIgnored private var retriedAfterAway: Set<String> = []
    /// The final kit's items (nil during the hunt): `finished` is about these.
    @ObservationIgnored private var finalItems: [KitItem]?
    /// Round 20: at most 3 image calls at once (the relay's 40 images/min limit; no 429 bursts).
    static let concurrency = 3
    @ObservationIgnored private let limiter = AsyncLimiter(limit: KitArtService.concurrency)
    /// DEBUG timing: when each job landed.
    @ObservationIgnored private(set) var landedAt: [String: Date] = [:]

    /// Round 20: the kit pages written during the hunt: their art starts now, in the background (no commentary).
    func prepare(items: [KitItem], gameTitle: String, style: PrintStyle) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTFakeArt") { return }
        #endif
        guard let client else { return }
        startOver(ifNot: "\(gameTitle)|\(style.rawValue)")
        NSLog("[RT] kit art: hunt prefetch, %d item(s)", items.count)
        plan = (items, gameTitle, style, nil)
        launch(KitArtPlan.jobs(items: items, title: gameTitle, style: style, settled: settled), client: client, style: style)
    }
    /// The latest items asked for (a failed cut-out sheet falls back to one image per cut-out from these).
    @ObservationIgnored private var plan: (items: [KitItem], title: String, style: PrintStyle, sheetCount: Int?)?
    @ObservationIgnored private var landedSheets: Set<String> = []

    /// The final kit (hunt over): any art not drawn or drawing yet starts now (the skipped props' cut-outs, a page that
    /// was never prefetched); `finished` once every page has landed or definitively fallen back.
    func generate(kit: Kit, gameTitle: String, style: PrintStyle, sheetCount: Int? = nil) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTFakeArt") { fakeArt(kit); return }
        #endif
        guard let client else { finished = true; return }   // app-drawn pages: final right away
        startOver(ifNot: "\(gameTitle)|\(style.rawValue)")
        finalItems = kit.items
        let gen = generation
        plan = (kit.items, gameTitle, style, sheetCount)
        let jobs = KitArtPlan.jobs(items: kit.items, title: gameTitle, style: style, settled: settled, sheetCount: sheetCount)
        NSLog("[RT] kit art: final kit, %d new job(s), %d already drawing, %d landed", jobs.count, inFlight.count,
              images.count + cutouts.values.map(\.count).reduce(0, +))
        launch(jobs, client: client, style: style)
        updateFinished()
        // Wait here until the kit is final (callers don't depend on it, but it keeps the old async shape).
        while gen == generation && !finished { try? await Task.sleep(for: .milliseconds(200)) }
    }

    private var settled: Set<String> {
        var s = inFlight.union(failed).union(images.keys).union(landedSheets)
        for (id, m) in cutouts { for n in m.keys { s.insert(KitArtPlan.cutoutKey(id, n)) } }
        return s
    }

    private func startOver(ifNot key: String) {
        guard drawnFor != key else { return }
        if drawnFor != nil { reset() }
        drawnFor = key
    }

    private func launch(_ jobs: [KitArtJob], client: ImageClient, style: PrintStyle) {
        let gen = generation
        isGenerating = isGenerating || !jobs.isEmpty
        for job in jobs {
            inFlight.insert(job.key)
            Task { @MainActor in
                let limiter = self.limiter
                // Retry once, then the existing fallback (that page is app-drawn).
                let result: Result<Data, Error>
                do { result = .success(try await RetryOnce.run { try await limiter.run { try await client.generate(prompt: job.prompt, size: job.size, quality: ImageQuality.kit) } }) }
                catch { result = .failure(error) }
                // Round 21: decode + paper-white + slicing run OFF the main actor (they held the main thread for a
                // moment during the prop hunt, when taps and her voice need it).
                let sheet = KitArtPlan.isSheet(job.key), count = job.count
                var decoded: [UIImage] = []
                if case .success(let data) = result {
                    decoded = await Task.detached(priority: .utility) { () -> [UIImage] in
                        guard let img = UIImage(data: data) else { return [] }
                        let white = PaperWhite.normalize(img, style: style)
                        return sheet ? CutoutSlicer.slice(white, count: count) : [white.preparedForDisplay()]
                    }.value
                }
                guard gen == self.generation else { return }   // a remade kit: this old page is dropped
                self.inFlight.remove(job.key)
                switch result {
                case .success:
                    if sheet {
                        let id = String(job.key.dropLast("#sheet".count))
                        let parts = decoded
                        if parts.count == job.count {
                            for (n, img) in parts.enumerated() { self.cutouts[id, default: [:]][n] = img }
                            self.landedSheets.insert(job.key); self.landedAt[job.key] = Date()
                        } else { self.sheetFailed(id, client: client, style: style) }
                    } else if let image = decoded.first {
                        let parts = job.key.split(separator: "#")
                        if parts.count == 2, let n = Int(parts[1]) { self.cutouts[String(parts[0]), default: [:]][n] = image }
                        else { self.images[job.key] = image }
                        self.landedAt[job.key] = Date()
                    } else { self.failed.insert(job.key) }
                case .failure(let e):
                    // Round 9: a network failure (locked or backgrounded mid-kit) gets one more try once the app is back.
                    let transient = e is URLError || (e as? ClaudeError) == .transport
                    if transient, client.unavailableReason == nil, !self.retriedAfterAway.contains(job.key) {
                        self.retriedAfterAway.insert(job.key)
                        while UIApplication.shared.applicationState != .active { try? await Task.sleep(for: .milliseconds(500)) }
                        guard gen == self.generation else { return }
                        NSLog("[RT] kit art: retrying %@ after a network failure", job.key)
                        self.launch([job], client: client, style: style)
                        return
                    }
                    NSLog("[RT] kit art: %@ failed twice (%@): app-drawn", job.key, client.unavailableReason ?? String(describing: e))
                    if KitArtPlan.isSheet(job.key) { self.sheetFailed(String(job.key.dropLast("#sheet".count)), client: client, style: style) }
                    else { self.failed.insert(job.key) }
                }
                self.updateFinished()
            }
        }
    }

    /// The cut-out sheet didn't work out: those cut-outs are drawn one each instead (the old way).
    private func sheetFailed(_ itemID: String, client: ImageClient, style: PrintStyle) {
        failed.insert(KitArtPlan.sheetFailedKey(itemID))
        guard let plan else { return }
        NSLog("[RT] kit art: cut-out sheet failed: one image per cut-out instead")
        launch(KitArtPlan.jobs(items: plan.items, title: plan.title, style: plan.style, settled: settled, sheetCount: plan.sheetCount)
                .filter { $0.key.hasPrefix(itemID + "#") }, client: client, style: style)
    }

    private func updateFinished() {
        isGenerating = !inFlight.isEmpty
        guard let items = finalItems else { return }
        let need = KitArtPlan.keys(items: items)
        let s = settled.subtracting(inFlight)
        progress = need.isEmpty ? 1 : Double(need.intersection(s).count) / Double(need.count)
        if need.isSubset(of: s) { finished = true }
    }
}

/// Paper-white AI art (Haylee, page preview fix): the image model paints near-white, off-white or light-gray paper and
/// soft drop shadows behind items. A tone curve lifts everything above ~84% luminance to pure white, so every tile
/// sits flat on the one white sheet (dark line art is unchanged).
extension UIImage {
    /// Round 21: fully decoded off the main thread, so the first draw on screen doesn't decode it there.
    nonisolated func preparedForDisplay() -> UIImage { preparingForDisplay() ?? self }
}

enum PaperWhite {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    /// Round 20: full-color art only lifts the near-white paper (above ~94%), so light colors keep their tint.
    static func normalize(_ image: UIImage, style: PrintStyle = .colorIn) -> UIImage {
        guard let input = CIImage(image: image) else { return image }
        let f = CIFilter(name: "CIToneCurve")!
        f.setValue(input, forKey: kCIInputImageKey)
        let points: [(CGFloat, CGFloat)] = style == .fullColor
            ? [(0, 0), (0.25, 0.25), (0.5, 0.5), (0.9, 0.9), (0.95, 1)]
            : [(0, 0), (0.3, 0.3), (0.6, 0.62), (0.76, 0.84), (0.84, 1)]
        for (i, p) in points.enumerated() { f.setValue(CIVector(x: p.0, y: p.1), forKey: "inputPoint\(i)") }
        guard let out = f.outputImage, let cg = context.createCGImage(out, from: input.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}

/// Round 20: slices a cut-out sheet into one image per cut-out (`CutoutSheet.cells` finds the cells).
enum CutoutSlicer {
    static func slice(_ image: UIImage, count: Int) -> [UIImage] {
        guard let cg = image.cgImage else { return [] }
        let w = cg.width, h = cg.height
        var gray = [UInt8](repeating: 255, count: w * h)
        let ok = gray.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return [] }
        return CutoutSheet.cells(gray: gray, width: w, height: h, count: count).compactMap { r in
            cg.cropping(to: CGRect(x: r.x, y: r.y, width: r.width, height: r.height)).map { UIImage(cgImage: $0, scale: image.scale, orientation: .up) }
        }
    }
}
