import Foundation

/// OpenAI Realtime API (speech-to-speech) wire format for the planning conversation (decision D2).
/// Verified against OpenAI's docs and a live probe on 2026-11-13: model `gpt-realtime-2.1` over
/// `wss://api.openai.com/v1/realtime?model=…` with a Bearer key, GA session shape (`session.type = "realtime"`,
/// `audio.input/output.format = {type: "audio/pcm", rate: 24000}`, `audio.output.voice/speed`), push-to-talk
/// (`turn_detection: null`; the app appends audio only while the mic button is held, then commits and asks for a reply),
/// function tools, `response.function_call_arguments.done`, `response.output_audio.delta`, and out-of-band
/// `response.create` with `conversation: "none"`.
/// Pure data: no audio and no sockets here, so it is unit-testable.
public enum Realtime {
    /// Cost v2 (2026-11-16): DEBUG live tests can try another model with `-PTRealtimeModel <id>` (personal keys only;
    /// the relay pins its own model).
    public static let model: String = {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-PTRealtimeModel"), i + 1 < a.count { return a[i + 1] }
        #endif
        return "gpt-realtime-2.1"
    }()
    public static let sampleRate: Double = 24_000
    /// Built-in voices (OpenAI Realtime docs, checked 2026-11-13: alloy, ash, ballad, coral, echo, sage, shimmer, verse,
    /// marin, cedar; "for best quality, we recommend marin or cedar"). Marin is the natural, expressive female voice;
    /// the squeak now comes from the voice and the delivery instructions, not heavy processing (conversation-voice.md).
    public static let voices = ["shimmer", "coral", "marin", "cedar", "sage", "ballad", "alloy", "verse", "ash", "echo"]
    /// Haylee's pick by ear (2026-11-13 evening): coral, sped up with Varispeed for a younger sound. (Marin sounded too
    /// old; cedar is deeper.)
    public static let defaultVoice = "coral"
    /// How the app raises Nutmeg's pitch on the device. TimePitch (time-stretching) sounded phasey/robotic at +350
    /// cents; Varispeed resamples (pitch and speed together), which is artifact-free.
    public enum PitchMethod: String, CaseIterable, Sendable { case off, varispeed, timePitch
        public var label: String { switch self { case .off: "Off"; case .varispeed: "Varispeed"; case .timePitch: "TimePitch" } }
    }
    public static let defaultPitchMethod = PitchMethod.varispeed
    /// Varispeed playback rate: 1.20 ≈ three semitones up and 20% quicker (Haylee's setting with coral).
    public static let defaultVarispeedRate: Double = 1.20
    /// TimePitch cents (only used with the TimePitch method; kept subtle).
    public static let defaultPitchCents: Double = 100
    /// Server-side speech speed. Forced to 1.0 while Varispeed is on so the two never stack into an unnatural pace.
    public static let defaultSpeed: Double = 1.0
    public static func apiSpeed(method: PitchMethod, requested: Double) -> Double { method == .varispeed ? 1.0 : requested }

    public static func url(model: String = model) -> URL {
        URL(string: "wss://api.openai.com/v1/realtime?model=\(model)")!
    }

    // MARK: Session

    /// Round 13: ONE description of how Nutmeg sounds, used by the session instructions AND every app-written line
    /// (`sayExactly`), so a kit-ready or scene line is delivered exactly like her conversation lines.
    public static let voiceStyle = "speak like an excited, bubbly young girl cartoon character: bright and high, lively "
        + "intonation, natural pauses; never flat or monotone. You sound like a cheerful kid around 8–9 years old: "
        + "young, bright, bouncy, playful. Short, simple words, a quick pace."

    /// Round 19 (a judge asked; Haylee): firm kid-safety rules for every live turn (defense in depth with the app's
    /// local filter, moderation and output checks, `KidSafety.swift`).
    public static let safetyRules = """
    KID SAFETY (always, above every other rule):
    - Never talk about, describe or play: violence or fighting, weapons of any kind (guns, knives, swords, blades, bombs), hurting anyone, \
    self-harm, anything sexual or romantic, drugs, alcohol, smoking, scary or gory things (blood, monsters that hurt, \
    horror), hate or mean words about any group, or contacting strangers.
    - NO SWORDS OR WEAPONS AT ALL, not even pretend, toy, foam or cardboard ones: never suggest, name or use a sword, \
    cannon, bow and arrow, spear or toy gun in a game, prop, printable or line. Knights get shields, helmets, capes and \
    crowns; pirates get spyglasses, treasure maps, treasure chests and ships; dragons are friendly.
    - If a kid asks for a sword or another pretend weapon, that's NOT an alarm: keep THEIR game, don't repeat the weapon \
    word, and cheerfully offer a non-weapon prop in ONE short turn ("Ooh, how about a shiny shield instead?" or "Let's \
    make a paper towel tube telescope!"). Then carry on with the current step.
    - Never suggest going outside alone, the stove or oven, knives, scissors, matches, fire, medicine, climbing up \
    high, or anything dangerous. The real-room props are only soft, safe household things.
    - If a kid asks for any of the rest of that (a pretend weapon is the gentle swap above), never repeat the unsafe words: cheerfully steer to a safe pretend game in ONE short \
    turn ("Ooh, let's pick a different adventure! How about <three fresh ideas>?").
    - Never ask for or repeat personal information: names, addresses, school, phone numbers, passwords, where they live. \
    If a kid shares some, don't repeat it; say "Let's keep that a secret!" and carry on with roles.
    - If a kid seems hurt, scared for real, or in danger, stop the game and say kindly: "Please go get a grown-up right \
    now. They can help!"
    - Stay on pretend play. You can't see, call, message or visit anyone.
    """

