import SwiftUI
import UIKit
import NutmegCore

/// Sticker illustrations for the things Nutmeg presents (ideas, roles, props), D5.
/// One image per subject, generated in parallel with OpenAI (transparent background, quality low for speed),
/// cached for this adventure only (in memory; `reset()` on leave/new game). No names are ever in a prompt.
@Observable @MainActor
final class ItemArtService {
    private(set) var images: [String: UIImage] = [:]
    /// Subjects whose sticker could not be drawn (no image key, an error, or slower than `patience`): the card
    /// resolves to a bundled stage illustration instead of shimmering forever.
    private(set) var unresolved: Set<String> = []
    /// How long a card shimmers before it settles on the fallback art (a late sticker still replaces it).
    static let patience: Duration = .seconds(30)
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let client: ImageClient?

    init(client: ImageClient?) { self.client = client }

    static func key(_ kind: StickerPrompt.Kind, _ subject: String) -> String {
        "\(kind):\(subject.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    func image(_ kind: StickerPrompt.Kind, _ subject: String) -> UIImage? { images[Self.key(kind, subject)] }

    /// The sticker, or (once it can't arrive) a neutral bundled stage illustration picked from the subject.
    func art(_ kind: StickerPrompt.Kind, _ subject: String) -> UIImage? {
        let key = Self.key(kind, subject)
        if let img = images[key] { return img }
        guard client == nil || unresolved.contains(key) else { return nil }
        return UIImage(named: Self.fallbackAssets[key.unicodeScalars.reduce(0) { $0 + Int($1.value) } % Self.fallbackAssets.count])
    }
    static let fallbackAssets = ["stage-star", "stage-crown", "stage-scroll", "stage-lamp", "stage-bulbs"]

    func reset() { images = [:]; inFlight = []; unresolved = []; generation += 1 }

    /// Starts any missing illustrations in parallel; returns immediately.
    func request(_ jobs: [(kind: StickerPrompt.Kind, subject: String, detail: String)], game: String?) {
        guard let client else { return }
        let gen = generation
        for job in jobs {
            let key = Self.key(job.kind, job.subject)
            guard images[key] == nil, !inFlight.contains(key), !job.subject.isEmpty else { continue }
            inFlight.insert(key)
            let prompt = StickerPrompt.prompt(job.kind, subject: job.subject, detail: job.detail, game: game)
            Task { [weak self] in   // patience timer: settle on the fallback art if the sticker is slow
                try? await Task.sleep(for: Self.patience)
                guard let self, self.generation == gen, self.images[key] == nil else { return }
                self.unresolved.insert(key)
            }
            Task { [weak self] in
                let result: Result<Data, Error>
                do { result = .success(try await client.generate(prompt: prompt, size: "1024x1024", quality: "low", background: "transparent")) }
                catch { result = .failure(error) }
                guard let self, self.generation == gen else { return }
                self.inFlight.remove(key)
                switch result {
                case .success(let data):
                    if let img = UIImage(data: data) { self.images[key] = img }
                case .failure(let e):
                    self.unresolved.insert(key)
                    rtLog("sticker failed: \(client.unavailableReason ?? String(describing: e))")
                }
            }
        }
    }
}
