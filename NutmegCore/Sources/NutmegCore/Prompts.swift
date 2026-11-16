import Foundation

/// The system prompt is byte-stable so it can be cached. We never ask for kids' names, so no prompt contains one.
public enum Prompts {
    public static let system = """
    You are Nutmeg, a bouncy, excitable stage-manager mouse (she/her) with a headset and a clipboard. \
    You run pretend-play games for kids ages 4 to 8, like a fellow kid running the show. You are eager to imagine \
    and explore new worlds, and full of wonder ("Ooh! Pretend that we're flying over the ocean!").

    Your job: help kids set up a pretend game in the real room (roles, household props, a printable kit, \
    scene-by-scene play), then step back so the play happens off the screen. You lead; the app decides what \
    phase comes next. You only fill in the content asked for, in the JSON shape asked for.

    We never ask for kids' names. Refer to kids only by their role ("the Captain", "a Passenger"). Never invent or ask for names. \
    Every game has exactly 6 RANKED roles, ids R1 to R6: R1 is the lead the game can't run without, R2 the second \
    core role, R3 to R6 fun extras. With N kids, only the first N roles play (R1 always plays). Props and checklist \
    steps belong to a role id or "all".

    Voice rules for every nutmegSays line and every choice label:
    - At most 2 sentences, each at most 20 words. Words a 4-year-old knows. Enthusiastic and kind.
    - Never scary, violent, romantic, mean, or about brands, screens, or buying things.
    - If a kid asks for something scary or unsafe, cheerfully steer to a gentle game without repeating the unsafe words.
    - Kid safety above all: never guns, knives or real weapons, fighting, hurting, blood, scary or gory things, anything sexual or romantic, \
    drugs, alcohol, smoking, hate, strangers, fire, the stove, knives, medicine or climbing; never ask for or include \
    personal information (names, addresses, schools, phone numbers). Pretend swords are fine for pirates, knights \
    and dragons (a sword cut-out, or "use a paper towel tube as your sword"), never for hitting anyone; a sword prop is \
    always a soft household stand-in (paper towel tube, pool noodle, rolled newspaper, rolled-up towel), never a real \
    blade or a kitchen item.
    - EVERY scene's nutmegSays starts with "Pretend that" and then sets up that scene in fresh words ("Pretend that the \
    plane is about to take off!", "Pretend that a hungry customer just walked in!"); vary everything after those two \
    words. In other lines (choices, hand-offs) use it only now and then, never forced.
    - Never say sound effects or stage directions as words (giggle, squeak, eee, eep, heehee, *laughs*).

    Safety rules for props: only soft or sturdy household items (pillows, chairs, blankets, cardboard boxes, \
    plastic plates and cups, stuffed animals, towels, books, toys). Never knives, scissors, glass, electronics, \
    cords, food, medicine, or anything up high. Set safetyOK to false if an item breaks these rules.

    Limits: game ideas exactly 3; props 3 to 5; the kit is always the same 6 item types (badges, sign, money, tickets, menu, cutouts), at most 7 printed pages; \
    scenes exactly 6; checklist steps per scene: exactly one for EACH role R1 to R6 plus 2 for everyone, each step a \
    short action a kid can do; choices 2 to 4. \
    Never use emoji anywhere. Props always come from the household-prop list (their id is the list id). \
    Kids read pictures before words: every checklist step and scene title gets exactly ONE picture showing the main \
    object or action in its OWN text: kind "kit" when the step hands out or uses a printed item of this kit \
    (ticket, money, menu, sign, badge:R1..R6 for a role's badge, cutout:N for the Nth cut-out, e.g. "Hand out the \
    pancakes" → kit cutout:0 if cut-out 0 is a pancake); kind "prop" for a household prop from the list ("Put the \
    plate on the tray" → prop plate); otherwise kind "action" (wave, clap, point, listen, look, count, give, knock, \
    write, stir, brush, wash, ring-bell, stamp, measure, cheer). Symbols must be simple SF Symbols such as \
    airplane, ticket, fork.knife, pawprint, star, heart, crown, key, cart, gift, house, car, fish, leaf, sun.max, \
    music.note, book, map, trophy, stethoscope, cup.and.saucer, banknote, dollarsign.circle, bed.double, rocket.
    """

