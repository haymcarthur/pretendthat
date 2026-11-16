import Foundation

/// The fixed steps of the planning conversation (decisions/conversation-structure.md). Wording varies; goals don't.
public enum PlanningStep: Int, Comparable, Sendable, CaseIterable {
    /// Round 19: `confirm` sits between the player count and the roles: she recaps and waits for a yes or a change.
    /// Round 20: `color` (full color, or color them yourself?) follows the yes, before the roles.
    /// Round 24: `printer` ("Do you have a printer?") sits between the yes and the color question.
    case game, theme, players, confirm, printer, color, roles, props, finish
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// The step's goal, for nudges.
    public var goal: String {
        switch self {
        case .game: "Ask what they want to play today, suggesting today's game ideas (from your instructions)."
        case .theme: "Ask what theme or twist their game should have, suggesting today's theme ideas (from the set_game result)."
        case .players: "Ask an open question: \"How many friends are playing today?\" (never a list of numbers)."
        case .confirm: "Recap the game, theme and number of friends in ONE short sentence and ask \"\(ConfirmStep.question)\""
        case .printer: "Ask exactly: \"\(PrinterChoice.question)\""
        case .color: "Ask exactly: \"\(ColorChoice.question)\""
        case .roles: "Call set_roles, then show_next_prop, then announce the roles and say \"\(AdventureStore.huntTransition)\" (the first prop follows). Never ask \"Sound good?\"."
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
        case .confirm: "confirm_plan (or set_game / set_theme / set_player_count for a change)"
        case .printer: "set_printer"
        case .color: "set_print_style"
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
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        // Push-to-talk reminder ("Hold the red button and tell me!") closing the turn: judge the sentence before it.
        if lastSentence(t.lowercased()).contains("red button") {
            let lower = t.lowercased(), last = lastSentence(lower)
            if let r = lower.range(of: last, options: .backwards) {
                let rest = String(t[..<t.index(t.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: r.lowerBound))])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if rest.isEmpty { return nil }   // the reminder alone is a clear instruction
                t = rest
            }
        }
        let lower = t.lowercased()
        let endsWithQuestion = t.hasSuffix("?")
        let lastSentence = Self.lastSentence(lower)
        let instruction = !isNarration(lastSentence) && instructionWords.contains { lastSentence.contains($0) }
        let problem: String?
        if hasSoundEffect(t) {
            return "(Silent coaching, don't mention it.) Never say sound effects or stage directions as words (giggle, "
                + "squeak, eee, eep, heehee). Just talk. Step goal: \(step.goal)"
        }
        if assignsAllRolesToOne(lower) {
            return "(Silent coaching, don't mention it.) Say the roles as parts the kids share (\"Our crew is a Captain, a "
                + "Navigator, and an Explorer! \(AdventureStore.huntTransition)\"), never \"You're the X, the Y, and the Z\"."
        }
        if mentionsGoPlay(lower) {
            return "(Silent coaching, don't mention it.) Never tell the kids to go play or start their adventure: that "
                + "only happens later, after they print and tap Let's play. Step goal: \(step.goal)"
        }
        // Round 19: the recap's "Ready, or want to change something?" is the confirm step's own question.
        if step == .confirm {
            return endsWithQuestion ? nil : "(Silent coaching, don't mention it.) End with the recap question: \(step.goal)"
        }
        // Round 20: the color question is this step's own question.
        if step == .color {
            return endsWithQuestion ? nil : "(Silent coaching, don't mention it.) End with the color question: \(step.goal)"
        }
        // Round 24: so is the printer question.
        if step == .printer {
            return endsWithQuestion ? nil : "(Silent coaching, don't mention it.) End with the printer question: \(step.goal)"
        }
        if endsWithQuestion && isPermissionCheck(lastSentence) {
            // Round 7 (Haylee): never "Sound good?" / "Okay?" / "Ready?". Her only questions are the steps' questions.
            return "(Silent coaching, don't mention it.) You ended with a permission check. Never ask \"Sound good?\", "
                + "\"Okay?\", \"Ready?\" or anything like it: there is nothing to approve. " + (step == .props || step == .roles
                    ? "Keep going: the first prop comes right after the roles, no check-in." : "Step goal: \(step.goal)")
        }
        switch step {
        case .roles:
            problem = endsWithQuestion || instruction ? nil : "go straight into the first prop"
        case .players:
            // Open question only (round 7): a closed list ("just you, or two, or three?") sounds like the maximum.
            if !endsWithQuestion && !instruction { problem = "end with the open question \"How many friends are playing today?\"" }
            else if offersCountList(lastSentence) { problem = "ask the open question \"How many friends are playing today?\" (you offered a list of numbers, which sounds like the most they can have)" }
            else { problem = nil }
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

    /// What the app does after one of her spoken turns (round 7): nil = fine; otherwise a silent note, and whether she
    /// continues the SAME turn right away (`complete`). Roles set but no prop card yet: she must go straight into the
    /// first prop without waiting for a kid reply (no "Sound good?" pause).
    public static func review(_ text: String, step: PlanningStep, rolesSet: Bool, propsShown: Int,
                              currentPropDone: Bool = false) -> (note: String, complete: Bool)? {
        if step == .props && rolesSet && propsShown == 0 { return (firstPropNote, true) }
        // The current prop is found (or skipped) and no next card is out: the next prop comes right away.
        if step == .props && currentPropDone && propsShown < 5 { return (nextPropNote(propsShown: propsShown), true) }
        if needsCompletion(for: text, step: step) { return (completionNote(step: step), true) }
        return nudge(for: text, step: step).map { ($0, false) }
    }

    /// Roles are announced, the first prop isn't out yet: continue the same turn with it (never wait for an answer).
    public static let firstPropNote = "(Silent coaching, don't mention it.) Don't wait for the kids and don't ask anything "
        + "about the roles. Call show_next_prop for the FIRST prop right now, then say ONLY what to find and what it becomes, "
        + "plus: say 'found it' when you have it, or tell me if you don't. Don't repeat the roles. No \"Sound good?\"."

    static func nextPropNote(propsShown: Int) -> String {
        "(Silent coaching, don't mention it.) Don't stop: call show_next_prop for the next prop right now"
            + (propsShown >= 3 ? " (or finish_planning if the props are enough)" : "")
            + ", then say ONLY what to find and what it becomes. Don't repeat your cheer. Never narrate (no \"let me...\")."
    }

    /// "Go play"-type lines belong ONLY to the play step (after "Let's play!"), never in planning or at kit-ready (Haylee).
    static let goPlayPhrases = ["go play", "go have", "have your", "dive into", "hop into", "jump into the story", "start playing",
                                "go have fun", "time to play", "let's play", "go on your", "off you go", "have fun playing"]
    public static func mentionsGoPlay(_ text: String) -> Bool {
        let s = text.lowercased()
        return goPlayPhrases.contains { s.contains($0) }
    }

    /// Sound effects or stage directions said as words (Haylee): "giggle", "squeak", "eee", "eep", "heehee"...
    public static func hasSoundEffect(_ text: String) -> Bool {
        let lower = text.lowercased()
        if ["*laugh", "(laugh", "*gig", "(gig", "hee hee", "tee hee", "nibble nibble"].contains(where: lower.contains) { return true }
        let words = lower.split { !$0.isLetter }.map(String.init)
        return words.contains { w in
            w.hasPrefix("giggl") || w.hasPrefix("squeak") || w.hasPrefix("squee") || ["eep", "heehee", "teehee", "hehe"].contains(w)
                || (w.count >= 3 && w.allSatisfy { $0 == "e" })   // "eee", "eeee"
        }
    }

    /// "You're the Train Driver, the Conductor, and the Passenger" (one kid seems to get every role; Haylee).
    public static func assignsAllRolesToOne(_ text: String) -> Bool {
        let s = text.lowercased().replacingOccurrences(of: "’", with: "'")
        for opener in ["you're the ", "you are the ", "you'll be the ", "you will be the "] {
            guard let r = s.range(of: opener) else { continue }
            let rest = s[r.upperBound...].prefix(90)
            let clause = rest.prefix { !".!?".contains($0) }
            if clause.contains(", the ") || clause.contains(" and the ") || clause.contains(" and a ") { return true }
        }
        return false
    }

    /// Narrating her process or a tool call instead of talking to the kids ("let me set that up", "next prop coming up").
    static let narrationPhrases = ["let me ", "let's get ", "coming up", "i'll get", "i'll grab", "i'm going to ", "hang on",
                                   "one moment", "one sec", "set that up", "line up the", "getting it ready", "get it ready",
                                   "let me think", "give me a", "line up", "one last moment", "wrap up", "set this up",
                                   "set up for", "jump right into", "we'll set", "i'll set", "getting your", "while i ",
                                   "coming up next", "get ready to hunt", "start the hunt", "prop card", "i'll get the",
                                   "think about the next", "think of the next", "all set"]
    /// The one allowed line before the writing moment ("Great, let me put some plans together!").
    static let planningLine = ["plans together", "make a plan", "put a plan together"]
    public static func isNarration(_ sentence: String) -> Bool {
        let s = sentence.lowercased()
        if planningLine.contains(where: s.contains) { return false }
        return narrationPhrases.contains { s.contains($0) }
    }

    /// The ONE gentle reminder after ~20 s of quiet (round 6, push-to-talk): never the full question again.
    /// Round 7: spoken only (an out-of-band line in her voice), never added to the chat transcript or the conversation.
    public static func silenceNudge(step: PlanningStep) -> String { silenceLine }
    public static let silenceLine = "Hold the red button whenever you're ready!"

    /// Her turn ended with NO question and NO instruction at all ("Ooh, a pet rescue, so sweet!"): the kid has nothing to
    /// answer. Only then does the app let her finish the same turn (one short continuation, never a repeat).
    public static func needsCompletion(for text: String, step: PlanningStep) -> Bool {
        guard step != .finish else { return false }
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if lastSentence(t.lowercased()).contains("red button") { return false }   // the reminder is an instruction
        t = t.lowercased()
        let last = lastSentence(t)
        if t.hasSuffix("?") { return false }
        // Round 7: narration ("let me grab the next prop.") is never an ending, even with an instruction word in it.
        if isNarration(last) { return true }
        if t.contains("?") { return false }
        return !instructionWords.contains { last.contains($0) }
    }

    /// The continuation note: add ONLY the missing question, nothing repeated.
    public static func completionNote(step: PlanningStep) -> String {
        "(Silent coaching, don't mention it.) You stopped without asking anything. Continue the SAME turn with ONLY the "
            + "next question plus 2 or 3 suggestions, in one short sentence. Don't repeat or rephrase anything you already "
            + "said, no new reaction, never narrate (no \"let me...\"). If the kids already answered this step, call "
            + "\(step.tool) first. Step goal: \(step.goal)"
    }

    /// Ending phrases that ask permission instead of a real step question (round 7: never asked, anywhere).
    static let permissionChecks = ["sound good", "sounds good", "okay", "ok?", "ready", "does that sound", "how does that sound",
                                   "is that good", "is that okay", "is that ok", "all right", "alright", "want to start",
                                   "shall we", "deal", "cool?", "got it", "you like that", "like that", "fun?"]

    /// True when the turn's last sentence is a yes/no check-in ("Sound good?", "Ready?", "Okay?").
    public static func isPermissionCheck(_ sentence: String) -> Bool {
        let s = sentence.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = s.trimmingCharacters(in: CharacterSet(charactersIn: " ?!.")).split(separator: " ").count
        // A short question (≤ 6 words) built around a check-in phrase. Real step questions are longer or carry ideas.
        return words <= 6 && permissionChecks.contains { s.contains($0) }
    }

    /// A closed list of player counts ("just you, or two, or three friends?").
    static func offersCountList(_ s: String) -> Bool {
        let l = s.lowercased()
        let numbers = ["just you", "one", "two", "three", "four", "five", "1", "2", "3", "4"]
        return l.contains(" or ") && numbers.filter { l.contains($0) }.count >= 2
    }

    /// Suggestions: an "or" choice, or a comma list.
    static func hasSuggestions(_ s: String) -> Bool {
        s.contains(" or ") || s.filter { $0 == "," }.count >= 2
    }

    static func lastSentence(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: " ?!."))
        // The LAST sentence break (a backwards regex search returned an earlier one with 3+ sentences, round 6).
        let chars = Array(trimmed)
        var i = chars.count - 2
        while i >= 0 {
            if ".!?".contains(chars[i]) && chars[i + 1].isWhitespace { return String(chars[(i + 2)...]) }
            i -= 1
        }
        return s
    }

}
