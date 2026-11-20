import Foundation

// Round 29 (ensemble scenes): the guide is 3 scenes × one task per role + a solo task; the weave rewrites whole tasks.
// Guide prefetch (2026-11-15, Haylee: "fix it first"). Round C1 made the play guide much longer (6 scenes × a step for
// each of the 6 ranked roles + 2 for everyone), and it waited for the hunt's end, so the Paper step waited ~30 s for it.
// Now the play guide is written DURING the hunt, as soon as the kit pages land (the props aren't known yet: the voice
// model picks them one at a time), and each prop is worked into a step or two by a small fast call as its card comes
// up ("weaving"). When the hunt ends, skips and swaps are applied here, deterministically, with no new call: a skipped
// prop's steps say "pretend …" and show its printed cut-out; a swapped prop's steps name and show the new item.
// A correction (game, theme, new roles) restarts the pages and so the guide (the same generation as the pages).

/// What the weave call returns: for each prop, the 1 or 2 existing steps rewritten to use it.
public struct PropWeave: Codable, Equatable, Sendable {
    public struct Use: Codable, Equatable, Sendable {
        public var propID: String; public var scene: Int; public var step: Int; public var text: String
        public init(propID: String, scene: Int, step: Int, text: String) { self.propID = propID; self.scene = scene; self.step = step; self.text = text }
    }
    public var uses: [Use]
    /// Round 36: each prop's setup and clean-up jobs (`item` = the prop id), written in the same call.
    public var jobs: [ItemJobs.Job]?
    public init(uses: [Use], jobs: [ItemJobs.Job]? = nil) { self.uses = uses; self.jobs = jobs }
}
extension PropWeave: SafetyText { public var safetyTexts: [String] { uses.map(\.text) + (jobs ?? []).flatMap(\.texts) } }

/// Round 36: one item's setup + clean-up jobs, as the AI writes them (the guide for the pages, the weave for a prop,
/// and the one re-ask for anything missing).
public struct ItemJobs: Codable, Equatable, Sendable, SafetyText {
    public struct Job: Codable, Equatable, Sendable {
        public var item: String; public var role: String
        public var setupShort: String; public var setupSay: String
        public var cleanupShort: String; public var cleanupSay: String
        public init(item: String, role: String, setupShort: String, setupSay: String, cleanupShort: String, cleanupSay: String) {
            self.item = item; self.role = role; self.setupShort = setupShort; self.setupSay = setupSay
            self.cleanupShort = cleanupShort; self.cleanupSay = cleanupSay
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            item = try c.decodeIfPresent(String.self, forKey: .item) ?? ""   // the guide's page jobs are keyed by recipe
            role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
            // Round 40: the rows show goals, so the jobs no longer carry a short row text (older answers still may).
            // 2026-11-20: a checklist kit's weave asks only for the clean-up job (no setup scene any more).
            setupShort = try c.decodeIfPresent(String.self, forKey: .setupShort) ?? ""; setupSay = try c.decodeIfPresent(String.self, forKey: .setupSay) ?? ""
            cleanupShort = try c.decodeIfPresent(String.self, forKey: .cleanupShort) ?? ""; cleanupSay = try c.decode(String.self, forKey: .cleanupSay)
        }
        var texts: [String] { [setupShort, setupSay, cleanupShort, cleanupSay] }
        /// The two `ItemJob`s for a cover item id ("page:sign" / "prop:bowl").
        public func jobs(id: String, prop: Prop? = nil) -> (setup: ItemJob, cleanup: ItemJob) {
            let r = RoleID(rawValue: role)
            return (ItemJob(item: id, short: setupShort, say: setupSay, role: r, householdItem: prop?.householdItem, becomes: prop?.becomes),
                    ItemJob(item: id, short: cleanupShort, say: cleanupSay, role: r, householdItem: prop?.householdItem, becomes: prop?.becomes))
        }
    }
    public var jobs: [Job]
    public init(jobs: [Job]) { self.jobs = jobs }
    public var safetyTexts: [String] { jobs.flatMap(\.texts) }

