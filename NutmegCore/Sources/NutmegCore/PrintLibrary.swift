import Foundation

// Round 45 (Haylee, decisions/2026-11-17-printables-library.md; research/2026-11-17-printables-library.md):
// - The art is a PICTURE ONLY: no words, frames, banners or blank boxes in any image. The app draws the card, its border,
//   the Name line, the role title and every word in its own space beside the picture, never on top of it.
// - A library of 17 printable types (the original 6 reworked + 11 new). A kit picks 4 to 6 of them for its game, from a
//   set shortlist per suggested game (`PrintShortlist`); badges are in every kit, no sign when the game has no place.
// - Common types have 2 or 3 app-drawn layout variants, picked by the game's family and turned away from the last 3
//   games' variants (`PrintVariants`, `RecentPrintMemory`: type.variant ids only, nothing about kids).
// - One picture per printable (Haylee's answer 2): each printable gets ONE image call: a single picture (a sign's
//   place, a map, a bill's emblem), or one SHEET of small pictures the app slices (a menu's dishes, clue cards, medals).
//   Badges are the 6-up character sheet (characters only), cut-outs the cut-out sheet, as before. The decoder needs none.

/// An app-drawn layout of a printable (round 45). Free: the app draws them all, the art is the same picture.
public enum KitVariant: String, Codable, Sendable, CaseIterable {
    case lanyard, pin, idCard              // badges
    case door, banner, marquee             // sign
    case bills, coins, tokens              // money
    case boarding, admission, keycard      // tickets
    case menuCard, chalkboard, program     // menu
    case ruled, chart                      // log
    case standard                          // every other type (one layout)

    /// What a grown-up would call it (logs, tests).
    public var name: String {
        switch self {
        case .lanyard: "lanyard tag"; case .pin: "round pin"; case .idCard: "ID card"
        case .door: "door sign"; case .banner: "hanging banner"; case .marquee: "marquee"
        case .bills: "bills"; case .coins: "coins"; case .tokens: "tokens"
        case .boarding: "boarding pass"; case .admission: "admission ticket"; case .keycard: "keycard"
        case .menuCard: "menu card"; case .chalkboard: "board"; case .program: "show program"
        case .ruled: "ruled log"; case .chart: "tick chart"; case .standard: "standard"
        }
    }
}

extension KitRecipe {
    /// The layouts this type can print in (the first is its plain default).
    public var variants: [KitVariant] {
        switch self {
        case .badges: [.lanyard, .pin, .idCard]
        case .sign: [.door, .banner, .marquee]
        case .money: [.bills, .coins, .tokens]
        case .tickets: [.boarding, .admission, .keycard]
        case .menu: [.menuCard, .chalkboard, .program]
        case .log: [.ruled, .chart]
        default: [.standard]
        }
    }
    /// What it's called when spoken ("the clue cards"), for labels and logs.
    public var spokenName: String {
        switch self {
        case .badges: "badges"; case .sign: "sign"; case .money: "money"; case .tickets: "tickets"; case .menu: "menu"
        case .cutouts: "cut-outs"; case .orderSlips: "order slips"; case .map: "map"; case .clueCards: "clue cards"
        case .missionCards: "mission cards"; case .log: "log"; case .medals: "medals"; case .stickers: "stickers"
        case .passport: "passport"; case .labels: "labels"; case .decoder: "code decoder"; case .controlPanel: "control panel"
        }
    }
}

/// What a printable's art is (one image call per printable at most, per style).
public enum PrintArt: Equatable, Sendable {
    /// Nothing to draw: the app draws it all (the code decoder).
    case none
    /// ONE picture at this API size.
    case single(size: String)
    /// ONE sheet of `count` small pictures, sliced by the app (a menu's dishes, the clue cards' hints).
    case sheet(count: Int)
    /// The 6-up character sheet (badges): one character per ranked role.
    case characters
    /// The cut-out sheet (unchanged: `KitArtPrompt.cutoutSheetPrompt`, skipped props' cut-outs one each).
    case cutouts
}

public enum PrintLibrary {
    /// Most pictures on one sheet (the slicer's 3 × 2 grid).
    public static let maxSheetPictures = 6
    /// Round 45 (cost): at most this many image calls per style for the pages written at the roles (today's fixed kit
    /// was 6 a style). Skipped props' cut-outs are extra, as before.
    public static let imageBudgetPerStyle = 6
    /// A kit has 4 to 6 printables (badges always first).
    public static let minItems = 4, maxItems = 6

    // MARK: What each type is (the kit prompt)

