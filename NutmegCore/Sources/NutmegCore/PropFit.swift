import Foundation

// Round 24 (Haylee: "a bowl as a pirate map" made no sense): every household item → pretend use must be plausible by
// shape or function. Each library item has shape/function tags and a few curated pretend uses; each pretend use
// ("the pirate map", "a captain's hat") needs one of a few tag sets (a map needs something flat or sheet-like; a hat
// needs something that goes on a head). A pairing whose tags don't fit is rejected: the model gets one retry, then
// the app falls back to a curated sensible pair.
//
// Round 43 (the prop audit, thinking/research/2026-11-17-prop-audit.md; Haylee approved every fix):
// - F1: the head noun is the LAST word of the head phrase, only that word ("the pet drying cloth" → cloth, never "pet");
//   possessives are never the head ("the pet's food" → food); plurals fold with `PrintedProps.singular`.
// - F2: many more use words (cloths, gloves, boots, goggles, keys, walls, panels, round things, tubes, rings, food…).
// - F4: tighter tags: where a thing is worn (head, hand, feet, face, back, body), fabric, disc / ball / ring, size for
//   rides and shelters, real surfaces for counters. IDENTITY items (a stuffed animal, sneakers, mittens…) may only
//   become what they really are (a stuffed animal is only ever a creature); FLEXIBLE items (box, blanket, towel, bowl,
//   tray…) may still keep creative unknown uses (logged in DEBUG as "PROP unknown use").

/// What a household item is like (shape or what it can do).
public enum PropTag: String, Sendable, CaseIterable {
    case round, flat, long, soft, container, wearable, sheet, sittable, big, boxy, creature, light, paper, surface, vehicle
    /// Round 30: held with two hands like a wheel (a baking sheet, a hula hoop).
    case grip
    /// Round 30: lays a shape or line on the floor (a hula hoop, a jump rope, tape, chalk): a pond, a river, a finish line.
    case outline
    /// Round 43: where it's worn (`wearable` stays as the umbrella tag).
    case head, hand, feet, face, back, body
    /// Round 43: cloth (capes, sashes, bandages and cloths need it).
    case fabric
    /// Round 43: round split three ways: a flat disc (plate), a ball (ball, a rolled-up sock), a ring (hula hoop, headband).
    case disc, ball, ring
    /// Round 43: hollow like a telescope (paper towel tube, flashlight).
    case tube
    /// Round 43: jingly keys (toy keys only).
    case keys
    /// Round 43: stiff and sturdy (walls, towers, shields).
    case rigid
    /// Round 43: lies flat on the floor (a rug): an island, a river, a stage to stand on.
    case floor
    /// Round 43: holds several things (a box, a basket, a bag): a chest, a cage, a sack. A cup or a measuring cup isn't.
    case roomy
}

extension PropLibrary {
    /// Shape/function tags per library item. (Round 43: `surface` is a real raised top, like a table, a stool or a box;
    /// paper and the rug are no longer `sheet`, so paper is never a cape or a tent.)
    public static let tags: [String: Set<PropTag>] = [
        "stuffed-animal": [.soft, .creature],
        "chair": [.sittable, .big, .rigid],
        "table": [.flat, .big, .surface, .rigid],
        "couch": [.sittable, .big, .soft],
        "pillow": [.soft, .flat, .sittable],
        "blanket": [.sheet, .soft, .big, .wearable, .fabric, .body],
        "rug": [.flat, .big, .floor],
        "cardboard-box": [.container, .roomy, .big, .boxy, .vehicle, .sittable, .surface, .rigid],
        "plate": [.round, .disc, .flat, .rigid],
        "cup": [.round, .container],
        "bowl": [.round, .container, .wearable, .head],
        "tray": [.flat, .rigid],
        "spoon": [.long],
        "pot": [.round, .container, .roomy, .wearable, .head],
        "towel": [.sheet, .soft, .wearable, .fabric, .body],
        "laundry-basket": [.container, .roomy, .big, .vehicle, .sittable],
        "books": [.flat, .paper, .boxy, .rigid],
        "hat": [.wearable, .round, .head, .soft],
        "bag": [.container, .roomy, .soft],
        "backpack": [.container, .roomy, .wearable, .back],
        "toy-car": [.vehicle],
        "flashlight": [.long, .light, .tube],
        "broom": [.long],
        "teddy-bed": [.container, .soft, .flat],
        "cushion": [.soft, .flat, .sittable],
        "stool": [.sittable, .flat, .surface, .rigid],
        "sheet": [.sheet, .soft, .big, .wearable, .fabric, .body],
        "basket": [.container, .roomy, .round],
        "bucket": [.container, .roomy, .round, .wearable, .head],
        // Round 30: set 2.
        "paper": [.paper, .flat, .ball],   // crumples into a ball
        "paper-towel-tube": [.long, .tube],
        "paper-bag": [.container, .roomy, .paper],
        "egg-carton": [.container, .roomy, .boxy],
        "crayons": [.long],
        "tape": [.round, .ring, .outline],
        "paper-plate": [.round, .disc, .flat, .paper],
        "plastic-container": [.container, .roomy, .boxy, .rigid],
        "measuring-cup": [.container, .round],
        "colander": [.round, .container, .wearable, .head],
        "baking-sheet": [.flat, .surface, .grip, .rigid],
        "wooden-spoon": [.long],
        "apron": [.wearable, .soft, .fabric, .body],
        "oven-mitt": [.wearable, .soft, .fabric, .hand],
        "ball": [.round, .ball],
        "scarf": [.wearable, .soft, .sheet, .fabric, .body],
        "sunglasses": [.wearable, .face],
        "sneakers": [.wearable, .feet],
        "headband": [.wearable, .ring, .head],
        "sock": [.wearable, .soft, .fabric, .hand, .ball],   // rolls up into a ball
        "mittens": [.wearable, .soft, .fabric, .hand],
        "umbrella": [.long],   // closed: a cane or a wand, never opened indoors
        "pillowcase": [.sheet, .soft, .container, .roomy, .wearable, .fabric, .body],
        "toy-keys": [.keys],
        "wagon": [.vehicle, .big],
        "jump-rope": [.outline],   // round 43 (Haylee): only ever a shape on the floor
        "hula-hoop": [.round, .ring, .big, .grip, .outline],
        "sidewalk-chalk": [.long, .outline],
        "plastic-cups": [.round, .container, .rigid],
        "sticky-notes": [.paper, .flat],
    ]

