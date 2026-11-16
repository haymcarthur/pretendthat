import Foundation
import Testing
@testable import NutmegCore

@MainActor
func storeWithKit(owners: [SceneOwner], players: Int, llm: FakeLLM = FakeLLM()) async -> AdventureStore {
    var kit = Fallback.airplane.kit
    kit.scenes = owners.enumerated().map { Fixture.scene("s\($0.offset)", owner: $0.element) }
    llm.responses["Kit"] = kit
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
    store.autoCheckStep = .zero; store.autoCheckHold = .zero
    store.beginPlay()
    for i in 0..<(store.kit?.scenes.count ?? 0) {
        seen.append(store.phase)
        if case .handoff = store.phase, let owner = store.kit?.scenes[i].owner.role { store.badgeTapped(owner) }
        await store.sceneDone()
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
    #expect(store.phase == .handoff(sceneIndex: 0))
    #expect(store.nutmegLine == "Pass the iPad to the Captain! Tap the green check when you have the iPad!")
}

@Test @MainActor func handoffLineUsesTheRoleNeverAName() async {
    let store = await storeWithKit(owners: [.R2, .R1, .all, .R1], players: 3)
    store.autoCheckStep = .zero; store.autoCheckHold = .zero
    store.beginPlay(); store.badgeTapped(.R1)
    await store.sceneDone()
    #expect(store.nutmegLine.hasSuffix("Pass the iPad to the Flight Attendant! Tap the green check when you have the iPad!"))
}

@Test @MainActor func handoffsRotateThroughThePlayingRoles() async {
    // Round C1 (Haylee): every kid gets a turn holding the iPad. Claude's old owners are ignored.
    let two = await storeWithKit(owners: [.R1, .R1, .R2, .all, .R2], players: 2)
    #expect(await walk(two) == (0..<5).map { .handoff(sceneIndex: $0) })
    #expect((0..<5).map { two.kit!.scenes[$0].owner } == [.R1, .R2, .R1, .R2, .R1])
    let three = await storeWithKit(owners: Array(repeating: .all, count: 6), players: 3)
    #expect(three.kit!.scenes.map(\.owner) == [.R1, .R2, .R3, .R1, .R2, .R3])
}

@Test @MainActor func singlePlayerSkipsHandoff() async {
    let store = await storeWithKit(owners: [.R1, .all, .R1, .R1], players: 1)
    #expect(await walk(store).allSatisfy { if case .scene = $0 { true } else { false } })
}

@Test @MainActor func wrongBadgeDoesNotAdvance() async {
    let store = await storeWithKit(owners: [.R1, .R2, .all, .R1], players: 2)
    store.beginPlay()
    #expect(store.phase == .handoff(sceneIndex: 0))
    store.badgeTapped(.R2)
    #expect(store.phase == .handoff(sceneIndex: 0))
    store.badgeTapped(.R1)
    #expect(store.phase == .scene(0))
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
    #expect(store.kit?.scenes.allSatisfy { $0.owner != .R3 && $0.owner != .R4 } == true)
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
    #expect(store.phase == .handoff(sceneIndex: 0))   // round C1: back to the Captain's turn
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

// MARK: Round 10 / 26: finishing a scene (no Done button; "we're done" by voice checks the rest)

@MainActor
func storeAtFirstScene(grace: Duration = .milliseconds(150)) async -> AdventureStore {
    let store = await storeWithKit(owners: [.R1, .R2, .all, .R1], players: 3)
    store.autoCheckStep = .zero; store.autoCheckHold = .zero
    store.autoAdvanceGrace = grace
    store.beginPlay()
    if case .handoff(let i) = store.phase, let owner = store.kit?.scenes[i].owner.role { store.badgeTapped(owner) }
    return store
}

@Test @MainActor func finishingEarlyAutoChecksThenGoesToTheHandoff() async {
    let store = await storeAtFirstScene()
    #expect(store.phase == .scene(0))
    store.toggleStep(0)
    await store.sceneDone()
    #expect(store.phase == .handoff(sceneIndex: 1))
    #expect(store.checkedSteps.count == store.kit?.scenes[0].steps.count)
}

@Test @MainActor func tappingACheckedStepUnchecksIt() async {
    let store = await storeAtFirstScene()
    store.toggleStep(0); store.toggleStep(0)
    #expect(store.checkedSteps.isEmpty)
}

@Test @MainActor func voiceFinishThenVoiceHandoff() async {
    let store = await storeAtFirstScene()
    let done = await store.apply(.finishScene)
    #expect(done.contains("Say nothing") && store.phase == .handoff(sceneIndex: 1))
    let out = await store.apply(.confirmHandoff)
    #expect(out.contains("Hand-off confirmed"))
    #expect(store.phase == .scene(1))
    #expect(await store.apply(.finishScene) == "Scene finished: the app moves on and says the next line. Say nothing.")
    #expect(Realtime.afterHuntTools(.scene(0)) == ["finish_scene", "go_to_step", "just_talk"])
    #expect(PlanningCall.decode(name: "finish_scene", arguments: "{}") == .finishScene)
    #expect(Realtime.tools.contains { $0["name"] as? String == "finish_scene" })
}

// Round 26 (Haylee): the checklist moves on by itself once every step is checked, after a grace.
@Test @MainActor func checkingEveryStepAutoAdvancesAfterTheGrace() async throws {
    let store = await storeAtFirstScene()
    var told = 0
    store.willAutoAdvance = { told += 1 }
    let n = store.kit?.scenes[0].steps.count ?? 0
    for s in 0..<n { store.toggleStep(s) }
    #expect(store.advancePending && store.phase == .scene(0))   // a beat first: the last check is still visible
    for _ in 0..<300 where store.phase == .scene(0) { try await Task.sleep(for: .milliseconds(10)) }
    #expect(store.phase == .handoff(sceneIndex: 1), "\(store.phase)")
    #expect(told == 1 && !store.advancePending)
}

@Test @MainActor func uncheckingInsideTheGraceCancelsTheAdvance() async throws {
    let store = await storeAtFirstScene(grace: .milliseconds(300))
    let n = store.kit?.scenes[0].steps.count ?? 0
    for s in 0..<n { store.toggleStep(s) }
    try await Task.sleep(for: .milliseconds(100))
    store.toggleStep(n - 1)   // an accidental last tap, undone in time
    #expect(!store.advancePending)
    try await Task.sleep(for: .milliseconds(500))
    #expect(store.phase == .scene(0) && store.checkedSteps.count == n - 1)
    store.toggleStep(n - 1)   // checked again: the grace starts over, then it moves on
    for _ in 0..<300 where store.phase == .scene(0) { try await Task.sleep(for: .milliseconds(10)) }
    #expect(store.phase == .handoff(sceneIndex: 1))
}

@Test @MainActor func theDefaultGraceIsAboutASecondAndAHalf() async {
    #expect(AdventureStore(service: nil).autoAdvanceGrace == .milliseconds(1500))
}

@Test @MainActor func leavingTheSceneCancelsAPendingAdvance() async throws {
    let store = await storeAtFirstScene(grace: .milliseconds(200))
    let n = store.kit?.scenes[0].steps.count ?? 0
    for s in 0..<n { store.toggleStep(s) }
    #expect(store.goTo(.print))   // the rail, inside the grace
    try await Task.sleep(for: .milliseconds(400))
    #expect(store.phase == .kitReady && !store.advancePending)
}

@Test @MainActor func lastSceneGoesToTheEndAndThePlayStepReopensItUnchecked() async {
    let store = await storeAtFirstScene()
    let n = store.kit?.scenes.count ?? 0
    for _ in 0..<(n - 1) {
        await store.sceneDone()
        if case .handoff(let i) = store.phase, let owner = store.kit?.scenes[i].owner.role { store.badgeTapped(owner) }
    }
    #expect(store.phase == .scene(n - 1))
    await store.sceneDone()
    #expect(store.phase == .end && store.nutmegLine.hasSuffix(HandOffLines.end()))
    #expect(store.goTo(.play))
    #expect(store.phase == .scene(n - 1) && store.checkedSteps.isEmpty && store.nutmegLine == HandOffLines.backToChecklist)
}
