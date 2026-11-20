import Foundation

// 2026-11-21 (Haylee, decisions/2026-11-21-one-scene-music-beats.md; build: decisions/2026-11-21-round-one-scene-build.md):
// the play guide is a SETUP checklist, then ONE ~10 minute scene with music, then a CLEAN-UP checklist. During the scene
// Nutmeg (the director) calls out events at set moments: each event names its role(s) first and gives one short thing
// to do. Tense events are resolved later by a calm-again line that never says the kids fixed it ("Phew, the rush has
// died down."). A finale for everyone ends the scene, and the clean-up checklist opens by itself.
//
// The shape (Claude's calls in the build decision):
// - The ONE guide call writes the story, the setup checklist (2 to 3 items per ranked role R1…R6), the scene's
//   "Pretend that…" opener, an EVENT POOL (8 to 12 events across all 6 roles), the finale, a music family from a fixed
//   list, and the clean-up title. Stored as ONE guide scene (`Scene.beats` + its setup items as checklist steps), so the
//   prop weave, the kid-safety check and the saved game all keep working on it.
// - The app picks the events for the playing count (`pick`): about 3 for 1–2 kids, 4 for 3–4, 5 for 5–6, a calm/tense
//   cadence, and FAIR CALLS: each playing role is called a near-equal number of times (max difference 1, at least
//   once), counted here. A pool that can't do it is repaired with app-written events (no AI call).
// - When the events fire is `BeatTimeline` (~10 minutes; events 1.5–3 min apart; calm-again 45 s after a tense event;
//   Nutmeg repeats each event line once 15 s later; the finale near the end; the clean-up 20 s after it), driven by
//   `BeatClock` (an injected clock, so tests and the demo fast-clock run it at any speed).
// - Clean-up (`cleanupScene`): one item for EVERY prop the kids got out + exactly one item for the print mess, spread
//   fairly over the playing roles (max difference 1).
// - Older saved games (schemas 2 to 6) never have `beats` and keep their own scene path.

// MARK: - Music families

/// The music the scene plays (bundled loops; `Music/<family>/calm|tense|win.m4a`, see PretendThat/Resources/Music/README.md).
/// A fixed list: the guide picks one, the app falls back to a keyword guess.
public enum MusicFamily: String, Codable, Sendable, CaseIterable {
    case spaceAdventure = "space-adventure"
    case jungleOutdoors = "jungle-outdoors"
    case magical
    case cozyShop = "cozy-shop"
    case spookySilly = "spooky-silly"
    case underTheSea = "under-the-sea"
    case desertWestern = "desert-western"

    /// The small music pill's words ("Space adventure").
    public var label: String {
        switch self {
        case .spaceAdventure: "Space adventure"
        case .jungleOutdoors: "Jungle adventure"
        case .magical: "Magic kingdom"
        case .cozyShop: "Cozy shop"
        case .spookySilly: "Silly spooky"
        case .underTheSea: "Under the sea"
        case .desertWestern: "Wild west"
        }
    }

    /// What it fits (the prompt's list).
    public var fits: String {
        switch self {
        case .spaceAdventure: "rockets, the Moon, planets, aliens, robots"
        case .jungleOutdoors: "jungle, safari, camping, farm, zoo, dinosaurs, gardens"
        case .magical: "castles, fairies, wizards, dragons, unicorns, knights"
        case .cozyShop: "bakery, restaurant, shop, vet, doctor, school, salon, post office, anything everyday"
        case .spookySilly: "silly ghosts, monsters, haunted houses, mystery (never scary)"
        case .underTheSea: "ocean, pirates, mermaids, submarines, beach, islands"
        case .desertWestern: "cowboys, ranch, desert, horses, sheriffs, gold mines"
        }
    }

    public static let fallback: MusicFamily = .cozyShop

    /// Tolerant: "space adventure", "Space_Adventure", "space-adventure" and the pill label all work.
    public static func parse(_ raw: String) -> MusicFamily? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let k = t.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "_", with: "-")
        return MusicFamily(rawValue: k) ?? allCases.first { $0.label.lowercased() == t }
    }

    static let keywords: [(MusicFamily, [String])] = [
        (.spaceAdventure, ["space", "rocket", "moon", "planet", "astronaut", "alien", "galaxy", "robot", "star base"]),
        (.underTheSea, ["sea", "ocean", "pirate", "mermaid", "submarine", "beach", "island", "fish", "shark", "boat"]),
        (.spookySilly, ["spooky", "ghost", "haunted", "monster", "halloween", "witch", "vampire", "mystery", "detective"]),
        (.magical, ["magic", "fairy", "castle", "wizard", "dragon", "princess", "unicorn", "knight", "royal", "kingdom"]),
        (.desertWestern, ["west", "cowboy", "cowgirl", "desert", "ranch", "horse", "sheriff", "rodeo", "gold"]),
        (.jungleOutdoors, ["jungle", "safari", "camp", "forest", "zoo", "farm", "dinosaur", "garden", "park", "explorer", "hike"]),
    ]

    /// A keyword guess from the game's words (title, setting) when the guide's tag is missing or unknown.
    public static func guess(_ text: String) -> MusicFamily {
        let t = text.lowercased()
        for (f, words) in keywords where words.contains(where: { PlayCast.names(t, $0) }) { return f }
        return fallback
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MusicFamily.parse(raw) ?? .fallback
    }
}

// MARK: - Events

/// An event's beat: calm (a fun job) or tense (a small problem, later resolved by a calm-again line).
public enum BeatMood: String, Codable, Sendable, CaseIterable {
    case calm, tense
    public init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = BeatMood(rawValue: raw.lowercased()) ?? .calm
    }
}