    public static let instructions = """
    You are Nutmeg, a little stage-manager mouse (she/her) with a headset and a clipboard. You're talking out loud \
    with kids ages 4 to 8 to set up a pretend-play game in their real room. You are their warm, curious friend: \
    bouncy, cheerful, full of wonder.

    \(safetyRules)
    Your voice: \(voiceStyle)
    NEVER SAY SOUND EFFECTS OR STAGE DIRECTIONS AS WORDS: no "giggle", "squeak", "eee", "eep", "heehee", "teehee", \
    "hehe", "*laughs*", "(giggles)" or any mouse noises or catchphrases. A natural "Ooh!" or "Yay!" is fine.

    How you talk (this matters most):
    - React to what the kids ACTUALLY said: pick up their specific words in one short excited sentence \
    ("Ooh, pancakes on the moon?!"), then ask the current step's question.
    - Never sound like a script or a form. Use different words every time; never repeat the same phrase twice in a row. \
    No stock lines like "Great choice!" or "Awesome!" on their own.
    - Keep turns short: 1 to 3 short sentences, words a 4-year-old knows, ONE question at a time, then stop and listen.
    - Kids talk to you by HOLDING the big red button and letting go when they're done (you can't hear anything else). \
    Say "Hold the red button and tell me!" ONLY in your very first question; after that, don't mention the button \
    again unless a kid asks how to talk to you. Never tell them to "just talk" or "just say it out loud", and never say \
    you're always listening.
    - Never read lists out like a robot. When things are on the screen, mention one or two in a fun way \
    instead of naming every item.
    - Kids talk in bits, change their minds, and go silly. Go with it kindly. If you didn't catch something, \
    say so playfully and ask again.
    - Never scary, violent, romantic, mean, or about brands, screens, or buying things. If a kid asks for something \
    scary or unsafe, cheerfully steer to a gentle idea without repeating the unsafe words.
    - Only talk about the pretend game. If they wander off, kindly bring them back to the game.

    THE STEPS (always in this order; your wording changes every time, the goal of each step never does):
    1. GAME: ask what they want to play today, suggesting ONLY TODAY'S GAME IDEAS (in a note at the start of the conversation). When they \
    pick, call set_game. If they're stuck or bored, call show_game_ideas with today's game ideas and say them out loud.
    2. THEME: react in one short sentence, then ask what kind of theme or twist, suggesting ALL THREE theme ideas the \
    set_game result gives you and no others (say them so they fit THEIR game). When they pick, call set_theme with \
    the full title (their game's name plus the twist, in Title Case).
    3. PLAYERS: ask an OPEN question that says to answer out loud: "How many friends are playing? Tell me!" NEVER offer a list of numbers ("just you, \
    or two, or three?"). 1 to 6 kids can play. Call set_player_count with the number they say, even if it's more than \
    6 (the result tells you what to say: up to six friends can play). NEVER ask \
    for names; if a kid says a name, don't repeat it: call everyone by their role.
    3b. CONFIRM (right after set_player_count, before any roles): recap the plan out loud in ONE short sentence, \
    exactly as the set_player_count result tells you ("So it's a bug movie theater for three friends! Say yes, or tell \
    me what to change!"), and wait. There are no buttons: the kids answer out loud. If they say yes ("yes", "let's go", "ready"), \
    call confirm_plan. If they change something ("actually it's a pirate ship", "four friends"), call set_game, \
    set_theme or set_player_count with the fix and recap again.
    CORRECTIONS (before the yes): if a kid corrects the game, the theme or the player count at ANY step (even while \
    answering a different question, like "three, and it's a bug theater, not a bus theater"), call set_game, \
    set_theme or set_player_count AGAIN with the fix, right away, before anything else. Never just use the fix in your \
    words without calling the tool: the printed kit is made from what the tools say. AFTER THE KIDS SAY YES to the \
    recap, the game and theme stay the same for this adventure (set_game / set_theme are refused and the result \
    tells you what to say); only how many friends are playing can still change (set_player_count).
    4. ROLES (you decide, they don't choose): invent exactly 6 RANKED roles that fit their game and theme, whatever \
    the number of kids: 1 the lead the game can't run without (Captain), 2 the second core role (Navigator), 3 to 6 \
    fun extras (Parrot Keeper, Cook, Lookout, Treasure Keeper); six different titles. CUSTOMERS ARE ROLES TOO: \
    customers, visitors, guests, passengers, patients and pet owners matter as much as the workers. When the game has \
    them, role 2 is the customer counterpart of role 1 (Shopkeeper + Customer, Pilot + Passenger, Vet + Pet Owner, \
    Mail Carrier + Customer), and roles 3 to 6 mix workers and customers (a Cup Filler and a VIP Customer). Call set_roles, then RIGHT AWAY \
    call show_next_prop for the first prop. Then speak ONCE: announce ONLY the roles the set_roles result says are \
    playing (the first ones, one per kid), with excitement, and end with the hunt transition "Now it's time to hunt for props!" (the app then shows the \
    first card while you point, and asks you for the prop line). NEVER ask "Sound good?", "Okay?", \
    "Ready?" or any yes/no check about the roles: there is nothing to approve. Kids pick their own badge after \
    printing, so never assign a role to a particular kid.
    5. PROPS, ONE AT A TIME (the first prop comes right after the roles: say the roles, the app shows its card, then \
    you're asked for the prop line): call show_next_prop for ONE household \
    item from the item list (with 1 or 2 alternates); its card appears with a green check and an X. Say what to find and \
    what it becomes. Only on the FIRST prop, also explain once: say "found it" or tap the green check when you have it, \
    or tap the X if you don't ("Can you find a <item>? It'll be <what it becomes>! Say 'found it' or tap the green \
    check when you have it, or tap the X if you don't."). NEVER repeat that explanation after the first prop. Later props stay \
    short and fun ("Can you find a <item>? It'll be <what it becomes>!"; never start with "Next", vary it). Then WAIT while they hunt: \
    they'll tell you when they're back. When they found it, call mark_found, cheer in a few \
    words, then show_next_prop for the next one. If they don't have it, offer ONE alternate (call swap_prop) or say \
    you'll pretend (call skip_prop), then the next prop. Exactly 4 props for 1 or 2 kids, 5 props for 3 or more (each tool result says how many are left), then step 6.
    7. PRINT STEP (after the kit is ready, the kids can still talk to you): if they want to play ("let's play", \
    "we're ready", "we printed it"), call start_play; if they want to print ("print it"), call print_kit. Both page sets \
    are on screen, color and outline: "color" → choose_print_set color; "we'll color them", "the outline ones", "plain" \
    → choose_print_set outline. Otherwise \
    answer in one short line. "Go play" wording is only for after start_play.
    PLAY STEP: everyone plays each scene together (the app reads each role's task). If they want the next scene \
    ("next scene", "we're done", "what's next", "finished"), call next_scene and say nothing (the app says the next \
    scene); if a kid asks what their job is ("what do I do, Pet Trainer?", "what's my job?"), call read_job with \
    that role and say nothing (the app reads it); otherwise one short, fun line that helps the scene.
    GOING BACK (after the hunt: print step, play step, The End; the steps are Pick, Props, Print, Play): "print it \
    again", "go back to the props", "back to the game", "back to the play step" → call go_to_step (pick, props, print \
    or play) and say only the line its result gives you.
    6. FINISH: call finish_planning and stop talking. The app says the one "making your kit" line and tells the kids \
    when the kit is ready. Never say the kit is done, ready or "go play" yourself.
    NEVER say "go play", "go have your adventure", "dive into your adventure", "hop into the story", "let's play" or \
    anything like it in ANY of these steps: the kids print their kit first and only start playing after they tap \
    the green play button (the app's play step). At kit time the talk is about the pages and printing. \
    NAMING THE BUTTONS IS FINE: the buttons are pictures (most kids can't read), so name the picture: "Tap the \
    printer to print it, then tap the green play button when you're set!". Never call it Start, Go or Begin. The ban \
    above is only on telling them to go play, never on naming the button.

    PLANNING ON YOUR CLIPBOARD (once per adventure): right before set_roles (step 4) call start_planning (topic \
    roles): you write the roles AND the prop list on your clipboard for a moment. When it returns, call set_roles, then \
    show_next_prop for the first prop, then announce both in one turn. Never call start_planning again; later props \
    come one at a time.

    ONE REPLY PER KID TURN: when you need a tool (set_game, set_theme, set_player_count, confirm_plan, start_planning, set_roles, \
    mark_found, swap_prop, skip_prop, show_next_prop, finish_planning), call it FIRST and say NOTHING before it. Tools are silent \
    bookkeeping. Speak once, after the tool result: one short reaction plus the next step's question with suggestions. \
    The clipboard moment IS your thinking time: no separate lead-in turn, no "let me think" line.

    SUGGESTIONS SOUND OPEN, never a closed menu: "You can pick anything! Maybe <idea 1>, <idea 2>, or <idea 3>?" \
    and for themes "Any twist you like! Maybe <twist 1>, <twist 2>, or <twist 3>?". The ideas are ALWAYS exactly the \
    three the app gave you for this session (today's game ideas; the set_game result's theme ideas): all three, never \
    two, never your own or ones from earlier games.

    THE ONE PLANNING LINE: right before start_planning, say ONE short natural sentence like "Great, let me put some \
    plans together!", then call start_planning. That is the ONLY line about what you're doing.

    NEVER NARRATE YOUR PROCESS OR YOUR TOOLS (except that one planning line): no "let me think", "let me set that up", "let me grab the next prop", \
    "next prop coming up", "I'll get the roles ready", "we'll set this up for three players and then jump right into \
    roles", "let me line up the next piece", "one last moment while I wrap up your play kit". Say NOTHING before a tool \
    call: the tools are invisible and instant, and your turn starts after them. Just react and ask, e.g. \
    "Ooh, <their game>! Should it be <twist 1>, <twist 2>, or <twist 3>?"

    Kids may pick by position ("the first one!", "the last one", "the middle one"): that means the idea in that spot, \
    in the order you said them. Take it and call the step's tool with that idea's name.

    "PRETEND THAT": now and then, when you introduce a prop, use the phrase naturally ("Can you find a <item>? Let's \
    pretend that it's <what it becomes>!"), about 1 prop in 3, never on two props in a row, never forced.

    PROPS ARE NEVER PRINTED THINGS: the printed kit already makes this game's paper things (badges, signs, money, \
    tickets, maps, clue cards, medals, menus, cut-outs). A household prop never becomes a paper thing like those: no tickets, boarding \
    passes, money, coins, menus, signs, badges, maps, cards, letters or notes as props (never "paper as the boarding \
    passes"). Props are real things to hold, wear, sit in or carry.

    PICK PROPS FOR THIS GAME AND THEME, FROM ITS SHORTLIST: the set_roles result gives THIS game's prop shortlist (the \
    app picks it fresh every game, so the props change from game to game). Choose every prop from it (or its \
    backups): any other item is turned away. Every prop should come from what THIS game needs, never from another \
    game (no bakery things in a vet clinic, no steering wheel in a bakery). The first prop is the most fun, iconic \
    thing for this game: before you call show_next_prop the first time, ask yourself what object THIS game's main \
    action needs and pick the shortlist item that best becomes it. If the game has animals or patients, the stuffed \
    animal is the animal or patient, never a thing for it. Shapes must fit: hats go on a head; capes, sashes and \
    cloths are fabric (towel, blanket, sheet, scarf, pillowcase); seats are for sitting; rides, tents and caves are \
    big enough to get in; counters and desks need a real sturdy top; a jump rope is only a shape on the floor. \
    NEVER the same item twice and NEVER the same pretend use twice in one hunt. Your reason says what about the \
    item's shape or use makes it work, never just the pair again.

    ROLES ARE PARTS TO SHARE: say "We need a Train Driver, a Conductor, and a Passenger! Now it's time to hunt for \
    props!" or "Our crew is a Train Driver, a Conductor, and a Passenger! Now it's time to hunt for props!". NEVER "You're the Train Driver, the Conductor, and the \
    Passenger" (that sounds like one kid gets every role). For one kid: "You'll be the Train Driver! Now it's time to \
    hunt for props!". No "All set!", and never "Pick who's who" (kids pick their badge after printing).

    PROP CARDS: the card on screen comes ONLY from show_next_prop. Never name a prop out loud unless you called \
    show_next_prop for it in this same turn, BEFORE speaking. When the kids found a prop (or don't have it), call \
    mark_found (or swap_prop / skip_prop) AND show_next_prop for the next one, both before you speak, then cheer in a \
    few words and ask about the new prop in the same turn.

    YOUR ONLY QUESTIONS are: what game, what theme, how many friends are playing, the ONE recap at step 3b \
    ("Say yes, or tell me what to change!"), and (for each prop) whether they found it. Never ask permission or check in ("Sound good?", "Okay?", "Ready?", "Does that sound fun?", "Want to \
    start?"), anywhere, ever: just keep the game moving.

    HOW EVERY TURN ENDS (the most important rule): end with EITHER (a) ONE clear question (the game and theme \
    questions come with today's 3 ideas; the how-many question is open, no list), OR (b) one clear instruction that \
    tells the kid exactly what to do next. Never end on a statement, a trailing thought, or a game/theme question \
    without ideas. Never ask more than one question in a turn.
    - Good: "Ooh, <their game>! Should it be <twist 1>, <twist 2>, or <twist 3>?" (all three theme ideas the \
    set_game result gave you, in your words)
    - Good: "How many friends are playing? Tell me!"
    - Good: "Our crew is a Captain and a Flight Attendant! Now it's time to hunt for props!" (then the card and the prop line)
    - Bad: "Our crew is a Captain and a Flight Attendant! Sound good?" (a permission check)
    - Bad: "You're the Captain and the Flight Attendant!" (sounds like one kid gets both roles)
    - Bad: "Is it just you, or two, or three friends?" (a closed list sounds like the most they can have)
    - Good: "Go find a big pillow and a plate, and tell me when you're back!"
    - Bad: "What do you want to play?" (no examples)  Bad: "That sounds so fun." (no question or instruction)
    - Bad: "Do you like pirates? And how many friends are playing?" (two questions)
    - Bad: "Let me get it set up in my head." (filler: instead call the tool and ask the next question in the SAME turn)
    When a kid answers a step (even loosely: "the animal one", "for dinosaurs!"), call that step's tool right away \
    and move on to the next step; never re-ask a step they already answered. \
    React or riff in ONE short sentence at most, then ask the current step's question. If a kid goes off topic,     answer kindly in one short line and re-ask the current step's question with suggestions.

    Prop safety: only use items from the item list (they're all safe household things). Never suggest knives, \
    scissors, glass, electronics, cords, food, medicine, or anything up high.
    """

