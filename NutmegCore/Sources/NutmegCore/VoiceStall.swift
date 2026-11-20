import Foundation

// 2026-11-20 (Haylee: on the Play scenes, after a few 🔊 row taps ALL her speech stopped until the game was left and
// reopened; decisions/2026-11-20-voice-stall-fix.md). The pure parts of the fix, all Foundation only and clock-injected
// (seconds on any monotonic clock), so they are unit-tested without a socket or a speaker (VoiceStallTests).
// - `GameTakes`: every FINISHED take of an app line stays in memory for the rest of this game (repeat taps play it with
//   no socket), whatever its pitch or transcript. What gets SAVED for replays still goes through those checks.
// - `LineSocketHealth`: the fixed-lines session can fail after it was ready (an error, a failed response, no
//   response.created within 3 s, closed, missed pongs). Then lines go to the main session, the pending line is resent
//   there once, and the lines session is reopened in the background a few times.
// - `CreateLedger`: every response.create carries a per-socket tag in its metadata. A stop cancels only the requests
//   sent before it (the old count matching drifted for good after one create that never got response.created).
// - `LineWatchdog`: an app line that makes no sound within 4 s marks the voice unhealthy (silent reconnect).
// - `ResumeLoop`: a lock / unlock during a resume runs the resume again, so `suspended` can't stay on in the foreground.

/// Her finished app-line takes for THIS game, in memory only (never written, gone with the game). PCM16 24 kHz mono, by
/// the line's normalized text (the caller normalizes: `ClipText.normalize`). Oldest first out past `maxBytes`.
public struct GameTakes: Equatable, Sendable {
    /// About 8 minutes of her voice (PCM16 at 24 kHz is 48 KB a second).
    public static let maxBytes = 24 * 1024 * 1024
    private var takes: [String: Data] = [:]
    private var order: [String] = []
    public private(set) var bytes = 0
    public init() {}

    /// A take is kept for this game when its response finished (not cancelled, not cut) and it has sound. No pitch-band
    /// or transcript check here: those decide what is SAVED for replays, not what she can say again right now.
    public static func keeps(status: String?, audioBytes: Int) -> Bool {
        audioBytes > 0 && (status == nil || status == "completed")
    }

    public var count: Int { takes.count }
    public func take(_ key: String) -> Data? { takes[key] }
    public func has(_ key: String) -> Bool { takes[key] != nil }

    /// Adds (or replaces) a take; the oldest go when the budget is full. A take bigger than the whole budget is skipped.
    public mutating func add(_ key: String, pcm16: Data) {
        guard !pcm16.isEmpty, pcm16.count <= Self.maxBytes else { return }
        if let old = takes[key] { bytes -= old.count; order.removeAll { $0 == key } }
        takes[key] = pcm16
        order.append(key)
        bytes += pcm16.count
        while bytes > Self.maxBytes, let oldest = order.first {
            order.removeFirst()
            bytes -= takes.removeValue(forKey: oldest)?.count ?? 0
        }
    }

    public mutating func clear() { takes = [:]; order = []; bytes = 0 }
}

/// Per-request tags on `response.create` (response metadata), one ledger per socket. A stop marks everything sent so
/// far: a response that arrives later with one of those tags is cancelled on arrival; a request sent after the stop
/// never is. A request that errors and never gets response.created leaves nothing out of step.
public struct CreateLedger: Equatable, Sendable {
    /// The metadata key (next to the recorder's `pt_line`).
    public static let metadataKey = "pt_req"
    public private(set) var sent = 0
    public private(set) var stoppedThrough = 0
    public init() {}

    /// The tag for the next response.create on this socket.
    public mutating func nextTag() -> String { sent += 1; return "q\(sent)" }
    /// A stop (the kid moved on): every request sent so far is stale.
    public mutating func stop() { stoppedThrough = sent }
    /// True for a response whose request was sent before the last stop (untagged responses never are).
    public func cancelsOnArrival(_ tag: String?) -> Bool {
        guard let n = Self.number(tag) else { return false }
        return n <= stoppedThrough
    }

    static func number(_ tag: String?) -> Int? {
        guard let tag, tag.first == "q" else { return nil }
        return Int(tag.dropFirst())
    }

    /// The event with the tag in `response.metadata` (other metadata, like the recorder's `pt_line`, is kept).
    /// Anything that isn't a response.create is returned unchanged.
    public static func stamp(_ event: [String: Any], tag: String) -> [String: Any] {
        guard event["type"] as? String == "response.create" else { return event }
        var e = event
        var r = (e["response"] as? [String: Any]) ?? [:]
        var meta = (r["metadata"] as? [String: Any]) ?? [:]
        meta[metadataKey] = tag
        r["metadata"] = meta
        e["response"] = r
        return e
    }

    /// The tag on a response.created / response.done (nil for a response without one).
    public static func tag(in text: String) -> String? {
        guard let k = text.range(of: "\"\(metadataKey)\"") else { return nil }
        var rest = text[k.upperBound...].drop { $0 == " " }
        guard rest.first == ":" else { return nil }
        rest = rest.dropFirst().drop { $0 == " " }
        guard rest.first == "\"" else { return nil }
        rest = rest.dropFirst()
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }
}

