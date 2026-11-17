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
    public init(uses: [Use]) { self.uses = uses }
}
extension PropWeave: SafetyText { public var safetyTexts: [String] { uses.map(\.text) } }

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

    public static func schema(propIDs: [String]) -> [String: Any] {
        Schemas.obj(["uses": Schemas.arr(Schemas.obj(["propID": Schemas.enumStr(propIDs.isEmpty ? ["none"] : propIDs),
                                                       "scene": Schemas.int, "step": Schemas.int, "text": Schemas.str]))])
    }

    /// The weave prompt: the guide as numbered lines, the props to add, the tasks already taken by other props.
    public static func prompt(scenes: [Scene], props: [Prop], taken: [PropUse], roles: [Role], players: Int) -> String {
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
            "- id \(p.id): a \(p.householdItem.lowercased()) that becomes \(p.becomes)"
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
        to say. Name the prop by what it becomes (never the household item), gentle and kid-safe. Return PropWeave \
        (scene and step are the numbers above).
        """
    }

    /// Applies a weave answer: valid uses only (a prop asked for, a real step not already taken, a short non-empty
    /// text), at most `maxUsesPerProp` per prop. The step keeps its role; its picture becomes the prop.
    public static func apply(_ weave: PropWeave, to scenes: [Scene], props: [Prop], taken: [PropUse]) -> (scenes: [Scene], uses: [PropUse]) {
        var out = scenes, uses: [PropUse] = []
        var busy = Set(taken.map { "\($0.scene).\($0.step)" })
        var perProp: [String: Int] = [:]
        for u in weave.uses {
            guard let p = props.first(where: { $0.id == u.propID }),
                  out.indices.contains(u.scene), out[u.scene].steps.indices.contains(u.step),
                  !busy.contains("\(u.scene).\(u.step)"), (perProp[p.id] ?? 0) < maxUsesPerProp else { continue }
            let lib = p.libraryID ?? p.id
            let text = u.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = text.split(whereSeparator: \.isWhitespace).count
            guard words >= 2, words <= maxWords else { continue }
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
    public init(nutmegSays: String, scenes: [Scene]) { self.nutmegSays = nutmegSays; self.scenes = scenes }
    public static let count = 3
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
        scenes = try (1...Self.count).compactMap { i -> Scene? in
            guard var s = try c.decodeIfPresent(SceneBody.self, forKey: Key(stringValue: "scene\(i)"))?.scene else { return nil }
            s.id = "s\(i)"
            return s
        }
    }

    public static func schema() -> [String: Any] {
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
        var o = Schemas.obj(props)
        // One definition (3 inline copies make the grammar bigger for nothing).
        o["$defs"] = ["scene": Schemas.obj(sceneProps)]
        return o
    }
    public var safetyTexts: [String] { [nutmegSays] + scenes.flatMap { [$0.title, $0.nutmegSays] + $0.steps.flatMap { [$0.text] + ($0.short.map { [$0] } ?? []) } } }
}
