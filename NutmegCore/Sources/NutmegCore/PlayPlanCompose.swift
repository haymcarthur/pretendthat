import Foundation

// 2026-11-21 (Haylee, one game plan; build: decisions/2026-11-21-round-game-plan-build.md): what N kids see for a
// game-plan kit, composed with no AI call: setup cards by AREA (owner picture + role + the area job in big text, 2 to 3
// items that each place one object, a picture chip per item), the one scene (the fair events from the pool + the
// calm-stretch ideas in the calm gaps for every object no picked event uses), and clean-up cards by the same owners.
// `trace` is the traceability check: every object is placed once, used in play and put away; every area is built and
// appears in an event or an idea; every reference is real.

extension PlayPlans {
    /// Who does what for N kids: each object's ONE owner (fair: no role more than one object more than another) and
    /// each playing role's areas (an area whose owner isn't playing goes to the least busy playing role).
    public struct Cast: Equatable, Sendable {
        public var owner: [String: RoleID]
        public var areasOf: [RoleID: [String]]
    }

    public static func cast(_ plan: PlayPlan, playing: [RoleID]) -> Cast {
        guard !playing.isEmpty else { return Cast(owner: [:], areasOf: [:]) }
        var areasOf: [RoleID: [String]] = [:]
        var areaOwner: [String: RoleID] = [:]
        func objectsIn(_ area: String) -> Int { plan.objects.filter { $0.area == area }.count }
        func areaLoad(_ r: RoleID) -> Int { (areasOf[r] ?? []).reduce(0) { $0 + objectsIn($1) } }
        for a in plan.areas where playing.contains(a.owner) && areaOwner[a.id] == nil {
            areaOwner[a.id] = a.owner; areasOf[a.owner, default: []].append(a.id)
        }
        for a in plan.areas where areaOwner[a.id] == nil {
            let r = playing.min { x, y in
                let kx = ((areasOf[x] ?? []).count, areaLoad(x), x.rank), ky = ((areasOf[y] ?? []).count, areaLoad(y), y.rank)
                return kx < ky
            } ?? playing[0]
            areaOwner[a.id] = r; areasOf[r, default: []].append(a.id)
        }
        // Each object: its plan owner when playing, else its area's owner.
        var owner: [String: RoleID] = [:]
        for o in plan.objects {
            owner[o.id] = playing.contains(o.owner) ? o.owner : (areaOwner[o.area] ?? playing[0])
        }
        // Fair: move one object at a time from the busiest role to the least busy (an object of an area the receiver
        // builds first, else the busiest role's last one), until no role has two more than another.
        func load(_ r: RoleID) -> Int { owner.values.filter { $0 == r }.count }
        var guardCount = 0
        while guardCount < 100 {
            guardCount += 1
            let loads = playing.map { ($0, load($0)) }
            guard let hi = loads.max(by: { ($0.1, -$0.0.rank) < ($1.1, -$1.0.rank) }),
                  let lo = loads.min(by: { ($0.1, $0.0.rank) < ($1.1, $1.0.rank) }), hi.1 - lo.1 > 1 else { break }
            let theirs = plan.objects.filter { owner[$0.id] == hi.0 }
            let mine = Set(areasOf[lo.0] ?? [])
            guard let move = theirs.last(where: { mine.contains($0.area) }) ?? theirs.last else { break }
            owner[move.id] = lo.0
        }
        return Cast(owner: owner, areasOf: areasOf)
    }

    /// The big words on a role's setup card: its area's job ("Build the cockpit"); two or three areas "Set up the
    /// cockpit and the cabin"; a role with no area of its own helps where its objects live ("Help set up the cabin").
    static func areaJob(for r: RoleID, plan: PlayPlan, cast: Cast, title: String) -> String {
        let mine = (cast.areasOf[r] ?? []).compactMap { plan.area($0) }
        if mine.count == 1 { return mine[0].job }
        if mine.count > 1 {
            let names = mine.map(\.name)
            let joined = names.count == 2 ? "\(names[0]) and \(names[1])" : names.dropLast().joined(separator: ", ") + " and " + names.last!
            let job = "Set up " + joined
            return job.split(whereSeparator: \.isWhitespace).count <= maxItemWords || title.isEmpty ? job : title
        }
        if let o = plan.objects.first(where: { cast.owner[$0.id] == r }), let a = plan.area(o.area) { return "Help set up \(a.name)" }
        return "Get ready to play"
    }

