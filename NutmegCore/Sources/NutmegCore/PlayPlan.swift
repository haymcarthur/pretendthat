import Foundation

// 2026-11-21 (Haylee, decisions/2026-11-21-one-game-plan.md; build: decisions/2026-11-21-round-game-plan-build.md):
// ONE GAME PLAN. "Everything in a game should flow and feel intentional, as if it belongs together." The pieces used to
// be written separately (the kit, then the guide, then a weave call per prop, then repairs), so nothing knew the whole
// game. Now one AI step writes the world: the story, 2 to 4 AREAS (each with an owner role and a short "build it" job)
// and every OBJECT (each printed page, later each found prop) with its life cycle: the area it lives in, its owner, a
// setup placement item, its USE in play (an event that names it, or its own calm-stretch idea) and a put-away item.
// The events, calm-again lines, calm-stretch ideas and the finale all come from the same plan and point at its areas
// and objects. Setup cards are built by area, clean-up follows the same owners.
//
// Where it sits in the flow (Claude's call, see the build decision):
// 1. The kit pages are chosen first, as before (the art is the slow part and starts right away), but the kit prompt now
//    carries every type's PLAY JOB (`PrintPlayJobs`), so a page is only picked when it has a use in the scene.
// 2. The PLAN call replaces the guide call, in the same spot (while the kids hunt): it knows the pages and gives each a
//    life cycle; the app repairs any page left without one (`PrintPlayJobs`), so no printout ships unused.
// 3. When the hunt ends (skips and swaps known), ONE props call places every found prop INTO the plan (area, owner,
//    setup, idea, put-away, and optionally one event rewritten to use it). It replaces the per-prop weave calls.
//    No answer = the app places them (stand-ins, areas), no second call.
// 4. Composing for N kids (no AI): areas merge for fewer kids, objects get exactly one fair owner, the events are picked
//    (fair calls), and calm-stretch ideas are scheduled in the calm gaps for every object no picked event uses.
//
// The type is `PlayPlan` (the app already has a `GamePlan`: the game's title and roles).

// MARK: - The plan's parts (stored in the guide scene's beats; saved games schema 8)

/// One area of the play space ("the cockpit"), owned by one role, with its short setup job ("Build the cockpit").
public struct PlanArea: Codable, Equatable, Sendable {
    /// "A1"…"A4".
    public var id: String
    /// "the cockpit".
    public var name: String
    public var owner: RoleID
    /// "Build the cockpit" (2 to 6 words, no role title).
    public var job: String
    public init(id: String, name: String, owner: RoleID, job: String) {
        self.id = id; self.name = name; self.owner = owner; self.job = job
    }
    /// Stored as "place" (a saved game never has a "name" key: the privacy test guards it).
    private enum CodingKeys: String, CodingKey { case id, name = "place", owner, job }
}

/// One object's life cycle: a printed page ("page:log") or a found prop ("prop:box").
public struct PlanObject: Codable, Equatable, Sendable {
    /// The cover item id ("page:<recipe>" / "prop:<prop id>").
    public var id: String
    /// The area id it lives in.
    public var area: String
    /// Its owner in the full game (R1…R6); the app moves it for fewer kids (fair, exactly once).
    public var owner: RoleID
    /// A prop's pretend name ("the steering wheel"), always one of its stand-ins (the hunt settled it). Nil for pages.
    public var pretend: String?
    /// The setup item that places it in its area ("Put the steering wheel in the cockpit"), no role title.
    public var setup: String
    /// Its calm-stretch idea, no role title ("While we fly, write in the captain's log what you saw!"). Said when no
    /// picked event uses it.
    public var idea: String
    /// The clean-up item ("Put the plate back on the shelf"), no role title.
    public var putAway: String
    /// Written (or repaired) by the app, not the AI.
    public var appWritten: Bool?
    public init(id: String, area: String, owner: RoleID, pretend: String? = nil, setup: String, idea: String, putAway: String,
                appWritten: Bool? = nil) {
        self.id = id; self.area = area; self.owner = owner; self.pretend = pretend; self.setup = setup; self.idea = idea
        self.putAway = putAway; self.appWritten = appWritten
    }
    public var isProp: Bool { id.hasPrefix("prop:") }
    public var texts: [String] { [setup, idea, putAway] + (pretend.map { [$0] } ?? []) }
}

/// The whole game's plan: its areas and every object's life cycle.
public struct PlayPlan: Codable, Equatable, Sendable {
    public var areas: [PlanArea]
    public var objects: [PlanObject]
    /// The props were placed (by the props call, or by the app when it had no answer).
    public var propsPlaced: Bool?
    public init(areas: [PlanArea], objects: [PlanObject], propsPlaced: Bool? = nil) {
        self.areas = areas; self.objects = objects; self.propsPlaced = propsPlaced
    }
    public func area(_ id: String?) -> PlanArea? { id.flatMap { i in areas.first { $0.id == i } } }
    public func object(_ id: String) -> PlanObject? { objects.first { $0.id == id } }
    /// Every text the plan may show or say.
    public var texts: [String] { areas.flatMap { [$0.name, $0.job] } + objects.flatMap(\.texts) }
}

