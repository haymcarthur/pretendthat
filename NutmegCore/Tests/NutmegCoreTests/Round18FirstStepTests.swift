import Foundation
import Testing
@testable import NutmegCore

// Round 18 (Haylee): when the checklist appears, Nutmeg names the first step, not just how to use the list.

@Test func checklistLineNamesTheFirstStep() {
    let l = HandOffLines.checklist(sceneLine: "Pretend that the show is about to start!", firstScene: true,
                                   firstStep: "Hang up the theater sign.")
    #expect(l == "Pretend that the show is about to start! First, hang up the theater sign! Tap each step when you do it, then tap Done!")
    let later = HandOffLines.checklist(sceneLine: "Snack time!", firstScene: false, firstStep: "Pass out the cups")
    #expect(later == "Snack time! First, pass out the cups! Tap the steps as you go, then tap Done!")
    let noLine = HandOffLines.checklist(sceneLine: "", firstScene: true, firstStep: "Hang up the sign")
    #expect(noLine == "First, hang up the sign! Tap each step when you do it, then tap Done!")
}

@Test func checklistLineSkipsTheFirstStepIfTheSceneLineNamesIt() {
    let l = HandOffLines.checklist(sceneLine: "Let's hang up the theater sign!", firstScene: true,
                                   firstStep: "Hang up the theater sign.")
    #expect(l == "Let's hang up the theater sign! Tap each step when you do it, then tap Done!")
    #expect(l.components(separatedBy: "theater sign").count == 2)
}

@Test func checklistLineWithHowAlreadySaidStillNamesTheFirstStep() {
    let says = "Tap each step as you do it, then tap Done!"
    #expect(HandOffLines.checklist(sceneLine: says, firstScene: true, firstStep: "Find a hat")
            == says + " First, find a hat!")
}