    /// Everyday things that aren't on the card list but come up in talk ("a pool noodle works as a sword"): same tags.
    /// (Round 30: pillowcase, paper and paper towel tube are library items now.)
    public static let aliasTags: [String: Set<PropTag>] = [
        "pool noodle": [.long, .soft], "newspaper": [.paper, .flat],
    ]

    /// The library id for an id, a library name ("Bowl") or nil.
    public static func canonicalID(_ item: String) -> String? {
        if tags[item] != nil { return item }
        let l = item.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return items.first { $0.name.lowercased() == l }?.id
    }

    /// Tags for a library id, a library name ("Bowl") or an alias ("pool noodle"); nil when unknown.
    public static func tagsFor(_ item: String) -> Set<PropTag>? {
        if let t = tags[item] { return t }
        let l = item.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = aliasTags[l] { return t }
        return canonicalID(item).flatMap { tags[$0] }
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
        "plate": [("the steering wheel", "A plate is round like a steering wheel!")],   // round 42: no coins (the kit prints money)
        "cup": [("the magic potion", "A cup can hold things, just like a potion!"),   // round 43: no "telescope cup" (a cup isn't a tube)
                ("the tea cup", "A cup can hold pretend tea, just like a tea cup!")],
        "bowl": [("the captain's hat", "A bowl is round like a captain's hat!"),
                 ("the mixing bowl", "A bowl can hold things, just like a mixing bowl!"),
                 ("the treasure bowl", "A bowl can hold lots of treasure!")],
        "tray": [("the snack cart", "A tray is flat, just right for carrying snacks!")],
        "spoon": [("the magic wand", "A spoon is long and thin like a magic wand!"),
                  ("the big stirrer", "A spoon is long, just right for stirring!")],
        "pot": [("the knight's helmet", "A pot is round and fits on your head like a helmet!"),
                ("the soup pot", "A pot can hold things, just like a soup pot!")],
        "towel": [("the superhero cape", "A towel is big and floppy, just like a cape!"),
                  ("the magic carpet", "A towel is flat and floppy like a magic carpet!")],   // round 42: no maps (paper is the kit's job)
        "laundry-basket": [("the boat", "A laundry basket is big enough to sit in, like a boat!")],
        "books": [("the castle wall", "Books stack up like bricks in a wall!")],   // round 42: no menus or maps
        "hat": [("the captain's hat", "A hat goes on your head, just like a captain's hat!")],
        "bag": [("the treasure bag", "A bag can hold things, just like a treasure bag!")],
        "backpack": [("the jet pack", "A backpack goes on your back, just like a jet pack!")],
        "toy-car": [("the delivery truck", "A toy car can drive, just like a truck!")],
        "flashlight": [("the lighthouse light", "A flashlight lights up like a lighthouse!"),
                       ("the spyglass", "A flashlight is long like a spyglass!")],
        "broom": [("the ship's mast", "A broom is long and tall like a mast!")],
        "teddy-bed": [("the pet bed", "A doll bed is soft and cozy, just like a pet bed!")],
        "cushion": [("the throne", "A cushion is soft for sitting, like a throne!")],
        "stool": [("the stage", "A step stool is flat on top, like a little stage!")],
        "sheet": [("the pirate sail", "A sheet is big and floppy, just like a sail!"),
                  ("the tent", "A sheet is big and floppy, just right for a tent!")],
        "basket": [("the treasure chest", "A basket can hold things, just like a treasure chest!")],
        "bucket": [("the treasure bucket", "A bucket can hold lots of treasure!")],
        // Round 30: set 2.
        // Round 42: paper never becomes a printed thing (tickets, maps, letters: the kit prints those).
        "paper": [("the fan", "Paper folds into a fan, flap flap!"),
                  ("the snowballs", "Paper crumples into soft little snowballs!")],
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
                        ("the pizza", "A paper plate is round and flat like a pizza!")],
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
        "sticky-notes": [("the leaves", "Sticky notes can be the leaves on a pretend tree!"),   // round 42: no tickets or notes
                         ("the spots", "Sticky notes make great spots for a pretend ladybug!")],
    ]
}

/// Round 43 (F1): the head noun of a pretend use, shared by `PropFit` and `PrintedProps`.
public enum PropWords {
    /// Words that end the head phrase ("map OF the island", "bowl FOR the batter").
    public static let breakers: Set<String> = ["for", "of", "to", "with", "on", "in", "at", "from", "that", "where", "so",
                                                "and", "or", "who", "which", "when", "like", "as"]

