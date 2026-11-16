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

    /// Small items tile the whole sheet (Haylee fix round 1: one ticket in a corner looked broken): round the slot
    /// count up to whole pages. Full-page sheets (capacity 1) are unchanged.
    static func filled(_ slots: [KitSlot], capacity: Int, extra: (Int) -> KitSlot) -> [KitSlot] {
        guard capacity > 1, !slots.isEmpty else { return slots }
        let target = Int(ceil(Double(slots.count) / Double(capacity))) * capacity
        return slots + (slots.count..<target).map(extra)
    }

    /// Badges: exactly one per kid, grouped by role (a role played by 2 kids prints 2 badges), each with its role title.
    /// Tickets: one per kid with a blank name line. Kids pick their badge after printing.
    public static func pages(for kit: Kit, roles: [Role], playerCount: Int) -> [KitPage] {
        let kids = max(1, max(playerCount, roles.map(\.count).reduce(0, +)))
        // 1. Slots per item.
        var perItem: [[KitSlot]] = kit.items.map { item in
            if item.perPlayer {
                let isBadge = item.recipe == .badges || (item.recipe == nil && item.size == .badge)
                let base: [KitSlot]
                if isBadge, !roles.isEmpty {
                    base = roles.flatMap { r in (0..<r.count).map { _ in KitSlot(roleID: r.id, index: 0, role: r.roleName) } }
                        .enumerated().map { var s = $0.element; s.index = $0.offset; return s }
                } else {
                    base = (0..<kids).map { KitSlot(index: $0) }
                }
                // Round 23 (Haylee): exactly one badge per kid (2 kids → 2 badges), no spare badges. Tickets still fill
                // their page (spares keep counting seats).
                if isBadge { return base }
                return filled(base, capacity: grid(for: item.size).capacity) { k in KitSlot(index: k) }
            }
            let base = (0..<item.copies).map { KitSlot(index: $0) }
            return filled(base, capacity: grid(for: item.size).capacity) { k in KitSlot(index: k) }
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
            let slots = perItem[i].isEmpty ? [KitSlot(index: 0)] : perItem[i]
            return stride(from: 0, to: slots.count, by: cap).enumerated().map { n, start in
                KitPage(item: kit.items[i], pageIndex: n, slots: Array(slots[start..<min(start + cap, slots.count)]))
            }
        }
    }
}

/// Builds the OpenAI image prompt for one kit item's artwork. There are no kids' names anywhere: the art has a
/// blank banner where the app prints a "Name: ____" line for kids to write on, and badges a second one for the role.
public enum KitArtPrompt {
    /// Round 20: the art style for the kids' choice. "I'll color them": the thick-outline coloring page (unchanged).
    /// Full color: a full-color kid-friendly illustration (no line-art or coloring-page wording).
    public static func style(_ style: PrintStyle, cutout: Bool) -> String {
        switch style {
        case .colorIn:
            return "Black and white only, thick clean outlines, no shading, no gray fills, plain white background, "
                + "friendly and simple, easy for a 5-year-old to color\(cutout ? " and cut out" : "")."
        case .fullColor:
            return "Full-color, kid-friendly cartoon illustration: bright cheerful colors with flat fills, bold clean "
                + "dark outlines, soft and friendly shapes, plain white background, simple and easy for a 5-year-old to "
                + "read\(cutout ? " and cut out" : "")."
        }
    }

    static func opener(_ style: PrintStyle, gameTitle: String) -> String {
        (style == .fullColor ? "Printable full-color art" : "Coloring-page line art")
            + " for a kids' pretend-play game called \"\(gameTitle)\"."
    }

    public static func prompt(for item: KitItem, gameTitle: String, style printStyle: PrintStyle = .colorIn) -> String {
        let text = KitLayout.printedLines(for: item)
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
        var p = opener(printStyle, gameTitle: gameTitle) + " Draw \(shape): \(item.title). " + style(printStyle, cutout: false)
            + " Fill the whole image edge to edge with the card design and a thick rounded border."
        if item.recipe == .money || (item.recipe == nil && item.size == .bill) {
            p += " This is play money: no name field, no \"Name:\" label, no blank lines or banners to write on."
            if item.recipe == .money { p += " It is a ONE-dollar bill: the only amount anywhere on it is \"\(Money.bill)\"." }
        } else if item.size != .fullPage {
            p += " Leave a BLANK white rounded banner across the top quarter of the card with no text in it (a blank name line is printed there later)."
        }
        let isBadge = item.recipe == .badges || (item.recipe == nil && item.size == .badge)
        if isBadge {
            // One shared, role-neutral badge: the app prints each ROLE title and a blank name line on it.
            p += " Also leave a second BLANK white rounded banner across the bottom fifth (a role title is printed there later)."
            p += " Write no words or letters anywhere on the badge."
        } else if item.recipe == .cutouts, !text.isEmpty {
            p += " Draw these items, one each, with no words: " + text.joined(separator: ", ") + "."
            p += " Title at the top in big rounded letters: \"\(item.title)\"."
        } else if !text.isEmpty { p += " Spell these words exactly, in big rounded letters: " + text.map { "\"\($0)\"" }.joined(separator: ", ") + "." }
        if let n = item.bigNumber, !n.isEmpty, !isBadge { p += " Show the big number or code \"\(n)\"." }
        p += " Do not add any other words. No real brands, no logos, nothing scary."
        return p + ImageSafety.suffix   // round 19
    }

    /// One cut-out on its own (checklist-pictures.md): the cut-outs page is generated as one image per item so each
    /// food/tool item can also be a checklist picture; the app tiles them onto the printed page.
    public static func cutoutPrompt(_ label: String, gameTitle: String, style printStyle: PrintStyle = .colorIn) -> String {
        opener(printStyle, gameTitle: gameTitle) + " Draw ONE cut-out prop: \(label). A single simple object, centered, "
            + "filling most of the square, with a thick cut-around outline and white space around it. "
            + style(printStyle, cutout: true)
            + " No words, letters or numbers. No real brands, no logos, nothing scary." + ImageSafety.suffix   // round 19
    }

    /// Round 20 (cost): the themed cut-outs as ONE sheet, a grid the app slices back into one picture per cut-out.
    public static func cutoutSheetPrompt(_ labels: [String], gameTitle: String, style printStyle: PrintStyle = .colorIn) -> String {
        let (cols, rows) = CutoutSheet.grid(labels.count)
        let list = labels.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: ", ")
        return opener(printStyle, gameTitle: gameTitle) + " Draw a sheet of exactly \(labels.count) separate cut-out props "
            + "in a grid of \(cols) columns and \(rows) row\(rows == 1 ? "" : "s"), in this order, left to right and top to "
            + "bottom: \(list). Each prop is ONE simple object centered in its own equal grid cell, filling most of the "
            + "cell, with a thick cut-around outline. Leave wide plain white gaps between the cells; nothing touches or "
            + "crosses into another cell, no grid lines, no borders, no frames. " + style(printStyle, cutout: true)
            + " No words, letters or numbers. No real brands, no logos, nothing scary." + ImageSafety.suffix
    }

    /// The cut-out items of a kit (the cutouts item's lines, 6 to 8).
    public static func cutoutLabels(_ item: KitItem) -> [String] {
        item.recipe == .cutouts ? Array(item.lines.prefix(PictureResolver.maxCutouts)) : []
    }

    /// Image size to request per item shape.
    public static func size(for item: KitItem) -> String {
        switch item.size {
        case .badge, .fullPage: "1024x1536"
        default: "1536x1024"
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
