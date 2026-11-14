import Foundation
import Testing
@testable import NutmegCore

/// Round 9: the sleepy-Nutmeg clock and the state summary that goes into a silent reconnect.
struct DozeTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func awakeUntilTheReminderHasFinished() {
        let c = DozeClock()
        #expect(c.stage(at: t0.addingTimeInterval(500), eligible: true) == .awake)   // no reminder yet: never sleepy
    }

    @Test func sitsThenDroopsThenSleepsAfterReminderPlus30s() {
        var c = DozeClock()
        c.reminderFinished(at: t0)
        #expect(c.stage(at: t0.addingTimeInterval(29.9), eligible: true) == .awake)
        #expect(c.stage(at: t0.addingTimeInterval(30.1), eligible: true) == .sitting)
        #expect(c.stage(at: t0.addingTimeInterval(30 + DozeClock.sittingFor + 0.1), eligible: true) == .drowsy)
        let asleepAt = 30 + DozeClock.sittingFor + DozeClock.drowsyFor
        #expect(c.stage(at: t0.addingTimeInterval(asleepAt - 0.1), eligible: true) == .drowsy)
        #expect(c.stage(at: t0.addingTimeInterval(asleepAt + 0.1), eligible: true) == .asleep)
        #expect(c.stage(at: t0.addingTimeInterval(3600), eligible: true) == .asleep)   // stays asleep
    }

    @Test func wakingResetsUntilTheNextReminder() {
        var c = DozeClock()
        c.reminderFinished(at: t0)
        #expect(c.stage(at: t0.addingTimeInterval(60), eligible: true) == .asleep)
        c.wake()
        #expect(c.quietSince == nil)
        #expect(c.stage(at: t0.addingTimeInterval(600), eligible: true) == .awake)
        c.reminderFinished(at: t0.addingTimeInterval(700))
        #expect(c.stage(at: t0.addingTimeInterval(731), eligible: true) == .sitting)
    }

    @Test func neverSleepyWhenNotEligible() {
        var c = DozeClock()
        c.reminderFinished(at: t0)
        #expect(c.stage(at: t0.addingTimeInterval(120), eligible: false) == .awake)
        // Writing moment (roles) and kit making (finish) are never sleepy steps; the conversation steps are.
        #expect(!DozeClock.sleepyStep(.roles) && !DozeClock.sleepyStep(.finish))
        #expect(DozeClock.sleepyStep(.game) && DozeClock.sleepyStep(.theme) && DozeClock.sleepyStep(.players) && DozeClock.sleepyStep(.props))
    }

    @Test func scaleSpeedsUpDebugRuns() {
        var c = DozeClock(scale: 0.1)
        c.reminderFinished(at: t0)
        #expect(c.stage(at: t0.addingTimeInterval(3.1), eligible: true) == .sitting)
    }

    @Test func breathingIsDeeperAndSlowerAsleep() {
        let awake = (0..<400).map { IdleMotion.breathe(Double($0) * 0.05) }
        let asleep = (0..<400).map { IdleMotion.breathe(Double($0) * 0.05, asleep: true) }
        #expect((asleep.max()! - 1) > (awake.max()! - 1) * 1.5)
    }
}

