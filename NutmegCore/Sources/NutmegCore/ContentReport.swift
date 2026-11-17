import Foundation

// Round 37 (App Store Guideline 1.2 + the AI-generated content rules; compliance research #14): a grown-up can report a
// problem with something the AI made. Grown-ups (behind the gate) → "Report a problem" → a game (the one just played,
// or a saved one) → the part (a printed page, the story, a scene) → an email to support@pretendthat.app, prefilled.
//
// What the email carries (Claude's call, the "never store anything about kids" rule): ONLY the game's title and the
// AI-made text of that one part, plus the app version. No player count, no transcript, nothing a kid said, no names,
// no device or user identifiers. The grown-up sees it all before sending (their own mail app sends it; we send nothing).

public enum ContentReport {
    public static let address = "support@pretendthat.app"
    /// The longest a report's game text may be (a mailto: URL stays well under the usual limits).
    public static let maxTextCharacters = 1500

    /// One part of a game a grown-up can report.
    public struct Part: Identifiable, Equatable, Sendable {
        /// "page:sign", "story", "setup", "scene:2", "cleanup" (what the report's Part line says).
        public var id: String
        /// What the row shows: "Printed page: Sky Dollars", "Scene 2: Boarding".
        public var label: String
        /// The AI-made text of this part.
        public var text: String
    }

    /// A game that can be reported: its title and its parts. Kept in memory only (the game just played) or read from a
    /// saved game; never written anywhere by the report.
    public struct Game: Identifiable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var parts: [Part]
        public init(id: String, title: String, kit: Kit) {
            self.id = id; self.title = title; self.parts = ContentReport.parts(kit)
        }
    }

    /// Every reportable part of a kit: the printed pages, the story, the setup, each play scene, the clean-up.
    public static func parts(_ kit: Kit) -> [Part] {
        var out: [Part] = []
        for item in kit.items {
            let name = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = item.recipe?.rawValue ?? "page"
            let text = ([name] + item.lines + [item.purpose ?? ""]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }.joined(separator: "\n")
            out.append(Part(id: "page:\(kind)", label: "Printed page: \(name.isEmpty ? kind.capitalized : name)", text: text))
        }
        if let story = kit.story?.trimmingCharacters(in: .whitespacesAndNewlines), !story.isEmpty {
            out.append(Part(id: "story", label: "Nutmeg's story", text: story))
        }
        if let s = kit.setup, !(s.title.isEmpty && s.jobs.isEmpty) {
            out.append(Part(id: "setup", label: "Setup: \(s.title.isEmpty ? "Getting ready" : s.title)", text: bookendText(s)))
        }
        for (i, sc) in kit.scenes.filter({ $0.arc == .play }).enumerated() {
            let lines = [sc.title, sc.nutmegSays] + sc.steps.map { [$0.short ?? "", $0.text].filter { !$0.isEmpty }.joined(separator: ": ") }
            out.append(Part(id: "scene:\(i + 1)", label: "Scene \(i + 1): \(sc.title)", text: lines.filter { !$0.isEmpty }.joined(separator: "\n")))
        }
        if let c = kit.cleanup, !(c.title.isEmpty && c.jobs.isEmpty) {
            out.append(Part(id: "cleanup", label: "Clean-up: \(c.title.isEmpty ? "Clean-up time" : c.title)", text: bookendText(c)))
        }
        return out
    }

    static func bookendText(_ b: Bookend) -> String {
        ([b.title, b.nutmegSays] + b.jobs.map { "\($0.short): \($0.say)" }).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    public static func subject(game: String, part: Part) -> String {
        "Report a problem: \(game.isEmpty ? "a game" : game) (\(part.id))"
    }

    /// The email's body: room for the grown-up's words first, then the AI-made text, clearly marked.
    public static func body(game: String, part: Part, appVersion: String) -> String {
        var text = part.text
        if text.count > maxTextCharacters { text = String(text.prefix(maxTextCharacters)) + "…" }
        return """
        What seemed wrong or not OK? (optional)


        ---
        Game: \(game)
        Part: \(part.id) (\(part.label))
        App version: \(appVersion)
        What the AI made:
        \(text)
        ---
        This email includes only the game's AI-made text. Nothing about your child is included.
        """
    }

    /// The prefilled email as a mailto: URL (the fallback when the in-app mail sheet isn't available).
    public static func mailURL(game: String, part: Part, appVersion: String) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = address
        c.queryItems = [URLQueryItem(name: "subject", value: subject(game: game, part: part)),
                        URLQueryItem(name: "body", value: body(game: game, part: part, appVersion: appVersion))]
        // URLComponents leaves "+" alone; mail apps read it as a plus, which is what we want. Spaces become %20.
        return c.url
    }
}

/// The Grown-ups words for the report screen.
public enum ReportCopy {
    public static let intro = "Nutmeg's words, the story and the printed pages are made by AI. We filter them for kids, but AI can still get things wrong. If something seems wrong or not OK, pick the game and the part below. Your mail app opens with that part's text filled in; nothing about your child is included."
    public static let justPlayed = "The game you just played"
    public static let savedHeader = "Saved games"
    public static let none = "Play or save a game first. Its pages and scenes will show up here."
    public static let noMailTitle = "Email us"
    public static func noMailBody(_ address: String) -> String { "This \(DeviceWord.noun) has no mail account set up. Copy the report and send it to \(address)." }
    public static let copyButton = "Copy the report"
    public static let footer = "We read every report and use it to make Nutmeg better and safer."
}
