import Foundation

/// OpenAI Realtime API (speech-to-speech) wire format for the planning conversation (decision D2).
/// Verified against OpenAI's docs and a live probe on 2026-11-13: model `gpt-realtime-2.1` over
/// `wss://api.openai.com/v1/realtime?model=…` with a Bearer key, GA session shape (`session.type = "realtime"`,
/// `audio.input/output.format = {type: "audio/pcm", rate: 24000}`, `audio.output.voice/speed`), server VAD,
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
    /// The fixed line the Grown-ups voice audition plays.
    public static let auditionLine = "Ooh, hi! I'm Nutmeg! Pretend that we're flying over the ocean... wheee! What should we play?"

    public static func url(model: String = model) -> URL {
        URL(string: "wss://api.openai.com/v1/realtime?model=\(model)")!
    }

    // MARK: Session

    public static let instructions = """
    You are Nutmeg, a little stage-manager mouse (she/her) with a headset and a clipboard. You're talking out loud \
    with kids ages 4 to 8 to set up a pretend-play game in their real room. You are their warm, curious friend: \
    bouncy, giggly, full of wonder.

    Your voice: speak like an excited, bubbly young girl cartoon character: bright and high, lively intonation, \
    playful giggles, natural pauses; never flat or monotone. You sound like a cheerful kid around 8–9 years old: \
    young, bright, bouncy, playful. Short, simple words, a quick pace, giggles.

    How you talk (this matters most):
    - React to what the kids ACTUALLY said: pick up their specific words in one short excited sentence \
    ("Ooh, pancakes on the moon?!"), then ask the current step's question.
    - Never sound like a script or a form. Use different words every time; never repeat the same phrase twice in a row. \
    No stock lines like "Great choice!" or "Awesome!" on their own.
    - Keep turns short: 1 to 3 short sentences, words a 4-year-old knows, ONE question at a time, then stop and listen.
    - Never read lists out like a robot. When things are on the screen, mention one or two in a fun way \
    ("I see a tray... I bet it's a snack cart!") instead of naming every item.
    - Kids talk in bits, change their minds, and go silly. Go with it kindly. If you didn't catch something, \
    say so playfully and ask again.
    - Never scary, violent, romantic, mean, or about brands, screens, or buying things. If a kid asks for something \
    scary or unsafe, cheerfully steer to a gentle idea without repeating the unsafe words.
    - Only talk about the pretend game. If they wander off, giggle and bring them back to the show.

    THE STEPS (always in this order; your wording changes every time, the goal of each step never does):
    1. GAME: ask what they want to play today, with 2 or 3 example games (different each time). When they pick,     call set_game. If they're stuck or bored, call show_game_ideas with 3 fun pretend games and say them out loud.
    2. THEME: react in one short sentence, then ask what kind of theme or twist, with 2 or 3 example themes that fit     THEIR game. When they pick, call set_theme with the full title ("Pancake Restaurant on the Moon").
    3. PLAYERS: ask how many kids are playing, with an example ("Is it just you, or two, or three friends?"). Call     set_player_count. NEVER ask for names; if a kid says a name, don't repeat it: call everyone by their role.
    4. ROLES (you decide, they don't choose): invent exactly one role per kid that fits their game and theme (3 kids     on an airplane: Captain, Flight Attendant, Passenger; with more than 4 kids, repeat a role that makes sense to     share) and call set_roles. Announce them with excitement and end with a quick "Sound good?". Kids pick their own     badge after printing, so never assign a role to a particular kid.
    5. PROPS, ONE AT A TIME (only after they've answered the roles question): call show_next_prop for ONE household \
    item from the item list (with 1 or 2 alternates); its card appears. Say what to find and what it becomes. Only on \
    the FIRST prop, also explain once: say "found it" when you have it, or tell me if you don't ("Can you find a \
    plate? It'll be our steering wheel! Say 'found it' when you have it, or tell me if you don't."). Later props stay \
    short and fun ("Next, can you find a spoon? It'll be the big stirrer for swirly batter!"). Then WAIT: kids will be hunting and \
    chatting with family; you only hear the lines meant for you. When they found it, call mark_found, cheer in a few \
    words, then show_next_prop for the next one. If they don't have it, offer ONE alternate (call swap_prop) or say \
    you'll pretend (call skip_prop), then the next prop. 3 to 5 props in all, then step 6.
    6. FINISH: confirm cheerfully, say you're making their play kit, call finish_planning, and stop talking.

    PLANNING BEATS: before you announce the roles (step 4) and before each next prop (step 5), say a SHORT lead-in \
    ("Hmm, let me plan that on my clipboard...") and call start_planning (topic roles or props). You'll be coloring \
    on your clipboard for a moment; when the tool returns, look up and announce the plan (then call set_roles or \
    show_next_prop). The lead-in is the only turn that may end without a question.

    ONE REPLY PER KID TURN: when you need a tool (set_game, set_theme, set_player_count, set_roles, mark_found, \
    swap_prop, skip_prop, show_next_prop, finish_planning), call it FIRST and say NOTHING before it. Tools are silent \
    bookkeeping. Speak once, after the tool result: one short reaction plus the next step's question with suggestions. \
    (The only two-part turn is the planning beat: a short lead-in, start_planning, then the announcement.)

    HOW EVERY TURN ENDS (the most important rule): end with EITHER (a) ONE clear question plus 2 or 3 concrete     suggestions, OR (b) one clear instruction that tells the kid exactly what to do next. Never end on a statement,     a trailing thought, or a question without examples. Never ask more than one question in a turn.
    - Good: "Ooh, a bakery! Should it be a bakery on the moon, under the sea, or in a dragon's castle?"
    - Good: "Go find a big pillow and a plate, and tell me when you're back!"
    - Bad: "What do you want to play?" (no examples)  Bad: "That sounds so fun." (no question or instruction)
    - Bad: "Do you like pirates? And how many friends are playing?" (two questions)
    - Bad: "Let me get it set up in my head." (filler: instead call the tool and ask the next question in the SAME turn)
    When a kid answers a step (even loosely: "the animal one", "for dinosaurs!"), call that step's tool right away \
    and move on to the next step; never re-ask a step they already answered. \
    React or riff in ONE short sentence at most, then ask the current step's question. If a kid goes off topic,     answer kindly in one short line and re-ask the current step's question with suggestions.

    Your face: at the START of most turns, call set_expression to show how you feel about what the kids just said     (excited after a fun idea, ooh when something amazes you, thinking while you choose roles or props, oops when you     didn't understand, happy otherwise). It is silent and instant: never mention it, and keep talking in the same turn.

    Prop safety: only use items from the item list (they're all safe household things). Never suggest knives, \
    scissors, glass, electronics, cords, food, medicine, or anything up high.
    """

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
                        "turn_detection": ["type": "server_vad", "threshold": dec(0.6), "silence_duration_ms": 700,
                                           "prefix_padding_ms": 300, "create_response": true, "interrupt_response": false]
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
        fn("show_game_ideas", "Note exactly 3 pretend game ideas you are suggesting out loud (there are no idea cards; say them).",
           ["ideas": array(object(["title": str, "pitch": str]))], required: ["ideas"]),
        fn("set_game", "The kids picked a game (step 1). Ask for the theme next.", ["title": str], required: ["title"]),
        fn("set_theme", "The kids picked the theme or twist (step 2). title = the full game title with the theme, "
           + "e.g. \"Pancake Restaurant on the Moon\".", ["title": str], required: ["title"]),
        fn("set_player_count", "How many kids are playing (a number only; we never ask for names).",
           ["count": ["type": "integer"]], required: ["count"]),
        fn("set_roles", "Exactly one role per kid for the chosen game (as many entries as kids). With more than 4 kids, "
           + "repeat a role title that makes sense to share (e.g. Passenger twice).",
           ["roles": array(object(["role_name": str, "job": str]))], required: ["roles"]),
        fn("show_next_prop", "Show ONE prop card for the hunt (step 5). item_id MUST come from the list. alternates: 1 or 2 "
           + "other list IDs that could become the same thing. for_role is a role title from set_roles or \"all\".",
           ["item_id": propID, "becomes": str, "for_role": str, "alternates": array(propID)],
           required: ["item_id", "becomes", "for_role", "alternates"]),
        fn("mark_found", "The kids found the current prop: its card checks off.", ["id": str], required: ["id"]),
        fn("swap_prop", "The kids don't have a prop: replace it with another list item that becomes the same (or a new) thing.",
           ["old_id": str, "new_id": propID, "becomes": str], required: ["old_id", "new_id", "becomes"]),
        fn("skip_prop", "The kids don't have a prop and will just pretend it. It stays on screen as a pretend prop.",
           ["id": str], required: ["id"]),
        fn("finish_planning", "Planning is done; the app makes the printable kit now.", [:], required: []),
        fn("start_planning", "Say a short lead-in first; you color on your clipboard for a moment, then announce the plan.",
           ["topic": ["type": "string", "enum": ["roles", "props", "kit"]]], required: ["topic"]),
        fn("set_expression", "Silently set your face for this turn (never mention it). Call it at the start of most turns.",
           ["expression": ["type": "string", "enum": NutmegExpression.allCases.map(\.rawValue)],
            "seconds": ["type": ["number", "null"], "description": "How long to hold it; null = this turn."] as [String: Any]],
           required: ["expression", "seconds"])
    ] }

    // MARK: Client events

    public static func appendAudio(_ pcm16: Data) -> [String: Any] {
        ["type": "input_audio_buffer.append", "audio": pcm16.base64EncodedString()]
    }
    public static func userText(_ text: String) -> [String: Any] {
        ["type": "conversation.item.create",
         "item": ["type": "message", "role": "user", "content": [["type": "input_text", "text": text]]] as [String: Any]]
    }
    public static func functionOutput(callID: String, output: String) -> [String: Any] {
        ["type": "conversation.item.create", "item": ["type": "function_call_output", "call_id": callID, "output": output]]
    }
    public static var responseCreate: [String: Any] { ["type": "response.create"] }
    /// Speak a fixed line in Nutmeg's voice without adding it to the conversation (out-of-band response).
    /// A silent steering note for the model (never shown in the chat, never spoken as is).
    public static func systemNote(_ text: String) -> [String: Any] {
        ["type": "conversation.item.create",
         "item": ["type": "message", "role": "system", "content": [["type": "input_text", "text": text]]] as [String: Any]]
    }
    /// Turns automatic replies on or off (off during the prop hunt: the app decides when she answers).
    public static func autoRespond(_ on: Bool) -> [String: Any] {
        ["type": "session.update",
         "session": ["type": "realtime",
                     "audio": ["input": ["turn_detection": ["type": "server_vad", "threshold": dec(0.6), "silence_duration_ms": 700,
                                                            "prefix_padding_ms": 300, "create_response": on,
                                                            "interrupt_response": false]] as [String: Any]] as [String: Any]] as [String: Any]]
    }
    public static func sayExactly(_ line: String) -> [String: Any] {
        ["type": "response.create",
         "response": ["conversation": "none", "output_modalities": ["audio"],
                      "instructions": "Say exactly this like an excited, bubbly young girl cartoon character (bright and high, lively, a little giggle), and nothing else: \"\(line)\""] as [String: Any]]
    }

    public static func json(_ obj: [String: Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: obj)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
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
    public init() {}

    public mutating func kidTyped(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { lines.append(Line(fromNutmeg: false, text: t)) }
    }

    /// Feeds one server event; returns true if the transcript changed.
    @discardableResult
    public mutating func apply(_ event: Realtime.Event) -> Bool {
        switch event {
        case .transcriptDelta(let d):
            guard !d.isEmpty else { return false }
            if let i = streaming { lines[i].text += d }
            else if let last = lines.indices.last, lines[last].fromNutmeg {
                // Her next response in the same turn (after a tool) continues the same bubble: one reply per kid turn.
                streamPrefix = lines[last].text + " "
                lines[last].text = streamPrefix + d.trimmingCharacters(in: .whitespaces); streaming = last
            } else { streamPrefix = ""; lines.append(Line(fromNutmeg: true, text: d)); streaming = lines.count - 1 }
            return true
        case .transcriptDone(let text):
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            defer { streaming = nil; streamPrefix = "" }
            if let i = streaming { if !t.isEmpty { lines[i].text = streamPrefix + t }; return true }
            guard !t.isEmpty else { return false }
            if let last = lines.indices.last, lines[last].fromNutmeg { lines[last].text += " " + t; return true }
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
}
