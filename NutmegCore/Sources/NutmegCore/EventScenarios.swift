import Foundation

// 2026-11-21 (Haylee, decisions/2026-11-21-events-are-scenarios-and-ownership.md): an event is a SCENARIO the called
// role(s) act out for a minute or two, often with a prop or a printout ("A space cloud is in the way! Navigator, use
// the map to help the captain find a new path."; "The ship is wobbly! Everyone, make everything secure!"), never a
// single gesture or face ("point your hand forward", "make a silly face", "wiggle your finger"). The prompt asks for
// that with good and bad examples; this light check catches a line whose only action is a one-off body gesture, and
// the repair swaps in an app-written scenario event for the same role(s).

public enum EventScenario {
    /// One-off body gestures (a small list; Claude's call). A line whose only actions are these is not a scenario.
    static let gestures: [String] = [
        #"point(?:s|ing)?(?:\s+(?:your|a|the)\s+(?:hand|finger|arm)s?)?"#, #"wave(?:s|ing)?"#, #"wiggle(?:s|ing)?"#,
        #"clap(?:s|ping)?"#, #"nod(?:s|ding)?"#, #"jump(?:s|ing)?\s+once"#, #"jump(?:s)?\s+up\s+and\s+down"#,
        #"make\s+(?:a|your)\s+(?:[\p{L}-]+\s+){0,2}face"#, #"smile"#, #"wink"#, #"blink"#, #"(?:give\s+(?:a|everyone\s+a)\s+)?thumbs[- ]up"#,
        #"(?:give\s+(?:a|everyone\s+a)\s+)?high[- ]fives?"#, #"stomp(?:\s+your\s+feet)?"#, #"shake\s+your\s+(?:head|hands?|hips)"#,
        #"raise\s+your\s+hands?"#, #"salute"#, #"take\s+a\s+bow"#, #"bow"#, #"spin\s+around"#, #"touch\s+your\s+(?:nose|toes|head)"#,
        #"pat\s+your\s+(?:head|tummy)"#, #"flap\s+your\s+(?:arms|wings)"#,
    ]

    /// Verbs of a real scenario (a job to act out for a while). A line with one of these isn't gesture-only.
    static let scenarioVerbs: Set<String> = [
        "help", "find", "fix", "check", "secure", "use", "bring", "look", "search", "get", "take", "carry", "build",
        "clean", "steer", "guide", "serve", "cook", "hold", "protect", "rescue", "explore", "catch", "collect", "gather",
        "pack", "load", "fly", "drive", "sail", "deliver", "feed", "care", "calm", "keep", "hide", "warn", "lead", "plan",
        "count", "sort", "repair", "prepare", "set", "open", "close", "organize", "watch", "make", "ask", "tell", "show",
        "read", "write", "measure", "stir", "bake", "mix", "pour", "wrap", "fold", "stack", "line", "patch",
        "tidy", "sweep", "wash", "dry", "spray", "pump", "pull", "push", "lift", "row", "paddle", "climb", "follow",
        "track", "chase", "escape", "dodge", "land", "launch", "unload", "sell", "buy", "pay", "greet", "welcome", "seat",
        "dance", "sing", "practice", "train", "teach", "treat", "heal", "bandage", "visit", "decorate", "paint", "plant",
        "water", "pick", "choose", "test", "try", "listen", "call", "radio", "signal", "report", "scan", "cheer", "comfort",
        "buckle", "lock", "unlock", "save", "store", "put", "move", "turn", "start", "stop", "slow", "speed", "zoom",
    ]

    /// Small words that don't count as verbs.
    static let skip: Set<String> = ["quick", "quickly", "oh", "no", "uh", "everyone", "all", "and", "then", "now", "so", "too"]