/// One event Nutmeg calls out during the scene: its beat, the role(s) it calls (1 to 3; empty = everyone), the line
/// (names the role(s), then one short thing to do) and, for a tense event, the calm-again line that resolves it.
public struct BeatEvent: Codable, Equatable, Sendable {
    public var mood: BeatMood
    public var roles: [RoleID]
    public var line: String
    public var calmAgain: String?
    /// Written by the app (a pool that couldn't call every role fairly), not the guide.
    public var appWritten: Bool?
    public init(mood: BeatMood, roles: [RoleID], line: String, calmAgain: String? = nil, appWritten: Bool? = nil) {
        self.mood = mood; self.roles = roles; self.line = line; self.calmAgain = calmAgain; self.appWritten = appWritten
    }
    public var isTense: Bool { mood == .tense }
    public var isEveryone: Bool { roles.isEmpty }
    private enum CodingKeys: String, CodingKey { case mood, roles, line, calmAgain, appWritten }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mood = (try? c.decodeIfPresent(BeatMood.self, forKey: .mood)) ?? .calm
        let raw = ((try? c.decodeIfPresent([String].self, forKey: .roles)) ?? nil) ?? []
        var seen = Set<RoleID>()
        roles = raw.compactMap { RoleID(rawValue: $0.uppercased()) }.filter { seen.insert($0).inserted }
        line = ((try? c.decodeIfPresent(String.self, forKey: .line)) ?? nil) ?? ""
        let again = ((try? c.decodeIfPresent(String.self, forKey: .calmAgain)) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines)
        calmAgain = (again?.isEmpty ?? true) ? nil : again
        appWritten = (try? c.decodeIfPresent(Bool.self, forKey: .appWritten)) ?? nil
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mood, forKey: .mood); try c.encode(roles, forKey: .roles); try c.encode(line, forKey: .line)
        try c.encodeIfPresent(calmAgain, forKey: .calmAgain)
        if appWritten == true { try c.encode(true, forKey: .appWritten) }
    }
}

/// The one scene's beats. In the guide's scene `events` is the POOL; in the scene the players see (composed for a
/// count) it is the picked plan, in order.
public struct SceneBeats: Codable, Equatable, Sendable {
    public var opener: String
    public var events: [BeatEvent]
    public var finale: String
    public var music: MusicFamily
    public init(opener: String, events: [BeatEvent], finale: String, music: MusicFamily) {
        self.opener = opener; self.events = events; self.finale = finale; self.music = music
    }
    private enum CodingKeys: String, CodingKey { case opener, events, finale, music }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        opener = ((try? c.decodeIfPresent(String.self, forKey: .opener)) ?? nil) ?? ""
        events = ((try? c.decodeIfPresent([BeatEvent].self, forKey: .events)) ?? nil) ?? []
        finale = ((try? c.decodeIfPresent(String.self, forKey: .finale)) ?? nil) ?? ""
        music = ((try? c.decodeIfPresent(MusicFamily.self, forKey: .music)) ?? nil) ?? .fallback
    }
    /// Every text Nutmeg may say in the scene (the kid-safety check).
    public var texts: [String] { [opener, finale] + events.flatMap { [$0.line] + ($0.calmAgain.map { [$0] } ?? []) } }
}

extension Kit {
    /// 2026-11-21: a one-scene kit (setup checklist → one scene with events and music → clean-up checklist). Saved games
    /// from schema 7 on; older kits are never this and keep their own scene path.
    public var isOneScene: Bool { scenes.contains { $0.beats != nil } }
}

extension Scene {
    /// Every text of this scene Nutmeg may say (title, line, items, and the beats' lines).
    public var spokenTexts: [String] {
        [title, nutmegSays] + steps.flatMap { [$0.text] + ($0.short.map { [$0] } ?? []) } + (beats?.texts ?? [])
    }
}

// MARK: - The guide

public enum OneScene {
    /// Events the app plays for N kids: 1–2 → 3, 3–4 → 4, 5–6 → 5 (Haylee's defaults).
    public static func eventCount(players n: Int) -> Int {
        switch PlayCast.players(n) {
        case 1, 2: return 3
        case 3, 4: return 4
        default: return 5
        }
    }
    /// The pool the guide is asked for, and the most the app keeps.
    public static let poolMin = 8, poolMax = 12
    /// Roles one event may call.
    public static let maxRolesPerEvent = 3
    /// An event line longer than this is cut to its first two sentences.
    public static let maxLineWords = 34

    /// The beats' order: calm first, then alternating (calm → tense → calm → tense …). A tense event is followed by its
    /// calm-again line, then the next event.
    public static func cadence(_ count: Int) -> [BeatMood] {
        (0..<max(0, count)).map { $0 % 2 == 0 ? .calm : .tense }
    }

    // MARK: Schema and prompt

    /// The guide's answer: the story, the setup checklist (2 to 3 items per role R1…R6), the opener, the event pool,
    /// the finale, the music family and the clean-up title. Shorter than the 11-20 guide (one checklist instead of 4).
    public static func schema() -> [String: Any] {
        var setup: [String: Any] = [:]
        for r in RoleID.allCases {
            setup[r.rawValue] = ["type": "array", "items": ["type": "string"],
                                 "description": "The \(r.rawValue) role's setup checklist: 2 or 3 items, each 2 to 6 words, one simple action, no role title, no end punctuation (e.g. Put on your badge)."]
        }
        let event: [String: Any] = Schemas.obj([
            "mood": ["type": "string", "enum": BeatMood.allCases.map(\.rawValue), "description": "calm = a fun job; tense = a small, silly problem (never scary)."],
            "roles": ["type": "array", "items": ["type": "string", "enum": Schemas.roleIDs],
                      "description": "The 1 to 3 roles this event calls (every role it names)."],
            "line": ["type": "string", "description": "ONE short line, 10 to 25 words, that names the role or roles by their titles and gives each ONE short thing to do (e.g. There's a big lunch rush! Quick, Waiter, take the new people to their seats, and Cook, get ready to make more food!)."],
            "calmAgain": ["type": "string", "description": "tense events: the line said about 45 seconds later that says things are calm again WITHOUT saying the kids fixed it (e.g. Phew, the rush has died down.). calm events: an empty string."],
        ])
        var props: [String: Any] = [:]
        props["story"] = ["type": "string", "description": "The story Nutmeg tells right after printing: 3 or 4 short sentences, about 40 to 55 words (15 seconds): where we are, who the kids are (the R1 role and the crew; name no other role), and what is about to happen. Kid words, exciting, no quotes."]
        props["setupTitle"] = ["type": "string", "description": "2 to 5 words: what the kids get ready for (e.g. Get the rocket ready)."]
        props["setup"] = Schemas.obj(setup)
        props["opener"] = ["type": "string", "description": "The scene's opener: ONE short line, 12 to 25 words, that starts with \"Pretend that\" and starts the adventure (e.g. Pretend that the rocket is blasting off to the Moon! Everyone, take your places!)."]
        props["events"] = ["type": "array", "items": event,
                           "description": "\(poolMin) to \(poolMax) events, about half calm and half tense, calling all 6 roles (see the rules)."]
        props["finale"] = ["type": "string", "description": "The big ending for everyone, ONE short line (e.g. We made it to the Moon! Everyone, celebrate!)."]
        props["music"] = ["type": "string", "enum": MusicFamily.allCases.map(\.rawValue), "description": "The background music that fits the game best."]
        props["cleanupTitle"] = ["type": "string", "description": "2 to 4 words: the title of the final clean-up checklist, the story's ending (e.g. Closing Time)."]
        return Schemas.obj(props)
    }

