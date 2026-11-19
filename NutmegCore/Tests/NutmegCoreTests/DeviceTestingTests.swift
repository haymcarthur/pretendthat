import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-18 (Haylee's device testing, decisions/2026-11-18-device-testing-fixes.md).
struct DeviceTestingTests {

    // MARK: Back from idle / lock

    @Test func foregroundResumesASuspendedSession() {
        #expect(ForegroundRecovery.decide(suspended: true, live: true, connecting: false, gameHadVoice: true, inGame: true, busy: false) == .resume)
        // Suspended while a reconnect was still connecting: resume (the ping decides).
        #expect(ForegroundRecovery.decide(suspended: true, live: false, connecting: true, gameHadVoice: true, inGame: true, busy: false) == .resume)
    }

    @Test func foregroundReconnectsASessionThatDiedWhileAway() {
        // The bug: the reconnect failed (or the session failed in the background) and nothing ever tried again, so
        // the mic and the taps did nothing for the rest of the game.
        #expect(ForegroundRecovery.decide(suspended: false, live: false, connecting: false, gameHadVoice: true, inGame: true, busy: false) == .reconnect)
    }

    @Test func foregroundLeavesEverythingElseAlone() {
        // Live and fine.
        #expect(ForegroundRecovery.decide(suspended: false, live: true, connecting: false, gameHadVoice: true, inGame: true, busy: false) == .none)
        // Already connecting / a reconnect running.
        #expect(ForegroundRecovery.decide(suspended: false, live: false, connecting: true, gameHadVoice: true, inGame: true, busy: false) == .none)
        #expect(ForegroundRecovery.decide(suspended: true, live: false, connecting: false, gameHadVoice: true, inGame: true, busy: true) == .none)
        // Home screen, or a game that never had a voice (no keys / demo), or an offline replay.
        #expect(ForegroundRecovery.decide(suspended: false, live: false, connecting: false, gameHadVoice: true, inGame: false, busy: false) == .none)
        #expect(ForegroundRecovery.decide(suspended: false, live: false, connecting: false, gameHadVoice: false, inGame: true, busy: false) == .none)
        #expect(ForegroundRecovery.decide(suspended: false, live: false, connecting: false, gameHadVoice: true, inGame: true, busy: false,
                                          offlineReplay: true) == .none)
    }

    @Test func aFailedReconnectTriesAgainThenStops() {
        #expect(ReconnectBackoff.delay(before: 0) == 0)
        #expect(ReconnectBackoff.delay(before: 1) == 1.5)
        #expect(ReconnectBackoff.delays.count == 4)
        #expect(ReconnectBackoff.delay(before: 4) == nil)
        // Never longer than ~15 s in all before it gives up (the next tap or foreground tries again).
        #expect(ReconnectBackoff.delays.reduce(0, +) < 15)
    }

    @Test func anIdleSocketIsDeadAfterTwoMissedPongs() {
        var h = SocketHealth()
        var dead = h.pinged(ok: false)
        #expect(!dead)                  // one slow pong is not a drop
        dead = h.pinged(ok: true)
        #expect(!dead)                  // and an answer resets the count
        dead = h.pinged(ok: false)
        #expect(!dead)
        dead = h.pinged(ok: false)
        #expect(dead)                   // two in a row: reconnect
        h.reset()
        #expect(h.missed == 0)
    }

    // MARK: Sounds like a game you have: the spoken answer

    @Test func theSavedGameByVoice() {
        for s in ["That one!", "the saved one", "play it", "Yes!", "yeah", "The same one please", "play that one again",
                  "the airplane one", "AIRPLANE"] {
            #expect(SavedOrNew.decide(s, savedTitle: "Airplane to the Beach") == .saved, "\(s)")
        }
    }

    @Test func aNewGameByVoice() {
        for s in ["a new one", "New game!", "something else", "no", "Nope", "a different one", "make another one",
                  "yes a new one", "okay something else", "I want a new airplane game"] {
            #expect(SavedOrNew.decide(s, savedTitle: "Airplane to the Beach") == .new, "\(s)")
        }
    }

    @Test func unclearAnswersAskOnceMore() {
        for s in ["", "um", "pizza", "that one or a new one", "no, that one"] {
            #expect(SavedOrNew.decide(s, savedTitle: "Airplane to the Beach") == .unclear, "\(s)")
        }
        // Place words in the title never count as saying it ("shop" alone isn't the Pet Shop).
        #expect(SavedOrNew.decide("shop", savedTitle: "Pet Shop") == .unclear)
    }

    @Test func soundsLikeLinesAskBothChoices() {
        let l = ShelfLines.soundsLike(title: "Pet Vet")
        #expect(l.contains("play that one") && l.contains("new game"))
        // 2026-11-18 (picture only, no buttons): the unclear-answer line asks in words, never points at a button.
        let again = ShelfLines.soundsLikeAgain(title: "Pet Vet")
        #expect(again == "Do you want to play Pet Vet again, or make a new game?")
        #expect(!again.lowercased().contains("tap") && !again.contains("sparkles"))
        #expect(ShelfLines.soundsLikeOutput.contains("Say NOTHING"))
        #expect(!ShelfLines.soundsLikeOutput.contains("Tap the one you want"))
    }

    // MARK: Play: she looks up while she talks

    @Test func sheLooksUpWhileSpeakingAndDownAfter() {
        var g = PeekGaze()
        #expect(g.look(at: 0) == .down)            // reading the rows
        g.speaking(true, at: 1)
        #expect(g.look(at: 1.2) == .up)            // a role's job / the setup line
        g.speaking(false, at: 3)
        #expect(g.look(at: 3.2) == .up)            // a short pause between sentences: no flicker
        #expect(g.look(at: 3 + PeekGaze.hold + 0.01) == .down)   // back to the checklist
        g.speaking(true, at: 3.3)                  // the next sentence starts inside the hold: still up
        #expect(g.look(at: 3.4) == .up)
    }

    @Test func herHeadTipsUpAndBackSmoothly() {
        var g = PeekGaze()
        #expect(g.headUp(at: 0) == 0)
        g.speaking(true, at: 10)
        #expect(g.headUp(at: 10) == 0)
        let mid = g.headUp(at: 10 + PeekGaze.tip / 2)
        #expect(mid > 0.3 && mid < 0.7)
        #expect(g.headUp(at: 10 + PeekGaze.tip) == 1)
        g.speaking(false, at: 12)
        #expect(g.headUp(at: 12.2) == 1)                                   // the hold
        g.speaking(true, at: 12.3)                                         // the next sentence: no dip
        #expect(g.headUp(at: 12.31) == 1)
        g.speaking(false, at: 14)
        #expect(g.headUp(at: 14 + PeekGaze.hold + PeekGaze.tip) == 0)    // back down at the rows
    }

    @Test func stoppingWithoutSpeakingChangesNothing() {
        var g = PeekGaze()
        g.speaking(false, at: 5)
        #expect(g.look(at: 5.1) == .down)
        #expect(g.stoppedAt == nil)
    }
}