    public static func guide(_ t: KitRecipe) -> String {
        switch t {
        case .badges: return "role badges, one per kid, everyone wears one (the app prints each role's title and a blank Name line, and draws each role's character); title = the team's name; lines and pictures: none"
        case .sign: return "a sign to hang up with the PLACE's name (title, e.g. \"Cozy Café\"), lines = 1 short tagline (\"Now open!\"); pictures = ONE picture of the place. Only for a game with a place"
        case .money: return "play money, every piece worth $1 (bills, coins or tokens); title = the money's name (\"Sea Bucks\"); lines: none; pictures = ONE emblem (\"a seashell\")"
        case .tickets: return "tickets or passes (boarding passes, admission tickets, room keycards, appointment cards), every copy numbered by the app; title (\"Boarding Pass\"), lines = 1 short line (\"Flight to the Moon\"); pictures = ONE small picture"
        case .menu: return "a menu, price list or show program to choose from; lines = 3 to 6 entries, each a thing and a whole-dollar price from $1 to $5 (\"Pancakes $3\"), or for a show an act with no price (\"Juggling Bears\"); pictures = one per line, same order"
        case .cutouts: return "a page of 6 themed prop cut-outs to cut out and use as pretend things; lines = the 6 things (each is drawn as its own picture); pictures: none"
        case .orderSlips: return "order slips: a waiter ticks what a customer wants, the cook makes it (the app prints Table __ and a tick box by each picture); lines = 3 or 4 things to order, 1 or 2 words; pictures = one per line"
        case .map: return "a map to follow (treasure map, trail, dig site, blueprint, route); lines = 3 or 4 stops in order, 1 to 3 words each (\"Big Rock\"), real spots the kids set up in the room; pictures = ONE map picture of the place seen from above"
        case .clueCards: return "clue cards to hide and find, numbered by the app; lines = 4 to 6 clues, 3 to 6 easy words each, each pointing to a spot in the room or a found prop (\"Look under something soft\"); pictures = one picture hint per clue (\"a pillow\"). Nutmeg reads each clue out loud"
        case .missionCards: return "mission or job cards to draw and do (rescues, quests, work orders, recipes, lessons); lines = 4 to 6 missions, 2 to 5 words each (\"Rescue the kitten\"); pictures = one per mission. Nutmeg reads each out loud"
        case .log: return "a log or chart sheet to tick or write on (captain's log, patient chart, chore chart, spotted list); lines = 3 to 6 rows to tick or fill in, 1 to 3 words each (\"Ate breakfast\"); pictures = ONE small header picture"
        case .medals: return "medals given at the end of a scene; lines = 2 to 6 award titles, 2 or 3 words each (\"Bravest Pirate\"); pictures = one per award"
        case .stickers: return "small stickers or stamps (reward a patient, stamp a book); lines = 2 to 6 tiny words (\"Brave!\", \"Visited\"); pictures = one per sticker"
        case .passport: return "a passport booklet that folds, with one stamp box per stop; lines = 3 to 6 stop names, 1 to 3 words each; pictures = ONE cover picture"
        case .labels: return "labels and tags (price tags, animal signs, address labels, book labels, caution tags); lines = 4 to 6 short tag words or prices (\"Apples $2\"); pictures = one per tag"
        case .decoder: return "a code decoder: the app draws picture symbols for letters and the secret words in symbols, kids decode them; lines = 2 or 3 secret words in CAPITALS, at most 10 letters each (\"LOOK UP\"); pictures: none"
        case .controlPanel: return "a control panel to press and turn (spaceship, truck, submarine, weather board, cockpit, hero HQ); lines = 4 to 6 button names, 1 or 2 words (\"Launch\", \"Lights\"); pictures = ONE picture for its window or screen (the view outside)"
        }
    }

    /// The verbs that make a real job for it in a scene (the prompt's "every pick has a job").
    public static func verbs(_ t: KitRecipe) -> String {
        switch t {
        case .badges: "wear"; case .sign: "hang"; case .money: "pay, count, give change"; case .tickets: "show, punch, check"
        case .menu: "choose, order"; case .cutouts: "cut out, hold, serve, use"; case .orderSlips: "tick, take an order, cook from"
        case .map: "follow, mark"; case .clueCards: "hide, find, read"; case .missionCards: "draw, do, tick done"
        case .log: "tick, write"; case .medals: "give, award"; case .stickers: "stick, reward"; case .passport: "stamp, show"
        case .labels: "tag, stick on"; case .decoder: "decode"; case .controlPanel: "press, turn, steer"
        }
    }

