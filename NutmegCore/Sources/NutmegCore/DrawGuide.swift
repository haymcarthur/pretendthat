import Foundation

// Round 24 (Haylee): no printer → no kit images at all. Claude writes a VERY simple draw-your-own guide (at most about
// 5 pieces, each one or two shapes a 4-year-old can draw: "Draw a big star. Write a 1 in the middle."), and the Paper
// step becomes "Draw it!": one piece at a time, a built-in SF Symbol of the shape (no AI images), Next and the pill's
// Repeat, voice "next" / "again", Nutmeg reading each instruction. After the last piece the game goes on to Play.
// Money is always $1 bills; badges match the player count (capped at 6, round 23). The app owns every count.

/// What a drawn piece is (the printed kit's recipe types, plus one simple prop to draw).
public enum DrawKind: String, Codable, Sendable, CaseIterable {
    case badges, money, tickets, sign, menu, thing
}

public struct DrawPiece: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: DrawKind
    /// 1 to 3 words ("Captain badges").
    public var title: String
    /// One outline SF Symbol (PrintSymbols allowlist), shown big on the Draw it! card.
    public var symbol: String
    /// One or two very short sentences for ONE piece ("Draw a big star. Write a 1 in the middle.").
    public var instruction: String
    /// How many to make (the app decides: badges = players, money = 5 bills, tickets = players, else 1).
    public var count: Int
    public init(id: String, kind: DrawKind, title: String, symbol: String, instruction: String, count: Int = 1) {
        self.id = id; self.kind = kind; self.title = title; self.symbol = symbol; self.instruction = instruction; self.count = count
    }
}

public struct DrawGuide: Codable, Equatable, Sendable {
    public var nutmegSays: String
    public var pieces: [DrawPiece]
    public init(nutmegSays: String, pieces: [DrawPiece]) { self.nutmegSays = nutmegSays; self.pieces = pieces }
}

extension DrawGuide: SafetyText {
    public var safetyTexts: [String] { [nutmegSays] + pieces.flatMap { [$0.title, $0.instruction] } }
}

public enum DrawIt {
    /// The Paper step's title when there's no printer.
    public static let title = "Draw it!"
    public static let nextLabel = "Next"
    public static let playLabel = "Let's play!"
    public static let saveLabel = "Save printables for later"
    public static let savingLabel = "Making your printables…"

    // Limits (tested): at most 5 pieces, at most 2 sentences and 14 words per instruction, 3 words per title.
    public static let maxPieces = 5
    public static let maxSentences = 2
    public static let maxWords = 14
    public static let maxTitleWords = 3
    /// Bills to draw (every bill is $1).
    public static let moneyCount = 5
    public static let moneyInstruction = "Draw a long rectangle. Write $1 in the middle."

    /// The JSON schema (strict, like every structured call).
    public static func schema() -> [String: Any] {
        Schemas.obj(["nutmegSays": Schemas.str,
                     "pieces": Schemas.nonEmpty(Schemas.obj(["id": Schemas.str,
                                                             "kind": Schemas.enumStr(DrawKind.allCases.map(\.rawValue)),
                                                             "title": Schemas.str, "symbol": Schemas.str,
                                                             "instruction": Schemas.str, "count": Schemas.int]))])
    }

    public static func prompt(ctx: AdventureContext) -> String {
        """
        Phase: no printer, so the kids DRAW their own play kit with paper and crayons. Write a VERY simple \
        draw-your-own guide for THIS game: at most \(maxPieces) pieces (3 or 4 is great), only things the game really uses. \
        Each piece is ONE or TWO simple shapes a 4-year-old can draw. instruction: 1 or 2 very short sentences (at most \
        \(maxWords) words in all) for ONE piece, like "Draw a big star. Write a 1 in the middle." or "Draw a circle. \
        Color it gold." Never say how many to make (the app says it). kind: badges (one badge for a kid's role; \
        always include it), money (play money: every bill is $1, so write $1, e.g. "\(moneyInstruction)"), tickets, \
        sign, menu, or thing (one simple prop to draw, like a coin, a map or a key). Each kind at most once, except \
        thing. title: 1 to \(maxTitleWords) words ("Captain badges", "Gold coins"). symbol: one simple SF Symbol from \
        this list: \(symbols.joined(separator: ", ")). No names anywhere. count: 1 (the app sets it). nutmegSays: one \
        short cheerful line about drawing the kit. Return DrawGuide.
        \(Prompts.contextJSON(ctx))
        """
    }

