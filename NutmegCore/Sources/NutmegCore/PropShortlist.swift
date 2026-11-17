import Foundation

// Round 43 (Haylee: "box is always used"): round 30's RecentPropMemory only NUDGED (a note in the roles result plus a
// fresher swap), and the model kept copying the instructions' fixed examples (box, bowl). Now the app picks each game's
// prop SHORTLIST itself, the way SuggestionMemory picks the game ideas: ~8 library items that can become one of the
// uses THIS game needs, weighted away from the last 5 games' props, never an item used in each of the last 2 games
// (unless nothing else fits), and the chronic ones (box, bowl, blanket, pillow) down-weighted. The model must choose
// from the shortlist or its backups; anything else gets one retry, then a shortlist fallback. Made-up games work too:
// the needed uses are inferred from the game, theme and role words. Only library IDs are involved: nothing about kids.

/// What a game needs props for (pretend uses), inferred from its words.
public enum PropNeeds {
    /// A kind of game: words that name it, and the pretend uses its props usually become (most iconic first).
    public struct Profile: Sendable {
        public let keys: [String]
        public let uses: [String]
    }

    public static let profiles: [Profile] = [
        .init(keys: ["restaurant", "cafe", "café", "diner", "waiter", "waitress", "chef", "cook", "kitchen", "cooking", "pizza",
                     "pizzeria", "pancake", "burger", "taco", "noodle", "sushi", "dinner", "picnic", "lunch"],
              uses: ["the serving tray", "the chef's hat", "the soup pot", "the big stirrer", "the dinner table",
                     "the chef's apron", "the pizza", "the customer seats", "the oven mitt", "the mixing bowl"]),
        .init(keys: ["bakery", "baker", "cake", "cookie", "cupcake", "bread", "pastry", "donut", "muffin", "pie"],
              uses: ["the baker's apron", "the cookie tray", "the rolling pin", "the cake", "the oven glove", "the shop counter",
                     "the chef's hat", "the whisk", "the mixing bowl", "the cupcake box"]),
        .init(keys: ["vet", "veterinarian", "pet", "groomer", "grooming", "puppy", "kitten", "animal", "shelter", "kennel"],
              uses: ["the patient", "the pet bed", "the pet carrier", "the drying towel", "the feeding dish", "the check-up table",
                     "the bandage", "the thermometer", "the grooming brush", "the pet's leash"]),
        .init(keys: ["doctor", "hospital", "nurse", "patient", "clinic", "dentist", "medic", "ambulance"],
              uses: ["the patient", "the doctor's coat", "the thermometer", "the bandage", "the hospital bed",
                     "the waiting room chairs", "the check-up table", "the doctor's bag", "the ambulance"]),
        .init(keys: ["zoo", "zookeeper", "farm", "farmer", "barn", "safari", "aquarium", "stable", "jungle", "penguin",
                     "farm-animals", "dinosaurs", "unicorn", "unicorns", "dragon", "dragons"],
              uses: ["the animals", "the animal cage", "the feeding bucket", "the hay bed", "the zookeeper's hat", "the fence",
                     "the food bowl", "the binoculars", "the barn"]),
        .init(keys: ["pirate", "pirates", "ship", "sail", "sailor", "treasure", "island", "captain", "parrot"],
              uses: ["the treasure chest", "the pirate sail", "the captain's hat", "the spyglass", "the steering wheel",
                     "the ocean", "the pirate ship", "the parrot", "the gold sack", "the plank"]),
        .init(keys: ["space", "rocket", "moon", "mars", "astronaut", "planet", "alien", "galaxy", "star", "stars", "spaceship",
                     "launch", "nighttime"],
              uses: ["the rocket ship", "the space helmet", "the control panel", "the planet", "the astronaut gloves",
                     "the moon boots", "the space goggles", "the jet pack", "the moon rock", "the star light"]),
        .init(keys: ["robot", "robots", "inventor", "invention", "lab", "scientist", "science"],
              uses: ["the control panel", "the robot helmet", "the robot's antenna", "the repair toolbox", "the robot",
                     "the scanner", "the lab goggles", "the lab coat"]),
        .init(keys: ["airplane", "plane", "pilot", "flight", "airport", "jet", "cloud", "clouds", "sky"],
              uses: ["the airplane seats", "the pilot's hat", "the steering wheel", "the snack cart", "the carry-on bag",
                     "the pilot's goggles", "the cloud", "the runway"]),
        .init(keys: ["train", "railway", "railroad", "conductor", "bus", "subway", "tram", "trolley", "station"],
              uses: ["the train seats", "the conductor's hat", "the train", "the steering wheel", "the snack cart",
                     "the train tracks", "the luggage"]),
        .init(keys: ["car", "race", "racing", "racer", "driver", "truck", "garage", "mechanic", "car wash", "road", "taxi"],
              uses: ["the race car", "the steering wheel", "the finish line", "the driver's helmet", "the washing cloth",
                     "the soap bucket", "the road", "the toolbox"]),
        .init(keys: ["castle", "knight", "knights", "princess", "prince", "king", "queen", "royal", "kingdom", "palace",
                     "fairy", "wizard", "witch", "magic", "spell", "time-travel"],
              uses: ["the crown", "the knight's shield", "the knight's helmet", "the royal cape", "the throne",
                     "the castle wall", "the magic wand", "the dragon", "the tower", "the cauldron", "the potion"]),
        .init(keys: ["superhero", "superheroes", "hero", "heroes", "rescue"],
              uses: ["the superhero cape", "the hero mask", "the shield", "the power gloves", "the jet boots", "the hideout"]),
        .init(keys: ["camping", "camp", "campfire", "forest", "hike", "hiking", "tent", "woods", "explorer", "treehouse",
                     "bird-watching", "bird", "birds", "mountain"],
              uses: ["the tent", "the lantern", "the backpack", "the sleeping bag", "the campfire pot", "the hiking boots",
                     "the binoculars", "the river", "the bird nest"]),
        .init(keys: ["post office", "mail", "mailman", "postal", "letter", "letters", "delivery", "package", "parcel", "courier"],
              uses: ["the mailbag", "the mailbox", "the delivery truck", "the package box", "the mail carrier's hat",
                     "the sorting desk", "the delivery cart"]),
        .init(keys: ["grocery", "store", "shop", "market", "supermarket", "shopkeeper", "cashier", "toy shop", "toy", "toys",
                     "boutique"],
              uses: ["the shopping basket", "the shop counter", "the shopping cart", "the cash register", "the shopping bag",
                     "the shelves"]),
        .init(keys: ["flower", "flowers", "florist", "garden", "gardener", "plant", "plants"],
              uses: ["the flower vase", "the watering can", "the flower basket", "the flower pot", "the garden path",
                     "the shop counter"]),
        .init(keys: ["lemonade", "juice", "smoothie"],
              uses: ["the lemonade pitcher", "the cups", "the lemonade stand", "the ice bucket", "the money jar", "the stirrer"]),
        .init(keys: ["ice cream", "icecream", "sundae", "popsicle", "candy", "sweets", "cookie kingdom"],
              uses: ["the ice cream scoop", "the ice cream cone", "the ice cream truck", "the bowls", "the candy jar",
                     "the counter"]),
        .init(keys: ["firefighter", "firefighters", "fire", "firehouse", "volcano"],
              uses: ["the fire hose", "the firefighter's helmet", "the fire truck", "the water bucket", "the rescue light",
                     "the fire boots"]),
        .init(keys: ["salon", "hair", "barber", "hairdresser", "beauty", "spa", "nail", "nails"],
              uses: ["the salon chair", "the hair brush", "the salon cape", "the towel", "the headband", "the shampoo bottle"]),
        .init(keys: ["library", "librarian", "book", "books", "reading", "story"],
              uses: ["the story books", "the library desk", "the book cart", "the reading carpet", "the reading light",
                     "the book bag"]),
        .init(keys: ["school", "teacher", "class", "classroom", "student", "lesson"],
              uses: ["the teacher's desk", "the pointer", "the backpack", "the lunch box", "the class chairs", "the chalk"]),
        .init(keys: ["museum", "gallery", "art", "artist", "painter", "painting"],
              uses: ["the display stand", "the paint brushes", "the treasure box", "the guide's flashlight", "the art apron"]),
        .init(keys: ["dinosaur", "dino", "fossil", "dig", "digger", "archaeologist", "paleontologist"],
              uses: ["the dinosaur egg", "the dino nest", "the baby dinosaur", "the digging bucket", "the explorer's hat",
                     "the brush", "the lava"]),
        .init(keys: ["submarine", "sea", "ocean", "underwater", "mermaid", "fish", "beach", "diver", "diving", "ocean-island",
                     "tropical", "surf"],
              uses: ["the submarine", "the periscope", "the diving goggles", "the flippers", "the ocean", "the fish",
                     "the treasure chest", "the porthole"]),
        .init(keys: ["tea party", "tea", "party", "birthday", "picnic"],
              uses: ["the teapot", "the tea cups", "the party hats", "the picnic blanket", "the cake", "the guests"]),
        .init(keys: ["detective", "spy", "spies", "mystery", "clue", "clues", "secret"],
              uses: ["the spy glasses", "the detective's hat", "the flashlight", "the clue bag", "the hideout", "the spyglass"]),
        .init(keys: ["construction", "builder", "build", "building", "bulldozer", "crane"],
              uses: ["the hard hat", "the toolbox", "the bricks", "the dump truck", "the bucket", "the wall"]),
        .init(keys: ["circus", "clown", "show", "stage", "puppet", "band", "orchestra", "music", "musician", "concert",
                     "marching", "singer", "dance", "dancer", "theater", "theatre", "parade"],
              uses: ["the stage", "the microphone", "the drums", "the ringmaster's hat", "the hoop", "the juggling balls",
                     "the puppet", "the band hats", "the conductor's baton"]),
        .init(keys: ["hotel", "inn", "bellhop", "resort", "guest", "guests"],
              uses: ["the check-in desk", "the guest bed", "the luggage cart", "the room keys", "the suitcase", "the pillows"]),
        .init(keys: ["weather", "forecast", "news", "reporter", "tv"],
              uses: ["the microphone", "the cloud", "the sun", "the snowballs", "the rain boots", "the news desk"]),
        .init(keys: ["north pole", "snow", "snowy", "winter", "ice", "igloo", "polar", "arctic", "north-pole", "penguins",
                     "santa", "elf", "elves"],
              uses: ["the snowballs", "the igloo", "the polar gloves", "the snow boots", "the sled", "the warm scarf",
                     "the penguins", "the snow"]),
        .init(keys: ["bug", "bugs", "insect", "insects", "ladybug", "butterfly", "ant", "ants", "bee", "bees"],
              uses: ["the giant leaves", "the ladybug spots", "the bug jar", "the binoculars", "the bug house"]),
        .init(keys: ["rainbow", "unicorn"],
              uses: ["the rainbow river", "the cloud", "the sun", "the unicorn", "the magic wand"]),
        .init(keys: ["desert", "sand", "sandy", "camel", "oasis", "pyramid"],
              uses: ["the explorer's hat", "the sand", "the camel", "the water jug", "the sunglasses", "the tent"]),
        .init(keys: ["teddy", "teddy-bears", "bear", "bears", "doll", "dolls", "toy box", "toys", "nursery"],
              uses: ["the teddy bears", "the toy box", "the bed", "the picnic blanket", "the baby"]),
        .init(keys: ["monster", "monsters", "mouse-town", "mouse", "mice", "tiny"],
              uses: ["the friendly monster", "the monster cave", "the monster mask", "the snack bowl", "the little house"]),
    ]

