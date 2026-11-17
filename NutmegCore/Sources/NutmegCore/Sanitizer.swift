import Foundation
/// Clamps decoded AI output to the spec's limits (§5) instead of crashing on odd JSON.
public enum Sanitizer {
    public enum Limits {
        public static let ideas = 3, propsMax = 5, itemsMax = 6, scenesMax = 6, choicesMax = 4
        /// Round 28: 2 steps for each of the 6 roles a scene, none for everyone (a role's checklist is only theirs).
        public static let stepsMax = 12, legacyStepsMax = 5
        public static let copies = 1...8
    }

    /// `roleCount` is kept for older callers and ignored: round C1 writes every game for 6 ranked roles, and the app
    /// picks each scene's owner (the hand-offs rotate through the playing roles).
    public static func clean(_ k: Kit, roleCount: Int = RoleCast.count) -> Kit {
        var k = k
        k.items = recipeOrdered(k.items).map { item in
            var i = item
            i.symbol = PrintSymbols.safe(i.symbol)
            i.copies = min(max(i.copies, Limits.copies.lowerBound), Limits.copies.upperBound)
            return i
        }
        k.scenes = Array(k.scenes.prefix(Limits.scenesMax)).enumerated().map { i, scene in
            var s = scene
            s.nutmegSays = PretendLine.ensure(s.nutmegSays, index: i)   // round 13: every scene intro says "Pretend that"
            s.steps = roleSteps(s.steps)
            s.owner = .all
            return s
        }
        return k
    }

    /// Round 28: at most `PlayCast.stepsPerRole` steps per role (the first ones); steps for everyone are dropped (a
    /// role's checklist is only theirs). A scene with no role steps (older JSON) keeps its first `legacyStepsMax` steps.
    static func roleSteps(_ steps: [Step]) -> [Step] {
        guard steps.contains(where: { $0.role.role != nil }) else { return Array(steps.prefix(Limits.legacyStepsMax)) }
        var seen: [SceneOwner: Int] = [:]
        return steps.filter { st in
            if st.role == .all { return false }
            seen[st.role, default: 0] += 1
            return seen[st.role]! <= PlayCast.stepsPerRole
        }
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
            // Round 23 (Haylee): one $1 bill design; menu prices are small whole dollars ($1 to $5).
            if r == .money { item.bigNumber = Money.bill; item.lines = item.lines.map(Money.oneDollar) }
            if r == .menu { item.lines = item.lines.map(Money.smallPrices) }
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
        // Props come from the library only (checklist-pictures.md): off-list items are dropped, never shown as emoji.
        var seen = Set<String>()
        p.props = Array(p.props.filter { $0.safetyOK && PropLibrary.contains($0.libraryID ?? $0.id) && seen.insert($0.libraryID ?? $0.id).inserted }
            .prefix(Limits.propsMax)).map { prop in
            var prop = prop
            let id = prop.libraryID ?? prop.id
            prop.libraryID = id; prop.householdItem = PropLibrary.name(id) ?? prop.householdItem; prop.emoji = nil
            return prop
        }
        return p
    }

    public static func clean(_ plan: GamePlan, playerCount: Int) -> GamePlan {
        var plan = plan
        // Round C1: always 6 ranked roles; `playerCount` only says how many of them play (RoleCast.playing).
        // Round 28 (Haylee): customers are roles too (R2 = the customer counterpart for a game that has customers).
        let ranked = CustomerRoles.arrange(RoleCast.rank(plan.roles), game: plan.gameTitle + " " + plan.setting)
        plan.roles = ranked.map { var r = $0; r.symbol = PrintSymbols.safe(r.symbol); return r }
        return plan
    }

    public static func clean(_ i: GameIdeas) -> GameIdeas {
        var i = i; i.ideas = Array(i.ideas.prefix(Limits.ideas)); return i
    }

    public static func clean(_ t: NutmegTurn) -> NutmegTurn {
        var t = t; t.choices = Array(t.choices.prefix(Limits.choicesMax)); return t
    }
}

/// Round 13 (Haylee: in the play step she never said it): every scene's intro line says "Pretend that…". The kit
/// prompt asks for it; a line that still lacks it gets a short varied "Pretend that…" opener in front.
public enum PretendLine {
    public static let openers = [
        "Pretend that the show is starting!",
        "Pretend that the curtain just went up!",
        "Pretend that something exciting is about to happen!",
        "Pretend that everyone is watching!",
        "Pretend that it's the big moment!",
        "Pretend that the room is the stage!"
    ]
    public static func has(_ line: String) -> Bool { line.lowercased().contains("pretend that") }
    public static func ensure(_ line: String, index: Int) -> String {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if has(t) { return t }
        let opener = openers[((index % openers.count) + openers.count) % openers.count]
        return t.isEmpty ? opener : opener + " " + t
    }
}

/// Round 23 (Haylee): play money is a single $1 bill page (print more copies for more money), and menu prices are
/// small whole dollars, so counting out $1 bills makes sense.
public enum Money {
    public static let bill = "$1"
    public static let priceRange = 1...5
    static let amount = try! NSRegularExpression(pattern: #"\$\s?(\d+)(?:[.,](\d{1,2}))?"#)
    static let words = try! NSRegularExpression(pattern: #"\b(\d+)\s+dollars?\b"#, options: [.caseInsensitive])

    /// Any amount on a bill reads $1 ("$5" → "$1", "10 dollars" → "1 dollar").
    public static func oneDollar(_ line: String) -> String {
        var s = replace(amount, in: line) { _ in bill }
        s = replace(words, in: s) { _ in "1 dollar" }
        return s
    }

    /// Prices become whole dollars from $1 to $5: cents round to the nearest dollar (at least $1), bigger prices cap at $5.
    public static func smallPrices(_ line: String) -> String {
        replace(amount, in: line) { groups in
            let whole = Int(groups[1] ?? "") ?? 1
            let cents = Int((groups[2] ?? "0").padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
            let rounded = whole + (cents >= 50 ? 1 : 0)
            return "$\(min(max(rounded, priceRange.lowerBound), priceRange.upperBound))"
        }
    }

    /// The dollar amounts in a line (for tests and checks).
    public static func amounts(_ line: String) -> [String] {
        let ns = line as NSString
        return amount.matches(in: line, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    private static func replace(_ re: NSRegularExpression, in text: String, with make: ([String?]) -> String) -> String {
        let ns = text as NSString
        var out = text
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let groups = (0..<m.numberOfRanges).map { i -> String? in
                let r = m.range(at: i); return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            out = (out as NSString).replacingCharacters(in: m.range, with: make(groups))
        }
        return out
    }
}
