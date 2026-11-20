import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-20 (decisions/2026-11-20-voice-stall-fix.md): Haylee's family game, build 4. On the Play scenes, after a
/// few 🔊 row taps every line went silent until the game was left and reopened.
struct VoiceStallTests {

    /// PCM16 of `seconds` of a loud tone (passes the silence trim).
    func tone(_ seconds: Double) -> Data {
        var d = Data()
        for i in 0..<Int(seconds * Realtime.sampleRate) {
            var v = Int16(8000 * sin(Double(i) * 2 * .pi * 220 / Realtime.sampleRate)).littleEndian
            if abs(Int(v)) < 400 { v = Int16(500).littleEndian }
            withUnsafeBytes(of: &v) { d.append(contentsOf: $0) }
        }
        return d
    }

    // MARK: 1. Same-game takes

    @Test func everyFinishedTakeIsKeptForThisGameEvenWhenNotSaved() {
        // A row read whose transcript came back different (or empty) is NOT saved for replays, but the next tap of the
        // same row plays this take instead of going to the voice again.
        var rec = ClipRecorder()
        let line = "Captain, check every ticket!"
        let r = rec.request(line: line, kind: .line, role: "R1")
        rec.created(responseID: "resp_1", tag: r.tag)
        rec.audio(responseID: "resp_1", tone(1.5)); rec.transcript(responseID: "resp_1", "")
        let f = rec.finish(responseID: "resp_1", status: "completed")
        #expect(f.outcome == .rejected(.transcriptMismatch))
        #expect(f.take?.request.line == line && (f.take?.pcm16.count ?? 0) > 0)
        // A good take: kept for saving AND for this game.
        let r2 = rec.request(line: line, kind: .line, role: "R1")
        rec.created(responseID: "resp_2", tag: r2.tag)
        rec.audio(responseID: "resp_2", tone(1.5)); rec.transcript(responseID: "resp_2", line)
        let g = rec.finish(responseID: "resp_2", status: "completed")
        if case .kept = g.outcome {} else { Issue.record("a good line was rejected") }
        #expect(g.take != nil)
    }

    @Test func aCutOrEmptyTakeIsNeverKept() {
        func run(_ status: String?, _ audio: Data, cancel: Bool = false) -> RecordedLine? {
            var rec = ClipRecorder()
            let r = rec.request(line: "Wave the flag!", kind: .line, role: nil)
            rec.created(responseID: "resp_x", tag: r.tag)
            rec.audio(responseID: "resp_x", audio); rec.transcript(responseID: "resp_x", "Wave the flag!")
            if cancel { rec.cancel(["resp_x"]) }
            return rec.finish(responseID: "resp_x", status: status).take
        }
        #expect(run("cancelled", tone(1)) == nil)
        #expect(run("incomplete", tone(1)) == nil)
        #expect(run("completed", tone(1), cancel: true) == nil)   // a tap cut it
        #expect(run("completed", Data(count: 4800)) == nil)      // all silence
        #expect(run("completed", tone(1)) != nil)
        #expect(GameTakes.keeps(status: "completed", audioBytes: 10) && !GameTakes.keeps(status: "failed", audioBytes: 10))
        #expect(!GameTakes.keeps(status: "completed", audioBytes: 0))
    }

    @Test func gameTakesReplaceAndDropTheOldestPastTheBudget() {
        var t = GameTakes()
        t.add("a", pcm16: Data(count: 10)); t.add("a", pcm16: Data(count: 20))
        #expect(t.count == 1 && t.bytes == 20 && t.take("a")?.count == 20)
        let big = GameTakes.maxBytes / 2
        t.add("b", pcm16: Data(count: big)); t.add("c", pcm16: Data(count: big))
        #expect(!t.has("a") && t.has("b") && t.has("c") && t.bytes <= GameTakes.maxBytes)
        t.add("d", pcm16: Data(count: GameTakes.maxBytes + 1))   // bigger than everything: skipped
        #expect(!t.has("d") && t.has("c"))
        t.clear()
        #expect(t.count == 0 && t.bytes == 0)
    }

    // MARK: 3. Cancel bookkeeping: per-request tags

    @Test func aStopNeverCancelsARequestSentAfterIt() {
        // The bug: three creates, one errored (no response.created ever), a stop, then the tap's own line. The old
        // count matching was one behind for good, so every new line was cancelled the moment it arrived.
        var ledger = CreateLedger()
        let t1 = ledger.nextTag(), t2 = ledger.nextTag(), t3 = ledger.nextTag()
        _ = t2   // errored: never created
        #expect(!ledger.cancelsOnArrival(t1) && !ledger.cancelsOnArrival(t3))   // no stop yet
        ledger.stop()
        let t4 = ledger.nextTag()
        #expect(!ledger.cancelsOnArrival(t4))
        #expect(ledger.cancelsOnArrival(t1) && ledger.cancelsOnArrival(t3))   // late arrivals from before the stop
        // And again after a second stop / tap: only the old ones.
        ledger.stop()
        let t5 = ledger.nextTag()
        #expect(ledger.cancelsOnArrival(t4) && !ledger.cancelsOnArrival(t5))
        #expect(!ledger.cancelsOnArrival(nil) && !ledger.cancelsOnArrival("pt3"))   // untagged / the recorder's tag
    }

