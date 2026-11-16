import Foundation

// Round 27 (Haylee): every kit page is drawn in BOTH styles during the prop hunt (two separate image calls per page:
// full color and the outline coloring page). The Print screen shows both sets side by side; the kids tap (or say)
// the one they want, and the printer prints that set. Each game also gets one text-free, full-color square COVER
// picture of its scene for the bookshelf, kept only if the game is saved.

extension PrintStyle {
    /// The two print sets, in the order the Print screen shows them (color on the left, the default).
    public static let sets: [PrintStyle] = [.fullColor, .colorIn]
    /// The Print screen's default selection (Haylee: color).
    public static let defaultSet: PrintStyle = .fullColor

    /// The `choose_print_set` tool's value.
    public var toolValue: String { self == .fullColor ? "color" : "outline" }

    /// Reads the tool's value (and the kid's words, in case the model passes them through): "color" / "in color" →
    /// full color; "outline", "plain", "we'll color them", "coloring pages", "black and white" → the outline set.
    public init?(choice raw: String) {
        let s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let outlineWords = ["outline", "plain", "color them", "colour them", "color it", "coloring", "colouring",
                            "black and white", "white", "color myself", "color_myself", "ourselves", "line"]
        if outlineWords.contains(where: s.contains) { self = .colorIn; return }
        if s.contains("color") || s.contains("colour") || s == "full_color" { self = .fullColor; return }
        return nil
    }

    /// How she names the set ("the color ones").
    public var setName: String { self == .fullColor ? "the color ones" : "the outline ones to color yourself" }
}

/// What she says around the choice (the Print screen's voice and taps).
public enum PrintSetLines {
    /// The choose_print_set result: the selection moved (the app shows the highlight).
    public static func chosenOutput(_ style: PrintStyle) -> String {
        let say = style == .fullColor ? "Color it is! Tap the printer when you're ready!"
            : "The outline ones, to color yourselves! Tap the printer when you're ready!"
        return "Selected \(style.setName) (highlighted on screen; the printer prints this set). Say exactly this and nothing else: \"\(say)\""
    }
    /// Only one set exists (a game saved before round 27 has one style).
    public static func onlyOneOutput(_ have: PrintStyle) -> String {
        "This game only has \(have.setName), and they're already chosen. Say ONE short line: tap the printer to print them."
    }
    public static let notNowOutput = "Not now: the pages are chosen on the Print step. Answer in ONE short line."
}

// MARK: - Stored art keys for both styles

extension ArtKey {
    /// A page image in a style: full color keeps the plain keys (`img:`/`cut:`), the outline set is `o`-prefixed
    /// (`oimg:`/`ocut:`). A saved game's `printStyle` names the style of its PLAIN keys (games saved before round 27
    /// have one set, in whatever style was chosen then); a round 27 save sets it to full color.
    public static func image(_ itemID: String, style: PrintStyle) -> String {
        style == .fullColor ? image(itemID) : "o" + image(itemID)
    }
    public static func cutout(_ itemID: String, _ n: Int, style: PrintStyle) -> String {
        style == .fullColor ? cutout(itemID, n) : "o" + cutout(itemID, n)
    }
    /// (itemID, cut-out index, style) for a key; `plain` = the style of the unprefixed keys (`SavedGame.printStyle`).
    public static func parse(_ key: String, plain: PrintStyle) -> (itemID: String, index: Int?, style: PrintStyle)? {
        if key.hasPrefix("oimg:") || key.hasPrefix("ocut:") {
            return parse(String(key.dropFirst())).map { ($0.itemID, $0.index, .colorIn) }
        }
        return parse(key).map { ($0.itemID, $0.index, plain) }
    }
}

extension SavedGame {
    /// The style of the plain art keys (a game saved before round 27: its chosen style, coloring pages by default).
    public var plainArtStyle: PrintStyle { printStyle ?? .colorIn }
    /// The print sets this game has art for, in the Print screen's order.
    public var artSets: [PrintStyle] {
        let have = Set(art.compactMap { ArtKey.parse($0, plain: plainArtStyle)?.style })
        return PrintStyle.sets.filter(have.contains)
    }
}

// MARK: - The bookshelf cover

public enum CoverArt {
    /// One square image (the shelf cards are all the same size).
    public static let size = "1024x1024"
    /// The cover prompt: the game's scene, full color, and NO text of any kind (kids can't read it, and words drawn by
    /// the image model are often misspelled). The shelf-edge label carries the name.
    public static func prompt(title: String, setting: String?) -> String {
        let place = (setting ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return "A square, full-color cover illustration for a kids' pretend-play game called \"\(title)\""
            + (place.isEmpty || place.caseInsensitiveCompare(title) == .orderedSame ? "" : " (\(place))") + ". "
            + "Show the game's scene and theme: the place and its fun props, bright and inviting, like a picture-book cover, "
            + "kid-friendly cartoon style with bright cheerful colors, flat fills and bold clean outlines, filling the whole "
            + "square edge to edge. No words, no letters, no numbers, no title, no signs or labels with writing, no text of "
            + "any kind anywhere. No real brands, no logos, nothing scary." + ImageSafety.suffix
    }

    /// The shelf picture to keep at Save: the generated cover, else the color sign page, else the outline sign page.
    public static func pick<T>(cover: T?, colorSign: T?, outlineSign: T?) -> T? { cover ?? colorSign ?? outlineSign }
}

// MARK: - Image usage (round 27 measurements; numbers only)

/// DEBUG measurements for the image calls: how many, when (for the per-minute peak against the relay's 40/min
/// limit), how many came back 429, and the output tokens OpenAI reported (cost). Never any prompt or image.
public enum ImageUsageLog {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var starts: [Date] = []
    nonisolated(unsafe) private static var _rateLimited = 0
    nonisolated(unsafe) private static var _outputTokens = 0
    nonisolated(unsafe) private static var _inputTokens = 0

    public static func started(at date: Date = Date()) { lock.withLock { starts.append(date) } }
    public static func rateLimited() { lock.withLock { _rateLimited += 1 } }
    public static func usage(input: Int, output: Int) { lock.withLock { _inputTokens += input; _outputTokens += output } }

    public struct Snapshot: Equatable, Sendable {
        public let requests: Int, rateLimited: Int, inputTokens: Int, outputTokens: Int, peakPerMinute: Int
        /// $5 per 1M text input tokens, $30 per 1M image output tokens (gpt-image-2.x list prices).
        public var dollars: Double { Double(inputTokens) * 5 / 1_000_000 + Double(outputTokens) * 30 / 1_000_000 }
    }
    public static func snapshot(since: Date = .distantPast) -> Snapshot {
        lock.withLock {
            let s = starts.filter { $0 >= since }
            return Snapshot(requests: s.count, rateLimited: _rateLimited, inputTokens: _inputTokens, outputTokens: _outputTokens,
                            peakPerMinute: peakPerMinute(s))
        }
    }
    /// The most requests started inside any 60 s window.
    public static func peakPerMinute(_ dates: [Date]) -> Int {
        let d = dates.sorted()
        var best = 0, lo = 0
        for hi in d.indices {
            while d[hi].timeIntervalSince(d[lo]) >= 60 { lo += 1 }
            best = max(best, hi - lo + 1)
        }
        return best
    }
    public static func reset() { lock.withLock { starts = []; _rateLimited = 0; _outputTokens = 0; _inputTokens = 0 } }
}