    static var jobProps: [String: Any] { [
        "role": Schemas.enumStr(RoleID.allCases.map(\.rawValue)),
        // Round 40: no short row texts (the rows show each role's goal); Nutmeg says these after "…by".
        "setupSay": ["type": "string", "description": "The setup job Nutmeg SAYS: an imperative phrase of 5 to 12 words that STARTS WITH A VERB (hang, put, set, line up, stack…), no role title, NAMES this item and gives it a clear purpose in the play space (e.g. hang the Sunny Bakery sign by the door)."],
        "cleanupSay": ["type": "string", "description": "The clean-up job: an imperative phrase of 5 to 12 words that STARTS WITH A VERB, no role title, names this item and puts it away, framed in the story (e.g. put the mixing bowl back in the kitchen)."],
    ] }
    /// The re-ask / weave schema: a list of jobs, `item` one of `ids`.
    public static func schema(ids: [String]) -> [String: Any] {
        var j = jobProps; j["item"] = Schemas.enumStr(ids.isEmpty ? ["none"] : ids)
        return Schemas.obj(["jobs": Schemas.arr(Schemas.obj(j))])
    }
    /// The guide's fixed per-page object (one per recipe, required).
    static func pageSchema() -> [String: Any] { Schemas.obj(jobProps) }
}

/// One step that uses a prop, with the prop as it was when the step was written (to apply a later skip or swap).
public struct PropUse: Equatable, Sendable {
    public var propID: String, scene: Int, step: Int
    public var libraryID: String, item: String, becomes: String
    public init(propID: String, scene: Int, step: Int, libraryID: String, item: String, becomes: String) {
        self.propID = propID; self.scene = scene; self.step = step; self.libraryID = libraryID; self.item = item; self.becomes = becomes
    }
}

public enum GuideWeave {
    /// Tasks a prop may take over (round 29: 1 or 2 role tasks in different scenes, plus a solo task).
    public static let maxUsesPerProp = 3
    /// A rewritten task longer than this is dropped (round 29: the tasks are one sentence of at most about 20 words).
    public static let maxWords = 40   // round 34: the spoken task has the job plus 1–2 concrete ideas

    public static func schema(propIDs: [String], checklist: Bool = false) -> [String: Any] {
        var j = ItemJobs.jobProps; j["item"] = Schemas.enumStr(propIDs.isEmpty ? ["none"] : propIDs)
        // 2026-11-20: checklist scenes have no setup scene, so a prop's weave writes only its clean-up job.
        if checklist { j["setupSay"] = nil }
        return Schemas.obj(["uses": Schemas.arr(Schemas.obj(["propID": Schemas.enumStr(propIDs.isEmpty ? ["none"] : propIDs),
                                                              "scene": Schemas.int, "step": Schemas.int, "text": Schemas.str])),
                            // Round 36: each prop's setup + clean-up job (one entry per prop).
                            "jobs": Schemas.arr(Schemas.obj(j))])
    }

