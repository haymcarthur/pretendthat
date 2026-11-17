import Foundation

// Round 28, item 1 (Haylee): "Customers are roles too." Games only came back with worker roles (Stand Manager, Recipe
// Mixer, Cup Filler, Sign Artist…), but customers, visitors, guests, passengers and patients are just as important
// (and a game of shop needs someone to buy). The prompts now ask for them; this is the app-side check, with no AI call:
// for a game that has customers, R2 is the customer counterpart of R1 (Shopkeeper + Customer, Pilot + Passenger,
// Vet + Pet Owner) and the extras mix workers and customers (at least 2 customer-type roles of the 6).
public enum CustomerRoles {
    /// One kind of customer for a game: the R2 counterpart and a second one for the extras.
    public struct Kind: Equatable, Sendable {
        public var primary: (name: String, job: String)
        public var extra: (name: String, job: String)
        public static func == (a: Kind, b: Kind) -> Bool { a.primary.name == b.primary.name && a.extra.name == b.extra.name }
    }

    /// Words that make a role title a customer-type role (whole words; plurals count).
    static let words = ["customer", "shopper", "buyer", "client", "guest", "visitor", "passenger", "traveler",
                        "traveller", "tourist", "patient", "diner", "audience", "spectator", "fan", "reader", "borrower",
                        "student", "sender", "moviegoer", "vip"]
    /// "Owner" alone is often a worker (Shop Owner); only an animal's owner is a customer.
    static let ownerPattern = #"\b(pet|dog|cat|puppy|kitty|kitten|bunny|hamster|bird|fish|horse|pony)\s+owners?\b"#

    /// Whether a role title is a customer, visitor, guest, passenger, patient… ("Pet Owner", "VIP Customer").
    public static func isCustomer(_ roleName: String) -> Bool {
        let t = roleName.lowercased()
        if t.range(of: ownerPattern, options: .regularExpression) != nil { return true }
        let tokens = t.split { !$0.isLetter }.map(String.init)
        return tokens.contains { tok in words.contains(tok) || (tok.hasSuffix("s") && words.contains(String(tok.dropLast()))) }
    }

    /// Game keywords → the customer kind (checked in order: the more specific first, e.g. "pet shop" before "pet").
    static let table: [(keys: [String], kind: Kind)] = [
        (["pet shop", "pet store", "toy shop", "toy store"],
         Kind(primary: ("Customer", "pick something and pay with play money"), extra: ("VIP Customer", "ask for something extra special"))),
        (["vet", "animal doctor", "animal hospital", "pet clinic", "pet doctor", "animal clinic"],
         Kind(primary: ("Pet Owner", "bring a pet in for a checkup"), extra: ("Kitty Owner", "bring a kitty with a sniffle"))),
        (["doctor", "hospital", "clinic", "dentist", "nurse", "check-up", "checkup"],
         Kind(primary: ("Patient", "tell the doctor what feels funny"), extra: ("Sneezy Patient", "come in with a big pretend sneeze"))),
        (["airplane", "plane", "airline", "flight", "airport", "jet", "train", "bus", "taxi", "subway", "cruise", "trolley",
          "space shuttle", "rocket ride", "hot air balloon"],
         Kind(primary: ("Passenger", "show your ticket and find a seat"), extra: ("VIP Passenger", "ask for a snack and a blanket"))),
        (["hotel", "inn", "motel", "resort", "spa", "bed and breakfast"],
         Kind(primary: ("Guest", "check in and enjoy your stay"), extra: ("VIP Guest", "ask for extra fluffy pillows"))),
        (["library", "bookstore", "book shop", "book store"],
         Kind(primary: ("Reader", "pick a book and check it out"), extra: ("Book Borrower", "bring a book back and pick a new one"))),
        (["zoo", "museum", "aquarium", "farm", "park", "gallery", "castle tour", "safari", "planetarium"],
         Kind(primary: ("Visitor", "look around and ask lots of questions"), extra: ("VIP Visitor", "ask for the big special tour"))),
        (["theater", "theatre", "movie", "cinema", "circus", "concert", "magic show", "puppet show", "talent show", "show"],
         Kind(primary: ("Audience Member", "watch the show and clap loudly"), extra: ("Front Row Fan", "cheer the loudest"))),
        (["school", "class", "classroom", "lesson", "dance studio", "art class"],
         Kind(primary: ("Student", "raise your hand and learn something new"), extra: ("New Student", "say hello on your first day"))),
        (["post office", "mail", "postal"],
         Kind(primary: ("Customer", "mail a letter or a package"), extra: ("VIP Customer", "send a very special package"))),
        (["salon", "barber", "hair", "nail", "beauty"],
         Kind(primary: ("Customer", "sit down for a fancy new look"), extra: ("VIP Customer", "ask for something extra fancy"))),
        (["restaurant", "café", "cafe", "diner", "pizza", "pancake", "burger", "taco", "sushi", "noodle", "food truck",
          "ice cream", "tea party", "tea shop", "snack bar", "kitchen", "smoothie", "juice"],
         Kind(primary: ("Customer", "order something yummy"), extra: ("Hungry Customer", "order the biggest meal on the menu"))),
        (["shop", "store", "stand", "market", "bakery", "boutique", "grocery", "florist", "flower", "lemonade", "candy",
          "bank", "gas station", "car wash", "mall", "toy", "gift", "garden center", "repair", "pharmacy"],
         Kind(primary: ("Customer", "pick something and pay with play money"), extra: ("VIP Customer", "ask for something extra special"))),
    ]

