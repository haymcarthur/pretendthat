#if DEBUG
import Foundation
import AVFoundation
import QuartzCore
import UIKit
import NutmegCore

/// DEBUG only: `-PTDemo <phase>` launches straight into a phase with the bundled airplane game
/// (no network), so every screen can be screenshotted and reviewed quickly.
/// Phases: hello, pickGame, players, roles, props, kitReady, scene, scene2 (the second scene), end. Round 29:
/// `-PTPlayers N` sets the count (default 3); `sceneLong` is scene 1 with 6 players and long tasks.
enum DemoDriver {
    static var requestedPhase: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTDemo"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// Round D2: `-PTGrownUps holding|grid|list|confirm|deleteAll`: open the Grown-ups sheet at launch on that state
    /// (holding = the hold ring part filled, grid = the number question; list/confirm/deleteAll skip the gate).
    static var grownUps: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTGrownUps"), i + 1 < args.count else { return nil }
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

    /// Round 31: on-device recognition of every .wav in `dir` through the app's own capture (the same on-device
    /// request), as if each were held for its length then released. Logs what was heard, what would be sent (scrubbed)
    /// and release → words. Nothing is sent anywhere.
    @MainActor static func speechBench(dir: String) async {
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { $0.hasSuffix(".wav") }.sorted()
        rtLog("BENCH \(files.count) files, on-device supported: \(KidSpeechCapture.onDeviceSupported)")
        for f in files {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(f)
            let seconds = (try? AVAudioFile(forReading: url)).map { Double($0.length) / $0.fileFormat.sampleRate } ?? 1
            let capture = KidSpeechCapture()
            capture.debugUseFile(url)
            capture.begin(touchHost: CACurrentMediaTime())
            try? await Task.sleep(for: .seconds(seconds))
            let t0 = CACurrentMediaTime()
            let heard = await capture.finish()
            let ms = (CACurrentMediaTime() - t0) * 1000
            rtLog(String(format: "BENCH %@ | heard: \"%@\" | sent: \"%@\" | release→words %.0f ms", f, heard, NameScrubber.scrub(heard), ms))
        }
        rtLog("BENCH-END")
    }

