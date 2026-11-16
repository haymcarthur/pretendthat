import Foundation

/// Round 23 (Haylee): clearer navigation back to earlier steps. Finished steps on the rail look tappable (a picture
/// plus a small go-back mark), and voice ("print it again", "go back to the props") goes through the same
/// `AdventureStore.goTo`. On arrival Nutmeg says one short line. (Print again buttons were built, then removed:
/// the rail's go-back marks are enough.)
public enum BackNav {
    /// The picture on each rail step (SF Symbols, iPadOS 17, filled like the others). Round 25 (Haylee): the step is
    /// "Print" again and shows a printer (no sheet-with-crayon: drawing is gone).
    public static func symbol(_ step: JourneyStep) -> String {
        switch step {
        case .game: "theatermasks.fill"
        case .getReady: "shippingbox.fill"
        case .print: "printer.fill"
        case .play: "play.fill"
        }
    }
    /// A second symbol drawn over the step's picture, or nil (round 25: none; Paper's crayon is gone).
    public static func overlay(_ step: JourneyStep) -> String? { nil }

    /// The small mark on a reachable step that isn't the current one: back (↺) for finished steps, forward for a later
    /// step already reached (after going back).
    public static func mark(_ step: JourneyStep, current: JourneyStep?) -> String {
        step.rawValue < (current?.rawValue ?? -1) ? "arrow.counterclockwise" : "arrow.clockwise"
    }

    /// What she says on arrival (one short line).
    public static func arrivalLine(_ step: JourneyStep) -> String {
        switch step {
        case .game: return "Back to Pick! This is the game we picked."
        case .getReady: return "Back to Props! Here's everything for our game."
        case .print: return "Back to Print! Tap Print to print it again."
        case .play: return "Back to Play! Let's pick up where we left off."
        }
    }

    /// The voice tool's step names (the rail's names; "game" and "paper" still work).
    public static let toolSteps: [String: JourneyStep] = ["pick": .game, "game": .game, "props": .getReady,
                                                         "paper": .print, "print": .print, "play": .play]

    /// The go_to_step result: where she is now and the one line to say; or why not.
    public static func output(moved: Bool, to step: JourneyStep, current: JourneyStep?) -> String {
        if moved { return "Moved to the \(step.label) step. Say exactly this and nothing else: \"\(arrivalLine(step))\"" }
        if step == current { return "Already on the \(step.label) step. Answer in ONE short line." }
        return "Can't go to the \(step.label) step yet (not reached). Answer in ONE short, kind line and carry on with the current step."
    }

    /// Round 23: the post-hunt coaching line that lets voice go back ("print it again" → paper).
    public static let voiceHint = "If they want to go back to a step (\"print it again\", \"back to the props\", "
        + "\"back to the game\", \"back to the checklist\"), call go_to_step (print, props, pick or play) and say only the line its result gives you."
    /// The play step's (scene, The End) coaching note: go_to_step is its only tool (round 22 said "No tools").
    public static let playNote = "(Silent coaching, don't mention it.) They're playing now. " + voiceHint
        + " Otherwise answer in ONE short, fun line that helps the current scene, with no tools."

    /// The silent note after a TAP on the rail, so the conversation knows where the kids are.
    public static func tapNote(_ step: JourneyStep) -> String {
        "(Silent note, don't mention it.) The kids tapped back to the \(step.label) step and you said: \"\(arrivalLine(step))\". "
            + "Help them from there."
    }
}
