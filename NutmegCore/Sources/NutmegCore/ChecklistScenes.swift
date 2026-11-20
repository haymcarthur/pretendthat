import Foundation

// 2026-11-20 (Haylee, decisions/2026-11-20-checklist-then-scenario-scenes.md): every play scene is now
// "checklists, then a short scenario". In a real family game the ensemble tasks were too long (the kids replayed them
// over and over); short checklist items fit how 4 to 8 year olds listen: hear one thing, do it, come back for the next.
//
// The shape (Claude's calls in decisions/2026-11-20-round-checklist-scenes-build.md):
// - The ONE guide call writes the story, 4 play scenes and the clean-up title. A play scene is a short title, 2 to 3
//   checklist items for EACH of the 6 ranked roles (2 to 6 words, one action each) and ONE "Pretend that…" scenario
//   line that always ends with an action for everyone. The guide's scenes keep `checklist == true`; a step is one item
//   (its shown text in `short`, its role in `role`). What Nutmeg SAYS for an item ("Pilot, put on your badge!") is
//   written by the app when the scene is composed (`say`), so it costs no output tokens.
// - Scenes by player count (`visible`): 1–2 kids see 4, 3–4 see 3, 5–6 see 2 (the middle scenes drop, the first and
//   last stay), so a count change needs no AI call.
// - The old setup scene is folded in: every printed page and every prop the kids have must be named by a checklist
//   item the playing kids SEE, at every count from 1 to 6. The guide is asked to spread the pages over the scenes and
//   each prop's weave puts it into an item; whatever is still missing for a count is added by the app when the scene is
//   composed (`cover`, deterministic, no AI call). `ChecklistCoverage` checks it (tests run every count).
// - The clean-up scene stays as a final checklist (no scenario): every prop goes back, roles with room tidy a page.
// - Older saved games (schema 2 to 5) never have checklist scenes and keep their own scene path untouched.

public enum ChecklistScenes {
    /// The guide writes this many play scenes (shown by player count, `visible`).
    public static let generated = 4
    /// Items per role per scene (the prompt asks 2 to 3; the app keeps at most 3).
    public static let minItems = 2, maxItems = 3
    /// An item longer than this many words is cut back to its first clause (the prompt asks 2 to 6).
    public static let maxItemWords = 8

    // MARK: Which scenes a count sees

    /// How many play scenes N kids see: 1–2 → 4, 3–4 → 3, 5–6 → 2 (Haylee: more players, fewer scenes).
    public static func sceneCount(players n: Int) -> Int {
        switch PlayCast.players(n) {
        case 1, 2: return 4
        case 3, 4: return 3
        default: return 2
        }
    }

    /// The indexes (into the guide's play scenes) N kids see: the first and the last always, then the earliest middle
    /// ones. A pure function of N, so a count change needs no AI call.
    public static func visible(players n: Int, total: Int = generated) -> [Int] {
        guard total > 0 else { return [] }
        let want = sceneCount(players: n)
        if total <= want { return Array(0..<total) }
        if want <= 1 { return [0] }
        let middle = total > 2 ? Array((1..<(total - 1)).prefix(want - 2)) : []
        return [0] + middle + [total - 1]
    }

    // MARK: Item text