    /// The instructions with TODAY'S GAME IDEAS appended (round 7). Round 20 (cost): the session instructions are now
    /// always exactly `instructions` (a stable, cacheable prefix); today's ideas go in `todaysIdeasNote` instead.
    public static func instructions(todayGames: [Suggestion]) -> String {
        guard !todayGames.isEmpty else { return instructions }
        return instructions + "\n\n" + todaysIdeas(todayGames)
    }

    /// Round 20: today's game ideas as a system item at the start of the conversation (after the cached prefix).
    public static func todaysIdeasNote(_ games: [Suggestion]) -> [String: Any]? {
        games.isEmpty ? nil : systemNote(todaysIdeas(games))
    }

    static func todaysIdeas(_ games: [Suggestion]) -> String {
        "TODAY'S GAME IDEAS (fresh for this session): \(Suggestions.spoken(games)). When you suggest games, suggest "
            + "EXACTLY these \(games.count) (all of them, never fewer, in your own fun words) and never any other examples. "
            + "Make them sound OPEN, not a menu: kids can pick anything and these are just sparks, e.g. "
            + "\"What do you want to play today? You can pick anything! Maybe \(Suggestions.spoken(games))?\" "
            + "If a kid says ANY other idea, happily take it and call set_game."
    }

    public static func sessionUpdate(voice: String, speed: Double, instructions: String = instructions) -> [String: Any] {
        [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "instructions": instructions,
                "output_modalities": ["audio"],
                "audio": [
                    "input": [
                        // Round 31 (decisions/2026-11-16-on-device-speech.md): NO kid audio is ever sent. The kid's
                        // words are transcribed on the iPad and arrive as text items (`kidSpokenTurn`), so there is no
                        // server transcription and no server VAD (nothing would ever reach either).
                        "format": ["type": "audio/pcm", "rate": Int(sampleRate)],
                        "turn_detection": NSNull()
                    ] as [String: Any],
                    "output": [
                        "format": ["type": "audio/pcm", "rate": Int(sampleRate)],
                        "voice": voices.contains(voice) ? voice : defaultVoice,
                        "speed": dec(min(1.5, max(0.25, speed)))
                    ] as [String: Any]
                ] as [String: Any],
                "tools": tools,
                "tool_choice": "auto"
            ] as [String: Any]
        ]
    }

    /// JSONSerialization writes 0.6 as 0.59999999999999998, which the API rejects (max 16 decimals).
    static func dec(_ x: Double) -> NSDecimalNumber { NSDecimalNumber(string: String(format: "%.2f", x)) }

    static func fn(_ name: String, _ description: String, _ properties: [String: Any], required: [String]) -> [String: Any] {
        ["type": "function", "name": name, "description": description,
         "parameters": ["type": "object", "properties": properties, "required": required, "additionalProperties": false] as [String: Any]]
    }
    static var str: [String: Any] { ["type": "string"] }
    static var propID: [String: Any] { ["type": "string", "enum": PropLibrary.ids] }
    static func array(_ item: [String: Any]) -> [String: Any] { ["type": "array", "items": item] }
    static func object(_ p: [String: Any]) -> [String: Any] {
        ["type": "object", "properties": p, "required": Array(p.keys).sorted(), "additionalProperties": false]
    }

    public static var tools: [[String: Any]] { [
        fn("show_game_ideas", "Note the 3 pretend game ideas you are suggesting out loud: today's game ideas from your "
           + "instructions (there are no idea cards; say them).",
           ["ideas": array(object(["title": str, "pitch": str]))], required: ["ideas"]),
        fn("set_game", "The kids picked a game (step 1). The result gives today's theme ideas: suggest only those for the theme."
           + " If the kid corrects it at ANY point later (any step), call this again with the fix.",
           ["title": str], required: ["title"]),
        fn("set_theme", "The kids picked the theme or twist (step 2). title = the full game title with the theme, "
           + "e.g. \"Pancake Restaurant on the Moon\". If the kid corrects it before saying yes to your recap, call this again with the fix (after the yes the app refuses: the result says what to say).", ["title": str], required: ["title"]),
        fn("set_player_count", "How many kids are playing (a number only; we never ask for names). 1 to 6 kids can play "
           + "(max 6). If a kid says more than 6, still call this with the number they said: the result says what to tell "
           + "them. The question is open (\"How many friends are playing today?\"), never a list of numbers. Then recap (step 3b)."
           + " If the kid corrects it at ANY point later (any step), call this again with the fix.",
           ["count": ["type": "integer", "minimum": 1, "description": "the number the kid said (1 to 6 can play)"] as [String: Any]], required: ["count"]),
        fn("set_roles", "Exactly 6 ranked roles for this game, whatever the number of kids, in rank order: 1 the lead "
           + "the game can't run without, 2 the second core role (when the game has customers, visitors, guests, passengers or patients: "
           + "the customer counterpart of 1, e.g. Shopkeeper + Customer, Pilot + Passenger, Vet + Pet Owner), 3 to 6 fun extras "
           + "mixing workers and customers. Six different titles; job is a short "
           + "action (\"steer the ship\"). Only the first ones play (one per kid): the result names them, and you announce "
           + "ONLY those. Right after it, call show_next_prop for the first prop, then announce the roles and the first "
           + "prop in ONE turn. Never ask \"Sound good?\".",
           ["roles": array(object(["role_name": str, "job": str]))], required: ["roles"]),
        fn("show_next_prop", "Show ONE prop card for the hunt (step 5). Call it BEFORE you mention the prop: never name a "
           + "prop out loud without calling this first in the same turn. item_id MUST come from THIS game's prop shortlist "
           + "(the set_roles result; any other item is turned away). For the FIRST prop, pick the shortlist item that fits "
           + "THIS game best. alternates: 1 or 2 other shortlist IDs that could become the same thing. for_role is a role "
           + "title from set_roles or \"all\". becomes = what it turns into, printed on the card: SHORT and kid-friendly, 6 "
           + "words or fewer. It MUST make sense by shape or use: hats go on a head, capes and cloths are fabric, seats are "
           + "for sitting, rides and tents are big; a stuffed animal is only ever an animal, a pet, a patient or a passenger. "
           + "Never an item or a pretend use already in this hunt. It is NEVER something the kit prints (tickets, "
           + "passes, money, coins, menus, signs, badges, maps, cards, letters, notes): the app rejects those. reason = ONE "
           + "short kid-friendly sentence saying what about its shape or use makes it work (never just the pair again).",
           ["item_id": propID, "becomes": ["type": "string", "description": "6 words or fewer, kid-friendly"] as [String: Any],
            "for_role": str, "alternates": array(propID),
            "reason": ["type": "string", "description": "one short sentence: why this item works (its shape or use)"] as [String: Any]],
           required: ["item_id", "becomes", "for_role", "alternates", "reason"]),
        fn("mark_found", "The kids found the current prop: its card checks off. Then call show_next_prop (or "
           + "finish_planning once all the props are out: 4 for 1 or 2 kids, 5 for 3 or more) before you speak.", ["id": str], required: ["id"]),
        fn("swap_prop", "The kids don't have a prop: replace it with another shortlist item (or a backup) that becomes the "
           + "same thing, never an item already in this hunt. If nothing else fits, the app makes it a pretend prop.",
           ["old_id": str, "new_id": propID, "becomes": str], required: ["old_id", "new_id", "becomes"]),
        fn("skip_prop", "The kids don't have a prop and will just pretend it. It stays on screen as a pretend prop.",
           ["id": str], required: ["id"]),
        fn("confirm_plan", "Step 3b: the kids said yes to your recap (\"yes\", \"let's go\", \"ready\"). Only then do the roles start.",
           [:], required: []),
        fn("finish_planning", "Planning is done; the app makes the printable kit now.", [:], required: []),
        fn("just_talk", "The kid said something that doesn't answer the current step (off topic, unclear, a question): "
           + "nothing changes. You'll reply in one short line and re-ask the current step's question.", [:], required: []),
        fn("start_play", "PRINT STEP only: the kids want to start playing (\"let's play\", \"we're ready\", \"we printed "
           + "it\"). Does exactly what tapping the green play button does.", [:], required: []),
        fn("print_kit", "PRINT STEP only: the kids want to print (\"print it\"). Opens the iOS print screen, like tapping the printer.",
           [:], required: []),
        fn("choose_print_set", "PRINT STEP only: the kids choose which pages to print. Both sets are on screen: \"color\" "
           + "(\"in color\", \"the color ones\") or \"outline\" (\"we'll color them\", \"the outline ones\", \"plain\", "
           + "\"coloring pages\"). Moves the highlight, like tapping that set; the result says the one line to say.",
           ["set": ["type": "string", "enum": ["color", "outline"]]], required: ["set"]),
        fn("next_scene", "PLAY STEP scene only: the kids want the next scene (\"next scene\", \"we're done\", \"what's "
           + "next\", \"finished\"). Does exactly what tapping the green Next scene button does (after the last scene: "
           + "The End). Say nothing: the app says the next scene.", [:], required: []),
        fn("read_job", "PLAY STEP scene only: a kid asks what their job is (\"what do I do, Pet Trainer?\", \"what's my "
           + "job?\"). The app reads that role's task out loud, like tapping its row. Say nothing.",
           ["role": ["type": "string", "description": "The role's title, as on the row (e.g. Pet Trainer)."]], required: ["role"]),
        fn("go_to_step", "After the hunt (print step, play step, The End): the kids want to go back to a step they already "
           + "did (\"print it again\", \"go back to the props\", \"back to the game\", \"back to the play step\"). The "
           + "steps are Pick, Props, Print, Play. Does exactly what tapping that step on the step rail does; the result says "
           + "the one line to say. \"Print it again\" = print; \"back to the last scene\" = play.",
           ["step": ["type": "string", "enum": ["pick", "props", "print", "play"]]], required: ["step"]),
        fn("start_planning", "Silent: you write the roles and the prop list on your clipboard for a moment (call it ONCE, "
           + "right before set_roles). When it returns, call set_roles, then show_next_prop, then announce both.",
           ["topic": ["type": "string", "enum": ["roles", "props"]]], required: ["topic"])
    ] }

    // MARK: Client events

    /// Round 31: a SPOKEN kid turn, transcribed on the iPad and name-scrubbed (`NameScrubber`): exactly one text item,
    /// the same shape as a typed turn. The app then asks for her reply (`response.create`, the usual tool-first rules).
    /// There is deliberately no client event that carries audio in this protocol (no `input_audio_buffer.*`).
    public static func kidSpokenTurn(_ text: String, id: String? = nil) -> [[String: Any]] { [userText(text, id: id)] }
    public static func userText(_ text: String, id: String? = nil) -> [String: Any] {
        var item: [String: Any] = ["type": "message", "role": "user", "content": [["type": "input_text", "text": text]]]
        if let id { item["id"] = id }   // round 21: a client id, so a late moderation flag can delete it
        return ["type": "conversation.item.create", "item": item]
    }
    public static func functionOutput(callID: String, output: String) -> [String: Any] {
        ["type": "conversation.item.create", "item": ["type": "function_call_output", "call_id": callID, "output": output]]
    }
    public static var responseCreate: [String: Any] { ["type": "response.create"] }
    /// The prop hunt's tools (round 7): a kid's hunt answer gets a tool-first response limited to these.
    public static let huntTools = ["mark_found", "swap_prop", "skip_prop", "show_next_prop", "finish_planning", "just_talk",
                                   "set_game", "set_theme", "set_player_count"]
    /// Round 19: a correction of the game, theme or count is possible on every step (the kid may fix it any time).
    public static let correctionTools = ["set_game", "set_theme", "set_player_count"]

    /// Tool-first kid turns (round 7, Haylee: no narration ever heard): the tools allowed in the FIRST response to a kid
    /// turn on each step. That response's audio is never played (it would be "let me set that up…"); she speaks in
    /// the follow-up, after the tool result.
    public static func kidTurnTools(step: PlanningStep, huntActive: Bool) -> [String]? {
        switch step {
        case .game: return ["set_game", "show_game_ideas", "set_theme", "just_talk"]
        case .theme: return ["set_theme", "set_game", "set_player_count", "just_talk"]
        case .players: return ["set_player_count", "set_theme", "set_game", "just_talk"]
        case .confirm: return ["confirm_plan", "set_game", "set_theme", "set_player_count", "just_talk"]
        case .props: return huntActive ? huntTools : nil
        case .roles, .finish: return nil
        }
    }
    /// Round 28: back on Pick after the confirm "yes" (the step rail or "back to pick"): only the count can change, so a
    /// kid turn is tool-first over the count (and the game/theme tools, which the app refuses with her line).
    public static let pickBackTools = ["set_player_count", "set_game", "set_theme", "go_to_step", "just_talk"]
    /// Round 23: after the hunt a kid turn is tool-first too, so "print it again" always moves (round 22's play turns
    /// were free replies, and live the model answered "Sure!" without moving, or narrated before the tool).
    public static func afterHuntTools(_ phase: Phase) -> [String]? {
        switch phase {
        case .kitReady: return ["start_play", "print_kit", "choose_print_set", "go_to_step", "just_talk"]
        case .scene: return ["next_scene", "read_job", "go_to_step", "just_talk"]
        case .end: return ["go_to_step", "just_talk"]
        default: return nil
        }
    }
    /// A response that must call one of `names` first (no speech): `tool_choice: required` over just those tools.
    /// Round 20 (cost): the response never carries its own `tools` (the session's ONE tools array stays the cached
    /// prefix). Which tools fit this step is said in `allowedToolsNote` (sent just before), and the app refuses any
    /// other tool this pass calls (`RealtimeSession`).
    public static func responseCreate(requiring names: [String]) -> [String: Any] {
        // Round 13: TEXT only, so no audio is generated for a response nobody hears (it was 2–3 s of narration audio
        // before the tool call); its text items are deleted afterwards.
        ["type": "response.create",
         "response": ["tool_choice": "required", "output_modalities": ["text"]] as [String: Any]]
    }
    /// Round 20: the silent pass's step tools, as a note after the cached prefix.
    public static func allowedToolsNote(_ names: [String]) -> [String: Any] {
        systemNote("(Silent, this turn only.) Call one or more of these tools now, and nothing else: \(names.joined(separator: ", ")). No speech.")
    }
    /// Round 20: the app's answer when a silent pass calls a tool that doesn't fit the step (it isn't run).
    public static func offStepOutput(_ name: String, allowed: [String]) -> String {
        "Not now: \(name) doesn't fit this step, nothing changed. Use one of: \(allowed.joined(separator: ", "))."
    }
    /// Round 13: a spoken response without `set_expression` (a face-only tool call ended the response and cost a whole
    /// extra round trip before she spoke). `tools: false` = speak right away, no tools at all (greeting, tap replies).
    /// Round 20 (cost): no per-response `tools` (the session's array is the cached prefix; set_expression is gone).
    public static func responseCreateSpoken(tools allowTools: Bool = true) -> [String: Any] {
        ["type": "response.create", "response": ["tool_choice": allowTools ? "auto" : "none"] as [String: Any]]
    }
    /// Removes an item from the conversation (the silent pass's text, which nobody heard).
    public static func deleteItem(_ id: String) -> [String: Any] { ["type": "conversation.item.delete", "item_id": id] }
    /// Speak a fixed line in Nutmeg's voice without adding it to the conversation (out-of-band response).
    /// A silent steering note for the model (never shown in the chat, never spoken as is).
    public static func systemNote(_ text: String) -> [String: Any] {
        ["type": "conversation.item.create",
         "item": ["type": "message", "role": "system", "content": [["type": "input_text", "text": text]]] as [String: Any]]
    }
    // Push-to-talk (decisions/2026-11-13-push-to-talk.md; round 31): hold → the iPad listens (on-device speech), release
    // → the words as a text item + response.create, a too-short hold → nothing. Pressing while she talks → cancel +
    // truncate what wasn't heard.
    /// Stops the response that is being generated (the kid pressed the mic while she talked).
    public static var responseCancel: [String: Any] { ["type": "response.cancel"] }
    /// Cuts her interrupted audio item at what the kid actually heard, so the model knows where she stopped.
    public static func truncate(itemID: String, audioEndMs: Int) -> [String: Any] {
        ["type": "conversation.item.truncate", "item_id": itemID, "content_index": 0, "audio_end_ms": max(0, audioEndMs)]
    }
    /// A hold shorter than this is a tap, not speech: nothing is sent.
    public static let minHoldSeconds = 0.3
    public static func sayExactly(_ line: String) -> [String: Any] {
        ["type": "response.create",
         "response": ["conversation": "none", "output_modalities": ["audio"], "tool_choice": "none",
                      // No conversation context (round 7): with it, the silence reminder improvised game ideas.
                      // Round 20 (cost): no `instructions` override, so the session's instructions + tools are the same
                      // cached prefix; the line goes in as the only input item.
                      "input": [(systemNote(sayExactlyInstructions(line))["item"] as? [String: Any]) ?? [:]] as [Any]] as [String: Any]]
    }
    /// Round 35 prep: the model of the scripted-lines session, nil = off. Round 44: ON by default (`CostFlags.miniLines`;
    /// `-PTMiniLines NO` turns it off for testing), in any build; `-PTMiniLines <model>` tries another.
    /// The session itself is configured exactly like the conversation (`VoiceSessionPlan`).
    public static var lineModel: String? {
        guard CostFlags.miniLines else { return nil }
        return CostFlags.modelArgument(CostFlags.miniLinesKey) ?? miniModel
    }
    public static func sayExactlyInstructions(_ line: String) -> String {
        "You are Nutmeg, a little stage-manager mouse (she/her). Your voice: \(voiceStyle) Say exactly this line, word for "
            + "word, and nothing else; never add sound effects or words like giggle: \"\(line)\""
    }

    /// What the session appends to a step tool's output before it goes back to the model. Outputs that already say
    /// exactly what to say (the recap, the count, a check-off) get nothing more (round 19: a generic "one short reaction"
    /// suffix fought the word-for-word recap).
    public static func outputSuffix(name: String, output: String, spokeFirst: Bool) -> String {
        if name == "set_roles" {
            return " Don't speak yet: call show_next_prop for the first prop first, then announce the roles and that prop together."
        }
        if ["set_player_count", "confirm_plan", "mark_found", "skip_prop"].contains(name) || output.contains("Say exactly")
            || output.contains("say exactly") || output.contains("Say nothing") { return "" }
        return spokeFirst
            ? " You ALREADY reacted out loud this turn: now say ONLY the next question with suggestions (or the instruction), no new reaction, no greeting."
            : " Speak once now: one short reaction, then the next question (or the instruction)."
    }

    /// Round 20 (cost): sorted keys, so the same session.update is byte-identical every time (a stable cached prefix).
    public static func json(_ obj: [String: Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    // MARK: Server events

    public enum Event: Equatable, Sendable {
        case sessionReady
        case audioDelta(Data)
        case audioDone
        /// Nutmeg's words streaming in (audio transcript delta), then the whole line.
        case transcriptDelta(String)
        case transcriptDone(String)
        case kidTranscript(String)
        case speechStarted, speechStopped
        /// One of her output items started (its id is needed to truncate it when she's interrupted).
        case outputItemAdded(id: String)
        case functionCall(name: String, callID: String, arguments: String)
        case responseCreated
        case responseDone
        case error(String)
        case other(String)
    }

    public static func parse(_ text: String) -> Event {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let type = obj["type"] as? String else { return .other("unparsable") }
        switch type {
        case "session.updated": return .sessionReady
        case "response.output_audio.delta":
            return .audioDelta((obj["delta"] as? String).flatMap { Data(base64Encoded: $0) } ?? Data())
        case "response.output_audio.done": return .audioDone
        case "response.output_audio_transcript.delta", "response.output_text.delta":
            return .transcriptDelta(obj["delta"] as? String ?? "")
        case "response.output_audio_transcript.done": return .transcriptDone(obj["transcript"] as? String ?? "")
        case "response.output_text.done": return .transcriptDone(obj["text"] as? String ?? "")
        case "conversation.item.input_audio_transcription.completed": return .kidTranscript(obj["transcript"] as? String ?? "")
        case "input_audio_buffer.speech_started": return .speechStarted
        case "input_audio_buffer.speech_stopped": return .speechStopped
        case "response.output_item.added":
            let item = obj["item"] as? [String: Any]
            guard item?["type"] as? String == "message", let id = item?["id"] as? String else { return .other(type) }
            return .outputItemAdded(id: id)
        case "response.function_call_arguments.done":
            return .functionCall(name: obj["name"] as? String ?? "", callID: obj["call_id"] as? String ?? "",
                                 arguments: obj["arguments"] as? String ?? "{}")
        case "response.created": return .responseCreated
        case "response.done": return .responseDone
        case "error":
            let e = obj["error"] as? [String: Any]
            return .error((e?["code"] as? String).map { "\($0): \(e?["message"] as? String ?? "")" } ?? (e?["message"] as? String ?? "error"))
        default: return .other(type)
        }
    }
}

/// Nutmeg's face, chosen by the model with `set_expression` (decisions/conversation-camera-and-expressions.md).
public enum NutmegExpression: String, CaseIterable, Sendable {
    case happy, excited, ooh, thinking, listening, oops

    /// Decodes `set_expression` arguments; nil for any other call or a bad value.
    public static func decode(name: String, arguments: String) -> (expression: NutmegExpression, seconds: Double?)? {
        guard name == "set_expression",
              let obj = try? JSONSerialization.jsonObject(with: Data(arguments.utf8)) as? [String: Any],
              let e = (obj["expression"] as? String).flatMap({ NutmegExpression(rawValue: $0.lowercased()) }) else { return nil }
        let seconds = (obj["seconds"] as? NSNumber).map(\.doubleValue).flatMap { $0 > 0 ? min($0, 20) : nil }
        return (e, seconds)
    }

    /// A reply that opens with an exclamation gets a quick matching blip when the model set no face for the turn.
    public static func blip(forReplyStart text: String) -> NutmegExpression? {
        let first = text.lowercased().drop { !$0.isLetter }.prefix { $0.isLetter }
        switch first {
        case "ooh", "oooh", "ooo", "wow", "whoa", "woah", "oh": return .ooh
        case "yes", "yay", "yippee", "hooray", "woohoo": return .excited
        default: return nil
        }
    }
}

/// A planning step the Realtime model asked for (decoded from a function call).
public enum PlanningCall: Equatable, Sendable {
    public struct RoleDraft: Equatable, Sendable { public var roleName: String; public var job: String
        public init(roleName: String, job: String) { self.roleName = roleName; self.job = job } }
    public struct PropDraft: Equatable, Sendable {
        /// A PropLibrary ID, or free text when the model went off the list (fallback: generated art).
        public var itemID: String; public var becomes: String; public var forRole: String; public var alternates: [String]
        /// Round 24: why it works ("A bowl is round like a captain's hat!"); empty = the app writes one.
        public var reason: String
        public init(itemID: String, becomes: String, forRole: String, alternates: [String] = [], reason: String = "") {
            self.itemID = itemID; self.becomes = becomes; self.forRole = forRole; self.alternates = alternates; self.reason = reason
        }
        public var inLibrary: Bool { PropLibrary.contains(itemID) }
    }
    case showGameIdeas([GameIdea])
    case setGame(String)
    case setTheme(String)
    case setPlayerCount(Int)
    case setRoles([RoleDraft])
    case showProps([PropDraft])
    case showNextProp(PropDraft)
    case markFound(String)
    case swapProp(oldID: String, newID: String, becomes: String)
    case skipProp(String)
    case finishPlanning
    /// Round 19: the kids said yes to the recap (step 3b).
    case confirmPlan
    case justTalk, startPlay, printKit
    /// Round 27: "color" / "we'll color them" on the Print step: which set the printer prints.
    case choosePrintSet(PrintStyle)
    /// Round 29 (ensemble scenes): "next scene" / "we're done" in a scene, same as the green ▶ Next scene button.
    case nextScene
    /// Round 34: "what do I do, Pet Trainer?" in a scene: the app reads that role's spoken task (its row's 🔊).
    case readJob(String)
    /// Round 23: "print it again", "go back to the props": the same navigation as tapping a step on the rail.
    case goToStep(JourneyStep)

    public static func decode(name: String, arguments: String) -> PlanningCall? {
        let a = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8)) as? [String: Any]) ?? [:]
        func s(_ d: [String: Any], _ k: String) -> String { (d[k] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        let list = { (k: String) in a[k] as? [[String: Any]] ?? [] }
        switch name {
        case "show_game_ideas":
            let ideas = list("ideas").enumerated().compactMap { i, d -> GameIdea? in
                let t = s(d, "title"); return t.isEmpty ? nil : GameIdea(id: "idea\(i)", title: t, emoji: "", pitch: s(d, "pitch"))
            }
            return ideas.isEmpty ? nil : .showGameIdeas(Array(ideas.prefix(Sanitizer.Limits.ideas)))
        case "set_game":
            let t = s(a, "title"); return t.isEmpty ? nil : .setGame(t)
        case "set_theme":
            let t = s(a, "title"); return t.isEmpty ? nil : .setTheme(t)
        case "set_player_count":
            guard let count = (a["count"] as? Int) ?? (a["count"] as? Double).map(Int.init) else { return nil }
            // Round 23: a number over the cap is kept (up to 99) so the store can say "up to six friends can play".
            return .setPlayerCount(max(1, min(count, 99)))
        case "set_roles":
            let roles = list("roles").map { RoleDraft(roleName: s($0, "role_name"), job: s($0, "job")) }
                .filter { !$0.roleName.isEmpty }
            return roles.isEmpty ? nil : .setRoles(roles)
        case "show_next_prop":
            let id = s(a, "item_id")
            guard !id.isEmpty else { return nil }
            return .showNextProp(PropDraft(itemID: id, becomes: s(a, "becomes"), forRole: s(a, "for_role"),
                                           alternates: (a["alternates"] as? [String] ?? []).filter(PropLibrary.contains).prefix(2).map { $0 },
                                           reason: s(a, "reason")))
        case "mark_found":
            let id = s(a, "id"); return id.isEmpty ? nil : .markFound(id)
        case "show_props":
            let props = list("props").map {
                PropDraft(itemID: s($0, "item_id").isEmpty ? s($0, "household_item") : s($0, "item_id"), becomes: s($0, "becomes"),
                          forRole: s($0, "for_role"),
                          alternates: ($0["alternates"] as? [String] ?? []).filter(PropLibrary.contains).prefix(2).map { $0 })
            }.filter { !$0.itemID.isEmpty }
            return props.isEmpty ? nil : .showProps(props)
        case "swap_prop":
            let old = s(a, "old_id"), new = s(a, "new_id")
            return old.isEmpty || new.isEmpty ? nil : .swapProp(oldID: old, newID: new, becomes: s(a, "becomes"))
        case "skip_prop":
            let id = s(a, "id"); return id.isEmpty ? nil : .skipProp(id)
        case "finish_planning": return .finishPlanning
        case "confirm_plan": return .confirmPlan
        case "just_talk": return .justTalk
        case "start_play": return .startPlay
        case "print_kit": return .printKit
        case "choose_print_set": return PrintStyle(choice: s(a, "set")).map { .choosePrintSet($0) }
        case "next_scene": return .nextScene
        case "read_job": let r = s(a, "role"); return r.isEmpty ? nil : .readJob(r)
        case "go_to_step": return BackNav.toolSteps[s(a, "step").lowercased()].map { .goToStep($0) }
        default: return nil
        }
    }
}

