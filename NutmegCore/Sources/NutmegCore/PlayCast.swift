import Foundation

// Round C1 (generate for 6, Haylee's answer 2): every game is written for 6 kids. Claude (or the voice model) makes 6
// RANKED roles, R1…R6, and every scene has ONE step for each of the 6 roles (called out by the role's title) plus up
// to 2 steps for everyone. With N kids the first N roles play: the app shows and says only their steps, and the
// hand-offs rotate through those N roles over the scenes, so every kid gets a turn holding the iPad. Changing N never
// needs an AI call: everything here is a pure function of the game data and N (unit-tested in RoundC1Tests).

/// Turns the roles Nutmeg proposed into the game's cast (decision roles-not-names.md): exactly 6 distinct ranked
/// roles, ids R1…R6 by position, one kid each. A repeated or missing title gets a generic extra role.
public enum RoleCast {
    /// Every game has this many ranked roles.
    public static let count = 6

    /// Generic extras used when the model gave fewer than 6 distinct titles (Claude's call: role-neutral, kid-friendly).
    public static let extras: [(name: String, job: String)] = [
        ("Helper", "help everyone with a big smile"), ("Lookout", "look out for surprises"),
        ("Cheerleader", "cheer for the whole team"), ("Announcer", "announce the big moments"),
        ("Greeter", "welcome everyone with a wave"), ("Photographer", "snap pretend pictures"),
        ("Super Helper", "help wherever it's needed"),
    ]

    /// Exactly 6 distinct titles in rank order (the order given), ids R1…R6, count 1.
    public static func rank(_ roles: [Role]) -> [Role] {
        var out: [Role] = []
        func taken(_ name: String) -> Bool { out.contains { $0.roleName.caseInsensitiveCompare(name) == .orderedSame } }
        for r in roles {
            let name = r.roleName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !taken(name), out.count < count else { continue }
            var r = r; r.roleName = name; r.count = 1
            out.append(r)
        }
        for e in extras where out.count < count && !taken(e.name) {
            out.append(Role(id: .R1, roleName: e.name, emoji: "", symbol: "star", job: e.job))
        }
        for i in out.indices { out[i].id = RoleID.allCases[i] }
        return out
    }

    /// The roles playing with `kids` kids: the first N (at least 1, at most 6).
    public static func playing(_ roles: [Role], kids: Int) -> [Role] {
        Array(roles.prefix(PlayCast.players(kids)))
    }
}

public enum PlayCast {
    /// The most steps a checklist shows (the checklist fit is built for 3 to 6 rows).
    public static let maxVisibleSteps = 6
    /// Round 28 (Haylee): a role's checklist is only theirs, so no steps for everyone are shown (kept at 0 for older
    /// callers; a guide that still has "all" steps keeps them in the data, never on screen).
    public static let groupStepsMax = 0
    /// Round 28: each role has this many steps of its own in every scene (its checklist when it holds the iPad).
    public static let stepsPerRole = 2

    /// 1…6.
    public static func players(_ n: Int) -> Int { max(1, min(n, RoleCast.count)) }

    /// Who holds the iPad in turn `i` of a guide written before round C1 (no role steps): the playing roles in turn.
    public static func owner(scene i: Int, players n: Int) -> RoleID {
        RoleID.allCases[((i % players(n)) + players(n)) % players(n)]
    }

    /// A scene written before round C1 (no step belongs to a role): shown as it is.
    static func isLegacy(_ s: Scene) -> Bool { !s.steps.contains { $0.role.role != nil } }

    /// Round 28 (Haylee, "one role per checklist"): the checklist for ONE playing role in a scene: that role's own
    /// steps (at most `stepsPerRole`), or one the app writes from the role's job if the scene has none. No other
    /// role's steps and no steps for everyone. Order is the scene's own order.
    public static func turnSteps(_ scene: Scene, role: Role, roles: [Role], players n: Int) -> [Step] {
        let n = players(n)
        var own = scene.steps.filter { $0.role.role == role.id }
        if own.isEmpty { own = [filler(role)] }
        return own.prefix(stepsPerRole).map { st in
            var s = st
            s.text = calledOut(unname(s.text, roles: roles, players: n), role: role)
            return s
        }
    }

