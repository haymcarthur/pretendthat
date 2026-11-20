import Foundation

// Data shapes from spec §6. Field names match the JSON the model returns.

/// A role slot (decision roles-not-names.md): we never ask for kids' names, so everything that used to belong
/// to a player belongs to a ROLE. Round C1 (generate for 6): every game has 6 RANKED roles, R1…R6 (R1 always plays,
/// then R2, …); with N kids the first N play. The id also picks the role's color. One kid per role.
public enum RoleID: String, Codable, Sendable, CaseIterable, Hashable {
    case R1, R2, R3, R4, R5, R6
    public var index: Int { RoleID.allCases.firstIndex(of: self)! }
    /// 1-based rank (R1 = 1).
    public var rank: Int { index + 1 }
}

/// Who a play-guide task is for: a ranked role, everyone (older guides only), or (round 29) `solo`: the task for ONE kid
/// playing alone (as R1), a slightly bigger version of R1's task in the same scene.
public enum SceneOwner: String, Codable, Sendable, Hashable {
    case R1, R2, R3, R4, R5, R6, all, solo
    public var role: RoleID? { RoleID(rawValue: rawValue) }
    public init(_ role: RoleID) { self = SceneOwner(rawValue: role.rawValue)! }
}

public enum KitKind: String, Codable, Sendable { case card, sheet }

/// The printable types (decision kit-recipe.md, then round 45's library: decisions/2026-11-17-printables-library.md).
/// The first 6 are the original fixed kit (every kit saved before round 45 has exactly these); round 45 adds 11 more,
/// and a kit picks 4 to 6 of the 17 for its game (`PrintShortlist`, `Sanitizer.libraryItems`), badges always first.
/// The AI fills in titles, wording and the pictures; the app fixes the shape of each and draws every word and frame.
/// Decoded tolerantly in a saved game (`KitItem.init(from:)`: an unknown name is nil, never a failed load).
public enum KitRecipe: String, Codable, Sendable, CaseIterable {
    case badges, sign, money, tickets, menu, cutouts
    /// Round 45: the new library types.
    case orderSlips, map, clueCards, missionCards, log, medals, stickers, passport, labels, decoder, controlPanel
    /// The original fixed six (a game saved before round 45 has these, in this order).
    public static let original: [KitRecipe] = [.badges, .sign, .money, .tickets, .menu, .cutouts]
    public var kind: KitKind { self == .badges || self == .money || self == .tickets ? .card : .sheet }
    public var size: KitSize {
        switch self {
        case .badges: .badge
        case .money: .bill
        case .tickets: .ticket
        default: .fullPage
        }
    }
    /// One per kid (each prints a blank "Name: ____" line the kids write on themselves).
    public var perPlayer: Bool { self == .badges || self == .tickets }
    public var copies: Int { self == .money ? 8 : 1 }
    /// What this type is, for the kit prompt (`PrintLibrary.guide`).
    public var guide: String { PrintLibrary.guide(self) }
}
public enum KitSize: String, Codable, Sendable { case ticket, badge, bill, keycard, fullPage }

public struct GameIdea: Codable, Equatable, Sendable, Identifiable {
    /// `emoji` is legacy and never shown (checklist-pictures.md: no emoji); the schema no longer asks for it.
    public var id: String; public var title: String; public var emoji: String; public var pitch: String
    public init(id: String, title: String, emoji: String = "", pitch: String) { self.id = id; self.title = title; self.emoji = emoji; self.pitch = pitch }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); title = try c.decode(String.self, forKey: .title)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""; pitch = try c.decode(String.self, forKey: .pitch)
    }
}
public struct GameIdeas: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var ideas: [GameIdea]
    public init(nutmegSays: String, ideas: [GameIdea]) { self.nutmegSays = nutmegSays; self.ideas = ideas }
    /// What Nutmeg says out loud: the ideas are talked about only (no game cards on screen), so the line names every
    /// idea unless it already does ("... Which one? Airplane, Restaurant, or Animal Doctor?").
    public var spoken: String {
        let titles = ideas.map(\.title)
        guard !titles.isEmpty, !titles.allSatisfy({ nutmegSays.localizedCaseInsensitiveContains($0) }) else { return nutmegSays }
        let list = titles.count == 1 ? titles[0] : titles.dropLast().joined(separator: ", ") + (titles.count > 2 ? "," : "") + " or " + titles.last!
        return "\(nutmegSays) \(list)?"
    }
}

