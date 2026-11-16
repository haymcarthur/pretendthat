import Foundation

// Round 25 (Haylee's "magic bakery" bug): a saved round 24 Draw it! game had a play guide of ONE scene titled "x" whose
// role steps used none of the props. The draw path wrote its guide after the hunt with the array-form schema at low
// effort (cut short about 1 call in 3, the guide-prefetch finding), never ran the prop weave, and `Validate.scenes`
// let a short, placeholder-titled answer through after its one retry (non-fatal). With one scene, a replay at 2 kids
// rotated to nobody: scene 1 belongs to R1, and there was no scene 2 for R2.
//
// `GuideRepair` is the last line of defense, with NO AI call (it runs on replays too): every scene gets a real title,
// a guide with fewer than `minScenes` scenes gets template scenes (a step per role from the role's job, two group
// steps, a "Pretend that" intro), and every prop that no step uses is worked into a role step (and a group step) by
// what it becomes. It is idempotent: a good guide comes back unchanged.
public enum GuideRepair {
    /// A guide is padded to this many scenes (the schema asks for 6; `Validate.scenes` wants at least 4).
    public static let minScenes = 4

    /// Titles a model writes when it doesn't fill the field in.
    static let placeholders: Set<String> = ["x", "xx", "xxx", "title", "scene", "untitled", "tbd", "todo", "n/a", "na",
                                            "none", "null", "nil", "placeholder", "scene title", "...", "string", "text"]

    /// Whether `title` isn't a real scene title ("x", "", "Title", "Scene 3", "...").
    public static func isPlaceholderTitle(_ title: String) -> Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let letters = t.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if letters < 3 { return true }
        if placeholders.contains(t) { return true }
        return t.range(of: #"^(scene|part|step|title)\s*\d*$"#, options: .regularExpression) != nil
    }

    /// Titles for scenes that need one (by position; one already in the guide is skipped).
    static let titles = ["Let the Fun Begin", "Time to Get Busy", "A Big Surprise", "Teamwork Time", "The Grand Finale",
                         "One More Adventure", "Hooray, We Did It"]
    /// Intros for template scenes ("Pretend that" opens each, round 13).
    static let intros = ["Pretend that something surprising just happened!", "Pretend that everyone needs your help right now!",
                         "Pretend that it's the busiest moment of the day!", "Pretend that it's time for the big finish!"]
    static let groupSteps: [(String, String)] = [("Everyone, give a big cheer!", "cheer"), ("Everyone, clap together!", "clap"),
                                                 ("Everyone, wave to a friend!", "wave"), ("Everyone, take a bow!", "cheer")]

    /// The repaired guide (see the type comment). `roles` = the 6 ranked roles; `props` = the game's props.
    public static func repair(_ scenes: [Scene], roles: [Role], props: [Prop], title: String) -> [Scene] {
        guard !scenes.isEmpty else { return scenes }
        var out = scenes
        // 1. Real titles.
        var used = Set(out.map { $0.title.lowercased() })
        for i in out.indices where isPlaceholderTitle(out[i].title) {
            let t = titles.first { !used.contains($0.lowercased()) } ?? "\(title) Fun"
            out[i].title = t; used.insert(t.lowercased())
        }
        // 2. Enough scenes for the hand-offs to reach every playing role.
        var k = 0
        while out.count < minScenes {
            let t = titles.first { !used.contains($0.lowercased()) } ?? "More \(title) Fun"
            used.insert(t.lowercased())
            let roleSteps = roles.prefix(RoleCast.count).map { PlayCast.filler($0) }
            let g1 = groupSteps[(2 * k) % groupSteps.count], g2 = groupSteps[(2 * k + 1) % groupSteps.count]
            out.append(Scene(id: "repair\(k + 1)", owner: .all, title: t, picture: .action("cheer"),
                             nutmegSays: intros[k % intros.count],
                             steps: roleSteps + [Step(picture: .action(g1.1), text: g1.0), Step(picture: .action(g2.1), text: g2.0)]))
            k += 1
        }
        // 3. Every prop in the steps.
        return weave(out, roles: roles, props: props)
    }

    /// Whether a step already uses this prop (its picture, or its words name what it becomes or the item).
    static func uses(_ step: Step, _ p: Prop) -> Bool {
        if let lib = p.libraryID, step.picture == .prop(lib) { return true }
        if step.picture == .prop(p.id) { return true }
        let label = KitDraft.cutoutLabel(becomes: p.becomes)
        return (!label.isEmpty && PlayCast.names(step.text, label)) || PlayCast.names(step.text, p.householdItem)
    }

    /// Props that no step uses are worked in: R1's step in one scene (R1 always plays, so every count sees it) and a
    /// group step in the next. Steps that already use a prop are left alone.
    static func weave(_ scenes: [Scene], roles: [Role], props: [Prop]) -> [Scene] {
        var out = scenes
        let missing = props.filter { p in !out.contains { $0.steps.contains { uses($0, p) } } }
        guard !missing.isEmpty else { return out }
        func taken(_ s: Step) -> Bool { props.contains { uses(s, $0) } }
        for (n, p) in missing.enumerated() {
            let label = KitDraft.cutoutLabel(becomes: p.becomes).isEmpty ? p.householdItem.lowercased() : KitDraft.cutoutLabel(becomes: p.becomes)
            let thing = p.isSkipped ? "pretend \(label)" : label
            let pic: Picture = p.isSkipped ? .point : .prop(p.libraryID ?? p.id)
            // A role step: R1 first (always playing), then the prop's own role, then the others.
            let order = [RoleID.R1] + (p.forRole.role.map { [$0] } ?? []) + RoleID.allCases
            var placed = false
            for off in 0..<out.count where !placed {
                let si = (n + off) % out.count
                for r in order where !placed {
                    guard let j = out[si].steps.firstIndex(where: { $0.role.role == r && !taken($0) }),
                          let role = roles.first(where: { $0.id == r }) else { continue }
                    out[si].steps[j].text = "\(role.roleName), \(verb(n)) the \(thing)!"
                    out[si].steps[j].picture = pic
                    placed = true
                }
            }
            // And an everyone step in the next scene, so the whole crew plays with it.
            let si = (n + 1) % out.count
            if let j = out[si].steps.firstIndex(where: { $0.role == .all && !taken($0) }) {
                out[si].steps[j].text = "Everyone, take a turn with the \(thing)!"
                out[si].steps[j].picture = pic
            }
        }
        return out
    }

    static func verb(_ n: Int) -> String { ["grab", "use", "hold up", "show everyone"][n % 4] }
}
