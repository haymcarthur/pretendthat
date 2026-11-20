import Foundation

// 2026-11-21 (Haylee's live test): tapping 🔊 on the clean-up item "Pick up paper scraps, crayons and scissors" made the
// live voice refuse ("Uh-oh, it's not safe for me to say it like that…") and say something else, so the card and the
// voice didn't match. One shared check: every line shown on a card or read aloud in Play (setup and clean-up items,
// events, calm-again lines, the opener, the finale) is made speakable BEFORE it's shown, so the card and her voice
// always say the same words. A word the voice won't say to kids is dropped from a list ("paper scraps, crayons and
// scissors" → "paper scraps and crayons") or swapped for a safe pretend word ("knife" → "spoon").

public enum Speakable {
    /// Words the voice won't say to kids (singular and plural), each with a safe stand-in for when it isn't in a list.
    public static let swaps: [(word: String, safe: String)] = [
        ("scissors", "crayons"), ("knives", "spoons"), ("knife", "spoon"), ("blades", "paddles"), ("blade", "paddle"),
        ("razors", "combs"), ("razor", "comb"), ("needles", "bandages"), ("needle", "bandage"), ("sharp", "pointy"),
        ("lighters", "flashlights"), ("lighter", "flashlight"), ("candles", "flashlights"), ("candle", "flashlight"),
        ("flames", "sparkles"), ("on fire", "too hot"), ("guns", "bubble wands"),
        ("gun", "bubble wand"), ("swords", "wands"), ("sword", "wand"), ("weapons", "tools"), ("weapon", "tool"),
        ("blood", "boo-boo"), ("poison", "yucky goo"), ("axe", "tool"), ("glass shards", "sparkles"),
    ]

    static func pattern(_ w: String) -> String {
        #"(?i)(?<![\p{L}\p{N}-])"# + NSRegularExpression.escapedPattern(for: w) + #"(?![\p{L}\p{N}-])"#
    }

    /// The unsafe words in a line (empty = speakable).
    public static func problems(_ text: String) -> [String] {
        swaps.map(\.word).filter { text.range(of: pattern($0), options: .regularExpression) != nil }
    }

    public static func isSpeakable(_ text: String) -> Bool { problems(text).isEmpty }

    /// The line made speakable: an unsafe word in a list is dropped ("paper scraps, crayons and scissors" → "paper
    /// scraps and crayons"; "crayons and scissors" → "crayons"); anywhere else it becomes its safe word. Idempotent.
    public static func repair(_ text: String) -> String {
        var t = text
        for (word, safe) in swaps where t.range(of: pattern(word), options: .regularExpression) != nil {
            let w = NSRegularExpression.escapedPattern(for: word)
            let item = #"(?:the\s+|some\s+)?"# + w
            // "A, B and W" → "A and B"
            t = t.replacingOccurrences(of: #"(?i)([\p{L}\p{N}' -]+?),\s+([\p{L}\p{N}' -]+?),?\s+and\s+"# + item + #"(?![\p{L}\p{N}-])"#,
                                       with: "$1 and $2", options: .regularExpression)
            // "A and W" → "A"; "W and A" → "A"; "W, A" → "A"; ", W," → ","
            t = t.replacingOccurrences(of: #"(?i),?\s+and\s+"# + item + #"(?![\p{L}\p{N}-])"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"(?i)(?<![\p{L}\p{N}-])"# + w + #"\s+and\s+"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"(?i),\s+"# + item + #"(?=,)"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: pattern(word), with: safe, options: .regularExpression)
        }
        return t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    /// A step made speakable (its shown text and its spoken text).
    public static func repair(_ step: Step) -> Step {
        var s = step
        s.text = repair(s.text)
        s.short = s.short.map(repair)
        return s
    }

    /// The scene's beats made speakable (opener, finale, every event line and calm-again line).
    public static func repair(_ b: SceneBeats) -> SceneBeats {
        var out = b
        out.opener = repair(b.opener)
        out.finale = repair(b.finale)
        out.events = b.events.map { e in
            var e = e
            e.line = repair(e.line)
            e.calmAgain = e.calmAgain.map(repair)
            return e
        }
        return out
    }
}
