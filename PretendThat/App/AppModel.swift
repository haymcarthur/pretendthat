import SwiftUI
import NutmegCore

/// Wires the state machine to Nutmeg's voice, ears and kit art. One per app run. Round D1: only games the kids choose
/// to save are kept, on this iPad (`SavedGameStore`), and only their game content; nothing about kids.
@Observable @MainActor
final class AppModel {
    let store: AdventureStore
    let voice = NutmegVoice()
    let listener = Listener()
    let art: KitArtService
    let stickers: ItemArtService
    /// Round 19: the kid-safety check (local filter, then moderation).
    @ObservationIgnored let safety: KidSafetyCheck
    /// Round 21: the remote moderation runs in parallel with her reply (the local filter stays instant and first).
    @ObservationIgnored let gate: SafetyGate
    /// The planning state from before text that is still being moderated was used (a late flag restores it).
    @ObservationIgnored private var safeSnap: AdventureStore.SafeSnapshot?
    /// Typed turns still being moderated: ticket id → (text, conversation item id), so a flag can take them back.
    @ObservationIgnored private var screenedTurns: [Int: (text: String, itemID: String)] = [:]
    /// Hands-free planning conversation (D1, D2).
    let realtime = RealtimeSession()
    /// The writing moment's quiet scribble loop (round 5).
    @ObservationIgnored let scribble = ScribbleSound()
    /// Realtime auth: a personal OPENAI_API_KEY (dev mode) or the shared relay's ephemeral secrets.
    @ObservationIgnored private let realtimeAuth: RealtimeAuth?
    /// Only the IDs of last session's suggested games/themes (UserDefaults), so the next session differs. Nothing about kids.
    @ObservationIgnored private let suggestionMemory = SuggestionMemory()
    /// Round D1: saved games, on this iPad only (Application Support/SavedGames; iCloud is round D4).
    @ObservationIgnored let savedGames = SavedGameStore(root: SavedGameStore.defaultRoot())
    /// The My games shelf (newest first). The start screen shows "My games" once it isn't empty.
    var shelfGames: [SavedGame] = []
    /// The My games bookshelf screen is open (on the start screen; the phase stays Hello).
    var showingShelf = false
    /// The saved game being replayed (its art, for Paper).
    @ObservationIgnored var replayGame: SavedGame?
    /// The replay's voice session is connecting: its lines wait for it (never the device voice).
    @ObservationIgnored private var replayConnecting = false
    /// AI calls (Claude, images, moderation) when the replay started: the live check logs the difference.
    @ObservationIgnored private var replayStartCalls: [AICallLog.Kind: Int] = [:]
    enum SaveState: Equatable { case idle, saving, failed }
    private(set) var saveState: SaveState = .idle

