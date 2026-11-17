import Foundation

/// Compact summary of what's decided so far. There are no kids' names anywhere (roles-not-names.md).
public struct AdventureContext: Codable, Equatable, Sendable {
    public var gameTitle: String?
    public var plan: GamePlan?
    public var props: Props?
    public var playerCount: Int
    public init(gameTitle: String? = nil, plan: GamePlan? = nil, props: Props? = nil, playerCount: Int) {
        self.gameTitle = gameTitle; self.plan = plan; self.props = props; self.playerCount = playerCount
    }
}

/// One async function per phase. Every result is sanitized.
public final class PhaseService: Sendable {
    let llm: LLM
    /// Round 19: generated text is checked (local filter + moderation) before it's shown or printed.
    let safety: KidSafetyCheck
    public init(llm: LLM, moderator: Moderating? = nil) { self.llm = llm; self.safety = KidSafetyCheck(moderator: moderator) }

    /// Round 19: kid text checked before it reaches Claude (local filter, then moderation; fails safe to local).
    public func checkKidText(_ text: String) async -> Sanitizer.SafetyVerdict? { await safety.check([text]) }

    static let saferNote = "\nYour last answer had something that isn't okay for kids ages 4 to 8. Answer again with only "
        + "gentle, friendly, kid-safe words: no weapons, violence, scary or grown-up things."

    /// One structured call whose text must pass the kid-safety check: regenerated once, then it throws (the store falls
    /// back to the bundled game).
    func safe<T: SafetyText>(_ make: (String) async throws -> T, _ user: String) async throws -> T {
        let first = try await make(user)
        guard await safety.check(first.safetyTexts, pretend: true) != nil else { return first }
        #if DEBUG
        NSLog("[CLAUDE] answer failed the kid-safety check, asking once more")
        #endif
        let second = try await make(user + Self.saferNote)
        guard await safety.check(second.safetyTexts, pretend: true) != nil else { return second }
        throw ClaudeError.refusal
    }

    public func ideas(kidSaid: String?) async throws -> GameIdeas {
        try await ClaudeRouting.$call.withValue(.ideas) {
        try await safe({ try await self.ask(GameIdeas.self, $0, Schemas.gameIdeas(), .medium,
                                            clean: Sanitizer.clean, problem: Validate.ideas) }, Prompts.ideas(kidSaid: kidSaid))
        }
    }
    public func plan(game: String, ctx: AdventureContext) async throws -> GamePlan {
        try await ClaudeRouting.$call.withValue(.plan) {
        try await safe({ try await self.ask(GamePlan.self, $0, Schemas.plan(), .medium,
                      clean: { Sanitizer.clean($0, playerCount: ctx.playerCount) }, problem: { Validate.plan($0, count: RoleCast.count) }) },
                       Prompts.plan(game: game, ctx: ctx))
        }
    }
    /// Round 24: misfit pairings get one retry (`Validate.props`), then the app's curated sensible pairs.
    public func props(ctx: AdventureContext) async throws -> Props {
        try await ClaudeRouting.$call.withValue(.props) {
        PropFit.repair(try await safe({ try await self.ask(Props.self, $0, Schemas.props(), .medium, clean: Sanitizer.clean, problem: Validate.props) },
                                      Prompts.props(ctx: ctx)))
        }
    }
    public func kit(ctx: AdventureContext) async throws -> Kit {
        try await ClaudeRouting.$call.withValue(.kit) {
        try await safe({ try await self.ask(Kit.self, $0, Schemas.kit(), .medium,
                      clean: { Sanitizer.clean($0) }, problem: { Validate.kit($0, roles: ctx.plan?.roles.count ?? 0) }) }, Prompts.kit(ctx: ctx))
        }
    }