/// A calm-stretch idea in the composed scene: short, no chime, no music duck; it uses an object ("While we fly,
/// Captain, write in your log what you saw!"). Its card stays about 20 s or until the next event.
public struct BeatIdea: Codable, Equatable, Sendable {
    public var line: String
    /// The role it speaks to (the object's owner for this count).
    public var roles: [RoleID]
    /// The object(s) it uses (cover item ids).
    public var objects: [String]
    public var area: String?
    /// The card's thumbnail (the prop's art or the kit page).
    public var picture: Picture
    /// Which calm gap: before event `gap` (gap == events.count: after the last one).
    public var gap: Int
    public var appWritten: Bool?
    public init(line: String, roles: [RoleID], objects: [String], area: String?, picture: Picture, gap: Int, appWritten: Bool? = nil) {
        self.line = line; self.roles = roles; self.objects = objects; self.area = area; self.picture = picture; self.gap = gap
        self.appWritten = appWritten
    }
}

// MARK: - The plan call's answer

/// The plan call's answer, decoded into ONE guide scene (its setup items = the objects' setup, by owner; its beats =
/// the opener, the event pool, the finale, the music and the plan), the story and the clean-up title.
public struct GamePlanGuide: Decodable, Sendable, SafetyText {
    public var scene: Scene
    public var story: String?
    public var cleanupTitle: String
    public init(scene: Scene, story: String?, cleanupTitle: String) { self.scene = scene; self.story = story; self.cleanupTitle = cleanupTitle }

    struct Key: CodingKey {
        var stringValue: String; var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
    struct AreaBody: Decodable { var name: String?; var owner: String?; var job: String? }
    struct ObjectBody: Decodable { var item: String?; var area: String?; var owner: String?; var setup: String?; var idea: String?; var putAway: String? }
    struct EventBody: Decodable {
        var mood: BeatMood?; var roles: [String]?; var line: String?; var calmAgain: String?
        var objects: [String]?; var area: String?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        func str(_ k: String) -> String { ((try? c.decodeIfPresent(String.self, forKey: Key(stringValue: k))) ?? nil) ?? "" }
        let rawAreas = ((try? c.decodeIfPresent([AreaBody].self, forKey: Key(stringValue: "areas"))) ?? nil) ?? []
        var areas: [PlanArea] = []
        for a in rawAreas.prefix(PlayPlans.maxAreas) {
            let owner = RoleID(rawValue: (a.owner ?? "").uppercased()) ?? RoleID.allCases[min(areas.count, RoleCast.count - 1)]
            areas.append(PlanArea(id: "A\(areas.count + 1)", name: a.name ?? "", owner: owner, job: a.job ?? ""))
        }
        let rawObjects = ((try? c.decodeIfPresent([ObjectBody].self, forKey: Key(stringValue: "objects"))) ?? nil) ?? []
        let objects: [PlanObject] = rawObjects.compactMap { o in
            guard let item = o.item, !item.isEmpty else { return nil }
            return PlanObject(id: item, area: (o.area ?? "").uppercased(), owner: RoleID(rawValue: (o.owner ?? "").uppercased()) ?? .R1,
                              setup: o.setup ?? "", idea: o.idea ?? "", putAway: o.putAway ?? "")
        }
        let rawEvents = ((try? c.decodeIfPresent([EventBody].self, forKey: Key(stringValue: "events"))) ?? nil) ?? []
        let events: [BeatEvent] = rawEvents.map { e in
            var seen = Set<RoleID>()
            let roles = (e.roles ?? []).compactMap { RoleID(rawValue: $0.uppercased()) }.filter { seen.insert($0).inserted }
            let again = (e.calmAgain ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            var ev = BeatEvent(mood: e.mood ?? .calm, roles: roles, line: e.line ?? "", calmAgain: again.isEmpty ? nil : again)
            ev.objects = e.objects?.filter { !$0.isEmpty }
            let area = (e.area ?? "").uppercased()
            ev.area = area.isEmpty ? nil : area
            return ev
        }
        let steps = objects.map { Step(picture: .point, text: $0.setup, role: SceneOwner($0.owner), short: $0.setup) }
        var beats = SceneBeats(opener: str("opener"), events: events, finale: str("finale"),
                               music: MusicFamily.parse(str("music")) ?? .guess(str("setupTitle") + " " + str("story")))
        beats.plan = PlayPlan(areas: areas, objects: objects)
        scene = Scene(id: "s1", owner: .all, title: str("setupTitle"), picture: .point, nutmegSays: beats.opener, steps: steps,
                      checklist: true, beats: beats)
        let s = str("story").replacingOccurrences(of: "\"", with: "")
        story = s.isEmpty ? nil : s
        cleanupTitle = str("cleanupTitle")
    }

    public var safetyTexts: [String] { scene.spokenTexts + [story ?? "", cleanupTitle] + (scene.beats?.plan?.texts ?? []) }

