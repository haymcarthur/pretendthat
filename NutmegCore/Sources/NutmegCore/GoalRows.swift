import Foundation

// Round 40 (Haylee, decisions/2026-11-17-setup-rows-as-goals.md): the setup and clean-up rows are GOALS in the game's
// world ("Get the pet room ready", "Close up the clinic"), about one per role (a solo kid or 2 players: a few goal rows,
// not many small ones). The row SHOWS the goal; Nutmeg SAYS the specifics: "Head Vet, get the pet room ready by hanging
// up the sign and setting up the pet bed!" Every household prop and every printed page is named in some row's spoken
// specifics (the badges by the scene's opening line). Replaces round 37's "at most 2 items a row" labels; a game saved
// before round 40 (no goals) is still composed the round-37 way, so its replay looks and sounds as it did.
//
// How it is built (Claude's calls):
// - The guide writes one goal per ranked role (R1…R6) for each of the two scenes; item jobs say which role they suit.
// - Items are grouped by the role they suit. A playing role's row is its own goal + its group. A group whose role isn't
//   playing becomes an extra row (its goal) for a playing role that still has room (solo 3 rows, 2 players 2 each,
//   3+ players 1 each) when it has at least 2 items, else it joins the row with the fewest items.
// - A playing role with nothing to do takes one item from the busiest row (never a row's last item).

extension Bookends {
    /// The most goal rows one role gets: a solo kid 3, 2 players 2 each, 3 or more players 1 each.
    public static func goalRowsPerRole(players n: Int) -> Int {
        switch PlayCast.players(n) { case 1: 3; case 2: 2; default: 1 }
    }
    public static let minGoalWords = 2
    public static let maxGoalWords = 6

    /// A usable goal: 2 to 6 words, no quotes.
    public static func isValidGoal(_ g: String?) -> Bool {
        guard let g = g.map(trimEnd), !g.isEmpty, !g.contains("\"") else { return false }
        let w = g.split(whereSeparator: \.isWhitespace).count
        return w >= minGoalWords && w <= maxGoalWords
    }

    /// The app's goal when the AI's is missing or unusable.
    static func fallbackGoal(_ r: RoleID, cleanup: Bool, title: String) -> String {
        if r == .R1 {
            if !cleanup, isValidGoal(title), PlayCast.lowerFirst(title).hasPrefix("get ") { return trimEnd(title) }
            return cleanup ? "Put everything away" : "Get everything ready"
        }
        return cleanup ? "Tidy up your spot" : "Get your spot ready"
    }

    /// One goal row before it is written out: whose row, whose goal, which items.
    public struct GoalRow: Equatable, Sendable {
        public var role: RoleID
        public var goalOf: RoleID
        public var items: [String]
    }

    /// Which rows the N players get and what each row covers. Pure and deterministic. Every item is in exactly one row.
    public static func goalAssignment(items: [CoverItem], jobs: [String: ItemJob], roles: [Role], players n: Int) -> [GoalRow] {
        let playing = RoleCast.playing(roles, kids: n)
        guard !playing.isEmpty else { return [] }
        let playingIDs = Set(playing.map(\.id))
        let cap = goalRowsPerRole(players: n)
        var groups: [RoleID: [String]] = [:], loose: [String] = []
        for it in items {
            if let r = jobs[it.id]?.role ?? it.prop?.forRole.role { groups[r, default: []].append(it.id) } else { loose.append(it.id) }
        }
        var rows: [GoalRow] = playing.map { GoalRow(role: $0.id, goalOf: $0.id, items: groups[$0.id] ?? []) }
        func rowsOf(_ r: RoleID) -> Int { rows.filter { $0.role == r }.count }
        func load(_ r: RoleID) -> Int { rows.filter { $0.role == r }.reduce(0) { $0 + $1.items.count } }
        // The row a leftover item joins: the least busy role first, then its least busy row.
        func leastRow() -> Int {
            rows.indices.min { i, j in
                let (li, lj) = (load(rows[i].role), load(rows[j].role))
                if li != lj { return li < lj }
                if rows[i].items.count != rows[j].items.count { return rows[i].items.count < rows[j].items.count }
                return i < j
            }!
        }
        for r in RoleID.allCases where !playingIDs.contains(r) {
            guard let g = groups[r], !g.isEmpty else { continue }
            let room = playing.filter { rowsOf($0.id) < cap }
            if g.count >= 2, let who = room.min(by: { load($0.id) < load($1.id) || (load($0.id) == load($1.id) && $0.id.rank < $1.id.rank) }) {
                // The extra row goes right after that role's other rows.
                let at = (rows.lastIndex { $0.role == who.id } ?? rows.count - 1) + 1
                rows.insert(GoalRow(role: who.id, goalOf: r, items: g), at: at)
            } else {
                let i = leastRow(); rows[i].items += g
            }
        }
        for id in loose { let i = leastRow(); rows[i].items.append(id) }
        // A playing role with nothing to do takes one item from the busiest row that has more than one.
        for i in rows.indices where rows[i].items.isEmpty {
            guard let from = rows.indices.filter({ rows[$0].items.count > 1 }).max(by: { rows[$0].items.count < rows[$1].items.count }) else { break }
            rows[i].items.append(rows[from].items.removeLast())
        }
        // Items keep the kit's order inside a row (pages first, then props).
        let order = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
        for i in rows.indices { rows[i].items.sort { (order[$0] ?? 0) < (order[$1] ?? 0) } }
        return rows
    }

