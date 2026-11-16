import Foundation

/// Round 24 (Haylee): "Do you have a printer?" right after the confirm step's yes, before the color question. Two big
/// buttons (Yes / No) at the top of the stage and voice (set_printer). Yes: the round 20 flow (the color question, the
/// kit drawn during the hunt). No: no kit images at all; Claude writes a very simple draw-your-own guide and the Paper
/// step becomes "Draw it!". The answer lives in `AdventureStore.hasPrinter` (nil = not asked yet).
public enum PrinterChoice {
    public static let question = "Do you have a printer?"
    public static let yesLabel = "Yes, I have one"
    public static let noLabel = "No printer"

    /// confirm_plan's output when the printer isn't known yet: the printer question is her whole reply.
    public static func askOutput(playerCount: Int) -> String {
        "Confirmed: \(playerCount) kid\(playerCount == 1 ? "" : "s"). Next step: say exactly this and nothing else, then "
            + "wait: \"\(question)\" Big Yes / No buttons are on screen. When they answer, call set_printer "
            + "(has_printer true or false)."
    }

    /// The Yes, let's go! tap when the printer isn't known yet: no tools, just the printer question.
    public static func yesTapNote() -> String {
        "(Silent coaching, don't mention it.) The kids tapped Yes, let's go!: the plan is confirmed (don't call "
            + "confirm_plan). No tools now. Say exactly this and nothing else, then wait: \"\(question)\""
    }

    /// The no-printer answer: no color question, straight to the roles (the kit is drawn by hand).
    static let noPrinterNote = "No printer: the kids will DRAW their kit by hand (Nutmeg shows how, one piece at a time, "
        + "after the hunt). Don't ask about colors. "

    /// set_printer's output on the printer step.
    public static func chosenOutput(_ has: Bool, colorKnown: Bool, playerCount: Int) -> String {
        if !has { return noPrinterNote + ConfirmStep.confirmedOutput(playerCount: playerCount) }
        if colorKnown { return "Printer: yes. " + ConfirmStep.confirmedOutput(playerCount: playerCount) }
        return "Printer: yes. Now say exactly this and nothing else, then wait: \"\(ColorChoice.question)\" Big "
            + "\(ColorChoice.fullColorLabel) / \(ColorChoice.colorInLabel) buttons are on screen. When they answer, call "
            + "set_print_style (full_color or color_myself)."
    }

    /// A Yes / No tap (the app already set it): the same next step. No needs tools (start_planning, set_roles…).
    public static func tapNote(_ has: Bool, colorKnown: Bool, playerCount: Int) -> String {
        "(Silent coaching, don't mention it.) The kids tapped \(has ? yesLabel : noLabel): it's ALREADY set (don't call "
            + "set_printer). " + chosenOutput(has, colorKnown: colorKnown, playerCount: playerCount)
    }
}