    /// Round 20: the kit pages alone (during the hunt). Validated for all 6 recipe items.
    public func kitPages(ctx: AdventureContext) async throws -> [KitItem] {
        try await ClaudeRouting.$call.withValue(.pages) {
        let pages = try await safe({ try await self.ask(KitPages.self, $0, Schemas.kitPages(), .medium,
                                    clean: { p in KitPages(nutmegSays: p.nutmegSays, items: Sanitizer.clean(Kit(nutmegSays: "", items: p.items, scenes: [])).items) },
                                    problem: Validate.pages) }, Prompts.kitPages(ctx: ctx))
        return pages.items
        }
    }

    /// Round 20: the play guide for pages that already exist (when the hunt ends): the whole kit.
    /// The play guide's effort: it's what the kids wait for at Print. Round 20 live: medium 19.1 s, low 9.8 s (same shape).
    public static let scenesEffort: Effort = .low

    public func kitScenes(ctx: AdventureContext, items: [KitItem], effort: Effort = PhaseService.scenesEffort,
                          huntPending: Bool = false) async throws -> Kit {
        try await ClaudeRouting.$call.withValue(.guide) {
        let roles = ctx.plan?.roles.count ?? 0
        let call = {
            try await self.safe({ try await self.ask(KitScenes.self, $0, Schemas.kitScenes(), effort,
                                   clean: { s in KitScenes(nutmegSays: s.nutmegSays, scenes: Sanitizer.clean(Kit(nutmegSays: "", items: [], scenes: s.scenes)).scenes) },
                                   problem: { Validate.scenes($0.scenes, roles: roles) }) },
                                  Prompts.kitScenes(ctx: ctx, items: items, huntPending: huntPending))
        }
        var made = try await call()
        // Round 25: a guide still short after its one fix (the round 24 bakery kept ONE scene) is written once more;
        // whatever comes back, `GuideRepair` makes sure there are enough scenes, real titles and the props.
        if made.scenes.count < GuideRepair.minScenes, let again = try? await call(), again.scenes.count > made.scenes.count { made = again }
        return Kit(nutmegSays: made.nutmegSays, items: items, scenes: made.scenes)
        }
    }

    /// Guide prefetch (2026-11-15): the play guide written while the kids are still hunting (no props in it yet).
    public func earlyGuide(ctx: AdventureContext, items: [KitItem]) async throws -> Kit {
        try await ClaudeRouting.$call.withValue(.guide) {
        var c = ctx; c.props = nil
        let roles = ctx.plan?.roles.count ?? 0
        let made = try await safe({ try await self.ask(KitScenesSix.self, $0, KitScenesSix.schema(), Self.scenesEffort,
                                   clean: { s in KitScenesSix(nutmegSays: s.nutmegSays, scenes: Sanitizer.clean(Kit(nutmegSays: "", items: [], scenes: s.scenes)).scenes,
                                                              story: s.story, setup: s.setup, cleanup: s.cleanup) },
                                   problem: { Validate.scenes($0.scenes, roles: roles) }) },
                                  Prompts.kitScenes(ctx: c, items: items, huntPending: true))
        // There's time during the hunt: a guide still short after its one fix is written again (RetryOnce).
        if made.scenes.count < KitScenesSix.count { throw ClaudeError.decoding("the play guide had \(made.scenes.count) scenes") }
        // Round 36: the story and the setup / clean-up scenes come with it (empty if the answer had none: repaired later).
        return Bookends.ensure(Kit(nutmegSays: made.nutmegSays, items: items, scenes: made.scenes,
                                   story: made.story.map { $0.replacingOccurrences(of: "\"", with: "") }, setup: made.setup, cleanup: made.cleanup))
        }
    }

