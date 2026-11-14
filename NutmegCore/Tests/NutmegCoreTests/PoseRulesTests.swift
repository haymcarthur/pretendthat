import Foundation
import Testing
@testable import NutmegCore

@Test func idleIsTheRestingDefault() {
    #expect(PoseRules.base(napping: false, coloring: false) == .idle)
    #expect(PoseRules.base(napping: true, coloring: false) == .sit)
    #expect(PoseRules.base(napping: false, coloring: true) == .clipboardBoth)   // round 5: writing holds the clipboard
}

@Test func gesturesAreBriefAndOnlyOverIdle() {
    for g in [NutmegGesture.wave, .point, .celebrate] { #expect(PoseRules.hold(g) >= 1.2 && PoseRules.hold(g) <= 2.0) }
    #expect(PoseRules.allowsGesture(over: .idle))
    #expect(!PoseRules.allowsGesture(over: .sit))
    #expect(!PoseRules.allowsGesture(over: .coloring))
}

@Test func swapsAreThrottled() {
    let t0 = Date(timeIntervalSinceReferenceDate: 1000)
    #expect(PoseRules.delay(lastSwap: nil, now: t0) == 0)
    #expect(abs(PoseRules.delay(lastSwap: t0, now: t0.addingTimeInterval(0.5)) - 1.0) < 0.001)
    #expect(PoseRules.delay(lastSwap: t0, now: t0.addingTimeInterval(2)) == 0)
}

@Test func clipboardBothWhileTheKitIsMade() {   // round 3: whole pose from "making your pages" until the kit is final
    #expect(PoseRules.base(napping: false, coloring: false, clipboard: true) == .clipboardBoth)
    #expect(PoseRules.base(napping: true, coloring: false, clipboard: true) == .sit)
    #expect(PoseRules.holdsClipboard(phase: .makingKit, kitBeat: .coloring))
    #expect(PoseRules.holdsClipboard(phase: .kitReady, kitBeat: .coloring))   // pages still drawing
    #expect(!PoseRules.holdsClipboard(phase: .kitReady, kitBeat: .lookUp))    // back to idle for the paper reveal
    #expect(!PoseRules.holdsClipboard(phase: .kitReady, kitBeat: .papers))
    for phase in [Phase.pickGame, .players, .props, .scene(0)] { #expect(!PoseRules.holdsClipboard(phase: phase, kitBeat: .coloring)) }
    #expect(!PoseRules.allowsGesture(over: .clipboardBoth))
    #expect(PoseRules.minSwapInterval >= 1)   // held at least 1 s
}
