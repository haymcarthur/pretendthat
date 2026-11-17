import Foundation

// Round 24 (Haylee: "a bowl as a pirate map" made no sense): every household item → pretend use must be plausible by
// shape or function. Each library item has shape/function tags and a few curated pretend uses; each pretend use
// ("the pirate map", "a captain's hat") needs one of a few tags (a map needs something flat or sheet-like; a hat needs
// something round or wearable). A pairing whose tags don't fit is rejected: the model gets one retry, then the app
// falls back to a curated sensible pair. Uses the rules don't recognize are allowed (no false rejections).

/// What a household item is like (shape or what it can do).
public enum PropTag: String, Sendable, CaseIterable {
    case round, flat, long, soft, container, wearable, sheet, sittable, big, boxy, creature, light, paper, surface, vehicle
    /// Round 30: held with two hands like a wheel (a baking sheet, a hula hoop).
    case grip
    /// Round 30: lays a shape or line on the floor (a hula hoop, a jump rope, tape, chalk): a pond, a river, a finish line.
    case outline
}

extension PropLibrary {
    /// Shape/function tags per library item.
    public static let tags: [String: Set<PropTag>] = [
        "stuffed-animal": [.soft, .creature],
        "chair": [.sittable, .big],
        "table": [.flat, .big, .surface],
        "couch": [.sittable, .big, .soft],
        "pillow": [.soft, .flat, .sittable],
        "blanket": [.sheet, .soft, .big, .wearable],
        "rug": [.flat, .big, .surface, .sheet],
        "cardboard-box": [.container, .big, .boxy, .vehicle, .sittable],
        "plate": [.round, .flat],
        "cup": [.round, .container],
        "bowl": [.round, .container, .wearable],
        "tray": [.flat, .surface],
        "spoon": [.long],
        "pot": [.round, .container, .wearable],
        "towel": [.sheet, .soft, .wearable],
        "laundry-basket": [.container, .big, .vehicle, .sittable],
        "books": [.flat, .paper, .boxy],
        "hat": [.wearable, .round],
        "bag": [.container, .soft],
        "backpack": [.container, .wearable],
        "toy-car": [.vehicle],
        "flashlight": [.long, .light],
        "broom": [.long],
        "teddy-bed": [.container, .soft, .flat],
        "lamp-off": [.light, .long],
        "cushion": [.soft, .flat, .sittable],
        "stool": [.sittable, .flat, .surface],
        "sheet": [.sheet, .soft, .big, .wearable],
        "basket": [.container, .round],
        "bucket": [.container, .round, .wearable],
        // Round 30: set 2.
        "paper": [.sheet, .paper, .flat],
        "paper-towel-tube": [.long],
        "paper-bag": [.container, .paper],
        "egg-carton": [.container, .boxy],
        "crayons": [.long],
        "tape": [.round, .outline],
        "paper-plate": [.round, .flat, .paper],
        "plastic-container": [.container, .boxy],
        "measuring-cup": [.container],
        "colander": [.round, .container, .wearable],
        "baking-sheet": [.flat, .surface, .grip],
        "wooden-spoon": [.long],
        "apron": [.wearable, .sheet, .soft],
        "oven-mitt": [.wearable, .soft],
        "ball": [.round],
        "scarf": [.wearable, .soft, .long, .sheet],
        "sunglasses": [.wearable],
        "sneakers": [.wearable],
        "headband": [.wearable, .round],
        "sock": [.wearable, .soft],
        "mittens": [.wearable, .soft],
        "umbrella": [.long],   // closed: a cane or a wand, never opened indoors
        "pillowcase": [.sheet, .soft, .container, .wearable],
        "toy-keys": [],
        "wagon": [.vehicle, .container, .big],
        "jump-rope": [.long, .outline],
        "hula-hoop": [.round, .big, .grip, .outline],
        "sidewalk-chalk": [.long, .outline],
        "plastic-cups": [.round, .container],
        "sticky-notes": [.paper, .flat],
    ]

    /// Everyday things that aren't on the card list but come up in talk ("a pool noodle works as a sword"): same tags.
    /// (Round 30: pillowcase, paper and paper towel tube are library items now.)
    public static let aliasTags: [String: Set<PropTag>] = [
        "pool noodle": [.long, .soft], "newspaper": [.sheet, .paper, .flat],
    ]