    // MARK: Compose

    /// The arc N players see for a game-plan kit: the story, the area setup cards, the one scene (picked events +
    /// ideas), the clean-up cards. A pure function of the kit, the roles, N and the props.
    public static func compose(_ k: Kit, guide: Scene, roles: [Role], players n: Int, props: [Prop]) -> [Scene] {
        guard let b = guide.beats, let raw = b.plan else { return k.scenes }
        let p = PlayCast.players(n)
        let cover = Bookends.coverItems(items: k.items, props: props)
        var plan = complete(raw, cover: cover, roles: roles, title: guide.title)
        // Review pass (replays): a prop swapped for another household item keeps its pretend name, but a put-away item
        // that names none of its current names (it named the first play's item) gets the app's line.
        for k in plan.objects.indices {
            guard let it = cover.first(where: { $0.id == plan.objects[k].id }), let prop = it.prop, prop.swapped == true,
                  !Bookends.propNames(prop).contains(where: { Bookends.mentions(plan.objects[k].putAway, name: $0) }) else { continue }
            plan.objects[k].putAway = Bookends.fallbackCleanup(it).short
        }
        let playing = RoleCast.playing(roles, kids: p).map(\.id)
        let cast = cast(plan, playing: playing)
        var out: [Scene] = []
        if let story = k.story?.trimmingCharacters(in: .whitespacesAndNewlines), !story.isEmpty {
            out.append(Scene(id: "story", owner: .all, title: guide.title, picture: .point, nutmegSays: story, steps: [], kind: .story))
        }
        out.append(setupScene(guide, plan: plan, cast: cast, cover: cover, roles: roles, players: p, props: props))
        let pool = pretendGone(b.events, plan: raw, cover: cover, props: props).map { tie($0, plan: plan, cover: cover, roles: roles) }
        let events = OneScene.pick(pool: pool, roles: roles, players: p)
        let ideas = scheduleIdeas(plan: plan, events: events, cover: cover, cast: cast, roles: roles, players: p)
        let rawOpener = EventScenario.isGenericOpener(b.opener) ? EventScenario.opener(story: k.story, title: guide.title) : b.opener
        // 2026-11-20 (Haylee): the opener ends in something everyone does (never just "take your places").
        let opener = EventScenario.actionOpener(PlayCast.sceneLine(rawOpener, roles: roles, players: p))
        let finale = PlayCast.unname(b.finale, roles: roles, players: p, keep: PlayCast.pageTitles(cover))
        let beats = Speakable.repair(SceneBeats(opener: opener, events: events, finale: finale, music: b.music, ideas: ideas))
        out.append(Scene(id: "play", owner: .all, title: guide.title, picture: .point, nutmegSays: beats.opener, steps: [], beats: beats))
        out.append(cleanupScene(k.cleanup ?? Bookend(title: "", nutmegSays: ""), plan: plan, cast: cast, cover: cover, roles: roles,
                                players: p, props: props))
        return out
    }

    /// Review pass (replays): a prop the saved plan placed that the kids don't have now (skipped on this replay) is
    /// "the pretend …" in the event lines that name it, so no line asks for a prop that isn't there.
    static func pretendGone(_ events: [BeatEvent], plan: PlayPlan, cover: [CoverItem], props: [Prop]) -> [BeatEvent] {
        let here = Set(cover.map(\.id))
        let gone = plan.objects.filter { $0.isProp && !here.contains($0.id) }
        guard !gone.isEmpty else { return events }
        var out = events
        for o in gone {
            let prop = props.first { Bookends.propID($0.id) == o.id }
            let name = prop.map { KitDraft.cutoutLabel(becomes: $0.becomes) } ?? KitDraft.cutoutLabel(becomes: o.pretend ?? "")
            guard !name.isEmpty else { continue }
            for k in out.indices {
                out[k].line = GuideWeave.pretend(out[k].line, item: prop?.householdItem ?? "", becomes: name, label: name)
            }
        }
        return out
    }

