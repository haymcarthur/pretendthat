import Foundation

/// Round 19 (Haylee): after the player count and before the roles, Nutmeg recaps the plan out loud in ONE short sentence
/// ("So it's a bug movie theater for three friends! Ready, or want to change something?") and two big buttons show:
/// "Yes, let's go!" and "Change something". Voice works too ("yes", "actually it's a pirate ship"). A change is applied
/// (set_game / set_theme / set_player_count again) and she recaps again; only a yes moves on to the roles.
/// Pure text and rules, unit-tested (Round19ConfirmTests).
public enum ConfirmStep {
    public static let yesLabel = "Yes, let's go!"
    public static let changeLabel = "Change something"
    public static let question = "Ready, or want to change something?"

    /// The recap line, e.g. "So it's a bug movie theater for three friends! Ready, or want to change something?"
    public static func recap(title: String, playerCount: Int) -> String {
        let game = phrase(title)
        let who = playerCount <= 1 ? ", just for you" : " for \(number(playerCount)) friends"
        return "So it's \(game)\(who)! \(question)"
    }

    /// "a bug movie theater", "an ice cream truck", "the great bake off", "dinosaur explorers".
    static func phrase(_ title: String) -> String {
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        if t.isEmpty { t = "pretend game" }
        let words = t.split(separator: " ").map { w -> String in
            // Keep acronyms ("UFO"); everything else reads as plain words in the sentence.
            w.count > 1 && w.allSatisfy({ $0.isUppercase }) ? String(w) : w.lowercased()
        }
        let s = words.joined(separator: " ")
        let first = words.first ?? ""
        if ["a", "an", "the", "our", "my", "your"].contains(first) { return s }
        // The head noun is the last word before a preposition ("castle with friendly monsters" → castle).
        let preps: Set<String> = ["with", "on", "in", "under", "at", "of", "for", "from", "by", "near", "inside", "over", "to", "and"]
        let head = words.prefix { !preps.contains($0) }
        let last = head.last ?? words.last ?? ""
        // A plural name ("dinosaur explorers") takes no article; "circus", "bus", "glass" aren't plurals.
        if last.count > 3, last.hasSuffix("s"), !last.hasSuffix("ss"), !last.hasSuffix("us"), !last.hasSuffix("is") { return s }
        let vowel = first.first.map { "aeiou".contains($0) } ?? false
        return (vowel ? "an " : "a ") + s
    }

    static func number(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return n >= 0 && n < words.count ? words[n] : "\(n)"
    }

    /// The silent note that makes her spoken reply the recap, word for word.
    public static func sayRecapNote(_ recap: String) -> String {
        "(Silent coaching, don't mention it.) Now say exactly this and nothing else, then wait for the kids: \"\(recap)\""
    }

    /// What she does once the kids say yes (by voice: confirm_plan; or the Yes, let's go! button).
    public static func confirmedOutput(playerCount: Int) -> String {
        let shared = playerCount > RoleID.allCases.count ? " With more than 4 kids, repeat a role that makes sense to share." : ""
        return "Confirmed: \(playerCount) kid\(playerCount == 1 ? "" : "s"). Say ONE short line like \"Great, let me put some plans together!\" and call start_planning (topic roles) now (nothing longer, no other narration); after it, invent exactly \(playerCount) role\(playerCount == 1 ? "" : "s") for this game, call set_roles, then show_next_prop, and only then announce the roles and the first prop in ONE turn.\(shared) Never ask for names."
    }

    /// The Yes, let's go! tap (the app already confirmed): the same next step, spoken with tools allowed.
    public static func yesTapNote(playerCount: Int) -> String {
        "(Silent coaching, don't mention it.) The kids tapped Yes, let's go!: the plan is confirmed (don't call confirm_plan). "
            + confirmedOutput(playerCount: playerCount)
    }

    /// The Change something tap: she asks what to change, nothing else.
    public static let changeTapNote = "(Silent coaching, don't mention it.) The kids tapped Change something. No tools now: in "
        + "ONE short, cheerful question ask what they want to change: the game, the theme, or how many friends. When they "
        + "tell you, call set_game, set_theme or set_player_count with the fix."

    /// The output for a fix while she's waiting on the recap: she recaps again.
    public static func recapAgainOutput(what: String, recap: String) -> String {
        "\(what) Say exactly this and nothing else, then wait: \"\(recap)\" If they say yes, call confirm_plan; if they "
            + "change something again, call set_game, set_theme or set_player_count with the fix."
    }

    /// A fix after the roles/props were made for the old plan: they're cleared and redone after the new recap.
    public static func redoOutput(what: String, recap: String) -> String {
        "\(what) The roles and props were for the old plan, so they're cleared and you'll make new ones after the kids "
            + "say yes. Say ONE short sentence that you'll redo the roles and props to match, then say exactly: \"\(recap)\" "
            + "Then wait: yes → confirm_plan; another change → set_game, set_theme or set_player_count again."
    }
}