    /// The guide prompt (written during the hunt: no household props yet; each prop's weave puts it into a setup item).
    public static func prompt(ctx: AdventureContext, items: [KitItem]) -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let pages = items.map { ["recipe": $0.recipe?.rawValue ?? "", "title": $0.title, "purpose": $0.purpose ?? ""] }
        let pagesJSON = (try? enc.encode(pages)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
        return """
        Phase: the play guide. The printable pages are already made (JSON): \(pagesJSON)
        \(rules)
        \(Prompts.contextJSON(ctx))
        """
    }

    static var musicList: String { MusicFamily.allCases.map { "\($0.rawValue) (\($0.fits))" }.joined(separator: "; ") }

    /// The rules (Haylee's one-scene design; the event pool is what makes every group size work).
    static var rules: String {
        "Write the STORY, a SETUP checklist, ONE PLAY SCENE and the clean-up title, all in this one answer. Kids ages 4 "
        + "to 8 play together, the iPad on the side: the app plays music for about 10 minutes and Nutmeg, the director, "
        + "calls out events now and then. The game is written for up to 6 kids: the roles R1 to R6 are ranked, and with N "
        + "kids only R1 to RN play. "
        + "SETUP: setupTitle (2 to 5 words, e.g. Get the rocket ready); for EACH role R1 to R6 a checklist of 2 or 3 SHORT "
        + "items, each 2 to 6 words, ONE simple action a 4-year-old can do alone, no role title, no end punctuation: put on "
        + "or set up a printed page, or get a spot ready (e.g. Put on your badge, Hang the Moon Base sign, Line up the "
        + "seats). Every role's list starts with Put on your badge; spread the other printed pages over the roles, naming "
        + "each by its kind or title, so every page is used. "
        + "THE SCENE: opener = ONE short line starting with \"Pretend that\". events = \(poolMin) to \(poolMax) events. Each "
        + "event: mood calm (a fun job) or tense (a small, silly problem, never scary or sad), the roles it calls (1 to 3) "
        + "and ONE short line, 10 to 25 words, that calls each of those roles by its title and gives each ONE short thing "
        + "to do (e.g. \"There's a big lunch rush! Quick, Waiter, take the new people to their seats, and Cook, get ready to "
        + "make more food!\"). An event may name ONLY the roles in its roles list. Every tense event has calmAgain: what "
        + "Nutmeg says later when it's over, WITHOUT saying the kids fixed it (e.g. \"Phew, the rush has died down.\"); calm "
        + "events have an empty calmAgain. THE POOL MUST WORK FOR EVERY GROUP SIZE: at least 3 events (one of them tense) "
        + "call ONLY R1; at least 2 call R2 (alone or with R1); then every role R3, R4, R5 and R6 is called by at least 2 "
        + "events, which may also call roles ranked above it (a lower R number); include a few events that call 2 or 3 "
        + "roles together. finale = the big ending for everyone (\"We made it to the Moon! Everyone, celebrate!\"). "
        + "Lines are pretend actions with the kids' bodies, voices and the printed pages: use NO household props and no "
        + "household things (the kids are still hunting for props), no scripted words to repeat, no quotes. Only the opener, finale and story name no "
        + "role except R1. music = one of: \(musicList). "
        + "story: what Nutmeg tells right after printing, 3 or 4 short sentences (about 15 seconds): where we are, who the "
        + "kids are and what is about to happen. cleanupTitle: 2 to 4 words for the final clean-up checklist (e.g. Closing Time)."
    }

    // MARK: Repairing the guide (no AI call; runs on every guide that lands and on replays)

    /// The guide's one scene made usable: a real setup title, 1 to 3 clean setup items per role (a role with none gets
    /// two from its job), only real objects, a "Pretend that" opener, a clean event pool (every event names the roles
    /// it calls, at most 3, a tense one has a calm-again line that doesn't credit the kids), a finale for everyone and a
    /// known music family. Idempotent.
    public static func repair(_ scene: Scene, roles: [Role], props: [Prop], title: String, items: [KitItem]) -> Scene {
        var s = scene
        if s.id.isEmpty { s.id = "s1" }
        s.checklist = true
        s.owner = .all
        s.kind = nil
        s.title = Bookends.trimEnd(s.title.trimmingCharacters(in: .whitespacesAndNewlines))
        if s.title.isEmpty || GuideRepair.isPlaceholderTitle(s.title) { s.title = "Get Ready" }
        s.steps = ChecklistScenes.roleItems(s.steps, roles: roles)
        var list = GuideRepair.noScriptedLines([s])
        list = GuideRepair.realProps(list, roles: roles, props: props, items: items)
        s = list[0]
        s.steps = s.steps.map { st in
            var st = st
            let t = ChecklistScenes.cleanItem(st.short ?? st.text, roles: roles)
            st.short = t; st.text = t
            return st
        }
        var b = s.beats ?? SceneBeats(opener: s.nutmegSays, events: [], finale: "", music: .guess(title))
        b.opener = opener(b.opener.isEmpty ? s.nutmegSays : b.opener)
        b.finale = finale(b.finale, title: title)
        var seen = Set<String>()
        b.events = b.events.compactMap { repairEvent($0, roles: roles) }.filter { seen.insert($0.line.lowercased()).inserted }
        b.events = Array(b.events.prefix(poolMax))
        s.beats = b
        s.nutmegSays = b.opener
        return s
    }