    /// The weave prompt: the guide as numbered lines, the props to add, the tasks already taken by other props.
    public static func prompt(scenes: [Scene], props: [Prop], taken: [PropUse], roles: [Role], players: Int) -> String {
        if scenes.contains(where: \.isChecklist) { return checklistPrompt(scenes: scenes, props: props, taken: taken, roles: roles, players: players) }
        let n = PlayCast.players(players)
        let busy = Set(taken.map { "\($0.scene).\($0.step)" })
        func who(_ s: Step) -> String {
            if s.role == .solo { return "solo: one kid alone as R1" }
            guard let r = s.role.role else { return "everyone" }
            return "\(r.rawValue) \(roles.first { $0.id == r }?.roleName ?? "")"
        }
        let guide = scenes.enumerated().map { i, sc in
            "Scene \(i) \"\(sc.title)\":\n" + sc.steps.enumerated().map { j, st in
                "  s\(i).\(j) [\(who(st))]\(busy.contains("\(i).\(j)") ? " (taken)" : ""): \(st.text)"
            }.joined(separator: "\n")
        }.joined(separator: "\n")
        let list = props.map { p in
            // 2026-11-18: a multiple is plural in the guide ("the cups"), never a count (replays change the count).
            (p.rule == .one ? "- id \(p.id): a \(p.householdItem.lowercased()) that becomes \(p.becomes)"
                : "- id \(p.id): several \(p.itemWords)\(p.isPerPlayer ? " (one for each player)" : "") that become \(p.becomes) (always say them in the plural, like \"the \(p.itemWords)\", never a number)")
                + (p.forRole.role.map { r in r.rank <= n ? " (for the \(roles.first { $0.id == r }?.roleName ?? r.rawValue))" : "" } ?? "")
                + (p.isSkipped ? " (pretend: they don't have it, they'll use a printed cut-out)" : "")
        }.joined(separator: "\n")
        let playing = (1...n).map { "R\($0)" }.joined(separator: ", ")
        return """
        Phase: add household props to the play guide. The kids found these props in their home for this game:
        \(list)
        The play guide (sN.M = scene N, task M; [who the task is for]):
        \(guide)
        For EACH prop, pick 1 or 2 role tasks (in different scenes, where it fits best) plus the solo task of one of \
        those scenes, and rewrite ONLY those tasks so the kids use the prop as what it becomes, keeping what the task \
        does with the other roles (e.g. "Waiter, carry the Customer's order on the serving tray!"). Pick tasks of the \
        roles that are playing (\(playing)) and spread the props over them: first a playing role with no (taken) task \
        yet, then the prop's own role. Never pick a task marked (taken), and at most one prop per task. Keep the task \
        for the same role: it still starts with that role's title. These are the SPOKEN tasks: the job plus 1 or 2 concrete ideas, at most 30 words, no quotes or lines \
        to say. Name the prop by what it becomes (never the household item), gentle and kid-safe. \
        ALSO, for EACH prop, write its jobs (one entry per prop, item = the prop id): setupSay = how the kids put it in \
        place before the play starts so it has a clear purpose in the play space, starting with a verb (e.g. "set the \
        treasure chest by the ship's wheel to hold the gold"), named by what it becomes; cleanupSay = how they put the \
        household item back at the end, framed in the story, starting with a verb (e.g. "put the box back in the closet \
        so the ship can rest"); role = the playing role it suits best. No quotes. Return PropWeave \
        (scene and step are the numbers above).
        """
    }

