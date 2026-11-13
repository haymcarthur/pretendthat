import Foundation

// Data shapes from spec §6. Field names match the JSON the model returns.

public enum PlayerToken: String, Codable, Sendable, CaseIterable, Hashable {
    case P1, P2, P3, P4
    public var index: Int { PlayerToken.allCases.firstIndex(of: self)! }
    public var placeholder: String { "{\(rawValue)}" }
}

public enum SceneOwner: String, Codable, Sendable, Hashable {
    case P1, P2, P3, P4, all
    public var token: PlayerToken? { PlayerToken(rawValue: rawValue) }
}

public enum KitKind: String, Codable, Sendable { case card, sheet }
public enum KitSize: String, Codable, Sendable { case ticket, badge, bill, keycard, fullPage }

public struct GameIdea: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var title: String; public var emoji: String; public var pitch: String
    public init(id: String, title: String, emoji: String, pitch: String) { self.id = id; self.title = title; self.emoji = emoji; self.pitch = pitch }
}
public struct GameIdeas: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var ideas: [GameIdea]
    public init(nutmegSays: String, ideas: [GameIdea]) { self.nutmegSays = nutmegSays; self.ideas = ideas }
}

public struct Role: Codable, Equatable, Sendable {
    public var player: PlayerToken; public var roleName: String; public var emoji: String; public var symbol: String; public var job: String
    public init(player: PlayerToken, roleName: String, emoji: String, symbol: String, job: String) {
        self.player = player; self.roleName = roleName; self.emoji = emoji; self.symbol = symbol; self.job = job
    }
}
public struct GamePlan: Codable, Equatable, Sendable {
    public var gameTitle: String; public var gameEmoji: String; public var setting: String; public var roles: [Role]; public var nutmegSays: String
    public init(gameTitle: String, gameEmoji: String, setting: String, roles: [Role], nutmegSays: String) {
        self.gameTitle = gameTitle; self.gameEmoji = gameEmoji; self.setting = setting; self.roles = roles; self.nutmegSays = nutmegSays
    }
    public func role(for t: PlayerToken) -> Role? { roles.first { $0.player == t } }
}

public struct Prop: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var householdItem: String; public var becomes: String; public var emoji: String
    public var forRole: SceneOwner; public var safetyOK: Bool
    public init(id: String, householdItem: String, becomes: String, emoji: String, forRole: SceneOwner, safetyOK: Bool) {
        self.id = id; self.householdItem = householdItem; self.becomes = becomes; self.emoji = emoji; self.forRole = forRole; self.safetyOK = safetyOK
    }
}
public struct Props: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var props: [Prop]
    public init(nutmegSays: String, props: [Prop]) { self.nutmegSays = nutmegSays; self.props = props }
}

public struct KitItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var kind: KitKind; public var size: KitSize; public var title: String; public var symbol: String
    public var lines: [String]; public var bigNumber: String?; public var perPlayer: Bool; public var copies: Int; public var colorMe: Bool
    public init(id: String, kind: KitKind, size: KitSize, title: String, symbol: String, lines: [String], bigNumber: String?, perPlayer: Bool, copies: Int, colorMe: Bool) {
        self.id = id; self.kind = kind; self.size = size; self.title = title; self.symbol = symbol; self.lines = lines
        self.bigNumber = bigNumber; self.perPlayer = perPlayer; self.copies = copies; self.colorMe = colorMe
    }
    // bigNumber must encode as an explicit null (schema requires the key).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(kind, forKey: .kind); try c.encode(size, forKey: .size)
        try c.encode(title, forKey: .title); try c.encode(symbol, forKey: .symbol); try c.encode(lines, forKey: .lines)
        try c.encode(bigNumber, forKey: .bigNumber); try c.encode(perPlayer, forKey: .perPlayer)
        try c.encode(copies, forKey: .copies); try c.encode(colorMe, forKey: .colorMe)
    }
}
public struct Step: Codable, Equatable, Sendable {
    public var emoji: String; public var text: String
    public init(emoji: String, text: String) { self.emoji = emoji; self.text = text }
}
public struct Scene: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var owner: SceneOwner; public var title: String; public var emoji: String; public var nutmegSays: String; public var steps: [Step]
    public init(id: String, owner: SceneOwner, title: String, emoji: String, nutmegSays: String, steps: [Step]) {
        self.id = id; self.owner = owner; self.title = title; self.emoji = emoji; self.nutmegSays = nutmegSays; self.steps = steps
    }
}
public struct Kit: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var items: [KitItem]; public var scenes: [Scene]
    public init(nutmegSays: String, items: [KitItem], scenes: [Scene]) { self.nutmegSays = nutmegSays; self.items = items; self.scenes = scenes }
}

public struct Choice: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var label: String; public var emoji: String
    public init(id: String, label: String, emoji: String) { self.id = id; self.label = label; self.emoji = emoji }
}
public struct NutmegTurn: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var choices: [Choice]; public var understood: Bool
    public init(nutmegSays: String, choices: [Choice], understood: Bool) { self.nutmegSays = nutmegSays; self.choices = choices; self.understood = understood }
}

public struct Player: Equatable, Sendable, Identifiable {
    public var token: PlayerToken; public var name: String; public var colorIndex: Int; public var emoji: String
    public var id: PlayerToken { token }
    public init(token: PlayerToken, name: String, colorIndex: Int, emoji: String) { self.token = token; self.name = name; self.colorIndex = colorIndex; self.emoji = emoji }
    /// Display name, never empty ("Player 2" when no name was captured).
    public var displayName: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Player \(token.index + 1)" : n
    }
    public static let defaultEmojis = ["💙", "🧡", "💚", "💜"]
}