    /// "Pretend that…" first, one or two short sentences, no quotes.
    static func opener(_ line: String) -> String {
        var t = clean(line)
        t = PretendLine.ensure(t, index: 0)
        return PlayCast.endSentence(capWords(t, max: 40))
    }

    static let everyoneWords = ChecklistScenes.everyoneWords

    /// The finale always speaks to everyone ("…Everyone, celebrate!").
    static func finale(_ line: String, title: String) -> String {
        var t = PlayCast.endSentence(capWords(clean(line), max: 30))
        if t.isEmpty {
            let place = title.trimmingCharacters(in: .whitespacesAndNewlines)
            t = place.isEmpty ? "We did it! What a great game!" : "We did it! The \(place) was a big success!"
        }
        let lower = t.lowercased()
        if !everyoneWords.contains(where: { lower.contains($0) }) { t += " Everyone, celebrate!" }
        return t
    }

    static func clean(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"["\x{201C}\x{201D}]"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A line over `max` words keeps its first two sentences (then its first `max` words).
    static func capWords(_ s: String, max: Int) -> String {
        guard s.split(whereSeparator: \.isWhitespace).count > max else { return s }
        let two = PlayCast.sentences(s).prefix(2).joined(separator: " ")
        let w = two.split(whereSeparator: \.isWhitespace)
        return w.count <= max ? two : w.prefix(max).joined(separator: " ")
    }

    /// Words that credit the kids for a calm-again ("you fixed it"): Haylee's rule is that it's just calm again, so it
    /// works whether or not they acted it out.
    static let creditPattern = #"(?i)\b(you|we)\s+(all\s+)?(fixed|did it|saved|stopped|solved|caught|got it|made it|helped)\b|great job|well done|good job|nice work|thanks to you|because of you"#
    public static let calmAgainLines = ["Phew, everything is calm again.", "Phew, things are quiet again.", "Phew, it's all calm now."]

    /// The calm-again line for a tense event: clean, short, never crediting the kids.
    static func calmAgain(_ line: String?, index: Int) -> String {
        let t = PlayCast.endSentence(capWords(clean(line ?? ""), max: 16))
        if t.split(whereSeparator: \.isWhitespace).count < 2 || t.range(of: creditPattern, options: .regularExpression) != nil {
            return calmAgainLines[((index % calmAgainLines.count) + calmAgainLines.count) % calmAgainLines.count]
        }
        return t
    }

    /// The roles a line names, by title (a longer title first, so "VIP Passenger" doesn't also count as "Passenger").
    public static func named(_ line: String, roles: [Role]) -> [RoleID] {
        var rest = line
        var out = Set<RoleID>()
        for r in roles.filter({ !$0.roleName.isEmpty }).sorted(by: { $0.roleName.count > $1.roleName.count }) {
            guard PlayCast.names(rest, r.roleName) else { continue }
            out.insert(r.id)
            rest = rest.replacingOccurrences(of: "(?i)" + PlayCast.wordPattern(r.roleName), with: "~", options: .regularExpression)
        }
        return RoleID.allCases.filter { out.contains($0) }
    }

    /// "Captain", "Captain and Pilot", "Captain, Pilot and Cook".
    public static func names(_ ids: [RoleID], roles: [Role]) -> String {
        let n = ids.compactMap { id in roles.first { $0.id == id }?.roleName }
        switch n.count {
        case 0: return "Everyone"
        case 1: return n[0]
        case 2: return "\(n[0]) and \(n[1])"
        default: return n.dropLast().joined(separator: ", ") + " and " + n.last!
        }
    }

    /// One pool event made usable (nil = dropped). Its roles are the roles its line names (the roles list counts only
    /// when the line names none of them: then the titles go in front); more than 3 named roles drop it. A line naming
    /// no role and listing none is an "everyone" event.
    static func repairEvent(_ e: BeatEvent, roles: [Role]) -> BeatEvent? {
        var line = PlayCast.endSentence(capWords(clean(e.line), max: maxLineWords))
        guard line.split(whereSeparator: \.isWhitespace).count >= 3 else { return nil }
        var ids = named(line, roles: roles)
        if ids.isEmpty {
            let listed = e.roles.filter { r in roles.contains { $0.id == r } }
            if !listed.isEmpty && listed.count <= maxRolesPerEvent {
                line = "\(names(listed, roles: roles)), \(PlayCast.lowerFirst(line))"
                ids = listed
            } else {
                let lower = line.lowercased()
                if !everyoneWords.contains(where: { lower.contains($0) }) { line = "Everyone, \(PlayCast.lowerFirst(line))" }
            }
        }
        guard ids.count <= maxRolesPerEvent else { return nil }
        var out = BeatEvent(mood: e.mood, roles: ids, line: line, appWritten: e.appWritten)
        if e.isTense { out.calmAgain = calmAgain(e.calmAgain, index: line.count) }
        return out
    }

    // MARK: Picking the events for N kids (fair calls, Haylee)

    /// How many times each playing role is called by `events` (an "everyone" event calls every playing role).
    public static func calls(_ events: [BeatEvent], playing: [RoleID]) -> [RoleID: Int] {
        var c = Dictionary(uniqueKeysWithValues: playing.map { ($0, 0) })
        for e in events {
            for r in (e.isEveryone ? playing : e.roles) where c[r] != nil { c[r]! += 1 }
        }
        return c
    }

    /// Haylee's fair-calls rule: every playing role is called at least once, and no role more than one call more than
    /// any other.
    public static func isFair(_ events: [BeatEvent], playing: [RoleID]) -> Bool {
        let c = calls(events, playing: playing).values
        guard let lo = c.min(), let hi = c.max() else { return false }
        return lo >= 1 && hi - lo <= 1
    }

    struct Score: Comparable {
        var unfair: Int, spread: Int, uncalled: Int, appWritten: Int, mismatch: Int, order: Int
        static func < (a: Score, b: Score) -> Bool {
            (a.unfair, a.spread, a.uncalled, a.appWritten, a.mismatch, a.order) < (b.unfair, b.spread, b.uncalled, b.appWritten, b.mismatch, b.order)
        }
    }

