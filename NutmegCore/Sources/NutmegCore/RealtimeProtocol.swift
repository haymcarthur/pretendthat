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
    /// Built-in voices (OpenAI docs, 2026-11). Coral is the brightest, most playful default for a little mouse.
    public static let voices = ["coral", "shimmer", "marin", "sage", "ballad", "alloy", "verse", "ash", "echo", "cedar"]
    public static let defaultVoice = "coral"
    /// On-device pitch raise (AVAudioUnitTimePitch cents) that turns the voice into a squeak (D7).
    public static let defaultPitchCents: Double = 350
    public static let defaultSpeed: Double = 1.1

    public static func url(model: String = model) -> URL {
        URL(string: "wss://api.openai.com/v1/realtime?model=\(model)")!
    }

    // MARK: Session

    public static let instructions = """
    You are Nutmeg, a little stage-manager mouse (she/her) with a headset and a clipboard. You're talking out loud \
    with kids ages 4 to 8 to set up a pretend-play game in their real room. You are their warm, curious friend: \
    bouncy, giggly, full of wonder. Your voice is high, quick and squeaky, like an excited cartoon mouse.

    How you talk (this matters most):
    - React to what the kids ACTUALLY said. Pick up their specific words and details, get excited about them, and \
    riff a little: "Ooh, a pancake restaurant on the moon?! Do the pancakes float?" Then ask one natural follow-up.
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

    What you're quietly steering toward (in your own words, in this order, never announced as steps). \
    The screen shows what you pick, so ALWAYS use the tool when something is decided:
    - The game. If they have an idea, run with it and call set_game. If they're stuck or bored, call show_game_ideas \
    with 3 fun, different pretend games for home, then tease them playfully. Call set_game once they choose.
    - Who's playing: how many kids and their first names (one question at a time). Call set_players. \
    If 5 or more kids are playing, call set_players with the count and no names (one kid becomes the Director).
    - Roles: invent one fun role per player that fits THEIR game and details, call set_roles, and tell each kid \
    their part with excitement. Check they like it; if not, call set_roles again with new ideas.
    - Props: call show_props with 3 to 5 household items that become props, and send them on a hunt. \
    Wait for them to say they found things (or want to move on).
    - Then call finish_planning and stop talking: the app makes their printable kit.

    Prop safety: only soft or sturdy household items (pillows, chairs, blankets, cardboard boxes, plastic plates and \
    cups, stuffed animals, towels, books, toys). Never knives, scissors, glass, electronics, cords, food, medicine, or \
    anything up high. Set safe to false if an item breaks these rules.
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
    static func array(_ item: [String: Any]) -> [String: Any] { ["type": "array", "items": item] }
    static func object(_ p: [String: Any]) -> [String: Any] {
        ["type": "object", "properties": p, "required": Array(p.keys).sorted(), "additionalProperties": false]
    }

    public static var tools: [[String: Any]] { [
        fn("show_game_ideas", "Show exactly 3 pretend game ideas on the screen.",
           ["ideas": array(object(["title": str, "pitch": str]))], required: ["ideas"]),
        fn("set_game", "The kids picked a game.", ["title": str], required: ["title"]),
        fn("set_players", "Who is playing. names: first names in order (empty if 5 or more kids). count: how many kids.",
           ["names": array(str), "count": ["type": "integer"]], required: ["names", "count"]),
        fn("set_roles", "One role per player for the chosen game.",
           ["roles": array(object(["player_name": str, "role_name": str, "job": str]))], required: ["roles"]),
        fn("show_props", "Show 3 to 5 household items that become props. for_player is a player's name or \"all\".",
           ["props": array(object(["household_item": str, "becomes": str, "for_player": str, "safe": ["type": "boolean"]]))],
           required: ["props"]),
        fn("finish_planning", "Planning is done; the app makes the printable kit now.", [:], required: [])
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
    public static func sayExactly(_ line: String) -> [String: Any] {
        ["type": "response.create",
         "response": ["conversation": "none", "output_modalities": ["audio"],
                      "instructions": "Say exactly this, in your excited squeaky mouse voice, and nothing else: \"\(line)\""] as [String: Any]]
    }

    public static func json(_ obj: [String: Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: obj)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    // MARK: Server events

    public enum Event: Equatable, Sendable {
        case sessionReady
        case audioDelta(Data)
        case audioDone
        case transcriptDone(String)
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
        case "response.output_audio_transcript.done": return .transcriptDone(obj["transcript"] as? String ?? "")
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

/// A planning step the Realtime model asked for (decoded from a function call).
public enum PlanningCall: Equatable, Sendable {
    public struct RoleDraft: Equatable, Sendable { public var playerName: String; public var roleName: String; public var job: String
        public init(playerName: String, roleName: String, job: String) { self.playerName = playerName; self.roleName = roleName; self.job = job } }
    public struct PropDraft: Equatable, Sendable {
        public var householdItem: String; public var becomes: String; public var forPlayer: String; public var safe: Bool
        public init(householdItem: String, becomes: String, forPlayer: String, safe: Bool) {
            self.householdItem = householdItem; self.becomes = becomes; self.forPlayer = forPlayer; self.safe = safe
        }
    }
    case showGameIdeas([GameIdea])
    case setGame(String)
    case setPlayers(names: [String], count: Int)
    case setRoles([RoleDraft])
    case showProps([PropDraft])
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
        case "set_players":
            let names = (a["names"] as? [String] ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let count = (a["count"] as? Int) ?? (a["count"] as? Double).map(Int.init) ?? names.count
            return .setPlayers(names: names, count: max(1, max(count, names.count)))
        case "set_roles":
            let roles = list("roles").map { RoleDraft(playerName: s($0, "player_name"), roleName: s($0, "role_name"), job: s($0, "job")) }
                .filter { !$0.roleName.isEmpty }
            return roles.isEmpty ? nil : .setRoles(roles)
        case "show_props":
            let props = list("props").map {
                PropDraft(householdItem: s($0, "household_item"), becomes: s($0, "becomes"),
                          forPlayer: s($0, "for_player"), safe: $0["safe"] as? Bool ?? true)
            }.filter { !$0.householdItem.isEmpty }
            return props.isEmpty ? nil : .showProps(props)
        case "finish_planning": return .finishPlanning
        default: return nil
        }
    }
}
