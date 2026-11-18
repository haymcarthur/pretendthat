import Foundation
import Testing
@testable import NutmegCore

/// Replay Pick with no number tiles (Haylee, 2026-11-17): with no voice session the count is read on the device.
@MainActor @Suite struct ReplayCountTests {
    @Test func readsDigitsWordsAndSentences() {
        #expect(ReplayCount.parse("3") == 3)
        #expect(ReplayCount.parse("three") == 3)
        #expect(ReplayCount.parse("Three.") == 3)
        #expect(ReplayCount.parse("we have four") == 4)
        #expect(ReplayCount.parse("4 kids") == 4)
        #expect(ReplayCount.parse("4kids!") == 4)
        #expect(ReplayCount.parse("  six  ") == 6)
        #expect(ReplayCount.parse("There are 2 of us") == 2)
        #expect(ReplayCount.parse("one") == 1)
    }

    @Test func readsMeAndOthers() {
        #expect(ReplayCount.parse("just me") == 1)
        #expect(ReplayCount.parse("only me") == 1)
        #expect(ReplayCount.parse("me") == 1)
        #expect(ReplayCount.parse("me and my sister") == 2)
        #expect(ReplayCount.parse("my brother and me") == 2)
        #expect(ReplayCount.parse("me and mom and dad") == 3)
        #expect(ReplayCount.parse("me & my friend") == 2)
        #expect(ReplayCount.parse("me and 2 friends") == 3)
    }

    @Test func noCountIsNil() {
        #expect(ReplayCount.parse("") == nil)
        #expect(ReplayCount.parse("pirates!") == nil)
        #expect(ReplayCount.parse("we want to play") == nil)
        #expect(ReplayCount.parse("go for it too") == nil)
    }

    @Test func decideKeepsOneToSix() {
        #expect(ReplayCount.decide("five") == .pick(5))
        #expect(ReplayCount.decide("1") == .pick(1))
        #expect(ReplayCount.decide("0") == .outOfRange(0))
        #expect(ReplayCount.decide("nobody") == .outOfRange(0))
        #expect(ReplayCount.decide("ten") == .outOfRange(10))
        #expect(ReplayCount.decide("seven kids") == .outOfRange(7))
        #expect(ReplayCount.decide("twenty-one") == .outOfRange(21))
        #expect(ReplayCount.decide("banana") == .noNumber)
    }

    @Test func theReAskIsHerRecordedQuestion() {
        // The re-ask is a bundled line (plays offline); the range hint is text only, never spoken.
        #expect(CommonLines.all.contains(ReplayCount.reask))
        #expect(!CommonLines.all.contains(ReplayCount.rangeHint))
        #expect(ReplayCount.rangeHint.contains("1 to 6"))
    }

    @Test func onlyAReplaysPickWithNoVoiceIsReadOnDevice() {
        #expect(ReplayCount.handlesOnDevice(isReplay: true, phase: .players, voiceLive: false))
        #expect(!ReplayCount.handlesOnDevice(isReplay: true, phase: .players, voiceLive: true))   // voice: unchanged
        #expect(!ReplayCount.handlesOnDevice(isReplay: false, phase: .players, voiceLive: false))   // first play
        #expect(!ReplayCount.handlesOnDevice(isReplay: true, phase: .props, voiceLive: false))
    }

    /// The no-voice path end to end in the store: a typed or spoken answer moves the replay on to Props with that count;
    /// an out-of-range or empty answer keeps Pick (she re-asks), so it never dead-ends.
    @Test func noVoiceReplayPickGoesOnToProps() async {
        let store = AdventureStore(service: nil)
        store.loadReplay(RoundD1Fixtures.game())
        #expect(store.phase == .players)
        for text in ["ten", "banana", "0"] {
            if case .pick = ReplayCount.decide(text) { Issue.record("\(text) picked") }
            #expect(store.phase == .players)
        }
        guard case .pick(let n) = ReplayCount.decide("we have three"),
              ReplayCount.handlesOnDevice(isReplay: store.isReplay, phase: store.phase, voiceLive: false) else {
            Issue.record("no pick"); return
        }
        store.replayPick(n)
        #expect(store.playerCount == 3)
        #expect(store.phase == .props)
    }

    /// A game's FIRST replay with no voice session: none of its lines are recorded (only the bundled common lines are).
    /// Every line it reaches is shown as her text (with a recorded stand-in where one fits) and nothing pauses.
    @Test func aNeverReplayedGameOfflineNeverBlocks() async {
        var commonKeys: [String: String] = [:]
        for l in CommonLines.all { commonKeys[l] = CommonLines.key(l) }
        let clips = ClipIndex(clips: [], commonKeys: commonKeys)   // no game clips: never replayed
        let store = AdventureStore(service: nil)
        store.loadReplay(RoundD1Fixtures.game())

        // The greeting ("Airplane! How many friends…") was never recorded: text, with her recorded question.
        let greeting = store.nutmegLine
        #expect(!clips.has(greeting))
        #expect(LineRoute.choose(hasClip: false, live: false, replay: true, recordable: true) == .caption)
        let g = OfflineLine.plan(greeting, hasClip: clips.has)
        #expect(g.caption == greeting && g.standIn == ReplayLines.howMany)

        // The kid types "four"; the count line ("Four friends! Our crew is…") is text only, and the game is on Props.
        guard case .pick(let n) = ReplayCount.decide("four") else { Issue.record("no pick"); return }
        store.replayPick(n)
        #expect(store.phase == .props)
        let count = OfflineLine.plan(store.nutmegLine, hasClip: clips.has)
        #expect(count.caption.hasPrefix("Four friends!") && count.standIn == nil)
        // The first prop line follows (text too), and the hunt goes on with ✓ / ✗.
        let follow = store.takeReplayFollowUp()
        #expect(follow != nil)
        #expect(OfflineLine.plan(follow ?? "", hasClip: clips.has).caption == follow)
        store.replayHunt(found: false)
        #expect(store.nutmegLine.isEmpty == false)
        // A "pretend" line gets her recorded "No problem, we'll pretend!" when it's that kind of line.
        #expect(OfflineLine.plan(ReplayLines.pretend("magic wand"), hasClip: clips.has).standIn == "No problem, we'll pretend!")
    }
}