    /// One checklist item as shown: trimmed, no quotes, no end punctuation, no leading role title, first letter capital.
    /// A run-on item is cut back to its first clause. Idempotent.
    public static func cleanItem(_ text: String, roles: [Role] = []) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: #"["\x{201C}\x{201D}]"#, with: "", options: .regularExpression)
        // "Pilot, put on your helmet" → "put on your helmet" (the card already shows the role).
        for r in roles where !r.roleName.isEmpty {
            let p = #"(?i)^(?:the\s+)?"# + NSRegularExpression.escapedPattern(for: r.roleName) + #"\s*[,:]\s*"#
            t = t.replacingOccurrences(of: p, with: "", options: .regularExpression)
        }
        t = Bookends.trimEnd(t)
        let words = t.split(whereSeparator: \.isWhitespace)
        if words.count > maxItemWords {
            // First clause ("Set out the seats, then wave to the passengers" → "Set out the seats").
            let clause = t.components(separatedBy: CharacterSet(charactersIn: ",;")).first ?? t
            let cw = clause.split(whereSeparator: \.isWhitespace)
            t = cw.count >= 2 && cw.count <= maxItemWords ? clause : cw.prefix(maxItemWords).joined(separator: " ")
            t = Bookends.trimEnd(t)
        }
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return Bookends.capFirst(t)
    }

    /// What Nutmeg says for an item: "Pilot, put on your badge!" (app-written, so a replay says the same words).
    public static func say(_ item: String, role: Role) -> String {
        let t = Bookends.trimEnd(item.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !t.isEmpty else { return "\(role.roleName), you're ready!" }
        return "\(role.roleName), \(PlayCast.lowerFirst(t))!"
    }

    /// Words that make a scenario end with an action for everyone (Haylee: it never ends on just a problem).
    static let everyoneWords = ["everyone", "everybody", "all of you", "together", "the whole crew", "the whole team"]

    /// The scenario as said: "Pretend that…" first, and an action for everyone at the end (Haylee's update). A line
    /// missing either gets a short app-written piece. Idempotent.
    public static func scenario(_ line: String, index: Int) -> String {
        var t = PretendLine.ensure(line.replacingOccurrences(of: "\"", with: ""), index: index)
        t = PlayCast.endSentence(t.trimmingCharacters(in: .whitespacesAndNewlines))
        let lower = t.lowercased()
        if !everyoneWords.contains(where: { lower.contains($0) }) {
            t += " " + everyoneEndings[((index % everyoneEndings.count) + everyoneEndings.count) % everyoneEndings.count]
        }
        return t
    }
    static let everyoneEndings = ["Everyone, do your job to save the day!", "Everyone, work together to fix it!",
                                  "Everyone, do your job and make it a big success!", "Everyone, help out to finish the adventure!"]

    // MARK: The cue when a scene opens

    /// The one short line when a checklist scene opens (app-written: recorded on the first play, replayed from the clip).
    /// "Scene 2: Get the rocket ready! Tap your picture to hear your jobs."
    public static func cue(_ scene: Scene, number: Int) -> String {
        let title = Bookends.trimEnd(scene.title.trimmingCharacters(in: .whitespacesAndNewlines))
        if scene.arc == .cleanup {
            return (title.isEmpty ? "Clean-up time!" : "Clean-up time: \(title)!") + " " + tapHint
        }
        return (title.isEmpty ? "Scene \(number)!" : "Scene \(number): \(title)!") + " " + tapHint
    }
    public static let tapHint = "Tap your picture to hear your jobs."

    /// The title as the card shows it ("Scene 2: Get the rocket ready"; the clean-up scene keeps its own title).
    public static func shownTitle(_ scene: Scene, number: Int) -> String {
        scene.arc == .cleanup ? scene.title : "Scene \(number): \(scene.title)"
    }

    /// A role's whole checklist in one line (a tap on the card's picture, or "what do I do?" by voice):
    /// "Pilot, put on your badge, hang the Gate 3 sign and set up the steering wheel!"
    public static func roleLine(_ scene: Scene, role: RoleID, roles: [Role]) -> String? {
        let mine = scene.steps.filter { $0.role.role == role }.map { PlayCast.lowerFirst(Bookends.trimEnd($0.short ?? $0.text)) }
        guard !mine.isEmpty, let r = roles.first(where: { $0.id == role }) else { return nil }
        return "\(r.roleName), \(Bookends.list(mine).replacingOccurrences(of: ", and ", with: " and "))!"
    }

    // MARK: Cards (one per playing role)

    /// One playing role's card in a composed checklist scene: the role and its rows (indexes into `scene.steps`).
    public struct Card: Equatable, Sendable {
        public var role: RoleID
        public var rows: [Int]
        public init(role: RoleID, rows: [Int]) { self.role = role; self.rows = rows }
    }

    /// The cards of a composed checklist scene, in rank order (each role's rows in order).
    public static func cards(_ scene: Scene) -> [Card] {
        var out: [Card] = []
        for (i, st) in scene.steps.enumerated() {
            guard let r = st.role.role else { continue }
            if let k = out.firstIndex(where: { $0.role == r }) { out[k].rows.append(i) } else { out.append(Card(role: r, rows: [i])) }
        }
        return out.sorted { $0.role.rank < $1.role.rank }
    }

    // MARK: Repairing the guide (no AI call; runs on every guide that lands and on replays)

    /// The guide's checklist scenes made usable: real titles, exactly `generated` scenes, 1 to 3 clean items per role
    /// (a role with none gets two from its job), no scripted lines, a scenario that says "Pretend that" and ends with an
    /// action for everyone, and only objects the kids really have (`GuideRepair.realProps`). Idempotent.
    public static func repair(_ scenes: [Scene], roles: [Role], props: [Prop], title: String, items: [KitItem]) -> [Scene] {
        var out = Array(scenes.prefix(generated))
        var used = Set(out.map { $0.title.lowercased() })
        for i in out.indices where GuideRepair.isPlaceholderTitle(out[i].title) {
            let t = GuideRepair.titles.first { !used.contains($0.lowercased()) } ?? "\(title) Fun"
            out[i].title = t; used.insert(t.lowercased())
        }
        var k = 0
        while out.count < generated {
            let t = GuideRepair.titles.first { !used.contains($0.lowercased()) } ?? "More \(title) Fun"
            used.insert(t.lowercased())
            out.append(Scene(id: "repair\(k + 1)", owner: .all, title: t, picture: .point,
                             nutmegSays: GuideRepair.intros[k % GuideRepair.intros.count], steps: [], checklist: true))
            k += 1
        }
        var ids = Set<String>()
        for i in out.indices {
            if out[i].id.isEmpty || ids.contains(out[i].id) { out[i].id = "s\(i + 1)" }
            ids.insert(out[i].id)
            out[i].checklist = true
            out[i].owner = .all
            out[i].kind = nil
            out[i].title = Bookends.trimEnd(out[i].title.trimmingCharacters(in: .whitespacesAndNewlines))
            out[i].nutmegSays = scenario(out[i].nutmegSays, index: i)
            out[i].steps = roleItems(out[i].steps, roles: roles)
        }
        out = GuideRepair.noScriptedLines(out)
        out = GuideRepair.realProps(out, roles: roles, props: props, items: items)
        // The repairs above may add words or an end mark: one more clean keeps it idempotent.
        for i in out.indices {
            out[i].steps = out[i].steps.map { st in
                var st = st
                let s = cleanItem(st.short ?? st.text, roles: roles)
                st.short = s; st.text = s
                return st
            }
        }
        return out
    }

    /// One scene's items: R1…R6 in rank order, each role's first `maxItems` distinct non-empty items; a role with none
    /// gets two from its job. Steps for everyone or solo (older shapes) are dropped.
    static func roleItems(_ steps: [Step], roles: [Role]) -> [Step] {
        var out: [Step] = []
        for r in RoleID.allCases {
            var seen = Set<String>(), mine: [Step] = []
            for st in steps where st.role.role == r {
                let s = cleanItem(st.short ?? st.text, roles: roles)
                guard s.split(whereSeparator: \.isWhitespace).count >= 1, seen.insert(s.lowercased()).inserted, mine.count < maxItems else { continue }
                var x = st; x.short = s; x.text = s; x.role = SceneOwner(r)
                mine.append(x)
            }
            if mine.isEmpty, let role = roles.first(where: { $0.id == r }) {
                mine = fillers(role).map { Step(picture: .point, text: $0, role: SceneOwner(r), short: $0) }
            }
            out += mine
        }
        return out
    }

    /// Two items the app writes for a role with none: its job (when short enough) and finding its spot.
    static func fillers(_ role: Role) -> [String] {
        let job = cleanItem(role.job)
        let words = job.split(whereSeparator: \.isWhitespace).count
        let first = words >= 2 && words <= 6 ? job : "Show your best \(role.roleName) move"
        return [first, "Get in your spot"]
    }

    // MARK: Composing the scenes N players see

    /// The arc N players see for a checklist kit: the story, the visible play scenes (with every page and prop the kids
    /// have covered by an item they see), the clean-up checklist. A pure function of the kit, the roles, N and the props.
    public static func compose(_ k: Kit, roles: [Role], players n: Int, props: [Prop]) -> [Scene] {
        guard !roles.isEmpty else { return k.scenes }
        var out: [Scene] = []
        if let story = k.story?.trimmingCharacters(in: .whitespacesAndNewlines), !story.isEmpty {
            out.append(Scene(id: "story", owner: .all, title: k.scenes.first?.title ?? "", picture: .point, nutmegSays: story, steps: [], kind: .story))
        }
        let play = k.scenes.filter(\.isChecklist)
        var shown = visible(players: n, total: play.count).map { playerScene(play[$0], roles: roles, players: n) }
        cover(&shown, items: Bookends.coverItems(items: k.items, props: props), roles: roles, players: n)
        out += shown
        if let c = k.cleanup { out.append(cleanupScene(c, kit: k, roles: roles, players: n, props: props)) }
        return out
    }

    /// One play scene as N players see it: the playing roles' items (rank order), each with the line Nutmeg says, and
    /// no role that isn't playing named anywhere (it becomes "a friend").
    public static func playerScene(_ s: Scene, roles: [Role], players n: Int) -> Scene {
        let p = PlayCast.players(n)
        let playing = RoleCast.playing(roles, kids: p)
        var steps: [Step] = []
        for role in playing {
            for st in s.steps where st.role.role == role.id {
                var x = st
                var shown = st.short ?? st.text
                if p > 1 { shown = PlayCast.unname(shown, roles: roles, players: p) }
                x.short = shown
                x.text = say(shown, role: role)
                steps.append(x)
            }
        }
        let line = PlayCast.sceneLine(s.nutmegSays, roles: roles, players: p)
        return Scene(id: s.id, owner: .all, title: PlayCast.unname(s.title, roles: roles, players: p, title: true), picture: s.picture,
                     nutmegSays: scenario(line, index: 0), steps: steps, checklist: true)
    }

    /// Every page and prop the kids have is named by an item the playing kids see (Haylee: every item is used on
    /// purpose). A missing one is added by the app: the badges as "Put on your badge" for every playing role in the
    /// first scene; anything else as one item ("Hang up the sign", "Set up the airplane seats") for the role it suits
    /// when that role has room, else the least busy role, in the scene where it has the fewest items. Deterministic.
    public static func cover(_ scenes: inout [Scene], items: [CoverItem], roles: [Role], players n: Int) {
        guard !scenes.isEmpty else { return }
        let playing = RoleCast.playing(roles, kids: n)
        guard !playing.isEmpty else { return }
        func named(_ it: CoverItem) -> Bool {
            scenes.contains { $0.steps.contains { Bookends.mentions($0.short ?? $0.text, it) } }
        }
        func count(_ s: Int, _ r: RoleID) -> Int { scenes[s].steps.filter { $0.role.role == r }.count }
        func add(_ item: String, role: Role, scene s: Int, first: Bool = false) {
            let p = PlayCast.players(n)
            let shown = p > 1 ? PlayCast.unname(item, roles: roles, players: p) : item
            let step = Step(picture: .point, text: say(shown, role: role), role: SceneOwner(role.id), short: shown)
            let mine = scenes[s].steps.indices.filter { scenes[s].steps[$0].role.role == role.id }
            if first, let at = mine.first { scenes[s].steps.insert(step, at: at); return }
            if let last = mine.last { scenes[s].steps.insert(step, at: last + 1); return }
            // The role had no items here: its place in rank order.
            let at = scenes[s].steps.firstIndex { ($0.role.role?.rank ?? 0) > role.id.rank } ?? scenes[s].steps.count
            scenes[s].steps.insert(step, at: at)
        }
        for it in items where !named(it) {
            if it.recipe == .badges {
                for role in playing { add("Put on your badge", role: role, scene: 0, first: true) }
                continue
            }
            let text = Bookends.fallbackSetup(it).short
            let preferred = it.prop?.forRole.role.flatMap { r in playing.first { $0.id == r } }
            var best: (s: Int, role: Role)?
            if let pr = preferred {
                let s = scenes.indices.min { count($0, pr.id) < count($1, pr.id) }!
                if count(s, pr.id) < maxItems { best = (s, pr) }
            }
            if best == nil {
                var pick: (s: Int, role: Role, c: Int)?
                for s in scenes.indices {
                    for role in playing {
                        let c = count(s, role.id)
                        if pick == nil || c < pick!.c { pick = (s, role, c) }
                    }
                }
                best = pick.map { ($0.s, $0.role) }
            }
            if let b = best { add(text, role: b.role, scene: b.s) }
        }
    }

    /// The clean-up checklist: every prop the kids have goes back (the role it suits first, spread evenly); then the
    /// printed pages are tidied by roles with room (at most `maxItems` each; the badges last). A role with nothing gets
    /// a high five. Each item shows a short label and Nutmeg says the job ("Captain, put the plastic plate back in the
    /// kitchen!"). No scenario.
    public static func cleanupScene(_ b: Bookend, kit: Kit, roles: [Role], players n: Int, props: [Prop]) -> Scene {
        let p = PlayCast.players(n)
        let playing = RoleCast.playing(roles, kids: p)
        let items = Bookends.coverItems(items: kit.items, props: props)
        var jobs: [String: ItemJob] = [:]
        for it in items {
            let j = b.job(it.id).map { Bookends.transformed($0, props: props) }
            jobs[it.id] = Bookends.isValid(j, for: it) ? j : Bookends.fallbackCleanup(it)
        }
        var load: [RoleID: [String]] = [:]
        func count(_ r: RoleID) -> Int { load[r]?.count ?? 0 }
        func leastLoaded() -> Role? { playing.min { count($0.id) < count($1.id) || (count($0.id) == count($1.id) && $0.id.rank < $1.id.rank) } }
        func preferred(_ id: String) -> Role? { jobs[id]?.role.flatMap { r in playing.first { $0.id == r } } }
        let propItems = items.filter { $0.prop != nil }
        let target = max(1, Int((Double(propItems.count) / Double(max(1, playing.count))).rounded(.up)))
        for it in propItems {
            guard let r = preferred(it.id).flatMap({ count($0.id) < target ? $0 : nil }) ?? leastLoaded() else { continue }
            load[r.id, default: []].append(it.id)
        }
        let pages = items.filter { $0.recipe != nil }.sorted { ($0.recipe == .badges ? 1 : 0) < ($1.recipe == .badges ? 1 : 0) }
        for it in pages {
            let r = preferred(it.id).flatMap { count($0.id) < minItems ? $0 : nil } ?? leastLoaded()
            guard let r, count(r.id) < minItems || (count(r.id) < maxItems && playing.allSatisfy { count($0.id) >= minItems }) else { continue }
            load[r.id, default: []].append(it.id)
        }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var steps: [Step] = []
        for role in playing {
            let ids = load[role.id] ?? []
            if ids.isEmpty {
                steps.append(Step(picture: .point, text: "\(role.roleName), give everyone a big high five for a great game!",
                                  role: SceneOwner(role.id), short: "Give high fives"))
                continue
            }
            for id in ids {
                guard let job = jobs[id], let item = byID[id] else { continue }
                var shown = Bookends.rowShort([job], items: [item], verb: "Put away", cleanup: true)
                var text = "\(role.roleName), \(PlayCast.lowerFirst(Bookends.trimEnd(job.say)))!"
                if p > 1 { shown = PlayCast.unname(shown, roles: roles, players: p); text = PlayCast.unname(text, roles: roles, players: p) }
                steps.append(Step(picture: .point, text: text, role: SceneOwner(role.id), short: shown))
            }
        }
        let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return Scene(id: "cleanup", owner: .all, title: PlayCast.unname(title.isEmpty ? "Clean-Up Time" : title, roles: roles, players: p, title: true),
                     picture: .point, nutmegSays: "", steps: steps, kind: .cleanup, checklist: true)
    }
}

