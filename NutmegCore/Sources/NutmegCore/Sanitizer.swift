/// Clamps decoded AI output to the spec's limits (§5) instead of crashing on odd JSON.
public enum Sanitizer {
    public enum Limits {
        public static let ideas = 3, propsMax = 5, itemsMax = 6, scenesMax = 6, stepsMax = 5, choicesMax = 4
        public static let copies = 1...8
    }

    static func allowed(_ owner: SceneOwner, playerCount: Int) -> SceneOwner {
        guard let t = owner.token else { return .all }
        return t.index < max(1, min(playerCount, 4)) ? owner : .all
    }

    public static func clean(_ k: Kit, playerCount: Int) -> Kit {
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
            s.owner = allowed(s.owner, playerCount: playerCount)
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
        var seen = Set<PlayerToken>()
        plan.roles = plan.roles.filter { r in
            guard r.player.index < max(1, min(playerCount, 4)), !seen.contains(r.player) else { return false }
            seen.insert(r.player); return true
        }.map { var r = $0; r.symbol = PrintSymbols.safe(r.symbol); return r }
        .sorted { $0.player.index < $1.player.index }
        return plan
    }

    public static func clean(_ i: GameIdeas) -> GameIdeas {
        var i = i; i.ideas = Array(i.ideas.prefix(Limits.ideas)); return i
    }

    public static func clean(_ t: NutmegTurn) -> NutmegTurn {
        var t = t; t.choices = Array(t.choices.prefix(Limits.choicesMax)); return t
    }
}