    /// Uses that fit almost any game (for a made-up game whose words match nothing).
    public static let generic: [String] = ["the treasure chest", "the magic wand", "the superhero cape", "the captain's hat",
                                           "the seats", "the treasure bag", "the counter", "the bed", "the light", "the ocean"]

    /// The words of a game: lowercased, singular and plural kept, plus the whole text for two-word keys.
    static func words(_ texts: [String]) -> (tokens: Set<String>, text: String) {
        let text = texts.joined(separator: " ").lowercased()
        var tokens = Set<String>()
        for w in text.split(whereSeparator: { !$0.isLetter && $0 != "-" }) {
            let s = String(w)
            tokens.insert(s); tokens.insert(PrintedProps.singular(s))
            for part in s.split(separator: "-") { tokens.insert(String(part)); tokens.insert(PrintedProps.singular(String(part))) }
        }
        return (tokens, text)
    }

    static func matches(_ p: Profile, _ w: (tokens: Set<String>, text: String)) -> Bool {
        p.keys.contains { k in k.contains(" ") ? w.text.contains(k) : w.tokens.contains(k) }
    }

    /// Words too general to be a prop use on their own ("friend", "customer": they're people in the game).
    static let notDirect: Set<String> = ["friend", "buddy", "sidekick", "customer", "guest", "passenger", "patient", "line",
                                         "start", "can", "pin", "pack", "set", "kit", "stand", "control", "light", "bits",
                                         "story", "book", "floor", "water", "food", "treat", "card", "page", "paper"]

