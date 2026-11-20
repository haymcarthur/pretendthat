import Foundation

// 2026-11-21 (Haylee, decisions/2026-11-21-events-are-scenarios-and-ownership.md): a sock became "a planet" in a live
// game. Instead of one more rule per bad pairing, every library prop gets a short list of believable pretend things it
// can become, judged by shape and function for a 4 to 8 year old. The hunt, the guide's weave and the setup items may
// only turn a prop into one of its stand-ins; the app repairs anything else with no AI call (`settle`, `itemText`).
// Haylee reviews the list in design/prop-stand-ins.md (kept in sync by a test: `PropStandInsTests`).

public enum PropStandIns {
    /// Library id → 3 to 6 pretend things it can become (Claude's list, for Haylee's review). Includes every curated
    /// use in `PropLibrary.uses` (tested), so the app's own fallback pairs always pass.
    public static let table: [(id: String, standIns: [String])] = [
        ("stuffed-animal", ["patient", "pet", "baby animal", "passenger", "sidekick", "customer"]),
        ("chair", ["airplane seat", "driver's seat", "throne", "train seat", "ship's seat", "cockpit seat"]),
        ("table", ["shop counter", "cave", "desk", "stage", "bridge", "control desk"]),
        ("couch", ["boat", "bus", "spaceship", "island", "train", "sofa fort"]),
        ("pillow", ["shield", "cloud", "boulder", "bed", "seat cushion", "marshmallow"]),
        ("blanket", ["ocean", "superhero cape", "tent", "lava", "magic carpet", "snowy field"]),
        ("rug", ["island", "stage", "magic carpet", "landing pad", "pond", "dance floor"]),
        ("cardboard-box", ["rocket ship", "treasure chest", "big oven", "car", "fort", "robot body"]),
        ("plate", ["steering wheel", "pizza", "dish", "flying saucer", "shield", "clock"]),
        ("cup", ["magic potion", "tea cup", "mug", "goblet", "drum"]),
        ("bowl", ["captain's hat", "mixing bowl", "treasure bowl", "snack bowl", "helmet", "nest"]),
        ("tray", ["snack cart", "serving tray", "control panel", "shield", "treat tray", "display tray"]),
        ("spoon", ["magic wand", "big stirrer", "microphone", "oar", "scoop"]),
        ("pot", ["knight's helmet", "soup pot", "cauldron", "drum", "treasure pot"]),
        ("towel", ["superhero cape", "magic carpet", "blanket", "drying cloth", "river", "sail"]),
        ("laundry-basket", ["boat", "cage", "cockpit", "nest", "race car", "treasure cart"]),
        ("books", ["castle wall", "ramp", "wall", "bricks", "control panel", "stepping stones"]),
        ("hat", ["captain's hat", "chef's hat", "conductor's cap", "pilot cap", "wizard hat", "cowboy hat"]),
        ("bag", ["treasure bag", "mailbag", "shopping bag", "doctor's bag", "picnic bag", "loot sack"]),
        ("backpack", ["jet pack", "carry-on bag", "explorer pack", "air tank", "rescue pack", "school bag"]),
        ("toy-car", ["delivery truck", "race car", "police car", "fire truck", "taxi", "ambulance"]),
        ("flashlight", ["lighthouse light", "spyglass", "searchlight", "torch", "laser beam", "headlight"]),
        ("broom", ["ship's mast", "horse", "witch's broom", "flagpole", "sweeper"]),
        ("teddy-bed", ["pet bed", "baby crib", "nest", "hospital bed", "dragon nest"]),
        ("cushion", ["throne", "stepping stone", "seat", "cloud", "lily pad", "raft"]),
        ("stool", ["stage", "lookout tower", "podium", "throne", "step", "counter"]),
        ("sheet", ["pirate sail", "tent", "ghost costume", "cape", "ocean", "fort roof"]),
        ("basket", ["treasure chest", "picnic basket", "nest", "shopping basket", "egg basket", "fruit basket"]),
        ("bucket", ["treasure bucket", "drum", "helmet", "well", "water bucket", "sand bucket"]),
        ("paper-towel-tube", ["telescope", "microphone", "magic wand", "spyglass", "megaphone", "baton"]),
        ("paper-bag", ["treasure sack", "mailbag", "lunch bag", "puppet", "shopping bag"]),
        ("egg-carton", ["jewel box", "cupcake box", "egg box", "seed tray", "control panel", "paint palette"]),
        ("crayons", ["magic wands", "paint brushes", "candles on a cake", "rocket fuel sticks", "carrots"]),
        ("tape", ["finish line", "road lines", "path", "start line", "boundary line", "runway"]),
        ("paper-plate", ["steering wheel", "pizza", "flying saucer", "clock", "pie", "shield"]),
        ("plastic-container", ["treasure chest", "lunch box", "first aid kit", "toolbox", "cash box", "fish tank"]),
        ("measuring-cup", ["magic potion", "watering jug", "pitcher", "scoop", "tea pot"]),
        ("colander", ["space helmet", "knight's helmet", "strainer", "lamp shade", "crown"]),
        ("baking-sheet", ["steering wheel", "serving tray", "knight's shield", "control panel", "cookie sheet", "sled"]),
        ("wooden-spoon", ["magic wand", "microphone", "big stirrer", "oar", "conductor's baton"]),
        ("apron", ["chef's apron", "superhero cape", "doctor's coat", "painter's smock", "tool belt"]),
        ("oven-mitt", ["chef's glove", "astronaut glove", "puppet", "dragon claw", "boxing glove"]),
        ("ball", ["planet", "moon", "giant snowball", "egg", "pumpkin", "cannonball"]),
        ("scarf", ["royal sash", "river", "tail", "snake", "rope bridge", "cape"]),
        ("sunglasses", ["spy glasses", "space goggles", "superhero mask", "diving goggles", "movie star glasses"]),
        ("sneakers", ["jet boots", "space boots", "rocket shoes", "hiking boots", "running shoes"]),
        ("headband", ["crown", "tiara", "halo", "headset", "flower crown"]),
        ("sock", ["sock puppet", "puppet", "snake", "tail", "snowball", "glove"]),
        ("mittens", ["polar gloves", "boxing gloves", "puppets", "bear paws", "snow gloves"]),
        ("umbrella", ["walking cane", "magic wand", "flagpole", "fishing rod", "hiking stick"]),
        ("pillowcase", ["treasure sack", "superhero cape", "treasure bag", "sleeping bag", "loot sack", "mailbag"]),
        ("toy-keys", ["magic keys", "castle keys", "car keys", "jail keys", "treasure keys"]),
        ("wagon", ["delivery cart", "train", "race car", "ambulance", "chariot", "fire truck"]),
        ("jump-rope", ["finish line", "river", "snake", "rope bridge", "fishing line", "fence"]),
        ("hula-hoop", ["magic portal", "steering wheel", "pond", "life ring", "landing circle", "hoop gate"]),
        ("sidewalk-chalk", ["road lines", "magic wands", "space rocks", "carrots", "candles"]),
        ("plastic-cups", ["castle tower", "drums", "tea cups", "cones", "traffic cones", "flower pots"]),
        ("sticky-notes", ["leaves", "spots", "buttons", "stars", "fish scales", "dragon scales"]),
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

    /// Library props (everyday first) whose stand-ins include `becomes`: the game clearly needs that thing.
    public static func betterProps(for becomes: String) -> [String] {
        PropFit.everydayFirst.filter { id in byID[id]?.contains { same($0, becomes) } ?? false }
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