    /// The kit for these pages (the story and the clean-up title; the props are placed when the hunt ends).
    public func kit(items: [KitItem]) -> Kit {
        Kit(nutmegSays: "", items: items, scenes: [scene], story: story ?? "", cleanup: Bookend(title: cleanupTitle, nutmegSays: ""))
    }
}

/// The props call's answer: each found prop placed into the plan.
public struct PlanPropsAnswer: Codable, Equatable, Sendable, SafetyText {
    public struct Placed: Codable, Equatable, Sendable {
        public var item: String
        public var area: String?
        public var owner: String?
        public var setup: String?
        public var idea: String?
        public var putAway: String?
        /// The pool event (index) rewritten to use this prop, or -1 / nil for none.
        public var event: Int?
        public var eventLine: String?
        public init(item: String, area: String? = nil, owner: String? = nil, setup: String? = nil, idea: String? = nil,
                    putAway: String? = nil, event: Int? = nil, eventLine: String? = nil) {
            self.item = item; self.area = area; self.owner = owner; self.setup = setup; self.idea = idea; self.putAway = putAway
            self.event = event; self.eventLine = eventLine
        }
    }
    public var props: [Placed]
    public init(props: [Placed]) { self.props = props }
    public var safetyTexts: [String] { props.flatMap { [$0.setup ?? "", $0.idea ?? "", $0.putAway ?? "", $0.eventLine ?? ""] } }
}

extension Scene {
    /// 2026-11-21: this guide scene carries a game plan (a schema 8 game).
    public var plan: PlayPlan? { beats?.plan }
}

extension Kit {
    /// 2026-11-21: a game-plan kit (areas, object life cycles, ideas). Saved games from schema 8 on.
    public var hasGamePlan: Bool { scenes.contains { $0.beats?.plan != nil } }
}

// MARK: - The plan: prompt, repair, compose, trace

public enum PlayPlans {
    public static let minAreas = 2, maxAreas = 4
    /// The longest setup / put-away item (words; a placement needs a few more than a plain checklist item).
    public static let maxItemWords = 10
    /// The longest idea (words).
    public static let maxIdeaWords = 22
    /// The area ids the schema allows.
    static let areaIDs = (1...maxAreas).map { "A\($0)" }

    // MARK: Schema and prompt

    /// The plan call's schema: the story, the areas, every printed page's life cycle, the opener, the event pool (each
    /// event names the objects and the area it uses), the finale, the music and the titles.
    public static func schema(items: [KitItem]) -> [String: Any] {
        let pageIDs = pageObjectIDs(items)
        let ids = pageIDs.isEmpty ? ["none"] : pageIDs
        let area: [String: Any] = Schemas.obj([
            "name": ["type": "string", "description": "The area's name with \"the\", 2 to 4 words, a place in the pretend world built from props and printed pages (e.g. the cockpit, the snack galley)."],
            "owner": ["type": "string", "enum": Array(Schemas.roleIDs.prefix(maxAreas)), "description": "The role that builds it (each area a different role, R1 first)."],
            "job": ["type": "string", "description": "The area's setup job: 2 to 5 words, an imperative, no role title (e.g. Build the cockpit)."],
        ])
        let object: [String: Any] = Schemas.obj([
            "item": ["type": "string", "enum": ids, "description": "The printed page (its id)."],
            "area": ["type": "string", "enum": areaIDs, "description": "The area it lives in (A1 = the first area)."],
            "owner": ["type": "string", "enum": Schemas.roleIDs, "description": "The ONE role that sets it up and puts it away (the area's owner or another role that works there)."],
            "setup": ["type": "string", "description": "The setup item that PLACES it in its area: 3 to 8 words, starts with a verb, names it, no role title, no end punctuation (e.g. Put the captain's log by the steering wheel)."],
            "idea": ["type": "string", "description": "A calm-stretch idea that USES it in play, for its owner, 8 to 18 words, NO role title (the app adds it), its play job (e.g. While we fly, write in the captain's log what you saw!)."],
            "putAway": ["type": "string", "description": "The clean-up item: 3 to 8 words, starts with a verb, names it, no role title (e.g. Close the captain's log)."],
        ])
        let event: [String: Any] = Schemas.obj([
            "mood": ["type": "string", "enum": BeatMood.allCases.map(\.rawValue), "description": "calm = a fun job; tense = a small, silly problem (never scary)."],
            "roles": ["type": "array", "items": ["type": "string", "enum": Schemas.roleIDs],
                      "description": "The 1 to 3 roles this event calls (every role it names)."],
            "line": ["type": "string", "description": "ONE short line, 10 to 25 words: a SITUATION in one of the areas plus a general direction the named role or roles act out for a minute or two, using a printed page when it fits (e.g. A space cloud is in the way! Navigator, use the map to help the Captain find a new path.)."],
            "calmAgain": ["type": "string", "description": "tense events: the line said about 45 seconds later that says things are calm again WITHOUT saying the kids fixed it. calm events: an empty string."],
            "objects": ["type": "array", "items": ["type": "string", "enum": ids], "description": "The printed pages the line names and uses (may be empty)."],
            "area": ["type": "string", "enum": areaIDs + [""], "description": "The area where it happens (or empty)."],
        ])
        var props: [String: Any] = [:]
        props["story"] = ["type": "string", "description": "The story Nutmeg tells right after printing: 3 or 4 short sentences, about 40 to 55 words (15 seconds): where we are, who the kids are (the R1 role and the crew; name no other role), and what is about to happen. Kid words, exciting, no quotes."]
        props["setupTitle"] = ["type": "string", "description": "2 to 5 words: what the kids get ready for (e.g. Get the spaceship ready)."]
        props["areas"] = ["type": "array", "items": area, "description": "\(minAreas) to \(maxAreas) areas of the play space."]
        props["objects"] = ["type": "array", "items": object, "description": "EVERY printed page in the list (except the badges), each exactly once."]
        props["opener"] = ["type": "string", "description": "The scene's opener: ONE short line, 12 to 25 words, that starts with \"Pretend that\" and starts the adventure (e.g. Pretend that the rocket is blasting off to the Moon! Everyone, take your places!)."]
        props["events"] = ["type": "array", "items": event,
                           "description": "\(OneScene.poolMin) to \(OneScene.poolMax) events, about half calm and half tense, calling all 6 roles (see the rules)."]
        props["finale"] = ["type": "string", "description": "The big ending for everyone, ONE short line (e.g. We made it to the Moon! Everyone, celebrate!)."]
        props["music"] = ["type": "string", "enum": MusicFamily.allCases.map(\.rawValue), "description": "The background music that fits the game best."]
        props["cleanupTitle"] = ["type": "string", "description": "2 to 4 words: the title of the final clean-up checklist, the story's ending (e.g. Closing Time)."]
        return Schemas.obj(props)
    }