    /// The pretend uses THIS game needs, most important first (the game and theme words before the roles' words),
    /// at most `limit`, no two the same use.
    public static func uses(game: [String], roles: [String] = [], limit: Int = 16) -> [String] {
        let g = words(game), r = words(roles)
        var out: [String] = [], keys = Set<String>()
        func add(_ u: String) {
            guard out.count < limit, PrintedProps.clash(u) == nil, keys.insert(PropWords.useKey(u)).inserted else { return }
            out.append(u)
        }
        // A thing the game names itself ("Rocket Bakery" → the rocket) comes first: it's what the kids picture.
        for t in game.joined(separator: " ").lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        where !notDirect.contains(t) && !notDirect.contains(PrintedProps.singular(t)) {
            if PropFit.need(for: t) != nil, PrintedProps.clash(t) == nil { add("the \(t)") }
        }
        let fromGame = profiles.filter { matches($0, g) }
        let fromRoles = profiles.filter { p in !fromGame.contains { $0.keys == p.keys } && matches(p, r) }
        // Interleave the matched profiles so a two-part game ("Bakery on the Moon") gets uses from both parts.
        let lists = (fromGame + fromRoles).map(\.uses)
        var i = 0
        while out.count < limit, lists.contains(where: { $0.count > i }) {
            for l in lists where l.count > i { add(l[i]) }
            i += 1
        }
        if out.count < 6 { for u in generic { add(u) } }
        return out
    }
}