    /// 2026-11-20 (Haylee, checklist scenes): the weave for a checklist guide: each prop takes over 1 or 2 checklist
    /// items (2 to 6 words, by what it becomes), preferably in the first or last scene (every group size sees those),
    /// plus its clean-up job. The app's coverage step still adds any prop a count wouldn't see (no AI call).
    static func checklistPrompt(scenes: [Scene], props: [Prop], taken: [PropUse], roles: [Role], players: Int) -> String {
        let n = PlayCast.players(players)
        let busy = Set(taken.map { "\($0.scene).\($0.step)" })
        let guide = scenes.enumerated().map { i, sc in
            "Scene \(i) \"\(sc.title)\":\n" + sc.steps.enumerated().map { j, st in
                let who = st.role.role.map { r in "\(r.rawValue) \(roles.first { $0.id == r }?.roleName ?? "")" } ?? "everyone"
                return "  s\(i).\(j) [\(who)]\(busy.contains("\(i).\(j)") ? " (taken)" : ""): \(st.short ?? st.text)"
            }.joined(separator: "\n")
        }.joined(separator: "\n")
        let list = props.map { p in
            (p.rule == .one ? "- id \(p.id): a \(p.householdItem.lowercased()) that becomes \(p.becomes)"
                : "- id \(p.id): several \(p.itemWords) that become \(p.becomes) (always plural, never a number)")
                + (p.forRole.role.map { r in r.rank <= n ? " (for the \(roles.first { $0.id == r }?.roleName ?? r.rawValue))" : "" } ?? "")
                + (p.isSkipped ? " (pretend: they don't have it, they'll use a printed cut-out)" : "")
                + PropStandIns.promptNote(p)   // 2026-11-21 (Haylee): only believable pretend uses
        }.joined(separator: "\n")
        let playing = (1...n).map { "R\($0)" }.joined(separator: ", ")
        let last = max(0, scenes.count - 1)
        // 2026-11-21: a one-scene guide has ONE checklist (the setup), so there's no scene to prefer.
        let place = scenes.count == 1 ? "in the setup checklist," : "preferably in scene 0 or scene \(last) (every group size plays those),"
        return """
        Phase: add household props to the play checklists. The kids found these props in their home for this game:
        \(list)
        The checklists (sN.M = scene N, item M; [the role it belongs to]):
        \(guide)
        For EACH prop, pick 1 or 2 checklist items of the playing roles (\(playing)), \(place) spread over the roles (the prop's own role first), and rewrite ONLY those items \
        so the kid sets up or uses the prop as what it becomes: 2 to 6 words, one simple action, no role title, no end \
        punctuation, no quotes (e.g. Set up the airplane seats, Put on your space helmet). Never pick an item marked \
        (taken), and at most one prop per item, and never an item of a role that already has another prop's or page's job \
        (each object has ONE owner). Name the prop ONLY by what it becomes (Hold up the planet), never the household \
        item and never the word pretend (not "your sock pretend planet"), and only as one of its allowed pretend uses. \
        Gentle and kid-safe. Everything is pretend: an appliance or place is the pretend one tied to a prop (the pretend \
        stove, never the real stove), and never send the kids to anything real and unsafe (stove, oven, sink, outlet, \
        stairs, climbing, outside). ALSO, for EACH prop, its clean-up job (one entry per prop, item = the prop id): cleanupSay = how they put the \
        household item back at the end, framed in the story, starting with a verb (e.g. put the box back in the closet \
        so the ship can rest); role = the playing role it suits best. Return PropWeave (scene and step are the numbers above).
        """
    }

    /// Applies a weave answer: valid uses only (a prop asked for, a real step not already taken, a short non-empty
    /// text), at most `maxUsesPerProp` per prop. The step keeps its role; its picture becomes the prop.
    public static func apply(_ weave: PropWeave, to scenes: [Scene], props: [Prop], taken: [PropUse], roles: [Role] = []) -> (scenes: [Scene], uses: [PropUse]) {
        var out = scenes, uses: [PropUse] = []
        var busy = Set(taken.map { "\($0.scene).\($0.step)" })
        var perProp: [String: Int] = [:]
        for u in weave.uses {
            guard let p = props.first(where: { $0.id == u.propID }),
                  out.indices.contains(u.scene), out[u.scene].steps.indices.contains(u.step),
                  !busy.contains("\(u.scene).\(u.step)"), (perProp[p.id] ?? 0) < maxUsesPerProp else { continue }
            let lib = p.libraryID ?? p.id
            var text = u.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = text.split(whereSeparator: \.isWhitespace).count
            // 2026-11-20: a checklist item stays short (shown and said as one item).
            let checklist = out[u.scene].isChecklist
            guard words >= 2, words <= (checklist ? ChecklistScenes.maxItemWords + 2 : maxWords) else { continue }
            if checklist {
                // 2026-11-21: the pretend name only, and only one of the prop's stand-ins.
                text = ChecklistScenes.cleanItem(PropStandIns.itemText(PropWording.clean(text, props: props), prop: p), roles: roles)
                out[u.scene].steps[u.step].short = text
            }
            out[u.scene].steps[u.step].text = text
            out[u.scene].steps[u.step].picture = .prop(lib)
            busy.insert("\(u.scene).\(u.step)"); perProp[p.id, default: 0] += 1
            uses.append(PropUse(propID: p.id, scene: u.scene, step: u.step, libraryID: lib, item: p.householdItem, becomes: p.becomes))
        }
        return (out, uses)
    }