    /// The plan prompt (written during the hunt: the pages are known, the household props come later).
    public static func prompt(ctx: AdventureContext, items: [KitItem]) -> String {
        """
        Phase: the GAME PLAN. The printable pages are already made; each one's id, name and PLAY JOB:
        \(PrintPlayJobs.promptList(items))
        \(rules)
        \(Prompts.contextJSON(ctx))
        """
    }

    static var rules: String {
        "Write ONE GAME PLAN where everything belongs together: the STORY, the AREAS of the play space, every printed "
        + "page's LIFE CYCLE, ONE PLAY SCENE and the clean-up title, all in this one answer. Kids ages 4 to 8 play "
        + "together, the iPad on the side: the app plays music for about 10 minutes and Nutmeg, the director, calls out "
        + "events now and then. The game is written for up to 6 kids: the roles R1 to R6 are ranked, and with N kids "
        + "only R1 to RN play. "
        + "AREAS: \(minAreas) to \(maxAreas) areas the kids build from props and printed pages (a spaceship = the "
        + "cockpit, the engine room, the passenger seats; a restaurant = the kitchen, the dining room, the host stand; a "
        + "treasure hunt = the starting point, the hiding spots, the supply camp). Each area has a name, ONE owner (R1 "
        + "owns A1, then R2, R3, R4) and a short job (Build the cockpit). "
        + "OBJECTS: EVERY printed page except the badges, each exactly once: the area it lives in, its ONE owner (no two "
        + "pages need the same owner unless there are more pages than roles), a setup item that PLACES it in its area "
        + "(Put the captain's log by the steering wheel), an idea that USES it in play following its play job (While we "
        + "fly, write in the captain's log what you saw!) with no role title, and a put-away item. A page with no real "
        + "use is a mistake: every page must be used. No badges anywhere: Nutmeg tells everyone to put on their badge. "
        + "THE SCENE: opener = ONE short line starting with \"Pretend that\". events = \(OneScene.poolMin) to "
        + "\(OneScene.poolMax) events. Each event: mood calm (a fun job) or tense (a small, silly problem, never scary or "
        + "sad), the roles it calls (1 to 3), ONE short line, 10 to 25 words, that calls each of those roles by its "
        + "title: a SCENARIO in one of the AREAS, meaning a situation plus a general direction they act out together for "
        + "a minute or two, USING a printed page by its name when it fits (list it in objects, and the area in area). "
        + "Spread the events over the areas and the pages. Never a single gesture or face. " + OneScene.eventExamples
        + "An event may name ONLY the roles in its roles list. Every tense event has calmAgain: what Nutmeg says later "
        + "when it's over, WITHOUT saying the kids fixed it (e.g. \"Phew, the rush has died down.\"); calm events have an "
        + "empty calmAgain. THE POOL MUST WORK FOR EVERY GROUP SIZE: at least 3 events (one of them tense) call ONLY R1; "
        + "at least 2 call R2 (alone or with R1); then every role R3, R4, R5 and R6 is called by at least 2 events, which "
        + "may also call roles ranked above it (a lower R number); include a few events that call 2 or 3 roles together. "
        + "opener = \"Pretend that…\" plus WHERE we are and what's happening (e.g. Pretend that our rocket is blasting off "
        + "to the Moon! Everyone, take your places!), never a generic get ready. finale = the big ending for everyone "
        + "(\"We made it to the Moon! Everyone, celebrate!\"). "
        + "EVERYTHING IN THE PLAY WORLD IS PRETEND, made from the props and the printed pages: an area is a pretend place "
        + "(the pretend kitchen, never the real one); never send the kids to a real stove, oven, microwave, toaster, sink, "
        + "bath, water tap, outlet, cord, fireplace, candle, window, stairs, the car, outside, medicine, cleaning products "
        + "or knives, and never ask them to climb. "
        + "Use NO household props yet (the kids are still hunting; the app adds each one to the plan later), no scripted "
        + "words to repeat, no quotes. Only the opener, finale and story name no role except R1. music = one of: "
        + "\(OneScene.musicList). story: what Nutmeg tells right after printing, 3 or 4 short sentences (about 15 "
        + "seconds). setupTitle: 2 to 5 words. cleanupTitle: 2 to 4 words for the final clean-up checklist (e.g. Closing Time)."
    }