    static func score(_ plan: [BeatEvent], playing: [RoleID], cadence: [BeatMood], order: Int = 0) -> Score {
        let c = calls(plan, playing: playing).values
        let lo = c.min() ?? 0, hi = c.max() ?? 0
        let mismatch = zip(plan, cadence).filter { $0.0.mood != $0.1 }.count
        return Score(unfair: isFair(plan, playing: playing) ? 0 : 1, spread: hi - lo, uncalled: c.filter { $0 == 0 }.count,
                     appWritten: plan.filter { $0.appWritten == true }.count, mismatch: mismatch, order: order)
    }

    /// Puts a set of events into the cadence's slots: calm events into calm slots, tense into tense (each in pool
    /// order); a slot with none of its mood left takes the other mood.
    static func ordered(_ set: [BeatEvent], cadence: [BeatMood]) -> [BeatEvent] {
        var calm = set.filter { !$0.isTense }, tense = set.filter(\.isTense)
        var out: [BeatEvent] = []
        for m in cadence.prefix(set.count) {
            if m == .tense, !tense.isEmpty { out.append(tense.removeFirst()) }
            else if m == .calm, !calm.isEmpty { out.append(calm.removeFirst()) }
            else if !tense.isEmpty { out.append(tense.removeFirst()) }
            else if !calm.isEmpty { out.append(calm.removeFirst()) }
        }
        return out
    }

    /// Every k-subset of 0..<n, in order.
    static func combinations(_ n: Int, _ k: Int) -> [[Int]] {
        guard k > 0, k <= n else { return k == 0 ? [[]] : [] }
        var out: [[Int]] = [], cur: [Int] = []
        func go(_ start: Int) {
            if cur.count == k { out.append(cur); return }
            guard start < n else { return }
            for i in start..<n where n - i >= k - cur.count {
                cur.append(i); go(i + 1); cur.removeLast()
            }
        }
        go(0)
        return out
    }

    /// The events N kids hear, in order (Haylee's fair calls, counted here): the best fair set from the pool (fewest
    /// app-written, closest to the calm/tense cadence, earliest in the pool), else the pool's best repaired with
    /// app-written events for the roles called least, else an all app-written rotation (always fair). Deterministic.
    public static func pick(pool: [BeatEvent], roles: [Role], players n: Int) -> [BeatEvent] {
        let playingRoles = RoleCast.playing(roles, kids: n)
        let playing = playingRoles.map(\.id)
        guard !playing.isEmpty else { return [] }
        let want = eventCount(players: n)
        let cad = cadence(want)
        let usable = Array(pool.filter { e in e.roles.allSatisfy { playing.contains($0) } }.prefix(poolMax))
        var best: (plan: [BeatEvent], score: Score)?
        for combo in combinations(usable.count, min(want, usable.count)) {
            let plan = ordered(combo.map { usable[$0] }, cadence: cad)
            let s = score(plan, playing: playing, cadence: cad, order: combo.reduce(0, +))
            if best == nil || s < best!.score { best = (plan, s) }
        }
        var plan = best?.plan ?? []
        // Too few usable events: app-written ones for the roles called least fill the slots.
        while plan.count < want {
            let c = calls(plan, playing: playing)
            let lo = playing.map { c[$0] ?? 0 }.min() ?? 0
            let under = playing.filter { (c[$0] ?? 0) == lo }
            plan.append(appEvent(mood: cad[plan.count], roles: Array(under.prefix(maxRolesPerEvent)), all: roles, index: plan.count))
        }
        // Unfair: swap in app-written events for the roles called least, one at a time (the swap that helps most).
        var rounds = 0
        while !isFair(plan, playing: playing) && rounds < 2 * want {
            rounds += 1
            let c = calls(plan, playing: playing)
            let lo = playing.map { c[$0] ?? 0 }.min() ?? 0
            let under = playing.filter { (c[$0] ?? 0) == lo }
            var cand: (plan: [BeatEvent], score: Score)?
            for j in plan.indices {
                for k in 1...min(maxRolesPerEvent, under.count) {
                    var p = plan
                    p[j] = appEvent(mood: cad[j], roles: Array(under.prefix(k)), all: roles, index: j)
                    let s = score(p, playing: playing, cadence: cad)
                    if cand == nil || s < cand!.score { cand = (p, s) }
                }
            }
            guard let cand, cand.score < score(plan, playing: playing, cadence: cad) else { break }
            plan = cand.plan
        }
        if !isFair(plan, playing: playing) { plan = rotation(playing: playing, roles: roles, count: want) }
        return plan
    }

    /// The all app-written plan: the playing roles round-robin over the events (always fair: every role once or twice).
    static func rotation(playing: [RoleID], roles: [Role], count: Int) -> [BeatEvent] {
        let cad = cadence(count)
        var groups = Array(repeating: [RoleID](), count: count)
        for j in 0..<max(playing.count, count) {
            let r = playing[j % playing.count]
            if !groups[j % count].contains(r) { groups[j % count].append(r) }
        }
        return groups.enumerated().map { k, g in appEvent(mood: cad[k], roles: g, all: roles, index: k) }
    }

    static let calmTemplates = ["take a look around and make sure everything is ready!",
                                "it's your turn to shine! Show everyone your best move!",
                                "give the whole crew a big thumbs-up and keep up the good work!"]
    static let tenseTemplates = ["uh-oh, something is beeping! Quick, go check it out!",
                                 "oh no, it's getting really busy! Quick, lend a hand!"]

    /// An app-written event (the pool couldn't call every role fairly): the role titles first, one short thing to do.
    static func appEvent(mood: BeatMood, roles ids: [RoleID], all roles: [Role], index: Int) -> BeatEvent {
        let who = names(ids, roles: roles)
        let pool = mood == .tense ? tenseTemplates : calmTemplates
        let line = "\(who), " + pool[((index % pool.count) + pool.count) % pool.count]
        return BeatEvent(mood: mood, roles: ids, line: line,
                         calmAgain: mood == .tense ? calmAgainLines[index % calmAgainLines.count] : nil, appWritten: true)
    }

    // MARK: Composing what N players see

