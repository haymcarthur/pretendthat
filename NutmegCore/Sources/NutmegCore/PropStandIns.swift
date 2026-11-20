import Foundation

// 2026-11-21 (Haylee, decisions/2026-11-21-events-are-scenarios-and-ownership.md): a sock became "a planet" in a live
// game. Instead of one more rule per bad pairing, every library prop gets a short list of believable pretend things it
// can become, judged by shape and function for a 4 to 8 year old. The hunt, the guide's weave and the setup items may
// only turn a prop into one of its stand-ins; the app repairs anything else with no AI call (`settle`, `itemText`).
// Haylee reviews the list in design/prop-stand-ins.md (kept in sync by a test: `PropStandInsTests`).

public enum PropStandIns {
    /// Library id → 10 to 15 pretend things (2026-11-21, Haylee: a big range, spread over the theme families: space, jungle/farm/dinosaurs, castle/magic, shop/restaurant/doctor/school, sea, wild west, superheroes, pirates, rescue, spooky, snowy north, robots/lab, circus, sports) it can become (Claude's list, for Haylee's review). Includes every curated
    /// use in `PropLibrary.uses` (tested), so the app's own fallback pairs always pass.
    public static let table: [(id: String, standIns: [String])] = [
        ("stuffed-animal", ["patient", "pet", "baby animal", "passenger", "sidekick", "customer", "baby dinosaur", "lost puppy", "zoo animal", "sea creature", "circus animal", "royal pet", "student", "friendly monster", "polar bear cub"]),
        ("chair", ["airplane seat", "driver's seat", "throne", "train seat", "ship's seat", "cockpit seat", "race car seat", "fire truck seat", "waiting room chair", "barber chair", "stagecoach seat", "rocket seat", "lifeguard chair", "ringmaster's stand"]),
        ("table", ["shop counter", "cave", "desk", "stage", "bridge", "control desk", "checkout counter", "vet table", "lab bench", "hideout", "fort", "dinosaur den", "bakery counter", "workbench", "ticket booth"]),
        ("couch", ["boat", "bus", "spaceship", "island", "train", "sofa fort", "pirate ship", "submarine", "fire truck", "stagecoach", "sled", "parade float", "lifeboat", "racing car", "castle wall"]),
        ("pillow", ["shield", "cloud", "boulder", "bed", "seat cushion", "marshmallow", "stepping stone", "snowdrift", "giant egg", "hay bale", "lily pad", "moon rock", "treasure sack", "crash pad", "pillow fort wall"]),
        ("blanket", ["ocean", "superhero cape", "tent", "lava", "magic carpet", "snowy field", "picnic blanket", "royal robe", "cave roof", "river", "grass field", "space blanket", "ghost costume", "parachute", "sail"]),
        ("rug", ["island", "stage", "magic carpet", "landing pad", "pond", "dance floor", "circus ring", "sports field", "beach", "ice rink", "lava lake", "launch pad", "throne room", "camp site", "finish area"]),
        ("cardboard-box", ["rocket ship", "treasure chest", "big oven", "car", "fort", "robot body", "boat", "cave", "puppet theater", "shop stand", "mailbox", "time machine", "dog house", "race car", "submarine"]),
        ("plate", ["steering wheel", "pizza", "dish", "flying saucer", "shield", "clock", "pie", "cookie", "moon", "dial", "gold medal", "lily pad", "frisbee", "drum", "planet ring"]),
        ("cup", ["magic potion", "tea cup", "mug", "goblet", "drum", "cocoa mug", "medicine cup", "science beaker", "trophy", "telescope lens", "space cup", "pirate mug", "milkshake", "soup cup", "megaphone"]),
        ("bowl", ["captain's hat", "mixing bowl", "treasure bowl", "snack bowl", "helmet", "nest", "cauldron", "soup bowl", "pet bowl", "space helmet", "dinosaur egg nest", "crystal ball", "drum", "feeding dish", "fruit bowl"]),
        ("tray", ["snack cart", "serving tray", "control panel", "shield", "treat tray", "display tray", "steering wheel", "sled", "bakery tray", "doctor's tray", "lab tray", "cookie sheet", "surfboard", "map table", "pizza peel"]),
        ("spoon", ["magic wand", "big stirrer", "microphone", "oar", "scoop", "shovel", "doctor's tool", "fishing rod", "baton", "paintbrush", "conductor's baton", "ladle", "robot arm", "magic staff", "flag"]),
        ("pot", ["knight's helmet", "soup pot", "cauldron", "drum", "treasure pot", "cooking pot", "helmet", "witch's cauldron", "pot of gold", "flower pot", "bucket", "rocket engine", "science pot", "campfire pot", "honey pot"]),
        ("towel", ["superhero cape", "magic carpet", "blanket", "drying cloth", "river", "sail", "beach towel", "royal robe", "flag", "bandage", "ghost costume", "baby blanket", "picnic cloth", "surfboard", "pet blanket"]),
        ("laundry-basket", ["boat", "cage", "cockpit", "nest", "race car", "treasure cart", "shopping cart", "crib", "bumper car", "sled", "lifeboat", "hot air balloon basket", "pet carrier", "train car", "submarine"]),
        ("books", ["castle wall", "ramp", "wall", "bricks", "control panel", "stepping stones", "tower", "bridge", "dinosaur fossils", "magic spell books", "stairs", "treasure crates", "road block", "podium", "shop shelf"]),
        ("hat", ["captain's hat", "chef's hat", "conductor's cap", "pilot cap", "wizard hat", "cowboy hat", "pirate hat", "firefighter helmet", "police cap", "explorer hat", "crown", "ringmaster's hat", "baseball cap", "witch hat", "detective hat"]),
        ("bag", ["treasure bag", "mailbag", "shopping bag", "doctor's bag", "picnic bag", "loot sack", "gold sack", "lunch bag", "bag of seeds", "rescue bag", "magic bag", "toy sack", "explorer bag", "gift sack", "popcorn bag"]),
        ("backpack", ["jet pack", "carry-on bag", "explorer pack", "air tank", "rescue pack", "school bag", "oxygen tank", "parachute pack", "camping pack", "diving tank", "superhero jet pack", "first aid pack", "space pack", "treasure pack", "hiking pack"]),
        ("toy-car", ["delivery truck", "race car", "police car", "fire truck", "taxi", "ambulance", "moon buggy", "tow truck", "school bus", "jeep", "ice cream truck", "dump truck", "monster truck", "mail truck", "robot car"]),
        ("flashlight", ["lighthouse light", "spyglass", "searchlight", "torch", "laser beam", "headlight", "magic light", "ghost detector", "rescue light", "space beam", "lantern", "spotlight", "flashlight beacon", "scanner", "microphone"]),
        ("broom", ["ship's mast", "horse", "witch's broom", "flagpole", "sweeper", "hobby horse", "magic broom", "fishing pole", "jousting horse", "street sweeper", "giant paintbrush", "oar", "tent pole", "hockey stick", "rake"]),
        ("teddy-bed", ["pet bed", "baby crib", "nest", "hospital bed", "dragon nest", "doll bed", "baby animal bed", "dinosaur nest", "puppy basket", "royal bed", "space pod", "vet bed", "boat", "sleeping bag", "cradle"]),
        ("cushion", ["throne", "stepping stone", "seat", "cloud", "lily pad", "raft", "hay bale", "island", "boulder", "space rock", "pillow", "moon rock", "trampoline", "royal cushion", "magic carpet"]),
        ("stool", ["stage", "lookout tower", "podium", "throne", "step", "counter", "circus stand", "winner's podium", "ladder", "mountain top", "crow's nest", "pedestal", "cash register stand", "lion's stand", "rock"]),
        ("sheet", ["pirate sail", "tent", "ghost costume", "cape", "ocean", "fort roof", "sail", "magic curtain", "parachute", "snow field", "cloud", "royal banner cloth", "circus tent", "river", "picnic cloth"]),
        ("basket", ["treasure chest", "picnic basket", "nest", "shopping basket", "egg basket", "fruit basket", "basket of gold", "bird nest", "harvest basket", "laundry basket", "hot air balloon basket", "fishing basket", "popcorn basket", "gift basket", "puppy basket"]),
        ("bucket", ["treasure bucket", "drum", "helmet", "well", "water bucket", "sand bucket", "fire bucket", "paint bucket", "pail", "ice bucket", "popcorn bucket", "feed bucket", "fishing bucket", "cauldron", "trash can"]),
        ("paper-towel-tube", ["telescope", "microphone", "magic wand", "spyglass", "megaphone", "baton", "rocket", "flute", "periscope", "light saber", "binoculars", "walkie-talkie", "candle", "tree trunk", "pipe"]),
        ("paper-bag", ["treasure sack", "mailbag", "lunch bag", "puppet", "shopping bag", "gold sack", "popcorn bag", "goody bag", "hand puppet", "mask", "seed bag", "candy sack", "grocery bag", "flour sack", "loot sack"]),
        ("egg-carton", ["jewel box", "cupcake box", "egg box", "seed tray", "control panel", "paint palette", "treasure box", "dinosaur egg nest", "candy box", "muffin tin", "button board", "robot panel", "spaceship dashboard", "bug house", "gem tray"]),
        ("crayons", ["magic wands", "paint brushes", "candles on a cake", "rocket fuel sticks", "carrots", "pretend candles", "drumsticks", "fishing rods", "logs", "sparklers", "magic sticks", "chopsticks", "test tubes", "fence posts", "pencils"]),
        ("tape", ["finish line", "road lines", "path", "start line", "boundary line", "runway", "racetrack", "parking spaces", "hopscotch", "laser maze", "train tracks", "crosswalk", "river", "goal line", "map lines"]),
        ("paper-plate", ["steering wheel", "pizza", "flying saucer", "clock", "pie", "shield", "mask", "moon", "planet", "cookie", "gold medal", "lily pad", "frisbee", "sun", "dial"]),
        ("plastic-container", ["treasure chest", "lunch box", "first aid kit", "toolbox", "cash box", "fish tank", "bug house", "time capsule", "jewel box", "cooler", "science box", "dino fossil box", "ice block", "mail box", "lunch tray"]),
        ("measuring-cup", ["magic potion", "watering jug", "pitcher", "scoop", "tea pot", "science beaker", "milk jug", "potion bottle", "lemonade pitcher", "watering can", "gold scoop", "lab cup", "feed scoop", "sand scoop", "medicine cup"]),
        ("colander", ["space helmet", "knight's helmet", "strainer", "lamp shade", "crown", "robot helmet", "diving helmet", "alien hat", "gold sifter", "sieve", "planet dome", "rescue helmet", "bubble helmet", "basket", "fishing net"]),
        ("baking-sheet", ["steering wheel", "serving tray", "knight's shield", "control panel", "cookie sheet", "sled", "pizza tray", "surfboard", "skateboard", "robot chest plate", "dashboard", "shield", "treasure map table", "snowboard", "bakery tray"]),
        ("wooden-spoon", ["magic wand", "microphone", "big stirrer", "oar", "conductor's baton", "drumstick", "paddle", "magic staff", "baton", "torch", "flag pole", "fairy wand", "fishing rod", "shovel", "walking stick"]),
        ("apron", ["chef's apron", "superhero cape", "doctor's coat", "painter's smock", "tool belt", "lab coat", "baker's apron", "vet coat", "shop apron", "blacksmith apron", "art smock", "cape", "royal robe", "uniform", "costume"]),
        ("oven-mitt", ["chef's glove", "astronaut glove", "puppet", "dragon claw", "boxing glove", "hand puppet", "bear paw", "robot hand", "monster hand", "space glove", "firefighter glove", "lobster claw", "dinosaur claw", "winter glove", "baking glove"]),
        ("ball", ["planet", "moon", "giant snowball", "egg", "pumpkin", "cannonball", "dinosaur egg", "crystal ball", "sun", "meteor", "apple", "coconut", "magic orb", "soccer ball", "basketball"]),
        ("scarf", ["royal sash", "river", "tail", "snake", "rope bridge", "cape", "sash", "headband", "belt", "flag", "bandage", "leash", "lasso", "ribbon", "scarf of a snowman"]),
        ("sunglasses", ["spy glasses", "space goggles", "superhero mask", "diving goggles", "movie star glasses", "safety goggles", "ski goggles", "detective glasses", "x-ray glasses", "pilot goggles", "rock star glasses", "night vision goggles", "robot eyes", "swim goggles", "lifeguard glasses"]),
        ("sneakers", ["jet boots", "space boots", "rocket shoes", "hiking boots", "running shoes", "moon boots", "magic boots", "cowboy boots", "rain boots", "snow boots", "superhero boots", "dancing shoes", "spring shoes", "racing shoes", "soccer cleats"]),
        ("headband", ["crown", "tiara", "halo", "headset", "flower crown", "royal crown", "superhero mask band", "antennae band", "sweatband", "pilot headset", "princess crown", "laurel crown", "lion mane band", "unicorn horn band", "radio headset"]),
        ("sock", ["sock puppet", "puppet", "snake", "tail", "snowball", "glove", "worm", "caterpillar", "elephant trunk", "mitten", "dragon puppet", "animal tail", "hand puppet", "stocking", "sea serpent"]),
        ("mittens", ["polar gloves", "boxing gloves", "puppets", "bear paws", "snow gloves", "oven gloves", "astronaut gloves", "monster paws", "lion paws", "cat paws", "space gloves", "firefighter gloves", "hand puppets", "robot hands", "winter gloves"]),
        ("umbrella", ["walking cane", "magic wand", "flagpole", "fishing rod", "hiking stick", "wizard staff", "ringmaster's cane", "royal scepter", "tent pole", "conductor's baton", "lightning rod", "magic staff", "cane", "candy cane", "pointer stick"]),
        ("pillowcase", ["treasure sack", "superhero cape", "treasure bag", "sleeping bag", "loot sack", "mailbag", "gold sack", "toy sack", "sack race bag", "ghost costume", "laundry sack", "flour sack", "gift sack", "potato sack", "cape"]),
        ("toy-keys", ["magic keys", "castle keys", "car keys", "jail keys", "treasure keys", "spaceship keys", "shop keys", "door keys", "secret keys", "robot keys", "fire truck keys", "train keys", "dungeon keys", "house keys", "boat keys"]),
        ("wagon", ["delivery cart", "train", "race car", "ambulance", "chariot", "fire truck", "mine cart", "covered wagon", "shopping cart", "moon buggy", "parade float", "popcorn cart", "farm cart", "ice cream cart", "mail cart"]),
        ("jump-rope", ["finish line", "river", "snake", "rope bridge", "fishing line", "fence", "lasso", "tightrope", "tow rope", "laser beam", "path", "boundary line", "circus ring", "leash", "starting line"]),
        ("hula-hoop", ["magic portal", "steering wheel", "pond", "life ring", "landing circle", "hoop gate", "circus ring", "lily pond", "landing pad", "time portal", "lasso", "fairy ring", "basketball hoop", "fire ring", "island"]),
        ("sidewalk-chalk", ["road lines", "magic wands", "space rocks", "carrots", "candles", "crystals", "gems", "dinosaur bones", "fossils", "chalk sticks", "paint sticks", "rocket fuel", "ice crystals", "gold nuggets", "magic crystals"]),
        ("plastic-cups", ["castle tower", "drums", "tea cups", "cones", "traffic cones", "flower pots", "towers", "bowling pins", "rocket tower", "lemonade cups", "potion cups", "space towers", "bells", "trophies", "stepping stones"]),
        ("sticky-notes", ["leaves", "spots", "buttons", "stars", "fish scales", "dragon scales", "snowflakes", "petals", "feathers", "bandages", "control buttons", "jewels", "flower petals", "puzzle pieces", "footprints"]),
    ]

