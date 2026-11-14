import Foundation

/// Light commentary while a long kit is generating (round 7, Haylee): after the one "making your kit" line, a short
/// progress line about every 13 s, tied to the pages still being made, at most 4, never repeated, and never "go play"
/// or "all set" (the ready line waits for the whole kit).
public enum KitProgress {
    public static let interval: TimeInterval = 13
    public static let maxLines = 4

    /// Lines for a page that is still being drawn.
    public static let byRecipe: [KitRecipe: [String]] = [
        .badges: ["I'm making your name badges!", "Ooh, the badges are getting shiny!"],
        .sign: ["Now I'm painting your big sign!", "Your sign is looking so bright!"],
        .money: ["I'm printing some pretend money!", "Counting out the play money... one, two, three!"],
        .tickets: ["I'm putting together some tickets!", "The tickets are almost stamped!"],
        .menu: ["Ooh, the menu's looking yummy!", "I'm writing out the menu!"],
        .cutouts: ["I'm drawing little cut-outs for you!", "The cut-outs are getting so cute!"]
    ]
    /// The next line: ONLY about a page that is being drawn right now (Haylee: the lines must be true), never one
    /// already said; nil when nothing is being drawn or after `maxLines`. No generic lines about earlier steps.
    public static func line(pending: [KitRecipe], said: [String]) -> String? {
        guard said.count < maxLines else { return nil }
        for recipe in pending {
            if let l = byRecipe[recipe]?.first(where: { !said.contains($0) }) { return l }
        }
        return nil
    }

    /// No progress line ever tells them to play or says it's done.
    public static var allLines: [String] { byRecipe.values.flatMap { $0 } }
}
