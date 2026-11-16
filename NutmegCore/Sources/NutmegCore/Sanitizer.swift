import Foundation
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
        k.scenes = Array(k.scenes.prefix(Limits.scenesMax)).enumerated().map { i, scene in
            var s = scene
            s.nutmegSays = PretendLine.ensure(s.nutmegSays, index: i)   // round 13: every scene intro says "Pretend that"
            s.steps = Array(s.steps.prefix(Limits.stepsMax))
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
