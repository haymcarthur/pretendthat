import Foundation

/// Picks short lines at random from a pool, never repeating one until the whole pool has been used (round 15,
/// Haylee: the same kit line every test). One deck per session; each pool has its own key.
public struct LineDeck: Sendable {
    private var used: [String: Set<String>] = [:]
    private var last: [String: String] = [:]
    public init() {}

    /// A random unused line from `pool` (the pool starts over once every line has been said, never with the last one).
    public mutating func draw<G: RandomNumberGenerator>(_ key: String, from pool: [String], using rng: inout G) -> String? {
        guard !pool.isEmpty else { return nil }
        var u = used[key] ?? []
        var fresh = pool.filter { !u.contains($0) }
        if fresh.isEmpty {
            u = []
            fresh = pool.count > 1 ? pool.filter { $0 != last[key] } : pool
        }
        guard let pick = fresh.randomElement(using: &rng) else { return nil }
        u.insert(pick); used[key] = u; last[key] = pick
        return pick
    }

    public mutating func draw(_ key: String, from pool: [String]) -> String? {
        var g = SystemRandomNumberGenerator()
        return draw(key, from: pool, using: &g)
    }

    /// Every line of `pool` has been drawn at least once since it last started over.
    public func exhausted(_ key: String, pool: [String]) -> Bool { pool.allSatisfy { (used[key] ?? []).contains($0) } }
}

/// Light commentary while a long kit is generating (round 7, Haylee): a short progress line about every 13 s, at most
/// 4, never "go play" or "all set" (the ready line waits for the whole kit).
/// Round 15 (Haylee: always the same line): a bigger pool, several wordings per page kind, picked at random with no
/// repeats in a session, and only about something really being made right now (loading lines must be true).
public enum KitProgress {
    public static let interval: TimeInterval = 13
    public static let maxLines = 4

    /// What she can say she's making: the 6 kit pages, plus the play guide (the scene checklists), which is only being
    /// written while the kit's content (`store.kit`) hasn't come back yet.
    public enum Topic: String, CaseIterable, Sendable {
        case badges, sign, money, tickets, menu, cutouts, checklists
        public init(_ recipe: KitRecipe) {
            switch recipe {
            case .badges: self = .badges
            case .sign: self = .sign
            case .money: self = .money
            case .tickets: self = .tickets
            case .menu: self = .menu
            case .cutouts: self = .cutouts
            }
        }
    }

    public static let lines: [Topic: [String]] = [
        .badges: ["I'm making your name badges!", "Ooh, the badges are getting shiny!", "I'm putting a part on every badge!",
                  "Every badge gets a line for your name!", "I'm drawing a little picture on each badge!",
                  "Badges for the whole crew, one for each of you!", "Your badges are looking so fancy!"],
        .sign: ["Now I'm painting your big sign!", "Your sign is looking so bright!", "I'm making a sign to hang on the wall!",
                "I'm adding big letters to your sign!", "The sign is getting a fancy border!",
                "Everyone will see this sign from far away!"],
        .money: ["I'm printing some pretend money!", "Counting out the play money: one, two, three!",
                 "The play money is getting big numbers!", "I'm making a stack of pretend bills!",
                 "Ooh, so much play money to share!", "Each pretend bill gets a fancy border!"],
        .tickets: ["I'm putting together some tickets!", "The tickets are almost stamped!", "I'm making a ticket for every player!",
                   "Your tickets are getting a little picture!", "One ticket each, coming right up!",
                   "Each ticket gets a line for your name!"],
        .menu: ["I'm writing out the menu!", "I'm putting prices on the menu!", "Every line on the menu gets a little picture!",
                "The menu is almost filled in!", "I'm making a list of things to pick from!", "Your menu is looking so nice!"],
        .cutouts: ["I'm drawing little cut-outs for you!", "The cut-outs are getting so cute!",
                   "Every cut-out gets a thick line to cut on!", "So many tiny things to cut out!",
                   "I'm drawing the cut-outs one by one!", "Your cut-outs will be fun to hold!"],
        .checklists: ["I'm writing the checklists for your scenes!", "I'm planning the scenes for your story!",
                      "Each scene gets its own little checklist!", "I'm thinking up fun things for every scene!",
                      "I'm putting pictures on your checklists!", "I'm writing down what happens in each scene!"]
    ]