    /// The area setup cards: for each playing role its area job (big) and a row per object it owns (2 to 3 rows; pairs
    /// past 3; a solo kid with more than 6 objects gets more rows), each row placing its object(s) with a picture
    /// chip. A role with fewer than 2 rows also gets "Take your place in <area>" / "Get in your spot". Every object in
    /// exactly one row. Speakable; the shown text is what she says after the role's title.
    static func setupScene(_ guide: Scene, plan: PlayPlan, cast: Cast, cover: [CoverItem], roles: [Role], players p: Int,
                           props: [Prop]) -> Scene {
        let playing = RoleCast.playing(roles, kids: p)
        var steps: [Step] = []
        var jobs: [String: String] = [:]
        for role in playing {
            let areaOrder = cast.areasOf[role.id] ?? []
            let mine = plan.objects.filter { cast.owner[$0.id] == role.id }
                .sorted { a, b in (areaOrder.firstIndex(of: a.area) ?? 9, plan.objects.firstIndex(of: a) ?? 0)
                    < (areaOrder.firstIndex(of: b.area) ?? 9, plan.objects.firstIndex(of: b) ?? 0) }
            var rows: [(shown: String, picture: Picture, objects: [String]?)] = []
            for group in ObjectOwners.rows(mine.map(\.id)) {
                let its = group.compactMap { id in mine.first { $0.id == id } }
                guard let first = its.first else { continue }
                let shown: String
                if its.count == 1 {
                    shown = first.setup
                } else {
                    let labels = its.compactMap { o in cover.first { $0.id == o.id }.map(displayLabel) }
                    shown = "Set up " + labels.joined(separator: " and ")
                }
                rows.append((shown, picture(first.id, cover: cover), group))
            }
            let place = areaOrder.first.flatMap { plan.area($0)?.name } ?? mine.first.flatMap { plan.area($0.area)?.name }
            var extra: [String] = []
            if let place { extra.append("Take your place in \(place)") }
            extra.append("Get in your spot")
            for e in extra where rows.count < ChecklistScenes.minItems && !rows.contains(where: { $0.shown.lowercased() == e.lowercased() }) {
                rows.append((e, .point, nil))
            }
            for row in rows {
                var shown = Speakable.repair(PropWording.clean(row.shown, props: props), fallback: Speakable.safeItem)
                if p > 1 { shown = PlayCast.unname(shown, roles: roles, players: p, keep: PlayCast.pageTitles(cover)) }
                steps.append(Step(picture: row.picture, text: ChecklistScenes.say(shown, role: role), role: SceneOwner(role.id),
                                  short: shown, objects: row.objects))
            }
            var job = Speakable.repair(areaJob(for: role.id, plan: plan, cast: cast, title: guide.title), fallback: "Get ready to play")
            if p > 1 { job = PlayCast.unname(job, roles: roles, players: p, keep: PlayCast.pageTitles(cover)) }
            jobs[role.id.rawValue] = job
        }
        return Scene(id: "setup", owner: .all, title: PlayCast.unname(guide.title, roles: roles, players: p, title: true), picture: .point,
                     nutmegSays: "", steps: steps, kind: .setup, checklist: true, areaJobs: jobs)
    }

