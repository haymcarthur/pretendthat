/// Clamps decoded AI output to the spec's limits (§5) instead of crashing on odd JSON.
public enum Sanitizer {
    public enum Limits {
        public static let ideas = 3, propsMax = 5, itemsMax = 6, scenesMax = 6, stepsMax = 5, choicesMax = 4
        public static let copies = 1...8
    }

    static func allowed(_ owner: SceneOwner, roleCount: Int) -> SceneOwner {
        guard let r = owner.role else { return .all }
        return r.index < max(1, min(roleCount, 4)) ? owner : .all
    }

    /// `roleCount`: distinct roles in the plan (scene owners past it become "all").
    public static func clean(_ k: Kit, roleCount: Int) -> Kit {
        var k = k
        k.items = recipeOrdered(k.items).map { item in
            var i = item
            i.symbol = PrintSymbols.safe(i.symbol)
            i.copies = min(max(i.copies, Limits.copies.lowerBound), Limits.copies.upperBound)
            return i
        }
        k.scenes = Array(k.scenes.prefix(Limits.scenesMax)).map { scene in
            var s = scene
            s.steps = Array(s.steps.prefix(Limits.stepsMax)).map { Step(emoji: EmojiMatch.fix($0.emoji, for: $0.text), text: $0.text) }
            s.owner = allowed(s.owner, roleCount: roleCount)
            return s
        }
        return k
    }

    /// Kit recipe (kit-recipe.md): one item per recipe slot in the fixed order, shaped by the app. Items without a
    /// recipe (older JSON) fill empty slots by their size; extras are dropped.
    static func recipeOrdered(_ items: [KitItem]) -> [KitItem] {
        var pool = items
        var out: [KitItem] = []
        for r in KitRecipe.allCases {
            let idx = pool.firstIndex { $0.recipe == r } ?? pool.firstIndex { $0.recipe == nil && Self.guess($0) == r }
            guard let i = idx else { continue }
            var item = pool.remove(at: i)
            item.recipe = r; item.kind = r.kind
            item.size = (r == .tickets && item.size == .keycard) ? .keycard : r.size
            item.perPlayer = r.perPlayer
            item.copies = r == .money ? 8 : (r.perPlayer ? 1 : 1)
            if r == .badges { item.bigNumber = nil }
            out.append(item)
        }
        return out
    }

    static func guess(_ item: KitItem) -> KitRecipe? {
        let t = item.title.lowercased()
        switch item.size {
        case .badge: return .badges
        case .bill: return .money
        case .ticket, .keycard: return .tickets
        case .fullPage:
            if t.contains("menu") || t.contains("price") || t.contains("list") { return .menu }
            if t.contains("sign") { return .sign }
            return t.contains("cut") ? .cutouts : nil
        }
    }

    public static func clean(_ p: Props) -> Props {
        var p = p
        p.props = Array(p.props.filter(\.safetyOK).prefix(Limits.propsMax)).map { prop in
            var prop = prop
            // The card's emoji shows the household item the kid hunts for.
            prop.emoji = EmojiMatch.fix(prop.emoji, for: prop.householdItem, fallback: EmojiMatch.fix(prop.emoji, for: prop.becomes))
            return prop
        }
        return p
    }

    public static func clean(_ plan: GamePlan, playerCount: Int) -> GamePlan {
        var plan = plan
        plan.roles = RoleCast.normalize(plan.roles, kids: playerCount).map { var r = $0; r.symbol = PrintSymbols.safe(r.symbol); return r }
        return plan
    }

    public static func clean(_ i: GameIdeas) -> GameIdeas {
        var i = i; i.ideas = Array(i.ideas.prefix(Limits.ideas)); return i
    }

    public static func clean(_ t: NutmegTurn) -> NutmegTurn {
        var t = t; t.choices = Array(t.choices.prefix(Limits.choicesMax)); return t
    }
}

/// Turns the roles Nutmeg proposed into the cast for N kids (decision roles-not-names.md): same titles merge
/// ("Passenger" twice → one Passenger role played by 2), at most 4 distinct roles (R1…R4, which also pick the color),
/// and the counts add up to exactly the number of kids (the last role takes any extra kids, e.g. more Passengers).
public enum RoleCast {
    public static func normalize(_ roles: [Role], kids: Int) -> [Role] {
        let kids = max(1, min(kids, Players.max))
        var merged: [Role] = []
        for r in roles where !r.roleName.trimmingCharacters(in: .whitespaces).isEmpty {
            if let i = merged.firstIndex(where: { $0.roleName.caseInsensitiveCompare(r.roleName) == .orderedSame }) {
                merged[i].count += max(1, r.count)
            } else { var r = r; r.count = max(1, r.count); merged.append(r) }
        }
        merged = Array(merged.prefix(min(kids, RoleID.allCases.count)))
        guard !merged.isEmpty else { return [] }
        for i in merged.indices { merged[i].id = RoleID.allCases[i] }
        var total = merged.map(\.count).reduce(0, +)
        while total > kids, let i = merged.lastIndex(where: { $0.count > 1 }) { merged[i].count -= 1; total -= 1 }
        if total < kids { merged[merged.count - 1].count += kids - total }
        return merged
    }
}
