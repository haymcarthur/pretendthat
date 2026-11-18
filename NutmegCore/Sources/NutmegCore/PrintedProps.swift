import Foundation

// Round 42 (Haylee's fresh-install test: Nutmeg asked for "Paper → boarding passes", but the boarding passes come out of
// the printer): the prop hunt never asks for a household item whose pretend use is something the kit prints. Every kit
// has the same 6 printed item types (badges, sign, money, tickets, menu, cut-outs); paper things like these are the
// kit's job, never a prop's. Checked two ways:
// - by WORD: the use's head noun is a printed kind of thing (tickets, passes, money, coins, menus, signs, badges, maps,
//   cards, letters, notes…), whatever the kit ends up calling it;
// - by THIS kit: once the kit pages are written (during the hunt), the use's head noun may not be one of the kit's own
//   printed things (a ticket title like "Sky Bucks", a cut-out like "Suitcase").
// A clash gets one retry from the model, then the app swaps in a sensible non-printed pair (`PropFit.fallback`).

public enum PrintedProps {
    /// Head nouns of things the kit prints (singular; plurals are folded by `singular`).
    public static let words: Set<String> = [
        // tickets (boarding passes, keycards, appointment cards, order tickets, admission tickets)
        "ticket", "pass", "boarding", "keycard", "card", "postcard", "wristband", "voucher", "coupon", "passport", "receipt",
        // money
        "money", "cash", "dollar", "bill", "coin", "buck", "token",
        // menu / price list
        "menu", "list", "pricelist",
        // sign / poster
        "sign", "poster", "banner", "label", "flyer", "brochure",
        // badges
        "badge", "tag", "nametag", "sticker", "certificate", "license", "licence", "id",
        // other paper things (maps, letters, notes)
        "map", "letter", "note", "scroll", "invitation", "stamp", "page", "paper", "newspaper", "chart",
        // round 45: the library's other printables (medals, order slips, clue cards, logbooks, decoders, booklets)
        "medal", "slip", "clue", "logbook", "decoder", "booklet", "blueprint",
        // 2026-11-17 (live test: "Paper" became the "recipe sheet"): recipes and worksheets are printouts
        "recipe", "worksheet", "printout", "handout", "form"
    ]

    /// 2026-11-17: "sheet" alone is cloth (a bedsheet sail, a ghost costume) and stays allowed; a sheet with one of
    /// these in front of it is a printout ("the recipe sheet", "the score sheet", "a sheet of paper").
    static let printedSheetWords: Set<String> = ["recipe", "score", "work", "answer", "song", "music", "coloring", "colouring",
                                                 "activity", "sticker", "signup", "sign-up", "fact", "cheat", "character",
                                                 "order", "time", "tally", "price", "paper", "lyric", "lyrics", "instruction",
                                                 "data", "spec", "rule", "rules", "puzzle", "word", "task", "job", "chore"]

    /// "the recipe sheet" → "recipe sheet"; "the bed sheet" / "the sheet" → nil.
    static func printedSheet(_ becomes: String) -> String? {
        let words = becomes.lowercased().split { !$0.isLetter && $0 != "-" }.map(String.init)
        if let of = words.firstIndex(where: { $0 == "sheet" || $0 == "sheets" }), of + 2 < words.count,
           words[of + 1] == "of", ["paper", "papers"].contains(words[of + 2]) { return "sheet of paper" }
        guard headNoun(becomes) == "sheet", let i = words.lastIndex(where: { $0 == "sheet" || $0 == "sheets" }), i > 0 else { return nil }
        return printedSheetWords.contains(words[i - 1]) ? "\(words[i - 1]) sheet" : nil
    }

    /// Words that end the head phrase ("map OF the island", "holder FOR the tickets").
    static let breakers: Set<String> = PropWords.breakers

