import Foundation

// Round 20 (Haylee): the kit is made DURING the prop hunt. As soon as the color and the roles are set, Claude writes
// the kit pages (badges, sign, money, tickets, menu, cut-outs) and their art starts drawing in the background, while
// the kids hunt. When the hunt ends, Claude writes the play guide (the scenes, with the props the kids really found),
// and only the cut-outs for SKIPPED props are drawn then. Nothing about this talks over the hunt: the kit commentary
// only starts at the Print step, and only about pages still in progress.

/// The kit pages without the play guide (written at the roles).
public struct KitPages: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var items: [KitItem]
    public init(nutmegSays: String, items: [KitItem]) { self.nutmegSays = nutmegSays; self.items = items }
}

/// The play guide (written when the hunt ends, with the found and skipped props).
public struct KitScenes: Codable, Equatable, Sendable {
    public var nutmegSays: String; public var scenes: [Scene]
    public init(nutmegSays: String, scenes: [Scene]) { self.nutmegSays = nutmegSays; self.scenes = scenes }
}

extension KitPages: SafetyText { public var safetyTexts: [String] { [nutmegSays] + items.flatMap { [$0.title] + $0.lines } } }
extension KitScenes: SafetyText {
    public var safetyTexts: [String] { [nutmegSays] + scenes.flatMap { [$0.title, $0.nutmegSays] + $0.steps.map(\.text) } }
}

/// What the kit pages depend on. A change (a round 19 correction of the game, theme or count, or new roles) cancels the
/// pages being written and starts again. The color is NOT here: it only changes the art (the app redraws it).
public struct KitInputs: Equatable, Sendable {
    public var title: String
    public var playerCount: Int
    public var roles: [String]
    public init(title: String, playerCount: Int, roles: [String]) { self.title = title; self.playerCount = playerCount; self.roles = roles }
}

public enum KitDraft {
    /// The themed cut-outs Claude writes at the roles; up to `maxSkipped` slots are left for skipped props.
    public static let themedCutouts = 6
    public static let maxSkipped = 2

    /// The inputs the pages are written for, or nil when it's too early (no color yet, no roles yet) or too late
    /// (the hunt is over: makeKit takes over).
    public static func inputs(title: String, playerCount: Int, plan: GamePlan?, printStyle: PrintStyle?,
                              step: PlanningStep) -> KitInputs? {
        guard printStyle != nil, let plan, !plan.roles.isEmpty, step == .props else { return nil }
        return KitInputs(title: title, playerCount: max(1, playerCount),
                         roles: plan.roles.map { "\($0.roleName)×\($0.count)" })
    }

    /// The printed cut-out for a skipped prop: what it would have become ("the steering wheel" → "steering wheel").
    public static func cutoutLabel(becomes: String) -> String {
        var t = becomes.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
        for article in ["the ", "a ", "an ", "our ", "your "] where t.lowercased().hasPrefix(article) {
            t = String(t.dropFirst(article.count)); break
        }
        return t
    }

    /// The hunt is over: the cut-outs item gets the skipped props' cut-outs appended (the themed ones keep their
    /// indices, so art drawn during the hunt stays in place). At most `PictureResolver.maxCutouts` in all.
    public static func finalItems(_ items: [KitItem], props: Props?) -> [KitItem] {
        let skipped = (props?.props ?? []).filter(\.isSkipped).map { cutoutLabel(becomes: $0.becomes) }
            .filter { !$0.isEmpty }.prefix(maxSkipped)
        guard !skipped.isEmpty else { return items }
        return items.map { item in
            guard item.recipe == .cutouts else { return item }
            var i = item
            let room = PictureResolver.maxCutouts - skipped.count
            let fresh = skipped.filter { s in !i.lines.contains { $0.caseInsensitiveCompare(s) == .orderedSame } }
            i.lines = Array(i.lines.prefix(room)) + fresh
            return i
        }
    }
}

/// One kit image request: a key (`<item id>` for a page, `<item id>#<n>` for one cut-out), its prompt and size.
public struct KitArtJob: Equatable, Sendable {
    public let key: String, prompt: String, size: String
    public init(key: String, prompt: String, size: String) { self.key = key; self.prompt = prompt; self.size = size }
}

public enum KitArtPlan {
    public static func cutoutKey(_ itemID: String, _ n: Int) -> String { "\(itemID)#\(n)" }

    /// Every image these items need, minus `settled` (landed, in flight or given up). During the hunt the items are the
    /// draft pages, so the skipped props' cut-outs simply aren't there yet; the final kit adds them.
    public static func jobs(items: [KitItem], title: String, style: PrintStyle, settled: Set<String>) -> [KitArtJob] {
        var out: [KitArtJob] = []
        for item in items {
            let labels = KitArtPrompt.cutoutLabels(item)
            if item.recipe == .cutouts, !labels.isEmpty {
                for (n, label) in labels.enumerated() where !settled.contains(cutoutKey(item.id, n)) {
                    out.append(KitArtJob(key: cutoutKey(item.id, n), prompt: KitArtPrompt.cutoutPrompt(label, gameTitle: title, style: style),
                                         size: "1024x1024"))
                }
            } else if !settled.contains(item.id) {
                out.append(KitArtJob(key: item.id, prompt: KitArtPrompt.prompt(for: item, gameTitle: title, style: style),
                                     size: KitArtPrompt.size(for: item)))
            }
        }
        return out
    }

    /// Every key the items need (a page is done when all of these have landed or definitively failed).
    public static func keys(items: [KitItem]) -> Set<String> {
        Set(jobs(items: items, title: "", style: .colorIn, settled: []).map(\.key))
    }
}

/// At most `limit` image calls at once (round 20: the relay allows 40 images a minute; ~3 in flight stays well under it
/// and avoids 429s). FIFO, cancellation-safe.
public actor AsyncLimiter {
    public let limit: Int
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    public private(set) var peak = 0
    public init(limit: Int) { self.limit = max(1, limit) }

    public func run<T: Sendable>(_ op: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await op()
    }

    private func acquire() async {
        if running < limit { running += 1; peak = max(peak, running); return }
        await withCheckedContinuation { waiting.append($0) }
        peak = max(peak, running)
    }

    private func release() {
        if waiting.isEmpty { running -= 1 } else { waiting.removeFirst().resume() }   // the slot passes straight on
    }
}

/// Retry once, then give up (the caller's existing fallback takes over: app-drawn page art, or the bundled kit).
public enum RetryOnce {
    public static func run<T: Sendable>(delay: Duration = .seconds(1), _ op: @Sendable () async throws -> T) async throws -> T {
        do { return try await op() } catch {
            if Task.isCancelled { throw error }
            try? await Task.sleep(for: delay)
            return try await op()
        }
    }
}