    /// The head word as written (lowercased, possessives skipped): the LAST word of the head phrase, only that word.
    /// "the pet drying cloth" → cloth, "the captain's hat" → hat, "the pet's food" → food, "the check-in desk" → desk,
    /// "the jet-pack" → pack. Nil when there is no head phrase.
    public static func head(_ becomes: String) -> String? {
        let tokens = becomes.lowercased().replacingOccurrences(of: "’", with: "'")
            .split { $0.isWhitespace || $0 == "," || $0 == "/" || $0 == "(" || $0 == ")" }
        var head: [(word: String, possessive: Bool)] = []
        for raw in tokens {
            var t = String(raw.filter { $0.isLetter || $0 == "'" || $0 == "-" })
            while t.hasPrefix("'") || t.hasPrefix("-") { t.removeFirst() }
            while t.hasSuffix("-") { t.removeLast() }
            guard !t.isEmpty else { continue }
            if breakers.contains(t) { break }
            var possessive = false
            if t.hasSuffix("'s") { t.removeLast(2); possessive = true } else if t.hasSuffix("'") { t.removeLast(); possessive = true }
            t = t.replacingOccurrences(of: "'", with: "")
            let last = t.split(separator: "-").last.map(String.init) ?? t
            if !last.isEmpty { head.append((last, possessive)) }
        }
        return head.last(where: { !$0.possessive })?.word ?? head.last?.word
    }

    /// The head noun, singular ("the boarding passes" → pass, "the puppies" → puppy).
    public static func headNoun(_ becomes: String) -> String? { head(becomes).map(PrintedProps.singular) }

    /// A use's identity for the no-repeat rule: its singular head noun, or the whole phrase without articles when the
    /// head isn't a known use word ("the treasure chest" and "a treasure chest" and "the gold chest" are one use).
    public static func useKey(_ becomes: String) -> String {
        if let h = headNoun(becomes), PropFit.need(for: becomes) != nil { return h }
        let skip: Set<String> = ["the", "a", "an", "our", "my", "your", "their", "some"]
        return becomes.lowercased().split { !$0.isLetter }.map(String.init).filter { !skip.contains($0) }
            .map(PrintedProps.singular).joined(separator: " ")
    }
}

public enum PropFit {
    /// One kind of pretend use: the words that name it (singular, plus any irregular plurals), the tag sets an item
    /// may have to become it (any one set, every tag in it), and why it needs them (said in the retry).
    public struct Need: Equatable, Sendable {
        public let name: String
        public let words: Set<String>
        public let options: [Set<PropTag>]
        public let why: String
        public init(_ name: String, _ words: [String], _ options: [Set<PropTag>], why: String) {
            self.name = name; self.words = Set(words); self.options = options; self.why = why
        }
        /// Every tag any option uses.
        public var anyOf: Set<PropTag> { options.reduce(into: Set<PropTag>()) { $0.formUnion($1) } }
        public func fits(_ tags: Set<PropTag>) -> Bool { options.contains { $0.isSubset(of: tags) } }
    }

