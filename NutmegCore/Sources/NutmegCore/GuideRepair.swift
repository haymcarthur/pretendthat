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

    /// The repaired guide (see the type comment). `roles` = the 6 ranked roles; `props` = the game's props; `items` =
    /// the printed pages (round 28: steps may name only the props, the printed kit and body actions, `realProps`).
    public static func repair(_ scenes: [Scene], roles: [Role], props: [Prop], title: String, items: [KitItem] = []) -> [Scene] {
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
            // Round 28: two steps for each role (its own checklist), none for everyone.
            let roleSteps = roles.prefix(RoleCast.count).enumerated().flatMap { j, r in [PlayCast.filler(r), PlayCast.filler2(r, variant: k + j)] }
            out.append(Scene(id: "repair\(k + 1)", owner: .all, title: t, picture: .action("cheer"),
                             nutmegSays: intros[k % intros.count], steps: roleSteps))
            k += 1
        }
        // 3. Every prop in the steps.
        out = weave(out, roles: roles, props: props)
        // 4. Round 28: only objects the kids really have.
        return realProps(out, roles: roles, props: props, items: items)
    }

    /// Whether a step already uses this prop (its picture, or its words name what it becomes or the item).
    static func uses(_ step: Step, _ p: Prop) -> Bool {
        if let lib = p.libraryID, step.picture == .prop(lib) { return true }
        if step.picture == .prop(p.id) { return true }
        let label = KitDraft.cutoutLabel(becomes: p.becomes)
        return (!label.isEmpty && PlayCast.names(step.text, label)) || PlayCast.names(step.text, p.householdItem)
    }

    /// Props that no step uses are worked in: R1's step in one scene (R1 always plays, so every count sees it) and
    /// R2's step in the next (round 28: no steps for everyone any more; a guide that still has one uses it). Steps that
    /// already use a prop are left alone.
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
            // And a second step in the next scene (R2's, or an older guide's everyone step), so more kids use it.
            let si = (n + 1) % out.count
            if let j = out[si].steps.firstIndex(where: { $0.role == .R2 && !taken($0) }), let r2 = roles.first(where: { $0.id == .R2 }) {
                out[si].steps[j].text = "\(r2.roleName), take a turn with the \(thing)!"
                out[si].steps[j].picture = pic
            } else if let j = out[si].steps.firstIndex(where: { $0.role == .all && !taken($0) }) {
                out[si].steps[j].text = "Everyone, take a turn with the \(thing)!"
                out[si].steps[j].picture = pic
            }
        }
        return out
    }

    static func verb(_ n: Int) -> String { ["grab", "use", "hold up", "show everyone"][n % 4] }
}

// MARK: - Round 28: props must be real

// Haylee: a step said "ring the bell" when no bell was ever a prop. Steps may name ONLY objects the kids really have:
// the props found in the hunt (and the pretend stand-ins for the ✗ ones), the printed kit (badges, sign, money,
// tickets, menu, cut-outs, and what's written on them) and body actions. The guide prompt asks for that; this is the
// app-side check, with no AI call: a step that names any other object gets "pretend" in front of it ("ring the
// pretend bell", a pretend action) and its picture stops showing the missing thing.
extension GuideRepair {
    /// Objects a step might name that a kid would need in hand (whole words, singular). Ambiguous verbs (stamp, brush,
    /// mop, drum, whistle, comb, stick) are left out so "stamp your feet" stays a body action.
    static let objects: Set<String> = Set([
        "bell", "wand", "crown", "tiara", "hat", "cap", "helmet", "cup", "mug", "glass", "plate", "bowl", "spoon", "fork",
        "tray", "basket", "bag", "box", "phone", "telephone", "computer", "laptop", "keyboard", "camera", "microphone", "mic",
        "map", "telescope", "binocular", "compass", "wheel", "flag", "broom", "bucket", "shovel", "ladder", "rope", "net",
        "rod", "pole", "sword", "shield", "cape", "mask", "apron", "glasses", "sunglasses", "scarf", "glove", "boot",
        "umbrella", "suitcase", "luggage", "backpack", "wallet", "purse", "register", "scanner", "clipboard", "pencil",
        "pen", "crayon", "marker", "notebook", "envelope", "letter", "package", "parcel", "mailbox", "key", "lock",
        "flashlight", "lantern", "lamp", "blanket", "pillow", "cushion", "chair", "table", "stool", "couch", "sofa", "bed",
        "rug", "mat", "towel", "sheet", "tent", "ball", "balloon", "kite", "guitar", "trumpet", "horn", "doll", "teddy",
        "toy", "book", "coin", "receipt", "stethoscope", "thermometer", "bandage", "mirror", "bottle", "jar", "pitcher",
        "jug", "pot", "pan", "whisk", "tongs", "straw", "napkin", "tablecloth", "vase", "cake", "cookie", "cupcake",
        "pizza", "sandwich", "lemonade", "juice", "tea", "cone", "candy", "lollipop", "treat", "pie", "bread", "muffin",
        "donut", "popcorn", "drink", "snack", "ticket", "badge", "sign", "menu", "money", "dollar", "bill", "cash",
        "stamp", "sticker", "card", "cart", "trolley", "scale", "ruler", "tape", "string", "ribbon", "bow", "gift",
        "present", "wrapping", "bucket", "sponge", "soap", "hose", "brush", "comb", "paintbrush", "paint", "easel",
        "leash", "collar", "bone", "carrot", "food", "seed", "flower", "bouquet", "shell", "rock", "stone", "jewel",
        "gem", "treasure", "chest", "coin", "trophy", "medal", "whistle", "drum", "megaphone", "radio", "remote",
        "seatbelt", "pillowcase", "blanket", "car", "truck", "boat", "rocket", "plane", "train", "bike", "scooter",
    ]).subtracting(["stamp", "brush", "comb", "whistle", "drum", "card", "treat", "present", "wrapping", "food", "drink",
                   "snack", "string", "bow", "rock", "car", "truck", "boat", "rocket", "plane", "train", "bike", "scooter",
                   "chest", "paint", "scale", "tape"])
    /// Every kit has these printed items, whatever their titles (badges, sign, money, tickets, menu, cut-outs).
    static let kitWords: Set<String> = ["badge", "name", "sign", "money", "dollar", "bill", "cash", "ticket", "pass", "keycard",
                                        "menu", "cutout", "cut", "out", "price", "list", "page", "paper"]
    /// Action pictures that show a thing in hand, and the thing ("ring-bell" draws a bell).
    static let actionObjects: [String: String] = ["ring-bell": "bell"]

