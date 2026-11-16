import Foundation

/// Round 23 (Haylee): clearer navigation back to earlier steps. Finished steps on the rail look tappable (a picture
/// plus a small go-back mark), "Print again" on the checklist and The End, and voice ("print it again", "go back to the
/// props") goes through the same `AdventureStore.goTo`. On arrival Nutmeg says one short line.
public enum BackNav {
    /// The picture on each rail step (SF Symbols, iPadOS 17).
    public static func symbol(_ step: JourneyStep) -> String {
        switch step {
        case .game: "theatermasks.fill"
        case .getReady: "shippingbox.fill"
        case .print: "printer.fill"
        case .play: "play.fill"
        }
    }

    /// The small mark on a reachable step that isn't the current one: back (↺) for finished steps, forward for a later
    /// step already reached (after going back).
    public static func mark(_ step: JourneyStep, current: JourneyStep?) -> String {
        step.rawValue < (current?.rawValue ?? -1) ? "arrow.counterclockwise" : "arrow.clockwise"
    }

    /// What she says on arrival (one short line).
    public static func arrivalLine(_ step: JourneyStep) -> String {
        switch step {
        case .game: "Back to our game plan! This is the game we picked."
        case .getReady: "Back to the props! Here's everything for our game."
        case .print: "Back to printing! Tap Print to print it again."
        case .play: "Back to playing! Let's pick up where we left off."
        }
    }

    /// The voice tool's step names.
    public static let toolSteps: [String: JourneyStep] = ["game": .game, "props": .getReady, "print": .print, "play": .play]

    /// The go_to_step result: where she is now and the one line to say; or why not.
    public static func output(moved: Bool, to step: JourneyStep, current: JourneyStep?) -> String {
        if moved { return "Moved to the \(step.label) step. Say exactly this and nothing else: \"\(arrivalLine(step))\"" }
        if step == current { return "Already on the \(step.label) step. Answer in ONE short line." }
        return "Can't go to the \(step.label) step yet (not reached). Answer in ONE short, kind line and carry on with the current step."
    }

    /// The silent note after a TAP on the rail or Print again, so the conversation knows where the kids are.
    public static func tapNote(_ step: JourneyStep) -> String {
        "(Silent note, don't mention it.) The kids tapped back to the \(step.label) step and you said: \"\(arrivalLine(step))\". "
            + "Help them from there."
    }
}
