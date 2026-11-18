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
    public var safetyTexts: [String] { [nutmegSays] + scenes.flatMap { [$0.title, $0.nutmegSays] + $0.steps.flatMap { [$0.text] + ($0.short.map { [$0] } ?? []) } } }
}

/// What the kit pages depend on. A change (a round 19 correction of the game, theme or count, or new roles) cancels the
/// pages being written and starts again. The color is NOT here: it only changes the art (the app redraws it).
/// Round C1: the pages are written for the 6 ranked roles, so the player count is always `RoleCast.count` here and a
/// count change never restarts them.
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
        return KitInputs(title: title, playerCount: RoleCast.count, roles: plan.roles.map(\.roleName))
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
            let themed = Array(i.lines.prefix(room))
            i.lines = themed + fresh
            // Round 46: the themed page was drawn during the hunt; the skipped props' cut-outs are a second page.
            if i.aiPage, !fresh.isEmpty { i.pageLines = themed.count }
            return i
        }
    }
}

/// One kit image request: its art key (`KitArtPlan.pageKey`, or the character sheet's `characters#sheet`), its prompt
/// and size. Round 46: a page's `words` are what the on-device check looks for; a sheet's grid is how it's sliced.
public struct KitArtJob: Equatable, Sendable {
    public let key: String, prompt: String, size: String
    /// A sheet's number of pictures (1 for a page).
    public let count: Int
    /// The words this page must show (every occurrence), for `PageWordCheck`. Empty for the character sheet.
    public let words: [String]
    /// A sheet's grid (columns × rows); 0 for a page.
    public let columns: Int, rows: Int
    public init(key: String, prompt: String, size: String, count: Int = 1, words: [String] = [], columns: Int = 0, rows: Int = 0) {
        self.key = key; self.prompt = prompt; self.size = size; self.count = count; self.words = words
        self.columns = columns; self.rows = rows
    }
    public var isSheet: Bool { KitArtPlan.isSheet(key) }
}

/// Round 46: the image calls of a kit. Each AI page is ONE image per set (the decoder none), the cut-outs get a second
/// page when skipped props were added, and the color set also draws the kit's one character sheet. A round 45 or older
/// kit never draws anything (it is only ever replayed with its saved art).
public enum KitArtPlan {
    public static func cutoutKey(_ itemID: String, _ n: Int) -> String { "\(itemID)#\(n)" }
    public static func sheetKey(_ itemID: String) -> String { "\(itemID)#sheet" }
    public static func isSheet(_ key: String) -> Bool { key.hasSuffix("#sheet") }
    /// The character sheet's job key (its slices are stored as `characters#k`).
    public static let characterKey = sheetKey(CharacterSheet.id)

    /// The art key of one page of an item: the item id; the badge page for N kids is `badges@N` (a different count is a
    /// different page); the cut-outs' extra page for skipped props is `cutouts#more`.
    public static func pageKey(_ item: KitItem, part: Int = 0, players: Int) -> String {
        if item.recipe == .badges { return "\(item.id)@\(min(max(players, 1), RoleCast.count))" }
        return part > 0 ? "\(item.id)#more" : item.id
    }

    /// The pages (parts) an AI item has: the cut-outs have 2 when skipped props were added; the decoder none.
    public static func parts(_ item: KitItem) -> [Int] {
        guard item.aiPage, item.recipe != .decoder else { return [] }
        if item.recipe == .cutouts, let n = item.pageLines, n < item.lines.count { return [0, 1] }
        return [0]
    }

    /// Every image these items need in one set, minus `settled` (landed, in flight or given up). `characters`: also the
    /// kit's character sheet (the color set draws it).
    public static func jobs(items: [KitItem], ctx: KitArtContext, style: PrintStyle, settled: Set<String>,
                            characters: Bool = false) -> [KitArtJob] {
        var out: [KitArtJob] = []
        for item in items {
            for part in parts(item) {
                let key = pageKey(item, part: part, players: ctx.players)
                guard !settled.contains(key), let p = KitPagePrompt.prompt(for: item, ctx: ctx, style: style, part: part) else { continue }
                out.append(KitArtJob(key: key, prompt: p.prompt, size: KitPagePrompt.size, words: p.words))
            }
        }
        if characters, items.contains(where: \.aiPage), !ctx.roles.isEmpty, !settled.contains(characterKey) {
            let things = CharacterSheet.things(items)
            out.append(KitArtJob(key: characterKey, prompt: CharacterSheet.prompt(roles: ctx.roles, things: things, title: ctx.title),
                                 size: CharacterSheet.size(things: things.count), count: CharacterSheet.count(things: things.count),
                                 columns: CharacterSheet.columns, rows: CharacterSheet.rows(things: things.count)))
        }
        return out
    }

    /// Round 45/46 (cost): how many page images one set of these items makes (the cut-outs' extra page counts when it's
    /// there). The cover and the character sheet are one more each per game.
    public static func imageCount(_ items: [KitItem], ctx: KitArtContext = KitArtContext(title: "", roles: RoleCast.rank([]))) -> Int {
        jobs(items: items, ctx: ctx, style: .fullColor, settled: []).count
    }

    /// Every page key these items need in one set (a set is final when all of these have landed or definitively
    /// failed). The character sheet isn't one: the pages never wait for it.
    public static func keys(items: [KitItem], ctx: KitArtContext) -> Set<String> {
        Set(items.flatMap { item in parts(item).map { pageKey(item, part: $0, players: ctx.players) } })
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