    /// The symbols a piece may show (all outline SF Symbols from the print allowlist).
    public static let symbols = ["star", "heart", "crown", "banknote", "dollarsign.circle", "ticket", "flag", "map",
                                 "key", "fork.knife", "cup.and.saucer", "birthday.cake", "fish", "leaf", "sun.max",
                                 "moon", "cloud", "sparkles", "gift", "house", "car", "sailboat", "airplane", "rocket",
                                 "trophy", "medal", "shield", "bell", "pawprint", "stethoscope", "bandage", "book",
                                 "envelope", "music.note", "carrot", "tree", "balloon", "wand.and.stars", "magnifyingglass"]

    static func defaultSymbol(_ k: DrawKind) -> String {
        switch k { case .badges: "star"; case .money: "banknote"; case .tickets: "ticket"; case .sign: "flag"
        case .menu: "fork.knife"; case .thing: "star" }
    }

    /// Words in a text (letters, digits or a $ amount).
    static func words(_ s: String) -> [Substring] { s.split { $0 == " " || $0 == "\n" }.filter { $0.contains { $0.isLetter || $0.isNumber } } }

    static func sentences(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in s {
            cur.append(ch)
            if ".!?".contains(ch) { let t = cur.trimmingCharacters(in: .whitespaces); if !t.isEmpty { out.append(t) }; cur = "" }
        }
        let t = cur.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { out.append(t.hasSuffix(".") ? t : t + ".") }
        return out
    }

    /// Cut an instruction to the limits: the first 2 sentences, at most `maxWords` words.
    static func trim(_ s: String) -> String {
        let first = sentences(s.trimmingCharacters(in: .whitespacesAndNewlines)).prefix(maxSentences)
        var kept: [String] = [], n = 0
        for sentence in first {
            let w = words(sentence).count
            if n + w > maxWords {
                if kept.isEmpty { kept.append(sentence.split(separator: " ").prefix(maxWords).joined(separator: " ") + ".") }
                break
            }
            kept.append(sentence); n += w
        }
        return kept.joined(separator: " ")
    }

