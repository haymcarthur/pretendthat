import Foundation

// Round 36 (Haylee, decisions/2026-11-16-story-setup-cleanup-scenes.md): the game's arc is
// Print → STORY → SETUP scene → the 3 play scenes → CLEAN-UP scene → The End.
//
// How it is built (Claude's calls, decisions/2026-11-16-round36-story-setup-cleanup-build.md):
// - The guide call writes the story, the setup and clean-up scenes' titles and "Pretend that" lines, and ONE job per
//   printed page (what to do with it at setup, and how to tidy it at clean-up). Each household prop's jobs come with
//   its weave call (the props aren't known when the guide is written: the kids are still hunting).
// - The setup and clean-up ROWS are composed here, per player count, from those item jobs (`Bookends.compose`), so
//   every count from 1 to 6 uses every prop and every page with no AI call (the same rule as the play scenes).
// - `SetupCoverage` checks it: every found / swapped prop and every printed page is named by a setup task (badges by
//   the setup's opening line), or, when there are more items than a role can take, by a task the same players see in
//   a play scene. An item no play task names always goes into a setup task (a role then gets 2 or 3 items).
// - A job the AI left out or got wrong is asked for once more (`PhaseService.itemJobs`), else written by the app
//   (`Bookends.repair`, deterministic).

/// Where a scene sits in the game's arc.
public enum SceneKind: String, Codable, Sendable, CaseIterable { case story, setup, play, cleanup }

extension Kit {
    /// The play scenes only (the players' view also has the story, setup and clean-up scenes).
    public var playScenes: [Scene] { scenes.filter { $0.arc == .play } }
}

/// One item's job in the setup or the clean-up scene: an imperative phrase with no role title ("hang the Sunny Bakery
/// sign by the door"), its short row text ("Hang up the sign"), and the role it suits best.
public struct ItemJob: Codable, Equatable, Sendable {
    /// "page:<recipe>" (a printed page) or "prop:<prop id>" (a household prop).
    public var item: String
    public var short: String
    public var say: String
    public var role: RoleID?
    /// A prop job: the prop as it was when the job was written (a later swap or skip is applied at compose time).
    public var householdItem: String?
    public var becomes: String?
    public init(item: String, short: String, say: String, role: RoleID? = nil, householdItem: String? = nil, becomes: String? = nil) {
        self.item = item; self.short = short; self.say = say; self.role = role; self.householdItem = householdItem; self.becomes = becomes
    }
}

/// The setup or the clean-up scene as written: its title, its "Pretend that" line and the item jobs.
public struct Bookend: Codable, Equatable, Sendable {
    public var title: String
    public var nutmegSays: String
    public var jobs: [ItemJob]
    public init(title: String, nutmegSays: String, jobs: [ItemJob] = []) { self.title = title; self.nutmegSays = nutmegSays; self.jobs = jobs }
    public static let empty = Bookend(title: "", nutmegSays: "")
    public func job(_ item: String) -> ItemJob? { jobs.first { $0.item == item } }
    /// Adds or replaces the job for its item.
    public mutating func put(_ j: ItemJob) {
        if let i = jobs.firstIndex(where: { $0.item == j.item }) { jobs[i] = j } else { jobs.append(j) }
    }
}

/// Something that has to be used on purpose: a printed page or a household prop the kids really have.
public struct CoverItem: Equatable, Sendable {
    /// "page:<recipe>" or "prop:<prop id>".
    public var id: String
    /// What it's called on screen and in speech ("the Sky Dollars", "the airplane seats").
    public var label: String
    /// Words that count as naming it in a task.
    public var names: [String]
    /// The page's stated purpose, or the prop's reason.
    public var purpose: String?
    public var recipe: KitRecipe?
    public var prop: Prop?
}

public enum Bookends {
    /// Setup rows aim for this many items per role (Claude's call: one easy task; two items when there are more items
    /// than roles; a solo kid three). An item no play task names may push a role one past it.
    public static func setupTarget(players n: Int) -> Int { PlayCast.players(n) == 1 ? 3 : 2 }
    /// A job's spoken phrase: at most this many words (a quick setup action).
    public static let maxJobWords = 22
    public static let maxShortWords = 6