    /// Tags for a library id, a library name ("Bowl") or an alias ("pillowcase"); nil when unknown.
    public static func tagsFor(_ item: String) -> Set<PropTag>? {
        if let t = tags[item] { return t }
        let l = item.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = aliasTags[l] { return t }
        return items.first { $0.name.lowercased() == l }.flatMap { tags[$0.id] }
    }

    /// Curated, always-sensible pretend uses per item, each with a kid-friendly reason. The fallback picks from these.
    public static let uses: [String: [(becomes: String, reason: String)]] = [
        "stuffed-animal": [("the patient", "A stuffed animal is soft and cuddly, just like a patient!"),
                           ("our pet", "A stuffed animal can be our furry pet!")],
        "chair": [("the airplane seats", "A chair is just right for sitting, like a seat on a plane!"),
                  ("the driver's seat", "A chair is perfect for sitting, like a driver's seat!")],
        "table": [("the shop counter", "A table is flat on top, just like a counter!"),
                  ("the cozy cave", "A table is big enough to hide under, like a cave!")],
        "couch": [("the big boat", "A couch is big enough for everyone to ride, like a boat!")],
        "pillow": [("the shield", "A pillow is soft and flat, just right for a pretend shield!"),
                   ("the cloud", "A pillow is soft and puffy like a cloud!")],
        "blanket": [("the ocean", "A blanket is big and floppy, like waves on the ocean!"),
                    ("the superhero cape", "A blanket is big and floppy, just like a cape!")],
        "rug": [("the island", "A rug is flat and big enough to stand on, like an island!")],
        "cardboard-box": [("the rocket ship", "A box is big enough to sit in, like a rocket!"),
                          ("the treasure chest", "A box can hold things, just like a treasure chest!")],
        "plate": [("the steering wheel", "A plate is round like a steering wheel!"),
                  ("the gold coin", "A plate is round and flat like a big coin!")],
        "cup": [("the telescope cup", "A cup is round like the end of a telescope!"),
                ("the magic potion", "A cup can hold things, just like a potion!")],
        "bowl": [("the captain's hat", "A bowl is round like a captain's hat!"),
                 ("the mixing bowl", "A bowl can hold things, just like a mixing bowl!"),
                 ("the treasure bowl", "A bowl can hold lots of treasure!")],
        "tray": [("the snack cart", "A tray is flat, just right for carrying snacks!")],
        "spoon": [("the magic wand", "A spoon is long and thin like a magic wand!"),
                  ("the big stirrer", "A spoon is long, just right for stirring!")],
        "pot": [("the knight's helmet", "A pot is round and fits on your head like a helmet!"),
                ("the soup pot", "A pot can hold things, just like a soup pot!")],
        "towel": [("the superhero cape", "A towel is big and floppy, just like a cape!"),
                  ("the treasure map", "A towel is flat and floppy like a big map!")],
        "laundry-basket": [("the boat", "A laundry basket is big enough to sit in, like a boat!")],
        "books": [("the menu", "Books have flat pages like a menu!"),
                  ("the map book", "Books have flat pages, just like a map!")],
        "hat": [("the captain's hat", "A hat goes on your head, just like a captain's hat!")],
        "bag": [("the treasure bag", "A bag can hold things, just like a treasure bag!")],
        "backpack": [("the jet pack", "A backpack goes on your back, just like a jet pack!")],
        "toy-car": [("the delivery truck", "A toy car can drive, just like a truck!")],
        "flashlight": [("the lighthouse light", "A flashlight lights up like a lighthouse!"),
                       ("the spyglass", "A flashlight is long like a spyglass!")],
        "broom": [("the ship's mast", "A broom is long and tall like a mast!")],
        "teddy-bed": [("the pet bed", "A doll bed is soft and cozy, just like a pet bed!")],
        "lamp-off": [("the lighthouse", "A lamp is tall and lights up like a lighthouse!")],
        "cushion": [("the throne", "A cushion is soft for sitting, like a throne!")],
        "stool": [("the stage", "A step stool is flat on top, like a little stage!")],
        "sheet": [("the pirate sail", "A sheet is big and floppy, just like a sail!"),
                  ("the treasure map", "A sheet is big and flat like a map!")],
        "basket": [("the treasure chest", "A basket can hold things, just like a treasure chest!")],
        "bucket": [("the treasure bucket", "A bucket can hold lots of treasure!")],
        // Round 30: set 2.
        "paper": [("the treasure map", "Paper is flat, just right for a map!"),
                  ("the secret letter", "Paper is flat, just like a letter!"),
                  ("the train ticket", "Paper is flat, just like a ticket!")],
        "paper-towel-tube": [("the telescope", "A paper towel tube is long and hollow, just like a telescope!"),
                             ("the microphone", "A paper towel tube is long, just right for a microphone!"),
                             ("the magic wand", "A paper towel tube is long like a magic wand!")],
        "paper-bag": [("the treasure sack", "A paper bag can hold things, just like a sack!"),
                      ("the mailbag", "A paper bag can hold letters, just like a mailbag!")],
        "egg-carton": [("the jewel box", "An egg carton has little cups, just right for jewels!"),
                       ("the cupcake box", "An egg carton has little cups, just right for cupcakes!")],
        "crayons": [("the magic wands", "Crayons are long and thin like little wands!"),
                    ("the paint brushes", "Crayons are long like paint brushes!")],
        "tape": [("the finish line", "Tape makes a long line on the floor, just like a finish line!"),
                 ("the road lines", "Tape makes lines on the floor, just like a road!")],
        "paper-plate": [("the steering wheel", "A paper plate is round like a steering wheel!"),
                        ("the pizza", "A paper plate is round and flat like a pizza!"),
                        ("the gold coin", "A paper plate is round like a big coin!")],
        "plastic-container": [("the treasure chest", "A container can hold things, just like a treasure chest!"),
                              ("the lunch box", "A container can hold things, just like a lunch box!")],
        "measuring-cup": [("the magic potion", "A measuring cup can hold things, just like a potion!"),
                          ("the watering jug", "A measuring cup can pour, just like a watering jug!")],
        "colander": [("the space helmet", "A colander is round and fits on your head like a helmet!"),
                     ("the knight's helmet", "A colander is round like a knight's helmet!")],
        "baking-sheet": [("the steering wheel", "A baking sheet is easy to hold with two hands, like a steering wheel!"),
                         ("the serving tray", "A baking sheet is flat, just like a tray!"),
                         ("the knight's shield", "A baking sheet is flat and sturdy like a shield!")],
        "wooden-spoon": [("the magic wand", "A wooden spoon is long and thin like a magic wand!"),
                         ("the microphone", "A wooden spoon is long, just right for a microphone!"),
                         ("the big stirrer", "A wooden spoon is long, just right for stirring!")],
        "apron": [("the chef's apron", "An apron goes on you, just like a chef's apron!"),
                  ("the superhero cape", "An apron can tie on like a cape!")],
        "oven-mitt": [("the chef's glove", "An oven mitt goes on your hand, just like a chef's glove!"),
                      ("the astronaut glove", "An oven mitt is big and puffy like a space glove!")],
        "ball": [("the planet", "A ball is round like a planet!"),
                 ("the giant snowball", "A ball is round like a snowball!")],
        "scarf": [("the royal sash", "A scarf is long and soft like a royal sash!"),
                  ("the river", "A scarf is long and wavy like a river!")],
        "sunglasses": [("the spy glasses", "Sunglasses go on your face, just like spy glasses!"),
                       ("the space goggles", "Sunglasses go on your face like goggles!")],
        "sneakers": [("the jet boots", "Sneakers go on your feet, just like jet boots!"),
                     ("the space boots", "Sneakers go on your feet, just like space boots!")],
        "headband": [("the crown", "A headband goes on your head, just like a crown!"),
                     ("the tiara", "A headband is round and fits on your head like a tiara!")],
        "sock": [("the sock puppet", "A sock goes on your hand like a puppet!"),
                 ("the snowball", "A sock rolls up into a soft ball!")],
        "mittens": [("the polar gloves", "Mittens go on your hands, just like snowy gloves!"),
                    ("the boxing gloves", "Mittens are soft and puffy like big gloves!")],
        "umbrella": [("the walking cane", "A closed umbrella is long, just like a cane!"),
                     ("the magic wand", "A closed umbrella is long like a big magic wand!")],
        "pillowcase": [("the treasure sack", "A pillowcase can hold things, just like a sack!"),
                       ("the superhero cape", "A pillowcase is floppy like a little cape!"),
                       ("the treasure bag", "A pillowcase can hold lots of treasure!")],
        "toy-keys": [("the magic keys", "Toy keys jingle, just like magic keys!"),
                     ("the castle keys", "Toy keys can open a pretend castle door!")],
        "wagon": [("the delivery cart", "A wagon rolls and holds things, just like a cart!"),
                  ("the train", "A wagon rolls along, just like a train!"),
                  ("the race car", "A wagon has wheels, just like a car!")],
        "jump-rope": [("the finish line", "A jump rope lies flat on the floor like a finish line!"),
                      ("the river", "A jump rope makes a wiggly line on the floor like a river!")],
        "hula-hoop": [("the magic portal", "A hula hoop is a big circle, just like a portal!"),
                      ("the steering wheel", "A hula hoop is round like a giant steering wheel!"),
                      ("the pond", "A hula hoop makes a circle on the floor like a pond!")],
        "sidewalk-chalk": [("the road lines", "Chalk draws lines, just like a road!"),
                           ("the magic wands", "Chalk sticks are long like little wands!")],
        "plastic-cups": [("the castle tower", "Plastic cups stack up tall like a tower!"),
                         ("the drums", "Plastic cups are round like little drums!")],
        "sticky-notes": [("the tickets", "Sticky notes are flat, just like tickets!"),
                         ("the secret notes", "Sticky notes are just right for secret notes!")],
    ]
}