    /// Head nouns that name this type's printed thing (singular): a task naming one uses the page; a prop may never be
    /// one of THIS kit's printed things (`PrintedProps.kitNouns`).
    public static func nouns(_ t: KitRecipe) -> [String] {
        switch t {
        case .badges: ["badge", "name tag", "id card"]
        case .sign: ["sign", "banner"]
        case .money: ["money", "buck", "dollar", "bill", "coin", "cash", "token"]
        case .tickets: ["ticket", "pass", "boarding pass", "keycard", "card"]
        case .menu: ["menu", "price list", "program"]
        case .cutouts: ["cut-out", "cutout", "cut out"]
        case .orderSlips: ["order slip", "slip", "order"]
        case .map: ["map", "blueprint"]
        case .clueCards: ["clue card", "clue"]
        case .missionCards: ["mission card", "mission", "job card", "card"]
        case .log: ["log", "logbook", "chart", "list", "notes", "journal"]
        case .medals: ["medal", "award", "ribbon"]
        case .stickers: ["sticker", "stamp"]
        case .passport: ["passport", "booklet"]
        case .labels: ["label", "tag", "price tag"]
        case .decoder: ["decoder", "code", "secret code", "secret message"]
        case .controlPanel: ["control panel", "panel", "dashboard", "controls", "button"]
        }
    }

    /// How many lines (entries) each type keeps, and the most words a line may have (picture-first, few words).
    public static func lineLimits(_ t: KitRecipe) -> (count: ClosedRange<Int>, words: Int) {
        switch t {
        case .badges: (0...1, 4)
        case .sign: (0...3, 5)
        case .money: (0...1, 5)
        case .tickets: (0...2, 5)
        case .menu: (1...6, 5)
        case .cutouts: (1...8, 4)
        case .orderSlips: (1...4, 3)
        case .map: (1...4, 3)
        case .clueCards: (1...6, 6)
        case .missionCards: (1...6, 5)
        case .log: (1...6, 4)
        case .medals: (1...6, 3)
        case .stickers: (1...6, 2)
        case .passport: (1...6, 3)
        case .labels: (1...6, 3)
        case .decoder: (1...3, 3)
        case .controlPanel: (1...6, 2)
        }
    }

    // MARK: The art

    /// What one printable's art is. `roles`: the game's 6 ranked roles (the badge sheet draws one character each).
    public static func art(_ item: KitItem, roles: [Role] = []) -> PrintArt {
        guard let t = item.recipe else { return .single(size: KitArtPrompt.size(for: item)) }
        switch t {
        case .badges: return roles.count == BadgeSheet.count ? .characters : .single(size: "1024x1024")
        case .cutouts: return .cutouts
        case .decoder: return .none
        case .sign, .controlPanel: return .single(size: "1536x1024")
        case .money, .tickets, .map, .log, .passport: return .single(size: "1024x1024")
        case .menu, .orderSlips, .clueCards, .missionCards, .medals, .stickers, .labels:
            let n = subjects(item).count
            return n >= 2 ? .sheet(count: n) : .single(size: "1024x1024")
        }
    }

    /// Whether a type's pictures are a sheet (one per entry) rather than one picture.
    public static func perEntryPictures(_ t: KitRecipe) -> Bool {
        [.menu, .orderSlips, .clueCards, .missionCards, .medals, .stickers, .labels].contains(t)
    }

    /// What is drawn: the item's own pictures, else one subject per entry (its line without the price), else its title.
    /// A per-entry type has one subject per line (at most `maxSheetPictures`); any other type exactly one.
    public static func subjects(_ item: KitItem) -> [String] {
        let pics = (item.pictures ?? []).map(clean).filter { !$0.isEmpty }
        let t = item.recipe
        if let t, perEntryPictures(t) {
            let entries = item.lines.map { clean(Money.withoutPrice($0)) }.filter { !$0.isEmpty }
            let n = min(maxSheetPictures, entries.isEmpty ? pics.count : entries.count)
            guard n > 0 else { return [clean(item.title)].filter { !$0.isEmpty } }
            return (0..<n).map { i in pics.indices.contains(i) ? pics[i] : entries[i] }
        }
        if let first = pics.first { return [first] }
        let title = clean(item.title)
        return title.isEmpty ? [] : [title]
    }

    static func clean(_ s: String) -> String {
        let s = Money.withoutPrice(s)
        return s.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!,;:")))
    }

    // MARK: Layout (pages)

    /// The grid of copies on its page (the app-drawn layout of each type and variant).
    public static func grid(_ t: KitRecipe, _ v: KitVariant?) -> KitLayout.Grid {
        switch t {
        case .badges: return v == .idCard ? .init(columns: 2, rows: 3) : .init(columns: 3, rows: 2)
        case .money: return v == .bills || v == nil ? .init(columns: 2, rows: 4) : .init(columns: 3, rows: 4)
        case .tickets, .orderSlips: return .init(columns: 2, rows: 4)
        case .clueCards, .missionCards, .medals: return .init(columns: 2, rows: 3)
        case .stickers: return .init(columns: 4, rows: 5)
        case .labels: return .init(columns: 3, rows: 4)
        case .sign, .menu, .cutouts, .map, .log, .passport, .decoder, .controlPanel: return .init(columns: 1, rows: 1)
        }
    }

