import Foundation

// Data shapes from spec §6. Field names match the JSON the model returns.

/// A role slot (decision roles-not-names.md): we never ask for kids' names, so everything that used to belong
/// to a player belongs to a ROLE. R1…R4 also pick the role's color. At most 4 distinct roles; more kids share roles.
public enum RoleID: String, Codable, Sendable, CaseIterable, Hashable {
    case R1, R2, R3, R4
    public var index: Int { RoleID.allCases.firstIndex(of: self)! }
}

public enum SceneOwner: String, Codable, Sendable, Hashable {
    case R1, R2, R3, R4, all
    public var role: RoleID? { RoleID(rawValue: rawValue) }
}

public enum KitKind: String, Codable, Sendable { case card, sheet }

/// The fixed kit recipe (decision kit-recipe.md): every kit has these 6 item types, in this order.
/// The AI fills in titles, wording, numbers and what goes on each; the app fixes the shape of each.
public enum KitRecipe: String, Codable, Sendable, CaseIterable {
    case badges, sign, money, tickets, menu, cutouts
    public var kind: KitKind { self == .badges || self == .money || self == .tickets ? .card : .sheet }
    public var size: KitSize {
        switch self {
        case .badges: .badge
        case .money: .bill
        case .tickets: .ticket
        case .sign, .menu, .cutouts: .fullPage
        }
    }
    /// One per kid (each prints a blank "Name: ____" line the kids write on themselves).
    public var perPlayer: Bool { self == .badges || self == .tickets }
    public var copies: Int { self == .money ? 8 : 1 }
    public var guide: String {
        switch self {
        case .badges: "role badges, one per kid (the app prints each role title and a blank Name line the kids write on)"
        case .sign: "a sign to hang up with the place's name, e.g. \"Cozy Café\" or \"Sky Airlines Gate 3\""
        case .money: "play money: one design of $1 bills themed to the game; every bill is worth one dollar, so bigNumber is always \"$1\" and no other amounts appear"
        case .tickets: "tickets or passes that fit the game (boarding passes, appointment cards, room keycards, order tickets, admission tickets)"
        case .menu: "a menu for food games, otherwise a price list or services sheet (lines = items with small whole-dollar prices from $1 to $5, e.g. \"Pancakes $3\"; no cents, nothing over $5, so kids can pay with $1 bills)"
        case .cutouts: "a page of 6 to 8 themed prop cut-outs (food for food games; tools for doctor/vet/engineer; luggage and snacks for airplane); lines = the items"
        }
    }
}
public enum KitSize: String, Codable, Sendable { case ticket, badge, bill, keycard, fullPage }

public struct GameIdea: Codable, Equatable, Sendable, Identifiable {
    /// `emoji` is legacy and never shown (checklist-pictures.md: no emoji); the schema no longer asks for it.
    public var id: String; public var title: String; public var emoji: String; public var pitch: String
    public init(id: String, title: String, emoji: String = "", pitch: String) { self.id = id; self.title = title; self.emoji = emoji; self.pitch = pitch }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); title = try c.decode(String.self, forKey: .title)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""; pitch = try c.decode(String.self, forKey: .pitch)
    }
}
public struct GameIdeas: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var ideas: [GameIdea]
    public init(nutmegSays: String, ideas: [GameIdea]) { self.nutmegSays = nutmegSays; self.ideas = ideas }
    /// What Nutmeg says out loud: the ideas are talked about only (no game cards on screen), so the line names every
    /// idea unless it already does ("... Which one? Airplane, Restaurant, or Animal Doctor?").
    public var spoken: String {
        let titles = ideas.map(\.title)
        guard !titles.isEmpty, !titles.allSatisfy({ nutmegSays.localizedCaseInsensitiveContains($0) }) else { return nutmegSays }
        let list = titles.count == 1 ? titles[0] : titles.dropLast().joined(separator: ", ") + (titles.count > 2 ? "," : "") + " or " + titles.last!
        return "\(nutmegSays) \(list)?"
    }
}