public enum PropFit {
    /// One kind of pretend use: the words that name it, and the tags an item needs (any one of them) to become it.
    public struct Need: Equatable, Sendable {
        public let name: String
        public let words: [String]
        public let anyOf: Set<PropTag>
    }

    /// The pretend-use rules. The head noun of "becomes" picks the rule (the last matching word before any "for/of/…").
    public static let needs: [Need] = [
        Need(name: "map", words: ["map", "maps", "scroll", "letter", "poster", "note", "chart", "flag", "sign", "menu",
                                  "ticket", "tickets", "paper", "page", "card", "postcard"], anyOf: [.sheet, .paper, .flat]),
        Need(name: "hat", words: ["hat", "hats", "helmet", "helmets", "crown", "crowns", "cap", "tiara", "headband"],
             anyOf: [.wearable, .round]),
        Need(name: "cape", words: ["cape", "capes", "cloak", "robe", "apron", "scarf", "veil", "costume", "gown", "dress"],
             anyOf: [.sheet]),
        Need(name: "sail", words: ["sail", "sails", "ocean", "sea", "waves", "water", "grass",
                                   "lava", "carpet", "tablecloth", "parachute", "snow", "sky"], anyOf: [.sheet, .surface]),
        // Round 30: a river, a pond or a finish line can also be a shape laid on the floor (a hula hoop, a jump rope).
        Need(name: "floor shape", words: ["river", "lake", "pond", "puddle", "stream", "finish", "line", "lines", "road",
                                          "path", "trail", "track"], anyOf: [.sheet, .surface, .outline]),
        // Round 30: a wheel is round, or held with two hands like one (a baking sheet).
        Need(name: "wheel", words: ["wheel", "steering", "dial"], anyOf: [.round, .grip]),
        Need(name: "round", words: ["clock", "sun", "moon", "coin", "coins", "porthole",
                                    "pizza", "cookie", "pancake", "planet", "drum"], anyOf: [.round]),
        Need(name: "shield", words: ["shield", "shields"], anyOf: [.round, .flat]),
        Need(name: "seat", words: ["seat", "seats", "throne", "bench", "saddle", "chair", "chairs", "sofa"],
             anyOf: [.sittable]),
        Need(name: "ride", words: ["boat", "ship", "rocket", "spaceship", "train", "bus", "wagon", "sled", "carriage",
                                   "submarine", "canoe", "raft", "car", "truck", "plane", "airplane", "cockpit"],
             anyOf: [.vehicle, .sittable, .boxy]),
        Need(name: "holder", words: ["chest", "box", "cage", "carrier", "nest", "crate", "bin", "cauldron", "bowl",
                                     "cup", "mug", "goblet", "pot", "bucket", "basket", "bag", "sack", "purse", "potion",
                                     "jar", "kettle", "teapot", "mailbag", "mailbox", "oven"], anyOf: [.container]),
        Need(name: "long", words: ["telescope", "spyglass", "sword", "wand", "oar", "oars", "paddle", "mast", "rod",
                                   "pole", "staff", "cane", "plank", "baton", "stick", "microphone", "stirrer",
                                   "ladle", "scoop", "spatula", "whisk", "spoon", "brush", "broom", "hose", "torch"],
             anyOf: [.long]),
        Need(name: "cart", words: ["cart", "trolley", "stroller", "wheelbarrow"], anyOf: [.flat, .surface, .container, .vehicle]),
        Need(name: "bed", words: ["bed", "beds", "cot", "crib", "hammock", "nap", "pillow", "blanket", "quilt"], anyOf: [.soft, .sheet, .container]),
        Need(name: "surface", words: ["counter", "desk", "stage", "island", "table", "tray", "platform", "runway", "dock",
                                      "shelf"], anyOf: [.flat, .surface]),
        Need(name: "shelter", words: ["tent", "cave", "fort", "den", "hideout", "roof", "house"], anyOf: [.sheet, .big]),
        Need(name: "creature", words: ["baby", "puppy", "kitten", "pet", "patient", "animal", "dragon", "monster",
                                       "dog", "cat", "bunny", "bear", "dinosaur", "unicorn", "parrot", "doll"],
             anyOf: [.creature]),
        Need(name: "light", words: ["light", "lantern", "lighthouse", "headlight", "spotlight", "lamp", "beacon"],
             anyOf: [.light]),
        Need(name: "pack", words: ["backpack", "jetpack", "pack"], anyOf: [.wearable, .container]),
    ]

