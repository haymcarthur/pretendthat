import Foundation
import CryptoKit

// Round D3b (design 2026-11-15-saved-games-replay-design.md §D4, Haylee): replays use Nutmeg's REAL recorded voice.
// On a play, the app records the realtime output audio of its OWN scripted lines (the ones it sends with `sayExactly`:
// scene openings, task read-outs (round 29), Print lines, rail arrivals, the save and
// replay lines, The End). Never the kid's audio, never her conversational replies, never a transcript of anyone.
// A clip is kept only when her output transcript matches the script (the transcript gate). It is stored with the
// saved game (unsaved games discard theirs). On a replay the speaker plays the clip through the same pipeline
// (Varispeed 1.20, lip sync, barge-in). A line with no clip is said live once (same voice) and then saved; offline,
// the game pauses on it with a "please connect to Wi-Fi" note (Haylee's answer 1). Never the system / TTS voice.

/// What a recorded line is (metadata for the hit-rate log; never content about a kid).
public enum ClipKind: String, Codable, Sendable, CaseIterable {
    /// Round 29 (ensemble scenes): no hand-offs, checklists or cheers any more; a scene's opening line is `sceneIntro`.
    case sceneIntro, readout, printReady, draw, arrival, save, replay, end, kit
    case wifi, line
}

/// The text normalization shared by the clip key and the transcript gate (§D4.2, §D4.3): case, punctuation, quotes,
/// whitespace, "&" / "and", hyphens, and numerals vs words ("3" = "three").
public enum ClipText {
    public static func normalize(_ text: String) -> String {
        var s = text.lowercased()
        s = s.replacingOccurrences(of: "&", with: " and ")
        s = s.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
        // Apostrophes vanish ("let's" = "lets"); every other non-letter/digit is a space.
        s = String(s.compactMap { c -> Character? in
            if c == "'" { return nil }
            return c.isLetter || c.isNumber ? c : " "
        })
        let words = s.split(separator: " ").flatMap { w -> [String] in
            if let n = Int(w), let spelled = NumberWords.spell(n) {
                return spelled.split(separator: "-").map(String.init)   // "47" → "forty seven"
            }
            return [String(w)]
        }
        return words.joined(separator: " ")
    }
}