    /// The hunt is over: skips and swaps applied to the steps that use a prop, with no new call. A skipped prop's step
    /// says "the pretend <what it becomes>" and shows its printed cut-out (`items` = the final pages, with the skipped
    /// props' cut-outs appended); a swapped prop's step names and shows the new item. A prop that no longer exists (or
    /// no longer fits its use) gets its step's picture reset to the plain point (the text stays).
    public static func finalize(_ scenes: [Scene], uses: [PropUse], props: Props?, items: [KitItem]) -> [Scene] {
        var out = scenes
        let cutLines = items.first { $0.recipe == .cutouts }?.lines ?? []
        for u in uses where out.indices.contains(u.scene) && out[u.scene].steps.indices.contains(u.step) {
            var st = out[u.scene].steps[u.step]
            guard let p = props?.props.first(where: { $0.id == u.propID }) else {
                st.picture = .point; out[u.scene].steps[u.step] = st; continue
            }
            let lib = p.libraryID ?? p.id
            if p.isSkipped {
                let label = KitDraft.cutoutLabel(becomes: p.becomes)
                st.mapTexts { pretend($0, item: u.item, becomes: u.becomes, label: label) }   // round 34: shown + spoken
                if let n = cutLines.firstIndex(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) {
                    st.picture = .kit("cutout:\(n)")
                } else {
                    st.picture = .point
                }
            } else {
                // A swap: the step names what the prop becomes (unchanged), so only a step that named the old
                // household item itself gets the new one ("the snack bowl" stays, "the bowl" → "the cup").
                if p.householdItem.caseInsensitiveCompare(u.item) != .orderedSame,
                   !PlayCast.names(st.text, KitDraft.cutoutLabel(becomes: u.becomes)) {
                    st.mapTexts { replacing($0, phrase: u.item, with: p.householdItem.lowercased()) }
                }
                if p.becomes.caseInsensitiveCompare(u.becomes) != .orderedSame {
                    st.mapTexts { replacing($0, phrase: KitDraft.cutoutLabel(becomes: u.becomes), with: KitDraft.cutoutLabel(becomes: p.becomes)) }
                }
                st.picture = PropFit.fits(itemID: lib, becomes: p.becomes) ? .prop(lib) : .point
            }
            out[u.scene].steps[u.step] = st
        }
        return out
    }

    /// "Baker, stir with the big spoon!" → "Baker, stir with the pretend big spoon!" (the stand-in's name, from what the
    /// prop becomes, in place of the prop or the household item; "pretend" is never doubled).
    public static func pretend(_ text: String, item: String, becomes: String, label: String) -> String {
        let phrase = KitDraft.cutoutLabel(becomes: becomes)
        let t = text
        for name in [phrase, label, item.lowercased()] where !name.isEmpty {
            let escaped = NSRegularExpression.escapedPattern(for: name)
            let pattern = #"(?i)(?<![\p{L}\p{N}-])(?<!pretend )"# + escaped + #"(?![\p{L}\p{N}-])"#
            if t.range(of: pattern, options: .regularExpression) != nil {
                return t.replacingOccurrences(of: pattern, with: "pretend " + PlayCast.lowerFirst(label), options: .regularExpression)
            }
        }
        return t   // paraphrased: the step's picture (the printed cut-out) still shows the stand-in
    }

    static func replacing(_ text: String, phrase: String, with new: String) -> String {
        let p = phrase.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty, !new.isEmpty else { return text }
        let pattern = #"(?i)(?<![\p{L}\p{N}-])"# + NSRegularExpression.escapedPattern(for: p) + #"(?![\p{L}\p{N}-])"#
        return text.replacingOccurrences(of: pattern, with: new, options: .regularExpression)
    }