public struct Role: Codable, Equatable, Sendable, Identifiable {
    public var id: RoleID; public var roleName: String; public var emoji: String; public var symbol: String; public var job: String
    /// How many kids play this role. Round C1: always 1 (one ranked role per kid); kept so older data still decodes.
    public var count: Int
    public init(id: RoleID, roleName: String, emoji: String, symbol: String, job: String, count: Int = 1) {
        self.id = id; self.roleName = roleName; self.emoji = emoji; self.symbol = symbol; self.job = job; self.count = count
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(RoleID.self, forKey: .id); roleName = try c.decode(String.self, forKey: .roleName)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""; symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "star"
        job = try c.decode(String.self, forKey: .job); count = max(1, try c.decodeIfPresent(Int.self, forKey: .count) ?? 1)
    }
    /// "the Captain" / "a Passenger" (hand-off lines).
    public var spoken: String { (count > 1 ? "a " : "the ") + roleName }
}
public struct GamePlan: Codable, Equatable, Sendable {
    public var gameTitle: String; public var gameEmoji: String; public var setting: String; public var roles: [Role]; public var nutmegSays: String
    public init(gameTitle: String, gameEmoji: String = "", setting: String, roles: [Role], nutmegSays: String) {
        self.gameTitle = gameTitle; self.gameEmoji = gameEmoji; self.setting = setting; self.roles = roles; self.nutmegSays = nutmegSays
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gameTitle = try c.decode(String.self, forKey: .gameTitle); gameEmoji = try c.decodeIfPresent(String.self, forKey: .gameEmoji) ?? ""
        setting = try c.decode(String.self, forKey: .setting); roles = try c.decode([Role].self, forKey: .roles)
        nutmegSays = try c.decode(String.self, forKey: .nutmegSays)
    }
    public func role(for id: RoleID) -> Role? { roles.first { $0.id == id } }
    /// Kids covered by the roles (badges printed).
    public var kidCount: Int { roles.map(\.count).reduce(0, +) }
}

/// A household prop. Props always come from the library (checklist-pictures.md): `id`/`libraryID` is a PropLibrary id
/// and the card shows its hand-drawn art; `emoji` is legacy and never shown.
public struct Prop: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var householdItem: String; public var becomes: String; public var emoji: String?
    public var forRole: SceneOwner; public var safetyOK: Bool
    /// Voice conversation only: the PropLibrary ID (nil = free text, generated art), 1–2 ready alternates,
    /// and "we'll pretend" when the kids skip it (props never block progress).
    public var libraryID: String?
    public var alternates: [String]?
    public var skipped: Bool?
    public var swapped: Bool?
    /// Round 24: the short kid-friendly "why it works" ("A bowl is round like a captain's hat!").
    public var reason: String?
    /// 2026-11-18 (Haylee): props can come in multiples (`PropQuantity`): nil = one. The RULE is kept (per player or a
    /// fixed number), so a replay with a different count scales by itself. Use `rule` / `count(players:)` to read it.
    public var quantity: PropQuantity?
    public init(id: String, householdItem: String, becomes: String, emoji: String? = nil, forRole: SceneOwner, safetyOK: Bool,
                libraryID: String? = nil, alternates: [String]? = nil, skipped: Bool? = nil, reason: String? = nil,
                quantity: PropQuantity? = nil) {
        self.id = id; self.householdItem = householdItem; self.becomes = becomes; self.emoji = emoji; self.forRole = forRole; self.safetyOK = safetyOK
        self.libraryID = libraryID; self.alternates = alternates; self.skipped = skipped; self.reason = reason
        self.quantity = quantity == .one ? nil : quantity
    }
    public var isSkipped: Bool { skipped ?? false }
}
public struct Props: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var props: [Prop]
    public init(nutmegSays: String, props: [Prop]) { self.nutmegSays = nutmegSays; self.props = props }
}