    /// The arc N players see for a one-scene kit: the story, the setup checklist (with every page and prop the kids
    /// have covered), the one scene (its picked events in order), the clean-up checklist. A pure function of the kit,
    /// the roles, N and the props.
    public static func compose(_ k: Kit, roles: [Role], players n: Int, props: [Prop]) -> [Scene] {
        guard !roles.isEmpty, let guide = k.scenes.first(where: { $0.beats != nil }), let b = guide.beats else { return k.scenes }
        let p = PlayCast.players(n)
        var out: [Scene] = []
        if let story = k.story?.trimmingCharacters(in: .whitespacesAndNewlines), !story.isEmpty {
            out.append(Scene(id: "story", owner: .all, title: guide.title, picture: .point, nutmegSays: story, steps: [], kind: .story))
        }
        var setup = ChecklistScenes.playerScene(Scene(id: "setup", owner: .all, title: guide.title, picture: .point, nutmegSays: "",
                                                      steps: guide.steps, checklist: true), roles: roles, players: p)
        setup.kind = .setup
        setup.nutmegSays = ""
        var list = [setup]
        ChecklistScenes.cover(&list, items: Bookends.coverItems(items: k.items, props: props), roles: roles, players: p)
        out.append(list[0])
        let plan = pick(pool: b.events, roles: roles, players: p)
        let opener = PlayCast.sceneLine(b.opener, roles: roles, players: p)
        let finale = PlayCast.unname(b.finale, roles: roles, players: p)
        out.append(Scene(id: "play", owner: .all, title: guide.title, picture: .point, nutmegSays: opener, steps: [],
                         beats: SceneBeats(opener: opener, events: plan, finale: finale, music: b.music)))
        out.append(cleanupScene(k.cleanup ?? Bookend(title: "", nutmegSays: ""), kit: k, roles: roles, players: p, props: props))
        return out
    }

    /// The print-mess item (Haylee: exactly one, whatever was printed).
    public static let printMessShort = "Pick up paper scraps, crayons and scissors"
    public static let printMessSay = "pick up the paper scraps, crayons and scissors"
    public static let printMessID = "print-mess"

    /// The clean-up checklist (Haylee): one item for EVERY prop the kids got out (found or swapped; a skipped prop is
    /// a printed cut-out) and exactly one for the print mess, spread fairly over the playing roles: each item goes to
    /// the least busy role (ties: the role it suits, then rank), so no role has more than one item more than another.
    /// A role with none (fewer items than kids) gets a high five. Nutmeg says the job ("Captain, put the chairs back at
    /// the table!"). No scenario.
    public static func cleanupScene(_ b: Bookend, kit: Kit, roles: [Role], players n: Int, props: [Prop]) -> Scene {
        let p = PlayCast.players(n)
        let playing = RoleCast.playing(roles, kids: p)
        let items = Bookends.coverItems(items: kit.items, props: props).filter { $0.prop != nil }
        var jobs: [String: ItemJob] = [:]
        for it in items {
            let j = b.job(it.id).map { Bookends.transformed($0, props: props) }
            jobs[it.id] = Bookends.isValid(j, for: it) ? j : Bookends.fallbackCleanup(it)
        }
        var load: [RoleID: [String]] = [:]
        func count(_ r: RoleID) -> Int { load[r]?.count ?? 0 }
        func assign(_ id: String, prefers: RoleID?) {
            let lo = playing.map { count($0.id) }.min() ?? 0
            let free = playing.filter { count($0.id) == lo }
            guard let r = free.first(where: { $0.id == prefers }) ?? free.first else { return }
            load[r.id, default: []].append(id)
        }
        for it in items { assign(it.id, prefers: jobs[it.id]?.role) }
        assign(printMessID, prefers: nil)
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
                var shown: String, text: String
                if id == printMessID {
                    shown = printMessShort
                    text = "\(role.roleName), \(printMessSay)!"
                } else {
                    guard let job = jobs[id], let item = byID[id] else { continue }
                    shown = Bookends.rowShort([job], items: [item], verb: "Put away", cleanup: true)
                    text = "\(role.roleName), \(PlayCast.lowerFirst(Bookends.trimEnd(job.say)))!"
                }
                if p > 1 { shown = PlayCast.unname(shown, roles: roles, players: p); text = PlayCast.unname(text, roles: roles, players: p) }
                steps.append(Step(picture: id == printMessID ? .point : .prop(byID[id]?.prop?.libraryID ?? byID[id]?.prop?.id ?? "point"),
                                  text: text, role: SceneOwner(role.id), short: shown))
            }
        }
        let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return Scene(id: "cleanup", owner: .all, title: PlayCast.unname(title.isEmpty ? "Clean-Up Time" : title, roles: roles, players: p, title: true),
                     picture: .point, nutmegSays: "", steps: steps, kind: .cleanup, checklist: true)
    }

    /// The cue when the setup checklist opens (app-written: recorded on the first play, replayed from the clip).
    public static func setupCue(_ scene: Scene) -> String {
        let title = Bookends.trimEnd(scene.title.trimmingCharacters(in: .whitespacesAndNewlines))
        return (title.isEmpty ? "Let's get ready!" : "\(title)!") + " " + ChecklistScenes.tapHint
    }

    /// The setup card's title.
    public static func setupTitle(_ scene: Scene) -> String { scene.title }
}

// MARK: - Coverage of the setup (every page and prop in a setup item, at every count)

public enum OneSceneCoverage {
    /// The cover items no setup item names (empty = the rule holds). `scenes` = the composed arc for N.
    public static func missing(_ scenes: [Scene], items: [CoverItem]) -> [String] {
        let setup = scenes.filter { $0.arc == .setup && $0.isChecklist }
        return items.filter { it in !setup.contains { $0.steps.contains { Bookends.mentions($0.short ?? $0.text, it) } } }.map(\.id)
    }
}

// MARK: - The scene's timeline (Claude's numbers; change after a family test)

/// One moment in the scene.
public enum BeatCueKind: Equatable, Hashable, Sendable {
    /// The "Pretend that…" opener (at 0).
    case opener
    /// Event i: the chime, the music ducks, Nutmeg says the line, the event card shows.
    case event(Int)
    /// Event i's line once more, by herself (the same take, no new call).
    case repeatEvent(Int)
    /// Tense event i is over: the soft calm-again card, the calm music returns.
    case calmAgain(Int)
    /// The finale for everyone: celebrate pose, confetti, the win music.
    case finale
    /// The clean-up checklist opens by itself.
    case cleanup
}

