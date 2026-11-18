import UIKit
import Vision
import NutmegCore

/// Round 46: reads an AI-drawn page's words on the device (Apple Vision, accurate, language correction off so a
/// misspelling isn't silently "fixed"), for `PageWordCheck`. Nothing leaves the device; the page's words are the kit's
/// own (never anything about kids). Printables draw-once (2026-11-17): the same read also measures each text box's
/// letter contrast on a color page (`LetterContrast`, guardrail 2; logged only since 2026-11-18).
enum PageOCR {
    /// The text Vision reads on the image, top to bottom, with each line's box (Vision's normalized, bottom-left origin).
    nonisolated static func observations(_ cg: CGImage) -> [(text: String, box: CGRect)] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["en-US"]
        do { try VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req]) } catch { return [] }
        return (req.results ?? []).compactMap { o in o.topCandidates(1).first.map { ($0.string, o.boundingBox) } }
    }

    /// The text lines Vision reads on the image, top to bottom (empty if it can't read it).
    nonisolated static func lines(_ image: UIImage) -> [String] {
        guard let cg = image.cgImage else { return [] }
        return observations(cg).map(\.text)
    }

    /// Reads the page and checks it against its words.
    nonisolated static func check(_ image: UIImage, words: [String]) -> (PageWordCheck.Result, [String]) {
        let read = lines(image)
        return (PageWordCheck.check(words: words, lines: read), read)
    }

    /// Printables draw-once: one read of a color page → its word check and its pale-letter boxes.
    nonisolated static func inspect(_ image: UIImage, words: [String], contrast: Bool) -> PageInspection {
        guard let cg = image.cgImage else { return PageInspection(words: words.isEmpty ? nil : PageWordCheck.check(words: words, lines: []), lightBoxes: 0) }
        let obs = observations(cg)
        let read = obs.map(\.text)
        let wordCheck = words.isEmpty ? nil : PageWordCheck.check(words: words, lines: read)
        guard contrast, let rgba = rgbaPixels(cg) else { return PageInspection(words: wordCheck, read: read, lightBoxes: 0) }
        let w = cg.width, h = cg.height
        var light = 0
        for o in obs where o.text.filter(\.isLetter).count >= 2 || o.text.filter(\.isNumber).count >= 2 {
            // Vision's box (normalized, bottom-left) → pixels (top-left), grown by half its height as the surrounding.
            let r = CGRect(x: o.box.minX * CGFloat(w), y: (1 - o.box.maxY) * CGFloat(h), width: o.box.width * CGFloat(w), height: o.box.height * CGFloat(h)).integral
            guard r.height >= CGFloat(h) * 0.012, r.width >= 8 else { continue }   // tiny print (a "Name:" line) isn't judged
            let m = max(4, Int(r.height * 0.5))
            let outer = r.insetBy(dx: -CGFloat(m), dy: -CGFloat(m)).intersection(CGRect(x: 0, y: 0, width: w, height: h)).integral
            let ow = Int(outer.width), oh = Int(outer.height), ox = Int(outer.minX), oy = Int(outer.minY)
            guard ow > 2, oh > 2 else { continue }
            var px = [UInt8](repeating: 255, count: ow * oh * 4)
            for y in 0..<oh {
                let src = ((oy + y) * w + ox) * 4
                px.replaceSubrange((y * ow * 4)..<((y + 1) * ow * 4), with: rgba[src..<(src + ow * 4)])
            }
            let box = TextBoxPixels(width: ow, height: oh, rgba: px,
                                    inner: (Int(r.minX) - ox, Int(r.minY) - oy, Int(r.width), Int(r.height)))
            if LetterContrast.judge(box).tooLight { light += 1 }
        }
        return PageInspection(words: wordCheck, read: read, lightBoxes: light)
    }

    /// The image as 8-bit RGBA (premultiplied on an opaque white page = plain RGB), top row first.
    nonisolated static func rgbaPixels(_ cg: CGImage) -> [UInt8]? {
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 255, count: w * h * 4)
        let ok = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? px : nil
    }
}
