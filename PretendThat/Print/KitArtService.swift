import SwiftUI
import UIKit
import NutmegCore

/// Generates one line-art image per kit item with OpenAI (in parallel). Names are never in the prompt;
/// the app writes them on each card's blank banner. Without a key, pages use app-drawn vector cards.
@Observable @MainActor
final class KitArtService {
    private(set) var images: [String: UIImage] = [:]
    private(set) var isGenerating = false
    @ObservationIgnored private let client: ImageClient?

    init(client: ImageClient?) { self.client = client }

    var isAvailable: Bool { client != nil }

    func reset() { images = [:]; isGenerating = false }

    func generate(kit: Kit, gameTitle: String) async {
        guard let client, !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        let jobs = kit.items.filter { images[$0.id] == nil }
            .map { ($0.id, KitArtPrompt.prompt(for: $0, gameTitle: gameTitle), KitArtPrompt.size(for: $0)) }
        await withTaskGroup(of: (String, Data?).self) { group in
            for (id, prompt, size) in jobs {
                group.addTask { (id, try? await client.generate(prompt: prompt, size: size)) }
            }
            for await (id, data) in group {
                if let data, let image = UIImage(data: data) { images[id] = image }
            }
        }
    }
}
