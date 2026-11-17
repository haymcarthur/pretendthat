import SwiftUI
import NutmegCore
import QuartzCore
import AVFoundation
import Speech

/// Wires the state machine to Nutmeg's voice, ears and kit art. One per app run. Round D1: only games the kids choose
/// to save are kept, on this iPad (`SavedGameStore`), and only their game content; nothing about kids.
@Observable @MainActor
final class AppModel {
    let store: AdventureStore
    let listener = Listener()
    /// Round 34: Apple's on-device English speech model, downloaded in the app on iPadOS 26+.
    let speechModel = SpeechModelInstaller()
    /// Round 34: check the in-app model, and use it when the older recognizer can't listen on the device.
    func refreshSpeechModel() async {
        speechModel.onInstalled = { [weak self] in
            guard let self else { return }
            let sfOK = SFSpeechRecognizer(locale: SpeechModelInstaller.locale)?.supportsOnDeviceRecognition ?? false
            KidSpeechCapture.useAnalyzer = !sfOK
            self.listener.refresh()
        }
        await speechModel.refresh()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTSpeechModelSheet") { speechModel.showingSheet = true }
        #endif
    }
    /// Round 27 (Haylee): the kit is drawn in BOTH styles during the hunt: the full-color set and the outline set,
    /// plus one text-free bookshelf cover, all on one limiter (≤3 image calls at once). The printer prints `printArt`.
    let colorArt: KitArtService
    let outlineArt: KitArtService
    let coverArt: CoverArtService
    func artSet(_ style: PrintStyle) -> KitArtService { style == .fullColor ? colorArt : outlineArt }
    /// The set chosen on the Print screen (color by default).
    var printArt: KitArtService { artSet(store.printSet) }
    /// The sets the Print screen shows (a game saved before round 27 has one).
    var printSets: [PrintStyle] { store.availableSets }
    private func resetArt() { colorArt.reset(); outlineArt.reset(); coverArt.reset() }
    let stickers: ItemArtService
    /// Round 19: the kid-safety check (local filter, then moderation).
    @ObservationIgnored let safety: KidSafetyCheck
    /// Round 21: the remote moderation runs in parallel with her reply (the local filter stays instant and first).
    @ObservationIgnored let gate: SafetyGate
    /// The planning state from before text that is still being moderated was used (a late flag restores it).
    @ObservationIgnored private var safeSnap: AdventureStore.SafeSnapshot?
    /// Typed turns still being moderated: ticket id → (text, conversation item id), so a flag can take them back.
    @ObservationIgnored private var screenedTurns: [Int: (text: String, itemID: String)] = [:]
    /// Round D3a: Nutmeg's speaker (her voice's playback, lip sync, speaking state, app lines, Repeat's last line).
    /// Owned here so D3b's recorded clips can play without a live session; the session uses it for live audio.
    let speaker: NutmegSpeaker
    /// Hands-free planning conversation (D1, D2).
    let realtime: RealtimeSession
    /// The writing moment's quiet scribble loop (round 5).
    @ObservationIgnored let scribble = ScribbleSound()
    /// Realtime auth: a personal OPENAI_API_KEY (dev mode) or the shared relay's ephemeral secrets.
    @ObservationIgnored let realtimeAuth: RealtimeAuth?
    /// Only the IDs of last session's suggested games/themes (UserDefaults), so the next session differs. Nothing about kids.
    @ObservationIgnored private let suggestionMemory = SuggestionMemory()
    /// Round D1: saved games, on this iPad only (Application Support/SavedGames; iCloud is round D4).
    @ObservationIgnored let savedGames = SavedGameStore(root: SavedGameStore.defaultRoot())
    /// The My games shelf (newest first). The start screen shows "My games" once it isn't empty.
    var shelfGames: [SavedGame] = []
    /// The My games bookshelf screen is open (on the start screen; the phase stays Hello).
    var showingShelf = false
    /// Round D2: the Grown-ups sheet (gate, then Saved games + About saved games).
    #if DEBUG
    /// Round 25 (button audit): the driver's `#leavedialog` shows the X's leave dialog (RootView owns its state).
    var debugLeaveDialog = false
    #endif
    var showingGrownUps = false
    /// Round 33: the parent onboarding (shown once; replayable from Grown-ups). Device flags only, nothing about kids.
    @ObservationIgnored let parentSettings = ParentSettings(defaults: UserDefaults.standard)
    @ObservationIgnored let freePreview = FreePreviewCounter(defaults: UserDefaults.standard)
    /// Round 38: StoreKit (products, purchases, the entitlement) and the paid plan's new shows this month (a window key
    /// and a count on this iPad; nothing about kids).
    let purchases = PTPurchases()
    @ObservationIgnored let planShows = PlanShowCounter(defaults: UserDefaults.standard)
    /// Round 38: the relay's show counts (`RELAY_SHOW_LIMITS = YES` and the AI going through the relay); nil = off.
    @ObservationIgnored let showLimitsRelay: RelayConfig?
    /// Bumped when a show is counted, so views reading `allowance` refresh.
    var showCountVersion = 0
    #if DEBUG
    /// `-PTPlanUsed N`: at launch, this month's plan count is set to N (to reach the monthly limit quickly).
    @ObservationIgnored var debugPlanUsed: Int?
    #endif
    /// The onboarding flow on screen (nil = not showing).
    var onboarding: OnboardingFlow?
    /// Mirrors `parentSettings.aiConsent` so views update (the AI partners row, New game).
    var aiConsent = false
    /// New game (or a saved game) was blocked: the kid card on the start screen says why (no prices).
    var kidBlock: NewGameGate?
    /// The plans screen behind the gate (the Free Preview ran out).
    var showingPlans = false
    /// Anonymous usage counts (2026-11-17-analytics-build.md): this game's steps and scenes, each counted once.
    @ObservationIgnored var gameStats = AnalyticsGameTracker()
    /// When the first-launch onboarding opened (for its coarse duration bucket only).
    @ObservationIgnored var onboardingStartedAt: Date?
    /// Mirrors the grown-up's "Share anonymous usage counts" switch so the toggles update.
    var analyticsSharing = Analytics.sharing
    /// The current plan (StoreKit entitlements; none until products exist).
    var planStatus: PlanStatus = .none
    /// Nutmeg's two onboarding lines (bundled clips through her one speaker; round 35 prep).
    let onboardingVoice: OnboardingVoice
    /// The saved game being replayed (its art, for Paper).
    @ObservationIgnored var replayGame: SavedGame?
    /// The replay's voice session is connecting: its lines wait for it (never the device voice).
    @ObservationIgnored private var replayConnecting = false
    /// AI calls (Claude, images, moderation) when the replay started: the live check logs the difference.
    @ObservationIgnored private var replayStartCalls: [AICallLog.Kind: Int] = [:]
    enum SaveState: Equatable { case idle, saving, failed }
    private(set) var saveState: SaveState = .idle
    /// Round D3b: Nutmeg's recorded lines for the current game (her app lines only), the speaker's clip source.
    @ObservationIgnored let clipStore: ClipStore
    /// Round D3b: the network (an unrecorded replay line offline pauses the game with the Wi-Fi note).
    let network = NetworkWatch()
    /// Round D3b (Haylee's answer 1): offline on a replay, a line she never said: the Wi-Fi note, paused on that line.
    private(set) var wifiPause = WiFiPause()
    /// Round D3b: the replay's clip hit rate (counts only) and the Realtime usage when the replay started.
    @ObservationIgnored private(set) var clipLog = ClipHitLog()
    @ObservationIgnored private var replayUsageStart = RealtimeUsageTotals()
    @ObservationIgnored private var wifiTask: Task<Void, Never>?