    /// The badges in the clean-up: the opening line has everyone take theirs off (like the setup's "put on").
    public static func badgeOffLine(players n: Int) -> String {
        PlayCast.players(n) == 1 ? "Take off your badge first!" : "Everyone, take off your badge first!"
    }

    /// The setup or clean-up scene with goal rows.
    static func goalScene(_ b: Bookend, kit: Kit, roles: [Role], players n: Int, props: [Prop], cleanup: Bool) -> Scene {
        let items = coverItems(items: kit.items, props: props).filter { $0.recipe != .badges }
        let hasBadges = kit.items.contains { $0.recipe == .badges }
        var jobs: [String: ItemJob] = [:]
        for it in items {
            let j = b.job(it.id).map { transformed($0, props: props) }
            jobs[it.id] = isValid(j, for: it) ? j : (cleanup ? fallbackCleanup(it) : fallbackSetup(it))
        }
        let plan = goalAssignment(items: items, jobs: jobs, roles: roles, players: n)
        let p = PlayCast.players(n)
        let steps = plan.compactMap { row -> Step? in
            guard let role = roles.first(where: { $0.id == row.role }) else { return nil }
            let goal = trimEnd(b.goal(row.goalOf).flatMap { isValidGoal($0) ? $0 : nil } ?? fallbackGoal(row.goalOf, cleanup: cleanup, title: b.title))
            let says = row.items.compactMap { jobs[$0] }.map { trimEnd($0.say) }.filter { !$0.isEmpty }
            let filler = cleanup ? "give everyone a big high five for a great show" : "check that everything is ready and give a big thumbs up"
            let text = "\(role.roleName), " + goalLine(goal: goal, says: says.isEmpty ? [filler] : says) + "!"
            var short = capFirst(goal)
            if p > 1 { short = PlayCast.unname(short, roles: roles, players: p) }
            return Step(picture: .point, text: p > 1 ? PlayCast.unname(text, roles: roles, players: p) : text,
                        role: SceneOwner(row.role), short: short)
        }
        let opening = PlayCast.sceneLine(b.nutmegSays, roles: roles, players: n).trimmingCharacters(in: .whitespacesAndNewlines)
        let badge = hasBadges ? " " + (cleanup ? badgeOffLine(players: n) : badgeLine(players: n)) : ""
        return Scene(id: cleanup ? "cleanup" : "setup", owner: .all,
                     title: PlayCast.unname(b.title, roles: roles, players: p, title: true), picture: .point,
                     nutmegSays: PlayCast.endSentence(opening) + badge, steps: steps, kind: cleanup ? .cleanup : .setup)
    }

    /// "get the pet room ready by hanging up the sign and setting up the pet bed" (every job turned into an -ing phrase).
    /// If a job doesn't start with a verb the app knows, the specifics follow as their own sentence instead:
    /// "get the pet room ready! Hang up the sign, then set up the pet bed".
    public static func goalLine(goal: String, says: [String]) -> String {
        let g = PlayCast.lowerFirst(trimEnd(goal))
        let phrases = says.map { PlayCast.lowerFirst(trimEnd($0)) }
        let ing = phrases.map(Gerund.phrase)
        if ing.allSatisfy({ $0 != nil }) { return g + " by " + list(ing.compactMap { $0 }) }
        return g + "! " + capFirst(steps(phrases))
    }
}

