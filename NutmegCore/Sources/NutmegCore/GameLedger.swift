import Foundation

// Round D1: hooks section E (plans and pricing) will need. No-op for now; nothing is stored or sent.

/// Counts new games vs replays for E's plans (design §7). D1 ships the no-op; tests use a counting one.
@MainActor
public protocol GameLedger: AnyObject {
    /// A new game counts at the confirm-step yes, the moment before the first paid AI call (the kit).
    func newGameStarted(id: UUID)
    /// A saved game was replayed (never counts as a new game).
    func replayStarted(id: UUID)
    func paidAICall(kind: PaidAICall)
}

public enum PaidAICall: String, Sendable { case kitPages, playGuide, pageArt, replayLine }

@MainActor
public final class NoOpLedger: GameLedger {
    public init() {}
    public func newGameStarted(id: UUID) {}
    public func replayStarted(id: UUID) {}
    public func paidAICall(kind: PaidAICall) {}
}

/// Round D1: how many AI calls went out this app run, by kind (numbers only, in memory). The live checks log it to
/// confirm a replay makes no content calls (Claude or images).
public enum AICallLog {
    public enum Kind: String, Sendable, CaseIterable { case claude, image, moderation }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var counts: [Kind: Int] = [:]
    public static func record(_ kind: Kind) { lock.withLock { counts[kind, default: 0] += 1 } }
    public static func count(_ kind: Kind) -> Int { lock.withLock { counts[kind] ?? 0 } }
    public static var snapshot: [Kind: Int] { lock.withLock { counts } }
    /// Claude + image calls (game content).
    public static var contentCalls: Int { count(.claude) + count(.image) }
    public static func summary() -> String { Kind.allCases.map { "\($0.rawValue)=\(count($0))" }.joined(separator: " ") }
}