    /// The props still to weave in: on the guide's props, not yet asked about.
    public static func pending(_ props: Props?, attempted: Set<String>) -> [Prop] {
        (props?.props ?? []).filter { !attempted.contains($0.id) }
    }
}

/// The early play guide's answer in a FIXED shape: exactly `count` scenes (scene1 … scene3), each with exactly one task
/// per ranked role (R1 … R6) and a solo task, as required fields rather than arrays. At low effort the array form
/// sometimes came back cut short (seen live: ONE scene, about 1 call in 3); a fixed shape can't be. The task's role
/// comes from its field. Decoded into the usual scene list.
/// Round 29 (Haylee, ensemble scenes): 3 scenes × (6 role tasks + 1 solo task) = 21 short task strings, no pictures
/// (the rows show each role's character), no ids. (The type keeps its name: it is the guide for SIX ranked roles.)
public struct KitScenesSix: Decodable, Sendable, SafetyText {
    public var nutmegSays: String
    public var scenes: [Scene]
    /// Round 36 (Haylee): the story opener and the setup / clean-up scenes (titles, lines, one job per printed page),
    /// written in this same call. Nil in an answer without them (tests, older shapes).
    public var story: String?
    public var setup: Bookend?
    public var cleanup: Bookend?
    public init(nutmegSays: String, scenes: [Scene], story: String? = nil, setup: Bookend? = nil, cleanup: Bookend? = nil) {
        self.nutmegSays = nutmegSays; self.scenes = scenes; self.story = story; self.setup = setup; self.cleanup = cleanup
    }
    public static let count = 3
    /// 2026-11-20 (Haylee, checklist scenes): a new guide has 4 checklist scenes (shown 2 to 4 by player count).
    public static let checklistCount = ChecklistScenes.generated

    struct BookendBody: Decodable { var title: String; var nutmegSays: String; var goals: [String: String]? }
    /// Round 36: the setup / clean-up scenes and the pages' jobs (keyed by recipe).
    static func bookends(_ c: KeyedDecodingContainer<Key>) -> (setup: Bookend, cleanup: Bookend)? {
        guard let s = try? c.decode(BookendBody.self, forKey: Key(stringValue: "setupScene")),
              let k = try? c.decode(BookendBody.self, forKey: Key(stringValue: "cleanupScene")) else { return nil }
        // Round 40: a new answer always makes goal rows (missing goals are written by the app, `Bookends.repair`).
        var setup = Bookend(title: s.title, nutmegSays: s.nutmegSays, goals: s.goals ?? [:])
        var cleanup = Bookend(title: k.title, nutmegSays: k.nutmegSays, goals: k.goals ?? [:])
        if let pages = try? c.nestedContainer(keyedBy: Key.self, forKey: Key(stringValue: "pageJobs")) {
            for r in KitRecipe.allCases {
                guard let j = try? pages.decode(ItemJobs.Job.self, forKey: Key(stringValue: r.rawValue)) else { continue }
                let two = j.jobs(id: Bookends.pageID(r))
                setup.put(two.setup); cleanup.put(two.cleanup)
            }
        }
        return (setup, cleanup)
    }
    static let taskKeys: [(key: String, role: SceneOwner)] = RoleID.allCases.map { ($0.rawValue, SceneOwner($0)) } + [("solo", .solo)]

