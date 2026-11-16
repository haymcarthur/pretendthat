import Foundation
import Testing
@testable import NutmegCore

struct LipSyncTests {
    private let sr = 24_000.0
    private func tone(_ hz: Double, seconds: Double, amp: Float = 0.3) -> [Float] {
        (0..<Int(sr * seconds)).map { amp * Float(sin(2 * .pi * hz * Double($0) / sr)) }
    }
    private func shapes(_ samples: [Float]) -> [MouthShape] {
        var a = LipSyncAnalyzer(sampleRate: sr), s = MouthShaper()
        return a.analyze(samples).map { s.step($0, at: $0.offset) }
    }

    @Test func spectralSplit() {
        var a = LipSyncAnalyzer(sampleRate: sr)
        let low = a.analyze(tone(250, seconds: 0.1)).last!
        a.reset()
        let high = a.analyze(tone(5000, seconds: 0.1)).last!
        #expect(low.low > 0.8 && low.bright < 0.01)
        #expect(high.bright > 0.1 && high.low < 0.01)
    }

    @Test func silenceIsClosedLowIsOohBrightIsWideMidIsOpen() {
        #expect(shapes([Float](repeating: 0, count: 4800)).last == .closed)
        #expect(shapes(tone(250, seconds: 0.2)).last == .ooh)
        #expect(shapes(tone(5000, seconds: 0.2)).last == .wide)
        #expect(shapes(tone(1500, seconds: 0.2)).last == .open)
        #expect(shapes(tone(1500, seconds: 0.2, amp: 0.02)).last == .small)
    }

    @Test func snapsOpenFastAndClosesOnPauses() {
        // 30 ms attack: open within ~60 ms of a syllable; 80 ms release: closed within ~200 ms of a pause.
        let syllable = tone(1500, seconds: 0.25), pause = [Float](repeating: 0, count: Int(sr * 0.25))
        let out = shapes(syllable + pause)
        #expect(out[6] != .closed)                 // 60 ms in
        #expect(out.last == .closed)
    }

    @Test func holdsEachShapeAtLeast60ms() {
        // Alternate bright and low every 20 ms: the shape must not change faster than every 60 ms.
        var samples: [Float] = []
        for k in 0..<20 { samples += tone(k % 2 == 0 ? 5000 : 250, seconds: 0.02) }
        var a = LipSyncAnalyzer(sampleRate: sr), s = MouthShaper()
        var last: MouthShape?, since = 0.0, minRun = Double.infinity
        for f in a.analyze(samples) {
            let shape = s.step(f, at: f.offset)
            if shape != last { if last != nil { minRun = min(minRun, f.offset - since) }; last = shape; since = f.offset }
        }
        #expect(minRun >= 0.06 - 1e-9)
    }
}

struct ExpressionToolTests {
    @Test func decodesSetExpression() {
        let d = NutmegExpression.decode(name: "set_expression", arguments: #"{"expression":"excited","seconds":null}"#)
        #expect(d?.expression == .excited && d?.seconds == nil)
        #expect(NutmegExpression.decode(name: "set_expression", arguments: #"{"expression":"ooh","seconds":2}"#)?.seconds == 2)
        #expect(NutmegExpression.decode(name: "set_expression", arguments: #"{"expression":"angry","seconds":null}"#) == nil)
        #expect(NutmegExpression.decode(name: "set_game", arguments: #"{"title":"x"}"#) == nil)
        #expect(PlanningCall.decode(name: "set_expression", arguments: #"{"expression":"happy","seconds":null}"#) == nil)
    }

    @Test func toolIsDeclaredAndBlipsMatchExclamations() {
        // Round 20 (cost): the face tool is gone from the one tools array (it was never offered after round 13).
        #expect(!Realtime.tools.contains { $0["name"] as? String == "set_expression" })
        // Round 13: faces come from her words (blips) and the app; spoken responses don't offer the face tool.
        #expect(!(((Realtime.responseCreateSpoken()["response"] as? [String: Any])?["tools"] as? [[String: Any]]) ?? []).contains { $0["name"] as? String == "set_expression" })
        #expect(NutmegExpression.blip(forReplyStart: "Ooh! A moon bakery?") == .ooh)
        #expect(NutmegExpression.blip(forReplyStart: "Wow, that's fun") == .ooh)
        #expect(NutmegExpression.blip(forReplyStart: "Yes! Let's go") == .excited)
        #expect(NutmegExpression.blip(forReplyStart: "So how many kids?") == nil)
    }
}

struct ConversationStepTests {
    @MainActor @Test func stepsFollowTheCalls() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        #expect(store.planningStep == .game)
        _ = await store.apply(.setGame("Bakery")); #expect(store.planningStep == .theme)
        _ = await store.apply(.setTheme("Bakery on the Moon")); #expect(store.planningStep == .players && store.gameTitle == "Bakery on the Moon")
        _ = await store.apply(.setPlayerCount(2)); #expect(store.planningStep == .confirm)
        _ = await store.confirmYes(); #expect(store.planningStep == .roles)   // round 26: no color question
        _ = await store.apply(.setRoles([.init(roleName: "Baker", job: "bakes"), .init(roleName: "Customer", job: "buys")]))
        #expect(store.planningStep == .props)
        #expect(PlanningCall.decode(name: "set_theme", arguments: #"{"title":"Zoo in Space"}"#) == .setTheme("Zoo in Space"))
    }