    /// The pretend-use rules. The head noun of "becomes" picks the rule (round 43: only the head noun).
    public static let needs: [Need] = [
        // Printed things are caught first (`PrintedProps`); a flag can still be cloth or paper.
        Need("flag", ["flag", "pennant", "map", "scroll", "letter", "poster", "note", "chart", "sign", "menu", "ticket",
                      "paper", "page", "card", "postcard"], [[.fabric], [.paper], [.sheet]], why: "it needs cloth or paper"),
        Need("hat", ["hat", "cap", "headband", "headdress", "bonnet", "beanie", "hood"], [[.head]],
             why: "it has to go on your head"),
        Need("helmet", ["helmet"], [[.head, .container], [.head, .round]], why: "a helmet has to fit over your head"),
        Need("crown", ["crown", "tiara", "halo"], [[.ring], [.head, .soft]], why: "a crown has to be a ring that sits on your head"),
        Need("cape", ["cape", "cloak", "robe", "apron", "scarf", "scarves", "veil", "costume", "gown", "dress", "sash",
                      "shawl", "skirt", "uniform", "coat", "vest", "smock", "toga", "jacket"],
             [[.fabric, .body]], why: "you wear it, so it needs cloth"),
        Need("cloth", ["cloth", "rag", "napkin", "towel", "bandage", "bib", "diaper", "tablecloth", "leash", "blanket",
                       "quilt", "cover", "washcloth", "dishcloth", "bedspread", "wrap", "curtain", "sponge", "duster"],
             [[.fabric]], why: "a cloth needs fabric"),
        Need("sail", ["sail", "parachute", "kite"], [[.sheet]], why: "it needs a big floppy cloth"),
        Need("cloud", ["cloud", "fluff", "puff"], [[.soft]], why: "it needs something soft"),
        Need("wing", ["wing"], [[.fabric], [.paper]], why: "wings need cloth or paper"),
        Need("sea", ["ocean", "sea", "wave", "waves", "water", "grass", "lava", "carpet", "snow", "sky", "sand", "beach",
                     "ice", "field", "lawn", "mud", "swamp", "floor"], [[.sheet], [.floor]],
             why: "it has to spread out flat on the floor"),
        // Round 30: a river, a pond or a finish line can also be a shape laid on the floor (a hula hoop, a jump rope).
        Need("floor shape", ["river", "lake", "pond", "puddle", "stream", "finish", "line", "road", "path", "trail", "track",
                             "island", "moat", "start", "circle", "lane", "crosswalk", "hopscotch"],
             [[.sheet], [.floor], [.outline]], why: "it has to lie on the floor"),
        // Round 30: a wheel is round, or held with two hands like one (a baking sheet).
        Need("wheel", ["wheel", "steering", "dial", "knob"], [[.disc], [.ring], [.grip]], why: "a wheel needs something round to hold"),
        Need("disc", ["clock", "coin", "pizza", "cookie", "pancake", "plate", "frisbee", "record", "tortilla", "pie",
                      "saucer", "lid", "cymbal", "waffle"], [[.disc]], why: "it needs something round and flat"),
        Need("sky", ["sun", "moon"], [[.disc], [.ball]], why: "it needs something round"),
        Need("ball", ["planet", "snowball", "apple", "egg", "ball", "orange", "meatball", "globe", "bubble", "marble",
                      "cannonball", "rock", "stone", "pumpkin", "berry", "melon", "coconut"], [[.ball]],
             why: "it needs something round like a ball"),
        Need("ring", ["portal", "hoop", "ring", "porthole", "lifesaver", "donut", "doughnut", "bagel", "wreath"],
             [[.ring], [.disc]], why: "it needs a circle"),
        Need("drum", ["drum", "bongo"], [[.container, .round], [.container, .rigid], [.disc]], why: "a drum needs something round and hollow"),
        Need("shield", ["shield"], [[.disc], [.rigid, .flat], [.soft, .flat]], why: "a shield needs something flat to hold up"),
        Need("seat", ["seat", "throne", "bench", "saddle", "chair", "sofa", "stool", "booth", "couch", "perch"],
             [[.sittable]], why: "you sit on it"),
        Need("ride", ["boat", "ship", "rocket", "spaceship", "train", "bus", "buses", "wagon", "sled", "carriage", "submarine",
                      "canoe", "raft", "car", "truck", "plane", "airplane", "cockpit", "taxi", "van", "tractor", "scooter",
                      "jet", "helicopter", "ambulance", "firetruck", "kayak", "sleigh", "chariot", "ufo", "spacecraft",
                      "vehicle", "engine", "motorcycle", "bike", "limo", "cab"],
             [[.vehicle], [.big, .sittable], [.big, .boxy]], why: "it has to be big enough to ride in"),
        Need("chest", ["chest", "box", "cage", "carrier", "crate", "bin", "bag", "sack", "purse", "mailbag", "mailbox",
                       "trunk", "safe", "vault", "pouch", "cooler", "lunchbox", "container", "hamper", "toolbox", "kit",
                       "basket", "case"], [[.container, .roomy]], why: "it has to hold lots of things"),
        Need("luggage", ["suitcase", "luggage"], [[.container, .boxy, .roomy], [.container, .soft], [.back]],
             why: "it has to be a bag or a case you can carry"),
        Need("cup", ["cup", "mug", "goblet", "bowl", "bowls", "pot", "bucket", "pail", "potion", "jar", "kettle", "teapot",
                     "dish", "jug", "pitcher", "can", "vase", "bottle", "cone", "teacup", "pan", "skillet", "wok", "feeder",
                     "cauldron", "oven", "sink", "bathtub", "tub", "tank"], [[.container, .round], [.container, .rigid]],
             why: "it has to be something like a cup or a dish"),
        Need("long", ["sword", "wand", "oar", "paddle", "mast", "rod", "pole", "staff", "cane", "plank", "baton",
                      "stick", "microphone", "mic", "stirrer", "ladle", "scoop", "spatula", "whisk", "spoon", "brush", "broom",
                      "hose", "torch", "bat", "flagpole", "lightsaber", "drumstick", "pointer", "ruler", "pen", "pencil",
                      "marker", "crayon", "paintbrush", "chalk", "thermometer", "pin", "antenna", "lollipop", "fork",
                      "toothbrush", "comb", "net", "shovel", "rake", "mop", "handle", "lever", "joystick"],
             [[.long]], why: "it needs something long"),
        Need("tube", ["telescope", "scope", "spyglass", "periscope", "horn", "megaphone", "binoculars", "binocular", "tube",
                      "trumpet", "flute", "kazoo", "pipe"], [[.tube]], why: "it needs something long and hollow"),
        Need("cart", ["cart", "trolley", "stroller", "wheelbarrow", "buggy"], [[.vehicle], [.flat, .rigid], [.container, .big]],
             why: "it has to carry things"),
        Need("tray", ["tray", "platter"], [[.flat]], why: "it needs something flat"),
        Need("bed", ["bed", "cot", "crib", "hammock", "nest", "cradle", "mattress", "nap"],
             [[.fabric], [.soft], [.container, .big]], why: "a bed needs something soft or cozy"),
        Need("cushion", ["pillow", "cushion", "beanbag"], [[.soft]], why: "it has to be soft"),
        Need("panel", ["panel", "console", "dashboard", "controls", "control", "register", "computer", "keyboard", "screen"],
             [[.surface], [.boxy]], why: "it needs a sturdy top or a box shape"),
        Need("stage", ["stage", "platform", "runway", "dock", "podium"], [[.surface], [.floor]], why: "you stand on it"),
        Need("surface", ["counter", "desk", "table", "shelf", "shelves", "rack", "stand", "workbench", "altar"],
             [[.surface]], why: "it needs a real sturdy top"),
        Need("shelter", ["tent", "cave", "fort", "den", "hideout", "roof", "house", "castle", "tunnel", "igloo", "hut",
                         "cabin", "treehouse", "garage", "barn", "doghouse", "kennel", "stable", "burrow", "lair", "palace",
                         "clubhouse", "shelter"], [[.big]], why: "it has to be big enough to get under or inside"),
        Need("wall", ["wall", "tower", "gate", "fence", "door", "brick", "building", "skyscraper", "bridge"],
             [[.rigid], [.big]], why: "it has to be sturdy or big"),
        Need("creature", ["baby", "puppy", "kitten", "pet", "patient", "animal", "dragon", "monster", "dog", "cat", "bunny",
                          "rabbit", "bear", "teddy", "dinosaur", "dino", "unicorn", "parrot", "doll", "passenger", "customer",
                          "guest", "pony", "horse", "fish", "bird", "chick", "lion", "tiger", "elephant", "penguin", "monkey",
                          "duck", "frog", "turtle", "owl", "mouse", "mice", "kitty", "critter", "creature", "giraffe",
                          "whale", "dolphin", "shark", "octopus", "seal", "otter", "fox", "koala", "panda", "sheep", "cow",
                          "pig", "goat", "chicken", "hamster", "camel", "alien", "friend", "buddy", "sidekick",
                          "kangaroo", "zebra", "hippo", "puppies", "babies"],
             [[.creature]], why: "only a stuffed animal can be a creature"),
        Need("puppet", ["puppet"], [[.hand], [.creature]], why: "a puppet goes on your hand"),
        Need("light", ["light", "lantern", "lighthouse", "headlight", "spotlight", "lamp", "beacon", "scanner", "flashlight",
                       "laser", "nightlight", "candle"], [[.light]], why: "it has to light up"),
        Need("pack", ["backpack", "jetpack", "pack", "rucksack", "knapsack"], [[.back], [.container, .soft], [.container, .paper]],
             why: "it goes on your back"),
        Need("glove", ["glove", "mitt", "mitten", "gauntlet", "mittens"], [[.hand]], why: "it goes on your hand"),
        Need("boot", ["boot", "shoe", "skate", "flipper", "slipper", "sneaker", "sandal"], [[.feet]], why: "it goes on your feet"),
        Need("goggles", ["goggles", "glasses", "sunglasses", "mask", "visor", "spectacles", "shades", "eyepatch", "monocle"],
             [[.face]], why: "it goes on your face"),
        Need("keys", ["key", "keys"], [[.keys]], why: "keys have to jingle"),
        Need("food", ["food", "snack", "treat", "meal", "dinner", "lunch", "breakfast", "cake", "cupcake", "sandwich", "fruit",
                      "popcorn", "burger", "taco", "salad", "noodle", "spaghetti", "candy", "sweets", "dessert", "muffin",
                      "bread", "loaf", "pretzel", "sushi", "carrot", "veggie", "vegetable", "cream", "icecream"],
             [[.disc], [.ball], [.container, .round]], why: "pretend food needs something round or a dish to hold it"),
        Need("bits", ["leaf", "leaves", "spot", "petal", "feather", "scale", "sprinkle", "confetti", "snowflake", "fan",
                      "book", "story"], [[.paper]], why: "it needs paper"),
    ]

