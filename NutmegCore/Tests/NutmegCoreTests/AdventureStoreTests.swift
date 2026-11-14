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
    #expect(store.plan?.roles.count == 3)
    #expect(store.usingFallback == false)
}

@Test @MainActor func fiveKidsGetFourRolesAndHandoffsByRole() async {
    let store = await storeWithKit(owners: [.R1, .R2, .R3, .R4], players: 5)
    #expect(store.playerCount == 5)
    #expect(store.plan?.roles.count == 4)
    #expect(store.plan?.kidCount == 5)
    #expect(store.plan?.roles.last?.count == 2)   // the extra kid shares the last role
    store.beginPlay()
    #expect(store.phase == .handoff(sceneIndex: 0))
    #expect(store.nutmegLine == "Pass the iPad to the Captain! Then tap I'm the Captain!")
}

@Test @MainActor func handoffLineUsesTheRoleNeverAName() async {
    let store = await storeWithKit(owners: [.R2, .R1, .all, .R1], players: 3)
    store.beginPlay()
    #expect(store.nutmegLine == "Pass the iPad to the Flight Attendant! Then tap I'm the Flight Attendant!")
}

@Test @MainActor func singlePlayerSkipsHandoff() async {
    let store = await storeWithKit(owners: [.R1, .all, .R1, .R1], players: 1)
    #expect(await walk(store).allSatisfy { if case .scene = $0 { true } else { false } })
}

@Test @MainActor func handoffOnlyWhenOwnerChanges() async {
    let store = await storeWithKit(owners: [.R1, .R1, .R2, .all, .R2], players: 2)
    #expect(await walk(store) == [.handoff(sceneIndex: 0), .scene(1), .handoff(sceneIndex: 2), .scene(3), .scene(4)])
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

@Test @MainActor func playerCountDecidesTheRoles() async {
    for n in 1...4 {
        let store = await storeWithKit(owners: [.all, .all, .all, .all], players: n)
        #expect(store.plan?.roles.count == n)
        #expect(store.plan?.roles.allSatisfy { $0.count == 1 } == true)
    }
}

@Test @MainActor func playAgainRestartsScenes() async {
    let store = await storeWithKit(owners: [.all, .all, .all, .all], players: 2)
    _ = await walk(store)
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

// MARK: Round 10: Done! auto-checks, goes straight to the hand-off; Back restores the checklist

@MainActor
func storeAtFirstScene() async -> AdventureStore {
    let store = await storeWithKit(owners: [.R1, .R2, .all, .R1], players: 3)
    store.autoCheckStep = .zero; store.autoCheckHold = .zero
    store.beginPlay()
    if case .handoff(let i) = store.phase, let owner = store.kit?.scenes[i].owner.role { store.badgeTapped(owner) }
    return store
}

@Test @MainActor func earlyDoneAutoChecksThenGoesToTheHandoff() async {
    let store = await storeAtFirstScene()
    #expect(store.phase == .scene(0))
    store.toggleStep(0)
    await store.sceneDone()
    #expect(store.phase == .handoff(sceneIndex: 1))
    #expect(store.checkedSteps.count == store.kit?.scenes[0].steps.count)
    #expect(store.doneSnapshot == .init(scene: 0, checked: [0]))
    #expect(store.canGoBackToChecklist)
}

@Test @MainActor func backRestoresTheChecklistExactly() async {
    let store = await storeAtFirstScene()
    store.toggleStep(1)
    await store.sceneDone()
    store.backToChecklist()
    #expect(store.phase == .scene(0))
    #expect(store.checkedSteps == [1])
    #expect(!store.canGoBackToChecklist)
    // Done again → hand-off again; the next role confirms → Back is gone.
    await store.sceneDone()
    guard case .handoff(let i) = store.phase, let owner = store.kit?.scenes[i].owner.role else { Issue.record("no hand-off"); return }
    store.badgeTapped(owner)
    #expect(store.phase == .scene(1) && store.checkedSteps.isEmpty && !store.canGoBackToChecklist)
}

@Test @MainActor func tappingACheckedStepUnchecksIt() async {
    let store = await storeAtFirstScene()
    store.toggleStep(0); store.toggleStep(0)
    #expect(store.checkedSteps.isEmpty)
}

@Test @MainActor func backWorksWithVoiceConfirmAfterwards() async {
    let store = await storeAtFirstScene()
    await store.sceneDone()
    store.backToChecklist()
    await store.sceneDone()
    let out = await store.apply(.confirmHandoff)
    #expect(out.contains("Hand-off confirmed"))
    #expect(store.phase == .scene(1))
}

@Test @MainActor func lastSceneDoneGoesToTheFinaleWithBack() async {
    let store = await storeAtFirstScene()
    let n = store.kit?.scenes.count ?? 0
    for _ in 0..<(n - 1) {
        await store.sceneDone()
        if case .handoff(let i) = store.phase, let owner = store.kit?.scenes[i].owner.role { store.badgeTapped(owner) }
    }
    #expect(store.phase == .scene(n - 1))
    await store.sceneDone()
    #expect(store.phase == .end && store.canGoBackToChecklist)
    store.backToChecklist()
    #expect(store.phase == .scene(n - 1))
}
