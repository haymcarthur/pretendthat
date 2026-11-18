import Foundation
/// Clamps decoded AI output to the spec's limits (§5) instead of crashing on odd JSON.
public enum Sanitizer {
    public enum Limits {
        /// Round 29 (ensemble scenes): 3 scenes.
        public static let ideas = 3, propsMax = 5, itemsMax = 6, scenesMax = 3, choicesMax = 4
        /// Round 29: ONE task for each of the 6 roles a scene, plus one solo task; none for everyone.
        public static let stepsMax = 7, legacyStepsMax = 5
        public static let copies = 1...8
    }

    /// `roleCount` is kept for older callers and ignored: round C1 writes every game for 6 ranked roles, and the app
    /// picks each scene's owner (the hand-offs rotate through the playing roles).
    /// Round 45: `picks` = this game's printables plan: the items become a library kit (`libraryItems`: badges first,
    /// 4 to 6 types, picture-only art, app-picked layouts). Without it, a kit that is already a library kit (the bundled
    /// game) is re-shaped the same way, and an older fixed-six kit keeps the old recipe order.
    public static func clean(_ k: Kit, roleCount: Int = RoleCast.count, picks: PrintPicks? = nil) -> Kit {
        var k = k
        let library = picks != nil || k.items.contains { $0.pictureOnly || ($0.recipe.map { !KitRecipe.original.contains($0) } ?? false) }
        k.items = (library ? libraryItems(k.items, picks: picks ?? PrintPicks(game: nil)) : recipeOrdered(k.items)).map { item in
            var i = item
            i.symbol = PrintSymbols.safe(i.symbol)
            if !i.pictureOnly { i.copies = min(max(i.copies, Limits.copies.lowerBound), Limits.copies.upperBound) }
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

    /// Round 29: at most `PlayCast.stepsPerRole` (1) task per role and one solo task (the first ones); steps for
    /// everyone are dropped. A scene with no role steps (older JSON) keeps its first `legacyStepsMax` steps.
    static func roleSteps(_ steps: [Step]) -> [Step] {
        guard steps.contains(where: { $0.role.role != nil || $0.role == .solo }) else { return Array(steps.prefix(Limits.legacyStepsMax)) }
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

    /// Round 45 (the printables library): one item per type (the first one kept), the badges FIRST (written by the app
    /// if the answer had none), no sign in a game with no place, at most `PrintPicks.maxSwaps` types off a known game's
    /// shortlist, 4 to 6 items (topped up from the shortlist with app-written items), within the image budget per
    /// style (`PrintLibrary.imageBudgetPerStyle`). Each item is shaped by its type: its id is the type (unique in a
    /// kit), its layout variant is picked by the app (`PrintPicks.variant`), its lines and pictures are clamped (few
    /// words: kids 4 to 8), money is $1, menu prices $1 to $5. Idempotent.
    public static func libraryItems(_ items: [KitItem], picks: PrintPicks) -> [KitItem] {
        var seen = Set<KitRecipe>(), out: [KitItem] = [], swaps = 0
        let shortlist = Set(picks.shortlist)
        for var item in items {
            guard let t = item.recipe ?? guess(item), !seen.contains(t) else { continue }
            if t == .sign, picks.noSign { continue }
            if !picks.isMadeUp, !shortlist.contains(t) {
                guard swaps < PrintPicks.maxSwaps else { continue }
                swaps += 1
            }
            item.recipe = t
            seen.insert(t); out.append(item)
        }
        // Badges first, always.
        if let b = out.firstIndex(where: { $0.recipe == .badges }) { out.insert(out.remove(at: b), at: 0) }
        else { out.insert(PrintDefaults.item(.badges, title: nil), at: 0); seen.insert(.badges) }
        // At most 6 (the earliest picks stay), at least 4 (the shortlist's next types, written by the app).
        out = Array(out.prefix(PrintLibrary.maxItems))
        if out.count < PrintLibrary.minItems {
            let fill = (picks.isMadeUp ? PrintDefaults.madeUpTopUp : picks.shortlist + PrintDefaults.madeUpTopUp)
                .filter { !seen.contains($0) && !($0 == .sign && picks.noSign) }
            for t in fill where out.count < PrintLibrary.minItems { out.append(PrintDefaults.item(t, title: nil)); seen.insert(t) }
        }
        out = out.map { shaped($0, picks: picks) }
        // The image budget (one call per printable at most, so 6 items fit; kept as a guard for later types).
        while KitArtPlan.imageCount(out) > PrintLibrary.imageBudgetPerStyle, out.count > PrintLibrary.minItems,
              let drop = out.lastIndex(where: { $0.recipe != .badges && PrintLibrary.art($0) != .none }) {
            out.remove(at: drop)
        }
        return out
    }

    /// One library item, shaped by its type.
    static func shaped(_ item: KitItem, picks: PrintPicks) -> KitItem {
        guard let t = item.recipe else { return item }
        var i = item
        i.id = t.rawValue
        i.kind = t.kind; i.size = t.size; i.perPlayer = t.perPlayer
        i.title = i.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if i.title.isEmpty { i.title = PrintDefaults.title(t) }
        let limits = PrintLibrary.lineLimits(t)
        func short(_ s: String) -> String {
            let ws = s.replacingOccurrences(of: "\"", with: "").split(whereSeparator: \.isWhitespace)
            return ws.prefix(limits.words + (Money.amounts(s).isEmpty ? 0 : 1)).joined(separator: " ")
        }
        i.lines = Array(i.lines.map(short).filter { !$0.isEmpty }.prefix(limits.count.upperBound))
        if i.lines.count < limits.count.lowerBound { i.lines = PrintDefaults.lines(t) }
        switch t {
        case .money: i.bigNumber = Money.bill; i.lines = i.lines.map(Money.oneDollar)
        case .menu, .labels: i.lines = i.lines.map(Money.smallPrices); i.bigNumber = nil
        case .decoder: i.lines = i.lines.map { String($0.uppercased().filter { $0.isLetter || $0 == " " }.prefix(12)) }.filter { !$0.isEmpty }
            if i.lines.isEmpty { i.lines = PrintDefaults.lines(.decoder) }
        default: i.bigNumber = nil
        }
        i.copies = PrintLibrary.copies(i)
        // Pictures: never words (one per entry for a sheet type, else one), at most the sheet's size.
        let pics = (i.pictures ?? []).map(PrintLibrary.clean).filter { !$0.isEmpty }
        switch t {
        case .badges, .cutouts, .decoder: i.pictures = nil
        default:
            let want = PrintLibrary.perEntryPictures(t) ? min(PrintLibrary.maxSheetPictures, i.lines.count) : 1
            var p = Array(pics.prefix(want))
            if p.count < want {
                let extra = PrintLibrary.perEntryPictures(t) ? i.lines.dropFirst(p.count).map { PrintLibrary.clean(Money.withoutPrice($0)) }
                    : [PrintLibrary.clean(i.title)]
                p += extra.prefix(want - p.count)
            }
            i.pictures = p
        }
        if let v = i.variant, !t.variants.contains(v) { i.variant = nil }
        if i.variant == nil { i.variant = picks.variant(for: i) }
        if t == .menu, i.variant == .program { i.lines = i.lines.map(Money.withoutPrice) }
        return i
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

    /// Round 45: the line without its price ("Pancakes $3" → "Pancakes"; "Juice box  2" → "Juice box").
    public static func withoutPrice(_ line: String) -> String {
        var s = replace(amount, in: line) { _ in "" }
        s = s.replacingOccurrences(of: #"\s+\d+\s*$"#, with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–:.")))
    }
    /// Round 45: the price on a line as the app prints it ("$3"), or nil (a show's act has none).
    public static func price(_ line: String) -> String? {
        if let a = amounts(line).first { return smallPrices(a).replacingOccurrences(of: " ", with: "") }
        if let r = line.range(of: #"\s(\d)\s*$"#, options: .regularExpression) {
            return smallPrices("$" + line[r].trimmingCharacters(in: .whitespaces))
        }
        return nil
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
