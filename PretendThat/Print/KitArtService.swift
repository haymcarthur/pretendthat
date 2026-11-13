import SwiftUI
import UIKit
import NutmegCore

/// Generates one line-art image per kit item with OpenAI (in parallel). Names are never in the prompt;
/// the app writes them on each card's blank banner. Without a key, pages use app-drawn vector cards.
@Observable @MainActor
final class KitArtService {
    private(set) var images: [String: UIImage] = [:]
    private(set) var isGenerating = false
    /// Pages drawn so far / pages asked for, for the progress bar.
    private(set) var progress: Double = 0
    /// Last kit-image result, for the Grown-ups debug line ("OK (model)" or the error).
    private(set) var lastResult: String?
    @ObservationIgnored private let client: ImageClient?

    init(client: ImageClient?) { self.client = client }

    var isAvailable: Bool { client != nil }
    /// Set after OpenAI says this account can't make images this run (no credits, unverified org, bad key).
    var unavailableReason: String? { client?.unavailableReason }

    func reset() { images = [:]; isGenerating = false; progress = 0 }

    func generate(kit: Kit, gameTitle: String) async {
        guard let client, !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        let jobs = kit.items.filter { images[$0.id] == nil }
            .map { ($0.id, KitArtPrompt.prompt(for: $0, gameTitle: gameTitle), KitArtPrompt.size(for: $0)) }
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
                    if let image = UIImage(data: data) { images[id] = image; lastResult = "OK (\(client.workingModel ?? "?"))" }
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