    @MainActor static func live(_ model: AppModel, turns: [String]) async {
        // Round 13: "-PTLetsPlayAfter N": sit on the start screen N s (the socket pre-connects), then tap Let's play!.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-PTLetsPlayAfter"), i + 1 < args.count, let secs = Double(args[i + 1]) {
            model.preconnect()
            try? await Task.sleep(for: .seconds(secs))
        }
        // Round D1: "-PTStayHome": stay on the start screen (the socket pre-connects) for the My games / replay turns.
        // Round D3b: "-PTRecordCommon": record the bundled common lines in her real Realtime voice, then stop.
        if args.contains("-PTRecordCommon") { await model.debugRecordCommonLines(); rtLog("DRIVER-END"); return }
        if args.contains("-PTStayHome") { model.preconnect() } else { await model.startConversation() }
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
                for _ in 0..<1800 { if model.kitPapersOut { break }; try? await Task.sleep(for: .milliseconds(100)) }
                for _ in 0..<100 where !model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
                for _ in 0..<200 where model.realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            // Round 13 taps: "#found" / "#missing" (prop card buttons), "#play" (print step Let's play!). Round 29:
            // "#next" (the green ▶ Next scene), "#task N" (row N's 🔊). Timed like real taps.
            // Round 26: on a replay the same card buttons answer the replay's one-card hunt.
            // Round 31: "#speak /path/phrase.wav": a SPOKEN turn. The mic is pressed (the same talkPressed path), the
            // recorded phrase stands in for the mic audio for as long as it lasts, then the mic is released: on-device
            // words → name scrub → safety gate → one text item. "#bench /dir": on-device words for every .wav in a
            // folder (accuracy + release → words time), no session needed.
            if turn.hasPrefix("#speak ") {
                let url = URL(fileURLWithPath: String(turn.dropFirst(7)))
                let seconds = (try? AVAudioFile(forReading: url)).map { Double($0.length) / $0.fileFormat.sampleRate } ?? 1
                model.realtime.capture.debugUseFile(url)
                model.listener.capture.debugUseFile(url)
                model.talkPressed(touchHost: CACurrentMediaTime())
                try? await Task.sleep(for: .seconds(max(0.5, seconds)))
                model.talkReleased()
                try? await Task.sleep(for: .milliseconds(100))
                model.realtime.capture.debugUseFile(nil)
                model.listener.capture.debugUseFile(nil)
                continue
            }
            // Round 31: "#heard WORDS": a real press + hold + release on the live session, with WORDS standing in for the
            // on-device recognizer's output (the simulator's speech model can't load). Everything after the words is real.
            if turn.hasPrefix("#heard ") {
                let words = String(turn.dropFirst(7))
                model.realtime.capture.debugUseWords(words)
                model.talkPressed(touchHost: CACurrentMediaTime())
                try? await Task.sleep(for: .seconds(1.2))
                model.talkReleased()
                continue
            }
            if turn.hasPrefix("#bench ") { await speechBench(dir: String(turn.dropFirst(7))); continue }
            if turn == "#found" || turn == "#missing" {
                if model.store.isReplay { model.replayHunt(found: turn == "#found") } else { model.huntReply(found: turn == "#found") }
                continue
            }
            if turn == "#next" { model.realtime.beginTrace("next scene tap"); model.tapNextScene(); continue }
            if turn.hasPrefix("#task "), let n = Int(turn.dropFirst(6)) { model.readTask(n); continue }
            if turn == "#scene" {   // round 29: the current scene's rows (text only, for the log)
                if case .scene(let i) = model.store.phase, let sc = model.store.kit?.scenes[i] {
                    rtLog("SCENE \(i + 1) \"\(sc.title)\": \(sc.nutmegSays)")
                    for st in sc.steps { rtLog("SCENE \(i + 1) row \(st.role.rawValue): \(st.text)") }
                }
                continue
            }
            // Round 19: "#newgame" (the finale's New game: all the way home),
            // "#home" (the X close → Leave), "#sleep N" (a short pause in ms between fast taps).
            // Round 23: "#rail pick|props|paper|play" (a step-rail tap), "#chat" (dump the chat transcript to the log).
            if turn.hasPrefix("#rail "), let step = BackNav.toolSteps[String(turn.dropFirst(6))] { model.tapStepRail(step); continue }
            if turn == "#chat" {
                for (i, line) in model.realtime.transcript.enumerated() { rtLog("CHAT[\(i)] \(line.fromNutmeg ? "Nutmeg" : "Kid"): \(line.text)") }
                continue
            }
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
            // Round 16/17: "#repeat": the pill's Repeat (the whole scene again in play, else her last line again).
            if turn == "#repeat" { model.repeatTapped(); continue }
            // Guide prefetch: "#guide": wait until the play guide is final (Paper may already be out without it).
            if turn == "#guide" {
                for _ in 0..<1800 { if !(model.store.guidePending || model.store.kit?.scenes.isEmpty != false) { break }; try? await Task.sleep(for: .milliseconds(100)) }
                rtLog("guide: final (\(model.store.kit?.scenes.count ?? 0) scenes)")
                continue
            }
            if turn == "#scenes" {   // the kit's scene intro lines (round 13: each says "Pretend that")
                for (i, sc) in (model.store.kit?.scenes ?? []).enumerated() { rtLog("SCENE[\(i)] \(sc.nutmegSays)") }
                continue
            }
            // Round C1: "#checklist": every scene as the playing kids see it (who holds the iPad, each visible step's role).
            if turn == "#checklist" {
                let s = model.store
                rtLog("CHECKLIST players=\(s.playerCount) playing=\(s.playingRoles.map(\.roleName)) all=\(s.plan?.roles.map(\.roleName) ?? [])")
                for (i, sc) in (s.kit?.scenes ?? []).enumerated() {
                    let who = sc.owner.role.flatMap { s.plan?.role(for: $0)?.roleName } ?? "-"
                    rtLog("CHECKLIST[\(i)] holder=\(who) \(sc.title): " + sc.steps.map { "\($0.role.rawValue): \($0.text)" }.joined(separator: " | "))
                }
                let badges = model.kitPages.filter { $0.item.recipe == .badges }.flatMap(\.slots)
                rtLog("CHECKLIST badges=\(badges.compactMap(\.role)) slices=\(s.kit?.items.first { $0.recipe == .badges }.map { model.printArt.cutoutImages($0).compactMap { $0 }.count } ?? 0)")
                continue
            }
            if turn == "#play" { model.realtime.beginTrace("play tap"); model.tapLetsPlay(); continue }
            // Round D1 (saved games + replays): "#shot NAME" (the host script screenshots on this log line), "#saveGame"
            // (The End's star: save, then home), "#tohome" (Leave, and keep going), "#shelf" (Saved games), "#replay N"
            // (the Nth card), "#count N" (Pick's tile fallback; by voice say the number), "#found" / "#missing" (the card's
            // ✓ / ✗, a replay too), "#print" (the printer), "#dismissprint", "#calls MOMENT" (AI calls since the replay
            // started), "#playthrough" (every hand-off and every checklist step tapped, to The End; round 26: auto-advance).
            if turn.hasPrefix("#shot ") {
                rtLog("SHOT \(turn.dropFirst(6))")
                try? await Task.sleep(for: .seconds(1.2))   // let the screen settle
                saveShot(String(turn.dropFirst(6)))         // round 25: the app renders its own window (exact timing)
                try? await Task.sleep(for: .seconds(1.3)); continue
            }
            // Round 27: "#allart": wait (≤ 3 min) until both print sets and the cover have settled, then log it.
            if turn == "#allart" {
                for _ in 0..<1800 where !(model.colorArt.finished && model.outlineArt.finished && (model.coverArt.settledAt != nil || model.store.isReplay)) {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                rtLog("ART: color=\(model.colorArt.finished) outline=\(model.outlineArt.finished) cover=\(model.coverArt.image != nil) set=\(model.store.printSet.toolValue)")
                continue
            }
            if turn == "#saveGame" {
                model.tapSave()
                for _ in 0..<100 where model.store.savedAs == nil { try? await Task.sleep(for: .milliseconds(100)) }
                rtLog("SAVE: \(model.store.savedAs.map { "saved \($0)" } ?? "NOT saved (\(model.saveState))") shelf=\(model.shelfGames.count)")
                continue
            }
            if turn == "#tohome" {
                for (i, line) in model.realtime.transcript.enumerated() { rtLog("CHAT[\(i)] \(line.fromNutmeg ? "Nutmeg" : "Kid"): \(line.text)") }
                model.leave(); try? await Task.sleep(for: .seconds(2))
                rtLog("HOME: phase=\(model.store.phase) shelf=\(model.shelfGames.count) myGamesButton=\(!model.shelfGames.isEmpty)")
                continue
            }
            if turn == "#shelf" { model.openShelf(); try? await Task.sleep(for: .seconds(1)); continue }
            if turn.hasPrefix("#replay "), let n = Int(turn.dropFirst(8)), model.shelfGames.indices.contains(n) {
                model.tapSavedGame(model.shelfGames[n])
                for _ in 0..<150 where !(model.store.isReplay && (model.realtime.isLive || !model.hasRealtime || !model.network.online)) { try? await Task.sleep(for: .milliseconds(100)) }
                rtLog("REPLAY: phase=\(model.store.phase) live=\(model.realtime.isLive)")
                continue
            }
            if turn.hasPrefix("#count "), let n = Int(turn.dropFirst(7)) { model.replayPick(n); continue }
            if turn == "#print" { model.tapPrint(); try? await Task.sleep(for: .seconds(1.5)); continue }   // round 26: the printer button
            if turn == "#dismissprint" { UIPrintInteractionController.shared.dismiss(animated: true); try? await Task.sleep(for: .seconds(1)); continue }
            if turn.hasPrefix("#calls ") { model.logReplayCalls(String(turn.dropFirst(7))); continue }
            // Round D3b: "#offline" / "#online" (the in-app network switch), "#waitwifi" (until the Wi-Fi pause ends,
            // ≤ 60 s), "#clips" (the clip hit-rate log), "#waitclip" (until a clip has started playing, ≤ 5 s).
            if turn == "#offline" { model.network.debugOffline = true; try? await Task.sleep(for: .seconds(1)); continue }
            if turn == "#online" { model.network.debugOffline = false; continue }
            if turn == "#waitwifi" {
                let t0 = Date()
                for _ in 0..<600 where model.wifiPause.isPaused { try? await Task.sleep(for: .milliseconds(100)) }
                rtLog(String(format: "WIFI pause ended after %.1f s (paused=%@)", Date().timeIntervalSince(t0), model.wifiPause.isPaused ? "yes" : "no"))
                continue
            }
            if turn == "#clips" { model.logReplayClips("driver"); continue }
            if turn == "#waitclip" { for _ in 0..<50 where !model.speaker.clipPlaying { try? await Task.sleep(for: .milliseconds(100)) }; continue }
            // Round 25 (button audit): "#leavedialog" / "#stay" (the X's leave dialog on / off).
            if turn == "#leavedialog" { model.debugLeaveDialog = true; try? await Task.sleep(for: .seconds(1)); continue }
            if turn == "#stay" { model.debugLeaveDialog = false; try? await Task.sleep(for: .seconds(1)); continue }
            if turn == "#props" {
                rtLog("PROPS " + (model.store.props?.props.map { "\($0.id)=\($0.householdItem)\($0.isSkipped ? "(pretend)" : "")" }.joined(separator: ", ") ?? "-"))
                continue
            }
            if turn == "#playthrough" {
                for _ in 0..<12 {   // round 29: 3 scenes, everyone at once: let her read each scene, then ▶
                    for _ in 0..<600 where model.wifiPause.isPaused { try? await Task.sleep(for: .milliseconds(100)) }   // round D3b
                    for _ in 0..<50 where !model.realtime.isSpeaking && !model.wifiPause.isPaused { try? await Task.sleep(for: .milliseconds(100)) }
                    for _ in 0..<900 where model.realtime.isSpeaking || model.realtime.isBusy { try? await Task.sleep(for: .milliseconds(100)) }
                    try? await Task.sleep(for: .seconds(1))
                    guard case .scene(let i) = model.store.phase else { break }
                    rtLog("driver: next scene from \(i + 1)")
                    model.tapNextScene()
                    if model.store.phase == .end { break }
                }
                for _ in 0..<80 where model.realtime.isSpeaking || model.realtime.isBusy { try? await Task.sleep(for: .milliseconds(100)) }
                rtLog("PLAYTHROUGH: phase=\(model.store.phase)")
                continue
            }
            // Round 26: "#ifhunt TEXT": a typed (voice) turn only while a prop card is up (first play or replay), so a
            // script can say "found it" more times than there are props.
            if turn.hasPrefix("#ifhunt ") {
                guard model.store.huntActive || model.store.replayHuntActive else { rtLog("driver: (hunt over, skipped)"); continue }
                let said = String(turn.dropFirst(8))
                rtLog("driver: \(said)")
                if AppModel.isPlanning(model.store.phase) && !model.store.isReplay { await model.typed(said) } else { model.realtime.sendText(said) }
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
        rtLog("DRIVER-END")
    }

    /// Round 25 (button audit): renders the key window into tmp/shots/<name>.png (what the screen shows, at 2x).
    @MainActor static func saveShot(_ name: String) {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else { return }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? image.pngData()?.write(to: dir.appendingPathComponent("\(name).png"))
    }

    @MainActor static func drive(_ store: AdventureStore, model: AppModel, to target: String) async {
        if !target.hasPrefix("conv") { model.realtime.debugSeedTranscript(demoTranscript) }
        if target.hasPrefix("conv") { await conversation(store, model: model, to: target); return }
        if target == "seed2" { await seedGames(store, model: model); return }
        // Shelf fix (round 27 follow-up): `-PTDemo shelf` seeds 5 games (env PT_SEED_COUNT for more) (cover from env PT_SEED_COVER on every other
        // one, so both the cover and the fallback show) and opens the bookshelf (two shelves + a second page at 10+).
        if target == "shelf" || target == "seed5" {
            await seedGames(store, model: model, count: Int(ProcessInfo.processInfo.environment["PT_SEED_COUNT"] ?? "") ?? 5)
            if target == "shelf" { model.openShelf() }
            return
        }
        if target == "sceneLong" {   // round 14/29: 6 players, a 2-line title and 6 long tasks
            await drive(store, model: model, to: "scene")
            store.changePlayerCount(6)
            if var sc = store.fullKit?.scenes[0] {
                sc.title = "Sunset Closing Time at the Beach Café"
                let long = ["wipe every table until it sparkles, then stack the menus by the door",
                            "count your Sky Dollars and pay for one last snack from the menu",
                            "carry the snack cart to the kitchen and hand out the last cookie cut-outs",
                            "flip the sign to Closed and wave goodbye to every passenger at the gate",
                            "pack the snacks away and give the Captain a big thank-you high five",
                            "find your suitcase, show your boarding pass and line up for the last ride"]
                for k in 0..<6 { if let j = sc.steps.firstIndex(where: { $0.role.role?.index == k }) { sc.steps[j].text = long[k] } }
                store.debugReplaceScene(0, with: sc)
            }
            store.debugSetPhase(.scene(0))
            return
        }
        if target == "coloring" {   // the kit loader: Nutmeg coloring, clipboard back
            await drive(store, model: model, to: "props")
            store.debugSetPhase(.makingKit)
            return
        }
        _ = model
        let order = ["hello", "pickGame", "players", "roles", "props", "kitReady", "scene", "scene2", "end"]
        guard let stop = order.firstIndex(of: target), stop > 0 else { return }
        func reached(_ name: String) -> Bool { order.firstIndex(of: name)! >= stop }
        await store.start(); if reached("pickGame") { return }
        await store.chooseGame("Airplane")
        store.setPlayerCount(demoPlayers)
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
        if target == "scene" { return }
        store.nextScene()
        if target == "scene2" { return }
        while case .scene = store.phase { store.nextScene() }
    }

    /// Round 29: `-PTPlayers N` (1–6) for the demo phases (default 3).
    static var demoPlayers: Int {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTPlayers"), i + 1 < args.count, let n = Int(args[i + 1]) else { return 3 }
        return max(1, min(n, Players.max))
    }

    /// Round D2: `-PTDemo seed2`: plays the bundled airplane game to The End (no network), saves it twice under two
    /// titles (game content only, no art), then goes home: the start screen shows My games + Grown-ups.
    @MainActor static func seedGames(_ store: AdventureStore, model: AppModel, count: Int = 2) async {
        if model.savedGames.count < count {
            await drive(store, model: model, to: "end")
            let titles = ["Moon Crumbs Bakery", "Pirate Ship on the Moon", "Bug Theater", "Sky Airlines", "Pet Vet",
                          "Cozy Café", "Dino Dig", "Royal Ball", "Space Station", "Ice Cream Truck", "Treasure Island"]
            let coverData = ProcessInfo.processInfo.environment["PT_SEED_COVER"].flatMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) }
            for (i, title) in titles.prefix(count - model.savedGames.count).enumerated() {
                guard var g = store.savedGame(now: Date().addingTimeInterval(Double(i - 2) * 86_400), art: [],
                                              cover: nil) else { break }
                g.title = title
                try? model.savedGames.save(g, art: [:], cover: i.isMultiple(of: 2) ? coverData : nil)
            }
            model.leave()
        }
        model.refreshShelf()
        rtLog("SEED: shelf=\(model.shelfGames.count)")
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
        if target == "convConfirm" {   // round 19: the recap (round 26: voice only, no buttons)
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