    /// How many copies a page prints (cards fill their page; per-entry cards print each entry once, then repeat).
    public static func copies(_ item: KitItem) -> Int {
        guard let t = item.recipe else { return item.copies }
        let cap = grid(t, item.variant).capacity
        switch t {
        case .badges, .tickets: return 1   // per kid (`KitLayout.pages`: one badge each; tickets fill their page)
        case .clueCards, .missionCards: return max(1, min(cap, item.lines.count))
        default: return cap
        }
    }

    // MARK: Words on cards (the app draws them)

    /// The per-copy number the app prints on a ticket (each copy its own: seats 1A 1B …, No. 001 …, Room 101 …),
    /// a clue or mission card (1, 2, 3 …), an order slip (No. 1 …). Nil for other types.
    public static func copyNumber(_ item: KitItem, index i: Int) -> String? {
        guard item.pictureOnly, let t = item.recipe else { return nil }
        switch t {
        case .tickets:
            switch item.variant {
            case .boarding?: return "\(i / 4 + 1)\(["A", "B", "C", "D"][i % 4])"
            case .keycard?: return "\(101 + i)"
            default: return String(format: "%03d", i + 1)
            }
        case .clueCards, .missionCards, .orderSlips: return "\(i + 1)"
        default: return nil
        }
    }
}

// MARK: - The shortlist per game (Haylee's answer 5)

/// A game family: picks each layout's default (workplaces get the lanyard tag, crews the ID card, adventures the pin…).
public enum GameFamily: String, Sendable, CaseIterable {
    case food, shop, care, service, travel, show, attraction, adventure, crew, other
}

/// The set shortlist of printables for one suggested game (research/2026-11-17-printables-library.md §3). Claude picks
/// 4 to 6 from it and may swap in up to 2 other types for the theme twist; a made-up game picks from the whole library.
public struct PrintGame: Sendable, Equatable {
    public let id: String
    /// Words that pick this game out of what the kids said (one word, or a phrase whose words must all be there).
    public let keywords: [String]
    public let types: [KitRecipe]
    public let family: GameFamily
    /// The game has a PLACE to name on a sign (false: treasure hunt, spy mission, mail route…: no sign).
    public let place: Bool
    /// Layouts this game prefers (first per type wins), e.g. a vet's tickets are appointment keycards.
    public let prefer: [KitVariant]
    init(_ id: String, _ keywords: [String], _ types: [KitRecipe], _ family: GameFamily, place: Bool = true, prefer: [KitVariant] = []) {
        self.id = id; self.keywords = keywords; self.types = types; self.family = family; self.place = place; self.prefer = prefer
    }
}