/// The clip key (§D4.3): SHA-256 hex, first 32 characters, of "v1|" + voiceID + "|" + normalize(line). The line text
/// already names the role where it matters ("Pass the iPad to the Navigator…"), so text + role is covered by the text.
public enum ClipKey {
    public static func make(line: String, voiceID: String) -> String {
        let digest = SHA256.hash(data: Data(("v1|" + voiceID + "|" + ClipText.normalize(line)).utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(32).description
    }
}

/// The transcript gate (§D4.2): her output transcript must say the requested line, after normalizing. This catches a
/// paraphrase ("tap Start" for "tap Let's play"), which is then never saved: the line stays never-said.
public enum TranscriptGate {
    public static func accepts(requested: String, transcript: String) -> Bool {
        let r = ClipText.normalize(requested)
        return !r.isEmpty && r == ClipText.normalize(transcript)
    }
}

/// Which role a line is about (R1…R6), from the role names it mentions (metadata only).
public enum ClipMeta {
    public static func role(of line: String, roles: [Role]) -> String? {
        let n = " " + ClipText.normalize(line) + " "
        // Longest names first ("Parrot Keeper" before "Keeper").
        for r in roles.sorted(by: { $0.roleName.count > $1.roleName.count }) {
            let name = ClipText.normalize(r.roleName)
            if !name.isEmpty && n.contains(" " + name + " ") { return r.id.rawValue }
        }
        return nil
    }

    public static func kind(of line: String) -> ClipKind {
        let l = line.trimmingCharacters(in: .whitespaces)
        if l == WiFiPause.spokenNote { return .wifi }
        if l.hasPrefix("Pretend that") || l.contains(" Pretend that") { return .sceneIntro }
        if l.hasPrefix("The end!") { return .end }
        if l.contains("on your shelf now") { return .save }
        if l == HandOffLines.printReady { return .printReady }
        if l.hasPrefix("Let's draw") || l.contains("Make one") || l.contains(", one for each friend") || l.hasPrefix("Next, draw") { return .draw }
        if l.contains("How many friends") || l.hasPrefix("Do you still have") || l.hasPrefix("No problem, we'll pretend")
            || l.hasPrefix("Next, do you still have") || l.contains(" too! Do you have ") || l == ReplayLines.savedGame || l.contains(" friends! Our crew") || l.hasPrefix("Just you!") { return .replay }
        if KitProgress.lines.values.contains(where: { $0.contains(l) }) { return .kit }
        if l.hasPrefix("Back to ") { return .arrival }
        return .line
    }
}

/// One app line the recorder was asked to capture (`tag` goes out as the `sayExactly` response's metadata and comes
/// back on response.created: only responses the app started with `sayExactly` can be recorded).
public struct ClipRequest: Equatable, Sendable {
    public let tag: String
    public let line: String
    public let kind: ClipKind
    public let role: String?
}

/// A line the recorder kept: her raw PCM16 24 kHz mono audio (before Varispeed), trimmed, plus the request.
public struct RecordedLine: Equatable, Sendable {
    public let request: ClipRequest
    public let pcm16: Data
    public var duration: Double { Double(pcm16.count / 2) / Realtime.sampleRate }
}

/// The recorder's bookkeeping (pure, unit-tested). The app feeds it the session's events by response id.
public struct ClipRecorder: Sendable {
    public enum Outcome: Equatable, Sendable {
        case kept(RecordedLine)
        case rejected(Reason)
        case notTracked
    }
    public enum Reason: String, Equatable, Sendable { case cancelled, incomplete, transcriptMismatch, tooShort, tooLong, noAudio }

    public static let minSeconds = 0.4
    /// Round 29: a scene's opening line reads up to 6 tasks in one reply (about 40 to 60 s), so the limit is 90 s.
    public static let maxSeconds = 90.0
    /// The most audio buffered for one line (a little over the 30 s limit; more is cut and the line rejected).
    static let maxBytes = Int((maxSeconds + 1) * Realtime.sampleRate) * 2

    private struct Capture: Sendable { var request: ClipRequest; var audio = Data(); var transcript = ""; var overflow = false }
    private var serial = 0
    private var requested: [String: ClipRequest] = [:]
    private var captures: [String: Capture] = [:]
    public init() {}

    /// The app is about to `sayExactly` this line with recording on: returns the tag for the response metadata.
    public mutating func request(line: String, kind: ClipKind, role: String?) -> ClipRequest {
        serial += 1
        let r = ClipRequest(tag: "pt\(serial)", line: line, kind: kind, role: role)
        requested[r.tag] = r
        if requested.count > 32, let oldest = requested.keys.sorted(by: { Int($0.dropFirst(2)) ?? 0 < Int($1.dropFirst(2)) ?? 0 }).first {
            requested[oldest] = nil   // a request whose response never came
        }
        return r
    }

    /// response.created: starts capturing ONLY when its metadata tag is one the app requested (a conversation reply,
    /// a silence reminder or anything else has no tag and is never captured).
    public mutating func created(responseID: String?, tag: String?) {
        guard let responseID, let tag, let r = requested.removeValue(forKey: tag) else { return }
        captures[responseID] = Capture(request: r)
    }

    public func isCapturing(_ responseID: String?) -> Bool { responseID.map { captures[$0] != nil } ?? false }

    public mutating func audio(responseID: String?, _ pcm16: Data) {
        guard let id = responseID, var c = captures[id] else { return }
        if c.audio.count + pcm16.count > Self.maxBytes { c.overflow = true } else { c.audio.append(pcm16) }
        captures[id] = c
    }

    public mutating func transcript(responseID: String?, _ text: String) {
        guard let id = responseID, var c = captures[id] else { return }
        c.transcript = text
        captures[id] = c
    }

    /// A stop (barge-in) cancelled these responses: their partial audio is dropped.
    public mutating func cancel(_ responseIDs: [String]) { for id in responseIDs { captures[id] = nil } }

    /// response.done: keep the clip only if the response completed, the transcript matches the script and the
    /// trimmed audio is 0.4–30 s.
    public mutating func done(responseID: String?, status: String?) -> Outcome {
        guard let id = responseID, let c = captures.removeValue(forKey: id) else { return .notTracked }
        if status == "cancelled" { return .rejected(.cancelled) }
        if let status, status != "completed" { return .rejected(.incomplete) }
        if c.overflow { return .rejected(.tooLong) }
        guard !c.audio.isEmpty else { return .rejected(.noAudio) }
        guard TranscriptGate.accepts(requested: c.request.line, transcript: c.transcript) else { return .rejected(.transcriptMismatch) }
        let trimmed = ClipAudio.trimSilence(c.audio)
        let secs = Double(trimmed.count / 2) / Realtime.sampleRate
        if secs < Self.minSeconds { return .rejected(.tooShort) }
        if secs > Self.maxSeconds { return .rejected(.tooLong) }
        return .kept(RecordedLine(request: c.request, pcm16: trimmed))
    }
}

/// Clip audio helpers (PCM16 little-endian, 24 kHz mono).
public enum ClipAudio {
    /// Leading and trailing silence is trimmed, keeping `keep` seconds (60 ms) on each side (§D4.2).
    public static func trimSilence(_ pcm16: Data, threshold: Int16 = 300, keep: Double = 0.06) -> Data {
        let n = pcm16.count / 2
        guard n > 0 else { return pcm16 }
        var first = -1, last = -1
        pcm16.withUnsafeBytes { raw in
            let s = raw.bindMemory(to: Int16.self)
            for i in 0..<n where abs(Int(Int16(littleEndian: s[i]))) > Int(threshold) { first = i; break }
            if first >= 0 { for i in stride(from: n - 1, through: 0, by: -1) where abs(Int(Int16(littleEndian: s[i]))) > Int(threshold) { last = i; break } }
        }
        guard first >= 0 else { return Data() }   // all silence
        let pad = Int(keep * Realtime.sampleRate)
        let a = max(0, first - pad), b = min(n, last + 1 + pad)
        return pcm16.subdata(in: (a * 2)..<(b * 2))
    }

    /// Float samples (−1…1) from PCM16, for playback and tests.
    public static func floats(_ pcm16: Data) -> [Float] {
        let n = pcm16.count / 2
        return pcm16.withUnsafeBytes { raw in
            let s = raw.bindMemory(to: Int16.self)
            return (0..<n).map { Float(Int16(littleEndian: s[$0])) / 32768 }
        }
    }

    /// The ~100 ms chunks a clip is fed to the speaker in (§D4.4).
    public static func chunks(count: Int, size: Int = 2400) -> [Range<Int>] {
        stride(from: 0, to: count, by: size).map { $0..<min(count, $0 + size) }
    }
}

/// The current game's clip index: lookup by normalized text, so a clip recorded in an older voice ID still plays
/// (her voice never changes inside a game, §D4.5). Bundled common lines are the last stop before "never said".
public struct ClipIndex: Equatable, Sendable {
    public private(set) var byText: [String: SavedClip] = [:]
    public private(set) var common: [String: String] = [:]   // normalized text → bundled key
    public init(clips: [SavedClip] = [], commonKeys: [String: String] = [:]) {
        for c in clips { byText[ClipText.normalize(c.text)] = c }
        for (text, key) in commonKeys { common[ClipText.normalize(text)] = key }
    }
    public enum Hit: Equatable, Sendable { case game(SavedClip), common(key: String) }
    public func hit(for line: String) -> Hit? {
        let n = ClipText.normalize(line)
        if let c = byText[n] { return .game(c) }
        if let k = common[n] { return .common(key: k) }
        return nil
    }
    public func has(_ line: String) -> Bool { hit(for: line) != nil }
    public mutating func add(_ clip: SavedClip) { byText[ClipText.normalize(clip.text)] = clip }
    public var gameClips: [SavedClip] { byText.values.sorted { $0.key < $1.key } }
}

/// How a line is said (§D4.4–D4.6 + Haylee's answer 1).
public enum LineRoute: Equatable, Sendable {
    /// Her recorded clip, through the same speaker pipeline.
    case clip
    /// Said live by the Realtime voice (`sayExactly`); `record` = captured and kept if it passes the gate.
    case live(record: Bool)
    /// A replay, offline, and this line was never recorded: the Wi-Fi note, and the game pauses on the line.
    case waitForNetwork
    /// No clip and no live voice on a first play (the existing reconnect / tap-fallback behavior).
    case unavailable

    public static func choose(hasClip: Bool, live: Bool, replay: Bool, recordable: Bool) -> LineRoute {
        if hasClip { return .clip }
        if live { return .live(record: recordable) }
        return replay ? .waitForNetwork : .unavailable
    }
}

/// Haylee's answer 1: offline on a replay, a line she never said → a friendly note asks a grown-up to connect to
/// Wi-Fi, and the game PAUSES on that line until the connection is back (never silent text, never another voice).
public struct WiFiPause: Equatable, Sendable {
    public static let note = "Nutmeg needs the internet to say this part. Grown-ups, please connect to Wi-Fi so Nutmeg can talk!"
    /// Said from her bundled clip (her real voice, recorded once in development), never live (there's no network).
    public static let spokenNote = "Oops! I need the internet to say this part. Can a grown-up please connect to Wi-Fi?"
    /// The line she owes (the newest wins: the screen is paused, so nothing else should come).
    public private(set) var owed: String?
    public init() {}
    public var isPaused: Bool { owed != nil }
    public mutating func owe(_ line: String) { owed = line }
    /// The network is back and the voice is live: the owed line to say now (then the pause ends).
    public mutating func resume(live: Bool) -> String? {
        guard live, let line = owed else { return nil }
        owed = nil
        return line
    }
    public mutating func clear() { owed = nil }
}

/// The replay's hit-rate log (§8): counts only, never any content.
public struct ClipHitLog: Equatable, Sendable {
    public private(set) var clips = 0, common = 0, live = 0, saved = 0, rejected = 0, waited = 0
    public private(set) var byKind: [ClipKind: (hit: Int, total: Int)] = [:]
    public init() {}
    public var total: Int { clips + common + live + waited }
    public var hitRate: Double { total == 0 ? 0 : Double(clips + common) / Double(total) }
    public mutating func note(_ route: LineRoute, common isCommon: Bool = false, kind: ClipKind) {
        var k = byKind[kind] ?? (0, 0)
        k.total += 1
        switch route {
        case .clip: if isCommon { common += 1 } else { clips += 1 }; k.hit += 1
        case .live: live += 1
        case .waitForNetwork: waited += 1
        case .unavailable: k.total -= 1
        }
        byKind[kind] = k
    }
    public mutating func savedOne() { saved += 1 }
    public mutating func rejectedOne() { rejected += 1 }
    public var line: String {
        let kinds = byKind.keys.sorted { $0.rawValue < $1.rawValue }.map { "\($0.rawValue) \(byKind[$0]!.hit)/\(byKind[$0]!.total)" }
        return "clips hit \(clips + common)/\(total) (\(String(format: "%.0f%%", hitRate * 100))): game \(clips), bundled \(common), "
            + "live \(live), saved \(saved), rejected \(rejected), waited for Wi-Fi \(waited); " + kinds.joined(separator: ", ")
    }
    public static func == (a: ClipHitLog, b: ClipHitLog) -> Bool {
        a.clips == b.clips && a.common == b.common && a.live == b.live && a.saved == b.saved && a.rejected == b.rejected && a.waited == b.waited
    }
}

/// §D4.6: generic whole lines recorded once in development from her real Realtime voice (the same pipeline), bundled
/// with the app as AAC (ADTS `.aac`). They cover offline moments and make generic lines sound recorded on a first replay.
public enum CommonLines {
    public static let all: [String] = [
        WiFiPause.spokenNote,
        HandOffLines.printReady,
        ReplayLines.savedGame,
        ReplayLines.howMany,
        "No problem, we'll pretend!",
        "Almost ready!",
        OnboardingCopy.getAGrownUp,   // round 33: the parent onboarding's two lines (screen 1 and the hand-off)
        OnboardingCopy.greetKid,
    ] + GameGreeting.all   // round 33: the New game greetings (first-game intro + short variants)
    /// The bundled clip key (the current voice).
    public static func key(_ line: String) -> String { ClipKey.make(line: line, voiceID: VoiceConfig.nutmeg.voiceID) }
}

extension LineDeck {
    /// §D4.3 clip-aware draw: on a replay, pick first from the variants that already have a clip in this game; only
    /// when none has one, the usual draw (so variety still grows a little over many plays).
    public mutating func drawPreferring<G: RandomNumberGenerator>(_ key: String, from pool: [String], recorded: (String) -> Bool,
                                                                 using rng: inout G) -> String? {
        let have = pool.filter(recorded)
        if !have.isEmpty { return draw(key + ".rec", from: have, using: &rng) }
        return draw(key, from: pool, using: &rng)
    }
}

extension Realtime {
    /// `sayExactly` with recording on: the same response plus a metadata tag the recorder matches on response.created.
    /// (Metadata isn't model input: the cached prefix and the line's words are unchanged.)
    public static func sayExactly(_ line: String, tag: String) -> [String: Any] {
        var e = sayExactly(line)
        if var r = e["response"] as? [String: Any] { r["metadata"] = ["pt_line": tag]; e["response"] = r }
        return e
    }

    /// The recorder's tag on a response.created / response.done (nil for every response without one).
    public static func lineTag(_ text: String) -> String? {
        guard text.contains("\"pt_line\""), let r = text.range(of: "\"pt_line\":\"") else { return nil }
        let rest = text[r.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    /// A response.done's status ("completed", "cancelled", "incomplete", "failed").
    public static func responseStatus(_ text: String) -> String? {
        guard text.contains("\"response.done\""),
              let obj = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let r = obj["response"] as? [String: Any] else { return nil }
        return r["status"] as? String
    }
}

extension SavedGame {
    /// The clip file name inside the game folder: AAC-LC in an ADTS stream (`.aac`). [Claude's call, round D3b: the
    /// .m4a writer reserves 32 KB of header space per file, 10–30× the audio of a short line; ADTS has none. The
    /// encoder's 2112 priming samples are trimmed on decode.]
    public static func clipFile(_ key: String) -> String { "clips/\(key).aac" }
}