    /// Heads that name no real thing ("the robot repair hub", "the sorting station"): treated as unknown uses, so an
    /// identity item can never become one, and a flexible item may (logged in DEBUG).
    public static let abstractHeads: Set<String> = ["hub", "station", "area", "zone", "center", "sorter", "thing", "stuff",
                                                    "helper", "corner", "place", "maker", "set", "gear", "tool", "supplies",
                                                    "equipment", "machine", "headquarters", "base", "room", "site"]

    /// Words that end the head phrase (kept for older callers).
    static let breakers: Set<String> = PropWords.breakers

    /// The rule for a pretend use, or nil when the head noun isn't recognized (then a flexible item is allowed).
    public static func need(for becomes: String) -> Need? {
        guard let w = PropWords.head(becomes) else { return nil }
        if let n = needs.first(where: { $0.words.contains(w) }) { return n }
        let s = PrintedProps.singular(w)
        return needs.first { $0.words.contains(s) }
    }

    // MARK: Identity items (round 43, Haylee: "a stuffed animal is only ever a creature")

    /// An item so clearly itself that it may only become what it's shaped like: these rules (by name) or head words.
    public struct Identity: Sendable {
        public let needs: Set<String>
        public let words: Set<String>
        /// "an animal, a pet, a patient or a passenger" (said in the retry).
        public let only: String
    }

    public static let identity: [String: Identity] = [
        "stuffed-animal": .init(needs: ["creature", "puppet"], words: [], only: "a creature: the pet, the patient, the baby or the passenger"),
        "sneakers": .init(needs: ["boot"], words: [], only: "shoes or boots"),
        "mittens": .init(needs: ["glove", "puppet"], words: [], only: "gloves or a hand puppet"),
        "oven-mitt": .init(needs: ["glove", "puppet"], words: [], only: "a glove or a hand puppet"),
        "sock": .init(needs: ["glove", "puppet", "ball"], words: [], only: "a puppet, a glove or a soft snowball"),
        "sunglasses": .init(needs: ["goggles"], words: [], only: "glasses, goggles or a mask"),
        "toy-car": .init(needs: ["ride"], words: [], only: "a little car or truck"),
        "toy-keys": .init(needs: ["keys"], words: [], only: "keys"),
        "ball": .init(needs: ["ball", "sky", "food"], words: [], only: "something round: a planet, a snowball, an apple"),
        "crayons": .init(needs: [], words: ["wand", "brush", "paintbrush", "pen", "pencil", "marker", "crayon", "chalk", "pointer"],
                         only: "drawing tools or little wands"),
        "sidewalk-chalk": .init(needs: ["floor shape"], words: ["wand", "brush", "paintbrush", "pen", "pencil", "marker", "crayon",
                                                              "chalk", "pointer"], only: "lines on the floor or drawing tools"),
        "flashlight": .init(needs: ["light", "tube"], words: [], only: "a light or a scanner"),
        "umbrella": .init(needs: [], words: ["cane", "wand", "staff", "stick"], only: "a cane or a wand (closed)"),
        "jump-rope": .init(needs: ["floor shape"], words: [], only: "a shape on the floor: a river, a road, a finish line"),
        "hula-hoop": .init(needs: ["floor shape", "ring", "wheel"], words: [], only: "a circle: a pond, a portal or a wheel"),
    ]