// MARK: - Coverage (every page and prop in an item the kids see, at every count)

public enum ChecklistCoverage {
    /// The cover items no visible play-scene item names (empty = the rule holds). `scenes` = the composed arc for N.
    public static func missing(_ scenes: [Scene], items: [CoverItem]) -> [String] {
        let play = scenes.filter { $0.arc == .play }
        return items.filter { it in !play.contains { $0.steps.contains { Bookends.mentions($0.short ?? $0.text, it) } } }.map(\.id)
    }

    /// One log line per item: "page:sign (the Gate 3 sign) → scene 1 R1".
    public static func log(_ scenes: [Scene], items: [CoverItem]) -> [String] {
        let play = scenes.filter { $0.arc == .play }
        return items.map { it in
            var places: [String] = []
            for (k, sc) in play.enumerated() {
                for st in sc.steps where Bookends.mentions(st.short ?? st.text, it) { places.append("scene \(k + 1) \(st.role.rawValue)") }
            }
            return "\(it.id) (\(it.label)) → " + (places.isEmpty ? "UNUSED" : places.joined(separator: ", "))
        }
    }
}

// MARK: - Checks (which items are ticked), kept per scene

/// Which checklist items are checked, per scene id ("s1"…, "cleanup"). Game content only (indexes), never anything
/// about a kid. Kept when the kids go back a scene (Haylee: Previous keeps the checks as they were), cleared on a
/// count change (the rows are for the old crew).
public struct ChecklistProgress: Codable, Equatable, Sendable {
    public var checked: [String: Set<Int>]
    public init(checked: [String: Set<Int>] = [:]) { self.checked = checked }