public struct BeatCue: Equatable, Sendable {
    public var at: TimeInterval
    public var kind: BeatCueKind
    public init(at: TimeInterval, kind: BeatCueKind) { self.at = at; self.kind = kind }
}

public enum BeatTimeline {
    /// The scene is about 10 minutes (Haylee).
    public static let total: TimeInterval = 600
    /// The first event (the kids settle into the scene first).
    public static let firstEvent: TimeInterval = 90
    /// The finale this long before the end.
    public static let finaleBeforeEnd: TimeInterval = 45
    /// A tense event's calm-again line (30 to 60 s).
    public static let calmAgainAfter: TimeInterval = 45
    /// Nutmeg says each event line once more by herself.
    public static let repeatAfter: TimeInterval = 15
    /// The clean-up checklist opens this long after the finale.
    public static let cleanupAfterFinale: TimeInterval = 20

    public static func finaleAt(total: TimeInterval = total) -> TimeInterval { total - finaleBeforeEnd }

    /// When event i fires: evenly spaced between the first event and the finale (3 events ≈ 155 s apart, 4 ≈ 116 s,
    /// 5 ≈ 93 s, all inside Haylee's 1.5 to 3 minutes).
    public static func eventAt(_ i: Int, count: Int, total: TimeInterval = total) -> TimeInterval {
        let gap = (finaleAt(total: total) - firstEvent) / Double(max(1, count))
        return firstEvent + Double(i) * gap
    }

    /// Every cue, in time order.
    public static func cues(_ events: [BeatEvent], total: TimeInterval = total) -> [BeatCue] {
        var out = [BeatCue(at: 0, kind: .opener)]
        for (i, e) in events.enumerated() {
            let t = eventAt(i, count: events.count, total: total)
            out.append(BeatCue(at: t, kind: .event(i)))
            out.append(BeatCue(at: t + repeatAfter, kind: .repeatEvent(i)))
            if e.isTense { out.append(BeatCue(at: t + calmAgainAfter, kind: .calmAgain(i))) }
        }
        let f = finaleAt(total: total)
        out.append(BeatCue(at: f, kind: .finale))
        out.append(BeatCue(at: f + cleanupAfterFinale, kind: .cleanup))
        return out.sorted { $0.at < $1.at }
    }

    /// The scene bar's dots (0…1 along the bar, the bar ends at the finale's star).
    public static func dots(count: Int, total: TimeInterval = total) -> [Double] {
        (0..<count).map { eventAt($0, count: count, total: total) / finaleAt(total: total) }
    }
}

/// What the scene shows right now.
public enum BeatDisplay: Equatable, Sendable {
    /// Calm play: Nutmeg happy, gently bobbing to the music.
    case playing
    /// Event i's big card (from its line until a little after the repeat).
    case event(Int)
    /// Tense event i's soft calm-again card.
    case calmAgain(Int)
    /// The finale (until the clean-up opens).
    case finale
}

/// Which music segment plays.
public enum BeatMusic: String, Equatable, Sendable { case calm, tense, win, silent }

/// Nutmeg's face for the beat (the app maps it to faces, with the fallbacks for art that isn't in yet).
public enum BeatFace: String, Equatable, Sendable {
    /// Calm play: happy, gently bobbing to the music.
    case happyBob
    /// A calm event: talking, ears perked.
    case talkingPerked
    /// A tense event: `alarmed` (fallback: ooh + perked ears).
    case alarmed
    /// Calm-again: `phew` (fallback: happy).
    case phew
    /// The finale: yay + the celebrate pose.
    case celebrate
}

/// The scene's run: its cues, which have fired, and what it looks and sounds like at a moment. Pure state (the app
/// ticks it with `BeatClock`'s elapsed time).
public struct BeatRun: Equatable, Sendable {
    public let events: [BeatEvent]
    public let total: TimeInterval
    public let cues: [BeatCue]
    public private(set) var fired: Set<Int> = []
    /// How long an event's card stays up (past its repeat).
    public static let eventShows: TimeInterval = 30
    /// How long the calm-again card stays up.
    public static let calmAgainShows: TimeInterval = 12

    public init(events: [BeatEvent], total: TimeInterval = BeatTimeline.total) {
        self.events = events; self.total = total
        cues = BeatTimeline.cues(events, total: total)
    }

    /// A resume (pause or relaunch): every cue up to `elapsed` counts as fired (none is said again).
    public mutating func restore(elapsed: TimeInterval) {
        fired = Set(cues.indices.filter { cues[$0].at <= elapsed })
    }

    /// The cues due by `elapsed` that haven't fired, in order (each fires once). A repeat whose next event is also due
    /// (the app was held up) is dropped, so two lines never pile up; so is an opener once an event is due.
    public mutating func due(at elapsed: TimeInterval) -> [BeatCue] {
        let now = cues.indices.filter { !fired.contains($0) && cues[$0].at <= elapsed }
        fired.formUnion(now)
        let list = now.map { cues[$0] }
        return list.filter { c in
            switch c.kind {
            case .repeatEvent(let i): return !list.contains { if case .event(let j) = $0.kind { return j > i } else { return $0.kind == .finale } }
            case .opener: return !list.contains { if case .event = $0.kind { return true } else { return false } }
            default: return true
            }
        }
    }

    public var finaleAt: TimeInterval { BeatTimeline.finaleAt(total: total) }
    public var cleanupAt: TimeInterval { finaleAt + BeatTimeline.cleanupAfterFinale }
    public func eventAt(_ i: Int) -> TimeInterval { BeatTimeline.eventAt(i, count: events.count, total: total) }

    /// The last event that has fired by `t`.
    func lastEvent(at t: TimeInterval) -> Int? { events.indices.last { eventAt($0) <= t } }

    public func display(at t: TimeInterval) -> BeatDisplay {
        if t >= finaleAt { return .finale }
        guard let i = lastEvent(at: t) else { return .playing }
        let at = eventAt(i)
        if t - at < Self.eventShows { return .event(i) }
        if events[i].isTense {
            let calm = at + BeatTimeline.calmAgainAfter
            if t >= calm && t - calm < Self.calmAgainShows { return .calmAgain(i) }
        }
        return .playing
    }

