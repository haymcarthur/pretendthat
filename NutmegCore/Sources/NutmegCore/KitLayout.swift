import Foundation

/// One printed copy. Every card with a name field prints a blank "Name: ________" line: we never ask for kids'
/// names, kids write their own (roles-not-names.md).
public struct KitSlot: Equatable, Sendable {
    /// The role this badge is for (nil on tickets, shared items and spares).
    public var roleID: RoleID?
    public var index: Int
    /// The role title ("Captain"), printed by the app on the badge's role banner.
    public var role: String? = nil
    public init(roleID: RoleID? = nil, index: Int, role: String? = nil) { self.roleID = roleID; self.index = index; self.role = role }
}

public struct KitPage: Equatable, Sendable, Identifiable {
    public var id: String { "\(item.id)-\(pageIndex)" }
    public var item: KitItem
    public var pageIndex: Int
    public var slots: [KitSlot]
    /// Round 46: the art key of this page's whole-page image (`KitArtPlan.pageKey`: the cut-outs' second page is the
    /// skipped props'). Older kits keep the item id. Round 47: a per-player page's art is the 6-piece sheet
    /// (`badges@all`, `tickets@all`); this page prints its first `slots.count` pieces.
    public var artKey: String {
        item.aiPage ? KitArtPlan.pageKey(item, part: pageIndex) : item.id
    }
    /// Round 47: the key a round 46 game saved this per-player page under (`badges@N`, `tickets`), or nil.
    public var legacyArtKey: String? { KitArtPlan.legacyKey(item, players: slots.count) }
    /// Round 47: how many pieces of the per-player sheet this page prints (the playing kids), or nil for other pages.
    public var pieces: Int? { KitArtPlan.perPlayerSheet(item) ? slots.count : nil }
}

/// Paginates kit items onto US Letter pages (spec §6): 8 tickets/bills/keycards, 6 badges, or 1 sheet per page.
/// Small items always fill their page (spares), so no sheet prints mostly blank.
public enum KitLayout {
    public static let maxPages = 7

    public struct Grid: Equatable, Sendable {
        public var columns: Int, rows: Int
        public var capacity: Int { columns * rows }
    }

    /// Per-copy big number: per-kid seats count up (1A, 1B, 1C…); shared items keep theirs.
    public static func bigNumber(for item: KitItem, slot: KitSlot) -> String? {
        guard let n = item.bigNumber, !n.isEmpty else { return nil }
        guard item.perPlayer, let last = n.unicodeScalars.last, CharacterSet.uppercaseLetters.contains(last),
              let base = UnicodeScalar(last.value + UInt32(slot.index)), base.value <= 90 else { return n }
        return String(n.dropLast()) + String(Character(base))
    }

    /// Lines printed on a card (any stray "{P1}"-style placeholder from older JSON is dropped).
    public static func printedLines(for item: KitItem) -> [String] {
        item.lines.filter { !$0.contains("{P") && !$0.contains("{R") }
    }

    public static func grid(for size: KitSize) -> Grid {
        switch size {
        case .ticket, .bill, .keycard: Grid(columns: 2, rows: 4)
        case .badge: Grid(columns: 3, rows: 2)   // portrait badges side by side
        case .fullPage: Grid(columns: 1, rows: 1)
        }
    }
    /// Round 45: a library item's grid comes from its type and layout (an ID-card badge page is 2 × 3, coins 3 × 4…);
    /// an older kit's from its size, as before.
    public static func grid(for item: KitItem) -> Grid {
        guard item.pictureOnly, let t = item.recipe else { return grid(for: item.size) }
        return PrintLibrary.grid(t, item.variant)
    }

    /// Round 45: the number the app prints on THIS copy (every ticket its own seat or number, clue cards 1, 2, 3…).
    public static func copyNumber(for item: KitItem, slot: KitSlot) -> String? {
        PrintLibrary.copyNumber(item, index: slot.index)
    }