    /// The clean-up cards by the same owners: each prop's put-away item by its owner, then the one print-mess item to a
    /// least busy role, then the pages' put-away items while a card has room (under 3 rows). A role with nothing gets a
    /// high five. The card's big words: "Tidy up <its area>".
    static func cleanupScene(_ bookend: Bookend, plan: PlayPlan, cast: Cast, cover: [CoverItem], roles: [Role], players p: Int,
                             props: [Prop]) -> Scene {
        let playing = RoleCast.playing(roles, kids: p)
        var load: [RoleID: [String]] = [:]
        for o in plan.objects where o.isProp { if let r = cast.owner[o.id] { load[r, default: []].append(o.id) } }
        let lo = playing.map { load[$0.id]?.count ?? 0 }.min() ?? 0
        let messRole = playing.first { (load[$0.id]?.count ?? 0) == lo }?.id
        var mess: [RoleID: Bool] = [:]
        if let messRole { mess[messRole] = true }
        for o in plan.objects where !o.isProp {
            guard let r = cast.owner[o.id] else { continue }
            if (load[r]?.count ?? 0) + (mess[r] == true ? 1 : 0) < ChecklistScenes.maxItems { load[r, default: []].append(o.id) }
        }
        var steps: [Step] = []
        var jobs: [String: String] = [:]
        for role in playing {
            let ids = load[role.id] ?? []
            var rows: [(shown: String, picture: Picture, objects: [String]?)] = []
            for group in ObjectOwners.rows(ids) {
                let its = group.compactMap { plan.object($0) }
                guard let first = its.first else { continue }
                let shown: String
                if its.count == 1 {
                    shown = first.putAway
                } else {
                    let labels: [String] = its.compactMap { (o: PlanObject) -> String? in
                        guard let it = cover.first(where: { $0.id == o.id }) else { return nil }
                        if let prop = it.prop { return "the " + prop.itemWords }
                        return it.label
                    }
                    shown = "Put away " + labels.joined(separator: " and ")
                }
                rows.append((shown, picture(first.id, cover: cover), group))
            }
            if mess[role.id] == true { rows.append((OneScene.printMessShort, OneScene.printMessPicture, [OneScene.printMessID])) }
            if rows.isEmpty {
                steps.append(Step(picture: .point, text: "\(role.roleName), give everyone a big high five for a great game!",
                                  role: SceneOwner(role.id), short: "Give high fives"))
            }
            for row in rows {
                var shown = Speakable.repair(PropWording.clean(row.shown, props: props), fallback: "Tidy up your spot")
                if p > 1 { shown = PlayCast.unname(shown, roles: roles, players: p, keep: PlayCast.pageTitles(cover)) }
                steps.append(Step(picture: row.picture, text: ChecklistScenes.say(shown, role: role), role: SceneOwner(role.id),
                                  short: shown, objects: row.objects))
            }
            let area = (cast.areasOf[role.id] ?? []).first.flatMap { plan.area($0) }
                ?? ids.first.flatMap { plan.object($0) }.flatMap { plan.area($0.area) }
            var job = area.map { "Tidy up \($0.name)" } ?? "Help tidy up"
            job = Speakable.repair(job, fallback: "Help tidy up")
            if p > 1 { job = PlayCast.unname(job, roles: roles, players: p, keep: PlayCast.pageTitles(cover)) }
            jobs[role.id.rawValue] = job
        }
        let title = bookend.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return Scene(id: "cleanup", owner: .all, title: PlayCast.unname(title.isEmpty ? "Clean-Up Time" : title, roles: roles, players: p, title: true),
                     picture: .point, nutmegSays: "", steps: steps, kind: .cleanup, checklist: true, areaJobs: jobs)
    }

    // MARK: Calm-stretch ideas