    public func isChecked(scene: String, step: Int) -> Bool { checked[scene]?.contains(step) ?? false }

    /// Ticks or unticks one item.
    public mutating func toggle(scene: String, step: Int) {
        if checked[scene, default: []].contains(step) { checked[scene]?.remove(step) } else { checked[scene, default: []].insert(step) }
        if checked[scene]?.isEmpty == true { checked[scene] = nil }
    }

    /// Every item of a composed checklist scene is checked (a scene with no items is never "done").
    public func isDone(_ scene: Scene) -> Bool {
        guard scene.isChecklist, !scene.steps.isEmpty else { return false }
        let mine = checked[scene.id] ?? []
        return scene.steps.indices.allSatisfy { mine.contains($0) }
    }

    /// How many of a role's rows are checked ("1 of 3").
    public func count(scene: String, rows: [Int]) -> Int { rows.filter { isChecked(scene: scene, step: $0) }.count }
}

// MARK: - Reading queue (Haylee: taps while she talks queue up; only the row being read is highlighted)

/// The checklist's reading queue: a 🔊 tap while she is talking waits its turn (no visible queued marker); the row
/// being read is highlighted. The scenario joins the queue too (after the row she's reading). Pure state; the app
/// says each item and calls `finished()` when she stops.
public struct ChecklistReader: Equatable, Sendable {
    public enum Item: Equatable, Sendable { case row(Int), line(String) }
    public private(set) var reading: Item?
    public private(set) var queue: [Item] = []
    public init() {}