    struct Key: CodingKey {
        var stringValue: String; var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
    /// Round 34: a task's two texts.
    struct TwoTexts: Decodable { var short: String; var say: String }
    struct SceneBody: Decodable {
        var scene: Scene
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            // 2026-11-20: a checklist scene is {title, scenario, R1…R6: [item]} (2 to 3 short items per role).
            if c.contains(Key(stringValue: "scenario")) {
                let steps = RoleID.allCases.flatMap { r -> [Step] in
                    let list = (try? c.decodeIfPresent([String].self, forKey: Key(stringValue: r.rawValue))) ?? nil
                    return (list ?? []).map { Step(picture: .point, text: $0, role: SceneOwner(r), short: $0) }
                }
                scene = Scene(id: "", owner: .all, title: try c.decode(String.self, forKey: Key(stringValue: "title")), picture: .point,
                              nutmegSays: try c.decode(String.self, forKey: Key(stringValue: "scenario")), steps: steps, checklist: true)
                return
            }
            // Round 34: each task is {short, say} (shown, spoken); a plain string (older answers) is the spoken text.
            let steps = try KitScenesSix.taskKeys.compactMap { k -> Step? in
                let key = Key(stringValue: k.key)
                if let two = try? c.decodeIfPresent(TwoTexts.self, forKey: key) {
                    return Step(picture: .point, text: two.say, role: k.role, short: two.short)
                }
                guard let t = try c.decodeIfPresent(String.self, forKey: key) else { return nil }
                return Step(picture: .point, text: t, role: k.role)
            }
            scene = Scene(id: "", owner: .all, title: try c.decode(String.self, forKey: Key(stringValue: "title")),
                          picture: .point, nutmegSays: try c.decode(String.self, forKey: Key(stringValue: "nutmegSays")), steps: steps)
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        nutmegSays = try c.decodeIfPresent(String.self, forKey: Key(stringValue: "nutmegSays")) ?? ""
        scenes = try (1...Self.checklistCount).compactMap { i -> Scene? in
            guard var s = try c.decodeIfPresent(SceneBody.self, forKey: Key(stringValue: "scene\(i)"))?.scene else { return nil }
            s.id = "s\(i)"
            return s
        }
        story = try? c.decodeIfPresent(String.self, forKey: Key(stringValue: "story"))
        if scenes.contains(where: \.isChecklist) {
            // 2026-11-20: no setup scene; the clean-up checklist's title (its jobs come from the app and the weaves).
            let t = ((try? c.decodeIfPresent(String.self, forKey: Key(stringValue: "cleanupTitle"))) ?? nil) ?? ""
            cleanup = Bookend(title: t, nutmegSays: "")
        } else if let b = Self.bookends(c) { setup = b.setup; cleanup = b.cleanup }
    }

    /// 2026-11-20 (Haylee, checklist scenes): the guide's schema: the story, 4 scenes (a title, 2 to 3 short checklist
    /// items for EACH role R1 to R6, one scenario) and the clean-up checklist's title. No setup scene, no goals, no page
    /// jobs, no spoken task texts (the app writes what Nutmeg says for each item), so the answer is about half as long.
    public static func checklistSchema() -> [String: Any] {
        var sceneProps: [String: Any] = [
            "title": ["type": "string", "description": "2 to 5 words: what the kids get ready for in this scene (e.g. Get the rocket ready)."],
            "scenario": ["type": "string", "description": "ONE short line, about 20 to 30 words, that starts with \"Pretend that\", adds a small twist and ALWAYS ends with an action for everyone (e.g. Pretend that the rocket is blasting off... uh-oh, the control panel is beeping! Everyone, do your job to get the rocket safely into space!)."],
        ]
        for r in RoleID.allCases {
            sceneProps[r.rawValue] = ["type": "array", "items": ["type": "string"],
                                      "description": "The \(r.rawValue) role's checklist in this scene: 2 or 3 items, each 2 to 6 words, one simple action, no role title, no end punctuation (e.g. Put on your badge)."]
        }
        var props: [String: Any] = [:]
        for i in 1...checklistCount { props["scene\(i)"] = ["$ref": "#/$defs/scene"] }
        props["story"] = ["type": "string", "description": "The story Nutmeg tells right after printing: 3 or 4 short sentences, about 40 to 55 words (15 seconds): where we are, who the kids are (the R1 role and the crew; name no other role), and what is about to happen. Kid words, exciting, no quotes."]
        props["cleanupTitle"] = ["type": "string", "description": "2 to 4 words: the title of the final clean-up checklist, the story's ending (e.g. Closing Time)."]
        var o = Schemas.obj(props)
        o["$defs"] = ["scene": Schemas.obj(sceneProps)]
        return o
    }