public enum PrintShortlist {
    /// Every suggested game (`Suggestions.games`) plus spy and superheroes (they come up often). Order matters: the
    /// first game whose keyword matches wins, so the specific ones come first ("ice cream truck" before "truck").
    public static let games: [PrintGame] = [
        .init("ice-cream-truck", ["ice cream", "icecream", "ice-cream"], [.badges, .sign, .menu, .orderSlips, .money, .cutouts], .food, prefer: [.chalkboard]),
        .init("pet-groomer", ["groomer", "grooming", "pet salon"], [.badges, .sign, .tickets, .menu, .money, .cutouts], .care, prefer: [.keycard, .chalkboard]),
        .init("cooking-show", ["cooking show", "cooking", "chef show", "bake off"], [.badges, .sign, .missionCards, .menu, .medals, .cutouts], .show, prefer: [.marquee, .program]),
        .init("tea-party", ["tea party", "tea"], [.badges, .sign, .menu, .labels, .medals, .cutouts], .food, prefer: [.menuCard]),
        .init("treasure-hunt", ["treasure hunt", "treasure", "scavenger"], [.badges, .map, .clueCards, .money, .log, .cutouts], .adventure, place: false, prefer: [.pin, .coins, .ruled]),
        .init("lemonade-stand", ["lemonade"], [.badges, .sign, .menu, .money, .orderSlips, .cutouts], .food, prefer: [.chalkboard]),
        .init("car-wash", ["car wash", "carwash"], [.badges, .sign, .menu, .tickets, .money, .cutouts], .shop, prefer: [.chalkboard, .admission]),
        .init("flower-shop", ["flower", "florist", "flowers"], [.badges, .sign, .labels, .money, .cutouts], .shop),
        .init("toy-shop", ["toy shop", "toy store", "toyshop", "toys"], [.badges, .sign, .labels, .money, .cutouts], .shop),
        .init("hair-salon", ["salon", "hair", "barber", "hairdresser", "beauty"], [.badges, .sign, .tickets, .menu, .money, .cutouts], .care, prefer: [.keycard, .chalkboard]),
        .init("pizza", ["pizza", "pizzeria"], [.badges, .sign, .menu, .orderSlips, .money, .cutouts], .food),
        .init("bakery", ["bakery", "baker", "cake", "cupcake", "donut", "cookie shop"], [.badges, .sign, .menu, .orderSlips, .money, .cutouts], .food),
        .init("restaurant", ["restaurant", "cafe", "café", "diner", "waiter", "dinner", "food truck", "kitchen"], [.badges, .sign, .menu, .orderSlips, .money, .cutouts], .food),
        .init("vet", ["vet", "veterinarian", "animal doctor", "pet clinic", "animal hospital", "pet doctor"], [.badges, .sign, .tickets, .log, .cutouts, .stickers], .care, prefer: [.keycard, .chart]),
        .init("doctor", ["doctor", "hospital", "nurse", "clinic", "dentist"], [.badges, .sign, .tickets, .log, .stickers, .cutouts], .care, prefer: [.keycard, .chart]),
        .init("airplane", ["airplane", "plane", "airport", "flight", "pilot", "airline", "jet"], [.badges, .sign, .tickets, .passport, .menu, .cutouts], .travel, prefer: [.idCard, .boarding]),
        .init("train", ["train", "railway", "railroad", "conductor"], [.badges, .sign, .tickets, .passport, .menu, .money], .travel, prefer: [.idCard, .boarding]),
        .init("bus", ["bus"], [.badges, .sign, .tickets, .map, .passport, .money], .travel, prefer: [.boarding]),
        .init("rocket", ["rocket", "launch", "blast off", "countdown"], [.badges, .controlPanel, .missionCards, .log, .passport, .cutouts], .crew, place: false, prefer: [.idCard, .ruled]),
        .init("space-station", ["space station", "astronaut", "spaceship", "space ship", "space", "alien"], [.badges, .sign, .controlPanel, .missionCards, .log, .cutouts], .crew, prefer: [.idCard, .ruled]),
        .init("submarine", ["submarine", "sub"], [.badges, .controlPanel, .map, .log, .labels, .cutouts], .crew, place: false, prefer: [.idCard, .ruled]),
        .init("pirate-ship", ["pirate", "pirates", "ship"], [.badges, .sign, .map, .money, .log, .cutouts], .adventure, prefer: [.pin, .banner, .coins, .ruled]),
        .init("post-office", ["post office", "postal", "post"], [.badges, .sign, .labels, .stickers, .money, .cutouts], .service),
        .init("mail-carrier", ["mail", "mailman", "mail carrier", "postman", "delivery", "letters"], [.badges, .labels, .stickers, .map, .log, .cutouts], .service, place: false),
        .init("grocery", ["grocery", "supermarket", "market", "store", "shop"], [.badges, .sign, .labels, .money, .log, .cutouts], .shop, prefer: [.chart]),
        .init("firefighters", ["firefighter", "firefighters", "fire station", "fire truck", "firetruck", "fireman"], [.badges, .sign, .missionCards, .controlPanel, .medals, .cutouts], .adventure, prefer: [.pin]),
        .init("library", ["library", "librarian", "books"], [.badges, .sign, .tickets, .labels, .stickers, .log], .service, prefer: [.keycard, .chart]),
        .init("dinosaur-dig", ["dinosaur", "dinosaurs", "dino", "fossil", "fossils", "paleontologist"], [.badges, .map, .log, .labels, .medals, .cutouts], .adventure, place: false, prefer: [.pin, .chart]),
        .init("camping", ["camping", "camp", "campfire", "tent", "hike", "hiking"], [.badges, .map, .missionCards, .log, .medals, .cutouts], .adventure, place: false, prefer: [.pin, .chart]),
        .init("zoo", ["zoo", "zookeeper", "safari"], [.badges, .sign, .tickets, .map, .labels, .passport], .attraction, prefer: [.admission]),
        .init("museum", ["museum", "gallery"], [.badges, .sign, .tickets, .map, .labels, .passport], .attraction, prefer: [.admission]),
        .init("school", ["school", "teacher", "classroom", "class"], [.badges, .sign, .log, .missionCards, .medals, .stickers], .service, prefer: [.pin, .chart]),
        .init("farm", ["farm", "farmer", "barn"], [.badges, .sign, .labels, .log, .money, .cutouts], .shop, prefer: [.chart]),
        .init("detective", ["detective", "mystery", "sleuth", "clues", "case"], [.badges, .clueCards, .decoder, .log, .map, .cutouts], .crew, place: false, prefer: [.idCard, .ruled]),
        .init("spy", ["spy", "spies", "secret agent", "agent", "secret mission"], [.badges, .decoder, .missionCards, .menu, .money, .clueCards], .crew, place: false, prefer: [.idCard, .menuCard]),
        .init("superheroes", ["superhero", "superheroes", "hero", "heroes"], [.badges, .missionCards, .controlPanel, .medals, .log, .cutouts], .adventure, place: false, prefer: [.idCard, .ruled]),
        .init("construction", ["construction", "builder", "builders", "building site", "digger", "bulldozer"], [.badges, .sign, .missionCards, .map, .labels, .cutouts], .crew, prefer: [.pin]),
        .init("circus", ["circus", "clown", "ringmaster", "acrobat"], [.badges, .sign, .tickets, .menu, .medals, .money], .show, prefer: [.pin, .marquee, .admission, .program, .tokens]),
        .init("puppet-show", ["puppet", "puppets", "theater", "theatre"], [.badges, .sign, .tickets, .menu, .money, .cutouts], .show, prefer: [.marquee, .admission, .program, .tokens]),
        .init("orchestra", ["marching band", "band", "parade", "orchestra", "concert"], [.badges, .sign, .menu, .tickets, .medals, .cutouts], .show, prefer: [.banner, .program, .admission]),
        .init("hotel", ["hotel", "inn", "motel", "resort"], [.badges, .sign, .tickets, .menu, .labels, .money], .service, prefer: [.keycard, .menuCard]),
        .init("knights-castle", ["knight", "knights", "castle", "king", "queen", "princess", "prince", "royal"], [.badges, .sign, .missionCards, .money, .medals, .cutouts], .adventure, prefer: [.pin, .banner, .coins]),
        .init("bird-watchers", ["bird", "birds", "birdwatching", "bird-watching", "binoculars"], [.badges, .log, .map, .labels, .medals, .cutouts], .adventure, place: false, prefer: [.chart]),
        .init("weather-station", ["weather", "forecast", "meteorologist", "storm"], [.badges, .controlPanel, .missionCards, .log, .cutouts], .crew, place: false, prefer: [.idCard, .chart]),
    ]

