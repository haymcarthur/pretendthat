import Foundation

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
    /// Steps a prop may take over (the prompt asks for 1 or 2, in different scenes).
    public static let maxUsesPerProp = 2
    /// A rewritten step longer than this is dropped (the guide's steps are at most 9 words; a little slack).
    public static let maxWords = 12

    public static func schema(propIDs: [String]) -> [String: Any] {
        Schemas.obj(["uses": Schemas.arr(Schemas.obj(["propID": Schemas.enumStr(propIDs.isEmpty ? ["none"] : propIDs),
                                                       "scene": Schemas.int, "step": Schemas.int, "text": Schemas.str]))])
    }

    /// The weave prompt: the guide as numbered lines, the props to add, the steps already taken by other props.
    public static func prompt(scenes: [Scene], props: [Prop], taken: [PropUse], roles: [Role], players: Int) -> String {
        let n = PlayCast.players(players)
        let busy = Set(taken.map { "\($0.scene).\($0.step)" })
        func who(_ s: Step) -> String {
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
        The play guide (sN.M = scene N, step M; [who the step is for]):
        \(guide)
        For EACH prop, pick 1 or 2 steps (in different scenes, where it fits the scene best) and rewrite ONLY those steps \
        so the kids use the prop as what it becomes (e.g. "Captain, steer with the steering wheel!"). Pick steps of the \
        roles that are playing (\(playing)) and spread the props over them: first a playing role with no (taken) step \
        yet, then the prop's own role, then an everyone step. Never pick a step marked (taken), and at most one prop per step. Keep the step for the same role: a role's step still starts \
        with that role's title; an everyone step starts with "Everyone". Name the prop by what it becomes (never the \
        household item), at most 9 words, gentle and kid-safe. Return PropWeave (scene and step are the numbers above).
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
                st.text = pretend(st.text, item: u.item, becomes: u.becomes, label: label)
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
                    st.text = replacing(st.text, phrase: u.item, with: p.householdItem.lowercased())
                }
                if p.becomes.caseInsensitiveCompare(u.becomes) != .orderedSame {
                    st.text = replacing(st.text, phrase: KitDraft.cutoutLabel(becomes: u.becomes), with: KitDraft.cutoutLabel(becomes: p.becomes))
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
                return t.replacingOccurrences(of: pattern, with: "pretend " + label, options: .regularExpression)
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

/// The early play guide's answer in a FIXED shape: exactly 6 scenes (scene1 … scene6), each with exactly one step per
/// ranked role (R1 … R6) and two for everyone (all1, all2), as required fields rather than arrays. At low effort the
/// array form sometimes came back cut short (seen live: ONE scene, or scenes with ONE step, about 1 call in 3); a fixed
/// shape can't be. The step's role comes from its field. Decoded into the usual scene list.
public struct KitScenesSix: Decodable, Sendable, SafetyText {
    public var nutmegSays: String
    public var scenes: [Scene]
    public init(nutmegSays: String, scenes: [Scene]) { self.nutmegSays = nutmegSays; self.scenes = scenes }
    public static let count = 6
    static let stepKeys: [(key: String, role: SceneOwner)] = RoleID.allCases.map { ($0.rawValue, SceneOwner($0)) } + [("all1", .all), ("all2", .all)]

    struct Key: CodingKey {
        var stringValue: String; var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
    struct StepBody: Decodable { var picture: Picture?; var text: String }
    struct SceneBody: Decodable {
        var scene: Scene
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            let steps = try KitScenesSix.stepKeys.compactMap { k -> Step? in
                guard let b = try c.decodeIfPresent(StepBody.self, forKey: Key(stringValue: k.key)) else { return nil }
                return Step(picture: b.picture ?? .point, text: b.text, role: k.role)
            }
            scene = Scene(id: try c.decode(String.self, forKey: Key(stringValue: "id")), owner: .all,
                          title: try c.decode(String.self, forKey: Key(stringValue: "title")),
                          picture: try c.decodeIfPresent(Picture.self, forKey: Key(stringValue: "picture")) ?? .point,
                          nutmegSays: try c.decode(String.self, forKey: Key(stringValue: "nutmegSays")), steps: steps)
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        nutmegSays = try c.decode(String.self, forKey: Key(stringValue: "nutmegSays"))
        scenes = try (1...Self.count).compactMap { try c.decodeIfPresent(SceneBody.self, forKey: Key(stringValue: "scene\($0)"))?.scene }
    }

    public static func schema() -> [String: Any] {
        let step = Schemas.obj(["picture": ["$ref": "#/$defs/picture"], "text": Schemas.str])
        var sceneProps: [String: Any] = ["id": Schemas.str, "title": Schemas.str, "picture": ["$ref": "#/$defs/picture"], "nutmegSays": Schemas.str]
        for k in stepKeys {
            var st = ["$ref": "#/$defs/step"] as [String: Any]
            st["description"] = k.role == .all ? "A step for everyone together (text starts with \"Everyone\")."
                : "The \(k.key) role's own step (its text starts with that role's title)."
            sceneProps[k.key] = st
        }
        var props: [String: Any] = ["nutmegSays": Schemas.str]
        for i in 1...count { props["scene\(i)"] = ["$ref": "#/$defs/scene"] }
        var o = Schemas.obj(props)
        // One definition each (6 inline copies compile too large: the API refuses the grammar).
        // No props yet, so the picture is an action or a printed kit item (a short enum; the props' pictures come
        // with the weave).
        let picture: [String: Any] = ["type": "object", "description": "The ONE picture: kind action (id an action id) or kind kit "
            + "(id a printed item of THIS kit: ticket, money, menu, sign, badge:R1..R6, cutout:N for the Nth cutouts line).",
            "properties": ["kind": Schemas.enumStr([PictureKind.action.rawValue, PictureKind.kit.rawValue]),
                           "id": Schemas.enumStr(ActionArt.ids + PictureResolver.kitIDs)],
            "required": ["id", "kind"], "additionalProperties": false]
        o["$defs"] = ["scene": Schemas.obj(sceneProps), "step": step, "picture": picture]
        return o
    }
    public var safetyTexts: [String] { [nutmegSays] + scenes.flatMap { [$0.title, $0.nutmegSays] + $0.steps.map(\.text) } }
}
