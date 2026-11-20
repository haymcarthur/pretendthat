import Foundation

// 2026-11-18 (Haylee's device testing, decisions/2026-11-18-device-testing-fixes.md): the pure parts of four fixes.
// - The app comes back after idle / lock: what the foreground does (`ForegroundRecovery`), how a failed silent
//   reconnect retries (`ReconnectBackoff`), and when an idle socket counts as dead (`SocketHealth`).
// - "Sounds like a game you have": the kid's spoken answer, play the saved game or make a new one (`SavedOrNew`).
// - Play: Nutmeg looks UP at the kids while she says a line, DOWN at the rows otherwise (`PeekGaze`).

/// What the app does when it comes back to the foreground (scene phase `.active`).
public enum ForegroundRecovery: Equatable, Sendable {
    /// Nothing to bring back (no game, no voice for this game, or already coming back).
    case none
    /// The session was suspended in the background: ping it; restart the audio, or reconnect silently.
    case resume
    /// The session is gone (it failed while away, or a reconnect failed): reconnect silently with the game's state.
    case reconnect

    /// - suspended: the session was put to sleep by the background (round 9).
    /// - live / connecting: the session's status right now.
    /// - gameHadVoice: this game's conversation was live at some point (a voice was chosen for it).
    /// - inGame: the phase is past Hello (a game is on screen).
    /// - busy: a reconnect (or a resume) is already running.
    /// - offlineReplay: a replay running without a voice on purpose (offline: its recorded lines carry it).
    /// 2026-11-20 (decisions/2026-11-20-voice-stall-fix.md): a suspended session resumes EVEN while busy. A lock and
    /// unlock during a resume left `suspended` on in the foreground (no clips, no live voice); the resume itself runs
    /// once at a time (`ResumeLoop`) and goes again when it finds the session suspended with the app active.
    public static func decide(suspended: Bool, live: Bool, connecting: Bool, gameHadVoice: Bool, inGame: Bool,
                              busy: Bool, offlineReplay: Bool = false) -> ForegroundRecovery {
        guard inGame else { return .none }
        if suspended { return .resume }
        guard !busy, gameHadVoice, !live, !connecting, !offlineReplay else { return .none }
        return .reconnect
    }
}

/// A silent reconnect that fails (the network or the audio is often not ready the moment the phone unlocks) tries
/// again after a short wait, a few times, instead of leaving the game with no voice (taps and the mic did nothing).
public enum ReconnectBackoff {
    /// The wait before each try (seconds): the first try at once, then 1.5 s, 4 s and 8 s later.
    public static let delays: [Double] = [0, 1.5, 4, 8]
    /// The wait before try `attempt` (0-based); nil = give up (the next tap or foreground tries again).
    public static func delay(before attempt: Int) -> Double? {
        delays.indices.contains(attempt) ? delays[attempt] : nil
    }
}

/// Keepalive for the voice socket while the app sits idle in the foreground: a ping every `interval` seconds. A socket
/// that misses `maxMissed` pongs in a row is dead (a Wi-Fi or NAT drop the socket itself never reported), so the app
/// reconnects silently before the kids' next tap, instead of sending their turn into a dead socket.
public struct SocketHealth: Equatable, Sendable {
    public static let interval: Double = 20
    public static let maxMissed = 2
    public private(set) var missed = 0
    public init() {}
    /// Records one ping's result; true when the socket should now be treated as dead.
    public mutating func pinged(ok: Bool) -> Bool {
        missed = ok ? 0 : missed + 1
        return missed >= Self.maxMissed
    }
    public mutating func reset() { missed = 0 }
}

/// "Sounds like a game you have" (2026-11-18): she asks out loud "play that one, or make a new game?" and the kid
/// answers by voice. On-device word match (no AI call): the saved game, a new game, or unclear (she asks once more in
/// words: "Do you want to play <title> again, or make a new game?").
public enum SavedOrNew: Equatable, Sendable {
    case saved, new, unclear

    static let newWords = ["new", "different", "another", "other one", "something else", "start over", "no", "nope",
                           "not that", "don't want that"]
    static let savedWords = ["that one", "this one", "saved", "old one", "same", "again", "play it", "play that",
                             "yes", "yeah", "yep", "sure", "ok", "okay", "picture"]
    static let plainYes: Set<String> = ["yes", "yeah", "yep", "sure", "ok", "okay"]

    /// `savedTitle`: the saved game's title (saying its name means that game).
    public static func decide(_ words: String, savedTitle: String = "") -> SavedOrNew {
        let cleaned = words.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
            .map { $0.isLetter || $0 == "'" ? $0 : " " }
        let t = " " + String(cleaned).split(separator: " ").joined(separator: " ") + " "
        func has(_ w: String) -> Bool { t.contains(" " + w + " ") }
        let wantsNew = newWords.contains(where: has)
        let titleWords = GameMatch.words(savedTitle).subtracting(GameMatch.placeWords)
        let saysTitle = !titleWords.isDisjoint(with: GameMatch.words(words))
        let savedHits = savedWords.filter(has)
        switch (!savedHits.isEmpty || saysTitle, wantsNew) {
        case (true, false): return .saved
        case (false, true): return .new
        case (true, true):
            // "Yes, a new one!" / "ok, something else" / "a new airplane game": a new-game word wins over a plain yes
            // or the game's name. "That one or a new one?" stays unclear (she asks once more).
            return savedHits.allSatisfy(plainYes.contains) ? .new : .unclear
        case (false, false): return .unclear
        }
    }
}

/// Play (2026-11-18, Haylee): while Nutmeg says a role's job or a scene's setup line she looks UP at the kids (the
/// talking face, eyes forward); when the line ends she looks back DOWN at the rows (the focus face). A short hold
/// after her voice stops keeps the pauses between sentences from flickering her eyes.
public struct PeekGaze: Equatable, Sendable {
    public enum Look: Equatable, Sendable { case up, down }
    /// How long she keeps looking up after her voice stops.
    public static let hold: Double = 0.5
    /// How long her head takes to tip up or back down (the eyes swap at once).
    public static let tip: Double = 0.18
    public private(set) var stoppedAt: Double?
    /// When she started looking up (kept through a pause inside the hold, so the head never dips mid-line).
    public private(set) var upSince: Double?
    public private(set) var speaking = false
    public init() {}

    /// Her voice started or stopped at `now` (seconds, any monotonic clock).
    public mutating func speaking(_ on: Bool, at now: Double) {
        if on {
            if look(at: now) == .down { upSince = now }
            speaking = true; stoppedAt = nil
        } else if speaking { speaking = false; stoppedAt = now }
    }
    public func look(at now: Double) -> Look {
        if speaking { return .up }
        if let s = stoppedAt, now - s < Self.hold { return .up }
        return .down
    }

    /// 0 (head down at the rows) … 1 (head up at the kids), eased over `tip`.
    public func headUp(at now: Double) -> Double {
        let up = look(at: now) == .up
        let since = up ? now - (upSince ?? (now - Self.tip)) : now - ((stoppedAt ?? -1_000) + Self.hold)
        let p = max(0, min(1, since / Self.tip))
        let eased = p * p * (3 - 2 * p)
        return up ? eased : 1 - eased
    }
}