    /// Every playing role's steps in a scene, in role order (tests and the guide view; play uses `turnSteps`).
    public static func visibleSteps(_ scene: Scene, roles: [Role], players n: Int) -> [Step] {
        let n = players(n)
        if isLegacy(scene) { return scene.steps.map { var s = $0; s.text = unname(s.text, roles: roles, players: n); return s } }
        return RoleCast.playing(roles, kids: n).flatMap { turnSteps(scene, role: $0, roles: roles, players: n) }
    }

    /// The step the app writes for a role that has none in a scene ("Lookout, look out for surprises!").
    static func filler(_ role: Role) -> Step {
        let job = role.job.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
        let text = job.isEmpty ? "\(role.roleName), show everyone your best move!" : "\(role.roleName), \(lowerFirst(job))!"
        return Step(picture: .action("cheer"), text: text, role: SceneOwner(role.id))
    }

    /// Round 28: a second step the app writes (template scenes): a body action, no object.
    static func filler2(_ role: Role, variant k: Int) -> Step {
        let moves: [(String, String)] = [("give a friend a big wave", "wave"), ("clap for your team", "clap"),
                                         ("point to where the fun is", "point"), ("count to five out loud", "count")]
        let m = moves[((k % moves.count) + moves.count) % moves.count]
        return Step(picture: .action(m.1), text: "\(role.roleName), \(m.0)!", role: SceneOwner(role.id))
    }

    /// Round 28 (Haylee, "one role per checklist"): the play TURNS for N players. For each scene, each playing role in
    /// rank order gets a turn: a hand-off to that role, then a checklist of only that role's steps. The first turn of
    /// a scene carries the scene's "Pretend that" intro; the others start straight at the role's first step.
    /// A guide written before round C1 (no role steps) keeps one turn per scene, rotating as before.
    public static func turns(_ s: Scene, index i: Int, roles: [Role], players n: Int) -> [Scene] {
        let n = players(n)
        let title = unname(s.title, roles: roles, players: n, title: true)
        let intro = sceneLine(s.nutmegSays, roles: roles, players: n)
        let playing = roles.isEmpty ? [] : RoleCast.playing(roles, kids: n)
        if isLegacy(s) || playing.isEmpty {
            var out = s
            out.steps = visibleSteps(s, roles: roles, players: n)
            out.owner = SceneOwner(owner(scene: i, players: n))
            out.title = title; out.nutmegSays = intro
            return [out]
        }
        return playing.enumerated().map { k, role in
            Scene(id: "\(s.id)#\(role.id.rawValue)", owner: SceneOwner(role.id), title: title, picture: s.picture,
                  nutmegSays: k == 0 ? intro : "", steps: turnSteps(s, role: role, roles: roles, players: n))
        }
    }

    /// The scene as N players see it, for the first playing role (kept for older callers).
    public static func scene(_ s: Scene, index i: Int, roles: [Role], players n: Int) -> Scene {
        turns(s, index: i, roles: roles, players: n)[0]
    }

    /// The whole kit as N players see it: `scenes` is the list of play TURNS (scene 1: R1, R2, …, RN; scene 2: R1, …).
    /// The pages are unchanged (KitLayout prints N badges).
    public static func kit(_ k: Kit, roles: [Role], players n: Int) -> Kit {
        var out = k
        out.scenes = k.scenes.enumerated().flatMap { turns($0.element, index: $0.offset, roles: roles, players: n) }
        return out
    }

    // MARK: Text

