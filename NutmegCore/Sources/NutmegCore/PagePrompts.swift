import Foundation

// Round 46 (Haylee, decisions/2026-11-17-ai-drawn-printables.md; the approved recipes in
// design/printables-ai-test/scripts/recipes.py): the image model draws each WHOLE printable page (its frame, its layout,
// its decorations and every word) and the app draws nothing on top. Every prompt is the same blocks in this order:
// PAGE + the game + STYLE (one shared line per kit, so the pages look like one set) + the type's layout + WORDS (the
// only words, quoted exactly, with their repeat counts) + CUT (sheets that get cut apart) + SAFE. The 17-type library,
// the shortlists and the layout variants stay; a layout variant is now a prompt variant. The app only places each 2:3
// page image inside the printable area (`PageFit`) and checks its words on the device (`PageWordCheck`).

/// What every page of one kit is drawn for: the game's title and place, the 6 ranked roles and how many kids play.
/// Round 47: the per-player pages (badges, tickets) are drawn for all 6 whatever the count; the count only says how
/// many pieces print.
public struct KitArtContext: Equatable, Sendable {
    public var title: String
    public var setting: String?
    /// The game's 6 ranked roles (R1…R6).
    public var roles: [Role]
    /// How many kids play (1 to 6). Round 47: no prompt depends on it (the badge page always shows all 6 roles).
    public var players: Int
    public init(title: String, setting: String? = nil, roles: [Role] = [], players: Int = RoleCast.count) {
        self.title = title; self.setting = setting; self.roles = roles; self.players = min(max(players, 1), RoleCast.count)
    }
    /// The playing roles (the first N ranked roles).
    public var playing: [Role] { RoleCast.playing(roles, kids: players) }
}

/// One page's image prompt and the words the page must show (every occurrence, so "Name:" on 4 badges is listed 4
/// times), for the on-device word check.
public struct PagePrompt: Equatable, Sendable {
    public var prompt: String
    public var words: [String]
    public init(prompt: String, words: [String]) { self.prompt = prompt; self.words = words }
}

public enum KitPagePrompt {
    /// Every page is a portrait 2:3 image (the API's closest size to a US Letter page); the app fits it in the margins.
    public static let size = "1024x1536"

    // MARK: The shared blocks (word for word from the approved test)

    public static let page = "A printable US Letter portrait page (8.5 by 11 inches) for a kids' pretend-play game, drawn "
        + "flat and straight-on and filling the whole image: the page itself, not a photo or mockup of paper. Plain white "
        + "paper with a clean white margin of about half an inch on every side where nothing is drawn, so it prints on a "
        + "home printer."

    /// The ONE style line every page of a kit shares (the color set or the coloring-page set).
    public static func style(_ s: PrintStyle) -> String {
        switch s {
        case .fullColor:
            return "Art style for the whole kit: bright, friendly flat vector cartoon like a modern kids' picture-book app: "
                + "bold clean dark purple outlines, flat cheerful fills in coral red, sunny yellow, lime green, sky blue, "
                + "deep purple and cream, soft rounded shapes, no gradients, no shading texture, no photo effects, lots of "
                + "white paper. Ink-friendly: color sits on white, no full-page dark background."
        case .colorIn:
            return "Art style for the whole kit: coloring-page version of a friendly flat vector cartoon: black outlines "
                + "only on white paper, thick clean even lines, soft rounded shapes, no color, no gray, no shading, no "
                + "filled black areas, every shape open for a 5-year-old to color in. Letters are bold outlined bubble "
                + "letters that can be colored in too."
        }
    }

    public static let cut = " Thin gray dashed cut lines around each piece, with wide white gutters between pieces so scissors fit."

    /// Kid-safe (round 19's suffix) plus round 46's friendly pirates: no skulls or crossbones anywhere.
    public static let safe = ImageSafety.suffix + " No skulls, no crossbones, no skeletons: pirates and their flags are "
        + "friendly and cheerful."

