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

    /// `-PTShot closeUp|medium|wide`: hold the conversation camera on one shot (screenshots).
    static var forcedShot: PTCameraShot? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTShot"), i + 1 < args.count else { return nil }
        switch args[i + 1] { case "closeUp": return .closeUp; case "medium": return .medium; case "wide": return .wide; default: return nil }
    }

    /// `-PTStartAt <seconds>`: hold the start screen's opening sequence at that time (screenshots).
    static var startFreeze: Double? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTStartAt"), i + 1 < args.count else { return nil }
        return Double(args[i + 1])
    }

    /// `-PTChat`: open the chat panel at launch (screenshots).
    static var chatOpen: Bool { ProcessInfo.processInfo.arguments.contains("-PTChat") }

    /// `-PTState talking|listening|idle`: hold Nutmeg's state (close-up screenshots).
    static var forcedState: NutmegState? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTState"), i + 1 < args.count else { return nil }
        return NutmegState(rawValue: args[i + 1])
    }

    /// `-PTPreview <i>`: open the kit page preview on page i once the pages land (screenshots).
    static var previewPage: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTPreview"), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }

    /// `-PTLive [-PTSay "text"]...`: start the real voice conversation at launch and send typed turns
    /// (one per -PTSay, each after Nutmeg finishes talking). For live tests in the simulator.
    static var liveTurns: [String]? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-PTLive") else { return nil }
        return args.indices.filter { args[$0] == "-PTSay" && $0 + 1 < args.count }.map { args[$0 + 1] }
    }

    @MainActor static func live(_ model: AppModel, turns: [String]) async {
        await model.startConversation()
        for turn in turns {
            // Wait for Nutmeg to start and then finish her line.
            for _ in 0..<100 where !model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
            for _ in 0..<300 where model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
            try? await Task.sleep(for: .milliseconds(600))
            model.realtime.sendText(turn)
        }
    }

    @MainActor static func drive(_ store: AdventureStore, model: AppModel, to target: String) async {
        if target.hasPrefix("conv") { await conversation(store, model: model, to: target); return }
        if target == "coloring" {   // the kit loader: Nutmeg coloring, clipboard back
            await drive(store, model: model, to: "props")
            store.debugSetPhase(.makingKit)
            return
        }
        _ = model
        let order = ["hello", "pickGame", "players", "roles", "props", "kitReady", "handoff", "scene", "stepBack", "end"]
        guard let stop = order.firstIndex(of: target), stop > 0 else { return }
        func reached(_ name: String) -> Bool { order.firstIndex(of: name)! >= stop }
        await store.start(); if reached("pickGame") { return }
        await store.chooseGame("Airplane")
        store.setPlayerCount(3)
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
        if case .handoff(let i) = store.phase, let t = store.kit?.scenes[i].owner.role { store.badgeTapped(t) }
        store.toggleStep(0)
        if reached("scene") { return }
        store.sceneDone(); if reached("stepBack") { return }
        while case .stepBack = store.phase {
            store.nextScene()
            if case .handoff(let i) = store.phase, let t = store.kit?.scenes[i].owner.role { store.badgeTapped(t) }
            if case .scene = store.phase { store.sceneDone() }
        }
    }

    /// Conversation stage shots: convClose (close-up), convIdeas, convRoles, convProps.
    @MainActor static func conversation(_ store: AdventureStore, model: AppModel, to target: String) async {
        model.forceConversation = true
        store.beginConversation()
        if target == "convClose" { return }
        _ = await store.apply(.showGameIdeas([GameIdea(id: "a", title: "Airplane", emoji: "", pitch: "fly to the beach"),
                                              GameIdea(id: "b", title: "Cozy Café", emoji: "", pitch: "serve yummy snacks"),
                                              GameIdea(id: "c", title: "Pet Vet", emoji: "", pitch: "help sick puppies")]))
        if target == "convIdeas" { return }
        _ = await store.apply(.setGame("Airplane"))
        _ = await store.apply(.setPlayerCount(3))
        _ = await store.apply(.setRoles([.init(roleName: "Captain", job: "Fly the plane"),
                                         .init(roleName: "Flight Attendant", job: "Serve snacks"),
                                         .init(roleName: "Passenger", job: "Enjoy the trip")]))
        if target == "convRoles" { return }
        _ = await store.apply(.showProps([.init(itemID: "chair", becomes: "Plane seats", forRole: "all", alternates: ["cushion"]),
                                          .init(itemID: "plate", becomes: "Steering wheel", forRole: "Captain", alternates: ["bowl"]),
                                          .init(itemID: "tray", becomes: "Snack cart", forRole: "Flight Attendant", alternates: ["books"]),
                                          .init(itemID: "backpack", becomes: "Suitcase", forRole: "Passenger", alternates: ["bag"])]))
        if target == "convPropsEdit" {
            _ = await store.apply(.swapProp(oldID: "tray", newID: "books", becomes: "Snack cart"))
            _ = await store.apply(.skipProp("backpack"))
        }
    }
}
#endif
