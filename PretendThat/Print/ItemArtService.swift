import SwiftUI
import UIKit
import NutmegCore

/// Sticker illustrations for the things Nutmeg presents (ideas, roles, props), D5.
/// One image per subject, generated in parallel with OpenAI (transparent background, quality low for speed),
/// cached for this adventure only (in memory; `reset()` on leave/new game). No names are ever in a prompt.
@Observable @MainActor
final class ItemArtService {
    private(set) var images: [String: UIImage] = [:]
    /// Last result, for the Grown-ups debug line.
    private(set) var lastResult: String?
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let client: ImageClient?

    init(client: ImageClient?) { self.client = client }

    static func key(_ kind: StickerPrompt.Kind, _ subject: String) -> String {
        "\(kind):\(subject.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    func image(_ kind: StickerPrompt.Kind, _ subject: String) -> UIImage? { images[Self.key(kind, subject)] }

    func reset() { images = [:]; inFlight = []; generation += 1 }

    /// Starts any missing illustrations in parallel; returns immediately.
    func request(_ jobs: [(kind: StickerPrompt.Kind, subject: String, detail: String)], game: String?) {
        guard let client else { return }
        let gen = generation
        for job in jobs {
            let key = Self.key(job.kind, job.subject)
            guard images[key] == nil, !inFlight.contains(key), !job.subject.isEmpty else { continue }
            inFlight.insert(key)
            let prompt = StickerPrompt.prompt(job.kind, subject: job.subject, detail: job.detail, game: game)
            Task { [weak self] in
                let result: Result<Data, Error>
                do { result = .success(try await client.generate(prompt: prompt, size: "1024x1024", quality: "low", background: "transparent")) }
                catch { result = .failure(error) }
                guard let self, self.generation == gen else { return }
                self.inFlight.remove(key)
                switch result {
                case .success(let data):
                    if let img = UIImage(data: data) { self.images[key] = img; self.lastResult = "OK" }
                case .failure(let e):
                    self.lastResult = "Error: \(client.unavailableReason ?? String(describing: e))"
                }
            }
        }
    }
}