@MainActor
struct ResumeTests {
    @Test func summaryCarriesStepChoicesCurrentPropKitAndRecentLines() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Train"))
        _ = await store.apply(.setTheme("Snowy Mountain Train"))
        _ = await store.apply(.setPlayerCount(2))
        _ = await store.apply(.setRoles([.init(roleName: "Conductor", job: "tickets"), .init(roleName: "Passenger", job: "rides")]))
        _ = await store.apply(.showNextProp(.init(itemID: "hat", becomes: "conductor's cap", forRole: "Conductor")))
        _ = await store.apply(.markFound("hat"))
        _ = await store.apply(.showNextProp(.init(itemID: "pillow", becomes: "train seat", forRole: "all")))
        var chat = RealtimeTranscript()
        chat.kidTyped("We found the hat!")
        chat.apply(.transcriptDone("Yay! Next, can you find a pillow? It'll be the train seat!"))
        let ctx = ResumeContext(store: store, transcript: chat.lines)
        #expect(ctx.step == .props)
        #expect(ctx.kit == .notYet)
        #expect(ctx.props.map(\.status) == [.found, .looking])
        let s = ctx.summary
        #expect(s.contains("Do NOT greet"))
        #expect(s.contains("do NOT repeat your last question"))
        #expect(s.contains("do NOT give new suggestions"))
        #expect(s.contains("Say NOTHING until a kid talks"))
        #expect(s.contains("Snowy Mountain Train"))
        #expect(s.contains("2 kids"))
        #expect(s.contains("Conductor, Passenger"))
        #expect(s.contains("Hat (id hat, becomes conductor's cap): found"))
        #expect(s.contains("Pillow (id pillow, becomes train seat): CURRENT card, still looking"))
        #expect(s.contains("find the pillow"))
        #expect(s.contains("Kid: We found the hat!"))
        #expect(s.contains("Nutmeg: Yay! Next, can you find a pillow?"))
        #expect(s.contains("Kit: not started"))
    }

    @Test func onlyTheLatestFewLinesAndLongLinesClipped() {
        let lines = (0..<20).map { (fromNutmeg: $0 % 2 == 0, text: "line \($0) " + String(repeating: "x", count: $0 == 19 ? 400 : 1)) }
        let ctx = ResumeContext(step: .game, gameTitle: nil, playerCount: 0, roles: [], props: [], kit: .notYet, recent: lines)
        #expect(ctx.recent.count == ResumeContext.maxLines)
        #expect(ctx.recent.first?.text.hasPrefix("line 14") == true)
        #expect(!ctx.summary.contains("line 13 "))
        #expect(ctx.summary.contains("…"))
        #expect(ctx.summary.contains("step 1"))
    }

    @Test func kitAndPlayPhasesAreDescribed() {
        let making = ResumeContext(step: .finish, gameTitle: "Pirates", playerCount: 3, roles: [], props: [], kit: .making, recent: [])
        #expect(making.summary.contains("making the play kit"))
        #expect(making.summary.contains("Kit: being made"))
        let ready = ResumeContext(step: .finish, gameTitle: "Pirates", playerCount: 3, roles: [], props: [], kit: .ready, recent: [])
        #expect(ready.summary.contains("start_play"))
        let playing = ResumeContext(step: .finish, gameTitle: "Pirates", playerCount: 3, roles: [], props: [], kit: .playing(scene: 1, of: 3), recent: [])
        #expect(playing.summary.contains("scene 2 of 3"))
    }

    @Test func resumeInstructionsKeepTheBaseInstructionsAndTodaysIdeas() {
        let games = Array(Suggestions.games.prefix(3))
        let ctx = ResumeContext(step: .game, gameTitle: nil, playerCount: 0, roles: [], props: [], kit: .notYet, recent: [])
        let s = Realtime.resumeInstructions(todayGames: games, context: ctx)
        #expect(s.hasPrefix(Realtime.instructions))
        #expect(s.contains("TODAY'S GAME IDEAS"))
        #expect(s.hasSuffix(ctx.summary))
    }
}

/// Round 9: "I'm the Captain" by voice on the hand-off card.
@MainActor
struct HandoffVoiceTests {
    @Test func confirmHandoffStartsTheSceneLikeTheButton() async {
        #expect(PlanningCall.decode(name: "confirm_handoff", arguments: "{}") == .confirmHandoff)
        let store = AdventureStore(service: nil)
        await store.start()
        await store.chooseGame("Airplane")
        store.setPlayerCount(3)
        await store.confirmPlayers()
        await store.confirmRoles()
        await store.confirmProps()
        let early = await store.apply(.confirmHandoff)
        #expect(early.contains("no hand-off"))
        store.beginPlay()
        var guardCount = 0
        while true {
            guardCount += 1
            if case .handoff = store.phase { break }
            if case .scene = store.phase { store.sceneDone(); store.nextScene() }
            if store.phase == .end || guardCount > 10 { Issue.record("no hand-off in the bundled game"); return }
        }
        guard case .handoff(let i) = store.phase else { return }
        let out = await store.apply(.confirmHandoff)
        #expect(out.contains("Hand-off confirmed"))
        #expect(store.phase == .scene(i))
    }
}