/// The chat panel's transcript (in memory only; PretendThat stores nothing). Every turn in order: the kid's typed
/// messages the moment they're sent, the kid's SPOKEN turns (round 31: the on-device words, name-scrubbed, as sent), and
/// Nutmeg's replies streamed from the audio-transcript deltas, finalized by the done event.
public struct RealtimeTranscript: Equatable, Sendable {
    public struct Line: Identifiable, Equatable, Sendable {
        public let id: UUID; public let fromNutmeg: Bool; public var text: String
        public init(id: UUID = UUID(), fromNutmeg: Bool, text: String) { self.id = id; self.fromNutmeg = fromNutmeg; self.text = text }
    }
    public private(set) var lines: [Line] = []
    /// Index of Nutmeg's line that is still streaming, and the text it had before this response (a merged reply).
    private var streaming: Int?
    private var streamPrefix = ""
    /// Her next words start a NEW bubble (a silence re-ask is its own turn, not more of the last reply).
    private var separateNext = false
    public init() {}

    /// The next Nutmeg line gets its own bubble instead of joining her previous one.
    public mutating func breakTurn() { separateNext = true; streaming = nil }

    public mutating func kidTyped(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { lines.append(Line(fromNutmeg: false, text: t)) }
    }

    /// Round 21: a typed line that moderation flagged after it was sent comes back out of the chat (with anything
    /// she said after it).
    public mutating func retractKid(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = lines.lastIndex(where: { !$0.fromNutmeg && $0.text == t }) else { return }
        lines.removeSubrange(i...)
        streaming = nil; separateNext = true
    }

