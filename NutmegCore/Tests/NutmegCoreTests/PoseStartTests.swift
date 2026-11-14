import Testing
@testable import NutmegCore

/// Regression (Haylee's recording): the conversation must start in the idle pose with live resting motion. Round 5:
/// the writing moment (clipboardBoth) runs only during a planning beat or while the kit is being written.
struct PoseStartTests {
    @Test func conversationStartsIdle() {
        for phase in [Phase.pickGame, .players, .props] {
            let writing = PoseRules.isWriting(phase: phase, planningBeat: false, kitWriting: true)
            #expect(!writing)
            #expect(PoseRules.base(napping: false, coloring: writing) == .idle)
        }
    }

    @Test func writesOnEveryPlanningBeatAndTheKit() {
        for phase in [Phase.players, .props] { #expect(PoseRules.isWriting(phase: phase, planningBeat: true, kitWriting: false)) }
        #expect(PoseRules.isWriting(phase: .makingKit, planningBeat: false, kitWriting: true))
        #expect(PoseRules.isWriting(phase: .kitReady, planningBeat: false, kitWriting: true))
        #expect(!PoseRules.isWriting(phase: .kitReady, planningBeat: false, kitWriting: false))
        #expect(!PoseRules.isWriting(phase: .scene(0), planningBeat: false, kitWriting: true))
        #expect(PoseRules.base(napping: false, coloring: true) == .coloring)   // round 8: one-paw writing body
        #expect(PoseRules.minPlanningBeat >= 1.8 && PoseRules.minKitWriting > PoseRules.minPlanningBeat)
    }

    @Test func idleMotionIsActive() {
        // Breathing moves within any second, and she blinks at least twice in the first 15 s.
        let samples = stride(from: 0.0, to: 1.0, by: 1.0 / 30).map { IdleMotion.breathe($0) }
        #expect((samples.max()! - samples.min()!) > 0.005)
        var blinks = 0, wasClosed = false
        for t in stride(from: 0.0, to: 15.0, by: 1.0 / 60) {
            let c = IdleMotion.blink(t); if c && !wasClosed { blinks += 1 }; wasClosed = c
        }
        #expect(blinks >= 2)
    }
}

/// Prop lines (fix round 2): only the first prop explains "say found it / tell me if you don't".
struct PropLineTests {
    @Test func onlyFirstPropExplains() {
        let first = AdventureStore.nextPropOutput(id: "plate", item: "Plate", becomes: "the steering wheel", n: 1)
        let second = AdventureStore.nextPropOutput(id: "spoon", item: "Spoon", becomes: "the big stirrer", n: 2)
        // Round 7: the first prop explanation moved to its own line, asked after the roles finish playing.
        #expect(AdventureStore.firstPropLine(item: "Plate", becomes: "the steering wheel").contains("explain ONCE"))
        #expect(first.contains("Speak ONLY the roles"))
        #expect(second.contains("Next, can you find a spoon? It'll be the big stirrer!"))
        #expect(second.contains("Do NOT repeat"))
        #expect(!second.contains("explain ONCE"))
    }
}