    /// Round 45: `pages` = this kit's printable types (one page job each; the kit is custom per game now).
    public static func schema(pages kitPages: [KitRecipe] = KitRecipe.original) -> [String: Any] {
        var sceneProps: [String: Any] = ["title": Schemas.str, "nutmegSays": Schemas.str]
        // Round 34 (Haylee): every task has two texts: `short` (shown on the row) and `say` (spoken by its 🔊).
        for k in taskKeys {
            var task = Schemas.obj(["short": ["type": "string", "description": "What the row SHOWS: 3 to 7 words, broad, no role title, no end punctuation (e.g. Get the pet ready to go home)."],
                                    "say": ["type": "string", "description": "What Nutmeg SAYS for it: starts with the role's title, the same job, then 1 or 2 concrete example ideas with their props or printed pages (e.g. Pet Trainer, it's time to get the pet ready to go home! You could write its name on the Pet Visit Pass and hand over the leash.)."]])
            task["description"] = k.role == .solo
                ? "The task for ONE kid playing alone as R1: a slightly bigger version of R1's task in this scene."
                : "The \(k.role.rawValue) role's ONE task in this scene."
            sceneProps[k.key] = task
        }
        var props: [String: Any] = [:]
        for i in 1...count { props["scene\(i)"] = ["$ref": "#/$defs/scene"] }
        // Round 36 (Haylee): the story opener, the setup and clean-up scenes, and one job per printed page.
        props["story"] = ["type": "string", "description": "The story Nutmeg tells right after printing, before the setup: 3 or 4 short sentences, about 40 to 55 words (15 seconds): where we are, who the kids are (the R1 role and the crew; name no other role), and what is about to happen. Kid words, exciting, no quotes."]
        // Round 40 (Haylee): each role's GOAL in the scene (the row shows it; the item jobs are the spoken specifics).
        var goalProps: [String: Any] = [:]
        for r in RoleID.allCases { goalProps[r.rawValue] = Schemas.str }
        var goals = Schemas.obj(goalProps)
        goals["description"] = "For EACH role R1 to R6, that role's GOAL in this scene: 2 to 6 words in the game's world, an imperative, no role title, no list of items (setup e.g. Get the pet room ready; clean-up e.g. Close up the clinic). Different goals for different roles."
        let bookend: [String: Any] = Schemas.obj(["title": ["type": "string", "description": "2 to 4 words."],
                                                  "nutmegSays": ["type": "string", "description": "ONE sentence that starts with \"Pretend that\"."],
                                                  "goals": goals])
        props["setupScene"] = ["$ref": "#/$defs/bookend"]
        props["cleanupScene"] = ["$ref": "#/$defs/bookend"]
        var pages: [String: Any] = [:]
        for r in (kitPages.isEmpty ? KitRecipe.original : kitPages) { pages[r.rawValue] = ["$ref": "#/$defs/job"] }
        props["pageJobs"] = Schemas.obj(pages)
        var o = Schemas.obj(props)
        // One definition each (inline copies make the grammar and the input bigger for nothing; round 36: the 6 page
        // jobs share one, the 2 bookend scenes another).
        o["$defs"] = ["scene": Schemas.obj(sceneProps), "bookend": bookend, "job": ItemJobs.pageSchema()]
        return o
    }
    public var safetyTexts: [String] {
        [nutmegSays] + scenes.flatMap { [$0.title, $0.nutmegSays] + $0.steps.flatMap { [$0.text] + ($0.short.map { [$0] } ?? []) } }
            + Bookends.safetyTexts(Kit(nutmegSays: "", items: [], scenes: [], story: story, setup: setup, cleanup: cleanup))
    }
}
