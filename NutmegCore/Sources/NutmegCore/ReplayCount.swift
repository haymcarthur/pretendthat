import Foundation

/// Replay Pick without number tiles (Haylee, 2026-11-17: "Even if they don't have internet they can just type in their
/// answer right? So we shouldn't have that screen."). With no voice session, the kid answers how many are playing by
/// typing or by speaking (on-device speech works offline), and the count is read HERE, on the device: no AI call, and
/// the words never leave the iPad (only the number is used).
public enum ReplayCount {
    /// What the app does with a kid's answer on a replay's Pick.
    public enum Answer: Equatable, Sendable {
        /// 1–6: `replayPick(n)`.
        case pick(Int)
        /// A number, but 0 or more than 6: the gentle re-ask with the range.
        case outOfRange(Int)
        /// No number in it: the gentle re-ask.
        case noNumber
    }

    /// Her re-ask: the recorded Pick question (a bundled clip, so it plays offline).
    public static let reask = ReplayLines.howMany
    /// The text-only hint in the chat before the re-ask when the number is out of range (no recorded line says it, so
    /// it is never spoken: an unrecorded line on an offline replay would wait for Wi-Fi).
    public static let rangeHint = "I can play with 1 to 6 friends!"

    /// Whether the app reads the answer itself: a replay's Pick with no live voice session. (With a live session the
    /// voice model hears the count and calls set_player_count; nothing changes there.)
    public static func handlesOnDevice(isReplay: Bool, phase: Phase, voiceLive: Bool) -> Bool {
        isReplay && phase == .players && !voiceLive
    }

    public static func decide(_ text: String) -> Answer {
        guard let n = parse(text) else { return .noNumber }
        return (1...Players.max).contains(n) ? .pick(n) : .outOfRange(n)
    }

    /// The count in a kid's answer: "3", "three", "we have four", "4 kids", "just me" (1), "me and my sister" (2),
    /// "me and 2 friends" (3). nil when there's no count in it.
    public static func parse(_ text: String) -> Int? {
        let words = tokens(text)
        guard !words.isEmpty else { return nil }
        let numbers = words.enumerated().compactMap { i, w in value(w).map { (i, $0) } }
        if let (i, n) = numbers.first {
            // "me and 2 friends" / "me and my 3 sisters": the kid plus the others.
            let before = words[..<i]
            if before.contains("me") && before.contains("and") && n < 20 { return n + 1 }
            return n
        }
        // "me and my sister", "my brother and me", "me and mom and dad": the kid plus each person joined by an "and".
        if words.contains("me") && words.contains("and") { return 1 + words.filter { $0 == "and" }.count }
        if words.contains("me") || words.contains("myself") || words.contains("alone") { return 1 }   // "just me"
        return nil
    }

    private static func tokens(_ text: String) -> [String] {
        let lowered = text.lowercased().replacingOccurrences(of: "&", with: " and ")
        var out: [String] = []
        var cur = ""
        for ch in lowered {
            // Digits and letters split apart ("4kids" → "4", "kids"); hyphens join ("twenty-one").
            let isDigit = ch.isNumber, isLetter = ch.isLetter || ch == "-" || ch == "'"
            if isDigit || isLetter {
                if let last = cur.last, last.isNumber != isDigit { out.append(cur); cur = "" }
                cur.append(ch)
            } else if !cur.isEmpty { out.append(cur); cur = "" }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    private static let extras: [String: Int] = ["none": 0, "nobody": 0, "no-one": 0, "couple": 2, "pair": 2, "dozen": 12]

    private static func value(_ w: String) -> Int? {
        if let n = Int(w) { return n }
        if let i = NumberWords.ones.firstIndex(of: w) { return i }
        if w.contains("-"), let n = (1...99).first(where: { NumberWords.spell($0) == w }) { return n }
        if let i = NumberWords.tens.firstIndex(of: w), i >= 2 { return i * 10 }
        return extras[w]   // never "to" / "too" / "for" (they're not counts)
    }
}
