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
        #expect(Realtime.tools.contains { $0["name"] as? String == "set_expression" })
        #expect(Realtime.instructions.contains("set_expression"))
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
        _ = await store.apply(.setPlayerCount(2)); #expect(store.planningStep == .roles)
        _ = await store.apply(.setRoles([.init(roleName: "Baker", job: "bakes"), .init(roleName: "Customer", job: "buys")]))
        #expect(store.planningStep == .props)
        #expect(PlanningCall.decode(name: "set_theme", arguments: #"{"title":"Zoo in Space"}"#) == .setTheme("Zoo in Space"))
    }

    @Test func turnEndings() {
        #expect(TurnCheck.nudge(for: "What do you want to play?", step: .game) != nil)              // no examples
        #expect(TurnCheck.nudge(for: "That sounds so fun.", step: .theme) != nil)                    // no question
        #expect(TurnCheck.nudge(for: "Ooh! A bakery on the moon, under the sea, or in a castle?", step: .theme) == nil)
        #expect(TurnCheck.nudge(for: "Yay! Is it just you, or two, or three friends?", step: .players) == nil)
        #expect(TurnCheck.nudge(for: "You're the Baker and the Customer! Sound good?", step: .roles) == nil)
        #expect(TurnCheck.nudge(for: "Go find a pillow and a plate, and tell me when you're back!", step: .props) == nil)
        #expect(TurnCheck.nudge(for: "Here are your props.", step: .props) != nil)
        #expect(TurnCheck.nudge(for: "Want to start with the check-in desk, the exam room, or the rest spot?", step: .props) != nil)
        #expect(TurnCheck.nudge(for: "What do you feel like playing? Maybe a bakery, a rocket, or a jungle?", step: .game) == nil)
    }
}

struct HuntTests {
    @Test func gateHearsOnlyLinesForNutmeg() {
        #expect(!HuntGate.addressed("Mom, where's the big plate?"))
        #expect(!HuntGate.addressed("Look at this cool rock"))
        #expect(HuntGate.addressed("Nutmeg, we found it!"))
        #expect(HuntGate.addressed("we don't have one"))
        #expect(HuntGate.addressed("Got it!"))
        #expect(HuntGate.addressed("I can’t find it"))
    }

    @MainActor @Test func oneAtATime() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Ship")); _ = await store.apply(.setTheme("Space Ship"))
        _ = await store.apply(.setPlayerCount(1)); _ = await store.apply(.setRoles([.init(roleName: "Captain", job: "steer")]))
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