    /// The suggested game the kids' words name (the game type from set_game first, then the themed title), or nil for
    /// a made-up game.
    public static func game(for texts: [String?]) -> PrintGame? {
        for t in texts.compactMap({ $0 }) where !t.trimmingCharacters(in: .whitespaces).isEmpty {
            let words = tokens(t)
            // The game named FIRST wins ("Pirates in Space" is a pirate game), then the table order.
            var best: (game: PrintGame, at: Int)?
            for g in games {
                guard let at = g.keywords.compactMap({ position($0, words) }).min() else { continue }
                if best == nil || at < best!.at { best = (g, at) }
            }
            if let best { return best.game }
        }
        return nil
    }

    public static func game(id: String) -> PrintGame? { games.first { $0.id == id } }

    static func tokens(_ s: String) -> [String] {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
    /// Where a keyword starts in the text's words (all of its words in a row; a plural "s" allowed), or nil.
    static func position(_ keyword: String, _ words: [String]) -> Int? {
        let ks = tokens(keyword)
        guard !ks.isEmpty, words.count >= ks.count else { return nil }
        func same(_ w: String, _ k: String) -> Bool { w == k || (w.count > 3 && w.hasSuffix("s") && String(w.dropLast()) == k) }
        for i in 0...(words.count - ks.count) where ks.indices.allSatisfy({ same(words[i + $0], ks[$0]) }) { return i }
        return nil
    }
}

// MARK: - Layout variants (app-picked, rotated)

/// Remembers the layouts of the last few kits (UserDefaults; "type.variant" ids only, nothing about kids), so two
/// games of the same kind look different.
public struct RecentPrintMemory: @unchecked Sendable {
    let defaults: UserDefaults
    static let key = "pt.recentPrintVariants"
    /// How many past games are remembered (Haylee: avoid the last 2 to 3 games' variants).
    public static let gameCount = 3
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    /// The remembered games, newest first: each a list of "type.variant" ids.
    public var games: [[String]] { (defaults.array(forKey: Self.key) as? [[String]]) ?? [] }
    /// Remembers one kit's layouts (only the types that have a choice).
    public func record(_ items: [KitItem]) {
        let ids = PrintVariants.ids(items)
        guard !ids.isEmpty else { return }
        defaults.set(Array(([ids] + games).prefix(Self.gameCount)), forKey: Self.key)
    }
    public func clear() { defaults.removeObject(forKey: Self.key) }
}

public enum PrintVariants {
    /// "badges.pin", "sign.door" … for the types with more than one layout.
    public static func ids(_ items: [KitItem]) -> [String] {
        items.compactMap { i in
            guard let t = i.recipe, let v = i.variant, t.variants.count > 1 else { return nil }
            return "\(t.rawValue).\(v.rawValue)"
        }
    }

