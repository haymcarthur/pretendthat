import Foundation

/// Round 19 (a judge asked; Haylee): guardrails on what can be talked about or made. Defense in depth:
/// 1. the Realtime instructions (firm kid-safety rules, `Realtime.safetyRules`),
/// 2. this LOCAL filter on kid text (typed, or the transcript / tool arguments the app sees) before it sets the game,
///    theme or roles or goes to Claude or the image model,
/// 3. OpenAI's Moderation API (`omni-moderation-latest`, `ModerationClient`) on the same text, failing safe to (2),
/// 4. the same checks on Claude's generated JSON before it's shown or printed (regenerate once, then the bundled game),
/// 5. image prompts built only from checked text, with a safety suffix and `moderation: "auto"`.
/// Nothing is stored and no kid text is logged.
extension Sanitizer {
    public enum SafetyCategory: String, Sendable, CaseIterable {
        case selfHarm, violence, sexual, drugs, scary, hate, personalInfo, strangers, dangerous
        /// Not a topic to steer from: a kid may be hurt or in danger. She tells them to get a grown-up right away.
        case needsGrownUp
    }

    public struct SafetyVerdict: Equatable, Sendable {
        public let category: SafetyCategory
        public init(_ category: SafetyCategory) { self.category = category }
    }

    /// Lowercased, accents folded, look-alike digits/symbols mapped to letters ("k1ll", "$ex"), punctuation to spaces,
    /// long letter runs shortened ("kiiiill" → "kill"), and spaced-out letters joined ("k i l l" → "kill").
    public static func normalizeForSafety(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .init(identifier: "en"))
            .lowercased()
        let leet: [Character: Character] = ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i", "+": "t"]
        var mapped = ""
        let chars = Array(folded)
        for (i, c) in chars.enumerated() {
            // Digits inside a word are look-alikes ("k1ll"); a number on its own stays a number ("3 friends", a phone number).
            let inWord = (i > 0 && chars[i - 1].isLetter) || (i + 1 < chars.count && chars[i + 1].isLetter)
            if let l = leet[c], (c.isNumber ? inWord : (c == "!" ? inWord && i + 1 < chars.count && chars[i + 1].isLetter : true)) {
                mapped.append(l)
            } else if c.isLetter || c.isNumber || c == "'" {
                mapped.append(c == "’" ? "'" : c)
            } else {
                mapped.append(" ")
            }
        }
        // Shorten runs of 3+ of the same letter to 2 ("kiiiill" → "kiill", then matched as a stretched word below).
        var squeezed = ""
        var run = 0
        var last: Character?
        for c in mapped {
            if c == last { run += 1 } else { run = 1; last = c }
            if run <= 2 || !c.isLetter { squeezed.append(c) }
        }
        // Join single letters spelled out with spaces ("k i l l" → "kill").
        var words: [String] = []
        var letters = ""
        for w in squeezed.split(separator: " ").map(String.init) {
            if w.count == 1, w.first!.isLetter, w != "a", w != "i" || !letters.isEmpty { letters += w; continue }
            if !letters.isEmpty { words.append(letters); letters = "" }
            words.append(w)
        }
        if !letters.isEmpty { words.append(letters) }
        return words.joined(separator: " ").replacingOccurrences(of: "'", with: "")
    }

    // Whole words (or a word's start, for stems marked with a trailing "*"). Matched on the normalized text's words,
    // so "skill", "class", "therapist" or "shooting star" never match.
    static let blocklist: [SafetyCategory: [String]] = [
        .violence: ["kill*", "murder*", "gun", "guns", "pistol*", "rifle*", "shotgun*", "knife", "knives", "dagger*", "sword",
                    "swords", "bomb", "bombs", "bombing", "grenade*", "explosive*", "weapon*", "ammo", "bullet", "bullets",
                    "stab*", "shoot", "shoots", "shooting", "shooter", "strangle*", "choke", "choking", "punch them",
                    "beat up", "beat them up", "hurt someone", "hurt them", "hurt him", "hurt her", "fight to the death",
                    "war", "terrorist*", "kidnap*", "torture*", "massacre*", "behead*", "execute*", "die", "dying"],
        .selfHarm: ["suicide*", "kill myself", "self harm", "cut myself", "hurt myself", "want to die"],
        .sexual: ["sex", "sexy", "sexual*", "naked", "nude*", "porn*", "boobs", "penis*", "vagina*", "make out", "strip*"],
        .drugs: ["drug", "drugs", "weed", "cocaine", "heroin", "meth", "beer", "beers", "wine", "vodka", "whiskey", "alcohol*",
                 "drunk", "cigarette*", "vape*", "vaping", "smoke weed", "high on", "pills"],
        .scary: ["gore", "gory", "blood", "bloody", "corpse*", "dead body", "dead bodies", "horror", "demon*", "satan*",
                 "creepy clown", "slasher", "zombie*", "nightmare*", "haunted", "skeleton army"],
        .hate: ["nazi*", "kkk", "racist*", "hate them", "hate people", "slur*"],
        .personalInfo: ["my address", "i live at", "i live on", "my school is", "i go to school at", "my password",
                        "password is", "my phone number", "phone number is", "my email", "my last name", "my full name",
                        "credit card"],
        .strangers: ["stranger*", "meet a man", "meet someone online", "send a picture", "send pictures", "text someone",
                     "call someone", "meet up with", "secret friend"],
        .dangerous: ["stove", "oven", "matches", "lighter", "light a fire", "start a fire", "set a fire", "set fire",
                     "play with fire", "go outside alone", "go outside by myself", "leave the house", "climb the roof",
                     "on the roof", "climb the counter", "jump off", "bleach", "medicine", "plastic bag over", "the pool alone",
                     "cross the street", "unlock the door", "electrical outlet", "outlet", "power drill", "chainsaw", "scissors",
                     "glass"],
        .needsGrownUp: ["im hurt", "i am hurt", "im bleeding", "i am bleeding", "i got hurt", "i fell down", "someone hurt me",
                        "someone is hurting me", "hurting me", "i cant breathe", "help me please", "emergency", "call 911",
                        "theres a fire", "there is a fire", "i swallowed", "im lost", "i am lost"]
    ]

    /// Kid phrases that look like a blocked word but are fine ("shooting star", "photo shoot").
    static let allowPhrases = ["shooting star", "shooting stars", "photo shoot", "war of the", "cookie dough"]

    /// The local kid-safety check. nil = fine to use. `needsGrownUp` wins over everything (the kid may be in danger).
    public static func kidSafety(_ text: String) -> SafetyVerdict? {
        var n = " " + normalizeForSafety(text) + " "
        for p in allowPhrases { n = n.replacingOccurrences(of: " \(p) ", with: " ") }
        let squeezedWords = n.split(separator: " ").map { squeeze(String($0)) }
        let words = n.split(separator: " ").map(String.init)
        let joined = " " + words.joined(separator: " ") + " ", joinedSq = " " + squeezedWords.joined(separator: " ") + " "
        func hit(_ entry: String) -> Bool {
            if entry.hasSuffix("*") {
                let stem = String(entry.dropLast())
                return words.contains { $0.hasPrefix(stem) } || squeezedWords.contains { $0.hasPrefix(stem) }
            }
            return joined.contains(" \(entry) ") || joinedSq.contains(" \(entry) ")
        }
        if blocklist[.needsGrownUp]!.contains(where: hit) { return SafetyVerdict(.needsGrownUp) }
        for c in SafetyCategory.allCases where c != .needsGrownUp {
            if blocklist[c]!.contains(where: hit) { return SafetyVerdict(c) }
        }
        if hasPersonalPattern(text) { return SafetyVerdict(.personalInfo) }
        return nil
    }

    /// "kiill" → "kil"; used next to the plain word so stretched spellings still match ("kiiiill" → "kill" or "kil").
    static func squeeze(_ w: String) -> String {
        var out = ""; var last: Character?
        for c in w where c != last { out.append(c); last = c }
        return w.count > 2 && out != w ? (w.contains("ll") ? out.replacingOccurrences(of: "l", with: "ll") : out) : w
    }

    /// Phone numbers, emails and street addresses.
    static func hasPersonalPattern(_ text: String) -> Bool {
        let digits = text.filter(\.isNumber).count
        if digits >= 7 { return true }
        if text.range(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, options: .regularExpression) != nil { return true }
        return text.range(of: #"\b\d{1,5}\s+\w+\s+(street|st|avenue|ave|road|rd|lane|ln|drive|dr|court|ct|way|boulevard|blvd)\b"#,
                          options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// The first unsafe text among several (a tool call's fields, a kit's text).
    public static func kidSafety(_ texts: [String]) -> SafetyVerdict? {
        for t in texts { if let v = kidSafety(t) { return v } }
        return nil
    }
}

/// What Nutmeg says when kid text was blocked: cheerful, never repeats the unsafe words, with new ideas.
public enum SafetySteer {
    public static func line(for v: Sanitizer.SafetyVerdict, ideas: [Suggestion]) -> String {
        let how = ideas.isEmpty ? "a pirate ship, a bakery, or a zoo" : Suggestions.spoken(ideas)
        switch v.category {
        case .needsGrownUp, .selfHarm:
            return "Oh no! Please go get a grown-up right now. They can help!"
        case .personalInfo:
            return "Ooh, let's keep that a secret! We only need pretend roles. What should we play? Maybe \(how)?"
        case .dangerous:
            return "Ooh, let's keep our game super safe! How about \(how)?"
        default:
            return "Ooh, let's pick a different adventure! How about \(how)?"
        }
    }

    /// The silent note for the model when a tool call carried unsafe text (it must not use it or say it again).
    public static func toolNote(_ v: Sanitizer.SafetyVerdict, ideas: [Suggestion]) -> String {
        if v.category == .needsGrownUp || v.category == .selfHarm {
            return "That can't be used. The kid may be hurt or in danger: say ONLY, kindly: \"\(line(for: v, ideas: ideas))\" Nothing else."
        }
        return "That can't be used: it isn't okay for a kids' pretend game. Don't use it, don't repeat any of its words, and "
            + "don't call the tool with it again. Cheerfully steer in ONE short turn, like: \"\(line(for: v, ideas: ideas))\" "
            + "Offer ONLY these new ideas (\(Suggestions.spoken(ideas))), never ideas you already suggested."
    }
}

/// Image prompts end with this (on top of OpenAI's own `moderation: "auto"`).
public enum ImageSafety {
    public static let suffix = " Kid-friendly and gentle, for ages 4 to 8: no weapons, no blood, nothing scary, violent or grown-up, no real people, no brands, no text other than the words given."
}

/// Round 19: every generated text field a kid sees, hears or prints (checked before it's shown or printed).
public protocol SafetyText { var safetyTexts: [String] { get } }
extension GameIdeas: SafetyText { public var safetyTexts: [String] { [nutmegSays] + ideas.flatMap { [$0.title, $0.pitch] } } }
extension GamePlan: SafetyText {
    public var safetyTexts: [String] { [gameTitle, setting, nutmegSays] + roles.flatMap { [$0.roleName, $0.job] } }
}
extension Props: SafetyText { public var safetyTexts: [String] { [nutmegSays] + props.flatMap { [$0.householdItem, $0.becomes] } } }
extension Kit: SafetyText {
    public var safetyTexts: [String] {
        [nutmegSays] + items.flatMap { [$0.title] + $0.lines } + scenes.flatMap { [$0.title, $0.nutmegSays] + $0.steps.map(\.text) }
    }
}
extension NutmegTurn: SafetyText { public var safetyTexts: [String] { [nutmegSays] + choices.map(\.label) } }

/// Round 19 addition (Haylee: every redirect offered the SAME ideas): each steer-away gets 2–3 NEW game ideas from the
/// Suggestions pool, never one already offered or mentioned this session (today's games, theme ideas, earlier
/// redirects). In memory only, for this session; when the pool runs dry it starts over.
public struct SteerIdeas: Sendable {
    public private(set) var offered: Set<String> = []
    public init() {}

    /// Notes ideas the kid has already heard (today's game ideas, the theme ideas from set_game).
    public mutating func markOffered(_ ideas: [Suggestion]) { offered.formUnion(ideas.map(\.id)) }

    /// The next fresh set, marked as offered.
    public mutating func next<G: RandomNumberGenerator>(count: Int = 3, using rng: inout G) -> [Suggestion] {
        var fresh = Suggestions.games.filter { !offered.contains($0.id) }
        if fresh.count < count {   // everything was offered: start over (still avoiding the latest picks where possible)
            offered = offered.intersection(fresh.map(\.id)); fresh = Suggestions.games
        }
        let picks = Array(fresh.shuffled(using: &rng).prefix(count))
        markOffered(picks)
        return picks
    }

    public mutating func next(count: Int = 3) -> [Suggestion] {
        var rng = SystemRandomNumberGenerator()
        return next(count: count, using: &rng)
    }
}
