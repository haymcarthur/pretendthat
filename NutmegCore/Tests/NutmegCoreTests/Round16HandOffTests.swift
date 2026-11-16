import Foundation
import Testing
@testable import NutmegCore

// Round 16 (Haylee): every hand-off to the kid is said out loud with the real button labels, and the checklist's
// "Hear it again" reads the title + the steps left.

private func clean(_ line: String) {
    #expect(!TurnCheck.hasSoundEffect(line), "\(line)")
    #expect(!line.contains("*") && !line.contains("("), "no stage directions: \(line)")
}

@Test func printReadyNamesBothButtonsAndNeverSaysGoPlay() {
    let l = HandOffLines.printReady
    #expect(l.contains("Print") && l.contains("Let's play"))
    #expect(!TurnCheck.mentionsGoPlay(l.replacingOccurrences(of: "Let's play", with: "")))
    #expect(AdventureStore.kitReadyLine == l)
    clean(l)
}

@Test func handoffLineMatchesTheCardButton() {
    #expect(HandOffLines.handoff(spokenRole: "the Captain") == "Pass the iPad to the Captain, then tap I'm the Captain!")
    #expect(HandOffLines.handoff(spokenRole: "a Pirate") == "Pass the iPad to a Pirate, then tap I'm a Pirate!")
    clean(HandOffLines.handoff(spokenRole: "the Captain"))
}

@Test func checklistLineAddsHowToOnceAndNotTwice() {
    let first = HandOffLines.checklist(sceneLine: "Time to board the plane", firstScene: true)
    #expect(first == "Time to board the plane. Tap each step when you do it, then tap Done!")
    let later = HandOffLines.checklist(sceneLine: "Snack time on the plane!", firstScene: false)
    #expect(later == "Snack time on the plane! Tap the steps as you go, then tap Done!")
    // The scene line already says how: nothing added (no duplicate instruction).
    let says = "Tap each step as you do it, then tap Done!"
    #expect(HandOffLines.checklist(sceneLine: says, firstScene: true) == says)
    #expect(HandOffLines.checklist(sceneLine: "  ", firstScene: true) == "Tap each step when you do it, then tap Done!")
    clean(first)
}

@Test func endLineSaysWhatEachButtonDoes() {
    let plain = HandOffLines.end(canGoBack: false)
    #expect(plain.contains("Save it to play again") && plain.contains("New game") && !plain.contains("Back"))   // round D1
    #expect(HandOffLines.end(canGoBack: false, replay: true).contains("Play it again"))
    let back = HandOffLines.end(canGoBack: true)
    #expect(back.contains(HandOffLines.endBackHint) && !back.contains("Back to the checklist"))   // round 25
    clean(back)
}

@Test @MainActor func playLinesUseTheHandOffBuilders() async {
    let store = await storeWithKit(owners: [.R1, .R2], players: 2)
    store.autoCheckStep = .zero; store.autoCheckHold = .zero
    store.beginPlay()
    #expect(store.nutmegLine == "Pass the iPad to the Captain, then tap I'm the Captain!")
    store.badgeTapped(.R1)
    #expect(store.nutmegLine.hasSuffix("then tap Done!"))
    // Round 25: GuideRepair pads a short guide to 4 scenes; play through all of them.
    for _ in 0..<8 where store.phase != .end {
        if case .handoff(let i) = store.phase, let o = store.kit?.scenes[i].owner.role { store.badgeTapped(o) }
        await store.sceneDone()
    }
    #expect(store.phase == .end)
    #expect(store.nutmegLine == HandOffLines.end(canGoBack: true))
    store.backToChecklist()
    #expect(store.nutmegLine == HandOffLines.backToChecklist)
}

@Test func repeatReadsTitleAndOnlyTheStepsLeftInOrder() {
    let steps = ["Line up the seats.", "Hold the steering wheel", "Say: Welcome aboard!"]
    #expect(HandOffLines.repeatText(title: "Get the plane ready", steps: steps, checked: [])
            == "Get the plane ready. First, line up the seats. Then, hold the steering wheel. Last, say: Welcome aboard.")
    #expect(HandOffLines.repeatText(title: "Get the plane ready", steps: steps, checked: [0])
            == "Get the plane ready. First, hold the steering wheel. Last, say: Welcome aboard.")
    #expect(HandOffLines.repeatText(title: "Get the plane ready", steps: steps, checked: [0, 2])
            == "Get the plane ready. Last step: hold the steering wheel.")
}

@Test func repeatReadsEveryStepWhenAllAreChecked() {
    let steps = ["Line up the seats.", "Hold the steering wheel"]
    #expect(HandOffLines.repeatText(title: "Get the plane ready", steps: steps, checked: [0, 1])
            == "Get the plane ready. First, line up the seats. Last, hold the steering wheel.")
    #expect(HandOffLines.repeatText(title: "Wave", steps: ["Wave bye"], checked: [0]) == "Wave. Wave bye.")
    clean(HandOffLines.repeatText(title: "Get the plane ready", steps: steps, checked: []))
}

// Round 24 (Haylee): naming the "Let's play!" button is fine; telling the kids to go play at kit time is not.
@Test func namingTheLetsPlayButtonIsNotGoPlay() {
    for line in ["Tap Print, then tap Let's play when you're set!", "When you're ready, press Let's play!",
                 "Hit \"Let's play!\" once you've printed it.", HandOffLines.printReady] {
        #expect(!TurnCheck.mentionsGoPlay(line), "\(line)")
    }
    for line in ["Let's play pirates now!", "Your kit is ready, let's play!", "Tap Print, then go play!"] {
        #expect(TurnCheck.mentionsGoPlay(line), "\(line)")
    }
    #expect(Realtime.instructions.contains("call the button exactly \"Let's play!\""))
    #expect(Realtime.instructions.contains("Never call it Start"))
}
