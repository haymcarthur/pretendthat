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

    /// Round 11: `-PTAutoStart`: the start screen taps "Let's play!" itself 1 s after the opening, and the conversation
    /// starts WITHOUT a voice session (forced conversation stage, no audio): frame strips of start → game.
    static var autoStart: Bool { ProcessInfo.processInfo.arguments.contains("-PTAutoStart") }
    /// Round 11: `-PTAutoPlay <seconds>` (with `-PTDemo kitReady`): taps "Let's play!" on the print step after that long.
    static var autoPlay: Double? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTAutoPlay"), i + 1 < args.count else { return nil }
        return Double(args[i + 1])
    }

    /// Round 11: `-PTKeyboard` (with `-PTChat`): focus the chat field so the keyboard comes up (stage audit screenshots).
    static var keyboard: Bool { ProcessInfo.processInfo.arguments.contains("-PTKeyboard") }

    /// `-PTWriting`: hold the writing moment (clipboardBoth, focus face, crayon top, writing close shot) for screenshots.
    static var forceWriting: Bool { ProcessInfo.processInfo.arguments.contains("-PTWriting") }

    /// Round 14: `-PTChatTabChat` (with `-PTChat`, in play): start on the panel's Chat tab instead of Checklist.
    static var chatTabChat: Bool { ProcessInfo.processInfo.arguments.contains("-PTChatTabChat") }

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
        // Round 13: "-PTLetsPlayAfter N": sit on the start screen N s (the socket pre-connects), then tap Let's play!.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-PTLetsPlayAfter"), i + 1 < args.count, let secs = Double(args[i + 1]) {
            model.preconnect()
            try? await Task.sleep(for: .seconds(secs))
        }
        await model.startConversation()
        for raw in turns {
            // Round 15: a leading "!" sends the turn right away (a quick tap while she's still talking).
            let quick = raw.hasPrefix("!")
            let turn = quick ? String(raw.dropFirst()) : raw
            if quick { try? await Task.sleep(for: .milliseconds(700)) } else {
            // Wait for Nutmeg to start and then finish her line.
            for _ in 0..<100 where !model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
            // ...and stay settled (no response, beat or reply pending) for 1.5 s: her chained tool responses finish first.
            var calm = 0
            for _ in 0..<600 where calm < 15 {
                try? await Task.sleep(for: .milliseconds(100))
                calm = model.realtime.isSpeaking || model.realtime.isBusy || model.beat != .none ? 0 : calm + 1
            }
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
            // Round 13 taps: "#found" / "#missing" (prop card buttons), "#play" (print step Let's play!), "#handoff"
            // (the hand-off card's I'm the ___! button). Timed like real taps.
            if turn == "#found" || turn == "#missing" { model.huntReply(found: turn == "#found"); continue }
            if turn == "#done" { await model.sceneDone(); continue }
            // Round 19: the confirm step's buttons.
            if turn == "#yes" { model.confirmYes(); continue }
            // Round 19: "#back" (Back to the checklist), "#newgame" (the finale's New game: all the way home),
            // "#home" (the X close → Leave), "#sleep N" (a short pause in ms between fast taps).
            if turn == "#back" { model.tapBackToChecklist(); continue }
            if turn == "#newgame" || turn == "#home" {
                for (i, line) in model.realtime.transcript.enumerated() { rtLog("CHAT[\(i)] \(line.fromNutmeg ? "Nutmeg" : "Kid"): \(line.text)") }
                if turn == "#newgame" { model.tapNewGame() } else { model.leave() }
                for t in 1...6 {
                    try? await Task.sleep(for: .milliseconds(500))
                    rtLog("HOME +\(Double(t) / 2) s: phase=\(model.store.phase) speaking=\(model.isSpeaking) status=\(model.realtime.status)")
                }
                return
            }
            if turn.hasPrefix("#sleep "), let ms = Int(turn.dropFirst(7)) { try? await Task.sleep(for: .milliseconds(ms)); continue }
            if turn == "#change" { model.confirmChange(); continue }
            // Round 15: "#check N": the kid checks step N of the current scene's checklist.
            if turn.hasPrefix("#check "), let n = Int(turn.dropFirst(7)) { model.checkStep(n); continue }
            // Round 16/17: "#repeat": the pill's Repeat (the checklist read-aloud in play, else her last line again).
            if turn == "#repeat" { model.repeatTapped(); continue }
            if turn == "#scenes" {   // the kit's scene intro lines (round 13: each says "Pretend that")
                for (i, sc) in (model.store.kit?.scenes ?? []).enumerated() { rtLog("SCENE[\(i)] \(sc.nutmegSays)") }
                continue
            }
            if turn == "#play" { model.realtime.beginTrace("play tap"); model.tapLetsPlay(); continue }
            if turn == "#handoff" {
                if case .handoff(let i) = model.store.phase, let t = model.store.kit?.scenes[i].owner.role {
                    model.realtime.beginTrace("handoff tap"); model.tapHandoff(t)
                }
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
        if target == "sceneLong" {   // round 14: a long Sunset-style checklist (2-line title, 6 long steps)
            await drive(store, model: model, to: "scene")
            if case .scene(let i) = store.phase, var sc = store.kit?.scenes[i] {
                let pics = sc.steps.map(\.picture)
                sc.title = "Sunset Closing Time at the Beach Café"
                sc.steps = ["Wipe every table until it sparkles", "Stack the cups and plates on the tray",
                            "Count the money in the cash register", "Flip the sign on the door to Closed",
                            "Turn off the lights one by one", "Wave goodbye to the very last customer"]
                    .enumerated().map { Step(picture: pics[$0.offset % max(1, pics.count)], text: $0.element) }
                store.debugReplaceScene(i, with: sc)
            }
            return
        }
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
        await store.confirmProps()
        if reached("kitReady") {
            if let wait = autoPlay { try? await Task.sleep(for: .seconds(wait)); store.beginPlay() }
            return
        }
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
        _ = await store.apply(.setTheme("Airplane to the Beach"))
        _ = await store.apply(.setPlayerCount(3))
        if target == "convConfirm" {   // round 19: the recap + Yes / Change buttons
            model.realtime.debugSeedTranscript([store.recapLine])
            return
        }
        _ = await store.apply(.confirmPlan)
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
