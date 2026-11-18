import Foundation

/// Round 46 (decisions/2026-11-17-ai-drawn-printables.md): the forgiving check of an AI-drawn page's words. The app
/// reads the page on the device (Apple Vision, language correction off: `PageOCR`) and compares what it read with the
/// page's quoted words (`PagePrompt.words`). The test (research/2026-11-17-ai-drawn-printables-test.md) showed a strict
/// match would have redrawn 4 good pages of 17, so the match is tolerant: spaces, underscores, "!" and other punctuation
/// don't count; letter case and accents don't count; look-alike letters are the same (Cyrillic and Greek capitals, 0/O,
/// 1/l/I, 5/S); and an "S" right before a digit is a "$" (hollow bubble-letter dollar signs). A word that is really
/// missing or misspelled is a miss, and only then is the page redrawn, once. Pure (strings in, a result out), so it's
/// unit-tested with the test's real OCR readings. Nothing about kids is in a page's words or the log.
public enum PageWordCheck {
    public struct Result: Equatable, Sendable {
        /// Each word the page must show and how many times (repeats: "Name:" on 4 badges is 4).
        public var wanted: [String: Int]
        /// How many times each word was read (tolerantly).
        public var found: [String: Int]
        /// The words really missing (a word wanted once wasn't read at all; a repeated word was read on fewer than half
        /// its copies). One-character words never count (a coin's "1", a card's number in a decorated circle).
        public var missing: [String]
        /// How many wanted copies weren't read, over every word (to keep the better of two drawings).
        public var shortfall: Int
        public var ok: Bool { missing.isEmpty }
    }

    /// Checks one page: `words` = every wanted occurrence (`PagePrompt.words`), `lines` = what the OCR read.
    public static func check(words: [String], lines: [String]) -> Result {
        var wanted: [String: Int] = [:], order: [String] = []
        for w in words where !fold(w).isEmpty {
            if wanted[w] == nil { order.append(w) }
            wanted[w, default: 0] += 1
        }
        let text = fold(lines.joined(separator: " "))
        var found: [String: Int] = [:], missing: [String] = [], shortfall = 0
        for w in order {
            let want = wanted[w]!
            var got = count(fold(w), in: text)
            // A phrase read in pieces (its lines out of order): every word of it is there.
            if got == 0, want == 1 {
                let parts = w.split(whereSeparator: \.isWhitespace).map { fold(String($0)) }.filter { !$0.isEmpty }
                if parts.count > 1, parts.allSatisfy({ text.contains($0) }) { got = 1 }
            }
            found[w] = got
            shortfall += max(0, want - got)
            let need = want == 1 ? 1 : (want + 1) / 2
            if got < need, fold(w).count > 1 { missing.append(w) }
        }
        return Result(wanted: wanted, found: found, missing: missing, shortfall: shortfall)
    }

    /// The better of two readings of the same page (fewer missing words, then fewer missing copies; a tie keeps `a`).
    public static func better(_ a: Result, _ b: Result) -> Bool {
        if a.missing.count != b.missing.count { return a.missing.count < b.missing.count }
        return a.shortfall <= b.shortfall
    }

    /// Look-alike letters read as the same letter (Cyrillic and Greek capitals and small letters that look Latin).
    static let lookAlikes: [Character: Character] = [
        "А": "A", "В": "B", "С": "C", "Е": "E", "Н": "H", "К": "K", "М": "M", "О": "O", "Р": "P", "Т": "T", "Х": "X",
        "З": "3", "Ѕ": "S", "І": "I", "Ј": "J", "У": "Y",
        "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "х": "x", "у": "y", "і": "i", "ј": "j", "ѕ": "s",
        "Α": "A", "Β": "B", "Ε": "E", "Ζ": "Z", "Η": "H", "Ι": "I", "Κ": "K", "Μ": "M", "Ν": "N", "Ο": "O", "Ρ": "P",
        "Τ": "T", "Υ": "Y", "Χ": "X", "ο": "o",
        "’": "'", "‘": "'", "＄": "$",
    ]

    /// The tolerant form: look-alikes mapped, S before a digit = $, no case or accents, only letters, digits and $,
    /// then the digit/letter look-alikes folded together (0 = o, 1 = l = i, 5 = s).
    public static func fold(_ s: String) -> String {
        var chars = Array(String(s.map { lookAlikes[$0] ?? $0 }))
        for i in chars.indices where (chars[i] == "S" || chars[i] == "s") && i + 1 < chars.count && chars[i + 1].isNumber
            && (i == 0 || !chars[i - 1].isLetter) {
            chars[i] = "$"
        }
        let plain = String(chars).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        return String(plain.compactMap { c -> Character? in
            guard c.isLetter || c.isNumber || c == "$" else { return nil }
            switch c {
            case "0": return "o"
            case "1", "i", "|": return "l"
            case "5": return "s"
            default: return c
            }
        })
    }

    /// Non-overlapping occurrences of `needle` in `hay`.
    static func count(_ needle: String, in hay: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var n = 0, range = hay.startIndex..<hay.endIndex
        while let r = hay.range(of: needle, range: range) { n += 1; range = r.upperBound..<hay.endIndex }
        return n
    }
}

/// Round 47 (Haylee's answer 1, option b): bubble letters read poorly, so a coloring (outline) page is checked ONLY when
/// the same printable's color page missed its words on its first drawing. A color page is always checked.
public enum OutlineWordCheck {
    public enum Action: Equatable, Sendable {
        /// Read the page and redraw once on a real miss.
        case check
        /// Keep the drawing without reading it.
        case keep
        /// The color page's first check isn't in yet: wait for it.
        case wait
    }

    /// What to do with one page's first drawing. `colorMissed`: the color page's first check (true = it missed, nil =
    /// not checked yet). `colorSettled`: the color page is done without a check (it failed, or has no words): keep.
    public static func action(style: PrintStyle, colorMissed: Bool?, colorSettled: Bool) -> Action {
        guard style == .colorIn else { return .check }
        if let colorMissed { return colorMissed ? .check : .keep }
        return colorSettled ? .keep : .wait
    }
}