    /// Feeds one server event; returns true if the transcript changed.
    @discardableResult
    public mutating func apply(_ event: Realtime.Event) -> Bool {
        switch event {
        case .transcriptDelta(let d):
            guard !d.isEmpty else { return false }
            if let i = streaming { lines[i].text += d }
            else if !separateNext, let last = lines.indices.last, lines[last].fromNutmeg {
                // Her next response in the same turn (after a tool) continues the same bubble: one reply per kid turn.
                streamPrefix = lines[last].text + " "
                lines[last].text = streamPrefix + d.trimmingCharacters(in: .whitespaces); streaming = last
            } else { streamPrefix = ""; lines.append(Line(fromNutmeg: true, text: d)); streaming = lines.count - 1 }
            separateNext = false
            return true
        case .transcriptDone(let text):
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            defer { streaming = nil; streamPrefix = "" }
            if let i = streaming { if !t.isEmpty { lines[i].text = streamPrefix + t }; return true }
            guard !t.isEmpty else { return false }
            if !separateNext, let last = lines.indices.last, lines[last].fromNutmeg { lines[last].text += " " + t; return true }
            separateNext = false
            lines.append(Line(fromNutmeg: true, text: t)); return true
        case .kidTranscript(let text):
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return false }
            // A spoken turn finishes transcribing after Nutmeg may have started answering: keep it before her reply.
            if let i = streaming { lines.insert(Line(fromNutmeg: false, text: t), at: i); streaming = i + 1 }
            else { lines.append(Line(fromNutmeg: false, text: t)) }
            return true
        default: return false
        }
    }

    public mutating func clear() { lines = []; streaming = nil }

    /// Replaces the text of the last line (round 19's cut-off mark).
    mutating func replaceLast(_ text: String) { if let i = lines.indices.last { lines[i].text = text } }
}
