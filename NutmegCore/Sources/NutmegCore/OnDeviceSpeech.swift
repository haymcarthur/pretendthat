import Foundation

// Round 31 (decisions/2026-11-16-on-device-speech.md, Haylee): kids' voices stay on the iPad. Push-to-talk audio is
// turned into words ON THE DEVICE (Apple Speech, on-device only); the audio is dropped at once and only the words, with
// name-like words replaced, go to the voice model as a text turn. These are the pure rules; the app does the audio.

/// Replaces name-like words in what a kid said before the text leaves the iPad. Simple, predictable rules (not a
/// general name detector): a capitalized word or two right after "my name is", "my name's", "I'm", "I am", "call me",
/// "this is", "it's", "his / her / their name is", or "my brother / sister / friend / mom / dad / cousin (is)"
/// becomes "[name]". The recognizer capitalizes proper names, so "I'm hungry" and "I'm the doctor" stay as they are.
/// Pretend names ("a dragon named Sparkle") are kept: they're the game, not a kid.
public enum NameScrubber {
    public static let token = "[name]"

    /// Lead-ins after which a capitalized word is taken as a person's name (lowercased, matched word by word).
    static let leadIns: [[String]] = [
        ["my", "name", "is"], ["my", "name's"], ["my", "names"], ["name", "is"], ["i'm"], ["im"], ["i", "am"],
        ["call", "me"], ["this", "is"], ["it's"], ["its"], ["it", "is"],
        ["his", "name", "is"], ["her", "name", "is"], ["their", "name", "is"], ["his", "name's"], ["her", "name's"],
    ]
    /// "my <relation> (is) <Name>"
    static let relations: Set<String> = ["brother", "sister", "friend", "mom", "mommy", "dad", "daddy", "cousin",
                                         "teacher", "grandma", "grandpa", "baby", "best"]
    /// Capitalized words that follow a lead-in but aren't names (sentence starts, titles of play, fillers).
    static let notNames: Set<String> = ["the", "a", "an", "ok", "okay", "not", "so", "done", "ready", "here", "there",
                                        "gonna", "going", "very", "really", "just", "still", "also", "and", "but",
                                        "yes", "no", "yeah", "nope", "fine", "good", "happy", "sad", "it", "that",
                                        "this", "your", "my", "his", "her", "their", "our", "nutmeg", "i", "me",
                                        "mr", "mrs", "ms", "miss", "doctor", "dr", "captain", "princess", "prince",
                                        "king", "queen", "chef", "officer", "friend"]

    public static func scrub(_ text: String) -> String {
        var words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return text }
        var i = 0
        while i < words.count {
            if let nameAt = nameStart(words, after: i) {
                let end = nameEnd(words, from: nameAt)
                if end > nameAt {
                    let trailing = trailingPunctuation(words[end - 1])
                    words.replaceSubrange(nameAt..<end, with: [token + trailing])
                    i = nameAt + 1
                    continue
                }
            }
            i += 1
        }
        return words.joined(separator: " ")
    }

    /// The index where a name would start if a lead-in begins at `i`.
    static func nameStart(_ words: [String], after i: Int) -> Int? {
        let lower = words.map { core($0).lowercased() }
        for lead in leadIns where i + lead.count <= words.count {
            if Array(lower[i..<(i + lead.count)]) == lead, !endsClause(words[i + lead.count - 1]) { return i + lead.count }
        }
        // my <relation> (is) <Name>   /   my best friend (is) <Name>
        if lower[i] == "my", i + 1 < words.count, relations.contains(lower[i + 1]), !endsClause(words[i + 1]) {
            var j = i + 2
            if lower[i + 1] == "best", j < words.count, lower[j] == "friend" { j += 1 }
            if j < words.count, lower[j] == "is" || lower[j] == "named" || lower[j] == "called" { j += 1 }
            return j
        }
        return nil
    }

    /// One or two capitalized, non-stop words starting at `start` (a first and a last name).
    static func nameEnd(_ words: [String], from start: Int) -> Int {
        var j = start
        while j < words.count, j < start + 2, isNameLike(words[j]) {
            j += 1
            if endsClause(words[j - 1]) { break }
        }
        return j
    }

    static func isNameLike(_ word: String) -> Bool {
        let w = core(word)
        guard let first = w.unicodeScalars.first, CharacterSet.uppercaseLetters.contains(first), w.count >= 2 else { return false }
        guard w.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" }) else { return false }
        return !notNames.contains(w.lowercased())
    }

    /// The word without surrounding punctuation ("Mia." → "Mia"; possessives kept as "Mia's").
    static func core(_ word: String) -> String {
        word.replacingOccurrences(of: "\u{2019}", with: "'").trimmingCharacters(in: CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "'-")))
    }
    static func trailingPunctuation(_ word: String) -> String {
        String(word.reversed().prefix { ".,!?;:".contains($0) }.reversed())
    }
    static func endsClause(_ word: String) -> Bool { word.last.map { ".,!?;:".contains($0) } ?? false }
}

