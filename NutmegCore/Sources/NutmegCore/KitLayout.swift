import Foundation

public struct KitSlot: Equatable, Sendable {
    /// The player this copy is for; nil = blank "Name: ____" (shared item, or Director mode).
    public var player: PlayerToken?
    public var index: Int
    /// The player's role ("Captain"), from their assignment; the app prints it on badges and tickets.
    public var role: String? = nil
}

public struct KitPage: Equatable, Sendable, Identifiable {
    public var id: String { "\(item.id)-\(pageIndex)" }
    public var item: KitItem
    public var pageIndex: Int
    public var slots: [KitSlot]
}

/// Paginates kit items onto US Letter pages (spec §6): 8 tickets/bills/keycards, 6 badges, or 1 sheet per page.
/// Small items always fill their page (spares), so no sheet prints mostly blank.
public enum KitLayout {
    public static let maxPages = 7

    public struct Grid: Equatable, Sendable {
        public var columns: Int, rows: Int
        public var capacity: Int { columns * rows }
    }

    /// Per-copy big number: per-player seats count up (1A, 1B, 1C…); shared items keep theirs.
    public static func bigNumber(for item: KitItem, slot: KitSlot) -> String? {
        guard let n = item.bigNumber, !n.isEmpty else { return nil }
        guard item.perPlayer, let last = n.unicodeScalars.last, CharacterSet.uppercaseLetters.contains(last),
              let base = UnicodeScalar(last.value + UInt32(slot.index)), base.value <= 90 else { return n }
        return String(n.dropLast()) + String(Character(base))
    }

    /// Lines printed on a card. Lines with a player token are dropped: the name banner already shows the name.
    public static func printedLines(for item: KitItem) -> [String] {
        item.lines.filter { !$0.contains("{P") }
    }

    public static func grid(for size: KitSize) -> Grid {
        switch size {
        case .ticket, .bill, .keycard: Grid(columns: 2, rows: 4)
        case .badge: Grid(columns: 3, rows: 2)   // portrait badges side by side
        case .fullPage: Grid(columns: 1, rows: 1)
        }
    }

    /// Small items tile the whole sheet (Haylee fix round 1: one ticket in a corner looked broken): round the slot
    /// count up to whole pages. Full-page sheets (capacity 1) are unchanged.
    static func filled(_ slots: [KitSlot], capacity: Int, extra: (Int) -> KitSlot) -> [KitSlot] {
        guard capacity > 1, !slots.isEmpty else { return slots }
        let target = Int(ceil(Double(slots.count) / Double(capacity))) * capacity
        return slots + (slots.count..<target).map(extra)
    }

    /// `roles`: each player's role name (from the plan), printed by the app on their badge/ticket so every badge
    /// shows the right role (the art is role-neutral and shared).
    public static func pages(for kit: Kit, players: [PlayerToken], directorMode: Bool,
                             roles: [PlayerToken: String] = [:]) -> [KitPage] {
        // 1. Slots per item.
        var perItem: [[KitSlot]] = kit.items.map { item in
            if item.perPlayer {
                // Director mode: 5+ kids and no names, so print a full page of blank ones (copies is "per player").
                if directorMode {
                    let n = max(item.copies, grid(for: item.size).capacity)
                    return (0..<n).map { KitSlot(player: nil, index: $0) }
                }
                let who = players.isEmpty ? [PlayerToken.P1] : players
                // Every player gets their copies; then the page is filled by cycling the players again (spares),
                // each copy keeping its player's seat/number (index = the player's position).
                let base = who.enumerated().flatMap { n, p in (0..<item.copies).map { _ in KitSlot(player: p, index: n, role: roles[p]) } }
                return filled(base, capacity: grid(for: item.size).capacity) { k in base[k % base.count] }
            }
            let base = (0..<item.copies).map { KitSlot(player: nil, index: $0) }
            return filled(base, capacity: grid(for: item.size).capacity) { k in KitSlot(player: nil, index: k) }
        }
        // 2. Enforce the page cap: trim trailing slots from the item using the most pages, never below 1 page.
        func pageCount(_ i: Int) -> Int { max(1, Int(ceil(Double(perItem[i].count) / Double(grid(for: kit.items[i].size).capacity)))) }
        while perItem.indices.map(pageCount).reduce(0, +) > maxPages {
            guard let i = perItem.indices.filter({ pageCount($0) > 1 }).max(by: { pageCount($0) < pageCount($1) }) else { break }
            let cap = grid(for: kit.items[i].size).capacity
            perItem[i] = Array(perItem[i].prefix((pageCount(i) - 1) * cap))
        }
        // 3. Chunk into pages.
        return kit.items.indices.flatMap { i -> [KitPage] in
            let cap = grid(for: kit.items[i].size).capacity
            let slots = perItem[i].isEmpty ? [KitSlot(player: nil, index: 0)] : perItem[i]
            return stride(from: 0, to: slots.count, by: cap).enumerated().map { n, start in
                KitPage(item: kit.items[i], pageIndex: n, slots: Array(slots[start..<min(start + cap, slots.count)]))
            }
        }
    }
}

