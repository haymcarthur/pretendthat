import Foundation

// Round 25 (Haylee's "magic bakery" bug): a saved round 24 Draw it! game had a play guide of ONE scene titled "x" whose
// role steps used none of the props. The draw path wrote its guide after the hunt with the array-form schema at low
// effort (cut short about 1 call in 3, the guide-prefetch finding), never ran the prop weave, and `Validate.scenes`
// let a short, placeholder-titled answer through after its one retry (non-fatal). With one scene, a replay at 2 kids
// rotated to nobody: scene 1 belongs to R1, and there was no scene 2 for R2.
//
// `GuideRepair` is the last line of defense, with NO AI call (it runs on replays too): every scene gets a real title,
// a guide with fewer than `minScenes` scenes gets template scenes (round 29: a task per role from the role's job, a
// solo task, a "Pretend that" intro), scripted lines are taken out, every prop that no task uses is worked into a
// role's task by what it becomes, and only real objects are named. It is idempotent: a good guide comes back unchanged.
public enum GuideRepair {
    /// A guide is padded to this many scenes (round 29: the guide has exactly 3).
    public static let minScenes = 3

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

    /// The repaired guide (see the type comment). `roles` = the 6 ranked roles; `props` = the game's props; `items` =
    /// the printed pages (round 28: tasks may name only the props, the printed kit and body actions, `realProps`).
    public static func repair(_ scenes: [Scene], roles: [Role], props: [Prop], title: String, items: [KitItem] = []) -> [Scene] {
        guard !scenes.isEmpty else { return scenes }
        var out = scenes
        // 1. Real titles.
        var used = Set(out.map { $0.title.lowercased() })
        for i in out.indices where isPlaceholderTitle(out[i].title) {
            let t = titles.first { !used.contains($0.lowercased()) } ?? "\(title) Fun"
            out[i].title = t; used.insert(t.lowercased())
        }
        // 2. Enough scenes (round 29: 3), each a task per role from the role's job plus a solo task.
        var k = 0
        while out.count < minScenes {
            let t = titles.first { !used.contains($0.lowercased()) } ?? "More \(title) Fun"
            used.insert(t.lowercased())
            let tasks = roles.prefix(RoleCast.count).map(PlayCast.filler) + (roles.first.map { [PlayCast.soloFiller($0)] } ?? [])
            out.append(Scene(id: "repair\(k + 1)", owner: .all, title: t, picture: .point,
                             nutmegSays: intros[k % intros.count], steps: tasks))
            k += 1
        }
        // 3. Round 29: tasks may imply talking but never script lines (no quotes, no "Say:").
        out = noScriptedLines(out)
        // 4. Every prop in the tasks.
        out = weave(out, roles: roles, props: props)
        // 5. Round 28: only objects the kids really have.
        return realProps(out, roles: roles, props: props, items: items)
    }

    /// Whether a step already uses this prop (its picture, or its words name what it becomes or the item).
    static func uses(_ step: Step, _ p: Prop) -> Bool {
        if let lib = p.libraryID, step.picture == .prop(lib) { return true }
        if step.picture == .prop(p.id) { return true }
        let label = KitDraft.cutoutLabel(becomes: p.becomes)
        return (!label.isEmpty && PlayCast.names(step.text, label)) || PlayCast.names(step.text, p.householdItem)
    }

    /// Props that no task uses are worked in (round 29: ONE task each, so the task keeps its interaction): R1's task in
    /// any scene (R1 always plays, so every count sees it), else R2's, else the prop's own role, …; and that scene's
    /// solo task too, so a kid playing alone uses it. A short task gets "with the <prop>" added ("Waiter, take the
    /// order with the serving tray!"); a task that already has two parts is rewritten around the prop.
    static func weave(_ scenes: [Scene], roles: [Role], props: [Prop]) -> [Scene] {
        var out = scenes
        let missing = props.filter { p in !out.contains { $0.steps.contains { uses($0, p) } } }
        guard !missing.isEmpty else { return out }
        func taken(_ s: Step) -> Bool { props.contains { uses(s, $0) } }
        for (n, p) in missing.enumerated() {
            let cut = KitDraft.cutoutLabel(becomes: p.becomes)
            let label = cut.isEmpty ? p.householdItem.lowercased() : PlayCast.lowerFirst(cut)
            let thing = p.isSkipped ? "pretend \(label)" : label
            let pic: Picture = p.isSkipped ? .point : .prop(p.libraryID ?? p.id)
            // R1 always plays and R2 whenever two do, so a found prop is used at (almost) every count.
            let order = [RoleID.R1, .R2] + (p.forRole.role.map { [$0] } ?? []) + RoleID.allCases
            var placed = false
            // Roles first, then scenes: R1 in any scene before R2 anywhere (R1 always plays, R2 whenever 2 do).
            for r in order where !placed {
                for off in 0..<out.count where !placed {
                    let si = (n + off) % out.count
                    guard let j = out[si].steps.firstIndex(where: { $0.role.role == r && !taken($0) }),
                          let role = roles.first(where: { $0.id == r }) else { continue }
                    out[si].steps[j].text = withProp(out[si].steps[j].text, thing: thing, role: role.roleName, n: n)
                    out[si].steps[j].picture = pic
                    placed = true
                    if let k = out[si].steps.firstIndex(where: { $0.role == .solo && !taken($0) }), let r1 = roles.first {
                        out[si].steps[k].text = withProp(out[si].steps[k].text, thing: thing, role: r1.roleName, n: n)
                        out[si].steps[k].picture = pic
                    }
                }
            }
        }
        return out
    }