    /// Tense between a tense event and its calm-again; the win ending from the finale; calm otherwise.
    public func music(at t: TimeInterval) -> BeatMusic {
        if t >= finaleAt { return .win }
        if let i = lastEvent(at: t), events[i].isTense, t < eventAt(i) + BeatTimeline.calmAgainAfter { return .tense }
        return .calm
    }

    public func face(at t: TimeInterval) -> BeatFace {
        switch display(at: t) {
        case .playing: return .happyBob
        case .event(let i): return events[i].isTense ? .alarmed : .talkingPerked
        case .calmAgain: return .phew
        case .finale: return .celebrate
        }
    }

    /// How far along the scene bar (0…1, the star at the finale).
    public func progress(at t: TimeInterval) -> Double { max(0, min(1, t / finaleAt)) }
    /// Events that have fired by `t` (their dots fill in).
    public func firedEvents(at t: TimeInterval) -> Int { events.indices.filter { eventAt($0) <= t }.count }
}

/// The scene's clock: elapsed scene time that only runs while playing (pause stops it), from an injected monotonic
/// `now` (seconds), at `speed` (the demo fast-clock runs a whole scene in about a minute).
public struct BeatClock: Equatable, Sendable {
    /// `-PTFastScene` (demo/testing): 10× → the 10 minute scene in about a minute.
    public static let fastSpeed: Double = 10
    public var speed: Double
    public private(set) var base: TimeInterval
    public private(set) var startedAt: TimeInterval?
    public init(elapsed: TimeInterval = 0, speed: Double = 1) { base = elapsed; self.speed = max(0.01, speed) }
    public var isRunning: Bool { startedAt != nil }
    public func elapsed(now: TimeInterval) -> TimeInterval {
        base + (startedAt.map { max(0, now - $0) * speed } ?? 0)
    }
    public mutating func start(now: TimeInterval) { guard startedAt == nil else { return }; startedAt = now }
    public mutating func pause(now: TimeInterval) {
        guard startedAt != nil else { return }
        base = elapsed(now: now); startedAt = nil
    }
}

// MARK: - Music mix (the app's player follows these numbers)

public enum MusicMix {
    /// The music's normal level (under her voice even before ducking).
    public static let base: Float = 0.5
    /// Ducking under Nutmeg's speech and the chime (about −12 dB).
    public static let duckDB: Float = -12
    public static var duckFactor: Float { pow(10, duckDB / 20) }
    /// Calm ↔ tense crossfade at an event boundary, and the duck's ramp.
    public static let crossfade: TimeInterval = 1.5
    public static let duckRamp: TimeInterval = 0.25
    /// The music level now.
    public static func gain(speaking: Bool, chime: Bool) -> Float { (speaking || chime) ? base * duckFactor : base }
    /// The bundle path of a segment ("Music/space-adventure/calm.m4a"); the silent segment has none.
    public static func file(_ family: MusicFamily, _ segment: BeatMusic) -> String? {
        segment == .silent ? nil : "Music/\(family.rawValue)/\(segment.rawValue).m4a"
    }
    /// The one shared event chime.
    public static let chime = "Music/chime.m4a"
    /// The win ending plays once; calm and tense loop.
    public static func loops(_ segment: BeatMusic) -> Bool { segment == .calm || segment == .tense }
}

// MARK: - The microphone stays off in Play (Haylee, decisions/2026-11-17-saved-game-page-and-play-bar.md)

public enum PlayMic {
    /// The mic is never on during Play (the setup checklist, the scene, the clean-up) or The End: no mic button shows
    /// and a press is refused. Everything else keeps push-to-talk.
    public static func allowed(_ phase: Phase) -> Bool {
        switch phase {
        case .scene, .end: return false
        default: return true
        }
    }
}

// MARK: - The guide's answer (decoded into one guide scene)

/// The one-scene guide answer: decoded into ONE guide scene (setup items as checklist steps + `beats`), the story and
/// the clean-up title.
public struct OneSceneGuide: Decodable, Sendable, SafetyText {
    public var scene: Scene
    public var story: String?
    public var cleanupTitle: String
    public init(scene: Scene, story: String?, cleanupTitle: String) { self.scene = scene; self.story = story; self.cleanupTitle = cleanupTitle }

    struct Key: CodingKey {
        var stringValue: String; var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func str(_ k: String) -> String { ((try? c.decodeIfPresent(String.self, forKey: Key(stringValue: k))) ?? nil) ?? "" }
        var steps: [Step] = []
        if let setup = try? c.nestedContainer(keyedBy: Key.self, forKey: Key(stringValue: "setup")) {
            for r in RoleID.allCases {
                let list = ((try? setup.decodeIfPresent([String].self, forKey: Key(stringValue: r.rawValue))) ?? nil) ?? []
                steps += list.map { Step(picture: .point, text: $0, role: SceneOwner(r), short: $0) }
            }
        }
        let events = ((try? c.decodeIfPresent([BeatEvent].self, forKey: Key(stringValue: "events"))) ?? nil) ?? []
        let musicRaw = str("music")
        let beats = SceneBeats(opener: str("opener"), events: events, finale: str("finale"),
                               music: MusicFamily.parse(musicRaw) ?? .guess(str("setupTitle") + " " + str("story")))
        scene = Scene(id: "s1", owner: .all, title: str("setupTitle"), picture: .point, nutmegSays: beats.opener, steps: steps,
                      checklist: true, beats: beats)
        let s = str("story").replacingOccurrences(of: "\"", with: "")
        story = s.isEmpty ? nil : s
        cleanupTitle = str("cleanupTitle")
    }

    public var safetyTexts: [String] { scene.spokenTexts + [story ?? "", cleanupTitle] }

    /// The kit for these pages (the story and the clean-up title; the props' clean-up jobs come with their weaves).
    public func kit(items: [KitItem]) -> Kit {
        Kit(nutmegSays: "", items: items, scenes: [scene], story: story ?? "", cleanup: Bookend(title: cleanupTitle, nutmegSays: ""))
    }
}