    /// The planning conversation is running (a replay has no planning: its Pick and Props steps are app lines).
    var planningNow: Bool { Self.isPlanning(store.phase) && !store.isReplay }
    /// Round 26 (the fallback, so a replay can't dead-end): with no voice session (offline, or Realtime can't connect),
    /// a replay's Pick shows number tiles. With voice, the count is said out loud.
    var noVoiceSession: Bool { realtime.status != .live && realtime.status != .connecting }

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        // Anonymous usage counts: a no-op without an app ID or until a grown-up turns sharing on. First, so the debug
        // drivers (which run before the launch check) count too.
        Analytics.configure(info: info)
        let speaker = NutmegSpeaker()
        self.speaker = speaker
        realtime = RealtimeSession(speaker: speaker)
        clipStore = ClipStore(games: savedGames)
        speaker.clips = clipStore
        onboardingVoice = OnboardingVoice(speaker: speaker)
        let config = ClaudeConfig.from(info: info)
        // Round 19: kid text and generated text are checked locally and with OpenAI moderation (fails safe to local).
        let moderation = ModerationClient.from(info: info)
        safety = KidSafetyCheck(moderator: moderation)
        gate = SafetyGate(check: safety)
        var service = config.map { PhaseService(llm: ClaudeClient(config: $0), moderator: moderation) }
        #if DEBUG
        if DemoDriver.requestedPhase != nil { service = nil }   // demo screens use the bundled game, no network
        let noAI = ProcessInfo.processInfo.arguments.contains("-PTNoAI")   // round 38 UI tests: no AI calls at all
        if noAI { service = nil }
        #endif
        store = AdventureStore(service: service)
        store.holdsEarlyFinish = true   // round 30: a firm prop count (4 for 1–2 kids, 5 for 3+)
        store.propMemory = RecentPropMemory()   // round 30: prop IDs of the last ~5 games (IDs only)
        var images = ImageClient.from(info: info)
        #if DEBUG
        // Demo screens skip paid image calls unless asked: -PTDemoArt 1
        if DemoDriver.requestedPhase != nil, !ProcessInfo.processInfo.arguments.contains("-PTDemoArt") { images = nil }
        if noAI { images = nil }
        #endif
        let limiter = AsyncLimiter(limit: KitArtService.concurrency)   // round 27: one limiter for both sets + the cover
        colorArt = KitArtService(client: images, style: .fullColor, limiter: limiter)
        outlineArt = KitArtService(client: images, style: .colorIn, limiter: limiter)
        coverArt = CoverArtService(client: images, limiter: limiter)
        stickers = ItemArtService(client: images)
        var rtAuth = RealtimeAuth.from(info: info)
        #if DEBUG
        if noAI { rtAuth = nil }
        #endif
        realtimeAuth = rtAuth
        if RelayShows.enabled(info: info), case .relay? = config?.mode { showLimitsRelay = RelayConfig.from(info: info) } else { showLimitsRelay = nil }
        // Round 20: the Grown-ups voice settings are gone; drop what older builds stored for them (device settings only).
        for k in ["voice", "method", "pitchCents", "rate", "speed", "echo"] { UserDefaults.standard.removeObject(forKey: "nutmeg.v4.\(k)") }
        realtime.onTurnDone = { [weak self] text in
            guard let self, self.planningNow, !self.realtime.propLinePending else { return nil }
            // Round 34: an app-written prop line is a complete turn (never nudged).
            if self.appPropLines.contains(ClipText.normalize(text)) { return nil }
            // Round 7: roles set but no prop yet → she continues straight into the first prop (no "Sound good?" wait).
            return TurnCheck.review(text, step: self.store.planningStep, rolesSet: self.store.plan != nil,
                                    propsShown: self.store.props?.props.count ?? 0, currentPropDone: self.store.currentPropDone,
                                    propTarget: self.store.propTarget)
        }
        realtime.onSilence = { [weak self] in
            guard let self, self.planningNow, self.store.planningStep != .finish else { return nil }
            return TurnCheck.silenceLine   // spoken only, never in the chat (round 7)
        }
        realtime.onPlanningBeat = { [weak self] topic in await self?.planningBeat(topic) }
        realtime.onPropLine = { [weak self] in self?.revealFirstProp() ?? "" }
        realtime.onSilentPassDone = { [weak self] in self?.noteAfterSilentPass() }
        realtime.onKidTranscript = { [weak self] text in self?.spokenSafetyCheck(text) }
        // Round 31: a spoken turn's words (on-device, name-scrubbed) go through the same gate as a typed turn: the local
        // filter first, moderation in parallel with her reply. Then ONE text item.
        realtime.onSpokenWords = { [weak self] text in Task { await self?.typed(text, kind: .spoken) } }
        // Round 31: on-device speech turned out to be missing (a recognition error said so): typing, with the note.
        let markOff: @Sendable () -> Void = { [weak self] in Task { @MainActor in self?.speechUnavailableNow() } }
        realtime.capture.onUnavailable = markOff
        listener.capture.onUnavailable = markOff
        // Round D3b: her app lines that passed the transcript gate are kept with the game (unsaved: until Save).
        realtime.onRecorded = { [weak self] line in
            guard let self else { return }
            self.clipStore.store(line, roles: self.store.plan?.roles ?? [])
        }
        realtime.onRecordRejected = { [weak self] _ in self?.clipLog.rejectedOne() }
        realtime.recordRoles = { [weak self] in self?.store.plan?.roles }
        clipStore.onStored = { [weak self] _ in if self?.store.isReplay == true { self?.clipLog.savedOne() } }
        store.isRecorded = { [weak self] line in self?.clipStore.has(line) ?? false }
        network.onChange = { [weak self] online in self?.networkChanged(online) }
        gate.onFlag = { [weak self] verdict, ticket in self?.lateFlag(verdict, ticket) }
        gate.onAllClear = { [weak self] in self?.safeSnap = nil; self?.screenedTurns = [:] }
        store.outboundGate = { [weak self] in await self?.gate.cleared() ?? true }
        // Tool-first kid turns (round 7): no narration is ever heard; she speaks after the tool result.
        realtime.onKidTurnTools = { [weak self] in
            guard let self else { return nil }
            if self.store.isReplay { return ReplayLines.tools(self.store.phase) }   // round D1
            if self.store.gameLocked && self.store.phase == .players { return Realtime.pickBackTools }   // round 28: back on Pick
            guard self.planningNow else {
                return Realtime.afterHuntTools(self.store.phase)   // round 23
            }
            return Realtime.kidTurnTools(step: self.store.planningStep, huntActive: self.store.huntActive)
        }
        realtime.onPostPlanningTurn = { [weak self] in
            guard let self else { return nil }
            switch self.store.phase {
            case .kitReady:
                return "(Silent coaching, don't mention it.) The kit is ready on screen (print step). If they want to play, "
                    + "call start_play; if they want to print, call print_kit. " + BackNav.voiceHint
                    + " Otherwise answer in ONE short line. No \"go play\" yet."
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
        #if DEBUG
        applyDebugLaunchFlags()   // round 33: before any driver runs
        #endif
        aiConsent = parentSettings.aiConsent
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
        // Round 33: no AI connection at all before the grown-up's consent (5.1.2(i)).
        guard let auth = realtimeAuth, store.phase == .hello, aiConsent, onboarding == nil else { return }
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
        onboardingVoice.stop()
        // Round 38: the relay's anonymous show count (only when deployed with it; unknown or offline = allow).
        guard await relayAllowsNewShow() else {
            if onboarding?.finished == true { onboarding = nil }
            kidBlock = purchases.entitlement == nil ? .needsPlan : .outOfShows
            return
        }
        // Round 33 / 38: a NEW game counts toward the Free Preview or the plan's month (replays never do).
        countNewShow()
        gameStats.begin(kind: .new)
        Analytics.send(.newGameStarted)
        // Consent was given later in Grown-ups (the onboarding's mic screen was skipped): the system prompts now.
        if AVAudioApplication.shared.recordPermission == .undetermined { await listener.requestAuth() }
        store.beginConversation()
        // Onboarding v2: "Start our first game" kept the onboarding up until now; the stage replaces it in this update.
        if onboarding?.finished == true { onboarding = nil }
        clipStore.startFirstPlay()   // round D3b: her app lines are recorded for this game (kept only if it's saved)
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
            openGreeting(games: games)
            startDozeWatch()
        } else {
            if let e = gameStats.error(.voiceConnectFailed) { Analytics.send(e) }
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
            speaker.say(line, record: false)   // round D3b: a safety steer is never kept with a game
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
        repeatTask?.cancel(); repeatTask = nil
        deferredLine = nil
        realtime.stopSpeaking(action.rawValue)
    }

    /// Round 29 (Haylee, ensemble scenes): the big green ▶ "Next scene" (after the last scene, The End). It stops her
    /// at once (barge-in) and the store says the next scene's setup and tasks.
    func tapNextScene() {
        guard case .scene = store.phase else { return }
        userAction(.nextScene)
        rtLog("scene: next (tap)")
        store.nextScene()
    }
    /// Round 29: a row's 🔊 reads just that role's task (her recorded clip if this game has one, else live once and
    /// saved, D3b). Any tap stops what she was saying first.
    func readTask(_ index: Int, wholeRole: Bool = false) {
        guard case .scene(let i) = store.phase, let rows = store.kit?.scenes[i].steps, rows.indices.contains(index) else { return }
        userAction(.readTask)
        wakeUp()
        // Round 37: by voice ("what do I do?") a role with several setup / clean-up rows hears all of them.
        let line = wholeRole ? (SceneRowTap.roleLine(rows: rows, index: index) ?? HandOffLines.task(rows[index])) : HandOffLines.task(rows[index])
        rtLog("scene: read task \(index + 1)/\(rows.count)")
        speak(line)   // straight to the voice (not through nutmegLine), so the same task can be heard twice
    }
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
    func tapPrint() { guard printArt.finished else { return }; userAction(.print); printKit() }   // round 27: the chosen set
    func tapStepRail(_ step: JourneyStep) {
        userAction(.stepRail)
        let queued = store.playQueued
        navigate(to: step)
        if !queued && store.playQueued { guideWaitStarted() }
    }
    /// Round 23: a tap back to a step on the rail: the same `store.goTo`, then her one arrival line, and a silent
    /// note so the conversation knows where the kids are. Voice uses go_to_step (the model says the line itself).
    func navigate(to step: JourneyStep) {
        // Round 25 (Haylee): at The End, Play (finished, ↺) reopens the last scene; round 29: the store says the scene.
        let toLastScene = step == .play && store.phase == .end
        // Round 26: a replay's Props restarts its one-card hunt and the store says the first card's line.
        let storeSays = (store.isReplay && step == .getReady) || toLastScene
        guard store.goTo(step) else { return }
        if storeSays {
            rtLog("back-nav: \(step.label) (tap, \(toLastScene ? "the last scene again" : "replay hunt again"))")
            if toLastScene { realtime.addNote(Realtime.systemNote(BackNav.tapNote(step, line: store.nutmegLine))) } else { noteReplayStep() }
            return
        }
        let line = store.arrivalLine(step)   // round 28: Pick names the game
        rtLog("back-nav: \(step.label) (tap)")
        if realtime.isLive {
            realtime.addNote(Realtime.systemNote(BackNav.tapNote(step, line: line)))
            speaker.remember(line)
            speaker.say(line)
        } else {
            speak(line)
        }
    }
    /// New game goes all the way home: the session hangs up, so nothing keeps talking on the start screen.
    func tapNewGame() { userAction(.newGame); leave() }

    /// Leave activity: hang up and go home. Nothing is kept.
    func leave() {
        userAction(.goHome)
        if store.isReplay { logReplayClips("left") }
        repeatTask?.cancel(); pointTask?.cancel(); beatEndTask?.cancel(); kitWait?.cancel()
        speaker.holdEngine = false   // round D3b: the session's stop now stops the engine too
        wifiPause.clear(); wifiTask?.cancel(); wifiTask = nil
        clipStore.reset()            // an unsaved game's clips go with it
        realtime.disconnect()
        speaker.shutdown()
        gameVoice = nil
        kitReadySaid = false; deferredLine = nil; doze.wake(); dozeStage = .awake; wokePop = false; endKitBackgroundTask()
        huntStartedAt = nil; printReachedAt = nil
        shownProps = 0; beat = .none; kitBeatTask?.cancel(); kitBeat = .coloring; papersShown = false; kitWriting = false; kitWritingTask?.cancel(); kitWritingTask = nil
        resetArt()
        stickers.reset()
        gate.reset(); safeSnap = nil; screenedTurns = [:]
        replayGame = nil; replayConnecting = false; saveState = .idle
        // Round 37: the game just played stays reportable from Grown-ups → Report a problem until the app quits (in
        // memory only: its title and AI-made text, never anything about the kids).
        if let k = store.fullKit, !(k.items.isEmpty && k.scenes.isEmpty) {
            lastPlayedReport = ContentReport.Game(id: "last", title: store.currentTitle, kit: k)
        }
        store.newGame()
    }
    /// Round 37: the last game played this launch, for Grown-ups → Report a problem (memory only).
    var lastPlayedReport: ContentReport.Game?
    /// "1.0 (1)" for a report email.
    static var appVersion: String {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "?") (\(i?["CFBundleVersion"] as? String ?? "?"))"
    }

