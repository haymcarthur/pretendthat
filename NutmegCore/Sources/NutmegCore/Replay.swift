import Foundation

// Round D1: the replay flow (design §D5 with Haylee's answers): the same rail, Pick · Props · Print · Play. NO AI calls
// for content anywhere in a replay. Round 26 (Haylee's button audit): a replay reuses the FIRST-PLAY flows. Pick asks
// how many are playing BY VOICE (number tiles only when there's no voice session); Props shows the saved props ONE
// card at a time with ✓ / ✗ (✗ uses the saved alternate first, then pretends, like the first play's hunt but with no
// AI); Print is the first play's printer + ▶ (every page for the current count); then Play.

public enum ReplayLines {
    /// The Pick step's question, after the title (round 26: it says to answer out loud).
    public static let howMany = "How many friends are playing this time? Tell me!"
    public static func greeting(title: String) -> String { "\(title)! \(howMany)" }

    /// "the captain's hat" (what a prop becomes, as a short spoken label).
    static func becomes(_ p: Prop) -> String {
        let label = KitDraft.cutoutLabel(becomes: p.becomes)
        return label.isEmpty ? p.becomes : "the " + label
    }

    /// One saved prop's card on a replay. Round 34 (Haylee): the SAME words as the first play's prop line
    /// (`PropLines`), never "do you still have…". `n` is the card's number in the hunt (1 = the first, with "First,"
    /// and the buttons explained once).
    public static func propAsk(_ p: Prop, n: Int) -> String {
        PropLines.ask(item: p.householdItem, becomes: p.becomes, reason: p.reason, n: n)
    }
    /// ✗ with a saved alternate: the card changes to it, same question.
    public static func useInstead(_ item: String) -> String {
        let s = some(item)
        return s.prefix(1).uppercased() + s.dropFirst() + (s.hasPrefix("some ") ? " work too! Do you have some?" : " works too! Do you have one?")
    }
    /// A missing prop (names what it becomes, so two in a row are two different lines).
    public static func pretend(_ becomes: String) -> String {
        let label = KitDraft.cutoutLabel(becomes: becomes)
        return label.isEmpty ? "No problem, we'll pretend!" : "No problem, we'll pretend the \(label.lowercased())!"
    }
    /// "Make it pirates instead": nothing is regenerated on a saved game.
    public static let savedGame = "This is a saved game! Start a new game from home for a new adventure."
    /// The tool output for a planning call on a replay (game, theme, roles, printer, color…).
    public static let savedGameOutput = "This is a saved game: nothing about the game can change and nothing is remade. Say exactly this and nothing else: \"\(savedGame)\""
    /// A replay's Pick, Props and hunt answers: the app says the next line itself.
    public static let appSaysOutput = "Done: the app moved on and says the next line itself. Say nothing."

    /// Round 26: the silent note after each replay move. Her app lines aren't in the conversation, so the session is
    /// told which card is up (seen live: without it she answered the last "found it" with just_talk and the hunt stuck).
    public static func stepNote(step: JourneyStep?, players: Int, playing: [String], card: Prop?, cardNumber: Int, cards: Int) -> String {
        var s = "(Silent note, don't mention it.) Replay: now on \(step?.label ?? "Pick")"
        if players > 0 { s += ", \(players) playing (\(playing.joined(separator: ", ")))" }
        s += "."
        if let card {
            s += " The prop card on screen now is card \(cardNumber) of \(cards): the \(card.householdItem.lowercased()) for "
                + "\(becomes(card)). When they say they have it (\"found it\", \"yes\", \"we have it\"), call mark_found; when they "
                + "don't (\"no\", \"we don't have one\"), call skip_prop. The app says the next line."
        } else if step == .print {
            s += " Every prop is answered: they're on Print. \"color\" / \"we'll color them\" → choose_print_set; \"print it\" → print_kit; \"let's play\" → start_play."
        }
        return s
    }

    /// "a bowl", "an apron", "some books" (the saved item's name in her line).
    static func some(_ item: String) -> String {
        let l = item.lowercased()
        if l.count > 2, l.hasSuffix("s"), !l.hasSuffix("ss") { return "some \(l)" }
        return ("aeiou".contains(l.first ?? "x") ? "an " : "a ") + l
    }