    /// The page ids a plan gives a life cycle (every printed page except the badges).
    static func pageObjectIDs(_ items: [KitItem]) -> [String] {
        KitRecipe.allCases.filter { r in r != .badges && items.contains { $0.recipe == r } }.map(Bookends.pageID)
    }

    // MARK: The props call (when the hunt ends; replaces the per-prop weave calls)

    public static func propsSchema(propIDs: [String], events: Int) -> [String: Any] {
        let ids = propIDs.isEmpty ? ["none"] : propIDs
        let placed: [String: Any] = Schemas.obj([
            "item": ["type": "string", "enum": ids],
            "area": ["type": "string", "enum": areaIDs],
            "owner": ["type": "string", "enum": Schemas.roleIDs],
            "setup": ["type": "string", "description": "3 to 8 words, starts with a verb, places it in its area by its PRETEND name, no role title (e.g. Set the steering wheel in the cockpit)."],
            "idea": ["type": "string", "description": "8 to 18 words, a calm-stretch idea that uses it by its pretend name, NO role title (e.g. While we fly, steer us around the clouds with the steering wheel!)."],
            "putAway": ["type": "string", "description": "3 to 8 words, starts with a verb, puts the HOUSEHOLD item back where it lives (e.g. Put the plate back on the shelf)."],
            "event": ["type": "integer", "description": "The number of ONE event (0 to \(max(0, events - 1))) to rewrite so it uses this prop, or -1 for none."],
            "eventLine": ["type": "string", "description": "That event's line rewritten to use the prop by its pretend name: the same situation, the same roles named, 10 to 25 words (empty when event is -1)."],
        ])
        return Schemas.obj(["props": ["type": "array", "items": placed, "description": "Every prop in the list, each exactly once."]])
    }

    /// The props prompt: the plan as it is (areas, objects, numbered events) and the props to place.
    public static func propsPrompt(scene: Scene, props: [Prop], roles: [Role], players: Int) -> String {
        let plan = scene.beats?.plan ?? PlayPlan(areas: [], objects: [])
        let roleList = roles.map { "\($0.id.rawValue) \($0.roleName)" }.joined(separator: ", ")
        let areas = plan.areas.map { "- \($0.id) \($0.name) (owner \($0.owner.rawValue)): \($0.job)" }.joined(separator: "\n")
        let objects = plan.objects.map { "- \($0.id) in \($0.area), owner \($0.owner.rawValue): \($0.setup)" }.joined(separator: "\n")
        let events = (scene.beats?.events ?? []).enumerated().map { k, e in
            "\(k) [\(e.mood.rawValue); \(e.roles.map(\.rawValue).joined(separator: "+"))]: \(e.line)"
        }.joined(separator: "\n")
        let list = props.map { p in
            (p.rule == .one ? "- prop:\(p.id): a \(p.householdItem.lowercased()) that becomes \(p.becomes)"
                : "- prop:\(p.id): several \(p.itemWords) that become \(p.becomes) (always plural, never a number)")
                + (p.forRole.role.map { " (for \($0.rawValue))" } ?? "")
        }.joined(separator: "\n")
        return """
        Phase: add the household props to the GAME PLAN. Roles: \(roleList). The plan's areas:
        \(areas)
        The objects already placed:
        \(objects)
        The scene's events (number [mood; roles]: line):
        \(events)
        The props the kids found:
        \(list)
        For EACH prop: the area where it belongs best, its ONE owner (spread the props over the roles: first a role with \
        no object yet, then the prop's own role), a setup item that places it in its area, a calm-stretch idea that \
        uses it, and a put-away item for the household item. Name the prop ONLY by what it becomes (the pretend name, \
        never the household item, never the word pretend) in setup, idea and eventLine. When an event fits it well, \
        rewrite that ONE event so the same roles use the prop in the same situation (each event for at most one prop; \
        never a single gesture). Everything is pretend: never send the kids to anything real and unsafe (stove, oven, \
        sink, outlet, stairs, climbing, outside). No quotes. Return the props list.
        """
    }

    /// The props placed into the guide scene's plan: the answer's valid parts, the app's lines for the rest (no call).
    /// Every found prop (not skipped) gets exactly one object; objects of props the kids no longer have are dropped.
    /// An event rewrite is kept only when it names the same roles, uses the prop and is a safe scenario.
    public static func placeProps(_ answer: PlanPropsAnswer?, into scene: Scene, props: [Prop], items: [KitItem], roles: [Role]) -> Scene {
        guard var b = scene.beats, var plan = b.plan else { return scene }
        let cover = Bookends.coverItems(items: items, props: props)
        let propItems = cover.filter { $0.prop != nil }
        let propIDs = Set(propItems.map(\.id))
        plan.objects.removeAll { $0.isProp && !propIDs.contains($0.id) }
        var rewritten = Set<Int>()
        for it in propItems {
            guard let prop = it.prop else { continue }
            let ans = answer?.props.first { $0.item == it.id || "prop:" + $0.item == it.id }
            let pretend = "the " + KitDraft.cutoutLabel(becomes: prop.becomes).lowercased()
            let fallback = appObject(it, plan: plan, roles: roles)
            var o = PlanObject(id: it.id, area: fallback.area, owner: fallback.owner, pretend: pretend,
                               setup: fallback.setup, idea: fallback.idea, putAway: fallback.putAway)
            var app = true
            if let ans {
                if let a = ans.area?.uppercased(), plan.area(a) != nil { o.area = a }
                if let r = ans.owner.flatMap({ RoleID(rawValue: $0.uppercased()) }) { o.owner = r }
                if let s = ans.setup, let t = validItem(s, for: it, roles: roles, props: props) { o.setup = t; app = false }
                if let s = ans.idea, let t = validIdea(s, for: it, roles: roles) { o.idea = t; app = false }
                if let s = ans.putAway, let t = validPutAway(s, roles: roles) { o.putAway = t }
                if let k = ans.event, k >= 0, b.events.indices.contains(k), !rewritten.contains(k), let line = ans.eventLine,
                   let fixed = validEventLine(line, replacing: b.events[k], uses: it, roles: roles) {
                    b.events[k].line = fixed
                    b.events[k].objects = Array(Set((b.events[k].objects ?? []) + [it.id])).sorted()
                    b.events[k].area = b.events[k].area ?? o.area
                    b.events[k].appWritten = nil
                    rewritten.insert(k)
                }
            }
            o.appWritten = app ? true : nil
            if let k = plan.objects.firstIndex(where: { $0.id == it.id }) { plan.objects[k] = o } else { plan.objects.append(o) }
        }
        plan.propsPlaced = true
        b.plan = plan
        var s = scene
        s.beats = b
        return s
    }

