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
    /// Last kit-image result, for the Grown-ups debug line ("OK (model)" or the error).
    private(set) var lastResult: String?
    @ObservationIgnored private let client: ImageClient?

    init(client: ImageClient?) { self.client = client }

    var isAvailable: Bool { client != nil }
    /// Set after OpenAI says this account can't make images this run (no credits, unverified org, bad key).
    var unavailableReason: String? { client?.unavailableReason }

    func reset() { images = [:]; cutouts = [:]; isGenerating = false; progress = 0; finished = false }

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

    func generate(kit: Kit, gameTitle: String) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTFakeArt") { fakeArt(kit); return }
        #endif
        guard let client else { finished = true; return }   // app-drawn pages: final right away
        guard !isGenerating else { return }
        isGenerating = true
        finished = false
        defer { isGenerating = false; finished = true }
        // Round 9: a request that failed for a network reason (the iPad was locked or the app went to the background
        // mid-kit) is retried once the app is active again. The kit stays not-final meanwhile, so the papers and the
        // kit-ready line wait for it (and play once).
        for attempt in 0..<3 {
            let transient = await runMissingJobs(kit: kit, gameTitle: gameTitle, client: client)
            guard transient > 0, client.unavailableReason == nil, attempt < 2 else { break }
            while UIApplication.shared.applicationState != .active { try? await Task.sleep(for: .milliseconds(500)) }
            NSLog("[RT] kit art: retrying %d page(s) after a network failure", transient)
        }
    }

    /// Runs one image job per missing page/cut-out; returns how many failed for a network (transient) reason.
    private func runMissingJobs(kit: Kit, gameTitle: String, client: ImageClient) async -> Int {
        // Job key: "<item id>" for a whole item, "<item id>#<n>" for one cut-out.
        var jobs: [(String, String, String)] = []
        for item in kit.items {
            if item.recipe == .cutouts, !KitArtPrompt.cutoutLabels(item).isEmpty {
                for (n, label) in KitArtPrompt.cutoutLabels(item).enumerated() where cutouts[item.id]?[n] == nil {
                    jobs.append(("\(item.id)#\(n)", KitArtPrompt.cutoutPrompt(label, gameTitle: gameTitle), "1024x1024"))
                }
            } else if images[item.id] == nil {
                jobs.append((item.id, KitArtPrompt.prompt(for: item, gameTitle: gameTitle), KitArtPrompt.size(for: item)))
            }
        }
        progress = 0
        var done = 0
        var transient = 0
        await withTaskGroup(of: (String, Result<Data, Error>).self) { group in
            for (id, prompt, size) in jobs {
                group.addTask {
                    do { return (id, .success(try await client.generate(prompt: prompt, size: size))) }
                    catch { return (id, .failure(error)) }
                }
            }
            for await (id, result) in group {
                switch result {
                case .success(let data):
                    if let image = UIImage(data: data).map(PaperWhite.normalize) {
                        let parts = id.split(separator: "#")
                        if parts.count == 2, let n = Int(parts[1]) { cutouts[String(parts[0]), default: [:]][n] = image }
                        else { images[id] = image }
                        lastResult = "OK (\(client.workingModel ?? "?"))"
                    }
                    else { lastResult = "Error: image data unreadable" }
                case .failure(let e):
                    lastResult = "Error: \(client.unavailableReason ?? String(describing: e))"
                    if e is URLError || (e as? ClaudeError) == .transport { transient += 1 }
                }
                done += 1
                progress = Double(done) / Double(max(1, jobs.count))
            }
        }
        return transient
    }
}


/// Paper-white AI art (Haylee, page preview fix): the image model paints near-white, off-white or light-gray paper and
/// soft drop shadows behind items. A tone curve lifts everything above ~84% luminance to pure white, so every tile
/// sits flat on the one white sheet (dark line art is unchanged).
enum PaperWhite {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    static func normalize(_ image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else { return image }
        let f = CIFilter(name: "CIToneCurve")!
        f.setValue(input, forKey: kCIInputImageKey)
        f.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        f.setValue(CIVector(x: 0.3, y: 0.3), forKey: "inputPoint1")
        f.setValue(CIVector(x: 0.6, y: 0.62), forKey: "inputPoint2")
        f.setValue(CIVector(x: 0.76, y: 0.84), forKey: "inputPoint3")
        f.setValue(CIVector(x: 0.84, y: 1), forKey: "inputPoint4")
        guard let out = f.outputImage, let cg = context.createCGImage(out, from: input.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}