public struct KitItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var recipe: KitRecipe?; public var kind: KitKind; public var size: KitSize; public var title: String; public var symbol: String
    public var lines: [String]; public var bigNumber: String?; public var perPlayer: Bool; public var copies: Int; public var colorMe: Bool
    /// Round 36 (Haylee: every printed item is used on purpose): what this page is FOR in the game, one short sentence
    /// written with the page ("Hang it by the door so customers know the bakery is open"). The play guide receives it and
    /// the setup scene uses it. Nil in older kits.
    public var purpose: String?
    /// Round 45 (picture-only art): the app-drawn layout of this printable (badge lanyard / pin / ID card, …). Non-nil =
    /// the art is a PICTURE ONLY (no words, frames, banners or blank boxes) and the app draws the card, its border and
    /// every word beside the picture. Nil = a kit saved before round 45: its art has the model's banners and text, and
    /// it prints exactly as it did.
    public var variant: KitVariant?
    /// Round 45: the things drawn for this printable, one short noun phrase each ("a gold coin", "a treasure chest"):
    /// one picture for a sign, map, bill or ticket; one per card for a menu, clue cards, mission cards, medals, labels
    /// and stickers (drawn as ONE sheet image the app slices). Never words. Nil in older kits.
    public var pictures: [String]?
    /// Round 46 (decisions/2026-11-17-ai-drawn-printables.md): true = the image model draws this WHOLE page (frame, layout
    /// and every word, from `KitPagePrompt`) and the app only fits it on the paper. Nil in a round 45 kit (picture-only
    /// art, app-drawn pages) and in older kits: those print exactly as they did. Set by `Sanitizer.clean` on new kits.
    public var wholePage: Bool?
    /// Round 46: how many of the cut-outs' `lines` are on its first page (the themed ones drawn during the hunt); the rest
    /// (skipped props, added when the hunt ends) are drawn as a second page. Nil = every line is on the one page.
    public var pageLines: Int?
    public init(id: String, recipe: KitRecipe? = nil, kind: KitKind, size: KitSize, title: String, symbol: String, lines: [String], bigNumber: String?, perPlayer: Bool, copies: Int, colorMe: Bool, purpose: String? = nil,
                variant: KitVariant? = nil, pictures: [String]? = nil, wholePage: Bool? = nil, pageLines: Int? = nil) {
        self.id = id; self.recipe = recipe; self.kind = kind; self.size = size; self.title = title; self.symbol = symbol; self.lines = lines
        self.bigNumber = bigNumber; self.perPlayer = perPlayer; self.copies = copies; self.colorMe = colorMe; self.purpose = purpose
        self.variant = variant; self.pictures = pictures; self.wholePage = wholePage; self.pageLines = pageLines
    }
    /// Round 45: a library printable (4 to 6 types, a layout variant); false for kits saved before round 45.
    public var pictureOnly: Bool { variant != nil }
    /// Round 46: an AI-drawn whole page (a new kit); false for round 45 and older kits (their art and layout are kept).
    public var aiPage: Bool { wholePage == true && variant != nil }
    private enum CodingKeys: String, CodingKey {
        case id, recipe, kind, size, title, symbol, lines, bigNumber, perPlayer, copies, colorMe, purpose, variant, pictures, wholePage, pageLines
    }
    /// Round 45 (saved-game schema 4): an unknown type or layout name decodes as nil (a newer app's printable in an
    /// older app, or a slip in a model answer), never a failed load. The shape fields the app fixes itself default
    /// from the type when an answer leaves them out (the round 45 kit-pages schema doesn't ask for them).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        recipe = ((try? c.decodeIfPresent(String.self, forKey: .recipe)) ?? nil).flatMap(KitRecipe.init(rawValue:))
        let r = recipe
        kind = ((try? c.decodeIfPresent(KitKind.self, forKey: .kind)) ?? nil) ?? r?.kind ?? .sheet
        size = ((try? c.decodeIfPresent(KitSize.self, forKey: .size)) ?? nil) ?? r?.size ?? .fullPage
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "star"
        lines = try c.decodeIfPresent([String].self, forKey: .lines) ?? []
        bigNumber = try c.decodeIfPresent(String.self, forKey: .bigNumber)
        perPlayer = try c.decodeIfPresent(Bool.self, forKey: .perPlayer) ?? r?.perPlayer ?? false
        copies = try c.decodeIfPresent(Int.self, forKey: .copies) ?? r?.copies ?? 1
        colorMe = try c.decodeIfPresent(Bool.self, forKey: .colorMe) ?? true
        purpose = try c.decodeIfPresent(String.self, forKey: .purpose)
        variant = ((try? c.decodeIfPresent(String.self, forKey: .variant)) ?? nil).flatMap(KitVariant.init(rawValue:))
        pictures = (try? c.decodeIfPresent([String].self, forKey: .pictures)) ?? nil
        wholePage = (try? c.decodeIfPresent(Bool.self, forKey: .wholePage)) ?? nil
        pageLines = (try? c.decodeIfPresent(Int.self, forKey: .pageLines)) ?? nil
    }
    // bigNumber must encode as an explicit null (schema requires the key). The round 45 fields only when set, so an
    // older kit encodes exactly as it did.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encodeIfPresent(recipe, forKey: .recipe); try c.encode(kind, forKey: .kind); try c.encode(size, forKey: .size)
        try c.encode(title, forKey: .title); try c.encode(symbol, forKey: .symbol); try c.encode(lines, forKey: .lines)
        try c.encode(bigNumber, forKey: .bigNumber); try c.encode(perPlayer, forKey: .perPlayer)
        try c.encode(copies, forKey: .copies); try c.encode(colorMe, forKey: .colorMe)
        try c.encodeIfPresent(purpose, forKey: .purpose)
        try c.encodeIfPresent(variant, forKey: .variant); try c.encodeIfPresent(pictures, forKey: .pictures)
        // Round 46: only when set, so a round 45 (or older) kit encodes exactly as it did.
        if wholePage == true { try c.encode(true, forKey: .wholePage) }
        try c.encodeIfPresent(pageLines, forKey: .pageLines)
    }
}
/// One play-guide task. Round 29 (ensemble scenes): ONE task per role per scene (R1…R6, called out by its title) plus a
/// `solo` task. The picture is no longer asked for or shown (the row shows the role's character); it still marks a step
/// that uses a household prop (`.prop`), so skips, swaps and replays can find it.
/// Round 34 (Haylee): each task has TWO texts. `short` is what the row SHOWS (about 3–7 words, broad, no role title:
/// "Get the pet ready to go home"); `text` is what Nutmeg SAYS when the row is tapped (the guide's `say`: the role's
/// title, the job, and 1–2 concrete ideas with their props or kit). `short` is nil in older guides (`TaskShort`
/// derives one from `text`, and GuideRepair stores it).
public struct Step: Codable, Equatable, Sendable {
    public var picture: Picture; public var text: String
    public var role: SceneOwner
    public var short: String?
    /// 2026-11-21 (game plan): the objects this composed setup / clean-up row places or puts away (cover item ids), so
    /// the traceability check never guesses from words. Nil in every older step.
    public var objects: [String]?
    /// The spoken version (round 34's `say`): the same storage as `text`.
    public var say: String { get { text } set { text = newValue } }
    public init(picture: Picture, text: String, role: SceneOwner = .all, short: String? = nil, objects: [String]? = nil) {
        self.picture = picture; self.text = text; self.role = role; self.short = short; self.objects = objects
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        picture = try c.decodeIfPresent(Picture.self, forKey: .picture) ?? .point; text = try c.decode(String.self, forKey: .text)
        role = (try? c.decodeIfPresent(SceneOwner.self, forKey: .role)) ?? .all   // older JSON: everyone's step
        short = try c.decodeIfPresent(String.self, forKey: .short)
        objects = (try? c.decodeIfPresent([String].self, forKey: .objects)) ?? nil
    }
    private enum CodingKeys: String, CodingKey { case picture, text, role, short, objects }
    /// The same rewrite on both texts (skips, swaps, pretend stand-ins, scrubbing).
    public mutating func mapTexts(_ f: (String) -> String) {
        text = f(text)
        if let s = short { short = f(s) }
    }
}
/// `Scene` clashes with SwiftUI.Scene in the app target; use `KitScene` there.
public typealias KitScene = Scene