    /// A tap (or the scenario). Returns the item to say now, or nil when it waits (or is already being read / queued).
    public mutating func tap(_ item: Item, busy: Bool) -> Item? {
        if busy {
            if item == reading || queue.contains(item) { return nil }
            queue.append(item)
            return nil
        }
        queue.removeAll { $0 == item }
        reading = item
        return item
    }

    /// She stopped talking: the next item to say (nil = nothing left; the highlight goes off).
    public mutating func finished() -> Item? {
        guard !queue.isEmpty else { reading = nil; return nil }
        reading = queue.removeFirst()
        return reading
    }

    /// The scene changed (or she was cut off): nothing waits and nothing is highlighted.
    public mutating func clear() { reading = nil; queue = [] }

    /// The rows still waiting are dropped (the scenario comes next instead).
    public mutating func dropQueuedRows() { queue.removeAll { if case .row = $0 { return true } else { return false } } }

    /// The row being read (highlighted), if any.
    public var highlighted: Int? { if case .row(let i)? = reading { return i } else { return nil } }
    public var isIdle: Bool { reading == nil && queue.isEmpty }
}

// MARK: - Resume (Haylee: relaunching mid-game shouldn't mean redoing the props and printing)

/// Where an in-progress game was: which saved game, how many played, the scene on screen and the checks. Game content
/// only (an id, numbers and indexes): never a name, a word a kid said or anything else about a kid. Stored on the
/// device only (no backend), cleared at The End, on Home and when the game is deleted.
public struct ResumePoint: Codable, Equatable, Sendable {
    public var gameID: UUID
    public var players: Int
    /// The index into the composed scenes (story = 0 when the game has one).
    public var scene: Int
    public var progress: ChecklistProgress
    public var savedAt: Date
    public init(gameID: UUID, players: Int, scene: Int, progress: ChecklistProgress, savedAt: Date) {
        self.gameID = gameID; self.players = players; self.scene = scene; self.progress = progress; self.savedAt = savedAt
    }
    /// An offer older than this is dropped (a game left days ago is a new evening: start from the bookshelf instead).
    public static let maxAge: TimeInterval = 3 * 24 * 3600
    public func isFresh(now: Date = Date()) -> Bool { now.timeIntervalSince(savedAt) < Self.maxAge && now >= savedAt.addingTimeInterval(-60) }

    /// The exact JSON keys a resume point may have (a privacy test compares against this; a new field is a decision).
    public static let allowedKeys: Set<String> = ["gameID", "players", "scene", "progress", "savedAt"]

    public static func encoder() -> JSONEncoder { SavedGame.encoder() }
    public static func decoder() -> JSONDecoder { SavedGame.decoder() }
}
