import Testing
@testable import NutmegCore

/// Regression (Haylee's recording): the conversation must start in the idle pose with live resting motion; the
/// coloring pose is retired.
struct PoseStartTests {
    @Test func conversationStartsIdle() {
        for phase in [Phase.pickGame, .players, .props] {
            let coloring = PoseRules.isColoring(phase: phase, planningBeat: false, kitBeat: .coloring)
            #expect(!coloring)
            #expect(PoseRules.base(napping: false, coloring: coloring) == .idle)
        }
    }

    @Test func neverColoring() {   // revert-animation.md: idle with expressions, also while the kit is made
        for phase in [Phase.pickGame, .props, .makingKit, .kitReady, .scene(0)] {
            for beat in [PTStageDirector.KitBeat.coloring, .lookUp, .papers] {
                #expect(!PoseRules.isColoring(phase: phase, planningBeat: true, kitBeat: beat))
            }
        }
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
