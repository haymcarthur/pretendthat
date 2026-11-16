import Foundation

/// Round 20 (Haylee): how the printables look. The value lives in `AdventureStore.printStyle` (the one source of
/// truth) and decides every kit image prompt: full color asks for full-color art; color-in keeps the thick-outline
/// coloring pages. Round 26 (Haylee, during the button audit): the color QUESTION is gone (its step, lines, the
/// set_print_style tool and the buttons); a new game makes coloring pages by default. The next round makes both
/// versions and moves the choice to the Print screen, so this plumbing stays.
public enum PrintStyle: String, Codable, Sendable, CaseIterable {
    case fullColor = "full_color"
    case colorIn = "color_myself"

    /// How she says it back ("Full color it is!").
    public var spoken: String { self == .fullColor ? "full color" : "pages you color yourself" }
}
