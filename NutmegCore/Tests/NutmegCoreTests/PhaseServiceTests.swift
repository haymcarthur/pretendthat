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
        let all: [Any] = [a.ideas, a.plan, a.props, a.kit, NutmegTurn(nutmegSays: "Ready, Captain {P1}?", choices: [], understood: true)]
        guard let v = all.compactMap({ $0 as? T }).first else { throw ClaudeError.decoding("no fake for \(T.self)") }
        return v
    }
}

@Test func kitIsSanitized() async throws {
    let llm = FakeLLM(responses: ["Kit": Fixture.oversizedKit])
    let kit = try await PhaseService(llm: llm).kit(ctx: AdventureContext(gameTitle: "Airplane", playerCount: 2))
    #expect(kit.items.count <= 4)
    #expect(kit.scenes.count <= 6)
}

@Test func userPromptHasNoRealNames() async throws {
    let players = [Player(token: .P1, name: "Mia", colorIndex: 0, emoji: "💙")]
    let tokens = NameTokens(players: players)
    let llm = FakeLLM()
    let svc = PhaseService(llm: llm)
    let plan = Sanitizer.clean(Fallback.airplane.plan, playerCount: 1)
    let ctx = AdventureContext(gameTitle: "Airplane", plan: plan, playerCount: 1)
    _ = try await svc.turn(kidSaid: tokens.tokenize("Mia wants to fly"), phase: "players", ctx: ctx)
    _ = try await svc.kit(ctx: ctx)
    #expect(llm.users.allSatisfy { !$0.contains("Mia") })
    #expect(llm.users[0].contains("{P1}"))
}

@Test func systemPromptCarriesPersonalityAndLimits() {
    #expect(Prompts.system.contains("Nutmeg"))
    #expect(Prompts.system.contains("{P1}"))
    #expect(Prompts.system.contains("20 words"))
}

@Test func fallbackDecodes() {
    let a = Fallback.airplane
    #expect(a.ideas.ideas.count == 3)
    #expect(a.plan.roles.count == 4)
    #expect((3...5).contains(a.props.props.count))
    #expect((2...4).contains(a.kit.items.count))
    #expect((4...6).contains(a.kit.scenes.count))
    #expect(a.kit.scenes.allSatisfy { (3...5).contains($0.steps.count) })
    #expect(Sanitizer.clean(a.kit, playerCount: 4) == a.kit)   // already within limits
}

@Test func fallbackTrimsToPlayerCount() {
    let a = Fallback.airplane(playerCount: 2, directorMode: false)
    #expect(a.plan.roles.map(\.player) == [.P1, .P2])
    #expect(a.kit.scenes.allSatisfy { $0.owner != .P3 && $0.owner != .P4 })
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
