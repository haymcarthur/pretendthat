import Foundation
import Testing
@testable import NutmegCore

// Round D3a: the speaker's rules, moved out of RealtimeSession unchanged (no behavior change).

private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

@Test func speakingStartsWithTheFirstBufferOnly() {
    var s = SpeakerTimeline(sampleRate: 24_000, playbackRate: 1.2)
    #expect(!s.isSpeaking)
    let first = s.willSchedule(frames: 2_400, now: t0)       // starts her speaking
    let second = s.willSchedule(frames: 2_400, now: t0)      // already speaking
    #expect(first && !second)
    #expect(s.isSpeaking)
}

@Test func speakingClockDividesOutVarispeed() {
    var s = SpeakerTimeline(sampleRate: 24_000, playbackRate: 1.2)
    s.willSchedule(frames: 24_000, now: t0)                  // 1 s of source audio plays in 1/1.2 s
    #expect(abs(s.speakingUntil.timeIntervalSince(t0) - 1 / 1.2) < 1e-9)
    s.willSchedule(frames: 24_000, now: t0)                  // queued after the first
    #expect(abs(s.speakingUntil.timeIntervalSince(t0) - 2 / 1.2) < 1e-9)
    // A buffer arriving after a gap starts from now, not from the old end.
    let later = t0.addingTimeInterval(10)
    s.willSchedule(frames: 12_000, now: later)
    #expect(abs(s.speakingUntil.timeIntervalSince(later) - 0.5 / 1.2) < 1e-9)
}

@Test func endCheckWaitsForTheTailAndALaterBufferPushesItOut() {
    var s = SpeakerTimeline(sampleRate: 24_000, playbackRate: 1)
    s.willSchedule(frames: 24_000, now: t0)                  // ends at t0 + 1
    #expect(abs(s.endCheckDelay(now: t0) - 1.45) < 1e-9)
    #expect(!s.hasFinished(now: t0.addingTimeInterval(1.3)))
    #expect(s.hasFinished(now: t0.addingTimeInterval(1.45)))
    s.willSchedule(frames: 24_000, now: t0.addingTimeInterval(0.5))
    #expect(!s.hasFinished(now: t0.addingTimeInterval(1.45)))   // still talking
    #expect(s.endCheckDelay(now: t0.addingTimeInterval(5)) == SpeakerTimeline.minEndWait)
    _ = s.place(frames: 48_000, player: nil, hostNow: 0, latency: 0)
    s.finish()
    #expect(!s.isSpeaking && s.scheduledEnd == 48_000)       // a normal end keeps the schedule
}

@Test func placementQueuesBuffersBackToBackAndStampsWhenHeard() {
    var s = SpeakerTimeline(sampleRate: 24_000, playbackRate: 1.2)
    // Not rendering yet: the first buffer starts at 0, heard after the latency.
    #expect(abs(s.place(frames: 2_400, player: nil, hostNow: 50, latency: 0.02) - 50.02) < 1e-9)
    #expect(s.scheduledEnd == 2_400)
    // The player is at sample 1_200 now: the next buffer waits for the first to end (1_200 samples later).
    let heard = s.place(frames: 2_400, player: (sample: 1_200, hostTime: 60), hostNow: 99, latency: 0.02)
    #expect(abs(heard - (60 + 1_200.0 / 24_000 / 1.2 + 0.02)) < 1e-9)
    #expect(s.scheduledEnd == 4_800)
    // The player ran past the schedule (a gap): the buffer starts where the player is.
    _ = s.place(frames: 100, player: (sample: 9_000, hostTime: 70), hostNow: 99, latency: 0)
    #expect(s.scheduledEnd == 9_100)
}

@Test func bargeInTruncatesAtWhatWasHeardAndClears() {
    var s = SpeakerTimeline(sampleRate: 24_000, playbackRate: 1.2)
    let start = s.itemStart(playerSample: nil)
    #expect(start == 0)
    _ = s.place(frames: 48_000, player: nil, hostNow: 0, latency: 0)   // 2 s of her item scheduled
    s.willSchedule(frames: 48_000, now: t0)
    #expect(s.heardMs(itemStart: start, playerSample: 12_000) == 500)  // half a second heard
    #expect(s.heardMs(itemStart: start, playerSample: 99_999) == 2_000) // capped at what was scheduled
    #expect(s.heardMs(itemStart: start, playerSample: nil) == 0)       // no render time: nothing heard
    #expect(s.itemStart(playerSample: 100) == 48_000)                  // a new item queues after hers
    s.clear()
    #expect(!s.isSpeaking && s.scheduledEnd == 0 && s.speakingUntil == .distantPast)
    #expect(s.hasFinished(now: t0))
}

@Test func lastLineMemoryKeepsTheLatestRealLine() {
    var m = LastLineMemory()
    #expect(m.line == nil)
    m.remember("Your kit is ready!")
    m.remember("   ")
    #expect(m.line == "Your kit is ready!")
    m.remember("Tap Let's play!")
    #expect(m.line == "Tap Let's play!")
    // It's the Repeat fallback when there's no chat line.
    #expect(RepeatTarget.choose(inScene: false, busy: false, transcriptLast: nil, appLast: m.line) == .lastLine("Tap Let's play!"))
}

@Test func kidTurnStopRulesAreUnchanged() {
    // Round 20: a kid turn stops her if anything of hers is running, playing (incl. audio still queued for the mouth),
    // or in flight.
    #expect(SpeechStop.kidTurnStops(responseActive: false, playing: true, inFlight: []))
    #expect(SpeechStop.kidTurnStops(responseActive: true, playing: false, inFlight: []))
    #expect(SpeechStop.kidTurnStops(responseActive: false, playing: false, inFlight: ["resp_1"]))
    #expect(!SpeechStop.kidTurnStops(responseActive: false, playing: false, inFlight: []))
    #expect(UserAction.allCases.filter { !$0.stopsSpeech } == [.chatTab, .toggleChat])
}

@Test func clipSeamPicksLiveWithoutAClip() {
    #expect(SpeechSource.choose(clipKey: nil) == .live)
    #expect(SpeechSource.choose(clipKey: "abc") == .clip(key: "abc"))
}

@Test func nutmegVoiceIsFrozen() {
    // D4.5: the replay voice must match the live voice (coral, Varispeed 1.20).
    let c = VoiceConfig.nutmeg
    #expect(c.voice == "coral" && c.method == .varispeed && c.rate == 1.20 && c.playbackRate == 1.20)
}
