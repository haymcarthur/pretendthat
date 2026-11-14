import Foundation

/// Fresh suggestions every session (round 7, Haylee): the questions stay the same and in the same order, but the example
/// games and themes Nutmeg offers change. The app picks 3 games when the session starts (injected into the session
/// instructions) and 3 theme twists once the game is set (in the set_game result). Kids can still say anything.
public struct Suggestion: Equatable, Hashable, Sendable {
    /// Stable ID (stored as "last picks" so the next session avoids them).
    public let id: String
    /// How Nutmeg might say it ("a vet clinic", "on the moon").
    public let text: String
    public init(_ id: String, _ text: String) { self.id = id; self.text = text }
}

public enum Suggestions {
    /// Kid-friendly pretend games that work with household props (pillows, plates, cups, boxes, blankets, spoons...).
    public static let games: [Suggestion] = [
        .init("restaurant", "a restaurant"), .init("vet", "a vet clinic"), .init("airplane", "an airplane trip"),
        .init("pirate-ship", "a pirate ship"), .init("post-office", "a post office"), .init("space-station", "a space station"),
        .init("grocery", "a grocery store"), .init("firefighters", "firefighters"), .init("hair-salon", "a hair salon"),
        .init("library", "a library"), .init("ice-cream-truck", "an ice cream truck"), .init("dinosaur-dig", "a dinosaur dig"),
        .init("bakery", "a bakery"), .init("doctor", "a doctor's office"), .init("train", "a train ride"),
        .init("camping", "a camping trip"), .init("zoo", "a zoo"), .init("school", "a school"),
        .init("pizza", "a pizza shop"), .init("toy-shop", "a toy shop"), .init("farm", "a farm"),
        .init("rocket", "a rocket launch"), .init("submarine", "a submarine"), .init("tea-party", "a tea party"),
        .init("detective", "a detective mystery"), .init("construction", "a construction site"), .init("car-wash", "a car wash"),
        .init("flower-shop", "a flower shop"), .init("museum", "a museum"), .init("circus", "a circus show"),
        .init("puppet-show", "a puppet show"), .init("hotel", "a hotel"), .init("pet-groomer", "a pet groomer"),
        .init("treasure-hunt", "a treasure hunt"), .init("bus", "a bus ride"), .init("lemonade-stand", "a lemonade stand"),
        .init("cooking-show", "a cooking show"), .init("knights-castle", "knights at a castle"), .init("bird-watchers", "a bird-watching trip"),
        .init("mail-carrier", "a mail delivery route"), .init("weather-station", "a weather report"), .init("orchestra", "a marching band")
    ]

    /// General theme twists that fit almost any game.
    public static let twists: [Suggestion] = [
        .init("sea", "under the sea"), .init("moon", "on the moon"), .init("castle", "in a castle"),
        .init("jungle", "in the jungle"), .init("north-pole", "at the North Pole"), .init("candy", "in a candy land"),
        .init("dinosaurs", "with dinosaurs"), .init("bugs", "in a tiny bug world"), .init("clouds", "up in the clouds"),
        .init("desert", "in a sandy desert"), .init("rainbow", "on a rainbow"), .init("teddy-bears", "for teddy bears"),
        .init("robots", "with robots"), .init("fairy", "in a fairy forest"), .init("pirates", "on a pirate island"),
        .init("snow", "in a snowy mountain"), .init("farm-animals", "for farm animals"), .init("mars", "on Mars"),
        .init("treehouse", "in a giant treehouse"), .init("dragons", "with friendly dragons"), .init("toys", "in a toy box"),
        .init("superheroes", "with superheroes"), .init("ocean-island", "on a tropical island"), .init("nighttime", "at nighttime under the stars"),
        .init("giants", "in a land of giants"), .init("unicorns", "with unicorns"), .init("penguins", "with penguins"),
        .init("volcano", "next to a silly volcano"), .init("time-travel", "back in time"), .init("mouse-town", "in a tiny mouse town"),
        .init("cookie", "in a cookie kingdom"), .init("monsters", "with friendly monsters")
    ]

    /// Picks `count` distinct items, never one of `avoiding` (unless the list is too short to avoid them all).
    public static func sample<G: RandomNumberGenerator>(_ pool: [Suggestion], count: Int = 3, avoiding: Set<String> = [],
                                                        using rng: inout G) -> [Suggestion] {
        let fresh = pool.filter { !avoiding.contains($0.id) }
        var picks = Array(fresh.shuffled(using: &rng).prefix(count))
        if picks.count < count {   // tiny pool: top up from the avoided ones
            picks += pool.filter { avoiding.contains($0.id) }.shuffled(using: &rng).prefix(count - picks.count)
        }
        return picks
    }

    public static func sample(_ pool: [Suggestion], count: Int = 3, avoiding: Set<String> = []) -> [Suggestion] {
        var rng = SystemRandomNumberGenerator()
        return sample(pool, count: count, avoiding: avoiding, using: &rng)
    }

    /// "a, b, or c"
    public static func spoken(_ picks: [Suggestion]) -> String {
        let t = picks.map(\.text)
        switch t.count {
        case 0: return ""
        case 1: return t[0]
        case 2: return "\(t[0]) or \(t[1])"
        default: return t.dropLast().joined(separator: ", ") + ", or " + t.last!
        }
    }
}

/// Remembers only the IDs of the last session's picks (UserDefaults; nothing about kids), so the next session differs.
public struct SuggestionMemory: @unchecked Sendable {
    let defaults: UserDefaults
    static let gamesKey = "pt.lastGamePicks", twistsKey = "pt.lastTwistPicks"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var lastGames: Set<String> { Set(defaults.stringArray(forKey: Self.gamesKey) ?? []) }
    public var lastTwists: Set<String> { Set(defaults.stringArray(forKey: Self.twistsKey) ?? []) }

    /// Today's 3 games (different from last session's), remembered for next time.
    public func pickGames() -> [Suggestion] {
        let picks = Suggestions.sample(Suggestions.games, avoiding: lastGames)
        defaults.set(picks.map(\.id), forKey: Self.gamesKey)
        return picks
    }

    /// 3 theme twists once the game is set (different from last time's), remembered for next time.
    public func pickTwists() -> [Suggestion] {
        let picks = Suggestions.sample(Suggestions.twists, avoiding: lastTwists)
        defaults.set(picks.map(\.id), forKey: Self.twistsKey)
        return picks
    }
}