    static let byID: [String: [String]] = Dictionary(uniqueKeysWithValues: table.map { ($0.id, $0.standIns) })

    /// The stand-ins of a library prop (empty for an item off the list).
    public static func standIns(_ id: String) -> [String] { byID[id] ?? [] }

    // MARK: Fuzzy match

    /// Words that don't identify a pretend thing ("the big magic wand" → wand).
    static let filler: Set<String> = ["the", "a", "an", "pretend", "big", "little", "small", "magic", "my", "your", "our",
                                      "giant", "tiny", "super", "special", "new", "old", "fancy", "cozy", "toy", "play"]

    static func words(_ s: String) -> [String] {
        s.lowercased().split { !$0.isLetter && $0 != "'" }.map { PrintedProps.singular(String($0)) }.filter { !filler.contains($0) }
    }

    /// The stand-in of `id` that `becomes` matches (same head noun, or one's head noun is a word of the other: "the
    /// captain's hat" ↔ "captain's hat", "the snack bowl" ↔ "snack bowl", "the pirate sail" ↔ "pirate sail"), or nil.
    /// An item off the list matches anything (nothing to check against).
    public static func match(_ id: String, _ becomes: String) -> String? {
        guard let list = byID[id] else { return KitDraft.cutoutLabel(becomes: becomes) }
        return list.first { same($0, becomes) }
    }

