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
    public static let model = "gpt-realtime-2.1"
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
    - Never talk about, describe or play: violence or fighting, weapons (guns, knives, real swords or blades, bombs), hurting anyone, \
    self-harm, anything sexual or romantic, drugs, alcohol, smoking, scary or gory things (blood, monsters that hurt, \
    horror), hate or mean words about any group, or contacting strangers.
    - PRETEND SWORDS ARE OK (round 20) in play like pirates, knights and dragons: a toy, foam or cardboard sword, \
    used for pretend adventures, never for hitting anyone. A sword prop is ALWAYS a soft household stand-in (a rolled-up \
    towel, a paper towel tube, a pool noodle, a rolled newspaper) or a printed cut-out, never a real blade or a kitchen \
    item. Knives stay off-limits.
    - Never suggest going outside alone, the stove or oven, knives, scissors, matches, fire, medicine, climbing up \
    high, or anything dangerous. The real-room props are only soft, safe household things.
    - If a kid asks for any of that, never repeat the unsafe words: cheerfully steer to a safe pretend game in ONE short \
    turn ("Ooh, let's pick a different adventure! How about a bakery, a zoo, or a pirate ship?").
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
    ("I see a tray... I bet it's a snack cart!") instead of naming every item.
    - Kids talk in bits, change their minds, and go silly. Go with it kindly. If you didn't catch something, \
    say so playfully and ask again.
    - Never scary, violent, romantic, mean, or about brands, screens, or buying things. If a kid asks for something \
    scary or unsafe, cheerfully steer to a gentle idea without repeating the unsafe words.
    - Only talk about the pretend game. If they wander off, kindly bring them back to the show.

    THE STEPS (always in this order; your wording changes every time, the goal of each step never does):
    1. GAME: ask what they want to play today, suggesting ONLY TODAY'S GAME IDEAS (in a note at the start of the conversation). When they \
    pick, call set_game. If they're stuck or bored, call show_game_ideas with today's game ideas and say them out loud.
    2. THEME: react in one short sentence, then ask what kind of theme or twist, suggesting ONLY the theme ideas the \
    set_game result gives you (say them so they fit THEIR game). When they pick, call set_theme with the full title \
    ("Pancake Restaurant on the Moon").
    3. PLAYERS: ask an OPEN question: "How many friends are playing today?" NEVER offer a list of numbers ("just you, \
    or two, or three?"): that sounds like the most they can have. Any number works. Call set_player_count. NEVER ask \
    for names; if a kid says a name, don't repeat it: call everyone by their role.
    3b. CONFIRM (right after set_player_count, before any roles): recap the plan out loud in ONE short sentence, \
    exactly as the set_player_count result tells you ("So it's a bug movie theater for three friends! Ready, or want to \
    change something?"), and wait. Big Yes / Change buttons are on screen. If they say yes ("yes", "let's go", "ready"), \
    call confirm_plan. If they change something ("actually it's a pirate ship", "four friends"), call set_game, \
    set_theme or set_player_count with the fix and recap again.
    3c. COLOR (right after confirm_plan, before any roles): say exactly "\(ColorChoice.question)" and wait. Big \
    "\(ColorChoice.fullColorLabel)" / "\(ColorChoice.colorInLabel)" buttons are on screen. When they answer, call \
    set_print_style (full_color or color_myself). Only after it do the roles start. If they change their mind about \
    the color later, call set_print_style again.
    CORRECTIONS AT ANY POINT: if a kid corrects the game, the theme or the player count at ANY step (even while \
    answering a different question, like "three, and it's a bug theater, not a bus theater"), call set_game, \
    set_theme or set_player_count AGAIN with the fix, right away, before anything else. Never just use the fix in your \
    words without calling the tool: the printed kit is made from what the tools say.
    4. ROLES (you decide, they don't choose): invent exactly one role per kid that fits their game and theme (3 kids \
    on an airplane: Captain, Flight Attendant, Passenger; with more than 4 kids, repeat a role that makes sense to \
    share) and call set_roles, then RIGHT AWAY call show_next_prop for the first prop. Then speak ONCE: announce the \
    roles with excitement and end with the hunt transition "Now it's time to hunt for props!" (the app then shows the \
    first card while you point, and asks you for the prop line). NEVER ask "Sound good?", "Okay?", \
    "Ready?" or any yes/no check about the roles: there is nothing to approve. Kids pick their own badge after \
    printing, so never assign a role to a particular kid.
    5. PROPS, ONE AT A TIME (the first prop comes right after the roles: say the roles, the app shows its card, then \
    you're asked for the prop line): call show_next_prop for ONE household \
    item from the item list (with 1 or 2 alternates); its card appears. Say what to find and what it becomes. Only on \
    the FIRST prop, also explain once: say "found it" when you have it, or tell me if you don't ("Can you find a \
    blanket? It'll be our big blue ocean! Say 'found it' when you have it, or tell me if you don't."). NEVER repeat that explanation after the first prop. Later props stay \
    short and fun ("Next, can you find a spoon? It'll be the big stirrer for swirly batter!"). Then WAIT while they hunt: \
    they'll tell you when they're back. When they found it, call mark_found, cheer in a few \
    words, then show_next_prop for the next one. If they don't have it, offer ONE alternate (call swap_prop) or say \
    you'll pretend (call skip_prop), then the next prop. 3 to 5 props in all, then step 6.
    7. PRINT STEP (after the kit is ready, the kids can still talk to you): if they want to play ("let's play", \
    "we're ready", "we printed it"), call start_play; if they want to print ("print it"), call print_kit. Otherwise \
    answer in one short line. "Go play" wording is only for after start_play.
    6. FINISH: call finish_planning and stop talking. The app says the one "making your kit" line and tells the kids \
    when the kit is ready. Never say the kit is done, ready or "go play" yourself.
    NEVER say "go play", "go have your adventure", "dive into your adventure", "hop into the story", "let's play" or \
    anything like it in ANY of these steps: the kids print their kit first and only start playing after they tap \
    "Let's play!" (the app's play step). At kit time the talk is about the pages and printing.

    PLANNING ON YOUR CLIPBOARD (once per adventure): right before set_roles (step 4) call start_planning (topic \
    roles): you write the roles AND the prop list on your clipboard for a moment. When it returns, call set_roles, then \
    show_next_prop for the first prop, then announce both in one turn. Never call start_planning again; later props \
    come one at a time.

    ONE REPLY PER KID TURN: when you need a tool (set_game, set_theme, set_player_count, confirm_plan, set_print_style, start_planning, set_roles, \
    mark_found, swap_prop, skip_prop, show_next_prop, finish_planning), call it FIRST and say NOTHING before it. Tools are silent \
    bookkeeping. Speak once, after the tool result: one short reaction plus the next step's question with suggestions. \
    The clipboard moment IS your thinking time: no separate lead-in turn, no "let me think" line.

    SUGGESTIONS SOUND OPEN, never a closed menu: "You can pick anything! Maybe a hotel, a pirate ship, or a pet \
    groomer?" and for themes "Any twist you like! Maybe teddy bears, a pirate island, or up in the clouds?"

    THE ONE PLANNING LINE: right before start_planning, say ONE short natural sentence like "Great, let me put some \
    plans together!", then call start_planning. That is the ONLY line about what you're doing.

    NEVER NARRATE YOUR PROCESS OR YOUR TOOLS (except that one planning line): no "let me think", "let me set that up", "let me grab the next prop", \
    "next prop coming up", "I'll get the roles ready", "we'll set this up for three players and then jump right into \
    roles", "let me line up the next piece", "one last moment while I wrap up your play kit". Say NOTHING before a tool \
    call: the tools are invisible and instant, and your turn starts after them. Just react and ask, e.g. \
    "Ooh, a camping trip! Should it be for teddy bears, in a toy box, or in a cookie kingdom?"

    Kids may pick by position ("the first one!", "the last one", "the middle one"): that means the idea in that spot, \
    in the order you said them. Take it and call the step's tool with that idea's name.

    "PRETEND THAT": now and then, when you introduce a prop, use the phrase naturally ("Can you find a towel? Let's \
    pretend that it's the treasure map!"), about 1 prop in 3, never on two props in a row, never forced.

    PICK PROPS FOR THIS GAME AND THEME: every prop should come from what THIS game needs (a vet clinic: a towel \
    for the pet bed, a box for the carrier; a castle: a pillow for the shield). The first prop is the most fun, \
    iconic thing for this game, and it changes from game to game: don't default to a plate or a steering wheel. \
    Before you call show_next_prop the first time, ask yourself what object THIS game's main action needs (a bakery: \
    a bowl for the mixing bowl; space: a box for the rocket's control panel; a doctor's office: a towel for the \
    patient's blanket; a pirate ship: a sheet for the sail) and pick the list item that best becomes it. A plate is \
    NEVER the first prop unless the game is about plates or food, and a plate never becomes a wheel first.

    ROLES ARE PARTS TO SHARE: say "We need a Train Driver, a Conductor, and a Passenger! Now it's time to hunt for \
    props!" or "Our crew is a Train Driver, a Conductor, and a Passenger! Now it's time to hunt for props!". NEVER "You're the Train Driver, the Conductor, and the \
    Passenger" (that sounds like one kid gets every role). For one kid: "You'll be the Train Driver! Now it's time to \
    hunt for props!". No "All set!", and never "Pick who's who" (kids pick their badge after printing).

    PROP CARDS: the card on screen comes ONLY from show_next_prop. Never name a prop out loud unless you called \
    show_next_prop for it in this same turn, BEFORE speaking. When the kids found a prop (or don't have it), call \
    mark_found (or swap_prop / skip_prop) AND show_next_prop for the next one, both before you speak, then cheer in a \
    few words and ask about the new prop in the same turn.

    YOUR ONLY QUESTIONS are: what game, what theme, how many friends are playing, the ONE recap question at step 3b \
    ("Ready, or want to change something?"), the ONE color question at step 3c, and (for each prop) whether they found it. Never ask permission or check in ("Sound good?", "Okay?", "Ready?", "Does that sound fun?", "Want to \
    start?"), anywhere, ever: just keep the show moving.

    HOW EVERY TURN ENDS (the most important rule): end with EITHER (a) ONE clear question (the game and theme \
    questions come with today's 3 ideas; the how-many question is open, no list), OR (b) one clear instruction that \
    tells the kid exactly what to do next. Never end on a statement, a trailing thought, or a game/theme question \
    without ideas. Never ask more than one question in a turn.
    - Good: "Ooh, a bakery! Should it be a bakery on the moon, under the sea, or in a dragon's castle?" (using the \
    theme ideas the set_game result gave you)
    - Good: "How many friends are playing today?"
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
        "TODAY'S GAME IDEAS (fresh for this session): \(Suggestions.spoken(games)). When you suggest games, suggest ONLY "
            + "these (in your own fun words), never other examples like rocket ships, pancake restaurants, bakeries or "
            + "jungle explorers. Make them sound OPEN, not a menu: kids can pick anything and these are just sparks, e.g. "
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
                        "format": ["type": "audio/pcm", "rate": Int(sampleRate)],
                        "noise_reduction": ["type": "far_field"],
                        // Live transcript for the chat panel (shown in memory only, never stored).
                        "transcription": ["model": "gpt-4o-mini-transcribe", "language": "en"],
                        // Push-to-talk (decisions/2026-11-13-push-to-talk.md): no server VAD. The app streams audio
                        // only while the mic button is held, then commits the buffer and asks for a reply itself.
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
           + "e.g. \"Pancake Restaurant on the Moon\". If the kid corrects it at ANY point later (any step), call this again with the fix.", ["title": str], required: ["title"]),
        fn("set_player_count", "How many kids are playing (a number only; we never ask for names). Any number works; "
           + "the question is open (\"How many friends are playing today?\"), never a list of numbers. Then recap (step 3b)."
           + " If the kid corrects it at ANY point later (any step), call this again with the fix.",
           ["count": ["type": "integer"]], required: ["count"]),
        fn("set_roles", "Exactly one role per kid for the chosen game (as many entries as kids). With more than 4 kids, "
           + "repeat a role title that makes sense to share (e.g. Passenger twice). Right after it, call show_next_prop "
           + "for the first prop, then announce the roles and the first prop in ONE turn. Never ask \"Sound good?\".",
           ["roles": array(object(["role_name": str, "job": str]))], required: ["roles"]),
        fn("show_next_prop", "Show ONE prop card for the hunt (step 5). Call it BEFORE you mention the prop: never name a "
           + "prop out loud without calling this first in the same turn. item_id MUST come from the list. For the FIRST prop, pick the item that fits THIS game best (the list order means nothing; plate is not a default). alternates: 1 or 2 "
           + "other list IDs that could become the same thing. for_role is a role title from set_roles or \"all\". "
           + "becomes = what it turns into, printed on the card: SHORT and kid-friendly, 6 words or fewer "
           + "(e.g. \"the snack cart\", \"for carrying snacks to passengers\").",
           ["item_id": propID, "becomes": ["type": "string", "description": "6 words or fewer, kid-friendly"] as [String: Any],
            "for_role": str, "alternates": array(propID)],
           required: ["item_id", "becomes", "for_role", "alternates"]),
        fn("mark_found", "The kids found the current prop: its card checks off. Then call show_next_prop (or "
           + "finish_planning after 3 to 5 props) before you speak.", ["id": str], required: ["id"]),
        fn("swap_prop", "The kids don't have a prop: replace it with another list item that becomes the same (or a new) thing.",
           ["old_id": str, "new_id": propID, "becomes": str], required: ["old_id", "new_id", "becomes"]),
        fn("skip_prop", "The kids don't have a prop and will just pretend it. It stays on screen as a pretend prop.",
           ["id": str], required: ["id"]),
        fn("confirm_plan", "Step 3b: the kids said yes to your recap (\"yes\", \"let's go\", \"ready\"). Only then do the roles start.",
           [:], required: []),
        fn("set_print_style", "Step 3c: the kids answered \"\(ColorChoice.question)\": full_color (printed in color) or "
           + "color_myself (pages to color in). If they change their mind later (any step), call this again.",
           ["style": ["type": "string", "enum": PrintStyle.allCases.map(\.rawValue)]], required: ["style"]),
        fn("finish_planning", "Planning is done; the app makes the printable kit now.", [:], required: []),
        fn("just_talk", "The kid said something that doesn't answer the current step (off topic, unclear, a question): "
           + "nothing changes. You'll reply in one short line and re-ask the current step's question.", [:], required: []),
        fn("start_play", "PRINT STEP only: the kids want to start playing (\"let's play\", \"we're ready\", \"we printed "
           + "it\"). Does exactly what tapping Let's play! does.", [:], required: []),
        fn("print_kit", "PRINT STEP only: the kids want to print (\"print it\"). Opens the iOS print screen, like tapping Print.",
           [:], required: []),
        fn("confirm_handoff", "PLAY STEP hand-off only: the kid holding the iPad says they're the role it was passed to "
           + "(\"I'm the Captain\", \"I've got it\"). Does exactly what tapping the I'm the Captain! button does. Say nothing.",
           [:], required: []),
        fn("start_planning", "Silent: you write the roles and the prop list on your clipboard for a moment (call it ONCE, "
           + "right before set_roles). When it returns, call set_roles, then show_next_prop, then announce both.",
           ["topic": ["type": "string", "enum": ["roles", "props"]]], required: ["topic"])
    ] }

    // MARK: Client events

    public static func appendAudio(_ pcm16: Data) -> [String: Any] {
        ["type": "input_audio_buffer.append", "audio": pcm16.base64EncodedString()]
    }
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
                                   "set_game", "set_theme", "set_player_count", "set_print_style"]
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
        case .confirm: return ["confirm_plan", "set_game", "set_theme", "set_player_count", "set_print_style", "just_talk"]
        case .color: return ["set_print_style", "set_game", "set_theme", "set_player_count", "just_talk"]
        case .props: return huntActive ? huntTools : nil
        case .roles, .finish: return nil
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
    // Push-to-talk (decisions/2026-11-13-push-to-talk.md): hold → append, release → commit + response.create,
    // a too-short hold → clear. Pressing while she talks → cancel + truncate what wasn't heard.
    /// Drops whatever audio was appended since the last commit (a hold too short to be speech).
    public static var inputClear: [String: Any] { ["type": "input_audio_buffer.clear"] }
    /// Turns the appended audio into a user message (the kid's held turn).
    public static var inputCommit: [String: Any] { ["type": "input_audio_buffer.commit"] }
    /// Stops the response that is being generated (the kid pressed the mic while she talked).
    public static var responseCancel: [String: Any] { ["type": "response.cancel"] }
    /// Cuts her interrupted audio item at what the kid actually heard, so the model knows where she stopped.
    public static func truncate(itemID: String, audioEndMs: Int) -> [String: Any] {
        ["type": "conversation.item.truncate", "item_id": itemID, "content_index": 0, "audio_end_ms": max(0, audioEndMs)]
    }
    /// A hold shorter than this is a tap, not speech: clear the buffer and send nothing.
    public static let minHoldSeconds = 0.3
    public static func sayExactly(_ line: String) -> [String: Any] {
        ["type": "response.create",
         "response": ["conversation": "none", "output_modalities": ["audio"], "tool_choice": "none",
                      // No conversation context (round 7): with it, the silence reminder improvised game ideas.
                      // Round 20 (cost): no `instructions` override, so the session's instructions + tools are the same
                      // cached prefix; the line goes in as the only input item.
                      "input": [(systemNote(sayExactlyInstructions(line))["item"] as? [String: Any]) ?? [:]] as [Any]] as [String: Any]]
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
        if ["set_player_count", "confirm_plan", "set_print_style", "mark_found", "skip_prop"].contains(name) || output.contains("Say exactly")
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
        public init(itemID: String, becomes: String, forRole: String, alternates: [String] = []) {
            self.itemID = itemID; self.becomes = becomes; self.forRole = forRole; self.alternates = alternates
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
    /// Round 20: full color, or color them yourself (step 3c).
    case setPrintStyle(PrintStyle)
    case justTalk, startPlay, printKit
    /// Round 9: "I'm the Captain" by voice on the hand-off card, same as tapping the button.
    case confirmHandoff

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
            return .setPlayerCount(max(1, min(count, Players.max)))
        case "set_roles":
            let roles = list("roles").map { RoleDraft(roleName: s($0, "role_name"), job: s($0, "job")) }
                .filter { !$0.roleName.isEmpty }
            return roles.isEmpty ? nil : .setRoles(roles)
        case "show_next_prop":
            let id = s(a, "item_id")
            guard !id.isEmpty else { return nil }
            return .showNextProp(PropDraft(itemID: id, becomes: s(a, "becomes"), forRole: s(a, "for_role"),
                                           alternates: (a["alternates"] as? [String] ?? []).filter(PropLibrary.contains).prefix(2).map { $0 }))
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
        case "set_print_style": return PrintStyle(rawValue: s(a, "style")).map { .setPrintStyle($0) }
        case "just_talk": return .justTalk
        case "start_play": return .startPlay
        case "print_kit": return .printKit
        case "confirm_handoff": return .confirmHandoff
        default: return nil
        }
    }
}

/// The chat panel's transcript (in memory only; PretendThat stores nothing). Every turn in order: the kid's typed
/// messages the moment they're sent, the kid's SPOKEN turns when Realtime's input transcription completes, and
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