public struct Role: Codable, Equatable, Sendable, Identifiable {
    public var id: RoleID; public var roleName: String; public var emoji: String; public var symbol: String; public var job: String
    /// How many kids play this role (more than 1 only when there are more kids than distinct roles: "2 Passengers").
    public var count: Int
    public init(id: RoleID, roleName: String, emoji: String, symbol: String, job: String, count: Int = 1) {
        self.id = id; self.roleName = roleName; self.emoji = emoji; self.symbol = symbol; self.job = job; self.count = count
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(RoleID.self, forKey: .id); roleName = try c.decode(String.self, forKey: .roleName)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""; symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "star"
        job = try c.decode(String.self, forKey: .job); count = max(1, try c.decodeIfPresent(Int.self, forKey: .count) ?? 1)
    }
    /// "the Captain" / "a Passenger" (hand-off lines).
    public var spoken: String { (count > 1 ? "a " : "the ") + roleName }
}
public struct GamePlan: Codable, Equatable, Sendable {
    public var gameTitle: String; public var gameEmoji: String; public var setting: String; public var roles: [Role]; public var nutmegSays: String
    public init(gameTitle: String, gameEmoji: String = "", setting: String, roles: [Role], nutmegSays: String) {
        self.gameTitle = gameTitle; self.gameEmoji = gameEmoji; self.setting = setting; self.roles = roles; self.nutmegSays = nutmegSays
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameTitle = try c.decode(String.self, forKey: .gameTitle); gameEmoji = try c.decodeIfPresent(String.self, forKey: .gameEmoji) ?? ""
        setting = try c.decode(String.self, forKey: .setting); roles = try c.decode([Role].self, forKey: .roles)
        nutmegSays = try c.decode(String.self, forKey: .nutmegSays)
    }
    public func role(for id: RoleID) -> Role? { roles.first { $0.id == id } }
    /// Kids covered by the roles (badges printed).
    public var kidCount: Int { roles.map(\.count).reduce(0, +) }
}

/// A household prop. Props always come from the library (checklist-pictures.md): `id`/`libraryID` is a PropLibrary id
/// and the card shows its hand-drawn art; `emoji` is legacy and never shown.
public struct Prop: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var householdItem: String; public var becomes: String; public var emoji: String?
    public var forRole: SceneOwner; public var safetyOK: Bool
    /// Voice conversation only: the PropLibrary ID (nil = free text, generated art), 1–2 ready alternates,
    /// and "we'll pretend" when the kids skip it (props never block progress).
    public var libraryID: String?
    public var alternates: [String]?
    public var skipped: Bool?
    public var swapped: Bool?
    /// Round 24: the short kid-friendly "why it works" ("A bowl is round like a captain's hat!").
    public var reason: String?
    public init(id: String, householdItem: String, becomes: String, emoji: String? = nil, forRole: SceneOwner, safetyOK: Bool,
                libraryID: String? = nil, alternates: [String]? = nil, skipped: Bool? = nil, reason: String? = nil) {
        self.id = id; self.householdItem = householdItem; self.becomes = becomes; self.emoji = emoji; self.forRole = forRole; self.safetyOK = safetyOK
        self.libraryID = libraryID; self.alternates = alternates; self.skipped = skipped; self.reason = reason
    }
    public var isSkipped: Bool { skipped ?? false }
}
public struct Props: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var props: [Prop]
    public init(nutmegSays: String, props: [Prop]) { self.nutmegSays = nutmegSays; self.props = props }
}