    static func same(_ standIn: String, _ becomes: String) -> Bool {
        let a = words(standIn), b = words(becomes)
        guard let ha = PropWords.headNoun(standIn), let hb = PropWords.headNoun(becomes), !a.isEmpty, !b.isEmpty else { return false }
        if ha == hb { return true }
        // A compound stand-in ("sock puppet") matches "puppet"; "the robot body" matches the stand-in "robot body".
        return (a.count > 1 && a.last == hb) || (b.count > 1 && b.last == ha)
    }

    public static func allows(_ id: String, _ becomes: String) -> Bool { match(id, becomes) != nil }

    /// The stand-in of `id` closest to `becomes`: one that needs the same kind of thing (`PropFit.need`), else one
    /// sharing a word, else its first stand-in.
    public static func closest(_ id: String, to becomes: String, avoidingUses: Set<String> = []) -> String? {
        let list = standIns(id).filter { !avoidingUses.contains(PropWords.useKey($0)) }
        guard !list.isEmpty else { return standIns(id).first }
        let need = PropFit.need(for: becomes)?.name
        if let need, let s = list.first(where: { PropFit.need(for: $0)?.name == need }) { return s }
        let w = Set(words(becomes))
        if let s = list.first(where: { !Set(words($0)).isDisjoint(with: w) }) { return s }
        return list[0]
    }