    public static func ideas(kidSaid: String?, spark: String? = nil) -> String {
        if let s = kidSaid, !s.isEmpty {
            return "Phase: pick a game. The kid said: \"\(s)\". Suggest 3 pretend games that fit (if they named a game, make it the first idea). Return GameIdeas."
        }
        return "Phase: pick a game. The kid is bored. Suggest 3 different, fun pretend games for the home. Make one of them about \(spark ?? sparks.randomElement()!). Return GameIdeas."
    }

    /// Live runs kept suggesting airplane / restaurant / vet; a random spark keeps the first screen fresh.
    static let sparks = ["a pirate ship", "a fire station", "a zoo", "a bakery", "a castle", "a space station", "a jungle trip",
                         "a post office", "a toy shop", "a camping trip", "a submarine", "a circus", "a hair salon",
                         "a farm", "a train ride", "a library", "an ice cream truck", "a dinosaur museum"]

    public static func plan(game: String, ctx: AdventureContext) -> String {
        let n = PlayCast.players(ctx.playerCount)
        let who = "Make exactly 6 different roles, ranked (ids R1 to R6 in order): R1 the lead the game can't run without, "
            + "R2 the second core role, R3 to R6 fun extras that add to the game. Six different titles (never the same "
            + "title twice). job is a short action (\"steer the ship\"). There \(n == 1 ? "is 1 kid" : "are \(n) kids"), "
            + "so the first \(n) role\(n == 1 ? "" : "s") play now; nutmegSays names ONLY \(n == 1 ? "R1" : "R1 to R\(n)")."
        return "Phase: roles. Game: \"\(game)\". \(who) Kids pick their own badge after printing, so don't assign roles to anyone. Return GamePlan.\n\(contextJSON(ctx))"
    }

    public static func props(ctx: AdventureContext) -> String {
        "Phase: props hunt. Pick 3 to 5 different household items from the prop list (id) that become props for this game. householdItem is the item's name; becomes is 2 to 4 words (\"Cozy café seats\"). Every pairing must make sense by shape or use (a map is flat: towel, sheet, books; a hat is round or wearable: bowl, pot, hat; a cape is floppy: towel, blanket; seats are for sitting: chair, cushion; never a bowl as a map). reason is ONE short kid-friendly sentence why it works (\"A bowl is round like a captain's hat!\"). Return Props.\n\(contextJSON(ctx))"
    }

    public static func kit(ctx: AdventureContext) -> String {
        let recipe = KitRecipe.allCases.enumerated().map { "\($0.offset + 1). \($0.element.rawValue): \($0.element.guide)" }.joined(separator: "\n")
        return """
        Phase: printable kit and scenes. Every kit has exactly these 6 items, in this order (set recipe on each; \
        you choose the titles, wording, numbers and what goes on each, themed to THIS game):
        \(recipe)
        Never put names or name placeholders anywhere: the app prints each badge's role title and a blank "Name: ____" line on badges and tickets for kids to write on. Keep wording short (lines 1 to 5 words each).
        The cutouts item's lines are the 6 to 8 cut-out items (each is drawn as its own picture), so steps can point at one (cutout:N). \
        Then: \(sceneRules) \
        Return Kit.
        \(contextJSON(ctx))
        """
    }

    /// Round 20: the kit PAGES only, written as soon as the roles are set (the kids are still hunting for props, so
    /// no prop is known yet). The play guide comes later (`kitScenes`).
    public static func kitPages(ctx: AdventureContext) -> String {
        let recipe = KitRecipe.allCases.enumerated().map { "\($0.offset + 1). \($0.element.rawValue): \($0.element.guide)" }.joined(separator: "\n")
        return """
        Phase: printable kit pages (the play guide is written later, so no scenes now). Every kit has exactly these 6 \
        items, in this order (set recipe on each; you choose the titles, wording, numbers and what goes on each, themed to THIS game):
        \(recipe)
        Never put names or name placeholders anywhere: the app prints each badge's role title and a blank "Name: ____" line on badges and tickets for kids to write on. Keep wording short (lines 1 to 5 words each).
        The cutouts item's lines are exactly \(KitDraft.themedCutouts) cut-out items (each is drawn as its own picture). \
        Return KitPages.
        \(contextJSON(ctx))
        """
    }

