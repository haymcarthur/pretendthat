import SwiftUI
import NutmegCore

/// Wires the state machine to Nutmeg's voice, ears and kit art. One per app run; nothing is persisted.
@Observable @MainActor
final class AppModel {
    let store: AdventureStore
    let voice = NutmegVoice()
    let listener = Listener()
    let art: KitArtService
    let stickers: ItemArtService
    let hasClaude: Bool
    let hasImages: Bool
    /// Hands-free planning conversation (D1, D2) and its Grown-ups tuning (D7).
    let realtime = RealtimeSession()
    /// The writing moment's quiet scribble loop (round 5).
    @ObservationIgnored let scribble = ScribbleSound()
    let voiceSettings = VoiceSettings()
    @ObservationIgnored private let openAIKey: String?
    /// Only the IDs of last session's suggested games/themes (UserDefaults), so the next session differs. Nothing about kids.
    @ObservationIgnored private let suggestionMemory = SuggestionMemory()

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        let config = ClaudeConfig.from(info: info)
        hasClaude = config != nil
        var service = config.map { PhaseService(llm: ClaudeClient(config: $0)) }
        #if DEBUG
        if DemoDriver.requestedPhase != nil { service = nil }   // demo screens use the bundled game, no network
        #endif
        store = AdventureStore(service: service)
        var images = ImageClient.from(info: info)
        #if DEBUG
        // Demo screens skip paid image calls unless asked: -PTDemoArt 1
        if DemoDriver.requestedPhase != nil, !ProcessInfo.processInfo.arguments.contains("-PTDemoArt") { images = nil }
        #endif
        hasImages = images != nil
        art = KitArtService(client: images)
        stickers = ItemArtService(client: images)
        openAIKey = (info["OPENAI_API_KEY"] as? String).flatMap { k in
            let k = k.trimmingCharacters(in: .whitespaces); return k.isEmpty || k.hasPrefix("$(") ? nil : k
        }
        realtime.onTurnDone = { [weak self] text in
            guard let self, Self.isPlanning(self.store.phase), !self.realtime.propLinePending else { return nil }
            // Round 7: roles set but no prop yet → she continues straight into the first prop (no "Sound good?" wait).
            return TurnCheck.review(text, step: self.store.planningStep, rolesSet: self.store.plan != nil,
                                    propsShown: self.store.props?.props.count ?? 0, currentPropDone: self.store.currentPropDone)
        }
        realtime.onSilence = { [weak self] in
            guard let self, Self.isPlanning(self.store.phase), self.store.planningStep != .finish else { return nil }
            return TurnCheck.silenceLine   // spoken only, never in the chat (round 7)
        }
        realtime.onPlanningBeat = { [weak self] topic in await self?.planningBeat(topic) }
        realtime.onPropLine = { [weak self] in self?.revealFirstProp() ?? "" }
        // Tool-first kid turns (round 7): no narration is ever heard; she speaks after the tool result.
        realtime.onKidTurnTools = { [weak self] in
            guard let self, Self.isPlanning(self.store.phase) else { return nil }
            return Realtime.kidTurnTools(step: self.store.planningStep, huntActive: self.store.huntActive)
        }
        realtime.onPostPlanningTurn = { [weak self] in
            guard let self else { return nil }
            switch self.store.phase {
            case .kitReady:
                return "(Silent coaching, don't mention it.) The kit is ready on screen (print step). If they want to play, "
                    + "call start_play; if they want to print, call print_kit. Otherwise answer in ONE short line. No \"go play\" yet."
            case .handoff(let i):
                // Round 9: "I'm the Captain" by voice confirms the hand-off, same as tapping the card's button.
                let role = self.store.kit.flatMap { k in k.scenes.indices.contains(i) ? k.scenes[i].owner.role : nil }
                    .flatMap { self.store.plan?.role(for: $0)?.roleName } ?? "next player"
                return "(Silent coaching, don't mention it.) The iPad is being passed to the \(role). If the kid says they're "
                    + "the \(role) or that they've got the iPad, call confirm_handoff and say nothing. Otherwise answer in ONE "
                    + "short line (remind them to tap I'm the \(role)!)."
            case .scene, .end:
                return "(Silent coaching, don't mention it.) They're playing now. Answer in ONE short, fun line that helps the "
                    + "current scene. No tools."
            default: return nil
            }
        }
        // Round 9: a drop in the foreground (session time limit, network) reconnects silently with the current state.
        realtime.onDropped = { [weak self] in
            guard let self, self.store.phase != .hello else { return false }
            Task { await self.reconnectSilently() }
            return true
        }
        realtime.onCall = { [weak self] name, args in
            guard let self else { return ("ok", true) }
            return await self.handleCall(name: name, arguments: args)
        }
    }

    // MARK: Voice conversation

    var hasRealtime: Bool { openAIKey != nil }
    /// Round 11: the game opens on the talking close-up (voice conversation), so the start screen's exit pushes its
    /// camera there. Without voice the tap screens take over from the arrival framing.
    var opensInCloseUp: Bool {
        #if DEBUG
        if DemoDriver.autoStart { return true }
        #endif
        return hasRealtime
    }

    /// Grown-ups: hear `voice` say the sample line through the conversation's audio path and pitch settings.
    func auditionVoice(_ voice: String) async {
        guard let key = openAIKey else { return }
        realtime.dropPrepared()   // its voice may change; the start screen pre-connects again afterwards
        var c = voiceConfig; c.voice = voice
        await realtime.audition(apiKey: key, config: c)
    }

    /// Round 13: Nutmeg's voice for every connect (first, pre-connect, reconnect, audition), from the Grown-ups settings.
    var voiceConfig: VoiceConfig {
        VoiceConfig(voice: voiceSettings.voice, method: voiceSettings.method, rate: voiceSettings.rate,
                    cents: voiceSettings.pitchCents, requestedSpeed: voiceSettings.speed)
    }
    /// The voice this game's conversation started with: a silent reconnect uses exactly this one.
    @ObservationIgnored private var gameVoice: VoiceConfig?

    /// Round 13: while the start screen shows, open the Realtime socket with today's ideas, so "Let's play!" only
    /// starts the audio and the greeting.
    func preconnect() {
        #if DEBUG
        if DemoDriver.autoStart || DemoDriver.requestedPhase != nil { return }
        #endif
        guard let key = openAIKey, store.phase == .hello else { return }
        if preparedGames.isEmpty { preparedGames = suggestionMemory.pickGames() }
        realtime.preconnect(apiKey: key, config: voiceConfig, instructions: Realtime.instructions(todayGames: preparedGames))
    }
    @ObservationIgnored private var preparedGames: [Suggestion] = []
    /// DEBUG screenshots: show the conversation stage without a live session.
    var forceConversation = false

    /// The planning phases run as a voice conversation while the Realtime session is up.
    var inConversation: Bool {
        if forceConversation { return Self.isPlanning(store.phase) }
        guard realtime.status == .live || realtime.status == .connecting else { return false }
        return Self.isPlanning(store.phase)
    }

    static func isPlanning(_ phase: Phase) -> Bool {
        switch phase { case .pickGame, .players, .props: true; default: false }
    }

    /// "Let's play!": start the conversation; if Realtime can't connect, fall back to the tap screens.
    func startConversation() async {
        #if DEBUG
        if DemoDriver.autoStart { forceConversation = true; store.beginConversation(); return }   // frame strips: no voice
        #endif
        realtime.beginTrace("let's play")
        store.beginConversation()
        guard let key = openAIKey else { await store.start(); return }
        // Fresh suggestions every session (round 7): 3 games picked now (never last session's), injected as today's ideas.
        // Round 13: the start screen already picked them for the pre-connected socket.
        let games = preparedGames.isEmpty ? suggestionMemory.pickGames() : preparedGames
        preparedGames = []
        todayGames = games
        #if DEBUG
        rtLog("today's games: \(games.map(\.id).joined(separator: ", "))")
        #endif
        let config = voiceConfig
        gameVoice = config
        let ok = await realtime.connect(apiKey: key, config: config, echoCancel: voiceSettings.echoCancel,
                                        instructions: Realtime.instructions(todayGames: games))
        guard store.phase == .pickGame else { return }   // left while connecting
        if ok {
            realtime.micWanted = true
            gesture(.wave)
            realtime.kickOff(games: games)
            startDozeWatch()
        } else {
            await store.start()   // tap screens (and the bundled airplane game if Claude is off too)
        }
    }

    /// Leave activity: hang up and go home. Nothing is kept.
    func leave() {
        realtime.disconnect()
        gameVoice = nil
        kitReadySaid = false; deferredLine = nil; doze.wake(); dozeStage = .awake; wokePop = false; endKitBackgroundTask()
        shownProps = 0; beat = .none; kitBeatTask?.cancel(); kitBeat = .coloring; kitWriting = false; kitWritingTask?.cancel(); kitWritingTask = nil
        voice.stop()
        art.reset()
        stickers.reset()
        store.newGame()
    }

    /// Typed fallback goes into the live conversation when there is one.
    func typed(_ text: String) async {
        wakeUp()
        if realtime.isLive && Self.isPlanning(store.phase) { realtime.sendText(text); return }
        if realtime.isLive && store.phase != .makingKit { realtime.sendText(text); return }   // print step, play
        // Kit being made (round 7): a tiny "Almost ready!" at most, never a new conversation turn.
        if realtime.isLive && store.phase == .makingKit { if !realtime.isSpeaking { realtime.say("Almost ready!") }; return }
        await handleSpeech(text)
    }

    func phaseChanged() {
        // Round 7 (Haylee): the mic only looks disabled while connecting. Kit making: pressable, "Almost ready!" at most.
        realtime.micWanted = true
        realtime.quickReplyOnly = store.phase == .makingKit
        if store.phase == .makingKit { startKitProgress() } else if store.phase != .kitReady { kitWait?.cancel() }
        // (A fast kit can skip straight to kitReady between two observations; it still gets its writing beat.)
        if (store.phase == .makingKit || store.phase == .kitReady) && kitBeat == .coloring && !kitWriting && kitWritingTask == nil {
            startKitWriting()
        }
        if !(store.phase == .makingKit || store.phase == .kitReady) { kitWritingTask?.cancel(); kitWritingTask = nil; kitWriting = false }
    }

    /// Kit writing (round 5): once she has finished saying she's making the kit, she writes on her clipboard until the
    /// whole kit is final (at least `PoseRules.minKitWriting`).
    private(set) var kitWriting = false
    @ObservationIgnored private var kitWritingSince = Date.distantPast
    @ObservationIgnored private var kitWritingTask: Task<Void, Never>?
    private func startKitWriting() {
        kitWritingTask?.cancel()
        kitWritingTask = Task { @MainActor in
            for _ in 0..<120 where isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // her line first (≤ 6 s)
            guard !Task.isCancelled, store.phase == .makingKit || store.phase == .kitReady, kitBeat == .coloring else {
                kitWritingTask = nil; return
            }
            kitWritingSince = Date()
            kitWriting = true
            kitWritingTask = nil
        }
    }

    /// Kit art runs in its own task, NOT tied to the kit screen's lifetime: a `.task` on the view was cancelled
    /// as soon as the kids tapped "Let's play!" (or the stage re-rendered), which cancelled every image request
    /// and left the pages app-drawn.
    func kitChanged() {
        guard let kit = store.kit else { return }
        let title = store.plan?.gameTitle ?? store.gameTitle ?? "Pretend"
        Task { await art.generate(kit: kit, gameTitle: title) }
    }

    /// Round 7: light progress commentary while the kit is being made (KitProgress): every ~13 s, about a page still
    /// being drawn, at most 4, never repeated; stops as soon as the whole kit has landed.
    /// Round 15 (Haylee: the kit line was always the same): a random line from a bigger pool (KitProgress.lines), never
    /// repeated this session, and only about something really being made at that moment.
    private func startKitProgress() {
        kitWait?.cancel()
        kitWait = Task { @MainActor in
            var said = 0
            var lastTopic: KitProgress.Topic?
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(KitProgress.interval))
                guard !Task.isCancelled, store.phase == .makingKit || store.phase == .kitReady, !kitFinal else { return }
                if isSpeaking || (realtime.isLive && realtime.voiceBusy) { continue }
                // While the kit's content is being written, every page and the play guide are in progress; then only
                // the pages whose art is still being drawn.
                let pending = (store.kit?.items ?? []).filter { item in
                    item.recipe == .cutouts ? art.cutoutImages(item).contains { $0 == nil } : art.images[item.id] == nil
                }.compactMap(\.recipe)
                let topics = KitProgress.inProgress(kitWritten: store.kit != nil, pendingPages: pending)
                guard said < KitProgress.maxLines else { return }
                guard let pick = KitProgress.next(inProgress: topics, saidThisKit: said, lastTopic: lastTopic,
                                                  deck: &lineDeck, using: &rng) else { continue }   // keep waiting
                rtLog("kit progress (\(pick.topic.rawValue)): \(pick.line)")
                said += 1; lastTopic = pick.topic
                speak(pick.line)
            }
        }
    }
    /// Round 15: one deck for the whole app session, so random lines never repeat until a pool is used up.
    @ObservationIgnored var lineDeck = LineDeck()
    @ObservationIgnored var rng = SystemRandomNumberGenerator()

    // MARK: Checklist cheers (round 15, Haylee)

    /// A checklist row was tapped: check/uncheck it, then (checked) ONE short varied cheer + the next step, or the
    /// overall congratulations when the list is complete. Quick taps never overlap: a pending cheer is replaced by
    /// the newest one (it waits a moment, and for anything she's saying to finish).
    func checkStep(_ index: Int) {
        guard case .scene(let i) = store.phase, let scene = store.kit?.scenes[i], !store.autoChecking else { return }
        store.toggleStep(index)
        cheerTask?.cancel(); cheerTask = nil
        let steps = scene.steps.map(\.text)
        guard store.checkedSteps.contains(index) else { return }   // an uncheck says nothing
        cheerTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))   // a quick second tap replaces this one
            for _ in 0..<160 where (realtime.isLive ? realtime.voiceBusy : isSpeaking) && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))   // never over another line (≤ 8 s)
            }
            guard !Task.isCancelled, case .scene(i) = store.phase, !store.autoChecking,
                  store.checkedSteps.contains(index) else { return }
            guard let line = ChecklistCheers.afterCheck(index: index, steps: steps, checked: store.checkedSteps,
                                                        deck: &lineDeck, using: &rng) else { return }
            if store.checkedSteps.count == steps.count { congratulatedScene = i }
            cheerTask = nil
            rtLog("checklist cheer: \(line)")
            if realtime.isLive { realtime.say(line) } else { speak(line) }
        }
    }
    @ObservationIgnored private var cheerTask: Task<Void, Never>?
    /// The scene whose overall congratulations has been said (the last step checked normally).
    @ObservationIgnored private var congratulatedScene: Int?

    /// "Done!": a pending step cheer is dropped; if the list wasn't finished (Done! checks the rest) or its
    /// congratulations hasn't been said yet, ONE overall congratulations starts the next line (hand-off, scene, end).
    func sceneDone() async {
        guard case .scene(let i) = store.phase, !store.autoChecking else { return }
        cheerTask?.cancel(); cheerTask = nil
        if congratulatedScene != i {
            store.sceneLeadIn = ChecklistCheers.finished(deck: &lineDeck, using: &rng)
        }
        congratulatedScene = nil
        await store.sceneDone()
    }
    @ObservationIgnored private var kitWait: Task<Void, Never>?

    /// Kit step beats (no-text-overlays.md, fix round 2): she colors in the close-up until the WHOLE kit is final, then
    /// looks up (crayon down), the camera zooms out, and the papers fly off her clipboard.
    private(set) var kitBeat: PTStageDirector.KitBeat = .coloring
    @ObservationIgnored private var kitBeatTask: Task<Void, Never>?
    /// The printable pages for the current kit.
    var kitPages: [KitPage] {
        guard let kit = store.kit else { return [] }
        return KitLayout.pages(for: kit, roles: store.plan?.roles ?? [], playerCount: store.playerCount)
    }
    /// Print (single tap, decisions/2026-11-13-single-tap-print.md): the whole kit as one PDF to the iOS print screen.
    func printKit() {
        let pdf = KitPrinter.pdf(pages: kitPages, art: art.images,
                                 cutouts: Dictionary(uniqueKeysWithValues: (store.kit?.items ?? []).map { ($0.id, art.cutoutImages($0)) }))
        KitPrinter.print(pdf, jobName: "PretendThat \(store.plan?.gameTitle ?? "kit")")
    }
    /// The papers are out (kit final, she looked up, the camera zoomed out).
    var kitPapersOut: Bool { kitFinal && kitBeat == .papers }

    /// Every page's art has landed or definitively fallen back.
    var kitFinal: Bool { store.phase == .kitReady && store.kit != nil && art.finished }
    func kitFinalChanged(_ final: Bool) {
        #if DEBUG
        // `-PTPDFOut`: write the print-path PDF (exactly what AirPrint gets) to tmp/kit.pdf once the kit is final.
        if final, ProcessInfo.processInfo.arguments.contains("-PTPDFOut") {
            let pdf = KitPrinter.pdf(pages: kitPages, art: art.images,
                                     cutouts: Dictionary(uniqueKeysWithValues: (store.kit?.items ?? []).map { ($0.id, art.cutoutImages($0)) }))
            try? pdf.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("kit.pdf"))
        }
        #endif
        kitBeatTask?.cancel()
        if final { endKitBackgroundTask() }
        guard final else { kitBeat = .coloring; return }
        kitBeatTask = Task { @MainActor in
            // Writing never reads as a flicker: at least minKitWriting on the clipboard, even for an instant kit.
            for _ in 0..<100 where !kitWriting && (store.phase == .makingKit || store.phase == .kitReady) && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))   // her "making your kit" line, then the writing (≤ 10 s)
            }
            let left = PoseRules.minKitWriting - Date().timeIntervalSince(kitWritingSince)
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            guard !Task.isCancelled else { return }
            kitWriting = false
            kitBeat = .lookUp                                   // eyes up (happy), crayon drops out of frame
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            kitBeat = .papers                                   // zoom out; the papers fly once the camera settles
            // Round 7: the ready line only now that the whole kit exists; about printing, never "go play".
            // Round 9: exactly once, even across a lock/background (deferred until the session is back).
            guard !kitReadySaid else { return }
            kitReadySaid = true
            speak(AdventureStore.kitReadyLine, deferIfAway: true)
        }
    }

    private func handleCall(name: String, arguments: String) async -> (output: String, respond: Bool) {
        guard let call = PlanningCall.decode(name: name, arguments: arguments) else {
            return ("I couldn't use that. Try again with the right fields.", true)
        }
        let before = realtime.responseSerial
        if case .printKit = call {
            guard store.phase == .kitReady || kitFinal else { return ("Not yet: the kit isn't ready. Say only \"Almost ready!\"", true) }
            printKit()
        }
        if case .setGame = call {
            // Theme ideas for this game (round 7): 3 twists, never last time's; delivered in the set_game result.
            store.themeIdeas = suggestionMemory.pickTwists()
            #if DEBUG
            rtLog("today's themes: \(store.themeIdeas.map(\.id).joined(separator: ", "))")
            #endif
        }
        // Round 13: the text-only hunt pass sometimes moves straight to the next prop without mark_found (seen live:
        // "We found it!" → show_next_prop only). Moving on from an open card means it was found: check it off first.
        if case .showNextProp = call, store.huntActive, let cur = store.currentPropID, !store.foundProps.contains(cur),
           store.props?.props.first(where: { $0.id == cur })?.isSkipped == false {
            _ = await store.apply(.markFound(cur))
            rtLog("hunt: show_next_prop without mark_found: \(cur) checked off")
        }
        // Round 15: the skip's reassurance goes with the next prop card; only a hunt that ends right after the skip
        // (finish_planning) uses it as the kit line's lead-in (live run: it was said twice).
        if case .showNextProp = call { store.kitLeadIn = nil }
        let output = await store.apply(call)
        realtime.huntMode = store.huntActive
        if case .showNextProp = call {
            if realtime.isLive && (store.props?.props.count ?? 0) == 1 && shownProps == 0 {
                // First prop (round 7): she says the roles first; the card waits for that line to finish + 1 s.
                realtime.holdFirstPropLine()
            } else {
                revealProps(after: before)
            }
        }
        if store.props == nil { shownProps = 0 }
        // finish_planning and start_play end her turn: the app speaks the kit and scene lines.
        return (output, call != .finishPlanning && call != .startPlay && call != .confirmHandoff)
    }

    /// Nutmeg's on-screen state, derived from everything that's happening.
    var nutmegState: NutmegState {
        #if DEBUG
        if let s = DemoDriver.forcedState { return s }
        #endif
        // Sleepy Nutmeg (round 9): sit → droop → asleep; a happy pop when woken.
        if wokePop { return .excited }
        switch dozeStage { case .sitting: return .sitting; case .drowsy: return .drowsy; case .asleep: return .asleep; case .awake: break }
        // Writing moment (round 5): focus face (eyes down at the clipboard) while she writes; she looks up happy after.
        if isWriting { return .coloring }
        if beat == .lookUp { return .idle }
        if store.phase == .makingKit || store.phase == .kitReady {
            switch kitBeat { case .coloring: return realtime.isSpeaking ? .idle : .thinking; case .lookUp: return .excited; case .papers: break }
        }
        if realtime.isLive {
            // Conversation faces (decisions/conversation-camera-and-expressions.md): listening while the kid talks,
            // thinking in the gap before her reply, then the face the model chose (its eyes; the live mouth
            // animates on top), happy by default.
            if realtime.kidIsTalking { return .listening }
            if let e = realtime.expression { return Self.state(for: e) }
            if realtime.thinkingGap { return .thinking }
            if realtime.isSpeaking { return .idle }
        }
        if listener.isListening { return .listening }
        // Kit: she colors until every page is final (the papers wait for it, no-text-overlays.md).
        if store.isWorking { return .thinking }
        if voice.isSpeaking { return .talking }
        if store.lastError != nil { return .oops }
        switch store.phase {
        case .makingKit: return .thinking
        case .kitReady, .end: return .excited
        default: return .idle
        }
    }

    /// Kit step (round 3): she holds the clipboard in front with both hands from "let me make your pages" until the
    /// whole kit is final, then pops back to idle (excited) for the paper reveal.
    var nutmegHoldsClipboard: Bool { PoseRules.holdsClipboard(phase: store.phase, kitBeat: kitBeat) || beat != .none }
    /// The writing moment is on (planning beat or the kit being made): clipboardBoth, focus face, crayon top, scribble.
    var isWriting: Bool {
        #if DEBUG
        if DemoDriver.forceWriting { return true }
        #endif
        return PoseRules.isWriting(phase: store.phase, planningBeat: beat == .writing, kitWriting: kitWriting)
    }
    /// The resting body pose on the stage (the camera's face focus follows it).
    var nutmegRestPose: NutmegPose { nutmegState.basePose(holdingClipboard: nutmegHoldsClipboard) }

    /// Planning beat (round 5 writing moment): she writes on her clipboard, then looks up and announces the plan.
    enum Beat { case none, writing, lookUp }
    private(set) var beat: Beat = .none

    /// Her lead-in (if any) finishes, she writes with her eyes down for ~1.8–2.6 s, looks up happy (crayon drops out of
    /// frame, the camera returns to the normal shot), and only then does the function result go back so she announces it.
    func planningBeat(_ topic: String) async {
        for _ in 0..<80 where realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // lead-in done
        beat = .writing
        let base = topic == "roles" ? 2.3 : PoseRules.minPlanningBeat
        try? await Task.sleep(for: .seconds(Double.random(in: base...(base + 0.6))))
        // Round 7: ONE continuous writing state. The beat's result goes back now (set_roles → show_next_prop run
        // silently), but she keeps writing until her roles line actually starts playing; only then does she look up.
        beatEndTask?.cancel()
        beatEndTask = Task { @MainActor in
            for _ in 0..<240 where !realtime.isSpeaking && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }   // ≤ 12 s
            guard !Task.isCancelled else { return }
            beat = .lookUp
            try? await Task.sleep(for: .milliseconds(550))
            beat = .none
        }
    }
    @ObservationIgnored private var beatEndTask: Task<Void, Never>?

    /// Prop cards on stage. A new card waits until the turn that was playing when it was requested has finished (never
    /// mid-sentence about the roles): it appears with her prop line, or once playback drains.
    private(set) var shownProps = 0
    /// Without a live session (demo screenshots, tap fallback) every card shows at once.
    var visibleProps: Int { realtime.isLive ? shownProps : (store.props?.props.count ?? 0) }
    private func revealProps(after serial: Int) {
        Task { @MainActor in
            // A new prop card waits for the writing beat too: it appears as she looks up and announces it.
            while beat != .none || (realtime.isSpeaking && realtime.audioResponseSerial <= serial) { try? await Task.sleep(for: .milliseconds(50)) }
            let n = store.props?.props.count ?? 0
            if n > shownProps { shownProps = n; pointAtCard() }   // the card appears as her prop line starts
        }
    }

    /// The roles line finished playing (+1 s): show the first card, point at it, and return the note for her prop line.
    private func revealFirstProp() -> String {
        shownProps = store.props?.props.count ?? 0
        pointAtCard()
        let p = store.props?.props.first
        return AdventureStore.firstPropLine(item: p?.householdItem ?? "prop", becomes: p?.becomes ?? "something fun")
    }

    /// Backup buttons on the current prop card (noisy rooms): the one planning tap.
    /// Round 13 (Haylee: taps felt slow): the card changes AT ONCE (local state first), then her line follows. No
    /// tool-first pass for what the app already knows: a swap she just says (one response); after a check-off or a
    /// skip only the next prop is hers to pick (a cheap text-only pass, then her line).
    func huntReply(found: Bool) {
        guard realtime.isLive, let p = store.props?.props.first(where: { $0.id == store.currentPropID }) else { return }
        let name = p.householdItem.lowercased()
        let count = store.props?.props.count ?? 0
        let next = count >= 3 ? ["show_next_prop", "finish_planning"] : ["show_next_prop"]
        let then = count >= 3 ? "call show_next_prop for the next prop (or finish_planning if that's enough props)" : "call show_next_prop for the next prop"
        Task { @MainActor in
            if found {
                _ = await store.apply(.markFound(p.id))
                realtime.tapTurn(kidLine: "We found the \(name)!",
                                 note: "(Silent coaching, don't mention it.) The kids tapped Found it: the \(name) is ALREADY checked off "
                                    + "on screen (don't call mark_found). Say nothing yet: \(then) FIRST, then cheer in a few words and ask "
                                    + "about the new prop in the same turn. Never narrate.",
                                 requiring: next)
            } else if !p.isSkipped, !(p.swapped ?? false), let alt = p.alternates?.first(where: { PropLibrary.contains($0) }) {
                _ = await store.apply(.swapProp(oldID: p.id, newID: alt, becomes: ""))
                let altName = (PropLibrary.name(alt) ?? alt).lowercased()
                realtime.tapTurn(kidLine: "We don't have a \(name).",
                                 note: "(Silent coaching, don't mention it.) The kids tapped Don't have it. The card ALREADY changed to "
                                    + "a \(altName) (it'll still be \(p.becomes)). No tools: in ONE short turn say a \(altName) works too and ask "
                                    + "if they can find one.",
                                 requiring: nil)
            } else {
                // Round 15 (Haylee: the second "Don't have it" moved the card aside in silence): she reassures them out
                // loud ("That's okay, we'll just pretend that...") with the next prop, in ONE reply. If the hunt ends
                // right here (finish_planning), the app's "making your kit" line starts with the reassurance instead.
                _ = await store.apply(.skipProp(p.id))
                store.kitLeadIn = (PropSkip.reassurance(item: p.householdItem, becomes: p.becomes, deck: &lineDeck, using: &rng), Date())
                realtime.tapTurn(kidLine: "We don't have a \(name).",
                                 note: PropSkip.note(item: p.householdItem, becomes: p.becomes, then: then),
                                 requiring: next)
            }
            realtime.huntMode = store.huntActive
        }
    }

    static func state(for e: NutmegExpression) -> NutmegState {
        switch e {
        case .happy: .idle
        case .excited: .excited
        case .ooh: .amazed
        case .thinking: .thinking
        case .listening: .listening
        case .oops: .oops
        }
    }

    /// One-shot body gesture (wave, point, celebrate). Poses rest on idle otherwise.
    var cue: NutmegCue?
    /// Bumped on celebration moments; stage props bounce once.
    var celebrations = 0
    func gesture(_ g: NutmegGesture, hold: TimeInterval? = nil) { cue = NutmegCue(gesture: g, hold: hold) }

    /// Round 7 choreography: the card appears and she points; the point holds through her prop line (until it has
    /// finished playing) plus a few seconds, then she rests.
    @ObservationIgnored private var pointTask: Task<Void, Never>?
    func pointAtCard() {
        gesture(.point, hold: 60)
        pointTask?.cancel()
        pointTask = Task { @MainActor in
            for _ in 0..<160 where !realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // her line starts (≤ 8 s)
            while realtime.isSpeaking && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            gesture(.point, hold: 0)   // release
        }
    }

    /// Nutmeg's voice for app-written lines. With a live Realtime session she keeps her conversation voice;
    /// during planning she speaks for herself, so app lines are skipped there.
    func speak(_ text: String, deferIfAway: Bool = false) {
        // Round 9: away (background, or reconnecting): an important line (kit ready) waits for the session; others drop.
        if realtime.suspended || (realtime.status == .connecting && Self.wasLive(store.phase)) || resuming {
            if deferIfAway { deferredLine = text; rtLog("line deferred until the session is back") }
            return
        }
        if realtime.isLive {
            if !Self.isPlanning(store.phase) {
                // Round 13: a scene / hand-off line follows a kid's tap: the thinking state shows until it plays.
                let tapped: Bool = { switch store.phase { case .handoff, .scene, .end: true; default: false } }()
                realtime.say(text, thinking: tapped)
            }
            return
        }
        // Round 13: every line in her ONE Realtime voice. A session that dropped comes back (silent reconnect) and the
        // line waits for it; the device voice is only for a run with no Realtime at all.
        if hasRealtime && gameVoice != nil && Self.wasLive(store.phase) {
            deferredLine = text
            rtLog("line deferred: session not live (\(realtime.status)), reconnecting")
            Task { await reconnectSilently() }
            return
        }
        rtLog("AVSpeech fallback (no Realtime session): \(text.prefix(40))")
        Task { await voice.say(text) }
    }

    // MARK: Sleepy Nutmeg (round 9, Haylee)

    @ObservationIgnored private var doze = DozeClock()
    private(set) var dozeStage: DozeClock.Stage = .awake
    /// The quick happy pop back to idle after she's woken.
    private(set) var wokePop = false
    @ObservationIgnored private var lastReminder: Date?
    @ObservationIgnored private var dozeTask: Task<Void, Never>?

    /// Watches the quiet after the one silence reminder during the conversation steps (twice a second; cheap).
    private func startDozeWatch() {
        guard dozeTask == nil else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTDozeFast") { doze.scale = 0.15 }   // 30 s → 4.5 s
        #endif
        dozeTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.dozeTick()
            }
        }
    }

    private func dozeTick() {
        // Away or reconnecting: hold her as she is (no stand-up flicker while the session comes back).
        if realtime.suspended || resuming || realtime.status == .connecting { return }
        if let at = realtime.reminderDoneAt, at != lastReminder { lastReminder = at; doze.reminderFinished(at: at) }
        let eligible = realtime.isLive && !realtime.suspended && Self.isPlanning(store.phase)
            && DozeClock.sleepyStep(store.planningStep) && !isWriting && beat == .none && !realtime.isSpeaking
            && !realtime.kidIsTalking && !realtime.isBusy && !realtime.propLinePending
        let stage = doze.stage(at: Date(), eligible: eligible)
        if stage != dozeStage { rtLog("doze: \(stage)"); dozeStage = stage }
    }

    /// The mic or typing wakes her: a quick happy pop back to idle, and (from drowsy/asleep) a silent note so she may say
    /// a tiny "Oh! I'm awake!" before carrying on where she left off.
    private func wakeUp() {
        let was = dozeStage
        doze.wake()
        guard was != .awake else { return }
        dozeStage = .awake
        rtLog("doze: woken from \(was)")
        if was >= .drowsy { realtime.noteForNextKidTurn = DozeClock.wakeNote }
        wokePop = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            wokePop = false
        }
    }

    // MARK: Lock / background (round 9, Haylee: only fully closing the app ends the game)

    /// The game's state never depends on the scene phase: it all stays in memory. Background stops the audio (and a
    /// held mic); foreground brings the session back silently, or reconnects with the current state injected.
    @ObservationIgnored private var todayGames: [Suggestion] = []
    /// The kit-ready line has been spoken (or is waiting for the session): it plays exactly once.
    @ObservationIgnored private var kitReadySaid = false
    @ObservationIgnored private var deferredLine: String?
    private(set) var resuming = false
    @ObservationIgnored private var kitBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private var lastReconnect = Date.distantPast

    /// A conversation was running for this phase (planning with the session, or anything after it).
    static func wasLive(_ phase: Phase) -> Bool { phase != .hello }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            rtLog("scene: background (phase \(store.phase), step \(store.planningStep))")
            realtime.suspend()
            voice.stop()
            scribble.setPlaying(false, ducked: false)
            if listener.isListening { Task { _ = await listener.stopListening() } }
            // In-flight kit requests (Claude kit, page art) get time to finish; failures are retried on return.
            if store.phase == .makingKit || (store.phase == .kitReady && !kitFinal) { beginKitBackgroundTask() }
        case .active:
            rtLog("scene: active (phase \(store.phase), step \(store.planningStep))")
            updateIdleTimer()
            endKitBackgroundTask()
            if realtime.suspended { Task { await resumeSession() } }
            retryKitIfNeeded()
            if isWriting { scribble.setPlaying(true, ducked: isSpeaking) }
        default: break
        }
    }

    /// The screen stays awake during the conversation and kit making; auto-lock is allowed in the Print and Play steps.
    func updateIdleTimer() {
        let awake = Self.isPlanning(store.phase) || store.phase == .makingKit || (store.phase == .kitReady && !kitPapersOut)
        if UIApplication.shared.isIdleTimerDisabled != awake {
            UIApplication.shared.isIdleTimerDisabled = awake
            rtLog("idle timer disabled: \(awake)")
        }
    }

    private func resumeSession() async {
        if await realtime.resumeIfAlive() {
            flushDeferredLine()
            return
        }
        await reconnectSilently()
    }

    /// Reconnects with the CURRENT game in the instructions (step, choices, current prop, kit, latest lines). No kick-off:
    /// no greeting, no repeated question, no new suggestions; she waits for the kid.
    func reconnectSilently() async {
        guard let key = openAIKey, store.phase != .hello, !resuming else { return }
        // At most one attempt every 5 s (a dead network must not loop).
        if Date().timeIntervalSince(lastReconnect) < 5 { try? await Task.sleep(for: .seconds(5)) }
        lastReconnect = Date()
        resuming = true
        defer { resuming = false }
        let ctx = ResumeContext(store: store, transcript: realtime.transcript)
        rtLog("reconnect: silent, step \(store.planningStep), phase \(store.phase), \(ctx.recent.count) recent lines, no kick-off")
        // Round 13: exactly the voice this game started with (never a changed setting or a default).
        let config = gameVoice ?? voiceConfig
        #if DEBUG
        rtLog("reconnect: voice identical to first connect: \(gameVoice == nil || config == realtime.connectedConfig ?? config)")
        assert(gameVoice == nil || config == gameVoice, "reconnect must use the first connect's voice")
        #endif
        let ok = await realtime.connect(apiKey: key, config: config, echoCancel: voiceSettings.echoCancel,
                                        instructions: Realtime.resumeInstructions(todayGames: todayGames, context: ctx),
                                        keepChat: true)
        guard store.phase != .hello else { realtime.disconnect(); return }   // left meanwhile
        rtLog("reconnect: \(ok ? "live" : "failed")")
        guard ok else { return }
        // Session-side per-turn state starts fresh; the game's state carries over.
        realtime.micWanted = true
        realtime.huntMode = store.huntActive
        realtime.quickReplyOnly = store.phase == .makingKit
        realtime.resumed(propsPlanned: store.plan != nil || store.props != nil)
        shownProps = store.props?.props.count ?? 0   // a card held for the roles line shows now
        startDozeWatch()
        resuming = false
        flushDeferredLine()
    }

    private func flushDeferredLine() {
        guard let line = deferredLine else { return }
        deferredLine = nil
        rtLog("deferred line spoken")
        speak(line)
    }

    private func beginKitBackgroundTask() {
        guard kitBackgroundTask == .invalid else { return }
        kitBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "PretendThat kit") { [weak self] in
            Task { @MainActor in self?.endKitBackgroundTask() }
        }
        rtLog("background task: kit requests may finish")
    }

    private func endKitBackgroundTask() {
        guard kitBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(kitBackgroundTask)
        kitBackgroundTask = .invalid
    }

    /// On return: a kit request that failed while away is retried (the kit JSON via the store's retry; missing page art
    /// is retried by KitArtService itself once the app is active again).
    private func retryKitIfNeeded() {
        if store.phase == .makingKit, store.kit == nil, store.lastError != nil, !store.isWorking {
            rtLog("kit: retrying the kit request after background")
            Task { await store.retry() }
        }
    }

    // MARK: Checklist and scene pictures (checklist-pictures.md)

    func resolve(_ picture: Picture) -> ResolvedPicture {
        PictureResolver.resolve(picture, kit: store.kit, roles: store.plan?.roles ?? [])
    }

    /// The tile for one picture: library/action art, or this game's own kit art (one ticket, one bill, a role's
    /// badge with its title, one cut-out). Falls back to a placeholder word while art is missing.
    func pictureTile(_ picture: Picture, size: CGFloat = 56) -> PTPictureTile {
        let r = resolve(picture)
        switch r {
        case .prop(let id):
            return PTPictureTile(image: UIImage(named: PropLibrary.asset(id)), placeholder: PropLibrary.name(id) ?? id, size: size)
        case .action(let id):
            return PTPictureTile(image: UIImage(named: ActionArt.asset(id)), placeholder: id.replacingOccurrences(of: "-", with: " "), size: size)
        case .kitItem(let itemID, _, let role):
            let title = store.kit?.items.first { $0.id == itemID }?.title ?? ""
            return PTPictureTile(image: art.images[itemID], placeholder: title, roleTitle: role?.roleName,
                                 roleTint: Theme.playerColor(role?.id.index ?? 0), size: size)
        case .cutout(let itemID, let index, let label):
            return PTPictureTile(image: art.cutout(itemID, index), placeholder: label, size: size)
        }
    }

    var mouthLevel: Float { realtime.isLive ? realtime.level : voice.level }
    /// The live voice's lip-synced mouth (nil: fall back to the amplitude mouth from `mouthLevel`).
    var mouthShape: NutmegMouth? { realtime.isLive ? NutmegMouth(rawValue: realtime.mouth.rawValue) : nil }
    var isSpeaking: Bool { realtime.isLive ? realtime.isSpeaking : voice.isSpeaking }

    // MARK: Push-to-talk (decisions/2026-11-13-push-to-talk.md)

    /// The red mic in the control pill. Live conversation: stream to Realtime while held. Without one (tap fallback):
    /// the on-device listener, same hold gesture.
    enum MicState { case idle, listening, disabled }
    var micState: MicState {
        if realtime.isLive {
            // Round 7: never disabled in a live session (only while connecting): print step and play take voice too.
            return realtime.kidIsTalking ? .listening : .idle
        }
        if realtime.status == .connecting { return .disabled }
        guard listener.available, store.phase != .hello else { return .disabled }
        return listener.isListening ? .listening : .idle
    }
    func talkPressed() {
        wakeUp()
        if realtime.isLive { realtime.beginTalk() } else if listener.available { micPressed() }
    }
    func talkReleased() {
        if realtime.isLive { realtime.endTalk() } else if listener.isListening { micReleased() }
    }

    func micPressed() { listener.startListening(stopping: voice) }

    func micReleased() {
        Task {
            let text = await listener.stopListening()
            guard !text.isEmpty else { return }
            await handleSpeech(text)
        }
    }

    /// Routes a spoken answer by phase (ideas on pick-game, chat elsewhere). Names are never captured.
    func handleSpeech(_ text: String) async {
        switch store.phase {
        case .hello:
            await store.start()
        case .pickGame:
            if let idea = store.ideas?.ideas.first(where: { text.localizedCaseInsensitiveContains($0.title) }) {
                await store.chooseGame(idea.title)
            } else {
                await store.askForIdeas(text)
            }
        default:
            await store.kidSaid(text)
        }
    }
}