    /// Library props whose stand-ins include `becomes` (the game clearly needs that thing): the props that list it
    /// earliest first (a ball's first stand-in is the planet), then everyday things before toy-ish ones.
    public static func betterProps(for becomes: String) -> [String] {
        let order = PropFit.everydayFirst
        let hits = order.compactMap { id -> (String, Int)? in
            guard let k = byID[id]?.firstIndex(where: { same($0, becomes) }) else { return nil }
            return (id, k)
        }
        return hits.enumerated().sorted { ($0.element.1, $0.offset) < ($1.element.1, $1.offset) }.map(\.element.0)
    }

    // MARK: The hunt (no AI call)

    /// A hunt pair checked against the stand-ins. Nil = it's fine. Otherwise: a library prop whose stand-ins include
    /// the use (unused and `allowed`, e.g. on this game's shortlist) takes its place, keeping the use; else the prop
    /// keeps its item and becomes its closest stand-in (never a use already in the hunt).
    public static func settle(itemID: String, becomes: String, avoiding: Set<String>, avoidingUses: Set<String> = [],
                              allowed: (String) -> Bool = { _ in true }) -> (itemID: String, becomes: String)? {
        guard byID[itemID] != nil, match(itemID, becomes) == nil else { return nil }
        if let better = betterProps(for: becomes).first(where: { !avoiding.contains($0) && $0 != itemID && allowed($0) }) {
            return (better, becomes)
        }
        guard let s = closest(itemID, to: becomes, avoidingUses: avoidingUses) else { return nil }
        return (itemID, "the " + s)
    }

