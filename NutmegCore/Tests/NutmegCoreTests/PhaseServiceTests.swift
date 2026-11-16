import Foundation
import Testing
@testable import NutmegCore

/// Returns canned values per type and records every prompt it sees.
final class FakeLLM: LLM, @unchecked Sendable {
    private let lock = NSLock()
    private var _users: [String] = []
    private var _calls = 0
    var users: [String] { lock.withLock { _users } }
    var calls: Int { lock.withLock { _calls } }
    var failuresLeft: Int
    var responses: [String: Any]

    init(responses: [String: Any] = [:], failures: Int = 0) { self.responses = responses; self.failuresLeft = failures }

    func structured<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, schema: JSONSchema, effort: Effort) async throws -> T {
        let shouldFail: Bool = lock.withLock {
            _users.append(user); _calls += 1
            if failuresLeft > 0 { failuresLeft -= 1; return true }
            return false
        }
        if shouldFail { throw ClaudeError.transport }
        if let v = lock.withLock({ responses[String(describing: T.self)] }) as? T { return v }
        let a = Fallback.airplane
        let all: [Any] = [a.ideas, a.plan, a.props, a.kit, NutmegTurn(nutmegSays: "Ready, Captain?", choices: [], understood: true),
                          KitPages(nutmegSays: a.kit.nutmegSays, items: a.kit.items), KitScenes(nutmegSays: a.kit.nutmegSays, scenes: a.kit.scenes),
                          KitScenesSix(nutmegSays: a.kit.nutmegSays, scenes: a.kit.scenes)]
        guard let v = all.compactMap({ $0 as? T }).first else { throw ClaudeError.decoding("no fake for \(T.self)") }
        return v
    }
}

@Test func kitIsSanitized() async throws {
    let llm = FakeLLM(responses: ["Kit": Fixture.oversizedKit])
    let kit = try await PhaseService(llm: llm).kit(ctx: AdventureContext(gameTitle: "Airplane", playerCount: 2))
    #expect(kit.items.count <= 6)
    #expect(kit.scenes.count <= 6)
}

@Test func promptsNeverAskForOrCarryNames() async throws {
    let llm = FakeLLM()
    let svc = PhaseService(llm: llm)
    let plan = Sanitizer.clean(Fallback.airplane.plan, playerCount: 1)
    let ctx = AdventureContext(gameTitle: "Airplane", plan: plan, playerCount: 1)
    _ = try await svc.turn(kidSaid: "I want to fly", phase: "players", ctx: ctx)
    _ = try await svc.kit(ctx: ctx)
    #expect(llm.users.allSatisfy { !$0.contains("{P") })
    #expect(llm.users[1].contains("Name: ____"))
}

@Test func systemPromptCarriesPersonalityAndLimits() {
    #expect(Prompts.system.contains("Nutmeg"))
    #expect(Prompts.system.contains("We never ask for kids' names"))
    #expect(!Prompts.system.contains("{P"))
    #expect(Prompts.system.contains("20 words"))
}

@Test func fallbackDecodes() {
    let a = Fallback.airplane
    #expect(a.ideas.ideas.count == 3)
    #expect(a.plan.roles.count == 6)   // round C1: 6 ranked roles
    #expect((3...5).contains(a.props.props.count))
    #expect(a.kit.items.map(\.recipe) == KitRecipe.allCases.map { Optional($0) })
    #expect(a.kit.scenes.count == 6)
    // Every scene: one step for each of the 6 roles, plus 2 for everyone.
    #expect(Validate.scenes(a.kit.scenes, roles: 6) == nil)
    #expect(a.kit.scenes.allSatisfy { $0.steps.count == 8 && $0.steps.filter { $0.role == .all }.count == 2 })
    #expect(Sanitizer.clean(a.kit) == a.kit)   // already within limits
}

@Test func fallbackKeepsSixRolesForAnyCount() {
    for n in 1...6 {
        let a = Fallback.airplane(playerCount: n)
        #expect(a.plan.roles.map(\.roleName) == ["Captain", "Flight Attendant", "Co-Pilot", "Passenger", "Snack Chef", "Weather Watcher"])
        #expect(a.kit == Fallback.airplane(playerCount: 1).kit)   // the count never changes the game data
        let view = PlayCast.kit(a.kit, roles: a.plan.roles, players: n)
        #expect(view.scenes.allSatisfy { s in s.steps.compactMap(\.role.role).sorted { $0.rank < $1.rank } == Array(RoleID.allCases.prefix(n)) })
        #expect(view.scenes.first?.owner == .R1)
    }
}

@Test func shortKitAsksOnceMoreThenKeepsIt() async throws {
    var short = Fallback.airplane.kit
    short.scenes = [Fixture.scene("only")]
    let llm = FakeLLM(responses: ["Kit": short])
    let kit = try await PhaseService(llm: llm).kit(ctx: AdventureContext(gameTitle: "Restaurant", playerCount: 2))
    #expect(llm.calls == 2)
    #expect(llm.users.last?.contains("it had 1 scenes; write 4 to 6 scenes") == true)
    #expect(kit.scenes.count == 1)
}

@Test func unusableKitThrowsAfterCorrection() async {
    var empty = Fallback.airplane.kit
    empty.scenes = []
    let llm = FakeLLM(responses: ["Kit": empty])
    await #expect(throws: ClaudeError.self) { try await PhaseService(llm: llm).kit(ctx: AdventureContext(gameTitle: "X", playerCount: 2)) }
    #expect(llm.calls == 2)
}

@Test func goodKitIsOneCall() async throws {
    let llm = FakeLLM()
    _ = try await PhaseService(llm: llm).kit(ctx: AdventureContext(gameTitle: "Airplane", playerCount: 2))
    #expect(llm.calls == 1)
}
