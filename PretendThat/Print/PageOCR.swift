import UIKit
import Vision
import NutmegCore

/// Round 46 (decisions/2026-11-17-ai-drawn-printables.md): reads the words on an AI-drawn page ON THE DEVICE (Apple
/// Vision, accurate, language correction off so a misspelling isn't "fixed" into the right word), for the forgiving
/// word check (`PageWordCheck`). Nothing leaves the iPad; nothing about kids is on the page.
enum PageOCR {
    /// The text lines Vision reads on the image, top to bottom (empty if it can't read it).
    nonisolated static func lines(_ image: UIImage) -> [String] {
        guard let cg = image.cgImage else { return [] }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["en-US"]
        do { try VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req]) } catch { return [] }
        return (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    /// Reads the page and checks it against its words.
    nonisolated static func check(_ image: UIImage, words: [String]) -> (PageWordCheck.Result, [String]) {
        let read = lines(image)
        return (PageWordCheck.check(words: words, lines: read), read)
    }
}