    /// The step names its role ("Navigator, read the map!"); if it doesn't, the title goes in front.
    public static func calledOut(_ text: String, role: Role) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if names(t, role.roleName) { return t }
        return "\(role.roleName), \(lowerFirst(t))"
    }

    /// Whether `text` names `title` as a whole word ("Co-Pilot" doesn't count as "Pilot").
    public static func names(_ text: String, _ title: String) -> Bool {
        text.range(of: wordPattern(title), options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func wordPattern(_ title: String) -> String {
        #"(?<![\p{L}\p{N}-])"# + NSRegularExpression.escapedPattern(for: title) + #"(?![\p{L}\p{N}-])"#
    }

    /// Roles that aren't playing become "a friend" ("Hand the map to the Lookout" → "Hand the map to a friend").
    public static func unname(_ text: String, roles: [Role], players n: Int, title: Bool = false) -> String {
        let away = roles.filter { $0.id.rank > players(n) }.map(\.roleName).filter { !$0.isEmpty }
            .filter { a in !RoleCast.playing(roles, kids: n).contains { $0.roleName.caseInsensitiveCompare(a) == .orderedSame } }
            .sorted { $0.count > $1.count }
        guard !away.isEmpty else { return text }
        var s = text
        let friend = title ? "A Friend" : "a friend"
        for name in away {
            let escaped = NSRegularExpression.escapedPattern(for: name)
            s = s.replacingOccurrences(of: #"(?i)(?<![\p{L}\p{N}-])(the|a|an|our|your)\s+"# + escaped + #"(?![\p{L}\p{N}-])"#,
                                       with: friend, options: .regularExpression)
            s = s.replacingOccurrences(of: "(?i)" + wordPattern(name), with: friend, options: .regularExpression)
        }
        return title ? s : capitalizeSentences(s)
    }

    /// A scene's intro line: sentences naming a role that isn't playing are dropped (the "Pretend that" sentence
    /// is kept); if nothing is left, the names are swapped for "a friend".
    public static func sceneLine(_ line: String, roles: [Role], players n: Int) -> String {
        let away = roles.filter { $0.id.rank > players(n) }.map(\.roleName)
            .filter { a in !RoleCast.playing(roles, kids: n).contains { $0.roleName.caseInsensitiveCompare(a) == .orderedSame } }
        guard away.contains(where: { names(line, $0) }) else { return line }
        let kept = sentences(line).filter { s in PretendLine.has(s) || !away.contains { names(s, $0) } }
        let joined = kept.joined(separator: " ")
        return joined.isEmpty ? unname(line, roles: roles, players: n) : unname(joined, roles: roles, players: n)
    }

    static func sentences(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in s {
            cur.append(ch)
            if ".!?".contains(ch) { let t = cur.trimmingCharacters(in: .whitespaces); if !t.isEmpty { out.append(t) }; cur = "" }
        }
        let t = cur.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { out.append(t) }
        return out
    }

    static func lowerFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        let firstWord = s.split(separator: " ").first.map(String.init) ?? ""
        // Keep "I", acronyms ("UFO") and the capital of a role or proper name the model wrote in the middle.
        if firstWord == "I" || firstWord.hasPrefix("I'") || (firstWord.count > 1 && firstWord.allSatisfy(\.isUppercase)) { return s }
        return first.lowercased() + s.dropFirst()
    }

    static func capitalizeSentences(_ s: String) -> String {
        var out = "", start = true
        for ch in s {
            if start, ch.isLetter { out += ch.uppercased(); start = false; continue }
            if ".!?".contains(ch) { start = true } else if ch.isLetter || ch.isNumber { start = false }
            out.append(ch)
        }
        return out
    }

    // MARK: What Nutmeg says about the crew

    /// "a Captain, a Navigator and a Parrot Keeper" (the playing roles).
    public static func crewList(_ roles: [Role]) -> String {
        let names = roles.map { article($0.roleName) + " " + $0.roleName }
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return names[0] + " and " + names[1]
        default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
    }

    static func article(_ word: String) -> String {
        "aeiou".contains(word.lowercased().first ?? "x") ? "an" : "a"
    }

    /// The line for a count change once the roles exist (no AI call: the roles, props and kit stay):
    /// "Four friends! Our crew is a Captain, a Navigator, a Cook and a Lookout!" / "Just you! You'll be the Captain!"
    public static func countChangeLine(roles: [Role], players n: Int) -> String {
        let n = players(n)
        let crew = RoleCast.playing(roles, kids: n)
        if n == 1 { return "Just you! You'll be the \(crew.first?.roleName ?? "star")!" }
        let count = ConfirmStep.number(n).prefix(1).uppercased() + ConfirmStep.number(n).dropFirst()
        return "\(count) friends! Our crew is \(crewList(crew))!"
    }
}
