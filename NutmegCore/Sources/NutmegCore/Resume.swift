import Foundation

/// Game survives lock/background (round 9, Haylee): when the Realtime socket dropped while the iPad was locked or the
/// app was in the background, the app reconnects silently with the CURRENT game injected into the session
/// instructions. She doesn't greet, doesn't repeat her question and gives no new suggestions: she waits for the kid.
/// Built from the in-memory state only (nothing is stored). Unit-tested (ResumeTests).
public struct ResumeContext: Equatable, Sendable {
    public struct PropLine: Equatable, Sendable {
        public var id: String; public var item: String; public var becomes: String
        public var status: Status
        public enum Status: String, Sendable { case found, pretend, looking, waiting }
        public init(id: String, item: String, becomes: String, status: Status) {
            self.id = id; self.item = item; self.becomes = becomes; self.status = status
        }
    }
    public enum Kit: Equatable, Sendable { case notYet, making, ready, playing(scene: Int, of: Int) }

    public var step: PlanningStep
    public var gameTitle: String?
    public var playerCount: Int
    public var roles: [String]
    public var props: [PropLine]
    public var kit: Kit
    /// The latest few chat lines (oldest first): (from Nutmeg, text).
    public var recent: [(fromNutmeg: Bool, text: String)]

    public static let maxLines = 6
    public static let maxLineLength = 220

    public init(step: PlanningStep, gameTitle: String?, playerCount: Int, roles: [String], props: [PropLine], kit: Kit,
                recent: [(fromNutmeg: Bool, text: String)]) {
        self.step = step; self.gameTitle = gameTitle; self.playerCount = playerCount; self.roles = roles
        self.props = props; self.kit = kit; self.recent = Array(recent.suffix(Self.maxLines))
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.step == b.step && a.gameTitle == b.gameTitle && a.playerCount == b.playerCount && a.roles == b.roles
            && a.props == b.props && a.kit == b.kit
            && a.recent.map(\.fromNutmeg) == b.recent.map(\.fromNutmeg) && a.recent.map(\.text) == b.recent.map(\.text)
    }

    /// The block appended to the session instructions on a silent reconnect.
    public var summary: String {
        var s = "RESUMING A GAME IN PROGRESS: the iPad was locked or the app was in the background, and the connection "
            + "was just restored. The kids never left. Do NOT greet them, do NOT say hi or welcome back, do NOT repeat your "
            + "last question and do NOT give new suggestions. Say NOTHING until a kid talks to you; then carry on from "
            + "exactly where you were, following the usual rules.\n"
        s += "Where we are: \(whereWeAre)\n"
        var so: [String] = []
        if let gameTitle { so.append("game: \(gameTitle)") }
        if playerCount > 0 { so.append("\(playerCount) kid\(playerCount == 1 ? "" : "s")") }
        if !roles.isEmpty { so.append("roles: \(roles.joined(separator: ", "))") }
        if !so.isEmpty { s += "Choices so far: \(so.joined(separator: "; ")).\n" }
        if !props.isEmpty {
            let list = props.map { p -> String in
                let st: String
                switch p.status {
                case .found: st = "found"
                case .pretend: st = "we'll pretend"
                case .looking: st = "CURRENT card, still looking"
                case .waiting: st = "not asked yet"
                }
                return "\(p.item) (id \(p.id), becomes \(p.becomes)): \(st)"
            }
            s += "Props: \(list.joined(separator: "; ")).\n"
        }
        s += "Kit: \(kitLine)\n"
        if !recent.isEmpty {
            s += "Latest lines of the conversation (oldest first):\n"
            for l in recent {
                let t = l.text.count > Self.maxLineLength ? String(l.text.prefix(Self.maxLineLength)) + "…" : l.text
                s += "\(l.fromNutmeg ? "Nutmeg" : "Kid"): \(t)\n"
            }
        }
        return s
    }