    // MARK: The guide's items (weave and setup)

    /// A setup / weave item for `prop`: when it turns the prop into something that is NOT on its list but on another
    /// prop's ("Hold up the planet" for a sock), that thing becomes the prop's own pretend name ("Hold up the snowball").
    public static func itemText(_ text: String, prop: Prop) -> String {
        let id = prop.libraryID ?? prop.id
        guard let mine = byID[id] else { return text }
        let label = KitDraft.cutoutLabel(becomes: prop.becomes).lowercased()
        if Bookends.mentions(text, name: label) || mine.contains(where: { Bookends.mentions(text, name: $0) }) { return text }
        let others = table.filter { $0.id != id }.flatMap(\.standIns).sorted { $0.count > $1.count }
        guard let wrong = others.first(where: { Bookends.mentions(text, name: $0) }) else { return text }
        let own = allows(id, prop.becomes) ? label : (closest(id, to: wrong) ?? label)
        return GuideWeave.replacing(text, phrase: wrong, with: own)
    }

    /// The prompt's note for one prop: "(it may only be: sock puppet, snake, tail, snowball, glove)".
    public static func promptNote(_ prop: Prop) -> String {
        let list = standIns(prop.libraryID ?? prop.id)
        return list.isEmpty ? "" : " (its ONLY allowed pretend uses: \(list.joined(separator: ", ")))"
    }