    /// Words that end the head phrase ("map OF the island", "bowl FOR the batter").
    static let breakers: Set<String> = ["for", "of", "to", "with", "on", "in", "at", "from", "that", "where", "so", "and", "or"]

    /// The rule for a pretend use, or nil when the words aren't recognized (then any item is allowed).
    public static func need(for becomes: String) -> Need? {
        let words = becomes.lowercased().replacingOccurrences(of: "’", with: "'")
            .split { !$0.isLetter && $0 != "'" }.map { w in w.hasSuffix("'s") ? String(w.dropLast(2)) : String(w) }
        let head = words.prefix { !breakers.contains($0) }
        // The head noun is the LAST recognized word of the head phrase ("pirate map" → map, "treasure chest" → chest).
        for w in head.reversed() {
            if let n = needs.first(where: { $0.words.contains(w) }) { return n }
            if w.hasSuffix("s"), let n = needs.first(where: { $0.words.contains(String(w.dropLast())) }) { return n }
        }
        return nil
    }

    /// True when the item can plausibly become `becomes` (or the use isn't recognized). Off-list items are never a fit.
    public static func fits(itemID: String, becomes: String) -> Bool {
        guard let tags = PropLibrary.tagsFor(itemID) else { return false }
        guard let need = need(for: becomes) else { return true }
        return !tags.isDisjoint(with: need.anyOf)
    }