    /// A money instruction must be a $1 bill (no other amounts, round 23).
    static func moneyOK(_ s: String) -> Bool {
        let amounts = s.matches(of: /\$\s*(\d+)/).map { String($0.output.1) }
        return amounts == ["1"] || (amounts.isEmpty && s.range(of: #"\b1\b"#, options: .regularExpression) != nil)
    }

    /// The app's counts and limits on Claude's guide (the schema can't express them).
    public static func clean(_ g: DrawGuide, playerCount: Int) -> DrawGuide {
        let kids = max(1, min(playerCount, Players.max))
        var seen = Set<DrawKind>(), used = Set<String>()
        var out: [DrawPiece] = []
        for (i, raw) in g.pieces.enumerated() where out.count < maxPieces {
            var p = raw
            if p.kind != .thing { guard seen.insert(p.kind).inserted else { continue } }
            p.title = p.title.split(separator: " ").prefix(maxTitleWords).joined(separator: " ")
                .trimmingCharacters(in: CharacterSet(charactersIn: " .!"))
            if p.title.isEmpty { p.title = p.kind.rawValue.capitalized }
            p.symbol = symbols.contains(p.symbol) ? p.symbol : defaultSymbol(p.kind)
            p.instruction = trim(p.instruction)
            if p.kind == .money && !moneyOK(p.instruction) { p.instruction = moneyInstruction }
            if p.instruction.isEmpty { continue }
            switch p.kind {
            case .badges, .tickets: p.count = kids
            case .money: p.count = moneyCount
            case .sign, .menu: p.count = 1
            case .thing: p.count = max(1, min(p.count, 3))
            }
            var id = "draw-\(p.kind.rawValue)"
            if used.contains(id) { id += "-\(i)" }
            used.insert(id); p.id = id
            out.append(p)
        }
        // Badges first (every game has them), then the order Claude chose.
        out.sort { ($0.kind == .badges ? 0 : 1) < ($1.kind == .badges ? 0 : 1) }
        return DrawGuide(nutmegSays: g.nutmegSays, pieces: out)
    }

    /// Too few pieces, or instructions longer than the limits (before `clean` cuts them).
    public static func problem(_ g: DrawGuide) -> Validate.Problem? {
        if g.pieces.isEmpty { return Validate.Problem(message: "it had no pieces; write 3 to 5", fatal: true) }
        if g.pieces.count > maxPieces { return Validate.Problem(message: "it had \(g.pieces.count) pieces; write at most \(maxPieces)", fatal: false) }
        if let p = g.pieces.first(where: { sentences($0.instruction).count > maxSentences || words($0.instruction).count > maxWords }) {
            return Validate.Problem(message: "the \(p.title) instruction was too long; use 1 or 2 very short sentences, at most \(maxWords) words", fatal: false)
        }
        if !g.pieces.contains(where: { $0.kind == .badges }) {
            return Validate.Problem(message: "it had no badges piece; include one", fatal: false)
        }
        return nil
    }

    /// The bundled guide (no Claude, or two failures): badges, money and tickets.
    public static func fallback(playerCount: Int) -> DrawGuide {
        clean(DrawGuide(nutmegSays: "Grab some paper and crayons, let's draw our kit!", pieces: [
            DrawPiece(id: "b", kind: .badges, title: "Badges", symbol: "star", instruction: "Draw a big star. Write your job in the middle."),
            DrawPiece(id: "m", kind: .money, title: "Money", symbol: "banknote", instruction: moneyInstruction),
            DrawPiece(id: "t", kind: .tickets, title: "Tickets", symbol: "ticket", instruction: "Draw a small rectangle. Draw a star on it."),
        ]), playerCount: playerCount)
    }

    /// "Make 3, one for each friend." (the app's count, never Claude's).
    public static func countLine(_ p: DrawPiece) -> String {
        switch p.kind {
        case .badges: return p.count == 1 ? "Make one for you." : "Make \(ConfirmStep.number(p.count)), one for each friend."
        case .tickets: return p.count == 1 ? "Make one." : "Make \(ConfirmStep.number(p.count)), one for each friend."
        case .money: return "Make \(ConfirmStep.number(p.count)) of them."
        case .sign, .menu: return ""
        case .thing: return p.count > 1 ? "Make \(ConfirmStep.number(p.count))." : ""
        }
    }

    /// The card's text and what she reads for piece `i` (one line; the first one says how the step works).
    public static func line(_ guide: DrawGuide, _ i: Int) -> String {
        guard guide.pieces.indices.contains(i) else { return "" }
        let p = guide.pieces[i], last = i == guide.pieces.count - 1
        let lead = i == 0 ? "Let's draw your kit! Grab paper and crayons. First, \(p.title.lowercased())!"
            : last ? "Last one, \(p.title.lowercased())!" : "Next, \(p.title.lowercased())!"
        let tail = last ? "Then tap \(playLabel)" : (i == 0 ? "Tap \(nextLabel) when it's done!" : "")
        return [lead, p.instruction, countLine(p), tail].filter { !$0.isEmpty }
            .map { $0.hasSuffix("!") || $0.hasSuffix(".") || $0.hasSuffix("?") ? $0 : $0 + "!" }
            .joined(separator: " ")
    }

    /// The pieces as kit items, so the play guide's pictures can point at them (kit:badge:R1, kit:money, cutout:N).
    /// No art is ever drawn for them: their tiles show the piece's SF Symbol.
    public static func kitItems(_ guide: DrawGuide) -> [KitItem] {
        var items: [KitItem] = []
        func item(_ p: DrawPiece, _ r: KitRecipe) -> KitItem {
            KitItem(id: p.id, recipe: r, kind: r.kind, size: r.size, title: p.title, symbol: p.symbol, lines: [p.instruction],
                    bigNumber: r == .money ? "$1" : nil, perPlayer: r.perPlayer, copies: p.count, colorMe: true)
        }
        for p in guide.pieces {
            switch p.kind {
            case .badges: items.append(item(p, .badges))
            case .money: items.append(item(p, .money))
            case .tickets: items.append(item(p, .tickets))
            case .sign: items.append(item(p, .sign))
            case .menu: items.append(item(p, .menu))
            case .thing: break
            }
        }
        let things = guide.pieces.filter { $0.kind == .thing }
        if !things.isEmpty {
            items.append(KitItem(id: "draw-things", recipe: .cutouts, kind: .sheet, size: .fullPage, title: "Things to draw",
                                 symbol: things[0].symbol, lines: things.map(\.title), bigNumber: nil, perPlayer: false,
                                 copies: 1, colorMe: true))
        }
        return items
    }

    /// The SF Symbol for a kit item that came from a drawn piece (its tile in the play guide).
    public static func symbol(forItem id: String, cutout index: Int? = nil, in guide: DrawGuide?) -> String? {
        guard let guide else { return nil }
        if id == "draw-things", let index {
            let things = guide.pieces.filter { $0.kind == .thing }
            return things.indices.contains(index) ? things[index].symbol : nil
        }
        return guide.pieces.first { $0.id == id }?.symbol
    }
}
