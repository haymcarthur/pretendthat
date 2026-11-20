import Foundation

// 2026-11-21 (Haylee, decisions/2026-11-21-events-are-scenarios-and-ownership.md): setup checklists can't repeat jobs
// across roles (kids fight over who does what). Likely root cause in the first build: the jobs written for the hidden
// roles 5–6 were folded into visible cards, next to the guide's own job for the same thing. Now the APP decides: for
// the playing count N, every found prop and every printed page (the badges aside: each kid puts on their own, said in
// the setup cue) gets exactly ONE playing owner (a fair spread, deterministic), and the setup cards are composed so
// each object is in exactly one visible card. The clean-up uses the same owners for the props.

public enum ObjectOwners {
    /// The objects that get an owner: every printed page except the badges, and every prop the kids have.
    public static func objects(_ items: [CoverItem]) -> [CoverItem] { items.filter { $0.recipe != .badges } }

    /// Each object's owner among the playing roles. Props first, spread so no role has more than one prop more than
    /// another; then the pages, each to a role with the fewest objects so far, so no role has more than one object
    /// more than another either. Within the fair choices an object goes to the role it suits (a prop's own role, then
    /// a playing role whose guide items name it), else the earliest-ranked. Deterministic.
    public static func assign(_ items: [CoverItem], guideSteps: [Step], roles: [Role], players n: Int) -> [String: RoleID] {
        let playing = RoleCast.playing(roles, kids: PlayCast.players(n)).map(\.id)
        guard !playing.isEmpty else { return [:] }
        var owner: [String: RoleID] = [:]
        var props: [RoleID: Int] = [:], total: [RoleID: Int] = [:]
        func prefs(_ it: CoverItem) -> [RoleID] {
            var out: [RoleID] = []
            if let r = it.prop?.forRole.role, playing.contains(r) { out.append(r) }
            for st in guideSteps where Bookends.mentions(st.short ?? st.text, it) {
                if let r = st.role.role, playing.contains(r), !out.contains(r) { out.append(r) }
            }
            return out
        }
        /// A fair choice: a role may take one more while it has fewer than `base`, or exactly `base` while fewer than
        /// `extra` roles are above it (so every role ends with `base` or `base + 1`). The role it suits first, else the
        /// least busy (ties: fewer of the other load, then rank).
        func pick(_ it: CoverItem, load: [RoleID: Int], tie: [RoleID: Int], total m: Int) -> RoleID {
            let base = m / playing.count, extra = m % playing.count
            let above = playing.filter { (load[$0] ?? 0) > base }.count
            let can = playing.filter { let l = load[$0] ?? 0; return l < base || (l == base && above < extra) }
            if let r = prefs(it).first(where: can.contains) { return r }
            let pool = can.isEmpty ? playing : can
            return pool.min { a, b in
                let la = load[a] ?? 0, lb = load[b] ?? 0
                if la != lb { return la < lb }
                let ta = tie[a] ?? 0, tb = tie[b] ?? 0
                return ta != tb ? ta < tb : a.rank < b.rank
            } ?? playing[0]
        }
        let objs = objects(items)
        let propObjs = objs.filter { $0.prop != nil }
        for it in propObjs {
            let r = pick(it, load: props, tie: total, total: propObjs.count)
            owner[it.id] = r; props[r, default: 0] += 1; total[r, default: 0] += 1
        }
        for it in objs where it.prop == nil {
            let r = pick(it, load: total, tie: props, total: objs.count)
            owner[it.id] = r; total[r, default: 0] += 1
        }
        return owner
    }

    /// Items per card the app aims for (max 3; a solo kid with more than 6 objects gets more rows, never 3 in a row).
    public static let maxRows = 3

    /// A role's objects split into rows: one a row while they fit in 3 rows, else pairs (first rows first).
    static func rows(_ ids: [String]) -> [[String]] {
        guard !ids.isEmpty else { return [] }
        let r = ids.count <= maxRows ? ids.count : max(maxRows, (ids.count + 1) / 2)
        let pairs = ids.count - r
        var out: [[String]] = [], i = 0
        for k in 0..<r {
            let take = k < pairs ? 2 : 1
            out.append(Array(ids[i..<min(ids.count, i + take)])); i += take
        }
        return out
    }
}