    /// "Waiter, take the order!" → "Waiter, take the order with the serving tray!"; a task that already has two parts
    /// ("… and …", "… then …") becomes "Waiter, grab the serving tray and get busy!".
    static func withProp(_ text: String, thing: String, role: String, n: Int) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = t.last, ".!?".contains(last) { t.removeLast() }
        let twoParts = t.range(of: #"(?i)\b(and|then|while)\b"#, options: .regularExpression) != nil
        if t.isEmpty || twoParts { return "\(role), \(verb(n)) the \(thing) and get busy!" }
        return t + " with the \(thing)!"
    }

    static func verb(_ n: Int) -> String { ["grab", "use", "hold up", "show everyone"][n % 4] }
}

// MARK: - Round 29: no scripted lines

// Haylee (ensemble scenes): a task may imply talking ("take the Customer's order") but never scripts the words: no
// quotes and no "Say:". The prompt asks for that; this is the app-side check, with no AI call: a speaking verb with
// quoted words loses the quote ("greet the guests and say \"Welcome!\"" → "greet the guests"); if nothing would be left,
// the verb stays with "in your own words". Any other quote marks are dropped and the words kept.
extension GuideRepair {
    static let speakingVerbs = "say|says|said|shout|shouts|yell|yells|call out|calls out|ask|asks|announce|announces|"
        + "whisper|whispers|sing|sings|cheer|cheers|tell everyone|tell them|exclaim|reply|answer"

    /// Whether a task scripts lines (quoted words, or "Say:").
    public static func hasScriptedLine(_ text: String) -> Bool {
        text.range(of: #"(?i)\b(say|says)\s*:"#, options: .regularExpression) != nil
            || text.range(of: #"["\x{201C}\x{201D}]"#, options: .regularExpression) != nil
            || text.range(of: #"(?<![\p{L}])['\x{2018}][^'\x{2018}\x{2019}]+['\x{2019}](?![\p{L}])"#, options: .regularExpression) != nil
    }

    /// The task with its scripted words taken out (see the extension comment). A task with none comes back unchanged.
    public static func unscripted(_ text: String) -> String {
        guard hasScriptedLine(text) else { return text }
        var t = text
        let quoted = #"(?:["\x{201C}][^"\x{201C}\x{201D}]*["\x{201D}]|(?<![\p{L}])['\x{2018}][^'\x{2018}\x{2019}]*['\x{2019}](?![\p{L}]))"#
        let verb = "(?:" + speakingVerbs + ")"
        // "Say: Welcome to the shop!" (no quotes): the words run to the end of the sentence.
        let colon = #"(?i)\b(say|says)\s*:\s*[^.!?]*[.!?]?"#
        let patterns = [
            #"(?i),?\s*\b(?:and|then)\s+"# + verb + #"\b[\s,:]*"# + quoted,   // "… and say "Hi""
            #"(?i)\b"# + verb + #"\b[\s,:]*"# + quoted + #"[\s,]*(?:and|then)\s+"#, // "say "Hi" and …"
        ]
        for p in patterns { t = t.replacingOccurrences(of: p, with: " ", options: .regularExpression) }
        // A speaking verb whose quote is the whole action: the verb stays, the words become the kid's own.
        t = t.replacingOccurrences(of: #"(?i)\b("# + speakingVerbs + #")\b[\s,:]*"# + quoted,
                                   with: "$1 it in your own words", options: .regularExpression)
        t = t.replacingOccurrences(of: colon, with: "say it in your own words!", options: .regularExpression)
        // Any quote marks left (a quoted name or word): the words stay.
        t = t.replacingOccurrences(of: #"["\x{201C}\x{201D}]"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<![\p{L}])['\x{2018}]([^'\x{2018}\x{2019}]+)['\x{2019}](?![\p{L}])"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+([,.!?])"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #",\s*([.!?])"#, with: "$1", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = t.last, !".!?".contains(last) { t += "!" }
        return t
    }

    /// Every task without scripted lines (idempotent).
    public static func noScriptedLines(_ scenes: [Scene]) -> [Scene] {
        scenes.map { sc in
            var sc = sc
            sc.steps = sc.steps.map { var st = $0; st.text = unscripted(st.text); return st }
            return sc
        }
    }
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