/// This game's prop shortlist (round 43): the items the model chooses from, each with a use it could become here.
public struct PropShortlist: Equatable, Sendable, Codable {
    public struct Pick: Equatable, Sendable, Codable {
        public let itemID: String
        /// A use from this game's needs that the item fits ("the serving tray").
        public let use: String
    }
    public var picks: [Pick]
    /// More items for swaps ("we don't have one"), same rules.
    public var backups: [Pick]
    /// The uses this game needs (inferred from its words).
    public var uses: [String]

    public static let size = 8
    public static let backupCount = 4

    public var allIDs: [String] { picks.map(\.itemID) + backups.map(\.itemID) }
    public var allowed: Set<String> { Set(allIDs) }
    public func contains(_ id: String) -> Bool { allowed.contains(id) }
    /// The pick's suggested use for an item.
    public func use(for id: String) -> String? { (picks + backups).first { $0.itemID == id }?.use }

    public init(picks: [Pick], backups: [Pick], uses: [String]) { self.picks = picks; self.backups = backups; self.uses = uses }

    // MARK: Weights

    /// Recent-game factors, newest game first: an item in the last game is much less likely, five games ago a little.
    public static let recencyFactors: [Double] = [0.15, 0.3, 0.5, 0.7, 0.85]
    public static let chronicFactor = 0.35
    public static let toyishFactor = 0.6