    /// The planning conversation is running (a replay has no planning: its Pick and Props steps are taps and app lines).
    var planningNow: Bool { Self.isPlanning(store.phase) && !store.isReplay }

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        let config = ClaudeConfig.from(info: info)
        // Round 19: kid text and generated text are checked locally and with OpenAI moderation (fails safe to local).
        let moderation = ModerationClient.from(info: info)
        safety = KidSafetyCheck(moderator: moderation)
        gate = SafetyGate(check: safety)
        var service = config.map { PhaseService(llm: ClaudeClient(config: $0), moderator: moderation) }
        #if DEBUG
        if DemoDriver.requestedPhase != nil { service = nil }   // demo screens use the bundled game, no network
        #endif
        store = AdventureStore(service: service)
        var images = ImageClient.from(info: info)
        #if DEBUG
        // Demo screens skip paid image calls unless asked: -PTDemoArt 1
        if DemoDriver.requestedPhase != nil, !ProcessInfo.processInfo.arguments.contains("-PTDemoArt") { images = nil }
        #endif
        art = KitArtService(client: images)
        stickers = ItemArtService(client: images)
        realtimeAuth = RealtimeAuth.from(info: info)
        // Round 20: the Grown-ups voice settings are gone; drop what older builds stored for them (device settings only).
        for k in ["voice", "method", "pitchCents", "rate", "speed", "echo"] { UserDefaults.standard.removeObject(forKey: "nutmeg.v4.\(k)") }
        realtime.onTurnDone = { [weak self] text in
            guard let self, self.planningNow, !self.realtime.propLinePending else { return nil }
            // Round 7: roles set but no prop yet → she continues straight into the first prop (no "Sound good?" wait).
            return TurnCheck.review(text, step: self.store.planningStep, rolesSet: self.store.plan != nil,
                                    propsShown: self.store.props?.props.count ?? 0, currentPropDone: self.store.currentPropDone)
        }
        realtime.onSilence = { [weak self] in
            guard let self, self.planningNow, self.store.planningStep != .finish else { return nil }
            return TurnCheck.silenceLine   // spoken only, never in the chat (round 7)
        }
        realtime.onPlanningBeat = { [weak self] topic in await self?.planningBeat(topic) }
        realtime.onPropLine = { [weak self] in self?.revealFirstProp() ?? "" }
        realtime.onSilentPassDone = { [weak self] in self?.noteAfterSilentPass() }
        realtime.onKidTranscript = { [weak self] text in self?.spokenSafetyCheck(text) }
        gate.onFlag = { [weak self] verdict, ticket in self?.lateFlag(verdict, ticket) }
        gate.onAllClear = { [weak self] in self?.safeSnap = nil; self?.screenedTurns = [:] }
        store.outboundGate = { [weak self] in await self?.gate.cleared() ?? true }
        // Tool-first kid turns (round 7): no narration is ever heard; she speaks after the tool result.
        realtime.onKidTurnTools = { [weak self] in
            guard let self else { return nil }
            if self.store.isReplay { return ReplayLines.tools(self.store.phase, drawing: self.store.drawing) }   // round D1
            guard self.planningNow else {
                return Realtime.afterHuntTools(self.store.phase, drawing: self.store.drawing)   // round 23 (+ round 24's Draw it!)
            }
            return Realtime.kidTurnTools(step: self.store.planningStep, huntActive: self.store.huntActive)
        }
        realtime.onPostPlanningTurn = { [weak self] in
            guard let self else { return nil }
            switch self.store.phase {
            case .kitReady where self.store.drawing:
                // Round 24: no printer, the Draw it! step: one piece at a time.
                let g = self.store.drawGuide
                return "(Silent coaching, don't mention it.) No printer: the kids are drawing their kit (the \(DrawIt.title) step), "
                    + "piece \(self.store.drawIndex + 1) of \(g?.pieces.count ?? 1): \"\(self.store.drawLine ?? "")\" If they finished it "
                    + "(\"next\", \"done\", \"I drew it\"), call draw_step with next; to hear it again, draw_step with again; to "
                    + "start playing, start_play. " + BackNav.voiceHint + " Otherwise answer in ONE short line."
            case .kitReady:
                return "(Silent coaching, don't mention it.) The kit is ready on screen (print step). If they want to play, "
                    + "call start_play; if they want to print, call print_kit. " + BackNav.voiceHint
                    + " Otherwise answer in ONE short line. No \"go play\" yet."
            case .handoff(let i):
                // Round 9: "I'm the Captain" by voice confirms the hand-off, same as tapping the card's button.
                let role = self.store.kit.flatMap { k in k.scenes.indices.contains(i) ? k.scenes[i].owner.role : nil }
                    .flatMap { self.store.plan?.role(for: $0)?.roleName } ?? "next player"
                return "(Silent coaching, don't mention it.) The iPad is being passed to the \(role). If the kid says they're "
                    + "the \(role) or that they've got the iPad, call confirm_handoff and say nothing. Otherwise answer in ONE "
                    + "short line (remind them to tap I'm the \(role)!)."
            case .scene, .end:
                // Round 23: the only tool while playing is going back ("print it again", "back to the props").
                return BackNav.playNote
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

    var hasRealtime: Bool { realtimeAuth != nil }
    /// Round 11: the game opens on the talking close-up (voice conversation), so the start screen's exit pushes its
    /// camera there. Without voice the tap screens take over from the arrival framing.
    var opensInCloseUp: Bool {
        #if DEBUG
        if DemoDriver.autoStart { return true }
        #endif
        return hasRealtime
    }

    /// Round 13: Nutmeg's voice for every connect (first, pre-connect, reconnect). Round 20 (Haylee): the Grown-ups
    /// settings are gone, so it's the fixed default (coral, Varispeed 1.20, speed 1.0), with no echo cancellation.
    var voiceConfig: VoiceConfig { VoiceConfig.nutmeg }
    static let echoCancel = false
    /// The voice this game's conversation started with: a silent reconnect uses exactly this one.
    @ObservationIgnored private var gameVoice: VoiceConfig?

    /// Round 13: while the start screen shows, open the Realtime socket with today's ideas, so "Let's play!" only
    /// starts the audio and the greeting.
    func preconnect() {
        #if DEBUG
        if DemoDriver.autoStart || DemoDriver.requestedPhase != nil { return }
        #endif
        guard let auth = realtimeAuth, store.phase == .hello else { return }
        if preparedGames.isEmpty { preparedGames = suggestionMemory.pickGames() }
        // Round 20 (cost): the session instructions are always the same (cached prefix); today's ideas follow as a note.
        realtime.preconnect(auth: auth, config: voiceConfig, instructions: Realtime.instructions)
    }
    @ObservationIgnored private var preparedGames: [Suggestion] = []
    /// DEBUG screenshots: show the conversation stage without a live session.
    var forceConversation = false

    /// The planning phases run as a voice conversation while the Realtime session is up.
    var inConversation: Bool {
        if forceConversation { return planningNow }
        guard realtime.status == .live || realtime.status == .connecting else { return false }
        return planningNow
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
        guard let auth = realtimeAuth else { await store.start(); return }
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
        let ok = await realtime.connect(auth: auth, config: config, echoCancel: Self.echoCancel,
                                        instructions: Realtime.instructions)
        guard store.phase == .pickGame else { return }   // left while connecting
        if ok {
            realtime.addNote(Realtime.todaysIdeasNote(games))
            realtime.micWanted = true
            gesture(.wave)
            realtime.kickOff(games: games)
            startDozeWatch()
        } else {
            await store.start()   // tap screens (and the bundled airplane game if Claude is off too)
        }
    }

    // MARK: Kid safety (round 19)

    /// Round 19: a fresh set of ideas for each steer ("How about a bakery, a zoo, or a pirate ship?"), never one already
    /// offered this session (today's games, theme ideas, earlier redirects).
    private var steerIdeas: [Suggestion] { store.nextSteerIdeas(alsoOffered: todayGames) }

    /// Unsafe kid text was dropped: Nutmeg cheerfully steers (or says to get a grown-up), one line, in the chat.
    func steer(_ verdict: Sanitizer.SafetyVerdict) {
        rtLog("safety: kid text blocked (\(verdict.category.rawValue))")   // the category only, never the text
        let line = SafetySteer.line(for: verdict, ideas: steerIdeas)
        if realtime.isLive {
            realtime.stopSpeaking("safety")
            realtime.say(line)
        } else {
            store.steerLine(line)
        }
    }

    /// What the kid SAID went straight to the voice model (its instructions handle it); the app adds one backstop: a kid
    /// who may be hurt or in danger hears "go get a grown-up" right away, whatever the model was about to say.
    private func spokenSafetyCheck(_ text: String) {
        guard let v = Sanitizer.kidSafety(text) else { return }
        rtLog("safety: spoken turn flagged (\(v.category.rawValue))")
        if v.category == .needsGrownUp || v.category == .selfHarm { steer(v) }
    }

    /// Text in a tool call (a game or theme title, roles, what a prop becomes) is checked before the app uses it.
    /// Round 21: the game, the theme (first steps) and the next prop card run ahead of moderation (local filter first;
    /// a late flag puts the state back). Every other call (roles, the kit, finish) first waits for ALL checks still
    /// running, then checks its own text in full, because it sends things out (Claude, the kit, images).
    private func screen(_ call: PlanningCall) async -> Sanitizer.SafetyVerdict? {
        let texts = SpeculativeTools.texts(call)
        if SpeculativeTools.mayRunBeforeModeration(call, step: store.planningStep, huntActive: store.huntActive) {
            guard !texts.isEmpty else { return nil }
            if !gate.isPending || safeSnap == nil { safeSnap = store.safeSnapshot() }
            return gate.screen(texts, kind: .toolText, pretend: true).local   // round 20: a pretend oven is fine
        }
        guard await gate.cleared() else { return nil }   // flagged meanwhile: the caller drops this call
        return texts.isEmpty ? nil : await safety.check(texts, pretend: true)
    }

    // MARK: The kid moved on (round 19, Haylee)

    /// ANY tap that advances or changes the screen stops her current speech at once (the in-flight responses, the
    /// local player, pending cheers / repeats / deferred lines); then only the newest line plays.
    func userAction(_ action: UserAction) {
        guard action.stopsSpeech else { return }
        cheerTask?.cancel(); cheerTask = nil
        repeatTask?.cancel(); repeatTask = nil
        deferredLine = nil
        voice.stop()
        realtime.stopSpeaking(action.rawValue)
    }

    func tapHandoff(_ role: RoleID) { userAction(.handoff); store.badgeTapped(role) }
    func tapBackToChecklist() { userAction(.backToChecklist); store.backToChecklist() }
    func tapLetsPlay() {
        userAction(.letsPlay)
        store.beginPlay()
        if store.playQueued { guideWaitStarted() }
    }

    /// Guide prefetch (2026-11-15): Let's play! while the play guide is still being finished. Play starts by itself the
    /// moment it lands; meanwhile she says one true "checklists" line, and the usual kit commentary keeps going.
    @ObservationIgnored var playWaitStartedAt: Date?
    func guideWaitStarted() {
        playWaitStartedAt = Date()
        rtLog("TIMING Let's play! while the play guide is still being finished: Play waits for it")
        if let line = lineDeck.draw("kit." + KitProgress.Topic.checklists.rawValue, from: KitProgress.lines[.checklists] ?? []) {
            speak(line)
        }
        startKitProgress()
    }

    /// Guide prefetch: DEBUG timings for the live check (the guide's start, written, final; the wait at Play).
    func guideTimingChanged() {
        let hunt = huntStartedAt
        func since(_ d: Date?) -> Double { d.flatMap { a in hunt.map { a.timeIntervalSince($0) } } ?? -1 }
        if store.guideWrittenAt != nil && !loggedGuideWritten {
            loggedGuideWritten = true
            rtLog(String(format: "TIMING play guide (no props) written %.1f s after the hunt started (call %.1f s)",
                         since(store.guideWrittenAt), store.guideWrittenAt!.timeIntervalSince(store.guideStartedAt ?? store.guideWrittenAt!)))
        }
        if let fin = store.guideFinalAt, !loggedGuideFinal {
            loggedGuideFinal = true
            rtLog(String(format: "TIMING play guide final %.1f s after the hunt started, %.1f s after Print was reached",
                         since(fin), printReachedAt.map { fin.timeIntervalSince($0) } ?? -1))
        }
        if store.guideStartedAt == nil { loggedGuideWritten = false; loggedGuideFinal = false }
    }
    @ObservationIgnored private var loggedGuideWritten = false
    @ObservationIgnored private var loggedGuideFinal = false
    func guidePendingChanged(_ pending: Bool) {
        if pending { rtLog("TIMING Paper went ahead while the play guide is still being finished") }
        if !pending && kitFinal { endKitBackgroundTask() }
        if !pending, let at = playWaitStartedAt {
            rtLog(String(format: "TIMING Play waited %.1f s for the play guide", Date().timeIntervalSince(at)))
            playWaitStartedAt = nil
        }
    }
    func tapPlayAgain() { userAction(.playAgain); store.playAgain() }
    func tapPrint() { userAction(.print); printKit() }
    func tapStepRail(_ step: JourneyStep) {
        userAction(.stepRail)
        let queued = store.playQueued
        navigate(to: step)
        if !queued && store.playQueued { guideWaitStarted() }
    }
    /// Round 23: a tap back to a step on the rail: the same `store.goTo`, then her one arrival line, and a silent
    /// note so the conversation knows where the kids are. Voice uses go_to_step (the model says the line itself).
    func navigate(to step: JourneyStep) {
        guard store.goTo(step) else { return }
        let line = BackNav.arrivalLine(step, drawing: store.drawMode)
        rtLog("back-nav: \(step.label) (tap)")
        if realtime.isLive {
            realtime.addNote(Realtime.systemNote(BackNav.tapNote(step, drawing: store.drawMode)))
            lastAppLine = line
            realtime.say(line)
        } else {
            speak(line)
        }
    }
    /// New game goes all the way home: the session hangs up, so nothing keeps talking on the start screen.
    func tapNewGame() { userAction(.newGame); leave() }

    /// Leave activity: hang up and go home. Nothing is kept.
    func leave() {
        userAction(.goHome)
        cheerTask?.cancel(); repeatTask?.cancel(); pointTask?.cancel(); beatEndTask?.cancel(); kitWait?.cancel()
        realtime.disconnect()
        gameVoice = nil
        kitReadySaid = false; deferredLine = nil; doze.wake(); dozeStage = .awake; wokePop = false; endKitBackgroundTask()
        huntStartedAt = nil; printReachedAt = nil
        shownProps = 0; beat = .none; kitBeatTask?.cancel(); kitBeat = .coloring; kitWriting = false; kitWritingTask?.cancel(); kitWritingTask = nil
        voice.stop()
        art.reset()
        stickers.reset()
        gate.reset(); safeSnap = nil; screenedTurns = [:]
        printablesKit = nil; printablesShare = nil; printablesState = .idle
        replayGame = nil; replayConnecting = false; saveState = .idle
        if let f = printablesFile { try? FileManager.default.removeItem(at: f); printablesFile = nil }
        store.newGame()
    }

    /// Typed fallback goes into the live conversation when there is one.
    func typed(_ text: String) async {
        realtime.beginTrace("typed")   // round 21: the trace starts at the send itself (the safety check included)
        wakeUp()
        // Round 20: the kid's own turn stops anything she's saying or about to say (cheers, repeats, deferred lines).
        if realtime.isLive && store.phase != .makingKit { userAction(.typedTurn) }
        let live = realtime.isLive && store.phase != .makingKit
        // Round 19: typed kid text is checked BEFORE it goes anywhere. Round 21: the local filter is instant and still
        // blocks first; moderation runs in parallel with her reply (a late flag takes the turn back and steers).
        if live && !gate.isPending { safeSnap = store.safeSnapshot() }
        let screened = gate.screen([text], kind: .kidText)
        if let verdict = screened.local { steer(verdict); return }
        realtime.markTrace("checked")
        if live {
            let itemID = "kid_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24).lowercased()
            if let t = screened.ticket { screenedTurns[t.id] = (text, itemID) }
            realtime.sendText(text, itemID: itemID)   // planning, the print step and play
            return
        }
        // Not sent to the voice model: wait for moderation before anything uses it (Claude, the kit).
        guard await gate.cleared() else { return }
        // Kit being made (round 7): a tiny "Almost ready!" at most, never a new conversation turn.
        if realtime.isLive && store.phase == .makingKit { if !realtime.isSpeaking { realtime.say("Almost ready!") }; return }
        await handleSpeech(text)
    }

    /// Round 21: moderation flagged text AFTER it was used (a typed turn, or a game / theme / prop text that ran ahead).
    /// Her reply is cancelled, the planning state goes back to before that text, the typed line leaves the chat and the
    /// conversation, and she steers, exactly like an early block. Nothing went out: Claude, the kit and images wait
    /// for the gate.
    private func lateFlag(_ verdict: Sanitizer.SafetyVerdict, _ ticket: SafetyGate.Ticket) {
        rtLog("safety: late moderation flag (\(ticket.kind == .kidText ? "typed turn" : "tool text"), \(verdict.category.rawValue)): reply cancelled, undone")
        realtime.stopSpeaking("safety (late)")
        if let snap = safeSnap {
            store.restore(snap)
            safeSnap = nil
            shownProps = min(shownProps, store.props?.props.count ?? 0)
            realtime.huntMode = store.huntActive
        }
        for (_, turn) in screenedTurns { realtime.retractKidTurn(text: turn.text, itemID: turn.itemID) }
        screenedTurns = [:]
        realtime.addNote(Realtime.systemNote("(Silent coaching, don't mention it.) The last request wasn't kid-safe, so the "
            + "app undid it: don't use it, repeat it or mention it. Wait for the kids' next answer."))
        steer(verdict)
    }

    func phaseChanged() {
        // Round 19: home (the start screen) is always silent.
        if store.phase == .hello {
            if realtime.status != .idle { realtime.disconnect() }
            voice.stop(); cheerTask?.cancel(); repeatTask?.cancel(); deferredLine = nil
        }
        // Round 7 (Haylee): the mic only looks disabled while connecting. Kit making: pressable, "Almost ready!" at most.
        realtime.micWanted = true
        realtime.quickReplyOnly = store.phase == .makingKit
        if store.phase == .makingKit { startKitProgress() } else if store.phase != .kitReady { kitWait?.cancel() }
        if store.phase == .makingKit && printReachedAt == nil {
            printReachedAt = Date()
            let pages = store.draftItems.map { KitArtPlan.keys(items: $0).count } ?? 0
            rtLog(String(format: "TIMING print reached %.1f s after the hunt started; pages written: %@; art landed: %d of %d",
                         huntStartedAt.map { Date().timeIntervalSince($0) } ?? -1, store.draftItems == nil ? "no" : "yes",
                         art.images.count + art.cutouts.values.map(\.count).reduce(0, +), pages))
        }
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
        // Round D1: a replay prints the saved art: never an image call.
        if store.isReplay { return }
        // Round 24: no printer → the kit is drawn by hand: never an image call.
        if store.drawMode { rtLog("kit: no printer, Draw it! (\(store.drawGuide?.pieces.count ?? 0) pieces, no image calls)"); return }
        // Round 19: the CURRENT title (a corrected theme wins over the one the roles were planned with).
        let title = store.currentTitle
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTLive") { rtLog("KIT for \(title): \(kit.items.map(\.title).joined(separator: " | "))") }
        #endif
        // Round 20: the hunt's themed cut-outs were one sheet; the skipped props' cut-outs after them are drawn one each.
        let sheet = store.draftItems?.first { $0.recipe == .cutouts }.map { KitArtPrompt.cutoutLabels($0).count }
        Task { await art.generate(kit: kit, gameTitle: title, style: store.currentPrintStyle, sheetCount: sheet, roles: store.plan?.roles ?? []) }
    }

    // MARK: Kit made during the hunt (round 20, Haylee)

    @ObservationIgnored private var artDraftGeneration = 0
    /// The hunt's kit pages (re)started or landed, or the color changed: their art follows, in the background. A
    /// restart (a correction, new roles) drops the old art. Never any commentary here: that's only at Print.
    func draftChanged() {
        if store.isReplay { return }   // round D1: nothing is drafted on a replay
        // The pages may land just after the hunt ended (the kit call waits for them): their art starts then too,
        // unless a late correction is remaking the kit for a new title.
        let making = store.phase == .makingKit && store.kitRemakes == 0 && store.kit == nil
        guard planningNow || making else { return }
        if store.draftGeneration != artDraftGeneration && !making {
            artDraftGeneration = store.draftGeneration
            art.reset()
        }
        guard let items = store.draftItems else { return }
        if let started = store.draftStartedAt, let ready = store.draftReadyAt {
            rtLog(String(format: "TIMING kit pages written during the hunt in %.1f s", ready.timeIntervalSince(started)))
        }
        art.prepare(items: items, gameTitle: store.currentTitle, style: store.currentPrintStyle, roles: store.plan?.roles ?? [])
    }

    /// DEBUG timings for the live check (hunt start → Print, the wait at Print).
    @ObservationIgnored var huntStartedAt: Date?
    @ObservationIgnored var printReachedAt: Date?

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
                // Guide prefetch: Let's play! is waiting for the play guide: the checklists are really being written.
                let guideWait = store.playQueued && store.guidePending
                guard !Task.isCancelled, store.phase == .makingKit || store.phase == .kitReady, !kitFinal || guideWait else { return }
                if isSpeaking || (realtime.isLive && realtime.voiceBusy) { continue }
                // While the kit's content is being written, every page and the play guide are in progress; then only
                // the pages whose art is still being drawn.
                // Round 20: the pages were written during the hunt, so only what's still in progress counts.
                let pending = (store.kit?.items ?? store.draftItems ?? []).filter { item in
                    item.recipe == .cutouts ? art.cutoutImages(item).contains { $0 == nil }
                        : item.recipe == .badges ? art.badge(item.id, role: 0) == nil   // round C1: the sheet or the shared badge
                        : art.images[item.id] == nil
                }.compactMap(\.recipe)
                // Round 24: no printer → no pages are drawn; only the play guide is being written.
                let topics = guideWait && kitFinal ? [KitProgress.Topic.checklists]
                    : store.drawMode ? (store.kit == nil ? [KitProgress.Topic.checklists] : [])
                    : KitProgress.inProgress(pagesWritten: store.kit != nil || store.draftItems != nil,
                                             scenesWritten: store.kit != nil && !store.guidePending, pendingPages: pending)
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
        userAction(.checkStep)
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
            speak(line)
        }
    }
    @ObservationIgnored private var cheerTask: Task<Void, Never>?