    @Test func theTagRidesInTheResponseMetadataNextToTheRecorderTag() throws {
        let e = CreateLedger.stamp(Realtime.sayExactly("Wave!", tag: "pt7"), tag: "q3")
        let meta = (e["response"] as? [String: Any])?["metadata"] as? [String: Any]
        #expect(meta?["pt_line"] as? String == "pt7" && meta?["pt_req"] as? String == "q3")
        let spoken = CreateLedger.stamp(Realtime.responseCreateSpoken(), tag: "q4")
        #expect(((spoken["response"] as? [String: Any])?["metadata"] as? [String: Any])?["pt_req"] as? String == "q4")
        #expect((spoken["response"] as? [String: Any])?["tool_choice"] as? String == "auto")   // nothing else changes
        let note = Realtime.systemNote("hi")
        #expect(CreateLedger.stamp(note, tag: "q5")["response"] == nil)   // only response.create is stamped
        // Read back from the server's response.created (compact or spaced JSON).
        let created = #"{"type":"response.created","response":{"id":"resp_1","metadata":{"pt_line":"pt7","pt_req":"q3"}}}"#
        #expect(CreateLedger.tag(in: created) == "q3" && Realtime.lineTag(created) == "pt7")
        #expect(CreateLedger.tag(in: #"{"metadata": {"pt_req" : "q12"}}"#) == "q12")
        #expect(CreateLedger.tag(in: #"{"type":"response.created","response":{"metadata":null}}"#) == nil)
        let json = Realtime.json(e)
        #expect(CreateLedger.tag(in: json) == "q3")
    }

    @Test func aStaleArrivalCancelsOnlyItself() {
        var s = SpeechStop()
        s.created("resp_new")            // the tap's own line, already running
        s.created("resp_stale")          // a cheer asked for before the tap, arriving late
        let cancelled = s.cancel("resp_stale")
        #expect(cancelled)
        #expect(s.active == ["resp_new"] && s.cancelled.contains("resp_stale"))
        #expect(s.drops(.audioDelta(Data([1, 2])), responseID: "resp_stale"))
        #expect(!s.drops(.audioDelta(Data([1, 2])), responseID: "resp_new"))
        let gone = s.cancel("resp_gone"), none = s.cancel(nil)
        #expect(!gone && !none)
    }

    // MARK: 2. Lines-session health

    @Test func aLineWithNoResponseCreatedIn3sFailsOverAndIsResentOnce() {
        var h = LineSocketHealth()
        #expect(!h.routesLines)
        h.ready()
        #expect(h.routesLines)
        h.sent(tag: "q1", at: 10); h.created(tag: "q1")
        let answered = h.check(at: 20)
        #expect(answered == nil)   // answered: fine
        h.sent(tag: "q2", at: 30)
        let early = h.check(at: 32.9)
        #expect(early == nil && h.hasPending)
        let f = h.check(at: 33)
        #expect(f == LineSocketHealth.Failure(reason: .noCreated, resend: ["q2"]))
        #expect(!h.routesLines && !h.hasPending)
        let again = h.check(at: 40), closed = h.fail(.closed, at: 40)
        #expect(again == nil && closed == nil)   // fails once
        h.sent(tag: "q3", at: 41)   // (the app sends to the main session now; nothing is tracked)
        #expect(!h.hasPending)
    }

    @Test func errorsAndFailedResponsesAfterReadyAreFailures() {
        var h = LineSocketHealth(); h.ready()
        let benign = h.error("response_cancel_not_active: Cancellation failed: no active response found", at: 1)
        #expect(benign == nil && h.routesLines)
        let normal = [h.done(status: "cancelled", at: 2), h.done(status: "incomplete", at: 2), h.done(status: "completed", at: 2)]
        #expect(normal.allSatisfy { $0 == nil })
        let failed = h.done(status: "failed", at: 3)
        #expect(failed?.reason == .failedResponse)
        var e = LineSocketHealth(); e.ready()
        e.sent(tag: "q1", at: 0)
        let err = e.error("server_error: The server had an error", at: 1)
        #expect(err == LineSocketHealth.Failure(reason: .error, resend: ["q1"]))
    }

    @Test func linesAKidAlreadyMovedPastAreNeverResent() {
        var h = LineSocketHealth(); h.ready()
        h.sent(tag: "q1", at: 0)
        h.stop()                       // a tap: q1 is stale
        h.sent(tag: "q2", at: 0.5)     // the tap's own line
        let f = h.check(at: 3.5)
        #expect(f?.resend == ["q2"])
        // A line far older than the resend window isn't resent either (the moment passed).
        var o = LineSocketHealth(); o.ready()
        o.sent(tag: "q1", at: 0)
        let old = o.fail(.closed, at: 9)
        #expect(old?.resend == [])
    }