    public static func pageID(_ r: KitRecipe) -> String { "page:\(r.rawValue)" }
    public static func propID(_ id: String) -> String { "prop:\(id)" }

    // MARK: What has to be used

    /// Every printed page (by recipe) and every prop the kids have (found or swapped; a skipped prop is a printed
    /// cut-out, which the cut-outs page covers).
    public static func coverItems(items: [KitItem], props: [Prop]) -> [CoverItem] {
        var out: [CoverItem] = []
        for r in KitRecipe.allCases {
            guard let item = items.first(where: { $0.recipe == r }) else { continue }
            out.append(CoverItem(id: pageID(r), label: pageLabel(item), names: pageNames(item), purpose: item.purpose, recipe: r))
        }
        for p in props where !p.isSkipped {
            out.append(CoverItem(id: propID(p.id), label: "the " + KitDraft.cutoutLabel(becomes: p.becomes).lowercased(),
                                 names: propNames(p), purpose: p.reason, prop: p))
        }
        return out
    }

    /// The setup scene's items: every cover item except the badges (the setup's opening line has everyone put theirs on).
    public static func setupItems(items: [KitItem], props: [Prop]) -> [CoverItem] {
        coverItems(items: items, props: props).filter { $0.recipe != .badges }
    }

    static func pageLabel(_ item: KitItem) -> String {
        var t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("the ") { t = String(t.dropFirst(4)) }   // "The Starry Moon Ship" → "the Starry Moon Ship sign"
        switch item.recipe {
        case .badges: return "your badge"
        case .cutouts: return "the cut-outs"
        case .sign: return t.isEmpty ? "the sign" : (t.lowercased().contains("sign") ? "the \(t)" : "the \(t) sign")
        default: return t.isEmpty ? "the \(item.recipe?.rawValue ?? "page")" : "the \(t)"
        }
    }