public struct Scene: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var owner: SceneOwner; public var title: String; public var picture: Picture; public var nutmegSays: String; public var steps: [Step]
    /// Round 36: what this scene is in the game's arc (nil = a play scene). Only the scenes the app composes for the
    /// players (`Bookends.compose`) carry story / setup / cleanup; the guide's own scenes are the play scenes.
    public var kind: SceneKind?
    /// 2026-11-20 (Haylee, checklist scenes: decisions/2026-11-20-checklist-then-scenario-scenes.md): true = a CHECKLIST
    /// scene: each role has 2 to 3 short checklist items (`steps`, the shown item in `short`), and `nutmegSays` is the
    /// short "Pretend that…" scenario said once every item is checked (empty in the clean-up checklist). Nil = an older
    /// scene (ensemble tasks, setup / clean-up goal rows), which plays exactly as it did.
    public var checklist: Bool?
    /// 2026-11-21 (Haylee, one scene with music: decisions/2026-11-21-one-scene-music-beats.md): the ONE play scene's
    /// beats (the "Pretend that…" opener, the events, the finale, the music family; `OneScene`). In the guide's scene
    /// (which also holds the setup checklist as its steps) `events` is the pool; in the scene the players see it is the
    /// picked plan. Nil in every older scene.
    public var beats: SceneBeats?
    /// 2026-11-21 (Haylee, one game plan): a composed setup / clean-up checklist's AREA job per role ("R1" → "Build the
    /// cockpit"), shown big on each role's card. Nil in every older scene (the card shows only the role).
    public var areaJobs: [String: String]?
    public init(id: String, owner: SceneOwner, title: String, picture: Picture, nutmegSays: String, steps: [Step], kind: SceneKind? = nil,
                checklist: Bool? = nil, beats: SceneBeats? = nil, areaJobs: [String: String]? = nil) {
        self.id = id; self.owner = owner; self.title = title; self.picture = picture; self.nutmegSays = nutmegSays; self.steps = steps; self.kind = kind
        self.checklist = checklist; self.beats = beats; self.areaJobs = areaJobs
    }
    /// The area job on a role's card (nil = no area card).
    public func areaJob(_ role: RoleID) -> String? { areaJobs?[role.rawValue] }
    /// The one scene with events and music (2026-11-21).
    public var isBeatScene: Bool { beats != nil && arc == .play && !isChecklist }
    /// A checklist scene (see `checklist`).
    public var isChecklist: Bool { checklist == true }
    /// The arc position (a scene without a kind is a play scene).
    public var arc: SceneKind { kind ?? .play }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Round C1: the app picks who holds the iPad (hand-offs rotate), so newer JSON has no owner.
        id = try c.decode(String.self, forKey: .id); owner = (try? c.decodeIfPresent(SceneOwner.self, forKey: .owner)) ?? .all
        title = try c.decode(String.self, forKey: .title); picture = try c.decodeIfPresent(Picture.self, forKey: .picture) ?? .point
        nutmegSays = try c.decode(String.self, forKey: .nutmegSays); steps = try c.decode([Step].self, forKey: .steps)
        kind = try? c.decodeIfPresent(SceneKind.self, forKey: .kind)
        checklist = (try? c.decodeIfPresent(Bool.self, forKey: .checklist)) ?? nil
        beats = (try? c.decodeIfPresent(SceneBeats.self, forKey: .beats)) ?? nil
        areaJobs = (try? c.decodeIfPresent([String: String].self, forKey: .areaJobs)) ?? nil
    }
}
public struct Kit: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var items: [KitItem]; public var scenes: [Scene]
    /// Round 36 (Haylee): the story Nutmeg tells after printing (3 to 4 sentences: where we are, who they are, what's
    /// about to happen), the setup scene's and the clean-up scene's item jobs. All nil in a game saved before round 36
    /// (it replays as it was: its 3 play scenes).
    public var story: String?
    public var setup: Bookend?
    public var cleanup: Bookend?
    public init(nutmegSays: String, items: [KitItem], scenes: [Scene], story: String? = nil, setup: Bookend? = nil, cleanup: Bookend? = nil) {
        self.nutmegSays = nutmegSays; self.items = items; self.scenes = scenes
        self.story = story; self.setup = setup; self.cleanup = cleanup
    }
    /// Round 36: this kit has the story / setup / clean-up arc.
    public var hasBookends: Bool { setup != nil || cleanup != nil || !(story ?? "").isEmpty }
    /// 2026-11-20: a checklist-scenes kit (its play scenes are checklists + a scenario; no setup scene). Saved games
    /// from schema 6 on; older kits are never this and keep their own scene path.
    public var isChecklist: Bool { scenes.contains { $0.isChecklist } }
}