    // MARK: Repair (no AI call; runs on every guide that lands and on every load)

    /// The guide scene's plan made whole and consistent (idempotent): 2 to 4 areas with real names and jobs owned by
    /// different roles (an empty area dropped), every page (and every placed prop) exactly one object with a real area,
    /// an owner, a setup item that names it, an idea and a put-away item (the app writes what's missing from
    /// `PrintPlayJobs` / the stand-ins), the events' object and area references real and true to their lines, and the
    /// setup steps rebuilt from the objects. Every text is speakable and safe.
    public static func repairGuide(_ scene: Scene, roles: [Role], props: [Prop], items: [KitItem], title: String) -> Scene {
        guard var b = scene.beats, let raw = b.plan else { return scene }
        // Props are only checked once they've been placed (the plan written during the hunt has none yet).
        let cover = Bookends.coverItems(items: items, props: raw.propsPlaced == true ? props : [])
        let plan = complete(raw, cover: cover, roles: roles, title: title)
        b.plan = plan
        b.events = b.events.map { tie($0, plan: plan, cover: cover, roles: roles) }
        var s = scene
        s.beats = b
        s.steps = plan.objects.map { Step(picture: picture($0, cover: cover), text: $0.setup, role: SceneOwner($0.owner), short: $0.setup) }
        return s
    }

    /// The plan with every cover object (badges aside) and real areas (pure, idempotent).
    public static func complete(_ raw: PlayPlan, cover: [CoverItem], roles: [Role], title: String = "") -> PlayPlan {
        let objs = ObjectOwners.objects(cover)
        var plan = raw
        // Areas: real names and jobs, distinct owners, at most 4.
        var areas: [PlanArea] = []
        var owners = Set<RoleID>()
        for a in raw.areas.prefix(maxAreas) {
            var x = a
            x.name = areaName(a.name)
            guard !x.name.isEmpty else { continue }
            if owners.contains(x.owner) { x.owner = RoleID.allCases.first { !owners.contains($0) } ?? x.owner }
            owners.insert(x.owner)
            x.job = areaJob(a.job, name: x.name)
            if x.id.isEmpty || areas.contains(where: { $0.id == x.id }) { x.id = "A\(areas.count + 1)" }
            areas.append(x)
        }
        if areas.isEmpty { areas = [PlanArea(id: "A1", name: "the play space", owner: .R1, job: "Set up the play space")] }
        plan.areas = areas
        // Objects: one per cover object, in the cover order (pages, then props).
        var out: [PlanObject] = []
        for it in objs {
            let given = raw.objects.first { $0.id == it.id }
            var o = given ?? appObject(it, plan: plan, roles: roles)
            if plan.area(o.area) == nil { o.area = appArea(it, owner: o.owner, plan: plan) }
            if let p = it.prop { o.pretend = "the " + KitDraft.cutoutLabel(becomes: p.becomes).lowercased() } else { o.pretend = nil }
            let props = it.prop.map { [$0] } ?? []
            let app = appObject(it, plan: plan, roles: roles, area: o.area)
            var repaired = false
            if let t = validItem(o.setup, for: it, roles: roles, props: props) { o.setup = t } else { o.setup = app.setup; repaired = true }
            if let t = validIdea(o.idea, for: it, roles: roles) { o.idea = t } else { o.idea = app.idea; repaired = true }
            if let t = validPutAway(o.putAway, roles: roles) { o.putAway = t } else { o.putAway = app.putAway; repaired = true }
            if repaired || given == nil { o.appWritten = true }
            out.append(o)
        }
        plan.objects = out
        // An area nothing lives in can't be built: dropped (the events that pointed at it lose the pointer), unless it's
        // the only one.
        let used = Set(out.map(\.area))
        let kept = plan.areas.filter { used.contains($0.id) }
        if !kept.isEmpty { plan.areas = kept }
        return plan
    }

