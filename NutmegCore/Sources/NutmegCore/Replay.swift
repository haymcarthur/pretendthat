import Foundation

// Round D1: the replay flow (design §D5 with Haylee's answers): the same rail, Pick · Props · Print · Play (round 25: Paper → Print).
// Pick only asks how many are playing; Props shows the whole saved list ("Do you still have these?") and a missing one
// becomes a pretend swap; Print offers Print everything / Just the badges / Let's play! (round 25: no Draw it!); then
// Play with the saved scenes for the current count. NO AI calls for content anywhere in a replay.

/// The Print step's choices on a replay .
public enum PaperChoice: String, Sendable, CaseIterable {
    case everything, badges, skip
    public var label: String {
        switch self { case .everything: "Print everything"; case .badges: "Just the badges"; case .skip: "Let's play!" }
    }
    public var symbol: String {
        switch self { case .everything: "printer.fill"; case .badges: "person.crop.rectangle.fill"; case .skip: "checkmark" }
    }
}

public enum ReplayLines {
    /// The Pick step's question, after the title.
    public static let howMany = "How many friends are playing this time?"
    public static func greeting(title: String) -> String { "\(title)! \(howMany)" }
    /// The Props step: the saved list, read out ("Do you still have these? A pot for the captain's hat, …").
    public static func stillHave(_ props: [Prop]) -> String {
        let items = props.map { "a \($0.householdItem.lowercased()) for \(KitDraft.cutoutLabel(becomes: $0.becomes).isEmpty ? $0.becomes : "the " + KitDraft.cutoutLabel(becomes: $0.becomes))" }
        let list: String
        switch items.count {
        case 0: return "Do you still have your props? Tap All set when you're ready!"
        case 1: list = items[0]
        case 2: list = items[0] + " and " + items[1]
        default: list = items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
        return "Do you still have these? " + list.prefix(1).uppercased() + list.dropFirst() + ". Tap Don't have it for any that are missing!"
    }
    /// A missing prop (names what it becomes, so two in a row are two different lines).
    public static func pretend(_ becomes: String) -> String {
        let label = KitDraft.cutoutLabel(becomes: becomes)
        return label.isEmpty ? "No problem, we'll pretend!" : "No problem, we'll pretend the \(label.lowercased())!"
    }
    public static func useInstead(_ item: String) -> String { "A \(item.lowercased()) works too!" }
    public static let paperQuestion = "Do you want to print everything, just the badges, or go straight to Let's play?"
    public static let printed = "Here's the print screen! When your pages are ready, tap Let's play!"
    /// "Make it pirates instead": nothing is regenerated on a saved game.
    public static let savedGame = "This is a saved game! Tap New game for a new adventure."
    /// The tool output for a planning call on a replay (game, theme, roles, props, printer, color…).
    public static let savedGameOutput = "This is a saved game: nothing about the game can change and nothing is remade. Say exactly this and nothing else: \"\(savedGame)\""

    /// The one system note a replay's voice session gets (a system item, never a change to the session instructions,
    /// so the cached prefix stays the same).
    public static func note(title: String, roles: [Role], players: Int, props: [Prop], step: JourneyStep?, scenes: [String]) -> String {
        let playing = RoleCast.playing(roles, kids: max(1, players)).map(\.roleName)
        return "(Silent note, don't mention it.) This is a REPLAY of a saved game, \"\(title)\": no planning at all, the game, "
            + "roles, props and play guide are already made and never change. The app runs the steps Pick (how many are "
            + "playing, 1 to 6: set_player_count), Props (the saved list: they tap Got it or Don't have it), Print (print "
            + "everything, just the badges, or go straight to Let's play!), then Play. The app says every step's line itself. "
            + "Ranked roles: \(roles.map(\.roleName).joined(separator: ", "))"
            + (players > 0 ? "; playing now: \(playing.joined(separator: ", "))" : "; the count isn't chosen yet") + ". "
            + "Props: \(props.map { "\($0.householdItem.lowercased()) as \($0.becomes)" }.joined(separator: ", ")). "
            + "Scenes: \(scenes.joined(separator: "; ")). Current step: \(step?.label ?? "Pick"). "
            + "Never call set_game, set_theme, set_roles, show_next_prop or finish_planning. If they want a different game or "
            + "theme, say exactly: \"\(savedGame)\" Otherwise answer in ONE short line."
    }
}

extension ReplayLines {
    /// The tool-first pass's tools on a replay: Pick takes a count, Props only moves on the rail, then the usual
    /// after-hunt tools (the existing session tools only: the cached prefix stays the same).
    public static func tools(_ phase: Phase) -> [String]? {
        switch phase {
        case .hello, .pickGame, .players: return ["set_player_count", "go_to_step", "just_talk"]
        case .props: return ["go_to_step", "just_talk"]
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
                        s.text = s.text.replacingOccurrences(of: "pretend " + label, with: label, options: .caseInsensitive)
                        s.picture = .prop(lib)
                        scenes[i].steps[j] = s
                        uses.append(PropUse(propID: sp.id, scene: i, step: j, libraryID: lib, item: sp.householdItem, becomes: sp.becomes))
                    }
                }
            }
        }
        return GuideWeave.finalize(scenes, uses: uses, props: Props(nutmegSays: "", props: current), items: items)
    }

    /// The pages to print for a Paper choice (`pages` = every page for the current count).
    public static func pages(_ pages: [KitPage], for choice: PaperChoice) -> [KitPage] {
        switch choice {
        case .everything: return pages
        case .badges: return pages.filter { $0.item.recipe == .badges }
        case .skip: return []
        }
    }
}
