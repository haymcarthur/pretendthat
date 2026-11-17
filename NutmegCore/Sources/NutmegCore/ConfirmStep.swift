import Foundation

/// Round 19 (Haylee): after the player count and before the roles, Nutmeg recaps the plan out loud in ONE short sentence
/// ("So it's a bug movie theater for three friends! Say yes, or tell me what to change!"). Round 26 (Haylee's button
/// audit): voice only, no Yes / Change buttons; the line tells the kids what to SAY ("yes", "actually it's a pirate
/// ship"). A change is applied (set_game / set_theme / set_player_count again) and she recaps again; only a yes moves on.
/// Pure text and rules, unit-tested (Round19ConfirmTests).
public enum ConfirmStep {
    /// Round 26: what to say (there are no buttons on this step).
    public static let question = "Say yes, or tell me what to change!"

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

    /// What she does once the kids say yes (confirm_plan; round 26: voice only).
    public static func confirmedOutput(playerCount: Int) -> String {
        // Round C1: always 6 ranked roles; the set_roles result says which ones to announce (the first N).
        "Confirmed: \(playerCount) kid\(playerCount == 1 ? "" : "s"). Say ONE short line like \"Great, let me put some plans together!\" and call start_planning (topic roles) now (nothing longer, no other narration); after it, invent exactly 6 ranked roles for this game (R1 the lead, R2 the second core role: the customer, visitor, guest, passenger or patient counterpart of R1 when the game has one, like Shopkeeper + Customer or Pilot + Passenger; R3 to R6 fun extras mixing workers and customers; six different titles), call set_roles, then show_next_prop, and only then announce ONLY the roles the set_roles result says are playing, ending with \"\(AdventureStore.huntTransition)\" in ONE turn (the first prop card and line follow). Never ask for names."
    }

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