    /// An event's references made real and true: the objects its line names (of the ones it listed, when it listed any),
    /// and its area (the listed one, else the area of its first object, else the area of the first role it calls).
    static func tie(_ e: BeatEvent, plan: PlayPlan, cover: [CoverItem], roles: [Role]) -> BeatEvent {
        var e = e
        let objs = ObjectOwners.objects(cover).filter { plan.object($0.id) != nil }
        let line = e.line
        let named = objs.filter { (it: CoverItem) -> Bool in
            if Bookends.mentions(line, it) { return true }
            guard let pretend = plan.object(it.id)?.pretend else { return false }
            return Bookends.mentions(line, name: KitDraft.cutoutLabel(becomes: pretend))
        }
        let listed = Set(e.objects ?? [])
        let refs = (listed.isEmpty || e.appWritten == true ? named : named.filter { listed.contains($0.id) }).map(\.id)
        e.objects = refs.isEmpty ? nil : refs
        if plan.area(e.area) == nil {
            e.area = refs.first.flatMap { plan.object($0)?.area }
                ?? e.roles.first.flatMap { r in plan.areas.first { $0.owner == r }?.id }
        }
        return e
    }

    // MARK: The app's lines (no AI call)

    /// The app's life cycle for an object with none (or a broken one): the area of its owner (a page's suited role, a
    /// prop's own role), else the area with the fewest objects; `PrintPlayJobs` / the stand-in for the words.
    static func appObject(_ it: CoverItem, plan: PlayPlan, roles: [Role], area given: String? = nil) -> PlanObject {
        let owner = it.prop?.forRole.role ?? plan.areas.first?.owner ?? .R1
        let area = given ?? appArea(it, owner: owner, plan: plan)
        let place = plan.area(area)?.name ?? ""
        let label = displayLabel(it)
        var setup: String, idea: String
        if let r = it.recipe {
            let job = PrintPlayJobs.job(r)
            setup = "\(job.placeVerb) \(label)" + (place.isEmpty ? "" : " in \(place)")
            idea = PrintPlayJobs.idea(r, label: label)
        } else {
            setup = "Set up \(label)" + (place.isEmpty ? "" : " in \(place)")
            idea = "use \(label) to help everyone in \(place.isEmpty ? "the game" : place)!"
        }
        if setup.split(whereSeparator: \.isWhitespace).count > maxItemWords { setup = it.recipe.map { "\(PrintPlayJobs.job($0).placeVerb) \(label)" } ?? "Set up \(label)" }
        let put = Bookends.fallbackCleanup(it).short
        return PlanObject(id: it.id, area: area, owner: owner, pretend: it.prop.map { "the " + KitDraft.cutoutLabel(becomes: $0.becomes).lowercased() },
                          setup: Bookends.capFirst(setup), idea: idea, putAway: put, appWritten: true)
    }

    static func appArea(_ it: CoverItem, owner: RoleID, plan: PlayPlan) -> String {
        if let a = plan.areas.first(where: { $0.owner == owner }) { return a.id }
        let load = Dictionary(grouping: plan.objects, by: \.area).mapValues(\.count)
        return plan.areas.min { (load[$0.id] ?? 0, $0.id) < (load[$1.id] ?? 0, $1.id) }?.id ?? "A1"
    }

    /// What an object is called in the app's lines ("the Sky Dollars", "the steering wheel").
    static func displayLabel(_ it: CoverItem) -> String {
        if let p = it.prop { return "the " + KitDraft.cutoutLabel(becomes: p.becomes).lowercased() }
        return it.label
    }

    static func picture(_ o: PlanObject, cover: [CoverItem]) -> Picture {
        guard let it = cover.first(where: { $0.id == o.id }) else { return .point }
        if let p = it.prop { return .prop(p.libraryID ?? p.id) }
        return .kit(o.id)
    }

    /// The object's picture chip (setup row, idea card).
    public static func picture(_ id: String, cover: [CoverItem]) -> Picture {
        guard let it = cover.first(where: { $0.id == id }) else { return .point }
        if let p = it.prop { return .prop(p.libraryID ?? p.id) }
        return .kit(id)
    }

    // MARK: Text checks

    /// "the cockpit" (a lowercase "the" in front; 1 to 5 words; speakable).
    static func areaName(_ raw: String) -> String {
        var t = OneScene.clean(raw)
        t = Bookends.trimEnd(t)
        guard !t.isEmpty else { return "" }
        let words = t.split(whereSeparator: \.isWhitespace)
        if words.count > 5 { t = words.prefix(5).joined(separator: " ") }
        if !t.lowercased().hasPrefix("the ") { t = "the " + t } else { t = "the " + t.dropFirst(4) }
        return Speakable.repair(t, fallback: "the play space")
    }

    /// "Build the cockpit" (an imperative, 2 to 6 words; else "Set up <name>").
    static func areaJob(_ raw: String, name: String) -> String {
        let t = Bookends.trimEnd(OneScene.clean(raw))
        let n = t.split(whereSeparator: \.isWhitespace).count
        let job = (n >= 2 && n <= 6) ? Bookends.capFirst(t) : "Set up \(name)"
        return Speakable.repair(job, fallback: "Set up \(name)")
    }