    /// How likely an item is to be sampled: more for fitting several of the game's uses, less for recent, chronic
    /// (box, bowl, blanket, pillow) and toy-ish things.
    public static func weight(_ id: String, fitCount: Int, recent: [[String]]) -> Double {
        var w = 1 + 0.5 * Double(min(max(fitCount - 1, 0), 2))
        for (i, game) in recent.prefix(recencyFactors.count).enumerated() where game.contains(id) { w *= recencyFactors[i] }
        if PropFit.chronic.contains(id) { w *= chronicFactor }
        if PropFit.toyish.contains(id) { w *= toyishFactor }
        return w
    }

    /// Items used in EACH of the last 2 games: never on the shortlist unless nothing else fits.
    public static func excluded(recent: [[String]]) -> Set<String> {
        guard recent.count >= 2 else { return [] }
        return Set(recent[0]).intersection(recent[1])
    }

    // MARK: Making one

    /// Samples this game's shortlist. `game`: the game type, title and theme; `roles`: role names and jobs; `recent`:
    /// the last games' prop ids, newest first (`RecentPropMemory.games`).
    public static func make<G: RandomNumberGenerator>(game: [String], roles: [String] = [], recent: [[String]],
                                                      size: Int = size, backups backupCount: Int = backupCount,
                                                      using rng: inout G) -> PropShortlist {
        let uses = PropNeeds.uses(game: game, roles: roles)
        // Which of the game's uses each item can become (by a KNOWN rule, never just "unknown use allowed").
        var fitsOf: [String: [String]] = [:]
        for id in PropLibrary.ids {
            let f = uses.filter { PropFit.fitsKnown(itemID: id, becomes: $0) }
            if !f.isEmpty { fitsOf[id] = f }
        }
        let out = excluded(recent: recent)
        var chosen: [Pick] = []
        var takenUses = Set<String>()
        func w(_ id: String) -> Double { weight(id, fitCount: fitsOf[id]?.count ?? 0, recent: recent) }
        func take(_ id: String, preferUse: String? = nil) {
            let options = fitsOf[id] ?? []
            let use = preferUse ?? options.first { !takenUses.contains(PropWords.useKey($0)) } ?? options.first ?? ""
            takenUses.insert(PropWords.useKey(use))
            chosen.append(Pick(itemID: id, use: use))
        }
        func pick(from pool: [String]) -> String? { weightedPick(pool, weight: w, using: &rng) }
        let isChosen: (String) -> Bool = { id in chosen.contains { $0.itemID == id } }

        // 1. The game's three core uses each get an item (an excluded one only if nothing else can be it).
        for use in uses.prefix(3) where !takenUses.contains(PropWords.useKey(use)) {
            let can = PropLibrary.ids.filter { !isChosen($0) && (fitsOf[$0] ?? []).contains(use) }
            if let id = pick(from: can.filter { !out.contains($0) }) ?? pick(from: can) { take(id, preferUse: use) }
        }
        // 2. The rest, weighted, from everything that fits one of the game's uses (excluded ones only to fill up).
        let all = PropLibrary.ids.filter { fitsOf[$0] != nil }
        while chosen.count < size + backupCount {
            let fresh = all.filter { !isChosen($0) && !out.contains($0) }
            let pool = fresh.isEmpty ? all.filter { !isChosen($0) } : fresh
            guard let id = pick(from: pool) else { break }
            take(id)
        }
        // 3. A tiny game (few known uses): top up with everyday flexible items and their curated uses.
        if chosen.count < size {
            for id in PropFit.everydayFirst where !isChosen(id) && !out.contains(id) && chosen.count < size {
                if let u = PropLibrary.uses[id]?.first(where: { PrintedProps.clash($0.becomes) == nil }) {
                    chosen.append(Pick(itemID: id, use: u.becomes))
                }
            }
        }
        return PropShortlist(picks: Array(chosen.prefix(size)), backups: Array(chosen.dropFirst(size).prefix(backupCount)), uses: uses)
    }

