#if DEBUG
import Foundation
import NutmegCore

/// DEBUG only: `-PTDemo <phase>` launches straight into a phase with the bundled airplane game
/// (no network), so every screen can be screenshotted and reviewed quickly.
/// Phases: hello, pickGame, players, roles, props, kitReady, handoff, scene, end; doneFlow (round 10: scene 0 with one step checked → early Done! after 3 s → hand-off → Back after 4 s more).
enum DemoDriver {
    static var requestedPhase: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTDemo"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// `-PTShot closeUp|medium|wide` (hunt = medium): hold the conversation camera on one shot (screenshots).
    static var forcedShot: PTCameraShot? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTShot"), i + 1 < args.count else { return nil }
        switch args[i + 1] { case "closeUp": return .closeUp; case "medium", "hunt": return .medium; case "wide": return .wide; default: return nil }
    }

    /// `-PTStartAt <seconds>`: hold the start screen's opening sequence at that time (screenshots).
    static var startFreeze: Double? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTStartAt"), i + 1 < args.count else { return nil }
        return Double(args[i + 1])
    }

    /// `-PTWriting`: hold the writing moment (clipboardBoth, focus face, crayon top, writing close shot) for screenshots.
    static var forceWriting: Bool { ProcessInfo.processInfo.arguments.contains("-PTWriting") }

    /// `-PTChat`: open the chat panel at launch (screenshots).
    static var chatOpen: Bool { ProcessInfo.processInfo.arguments.contains("-PTChat") }

    /// `-PTState talking|listening|idle`: hold Nutmeg's state (close-up screenshots).
    static var forcedState: NutmegState? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTState"), i + 1 < args.count else { return nil }
        return NutmegState(rawValue: args[i + 1])
    }

    /// `-PTPose idle|wave|point|celebrate|sit|coloring|clipboardBoth`: hold Nutmeg's body pose on the stage (head/neck close-ups).
    static var forcedPose: NutmegPose? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTPose"), i + 1 < args.count else { return nil }
        return NutmegPose(rawValue: args[i + 1])
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
            // ...and stay settled (no response, beat or reply pending) for 1.5 s: her chained tool responses finish first.
            var calm = 0
            for _ in 0..<600 where calm < 15 {
                try? await Task.sleep(for: .milliseconds(100))
                calm = model.realtime.isSpeaking || model.realtime.isBusy || model.beat != .none ? 0 : calm + 1
            }
            // "#wait N": stay quiet N seconds (checks the spoken-only silence reminder, round 7).
            rtLog("driver: \(turn)")
            if turn.hasPrefix("#wait "), let secs = Double(turn.dropFirst(6)) {
                try? await Task.sleep(for: .seconds(secs))
                for _ in 0..<100 where model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
                continue
            }
            // "#kit": wait for the whole kit to land (print step), then keep going (e.g. "Let's play!").
            if turn == "#kit" {
                for _ in 0..<1800 where !model.kitPapersOut { try? await Task.sleep(for: .milliseconds(100)) }
                for _ in 0..<100 where !model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
                for _ in 0..<200 where model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            guard model.store.phase != .makingKit else { rtLog("(kit being made, skipped: \(turn))"); continue }
            // Round 9: typed like the chat panel (wakes a sleepy Nutmeg first).
            if AppModel.isPlanning(model.store.phase) { await model.typed(turn) } else { model.realtime.sendText(turn) }
        }
        // Dump the chat panel's lines (what the kid sees), so live runs can show what's in the transcript.
        for _ in 0..<100 where !model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
        for _ in 0..<300 where model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
        try? await Task.sleep(for: .seconds(2))
        for (i, line) in model.realtime.transcript.enumerated() { rtLog("CHAT[\(i)] \(line.fromNutmeg ? "Nutmeg" : "Kid"): \(line.text)") }
    }

    @MainActor static func drive(_ store: AdventureStore, model: AppModel, to target: String) async {
        if !target.hasPrefix("conv") { model.realtime.debugSeedTranscript(demoTranscript) }
        if target.hasPrefix("conv") { await conversation(store, model: model, to: target); return }
        if target == "coloring" {   // the kit loader: Nutmeg coloring, clipboard back
            await drive(store, model: model, to: "props")
            store.debugSetPhase(.makingKit)
            return
        }
        _ = model
        let order = ["hello", "pickGame", "players", "roles", "props", "kitReady", "handoff", "scene", "doneFlow", "end"]
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
                case .scene: await store.sceneDone()
                default: return
                }
            }
        }
        if case .handoff(let i) = store.phase, let t = store.kit?.scenes[i].owner.role { store.badgeTapped(t) }
        store.toggleStep(0)
        if target == "scene" { return }
        if target == "doneFlow" {
            try? await Task.sleep(for: .seconds(3))
            await store.sceneDone()
            try? await Task.sleep(for: .seconds(4))
            store.backToChecklist()
            return
        }
        store.autoCheckStep = .zero; store.autoCheckHold = .zero
        while case .scene = store.phase {
            await store.sceneDone()
            if case .handoff(let i) = store.phase, let t = store.kit?.scenes[i].owner.role { store.badgeTapped(t) }
        }
    }

    static let demoTranscript = [
            "Hi! I'm Nutmeg! What should we pretend today?", "An airplane!",
            "Ooh, an airplane! How many friends are flying with us?", "Three!",
            "Three! We need a Captain, a Flight Attendant and a Passenger. Ready to find props?", "Yes!",
            "First, can you find a plate? It'll be the steering wheel! Say 'found it' or tell me if you don't have it.", "Found it!",
            "Yay! Next, can you find a chair? It'll be the plane seats!", "We don't have one.",
            "No problem, we'll pretend! Next, can you find a tray? It'll be the snack cart!"]


    /// Conversation stage shots: convClose (close-up), convIdeas, convRoles, convProps.
    @MainActor static func conversation(_ store: AdventureStore, model: AppModel, to target: String) async {
        model.forceConversation = true
        store.beginConversation()
        model.realtime.debugSeedTranscript(demoTranscript)
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
        if target == "convHuntLong" {   // round 6: the longest real description must show in full (never truncated)
            _ = await store.apply(.showNextProp(.init(itemID: "tray", becomes: "a serving tray for delivering orders across the restaurant", forRole: "all")))
            return
        }
        if target.hasPrefix("convHunt") {   // the one-at-a-time prop hunt: convHunt1, convHunt3 (2 done), convHuntLast
            let hunt: [(String, String)] = [("plate", "the steering wheel"), ("chair", "the plane seats"), ("tray", "the snack cart"), ("backpack", "a suitcase")]
            let upTo = target == "convHunt1" ? 1 : (target == "convHunt3" ? 3 : 4)
            for (i, p) in hunt.prefix(upTo).enumerated() {
                _ = await store.apply(.showNextProp(.init(itemID: p.0, becomes: p.1, forRole: "all")))
                if i < upTo - 1 { _ = await store.apply(i == 1 ? .skipProp(p.0) : .markFound(p.0)) }
            }
            return
        }
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
