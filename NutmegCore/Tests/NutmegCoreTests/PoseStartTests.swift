import Testing
@testable import NutmegCore

/// Regression (Haylee's recording): the conversation must start in the idle pose with live resting motion; the
/// coloring pose only appears during a planning beat or while the kit is made.
struct PoseStartTests {
    @Test func conversationStartsIdle() {
        for phase in [Phase.pickGame, .players, .props] {
            let coloring = PoseRules.isColoring(phase: phase, planningBeat: false, kitBeat: .coloring)
            #expect(!coloring)
            #expect(PoseRules.base(napping: false, coloring: coloring) == .idle)
        }
    }

    @Test func coloringOnlyInBeatsAndKit() {
        #expect(PoseRules.isColoring(phase: .pickGame, planningBeat: true, kitBeat: .papers))
        #expect(PoseRules.isColoring(phase: .makingKit, planningBeat: false, kitBeat: .coloring))
        #expect(!PoseRules.isColoring(phase: .kitReady, planningBeat: false, kitBeat: .lookUp))
        #expect(!PoseRules.isColoring(phase: .scene(0), planningBeat: false, kitBeat: .coloring))
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