    /// True when the line's only action is a one-off body gesture ("Captain, wave to everyone!", "Pilot, point your hand
    /// forward and zoom the ship", "make a silly wobbly face"). Role titles are ignored.
    public static func isGestureOnly(_ line: String, roles: [Role] = []) -> Bool {
        var t = line.lowercased()
        for r in roles where !r.roleName.isEmpty {
            t = t.replacingOccurrences(of: "(?i)" + PlayCast.wordPattern(r.roleName), with: " ", options: .regularExpression)
        }
        var found = false
        for g in gestures {
            let p = #"(?<![\p{L}])"# + g + #"(?![\p{L}])"#
            if t.range(of: p, options: .regularExpression) != nil {
                found = true
                t = t.replacingOccurrences(of: p, with: " ", options: .regularExpression)
            }
        }
        guard found else { return false }
        // Gestures removed: is any scenario verb left? ("zoom" alone after a point is still just a gesture: Haylee's bad
        // example "Point your hand forward and zoom the ship".)
        let left = t.split { !$0.isLetter }.map(String.init).filter { !skip.contains($0) }
        let verbs = left.filter { scenarioVerbs.contains($0) && $0 != "zoom" && $0 != "make" }
        return verbs.isEmpty
    }

    // MARK: App-written scenario events (a pool event that was only a gesture, or a pool that couldn't be fair)

    public static let calmTemplates = [
        "a new visitor is on the way! Get everything ready and show them around!",
        "it's time for a big check! Look around and make sure everything is in its place!",
        "something new is waiting to be found! Search all around and bring it back to the crew!",
    ]
    public static let tenseTemplates = [
        "uh-oh, something is beeping! Go check what's wrong and help get it working again!",
        "oh no, everything is getting wobbly! Make everything secure and help everyone hold on!",
        "uh-oh, it's getting really busy! Quick, help everyone get what they need!",
    ]

    /// The app's scenario line for these role(s): the titles first, a situation, then a general direction.
    public static func appLine(mood: BeatMood, who: String, index: Int) -> String {
        let pool = mood == .tense ? tenseTemplates : calmTemplates
        return "\(who), " + pool[((index % pool.count) + pool.count) % pool.count]
    }

    // MARK: The opener (Haylee: it sets the scene with a real "Pretend that…", never a generic "get ready")

    /// Generic openers that set no scene.
    static let genericPattern = #"(?i)^(pretend that\s+)?(?:(?:ok(?:ay)?|alright|now|so)[,!]?\s+)?(?:get ready|let'?s (?:go|play|start|begin)|here we go|the game is starting|it'?s time to play|the (?:game|show|fun) begins|the curtain just went up|something exciting is about to happen|everyone is watching|it'?s the big moment|the room is the stage)\b"#

    /// True when the opener sets no scene (no "Pretend that…", or only a generic "get ready").
    public static func isGenericOpener(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || !PretendLine.has(t) { return true }
        return t.range(of: genericPattern, options: .regularExpression) != nil
    }

    /// A scene-setting opener from the story or the title: "Pretend that we're at the Sky Airlines gate! Everyone, take
    /// your places!".
    public static func opener(story: String?, title: String) -> String {
        let place = setting(story: story, title: title)
        return "Pretend that \(place)! \(startAction)"
    }

    // MARK: The opener's ending (2026-11-20, Haylee: it ends in their ongoing job, never "take your places" or a
    // one-time action like a countdown that's over in five seconds)

    /// The opener's last line, always the app's: the kids built their areas in the setup, so they go there and play
    /// their role until the first event.
    public static let startAction = "Everyone, go to the spot you set up and do what your role would do!"

    /// The opener as said: its scene-setting first sentence ("Pretend that…") plus `startAction`. Anything else the
    /// model wrote after it ("Everyone, take your places!", "Count down from ten!") is dropped. Idempotent.
    public static func actionOpener(_ line: String) -> String {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = PlayCast.sentences(t).first, first != startAction else { return t.isEmpty ? t : startAction }
        return first + " " + startAction
    }

    static func setting(story: String?, title: String) -> String {
        let first = PlayCast.sentences(story ?? "").first ?? ""
        if let r = first.range(of: #"(?i)welcome (?:aboard |to )([^.!?,]+)"#, options: .regularExpression) {
            var place = String(first[r]).replacingOccurrences(of: #"(?i)^welcome (?:aboard |to )"#, with: "", options: .regularExpression)
            place = place.trimmingCharacters(in: .whitespaces)
            if !place.isEmpty { return (first.lowercased().contains("aboard") ? "we're aboard " : "we're at ") + place }
        }
        let t = Bookends.trimEnd(title.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !t.isEmpty else { return "our adventure is about to begin" }
        let lower = t.lowercased()
        return lower.hasPrefix("the ") ? "we're at \(t)" : "we're at the \(t)"
    }
}
