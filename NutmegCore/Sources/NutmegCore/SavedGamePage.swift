import Foundation

// Saved game page (Haylee, decisions/2026-11-17-saved-game-page-and-play-bar.md; mockup design/mockups/after-cancel,
// version A, WITHOUT the player picker). Tapping a saved game on the bookshelf opens its PAGE for everyone: the cover and
// title, a big "Play with Nutmeg", the printables (Color / Black & white, the kit pages) and Print. Viewing and printing
// are always free. Playing it again with Nutmeg needs an active pass (Haylee's change, 2026-11-17: the 2 Free Preview
// games too, no exception). Without one, Nutmeg says her ask-a-grown-up line, then the grown-ups gate, then the grown-up
// card. Kids never see prices. Nothing about kids here: titles and fixed words.

public enum SavedGamePage {
    /// The page always shows and prints the full 6-role badge / ticket sheets (no player picker: kids cut out what they
    /// need). The replay still asks how many are playing.
    public static let printPlayers = RoleCast.count

    /// What "Play with Nutmeg" does.
    public enum PlayAction: Equatable, Sendable {
        /// Today's replay flow (it asks how many are playing).
        case replay
        /// No AI consent: the existing explanation card (Nutmeg's live voice needs it).
        case needsConsent
        /// No active pass: Nutmeg's line → the grown-ups gate → the grown-up card.
        case askGrownUp
    }

    /// An active pass plays it (consent permitting); anything else asks a grown-up. A Free Preview game is no exception.
    public static func playAction(consent: Bool, hasPass: Bool) -> PlayAction {
        switch NewGameGate.replay(consent: consent, hasPass: hasPass) {
        case .start: .replay
        case .needsConsent: .needsConsent
        default: .askGrownUp
        }
    }
}

public enum SavedGamePageCopy {
    // Nutmeg (said through the app's usual line path; titles make them game-specific, so they're said live).
    public static func hello(title: String) -> String { "Want to play \(title) again? Tap play!" }
    public static func askGrownUp(title: String) -> String { "Ooh, \(title)! Let's ask a grown-up to help us play this one again." }

    // The page
    public static let play = "Play with Nutmeg"
    public static let printables = "Printables"
    public static func pageCount(_ n: Int) -> String { n == 1 ? "1 page" : "\(n) pages" }
    public static let color = "Color"
    public static let blackAndWhite = "Black & white"
    public static let print = "Print"
    public static let back = "Back to the bookshelf"

    // The kid card (no prices)
    public static let ok = "OK"
    public static let grownUps = "Grown-ups"

    // The grown-up card behind the gate
    public static let grownUpTitle = "Your saved games are still yours."
    public static let grownUpBody = "View and print this game's kit anytime. Playing saved games with Nutmeg is part of the Show Pass and the Season Pass."
    public static let seePasses = "See passes"
    public static let notNow = "Not now"
}
