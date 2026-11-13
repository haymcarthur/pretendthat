#if DEBUG
import Foundation
import NutmegCore

/// DEBUG only: `-PTDemo <phase>` launches straight into a phase with the bundled airplane game
/// (no network), so every screen can be screenshotted and reviewed quickly.
/// Phases: hello, pickGame, players, roles, props, kitReady, handoff, scene, stepBack, end.
enum DemoDriver {
    static var requestedPhase: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTDemo"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    @MainActor static func drive(_ store: AdventureStore, to target: String) async {
        let order = ["hello", "pickGame", "players", "roles", "props", "kitReady", "handoff", "scene", "stepBack", "end"]
        guard let stop = order.firstIndex(of: target), stop > 0 else { return }
        func reached(_ name: String) -> Bool { order.firstIndex(of: name)! >= stop }
        await store.start(); if reached("pickGame") { return }
        await store.chooseGame("Airplane")
        store.setPlayerCount(3)
        for (t, n) in zip(PlayerToken.allCases, ["Mia", "Sam", "Ollie"]) { store.setName(n, for: t) }
        if reached("players") { return }
        await store.confirmPlayers(); if reached("roles") { return }
        await store.confirmRoles()
        if let first = store.props?.props.first { store.toggleProp(first.id) }
        if reached("props") { return }
        await store.confirmProps(); if reached("kitReady") { return }
        store.beginPlay()
        if target == "handoff" {   // advance until someone has to pass the iPad
            while true {
                switch store.phase {
                case .handoff: return
                case .scene: store.sceneDone()
                case .stepBack: store.nextScene()
                default: return
                }
            }
        }
        if case .handoff(let i) = store.phase, let t = store.kit?.scenes[i].owner.token { store.badgeTapped(t) }
        store.toggleStep(0)
        if reached("scene") { return }
        store.sceneDone(); if reached("stepBack") { return }
        while case .stepBack = store.phase {
            store.nextScene()
            if case .handoff(let i) = store.phase, let t = store.kit?.scenes[i].owner.token { store.badgeTapped(t) }
            if case .scene = store.phase { store.sceneDone() }
        }
    }
}
#endif
