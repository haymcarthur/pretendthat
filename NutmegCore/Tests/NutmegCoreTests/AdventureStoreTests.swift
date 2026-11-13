import Foundation
import Testing
@testable import NutmegCore

@MainActor
func storeWithKit(owners: [SceneOwner], players: Int, director: Bool = false, llm: FakeLLM = FakeLLM()) async -> AdventureStore {
    var kit = Fallback.airplane.kit
    kit.scenes = owners.enumerated().map { Fixture.scene("s\($0.offset)", owner: $0.element) }
    llm.responses["Kit"] = kit
    let store = AdventureStore(service: PhaseService(llm: llm))
    await store.start()
    await store.chooseGame("Airplane")
    store.setPlayerCount(director ? 5 : players)
    for t in PlayerToken.allCases.prefix(players) { store.setName(["Mia", "Sam", "Ollie", "Ava"][t.index], for: t) }
    await store.confirmPlayers()
    await store.confirmRoles()
    await store.confirmProps()
    return store
}

@MainActor
func walk(_ store: AdventureStore) -> [Phase] {
    var seen: [Phase] = []
    store.beginPlay()
    for i in 0..<(store.kit?.scenes.count ?? 0) {
        seen.append(store.phase)
        if case .handoff = store.phase, let owner = store.kit?.scenes[i].owner.token { store.badgeTapped(owner) }
        store.sceneDone()
        store.nextScene()
    }
    return seen
}

@Test @MainActor func flowReachesKitReady() async {
    let store = await storeWithKit(owners: [.P1, .P2, .all, .P1], players: 3)
    #expect(store.phase == .kitReady)
    #expect(store.plan?.roles.count == 3)
    #expect(store.usingFallback == false)
}

@Test @MainActor func directorModeSkipsHandoff() async {
    let store = await storeWithKit(owners: [.P1, .P2, .P3, .P4], players: 0, director: true)
    #expect(store.directorMode)
    #expect(store.players.count == 4)
    #expect(walk(store).allSatisfy { if case .scene = $0 { true } else { false } })
}

@Test @MainActor func singlePlayerSkipsHandoff() async {
    let store = await storeWithKit(owners: [.P1, .all, .P1, .P1], players: 1)
    #expect(walk(store).allSatisfy { if case .scene = $0 { true } else { false } })
}

@Test @MainActor func handoffOnlyWhenOwnerChanges() async {
    let store = await storeWithKit(owners: [.P1, .P1, .P2, .all, .P2], players: 2)
    #expect(walk(store) == [.handoff(sceneIndex: 0), .scene(1), .handoff(sceneIndex: 2), .scene(3), .scene(4)])
}

@Test @MainActor func wrongBadgeDoesNotAdvance() async {
    let store = await storeWithKit(owners: [.P1, .P2, .all, .P1], players: 2)
    store.beginPlay()
    #expect(store.phase == .handoff(sceneIndex: 0))
    store.badgeTapped(.P2)
    #expect(store.phase == .handoff(sceneIndex: 0))
    store.badgeTapped(.P1)
    #expect(store.phase == .scene(0))
}

@Test @MainActor func lastSceneGoesToEnd() async {
    let store = await storeWithKit(owners: [.all, .all, .all, .all], players: 2)
    _ = walk(store)
    #expect(store.phase == .end)
}

@Test @MainActor func firstFailureOffersRetrySecondUsesFallback() async {
    let llm = FakeLLM(failures: 2)
    let store = AdventureStore(service: PhaseService(llm: llm))
    await store.start()
    #expect(store.lastError != nil)
    #expect(store.usingFallback == false)
    #expect(store.nutmegLine.contains("Oops"))
    await store.retry()
    #expect(store.usingFallback)
    #expect(store.ideas == Fallback.airplane.ideas)
    #expect(store.phase == .pickGame)
}

@Test @MainActor func noServiceRunsOnFallback() async {
    let store = AdventureStore(service: nil)
    await store.start()
    await store.chooseGame("Airplane")
    store.setPlayerCount(2)
    await store.confirmPlayers()
    await store.confirmRoles()
    await store.confirmProps()
    #expect(store.usingFallback)
    #expect(store.phase == .kitReady)
    #expect(store.kit?.scenes.allSatisfy { $0.owner != .P3 && $0.owner != .P4 } == true)
}

@Test @MainActor func newGameClearsNamesAndKit() async {
    let store = await storeWithKit(owners: [.P1, .P2, .all, .P1], players: 2)
    store.newGame()
    #expect(store.players.isEmpty)
    #expect(store.kit == nil && store.plan == nil && store.props == nil)
    #expect(store.phase == .hello)
}

@Test @MainActor func nutmegLineShowsRealNames() async {
    let store = await storeWithKit(owners: [.P1, .P2, .all, .P1], players: 2)
    await store.kidSaid("Mia wants juice")
    #expect(store.nutmegLine == "Ready, Captain Mia?")
}

@Test @MainActor func kidSpeechIsTokenizedBeforeSending() async {
    let llm = FakeLLM()
    let store = await storeWithKit(owners: [.P1, .P2, .all, .P1], players: 2, llm: llm)
    await store.kidSaid("Sam and Mia")
    #expect(llm.users.last?.contains("{P2} and {P1}") == true)
    #expect(llm.users.allSatisfy { !$0.contains("Mia") && !$0.contains("Sam") })
}

@Test @MainActor func swapRolesRotates() async {
    let store = await storeWithKit(owners: [.all, .all, .all, .all], players: 3)
    let before = store.plan!.roles.map(\.roleName)
    store.swapRoles()
    #expect(store.plan!.roles.map(\.roleName) == Array(before[1...] + before[..<1]))
    #expect(store.plan!.roles.map(\.player) == [.P1, .P2, .P3])
}

@Test @MainActor func playAgainRestartsScenes() async {
    let store = await storeWithKit(owners: [.all, .all, .all, .all], players: 2)
    _ = walk(store)
    store.playAgain()
    #expect(store.phase == .scene(0))
    #expect(store.kit != nil)
}

struct AuthFailLLM: LLM {
    func structured<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, schema: JSONSchema, effort: Effort) async throws -> T {
        throw ClaudeError.http(401)
    }
}

@Test @MainActor func badKeyGoesStraightToFallback() async {
    let store = AdventureStore(service: PhaseService(llm: AuthFailLLM()))
    await store.start()
    #expect(store.usingFallback)
    #expect(store.lastError == nil)
    #expect(store.ideas == Fallback.airplane.ideas)
}
