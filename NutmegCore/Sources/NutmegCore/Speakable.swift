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

    public static func isSpeakable(_ text: String) -> Bool { problems(text).isEmpty && !sendsToHazard(text) && unpretendHazards(text).isEmpty }

    // MARK: Real hazards and appliances (2026-11-21, Haylee's safety rule)
    // "Put the pot on the stove spot" could send a kid to the REAL stove. Everything in the play world is pretend and
    // made from the props and printouts: an appliance or a hazard is always named as the pretend one ("the pretend
    // stove"), and a line that sends kids to a real hazard (climbing, stairs, outside, windows to open, outlets, the
    // water taps, the car) is replaced by a safe app-written line.

    /// Appliances and hazards that may appear only as the pretend version ("stove" → "pretend stove").
    public static let pretendOnly: [String] = [
        "stove", "stoves", "oven", "ovens", "cooktop", "microwave", "toaster", "fireplace", "campfire", "heater", "grill",
        "kitchen sink", "bathroom sink", "bathtub", "bath", "shower", "window", "windows", "plug", "plugs", "cord", "cords", "medicine",
        "medicines", "pills", "bleach", "cleaner", "cleaning spray", "fire", "fires",
    ]
    /// "fire" in these is fine (a fire truck, a firefighter: rescue games).
    static let fireOK = #"(?!\s+(?:truck|trucks|engine|engines|station|fighter|fighters|hose|helmet|chief|drill|alarm|dog|boat|house))"#

    static func wordPattern(_ w: String) -> String {
        #"(?i)(?<![\p{L}\p{N}-])"# + NSRegularExpression.escapedPattern(for: w) + #"(?![\p{L}\p{N}-])"# + (w.hasPrefix("fire") ? fireOK : "")
    }
    static let marks: Set<String> = ["pretend", "play", "toy", "paper", "cardboard", "printed", "make-believe"]

    /// The ranges of `w` in `t` with no pretend mark among the 3 words before it ("the pretend big oven" is fine).
    static func unmarked(_ w: String, in t: String) -> [Range<String.Index>] {
        guard let re = try? NSRegularExpression(pattern: wordPattern(w)) else { return [] }
        let ns = NSRange(t.startIndex..., in: t)
        return re.matches(in: t, range: ns).compactMap { Range($0.range, in: t) }.filter { r in
            // A capitalized word is a name (a role like "Oven Watcher" or "Fire Chief"), never rewritten.
            if t[r].first?.isUppercase == true { return false }
            let before = t[..<r.lowerBound].lowercased().split { !$0.isLetter && $0 != "-" }.suffix(3)
            return !before.contains { marks.contains(String($0)) }
        }
    }

    /// The appliance / hazard words used without "pretend" (empty = fine).
    public static func unpretendHazards(_ text: String) -> [String] {
        pretendOnly.filter { !unmarked($0, in: text).isEmpty }
    }

    /// Lines that send kids to a real hazard: climbing, stairs, going outside or to the street or a pool, opening a
    /// window, outlets and sockets, the water taps, the car, the real thing.
    public static let hazardPattern = #"(?i)\b(?:climb\w*|stairs?|staircase|upstairs|downstairs|outside|outdoors|street|balcony|swimming pool|the pool|faucets?|water taps?|turn on the water|run the water|outlets?|sockets?|counter ?tops?|(?:to|at|in|into) the sink|(?:open|lean out(?: of)?) the windows?|(?:get|go|run|walk|hop) (?:in|into|to) the car|the real)\b"#

    public static func sendsToHazard(_ text: String) -> Bool { text.range(of: hazardPattern, options: .regularExpression) != nil }

    /// The line safe for play: hazard words become their pretend version ("the stove spot" → "the pretend stove
    /// spot"); a line that sends kids to a real hazard becomes `fallback` (an app-written safe line). Idempotent.
    public static func safe(_ text: String, fallback: String) -> String {
        if sendsToHazard(text) { return fallback }
        var t = text
        for w in pretendOnly.sorted(by: { $0.count > $1.count }) {
            for r in unmarked(w, in: t).reversed() { t.replaceSubrange(r, with: "pretend " + t[r]) }
        }
        return t
    }

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

    /// The line made speakable AND safe for play (`safe`), with `fallback` for a line that sends kids to a hazard.
    public static func repair(_ text: String, fallback: String) -> String { safe(repair(text), fallback: fallback) }

    /// The app's safe line for a setup / clean-up item that pointed at a real hazard.
    public static let safeItem = "Get your spot ready"

    /// A step made speakable and safe (its shown text and its spoken text).
    public static func repair(_ step: Step) -> Step {
        var s = step
        s.text = repair(s.text, fallback: safeItem)
        s.short = s.short.map { repair($0, fallback: safeItem) }
        return s
    }

    /// A whole stored scene made speakable and safe: its title, its line (a scenario or an opener), its steps and beats.
    public static func repair(_ scene: Scene) -> Scene {
        var s = scene
        s.title = repair(s.title, fallback: s.title.isEmpty ? "" : "Let's Play")
        s.nutmegSays = repair(s.nutmegSays, fallback: PretendLine.openers[0])
        s.steps = s.steps.map(repair)
        s.beats = s.beats.map(repair)
        // A one-scene guide's line IS its opener: keep them the same text.
        if let o = s.beats?.opener, scene.nutmegSays == scene.beats?.opener { s.nutmegSays = o }
        return s
    }

    /// The scene's beats made speakable (opener, finale, every event line and calm-again line).
    public static func repair(_ b: SceneBeats) -> SceneBeats {
        var out = b
        out.opener = repair(b.opener, fallback: EventScenario.opener(story: nil, title: ""))
        out.finale = repair(b.finale, fallback: "We did it! Everyone, celebrate!")
        out.events = b.events.enumerated().map { k, e in
            var e = e
            // An event that sends kids to a real hazard is replaced by the caller's app event (it knows the roles);
            // here it gets a neutral app scenario so nothing unsafe is ever shown.
            e.line = repair(e.line, fallback: EventScenario.appLine(mood: e.mood, who: "Everyone", index: k))
            e.calmAgain = e.calmAgain.map { repair($0, fallback: OneScene.calmAgainLines[k % OneScene.calmAgainLines.count]) }
            return e
        }
        return out
    }
}
