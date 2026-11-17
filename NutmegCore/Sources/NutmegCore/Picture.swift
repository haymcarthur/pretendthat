import Foundation

/// Checklist and scene pictures (decision checklist-pictures.md): no emoji. Every step and scene title points at ONE
/// picture of one of three kinds: a household prop from the library (`prop-<id>` art), an action (`action-<id>` art
/// Haylee is drawing), or a printed item from THIS game's generated kit (a ticket, a bill, a role's badge, the menu,
/// the sign, or one specific cut-out).
public enum PictureKind: String, Codable, Sendable, CaseIterable { case prop, action, kit }

public struct Picture: Codable, Equatable, Sendable, Hashable {
    public var kind: PictureKind
    public var id: String
    public init(kind: PictureKind, id: String) { self.kind = kind; self.id = id }
    public static func prop(_ id: String) -> Picture { Picture(kind: .prop, id: id) }
    public static func action(_ id: String) -> Picture { Picture(kind: .action, id: id) }
    public static func kit(_ id: String) -> Picture { Picture(kind: .kit, id: id) }
    /// The fallback when a picture can't be resolved.
    public static let point = Picture.action("point")
}

/// The action art set (`action-<id>`; placeholders until Haylee's vectors arrive).
public enum ActionArt {
    public static let ids = ["wave", "clap", "point", "listen", "look", "count", "give", "knock", "write", "stir",
                             "brush", "wash", "ring-bell", "stamp", "measure", "cheer"]
    public static func asset(_ id: String) -> String { "action-\(id)" }
    public static func contains(_ id: String) -> Bool { ids.contains(id) }
}

/// What the app draws for a picture.
public enum ResolvedPicture: Equatable, Sendable {
    /// Household-prop library art (`prop-<id>`).
    case prop(String)
    /// Action art (`action-<id>`).
    case action(String)
    /// A whole single-tile kit item (ticket, bill, menu, sign), or a role's badge (role title overlaid).
    case kitItem(itemID: String, recipe: KitRecipe, role: Role?)
    /// One cut-out from the cut-outs page (each is generated as its own image).
    case cutout(itemID: String, index: Int, label: String)

    public var assetName: String? {
        switch self {
        case .prop(let id): PropLibrary.asset(id)
        case .action(let id): ActionArt.asset(id)
        default: nil
        }
    }
}

public enum PictureResolver {
    public static let fallback = ResolvedPicture.action("point")
    /// Most cut-outs a kit has (the cut-outs page holds 6 to 8).
    public static let maxCutouts = 8

    /// Every kit picture id the scene schema allows (`kit:` ids). Badges name a role id.
    public static let kitIDs: [String] = ["ticket", "money", "menu", "sign"] + RoleID.allCases.map { "badge:\($0.rawValue)" }
        + (0..<maxCutouts).map { "cutout:\($0)" }

    /// Every picture id across the three kinds (the schema's id enum).
    public static let allIDs: [String] = PropLibrary.ids + ActionArt.ids + kitIDs

    public static func resolve(_ picture: Picture?, kit: Kit?, roles: [Role]) -> ResolvedPicture {
        guard let p = picture else { return fallback }
        let id = p.id.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "\(p.kind.rawValue):", with: "")
        switch p.kind {
        case .prop: return PropLibrary.hasArt(id) ? .prop(id) : fallback   // round 43: a retired item keeps its art
        case .action: return ActionArt.contains(id) ? .action(id) : fallback
        case .kit: return resolveKit(id, kit: kit, roles: roles) ?? fallback
        }
    }

    static func resolveKit(_ id: String, kit: Kit?, roles: [Role]) -> ResolvedPicture? {
        guard let kit else { return nil }
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        let head = parts.first ?? "", tail = parts.count > 1 ? parts[1] : nil
        func item(_ r: KitRecipe) -> KitItem? { kit.items.first { $0.recipe == r } }
        switch head {
        case "ticket", "tickets", "pass", "keycard":
            return item(.tickets).map { .kitItem(itemID: $0.id, recipe: .tickets, role: nil) }
        case "money", "bill", "bills":
            return item(.money).map { .kitItem(itemID: $0.id, recipe: .money, role: nil) }
        case "menu": return item(.menu).map { .kitItem(itemID: $0.id, recipe: .menu, role: nil) }
        case "sign": return item(.sign).map { .kitItem(itemID: $0.id, recipe: .sign, role: nil) }
        case "badge", "badges":
            guard let badge = item(.badges) else { return nil }
            let role = tail.flatMap { t in
                roles.first { $0.id.rawValue.lowercased() == t || $0.roleName.lowercased() == t }
            }
            if tail != nil && role == nil { return nil }   // a badge for a role that isn't in this game
            return .kitItem(itemID: badge.id, recipe: .badges, role: role)
        case "cutout", "cutouts":
            guard let cut = item(.cutouts), let n = Int(tail ?? "0"), cut.lines.indices.contains(n) else { return nil }
            return .cutout(itemID: cut.id, index: n, label: cut.lines[n])
        default: return nil
        }
    }
}
