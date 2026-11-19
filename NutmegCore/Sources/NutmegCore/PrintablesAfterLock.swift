import Foundation

// Printables after a lock (2026-11-18, decisions/2026-11-18-printables-after-lock.md). Haylee locked her phone during
// the hunt and opened it an hour later on cellular: a couple of color pages were app-drawn while their coloring pages
// were AI pictures. Image calls cut off by the lock were treated as real failures. Now:
//   1. `AwayRetry`: a call that failed while the app was away (it left the foreground during the call, or isn't back
//      yet) waits for the app to come back and tries again, without using up the real retries;
//   2. `PrintablePairs`: the color page of a printable is always the coloring page colored in (it waits for its
//      outline however long the phone was locked and never draws a picture of its own), and a page either set gave
//      up on is "not ready" in BOTH sets;
//   3. Haylee: no fallback art in live games. A page that really fails shows "not ready" with Try again (retrying
//      only that picture) and isn't printed. Demo mode (no image service) keeps the built-in art.

/// Whether the app is in the foreground, and how many times it has left it (the app sets it from the scene phase).
public final class AppPresence: @unchecked Sendable {
    public static let shared = AppPresence()
    private let lock = NSLock()
    private var _foreground = true
    private var _awayCount = 0
    public init() {}

    public var isForeground: Bool { lock.withLock { _foreground } }
    /// Times the app has gone to the background (a call that saw this change was cut off by it).
    public var awayCount: Int { lock.withLock { _awayCount } }

    public func setForeground(_ on: Bool) {
        lock.withLock {
            if !on && _foreground { _awayCount += 1 }
            _foreground = on
        }
    }

    /// Returns once the app is in the foreground (at once when it is), or when the task is cancelled.
    public func waitUntilForeground() async {
        while !isForeground && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(100)) }
    }
}

/// How an image call is retried.
public struct AwayPolicy: Sendable {
    /// Real retries for a network error in the foreground (with the first try: 3 calls, the old RetryOnce + the
    /// round 9 retry). Any other error gets one retry (the old RetryOnce).
    public static let defaultForegroundRetries = 2
    public let presence: AppPresence
    /// True: stop at once (the account can't make images this run: no credits, bad key).
    public var giveUp: @Sendable (Error) -> Bool
    /// The wait before a retry (and after the app is back, for the network to settle).
    public var pause: Duration
    public var foregroundRetries: Int
    /// Calls cut off by the app going away don't count, but a cap keeps it from looping forever.
    public var awayRetries: Int
    public init(presence: AppPresence = .shared, giveUp: @escaping @Sendable (Error) -> Bool = { _ in false },
                pause: Duration = .seconds(1.5), foregroundRetries: Int = defaultForegroundRetries, awayRetries: Int = 6) {
        self.presence = presence; self.giveUp = giveUp; self.pause = pause
        self.foregroundRetries = foregroundRetries; self.awayRetries = awayRetries
    }
}

public enum AwayRetry {
    /// A network error (a dropped connection, no network, a timeout).
    public static func isTransient(_ e: Error) -> Bool { e is URLError || (e as? ClaudeError) == .transport }

    /// Runs `op`; a failure while the app was away waits for it to come back and tries again (not counted); a failure
    /// in the foreground is retried `foregroundRetries` times (network errors) or once (others). Then it throws.
    public static func run<T: Sendable>(_ policy: AwayPolicy, _ op: @Sendable () async throws -> T) async throws -> T {
        var real = 0, away = 0
        while true {
            let awayBefore = policy.presence.awayCount
            do { return try await op() } catch {
                if Task.isCancelled || error is CancellationError || policy.giveUp(error) { throw error }
                let wasAway = policy.presence.awayCount != awayBefore || !policy.presence.isForeground
                if wasAway, away < policy.awayRetries {
                    away += 1
                    await policy.presence.waitUntilForeground()
                } else {
                    let allowed = isTransient(error) ? policy.foregroundRetries : min(1, policy.foregroundRetries)
                    guard real < allowed else { throw error }
                    real += 1
                }
                try? await Task.sleep(for: policy.pause)
                if Task.isCancelled { throw error }
            }
        }
    }
}

/// What a printable shows in one set.
public enum PictureState: Equatable, Sendable {
    /// Demo mode (no image service): the app-drawn page.
    case builtIn
    /// The AI picture is on its way (a spinner over a blank page, never fallback art).
    case drawing
    case ready
    /// The picture failed for real: a "not ready" tile with Try again; the page isn't printed.
    case notReady
}

/// Both sets of every AI page: the coloring (outline) page is drawn, the color page is that picture colored in.
public struct PrintablePairs: Equatable, Sendable {
    public enum Side: Equatable, Sendable { case drawing, landed, failed }
    public struct Pair: Equatable, Sendable {
        public var outline: Side = .drawing
        public var color: Side = .drawing
    }
    public private(set) var pairs: [String: Pair] = [:]
    public init() {}

    public func pair(_ key: String) -> Pair { pairs[key] ?? Pair() }

    /// A set's side of a page landed, failed (for real), or is drawing again.
    public mutating func set(_ key: String, _ style: PrintStyle, _ side: Side) {
        var p = pair(key)
        if style == .fullColor { p.color = side } else { p.outline = side }
        pairs[key] = p
    }

    /// Either set gave up on this page.
    public func gaveUp(_ key: String) -> Bool { let p = pair(key); return p.outline == .failed || p.color == .failed }

    /// What this page shows in `style`'s set. Not ready in both when either failed (the sets always match).
    public func state(_ key: String, style: PrintStyle, live: Bool) -> PictureState {
        guard live else { return .builtIn }
        if gaveUp(key) { return .notReady }
        let p = pair(key)
        return (style == .fullColor ? p.color : p.outline) == .landed ? .ready : .drawing
    }

    public enum ColorStart: Equatable, Sendable { case wait, colorIn, notReady }
    /// The color page waits for its outline (however long the phone was locked), colors it in once it's kept, and is
    /// not ready when the outline failed: it never draws a different picture of its own.
    public func colorStart(_ key: String) -> ColorStart {
        switch pair(key).outline {
        case .drawing: return .wait
        case .landed: return .colorIn
        case .failed: return .notReady
        }
    }

    public enum Redraw: Equatable, Sendable { case both, colorOnly, none }
    /// Try again on one page: the outline failed → both are drawn again; only the color failed → the kept outline is
    /// colored in again; nothing failed → nothing to do.
    public mutating func retry(_ key: String) -> Redraw {
        let p = pair(key)
        if p.outline == .failed { pairs[key] = Pair(); return .both }
        if p.color == .failed { set(key, .fullColor, .drawing); return .colorOnly }
        return .none
    }

    /// The pages of a set can be printed: every one is the AI picture (or demo mode's built-in art).
    public static func printable(_ states: [PictureState]) -> Bool {
        states.allSatisfy { $0 == .ready || $0 == .builtIn }
    }
}