    /// What is really being made right now: before the kit's content exists, every page and the play guide; after
    /// that, only the pages whose art is still being drawn.
    public static func inProgress(kitWritten: Bool, pendingPages: [KitRecipe]) -> [Topic] {
        kitWritten ? Array(Set(pendingPages.map(Topic.init))).sorted { $0.rawValue < $1.rawValue }
            : Topic.allCases
    }

    /// Round 20: the pages were written during the hunt, so at Print only what's really still in progress counts:
    /// pages whose art is still drawing, plus the checklists while the play guide is being written. Nothing written
    /// yet at all (no pages from the hunt): everything, as before.
    public static func inProgress(pagesWritten: Bool, scenesWritten: Bool, pendingPages: [KitRecipe]) -> [Topic] {
        guard pagesWritten else { return Topic.allCases }
        var t = Set(pendingPages.map(Topic.init))
        if !scenesWritten { t.insert(.checklists) }
        return t.sorted { $0.rawValue < $1.rawValue }
    }

    /// The next line: a random topic among `inProgress` (a different one than last time when possible), a random line
    /// of it never said this session. nil when nothing is being made, or after `maxLines` this kit.
    public static func next<G: RandomNumberGenerator>(inProgress: [Topic], saidThisKit: Int, lastTopic: Topic?,
                                                      deck: inout LineDeck, using rng: inout G) -> (line: String, topic: Topic)? {
        guard saidThisKit < maxLines, !inProgress.isEmpty else { return nil }
        let fresh = inProgress.filter { !deck.exhausted("kit." + $0.rawValue, pool: lines[$0] ?? []) }
        var options = (fresh.isEmpty ? inProgress : fresh)
        if options.count > 1, let lastTopic { options.removeAll { $0 == lastTopic } }
        guard let topic = options.randomElement(using: &rng),
              let line = deck.draw("kit." + topic.rawValue, from: lines[topic] ?? [], using: &rng) else { return nil }
        return (line, topic)
    }

    /// No progress line ever tells them to play or says it's done.
    public static var allLines: [String] { lines.values.flatMap { $0 } }
}

/// The prop card the kids don't have, skipped (round 15, Haylee): she reassures them out loud with a quick pretend
/// substitute. The model says it with the next prop; this app line is used when the hunt ends right there (the
/// "making your kit" line starts with it).
public enum PropSkip {
    public static func templates(item: String, becomes: String) -> [String] {
        let item = item.lowercased()
        var becomes = becomes.lowercased().trimmingCharacters(in: .whitespaces)
        for article in ["the ", "a ", "an ", "your ", "our "] where becomes.hasPrefix(article) {   // "the the pilot cap" (live run)
            becomes = String(becomes.dropFirst(article.count))
        }
        let thing = becomes.isEmpty ? item : becomes
        return ["That's okay, we'll just pretend that we have a magic \(item)!",
                "That's okay, we'll just pretend that your hands are the \(thing)!",
                "That's okay, we'll just pretend that the \(thing) is invisible!",
                "No problem! We'll just pretend that the \(thing) is right there in the air!"]
    }

    public static func reassurance<G: RandomNumberGenerator>(item: String, becomes: String, deck: inout LineDeck,
                                                             using rng: inout G) -> String {
        let pool = templates(item: item, becomes: becomes)
        // Keyed by template slot so the wording varies across props too.
        let slots = pool.indices.map(String.init)
        let slot = deck.draw("skip", from: slots, using: &rng).flatMap(Int.init) ?? 0
        return pool[slot]
    }

    /// The silent note for the model's spoken reply after a skip (the next prop's card is already out).
    public static func note(item: String, becomes: String, then: String) -> String {
        let example = templates(item: item, becomes: becomes)[1]
        return "(Silent coaching, don't mention it.) The kids tapped the X again (don't have it): the \(item.lowercased()) is ALREADY "
            + "marked as pretend on screen (don't call skip_prop or swap_prop). Say nothing yet: \(then) FIRST. Then speak ONCE: "
            + "start with \"That's okay, we'll just pretend that\" plus a quick pretend idea for it (like \"\(example)\"), "
            + "then say the new prop in the same turn. Never narrate."
    }
}
