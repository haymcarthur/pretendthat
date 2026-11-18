import Foundation
import Testing
@testable import NutmegCore

// 2026-11-18 (Haylee): it's a "game", never a "show" (decisions/2026-11-18-small-fixes.md). "Show Pass" (the plan) and
// shows that ARE the game's subject (a puppet show, a talent show) are fine; Nutmeg's own lines never call the game a show.
@Suite struct GameNotShowTests {
    static func saysShow(_ s: String) -> Bool {
        s.lowercased().split(whereSeparator: { !$0.isLetter }).contains { $0 == "show" || $0 == "shows" }
    }

    @Test func theEndSaysWhatAGame() {
        #expect(HandOffLines.endLine.hasPrefix("The end! What a game! Take a bow!"))
        #expect(!Self.saysShow(HandOffLines.end()))
        #expect(CommonLines.all.contains(HandOffLines.endLine))   // still a bundled clip (re-recorded)
    }

    /// Every bundled line has ITS clip (the key is the words): a changed line whose old clip was left behind fails here.
    @Test func everyBundledLineHasItsOwnClip() {
        for line in CommonLines.all {
            let f = VoicePitchTests.commonClips.appendingPathComponent("common-\(CommonLines.key(line)).aac")
            #expect(FileManager.default.fileExists(atPath: f.path), "no clip for: \(line)")
        }
    }

    @Test func herFixedLinesNeverCallTheGameAShow() {
        let lines = [HandOffLines.printReady, HandOffLines.nextSceneHowTo, HandOffLines.end(), TurnCheck.silenceLine]
            + PretendLine.openers + KitProgress.allLines + CommonLines.all
        for line in lines { #expect(!Self.saysShow(line), "\(line)") }
        #expect(!Self.saysShow(Bookends.fallbackStory(title: "", roles: [])))
        #expect(Bookends.fallbackStory(title: "", roles: []).contains("Welcome to our game!"))
    }

    @Test func theBundledFallbackGameNeverCallsItAShow() {
        let a = Fallback.airplane
        #expect(a.ideas.nutmegSays == "Ooh! Let's play a game! Which one?")
        let lines = [a.ideas.nutmegSays, a.plan.nutmegSays, a.props.nutmegSays, a.kit.story ?? ""]
            + a.kit.scenes.map(\.nutmegSays) + [a.kit.setup?.nutmegSays ?? "", a.kit.cleanup?.nutmegSays ?? ""]
        for line in lines { #expect(!Self.saysShow(line), "\(line)") }
    }
}
