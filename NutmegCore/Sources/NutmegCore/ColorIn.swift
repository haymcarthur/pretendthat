import Foundation

// Printables: draw once, color in (Haylee, decisions/2026-11-17-printables-draw-once-color-in.md; test in
// design/printables-match-test/). Each printable is drawn ONCE as the coloring (outline) page; the color page is made
// from that exact image with the image EDIT endpoint ("color it in, change nothing"), so both sets match except for
// color. Guardrails (Haylee: "as long as we can put guardrails around some of the light color choices"):
//   1. the color prompt forbids white / cream / pale-yellow / pastel letter fills and yellow on white, keeps white paper;
//   2. an on-device contrast check per text box (letter fill vs what's around it), LOG ONLY since 2026-11-18 (Haylee,
//      decisions/2026-11-18-small-fixes.md): its automatic re-color cost ~10¢ a game and fixed nothing (the pet hotel
//      game: 3 pages re-colored, all still flagged, the letters were readable), so pale letters never trigger a redraw;
//   3. the word check runs on the color page (an edit once turned "002" into "202"): a miss gets ONE re-edit.
// This file is pure (bytes and numbers in, decisions out) so it's unit-tested; the app supplies Vision and the pixels.

// MARK: - The edit prompt

public enum ColorInPrompt {
    /// The kit's color style line without its "Art style for the whole kit: " prefix (the same look as a drawn page).
    public static var colorStyle: String {
        let s = KitPagePrompt.style(.fullColor)
        let prefix = "Art style for the whole kit: "
        return s.hasPrefix(prefix) ? String(s.dropFirst(prefix.count)) : s
    }

    /// The letters rule (guardrail 1): strong, readable letter fills only, and white paper.
    public static let letters = "Every word, letter and number must be easy to read: fill letters with dark ink (deep "
        + "purple or dark navy) or a strong saturated color (coral red, deep purple, sky blue, lime green) with a dark "
        + "outline. Never fill letters with white, cream, pale yellow or any pastel, and never put yellow letters on "
        + "white. Keep the paper white: no full-page or big background color fills, color sits inside the shapes."

    /// The tuned v2 color prompt (design/printables-match-test/notes.md) plus the letters rule. `missing`: the words
    /// the color page's word check missed (the one re-edit).
    public static func prompt(missing: [String] = []) -> String {
        var p = "This is a finished coloring page. Color it in, exactly like a child filling a coloring book with flat "
            + "paint: keep every existing line exactly where it is and fill only the enclosed shapes. Color style: "
            + colorStyle + " Copy every word, letter and number exactly as it is drawn, character for character (for "
            + "example \"002\" stays \"002\"); never redraw, flip or rewrite any text. Keep the thin gray dashed cut lines "
            + "exactly as they are. Keep the paper background and the big empty areas white; no full dark or saturated "
            + "background fill. Do not change, move, add or remove any line, shape, character or letter. " + letters
        let m = KitPagePrompt.unique(missing.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        if !m.isEmpty {
            p += " Copy these words exactly as they are drawn on the page, letter for letter: "
                + m.map { "\"\($0)\"" }.joined(separator: ", ") + "."
        }
        return p
    }
}

// MARK: - The contrast check (guardrail 2: measured and logged only, never a redraw)

/// One text box Vision found on a color page, as RGBA pixels (8 bits each, row by row) of the box grown by a margin,
/// with the text's own rect inside it. The margin is the "surrounding" the letters are read against.
public struct TextBoxPixels: Sendable {
    public var width: Int, height: Int
    public var rgba: [UInt8]
    /// The text box inside the pixels (x, y, width, height).
    public var inner: (x: Int, y: Int, width: Int, height: Int)
    public init(width: Int, height: Int, rgba: [UInt8], inner: (x: Int, y: Int, width: Int, height: Int)) {
        self.width = width; self.height = height; self.rgba = rgba; self.inner = inner
    }
}

public enum LetterContrast {
    /// Below this WCAG contrast ratio between the letter fill and its surroundings, the letters are too light
    /// (yellow #FFD23F on white ≈ 1.4, cream on white ≈ 1.1; coral, lime, sky blue and purple on white are ≥ 2).
    public static let minRatio = 1.7
    /// A pixel this far (RGB distance) from the surrounding color is part of the letters.
    static let markDistance = 24.0
    /// Letter pixels darker than this (relative luminance) are ink outlines, not fill.
    static let inkLuminance = 0.1

