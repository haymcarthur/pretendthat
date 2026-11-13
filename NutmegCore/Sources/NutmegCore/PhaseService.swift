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
        Sanitizer.clean(try await llm.structured(GameIdeas.self, system: Prompts.system, user: Prompts.ideas(kidSaid: kidSaid), schema: JSONSchema(Schemas.gameIdeas()), effort: .medium))
    }
    public func plan(game: String, ctx: AdventureContext) async throws -> GamePlan {
        Sanitizer.clean(try await llm.structured(GamePlan.self, system: Prompts.system, user: Prompts.plan(game: game, ctx: ctx), schema: JSONSchema(Schemas.plan()), effort: .medium), playerCount: ctx.count)
    }
    public func props(ctx: AdventureContext) async throws -> Props {
        Sanitizer.clean(try await llm.structured(Props.self, system: Prompts.system, user: Prompts.props(ctx: ctx), schema: JSONSchema(Schemas.props()), effort: .medium))
    }
    public func kit(ctx: AdventureContext) async throws -> Kit {
        Sanitizer.clean(try await llm.structured(Kit.self, system: Prompts.system, user: Prompts.kit(ctx: ctx), schema: JSONSchema(Schemas.kit()), effort: .medium), playerCount: ctx.count)
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