    /// The exact-words net: the only words, spelled letter for letter (`extra` adds the repeat counts).
    public static func wordsRule(_ words: [String], _ extra: String = "") -> String {
        let q = unique(words).map { "\"\($0)\"" }.joined(separator: ", ")
        return " The ONLY words on the page, spelled exactly letter for letter: \(q).\(extra) Big, clear, rounded print "
            + "letters, easy for a 5-year-old to read, dark on a light background, never curved along a path, never tiny. "
            + "No other words, letters, numbers or signatures anywhere."
    }

    /// PAGE + the game + the kit's style line.
    static func head(_ ctx: KitArtContext, _ s: PrintStyle) -> String {
        let place = (ctx.setting ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let about = place.isEmpty || place.caseInsensitiveCompare(ctx.title) == .orderedSame || place.split(separator: " ").count > 14
            ? "" : " (\(clean(place)))"
        return "\(page) The game is \"\(clean(ctx.title))\"\(about). \(style(s))"
    }

    // MARK: One page

    /// The prompt for one kit page (`part` 1 = the cut-outs' extra page for skipped props), or nil when the page has
    /// nothing to draw (the code decoder is drawn by the app: its symbols must be exact) or isn't a round 46 page.
    public static func prompt(for item: KitItem, ctx: KitArtContext, style s: PrintStyle, part: Int = 0) -> PagePrompt? {
        guard item.aiPage, let t = item.recipe else { return nil }
        let h = head(ctx, s)
        switch t {
        case .badges: return badges(item, ctx, h)
        case .sign: return sign(item, ctx, h)
        case .money: return money(item, h)
        case .tickets: return tickets(item, h)
        case .menu: return menu(item, ctx, h)
        case .cutouts: return cutouts(item, h, part: part)
        case .orderSlips: return orderSlips(item, h)
        case .map: return map(item, ctx, h)
        case .clueCards: return numberedCards(item, h, kind: "clue cards", border: "rope, little stars or seashells", what: "clue", hint: "picture hint")
        case .missionCards: return numberedCards(item, h, kind: "mission cards", border: "little stars, badges or flags", what: "mission", hint: "picture")
        case .log: return log(item, h)
        case .medals: return medals(item, h)
        case .stickers: return stickers(item, h)
        case .passport: return passport(item, h)
        case .labels: return labels(item, h)
        case .controlPanel: return controlPanel(item, h)
        case .decoder: return nil
        }
    }

    /// The redraw after the word check found a word that really is missing or misspelled: the same page, with the
    /// words that came out wrong named once more.
    public static func redraw(_ p: PagePrompt, missing: [String]) -> PagePrompt {
        let m = unique(missing).map { "\"\($0)\"" }.joined(separator: ", ")
        return PagePrompt(prompt: p.prompt + " Check the spelling of every word before finishing, letter by letter, "
                          + "especially \(m): each one must be written exactly as quoted and be easy to read.", words: p.words)
    }

    // MARK: 1. Badges (lanyard / round pin / ID card), drawn for all 6 ranked roles

    /// Round 47 (Haylee): the badge page is drawn ONCE for all 6 ranked roles (in rank order), as a strict grid the app
    /// cuts apart (`SheetCells`) to print only the first N. Tall lanyard tags sit 3 across; round pins and wide ID
    /// cards 2 across.
    public static func badgeGrid(_ v: KitVariant?) -> (columns: Int, rows: Int) {
        v == .pin || v == .idCard ? (2, 3) : (3, 2)
    }

    /// Round 47: the strict-grid words every cut-apart sheet shares (equal pieces, even gutters, nothing between them).
    static func strictGrid(_ n: Int, _ what: String, columns: Int, rows: Int) -> String {
        "Draw a sheet of exactly \(n) \(what) in a strict grid of \(columns) columns and \(rows) rows, filling the page: every "
            + "piece exactly the same size and shape, evenly spaced, with equal wide plain white gutters between them and "
            + "nothing at all drawn in the gutters, each piece whole inside its own cell, never touching or overlapping "
            + "another piece."
    }

    static func badges(_ item: KitItem, _ ctx: KitArtContext, _ h: String) -> PagePrompt {
        let roles = ctx.roles.isEmpty ? [Role(id: .R1, roleName: "Helper", emoji: "", symbol: "star", job: "help everyone")]
            : Array(ctx.roles.prefix(RoleCast.count))
        let n = roles.count
        let titles = roles.map { clean($0.roleName) }
        let list = roles.enumerated().map { i, r in
            let job = clean(r.job)
            return "badge \(i + 1): a cute cartoon character as the \(clean(r.roleName).lowercased())\(job.isEmpty ? "" : " (\(job))"), "
                + "title \"\(clean(r.roleName))\""
        }.joined(separator: "; ")
        let shape: String
        switch item.variant {
        case .pin?:
            shape = "big round pin-back badges with a thick themed rim, one character picture in the middle, the role title "
                + "under it on a straight ribbon banner, and at the bottom the word \"Name:\" followed by a blank line to write on"
        case .idCard?:
            shape = "landscape ID cards with rounded corners and a colored header strip, one character picture on the left, "
                + "and on the right the role title and under it the word \"Name:\" followed by a long blank line to write on"
        default:
            shape = "tall rounded-rectangle tags with a punched hole and a little clip at the top center, a themed "
                + "decorative border, one character picture in the upper half, the role title under it on a ribbon banner, "
                + "and at the bottom the word \"Name:\" followed by a long blank line to write on"
        }
        let what = item.variant == .idCard ? "ID cards" : item.variant == .pin ? "round name badges" : "lanyard name badges"
        let g: (columns: Int, rows: Int) = n == RoleCast.count ? badgeGrid(item.variant) : (min(n, 2), (n + 1) / 2)
        let prompt = h + " " + strictGrid(n, what, columns: g.columns, rows: g.rows) + " Each one: \(shape). In order, left to "
            + "right, top to bottom: \(list)."
            + wordsRule(titles + ["Name:"], " \"Name:\" appears once on every badge (\(n) time\(n == 1 ? "" : "s")).")
            + " Every badge identical in shape and size so they look like a set." + cut + safe
        return PagePrompt(prompt: prompt, words: titles + Array(repeating: "Name:", count: n))
    }

    // MARK: 2. Sign (door / hanging banner / marquee)

    static func sign(_ item: KitItem, _ ctx: KitArtContext, _ h: String) -> PagePrompt {
        let place = clean(item.title)
        let tagline = item.lines.first.map(clean).flatMap { $0.isEmpty ? nil : $0 }
        let picture = picture(item, fallback: place)
        let words = [place] + (tagline.map { [$0] } ?? [])
        let tag = tagline.map { " Near the bottom on a ribbon: \"\($0)\"." } ?? ""
        let body: String
        switch item.variant {
        case .banner?:
            body = " Draw ONE big hanging banner sign that fills the page inside the margin: a wide pennant-shaped banner "
                + "hanging from a rope with little flags along the top and a fun themed frame. Across it in huge letters: "
                + "\"\(place)\". Under the name a big cheerful picture of \(picture).\(tag)"
        case .marquee?:
            body = " Draw ONE big theater marquee sign that fills the page inside the margin: an arched sign board with a "
                + "border of round light bulbs and a fun themed frame. Across the top in huge letters: \"\(place)\". In the "
                + "middle a big cheerful picture of \(picture).\(tag)"
        default:
            body = " Draw ONE big door sign that fills the page inside the margin: a tall rounded sign board with a hanging "
                + "string at the top and a fun themed frame. Across the top in huge letters: \"\(place)\". In the middle a big "
                + "cheerful picture of \(picture).\(tag)"
        }
        return PagePrompt(prompt: h + body + wordsRule(words) + safe, words: words)
    }

    // MARK: 3. Money (bills / coins / tokens), every piece worth one

    static func money(_ item: KitItem, _ h: String) -> PagePrompt {
        let name = clean(item.title)
        let emblem = picture(item, fallback: "a big shining star")
        switch item.variant {
        case .coins?:
            let count = 12
            let p = h + " Draw a sheet of exactly \(count) identical round play coins in a grid of 3 columns and \(count / 3) "
                + "rows, plus the title \"\(name)\" across the top of the page in big letters. Each coin: a thick rim, "
                + "\(emblem) in the middle, and a big \"1\" on it. Every coin is worth one: no other amounts."
                + wordsRule([name, "1"], " \"1\" appears once on every coin (\(count) times).")
                + " Thin gray dashed circle cut lines around each coin, wide white gaps between coins." + safe
            return PagePrompt(prompt: p, words: [name] + Array(repeating: "1", count: count))
        case .tokens?:
            let count = 12
            let p = h + " Draw a sheet of exactly \(count) identical play tokens in a grid of 3 columns and \(count / 3) rows, "
                + "plus the title \"\(name)\" across the top of the page in big letters. Each token: a round token with a "
                + "scalloped star-shaped rim and \(emblem) in the middle, with no numbers or writing on the tokens."
                + wordsRule([name], " \"\(name)\" appears only once, at the top.")
                + " Thin gray dashed circle cut lines around each token, wide white gaps between tokens." + safe
            return PagePrompt(prompt: p, words: [name])
        default:
            let count = 8
            let p = h + " Draw a sheet of exactly \(count) identical play-money bills in a grid of 2 columns and \(count / 2) "
                + "rows: wide rounded bills with a fancy border, \(emblem) in an oval in the middle, \"\(Money.bill)\" in two "
                + "corners, and the money's name \"\(name)\" across the top of each bill."
                + wordsRule([name, Money.bill], " Every bill shows the same words (\(count) copies).") + cut + safe
            return PagePrompt(prompt: p, words: Array(repeating: [name, Money.bill, Money.bill], count: count).flatMap { $0 })
        }
    }

    // MARK: 4. Tickets (boarding / admission / keycard), a different number on every copy

    /// Round 47 (Haylee): one pass per player for the most players (6), each with its own number (boarding seats 1A…2B,
    /// admission 001…006, rooms 101…106), drawn once as a strict 2 × 3 grid; the first N print.
    public static let ticketCopies = RoleCast.count

    /// The per-copy numbers on the ticket page, in order (left to right, top to bottom).
    public static func ticketNumbers(_ item: KitItem) -> [String] {
        (0..<ticketCopies).map { i in
            switch item.variant {
            case .boarding?: return "\(i / 4 + 1)\(["A", "B", "C", "D"][i % 4])"
            case .keycard?: return appointment(item) ? "\(i + 1)" : "\(101 + i)"
            default: return String(format: "%03d", i + 1)
            }
        }
    }

    static func appointment(_ item: KitItem) -> Bool {
        let t = (item.title + " " + item.lines.joined(separator: " ")).lowercased()
        return ["appointment", "visit", "checkup", "check-up", "booking"].contains { t.contains($0) }
    }

    static func tickets(_ item: KitItem, _ h: String) -> PagePrompt {
        let title = clean(item.title)
        let line = item.lines.first.map(clean).flatMap { $0.isEmpty ? nil : $0 }
        let numbers = ticketNumbers(item)
        let n = numbers.count
        let pic = picture(item, fallback: title)
        let list = numbers.map { "\"\($0)\"" }.joined(separator: ", ")
        let lineText = line.map { ", the line \"\($0)\"" } ?? ""
        let shape: String, stub: String
        var extra: [String] = []
        switch item.variant {
        case .boarding?:
            shape = "wide boarding passes with rounded corners and a perforated stub on the right"
            stub = "on the stub its OWN seat number"
        case .keycard?:
            if appointment(item) {
                shape = "wide rounded appointment cards with a colored stripe across the top"
                stub = "the word \"Time:\" followed by a short blank line to write on, and in a circle in the corner its OWN number"
                extra = ["Time:"]
            } else {
                shape = "wide rounded hotel key cards with a colored stripe across the top and a little key picture"
                stub = "in a box in the corner its OWN room number"
            }
        default:
            shape = "wide ticket shapes with notched corners and a perforated stub on the right"
            stub = "on the stub its OWN number"
        }
        let p = h + " " + strictGrid(n, "passes", columns: 2, rows: (n + 1) / 2) + " Each one: \(shape). Each pass shows "
            + "the title \"\(title)\"\(lineText), a small picture of \(pic), and \(stub), a different one on each pass, in this "
            + "order left to right, top to bottom: \(list)."
            + wordsRule([title] + (line.map { [$0] } ?? []) + extra + numbers, " Each number appears on exactly one pass.")
            + cut + safe
        let perCopy = [title] + (line.map { [$0] } ?? []) + extra
        return PagePrompt(prompt: p, words: Array(repeating: perCopy, count: n).flatMap { $0 } + numbers)
    }

    // MARK: 5. Menu (menu card / board / show program)

    static func menu(_ item: KitItem, _ ctx: KitArtContext, _ h: String) -> PagePrompt {
        let title = clean(item.title)
        let pics = item.pictures ?? []
        let program = item.variant == .program
        let rows: [(dish: String, price: String?, pic: String)] = item.lines.prefix(6).enumerated().map { i, l in
            let dish = clean(Money.withoutPrice(l))
            return (dish, program ? nil : Money.price(l), pics.indices.contains(i) ? clean(pics[i]) : dish.lowercased())
        }.filter { !$0.dish.isEmpty }
        let list = rows.map { r in
            "\"\(r.dish)\" with a small picture of \(r.pic) on the left" + (r.price.map { " and the price \"\($0)\" on the right" } ?? "")
        }.joined(separator: "; ")
        let words = [title] + rows.map(\.dish) + rows.compactMap(\.price)
        let frame: String
        switch item.variant {
        case .chalkboard?:
            frame = "ONE menu board that fills the page inside the margin: a wooden easel-board frame around a light cream "
                + "board with little hand-drawn chalk-style doodles in the corners (keep the board light, never a dark fill)"
        case .program?:
            frame = "ONE show program that fills the page inside the margin: a decorative theater frame with curtains and "
                + "stars at the top"
        default:
            frame = "ONE menu card that fills the page inside the margin: a decorative themed frame (little forks, spoons, "
                + "hearts, checkered corners)"
        }
        let rowsText = program
            ? "Then \(rows.count) rows, one act per row, evenly spaced: \(list)."
            : "Then \(rows.count) rows, one item per row, evenly spaced, with a dotted leader between the item and its price: \(list)."
        let p = h + " Draw \(frame). At the top in big letters: \"\(title)\". \(rowsText)" + wordsRule(words) + safe
        return PagePrompt(prompt: p, words: words)
    }

    // MARK: 6. Cut-outs (the themed props; part 1 = the skipped props' extra page)

    static func cutouts(_ item: KitItem, _ h: String, part: Int) -> PagePrompt {
        let all = item.lines.map(clean).filter { !$0.isEmpty }
        let split = min(item.pageLines ?? all.count, all.count)
        let things = part == 0 ? Array(all.prefix(split)) : Array(all.dropFirst(split))
        let title = part == 0 ? clean(item.title) : "More \(clean(item.title))"
        let n = max(1, things.count)
        let grid = n <= 2 ? "1 column of \(n)" : "2 columns and \((n + 1) / 2) rows"
        let list = things.enumerated().map { "\($0.offset + 1). \($0.element.lowercased())" }.joined(separator: ", ")
        let p = h + " Draw a sheet of exactly \(n) big cut-out props to hold in pretend play, in a grid of \(grid), each one "
            + "simple object filling its cell, in this order: \(list). Title across the top: \"\(title)\". Each prop has a thick "
            + "white cut-around border and a thin gray dashed cut line around that border, with wide white gaps between props."
            + wordsRule([title]) + " The props themselves have no writing on them." + safe
        return PagePrompt(prompt: p, words: [title])
    }

    // MARK: 7. Order slips (4 identical notepad slips)

    static func orderSlips(_ item: KitItem, _ h: String) -> PagePrompt {
        let pics = item.pictures ?? []
        let dishes = item.lines.prefix(4).map { clean(Money.withoutPrice($0)) }.filter { !$0.isEmpty }
        let copies = 4
        let list = dishes.enumerated().map { i, d in "\"\(d)\" (tiny picture of \(pics.indices.contains(i) ? clean(pics[i]) : d.lowercased()))" }
            .joined(separator: ", ")
        let p = h + " Draw a sheet of exactly \(copies) identical order slips in a grid of 2 columns and \(copies / 2) rows: "
            + "tall waiter's notepad slips with a little spiral at the top. On each slip: the word \"Order\" at the top, then "
            + "\"Table\" followed by a small empty box, then \(dishes.count) rows, each an empty square tick box, a tiny picture "
            + "and the dish name: \(list)."
            + wordsRule(["Order", "Table"] + dishes, " Every slip shows the same words (\(copies) copies).") + cut + safe
        return PagePrompt(prompt: p, words: Array(repeating: ["Order", "Table"] + dishes, count: copies).flatMap { $0 })
    }

    // MARK: 8. Map (one scroll map with the stops in order)

    static func map(_ item: KitItem, _ ctx: KitArtContext, _ h: String) -> PagePrompt {
        let title = clean(item.title)
        let stops = item.lines.prefix(4).map(clean).filter { !$0.isEmpty }
        let place = picture(item, fallback: clean(ctx.setting ?? ctx.title))
        let s = stops.map { "\"\($0)\"" }.joined(separator: ", ")
        let kind = title.lowercased().contains("treasure") ? "treasure map" : "map"
        let p = h + " Draw ONE \(kind) that fills the page inside the margin: an old paper scroll with curled ends, a picture-book "
            + "map of \(place) seen from above, a winding dashed path that visits \(stops.count) stops in order, each stop a "
            + "big simple landmark drawing with its name on a little flag or plaque beside it: \(s). The last stop has a big "
            + "red X. A friendly compass rose with no letters. Title across the top on a ribbon: \"\(title)\"."
            + wordsRule([title] + stops) + safe
        return PagePrompt(prompt: p, words: [title] + stops)
    }

    // MARK: 9 + 10. Clue cards and mission cards (numbered, each printed once)

    static func numberedCards(_ item: KitItem, _ h: String, kind: String, border: String, what: String, hint: String) -> PagePrompt {
        let pics = item.pictures ?? []
        let texts = item.lines.prefix(6).map(clean).filter { !$0.isEmpty }
        let n = max(1, texts.count)
        let list = texts.enumerated().map { i, c in
            "card \(i + 1): a big number \"\(i + 1)\" in a circle in the top corner, a picture of "
                + "\(pics.indices.contains(i) ? clean(pics[i]) : c.lowercased()), and the \(what) \"\(c)\""
        }.joined(separator: "; ")
        let p = h + " Draw a sheet of exactly \(n) \(kind) in a grid of 2 columns and \((n + 1) / 2) rows, all the same size: "
            + "rounded cards with a themed decorative border (\(border)), each with one \(hint) and one short \(what) under it. "
            + "In order, left to right, top to bottom: \(list)."
            + wordsRule(texts, " Plus the card numbers 1 to \(n), one per card.") + cut + safe
        return PagePrompt(prompt: p, words: texts + (1...n).map(String.init))
    }

    // MARK: 11. Log (ruled log / tick chart)

    static func log(_ item: KitItem, _ h: String) -> PagePrompt {
        let title = clean(item.title)
        let rows = item.lines.prefix(6).map(clean).filter { !$0.isEmpty }
        let pic = picture(item, fallback: title.lowercased())
        let list = rows.map { "\"\($0)\"" }.joined(separator: ", ")
        let body: String
        if item.variant == .chart {
            body = " Draw ONE tick chart that fills the page inside the margin: a header with the title \"\(title)\" and a small "
                + "picture of \(pic), then a big table with \(rows.count) rows, each row a label on the left and 3 big empty "
                + "square tick boxes on the right. The row labels in order: \(list)."
        } else {
            body = " Draw ONE log page that fills the page inside the margin, like a page from an adventure notebook: a header "
                + "with the title \"\(title)\" and a small picture of \(pic), then \(rows.count) sections, each with its label "
                + "and two long empty ruled lines under it to write or draw on. The section labels in order: \(list)."
        }
        return PagePrompt(prompt: h + body + wordsRule([title] + rows) + safe, words: [title] + rows)
    }

    // MARK: 12. Medals (one ribbon medal per award)

    static func medals(_ item: KitItem, _ h: String) -> PagePrompt {
        let pics = item.pictures ?? []
        let awards = item.lines.prefix(6).map(clean).filter { !$0.isEmpty }
        let n = max(1, awards.count)
        let list = awards.enumerated().map { i, a in
            "medal \(i + 1): \(pics.indices.contains(i) ? clean(pics[i]) : "a shining star") in the middle and the award \"\(a)\" on its ribbon banner"
        }.joined(separator: "; ")
        let p = h + " Draw a sheet of exactly \(n) award medals in a grid of 2 columns and \((n + 1) / 2) rows, all the same "
            + "size: big round rosette medals with a ruffled rim and two ribbon tails hanging below, a straight ribbon banner "
            + "across the lower part. In order: \(list)." + wordsRule(awards) + cut + safe
        return PagePrompt(prompt: p, words: awards)
    }

    // MARK: 13. Stickers (each design twice)

    static func stickers(_ item: KitItem, _ h: String) -> PagePrompt {
        let pics = item.pictures ?? []
        let texts = Array(item.lines.prefix(6).map(clean).filter { !$0.isEmpty })
        let n = max(1, texts.count)
        let each = 2
        let list = texts.enumerated().map { i, t in
            "\(pics.indices.contains(i) ? clean(pics[i]) : "a happy star") with the word \"\(t)\""
        }.joined(separator: "; ")
        let total = n * each
        let p = h + " Draw a sheet of exactly \(total) round reward stickers in a grid of \(total <= 6 ? 2 : 3) columns, all the "
            + "same size, each with a scalloped edge, one cheerful picture and one short word. \(n) designs, each drawn "
            + "\(each) times, in this order: \(list)."
            + wordsRule(texts, " Each word appears on exactly \(each) stickers.") + cut + safe
        return PagePrompt(prompt: p, words: Array(repeating: texts, count: each).flatMap { $0 })
    }

    // MARK: 14. Passport (a booklet that folds in half)

    static func passport(_ item: KitItem, _ h: String) -> PagePrompt {
        let title = clean(item.title)
        let stops = item.lines.prefix(6).map(clean).filter { !$0.isEmpty }
        let pic = picture(item, fallback: title.lowercased())
        let list = stops.map { "\"\($0)\"" }.joined(separator: ", ")
        let p = h + " Draw ONE passport booklet page that folds in half: the top half is the cover, a big rounded "
            + "passport cover with the title \"\(title)\" and a big picture of \(pic); a dashed fold line across the middle of the "
            + "page; the bottom half is the inside, a grid of \(stops.count) empty square stamp boxes with a little label under "
            + "each box, in order: \(list)." + wordsRule([title] + stops) + safe
        return PagePrompt(prompt: p, words: [title] + stops)
    }

    // MARK: 15. Labels (each tag twice)

    static func labels(_ item: KitItem, _ h: String) -> PagePrompt {
        let pics = item.pictures ?? []
        let texts = Array(item.lines.prefix(6).map(clean).filter { !$0.isEmpty })
        let n = max(1, texts.count)
        let each = 2
        let list = texts.enumerated().map { i, t in
            "\(pics.indices.contains(i) ? clean(pics[i]) : t.lowercased()) with the words \"\(t)\""
        }.joined(separator: "; ")
        let total = n * each
        let p = h + " Draw a sheet of exactly \(total) tags in a grid of \(total <= 6 ? 2 : 3) columns, all the same size: "
            + "tag shapes with a punched hole and a little loop of string at one end, each with a small picture and its words. "
            + "\(n) tags, each drawn \(each) times, in this order: \(list)."
            + wordsRule(texts, " Each tag's words appear on exactly \(each) tags.") + cut + safe
        return PagePrompt(prompt: p, words: Array(repeating: texts, count: each).flatMap { $0 })
    }

    // MARK: 16. Control panel

    static func controlPanel(_ item: KitItem, _ h: String) -> PagePrompt {
        let title = clean(item.title)
        let buttons = item.lines.prefix(6).map(clean).filter { !$0.isEmpty }
        let pic = picture(item, fallback: "a sky full of stars")
        let list = buttons.map { "\"\($0)\"" }.joined(separator: ", ")
        let p = h + " Draw ONE control panel that fills the page inside the margin: at the top a big rounded window or "
            + "screen showing \(pic), the title \"\(title)\" on a plate under it, then \(buttons.count) big round buttons, "
            + "dials and switches in neat rows, each with its name on a small label under it: \(list)."
            + wordsRule([title] + buttons) + safe
        return PagePrompt(prompt: p, words: [title] + buttons)
    }

    // MARK: Helpers

    /// The item's first picture, else a fallback subject (never a price or quotes).
    static func picture(_ item: KitItem, fallback: String) -> String {
        let p = (item.pictures ?? []).map(clean).first { !$0.isEmpty }
        return p ?? fallback
    }

    /// A word for the prompt: no double quotes (they'd break the quoting), single spaces, trimmed.
    static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "“", with: "").replacingOccurrences(of: "”", with: "")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func unique(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

// MARK: - The character sheet (in-app pictures)

/// Round 46: ONE small picture-only sheet per kit (drawn in the color style only): the game's 6 ranked roles' characters
/// in the first two rows, and (when the kit has cut-outs) the themed cut-out things below them. The app slices it into
/// the scene rows' character pictures, the hand-off and badge pictures and the prop cards' pictures. Whole printed
/// pages can't be sliced cleanly (frames, titles and cut lines are in them), so this sheet replaces round 45's slices.
/// No words, frames, badges or banners: just the pictures on white, so a slice IS the picture.
public enum CharacterSheet {
    /// The cut-outs store key of the sheet's slices: `characters#k` (k 0…5 = role R(k+1), 6… = cut-out thing k − 6).
    public static let id = "characters"
    public static let columns = 3
    public static let roleCount = RoleCast.count
    /// At most this many cut-out things below the characters.
    public static let maxThings = 6

    /// The things drawn below the characters: the kit's themed cut-outs (the first page's, at most 6).
    public static func things(_ items: [KitItem]) -> [String] {
        guard let c = items.first(where: { $0.recipe == .cutouts }) else { return [] }
        let lines = c.lines.map(KitPagePrompt.clean).filter { !$0.isEmpty }
        return Array(lines.prefix(min(c.pageLines ?? lines.count, maxThings)))
    }

    /// Cells on the sheet (6 characters + the things).
    public static func count(things: Int) -> Int { roleCount + min(max(things, 0), maxThings) }
    /// Rows: 2 of characters, then the things' rows.
    public static func rows(things: Int) -> Int { 2 + Int(ceil(Double(min(max(things, 0), maxThings)) / Double(columns))) }
    /// Landscape for the characters alone (3 × 2 square cells), portrait with the things (3 × 3 or 3 × 4).
    public static func size(things: Int) -> String { things > 0 ? "1024x1536" : "1536x1024" }

    public static func prompt(roles: [Role], things: [String], title: String) -> String {
        let roles = Array(roles.prefix(roleCount))
        let things = Array(things.prefix(maxThings))
        let rows = rows(things: things.count)
        let chars = roles.enumerated().map { i, r in
            let job = KitPagePrompt.clean(r.job)
            return "\(i + 1). the \(KitPagePrompt.clean(r.roleName).lowercased())" + (job.isEmpty ? "" : " (\(job))")
        }.joined(separator: ", ")
        var p = "A sheet of small separate pictures for a kids' pretend-play game called \"\(KitPagePrompt.clean(title))\", in a grid "
            + "of exactly \(columns) columns and \(rows) rows, read left to right and top to bottom. Rows 1 and 2: \(roles.count) cute "
            + "cartoon characters, one per cell, each from the waist up, dressed and holding things for their job: \(chars)."
        if !things.isEmpty {
            let list = things.enumerated().map { "\(roles.count + $0.offset + 1). \($0.element.lowercased())" }.joined(separator: ", ")
            p += " The next rows: \(things.count) simple objects, one per cell: \(list)."
        }
        p += " Each picture is centered in its own equal cell and fills most of it. Wide plain white gaps between the cells; "
            + "nothing touches or crosses into another cell, no grid lines. " + KitPagePrompt.style(.fullColor)
            + " Just the pictures on plain white paper: no words, no letters, no numbers, no frames, no borders, no badges, no "
            + "banners, no labels and no empty boxes anywhere." + KitPagePrompt.safe
        return p
    }
}