extension OneScene {
    /// The setup checklist N players see (2026-11-21, one owner per object): each playing role's card has a row for
    /// its own objects (the guide's own wording when one of its items names exactly that object, else the app's job),
    /// 2 to 3 rows; a role with fewer than 2 gets simple role items (its own guide items that name no object, then "Put
    /// on your badge", then "Get in your spot"). No object is in two cards. Items use the pretend name only and are
    /// speakable.
    public static func setupScene(_ guide: Scene, kit k: Kit, roles: [Role], players n: Int, props: [Prop]) -> Scene {
        let p = PlayCast.players(n)
        let playing = RoleCast.playing(roles, kids: p)
        let items = Bookends.coverItems(items: k.items, props: props)
        let objs = ObjectOwners.objects(items)
        let guideSteps = guide.steps
        let owners = ObjectOwners.assign(items, guideSteps: guideSteps, roles: roles, players: p)
        let hasBadges = items.contains { $0.recipe == .badges }
        func names(_ text: String) -> [CoverItem] { items.filter { Bookends.mentions(text, $0) } }
        /// The guide's own wording for one object: an item naming exactly it (the owner's first, then any role's).
        func own(_ it: CoverItem, owner: RoleID) -> String? {
            let mine = guideSteps.filter { $0.role.role == owner }, rest = guideSteps.filter { $0.role.role != owner }
            for st in mine + rest {
                let t = st.short ?? st.text
                let named = names(t)
                if named.count == 1, named[0].id == it.id { return t }
            }
            return nil
        }
        func text(_ it: CoverItem, owner: RoleID) -> String {
            var t = own(it, owner: owner) ?? Bookends.fallbackSetup(it).short
            if let prop = it.prop { t = PropStandIns.itemText(t, prop: prop) }
            return ChecklistScenes.cleanItem(PropWording.clean(t, props: props), roles: roles)
        }
        var steps: [Step] = []
        for role in playing {
            let mine = objs.filter { owners[$0.id] == role.id }
            var rows: [(shown: String, picture: Picture)] = []
            for group in ObjectOwners.rows(mine.map(\.id)) {
                let its = group.compactMap { id in mine.first { $0.id == id } }
                let texts = its.map { text($0, owner: role.id) }
                let shown: String
                if its.count == 1 {
                    shown = texts[0]
                } else {
                    let jobs = zip(its, texts).map { ItemJob(item: $0.id, short: $1, say: $1, role: role.id) }
                    let short = PropWording.clean(Bookends.rowShort(jobs, items: its, verb: "Set up"), props: props)
                    // The short label must still name both objects (a tight "the cart and bag" may not): else the labels.
                    shown = its.allSatisfy { Bookends.mentions(short, $0) } ? Bookends.capFirst(Bookends.trimEnd(short))
                        : "Set up " + its.map(\.label).joined(separator: " and ")
                }
                let pic: Picture = its.count == 1 ? (its[0].prop.map { .prop($0.libraryID ?? $0.id) } ?? .point) : .point
                rows.append((shown, pic))
            }
            if rows.count < ChecklistScenes.minItems {
                var extra = guideSteps.filter { $0.role.role == role.id }.map { $0.short ?? $0.text }
                    .filter { names($0).isEmpty }.map { ChecklistScenes.cleanItem($0, roles: roles) }
                if hasBadges { extra.append("Put on your badge") }
                extra.append("Get in your spot")
                for e in extra where rows.count < ChecklistScenes.minItems && !rows.contains(where: { $0.shown.lowercased() == e.lowercased() }) {
                    rows.append((e, .point))
                }
            }
            for row in rows {
                var shown = Speakable.repair(row.shown)
                if p > 1 { shown = PlayCast.unname(shown, roles: roles, players: p) }
                steps.append(Step(picture: row.picture, text: ChecklistScenes.say(shown, role: role), role: SceneOwner(role.id), short: shown))
            }
        }
        return Scene(id: "setup", owner: .all, title: PlayCast.unname(guide.title, roles: roles, players: p, title: true), picture: .point,
                     nutmegSays: "", steps: steps, kind: .setup, checklist: true)
    }
}
