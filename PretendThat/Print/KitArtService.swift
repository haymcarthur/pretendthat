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
    func cutoutImages(_ item: KitItem) -> [UIImage?] { KitArtPrompt.cutoutLabels(item).indices.map { cutouts[item.id]?[$0] } }

    func generate(kit: Kit, gameTitle: String) async {
        guard let client else { finished = true; return }   // app-drawn pages: final right away
        guard !isGenerating else { return }
        isGenerating = true
        finished = false
        defer { isGenerating = false; finished = true }
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
                    if let image = UIImage(data: data) {
                        let parts = id.split(separator: "#")
                        if parts.count == 2, let n = Int(parts[1]) { cutouts[String(parts[0]), default: [:]][n] = image }
                        else { images[id] = image }
                        lastResult = "OK (\(client.workingModel ?? "?"))"
                    }
                    else { lastResult = "Error: image data unreadable" }
                case .failure(let e):
                    lastResult = "Error: \(client.unavailableReason ?? String(describing: e))"
                }
                done += 1
                progress = Double(done) / Double(max(1, jobs.count))
            }
        }
    }
}