    /// Library items that can become this use, best first (`preferring` first, then the library order).
    public static func candidates(for becomes: String, preferring: [String] = [], avoiding: Set<String> = []) -> [String] {
        let pool = preferring.filter(PropLibrary.contains) + PropLibrary.ids.filter { !preferring.contains($0) }
        return pool.filter { !avoiding.contains($0) && fits(itemID: $0, becomes: becomes) }
    }

    /// A short kid-friendly reason for a pair that fits ("A bowl is round like a captain's hat!"): curated when the
    /// library has this exact use, else built from the tag the pair shares.
    public static func reason(itemID: String, becomes: String) -> String {
        let use = KitDraft.cutoutLabel(becomes: becomes).lowercased()
        if let c = PropLibrary.uses[itemID]?.first(where: { KitDraft.cutoutLabel(becomes: $0.becomes).lowercased() == use }) {
            return c.reason
        }
        let name = String((PropLibrary.name(itemID) ?? itemID).lowercased().split(separator: "(").first ?? "")
            .trimmingCharacters(in: .whitespaces)
        let plural = name.hasSuffix("s")
        let article = plural ? "" : ("aeiou".contains(name.first ?? "x") ? "an " : "a ")
        let item = article + name
        let subject = item.prefix(1).uppercased() + item.dropFirst()
        let thing = ConfirmStep.phrase(use)
        let tags = PropLibrary.tags[itemID] ?? []
        let shared = need(for: becomes).map { tags.intersection($0.anyOf) } ?? tags
        let be = plural ? "are" : "is", can = "can", have = plural ? "have" : "has"
        let tag = PropTag.allCases.first { shared.contains($0) }
        switch tag {
        case .round: return "\(subject) \(be) round like \(thing)!"
        case .flat, .surface: return "\(subject) \(be) flat like \(thing)!"
        case .sheet: return "\(subject) \(be) big and floppy like \(thing)!"
        case .long: return "\(subject) \(be) long like \(thing)!"
        case .container: return "\(subject) \(can) hold things, just like \(thing)!"
        case .wearable: return "\(subject) \(can) go on you, just like \(thing)!"
        case .sittable: return "\(subject) \(be) just right for sitting, like \(thing)!"
        case .soft: return "\(subject) \(be) soft and cozy, like \(thing)!"
        case .creature: return "\(subject) \(can) be \(thing)!"
        case .light: return "\(subject) \(can) light up like \(thing)!"
        case .paper: return "\(subject) \(have) flat pages like \(thing)!"
        case .grip: return "\(subject) \(be) easy to hold with two hands, like \(thing)!"
        case .outline: return "\(subject) \(can) make a shape on the floor, like \(thing)!"
        case .big, .boxy, .vehicle: return "\(subject) \(be) big enough to be \(thing)!"
        case nil: return "\(subject) \(can) be \(thing)!"
        }
    }