    // MARK: The review file (design/prop-stand-ins.md, kept in sync by a test)

    public static func markdown() -> String {
        var out = """
        # Prop stand-ins (for Haylee's review)

        Generated from `NutmegCore/Sources/NutmegCore/PropStandIns.swift` (a test fails when this file and the table differ;
        regenerate with `python3 tools/prop_stand_ins.py`). Each household prop may only become one of these pretend things
        (judged by shape and function for a 4 to 8 year old). Edit the Swift table, then regenerate.

        | Prop | Can become |
        |---|---|

        """
        for row in table {
            out += "| \(PropLibrary.name(row.id) ?? row.id) (`\(row.id)`) | \(row.standIns.joined(separator: ", ")) |\n"
        }
        return out
    }
}

// MARK: - Item wording (Haylee: "Hold up the planet", never "your sock pretend planet")

public enum PropWording {
    /// Setup / clean-up item wording: the pretend name only. "Hold up your sock pretend planet" → "Hold up the planet";
    /// "Put on the pretend crown" → "Put on the crown"; "Hold your sock as a puppet" → "Hold the puppet". Idempotent.
    public static func clean(_ text: String, props: [Prop]) -> String {
        var t = text
        for p in props {
            for name in Set([p.householdItem.lowercased(), p.itemWords.lowercased()]) where !name.isEmpty {
                let n = NSRegularExpression.escapedPattern(for: name)
                t = t.replacingOccurrences(of: #"(?i)\b(?:your|the|a|an|my|our)\s+"# + n + #"\s+(?:pretend\s+|as\s+(?:a|an|the|your)\s+)"#,
                                           with: "the ", options: .regularExpression)
                t = t.replacingOccurrences(of: #"(?i)\b"# + n + #"\s+pretend\s+"#, with: "", options: .regularExpression)
            }
        }
        t = t.replacingOccurrences(of: #"(?i)\b(your|the|a|an|my|our)\s+pretend\s+"#, with: "the ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return t
    }
}
