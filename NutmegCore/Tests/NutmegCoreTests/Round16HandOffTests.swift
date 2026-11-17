import Foundation
import Testing
@testable import NutmegCore

// Round 16 (Haylee): every hand-off to the kid is said out loud with the real button labels. Round 29: a scene opens
// with its setup and every playing role's task.

private func clean(_ line: String) {
    #expect(!TurnCheck.hasSoundEffect(line), "\(line)")
    #expect(!line.contains("*") && !line.contains("("), "no stage directions: \(line)")
}

@Test func printReadyNamesBothPictureButtonsAndNeverSaysGoPlay() {
    let l = HandOffLines.printReady
    // Round 26: the buttons are pictures, so she names them: the printer and the green play button.
    // Round 27: and the two sets (color or plain), tapped to choose, then the printer.
    #expect(l.contains("the printer") && l.contains("the green play button") && l.contains("color"))
    #expect(!TurnCheck.mentionsGoPlay(l))
    #expect(AdventureStore.kitReadyLine == l)
    clean(l)
}

@Test func sceneOpenSaysTheSetupThenEveryTaskAndTheFirstSaysTheButton() {
    // Round 29 (ensemble scenes): one flowing line, the setup then each playing role's task by name.
    let sc = Scene(id: "s1", owner: .all, title: "Open", picture: .point, nutmegSays: "Pretend that the café just opened",
                   steps: [Step(picture: .point, text: "Waiter, take the Customer's order", role: .R1),
                           Step(picture: .point, text: "Customer, order from the menu!", role: .R2)])
    // Round 34 (Haylee): the setup and the cue only; each kid taps their row for their job.
    #expect(HandOffLines.sceneOpen(sc) == "Pretend that the café just opened. Tap your speaker when you're ready to hear your job!")
    #expect(HandOffLines.sceneOpen(sc, first: true).hasSuffix("Tap the green play button for the next scene!"))
    #expect(HandOffLines.task(sc.steps[0]) == "Waiter, take the Customer's order.")
    clean(HandOffLines.sceneOpen(sc, first: true))
}

@Test func endLineSaysWhatEachButtonDoes() {
    // Round 26 (Haylee's button audit): The End has a star (save, then home) and a house (home); a replay only the house.
    let plain = HandOffLines.end()
    #expect(plain.contains("Tap the star to save it") && plain.contains("the house to go home") && !plain.contains("Back"))
    #expect(HandOffLines.end(replay: true).contains("Tap the house to go home") && !HandOffLines.end(replay: true).contains("star"))
    clean(plain)
}

@Test @MainActor func playLinesUseTheSceneBuilders() async {
    let store = await storeWithKit(owners: [.R1, .R2], players: 2)
    store.beginPlay()
    #expect(store.inStory && store.nutmegLine == store.sceneLine(0))   // round 36: the story, then the setup
    store.nextScene()
    #expect(store.nutmegLine == HandOffLines.sceneOpen(store.kit!.scenes[1], first: true))
    for _ in 0..<8 where store.phase != .end { store.nextScene() }
    #expect(store.phase == .end)
    #expect(store.nutmegLine == HandOffLines.end())
    #expect(store.goTo(.play))   // the rail's Play at The End: the last scene again
    #expect(store.nutmegLine == HandOffLines.sceneOpen(store.kit!.scenes[5]))   // round 36: the clean-up scene
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
    #expect(Realtime.instructions.contains("Tap the printer to print it, then tap the green play button"))
    #expect(Realtime.instructions.contains("Never call it Start"))
}