    /// Round 43 (Haylee): toy-ish things not in every home; everyday things come first for the first prop and fallbacks.
    public static let toyish: Set<String> = ["teddy-bed", "toy-keys", "broom", "wagon", "hula-hoop", "sidewalk-chalk"]

    /// Round 43: the items used most often over the last rounds (box, bowl, blanket, pillow): the shortlist down-weights them.
    public static let chronic: Set<String> = ["cardboard-box", "bowl", "blanket", "pillow"]

    // MARK: The check

    /// The verdict on one pair: whether it fits, the rule that decided it (nil = an unknown use) and why not.
    public struct Check: Equatable, Sendable {
        public let ok: Bool
        public let rule: String?
        public let why: String?
        /// A flexible item allowed for a use the rules don't know (logged in DEBUG).
        public var unknown: Bool { ok && rule == nil }
    }

    public static func check(itemID: String, becomes: String) -> Check {
        guard let tags = PropLibrary.tagsFor(itemID) else { return Check(ok: false, rule: nil, why: "it isn't on the item list") }
        // Round 42: never a paper thing the kit prints (tickets, passes, money, menus, signs, badges, maps, cards...).
        if let c = PrintedProps.clash(becomes) { return Check(ok: false, rule: "printed", why: "it's a paper thing the kit prints (the \(c))") }
        let need = need(for: becomes)
        if let id = PropLibrary.canonicalID(itemID), let rule = identity[id] {
            let head = PropWords.head(becomes)
            let byWord = head.map { rule.words.contains($0) || rule.words.contains(PrintedProps.singular($0)) } ?? false
            let byNeed = need.map { rule.needs.contains($0.name) } ?? false
            guard byWord || byNeed else {
                return Check(ok: false, rule: need?.name ?? "identity", why: "a \(itemName(id)) is only ever \(rule.only)")
            }
            if byWord, need.map({ !$0.fits(tags) }) ?? true { return Check(ok: true, rule: need?.name ?? "identity", why: nil) }
        }
        guard let need else { return Check(ok: true, rule: nil, why: nil) }
        return need.fits(tags) ? Check(ok: true, rule: need.name, why: nil) : Check(ok: false, rule: need.name, why: need.why)
    }

    /// True when the item can plausibly become `becomes` (or the use isn't recognized and the item is flexible).
    /// Off-list items are never a fit.
    public static func fits(itemID: String, becomes: String) -> Bool { check(itemID: itemID, becomes: becomes).ok }

    /// True when the pair fits by a KNOWN rule (never just "unknown use allowed").
    public static func fitsKnown(itemID: String, becomes: String) -> Bool {
        let c = check(itemID: itemID, becomes: becomes)
        return c.ok && c.rule != nil
    }