/// The fixed-lines session's health after it was ready (events and a clock in, decisions out).
public struct LineSocketHealth: Equatable, Sendable {
    public enum State: Equatable, Sendable { case down, healthy, failed }
    public enum Reason: String, Equatable, Sendable { case error, failedResponse, noCreated, closed, missedPongs }
    public struct Failure: Equatable, Sendable {
        public let reason: Reason
        /// Tags of the lines to resend once on the main session (sent recently, not stopped by a tap).
        public let resend: [String]
    }

    /// A line with no response.created after this long means the lines session is gone.
    public static let createdTimeout: Double = 3
    /// A line older than this when the session fails is not resent (the moment has passed).
    public static let resendWithin: Double = 8
    /// The waits before each background reopen; after the last, lines stay on the main session for this connection.
    public static let reopenDelays: [Double] = [2, 10, 30]

    struct Pending: Equatable, Sendable { let tag: String; let at: Double; var resend: Bool }
    public private(set) var state: State = .down
    private var pending: [Pending] = []
    public private(set) var reopenAttempts = 0
    public init() {}

    /// Lines go to the lines session only while it is healthy.
    public var routesLines: Bool { state == .healthy }
    /// A line was sent there and its response.created hasn't come yet.
    public var hasPending: Bool { !pending.isEmpty }

    /// session.updated arrived on a (re)opened lines session.
    public mutating func ready() { state = .healthy; pending = [] }
    /// A line went to the lines session.
    public mutating func sent(tag: String, at now: Double) {
        guard state == .healthy else { return }
        pending.append(Pending(tag: tag, at: now, resend: true))
    }
    /// response.created arrived for `tag` (untagged: the oldest pending).
    public mutating func created(tag: String?) {
        if let tag { pending.removeAll { $0.tag == tag } } else if !pending.isEmpty { pending.removeFirst() }
    }
    /// A tap stopped her: lines already sent are still watched (no response.created = dead), but never resent.
    public mutating func stop() { for i in pending.indices { pending[i].resend = false } }

    /// An error event after ready. Cancel errors are benign (a cancel for a response that already ended).
    public mutating func error(_ message: String, at now: Double) -> Failure? {
        Self.isBenign(message) ? nil : fail(.error, at: now)
    }
    /// response.done: only a "failed" status counts (cancelled / incomplete are normal).
    public mutating func done(status: String?, at now: Double) -> Failure? {
        status == "failed" ? fail(.failedResponse, at: now) : nil
    }
    /// The clock check: a pending line older than `createdTimeout`.
    public mutating func check(at now: Double) -> Failure? {
        pending.contains { now - $0.at >= Self.createdTimeout } ? fail(.noCreated, at: now) : nil
    }
    /// The session failed (once): lines move to the main session; returns the lines to resend there.
    public mutating func fail(_ reason: Reason, at now: Double) -> Failure? {
        guard state == .healthy else { return nil }
        state = .failed
        let resend = pending.filter { $0.resend && now - $0.at <= Self.resendWithin }.map(\.tag)
        pending = []
        return Failure(reason: reason, resend: resend)
    }

    /// The wait before the next background reopen try (nil = no more tries on this connection).
    public mutating func nextReopenDelay() -> Double? {
        guard state != .healthy, Self.reopenDelays.indices.contains(reopenAttempts) else { return nil }
        defer { reopenAttempts += 1 }
        return Self.reopenDelays[reopenAttempts]
    }

    public mutating func reset() { self = LineSocketHealth() }

    /// "response_cancel_not_active: …" and the like: a cancel that found nothing to cancel.
    public static func isBenign(_ message: String) -> Bool {
        let m = message.lowercased()
        return m.contains("cancel") && (m.contains("not_active") || m.contains("no active") || m.contains("not active"))
    }
}

/// The safety net: an app line that makes no sound within `limit` seconds marks the voice unhealthy.
public struct LineWatchdog: Equatable, Sendable {
    public static let limit: Double = 4
    public private(set) var armedAt: Double?
    public init() {}

    public var isArmed: Bool { armedAt != nil }
    /// A line was sent (the earliest unanswered one sets the clock).
    public mutating func lineSent(at now: Double) { if armedAt == nil { armedAt = now } }
    /// The line was resent elsewhere (the main session): its clock starts again.
    public mutating func rearm(at now: Double) { armedAt = now }
    /// Her voice played.
    public mutating func heard() { armedAt = nil }
    /// A tap stopped her, the app went away, or the session was reset.
    public mutating func disarm() { armedAt = nil }
    /// True once when the line is overdue (then it disarms).
    public mutating func check(at now: Double) -> Bool {
        guard let a = armedAt, now - a >= Self.limit else { return false }
        armedAt = nil
        return true
    }
}

/// One resume at a time, run again when the app went away and came back during it (the session was suspended a
/// second time while the first resume's ping ran, and `suspended` stayed on in the foreground: no clips, no voice).
public struct ResumeLoop: Equatable, Sendable {
    /// Rounds in a row before it stops (the next foreground or line asks again).
    public static let maxRounds = 4
    public private(set) var running = false
    private var rounds = 0
    public init() {}

    /// A resume was asked for: true = start one now; false = one is running (it checks again when it ends).
    public mutating func request() -> Bool {
        guard !running else { return false }
        running = true; rounds = 1
        return true
    }
    /// The running resume ended. True = run another round now (still suspended while the app is active).
    public mutating func ended(stillSuspended: Bool, appActive: Bool) -> Bool {
        guard running else { return false }
        if stillSuspended && appActive && rounds < Self.maxRounds { rounds += 1; return true }
        running = false; rounds = 0
        return false
    }
}
