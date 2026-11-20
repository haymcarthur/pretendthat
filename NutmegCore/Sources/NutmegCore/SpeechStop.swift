import Foundation

/// Round 19 (Haylee: fast taps through the checklist left her talking over the next screens, even on the home screen):
/// ANY kid action that advances or changes the screen stops her current speech at once, then only the newest line plays.
/// Pure rules, unit-tested (Round19SpeechStopTests); `RealtimeSession` sends the events and stops the local player.
public enum UserAction: String, CaseIterable, Sendable {
    /// Round 29: `nextScene` (the green ▶), `readTask` (a row's 🔊) replace the checklist and hand-off taps.
    case nextScene, readTask, propFound, propMissing, print, letsPlay, repeatLine
    /// 2026-11-20 (checklist scenes): ◀ Previous scene, and Skip to the scenes on a replay.
    case previousScene, skipToScenes
    case newGame, playAgain, close, goHome, stepRail, confirmYes, confirmChange
    /// Round 20 (Haylee: she typed during the greeting and the voice kept going): the kid starting their OWN turn,
    /// by sending typed text or pressing the mic, stops everything she's saying too.
    case typedTurn, micPressed, colorChoice
    /// Round D1: Save it to play again, a replay's Pick / Props / Print taps, a My games card.
    case saveGame, replayPick, replayProp, paperChoice, openSavedGame
    /// Not screen changes: switching the chat panel's tabs, opening or closing the chat.
    case chatTab, toggleChat

    public var stopsSpeech: Bool {
        switch self {
        case .chatTab, .toggleChat: false
        default: true
        }
    }
}

extension SpeechStop {
    /// Round 20: a kid turn starts (typed or mic) while ANYTHING of hers is in flight or playing (a reply, the greeting,
    /// an app line, a tool-first pass's follow-up): stop it all first, so only the reply to the new turn plays.
    public static func kidTurnStops(responseActive: Bool, playing: Bool, inFlight: [String]) -> Bool {
        responseActive || playing || !inFlight.isEmpty
    }
}

/// Tracks every response the server is generating (her conversation replies AND out-of-band app lines: cheers, scene
/// lines, the kit-ready line), so a stop cancels all of them by id, and late audio/text from a cancelled one is dropped.
public struct SpeechStop: Sendable {
    public private(set) var active: [String] = []
    public private(set) var cancelled: Set<String> = []
    public init() {}

    public mutating func created(_ id: String?) {
        guard let id, !active.contains(id), !cancelled.contains(id) else { return }
        active.append(id)
    }

    public mutating func done(_ id: String?) {
        guard let id else { return }
        active.removeAll { $0 == id }
    }

    /// Cancels every in-flight response: returns the ids to send `response.cancel` for. Later events from them are dropped.
    public mutating func cancelAll() -> [String] {
        let ids = active
        cancelled.formUnion(ids)
        if cancelled.count > 64 { cancelled = Set(ids) }   // ids are unique; old ones never come back
        active = []
        return ids
    }

    /// 2026-11-20: cancels ONE response (a stale request that arrived after a stop). `cancelAll` here also cancelled
    /// the tap's own new line when it was already running. True when it was in flight (send its response.cancel).
    @discardableResult
    public mutating func cancel(_ id: String?) -> Bool {
        guard let id, let i = active.firstIndex(of: id) else { return false }
        active.remove(at: i)
        cancelled.insert(id)
        if cancelled.count > 64 { cancelled = [id] }
        return true
    }

    /// True for a playback event (audio, her words) that belongs to a response the kid already moved past.
    public func drops(_ event: Realtime.Event, responseID: String?) -> Bool {
        guard let responseID, cancelled.contains(responseID) else { return false }
        switch event {
        case .audioDelta, .audioDone, .transcriptDelta, .transcriptDone, .outputItemAdded: return true
        default: return false
        }
    }
}

extension Realtime {
    /// Cancels one response by id (an out-of-band app line has no "current" conversation response to cancel).
    public static func responseCancel(id: String) -> [String: Any] { ["type": "response.cancel", "response_id": id] }

    /// The response id a server event belongs to (`resp_…`), found without decoding the whole JSON again (audio deltas
    /// are large). response.created / response.done carry it as `response.id`, deltas as `response_id`.
    public static func responseID(_ text: String) -> String? {
        guard let r = text.range(of: "\"resp_") else { return nil }
        let start = text.index(after: r.lowerBound)
        guard let end = text[start...].firstIndex(of: "\"") else { return nil }
        return String(text[start..<end])
    }
}

extension RealtimeTranscript {
    /// Her line was cut off by a kid's tap: the chat keeps what was said, marked with "…", and nothing more joins it.
    public mutating func cutOff() {
        guard let last = lines.indices.last, lines[last].fromNutmeg else { breakTurn(); return }
        var t = lines[last].text.trimmingCharacters(in: .whitespaces)
        if !t.hasSuffix("…") {
            while let c = t.last, ".!?,".contains(c) { t.removeLast() }
            t += "…"
        }
        replaceLast(t)
        breakTurn()
    }
}