/// Imperative job phrases as -ing phrases ("hang up the sign" → "hanging up the sign"), for "…by hanging up the sign".
public enum Gerund {
    /// Verbs a job may start with (the prompts ask for an imperative phrase).
    static let verbs: Set<String> = [
        "add", "arrange", "bring", "build", "carry", "check", "clean", "clear", "clip", "close", "collect", "color",
        "count", "cover", "deal", "decorate", "draw", "drop", "dust", "fan", "fill", "find", "fix", "flip", "fluff", "fold",
        "gather", "get", "give", "hand", "hang", "help", "hide", "hold", "keep", "label", "lay", "lean", "leave", "line",
        "load", "lock", "make", "mark", "move", "open", "pack", "park", "pass", "pick", "pile", "pin", "place", "plan",
        "point", "pop", "post", "pour", "prop", "pull", "push", "put", "rest", "return", "roll", "rub", "save", "set",
        "settle", "shake", "share", "show", "slide", "sort", "spread", "stack", "stand", "stash", "stick", "store", "stow",
        "straighten", "sweep", "take", "tape", "tidy", "tie", "tuck", "turn", "unpack", "wave", "wipe", "wrap", "write",
        "zip", "hop", "lift", "lower", "raise", "ready", "rinse", "scoop", "seat", "serve", "slip", "smooth", "snap",
        "steer", "stock", "stretch", "swap", "toss", "tow", "unfold", "unroll", "wash", "fasten", "feed", "fly", "drive",
    ]
    /// Verbs that may follow "and" inside a job ("write your name and keep it ready"); nouns that are also verbs
    /// ("stack", "pile", "post"…) are left out so "the cups and stack" can't turn into "stacking".
    static let andVerbs: Set<String> = [
        "put", "set", "hang", "give", "write", "keep", "take", "place", "lay", "line", "load", "pack", "gather", "collect",
        "fold", "bring", "carry", "move", "tuck", "leave", "make", "get", "wave", "hand", "slide", "push", "return", "wipe",
        "tidy", "sort", "open", "close", "tape", "stick", "hide", "stow", "store", "unpack", "wash", "sweep", "spread",
    ]

    /// The -ing form of a verb ("hang" → "hanging", "set" → "setting", "line" → "lining", "tie" → "tying").
    public static func ing(_ verb: String) -> String {
        let v = verb.lowercased()
        let special: [String: String] = ["tie": "tying", "lie": "lying", "die": "dying", "be": "being", "see": "seeing",
                                         "open": "opening", "visit": "visiting", "travel": "traveling", "label": "labeling",
                                         "color": "coloring", "lower": "lowering", "unfold": "unfolding", "unroll": "unrolling",
                                         "straighten": "straightening", "fasten": "fastening", "settle": "settling"]
        if let s = special[v] { return s }
        if v.hasSuffix("ie") { return String(v.dropLast(2)) + "ying" }
        if v.hasSuffix("ee") || v.hasSuffix("ye") || v.hasSuffix("oe") { return v + "ing" }
        if v.hasSuffix("e"), v.count > 2 { return String(v.dropLast()) + "ing" }
        let vowels = Set("aeiou")
        let cs = Array(v)
        let groups = zip(cs, [" "] + cs.dropLast()).filter { vowels.contains($0.0) && !vowels.contains($0.1) }.count
        if groups == 1, cs.count >= 3, let last = cs.last, !vowels.contains(last), !"wxy".contains(last),
           vowels.contains(cs[cs.count - 2]), !vowels.contains(cs[cs.count - 3]) {
            return v + String(last) + "ing"
        }
        return v + "ing"
    }

    /// The whole phrase with its leading verb (and any verb right after "and"/", then") in the -ing form, or nil if it
    /// doesn't start with a verb the app knows.
    public static func phrase(_ s: String) -> String? {
        var words = s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let first = words.first, verbs.contains(first.lowercased()) else { return nil }
        words[0] = ing(first)
        for i in words.indices.dropFirst() where i > 0 {
            let prev = words[i - 1].lowercased()
            guard prev == "and" || prev == "then" else { continue }
            if andVerbs.contains(words[i].lowercased()) { words[i] = ing(words[i]) }
        }
        return words.joined(separator: " ")
    }
}

extension SetupCoverage {
    /// Round 40: the items a goal-row SETUP doesn't name in a row's spoken specifics (badges count by the opening).
    /// Empty = every prop and every printed page is set up on purpose.
    public static func setupMissing(_ scenes: [Scene], items: [CoverItem]) -> [String] {
        missing(in: scenes.first { $0.arc == .setup }, items: items)
    }
    /// Round 40: the same for the clean-up scene (every prop goes back, every page is tidied).
    public static func cleanupMissing(_ scenes: [Scene], items: [CoverItem]) -> [String] {
        missing(in: scenes.first { $0.arc == .cleanup }, items: items)
    }
    static func missing(in scene: Scene?, items: [CoverItem]) -> [String] {
        guard let sc = scene else { return items.map(\.id) }
        return items.filter { it in
            if it.recipe == .badges { return !Bookends.mentions(sc.nutmegSays, it) }
            return !sc.steps.contains { Bookends.mentions($0.text, it) }
        }.map(\.id)
    }
}