/// Builds the OpenAI image prompt for one kit item's artwork. Names are never included:
/// the art has a blank name banner and the app writes names on it (names never leave the iPad).
public enum KitArtPrompt {
    public static func prompt(for item: KitItem, gameTitle: String) -> String {
        let text = item.lines.filter { !$0.contains("{P") }
        let shape: String
        switch item.recipe {
        case .sign?: shape = "a big sign to hang on the wall (portrait, US Letter) with a decorative theater-style border"
        case .money?: shape = "a single play-money bill (landscape, about 2 by 1) with an ornate border and a big value in the corners"
        case .menu?: shape = "a full-page menu or price list (portrait, US Letter) with a little picture next to each line"
        case .cutouts?: shape = "a full page (portrait, US Letter) of 6 to 8 separate cut-out props, each a simple object with a thick cut-around outline and space between them"
        case .badges?: shape = "a single name badge (portrait) with a clip hole at the top and one cute themed picture in the middle"
        case .tickets?: shape = item.size == .keycard ? "a single key card (landscape, about 2 by 1)" : "a single ticket or pass (landscape, about 2 by 1)"
        case nil:
            switch item.size {
            case .ticket: shape = "a single wide ticket card (landscape, about 2 by 1)"
            case .bill: shape = "a single play-money bill (landscape, about 2 by 1)"
            case .keycard: shape = "a single key card (landscape, about 2 by 1)"
            case .badge: shape = "a single name badge (portrait)"
            case .fullPage: shape = "a full printable page (portrait, US Letter)"
            }
        }
        var p = """
        Coloring-page line art for a kids' pretend-play game called "\(gameTitle)". Draw \(shape): \(item.title). \
        Black and white only, thick clean outlines, no shading, no gray fills, plain white background, friendly and simple, \
        easy for a 5-year-old to color. Fill the whole image edge to edge with the card design and a thick rounded border.
        """
        if item.recipe == .money || (item.recipe == nil && item.size == .bill) {
            p += " This is play money: no name field, no \"Name:\" label, no blank lines or banners to write on."
        } else if item.size != .fullPage {
            p += " Leave a BLANK white rounded banner across the top quarter of the card with no text in it (a name is written there later)."
        }
        let isBadge = item.recipe == .badges || (item.recipe == nil && item.size == .badge)
        if isBadge {
            // One shared, role-neutral badge: the app writes each player's NAME and ROLE on it, so it's always right.
            p += " Also leave a second BLANK white rounded banner across the bottom fifth (a role is written there later)."
            p += " Write no words or letters anywhere on the badge."
        } else if item.recipe == .cutouts, !text.isEmpty {
            p += " Draw these items, one each, with no words: " + text.joined(separator: ", ") + "."
            p += " Title at the top in big rounded letters: \"\(item.title)\"."
        } else if !text.isEmpty { p += " Spell these words exactly, in big rounded letters: " + text.map { "\"\($0)\"" }.joined(separator: ", ") + "." }
        if let n = item.bigNumber, !n.isEmpty, !isBadge { p += " Show the big number or code \"\(n)\"." }
        p += " Do not add any other words. No real brands, no logos, nothing scary."
        return p
    }

    /// Image size to request per item shape.
    public static func size(for item: KitItem) -> String {
        switch item.size {
        case .badge, .fullPage: "1024x1536"
        default: "1536x1024"
        }
    }
}

/// On-screen sticker illustrations for ideas, roles and props in the voice conversation (D5). Never contains names.
public enum StickerPrompt {
    public enum Kind: Sendable { case idea, role, prop }

    public static func prompt(_ kind: Kind, subject: String, detail: String = "", game: String?) -> String {
        let what: String
        switch kind {
        case .idea: what = "a scene icon for a kids' pretend-play game: \(subject)" + (detail.isEmpty ? "" : " (\(detail))")
        case .role: what = "a cute cartoon animal character dressed up as the \(subject)" + (detail.isEmpty ? "" : ", \(detail)")
                    + (game.map { ", in a pretend game of \($0)" } ?? "")
        case .prop: what = "\(subject)" + (detail.isEmpty ? "" : " pretending to be \(detail)") + ", a household item for pretend play"
        }
        return """
        Flat vector sticker illustration of \(what). Bold simple rounded shapes, thick dark purple outlines, \
        a thick white sticker border around the whole shape, brand palette: coral red, deep purple, sunny yellow, \
        lime green, cream. Cheerful and friendly for kids ages 4 to 8. Centered, one subject, no drop shadow, \
        transparent background. No text, no letters, no numbers, no logos, no real brands, nothing scary.
        """
    }
}