    /// Round 16 (Haylee): "Hear it again" on the checklist. She reads the scene title and the steps not checked yet
    /// (all of them if every one is checked). A pending cheer is dropped (never said late), the line waits for anything
    /// she's saying to finish, and repeated taps are ignored while one is queued or just sent: one reply per tap.
    func repeatChecklist() {
        guard case .scene(let i) = store.phase, let scene = store.kit?.scenes[i], !store.autoChecking else { return }
        guard repeatTask == nil, Date().timeIntervalSince(lastRepeatAt) > 2.5 else { return }
        // A tap while the read-aloud itself is still playing doesn't queue a second one.
        if Date().timeIntervalSince(lastRepeatAt) < 20 && (realtime.isLive ? realtime.isSpeaking : isSpeaking) { return }
        userAction(.repeatLine)
        lastRepeatAt = Date()
        wakeUp()
        repeatTask = Task { @MainActor in
            defer { repeatTask = nil }
            for _ in 0..<160 where (realtime.isLive ? realtime.voiceBusy : isSpeaking) && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))   // never over another line (≤ 8 s)
            }
            guard !Task.isCancelled, case .scene(i) = store.phase else { return }
            let line = HandOffLines.repeatText(title: scene.title, steps: scene.steps.map(\.text), checked: store.checkedSteps)
            lastRepeatAt = Date()
            rtLog("checklist repeat: \(line)")
            speak(line)
        }
    }
    @ObservationIgnored private var repeatTask: Task<Void, Never>?
    @ObservationIgnored private var lastRepeatAt = Date.distantPast

    // MARK: Repeat in the control pill (round 17, Haylee)

    /// The last line the app gave her to say (the fallback when there's no chat transcript, e.g. the device voice).
    private(set) var lastAppLine: String?
    /// What the pill's Repeat ("Hear it again") does right now; `.none` dims it (nothing yet, or she's busy).
    var repeatTarget: RepeatTarget {
        let inChecklist: Bool = { if case .scene = store.phase, !store.huntActive { return true } else { return false } }()
        let busy = isSpeaking || micState == .listening || store.autoChecking || repeatTask != nil
            || (realtime.isLive && (realtime.isBusy || realtime.thinkingGap))
        // Round 24: on the Draw it! card, Repeat reads the current piece.
        if store.drawing, !busy, let line = store.drawLine { return .lastLine(line) }
        let last = realtime.transcript.last(where: \.fromNutmeg)?.text
        return RepeatTarget.choose(inChecklist: inChecklist, busy: busy, transcriptLast: last, appLast: lastAppLine)
    }
    /// The pill's Repeat: the checklist read-aloud during play (round 16), else her last line again, in the same app
    /// line path and voice (no duplicate chat bubble). Debounced: one repeat per tap.
    func repeatTapped() {
        switch repeatTarget {
        case .none: return
        case .checklist: repeatChecklist()
        case .lastLine(let line):
            guard Date().timeIntervalSince(lastRepeatAt) > RepeatTarget.debounce else { return }
            if realtime.isLive && realtime.voiceBusy { return }
            userAction(.repeatLine)
            lastRepeatAt = Date()
            wakeUp()
            rtLog("repeat last line: \(line)")
            if realtime.isLive { realtime.say(line, echo: true) }
            else if !(hasRealtime && gameVoice != nil && Self.wasLive(store.phase)) { Task { await voice.say(line) } }
        }
    }
    /// The scene whose overall congratulations has been said (the last step checked normally).
    @ObservationIgnored private var congratulatedScene: Int?

    /// "Done!": a pending step cheer is dropped; if the list wasn't finished (Done! checks the rest) or its
    /// congratulations hasn't been said yet, ONE overall congratulations starts the next line (hand-off, scene, end).
    func sceneDone() async {
        guard case .scene(let i) = store.phase, !store.autoChecking else { return }
        userAction(.done)
        if congratulatedScene != i {
            store.sceneLeadIn = ChecklistCheers.finished(deck: &lineDeck, using: &rng)
        }
        congratulatedScene = nil
        await store.sceneDone()
    }
    @ObservationIgnored private var kitWait: Task<Void, Never>?

    /// Kit step beats (no-text-overlays.md, fix round 2): she colors in the close-up until the WHOLE kit is final, then
    /// looks up (crayon down), the camera zooms out, and the papers fly off her clipboard.
    var kitBeat: PTStageDirector.KitBeat = .coloring
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
        KitPrinter.print(pdf, jobName: "PretendThat \(store.currentTitle)")
    }
    /// The papers are out (kit final, she looked up, the camera zoomed out).
    var kitPapersOut: Bool { kitFinal && kitBeat == .papers }

    /// Every page's art has landed or definitively fallen back.
    var kitFinal: Bool { store.phase == .kitReady && store.kit != nil && (store.drawMode ? store.drawGuide != nil : art.finished) }
    func kitFinalChanged(_ final: Bool) {
        // Round D1: a replay's Paper step has its own choices (no writing beat, no ready line).
        if store.isReplay { kitBeatTask?.cancel(); return }
        #if DEBUG
        // `-PTPDFOut`: write the print-path PDF (exactly what AirPrint gets) to tmp/kit.pdf once the kit is final.
        if final, ProcessInfo.processInfo.arguments.contains("-PTPDFOut") {
            let pdf = KitPrinter.pdf(pages: kitPages, art: art.images,
                                     cutouts: Dictionary(uniqueKeysWithValues: (store.kit?.items ?? []).map { ($0.id, art.cutoutImages($0)) }))
            try? pdf.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("kit.pdf"))
        }
        #endif
        kitBeatTask?.cancel()
        if final && !store.guidePending { endKitBackgroundTask() }
        if final, let at = printReachedAt {
            rtLog(String(format: "TIMING kit final %.1f s after Print was reached", Date().timeIntervalSince(at)))
        }
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
            // Round 16 (Haylee: at print-ready she said nothing): never over a kit progress line or a reply still
            // playing; wait for quiet (≤ 6 s), then the one ready line naming both buttons.
            for _ in 0..<120 where realtime.isLive && realtime.voiceBusy && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
            }
            // Round 19: the kid already moved on (Let's play, step rail): the ready line is stale, never said late.
            guard !Task.isCancelled, !kitReadySaid, store.phase == .kitReady else { return }
            kitReadySaid = true
            // Round 24: no printer → the first Draw it! piece (it names the Next button).
            let ready = store.drawing ? (store.drawLine ?? AdventureStore.kitReadyLine) : AdventureStore.kitReadyLine
            rtLog("print ready line: \(ready)")
            speak(ready, deferIfAway: true)
        }
    }

    private func handleCall(name: String, arguments: String) async -> (output: String, respond: Bool) {
        guard let call = PlanningCall.decode(name: name, arguments: arguments) else {
            return ("I couldn't use that. Try again with the right fields.", true)
        }
        let before = realtime.responseSerial
        let flags = gate.flaggedCount
        if let verdict = await screen(call) {
            rtLog("safety: \(name) blocked (\(verdict.category.rawValue))")
            return (SafetySteer.toolNote(verdict, ideas: steerIdeas), true)
        }
        if gate.flaggedCount != flags {
            // A flag landed while this call waited (the state was already put back): drop it quietly.
            return ("(Silent coaching, don't mention it.) That was undone. Say nothing more.", false)
        }
        realtime.markTrace("checked \(name)")
        if case .printKit = call, store.isReplay, store.phase == .kitReady, store.replayPrintables != nil || !store.drawMode {
            replayPaper(.everything)   // round D1: "print it" on a replay = Print everything
            return ("The print screen is open. Say one short line like \"Here's the print screen!\"", true)
        }
        if case .printKit = call, store.phase.step != .play, !store.drawMode {
            guard store.phase == .kitReady || kitFinal else { return ("Not yet: the kit isn't ready. Say only \"Almost ready!\"", true) }
            printKit()
        }
        if case .goToStep(let step) = call { rtLog("back-nav: \(step.label) (voice)") }
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
        if case .showNextProp = call { store.kitLeadIn = nil; if huntStartedAt == nil { huntStartedAt = Date(); rtLog("TIMING hunt started") } }
        let remakes = store.kitRemakes, restyles = store.kitRestyles
        let queued = store.playQueued
        let output = await store.apply(call)
        if !queued && store.playQueued { guideWaitStarted() }   // guide prefetch: start_play / go to Play while it's finishing
        releasePointIfNoCard()   // round 23: mark_found / skip_prop / finish_planning by voice
        if store.kitRemakes != remakes {
            // Round 19: a theme/game fix at the print step remakes the kit: the old pages' art and ready line go too.
            remakeKitArt()
            return (output, false)
        }
        if store.kitRestyles != restyles {
            // Round 20: a color change at the print step redraws the same kit's pages in the new style.
            remakeKitArt()
            kitChanged()
            return (output, false)
        }
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

    /// Round 19: the kit is being remade for a corrected title: drop the old art and beats so the new kit runs fresh.
    private func remakeKitArt() {
        rtLog("kit: remade for a corrected title")
        art.reset()
        kitReadySaid = false; deferredLine = nil
        kitBeatTask?.cancel(); kitBeat = .coloring
    }

    // MARK: Confirm step (round 19, Haylee)

    /// The recap she was last told to say word for word (a new one is only sent when it changed).
    @ObservationIgnored private var lastRecap: String?
    /// The Yes / Change buttons: on the confirm step of the live conversation, once her recap reply has started.
    var showsConfirm: Bool {
        inConversation && store.planningStep == .confirm && !realtime.thinkingGap
    }

    /// After a tool-first pass on the confirm step: the newest recap, word for word (only when it changed).
    func noteAfterSilentPass() -> String? {
        guard planningNow, store.planningStep == .confirm else { lastRecap = nil; return nil }
        let recap = store.recapLine
        guard recap != lastRecap else { return nil }
        lastRecap = recap
        return ConfirmStep.sayRecapNote(recap)
    }

    /// "Yes, let's go!": confirmed at once. Round 20: her one reply is the color question (or, when the kids already
    /// chose a color, the planning line and the roles).
    func confirmYes() {
        guard realtime.isLive, store.planningStep == .confirm else { return }
        realtime.beginTrace("tap")
        wakeUp()
        Task { @MainActor in
            _ = await store.apply(.confirmPlan)
            lastRecap = nil
            if store.planningStep == .printer {
                realtime.tapTurn(kidLine: ConfirmStep.yesLabel, note: PrinterChoice.yesTapNote(), requiring: nil)
            } else if store.planningStep == .color {
                realtime.tapTurn(kidLine: ConfirmStep.yesLabel, note: ColorChoice.yesTapNote(), requiring: nil)
            } else {
                realtime.tapTurn(kidLine: ConfirmStep.yesLabel, note: ConfirmStep.yesTapNote(playerCount: max(1, store.playerCount)),
                                 requiring: nil, speakWithTools: true)
            }
        }
    }

    // MARK: Printer question and Draw it! (round 24, Haylee)

    /// The Yes / No printer buttons: on the printer step, once her question has started.
    var showsPrinterChoice: Bool {
        inConversation && store.planningStep == .printer && !realtime.thinkingGap
    }

    /// A printer button: set at once; her one reply is the color question (yes) or the planning line + roles (no).
    func choosePrinter(_ has: Bool) {
        guard realtime.isLive, store.planningStep == .printer else { return }
        realtime.beginTrace("tap")
        wakeUp()
        userAction(.printerChoice)
        Task { @MainActor in
            _ = await store.apply(.setPrinter(has))
            rtLog("printer: \(has ? "yes" : "no") (tap)")
            let note = PrinterChoice.tapNote(has, colorKnown: store.printStyle != nil, playerCount: max(1, store.playerCount))
            realtime.tapTurn(kidLine: has ? PrinterChoice.yesLabel : PrinterChoice.noLabel, note: note,
                             requiring: nil, speakWithTools: store.planningStep == .roles)
        }
    }

    /// Draw it!'s Next: the next piece and its line (one reply), or after the last piece, on to Play (its own line).
    func tapDrawNext() {
        guard store.drawing else { return }
        userAction(.drawNext)
        wakeUp()
        guard let line = store.drawNext() else { rtLog("draw it: done → play"); return }
        rtLog("draw it: piece \(store.drawIndex + 1): \(line)")
        if realtime.isLive {
            realtime.addNote(Realtime.systemNote("(Silent note, don't mention it.) The kids tapped Next on the Draw it! card; "
                + "you're saying piece \(store.drawIndex + 1): \"\(line)\""))
        }
        speak(line)
    }

    /// Save printables for later (no printer): the normal kit as coloring pages, then the share sheet (Save to Files,
    /// AirDrop, send to a grown-up). Nothing is stored by the app: the PDF is a temporary file for the share sheet.
    enum PrintablesState: Equatable { case idle, making, failed }
    private(set) var printablesState: PrintablesState = .idle
    /// The share sheet's file (non-nil = presented).
    var printablesShare: URL?
    @ObservationIgnored private var printablesKit: Kit?
    func tapSavePrintables() {
        guard store.drawMode, printablesState != .making else { return }
        userAction(.savePrintables)
        if let url = printablesFile { printablesShare = url; return }
        printablesState = .making
        speak("Ooh, I'll make your printable pages to save for later! Wait for it...")
        Task { @MainActor in
            let started = Date()
            var made = printablesKit
            if made == nil { made = await store.makePrintables() }
            guard let kit = made else { printablesState = .failed; speak("Oops, I couldn't make the pages. Tap to try again!"); return }
            printablesKit = kit
            // Coloring pages (Claude's call: no second question; they're for printing somewhere else, kids can color them).
            await art.generate(kit: kit, gameTitle: store.currentTitle, style: .colorIn,
                               sheetCount: kit.items.first { $0.recipe == .cutouts }.map { KitArtPrompt.cutoutLabels($0).count },
                               roles: store.plan?.roles ?? [])
            guard store.drawMode else { printablesState = .idle; return }
            let pages = KitLayout.pages(for: kit, roles: store.plan?.roles ?? [], playerCount: store.playerCount)
            let pdf = KitPrinter.pdf(pages: pages, art: art.images,
                                     cutouts: Dictionary(uniqueKeysWithValues: kit.items.map { ($0.id, art.cutoutImages($0)) }))
            let name = "PretendThat \(store.currentTitle)".replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
            do { try pdf.write(to: url, options: .atomic) } catch { printablesState = .failed; return }
            rtLog(String(format: "printables: %d pages ready in %.1f s → share sheet", pages.count, Date().timeIntervalSince(started)))
            printablesFile = url
            printablesState = .idle
            printablesShare = url
        }
    }
    @ObservationIgnored private var printablesFile: URL?
    func printablesShareClosed() { printablesShare = nil }

    // MARK: Color choice (round 20, Haylee)

    /// The Full color / I'll color them buttons: on the color step, once her question has started.
    var showsColorChoice: Bool {
        inConversation && store.planningStep == .color && !realtime.thinkingGap
    }

    /// A color button: set at once (the one source of truth); she says the planning line and starts the roles.
    func chooseColor(_ style: PrintStyle) {
        guard realtime.isLive, store.planningStep == .color else { return }
        realtime.beginTrace("tap")
        wakeUp()
        userAction(.colorChoice)
        Task { @MainActor in
            _ = await store.apply(.setPrintStyle(style))
            rtLog("print style: \(style.rawValue) (tap)")
            realtime.tapTurn(kidLine: style.label, note: ColorChoice.tapNote(style, playerCount: max(1, store.playerCount)),
                             requiring: nil, speakWithTools: true)
        }
    }

    /// "Change something": she asks what to change (one reply); the kid's answer is a normal confirm-step turn.
    func confirmChange() {
        guard realtime.isLive, store.planningStep == .confirm else { return }
        wakeUp()
        lastRecap = nil   // the fix's recap is said again even if they end up keeping the same plan
        realtime.tapTurn(kidLine: "Let's change something.", note: ConfirmStep.changeTapNote, requiring: nil)
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
        return AdventureStore.firstPropLine(item: p?.householdItem ?? "prop", becomes: p?.becomes ?? "something fun", reason: p?.reason)
    }

    /// Backup buttons on the current prop card (noisy rooms): the one planning tap.
    /// Round 13 (Haylee: taps felt slow): the card changes AT ONCE (local state first), then her line follows. No
    /// tool-first pass for what the app already knows: a swap she just says (one response); after a check-off or a
    /// skip only the next prop is hers to pick (a cheap text-only pass, then her line).
    func huntReply(found: Bool) {
        realtime.beginTrace("tap")
        guard realtime.isLive, let p = store.props?.props.first(where: { $0.id == store.currentPropID }) else { return }
        let name = p.householdItem.lowercased()
        let count = store.props?.props.count ?? 0
        let next = count >= 3 ? ["show_next_prop", "finish_planning"] : ["show_next_prop"]
        let then = count >= 3 ? "call show_next_prop for the next prop (or finish_planning if that's enough props)" : "call show_next_prop for the next prop"
        Task { @MainActor in
            if found {
                _ = await store.apply(.markFound(p.id))
                releasePointIfNoCard()
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
                releasePointIfNoCard()
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
    @ObservationIgnored private var pointingAtCard = false
    /// Round 23: the current prop card is on stage and still open (not found, not pretend).
    var activeCardOpen: Bool {
        guard let props = store.props?.props, let id = store.currentPropID,
              let i = props.firstIndex(where: { $0.id == id }) else { return false }
        return PoseRules.holdsPoint(huntActive: store.huntActive, cardShown: i < visibleProps,
                                    cardDone: store.foundProps.contains(id) || props[i].isSkipped)
    }
    /// Round 23: no open card → no point. Called whenever a hunt answer changes the cards (tap or voice).
    func releasePointIfNoCard() {
        guard pointingAtCard, !activeCardOpen else { return }
        pointTask?.cancel(); pointTask = nil
        pointingAtCard = false
        gesture(.point, hold: 0)   // back to rest in the same move as the card leaving
    }
    func pointAtCard() {
        gesture(.point, hold: 60)
        pointingAtCard = true
        pointTask?.cancel()
        pointTask = Task { @MainActor in
            for _ in 0..<160 where !realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // her line starts (≤ 8 s)
            while realtime.isSpeaking && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            pointingAtCard = false
            gesture(.point, hold: 0)   // release
        }
    }

    /// Nutmeg's voice for app-written lines. With a live Realtime session she keeps her conversation voice;
    /// during planning she speaks for herself, so app lines are skipped there.
    func speak(_ text: String, deferIfAway: Bool = false) {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lastAppLine = text }
        // Round 9: away (background, or reconnecting): an important line (kit ready) waits for the session; others drop.
        // Round D1: a replay's first lines wait for its voice session (never the device voice while it connects).
        if replayConnecting { deferredLine = text; return }
        if store.isReplay && realtime.isLive { store.ledger.paidAICall(kind: .replayLine) }   // E hook: a live replay line
        if realtime.suspended || (realtime.status == .connecting && Self.wasLive(store.phase)) || resuming {
            if deferIfAway { deferredLine = text; rtLog("line deferred until the session is back") }
            return
        }
        if realtime.isLive {
            if !planningNow {
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
        let eligible = realtime.isLive && !realtime.suspended && planningNow
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
            if store.phase == .makingKit || (store.phase == .kitReady && (!kitFinal || store.guidePending)) { beginKitBackgroundTask() }
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
        let awake = planningNow || store.phase == .makingKit || (store.phase == .kitReady && !kitPapersOut)
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
        guard let auth = realtimeAuth, store.phase != .hello, !resuming else { return }
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
        let ok = await realtime.connect(auth: auth, config: config, echoCancel: Self.echoCancel,
                                        instructions: Realtime.instructions, keepChat: true)
        if ok { realtime.addNote(store.isReplay ? Realtime.systemNote(replayNote) : Realtime.resumeNote(todayGames: todayGames, context: ctx)) }
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

    // MARK: Saved games and replays (round D1, Haylee)

    /// Reads the shelf from disk (newest first).
    func refreshShelf() {
        shelfGames = savedGames.list()
        coverCache = [:]
    }
    @ObservationIgnored private var coverCache: [UUID: UIImage] = [:]
    /// A game's shelf picture: its saved cover (the sign art), or nil (the card draws its prop stickers).
    func cover(for g: SavedGame) -> UIImage? {
        if let c = coverCache[g.id] { return c }
        guard let data = savedGames.cover(for: g), let img = UIImage(data: data) else { return nil }
        coverCache[g.id] = img
        return img
    }

    func openShelf() {
        refreshShelf()
        guard !shelfGames.isEmpty else { return }
        showingShelf = true
        rtLog("my games: shelf opened (\(shelfGames.count) saved)")
    }
    func closeShelf() { showingShelf = false }

    /// "Save it to play again": the game is written to this iPad at once (game content only), she says its title and
    /// that it's on the shelf, and the button becomes "Play it again".
    func tapSave() {
        guard store.canSave, saveState != .saving else { return }
        userAction(.saveGame)
        saveState = .saving
        let started = Date()
        let id = store.gameID
        let images = art.artByKey
        // Printer games: the sign art (it carries the place's name) is the shelf card's picture.
        let sign = store.kit?.items.first { $0.recipe == .sign }.flatMap { art.images[$0.id] }
        let printables = store.drawMode ? printablesKit?.items : nil
        Task { @MainActor in
            let (files, cover) = await Task.detached(priority: .userInitiated) { () -> ([String: Data], Data?) in
                var files: [String: Data] = [:]
                for (key, img) in images { if let d = img.heicData() ?? img.jpegData(compressionQuality: 0.9) { files[key] = d } }
                return (files, sign.flatMap { Self.coverData($0) })
            }.value
            guard store.canSave, let game = store.savedGame(id: id, art: files.keys.sorted(), cover: cover == nil ? nil : "cover.jpg",
                                                            printables: printables) else { saveState = .failed; return }
            do {
                try savedGames.save(game, art: files, cover: cover)
            } catch {
                rtLog("save: failed (\(error.localizedDescription))")
                saveState = .failed
                return
            }
            store.markSaved(game.id)
            saveState = .idle
            refreshShelf()
            rtLog(String(format: "SAVE game saved in %.2f s: %d art files, %d KB on disk, %d on the shelf", Date().timeIntervalSince(started),
                         files.count, savedGames.size(of: game.id) / 1024, shelfGames.count))
            gesture(.celebrate); celebrations += 1
            // Design: "<Title>!" then the shelf line (one app line here; separate title clips come with round D3b).
            speak("\(game.title)! It's on your shelf now. Play it again anytime!")
        }
    }

    /// A 600 px wide JPEG of the sign art for the shelf card.
    nonisolated static func coverData(_ image: UIImage) -> Data? {
        let w: CGFloat = 600, scale = w / max(image.size.width, 1)
        let size = CGSize(width: w, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.8)
    }

    /// The End's "Play it again": a replay of the game just saved, or of the game being replayed (back to Pick).
    func tapPlayItAgain() {
        let id = store.savedAs ?? store.replayGameID
        guard let id, let g = savedGames.game(id) else { return }
        userAction(.playAgain)
        Task { await startReplay(g) }
    }

    /// A card on the shelf: the replay starts (Pick: how many are playing). No AI calls for content anywhere in it.
    func tapSavedGame(_ g: SavedGame) {
        userAction(.openSavedGame)
        Task { await startReplay(g) }
    }

    /// Starts a replay: the saved art comes back from disk, the store loads the game (Pick), and the voice session
    /// (pre-connected on the start screen) speaks every line live (recorded clips are round D3b).
    func startReplay(_ g: SavedGame) async {
        cheerTask?.cancel(); repeatTask?.cancel(); pointTask?.cancel(); kitBeatTask?.cancel(); kitWait?.cancel()
        deferredLine = nil
        let files = savedGames.art(for: g)
        let decoded = await Task.detached(priority: .userInitiated) { () -> [String: UIImage] in
            var out: [String: UIImage] = [:]
            for (k, d) in files { if let img = UIImage(data: d)?.preparedForDisplay() { out[k] = img } }
            return out
        }.value
        var images: [String: UIImage] = [:], cutouts: [String: [Int: UIImage]] = [:]
        for (key, img) in decoded {
            guard let p = ArtKey.parse(key) else { continue }
            if let n = p.index { cutouts[p.itemID, default: [:]][n] = img } else { images[p.itemID] = img }
        }
        art.restore(images: images, cutouts: cutouts)
        printablesKit = nil; printablesShare = nil; printablesState = .idle
        replayGame = g
        kitBeat = .papers; kitWriting = false; kitReadySaid = true; beat = .none; shownProps = 0
        savedGames.touch(g.id)
        replayStartCalls = AICallLog.snapshot
        rtLog("REPLAY start \"\(g.title)\": \(decoded.count) art files restored, no generation; AI calls so far: \(AICallLog.summary())")
        let live = realtime.isLive
        replayConnecting = !live && realtimeAuth != nil
        showingShelf = false
        store.loadReplay(g)   // Pick; her greeting goes through speak (waits for the session if it's connecting)
        if live {
            realtime.addNote(Realtime.systemNote(replayNote))
            return
        }
        guard let auth = realtimeAuth else { flushDeferredLine(); return }
        let config = voiceConfig
        gameVoice = config
        let ok = await realtime.connect(auth: auth, config: config, echoCancel: Self.echoCancel, instructions: Realtime.instructions)
        replayConnecting = false
        guard store.isReplay, store.replayGameID == g.id else { return }   // left meanwhile
        if ok {
            realtime.addNote(Realtime.systemNote(replayNote))
            realtime.micWanted = true
            gesture(.wave)
        }
        rtLog("REPLAY voice session \(ok ? "live" : "failed: lines use the device voice")")
        flushDeferredLine()
    }

    /// The one system note a replay's session gets (title, roles, props, the current step, the scene titles).
    var replayNote: String {
        ReplayLines.note(title: store.currentTitle, roles: store.plan?.roles ?? [], players: store.playerCount,
                         props: store.props?.props ?? [], step: store.phase.step, scenes: store.fullKit?.scenes.map(\.title) ?? [])
    }

    /// DEBUG/live check: the AI calls made since the replay started (content = Claude + images).
    func logReplayCalls(_ moment: String) {
        guard store.isReplay else { return }
        let now = AICallLog.snapshot
        let d = AICallLog.Kind.allCases.map { "\($0.rawValue)=\((now[$0] ?? 0) - (replayStartCalls[$0] ?? 0))" }.joined(separator: " ")
        let content = (now[.claude] ?? 0) - (replayStartCalls[.claude] ?? 0) + (now[.image] ?? 0) - (replayStartCalls[.image] ?? 0)
        rtLog("REPLAY AI calls since start (\(moment)): \(d) → content calls: \(content)")
    }

    func replayPick(_ n: Int) {
        userAction(.replayPick)
        store.replayPick(n)
        noteReplayStep()
    }
    func replayPickDone() {
        userAction(.replayPick)
        store.replayPickDone()
        noteReplayStep()
    }
    func replayProp(_ id: String, have: Bool) {
        userAction(.replayProp)
        store.replayProp(id, have: have)
    }
    func replayUseAlternate(_ id: String) {
        userAction(.replayProp)
        store.replayUseAlternate(id)
    }
    func replayPropsDone() {
        userAction(.replayProp)
        store.replayPropsDone()
        noteReplayStep()
    }
    func replayDrawInstead() {
        userAction(.paperChoice)
        store.replayDrawInstead()
    }
    /// The pages a replay prints: the kit for the current count (or a no-printer game's saved printables).
    var replayPages: [KitPage] {
        if let items = store.replayPrintables {
            return KitLayout.pages(for: Kit(nutmegSays: "", items: items, scenes: []), roles: store.plan?.roles ?? [], playerCount: store.playerCount)
        }
        return kitPages
    }
    /// Paper on a replay: Print everything / Just the badges (the saved art, rebuilt as a PDF for this count) or Skip.
    func replayPaper(_ choice: PaperChoice) {
        userAction(.paperChoice)
        let pages = ReplayProps.pages(replayPages, for: choice)
        store.replayPaper(choice)
        guard choice != .skip else { rtLog("REPLAY paper: skip → play"); return }
        let items = store.replayPrintables ?? store.kit?.items ?? []
        let pdf = KitPrinter.pdf(pages: pages, art: art.images,
                                 cutouts: Dictionary(uniqueKeysWithValues: items.map { ($0.id, art.cutoutImages($0)) }))
        rtLog("REPLAY paper: \(choice.rawValue): \(pages.count) page(s), \(pages.flatMap(\.slots).filter { $0.role != nil }.count) badge(s) for \(store.playerCount), PDF \(pdf.count / 1024) KB")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTPDFOut") {
            try? pdf.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("replay-\(choice.rawValue).pdf"))
        }
        #endif
        KitPrinter.print(pdf, jobName: "PretendThat \(store.currentTitle)")
    }
    /// A silent note so the replay's session knows where the kids are.
    private func noteReplayStep() {
        guard store.isReplay, realtime.isLive else { return }
        realtime.addNote(Realtime.systemNote("(Silent note, don't mention it.) Replay: now on \(store.phase.step?.label ?? "Pick")"
            + (store.playerCount > 0 ? ", \(store.playerCount) playing (\(store.playingRoles.map(\.roleName).joined(separator: ", ")))" : "") + "."))
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
            // Round C1: a role's badge shows its own slice of the badge sheet.
            return PTPictureTile(image: art.badge(itemID, role: role?.id.index), placeholder: title, roleTitle: role?.roleName,
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
        if realtime.isLive { userAction(.micPressed) }
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
