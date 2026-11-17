import Foundation

/// Decides when the app sends `response.create` (round 6, push-to-talk): exactly ONE spoken reply per kid turn.
/// - A kid turn (held mic released, typed line, the greeting kick-off, a silence re-ask) asks for one response.
/// - Never two responses at once: a request while one is active waits for its `response.done`.
/// - After a response ends, ONE follow-up is sent only when this turn hasn't spoken yet (she called set_game or
///   set_expression silently, as instructed, and still owes her answer). A response that already spoke never gets a
///   follow-up, whatever tools it called; set_expression never asks for one by itself.
/// - The writing beat (start_planning) is the one deliberate second part: `forceFollowUp` lets her announce the plan.
/// - Round 7: a response that called a real step tool (set_game … show_next_prop, mark_found) AFTER speaking gets ONE
///   follow-up when what she said didn't finish the step ("let me grab the next prop." and stop): the session passes
///   `spokenTurnIncomplete`. A spoken turn that already ends with its question gets none (no repeats, round 6).
/// Pure state, unit-tested (RealtimeTests); `RealtimeSession` sends the events.
public struct ResponseGate: Equatable, Sendable {
    public private(set) var active = false
    public private(set) var turnSpoke = false
    private var inTurn = false
    private var pending = false
    /// Round 15: a NEW turn's request that arrived while the previous turn's response was still active (a tap or a
    /// typed line that interrupted her). The interrupt blocks the usual follow-up, so it must be asked again.
    public private(set) var deferredTurn = false
    /// Audio still arriving from a response that started before this turn belongs to the old turn.
    private var staleActive = false
    private var followUps = 0
    /// This response called a step tool (not set_expression / start_planning).
    public private(set) var toolThisResponse = false
    /// Safety cap: silent tool-only responses in a row before we stop asking.
    public static let maxFollowUps = 5

    public init() {}

    /// A new kid turn: she owes exactly one spoken reply.
    public mutating func newTurn() {
        inTurn = true; turnSpoke = false; pending = false; followUps = 0; deferredTurn = false
        staleActive = active
    }

    /// Returns true when `response.create` should be sent now (false: one is active; it follows on done).
    public mutating func request() -> Bool {
        if active { pending = true; if staleActive { deferredTurn = true }; return false }
        active = true
        return true
    }

    /// Round 15 (Haylee: a second "Don't have it" tap got no reply): the old turn's (cancelled) response is done and a
    /// new turn's request is waiting. Clears the old response and returns true: the session asks for the new turn's
    /// response now (with its tool-first rule), instead of `done`, whose follow-up the interrupt blocked.
    public mutating func takeDeferredTurn() -> Bool {
        guard deferredTurn else { return false }
        deferredTurn = false; pending = false
        active = false; staleActive = false; toolThisResponse = false
        return true
    }

    public mutating func created() { active = true; staleActive = false; toolThisResponse = false }

    /// The current response called a real step tool (its output must be followed by her next words).
    public mutating func toolCalled() { toolThisResponse = true }

    /// Her audio for this turn started playing.
    public mutating func spoke() { if !staleActive { turnSpoke = true } }

    /// The writing beat ended: she announces the plan (the turn's real answer), even after a lead-in line.
    /// Round 7 fix: also re-opens the turn (a lead-in line before start_planning had closed it, so the silent
    /// set_roles → show_next_prop chain after the beat never got its spoken reply).
    public mutating func forceFollowUp() { pending = true; continueTurn() }

    /// The app asked her to continue the same turn (a forced continuation): she owes a spoken reply again, so a silent
    /// tool-only continuation (just show_next_prop) still gets one follow-up that speaks.
    public mutating func continueTurn() { inTurn = true; turnSpoke = false }

    /// finish_planning: planning is over and the app speaks the kit lines, so she owes nothing more (no follow-up).
    public mutating func endTurn() { turnSpoke = true; pending = false; inTurn = false }

    /// `response.done`. Returns true when ONE follow-up `response.create` should be sent now.
    /// `allowFollowUp` is false while the kid holds the mic or after an interrupt (the release asks instead).
    public mutating func done(allowFollowUp: Bool = true, spokenTurnIncomplete: Bool = false) -> Bool {
        active = false; staleActive = false; deferredTurn = false
        let owes = inTurn && !turnSpoke
        let afterTool = toolThisResponse && turnSpoke && spokenTurnIncomplete
        toolThisResponse = false
        let wants = pending || owes || afterTool
        pending = false
        guard allowFollowUp, wants, !turnSpoke || afterTool, followUps < Self.maxFollowUps else {
            if turnSpoke { inTurn = false }
            return false
        }
        followUps += 1
        active = true
        return true
    }
}

/// Round 39 (the ~10 s pause after a spoken/typed "found it"): whether her spoken reply to the kid's turn is still due.
/// The session used to clear this only when her audio started. A turn that ends with a tool-only (silent) pass and NO
/// spoken follow-up (show_next_prop / finish_planning: the app says the next line itself) never plays audio, so it
/// stayed "due" forever, `isBusy` stayed true, and the app's prop line waited out its 10 s limit. Now a response that
/// ends with nothing more requested (the gate is idle) also closes it: no reply is coming.
public struct ReplyWait: Equatable, Sendable {
    public private(set) var due = false
    public init() {}
    /// The kid's turn ended (hold released, typed line, tap): her reply is due.
    public mutating func kidTurnEnded() { due = true }
    /// Her first audio for the turn played.
    public mutating func replyBegan() { due = false }
    /// `response.done` was handled. `gateActive` = a follow-up (or the next turn's response) was already requested.
    public mutating func responseDone(gateActive: Bool) { if !gateActive { due = false } }
    public mutating func reset() { due = false }
}
