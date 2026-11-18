import Foundation

// 2026-11-18 (Haylee): "the titles on saved games are too long, I can't read them at all on the bookshelf." A saved
// game's title is SHORT: 1 to 3 words, about 18 characters at most ("Pet Hotel", "Moon Bakery", "Sea Vet Clinic"), so
// the shelf label can be big, one line, with no truncation dots. The AI gives a short title with set_theme
// (`short_title`); the app checks it, and falls back to a sensible cut of the full title (never mid-word). Older saved
// games keep their saved title: the shelf shows `shelf(_:)` of it, nothing is rewritten.
public enum GameTitles {
    public static let maxChars = 18
    public static let maxWords = 3

    static func words(_ s: String) -> [String] {
        s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map(String.init)
    }

    /// A title that already fits the shelf: 1 to 3 words, at most 18 characters.
    public static func isShort(_ title: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = words(t)
        return !w.isEmpty && w.count <= maxWords && t.count <= maxChars
    }

    /// The model's short title, tidied (quotes and end punctuation off), or nil when it doesn't fit.
    public static func cleanShort(_ raw: String?) -> String? {
        guard var t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’.!?,:;"))
        t = words(t).joined(separator: " ")
        return isShort(t) ? t : nil
    }

    /// The short version of any title, never cut mid-word: a leading "The" / "A" / "An" goes, then any tail from a
    /// linking word ("Pancake Restaurant on the Moon" → "Pancake Restaurant", "Bakery for Bugs" → "Bakery"), then words
    /// from the front while it stays within 3 words and 18 characters. A single long word stays whole.
    public static func shelf(_ title: String) -> String {
        let full = words(title.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !full.isEmpty else { return title }
        if isShort(full.joined(separator: " ")) { return full.joined(separator: " ") }
        var w = full
        if w.count > 1, ["the", "a", "an"].contains(w[0].lowercased()) { w.removeFirst() }
        let links: Set<String> = ["on", "in", "at", "for", "with", "of", "under", "from", "to", "and", "&", "by", "inside", "near"]
        if let cut = w.indices.dropFirst().first(where: { links.contains(w[$0].lowercased()) }) { w = Array(w[..<cut]) }
        var out: [String] = []
        for word in w {
            let next = (out + [word]).joined(separator: " ")
            if out.count >= maxWords || (next.count > maxChars && !out.isEmpty) { break }
            out.append(word)
        }
        // Never end on a dangling linking word or article ("Moon and").
        while out.count > 1, let last = out.last, links.union(["the", "a", "an"]).contains(last.lowercased()) { out.removeLast() }
        return out.isEmpty ? full[0] : out.joined(separator: " ")
    }

    /// The title a new saved game gets: the AI's short title when it fits, else the shelf cut of the full title.
    public static func saved(full: String, short: String?) -> String { cleanShort(short) ?? shelf(full) }
}
