import Foundation
import Testing
@testable import NutmegCore

@MainActor
func storeWithKit(owners: [SceneOwner], players: Int, llm: FakeLLM = FakeLLM()) async -> AdventureStore {
    // Round 29: every guide is the ensemble shape (the bundled airplane guide); `owners` is kept for older callers.
    llm.responses["Kit"] = Fallback.airplane.kit
    let store = AdventureStore(service: PhaseService(llm: llm))
    await store.start()
    await store.chooseGame("Airplane")
    store.setPlayerCount(players)
    await store.confirmPlayers()
    await store.confirmRoles()
    await store.confirmProps()
    return store
}

@MainActor
func walk(_ store: AdventureStore) async -> [Phase] {
    var seen: [Phase] = []
    store.beginPlay()
    for _ in 0..<(store.kit?.scenes.count ?? 0) {
        seen.append(store.phase)
        store.nextScene()   // round 29: the green ▶ Next scene
    }
    return seen
}

@Test @MainActor func flowReachesKitReady() async {
    let store = await storeWithKit(owners: [.R1, .R2, .all, .R1], players: 3)
    #expect(store.phase == .kitReady)
    #expect(store.plan?.roles.count == 6 && store.playingRoles.count == 3)   // round C1: 6 ranked roles, 3 play
    #expect(store.usingFallback == false)
}

@Test @MainActor func fiveKidsPlayTheFirstFiveRankedRoles() async {
    let store = await storeWithKit(owners: [.R1, .R2, .R3, .R4], players: 5)
    #expect(store.playerCount == 5)
    #expect(store.plan?.roles.count == 6 && store.playingRoles.map(\.id) == Array(RoleID.allCases.prefix(5)))
    #expect(store.plan?.roles.allSatisfy { $0.count == 1 } == true)
    store.beginPlay()
    // Round 29 (ensemble scenes): no hand-off; scene 1 opens with every playing role's task.
    #expect(store.phase == .scene(0))
    // Round 36: scene 0 is the story (no rows), then the setup scene; every scene after it has a row per playing role.
    #expect(store.inStory && store.kit?.scenes[0].steps.isEmpty == true && store.nutmegLine == store.kit?.story.map { PlayCast.endSentence($0) })
    #expect(store.kit?.scenes.dropFirst().allSatisfy { $0.steps.count == 5 } == true)
    store.nextScene()
    #expect(store.nutmegLine.hasPrefix("Pretend that") && store.nutmegLine.contains(HandOffLines.taskCue) && !store.nutmegLine.contains("Captain,"))   // round 34
}

@Test @MainActor func everyKidCountPlaysTheSameThreeScenes() async {
    for n in [1, 2, 3, 6] {
        let store = await storeWithKit(owners: [.R1, .R2, .all], players: n)
        #expect(await walk(store) == (0..<6).map { .scene($0) }, "\(n)")   // round 36: story, setup, 3 play, clean-up
        #expect(store.phase == .end)
    }
}

@Test @MainActor func lastSceneGoesToEnd() async {
    let store = await storeWithKit(owners: [.all, .all, .all, .all], players: 2)
    _ = await walk(store)
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
    #expect(store.kit?.scenes.filter { $0.arc == .play }.allSatisfy { $0.steps.count == 2 && !$0.steps.contains { $0.role == .R3 } } == true)
}

@Test @MainActor func newGameClearsEverything() async {
    let store = await storeWithKit(owners: [.R1, .R2, .all, .R1], players: 2)
    store.newGame()
    #expect(store.playerCount == 0)
    #expect(store.kit == nil && store.plan == nil && store.props == nil)
    #expect(store.phase == .hello)
}

@Test @MainActor func kidSaidRepliesByRole() async {
    let store = await storeWithKit(owners: [.R1, .R2, .all, .R1], players: 2)
    await store.kidSaid("I want juice")
    #expect(store.nutmegLine == "Ready, Captain?")
}

@Test @MainActor func playerCountDecidesThePlayingRoles() async {
    for n in 1...6 {
        let store = await storeWithKit(owners: [.all, .all, .all, .all], players: n)
        #expect(store.plan?.roles.count == 6)
        #expect(store.playingRoles.count == n)
        #expect(store.plan?.roles.allSatisfy { $0.count == 1 } == true)
    }
}

@Test @MainActor func playAgainRestartsScenes() async {
    let store = await storeWithKit(owners: [.all, .all, .all, .all], players: 2)
    _ = await walk(store)
    store.playAgain()
    #expect(store.phase == .scene(0))   // round 29: back to scene 1, everyone together
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

struct RefusingLLM: LLM {
    func structured<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, schema: JSONSchema, effort: Effort) async throws -> T {
        throw ClaudeError.refusal
    }
}

@Test @MainActor func refusalGoesStraightToFallback() async {
    let store = AdventureStore(service: PhaseService(llm: RefusingLLM()))
    await store.start()
    #expect(store.usingFallback && store.lastError == nil)
}

// MARK: Round 29: the green ▶ Next scene (no checkboxes, no Done, no auto-advance)

@MainActor
func storeAtFirstScene(players: Int = 3) async -> AdventureStore {
    let store = await storeWithKit(owners: [.R1, .R2, .all], players: players)
    store.beginPlay()
    return store
}

@Test @MainActor func nextSceneMovesOnAndTheLastGoesToTheEnd() async {
    let store = await storeAtFirstScene()
    #expect(store.phase == .scene(0))
    store.nextScene()
    #expect(store.phase == .scene(1) && store.nutmegLine == HandOffLines.sceneOpen(store.kit!.scenes[1], first: true) && store.kit!.scenes[1].arc == .setup)
    store.nextScene(); store.nextScene(); store.nextScene(); store.nextScene(); store.nextScene()   // round 36: + setup … clean-up
    #expect(store.phase == .end && store.nutmegLine == HandOffLines.end())
    store.nextScene()   // nothing past The End
    #expect(store.phase == .end)
}

@Test @MainActor func voiceNextSceneDoesWhatTheButtonDoes() async {
    let store = await storeAtFirstScene()
    let out = await store.apply(.nextScene)
    #expect(out.contains("Say nothing") && store.phase == .scene(1))
    #expect(Realtime.afterHuntTools(.scene(0)) == ["next_scene", "read_job", "go_to_step", "just_talk"])
    #expect(PlanningCall.decode(name: "next_scene", arguments: "{}") == .nextScene)
    #expect(Realtime.tools.contains { $0["name"] as? String == "next_scene" })
    #expect(!Realtime.tools.contains { ["finish_scene", "confirm_handoff"].contains($0["name"] as? String ?? "") })
    store.debugSetPhase(.kitReady)
    #expect(await store.apply(.nextScene).contains("no scene"))
}

@Test @MainActor func thePlayStepAtTheEndReopensTheLastScene() async {
    let store = await storeAtFirstScene()
    for _ in 0..<6 { store.nextScene() }   // round 36: story, setup, 3 play scenes, clean-up
    #expect(store.phase == .end)
    #expect(store.goTo(.play))
    #expect(store.phase == .scene(5) && store.nutmegLine == HandOffLines.sceneOpen(store.kit!.scenes[5]) && store.kit!.scenes[5].arc == .cleanup)
    store.nextScene(); store.debugSetPhase(.end)
    #expect(await store.apply(.goToStep(.play)) == AdventureStore.backToLastSceneOutput && store.phase == .scene(5))
}