    /// The kid-friendly reason to keep: the model's own when it's short and kid-safe, else the app's.
    public static func keptReason(_ said: String?, itemID: String, becomes: String) -> String {
        let t = (said ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let words = t.split(separator: " ").count
        if (3...14).contains(words), Sanitizer.kidSafety(t, pretend: true) == nil, !TurnCheck.mentionsGoPlay(t) {
            return t.hasSuffix("!") || t.hasSuffix(".") ? t : t + "!"
        }
        return reason(itemID: itemID, becomes: becomes)
    }

    /// A sensible pair to fall back on: an item that fits THIS use (alternates first, items already used avoided), or
    /// when nothing fits, a curated pair from the library.
    public static func fallback(becomes: String, preferring: [String] = [], avoiding: Set<String> = [])
        -> (itemID: String, becomes: String, reason: String) {
        if let id = candidates(for: becomes, preferring: preferring, avoiding: avoiding).first {
            return (id, becomes, reason(itemID: id, becomes: becomes))
        }
        let id = (preferring + PropLibrary.ids).first { !avoiding.contains($0) && PropLibrary.uses[$0] != nil } ?? "towel"
        let use = PropLibrary.uses[id]?.first ?? ("the treasure map", "A towel is flat and floppy like a big map!")
        return (id, use.becomes, use.reason)
    }

    /// The tool output after a misfit: one retry, with the items that would fit.
    public static func retryOutput(itemID: String, becomes: String, preferring: [String] = []) -> String {
        let name = (PropLibrary.name(itemID) ?? itemID).lowercased()
        let fits = candidates(for: becomes, preferring: preferring).prefix(4).map { "\($0) (\((PropLibrary.name($0) ?? $0).lowercased()))" }
        return "Not shown: a \(name) can't really become \(becomes) (its shape doesn't fit). Say nothing yet: call the "
            + "same tool again with an item whose shape fits" + (fits.isEmpty ? "" : ", e.g. \(fits.joined(separator: ", "))")
            + ", or keep the item and pick a use that fits its shape. Add a short reason why it works."
    }

    /// Claude's prop list (tap path): every misfit pairing becomes a sensible one and every prop gets a reason.
    public static func repair(_ props: Props) -> Props {
        var out = props
        var used = Set<String>()
        for i in out.props.indices {
            var p = out.props[i]
            let id = p.libraryID ?? p.id
            if fits(itemID: id, becomes: p.becomes) {
                p.reason = keptReason(p.reason, itemID: id, becomes: p.becomes)
                used.insert(id)
            } else {
                let f = fallback(becomes: p.becomes, avoiding: used.union(out.props.compactMap { $0.libraryID ?? $0.id }))
                p.id = f.itemID; p.libraryID = f.itemID; p.householdItem = PropLibrary.name(f.itemID) ?? f.itemID
                p.becomes = f.becomes; p.reason = f.reason
                used.insert(f.itemID)
            }
            out.props[i] = p
        }
        return out
    }
}
