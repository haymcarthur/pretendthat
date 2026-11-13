import Foundation

public struct KitSlot: Equatable, Sendable {
    /// The player this copy is for; nil = blank "Name: ____" (shared item, or Director mode).
    public var player: PlayerToken?
    public var index: Int
}

public struct KitPage: Equatable, Sendable, Identifiable {
    public var id: String { "\(item.id)-\(pageIndex)" }
    public var item: KitItem
    public var pageIndex: Int
    public var slots: [KitSlot]
}

/// Paginates kit items onto US Letter pages (spec §6): 8 tickets/bills/keycards, 6 badges, or 1 sheet per page.
public enum KitLayout {
    public static let maxPages = 6

    public struct Grid: Equatable, Sendable {
        public var columns: Int, rows: Int
        public var capacity: Int { columns * rows }
    }

    public static func grid(for size: KitSize) -> Grid {
        switch size {
        case .ticket, .bill, .keycard: Grid(columns: 2, rows: 4)
        case .badge: Grid(columns: 2, rows: 3)
        case .fullPage: Grid(columns: 1, rows: 1)
        }
    }

    public static func pages(for kit: Kit, players: [PlayerToken], directorMode: Bool) -> [KitPage] {
        // 1. Slots per item.
        var perItem: [[KitSlot]] = kit.items.map { item in
            if item.perPlayer {
                if directorMode { return (0..<item.copies).map { KitSlot(player: nil, index: $0) } }
                let who = players.isEmpty ? [PlayerToken.P1] : players
                return who.flatMap { p in (0..<item.copies).map { _ in p } }.enumerated().map { KitSlot(player: $0.element, index: $0.offset) }
            }
            return (0..<item.copies).map { KitSlot(player: nil, index: $0) }
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
        switch item.size {
        case .ticket: shape = "a single wide ticket card (landscape, about 2 by 1)"
        case .bill: shape = "a single play-money bill (landscape, about 2 by 1)"
        case .keycard: shape = "a single key card (landscape, about 2 by 1)"
        case .badge: shape = "a single name badge (portrait)"
        case .fullPage: shape = "a full printable page (portrait, US Letter)"
        }
        var p = """
        Coloring-page line art for a kids' pretend-play game called "\(gameTitle)". Draw \(shape): \(item.title). \
        Black and white only, thick clean outlines, no shading, no gray fills, plain white background, friendly and simple, \
        easy for a 5-year-old to color. Fill the whole image edge to edge with the card design and a thick rounded border.
        """
        if item.size != .fullPage {
            p += " Leave a BLANK white rounded banner across the top quarter of the card with no text in it (a name is written there later)."
        }
        if !text.isEmpty { p += " Spell these words exactly, in big rounded letters: " + text.map { "\"\($0)\"" }.joined(separator: ", ") + "." }
        if let n = item.bigNumber, !n.isEmpty { p += " Show the big number or code \"\(n)\"." }
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