    /// "Bells" → "bell", "glasses" stays, "boxes" → "box", "berries" → "berry".
    static func singular(_ w: String) -> String {
        if ["glasses", "sunglasses", "binoculars"].contains(w) { return w == "binoculars" ? "binocular" : w }
        if w.hasSuffix("ies"), w.count > 4 { return String(w.dropLast(3)) + "y" }
        if w.hasSuffix("ches") || w.hasSuffix("shes") || w.hasSuffix("xes") || w.hasSuffix("sses") { return String(w.dropLast(2)) }
        if w.hasSuffix("s"), !w.hasSuffix("ss"), w.count > 3 { return String(w.dropLast()) }
        return w
    }

    static func words(_ text: String) -> [String] {
        text.lowercased().split { !($0.isLetter || $0 == "'") }.map { singular(String($0).replacingOccurrences(of: "'s", with: "")) }
    }

    /// The objects the kids really have, as singular words: every word of each prop (its household item, what it
    /// becomes, a pretend stand-in's name too), every word printed on the kit pages, and the kit's item types.
    public static func allowedWords(props: [Prop], items: [KitItem]) -> Set<String> {
        var ok = kitWords
        for p in props {
            for t in [p.householdItem, p.becomes, KitDraft.cutoutLabel(becomes: p.becomes), PropLibrary.name(p.libraryID ?? p.id) ?? ""] {
                ok.formUnion(words(t))
            }
        }
        for i in items { ok.formUnion(words(i.title)); for l in i.lines { ok.formUnion(words(l)) } }
        return ok
    }

    /// The objects a step names that the kids don't have (singular words, in text order). Role titles are skipped
    /// ("Bell Ringer, wave!" names no bell), and so is anything after "pretend" / "imaginary" / "invisible".
    public static func missingObjects(_ text: String, allowed: Set<String>, roles: [Role]) -> [String] {
        var t = text
        for r in roles where !r.roleName.isEmpty {
            t = t.replacingOccurrences(of: "(?i)" + PlayCast.wordPattern(r.roleName), with: " ", options: .regularExpression)
        }
        let lower = t.lowercased()
        let ws = words(t)
        var out: [String] = []
        for (k, w) in ws.enumerated() where objects.contains(w) && !allowed.contains(w) && !out.contains(w) {
            // A word describing a real thing right after it is a modifier ("the cake menu", "a juice ticket").
            if k + 1 < ws.count, allowed.contains(ws[k + 1]), objects.contains(ws[k + 1]) || kitWords.contains(ws[k + 1]) { continue }
            // "pretend to ring a bell" is already a pretend action.
            if let r = lower.range(of: #"(?<![\p{L}])"# + NSRegularExpression.escapedPattern(for: w), options: .regularExpression),
               ["pretend", "imaginary", "invisible", "make-believe"].contains(where: { lower[..<r.lowerBound].contains($0) }) { continue }
            out.append(w)
        }
        return out
    }

    /// The step with every missing object turned into a pretend one ("ring the bell" → "ring the pretend bell") and a
    /// picture that doesn't show a missing thing. A step that names only real things comes back unchanged.
    public static func realStep(_ step: Step, allowed: Set<String>, allowedPropIDs: Set<String>, roles: [Role]) -> Step {
        var st = step
        for w in missingObjects(st.text, allowed: allowed, roles: roles) {
            // The word as written (singular or plural), not already after "pretend".
            let forms = [w, w + "s", w + "es", w.hasSuffix("y") ? String(w.dropLast()) + "ies" : w].map(NSRegularExpression.escapedPattern(for:))
            let pattern = #"(?i)(?<![\p{L}-])(?<!pretend )("# + forms.joined(separator: "|") + #")(?![\p{L}-])"#
            st.text = st.text.replacingOccurrences(of: pattern, with: "pretend $1", options: .regularExpression)
        }
        switch st.picture.kind {
        case .prop:
            let id = st.picture.id.replacingOccurrences(of: "prop:", with: "")
            if !allowedPropIDs.contains(id) { st.picture = .point }
        case .action:
            if let thing = actionObjects[st.picture.id.replacingOccurrences(of: "action:", with: "")], !allowed.contains(thing) {
                st.picture = .point
            }
        case .kit: break
        }
        return st
    }

    /// Round 28: every step names only objects the kids really have (see the extension comment). Idempotent.
    public static func realProps(_ scenes: [Scene], roles: [Role], props: [Prop], items: [KitItem]) -> [Scene] {
        let allowed = allowedWords(props: props, items: items)
        // A prop picture may show a prop the kids found (a ✗ prop shows its printed cut-out instead, or the point).
        let realIDs = Set(props.filter { !$0.isSkipped }.flatMap { [$0.id, $0.libraryID].compactMap { $0 } })
        return scenes.map { sc in
            var sc = sc
            sc.steps = sc.steps.map { realStep($0, allowed: allowed, allowedPropIDs: realIDs, roles: roles) }
            return sc
        }
    }
}