    /// The ideas for the picked events: one for every object no picked event uses (wearables like the sign and the
    /// labels count their setup, unless their area would otherwise never come up), spread over the calm gaps (the
    /// gaps between events first, then after the last, then before the first), at most `maxIdeasPerGap` a gap. An
    /// object that finds no room joins an idea of the same owner ("…! Then …"), so nothing printed or found goes
    /// unused. Each idea speaks to the object's owner for this count.
    static func scheduleIdeas(plan: PlayPlan, events: [BeatEvent], cover: [CoverItem], cast: Cast, roles: [Role], players p: Int) -> [BeatIdea] {
        let inCover = plan.objects.filter { o in cover.contains { $0.id == o.id } }
        let used = Set(events.flatMap { $0.objects ?? [] })
        var seen = Set(events.compactMap(\.area) + used.compactMap { plan.object($0)?.area })
        var needs = inCover.filter { !used.contains($0.id) && !PrintPlayJobs.setupIsUse(recipe($0.id)) }
        seen.formUnion(needs.map(\.area))
        needs += inCover.filter { !used.contains($0.id) && PrintPlayJobs.setupIsUse(recipe($0.id)) && !seen.contains($0.area) }
        // Interleave the areas, so ideas in a row come from different places.
        var byArea: [[PlanObject]] = plan.areas.map { a in needs.filter { $0.area == a.id } }
        byArea.append(needs.filter { o in !plan.areas.contains { $0.id == o.area } })
        var order: [PlanObject] = []
        while byArea.contains(where: { !$0.isEmpty }) {
            for k in byArea.indices where !byArea[k].isEmpty { order.append(byArea[k].removeFirst()) }
        }
        let n = events.count
        let gaps = n == 0 ? [0] : Array(1..<n) + [n, 0]
        var room = Dictionary(uniqueKeysWithValues: gaps.map { ($0, BeatTimeline.ideaRoom($0, events: events)) })
        var placed: [(gap: Int, objects: [PlanObject])] = []
        var rest = order
        var round = 0
        while !rest.isEmpty && round < BeatTimeline.maxIdeasPerGap {
            for g in gaps where !rest.isEmpty && (room[g] ?? 0) > 0 {
                placed.append((g, [rest.removeFirst()])); room[g]! -= 1
            }
            round += 1
        }
        // No room left: an object joins an idea of the same owner (else the first idea).
        for o in rest {
            let r = cast.owner[o.id]
            if let k = placed.firstIndex(where: { $0.objects.count < 2 && cast.owner[$0.objects[0].id] == r })
                ?? placed.firstIndex(where: { $0.objects.count < 2 }) {
                placed[k].objects.append(o)
            } else if !placed.isEmpty {
                placed[placed.count - 1].objects.append(o)
            } else {
                placed.append((gaps.first ?? 0, [o]))
            }
        }
        // In time order (a stable sort: a gap's ideas keep their order).
        placed = placed.enumerated().sorted { ($0.element.gap, $0.offset) < ($1.element.gap, $1.offset) }.map(\.element)
        return placed.map { slot in
            let first = slot.objects[0]
            let r = cast.owner[first.id] ?? first.owner
            let who = roles.first { $0.id == r }?.roleName ?? "Everyone"
            var line = ideaLine(first.idea, who: who)
            for extra in slot.objects.dropFirst() {
                line += " Then " + PlayCast.lowerFirst(exclaim(dropLead(extra.idea)))
            }
            if p > 1 { line = PlayCast.unname(line, roles: roles, players: p, keep: PlayCast.pageTitles(cover)) }
            let fallback = ideaLine(appObject(cover.first { $0.id == first.id } ?? CoverItem(id: first.id, label: "it", names: []),
                                              plan: plan, roles: roles, area: first.area).idea, who: who)
            line = Speakable.repair(line, fallback: fallback)
            return BeatIdea(line: line, roles: [r], objects: slot.objects.map(\.id), area: first.area,
                            picture: picture(first.id, cover: cover), gap: slot.gap, appWritten: first.appWritten)
        }
    }

    /// "While we fly, write…" → "write…" (a second idea joined with "Then").
    static func dropLead(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let comma = t.firstIndex(of: ","), let first = t.split(separator: " ").first, leadWords.contains(first.lowercased()),
           t[..<comma].split(separator: " ").count <= 6 {
            return t[t.index(after: comma)...].trimmingCharacters(in: .whitespaces)
        }
        return t
    }

    static func recipe(_ id: String) -> KitRecipe? {
        id.hasPrefix("page:") ? KitRecipe(rawValue: String(id.dropFirst(5))) : nil
    }

    // MARK: The traceability check (tests; DEBUG logs)