    /// The one system note a replay's voice session gets (a system item, never a change to the session instructions,
    /// so the cached prefix stays the same).
    public static func note(title: String, roles: [Role], players: Int, props: [Prop], step: JourneyStep?, scenes: [String]) -> String {
        let playing = RoleCast.playing(roles, kids: max(1, players)).map(\.roleName)
        return "(Silent note, don't mention it.) This is a REPLAY of a saved game, \"\(title)\": no planning at all, the game, "
            + "roles, props and play guide are already made and never change. The app runs the steps and says every step's "
            + "line itself: Pick (how many are playing, 1 to 6: when they say a number, call set_player_count), Props (the "
            + "saved props one card at a time: \"found it\" / \"we have it\" → mark_found; \"we don't have it\" → skip_prop), "
            + "Print (both page sets, color and outline: \"color\" / \"we'll color them\" → choose_print_set; a printer button "
            + "and a green play button: \"print it\" → print_kit, \"let's play\" → start_play), then "
            + "Play. Ranked roles: \(roles.map(\.roleName).joined(separator: ", "))"
            + (players > 0 ? "; playing now: \(playing.joined(separator: ", "))" : "; the count isn't chosen yet") + ". "
            + "Props: \(props.map { "\($0.householdItem.lowercased()) as \($0.becomes)" }.joined(separator: ", ")). "
            + "Scenes: \(scenes.joined(separator: "; ")). Current step: \(step?.label ?? "Pick"). "
            + "Never call set_game, set_theme, set_roles, show_next_prop or finish_planning. If they want a different game or "
            + "theme, say exactly: \"\(savedGame)\" Otherwise answer in ONE short line."
    }
}

extension ReplayLines {
    /// The tool-first pass's tools on a replay: Pick takes a count, Props the hunt answers, then the usual after-hunt
    /// tools (the existing session tools only).
    public static func tools(_ phase: Phase) -> [String]? {
        switch phase {
        case .hello, .pickGame, .players: return ["set_player_count", "go_to_step", "just_talk"]
        case .props: return ["mark_found", "skip_prop", "swap_prop", "go_to_step", "just_talk"]
        default: return Realtime.afterHuntTools(phase)
        }
    }
}

public enum ReplayProps {
    /// The saved play guide with the replay's prop answers applied, with NO call: a prop the kids don't have now makes
    /// its steps "the pretend …" (its printed cut-out picture when the kit has one), an alternate they use instead is
    /// named and shown, and a prop that was pretend on the first play but is here now loses the "pretend".
    /// `base` = the saved scenes (as finalized on the first play), `saved` = the saved props, `current` = the replay's.
    public static func apply(_ base: [Scene], saved: [SavedProp], current: [Prop], items: [KitItem]) -> [Scene] {
        var scenes = base
        var uses: [PropUse] = []
        for sp in saved {
            guard let lib = sp.libraryID else { continue }
            let label = KitDraft.cutoutLabel(becomes: sp.becomes)
            for (i, sc) in scenes.enumerated() {
                for (j, st) in sc.steps.enumerated() {
                    if st.picture == .prop(lib) {
                        uses.append(PropUse(propID: sp.id, scene: i, step: j, libraryID: lib, item: sp.householdItem, becomes: sp.becomes))
                    } else if sp.pretendOnFirstPlay, !label.isEmpty, st.text.range(of: "pretend " + label, options: .caseInsensitive) != nil {
                        // The first play's pretend: back to the real prop (it's here this time, unless the kids say not).
                        var s = st
                        s.mapTexts { $0.replacingOccurrences(of: "pretend " + label, with: label, options: .caseInsensitive) }
                        s.picture = .prop(lib)
                        scenes[i].steps[j] = s
                        uses.append(PropUse(propID: sp.id, scene: i, step: j, libraryID: lib, item: sp.householdItem, becomes: sp.becomes))
                    }
                }
            }
        }
        return GuideWeave.finalize(scenes, uses: uses, props: Props(nutmegSays: "", props: current), items: items)
    }
}
