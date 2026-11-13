/// Clamps decoded AI output to the spec's limits (§5) instead of crashing on odd JSON.
public enum Sanitizer {
    public enum Limits {
        public static let ideas = 3, propsMax = 5, itemsMax = 4, scenesMax = 6, stepsMax = 5, choicesMax = 4
        public static let copies = 1...8
    }

    static func allowed(_ owner: SceneOwner, playerCount: Int) -> SceneOwner {
        guard let t = owner.token else { return .all }
        return t.index < max(1, min(playerCount, 4)) ? owner : .all
    }

    public static func clean(_ k: Kit, playerCount: Int) -> Kit {
        var k = k
        k.items = Array(k.items.prefix(Limits.itemsMax)).map { item in
            var i = item
            i.symbol = PrintSymbols.safe(i.symbol)
            i.copies = min(max(i.copies, Limits.copies.lowerBound), Limits.copies.upperBound)
            return i
        }
        k.scenes = Array(k.scenes.prefix(Limits.scenesMax)).map { scene in
            var s = scene
            s.steps = Array(s.steps.prefix(Limits.stepsMax))
            s.owner = allowed(s.owner, playerCount: playerCount)
            return s
        }
        return k
    }

    public static func clean(_ p: Props) -> Props {
        var p = p
        p.props = Array(p.props.filter(\.safetyOK).prefix(Limits.propsMax))
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