    /// Round 36 (Haylee: every prop and printed item used on purpose): the ONE re-ask for items whose setup or clean-up
    /// job is missing or unusable (small and fast, like the weave). Its jobs pass the kid-safety check.
    public func itemJobs(_ items: [CoverItem], ctx: AdventureContext) async throws -> ItemJobs {
        try await ClaudeRouting.$call.withValue(.weave) {
        let ids = items.map(\.id)
        let list = items.map { "- \($0.id): \($0.label)" + ($0.purpose.map { " (its purpose: \($0))" } ?? "") }.joined(separator: "\n")
        let roles = (ctx.plan?.roles ?? []).map { "\($0.id.rawValue) \($0.roleName)" }.joined(separator: ", ")
        let user = """
        Phase: setup and clean-up jobs. Before the play starts, the kids set up their play space with these printed pages \
        and household props; at the end they put them away. Items:
        \(list)
        Roles: \(roles).
        For EACH item write one entry (item = its id): setupSay = an imperative phrase of 5 to 12 words that starts with \
        a verb, no role title, that NAMES the item and gives it a clear purpose in the play space; cleanupSay = how they \
        tidy or put it back at the end, framed in the story, starting with a verb and naming it; role = the role it suits \
        best. No quotes. Return ItemJobs.
        \(Prompts.contextJSON(ctx))
        """
        return try await safe({ try await self.ask(ItemJobs.self, $0, ItemJobs.schema(ids: ids), .low, clean: { $0 }, problem: { _ in nil }) }, user)
        }
    }

    /// Guide prefetch: the props worked into 1 or 2 existing steps each (small and fast: low effort, short answer).
    /// The rewritten steps pass the kid-safety check (regenerated once, then this throws and the guide stays as it was).
    public func weaveProps(scenes: [Scene], props: [Prop], taken: [PropUse], ctx: AdventureContext) async throws -> PropWeave {
        try await ClaudeRouting.$call.withValue(.weave) {
        let roles = ctx.plan?.roles ?? []
        return try await safe({ try await self.ask(PropWeave.self, $0, GuideWeave.schema(propIDs: props.map(\.id)), .low,
                                                   clean: { $0 }, problem: { _ in nil }) },
                              GuideWeave.prompt(scenes: scenes, props: props, taken: taken, roles: roles, players: ctx.playerCount))
        }
    }

    /// Guide prefetch: the final guide's text (after the hunt's skips and swaps were applied) passes the kid-safety
    /// check before it's shown.
    public func guideIsSafe(_ scenes: [Scene], extra: [String] = []) async -> Bool {
        await safety.check(scenes.flatMap { [$0.title, $0.nutmegSays] + $0.steps.flatMap { [$0.text] + ($0.short.map { [$0] } ?? []) } } + extra, pretend: true) == nil
    }

    /// One call, sanitized. If the answer is under the spec's minimums (e.g. 1 scene), ask once more with a
    /// short correction. If the second answer is still short but usable, keep it; if unusable, throw.
    func ask<T: Decodable & Sendable>(_ type: T.Type, _ user: String, _ schema: [String: Any], _ effort: Effort,
                                      clean: (T) -> T, problem: (T) -> Validate.Problem?) async throws -> T {
        let first = clean(try await llm.structured(T.self, system: Prompts.system, user: user, schema: JSONSchema(schema), effort: effort))
        guard let issue = problem(first) else { return first }
        #if DEBUG
        NSLog("[CLAUDE] answer not usable, asking once more: %@", issue.message)
        #endif
        let fix = user + "\nYour last answer was not usable: \(issue.message). Fix that and answer again."
        let second = clean(try await llm.structured(T.self, system: Prompts.system, user: fix, schema: JSONSchema(schema), effort: effort))
        switch problem(second) {
        case nil: return second
        case let p? where !p.fatal: return second
        default: throw ClaudeError.decoding("still unusable: \(issue.message)")
        }
    }
    public func turn(kidSaid: String, phase: String, ctx: AdventureContext) async throws -> NutmegTurn {
        try await ClaudeRouting.$call.withValue(.turn) {
        try await safe({ Sanitizer.clean(try await self.llm.structured(NutmegTurn.self, system: Prompts.system, user: $0, schema: JSONSchema(Schemas.turn()), effort: .low)) },
                       Prompts.turn(kidSaid: kidSaid, phase: phase, ctx: ctx))
        }
    }
    public func help(scene: Scene, ctx: AdventureContext) async throws -> NutmegTurn {
        try await ClaudeRouting.$call.withValue(.help) {
        try await safe({ Sanitizer.clean(try await self.llm.structured(NutmegTurn.self, system: Prompts.system, user: $0, schema: JSONSchema(Schemas.turn()), effort: .low)) },
                       Prompts.help(scene: scene, ctx: ctx))
        }
    }
}

