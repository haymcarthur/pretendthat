import Foundation

/// Compact, tokenized summary of what's decided so far. Never contains real names.
public struct AdventureContext: Codable, Equatable, Sendable {
    public var gameTitle: String?
    public var plan: GamePlan?
    public var props: Props?
    public var playerCount: Int
    public var directorMode: Bool
    public init(gameTitle: String? = nil, plan: GamePlan? = nil, props: Props? = nil, playerCount: Int, directorMode: Bool = false) {
        self.gameTitle = gameTitle; self.plan = plan; self.props = props; self.playerCount = playerCount; self.directorMode = directorMode
    }
}

/// One async function per phase. Inputs are already tokenized; every result is sanitized.
public final class PhaseService: Sendable {
    let llm: LLM
    public init(llm: LLM) { self.llm = llm }

    public func ideas(kidSaid: String?) async throws -> GameIdeas {
        try await ask(GameIdeas.self, Prompts.ideas(kidSaid: kidSaid), Schemas.gameIdeas(), .medium,
                      clean: Sanitizer.clean, problem: Validate.ideas)
    }
    public func plan(game: String, ctx: AdventureContext) async throws -> GamePlan {
        try await ask(GamePlan.self, Prompts.plan(game: game, ctx: ctx), Schemas.plan(), .medium,
                      clean: { Sanitizer.clean($0, playerCount: ctx.count) }, problem: { Validate.plan($0, count: ctx.count) })
    }
    public func props(ctx: AdventureContext) async throws -> Props {
        try await ask(Props.self, Prompts.props(ctx: ctx), Schemas.props(), .medium, clean: Sanitizer.clean, problem: Validate.props)
    }
    public func kit(ctx: AdventureContext) async throws -> Kit {
        try await ask(Kit.self, Prompts.kit(ctx: ctx), Schemas.kit(), .medium,
                      clean: { Sanitizer.clean($0, playerCount: ctx.count) }, problem: Validate.kit)
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
        Sanitizer.clean(try await llm.structured(NutmegTurn.self, system: Prompts.system, user: Prompts.turn(kidSaid: kidSaid, phase: phase, ctx: ctx), schema: JSONSchema(Schemas.turn()), effort: .low))
    }
    public func help(scene: Scene, ctx: AdventureContext) async throws -> NutmegTurn {
        Sanitizer.clean(try await llm.structured(NutmegTurn.self, system: Prompts.system, user: Prompts.help(scene: scene, ctx: ctx), schema: JSONSchema(Schemas.turn()), effort: .low))
    }
}

extension AdventureContext {
    /// Token count used for sanitizing: Director mode always uses 4 role tokens.
    var count: Int { directorMode ? 4 : playerCount }
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
        p.roles.count < count ? short("roles", p.roles.count, want: "one role for each of \(count) players", fatal: p.roles.isEmpty) : nil
    }
    public static func props(_ p: Props) -> Problem? {
        p.props.count < 3 ? short("safe props", p.props.count, want: "3 to 5 safe props", fatal: p.props.isEmpty) : nil
    }
    public static func kit(_ k: Kit) -> Problem? {
        if k.items.count < 2 { return short("kit items", k.items.count, want: "2 to 4 kit items", fatal: k.items.isEmpty) }
        if k.scenes.count < 4 { return short("scenes", k.scenes.count, want: "4 to 6 scenes", fatal: k.scenes.isEmpty) }
        if let s = k.scenes.first(where: { $0.title.trimmingCharacters(in: .whitespaces).count < 3 }) {
            return Problem(message: "scene \"\(s.id)\" had no real title", fatal: false)
        }
        if let s = k.scenes.first(where: { $0.steps.count < 3 }) {
            return short("steps in scene \"\(s.title)\"", s.steps.count, want: "3 to 5 steps in every scene", fatal: s.steps.isEmpty)
        }
        return nil
    }
}