    /// Round 31: where a kid's words came from (both are text by the time they get here).
    enum KidWords { case typed, spoken }

    /// Typed fallback goes into the live conversation when there is one. Round 31: a SPOKEN turn's words (heard on the
    /// iPad, name-scrubbed) come through here too, so they get exactly the typed turn's safety gate.
    func typed(_ text: String, kind: KidWords = .typed) async {
        // Round 21: the trace starts at the send itself (the safety check included). A spoken turn's trace started at
        // the release (the on-device words are part of its latency).
        if kind == .typed { realtime.beginTrace("typed") } else { realtime.markTrace("scrubbed") }
        wakeUp()
        // Round 20: the kid's own turn stops anything she's saying or about to say (cheers, repeats, deferred lines).
        if realtime.isLive && store.phase != .makingKit { userAction(kind == .typed ? .typedTurn : .micPressed) }
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
            realtime.sendText(text, itemID: itemID, kind: kind == .typed ? "typed" : "voice")   // planning, print, play
            return
        }
        // Not sent to the voice model: wait for moderation before anything uses it (Claude, the kit).
        guard await gate.cleared() else { return }
        // Kit being made (round 7): a tiny "Almost ready!" at most, never a new conversation turn.
        if realtime.isLive && store.phase == .makingKit { if !realtime.isSpeaking { speaker.say("Almost ready!") }; return }
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
        watchStory()
        sendPhaseAnalytics()
        // Round 19: home (the start screen) is always silent.
        if store.phase == .hello {
            if realtime.status != .idle { realtime.disconnect() }
            repeatTask?.cancel(); deferredLine = nil
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
                         colorArt.images.count + colorArt.cutouts.values.map(\.count).reduce(0, +), pages))
            trackArtTimings()
        }
        // (A fast kit can skip straight to kitReady between two observations; it still gets its writing beat.)
        // Round 28 (Haylee): back to Print (step rail) once the papers came out: no writing beat, the pages at once.
        if store.phase == .kitReady && papersShown { kitBeat = .papers }
        if (store.phase == .makingKit || store.phase == .kitReady) && kitBeat == .coloring && !kitWriting && kitWritingTask == nil && !papersShown {
            startKitWriting()
        }
        if !(store.phase == .makingKit || store.phase == .kitReady) { kitWritingTask?.cancel(); kitWritingTask = nil; kitWriting = false }
    }

    /// Round 28 (Haylee): the scribble sound started before Nutmeg was visibly writing (the camera was still moving in
    /// and the pose swap waits for it). Now it starts only once the writing shot has settled with the writing pose on
    /// screen, and stops the moment she leaves the pose.
    static let writingShotSettle: Duration = .milliseconds(1100)
    static let writingShotSettleReduced: Duration = .milliseconds(400)
    /// The writing pose is on screen and the camera has settled (the scribble plays only while this is true).
    private(set) var writingOnScreen = false
    @ObservationIgnored private var writingShotTask: Task<Void, Never>?
    func writingChanged(_ on: Bool, reduceMotion: Bool = false) {
        writingShotTask?.cancel(); writingShotTask = nil
        guard on else {
            writingOnScreen = false
            scribble.setPlaying(false, ducked: false)
            return
        }
        let settle = reduceMotion ? Self.writingShotSettleReduced : Self.writingShotSettle
        writingShotTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: settle)
            guard let self, !Task.isCancelled, self.isWriting else { return }
            self.writingOnScreen = true
            self.scribble.setPlaying(true, ducked: self.isSpeaking)
            rtLog("scribble: on (the writing shot settled)")
        }
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
        // Round 19: the CURRENT title (a corrected theme wins over the one the roles were planned with).
        let title = store.currentTitle
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTLive") { rtLog("KIT for \(title): \(kit.items.map(\.title).joined(separator: " | "))") }
        #endif
        // Round 20: the hunt's themed cut-outs were one sheet; the skipped props' cut-outs after them are drawn one each.
        let sheet = store.draftItems?.first { $0.recipe == .cutouts }.map { KitArtPrompt.cutoutLabels($0).count }
        // Round 27: both sets (color first: it's the default, and the limiter is FIFO).
        let roles = store.plan?.roles ?? []
        Task { await colorArt.generate(kit: kit, gameTitle: title, sheetCount: sheet, roles: roles) }
        Task { await outlineArt.generate(kit: kit, gameTitle: title, sheetCount: sheet, roles: roles) }
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
            resetArt()
        }
        guard let items = store.draftItems else { return }
        if let started = store.draftStartedAt, let ready = store.draftReadyAt {
            rtLog(String(format: "TIMING kit pages written during the hunt in %.1f s", ready.timeIntervalSince(started)))
        }
        // Round 27: both sets, then the cover (queued last on the shared limiter).
        colorArt.prepare(items: items, gameTitle: store.currentTitle, roles: store.plan?.roles ?? [])
        outlineArt.prepare(items: items, gameTitle: store.currentTitle, roles: store.plan?.roles ?? [])
        coverArt.start(title: store.currentTitle, setting: store.plan?.setting)
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
                let art = printArt   // round 27: the chosen set
                let pending = (store.kit?.items ?? store.draftItems ?? []).filter { item in
                    item.recipe == .cutouts ? art.cutoutImages(item).contains { $0 == nil }
                        : item.recipe == .badges ? art.badge(item.id, role: 0) == nil   // round C1: the sheet or the shared badge
                        : art.images[item.id] == nil
                }.compactMap(\.recipe)
                let topics = guideWait && kitFinal ? [KitProgress.Topic.checklists]
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

    // MARK: Repeat during a scene (round 29)

    /// Round 29 (Haylee): "Hear it again" (the pill) during a scene re-reads the whole scene: the setup and every playing
    /// role's task, in one line. It waits for anything she's saying to finish; repeated taps are ignored while one is
    /// queued or just sent: one reply per tap.
    func repeatScene() {
        guard case .scene(let i) = store.phase, let line = store.sceneLine(i) else { return }
        guard repeatTask == nil, Date().timeIntervalSince(lastRepeatAt) > 2.5 else { return }
        userAction(.repeatLine)
        lastRepeatAt = Date()
        wakeUp()
        repeatTask = Task { @MainActor in
            defer { repeatTask = nil }
            guard !Task.isCancelled, case .scene(i) = store.phase else { return }
            lastRepeatAt = Date()
            rtLog("scene repeat: \(i + 1)")
            speak(line)
            if store.inStory { watchStory() }   // round 36: the story told again; the setup waits for its end
        }
    }
    @ObservationIgnored private var repeatTask: Task<Void, Never>?
    @ObservationIgnored private var lastRepeatAt = Date.distantPast

    // MARK: The story opener (round 36)

    /// Round 36 (Haylee): after printing, Nutmeg tells the story on stage (no card, no rows); when she has finished it,
    /// the setup scene opens by itself. The ▶ / "next scene" skip it; Repeat tells it again (and the wait starts over).
    /// No voice at all (offline, no clip): it moves on after a short pause instead of leaving the kids on an empty stage.
    func watchStory() {
        storyTask?.cancel(); storyTask = nil
        guard store.inStory, case .scene(let i) = store.phase else { return }
        storyTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var started = false
            // A line cut off by the tap that started play may still be fading out (≤ 1.5 s; a story clip that's
            // already playing is simply still playing after it).
            for _ in 0..<15 where !Task.isCancelled && self.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
            for _ in 0..<120 where !Task.isCancelled {   // her line starts (≤ 12 s: a live line takes a moment, a clip at once)
                if self.isSpeaking { started = true; break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            while !Task.isCancelled && (self.isSpeaking || self.wifiPause.isPaused || self.repeatTask != nil) {
                try? await Task.sleep(for: .milliseconds(100))
            }
            try? await Task.sleep(for: .seconds(started ? 0.9 : 1.5))
            guard !Task.isCancelled, case .scene(i) = self.store.phase, self.store.inStory, !self.isSpeaking else { return }
            rtLog("story: told (\(started ? "heard" : "no voice")), on to the setup scene")
            self.store.nextScene()
        }
    }
    @ObservationIgnored private var storyTask: Task<Void, Never>?

    // MARK: Repeat in the control pill (round 17, Haylee)

    /// The last line the app gave her to say (the fallback when there's no chat transcript, e.g. the device voice).
    /// Round D3a: the speaker's memory.
    var lastAppLine: String? { speaker.lastAppLine }
    /// What the pill's Repeat ("Hear it again") does right now; `.none` dims it (nothing yet, or she's busy).
    var repeatTarget: RepeatTarget {
        let inScene: Bool = { if case .scene = store.phase, !store.huntActive { return true } else { return false } }()
        // Round 29: in a scene Repeat is a tap like the 🔊 (it cuts her off), so only the mic or a queued repeat dims it.
        let busy = inScene ? (micState == .listening || repeatTask != nil)
            : isSpeaking || micState == .listening || repeatTask != nil
            || (realtime.isLive && (realtime.isBusy || realtime.thinkingGap))
        let last = realtime.transcript.last(where: \.fromNutmeg)?.text
        return RepeatTarget.choose(inScene: inScene, busy: busy, transcriptLast: last, appLast: lastAppLine)
    }
    /// The pill's Repeat: the whole scene again during play (round 29), else her last line again, in the same app
    /// line path and voice (no duplicate chat bubble). Debounced: one repeat per tap.
    func repeatTapped() {
        rtLog("repeat tapped: \(repeatTarget)")
        switch repeatTarget {
        case .none: return
        case .scene: repeatScene()
        case .lastLine(let line):
            guard Date().timeIntervalSince(lastRepeatAt) > RepeatTarget.debounce else { return }
            if realtime.isLive && realtime.voiceBusy { return }
            userAction(.repeatLine)
            lastRepeatAt = Date()
            wakeUp()
            rtLog("repeat last line: \(line)")
            // Round D3b: Repeat replays the clip (her recorded voice), or says it live; never the device voice on a replay.
            if realtime.isLive || clipStore.has(line) { speaker.say(line, echo: true, replay: store.isReplay) }
            else if store.isReplay { owe(line) }
            else { rtLog("repeat: no clip and no live voice: she stays quiet (never the system voice)") }
        }
    }
    @ObservationIgnored private var kitWait: Task<Void, Never>?

    /// Kit step beats (no-text-overlays.md, fix round 2): she colors in the close-up until the WHOLE kit is final, then
    /// looks up (crayon down), the camera zooms out, and the papers fly off her clipboard.
    var kitBeat: PTStageDirector.KitBeat = .coloring
    /// Round 28: this kit's papers have come out once (back to Print shows them at once, no writing beat).
    @ObservationIgnored var papersShown = false
    @ObservationIgnored private var kitBeatTask: Task<Void, Never>?
    /// The printable pages for the current kit.
    var kitPages: [KitPage] {
        guard let kit = store.kit else { return [] }
        return KitLayout.pages(for: kit, roles: store.plan?.roles ?? [], playerCount: store.playerCount)
    }
    /// Print (single tap, decisions/2026-11-13-single-tap-print.md): the whole kit as one PDF to the iOS print screen.
    func printKit() {
        let art = printArt   // round 27: the chosen set, for the current player count
        if let e = gameStats.printed(store.printSet, players: store.playerCount) { Analytics.send(e) }
        rtLog("print: the \(store.printSet.toolValue) set, \(kitPages.count) page(s)")
        let pdf = KitPrinter.pdf(pages: kitPages, art: art.images,
                                 cutouts: Dictionary(uniqueKeysWithValues: (store.kit?.items ?? []).map { ($0.id, art.cutoutImages($0)) }))
        KitPrinter.print(pdf, jobName: "PretendThat \(store.currentTitle)")
    }
    /// The papers are out (kit final, she looked up, the camera zoomed out).
    var kitPapersOut: Bool { kitFinal && kitBeat == .papers }

    /// Every page's art has landed or definitively fallen back.
    /// Round 27: the papers come out once one set is final (color first, normally); a set still drawing shows its
    /// progress on the Print screen and its printer waits for it.
    var kitFinal: Bool { store.phase == .kitReady && store.kit != nil && (colorArt.finished || outlineArt.finished) }
    /// Round 27: the chosen set is final, so the printer can print it.
    var printReady: Bool { kitFinal && printArt.finished }
    /// Round 27: a page of `set` whose art hasn't landed while the set is still drawing (shown in progress).
    func pageDrawing(_ page: KitPage, in set: KitArtService) -> Bool {
        guard !set.finished else { return false }
        let item = page.item
        if item.recipe == .cutouts { return set.cutoutImages(item).contains { $0 == nil } }
        if item.recipe == .badges { return set.badge(item.id, role: 0) == nil }
        return set.images[item.id] == nil
    }
    /// Round 27: a set tapped on the Print screen.
    func tapPrintSet(_ style: PrintStyle) {
        guard store.printSet != style, store.choosePrintSet(style) else { return }
        userAction(.print)
        rtLog("print set: \(style.toolValue) (tap)")
        if realtime.isLive {
            realtime.addNote(Realtime.systemNote("(Silent note, don't mention it.) The kids tapped \(style.setName) on the Print screen: that set is chosen."))
        }
    }
    /// Round 27 DEBUG: when each set and the cover settled, against the hunt start and Print, and the image calls.
    @ObservationIgnored private var artTimingTask: Task<Void, Never>?
    private func trackArtTimings() {
        artTimingTask?.cancel()
        let hunt = huntStartedAt ?? Date(), print = printReachedAt ?? Date()
        artTimingTask = Task { @MainActor in
            var logged: Set<String> = []
            for _ in 0..<1200 where !Task.isCancelled && logged.count < 3 {
                let marks: [(String, Date?)] = [("color", colorArt.finishedAt), ("outline", outlineArt.finishedAt), ("cover", coverArt.settledAt)]
                for (name, at) in marks where !logged.contains(name) {
                    guard let at else { continue }
                    logged.insert(name)
                    rtLog(String(format: "TIMING r27 %@ ready %.1f s after the hunt started (%+.1f s vs Print)%@", name,
                                  at.timeIntervalSince(hunt), at.timeIntervalSince(print), name == "cover" && coverArt.failed ? " FAILED" : ""))
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            // The last image of each set really landed (the set is only "final" once the hunt is over).
            for (name, set) in [("color", colorArt), ("outline", outlineArt)] {
                if let last = set.landedAt.values.max() {
                    rtLog(String(format: "TIMING r27 %@ last image landed %.1f s after the hunt started (%+.1f s vs Print)", name,
                                 last.timeIntervalSince(hunt), last.timeIntervalSince(print)))
                }
            }
            let u = ImageUsageLog.snapshot(since: hunt.addingTimeInterval(-120))
            rtLog(String(format: "TIMING r27 images: %d requests, peak %d/min, %d 429s, %d in + %d out tokens = $%.3f",
                         u.requests, u.peakPerMinute, u.rateLimited, u.inputTokens, u.outputTokens, u.dollars))
        }
    }
    func kitFinalChanged(_ final: Bool) {
        // Round D1: a replay's Paper step has its own choices (no writing beat, no ready line).
        if store.isReplay { kitBeatTask?.cancel(); return }
        #if DEBUG
        // `-PTPDFOut`: write the print-path PDF (exactly what AirPrint gets) to tmp/kit.pdf once the kit is final.
        if final, ProcessInfo.processInfo.arguments.contains("-PTPDFOut") {
            let art = printArt
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
        // Round 28 (Haylee): leaving Print for Play (kitFinal goes false) and coming back must show the pages at once:
        // the writing beat only plays while pages are still being made. `papersShown` is cleared on a remake / new game.
        guard final else { if !papersShown { kitBeat = .coloring }; return }
        if papersShown { kitWriting = false; kitBeat = .papers; return }
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
            papersShown = true
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
            let ready = AdventureStore.kitReadyLine
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
        // Round 34: "what do I do, Pet Trainer?": the app reads that row's spoken task (same as tapping the row).
        if case .readJob = call {
            let out = await store.apply(call)
            if let k = store.lastReadJobRow { store.lastReadJobRow = nil; rtLog("scene: read job (voice) row \(k + 1)"); readTask(k, wholeRole: true) }
            return (out, false)
        }
        // Round 34 (Haylee): on a live first play the app writes and says the prop lines (recorded as clips), so a
        // replay of the saved game says the same words.
        store.appSaysPropLines = realtime.isLive && !store.isReplay
        // Round 29: "next scene" / "we're done" in a scene: the same as the green ▶ (the app says the next scene).
        if case .nextScene = call {
            guard case .scene = store.phase else { return ("There's no scene right now. Answer in ONE short line.", true) }
            rtLog("scene: next (voice)")
            userAction(.nextScene)
            store.nextScene()
            return ("Next scene: the app moves on and says its line. Say nothing.", false)
        }
        // (Round 26: a replay's Print is the first play's, so "print it" prints every page for the current count.)
        if case .printKit = call, store.phase.step != .play {
            guard store.phase == .kitReady || kitFinal else { return ("Not yet: the kit isn't ready. Say only \"Almost ready!\"", true) }
            // Round 27: the chosen set is still drawing: the printer waits for it.
            if store.phase == .kitReady, !printArt.finished {
                return ("Not yet: \(store.printSet.setName) are still being drawn. Say only \"Almost ready! Those pages are still drawing.\"", true)
            }
            printKit()
        }
        if case .goToStep(let step) = call { rtLog("back-nav: \(step.label) (voice)") }
        let reopensLastScene: Bool = { if case .goToStep(.play) = call { return store.phase == .end } else { return false } }()
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
        let remakes = store.kitRemakes
        let queued = store.playQueued
        let output = await store.apply(call)
        // Round 26: a replay's count or hunt answer by voice: the app already said the next line.
        if output == ReplayLines.appSaysOutput {
            noteReplayStep()   // the count, or the next card
            return (output, false)
        }
        if !queued && store.playQueued { guideWaitStarted() }   // guide prefetch: start_play / go to Play while it's finishing
        releasePointIfNoCard()   // round 23: mark_found / skip_prop / finish_planning by voice
        if store.kitRemakes != remakes {
            // Round 19: a theme/game fix at the print step remakes the kit: the old pages' art and ready line go too.
            remakeKitArt()
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
            // Round 34: the app says this prop's line (cheer / pretend lead + the ask) once her turn is quiet; she says
            // nothing (the tool output told her the words).
            if let line = store.takePendingPropLine() {
                sayAppPropLine(line)
                return (output, false)
            }
        }
        if store.props == nil { shownProps = 0 }
        // finish_planning and start_play end her turn: the app speaks the kit and scene lines.
        // Round 29: back to the play step at The End reopens the last scene and the app says it, so she doesn't.
        // Round 30: an early finish_planning (fewer props than the game's firm count) was refused: she goes on with
        // the next prop, so her turn continues.
        let finished = call == .finishPlanning && store.planningStep == .finish
        return (output, !finished && call != .startPlay && !reopensLastScene)
    }

    /// Round 19: the kit is being remade for a corrected title: drop the old art and beats so the new kit runs fresh.
    private func remakeKitArt() {
        rtLog("kit: remade for a corrected title")
        resetArt()
        kitReadySaid = false; deferredLine = nil
        kitBeatTask?.cancel(); kitBeat = .coloring; papersShown = false
    }

    // MARK: Confirm step (round 19, Haylee)

    /// The recap she was last told to say word for word (a new one is only sent when it changed).
    @ObservationIgnored private var lastRecap: String?
    /// After a tool-first pass on the confirm step: the newest recap, word for word (only when it changed).
    func noteAfterSilentPass() -> String? {
        guard planningNow, store.planningStep == .confirm else { lastRecap = nil; return nil }
        let recap = store.recapLine
        guard recap != lastRecap else { return nil }
        lastRecap = recap
        return ConfirmStep.sayRecapNote(recap)
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
        // Round 34: the app says the first prop line itself (recorded, so a replay says the same words); the session
        // gets a silent note so the conversation knows what was asked, and asks her for nothing.
        store.appSaysPropLines = realtime.isLive && !store.isReplay
        if store.appSaysPropLines, let line = store.firstPropAppLine {
            realtime.addNote(Realtime.systemNote("(Silent note, don't mention it.) The app said the first prop line for you, in "
                + "your voice: \"\(line)\" Wait for the kids: found → mark_found then show_next_prop; missing → swap_prop "
                + "(one alternate) or skip_prop, then show_next_prop."))
            sayAppPropLine(line, now: true)
            return ""
        }
        return AdventureStore.firstPropLine(item: p?.householdItem ?? "prop", becomes: p?.becomes ?? "something fun", reason: p?.reason)
    }

    /// Round 34: the prop lines the app said this hunt (normalized), so the turn check doesn't nudge after them.
    @ObservationIgnored private var appPropLines: Set<String> = []
    /// Round 34 (Haylee): a prop line written by the app (`PropLines`), in her voice: her recorded clip if this game has
    /// one, else live through `sayExactly`, recorded with the game (D3b). It waits for her turn to go quiet first.
    func sayAppPropLine(_ line: String, now: Bool = false) {
        appPropLines.insert(ClipText.normalize(line))
        speaker.remember(line)
        Task { @MainActor in
            if !now {
                for _ in 0..<200 where realtime.isSpeaking || realtime.isBusy || beat != .none { try? await Task.sleep(for: .milliseconds(50)) }   // ≤ 10 s
            }
            guard store.huntActive, realtime.isLive else { return }
            rtLog("PROPLINE app says: \(line)")
            speaker.say(line)
        }
    }

    /// Backup buttons on the current prop card (noisy rooms): the one planning tap.
    /// Round 13 (Haylee: taps felt slow): the card changes AT ONCE (local state first), then her line follows. No
    /// tool-first pass for what the app already knows: a swap she just says (one response); after a check-off or a
    /// skip only the next prop is hers to pick (a cheap text-only pass, then her line).
    func huntReply(found: Bool) {
        realtime.beginTrace("tap")
        // Round 25: only while the hunt is on (a stray tap after it ended re-ran finish_planning and remade the kit).
        guard realtime.isLive, store.huntActive, let p = store.props?.props.first(where: { $0.id == store.currentPropID }) else { return }
        let name = p.householdItem.lowercased()
        let count = store.props?.props.count ?? 0
        // Round 30 (Haylee): a firm count (4 props for 1–2 kids, 5 for 3+): the last one goes straight to finish_planning.
        let last = count >= store.propTarget
        let next = last ? ["finish_planning"] : ["show_next_prop"]
        let then = last ? "call finish_planning (that was the last prop; the app says the kit line)"
            : "call show_next_prop for the next prop (prop \(count + 1) of \(store.propTarget))"
        // Round 34: the app says the next prop line itself (with the cheer or the pretend lead): she only picks it.
        store.appSaysPropLines = !store.isReplay
        let appLines = store.appSaysPropLines && !last
        Task { @MainActor in
            if found && appLines {
                _ = await store.apply(.markFound(p.id))
                releasePointIfNoCard()
                realtime.tapTurn(kidLine: "We found the \(name)!",
                                 note: "(Silent coaching, don't mention it.) The kids tapped the green check (found it): the \(name) is ALREADY checked off "
                                    + "on screen (don't call mark_found). \(then) now and say NOTHING: the app cheers and says the new prop's line.",
                                 requiring: next)
            } else if found {
                _ = await store.apply(.markFound(p.id))
                releasePointIfNoCard()
                realtime.tapTurn(kidLine: "We found the \(name)!",
                                 note: last
                                    ? "(Silent coaching, don't mention it.) The kids tapped the green check (found it): the \(name) is ALREADY checked off "
                                        + "on screen (don't call mark_found). It was the LAST prop: call finish_planning now and say nothing."
                                    : "(Silent coaching, don't mention it.) The kids tapped the green check (found it): the \(name) is ALREADY checked off "
                                        + "on screen (don't call mark_found). Say nothing yet: \(then) FIRST, then cheer in a few words and ask "
                                        + "about the new prop in the same turn. Never narrate.",
                                 requiring: next)
            } else if !p.isSkipped, !(p.swapped ?? false), let alt = p.alternates?.first(where: { PropLibrary.contains($0) }) {
                _ = await store.apply(.swapProp(oldID: p.id, newID: alt, becomes: ""))
                let altName = (PropLibrary.name(alt) ?? alt).lowercased()
                realtime.tapTurn(kidLine: "We don't have a \(name).",
                                 note: "(Silent coaching, don't mention it.) The kids tapped the X (don't have it). The card ALREADY changed to "
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
                                 note: appLines
                                    ? "(Silent coaching, don't mention it.) The kids tapped the X again (don't have it): the \(name) is ALREADY "
                                        + "marked as pretend on screen (don't call skip_prop or swap_prop). \(then) now and say NOTHING: the app "
                                        + "says the pretend line and the new prop's line."
                                    : PropSkip.note(item: p.householdItem, becomes: p.becomes, then: then),
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

    /// Nutmeg's voice for app-written lines: her recorded clip, else her live Realtime voice, else nothing (round 35
    /// prep: never the system voice). During planning she speaks for herself, so app lines are skipped there.
    func speak(_ text: String, deferIfAway: Bool = false) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        speaker.remember(text)   // whitespace-only lines aren't remembered
        // Round D3b: her recorded clip plays at once (no network, no thinking face), on a replay and on a first play
        // once a line has been recorded. Planning lines are hers to say in the conversation (never app lines).
        if clipStore.has(text) && !planningNow && !realtime.suspended {
            if store.isReplay { clipLog.note(.clip, common: clipStore.clip(for: text)?.common ?? false, kind: ClipMeta.kind(of: text)) }
            speaker.say(text, replay: store.isReplay)
            return
        }
        // Round 9: away (background, or reconnecting): an important line (kit ready) waits for the session; others drop.
        // Round D1: a replay's first lines wait for its voice session (never the device voice while it connects).
        if replayConnecting { deferredLine = text; return }
        // Round D3b (Haylee's answer 1): offline on a replay, a line she never said: the Wi-Fi note, paused on it.
        if store.isReplay && !realtime.isLive { owe(text); return }
        if store.isReplay && realtime.isLive {
            store.ledger.paidAICall(kind: .replayLine)   // E hook: a live replay line
            clipLog.note(.live(record: true), kind: ClipMeta.kind(of: text))
        }
        if realtime.suspended || (realtime.status == .connecting && Self.wasLive(store.phase)) || resuming {
            if deferIfAway { deferredLine = text; rtLog("line deferred until the session is back") }
            return
        }
        if realtime.isLive {
            if !planningNow {
                // Round 13: a scene / hand-off line follows a kid's tap: the thinking state shows until it plays.
                let tapped: Bool = { switch store.phase { case .scene, .end: true; default: false } }()
                speaker.say(text, thinking: tapped)
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
        // Round 35 prep (Haylee): never the system voice. No clip and no live voice: she says nothing (the line stays
        // in her memory for Repeat once the voice is back).
        rtLog("no clip and no live voice: she stays quiet (never TTS): \(text.prefix(40))")
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
            onboardingVoice.stop()   // v2: her onboarding clip never plays with the page off screen
            scribble.setPlaying(false, ducked: false)
            if listener.isListening { Task { _ = await listener.stopListening() } }   // round 31: words dropped, not sent
            // In-flight kit requests (Claude kit, page art) get time to finish; failures are retried on return.
            if store.phase == .makingKit || (store.phase == .kitReady && (!kitFinal || store.guidePending)) { beginKitBackgroundTask() }
        case .active:
            rtLog("scene: active (phase \(store.phase), step \(store.planningStep))")
            updateIdleTimer()
            endKitBackgroundTask()
            if realtime.suspended { Task { await resumeSession() } }
            retryKitIfNeeded()
            if writingOnScreen { scribble.setPlaying(true, ducked: isSpeaking) }
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
        // Round 27: the saved cover (the generated text-free picture, or the sign page it fell back to at Save); a
        // game with no cover.jpg falls back to its color sign page, then its outline one.
        var img = savedGames.cover(for: g).flatMap(UIImage.init(data:))
        if img == nil, let signID = g.kit.items.first(where: { $0.recipe == .sign })?.id {
            let files = savedGames.art(for: g)
            func sign(_ style: PrintStyle) -> UIImage? {
                files.first { ArtKey.parse($0.key, plain: g.plainArtStyle).map { $0.itemID == signID && $0.index == nil && $0.style == style } ?? false }
                    .flatMap { UIImage(data: $0.value) }
            }
            img = CoverArt.pick(cover: nil, colorSign: sign(.fullColor), outlineSign: sign(.colorIn))
        }
        if let img { coverCache[g.id] = img }
        return img
    }

    func openShelf() {
        refreshShelf()
        guard !shelfGames.isEmpty else { return }
        showingShelf = true
        rtLog("my games: shelf opened (\(shelfGames.count) saved)")
    }
    func closeShelf() { showingShelf = false }

    // MARK: Grown-ups corner (round D2, Haylee: delete lives here, behind the gate)

    func openGrownUps() {
        refreshShelf()
        showingGrownUps = true
        rtLog("grown-ups: opened (\(shelfGames.count) saved)")
    }
    func closeGrownUps() {
        showingGrownUps = false
        refreshShelf()
    }
    func grownUpRows() -> [SavedGameRow] { savedGames.rows() }
    /// Round 33: Grown-ups → "Replay the intro": close Grown-ups, then the onboarding from How it works (the Grown-ups
    /// gate was just passed, so the flow doesn't gate again).
    func replayParentIntro() {
        rtLog("grown-ups: replay the intro")
        closeGrownUps()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))   // the sheet's dismissal first
            onboarding = OnboardingFlow(replay: true)
        }
    }
    /// Deletes a saved game for good (its folder: game.json, art, cover). After the last one, My games goes away.
    func deleteSavedGame(_ id: UUID) {
        let gone = savedGames.deleteGame(id)
        refreshShelf()
        if shelfGames.isEmpty { showingShelf = false }
        rtLog("grown-ups: deleted a saved game (\(gone ? "files removed" : "FILES LEFT")), \(shelfGames.count) left")
    }

    /// The End's star (round 26; was "Save it to play again"): the game is written to this iPad at once (game content
    /// only), she says its title and that it's on the shelf, then the game goes home (the round 19 hang-up rules).
    func tapSave() {
        guard store.canSave, saveState != .saving else { return }
        userAction(.saveGame)
        saveState = .saving
        let started = Date()
        let id = store.gameID
        // Round 27: both sets (the outline set's keys are o-prefixed) and the generated cover.
        let images = colorArt.artByKey.merging(outlineArt.artByKey) { a, _ in a }
        // The shelf card: the text-free cover, else the color sign page, else the outline one.
        let signID = store.kit?.items.first { $0.recipe == .sign }?.id
        let generated = coverArt.image
        let sign = CoverArt.pick(cover: nil, colorSign: signID.flatMap { colorArt.images[$0] }, outlineSign: signID.flatMap { outlineArt.images[$0] })
        Task { @MainActor in
            let (files, cover) = await Task.detached(priority: .userInitiated) { () -> ([String: Data], Data?) in
                var files: [String: Data] = [:]
                for (key, img) in images { if let d = img.heicData() ?? img.jpegData(compressionQuality: 0.9) { files[key] = d } }
                return (files, generated.flatMap { CoverArtService.jpeg($0) } ?? sign.flatMap { Self.coverData($0) })
            }.value
            guard store.canSave, var game = store.savedGame(id: id, art: files.keys.sorted(), cover: cover == nil ? nil : "cover.jpg") else { saveState = .failed; return }
            // Round D3b: her lines recorded on this play are saved with it.
            let recorded = clipStore.pendingForSave()
            game.clips = recorded.clips
            do {
                try savedGames.save(game, art: files, cover: cover, clips: recorded.data)
                clipStore.didSave(game.id)
                rtLog("SAVE cover: \(generated != nil ? "the generated cover" : sign != nil ? "the sign page (no cover)" : "none")")
                rtLog("SAVE clips: \(recorded.clips.count) recorded lines, \(recorded.data.values.reduce(0) { $0 + $1.count } / 1024) KB AAC")
            } catch {
                rtLog("save: failed (\(error.localizedDescription))")
                Analytics.send(.error(.saveFailed))
                saveState = .failed
                return
            }
            store.markSaved(game.id)
            Analytics.send(.gameSaved(PlayersValue(count: store.playerCount), GameCategory.from(title: game.title)))
            saveState = .idle
            refreshShelf()
            rtLog(String(format: "SAVE game saved in %.2f s: %d art files, %d KB on disk, %d on the shelf", Date().timeIntervalSince(started),
                         files.count, savedGames.size(of: game.id) / 1024, shelfGames.count))
            gesture(.celebrate); celebrations += 1
            // Design: "<Title>!" then the shelf line. Round 26 (Haylee): the star saves AND goes home, once her line ends.
            speak("\(game.title)! It's on your shelf now. Play it again anytime!")
            homeAfterSave = Task { @MainActor in
                for _ in 0..<30 where !(isSpeaking || realtime.voiceBusy) && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(100)) }
                for _ in 0..<100 where (isSpeaking || realtime.voiceBusy) && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(100)) }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, store.phase == .end, store.savedAs == game.id else { return }
                rtLog("SAVE: home after the shelf line")
                leave()
            }
        }
    }
    @ObservationIgnored private var homeAfterSave: Task<Void, Never>?

    /// A 600 px wide JPEG of the sign art for the shelf card.
    nonisolated static func coverData(_ image: UIImage) -> Data? {
        let w: CGFloat = 600, scale = w / max(image.size.width, 1)
        let size = CGSize(width: w, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.8)
    }

    /// A card on the shelf: the replay starts (Pick: how many are playing). No AI calls for content anywhere in it.
    func tapSavedGame(_ g: SavedGame) {
        // Round 33: a replay is free (never counted) but Nutmeg's live voice still needs the AI consent.
        if NewGameGate.replay(consent: aiConsent) != .start { kidBlock = .needsConsent; showingShelf = false; return }
        freePreview.gameStarted(isReplay: true)
        userAction(.openSavedGame)
        Task { await startReplay(g) }
    }

    /// Starts a replay: the saved art comes back from disk, the store loads the game (Pick), and the voice session
    /// (pre-connected on the start screen) speaks every line live (recorded clips are round D3b).
    func startReplay(_ g: SavedGame) async {
        repeatTask?.cancel(); pointTask?.cancel(); kitBeatTask?.cancel(); kitWait?.cancel()
        deferredLine = nil
        let files = savedGames.art(for: g)
        let decoded = await Task.detached(priority: .userInitiated) { () -> [String: UIImage] in
            var out: [String: UIImage] = [:]
            for (k, d) in files { if let img = UIImage(data: d)?.preparedForDisplay() { out[k] = img } }
            return out
        }.value
        // Round 27: each set's art back into its own service (a game saved before round 27 has one set).
        var images: [PrintStyle: [String: UIImage]] = [:], cutouts: [PrintStyle: [String: [Int: UIImage]]] = [:]
        for (key, img) in decoded {
            guard let p = ArtKey.parse(key, plain: g.plainArtStyle) else { continue }
            if let n = p.index { cutouts[p.style, default: [:]][p.itemID, default: [:]][n] = img } else { images[p.style, default: [:]][p.itemID] = img }
        }
        coverArt.reset()
        for style in PrintStyle.sets { artSet(style).restore(images: images[style] ?? [:], cutouts: cutouts[style] ?? [:]) }
        replayGame = g
        kitBeat = .papers; papersShown = true; kitWriting = false; kitReadySaid = true; beat = .none; shownProps = 0
        savedGames.touch(g.id)
        replayStartCalls = AICallLog.snapshot
        rtLog("REPLAY start \"\(g.title)\": \(decoded.count) art files restored, no generation; AI calls so far: \(AICallLog.summary())")
        // Round D3b: her recorded lines for this game; the speaker's engine runs on its own so clips play at once
        // (and offline), and a dropped session never silences them.
        clipStore.load(savedGames.game(g.id) ?? g)
        clipLog = ClipHitLog()
        replayUsageStart = realtime.usageTotals
        wifiPause.clear()
        speaker.holdEngine = true
        speaker.startForClips()
        let live = realtime.isLive
        if !live { realtime.resetChat() }
        // Offline: no connect at all (clips only; a never-said line pauses with the Wi-Fi note).
        replayConnecting = !live && realtimeAuth != nil && network.online
        showingShelf = false
        gameStats.begin(kind: .replay)
        Analytics.send(.replayStarted(GameCategory.from(title: g.title)))
        store.loadReplay(g)   // Pick; her greeting: a clip at once, else live once (waits for the session if it's connecting)
        if live {
            realtime.addNote(Realtime.systemNote(replayNote))
            return
        }
        guard let auth = realtimeAuth, network.online else { flushDeferredLine(); return }
        let config = voiceConfig
        gameVoice = config
        let ok = await realtime.connect(auth: auth, config: config, echoCancel: Self.echoCancel, instructions: Realtime.instructions,
                                        keepChat: true)
        replayConnecting = false
        guard store.isReplay, store.replayGameID == g.id else { return }   // left meanwhile
        if ok {
            realtime.addNote(Realtime.systemNote(replayNote))
            realtime.micWanted = true
            gesture(.wave)
        }
        rtLog("REPLAY voice session \(ok ? "live" : "failed: clips only, a never-said line waits for Wi-Fi")")
        flushDeferredLine()
    }

    /// The one system note a replay's session gets (title, roles, props, the current step, the scene titles).
    var replayNote: String {
        ReplayLines.note(title: store.currentTitle, roles: store.plan?.roles ?? [], players: store.playerCount,
                         props: store.props?.props ?? [], step: store.phase.step, scenes: (store.kit?.scenes ?? []).filter { $0.arc != .story }.map(\.title))   // round 36: setup … clean-up
    }

    /// DEBUG/live check: the AI calls made since the replay started (content = Claude + images).
    func logReplayCalls(_ moment: String) {
        guard store.isReplay else { return }
        let now = AICallLog.snapshot
        let d = AICallLog.Kind.allCases.map { "\($0.rawValue)=\((now[$0] ?? 0) - (replayStartCalls[$0] ?? 0))" }.joined(separator: " ")
        let content = (now[.claude] ?? 0) - (replayStartCalls[.claude] ?? 0) + (now[.image] ?? 0) - (replayStartCalls[.image] ?? 0)
        rtLog("REPLAY AI calls since start (\(moment)): \(d) → content calls: \(content)")
        logReplayClips(moment)
    }

    // MARK: Recorded voice on replays (round D3b)

    /// The replay's clip hit rate and Realtime usage since it started (counts only, never content).
    func logReplayClips(_ moment: String) {
        guard store.isReplay else { return }
        let u = realtime.usageTotals
        var d = RealtimeUsageTotals()
        d.responses = u.responses - replayUsageStart.responses; d.input = u.input - replayUsageStart.input
        d.cached = u.cached - replayUsageStart.cached; d.output = u.output - replayUsageStart.output
        d.outAudio = u.outAudio - replayUsageStart.outAudio
        rtLog("REPLAY clips (\(moment)): \(clipLog.line)")
        rtLog(String(format: "REPLAY realtime usage (%@): %d responses, in %d (cached %d), out %d (audio %d) ≈ $%.4f", moment,
                     d.responses, d.input, d.cached, d.output, d.outAudio, d.dollars))
    }

    #if DEBUG
    /// Round D3b (§D4.6): records the bundled common lines in her real Realtime voice, through the same recorder and
    /// transcript gate, into Documents/CommonClips/common-<key>.aac (copied into the app bundle by hand). Never TTS.
    func debugRecordCommonLines() async {
        guard let auth = realtimeAuth else { rtLog("COMMON: no voice auth"); return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CommonClips", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var kept = Set<String>()
        realtime.onRecorded = { line in
            let key = CommonLines.key(line.request.line)
            let pcm = line.pcm16
            Task.detached {
                guard let data = ClipStore.encodeAAC(pcm) else { return }
                try? data.write(to: dir.appendingPathComponent("common-\(key).aac"))
                rtLog(String(format: "COMMON kept %@ (%.1f s, %d KB)", String(key.prefix(8)), line.duration, data.count / 1024))
            }
            Task { @MainActor in kept.insert(line.request.line) }
        }
        let ok = await realtime.connect(auth: auth, config: voiceConfig, echoCancel: Self.echoCancel, instructions: Realtime.instructions)
        guard ok else { rtLog("COMMON: connect failed"); return }
        // Round 33: only the lines not bundled yet (the earlier clips stay exactly as recorded).
        for line in CommonLines.all where ClipStore.bundledCommon[line] == nil {
            for attempt in 1...3 where !kept.contains(line) {
                realtime.say(line, record: true)
                for _ in 0..<50 where !realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
                for _ in 0..<300 where realtime.isSpeaking || realtime.isBusy { try? await Task.sleep(for: .milliseconds(100)) }
                try? await Task.sleep(for: .seconds(1.5))
                rtLog("COMMON line \(CommonLines.all.firstIndex(of: line)! + 1)/\(CommonLines.all.count) attempt \(attempt): \(kept.contains(line) ? "kept" : "not kept")")
            }
        }
        try? await Task.sleep(for: .seconds(2))
        rtLog("COMMON done: \(kept.count)/\(CommonLines.all.count) kept in \(dir.path)")
        realtime.disconnect()
    }
    #endif

    /// Haylee's answer 1: a replay line she never said, with no voice: the Wi-Fi note (her bundled clip says it) and
    /// the game pauses on this line until the connection is back; then she says it live (and it's saved).
    private func owe(_ line: String) {
        let first = !wifiPause.isPaused
        wifiPause.owe(line)
        clipLog.note(.waitForNetwork, kind: ClipMeta.kind(of: line))
        rtLog("WIFI pause: a never-said line with no voice (\(ClipMeta.kind(of: line).rawValue)); waiting for the network")
        if first {
            gesture(.point, hold: 2)
            _ = speaker.say(WiFiPause.spokenNote, record: false)   // her bundled clip; nothing if it isn't bundled
        }
        if network.online { resumeAfterWiFi() }   // online but the voice dropped: try to get it back
    }

    private func networkChanged(_ online: Bool) {
        rtLog("network: \(online ? "online" : "offline")")
        #if DEBUG
        // The debug offline switch also drops the live voice, like a lost connection.
        if !online && network.debugOffline && realtime.status != .idle && store.isReplay { realtime.disconnect() }
        #endif
        if online && wifiPause.isPaused { resumeAfterWiFi() }
    }

    /// The connection is back: the voice reconnects, then she says the owed line live (recorded), and the game goes on.
    private func resumeAfterWiFi() {
        guard wifiTask == nil, store.isReplay else { return }
        wifiTask = Task { @MainActor in
            defer { wifiTask = nil }
            while !Task.isCancelled && wifiPause.isPaused && store.isReplay {
                if !realtime.isLive, network.online, let auth = realtimeAuth {
                    let ok = await realtime.connect(auth: auth, config: gameVoice ?? voiceConfig, echoCancel: Self.echoCancel,
                                                    instructions: Realtime.instructions, keepChat: true)
                    if ok { realtime.addNote(Realtime.systemNote(replayNote)); realtime.micWanted = true }
                    rtLog("WIFI voice reconnect: \(ok ? "live" : "failed")")
                }
                if realtime.isLive, let line = wifiPause.resume(live: true) {
                    rtLog("WIFI back: saying the owed line live")
                    for _ in 0..<80 where speaker.isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // the note ends
                    speak(line)
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Round 26: the count on a replay's Pick (voice: set_player_count; the tiles only without a voice session). It
    /// goes straight on to Props, the first saved card.
    @ObservationIgnored private var lastReplayCardKey: String?
    func replayPick(_ n: Int) {
        userAction(.replayPick)
        store.replayPick(n)
        noteReplayStep()
    }
    /// Round 26: ✓ / ✗ on a replay's prop card (the first play's hunt card, with no AI). After the last card: Print.
    func replayHunt(found: Bool) {
        guard store.replayHuntActive else { return }
        userAction(.replayProp)
        store.replayHunt(found: found)
        noteReplayStep()
    }
    /// A silent note so the replay's session knows where the kids are.
    /// Round 26: with the card that's up during Props (her app lines aren't in the conversation).
    private func noteReplayStep() {
        // Round 34 (Haylee: replays look like new games): a new card on a replay gets the first play's point too.
        let key = store.replayCurrentProp.map { $0.id + ($0.libraryID ?? "") }
        if store.isReplay, let key, key != lastReplayCardKey { pointAtCard() }
        lastReplayCardKey = key
        // Round 34: the first prop line follows the count line as its own line (its first-play clip plays again).
        if let next = store.takeReplayFollowUp() {
            Task { @MainActor in
                for _ in 0..<60 where !isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // the count line starts (≤ 3 s)
                for _ in 0..<400 where isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // and ends (≤ 20 s)
                guard store.replayHuntActive else { return }
                speak(next)
            }
        }
        guard store.isReplay, realtime.isLive else { return }
        let props = store.props?.props ?? [], card = store.replayCurrentProp
        let n = card.flatMap { c in props.firstIndex { $0.id == c.id } }.map { $0 + 1 } ?? 0
        realtime.addNote(Realtime.systemNote(ReplayLines.stepNote(step: store.phase.step, players: store.playerCount,
            playing: store.playingRoles.map(\.roleName), card: card, cardNumber: n, cards: props.count)))
    }

    // MARK: Checklist and scene pictures (checklist-pictures.md)

    func resolve(_ picture: Picture) -> ResolvedPicture {
        PictureResolver.resolve(picture, kit: store.kit, roles: store.plan?.roles ?? [])
    }

    /// Round 29 (Haylee, ensemble scenes): a scene row's CHARACTER picture, cropped from the role's slice of the COLOR
    /// badge sheet: only the illustration between the blank name banners (`BadgeCharacter`), no frame, no blank fields.
    /// nil while it isn't drawn (the row shows the role's color chip). Cropped once per slice.
    func characterPicture(_ role: Role) -> UIImage? {
        guard let id = store.kit?.items.first(where: { $0.recipe == .badges })?.id,
              let slice = colorArt.badgeSlice(id, role: role.id.index) else { return nil }
        let key = "\(id)#\(role.id.index)"
        if let hit = characterCache[key], hit.slice === slice { return hit.crop }
        let crop = CharacterCropper.crop(slice)
        characterCache[key] = (slice, crop)
        return crop
    }
    @ObservationIgnored private var characterCache: [String: (slice: UIImage, crop: UIImage)] = [:]

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
            // Round 27: the chosen set's picture (the other set's while it's still drawing).
            let other = artSet(store.printSet == .fullColor ? .colorIn : .fullColor)
            return PTPictureTile(image: printArt.badge(itemID, role: role?.id.index) ?? other.badge(itemID, role: role?.id.index), placeholder: title, roleTitle: role?.roleName,
                                 roleTint: Theme.playerColor(role?.id.index ?? 0), size: size)
        case .cutout(let itemID, let index, let label):
            let other = artSet(store.printSet == .fullColor ? .colorIn : .fullColor)
            return PTPictureTile(image: printArt.cutout(itemID, index) ?? other.cutout(itemID, index), placeholder: label, size: size)
        }
    }

    /// Round D3b: her speaker plays (live audio, or a clip with no session): its lip sync and speaking state.
    private var speakerVoice: Bool { realtime.isLive || speaker.isRunning }
    var mouthLevel: Float { speaker.level }
    /// The live voice's lip-synced mouth (nil: fall back to the amplitude mouth from `mouthLevel`).
    var mouthShape: NutmegMouth? { speakerVoice ? NutmegMouth(rawValue: speaker.mouth.rawValue) : nil }
    var isSpeaking: Bool { speaker.isSpeaking }

    // MARK: Push-to-talk (decisions/2026-11-13-push-to-talk.md)

    /// The red mic in the control pill. Round 31: held → the iPad listens (on-device words only); released → the
    /// words go to the live conversation as text (or, with no session, through `handleSpeech`). `unavailable`: the iPad
    /// can't listen on the device (permission, or no on-device English speech): a press shows the grown-up note and
    /// typing takes over. Never any audio fallback.
    enum MicState { case idle, listening, disabled, unavailable }
    var micState: MicState {
        if realtime.status == .connecting { return .disabled }
        if realtime.isLive {
            // Round 7: never disabled in a live session (only while connecting): print step and play take voice too.
            if !listener.available { return .unavailable }
            return realtime.kidIsTalking ? .listening : .idle
        }
        guard store.phase != .hello else { return .disabled }
        guard listener.available else { return .unavailable }
        return listener.isListening ? .listening : .idle
    }
    /// Round 31: the grown-up note to show (the mic was pressed while the iPad can't listen on the device).
    var speechHelp: SpeechReadiness?
    func talkPressed(touchHost: Double = CACurrentMediaTime()) {
        wakeUp()
        guard listener.available else {
            // Round 34: iPadOS 26+: the one-tap in-app download sheet instead of the Settings note.
            if listener.readiness == .onDeviceUnavailable && speechModel.offersDownload {
                speechModel.showingSheet = true
                rtLog("mic: on-device model missing: the in-app download sheet (\(speechModel.state))")
                return
            }
            speechHelp = listener.readiness   // a friendly note for a grown-up, then typing
            rtLog("mic: can't listen on this iPad (\(listener.readiness)): grown-up note + typing")
            return
        }
        let t0 = CACurrentMediaTime()
        if realtime.isLive { userAction(.micPressed); realtime.beginTalk(touchHost: touchHost) }
        else { micPressed(touchHost: touchHost) }
        rtLog(String(format: "MIC press work on the main thread: %.1f ms", (CACurrentMediaTime() - t0) * 1000))
    }
    func talkReleased() {
        if realtime.isLive { realtime.endTalk() } else if listener.isListening { micReleased() }
    }

    /// Round 31: recognition said on-device speech isn't there after all (the asset went missing): the mic switches to
    /// its unavailable look and the next press shows the note. The turn in progress sends nothing.
    func speechUnavailableNow() {
        guard listener.available else { return }
        listener.markUnavailable()
        Analytics.send(.error(.speechUnavailable))
        if speechModel.offersDownload && !speechModel.state.isReady { speechModel.showingSheet = true; return }   // round 34
        speechHelp = listener.readiness
    }

    func micPressed(touchHost: Double = CACurrentMediaTime()) {
        if speaker.isSpeaking { speaker.cancel() }   // Nutmeg never hears herself
        listener.startListening(touchHost: touchHost)
    }

    func micReleased() {
        Task {
            let (words, held) = await listener.stopListening()
            guard case .send(let text) = SpokenTurn.decide(words: words, held: held, quickReplyOnly: false) else { return }
            await typed(text, kind: .spoken)
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

// MARK: - Anonymous usage counts (2026-11-17-analytics-build.md)

extension AppModel {
    /// The phase changed: each step and scene once per game, The End once (coarse buckets only; the title is reduced to
    /// a fixed category on the iPad). A fallback to the built-in game counts as "AI unavailable", once per game.
    func sendPhaseAnalytics() {
        let kinds = store.kit?.scenes.map(\.arc) ?? []
        for e in gameStats.phase(store.phase, sceneKinds: kinds, players: store.playerCount, title: store.currentTitle) {
            Analytics.send(e)
        }
        if store.usingFallback, store.phase != .hello, let e = gameStats.error(.aiUnavailable) { Analytics.send(e) }
    }

    /// The grown-up's switch (onboarding's privacy page, Grown-ups → About what we save).
    func setAnalyticsSharing(_ on: Bool) {
        Analytics.setSharing(on)
        analyticsSharing = Analytics.sharing
    }
}