    /// A word's singular (tickets → ticket, passes → pass, boxes → box, coins → coin).
    public static func singular(_ w: String) -> String {
        let w = w.lowercased()
        // Round 43: "-ie" words keep their ie (cookies → cookie, not "cooky"); a few irregular ones.
        if let irregular = irregulars[w] { return irregular }
        if w.count > 4, w.hasSuffix("ies"), ieWords.contains(String(w.dropLast())) { return String(w.dropLast()) }
        if w.count > 4, w.hasSuffix("sses") || w.hasSuffix("xes") || w.hasSuffix("ches") || w.hasSuffix("shes") { return String(w.dropLast(2)) }
        if w.count > 3, w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if w.count > 3, w.hasSuffix("s"), !w.hasSuffix("ss") { return String(w.dropLast()) }
        return w
    }

    static let ieWords: Set<String> = ["cookie", "pie", "movie", "brownie", "zombie", "hoodie", "smoothie", "veggie", "goalie",
                                       "birdie", "cutie", "rookie", "selfie", "genie", "pixie", "bootie", "magpie", "doggie", "kittie"]
    static let irregulars: [String: String] = ["leaves": "leaf", "scarves": "scarf", "knives": "knife", "mice": "mouse",
                                               "geese": "goose", "teeth": "tooth", "feet": "foot", "children": "child",
                                               "wolves": "wolf", "loaves": "loaf", "shelves": "shelf", "buses": "bus",
                                               "glasses": "glasses", "sunglasses": "sunglasses", "goggles": "goggles",
                                               "binoculars": "binoculars", "potatoes": "potato", "tomatoes": "tomato"]

    /// The head noun of a pretend use: the last word of its head phrase ("the boarding passes" → pass, "the treasure
    /// map of the island" → map, "the ticket booth" → booth). Round 43: shared with `PropFit` (`PropWords`).
    public static func headNoun(_ becomes: String) -> String? { PropWords.headNoun(becomes) }

    /// The kit's own printed things for this game (head nouns): the tickets, money and menu titles and every cut-out
    /// line. (The sign's title is the place's name and the badges are role titles, so those two don't count; their
    /// kinds are in `words`.)
    public static func kitNouns(_ items: [KitItem]) -> Set<String> {
        var out = Set<String>()
        for item in items {
            switch item.recipe {
            case .tickets, .money, .menu:
                if let n = headNoun(item.title) { out.insert(n) }
                if item.variant == .program { out.insert("program") }   // round 45: a show's printed program
            case .cutouts:
                for line in item.lines { if let n = headNoun(line) { out.insert(n) } }
            case .badges?, .sign?, nil: break
            case let t?:
                // Round 45: a library printable is this kit's printed thing by its title ("Treasure Map", "Rocket
                // Controls") and by its kind ("control panel", "log"): a prop may never be one of those in this game.
                if let n = headNoun(item.title) { out.insert(n) }
                for w in PrintLibrary.nouns(t) { if let n = headNoun(w) { out.insert(n) } }
            }
        }
        return out.subtracting(["the", "a", "an"])
    }

    /// What the use clashes with (a printed kind of thing, or one of this kit's printed things), or nil when it's fine.
    public static func clash(_ becomes: String, kit: [KitItem]? = nil) -> String? {
        guard let noun = headNoun(becomes) else { return nil }
        if words.contains(noun) { return noun }
        if let sheet = printedSheet(becomes) { return sheet }
        if let kit, kitNouns(kit).contains(noun) { return noun }
        return nil
    }

    /// The tool output after a clash: one retry, with the reason.
    public static func retryOutput(itemID: String, becomes: String, clash: String, kit: [KitItem]? = nil) -> String {
        let name = (PropLibrary.name(itemID) ?? itemID).lowercased()
        // Round 45: name THIS kit's printables when they're known (the kit is custom per game now).
        let printed = kit.flatMap { k -> String? in
            let names = k.compactMap { $0.recipe?.spokenName }
            return names.isEmpty ? nil : Bookends.list(names)
        } ?? "the badges, sign, money, tickets or passes, menu and cut-outs"
        return "Not shown: \(becomes) is a paper thing the printed kit makes (the \(clash)), so it can't be a household prop. "
            + "The kit already prints \(printed). Say nothing yet: call the "
            + "same tool again with a prop that is a real household thing for THIS game and is NOT paper or a printout "
            + "(never tickets, passes, money, coins, menus, signs, badges, maps, cards, letters or notes): keep the \(name) "
            + "only if it becomes something else that fits its shape. Add a short reason why it works."
    }
}
