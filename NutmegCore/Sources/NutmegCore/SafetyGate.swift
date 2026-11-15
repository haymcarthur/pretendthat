import Foundation

/// Round 21 (lag, measured): round 19 awaited OpenAI moderation BEFORE every typed turn was sent (0.15–1.2 s) and
/// before every text-carrying tool's output (0.2–0.9 s), so a typed turn took 2.1–2.7 s to her first audio (round 13:
/// 1.2–1.6 s). Now the instant local filter stays synchronous, and the remote moderation runs IN PARALLEL with her
/// reply. A late flag cancels the reply, undoes what the text changed (the last all-clear snapshot) and steers.
/// Anything that leaves the app with that text (Claude, the kit, images) waits for `cleared()` first.
@MainActor
public final class SafetyGate {
    public let check: KidSafetyCheck
    /// Called once per remote flag (on the main actor): cancel her reply, restore, steer.
    public var onFlag: ((Sanitizer.SafetyVerdict, Ticket) -> Void)?
    public struct Ticket: Equatable, Sendable {
        public let id: Int
        /// What was screened (a kid turn, or a tool's text), so the flag handler can undo the right thing.
        public let kind: Kind
        public enum Kind: Equatable, Sendable { case kidText, toolText }
    }
    /// Called when the last pending check comes back clear (the app drops its undo snapshot).
    public var onAllClear: (() -> Void)?
    private var pending: [Int: Task<Sanitizer.SafetyVerdict?, Never>] = [:]
    private var nextID = 0
    /// Flags seen since the last `takeFlags()` (a waiter that raced a flag must not go ahead).
    public private(set) var flaggedCount = 0

    public init(check: KidSafetyCheck) { self.check = check }

    public var isPending: Bool { !pending.isEmpty }

    /// The instant local filter now (nil = go ahead), then the remote check in the background.
    @discardableResult
    public func screen(_ texts: [String], kind: Ticket.Kind, pretend: Bool = false) -> (local: Sanitizer.SafetyVerdict?, ticket: Ticket?) {
        if let v = check.local(texts, pretend: pretend) { return (v, nil) }
        guard check.moderator != nil else { return (nil, nil) }
        nextID += 1
        let ticket = Ticket(id: nextID, kind: kind)
        let check = self.check
        pending[ticket.id] = Task { await check.remote(texts) }
        Task { [weak self] in
            guard let task = self?.pending[ticket.id] else { return }
            let verdict = await task.value
            guard let self else { return }
            self.pending[ticket.id] = nil
            if let verdict {
                self.flaggedCount += 1
                self.onFlag?(verdict, ticket)
            } else if self.pending.isEmpty {
                self.onAllClear?()
            }
        }
        return (nil, ticket)
    }

    /// Waits for every remote check started so far. false = one of them was flagged (don't use the text).
    public func cleared() async -> Bool {
        let before = flaggedCount
        while let task = pending.values.first {
            _ = await task.value
            await Task.yield()   // let the result handler remove it (and run onFlag) first
        }
        return flaggedCount == before
    }

    /// Drops every pending check (new game): late results are ignored.
    public func reset() {
        for t in pending.values { t.cancel() }
        pending = [:]
    }
}

/// Round 21: which tool calls may go ahead before the remote check on their text returns. Only ones whose effect is
/// app state the gate can undo (the store snapshot) and that send nothing out (no Claude, no kit, no images): the game
/// and theme at the first steps, and the next prop card in the hunt. Everything else waits for the checks.
public enum SpeculativeTools {
    public static func mayRunBeforeModeration(_ call: PlanningCall, step: PlanningStep, huntActive: Bool) -> Bool {
        switch call {
        case .setGame, .setTheme: return step < .players
        case .showNextProp: return huntActive || step == .roles || step == .props
        case .setPlayerCount, .confirmPlan, .setPrintStyle, .markFound, .skipProp: return true   // no free text
        default: return false
        }
    }
    /// The free text in a call (checked by the filter and moderation).
    public static func texts(_ call: PlanningCall) -> [String] {
        switch call {
        case .setGame(let t), .setTheme(let t): return [t]
        case .setRoles(let roles): return roles.flatMap { [$0.roleName, $0.job] }
        case .showNextProp(let d): return [d.becomes]
        case .showProps(let ds): return ds.map(\.becomes)
        case .swapProp(_, _, let becomes): return [becomes]
        case .showGameIdeas(let ideas): return ideas.flatMap { [$0.title, $0.pitch] }
        default: return []
        }
    }
}