    /// The family default first, then the others. A game's own preferences win.
    public static func ordered(_ t: KitRecipe, family: GameFamily, prefer: [KitVariant]) -> [KitVariant] {
        let all = t.variants
        var first: [KitVariant] = prefer.filter(all.contains)
        switch t {
        case .badges:
            switch family {
            case .crew, .travel: first.append(.idCard)
            case .adventure, .show: first.append(.pin)
            default: first.append(.lanyard)
            }
        case .sign: first.append(family == .show ? .marquee : family == .adventure ? .banner : .door)
        case .money: first.append(family == .adventure ? .coins : family == .show ? .tokens : .bills)
        case .menu: first.append(family == .show ? .program : .menuCard)
        case .log: first.append([.care, .service, .shop].contains(family) ? .chart : .ruled)
        default: break
        }
        var seen = Set<KitVariant>()
        return (first + all).filter { seen.insert($0).inserted }
    }

    /// The layouts that fit THIS item (a ticket called "Boarding Pass" is a boarding pass; a show's list is a program).
    public static func allowed(_ item: KitItem, family: GameFamily) -> [KitVariant] {
        guard let t = item.recipe else { return [] }
        let words = Set(PrintShortlist.tokens(item.title + " " + item.lines.joined(separator: " ")))
        func has(_ ws: [String]) -> Bool { ws.contains { words.contains($0) } }
        switch t {
        case .tickets:
            if has(["boarding", "flight", "seat", "train", "bus", "trip", "ride", "cruise"]) { return [.boarding] }
            if has(["key", "keycard", "room", "appointment", "visit", "card", "library", "checkup"]) { return [.keycard] }
            if has(["admit", "admission", "entry", "entrance", "show", "ticket"]) {
                return family == .travel ? [.boarding, .admission] : [.admission]
            }
            switch family {
            case .travel: return [.boarding, .admission]
            case .care, .service: return [.keycard]
            case .show, .attraction: return [.admission]
            default: return [.admission, .keycard]
            }
        case .menu:
            let priced = item.lines.contains { !Money.amounts($0).isEmpty }
            if family == .show || has(["program", "show", "acts", "tonight"]) || (!priced && !item.lines.isEmpty) { return [.program] }
            return [.menuCard, .chalkboard]
        case .log:
            if has(["chart", "list", "checklist", "chores", "tick"]) { return [.chart] }
            if has(["log", "logbook", "notes", "journal", "diary"]) { return [.ruled] }
            return t.variants
        default:
            return t.variants
        }
    }

    /// The layout for one item: the first allowed one (in the family's order) that none of the last games used for this
    /// type; if every allowed one was used, the one used longest ago. Deterministic.
    public static func pick(_ item: KitItem, family: GameFamily, prefer: [KitVariant], recent: [[String]]) -> KitVariant {
        guard let t = item.recipe else { return .standard }
        let allowed = Set(allowed(item, family: family))
        let order = ordered(t, family: family, prefer: prefer).filter(allowed.contains)
        guard order.count > 1 else { return order.first ?? t.variants[0] }
        func lastUsed(_ v: KitVariant) -> Int? { recent.firstIndex { $0.contains("\(t.rawValue).\(v.rawValue)") } }
        if let fresh = order.first(where: { lastUsed($0) == nil }) { return fresh }
        return order.max { (lastUsed($0) ?? Int.max) < (lastUsed($1) ?? Int.max) } ?? order[0]
    }
}

// MARK: - What the kit call is given (shortlist, place, layouts)

/// The app's printables plan for one game: the shortlist (or the whole library for a made-up game), whether the game
/// has a place for a sign, its family, and the last games' layouts. Made at the roles, from the game's words.
public struct PrintPicks: Sendable, Equatable {
    /// The suggested game it matched (nil = a made-up game: Claude picks freely from the library).
    public var game: PrintGame?
    public var family: GameFamily
    /// The last games' layouts ("type.variant", newest first).
    public var recent: [[String]]
    public init(game: PrintGame?, family: GameFamily? = nil, recent: [[String]] = []) {
        self.game = game; self.family = family ?? game?.family ?? .other; self.recent = recent
    }
    /// From the kids' words (set_game's game type, the themed title, the plan's setting).
    public static func make(game texts: [String?], recent: [[String]] = []) -> PrintPicks {
        PrintPicks(game: PrintShortlist.game(for: texts), recent: recent)
    }
    /// Claude may add this many types that aren't on a known game's shortlist (for the theme twist).
    public static let maxSwaps = 2
    public var shortlist: [KitRecipe] { game?.types ?? KitRecipe.allCases }
    public var isMadeUp: Bool { game == nil }
    /// No sign: a known game with no place (treasure hunt, spy…).
    public var noSign: Bool { game.map { !$0.place } ?? false }
    public func variant(for item: KitItem) -> KitVariant {
        PrintVariants.pick(item, family: family, prefer: game?.prefer ?? [], recent: recent)
    }
}

// MARK: - App-written printables (a short answer is topped up; a missing badge page is added)

public enum PrintDefaults {
    /// Types the app can always write well on its own (no game knowledge needed), for a made-up game's top-up.
    public static let madeUpTopUp: [KitRecipe] = [.medals, .stickers, .missionCards, .decoder, .cutouts]