    static func pageNames(_ item: KitItem) -> [String] {
        var names: [String] = []
        switch item.recipe {
        case .badges: names = ["badge", "badges", "name tag"]
        case .sign: names = ["sign"]
        case .money: names = ["money", "bucks", "dollars", "dollar", "bills", "bill", "coins", "cash", "tokens"]
        case .tickets: names = ["ticket", "tickets", "pass", "passes", "keycard", "keycards", "card", "cards", "boarding pass"]
        case .menu: names = ["menu", "menus", "price list", "price lists"]
        case .cutouts: names = ["cut-out", "cut-outs", "cutout", "cutouts", "cut out"] + item.lines
        case nil: break
        }
        let t = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty, item.recipe != .badges { names.append(t) }
        return names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    static func propNames(_ p: Prop) -> [String] {
        let label = KitDraft.cutoutLabel(becomes: p.becomes)
        var names = [label, p.householdItem]
        // "Airplane seats" → "seats" (tasks often shorten it); only a real word.
        if let last = label.split(separator: " ").last.map(String.init), last.count >= 4, last.lowercased() != label.lowercased() { names.append(last) }
        return names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Whether `text` names the item (whole words, any case, a plural "s" allowed).
    public static func mentions(_ text: String, _ item: CoverItem) -> Bool {
        item.names.contains { mentions(text, name: $0) }
    }
    static func mentions(_ text: String, name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return false }
        let pattern = #"(?i)(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: n) + #"(?:s|es)?(?![\p{L}\p{N}])"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: Checking and repairing the jobs

    /// Whether a job is usable for this item: a short imperative phrase that names the item.
    public static func isValid(_ job: ItemJob?, for item: CoverItem) -> Bool {
        guard let j = job else { return false }
        let say = j.say.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = say.split(whereSeparator: \.isWhitespace).count
        let shortWords = j.short.split(whereSeparator: \.isWhitespace).count
        return words >= 2 && words <= maxJobWords && shortWords >= 1 && shortWords <= maxShortWords + 2
            && !say.contains("\"") && mentions(say, item)
    }

    /// The items whose setup or clean-up job is missing or unusable (what a re-ask asks for).
    public static func missingJobs(_ kit: Kit, props: [Prop]) -> (setup: [CoverItem], cleanup: [CoverItem]) {
        let setupItems = setupItems(items: kit.items, props: props)
        let cleanItems = coverItems(items: kit.items, props: props)
        let s = setupItems.filter { !isValid(kit.setup?.job($0.id).map { transformed($0, props: props) }, for: $0) }
        let c = cleanItems.filter { !isValid(kit.cleanup?.job($0.id).map { transformed($0, props: props) }, for: $0) }
        return (s, c)
    }

    /// Fills every missing or unusable job (and an empty title, line or story) with one the app writes. Idempotent.
    /// Only for a kit that has the arc (an older saved game stays as it was). Returns the kit and what was repaired.
    public static func repair(_ kit: Kit, props: [Prop], roles: [Role], title gameTitle: String) -> (kit: Kit, repaired: [String]) {
        guard kit.hasBookends else { return (kit, []) }
        var k = kit, fixed: [String] = []
        var setup = k.setup ?? .empty, cleanup = k.cleanup ?? .empty
        let place = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if setup.title.trimmingCharacters(in: .whitespaces).isEmpty || GuideRepair.isPlaceholderTitle(setup.title) {
            setup.title = "Getting Ready"; fixed.append("setup title")
        }
        if !PretendLine.has(setup.nutmegSays) {
            setup.nutmegSays = "Pretend that \(place.isEmpty ? "the show" : "the " + place) opens in just a minute, so let's get everything ready!"
            fixed.append("setup line")
        }
        if cleanup.title.trimmingCharacters(in: .whitespaces).isEmpty || GuideRepair.isPlaceholderTitle(cleanup.title) {
            cleanup.title = "Clean-Up Time"; fixed.append("clean-up title")
        }
        if !PretendLine.has(cleanup.nutmegSays) {
            cleanup.nutmegSays = "Pretend that \(place.isEmpty ? "the show" : "the " + place) is closing for the night, so let's put everything away!"
            fixed.append("clean-up line")
        }
        let story = (k.story ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !isValidStory(story) {
            k.story = fallbackStory(title: place, roles: roles); fixed.append("story")
        }
        for item in setupItems(items: k.items, props: props) where !isValid(setup.job(item.id).map { transformed($0, props: props) }, for: item) {
            setup.put(fallbackSetup(item)); fixed.append("setup \(item.id)")
        }
        for item in coverItems(items: k.items, props: props) where !isValid(cleanup.job(item.id).map { transformed($0, props: props) }, for: item) {
            cleanup.put(fallbackCleanup(item)); fixed.append("clean-up \(item.id)")
        }
        k.setup = setup; k.cleanup = cleanup
        return (k, fixed)
    }

    /// Puts AI-written jobs into the kit where its job for that item is missing or unusable (a good job already there
    /// stays). `item` is a cover id ("page:sign" / "prop:bowl") or a bare prop id (the weave's answer).
    public static func merge(_ answer: [ItemJobs.Job], into kit: Kit, props: [Prop]) -> Kit {
        var k = ensure(kit)
        let all = coverItems(items: k.items, props: props)
        for j in answer {
            let id = j.item.contains(":") ? j.item : propID(j.item)
            guard let item = all.first(where: { $0.id == id }) else { continue }
            let two = j.jobs(id: id, prop: item.prop)
            if item.recipe != .badges, !isValid(k.setup?.job(id).map { transformed($0, props: props) }, for: item), isValid(two.setup, for: item) {
                k.setup?.put(two.setup)
            }
            if !isValid(k.cleanup?.job(id).map { transformed($0, props: props) }, for: item), isValid(two.cleanup, for: item) {
                k.cleanup?.put(two.cleanup)
            }
        }
        return k
    }

    /// The items to re-ask about (setup or clean-up job missing / unusable), each once.
    public static func toReask(_ kit: Kit, props: [Prop]) -> [CoverItem] {
        let m = missingJobs(kit, props: props)
        var seen = Set<String>(), out: [CoverItem] = []
        for it in m.setup + m.cleanup where seen.insert(it.id).inserted { out.append(it) }
        return out
    }

    /// A new game's kit always has the arc: missing parts are written by `repair`.
    public static func ensure(_ kit: Kit) -> Kit {
        var k = kit
        if k.setup == nil { k.setup = .empty }
        if k.cleanup == nil { k.cleanup = .empty }
        if k.story == nil { k.story = "" }
        return k
    }

    public static func isValidStory(_ s: String) -> Bool {
        let words = s.split(whereSeparator: \.isWhitespace).count
        let sentences = PlayCast.sentences(s).count
        return words >= 12 && words <= 75 && sentences >= 2 && sentences <= 6 && !s.contains("\"")
    }

    static func fallbackStory(title: String, roles: [Role]) -> String {
        let place = title.isEmpty ? "our show" : "the " + title
        let lead = roles.first?.roleName ?? "star"
        return "Welcome to \(place)! Today you are the \(lead) and the crew, and everyone is counting on you. "
            + "First we'll set everything up, and then the big adventure begins!"
    }

    static func fallbackSetup(_ item: CoverItem) -> ItemJob {
        let label = item.label
        let (short, say): (String, String)
        switch item.recipe {
        case .sign: (short, say) = ("Hang up the sign", "hang up \(label) where everyone can see it")
        case .money: (short, say) = ("Stack the money", "stack \(label) in a neat pile, ready to pay")
        case .tickets: (short, say) = ("Set out the tickets", "set out \(label) by the door")
        case .menu: (short, say) = ("Set out the menu", "put \(label) where everyone can read it")
        case .cutouts: (short, say) = ("Line up the cut-outs", "line up the cut-outs on a table")
        case .badges: (short, say) = ("Put on your badge", "put on your badge")
        case nil:
            let name = item.prop.map { KitDraft.cutoutLabel(becomes: $0.becomes).lowercased() } ?? label
            (short, say) = (capFirst("set up the \(name)"), "put the \(name) in its spot")
        }
        return ItemJob(item: item.id, short: short, say: say, role: item.prop?.forRole.role,
                       householdItem: item.prop?.householdItem, becomes: item.prop?.becomes)
    }

    static func fallbackCleanup(_ item: CoverItem) -> ItemJob {
        let (short, say): (String, String)
        switch item.recipe {
        case .sign: (short, say) = ("Take down the sign", "take down the sign and lay it flat")
        case .money: (short, say) = ("Gather the money", "gather up all the money in one pile")
        case .tickets: (short, say) = ("Collect the tickets", "collect the tickets in a pile")
        case .menu: (short, say) = ("Fold up the menu", "fold up the menu and put it with the pages")
        case .cutouts: (short, say) = ("Stack the cut-outs", "stack the cut-outs in a neat pile")
        case .badges: (short, say) = ("Collect the badges", "take off your badge and put it in the pile")
        case nil:
            let thing = (item.prop?.householdItem ?? "prop").lowercased()
            (short, say) = ("Put the \(thing) away", "put the \(thing) back where it lives")
        }
        return ItemJob(item: item.id, short: short, say: say, role: item.prop?.forRole.role,
                       householdItem: item.prop?.householdItem, becomes: item.prop?.becomes)
    }

    // MARK: A prop job as the props are now

    /// A prop job written for one household item, said with the props as they are now: a swap names the new item
    /// (same rule as the play guide: only where the job named the old item itself). A page job is unchanged.
    public static func transformed(_ job: ItemJob, props: [Prop]) -> ItemJob {
        guard job.item.hasPrefix("prop:"), let oldItem = job.householdItem else { return job }
        let pid = String(job.item.dropFirst(5))
        guard let p = props.first(where: { $0.id == pid }) else { return job }
        var j = job
        if p.householdItem.caseInsensitiveCompare(oldItem) != .orderedSame {
            j.say = GuideWeave.replacing(j.say, phrase: oldItem, with: p.householdItem.lowercased())
            j.short = GuideWeave.replacing(j.short, phrase: oldItem, with: p.householdItem.lowercased())
        }
        if let oldBecomes = job.becomes, p.becomes.caseInsensitiveCompare(oldBecomes) != .orderedSame {
            let o = KitDraft.cutoutLabel(becomes: oldBecomes), n = KitDraft.cutoutLabel(becomes: p.becomes)
            j.say = GuideWeave.replacing(j.say, phrase: o, with: n)
            j.short = GuideWeave.replacing(j.short, phrase: o, with: n)
        }
        return j
    }

    // MARK: Composing the scenes the players see

    /// The whole arc for N players: the story (no rows), the setup scene, the play scenes (as given, already for N),
    /// the clean-up scene. A kit without the arc (a game saved before round 36) is its play scenes, as it was.
    public static func compose(_ k: Kit, play: [Scene], roles: [Role], players n: Int, props: [Prop]) -> [Scene] {
        guard k.hasBookends, !roles.isEmpty else { return play }
        var out: [Scene] = []
        if let story = k.story?.trimmingCharacters(in: .whitespacesAndNewlines), !story.isEmpty {
            out.append(Scene(id: "story", owner: .all, title: k.setup?.title ?? "", picture: .point, nutmegSays: story, steps: [], kind: .story))
        }
        if let s = k.setup { out.append(setupScene(s, kit: k, play: play, roles: roles, players: n, props: props)) }
        out += play
        if let c = k.cleanup { out.append(cleanupScene(c, kit: k, roles: roles, players: n, props: props)) }
        return out
    }

    /// The setup's opening adds the badges (every kid puts theirs on: a clear purpose for the badge page).
    public static func badgeLine(players n: Int) -> String {
        PlayCast.players(n) == 1 ? "Put on your badge first!" : "Everyone, put on your badge first!"
    }

    /// Which roles get which setup items for N players (item ids in item order per role). Pure, deterministic.
    public static func setupAssignment(items: [CoverItem], jobs: [String: ItemJob], play: [Scene], roles: [Role], players n: Int) -> [(role: Role, items: [String])] {
        let playing = RoleCast.playing(roles, kids: n)
        guard !playing.isEmpty else { return [] }
        let visible = play.flatMap(\.steps).map(\.text)
        let inPlay = Set(items.filter { it in visible.contains { mentions($0, it) } }.map(\.id))
        let cap = setupTarget(players: n)
        let target = min(cap, max(1, Int((Double(items.count) / Double(playing.count)).rounded(.up))))
        var load: [RoleID: [String]] = [:]
        func count(_ r: RoleID) -> Int { load[r]?.count ?? 0 }
        func leastLoaded(_ pool: [Role]) -> Role? { pool.min { count($0.id) < count($1.id) || (count($0.id) == count($1.id) && $0.id.rank < $1.id.rank) } }
        func preferred(_ id: String) -> Role? { jobs[id]?.role.flatMap { r in playing.first { $0.id == r } } }
        // 1) Items no play task names MUST be set up (a role may go one past the target, or more for a solo kid).
        for it in items where !inPlay.contains(it.id) {
            let r = preferred(it.id).flatMap { count($0.id) < cap ? $0 : nil } ?? leastLoaded(playing)!
            load[r.id, default: []].append(it.id)
        }
        // 2) Every role gets at least one item, then the rest fill up to the target (the others are used in play).
        for it in items where inPlay.contains(it.id) {
            let empty = playing.filter { count($0.id) == 0 }
            let r: Role?
            if !empty.isEmpty {
                r = preferred(it.id).flatMap { count($0.id) == 0 ? $0 : nil } ?? empty.first
            } else {
                let room = playing.filter { count($0.id) < target }
                r = preferred(it.id).flatMap { count($0.id) < target ? $0 : nil } ?? leastLoaded(room)
            }
            guard let r else { continue }
            load[r.id, default: []].append(it.id)
        }
        let order = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
        return playing.map { r in (r, (load[r.id] ?? []).sorted { (order[$0] ?? 0) < (order[$1] ?? 0) }) }
    }

    static func setupScene(_ b: Bookend, kit: Kit, play: [Scene], roles: [Role], players n: Int, props: [Prop]) -> Scene {
        let items = setupItems(items: kit.items, props: props)
        var jobs: [String: ItemJob] = [:]
        for it in items {
            let j = b.job(it.id).map { transformed($0, props: props) }
            jobs[it.id] = isValid(j, for: it) ? j : fallbackSetup(it)
        }
        let plan = setupAssignment(items: items, jobs: jobs, play: play, roles: roles, players: n)
        let steps = plan.map { row -> Step in
            let js = row.items.compactMap { jobs[$0] }
            return task(js, role: row.role, roles: roles, players: n, filler: "check that everything is ready and give a big thumbs up")
        }
        let line = PlayCast.sceneLine(b.nutmegSays, roles: roles, players: n)
        return Scene(id: "setup", owner: .all, title: PlayCast.unname(b.title, roles: roles, players: PlayCast.players(n), title: true),
                     picture: .point, nutmegSays: PlayCast.endSentence(line.trimmingCharacters(in: .whitespacesAndNewlines)) + " " + badgeLine(players: n),
                     steps: steps, kind: .setup)
    }

    /// The clean-up rows: every prop the kids have goes back (props spread over the roles, the role it suits first);
    /// a role with no prop tidies a printed page.
    public static func cleanupAssignment(items: [CoverItem], jobs: [String: ItemJob], roles: [Role], players n: Int) -> [(role: Role, items: [String])] {
        let playing = RoleCast.playing(roles, kids: n)
        guard !playing.isEmpty else { return [] }
        var load: [RoleID: [String]] = [:]
        func count(_ r: RoleID) -> Int { load[r]?.count ?? 0 }
        func leastLoaded(_ pool: [Role]) -> Role? { pool.min { count($0.id) < count($1.id) || (count($0.id) == count($1.id) && $0.id.rank < $1.id.rank) } }
        func preferred(_ id: String) -> Role? { jobs[id]?.role.flatMap { r in playing.first { $0.id == r } } }
        let propItems = items.filter { $0.prop != nil }
        let target = max(1, Int((Double(propItems.count) / Double(playing.count)).rounded(.up)))
        for it in propItems {
            let r = preferred(it.id).flatMap { count($0.id) < target ? $0 : nil } ?? leastLoaded(playing)!
            load[r.id, default: []].append(it.id)
        }
        // Roles with nothing to put away tidy a page (each page once; the badges last: everyone has one).
        var pages = items.filter { $0.recipe != nil }.sorted { ($0.recipe == .badges ? 1 : 0) < ($1.recipe == .badges ? 1 : 0) }
        for r in playing where count(r.id) == 0 {
            guard !pages.isEmpty else { break }
            let k = pages.firstIndex { jobs[$0.id]?.role == r.id } ?? 0
            load[r.id, default: []].append(pages.remove(at: k).id)
        }
        return playing.map { ($0, load[$0.id] ?? []) }
    }

    static func cleanupScene(_ b: Bookend, kit: Kit, roles: [Role], players n: Int, props: [Prop]) -> Scene {
        let items = coverItems(items: kit.items, props: props)
        var jobs: [String: ItemJob] = [:]
        for it in items {
            let j = b.job(it.id).map { transformed($0, props: props) }
            jobs[it.id] = isValid(j, for: it) ? j : fallbackCleanup(it)
        }
        let plan = cleanupAssignment(items: items, jobs: jobs, roles: roles, players: n)
        let steps = plan.map { row in
            task(row.items.compactMap { jobs[$0] }, role: row.role, roles: roles, players: n, filler: "give everyone a big high five for a great show")
        }
        let line = PlayCast.sceneLine(b.nutmegSays, roles: roles, players: n)
        return Scene(id: "cleanup", owner: .all, title: PlayCast.unname(b.title, roles: roles, players: PlayCast.players(n), title: true),
                     picture: .point, nutmegSays: line, steps: steps, kind: .cleanup)
    }

    /// One role's row from its item jobs: "Head Baker, hang the sign by the door and put the mixing bowl on the counter!"
    static func task(_ jobs: [ItemJob], role: Role, roles: [Role], players n: Int, filler: String) -> Step {
        let phrases = jobs.map { trimEnd($0.say) }.filter { !$0.isEmpty }.map(PlayCast.lowerFirst)
        let says = phrases.isEmpty ? [filler] : phrases
        // "A, then B" / "A, B, then C" (phrases often contain "and" themselves); more than 3 (a solo kid with many
        // items) goes on in a second sentence.
        let text = says.count <= 3 ? "\(role.roleName), \(steps(says))!"
            : "\(role.roleName), \(steps(Array(says.prefix(3))))! After that, \(steps(Array(says.dropFirst(3))))!"
        let shorts = jobs.map { trimEnd($0.short) }.filter { !$0.isEmpty }
        var short: String
        let joined = list(shorts.enumerated().map { $0.offset == 0 ? capFirst($0.element) : PlayCast.lowerFirst($0.element) })
        if shorts.isEmpty { short = capFirst(says[0].split(separator: " ").prefix(5).joined(separator: " ")) }
        else if joined.split(separator: " ").count <= 8 { short = joined }
        else { short = capFirst(shorts[0]) + " and more" }
        // Roles that aren't playing become "a friend" (a solo kid's jobs are left as written, like the solo play task:
        // they may speak of pretend passengers).
        let n = PlayCast.players(n)
        if n > 1 { short = PlayCast.unname(short, roles: roles, players: n) }
        let say = n > 1 ? PlayCast.unname(text, roles: roles, players: n) : text
        return Step(picture: .point, text: say, role: SceneOwner(role.id), short: short)
    }

    static func steps(_ xs: [String]) -> String {
        switch xs.count {
        case 0: return ""
        case 1: return xs[0]
        default: return xs.dropLast().joined(separator: ", ") + ", then " + xs.last!
        }
    }

    static func list(_ xs: [String]) -> String {
        switch xs.count {
        case 0: return ""
        case 1: return xs[0]
        case 2: return xs[0] + " and " + xs[1]
        default: return xs.dropLast().joined(separator: ", ") + ", and " + xs.last!
        }
    }
    static func trimEnd(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?,;"))
    }
    static func capFirst(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    // MARK: Safety text

    /// Every text of the arc (the kid-safety check runs on it with the guide).
    public static func safetyTexts(_ k: Kit) -> [String] {
        var t: [String] = []
        if let s = k.story { t.append(s) }
        for b in [k.setup, k.cleanup].compactMap({ $0 }) { t += [b.title, b.nutmegSays] + b.jobs.flatMap { [$0.short, $0.say] } }
        return t.filter { !$0.isEmpty }
    }
}

// MARK: - The coverage check (Haylee: every prop and every printed item is used on purpose)

public enum SetupCoverage {
    /// Where one item is used, for N players: "setup R2" / "setup (opening)" / "scene 2 R1".
    public struct Use: Equatable, Sendable { public var item: String; public var label: String; public var places: [String] }

    /// Every cover item and where the players see it used in the setup scene or a play scene (`scenes` = the composed
    /// arc for N players). An item with no places is unused.
    public static func map(_ scenes: [Scene], items: [CoverItem], roles: [Role]) -> [Use] {
        var playNo = 0
        var found: [String: [String]] = [:]
        func roleName(_ s: Step) -> String { s.role.role.flatMap { r in roles.first { $0.id == r }?.roleName } ?? s.role.rawValue }
        for sc in scenes {
            switch sc.arc {
            case .story, .cleanup: continue
            case .setup:
                for it in items where Bookends.mentions(sc.nutmegSays, it) && it.recipe == .badges { found[it.id, default: []].append("setup (opening)") }
                for st in sc.steps { for it in items where Bookends.mentions(st.text, it) { found[it.id, default: []].append("setup \(roleName(st))") } }
            case .play:
                playNo += 1
                for st in sc.steps { for it in items where Bookends.mentions(st.text, it) { found[it.id, default: []].append("scene \(playNo) \(roleName(st))") } }
            }
        }
        return items.map { Use(item: $0.id, label: $0.label, places: found[$0.id] ?? []) }
    }

    /// The items nobody uses for these N players (empty = the rule holds).
    public static func missing(_ scenes: [Scene], items: [CoverItem], roles: [Role]) -> [String] {
        map(scenes, items: items, roles: roles).filter(\.places.isEmpty).map(\.item)
    }

    /// The items not named by a SETUP task (or the setup's opening): fine only when a play task names them.
    public static func notInSetup(_ scenes: [Scene], items: [CoverItem], roles: [Role]) -> [String] {
        map(scenes, items: items, roles: roles).filter { !$0.places.contains { $0.hasPrefix("setup") } }.map(\.item)
    }

    /// One log line per item: "page:sign (the Sunny Sign) → setup Head Baker".
    public static func log(_ scenes: [Scene], items: [CoverItem], roles: [Role]) -> [String] {
        map(scenes, items: items, roles: roles).map { "\($0.item) (\($0.label)) → " + ($0.places.isEmpty ? "UNUSED" : $0.places.joined(separator: ", ")) }
    }
}
