import Foundation

/// Round 20 (Haylee): how the printables look. Asked right after the confirm step's yes, before the roles: "Do you want
/// your printables in full color, or do you want to color them yourself?" Two big buttons (Full color / I'll color them)
/// and voice (set_print_style). The choice lives in `AdventureStore.printStyle` (the one source of truth) and decides
/// every kit image prompt: full color asks for full-color art; "I'll color them" keeps the thick-outline coloring pages.
public enum PrintStyle: String, Codable, Sendable, CaseIterable {
    case fullColor = "full_color"
    case colorIn = "color_myself"

    /// The big button's label.
    public var label: String {
        switch self { case .fullColor: ColorChoice.fullColorLabel; case .colorIn: ColorChoice.colorInLabel }
    }
    /// How she says it back ("Full color it is!").
    public var spoken: String { self == .fullColor ? "full color" : "pages you color yourself" }
}

public enum ColorChoice {
    public static let question = "Do you want your printables in full color, or do you want to color them yourself?"
    public static let fullColorLabel = "Full color"
    public static let colorInLabel = "I'll color them"

    /// confirm_plan's output when the color isn't chosen yet: the color question is her whole reply.
    public static func askOutput(playerCount: Int) -> String {
        "Confirmed: \(playerCount) kid\(playerCount == 1 ? "" : "s"). Step 3c: say exactly this and nothing else, then "
            + "wait: \"\(question)\" Big Full color / I'll color them buttons are on screen. When they answer, call "
            + "set_print_style (full_color or color_myself)."
    }

    /// The Yes, let's go! tap when the color isn't chosen yet: no tools, just the color question.
    public static func yesTapNote() -> String {
        "(Silent coaching, don't mention it.) The kids tapped Yes, let's go!: the plan is confirmed (don't call "
            + "confirm_plan). No tools now. Say exactly this and nothing else, then wait: \"\(question)\""
    }

    /// set_print_style's output on the color step: the roles start (the old confirm output).
    public static func chosenOutput(_ style: PrintStyle, playerCount: Int) -> String {
        "Printables: \(style.spoken). " + ConfirmStep.confirmedOutput(playerCount: playerCount)
    }

    /// A color button tap (the app already set it): the same next step, spoken with tools allowed.
    public static func tapNote(_ style: PrintStyle, playerCount: Int) -> String {
        "(Silent coaching, don't mention it.) The kids tapped \(style.label): it's ALREADY set (don't call "
            + "set_print_style). " + chosenOutput(style, playerCount: playerCount)
    }

    /// The line when a color change remakes the pages at the print step.
    public static func restyleLine(_ style: PrintStyle) -> String {
        style == .fullColor ? "Ooh, full color! Let me paint your pages to match. Wait for it..."
            : "Ooh, you want to color them! Let me draw your pages for coloring. Wait for it..."
    }
}