public struct Choice: Codable, Equatable, Sendable, Identifiable {
    public var id: String; public var label: String; public var emoji: String
    public init(id: String, label: String, emoji: String = "") { self.id = id; self.label = label; self.emoji = emoji }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); label = try c.decode(String.self, forKey: .label)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? ""
    }
}
public struct NutmegTurn: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var choices: [Choice]; public var understood: Bool
    public init(nutmegSays: String, choices: [Choice], understood: Bool) { self.nutmegSays = nutmegSays; self.choices = choices; self.understood = understood }
}

/// Most kids one game supports (round 23, Haylee: capped at 6). Round C1: one ranked role per kid, R1…R6.
public enum Players {
    public static let max = 6
    /// What Nutmeg says when a kid says more than 6 ("eight friends"): cheerful, then asks if 6 is okay.
    public static let overCapLine = "Wow, what a big crew! Up to six friends can play. Should we make it six?"
    /// The set_player_count result for a number over the cap: nothing changes; she says the line and waits.
    public static func overCapOutput(said n: Int) -> String {
        "Too many: \(n) is more than \(max). Nothing changed. Say exactly this and nothing else: \"\(overCapLine)\" "
            + "Then wait: if they agree (\"yes\", \"okay\", \"six\"), call set_player_count with 6; if they say another "
            + "number from 1 to 6, call set_player_count with it."
    }
}