    /// What's wrong with the arc N players see for a game-plan kit (empty = it holds): every object (badges aside) is
    /// in exactly one setup row of a playing role, has a use in play (a picked event or an idea; wearables may count
    /// their setup) and a put-away item (a prop: a clean-up row); every area is built in setup and appears in an
    /// event or an idea; every event and idea points at real objects and areas; no card has more than 3 rows (a solo
    /// kid with more than 6 objects aside); the setup is fair (no role two objects ahead).
    public static func trace(_ scenes: [Scene], kit: Kit, roles: [Role], players n: Int, props: [Prop]) -> [String] {
        guard let guide = kit.scenes.first(where: { $0.beats?.plan != nil }), let raw = guide.beats?.plan else { return ["no plan"] }
        let p = PlayCast.players(n)
        let cover = Bookends.coverItems(items: kit.items, props: props)
        let plan = complete(raw, cover: cover, roles: roles, title: guide.title)
        let playing = Set(RoleCast.playing(roles, kids: p).map(\.id))
        var issues: [String] = []
        guard let setup = scenes.first(where: { $0.arc == .setup }), let play = scenes.first(where: { $0.isBeatScene }),
              let cleanup = scenes.first(where: { $0.arc == .cleanup }), let beats = play.beats else { return ["missing a scene"] }
        let objs = ObjectOwners.objects(cover)
        let events = beats.events, ideas = beats.ideas ?? []
        let usedByEvents = Set(events.flatMap { $0.objects ?? [] })
        let usedByIdeas = Set(ideas.flatMap(\.objects))
        var appears = Set(events.compactMap(\.area) + ideas.compactMap(\.area))
        appears.formUnion((usedByEvents.union(usedByIdeas)).compactMap { plan.object($0)?.area })
        for it in objs {
            guard let o = plan.object(it.id) else { issues.append("\(it.id): not in the plan"); continue }
            let rows = setup.steps.filter { $0.objects?.contains(it.id) == true }
            if rows.count != 1 { issues.append("\(it.id): in \(rows.count) setup rows") }
            if let r = rows.first?.role.role, !playing.contains(r) { issues.append("\(it.id): owner \(r.rawValue) isn't playing") }
            if plan.area(o.area) == nil { issues.append("\(it.id): no area") }
            if o.setup.isEmpty || o.putAway.isEmpty || o.idea.isEmpty { issues.append("\(it.id): a missing life-cycle item") }
            let used = usedByEvents.contains(it.id) || usedByIdeas.contains(it.id)
                || (PrintPlayJobs.setupIsUse(it.recipe) && appears.contains(o.area))
            if !used { issues.append("\(it.id): never used in play") }
            if it.prop != nil, !cleanup.steps.contains(where: { $0.objects?.contains(it.id) == true }) { issues.append("\(it.id): never put away") }
        }
        let setupIDs = Set(setup.steps.flatMap { $0.objects ?? [] })
        for a in plan.areas {
            if !plan.objects.contains(where: { $0.area == a.id && setupIDs.contains($0.id) }) { issues.append("\(a.id): not built in setup") }
            if !appears.contains(a.id) { issues.append("\(a.id): never comes up in play") }
        }
        for (k, e) in events.enumerated() {
            for id in e.objects ?? [] where plan.object(id) == nil || !objs.contains(where: { $0.id == id }) { issues.append("event \(k): \(id) isn't real") }
            if let a = e.area, plan.area(a) == nil { issues.append("event \(k): area \(a) isn't real") }
        }
        for (k, i) in ideas.enumerated() {
            if i.objects.isEmpty { issues.append("idea \(k): uses nothing") }
            for id in i.objects where plan.object(id) == nil || !objs.contains(where: { $0.id == id }) { issues.append("idea \(k): \(id) isn't real") }
            if let a = i.area, plan.area(a) == nil { issues.append("idea \(k): area \(a) isn't real") }
            if !i.roles.allSatisfy(playing.contains) { issues.append("idea \(k): calls a role that isn't playing") }
        }
        let cards = ChecklistScenes.cards(setup)
        let objectCount = objs.count
        for c in cards where c.rows.count > ChecklistScenes.maxItems && !(p == 1 && objectCount > 2 * ChecklistScenes.maxItems) {
            issues.append("\(c.role.rawValue): \(c.rows.count) setup rows")
        }
        let loads = RoleCast.playing(roles, kids: p).map { r in setup.steps.filter { $0.role.role == r.id }.flatMap { $0.objects ?? [] }.count }
        if let lo = loads.min(), let hi = loads.max(), hi - lo > 1 { issues.append("setup isn't fair (\(loads))") }
        return issues
    }
}
