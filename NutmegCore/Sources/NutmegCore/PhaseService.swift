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
        let second = try await make(user + Self.saferNote)
        guard await safety.check(second.safetyTexts, pretend: true) != nil else { return second }
        throw ClaudeError.refusal
    }

    public func ideas(kidSaid: String?) async throws -> GameIdeas {
        try await safe({ try await self.ask(GameIdeas.self, $0, Schemas.gameIdeas(), .medium,
                                            clean: Sanitizer.clean, problem: Validate.ideas) }, Prompts.ideas(kidSaid: kidSaid))
    }
    public func plan(game: String, ctx: AdventureContext) async throws -> GamePlan {
        try await safe({ try await self.ask(GamePlan.self, $0, Schemas.plan(), .medium,
                      clean: { Sanitizer.clean($0, playerCount: ctx.playerCount) }, problem: { Validate.plan($0, count: min(4, max(1, ctx.playerCount))) }) },
                       Prompts.plan(game: game, ctx: ctx))
    }
    public func props(ctx: AdventureContext) async throws -> Props {
        try await safe({ try await self.ask(Props.self, $0, Schemas.props(), .medium, clean: Sanitizer.clean, problem: Validate.props) },
                       Prompts.props(ctx: ctx))
    }
    public func kit(ctx: AdventureContext) async throws -> Kit {
        try await safe({ try await self.ask(Kit.self, $0, Schemas.kit(), .medium,
                      clean: { Sanitizer.clean($0, roleCount: ctx.plan?.roles.count ?? 4) }, problem: Validate.kit) }, Prompts.kit(ctx: ctx))
    }

    /// Round 20: the kit pages alone (during the hunt). Validated for all 6 recipe items.
    public func kitPages(ctx: AdventureContext) async throws -> [KitItem] {
        let pages = try await safe({ try await self.ask(KitPages.self, $0, Schemas.kitPages(), .medium,
                                    clean: { p in KitPages(nutmegSays: p.nutmegSays, items: Sanitizer.clean(Kit(nutmegSays: "", items: p.items, scenes: []), roleCount: 4).items) },
                                    problem: Validate.pages) }, Prompts.kitPages(ctx: ctx))
        return pages.items
    }

    /// Round 20: the play guide for pages that already exist (when the hunt ends): the whole kit.
    public func kitScenes(ctx: AdventureContext, items: [KitItem]) async throws -> Kit {
        let roles = ctx.plan?.roles.count ?? 4
        let made = try await safe({ try await self.ask(KitScenes.self, $0, Schemas.kitScenes(), .medium,
                                   clean: { s in KitScenes(nutmegSays: s.nutmegSays, scenes: Sanitizer.clean(Kit(nutmegSays: "", items: [], scenes: s.scenes), roleCount: roles).scenes) },
                                   problem: { Validate.scenes($0.scenes) }) },
                                  Prompts.kitScenes(ctx: ctx, items: items))
        return Kit(nutmegSays: made.nutmegSays, items: items, scenes: made.scenes)
    }

    /// One call, sanitized. If the answer is under the spec's minimums (e.g. 1 scene), ask once more with a
    /// short correction. If the second answer is still short but usable, keep it; if unusable, throw.
    func ask<T: Decodable & Sendable>(_ type: T.Type, _ user: String, _ schema: [String: Any], _ effort: Effort,
                                      clean: (T) -> T, problem: (T) -> Validate.Problem?) async throws -> T {
        let first = clean(try await llm.structured(T.self, system: Prompts.system, user: user, schema: JSONSchema(schema), effort: effort))
        guard let issue = problem(first) else { return first }
        let fix = user + "\nYour last answer was not usable: \(issue.message). Fix that and answer again."
        let second = clean(try await llm.structured(T.self, system: Prompts.system, user: fix, schema: JSONSchema(schema), effort: effort))
        switch problem(second) {
        case nil: return second
        case let p? where !p.fatal: return second
        default: throw ClaudeError.decoding("still unusable: \(issue.message)")
        }
    }
    public func turn(kidSaid: String, phase: String, ctx: AdventureContext) async throws -> NutmegTurn {
        try await safe({ Sanitizer.clean(try await self.llm.structured(NutmegTurn.self, system: Prompts.system, user: $0, schema: JSONSchema(Schemas.turn()), effort: .low)) },
                       Prompts.turn(kidSaid: kidSaid, phase: phase, ctx: ctx))
    }
    public func help(scene: Scene, ctx: AdventureContext) async throws -> NutmegTurn {
        try await safe({ Sanitizer.clean(try await self.llm.structured(NutmegTurn.self, system: Prompts.system, user: $0, schema: JSONSchema(Schemas.turn()), effort: .low)) },
                       Prompts.help(scene: scene, ctx: ctx))
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
        p.props.count < 3 ? short("safe props", p.props.count, want: "3 to 5 safe props", fatal: p.props.isEmpty) : nil
    }
    public static func pages(_ p: KitPages) -> Problem? {
        if p.items.isEmpty { return short("kit items", 0, want: "the 6 kit items", fatal: true) }
        let missing = KitRecipe.allCases.filter { r in !p.items.contains { $0.recipe == r } }
        return missing.isEmpty ? nil
            : Problem(message: "the kit was missing these item types: \(missing.map(\.rawValue).joined(separator: ", ")); include all 6", fatal: false)
    }
    public static func kit(_ k: Kit) -> Problem? {
        if k.items.isEmpty { return short("kit items", 0, want: "the 6 kit items", fatal: true) }
        let missing = KitRecipe.allCases.filter { r in !k.items.contains { $0.recipe == r } }
        if !missing.isEmpty {
            return Problem(message: "the kit was missing these item types: \(missing.map(\.rawValue).joined(separator: ", ")); include all 6", fatal: false)
        }
        return scenes(k.scenes)
    }
    public static func scenes(_ scenes: [Scene]) -> Problem? {
        if scenes.count < 4 { return short("scenes", scenes.count, want: "4 to 6 scenes", fatal: scenes.isEmpty) }
        if let s = scenes.first(where: { $0.title.trimmingCharacters(in: .whitespaces).count < 3 }) {
            return Problem(message: "scene \"\(s.id)\" had no real title", fatal: false)
        }
        if let s = scenes.first(where: { $0.steps.count < 3 }) {
            return short("steps in scene \"\(s.title)\"", s.steps.count, want: "3 to 5 steps in every scene", fatal: s.steps.isEmpty)
        }
        return nil
    }
}