/// Minimums the schema can't express. `fatal` means the app can't use it at all.
public enum Validate {
    public struct Problem: Equatable, Sendable { public var message: String; public var fatal: Bool }
    static func short(_ what: String, _ n: Int, want: String, fatal: Bool) -> Problem {
        Problem(message: "it had \(n) \(what); write \(want)", fatal: fatal)
    }
    public static func ideas(_ i: GameIdeas) -> Problem? {
        i.ideas.count < 3 ? short("game ideas", i.ideas.count, want: "exactly 3", fatal: i.ideas.isEmpty) : nil
    }
    public static func plan(_ p: GamePlan, count: Int) -> Problem? {
        p.roles.count < count ? short("roles", p.roles.count, want: "\(count) different roles", fatal: p.roles.isEmpty) : nil
    }
    public static func props(_ p: Props) -> Problem? {
        if p.props.count < 3 { return short("safe props", p.props.count, want: "3 to 5 safe props", fatal: p.props.isEmpty) }
        let bad = p.props.filter { !PropFit.fits(itemID: $0.libraryID ?? $0.id, becomes: $0.becomes) }
        return bad.isEmpty ? nil : Problem(message: "these items can't really become that by shape or use: "
            + bad.map { "\($0.householdItem) as \($0.becomes)" }.joined(separator: "; ") + "; pick items whose shape fits", fatal: false)
    }
    public static func pages(_ p: KitPages) -> Problem? {
        if p.items.isEmpty { return short("kit items", 0, want: "the 6 kit items", fatal: true) }
        let missing = KitRecipe.allCases.filter { r in !p.items.contains { $0.recipe == r } }
        return missing.isEmpty ? nil
            : Problem(message: "the kit was missing these item types: \(missing.map(\.rawValue).joined(separator: ", ")); include all 6", fatal: false)
    }
    public static func kit(_ k: Kit, roles: Int = 0) -> Problem? {
        if k.items.isEmpty { return short("kit items", 0, want: "the 6 kit items", fatal: true) }
        let missing = KitRecipe.allCases.filter { r in !k.items.contains { $0.recipe == r } }
        if !missing.isEmpty {
            return Problem(message: "the kit was missing these item types: \(missing.map(\.rawValue).joined(separator: ", ")); include all 6", fatal: false)
        }
        return scenes(k.scenes, roles: roles)
    }
    /// `roles`: how many ranked roles the game has (round 29: each needs its own ONE task in every scene; 0 = no check).
    public static func scenes(_ scenes: [Scene], roles: Int = 0) -> Problem? {
        let want = GuideRepair.minScenes
        if scenes.count < want { return short("scenes", scenes.count, want: "exactly \(want) scenes", fatal: scenes.isEmpty) }
        if let s = scenes.first(where: { GuideRepair.isPlaceholderTitle($0.title) }) {
            return Problem(message: "scene \"\(s.id)\" had no real title", fatal: false)
        }
        if let s = scenes.first(where: { $0.steps.isEmpty }) {
            return short("tasks in scene \"\(s.title)\"", 0, want: "one task for each role in every scene", fatal: true)
        }
        // Every role gets its OWN task in every scene (non-fatal: the app writes one as a last resort).
        let ids = RoleID.allCases.prefix(min(roles, RoleCast.count))
        let gaps = scenes.compactMap { s -> String? in
            let missing = ids.filter { r in !s.steps.contains { $0.role.role == r } }
            return missing.isEmpty ? nil : "scene \"\(s.title)\" had no task for \(missing.map(\.rawValue).joined(separator: ", "))"
        }
        return gaps.isEmpty ? nil : Problem(message: gaps.joined(separator: "; ")
            + "; give EVERY role (R1 to R6) its own ONE task in EVERY scene, tagged with its role id and calling it by its title", fatal: false)
    }
}
