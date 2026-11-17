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
        "map", "letter", "note", "scroll", "invitation", "stamp", "page", "paper", "newspaper", "chart"
    ]

    /// Words that end the head phrase ("map OF the island", "holder FOR the tickets").
    static let breakers: Set<String> = PropFit.breakers

    /// A word's singular (tickets → ticket, passes → pass, boxes → box, coins → coin).
    public static func singular(_ w: String) -> String {
        let w = w.lowercased()
        if w.count > 4, w.hasSuffix("sses") || w.hasSuffix("xes") || w.hasSuffix("ches") || w.hasSuffix("shes") { return String(w.dropLast(2)) }
        if w.count > 3, w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if w.count > 3, w.hasSuffix("s"), !w.hasSuffix("ss") { return String(w.dropLast()) }
        return w
    }

    /// The head noun of a pretend use: the last word of its head phrase ("the boarding passes" → pass, "the treasure
    /// map of the island" → map, "the ticket booth" → booth).
    public static func headNoun(_ becomes: String) -> String? {
        let words = becomes.lowercased().replacingOccurrences(of: "’", with: "'")
            .split { !$0.isLetter && $0 != "'" }.map { w in w.hasSuffix("'s") ? String(w.dropLast(2)) : String(w) }
        let head = words.prefix { !breakers.contains($0) }
        return head.last.map(singular)
    }

    /// The kit's own printed things for this game (head nouns): the tickets, money and menu titles and every cut-out
    /// line. (The sign's title is the place's name and the badges are role titles, so those two don't count; their
    /// kinds are in `words`.)
    public static func kitNouns(_ items: [KitItem]) -> Set<String> {
        var out = Set<String>()
        for item in items {
            switch item.recipe {
            case .tickets, .money, .menu:
                if let n = headNoun(item.title) { out.insert(n) }
            case .cutouts:
                for line in item.lines { if let n = headNoun(line) { out.insert(n) } }
            default: break
            }
        }
        return out.subtracting(["the", "a", "an"])
    }

    /// What the use clashes with (a printed kind of thing, or one of this kit's printed things), or nil when it's fine.
    public static func clash(_ becomes: String, kit: [KitItem]? = nil) -> String? {
        guard let noun = headNoun(becomes) else { return nil }
        if words.contains(noun) { return noun }
        if let kit, kitNouns(kit).contains(noun) { return noun }
        return nil
    }

    /// The tool output after a clash: one retry, with the reason.
    public static func retryOutput(itemID: String, becomes: String, clash: String) -> String {
        let name = (PropLibrary.name(itemID) ?? itemID).lowercased()
        return "Not shown: \(becomes) is a paper thing the printed kit makes (the \(clash)), so it can't be a household prop. "
            + "The kit already prints the badges, sign, money, tickets or passes, menu and cut-outs. Say nothing yet: call the "
            + "same tool again with a prop that is a real household thing for THIS game and is NOT paper or a printout "
            + "(never tickets, passes, money, coins, menus, signs, badges, maps, cards, letters or notes): keep the \(name) "
            + "only if it becomes something else that fits its shape. Add a short reason why it works."
    }
}