    /// A setup item: cleaned (no quotes, no role title, no end punctuation), 2 to 10 words, naming the object (a prop by
    /// its pretend name, never the household word or "pretend"), speakable and safe. Nil = not usable.
    static func validItem(_ raw: String, for it: CoverItem, roles: [Role], props: [Prop]) -> String? {
        var t = item(raw, roles: roles)
        if let p = it.prop { t = item(PropStandIns.itemText(PropWording.clean(t, props: props + [p]), prop: p), roles: roles) }
        let n = t.split(whereSeparator: \.isWhitespace).count
        guard n >= 2, n <= maxItemWords, names(t, it), Speakable.isSpeakable(Speakable.repair(t)), !Speakable.sendsToHazard(t) else { return nil }
        return Speakable.repair(t, fallback: Speakable.safeItem)
    }

    /// The text names the object: a page by any of its names, a prop by its PRETEND name (never only the household
    /// word: "Load the tray" isn't the snack cart).
    static func names(_ t: String, _ it: CoverItem) -> Bool {
        guard let p = it.prop else { return Bookends.mentions(t, it) }
        let label = KitDraft.cutoutLabel(becomes: p.becomes)
        var pretendNames = Bookends.propNames(p).filter { $0.caseInsensitiveCompare(p.householdItem) != .orderedSame }
        // "the airplane seats" also counts as "an airplane seat".
        if label.lowercased().hasSuffix("s"), label.count > 3 { pretendNames.append(String(label.dropLast())) }
        return Bookends.mentions(t, name: label) || pretendNames.contains { Bookends.mentions(t, name: $0) }
    }

    static func validPutAway(_ raw: String, roles: [Role]) -> String? {
        let t = item(raw, roles: roles)
        let n = t.split(whereSeparator: \.isWhitespace).count
        guard n >= 2, n <= maxItemWords, !Speakable.sendsToHazard(t) else { return nil }
        return Speakable.repair(t, fallback: "Tidy up your spot")
    }

    /// An idea: cleaned, no role title (the app puts the owner's in), 4 to 22 words, uses the object, a scenario (never
    /// a single gesture), speakable and safe. Nil = not usable.
    static func validIdea(_ raw: String, for it: CoverItem, roles: [Role]) -> String? {
        var t = OneScene.clean(raw)
        t = stripRoles(t, roles: roles)
        t = exclaim(t)
        let n = t.split(whereSeparator: \.isWhitespace).count
        guard n >= 4, n <= maxIdeaWords, names(t, it), !Speakable.sendsToHazard(t), !EventScenario.isGestureOnly(t, roles: roles) else { return nil }
        return Speakable.repair(t, fallback: "")
    }

    /// A props-call event rewrite: names exactly the roles the event calls, uses the prop, not a gesture, safe.
    static func validEventLine(_ raw: String, replacing e: BeatEvent, uses it: CoverItem, roles: [Role]) -> String? {
        let t = PlayCast.endSentence(OneScene.capWords(OneScene.clean(raw), max: OneScene.maxLineWords))
        let n = t.split(whereSeparator: \.isWhitespace).count
        guard n >= 6, names(t, it), OneScene.named(t, roles: roles) == e.roles, !e.isEveryone || OneScene.named(t, roles: roles).isEmpty,
              !EventScenario.isGestureOnly(t, roles: roles), !Speakable.sendsToHazard(t), Speakable.isSpeakable(Speakable.repair(t)) else { return nil }
        return Speakable.repair(t)
    }

    /// A setup / put-away item's words: no quotes, no role title in front, no end punctuation, capitalized.
    static func item(_ raw: String, roles: [Role]) -> String {
        var t = OneScene.clean(raw)
        t = stripRoles(t, roles: roles)
        t = Bookends.trimEnd(t)
        return Bookends.capFirst(t)
    }

    /// "Captain, write…" → "write…"; "While we fly, Captain, write…" → "While we fly, write…".
    static func stripRoles(_ s: String, roles: [Role]) -> String {
        var t = s
        for r in roles.sorted(by: { $0.roleName.count > $1.roleName.count }) where !r.roleName.isEmpty {
            let name = NSRegularExpression.escapedPattern(for: r.roleName)
            t = t.replacingOccurrences(of: #"(?i)^(?:the\s+)?"# + name + #"\s*[,:]\s*"#, with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: #"(?i),\s*(?:the\s+)?"# + name + #"\s*,\s*"#, with: ", ", options: .regularExpression)
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let leadWords: Set<String> = ["while", "when", "before", "after", "now", "as", "until", "between", "meanwhile", "once", "during", "in"]

    /// The idea as she says it, with the owner's title in: "While we fly, Captain, write in your log what you saw!" or
    /// "Captain, count the Sky Dollars!".
    /// An idea ends with "!" (a nudge), unless it already ends a sentence.
    static func exclaim(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = t.last else { return t }
        return ".!?".contains(last) ? t : t + "!"
    }

    public static func ideaLine(_ idea: String, who: String) -> String {
        let t = exclaim(idea)
        guard !t.isEmpty else { return "" }
        if let comma = t.firstIndex(of: ","), let first = t.split(separator: " ").first,
           leadWords.contains(first.lowercased()), t[..<comma].split(separator: " ").count <= 6 {
            let head = t[..<comma], rest = t[t.index(after: comma)...].trimmingCharacters(in: .whitespaces)
            return "\(head), \(who), \(PlayCast.lowerFirst(rest))"
        }
        return "\(who), \(PlayCast.lowerFirst(t))"
    }
}