    /// The customer kind a game has ("Lemonade Stand on the Moon" → Customer), or nil (a pirate ship has no customers).
    public static func kind(forGame game: String) -> Kind? {
        let g = " " + game.lowercased() + " "
        for row in table {
            for k in row.keys {
                let pattern = #"(?<![\p{L}])"# + NSRegularExpression.escapedPattern(for: k) + #"(e?s)?(?![\p{L}])"#
                if g.range(of: pattern, options: .regularExpression) != nil { return row.kind }
            }
        }
        return nil
    }

    /// The ranked roles with customers in them (see the file comment). `roles` are already ranked (6, ids by position).
    /// For a game with no customer kind the roles are unchanged except that a customer the model wrote is kept at R2.
    public static func arrange(_ roles: [Role], game: String) -> [Role] {
        guard !roles.isEmpty else { return roles }
        var out = roles
        let kind = kind(forGame: game)
        func taken(_ name: String) -> Bool { out.contains { $0.roleName.caseInsensitiveCompare(name) == .orderedSame } }
        func role(_ c: (name: String, job: String), symbol: String = "person.fill") -> Role {
            Role(id: .R1, roleName: c.name, emoji: "", symbol: symbol, job: c.job)
        }
        // R1 is the worker lead; when R1 is itself a customer (rare), leave the order alone.
        let r1Customer = isCustomer(out[0].roleName)
        if !r1Customer {
            if let i = out.indices.dropFirst().first(where: { isCustomer(out[$0].roleName) }) {
                // 2. A customer the model ranked lower moves up to R2 (the core counterpart).
                if i != 1 { let c = out.remove(at: i); out.insert(c, at: min(1, out.count)) }
            } else if let kind, !taken(kind.primary.name) {
                // 1. No customer at all: the counterpart becomes R2; the lowest extra drops off.
                out.insert(role(kind.primary), at: min(1, out.count))
                if out.count > RoleCast.count { out.removeLast() }
            }
        }
        // 3. The extras mix workers and customers: at least 2 customer-type roles of the 6 (for a customer game).
        if let kind, out.count == RoleCast.count, out.filter({ isCustomer($0.roleName) }).count < 2, !taken(kind.extra.name),
           let j = out.indices.reversed().first(where: { $0 >= 2 && !isCustomer(out[$0].roleName) }) {
            out[j] = role(kind.extra)
        }
        for i in out.indices { out[i].id = RoleID.allCases[i] }
        return out
    }
}