/// Whether the iPad can listen on the device right now, and what to tell a grown-up when it can't (decided from
/// plain values so every case is testable). On-device only: there is NO fallback that sends audio anywhere.
public enum SpeechReadiness: Equatable, Sendable {
    case ready
    case notAskedYet
    case speechDenied
    case micDenied
    case restricted
    /// No English (US) recognizer, or this iPad can't recognize on the device, or its speech asset isn't installed.
    case onDeviceUnavailable

    public enum Permission: Sendable { case authorized, denied, restricted, notDetermined }

    public static func decide(speech: Permission, mic: Bool, recognizerExists: Bool, supportsOnDevice: Bool) -> SpeechReadiness {
        switch speech {
        case .notDetermined: return .notAskedYet
        case .denied: return .speechDenied
        case .restricted: return .restricted
        case .authorized: break
        }
        guard mic else { return .micDenied }
        guard recognizerExists, supportsOnDevice else { return .onDeviceUnavailable }
        return .ready
    }

    /// The mic can be used for a kid turn.
    public var canListen: Bool { self == .ready }
    /// Typing is the way to talk to Nutmeg (every case but ready).
    public var typingFallback: Bool { !canListen }

    /// One line for the Grown-ups screen.
    public var status: String {
        switch self {
        case .ready: return "On: speech is turned into words on this \(DeviceWord.noun) (voices never leave it)"
        case .notAskedYet: return "Off: speech permission not answered yet"
        case .speechDenied: return "Off: speech recognition permission is off"
        case .micDenied: return "Off: microphone permission is off"
        case .restricted: return "Off: speech recognition is restricted on this \(DeviceWord.noun)"
        case .onDeviceUnavailable: return "Off: on-device English speech isn't available on this \(DeviceWord.noun) yet"
        }
    }

    /// The friendly note for a grown-up when a kid presses the mic and it can't listen (nil when ready).
    public var grownUpPrompt: (title: String, message: String)? {
        let typing = " Until then, you can type what your kids say in the chat."
        switch self {
        case .ready: return nil
        case .notAskedYet:
            return ("Grown-ups: one quick yes", "Nutmeg needs the microphone and speech recognition to hear your kids. "
                    + "Their voices are turned into words right on this \(DeviceWord.noun) and never sent anywhere." + typing)
        case .speechDenied, .micDenied:
            return ("Grown-ups: Nutmeg can't hear yet", "Turn on Microphone and Speech Recognition for PretendThat in "
                    + "Settings › Privacy & Security. Voices are turned into words right on this \(DeviceWord.noun) and never sent anywhere." + typing)
        case .restricted:
            return ("Grown-ups: Nutmeg can't hear on this \(DeviceWord.noun)", "Speech recognition is restricted on this \(DeviceWord.noun) (Screen "
                    + "Time or a device profile)." + typing)
        case .onDeviceUnavailable:
            return ("Grown-ups: Nutmeg's ears need a download", "PretendThat only listens on the \(DeviceWord.noun) itself, so it needs "
                    + "Apple's on-device English (US) speech. Turn on Dictation in Settings › General › Keyboard with "
                    + "English (US), stay on Wi-Fi while it downloads, then try again." + typing)
        }
    }
}

/// What to do with a finished push-to-talk hold (pure: the session runs it).
public enum SpokenTurn: Equatable, Sendable {
    /// A tap-length hold: nothing is sent.
    case tooShort
    /// The kit is being made: one tiny "Almost ready!" at most, nothing sent.
    case almostReady
    /// Nothing was heard (empty words): nothing is sent; she may say one fixed "didn't catch that" line.
    case nothingHeard(sayHint: Bool)
    /// Send these words (already name-scrubbed) as a text turn.
    case send(String)

    /// A hold at least this long that heard nothing gets her one fixed hint line (a real try, not a slip).
    public static let hintAfterSeconds = 0.8

    public static func decide(words: String, held: Double, quickReplyOnly: Bool, minHold: Double = Realtime.minHoldSeconds) -> SpokenTurn {
        if held < minHold { return .tooShort }
        if quickReplyOnly { return .almostReady }
        let t = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return .nothingHeard(sayHint: held >= hintAfterSeconds) }
        return .send(NameScrubber.scrub(t))
    }

    /// Her one fixed line when a real hold heard nothing.
    public static let didntCatch = "Hmm, I didn't catch that. Hold the red button and tell me again!"
}