public struct KitItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var recipe: KitRecipe?; public var kind: KitKind; public var size: KitSize; public var title: String; public var symbol: String
    public var lines: [String]; public var bigNumber: String?; public var perPlayer: Bool; public var copies: Int; public var colorMe: Bool
    public init(id: String, recipe: KitRecipe? = nil, kind: KitKind, size: KitSize, title: String, symbol: String, lines: [String], bigNumber: String?, perPlayer: Bool, copies: Int, colorMe: Bool) {
        self.id = id; self.recipe = recipe; self.kind = kind; self.size = size; self.title = title; self.symbol = symbol; self.lines = lines
        self.bigNumber = bigNumber; self.perPlayer = perPlayer; self.copies = copies; self.colorMe = colorMe
    }
    // bigNumber must encode as an explicit null (schema requires the key).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encodeIfPresent(recipe, forKey: .recipe); try c.encode(kind, forKey: .kind); try c.encode(size, forKey: .size)
        try c.encode(title, forKey: .title); try c.encode(symbol, forKey: .symbol); try c.encode(lines, forKey: .lines)
        try c.encode(bigNumber, forKey: .bigNumber); try c.encode(perPlayer, forKey: .perPlayer)
        try c.encode(copies, forKey: .copies); try c.encode(colorMe, forKey: .colorMe)
    }
}
/// One checklist step: short text plus exactly ONE picture (prop, action or kit item; checklist-pictures.md).
public struct Step: Codable, Equatable, Sendable {
    public var picture: Picture; public var text: String
    public init(picture: Picture, text: String) { self.picture = picture; self.text = text }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        picture = try c.decodeIfPresent(Picture.self, forKey: .picture) ?? .point; text = try c.decode(String.self, forKey: .text)
    }
}
/// `Scene` clashes with SwiftUI.Scene in the app target; use `KitScene` there.
public typealias KitScene = Scene

public struct Scene: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var owner: SceneOwner; public var title: String; public var picture: Picture; public var nutmegSays: String; public var steps: [Step]
    public init(id: String, owner: SceneOwner, title: String, picture: Picture, nutmegSays: String, steps: [Step]) {
        self.id = id; self.owner = owner; self.title = title; self.picture = picture; self.nutmegSays = nutmegSays; self.steps = steps
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); owner = try c.decode(SceneOwner.self, forKey: .owner)
        title = try c.decode(String.self, forKey: .title); picture = try c.decodeIfPresent(Picture.self, forKey: .picture) ?? .point
        nutmegSays = try c.decode(String.self, forKey: .nutmegSays); steps = try c.decode([Step].self, forKey: .steps)
    }
}
public struct Kit: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var items: [KitItem]; public var scenes: [Scene]
    public init(nutmegSays: String, items: [KitItem], scenes: [Scene]) { self.nutmegSays = nutmegSays; self.items = items; self.scenes = scenes }
}

public struct Choice: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var label: String; public var emoji: String
    public init(id: String, label: String, emoji: String = "") { self.id = id; self.label = label; self.emoji = emoji }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); label = try c.decode(String.self, forKey: .label)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""
    }
}
public struct NutmegTurn: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var choices: [Choice]; public var understood: Bool
    public init(nutmegSays: String, choices: [Choice], understood: Bool) { self.nutmegSays = nutmegSays; self.choices = choices; self.understood = understood }
}

/// Most kids one game supports (round 23, Haylee: capped at 6; roles past 4 are shared).
public enum Players {
    public static let max = 6
    /// What Nutmeg says when a kid says more than 6 ("eight friends"): cheerful, then asks if 6 is okay.
    public static let overCapLine = "Wow, what a big crew! Up to six friends can play. Should we make it six?"
    /// The set_player_count result for a number over the cap: nothing changes; she says the line and waits.
    public static func overCapOutput(said n: Int) -> String {
        "Too many: \(n) is more than \(max). Nothing changed. Say exactly this and nothing else: \"\(overCapLine)\" "
            + "Then wait: if they agree (\"yes\", \"okay\", \"six\"), call set_player_count with 6; if they say another "
            + "number from 1 to 6, call set_player_count with it."
    }
}
