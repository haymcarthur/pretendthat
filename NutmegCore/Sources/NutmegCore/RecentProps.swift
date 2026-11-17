import Foundation

/// Round 30 (Haylee): remembers the PROP IDs used in the last few games (UserDefaults; library IDs only, never
/// anything about the kids, like `SuggestionMemory` does for game ideas), so the next games steer toward props that
/// weren't used lately.
public struct RecentPropMemory: @unchecked Sendable {
    let defaults: UserDefaults
    static let key = "pt.recentPropGames"
    /// How many past games are remembered.
    public static let gameCount = 5
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// The remembered games, newest first: each a list of PropLibrary IDs.
    public var games: [[String]] { (defaults.array(forKey: Self.key) as? [[String]]) ?? [] }
    /// Every prop ID used in the remembered games.
    public var recent: Set<String> { Set(games.joined()) }

    /// Remembers one finished hunt's props (library IDs only; anything else is dropped). Keeps the last `gameCount`.
    public func record(_ ids: [String]) {
        var seen = Set<String>()
        let clean = ids.filter { PropLibrary.contains($0) && seen.insert($0).inserted }
        guard !clean.isEmpty else { return }
        defaults.set(Array(([clean] + games).prefix(Self.gameCount)), forKey: Self.key)
    }

    public func clear() { defaults.removeObject(forKey: Self.key) }
}

public enum RecentProps {
    /// The note the set_roles result carries when props were used lately: pick other list items when one fits.
    public static func note(_ recent: Set<String>) -> String {
        guard !recent.isEmpty else { return "" }
        return " PROPS USED IN RECENT GAMES (pick DIFFERENT list items this time whenever one fits the game just as well; "
            + "there are lots of others on the list): \(recent.sorted().joined(separator: ", "))."
    }

    /// The item to show instead of a recently used one: its first alternate that fits the same use, wasn't used lately
    /// and isn't already a card in this hunt; nil = keep the item (no fresh alternate fits).
    public static func fresher(itemID: String, becomes: String, alternates: [String], recent: Set<String>,
                               used: Set<String>) -> String? {
        guard recent.contains(itemID) else { return nil }
        return alternates.first { alt in
            alt != itemID && PropLibrary.contains(alt) && !recent.contains(alt) && !used.contains(alt)
                && PropFit.fits(itemID: alt, becomes: becomes)
        }
    }
}