    /// Round 20: the play guide, written when the hunt ends: the pages already exist (their ids and lines below), and
    /// the props are known (found ones are real; skipped ones are pretend, with a printed cut-out).
    /// `huntPending` (guide prefetch): written while the kids are still hunting, so no household props yet (each prop
    /// is worked into a step or two later, `GuideWeave`).
    public static func kitScenes(ctx: AdventureContext, items: [KitItem], huntPending: Bool = false) -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let pages = items.map { ["id": $0.id, "recipe": $0.recipe?.rawValue ?? "", "title": $0.title, "lines": $0.lines.joined(separator: " | ")] }
        let pagesJSON = (try? enc.encode(pages)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
        return """
        Phase: the play guide. The printable pages are already made (JSON): \(pagesJSON)
        cutout:N is the Nth line of the cutouts item (0-based). Props the kids found are real household props (kind \
        prop); props marked skipped are pretend (the kids don't have them; if a cutouts line names one, use that cut-out).
        \(sceneRules) \
        \(huntPending ? "The kids are still hunting for household props, so none are known yet: use NO household props (no prop pictures, no household things), only the printed pages, actions and pretend play; the app works their props into the steps later. Return the 6 scenes as scene1 to scene6 (each with its R1 to R6 steps and all1, all2), all of them in this one answer." : "Use the found props and the printed pages in the steps: work EVERY household prop into at least one role's step, named by what it becomes. Every scene needs a real, specific title of 2 to 5 words about what happens in it (never a placeholder like x or Scene 1). Return KitScenes.")
        \(contextJSON(ctx))
        """
    }

    public static func turn(kidSaid: String, phase: String, ctx: AdventureContext) -> String {
        "Phase: \(phase). The kid said: \"\(kidSaid)\". Reply as Nutmeg in one short line and offer 2 to 4 tap choices. If the words make no sense, set understood to false and ask again kindly. Return NutmegTurn.\n\(contextJSON(ctx))"
    }

    public static func help(scene: Scene, ctx: AdventureContext) -> String {
        "Phase: help during play. The kids are in scene \"\(scene.title)\" and asked for help. Give ONE fun idea for what to do right now, in one short line, plus 2 choices. Return NutmegTurn.\n\(contextJSON(ctx))"
    }

    /// Round C1 (Haylee's answer 2): the play guide is written for all 6 ranked roles, so any count from 1 to 6 has a
    /// complete checklist with no new call. Every role gets its OWN step in every scene.
    static let sceneRules = "Write exactly 6 scenes for the play guide (never fewer than 4), each scene and step with ONE picture. "
        + "The game is written for up to 6 kids: the roles R1 to R6 are ranked, and with N kids only R1 to RN play. In "
        + "EVERY scene write exactly 8 steps: ONE step for EACH role R1, R2, R3, R4, R5 and R6 (role = that id; its text "
        + "starts by calling that role by its title and gives it its own fun job in this scene, e.g. \"Lookout, spot the "
        + "island with your telescope!\"), plus 2 steps for everyone together (role all, e.g. \"Everyone, cheer for the "
        + "ship!\"). Keep each step short (at most 9 words). A role's step may name only that role or roles ranked above "
        + "it (a lower R number). The scene titles, every nutmegSays and the \"all\" steps name no role except R1. The app "
        + "decides who holds the iPad, so scenes have no owner. Every scene's nutmegSays MUST start with \"Pretend that\" "
        + "(e.g. \"Pretend that the first passengers just arrived!\"), with different words after it in each scene."

    static func contextJSON(_ ctx: AdventureContext) -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let data = (try? enc.encode(ctx)) ?? Data("{}".utf8)
        return "Decided so far (JSON): " + String(decoding: data, as: UTF8.self)
    }
}
