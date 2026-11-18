import Foundation

// 2026-11-18 (Haylee): props can come in multiples. A tea party needs a cup for every player, a vet clinic a few stuffed
// animals as patients. Each prop carries a quantity RULE (not a number): one (the default), one per player, or a fixed
// small number. The AI picks the rule when it shows the prop; the app clamps it. Because the rule is stored, a replay
// with a different player count scales by itself. Every multiple is said and shown as "up to N" (Haylee: families
// without enough should never feel they can't play; ✓ means "we found some").

public enum PropQuantity: Equatable, Sendable, Hashable {
    case one
    case perPlayer
    case fixed(Int)

    /// The most of anything a card asks for (and the cap on a per-player count, which is also `Players.max`).
    public static let maxFixed = 6

    /// Items families usually have several of and that make sense several at a time. Anything else is always one
    /// (a couch, a rug, a wagon, a box of crayons), whatever the AI asked for.
    public static let multipliable: Set<String> = [
        "stuffed-animal", "chair", "pillow", "cushion", "blanket", "towel", "plate", "cup", "plastic-cups", "bowl", "spoon",
        "wooden-spoon", "paper-plate", "plastic-container", "hat", "bag", "paper-bag", "backpack", "toy-car", "ball", "scarf",
        "sock", "headband", "pillowcase", "apron", "tray", "basket", "bucket", "paper-towel-tube", "measuring-cup", "oven-mitt",
    ]
    public static func canMultiply(_ libraryID: String?) -> Bool { libraryID.map(multipliable.contains) ?? false }

    /// The tool's `how_many`: "one", "per_player", or a number 2 to 6 (as a number or a string). Anything else is one.
    public init(toolValue v: Any?) {
        if let s = v as? String {
            let t = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if ["per_player", "per player", "perplayer", "each", "one per player", "every player"].contains(t) { self = .perPlayer; return }
            if let n = Int(t) { self = PropQuantity(number: n); return }
            self = .one; return
        }
        if let n = v as? Int { self = PropQuantity(number: n); return }
        if let d = v as? Double { self = PropQuantity(number: Int(d)); return }
        self = .one
    }
    /// A plain number: 1 or less is one, otherwise a fixed count clamped to `maxFixed`.
    public init(number n: Int) { self = n <= 1 ? .one : .fixed(min(n, Self.maxFixed)) }

    /// How many the card asks for with `players` kids (1 = a single item).
    public func count(players: Int) -> Int {
        switch self {
        case .one: return 1
        case .perPlayer: return max(1, min(players, Players.max))
        case .fixed(let n): return max(1, min(n, Self.maxFixed))
        }
    }

    /// Stored as a short string ("perPlayer", "3"); "one" is never stored (a nil quantity is one), so an older prop and
    /// a single prop encode exactly as before.
    public var stored: String? {
        switch self {
        case .one: return nil
        case .perPlayer: return "perPlayer"
        case .fixed(let n): return n <= 1 ? nil : String(min(n, Self.maxFixed))
        }
    }
    public init(stored s: String?) {
        guard let s else { self = .one; return }
        if s == "perPlayer" { self = .perPlayer; return }
        self = Int(s).map { PropQuantity(number: $0) } ?? .one
    }
}

extension PropQuantity: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = PropQuantity(stored: s) }
        else if let n = try? c.decode(Int.self) { self = PropQuantity(number: n) }
        else { self = .one }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(stored ?? "one")
    }
}

public enum PropCount {
    /// Number words for her voice ("four", never "4").
    public static func word(_ n: Int) -> String {
        let w = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return w.indices.contains(n) ? w[n] : String(n)
    }

    /// "cups", "stuffed animals", "scarves", "boxes" (lowercased). An already-plural name stays as it is.
    public static func plural(_ item: String) -> String {
        var l = item.lowercased().trimmingCharacters(in: .whitespaces)
        if let paren = l.range(of: " (") { l = String(l[..<paren.lowerBound]) }
        guard let lastWord = l.split(separator: " ").last.map(String.init) else { return l }
        let head = l.dropLast(lastWord.count)
        let irregular = ["scarf": "scarves", "loaf": "loaves", "knife": "knives", "mouse": "mice", "person": "people"]
        let p: String
        if let ir = irregular[lastWord] { p = ir }
        else if lastWord.count > 2, lastWord.hasSuffix("s"), !lastWord.hasSuffix("ss") { p = lastWord }   // books, plastic cups
        else if ["s", "x", "z", "ch", "sh"].contains(where: lastWord.hasSuffix) { p = lastWord + "es" }
        else if lastWord.hasSuffix("y"), let before = lastWord.dropLast().last, !"aeiou".contains(before) { p = lastWord.dropLast() + "ies" }
        else { p = lastWord + "s" }
        return head + p
    }
}

extension Prop {
    /// The quantity rule, honoring the item: an item that doesn't come in multiples is always one.
    public var rule: PropQuantity {
        PropQuantity.canMultiply(libraryID ?? id) ? (quantity ?? .one) : .one
    }
    /// How many to find with `players` kids (1 = a single item).
    public func count(players: Int) -> Int { rule.count(players: players) }
    /// The card's title: the item's name, or "Up to 4 plastic cups" for a multiple.
    public func cardTitle(players: Int) -> String {
        let n = count(players: players)
        guard n > 1 else { return householdItem }
        return "Up to \(n) \(PropCount.plural(householdItem))"
    }
    /// The item as rows and guides say it, lowercased: plural for a multiple ("the plastic cups"), whatever the count.
    public var itemWords: String { rule == .one ? householdItem.lowercased() : PropCount.plural(householdItem) }
    /// One prop per player (the line says "one for each player").
    public var isPerPlayer: Bool { rule == .perPlayer }
}
