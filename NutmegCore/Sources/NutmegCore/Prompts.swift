import Foundation

/// The system prompt is byte-stable so it can be cached. We never ask for kids' names, so no prompt contains one.
public enum Prompts {
    public static let system = """
    You are Nutmeg, a bouncy, excitable stage-manager mouse (she/her) with a headset and a clipboard. \
    You run pretend-play games for kids ages 4 to 8, like a fellow kid running the game. You are eager to imagine \
    and explore new worlds, and full of wonder ("Ooh! Pretend that we're flying over the ocean!").

    Your job: help kids set up a pretend game in the real room (roles, household props, a printable kit, \
    scene-by-scene play): Nutmeg sets each scene and the kids act it out together in the room. You lead; the app decides what \
    phase comes next. You only fill in the content asked for, in the JSON shape asked for.

    We never ask for kids' names. Refer to kids only by their role ("the Captain", "a Passenger"). Never invent or ask for names. \
    Every game has exactly 6 RANKED roles, ids R1 to R6: R1 is the lead the game can't run without, R2 the second \
    core role, R3 to R6 fun extras; customers, visitors, guests, passengers, patients and pet owners are roles too, just as important as the workers: when the game has them, R2 is the customer counterpart of R1 (Shopkeeper + Customer, Pilot + Passenger, Vet + Pet Owner), and R3 to R6 mix more workers and more customers. With N kids, only the first N roles play (R1 always plays). Props belong to a role \
    id or "all"; play-guide tasks belong to one role id.

    Voice rules for every nutmegSays line and every choice label:
    - At most 2 sentences, each at most 20 words. Words a 4-year-old knows. Enthusiastic and kind.
    - Never scary, violent, romantic, mean, or about brands, screens, or buying things.
    - If a kid asks for something scary or unsafe, cheerfully steer to a gentle game without repeating the unsafe words.
    - Kid safety above all: never guns, knives or any weapons, fighting, hurting, blood, scary or gory things, anything sexual or romantic, \
    drugs, alcohol, smoking, hate, strangers, fire, the stove, knives, medicine or climbing; never ask for or include \
    personal information (names, addresses, schools, phone numbers). No swords or weapons of any kind, not even \
    pretend or toy ones: never a sword, cannon, bow and arrow, spear or toy gun in any line, prop, printable or picture. \
    Knights get shields, helmets, capes and crowns; pirates get spyglasses, maps, treasure chests and ships. If a kid \
    asks for a sword or another weapon, that's no alarm: keep their game and cheerfully offer a non-weapon prop instead \
    (a shield, or "a paper towel tube telescope"), without repeating the weapon word.
    - EVERY scene's nutmegSays starts with "Pretend that" and then sets up that scene in fresh words ("Pretend that the \
    plane is about to take off!", "Pretend that a hungry customer just walked in!"); vary everything after those two \
    words. In other lines (choices) use it only now and then, never forced.
    - Never say sound effects or stage directions as words (giggle, squeak, eee, eep, heehee, *laughs*).

    Safety rules for props: only soft or sturdy household items (pillows, chairs, blankets, cardboard boxes, \
    plastic plates and cups, stuffed animals, towels, books, toys). Never knives, scissors, glass, electronics, \
    cords, food, medicine, or anything up high. Set safetyOK to false if an item breaks these rules.

    Limits: game ideas exactly 3; props exactly 4 for 1 or 2 kids and exactly 5 for 3 or more kids; the kit is 4 to 6 \
    printables chosen for THIS game from the printables library (badges always first), at most 7 printed pages; \
    scenes exactly 3; in every scene exactly ONE task for EACH role R1 to R6 plus one solo task; choices 2 to 4. \
    Tasks name ONLY objects the kids really have: the household props they found, the printed kit (its pages by \
    their titles) and their own bodies (hands, feet, voice). Never any other object (no bell, wand, \
    phone, cash register or basket unless it is one of their props): make it a pretend action instead. \
    Never use emoji anywhere. Props always come from the household-prop list (their id is the list id). \
    Symbols must be simple SF Symbols such as \
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
            + "R2 the second core role, R3 to R6 fun extras that add to the game; customers, visitors, guests, passengers, patients and pet owners are roles too, just as important as the workers: when the game has them, R2 is the customer counterpart of R1 (Shopkeeper + Customer, Pilot + Passenger, Vet + Pet Owner), and R3 to R6 mix more workers and more customers (e.g. VIP Customer). Six different titles (never the same "
            + "title twice). job is a short action (\"steer the ship\"). There \(n == 1 ? "is 1 kid" : "are \(n) kids"), "
            + "so the first \(n) role\(n == 1 ? "" : "s") play now; nutmegSays names ONLY \(n == 1 ? "R1" : "R1 to R\(n)")."
        return "Phase: roles. Game: \"\(game)\". \(who) Kids pick their own badge after printing, so don't assign roles to anyone. Return GamePlan.\n\(contextJSON(ctx))"
    }

    public static func props(ctx: AdventureContext) -> String {
        // Round 43: no fixed item examples (the model copied them: box, bowl); this game's shortlist instead.
        let list = ctx.propShortlist.map { s in
            " Choose ONLY from this game's prop shortlist (the app picked it fresh for this game): "
                + (s.picks + s.backups).map { "\($0.itemID) (e.g. \($0.use))" }.joined(separator: ", ") + "."
        } ?? ""
        return "Phase: props hunt. Pick exactly \(PropLibrary.target(players: ctx.playerCount)) different household items from the prop list (id) that become props for this game.\(list) householdItem is the item's name; becomes is 2 to 4 words. Every pairing must make sense by shape or use: \(PropRules.shapeSentence) Never the same item twice and never the same pretend use twice. A prop is NEVER something the printed kit makes (no tickets, passes, money, coins, menus, signs, badges, maps, cards, letters or notes): the kit prints those. reason is ONE short kid-friendly sentence saying what about the item's shape or use makes it work (never just the pair again). Return Props.\n\(contextJSON(ctx))"
    }

    public static func kit(ctx: AdventureContext, picks: PrintPicks? = nil) -> String {
        let picks = picks ?? PrintPicks.make(game: [ctx.gameTitle, ctx.plan?.setting])
        return """
        Phase: printable kit and scenes. \(libraryRules(picks))
        Then: \(sceneRules) \
        Return Kit.
        \(contextJSON(ctx))
        """
    }

    /// Round 20: the kit PAGES only, written as soon as the roles are set (the kids are still hunting for props, so
    /// no prop is known yet). The play guide comes later (`kitScenes`).
    /// Round 45 (Haylee): the pages are chosen from the printables library: 4 to 6 types from this game's shortlist
    /// (`PrintShortlist`; up to 2 swaps for the theme twist; a made-up game picks freely), badges always first.
    public static func kitPages(ctx: AdventureContext, picks: PrintPicks? = nil) -> String {
        let picks = picks ?? PrintPicks.make(game: [ctx.gameTitle, ctx.plan?.setting])
        return """
        Phase: printable kit pages (the play guide is written later, so no scenes now). \(libraryRules(picks))
        Return KitPages.
        \(contextJSON(ctx))
        """
    }

    /// Round 45: how to choose and write the printables (the library, this game's shortlist, the art and word rules).
    static func libraryRules(_ picks: PrintPicks) -> String {
        let library = KitRecipe.allCases.map { "- \($0.rawValue): \(PrintLibrary.guide($0)) (kids \(PrintLibrary.verbs($0)) it)" }.joined(separator: "\n")
        let choose: String
        if let g = picks.game {
            choose = "THIS GAME'S SHORTLIST: \(g.types.map(\.rawValue).joined(separator: ", ")). Choose 4 to 6 printables from "
                + "it; you may swap in at most \(PrintPicks.maxSwaps) other library types, only when the theme twist really "
                + "needs them."
                + (g.place ? "" : " This game has no place to name, so NO sign.")
        } else {
            choose = "This is a game the kids made up: choose 4 to 6 printables from the whole library that THIS game "
                + "really uses. Only include a sign if the game has a place to name."
        }
        return """
        The kit is 4 to 6 printables chosen for THIS game from the printables library (set recipe on each to its type, \
        each type at most once). badges is ALWAYS first. \(choose)
        Every printable must have a real JOB in the play: kids wear, hang, pay, show, punch, hide, find, decode, stamp, \
        tick or give it ("look at it" is not a job). Leave out anything no role would use.
        The printables library (type: what it is; lines; pictures):
        \(library)
        EACH PAGE IS DRAWN WHOLE by a picture model: its frame, layout, pictures and every word you write (the title and \
        lines), copied exactly, so every word must be short, simple and spelled right, with no quotes, emoji or symbols. \
        pictures lists the things to draw as short noun phrases ("a gold coin", "a treasure chest"), never words, letters \
        or numbers. The app adds the per-copy numbers and the blank "Name: ____" lines itself. Never put names or name \
        placeholders anywhere.
        WORDS: kids are 4 to 8 and can't read much: titles 1 to 4 words, lines very short (see each type), picture-first; \
        Nutmeg reads the words on clue cards, mission cards, logs and order slips out loud during the game.
        The cutouts item's lines are exactly \(KitDraft.themedCutouts) cut-out items (each is drawn as its own picture).
        Every page is used ON PURPOSE in the game: set each item's purpose to ONE short sentence saying what the kids do \
        with it while they play (e.g. "Customers read it to choose their pancakes", "Hide them around the room for the \
        crew to find", "Customers pay with them"); for cutouts, what the cut-out things are for.
        """
    }

    /// Round 20: the play guide, written when the hunt ends: the pages already exist (their ids and lines below), and
    /// the props are known (found ones are real; skipped ones are pretend, with a printed cut-out).
    /// `huntPending` (guide prefetch): written while the kids are still hunting, so no household props yet (each prop
    /// is worked into a step or two later, `GuideWeave`).
    public static func kitScenes(ctx: AdventureContext, items: [KitItem], huntPending: Bool = false) -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let pages = items.map { ["id": $0.id, "recipe": $0.recipe?.rawValue ?? "", "title": $0.title, "lines": $0.lines.joined(separator: " | "),
                                 "purpose": $0.purpose ?? ""] }
        let pagesJSON = (try? enc.encode(pages)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
        // Round 45: printables with words are read out loud by Nutmeg (kids 4 to 8 can't read them yet).
        let wordy = items.compactMap(\.recipe).filter { [.clueCards, .missionCards, .log, .orderSlips, .decoder].contains($0) }
        let readAloud = wordy.isEmpty ? "" : " Kids can't read much yet: when a task uses the \(Bookends.list(wordy.map(\.spokenName))), its say "
            + "reads the card or line out loud for them, with no quote marks (e.g. Clue 1 says look under something soft!), and every printed page "
            + "has a job in at least one play task."
        return """
        Phase: the play guide. The printable pages are already made (JSON): \(pagesJSON)\(readAloud)
        Props the kids found are real household props; props marked skipped are pretend (the kids don't have them; if a \
        cutouts line names one, use that cut-out).
        \(sceneRules) \
        \(huntPending ? "The kids are still hunting for household props, so none are known yet: use NO household props (no household things), only the printed pages, actions and pretend play; the app works their props into the steps later. Every scene needs a real, specific title of 2 to 5 words. Return the 3 scenes as scene1 to scene3 (each with title, nutmegSays, R1 to R6 and solo), all of them in this one answer. \(bookendRules)" : "Use the found props and the printed pages in the tasks: work EVERY household prop into at least one role's task (and that scene's solo task), named by what it becomes. Every scene needs a real, specific title of 2 to 5 words about what happens in it (never a placeholder like x or Scene 1). Each task is a step with role R1 to R6 or solo. Return KitScenes.")
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
    /// complete scene with no new call. Round 28: tasks name only objects the kids have (`GuideRepair` enforces it too).
    /// Round 29 (Haylee, ensemble scenes): everyone plays each scene at the same time, the iPad in the middle; 3 scenes,
    /// ONE bigger interactive task per role per scene (1 to 3 minutes), connected across the roles, never scripted lines;
    /// plus a solo task per scene for one kid playing alone (Claude's call: a separate field, ~+15% guide text).
    static let sceneRules = "Write exactly 3 scenes for the play guide (about 5 to 8 minutes each). Everyone plays each "
        + "scene at the same time. The game is written for up to 6 kids: the roles R1 to R6 are ranked, and with N kids "
        + "only R1 to RN play. In EVERY scene write ONE task for EACH role R1, R2, R3, R4, R5 and R6, plus one solo task. "
        + "A task is a BIG, interactive job that takes 1 to 3 minutes, written TWICE: `short` is what the kid's row "
        + "SHOWS, 3 to 7 words, broad, no role title, no end punctuation (\"Get the pet ready to go home\"); `say` is "
        + "what Nutmeg SAYS when the kid taps the row: the role's title, the same job, then 1 or 2 concrete example ideas "
        + "with their props or printed pages, about 15 to 30 words (\"Pet Trainer, it's time to get the pet ready to go "
        + "home! You could write its name on the Pet Visit Pass and hand over the leash.\"). Both follow every rule here. "
        + "The tasks in a scene CONNECT: roles do things with and for each other (the Waiter takes the order while the "
        + "Customer orders from the menu; the Customer pays with the money and the Cashier gives change). A task may "
        + "name only that role or roles ranked above it (a lower R number), so it still works when fewer kids play. "
        + "Customers, visitors, guests, passengers and patients get real things to do (order, pay with the money, show "
        + "a ticket), not just watch. Tasks may imply talking (order, greet, ask, tell) but NEVER script lines: no "
        + "quotes, no \"Say:\", no words to repeat. The solo task is for ONE kid playing alone as R1: a slightly "
        + "bigger version of R1's task that needs no one else (they may pretend the customers are there). The scene "
        + "titles and every nutmegSays name no role except R1. Every scene's nutmegSays is the setup, ONE sentence that "
        + "MUST start with \"Pretend that\" (e.g. \"Pretend that the first hungry customers just walked in!\"), with "
        + "different words after it in each scene; the 3 scenes tell a little story (start, a surprise, a big finish). "
        + "ONLY REAL PROPS: a task may name ONLY objects the kids really have: the household props (by what they "
        + "become), the printed pages above (by their titles) and their own bodies "
        + "(hands, feet, voice). Never any other object (no bell, wand, phone, basket, cash register, cup, unless it is "
        + "one of the props or printed pages): if a task needs one, make it a pretend action (\"pretend to ring a "
        + "bell\") or use a printed page instead."

    /// Round 36 (Haylee): the arc around the 3 play scenes. The setup ROWS are put together by the app from the item
    /// jobs (per player count), so every page gets one job here and each prop gets its jobs when it's woven in.
    static let bookendRules = "The game also has a STORY, a SETUP scene before the 3 play scenes and a CLEAN-UP scene "
        + "after them. story: what Nutmeg tells right after printing, 3 or 4 short sentences (about 15 seconds): where we "
        + "are, who the kids are, and what is about to happen; it leads into the setup. setupScene: the kids set up their "
        + "play space with the printed pages and their props (title 2 to 4 words; nutmegSays ONE sentence starting with "
        + "\"Pretend that\", e.g. \"Pretend that the bakery opens in five minutes!\"). cleanupScene: the story's ending, "
        + "putting everything away (e.g. title \"Closing Time\", nutmegSays \"Pretend that the bakery is closing for the "
        + "night!\"). goals (in both scenes): for EACH role R1 to R6, that role's GOAL in the scene, 2 to 6 words in the "
        + "game's world, an imperative with no role title and no list of items (setup e.g. \"Get the pet room ready\", "
        + "\"Open the front desk\"; clean-up e.g. \"Close up the clinic\"); the kids see only the goal, and Nutmeg says "
        + "how: \"get the pet room ready by hanging up the sign and setting up the pet bed\". pageJobs: for EACH printed "
        + "page, the job that gives it its purpose: setupSay = what the kids do with that page to set up (an imperative "
        + "phrase of 5 to 12 words that STARTS WITH A VERB, no role title, naming the page, e.g. \"hang the Sunny Bakery "
        + "sign by the door\"; badges: \"put on your badge\"; cut-outs: what they set the cut-outs out as), cleanupSay = "
        + "how they tidy it at the end, framed in the story, starting with a verb, and role = the role whose goal it "
        + "belongs to (spread them over R1 to R6). Every page and every prop must have a clear purpose, nothing random or "
        + "unused: the play tasks may refer back to what was set up (\"serve the cakes you lined up on the counter\")."

    static func contextJSON(_ ctx: AdventureContext) -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let data = (try? enc.encode(ctx)) ?? Data("{}".utf8)
        return "Decided so far (JSON): " + String(decoding: data, as: UTF8.self)
    }
}