    static func itemName(_ id: String) -> String {
        String((PropLibrary.name(id) ?? id).lowercased().split(separator: "(").first ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// Library ids in the fallback order: everyday things first, toy-ish ones last (round 43, Haylee).
    public static var everydayFirst: [String] { PropLibrary.ids.filter { !toyish.contains($0) } + PropLibrary.ids.filter(toyish.contains) }

    /// Library items that can become this use, best first (`preferring` first, then everyday things, then toy-ish).
    public static func candidates(for becomes: String, preferring: [String] = [], avoiding: Set<String> = []) -> [String] {
        let pool = preferring.filter(PropLibrary.contains) + everydayFirst.filter { !preferring.contains($0) }
        var seen = Set<String>()
        return pool.filter { seen.insert($0).inserted && !avoiding.contains($0) && fits(itemID: $0, becomes: becomes) }
    }

    /// A short kid-friendly reason for a pair that fits ("A bowl is round like a captain's hat!"): curated when the
    /// library has this exact use, else built from the rule and the tags the pair shares.
    public static func reason(itemID: String, becomes: String) -> String {
        let use = KitDraft.cutoutLabel(becomes: becomes).lowercased()
        if let c = PropLibrary.uses[itemID]?.first(where: { KitDraft.cutoutLabel(becomes: $0.becomes).lowercased() == use }) {
            return c.reason
        }
        let name = itemName(itemID)
        let plural = name.hasSuffix("s")
        let article = plural ? "" : ("aeiou".contains(name.first ?? "x") ? "an " : "a ")
        let item = article + name
        let subject = item.prefix(1).uppercased() + item.dropFirst()
        let thing = ConfirmStep.phrase(use)
        let tags = PropLibrary.tags[itemID] ?? []
        let need = need(for: becomes)
        let shared = need.map { tags.intersection($0.anyOf) } ?? tags
        let be = plural ? "are" : "is", can = "can", have = plural ? "have" : "has", go = plural ? "go" : "goes"
        // The rule first (keeps the round-24 phrasing: "A bowl is round like a captain's hat!").
        switch need?.name {
        case "hat", "helmet": return tags.contains(.round) ? "\(subject) \(be) round like \(thing)!" : "\(subject) \(go) on your head, just like \(thing)!"
        case "crown": return tags.contains(.ring) ? "\(subject) \(be) a circle that fits on your head, like \(thing)!" : "\(subject) \(go) on your head, just like \(thing)!"
        case "cape", "sail": return tags.contains(.sheet) ? "\(subject) \(be) big and floppy like \(thing)!" : "\(subject) \(be) soft cloth, just like \(thing)!"
        case "cloth": return "\(subject) \(be) soft cloth, just right for \(thing)!"
        case "glove": return "\(subject) \(go) on your hand, just like \(thing)!"
        case "puppet" where tags.contains(.hand): return "\(subject) \(go) on your hand, just like \(thing)!"
        case "boot": return "\(subject) \(go) on your feet, just like \(thing)!"
        case "goggles": return "\(subject) \(go) on your face, just like \(thing)!"
        case "pack": return tags.contains(.back) ? "\(subject) \(go) on your back, just like \(thing)!" : "\(subject) \(can) hold things, just like \(thing)!"
        case "keys": return "\(subject) jingle, just like \(thing)!"
        case "tube": return "\(subject) \(be) long and hollow like \(thing)!"
        case "ball", "sky": return "\(subject) \(be) round like \(thing)!"
        case "disc": return "\(subject) \(be) round and flat like \(thing)!"
        case "ring": return "\(subject) \(be) a circle, just like \(thing)!"
        case "wall": return tags.contains(.rigid) ? "\(subject) \(be) strong and sturdy like \(thing)!" : "\(subject) \(be) big enough to be \(thing)!"
        case "shelter", "ride": return "\(subject) \(be) big enough to be \(thing)!"
        case "sea" where tags.contains(.floor), "stage" where tags.contains(.floor), "floor shape" where tags.contains(.floor): return "\(subject) \(be) flat on the floor, like \(thing)!"
        case "bits": return "\(subject) \(be) made of paper, just right for \(thing)!"
        default: break
        }
        let order: [PropTag] = [.round, .flat, .surface, .sheet, .long, .container, .wearable, .sittable, .soft, .creature,
                                .light, .paper, .grip, .outline, .disc, .ball, .ring, .tube, .fabric, .rigid, .floor, .big,
                                .boxy, .vehicle, .head, .hand, .feet, .face, .back, .body, .keys, .roomy]
        let tag = order.first { shared.contains($0) }
        switch tag {
        case .round, .disc, .ball, .ring: return "\(subject) \(be) round like \(thing)!"
        case .flat, .surface, .floor: return "\(subject) \(be) flat like \(thing)!"
        case .sheet, .fabric: return "\(subject) \(be) big and floppy like \(thing)!"
        case .long, .tube: return "\(subject) \(be) long like \(thing)!"
        case .container, .roomy: return "\(subject) \(can) hold things, just like \(thing)!"
        case .wearable, .head, .hand, .feet, .face, .back, .body: return "\(subject) \(can) go on you, just like \(thing)!"
        case .sittable: return "\(subject) \(be) just right for sitting, like \(thing)!"
        case .soft: return "\(subject) \(be) soft and cozy, like \(thing)!"
        case .creature: return "\(subject) \(can) be \(thing)!"
        case .light: return "\(subject) \(can) light up like \(thing)!"
        case .paper: return "\(subject) \(have) flat pages like \(thing)!"
        case .grip: return "\(subject) \(be) easy to hold with two hands, like \(thing)!"
        case .outline: return "\(subject) \(can) make a shape on the floor, like \(thing)!"
        case .rigid: return "\(subject) \(be) strong and sturdy like \(thing)!"
        case .keys: return "\(subject) jingle, just like \(thing)!"
        case .big, .boxy, .vehicle: return "\(subject) \(be) big enough to be \(thing)!"
        case nil: return "\(subject) \(can) be \(thing)!"
        }
    }

    /// Words that explain nothing in a reason ("A stuffed animal CAN BE a pet drying cloth!").
    static let emptyReasonWords: Set<String> = [
        "a", "an", "the", "can", "could", "be", "is", "are", "it", "its", "itll", "will", "would", "our", "your", "my", "we",
        "us", "just", "like", "pretend", "that", "this", "make", "makes", "great", "perfect", "awesome", "super", "so",
        "really", "very", "totally", "become", "becomes", "turn", "turns", "into", "as", "for", "of", "to", "and", "use",
        "good", "fun", "best", "one", "wonderful", "amazing", "cool", "nice", "too", "also", "here", "there", "now", "lets",
        "ok", "okay", "yes", "yay", "wow", "ooh", "hey", "you", "work", "works", "idea", "thing", "things", "some", "magic",
        "magical", "fantastic", "excellent", "lovely", "pretty", "special", "exactly", "right", "sure", "time",
    ]

    /// Round 43 (the audit): a reason that only repeats the pair ("A stuffed animal can be a pet drying cloth!")
    /// explains nothing. True when no word is left after the item's words, the use's words and empty words.
    public static func parrots(_ reason: String, itemID: String, becomes: String) -> Bool {
        func words(_ s: String) -> [String] {
            s.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
                .split { !$0.isLetter }.map { PrintedProps.singular(String($0)) }
        }
        let known = Set(words(itemName(itemID)) + words(PropLibrary.name(itemID) ?? itemID) + words(becomes)).union(emptyReasonWords)
        return words(reason).allSatisfy { known.contains($0) || known.contains($0 + "s") }
    }

    /// The kid-friendly reason to keep: the model's own when it's short, kid-safe and explains something, else the app's.
    public static func keptReason(_ said: String?, itemID: String, becomes: String) -> String {
        let t = (said ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let words = t.split(separator: " ").count
        if (3...14).contains(words), Sanitizer.kidSafety(t, pretend: true) == nil, !TurnCheck.mentionsGoPlay(t),
           !parrots(t, itemID: itemID, becomes: becomes) {
            return t.hasSuffix("!") || t.hasSuffix(".") ? t : t + "!"
        }
        return reason(itemID: itemID, becomes: becomes)
    }

    /// A sensible pair to fall back on: an item that fits THIS use (alternates first, items already used avoided), or
    /// when nothing fits, a curated pair from the library whose use isn't one of `avoidingUses`.
    public static func fallback(becomes: String, preferring: [String] = [], avoiding: Set<String> = [],
                                avoidingUses: Set<String> = []) -> (itemID: String, becomes: String, reason: String) {
        if !avoidingUses.contains(PropWords.useKey(becomes)),
           let id = candidates(for: becomes, preferring: preferring, avoiding: avoiding).first {
            return (id, becomes, reason(itemID: id, becomes: becomes))
        }
        return curatedPair(preferring: preferring, avoiding: avoiding, avoidingUses: avoidingUses)
    }

    /// The first curated pair (preferred items first, then everyday things) that isn't printed, used or a repeated use.
    public static func curatedPair(preferring: [String] = [], avoiding: Set<String> = [], avoidingUses: Set<String> = [],
                                   printed: (String) -> Bool = { PrintedProps.clash($0) != nil })
        -> (itemID: String, becomes: String, reason: String) {
        func ok(_ u: (becomes: String, reason: String)) -> Bool { !printed(u.becomes) && !avoidingUses.contains(PropWords.useKey(u.becomes)) }
        for id in preferring.filter(PropLibrary.contains) + everydayFirst where !avoiding.contains(id) {
            if let u = (PropLibrary.uses[id] ?? []).first(where: ok) { return (id, u.becomes, u.reason) }
        }
        return ("towel", "the superhero cape", "A towel is big and floppy, just like a cape!")
    }

    /// The tool output after a misfit: one retry, naming the problem and the items that would fit (round 43: an
    /// identity item is told what it really is).
    public static func retryOutput(itemID: String, becomes: String, preferring: [String] = [], avoiding: Set<String> = []) -> String {
        if let clash = PrintedProps.clash(becomes) { return PrintedProps.retryOutput(itemID: itemID, becomes: becomes, clash: clash) }
        let name = itemName(itemID)
        let c = check(itemID: itemID, becomes: becomes)
        let fits = candidates(for: becomes, preferring: preferring, avoiding: avoiding.union([itemID])).prefix(4)
            .map { "\($0) (\(itemName($0)))" }
        let keep: String
        if let id = PropLibrary.canonicalID(itemID), identity[id] != nil {
            let own = (PropLibrary.uses[id] ?? []).map(\.becomes).filter { !avoiding.contains($0) }.prefix(2).joined(separator: ", ")
            keep = ", or keep the \(name) as what it really is" + (own.isEmpty ? "" : ": \(own)")
        } else {
            keep = ", or keep the \(name) and pick a use that fits its shape"
        }
        return "Not shown: a \(name) can't become \(becomes) (\(c.why ?? "its shape doesn't fit")). Say nothing yet: call the "
            + "same tool again with an item that fits" + (fits.isEmpty ? "" : ", e.g. \(fits.joined(separator: ", "))")
            + keep + ". Add a short reason why it works."
    }

    /// Claude's prop list (tap path): every misfit pairing becomes a sensible one, every prop gets a reason, no item
    /// and no pretend use is there twice (round 43), and with a shortlist every item comes from it.
    public static func repair(_ props: Props, shortlist: PropShortlist? = nil) -> Props {
        var out = props
        var used = Set<String>(), usedUses = Set<String>()
        let allowed = shortlist?.allowed
        let preferring = shortlist?.allIDs ?? []
        var keptIDs: [String] = []
        for i in out.props.indices {
            var p = out.props[i]
            let id = p.libraryID ?? p.id
            let onList = allowed.map { $0.contains(id) } ?? true
            if onList, !used.contains(id), !usedUses.contains(PropWords.useKey(p.becomes)), fits(itemID: id, becomes: p.becomes) {
                p.reason = keptReason(p.reason, itemID: id, becomes: p.becomes)
            } else {
                let avoid = used.union(out.props.enumerated().filter { $0.offset > i }.compactMap { $0.element.libraryID ?? $0.element.id })
                var f = fallback(becomes: p.becomes, preferring: preferring.filter { allowed?.contains($0) ?? true },
                                 avoiding: avoid.union(allowed.map { a in Set(PropLibrary.ids.filter { !a.contains($0) }) } ?? []),
                                 avoidingUses: usedUses)
                if used.contains(f.itemID) || usedUses.contains(PropWords.useKey(f.becomes)) {
                    f = curatedPair(preferring: preferring, avoiding: avoid, avoidingUses: usedUses)
                }
                p.id = f.itemID; p.libraryID = f.itemID; p.householdItem = PropLibrary.name(f.itemID) ?? f.itemID
                p.becomes = f.becomes; p.reason = f.reason
            }
            let lib = p.libraryID ?? p.id
            used.insert(lib); usedUses.insert(PropWords.useKey(p.becomes)); keptIDs.append(lib)
            p.alternates = p.alternates?.filter { $0 != lib && !keptIDs.contains($0) && fits(itemID: $0, becomes: p.becomes) }
            out.props[i] = p
        }
        return out
    }
}