    public static func make(game: [String], roles: [String] = [], recent: [[String]]) -> PropShortlist {
        var rng = SystemRandomNumberGenerator()
        return make(game: game, roles: roles, recent: recent, using: &rng)
    }

    static func weightedPick<G: RandomNumberGenerator>(_ pool: [String], weight: (String) -> Double, using rng: inout G) -> String? {
        let ws = pool.map { max(weight($0), 0.0001) }
        let total = ws.reduce(0, +)
        guard !pool.isEmpty, total > 0 else { return nil }
        var r = Double.random(in: 0..<total, using: &rng)
        for (id, w) in zip(pool, ws) { if r < w { return id }; r -= w }
        return pool.last
    }

    // MARK: What the model is told

    static func listed(_ picks: [Pick]) -> String {
        picks.map { "\($0.itemID) (\(PropFit.itemName($0.itemID)), e.g. \($0.use))" }.joined(separator: ", ")
    }

    /// The set_roles result's shortlist note.
    public var note: String {
        " THIS GAME'S PROP SHORTLIST (the app picked it fresh for this game, so props change from game to game): choose "
            + "EVERY prop from these list items, any other item is turned away: \(Self.listed(picks))."
            + (backups.isEmpty ? "" : " Backups for swap_prop when the kids don't have one: \(Self.listed(backups)).")
            + " The e.g. uses are ideas; any use that fits the item's shape and THIS game is fine. Never the same item twice "
            + "and never the same pretend use twice in one hunt. The first prop is the most fun, iconic thing for this game, "
            + "and an everyday thing."
    }

    /// The tool output when the model picked an item that isn't on the shortlist: one retry.
    public func retryOutput(itemID: String, becomes: String, used: Set<String>) -> String {
        let free = picks.filter { !used.contains($0.itemID) }
        let fitting = (picks + backups).filter { !used.contains($0.itemID) && PropFit.fits(itemID: $0.itemID, becomes: becomes) }
            .prefix(3).map(\.itemID)
        return "Not shown: the \(PropFit.itemName(itemID)) isn't on this game's prop shortlist (the app picks a fresh "
            + "shortlist every game so props change). Say nothing yet: call the same tool again with an item from the "
            + "shortlist" + (fitting.isEmpty ? "" : " (for \(becomes): \(fitting.joined(separator: ", ")))")
            + ": \(Self.listed(free))" + (backups.isEmpty ? "" : "; backups: \(backups.map(\.itemID).joined(separator: ", "))")
            + ". Add a short reason why it works."
    }
}

/// Round 43: the one sentence of the shape rules both prompts carry (the audit's tag table, no anchoring examples).
public enum PropRules {
    public static let shapeSentence = "hats go on a head; capes, sashes and cloths are fabric (towel, blanket, sheet, scarf, "
        + "pillowcase); seats are for sitting; rides, tents and caves are big enough to get in; counters and desks need a "
        + "real sturdy top; a stuffed animal is only ever an animal, a pet, a patient or a passenger (in a game with animals "
        + "or patients it IS the animal or patient), never a thing for one; a jump rope is only a shape on the floor (a "
        + "river, a finish line)."
}