    @Test func turnEndings() {
        #expect(TurnCheck.nudge(for: "What do you want to play?", step: .game) != nil)              // no examples
        #expect(TurnCheck.nudge(for: "That sounds so fun.", step: .theme) != nil)                    // no question
        #expect(TurnCheck.nudge(for: "Ooh! A bakery on the moon, under the sea, or in a castle?", step: .theme) == nil)
        // Round 7: the count question is open; a closed list sounds like the maximum.
        #expect(TurnCheck.nudge(for: "Yay! Is it just you, or two, or three friends?", step: .players) != nil)
        #expect(TurnCheck.nudge(for: "Ooh, a moon bakery! How many friends are playing today?", step: .players) == nil)
        // Round 7: no permission checks after the roles (or anywhere).
        #expect(TurnCheck.nudge(for: "You're the Baker and the Customer! Sound good?", step: .roles) != nil)
        #expect(TurnCheck.nudge(for: "You're the Baker and the Customer! Sound good?", step: .props) != nil)
        #expect(TurnCheck.nudge(for: "Go find a pillow and a plate, and tell me when you're back!", step: .props) == nil)
        #expect(TurnCheck.nudge(for: "Here are your props.", step: .props) != nil)
        #expect(TurnCheck.nudge(for: "Want to start with the check-in desk, the exam room, or the rest spot?", step: .props) != nil)
        #expect(TurnCheck.nudge(for: "What do you feel like playing? Maybe a bakery, a rocket, or a jungle?", step: .game) == nil)
        // Push-to-talk reminder at the end: the question before it is what counts.
        #expect(TurnCheck.nudge(for: "What should we play: a rocket, a bakery, or a jungle? Hold the red button and tell me!", step: .game) == nil)
        #expect(TurnCheck.nudge(for: "That sounds fun. Hold the red button and tell me!", step: .game) != nil)
        #expect(TurnCheck.nudge(for: "Hold the red button and tell me!", step: .game) == nil)
        // Only a turn with no question and no instruction at all gets a continuation; never the reminder or a question.
        #expect(TurnCheck.needsCompletion(for: "Ooh, a pet rescue, so sweet!", step: .theme))
        #expect(!TurnCheck.needsCompletion(for: "Ooh! What twist: a jungle, a farm, or a zoo?", step: .theme))
        #expect(!TurnCheck.needsCompletion(for: "What twist? Hold the red button and tell me!", step: .theme))
        #expect(!TurnCheck.needsCompletion(for: "Go find a pillow and tell me when you're back!", step: .props))
        #expect(!TurnCheck.silenceNudge(step: .game).contains(PlanningStep.game.goal))   // never the full question again
        #expect(TurnCheck.nudge(for: "Hiya, I'm Nutmeg, ready for a show! What do you feel like playing today, maybe a rocket trip, a bakery, or a pet shop? Hold the red button and tell me!", step: .game) == nil)
    }
}

struct HuntTests {
    @MainActor @Test func oneAtATime() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Ship")); _ = await store.apply(.setTheme("Space Ship"))
        _ = await store.apply(.setPlayerCount(1)); _ = await store.confirmYes(); _ = await store.apply(.setRoles([.init(roleName: "Captain", job: "steer")]))
        _ = await store.apply(.showNextProp(.init(itemID: "plate", becomes: "steering wheel", forRole: "all")))
        #expect(store.props?.props.count == 1 && store.currentPropID == "plate" && store.huntActive)
        _ = await store.apply(.markFound("plate"))
        #expect(store.foundProps.contains("plate"))
        _ = await store.apply(.showNextProp(.init(itemID: "pillow", becomes: "seat", forRole: "all")))
        #expect(store.props?.props.count == 2 && store.currentPropID == "pillow")
        #expect(PlanningCall.decode(name: "show_next_prop", arguments: #"{"item_id":"plate","becomes":"wheel","for_role":"all","alternates":["bowl"]}"#)
                == .showNextProp(.init(itemID: "plate", becomes: "wheel", forRole: "all", alternates: ["bowl"])))
    }
}