    var whereWeAre: String {
        switch kit {
        case .making: return "planning is done and the app is making the play kit (say nothing about it unless asked; then only \"Almost ready!\")."
        case .ready: return "the kit is ready on screen (print step). If they want to play, call start_play; to print, call print_kit."
        case .playing(let i, let n): return "they're playing (scene \(i + 1) of \(n)). Answer in ONE short, fun line that helps the current scene. No tools."
        case .notYet: break
        }
        switch step {
        case .game: return "step 1, you asked what they want to play and are waiting for their answer (call set_game when they pick)."
        case .theme: return "step 2, you asked for a theme or twist and are waiting (call set_theme when they pick)."
        case .players: return "step 3, you asked how many friends are playing and are waiting (call set_player_count)."
        case .printer: return "step 3c, you asked \"\(PrinterChoice.question)\" and are waiting: their answer → set_printer (has_printer true or false)."
        case .color: return "step 3c, you asked \"\(ColorChoice.question)\" and are waiting: their answer → set_print_style (full_color or color_myself), then the roles."
        case .confirm: return "step 3b, you recapped the plan (\"So it's ... Ready, or want to change something?\") and are waiting: yes → confirm_plan; a change → set_game, set_theme or set_player_count with the fix, then recap again."
        case .roles: return "step 4, you were planning the roles (call set_roles, then show_next_prop)."
        case .props:
            if let cur = props.first(where: { $0.status == .looking }) {
                return "step 5, the prop hunt: you asked them to find the \(cur.item.lowercased()) and are waiting to hear if they found it (mark_found, swap_prop or skip_prop, then show_next_prop)."
            }
            return "step 5, the prop hunt: call show_next_prop for the next prop when they talk to you (or finish_planning after 3 to 5 props)."
        case .finish: return "planning is done; the kit is being made."
        }
    }

    var kitLine: String {
        switch kit {
        case .notYet: "not started (it's made after the prop hunt)."
        case .making: "being made right now."
        case .ready: "ready to print."
        case .playing: "printed; they're playing."
        }
    }
}

extension Realtime {
    /// The session instructions for a silent reconnect: the usual instructions (with today's ideas) plus the resume block.
    public static func resumeInstructions(todayGames: [Suggestion], context: ResumeContext) -> String {
        instructions(todayGames: todayGames) + "\n\n" + context.summary
    }

    /// Round 20 (cost): a silent reconnect keeps the stable session instructions; today's ideas and where the game is
    /// go in as one system item instead.
    public static func resumeNote(todayGames: [Suggestion], context: ResumeContext) -> [String: Any] {
        systemNote((todayGames.isEmpty ? "" : todaysIdeas(todayGames) + "\n\n") + context.summary)
    }
}

extension ResumeContext {
    /// The current game from the in-memory store and chat (no names exist anywhere: roles-not-names.md).
    @MainActor public init(store: AdventureStore, transcript: [RealtimeTranscript.Line]) {
        let kit: Kit
        switch store.phase {
        case .makingKit: kit = .making
        case .kitReady: kit = store.kit == nil ? .making : .ready
        case .handoff(let i), .scene(let i): kit = .playing(scene: i, of: store.kit?.scenes.count ?? 1)
        case .end: kit = .playing(scene: max(0, (store.kit?.scenes.count ?? 1) - 1), of: store.kit?.scenes.count ?? 1)
        default: kit = .notYet
        }
        let props: [PropLine] = (store.props?.props ?? []).map { p in
            let status: PropLine.Status = store.foundProps.contains(p.id) ? .found : p.isSkipped ? .pretend
                : p.id == store.currentPropID ? .looking : .waiting
            return PropLine(id: p.id, item: p.householdItem, becomes: p.becomes, status: status)
        }
        self.init(step: store.planningStep, gameTitle: store.gameTitle, playerCount: store.playerCount,
                  roles: store.playingRoles.map(\.roleName),   // round C1: only the roles playing now
                  props: props, kit: kit, recent: transcript.map { ($0.fromNutmeg, $0.text) })
    }
}