    /// Round 46: an AI kit prints ONE page per printable, as drawn (the cut-outs a second page when skipped props were
    /// added). Round 47: a per-player page (badges, tickets) has one slot per playing kid: it prints the first N pieces
    /// of the sheet drawn for 6. The slots are what the app-drawn fallback page prints if
    /// the art never came (round 45's layout). At most 6 printables + the extra cut-outs page = 7 pages.
    static func aiPages(_ kit: Kit, playing: [Role], kids: Int) -> [KitPage] {
        Array(kit.items.flatMap { item -> [KitPage] in
            let cap = grid(for: item).capacity
            if item.recipe == .badges {
                let slots = playing.isEmpty ? (0..<kids).map { KitSlot(index: $0) }
                    : playing.enumerated().map { KitSlot(roleID: $0.element.id, index: $0.offset, role: $0.element.roleName) }
                return [KitPage(item: item, pageIndex: 0, slots: slots)]
            }
            if item.recipe == .tickets {
                return [KitPage(item: item, pageIndex: 0, slots: (0..<min(max(kids, 1), RoleCast.count)).map { KitSlot(index: $0) })]
            }
            let n = item.recipe == .clueCards || item.recipe == .missionCards ? PrintLibrary.copies(item) : cap
            let slots = (0..<max(1, min(n, cap))).map { KitSlot(index: $0) }
            guard KitArtPlan.parts(item).count == 2, let split = item.pageLines else {
                return [KitPage(item: item, pageIndex: 0, slots: slots)]
            }
            var first = item, more = item
            first.lines = Array(item.lines.prefix(split)); more.lines = Array(item.lines.dropFirst(split))
            return [KitPage(item: first, pageIndex: 0, slots: slots), KitPage(item: more, pageIndex: 1, slots: slots)]
        }.prefix(maxPages))
    }

    /// Small items tile the whole sheet (Haylee fix round 1: one ticket in a corner looked broken): round the slot
    /// count up to whole pages. Full-page sheets (capacity 1) are unchanged.
    static func filled(_ slots: [KitSlot], capacity: Int, extra: (Int) -> KitSlot) -> [KitSlot] {
        guard capacity > 1, !slots.isEmpty else { return slots }
        let target = Int(ceil(Double(slots.count) / Double(capacity))) * capacity
        return slots + (slots.count..<target).map(extra)
    }

    /// Badges: exactly one per playing kid (round C1: the first N of the 6 ranked roles, one badge each, slot k = role
    /// Rk's slice of the badge sheet), each with its role title. Tickets: one per kid with a blank name line.
    /// Kids pick their badge after printing.
    public static func pages(for kit: Kit, roles: [Role], playerCount: Int) -> [KitPage] {
        let kids = PlayCast.players(playerCount > 0 ? playerCount : roles.map(\.count).reduce(0, +))
        let playing = RoleCast.playing(roles, kids: kids)
        if kit.items.contains(where: \.aiPage) { return aiPages(kit, playing: playing, kids: kids) }
        // 1. Slots per item.
        var perItem: [[KitSlot]] = kit.items.map { item in
            if item.perPlayer {
                let isBadge = item.recipe == .badges || (item.recipe == nil && item.size == .badge)
                let base: [KitSlot]
                if isBadge, !playing.isEmpty {
                    base = playing.enumerated().map { KitSlot(roleID: $0.element.id, index: $0.offset, role: $0.element.roleName) }
                } else {
                    base = (0..<kids).map { KitSlot(index: $0) }
                }
                // Round 23 (Haylee): exactly one badge per kid (2 kids → 2 badges), no spare badges. Tickets still fill
                // their page (spares keep counting seats).
                if isBadge { return base }
                return filled(base, capacity: grid(for: item).capacity) { k in KitSlot(index: k) }
            }
            // Round 45: a library card page prints its copies (cards fill their page; clue cards one per clue).
            let base = (0..<(item.pictureOnly ? PrintLibrary.copies(item) : item.copies)).map { KitSlot(index: $0) }
            // Clue and mission cards print each card once (a repeated clue would confuse the hunt).
            if item.pictureOnly, item.recipe == .clueCards || item.recipe == .missionCards { return base }
            return filled(base, capacity: grid(for: item).capacity) { k in KitSlot(index: k) }
        }
        // 2. Enforce the page cap: trim trailing slots from the item using the most pages, never below 1 page.
        func pageCount(_ i: Int) -> Int { max(1, Int(ceil(Double(perItem[i].count) / Double(grid(for: kit.items[i]).capacity)))) }
        while perItem.indices.map(pageCount).reduce(0, +) > maxPages {
            guard let i = perItem.indices.filter({ pageCount($0) > 1 }).max(by: { pageCount($0) < pageCount($1) }) else { break }
            let cap = grid(for: kit.items[i]).capacity
            perItem[i] = Array(perItem[i].prefix((pageCount(i) - 1) * cap))
        }
        // 3. Chunk into pages.
        return kit.items.indices.flatMap { i -> [KitPage] in
            let cap = grid(for: kit.items[i]).capacity
            let slots = perItem[i].isEmpty ? [KitSlot(index: 0)] : perItem[i]
            return stride(from: 0, to: slots.count, by: cap).enumerated().map { n, start in
                KitPage(item: kit.items[i], pageIndex: n, slots: Array(slots[start..<min(start + cap, slots.count)]))
            }
        }
    }
}

/// On-screen sticker illustrations for off-list props in the voice conversation (D5). Never contains names.
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
