import Foundation
import Testing
@testable import NutmegCore

// Round 17 (Haylee): the pill's Repeat button picks what to say again.

@Test func repeatReadsTheSceneDuringPlay() {
    #expect(RepeatTarget.choose(inScene: true, busy: false, transcriptLast: "Wonderful!", appLast: nil) == .scene)
    #expect(RepeatTarget.choose(inScene: true, busy: false, transcriptLast: nil, appLast: nil) == .scene)
}

@Test func repeatSaysHerLastLineElsewhere() {
    #expect(RepeatTarget.choose(inScene: false, busy: false, transcriptLast: "  Who wants to be the pilot? ",
                                appLast: "old") == .lastLine("Who wants to be the pilot?"))
    // No chat (device voice): the last line the app gave her.
    #expect(RepeatTarget.choose(inScene: false, busy: false, transcriptLast: nil, appLast: "Your kit is ready!")
            == .lastLine("Your kit is ready!"))
    #expect(RepeatTarget.choose(inScene: false, busy: false, transcriptLast: "  ", appLast: "Hi!") == .lastLine("Hi!"))
}

@Test func repeatIsDimmedWithNothingToSayOrWhileBusy() {
    #expect(RepeatTarget.choose(inScene: false, busy: false, transcriptLast: nil, appLast: nil) == .none)
    #expect(RepeatTarget.choose(inScene: false, busy: false, transcriptLast: "", appLast: " \n") == .none)
    #expect(RepeatTarget.choose(inScene: false, busy: true, transcriptLast: "Hi!", appLast: nil) == .none)
    #expect(RepeatTarget.choose(inScene: true, busy: true, transcriptLast: nil, appLast: nil) == .none)
    #expect(!RepeatTarget.none.isAvailable && RepeatTarget.scene.isAvailable)
    #expect(RepeatTarget.debounce >= 2)
}