    public struct Box: Equatable, Sendable {
        /// Letter fill vs surrounding contrast (nil = letters are dark ink, or nothing measurable: fine).
        public var ratio: Double?
        public var tooLight: Bool { (ratio ?? .infinity) < LetterContrast.minRatio }
    }

    /// sRGB 0–255 → relative luminance (WCAG).
    public static func luminance(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Double {
        func lin(_ c: UInt8) -> Double {
            let v = Double(c) / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }
    public static func ratio(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }

    /// Judges one text box: the surrounding color (median of the margin), the letter pixels (inside the box, clearly
    /// different from the surrounding), split into dark ink (outlines) and fill. Mostly ink → fine. Otherwise the fill's
    /// median color against the surrounding.
    public static func judge(_ box: TextBoxPixels) -> Box {
        let w = box.width, h = box.height
        guard w > 2, h > 2, box.rgba.count >= w * h * 4 else { return Box(ratio: nil) }
        let ix = max(0, box.inner.x), iy = max(0, box.inner.y)
        let ix2 = min(w, box.inner.x + box.inner.width), iy2 = min(h, box.inner.y + box.inner.height)
        guard ix2 > ix, iy2 > iy else { return Box(ratio: nil) }
        var ringR: [UInt8] = [], ringG: [UInt8] = [], ringB: [UInt8] = []
        for y in 0..<h { for x in 0..<w where x < ix || x >= ix2 || y < iy || y >= iy2 {
            let o = (y * w + x) * 4
            ringR.append(box.rgba[o]); ringG.append(box.rgba[o + 1]); ringB.append(box.rgba[o + 2])
        } }
        guard !ringR.isEmpty else { return Box(ratio: nil) }
        let sr = median(ringR), sg = median(ringG), sb = median(ringB)
        let surround = luminance(sr, sg, sb)
        var fillR: [UInt8] = [], fillG: [UInt8] = [], fillB: [UInt8] = []
        var marks = 0
        for y in iy..<iy2 { for x in ix..<ix2 {
            let o = (y * w + x) * 4
            let r = box.rgba[o], g = box.rgba[o + 1], b = box.rgba[o + 2]
            let dr = Double(r) - Double(sr), dg = Double(g) - Double(sg), db = Double(b) - Double(sb)
            guard (dr * dr + dg * dg + db * db).squareRoot() > markDistance else { continue }
            marks += 1
            if luminance(r, g, b) >= inkLuminance { fillR.append(r); fillG.append(g); fillB.append(b) }
        } }
        let area = (ix2 - ix) * (iy2 - iy)
        // Too few letter pixels to judge, or the letters are mostly dark ink: readable.
        guard marks * 100 >= area * 3, fillR.count * 10 >= marks * 3 else { return Box(ratio: nil) }
        let fill = luminance(median(fillR), median(fillG), median(fillB))
        // Dark ink letters on a dark board are the board's problem, not a pale fill: only pale fills are judged.
        guard fill > surround || fill > 0.35 else { return Box(ratio: nil) }
        return Box(ratio: ratio(fill, surround))
    }

    /// A page is too light when any of its text boxes is.
    public static func pageTooLight(_ boxes: [Box]) -> Bool { boxes.contains(where: \.tooLight) }

    static func median(_ v: [UInt8]) -> UInt8 {
        var counts = [Int](repeating: 0, count: 256)
        for x in v { counts[Int(x)] += 1 }
        var seen = 0
        for (i, c) in counts.enumerated() { seen += c; if seen * 2 >= v.count { return UInt8(i) } }
        return 255
    }
}

// MARK: - The image calls and the color-in flow

/// The two image calls a kit page uses (`ImageClient`, or a fake in tests).
public protocol PageImaging: Sendable {
    func generate(prompt: String, size: String, quality: String) async throws -> Data
    /// The image EDIT endpoint: `image` (one PNG page) changed by `prompt`.
    func edit(image: Data, prompt: String, size: String, quality: String) async throws -> Data
}

/// What the device saw on one color page: its word check and its contrast check.
public struct PageInspection: Equatable, Sendable {
    public var words: PageWordCheck.Result?
    public var read: [String]
    /// Letter boxes judged too light (guardrail 2: logged only, never a redraw).
    public var lightBoxes: Int
    public var tooLight: Bool { lightBoxes > 0 }
    public init(words: PageWordCheck.Result?, read: [String] = [], lightBoxes: Int) {
        self.words = words; self.read = read; self.lightBoxes = lightBoxes
    }
    /// Words fine (or none to check). Pale letters don't count (2026-11-18: logged only, no re-color).
    public var ok: Bool { words?.ok ?? true }

    /// `b` is strictly better than `a`: fewer word misses first (the words matter most), then fewer pale letter boxes.
    public static func better(_ b: PageInspection, than a: PageInspection) -> Bool {
        let am = a.words?.missing.count ?? 0, bm = b.words?.missing.count ?? 0
        if am != bm { return bm < am }
        let asf = a.words?.shortfall ?? 0, bsf = b.words?.shortfall ?? 0
        if asf != bsf { return bsf < asf }
        return b.lightBoxes < a.lightBoxes
    }
}

public enum ColorInFlow {
    public struct Outcome: Sendable {
        /// The color page kept (nil: the edit failed twice; the caller's fallback takes over).
        public var data: Data?
        public var first: PageInspection?
        public var redraw: PageInspection?
        public var keptRedraw: Bool
        /// Edits asked for: 1, or 2 with the word redraw (each may have been retried once on an error).
        public var calls: Int
        /// Why the redraw was asked for (nil = no redraw).
        public var redrawReason: String?
        /// The kept page has letter boxes the contrast check calls pale (logged only).
        public var stillLight: Bool { (keptRedraw ? redraw : first)?.tooLight ?? false }
    }

    /// The color page of one printable: the outline page colored in with the edit endpoint (retried once on an error),
    /// then inspected on the device (`inspect`: the word check + the contrast check). Only a word miss gets ONE redraw
    /// (another edit of the SAME outline, with the missed words); pale letters are logged, never redrawn (2026-11-18).
    /// The strictly better of the two is kept, else the first.
    /// `away` (2026-11-18, printables after a lock): an edit cut off while the app was away is retried once it's back
    /// (`AwayRetry`); nil keeps the round 20 rule (retried once on an error).
    public static func color(outline: Data, size: String, quality: String, client: PageImaging, away: AwayPolicy? = nil,
                             inspect: @Sendable (Data) async -> PageInspection) async -> Outcome {
        var calls = 0
        func edit(_ prompt: String) async -> Data? {
            let op: @Sendable () async throws -> Data = { try await client.edit(image: outline, prompt: prompt, size: size, quality: quality) }
            if let away { return try? await AwayRetry.run(away, op) }
            // Each edit is retried once on an error (the round 20 rule for every image call).
            do { return try await RetryOnce.run(op) }
            catch { return nil }
        }
        calls += 1
        guard let first = await edit(ColorInPrompt.prompt()) else {
            return Outcome(data: nil, first: nil, redraw: nil, keptRedraw: false, calls: calls, redrawReason: nil)
        }
        let i1 = await inspect(first)
        guard !i1.ok else { return Outcome(data: first, first: i1, redraw: nil, keptRedraw: false, calls: calls, redrawReason: nil) }
        let missing = i1.words?.missing ?? []
        let reason = "words"
        calls += 1
        guard let second = await edit(ColorInPrompt.prompt(missing: missing)) else {
            return Outcome(data: first, first: i1, redraw: nil, keptRedraw: false, calls: calls, redrawReason: reason)
        }
        let i2 = await inspect(second)
        let keep = PageInspection.better(i2, than: i1)
        return Outcome(data: keep ? second : first, first: i1, redraw: i2, keptRedraw: keep, calls: calls, redrawReason: reason)
    }
}