    @Test func theLinesSessionIsReopenedAFewTimesThenLeftOnTheMain() {
        var h = LineSocketHealth()
        h.ready()
        let healthy = h.nextReopenDelay()
        #expect(healthy == nil)   // healthy: nothing to reopen
        _ = h.fail(.missedPongs, at: 0)
        let first = h.nextReopenDelay()
        #expect(first == 2)
        h.ready()                              // the reopen worked
        #expect(h.routesLines)
        _ = h.fail(.closed, at: 100)
        let waits = [h.nextReopenDelay(), h.nextReopenDelay(), h.nextReopenDelay()]
        #expect(waits == [10, 30, nil])
        h.reset()
        #expect(h.state == .down && h.reopenAttempts == 0)
    }

    // MARK: 6. Watchdog

    @Test func aLineThatMakesNoSoundIn4sTripsTheWatchdogOnce() {
        var w = LineWatchdog()
        var trips: [Bool] = []
        trips.append(w.check(at: 100))
        w.lineSent(at: 0)
        trips.append(w.check(at: 3.9))
        w.lineSent(at: 2)   // a second line doesn't push the clock back
        let tripped = w.check(at: 4), twice = w.check(at: 5)
        #expect(tripped && !twice && !w.isArmed)
        // Heard in time: no trip.
        w.lineSent(at: 10); w.heard()
        trips.append(w.check(at: 20))
        // A tap stops her: no trip.
        w.lineSent(at: 30); w.disarm()
        trips.append(w.check(at: 40))
        // Resent on the main session at 3 s: the clock starts again there.
        w.lineSent(at: 50); w.rearm(at: 53)
        trips.append(w.check(at: 54))
        #expect(trips == [false, false, false, false, false])
        let resentTrip = w.check(at: 57)
        #expect(resentTrip)
    }

    // MARK: 4. Suspended can't stick in the foreground

    @Test func aSuspendedSessionResumesEvenWhileBusy() {
        #expect(ForegroundRecovery.decide(suspended: true, live: true, connecting: false, gameHadVoice: true, inGame: true, busy: true) == .resume)
        #expect(ForegroundRecovery.decide(suspended: true, live: false, connecting: true, gameHadVoice: true, inGame: true, busy: true) == .resume)
        #expect(ForegroundRecovery.decide(suspended: true, live: true, connecting: false, gameHadVoice: true, inGame: false, busy: true) == .none)
        #expect(ForegroundRecovery.decide(suspended: false, live: false, connecting: false, gameHadVoice: true, inGame: true, busy: true) == .none)
    }

    /// A tiny model of the app + session: lock / unlock / the resume's ping finishing, in every order.
    struct Model {
        var active = true, suspended = false, live = true
        var loop = ResumeLoop()
        var pingInFlight = false
        var resumesStarted = 0
        mutating func lock() { active = false; if live { suspended = true } }
        mutating func unlock() {
            active = true
            if ForegroundRecovery.decide(suspended: suspended, live: live, connecting: false, gameHadVoice: true, inGame: true,
                                         busy: pingInFlight) == .resume { startResume() }
        }
        mutating func startResume() { if loop.request() { round() } }
        /// resumeIfAlive: clears suspended, then pings.
        mutating func round() { suspended = false; pingInFlight = true; resumesStarted += 1 }
        mutating func pingDone() {
            guard pingInFlight else { return }
            pingInFlight = false
            // resumeIfAlive re-checks suspended after the ping (locked again meanwhile: no audio started).
            if loop.ended(stillSuspended: suspended, appActive: active) { round() }
        }
        /// Settles: every ping in flight finishes.
        mutating func settle() { var n = 0; while pingInFlight && n < 10 { pingDone(); n += 1 } }
    }

    @Test func lockAndUnlockDuringAResumeNeverLeaveItSuspendedInTheForeground() {
        enum Step: CaseIterable { case lock, unlock, ping }
        // Every sequence of up to 6 steps, starting from a lock + unlock (the first resume running).
        func all(_ n: Int) -> [[Step]] { n == 0 ? [[]] : all(n - 1).flatMap { p in Step.allCases.map { p + [$0] } } }
        for seq in all(6) {
            var m = Model()
            m.lock(); m.unlock()
            for s in seq {
                switch s { case .lock: m.lock(); case .unlock: m.unlock(); case .ping: m.pingDone() }
            }
            if !m.active { m.unlock() }   // the family is looking at the iPad again
            m.settle()
            #expect(!(m.active && m.suspended), "stuck suspended after \(seq)")
            #expect(!m.loop.running)
        }
    }

    @Test func theResumeLoopRunsOneAtATimeAndStops() {
        var l = ResumeLoop()
        let first = l.request(), second = l.request()
        #expect(first && !second)
        let more = l.ended(stillSuspended: true, appActive: true)     // locked + unlocked during the ping: once more
        let away = l.ended(stillSuspended: true, appActive: false)    // in the background now: the next foreground asks
        #expect(more && !away && !l.running)
        let again = l.request()
        let done = l.ended(stillSuspended: false, appActive: true)
        #expect(again && !done && !l.running)
        // Never more than `maxRounds` in a row.
        _ = l.request()
        var rounds = 1
        while l.ended(stillSuspended: true, appActive: true) { rounds += 1 }
        #expect(rounds == ResumeLoop.maxRounds)
    }
}