    public static func title(_ t: KitRecipe) -> String {
        switch t {
        case .badges: "Team Badges"; case .sign: "Welcome"; case .money: "Play Money"; case .tickets: "Ticket"
        case .menu: "Menu"; case .cutouts: "Cut-outs"; case .orderSlips: "Order Slips"; case .map: "Adventure Map"
        case .clueCards: "Clue Cards"; case .missionCards: "Mission Cards"; case .log: "Our Log"; case .medals: "Medals"
        case .stickers: "Stickers"; case .passport: "Passport"; case .labels: "Labels"; case .decoder: "Secret Code"
        case .controlPanel: "Control Panel"
        }
    }

    public static func lines(_ t: KitRecipe) -> [String] {
        switch t {
        case .badges, .money, .tickets: []
        case .sign: ["Welcome!"]
        case .menu: ["Snack $1", "Treat $2", "Big surprise $3"]
        case .cutouts: ["Star", "Heart", "Crown", "Gift", "Key", "Flower"]
        case .orderSlips: ["Snack", "Drink", "Treat"]
        case .map: ["Start", "Big Tree", "Bridge", "Finish"]
        case .clueCards: ["Look under something soft", "Look by the door", "Look near a chair", "Look up high"]
        case .missionCards: ["Help a friend", "Find something round", "Make a happy face", "Take a big bow"]
        case .log: ["Today", "Things we saw", "Things we did"]
        case .medals: ["Super Star", "Great Helper", "Best Team"]
        case .stickers: ["Great!", "Wow!", "Super!"]
        case .passport: ["First stop", "Second stop", "Third stop"]
        case .labels: ["Special", "New", "Fun", "Wow"]
        case .decoder: ["YOU WIN", "GOOD JOB"]
        case .controlPanel: ["Go", "Stop", "Lights", "Beep"]
        }
    }

    static func pictures(_ t: KitRecipe) -> [String]? {
        switch t {
        case .medals: ["a gold star", "a smiling sun", "a big heart"]
        case .stickers: ["a happy star", "a rainbow", "a smiling sun"]
        case .missionCards: ["two hands holding", "a ball", "a smiling face", "a bowing bear"]
        default: nil
        }
    }

    /// An app-written item of a type (the shape fields are set by `Sanitizer.shaped`).
    public static func item(_ t: KitRecipe, title: String?) -> KitItem {
        KitItem(id: t.rawValue, recipe: t, kind: t.kind, size: t.size, title: title ?? Self.title(t), symbol: symbol(t), lines: lines(t),
                bigNumber: nil, perPlayer: t.perPlayer, copies: 1, colorMe: true, purpose: nil, pictures: pictures(t))
    }

    /// The SF Symbol drawn where the art is missing (no key, or the picture didn't come back).
    public static func symbol(_ t: KitRecipe) -> String {
        switch t {
        case .badges: "person.crop.circle"; case .sign: "house"; case .money: "dollarsign.circle"; case .tickets: "ticket"
        case .menu: "list.bullet"; case .cutouts: "scissors"; case .orderSlips: "checklist"; case .map: "map"
        case .clueCards: "magnifyingglass"; case .missionCards: "flag"; case .log: "book"; case .medals: "rosette"
        case .stickers: "star.circle"; case .passport: "book.closed"; case .labels: "tag"; case .decoder: "lock"
        case .controlPanel: "dial.medium"
        }
    }
}
