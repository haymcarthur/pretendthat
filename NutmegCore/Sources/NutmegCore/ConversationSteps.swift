import Foundation

/// The fixed steps of the planning conversation (decisions/conversation-structure.md). Wording varies; goals don't.
public enum PlanningStep: Int, Comparable, Sendable, CaseIterable {
    case game, theme, players, roles, props, finish
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// The step's goal, for nudges.
    public var goal: String {
        switch self {
        case .game: "Ask what they want to play today, with 2 or 3 example games."
        case .theme: "Ask what theme or twist their game should have, with 2 or 3 example themes that fit it."
        case .players: "Ask how many kids are playing, with an example (just you, or two, or three friends?)."
        case .roles: "Announce the roles for that many kids and end with a quick \"Sound good?\"."
        case .props: "Tell them exactly which props to go find, and to tell you when they've found them or don't have one."
        case .finish: "Say you're making their play kit."
        }
    }

    /// The tool that completes this step.
    public var tool: String {
        switch self {
        case .game: "set_game"
        case .theme: "set_theme"
        case .players: "set_player_count"
        case .roles: "set_roles"
        case .props: "finish_planning (when they're ready)"
        case .finish: "finish_planning"
        }
    }
}

/// App-side check of how one of Nutmeg's turns ended: every turn must end with ONE question plus 2–3 suggestions, or a
/// clear instruction. Returns a silent nudge for the model when the turn broke the rule, nil when it's fine.
public enum TurnCheck {
    static let instructionWords = ["go find", "go get", "go look", "find ", "grab ", "bring ", "look for", "tell me when",
                                   "tell me if", "tell me what", "say ", "let me know", "show me", "gather ", "get a", "go grab"]

    public static func nudge(for text: String, step: PlanningStep) -> String? {
        guard step != .finish else { return nil }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let lower = t.lowercased()
        let endsWithQuestion = t.hasSuffix("?")
        let lastSentence = Self.lastSentence(lower)
        let instruction = instructionWords.contains { lastSentence.contains($0) }
        let problem: String?
        switch step {
        case .roles:
            problem = endsWithQuestion || instruction ? nil : "end with a quick question like \"Sound good?\""
        case .props:
            // The props step is about the hunt: the turn must be about finding the props.
            let aboutProps = ["find", "look for", "grab", "gather", "do you have", "got ", "found", "pretend", "prop"]
                .contains { lower.contains($0) }
            problem = aboutProps && (endsWithQuestion || instruction) ? nil
                : "end with a clear instruction about the props (what to find, and to tell you when they're back)"
        default:
            if instruction && !endsWithQuestion { problem = nil }
            else if !endsWithQuestion { problem = "end with one clear question plus 2 or 3 suggestions" }
            else if !hasSuggestions(lastSentence) { problem = "add 2 or 3 concrete suggestions to your question" }
            else { problem = nil }
        }
        guard let problem else { return nil }
        return "(Silent coaching, don't mention it.) Your last turn didn't \(problem). If the kids already answered this "
            + "step, call \(step.tool) now and ask the NEXT step's question instead. Otherwise, in one short turn: \(step.goal)"
    }

    /// A gentle re-ask after the kids have been quiet.
    public static func silenceNudge(step: PlanningStep) -> String {
        "(Silent coaching, don't mention it.) The kids are quiet. Gently, in one short sentence, re-ask: \(step.goal)"
    }

    /// Suggestions: an "or" choice, or a comma list.
    static func hasSuggestions(_ s: String) -> Bool {
        s.contains(" or ") || s.filter { $0 == "," }.count >= 2
    }

    static func lastSentence(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: " ?!."))
        guard let r = trimmed.range(of: "[.!?]\\s", options: [.regularExpression, .backwards]) else { return s }
        return String(s[r.upperBound...])
    }

}

/// During the prop hunt Nutmeg answers only lines meant for her (prop-gathering-flow.md): kids are hunting and talking
/// to family. Addressed = her name, or a clear found / not-found / back phrase.
public enum HuntGate {
    static let phrases = ["found it", "found one", "found the", "we found", "i found", "got it", "got one", "got the",
                          "here it is", "here's the", "we're back", "i'm back", "we are back", "we don't have",
                          "we dont have", "i don't have", "i dont have", "don't have one", "can't find", "cant find",
                          "couldn't find", "no we don't", "we have it", "i have it", "we're ready", "i'm ready", "we're done"]
    public static func addressed(_ text: String) -> Bool {
        let t = text.lowercased().replacingOccurrences(of: "’", with: "'")
        return t.contains("nutmeg") || phrases.contains { p in
            // Whole words only ("where's the plate" must not match "here's the").
            t.range(of: "\\b" + NSRegularExpression.escapedPattern(for: p), options: .regularExpression) != nil
        }
    }
}
