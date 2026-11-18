import SwiftUI
import AVFoundation
import NutmegCore

/// Round 33: the parent onboarding, the AI consent, the Free Preview count and the New game greeting.
/// Stored on this iPad as device flags only (booleans and a count); nothing about kids.
extension AppModel {

    /// Debug runs that drive the app (demo phases, live turns, Grown-ups shots, frame strips) skip the onboarding and
    /// act as if the grown-up agreed (in memory only).
    var debugDriving: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-PTOnboarding") { return false }
        return DemoDriver.requestedPhase != nil || DemoDriver.liveTurns != nil || DemoDriver.grownUps != nil || DemoDriver.autoStart
            || DemoDriver.startFreeze != nil || DemoDriver.voiceRenderFile != nil
        #else
        return false
        #endif
    }

    /// At launch (RootView's task): the onboarding on the first launch, else the usual permission check.
    #if DEBUG
    /// DEBUG launch flags (applied in `init`, before any driver runs): `-PTResetOnboarding`, `-PTResetFreePreview`,
    /// `-PTResetGreeting`, `-PTFreeUsed N`, `-PTConsent`, `-PTNoConsent`.
    func applyDebugLaunchFlags() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-PTResetOnboarding") { parentSettings.reset(); rtLog("ONBOARDING reset (-PTResetOnboarding)") }
        if args.contains("-PTResetFreePreview") { freePreview.reset(); planShows.reset(); rtLog("FREE PREVIEW + plan count reset (-PTResetFreePreview)") }
        if let i = args.firstIndex(of: "-PTPlanUsed"), i + 1 < args.count, let n = Int(args[i + 1]) { debugPlanUsed = n }
        if args.contains("-PTResetGreeting") {
            UserDefaults.standard.removeObject(forKey: GameGreeting.hasPlayedKey)
            UserDefaults.standard.removeObject(forKey: GameGreeting.lastShortKey)
            rtLog("GREETING reset: the next game gets the first-game intro")
        }
        if let i = args.firstIndex(of: "-PTFreeUsed"), i + 1 < args.count, let n = Int(args[i + 1]) {
            UserDefaults.standard.set(n, forKey: OnboardingKeys.freePreviewUsed)
        }
        if args.contains("-PTConsent") { parentSettings.aiConsent = true; parentSettings.onboardingDone = true }
        if args.contains("-PTNoConsent") { parentSettings.aiConsent = false; parentSettings.onboardingDone = true }
        aiConsent = parentSettings.aiConsent
    }
    #endif

    func launchOnboardingCheck() async {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        #endif
        aiConsent = parentSettings.aiConsent
        analyticsSharing = Analytics.sharing   // (Analytics.configure ran in init)
        // Round 38: StoreKit: the updates listener, the products and the current entitlement.
        purchases.onChange = { [weak self] in
            guard let self else { return }
            self.planStatus = self.purchases.status
            if self.kidBlock == .needsPlan || self.kidBlock == .outOfShows, !self.allowance.exhausted { self.kidBlock = nil }
        }
        purchases.start()
        await purchases.refresh()
        planStatus = purchases.status
        #if DEBUG
        // `-PTPlanUsed N`: this month's plan count starts at N (to reach the limit quickly on the simulator).
        if let n = debugPlanUsed, let e = purchases.entitlement {
            planShows.reset()
            for _ in 0..<n { planShows.gameStarted(in: e.window(), isReplay: false) }
            showCountVersion += 1
            rtLog("SHOWS debug: \(n) of \(e.tier.allowance) used this month (-PTPlanUsed)")
        }
        #endif
        rtLog("ONBOARDING launch: done \(parentSettings.onboardingDone), AI consent \(aiConsent), free preview \(freePreview.used)/\(freePreview.allowance) used")
        if debugDriving {
            aiConsent = true   // in memory only: the drivers need the voice
            await listener.requestAuth()
            await refreshSpeechModel()
            return
        }
        if !parentSettings.onboardingDone {
            // v2: back on the page the grown-up was on if the app was closed mid-way (device flags only).
            var flow = parentSettings.resumeFlow()
            #if DEBUG
            if let i = args.firstIndex(of: "-PTOnboarding"), i + 1 < args.count {
                flow = Self.debugFlow(at: args[i + 1])
            }
            #endif
            onboarding = flow
            onboardingStartedAt = Date()
            Analytics.send(.onboardingPageReached(OnboardingPageValue(flow.screen)))
            return
        }
        if aiConsent { await listener.requestAuth() } else { listener.refresh() }
        await refreshSpeechModel()   // round 34: the in-app model (iPadOS 26+) counts as on-device speech
        if aiConsent { preconnect() }
    }

    #if DEBUG
    /// `-PTOnboarding <screen>[Denied]`: open the flow on a page (for screenshots). `privacyDenied` = the mic-denied
    /// state ("No mic? Kids can type.").
    static func debugFlow(at name: String) -> OnboardingFlow {
        var f = OnboardingFlow()
        let target = OnboardingScreen(rawValue: name.replacingOccurrences(of: "Denied", with: "")) ?? .hello
        while f.screen != target && f.screen != .privacy { f.next() }
        if f.screen == target {
            if target == .privacy && name.hasSuffix("Denied") { f.agree(); f.micAnswered(granted: false) }
            return f
        }
        f.agree()
        f.micAnswered(granted: true)
        if target == .plans { return f }
        f.startFreePreview()
        return f
    }
    #endif

    // MARK: The flow's actions

    func onboardingUpdate(_ change: (inout OnboardingFlow) -> Void) {
        guard var f = onboarding else { return }
        let before = f.screen
        let consentBefore = f.consent
        change(&f)
        onboarding = f
        if f.screen != before { rtLog("ONBOARDING \(before.rawValue) → \(f.screen.rawValue)") }
        if !f.isReplay {   // a Grown-ups "Replay the intro" isn't counted
            if f.screen != before, !f.finished {
                Analytics.send(.onboardingPageReached(OnboardingPageValue(f.screen)))
                if f.screen == .plans { Analytics.send(.paywallShown(.onboarding)) }
            }
            if let c = f.consent, c != consentBefore { Analytics.send(.consentAnswered(c ? .yes : .no)) }
            if f.finished, let exit = f.exit { sendOnboardingFinished(exit) }
        }
        if f.finished { finishOnboarding(f) } else { parentSettings.saveProgress(f) }
    }

    /// v3 privacy page's "I agree, turn on the mic" (after `agree`): the system prompts (microphone, then speech
    /// recognition), then on to the plans (or the "No mic? Kids can type." state).
    func onboardingMicContinue() async {
        let micOK = await AVAudioApplication.requestRecordPermission()
        let speech = await Listener.speechAuth()
        listener.refresh(speech: speech, mic: micOK)
        let granted = micOK && speech == .authorized
        rtLog("ONBOARDING mic: \(micOK ? "granted" : "denied"), speech: \(speech == .authorized ? "granted" : "denied")")
        if onboarding?.isReplay == false { Analytics.send(.micAnswered(granted ? .yes : .no)) }
        // Round 34 (Haylee): start the on-device speech model download quietly now, so it's usually ready before the
        // first press (iPadOS 26+; already installed or older OS: nothing happens).
        if granted {
            Task { @MainActor in
                await refreshSpeechModel()
                if !listener.available && speechModel.state.canStart { speechModel.start(quiet: true) }
            }
        }
        onboardingUpdate { $0.micAnswered(granted: granted) }
    }

    /// v3 page 6's "Start our first game": straight into a new game on the stage, Nutmeg visible and talking (her
    /// game greeting is the first thing she says). The onboarding stays on screen until the game's first phase is
    /// set (`startConversation` closes it in the same update), so the home page never flashes in between. If New game
    /// is blocked (a replay with the Free Preview used up), it lands on the home page with the kid card, silently.
    func onboardingStartFirstGame() {
        guard var f = onboarding, f.screen == .handOff, !f.finished else { return }
        f.startFirstGame()
        if !f.isReplay { sendOnboardingFinished(.firstGame) }
        parentSettings.finish(f)
        aiConsent = parentSettings.aiConsent
        rtLog("ONBOARDING finished (\(f.isReplay ? "replay" : "first launch")) → first game, AI consent \(aiConsent)")
        guard canStartNewGame() else { onboarding = nil; return }
        onboarding = f   // finished: RootView keeps it on screen until the stage takes over
        Task { @MainActor in await startConversation() }
    }

    private func sendOnboardingFinished(_ exit: OnboardingExit) {
        let seconds = onboardingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        Analytics.send(.onboardingFinished(OnboardingExitValue(exit), DurationValue(seconds: seconds)))
        onboardingStartedAt = nil
    }

    private func finishOnboarding(_ f: OnboardingFlow) {
        parentSettings.finish(f)
        aiConsent = parentSettings.aiConsent
        onboardingVoice.stop()
        onboarding = nil
        // v2 (Haylee): "Go to the home page" (and Close for now) land on the start screen with NO voice at all.
        rtLog("ONBOARDING finished (\(f.isReplay ? "replay" : "first launch")) → \(f.exit?.rawValue ?? "?"), AI consent \(aiConsent), silent")
        if aiConsent { preconnect() }
    }

    // MARK: Consent (Grown-ups → AI partners)

    func setAIConsent(_ on: Bool) {
        parentSettings.aiConsent = on
        parentSettings.onboardingDone = true
        aiConsent = on
        rtLog("grown-ups: AI partners \(on ? "on" : "off")")
        if on { kidBlock = nil; preconnect() } else { realtime.disconnect() }
    }

    // MARK: New game gate

    /// The start button asks before its exit runs. False: the kid card shows why (consent, or the Free Preview).
    func canStartNewGame() -> Bool {
        #if DEBUG
        if debugDriving { return true }
        #endif
        let a = allowance
        let gate = NewGameGate.newGame(consent: aiConsent, allowance: a)
        rtLog("NEW GAME gate: \(gate) (consent \(aiConsent), \(a.tier.name): \(a.summary))")
        guard gate == .start else { kidBlock = gate; return false }
        return true
    }

    /// The kid card's "Grown-ups" button: the gate, then the plans (Free Preview used up) or the AI partners screen.
    func openGrownUpsFromKidCard() {
        let block = kidBlock
        kidBlock = nil
        if block == .needsPlan || block == .outOfShows { showingPlans = true } else { openGrownUps() }
    }

    // MARK: Round 38: the allowance (Free Preview 2 in total; Show Pass 10 / Season Pass 30 a month; replays free)

    var allowance: ShowAllowance {
        _ = showCountVersion
        return ShowAllowance.current(entitlement: purchases.entitlement, freeUsed: freePreview.used, counter: planShows)
    }

    /// A NEW show started: one more on the Free Preview, or on the plan's current month.
    func countNewShow() {
        if let e = purchases.entitlement {
            let w = e.window()
            let n = planShows.gameStarted(in: w, isReplay: false)
            rtLog("SHOWS \(e.tier.name) new show: \(n) of \(e.tier.allowance) this month")
        } else {
            let used = freePreview.gameStarted(isReplay: false)
            rtLog("FREE PREVIEW new game started: \(used) used, \(freePreview.remaining) left")
        }
        showCountVersion += 1
    }

    /// The relay's anonymous show count (off unless `RELAY_SHOW_LIMITS = YES` and the AI goes through the relay). The
    /// proof is StoreKit's signed transaction (a plan) or the AppTransaction (the Free Preview). A relay that doesn't
    /// know the endpoint, or can't be reached, allows (fail open); only an explicit "limit_reached" blocks.
    func relayAllowsNewShow() async -> Bool {
        ShowTicket.set(nil)
        guard let relay = showLimitsRelay else { return true }
        let proof: RelayShows.Proof
        if let jws = purchases.entitlement?.jws { proof = .subscription(jws: jws) }
        else if let jws = await purchases.appTransactionJWS() { proof = .preview(jws: jws) }
        else { rtLog("SHOWS relay: no StoreKit proof, allowed"); return true }
        var data: Data?, status: Int?
        do {
            let (d, http) = try await URLSessionTransport().send(RelayShows.request(relay: relay, proof: proof))
            data = d; status = http.statusCode
        } catch { rtLog("SHOWS relay unreachable: allowed") }
        switch RelayShows.decode(data: data, status: status) {
        case .allowed(let ticket, let remaining):
            ShowTicket.set(ticket)
            rtLog("SHOWS relay counted the show (\(remaining.map(String.init) ?? "?") left)")
            return true
        case .limitReached:
            rtLog("SHOWS relay: limit reached")
            return false
        case .allowUnknown:
            rtLog("SHOWS relay: endpoint unknown (\(status.map(String.init) ?? "offline")): allowed")
            return true
        }
    }

    // MARK: The New game greeting (Haylee: shorter, no re-introduction after the first game)

    func openGreeting(games: [Suggestion]) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTOldGreeting") {
            rtLog("GREETING old opening (-PTOldGreeting): she says hi in her own words")
            realtime.kickOff(games: games)
            return
        }
        #endif
        let line = GameGreeting.next(UserDefaults.standard)
        let route = speaker.say(line, record: false)
        let clipSeconds: Double
        if case .clip = route, let c = clipStore.clip(for: line) { clipSeconds = Double(c.samples.count) / Realtime.sampleRate } else { clipSeconds = 0 }
        rtLog("GREETING \(line == GameGreeting.firstIntro ? "first-game intro" : "short") (\(route)): \"\(line)\"")
        realtime.kickOff(games: games, greetingClip: clipSeconds, returning: line != GameGreeting.firstIntro)
    }
}

/// Round 33: Nutmeg's two onboarding lines, from her bundled recorded clips (never TTS).
/// Round 35 prep (Haylee heard her sound different during onboarding on the iPad): the clips now play through her ONE
/// speaker (`NutmegSpeaker.playClip`: the game's session setup, the same engine and Varispeed 1.20 graph, the re-link
/// guards and lip sync), not a separate `.playback` engine. Before the mic is allowed the speaker starts output-only,
/// so nothing asks for the microphone before the Mic page. This is only a thin wrapper the onboarding views watch.
@Observable @MainActor
final class OnboardingVoice {
    @ObservationIgnored private let speaker: NutmegSpeaker
    /// One of the onboarding's clips is what the speaker is playing.
    private(set) var playing = false
    @ObservationIgnored private var task: Task<Void, Never>?

    init(speaker: NutmegSpeaker) { self.speaker = speaker }

    var speaking: Bool { playing && speaker.isSpeaking }
    var level: Float { playing ? speaker.level : 0 }

    func play(_ line: String) {
        stop()
        guard let clip = ClipStore.bundledClip(for: line) else {
            rtLog("ONBOARDING clip missing for \"\(line.prefix(24))…\": she stays quiet (never TTS)")
            return
        }
        speaker.startForClips()
        guard speaker.isRunning else { rtLog("ONBOARDING: speaker didn't start; she stays quiet"); return }
        speaker.playClip(clip, echo: true)   // echo: no chat bubble (there is no conversation yet)
        playing = true
        rtLog(String(format: "ONBOARDING clip play through the speaker (%.1f s heard at ×%.2f)",
                     Double(clip.samples.count) / Realtime.sampleRate / VoiceConfig.nutmeg.playbackRate, VoiceConfig.nutmeg.playbackRate))
        #if DEBUG
        speaker.logFormats("onboarding")
        rtLog("ONBOARDING mic permission after play: \(AVAudioApplication.shared.recordPermission == .undetermined ? "not asked" : "\(AVAudioApplication.shared.recordPermission.rawValue)") (speaker input \(speaker.inputEnabled ? "on" : "off"))")
        #endif
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            while let self, self.speaker.isSpeaking, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }
            guard !Task.isCancelled else { return }
            self?.playing = false
        }
    }

    func stop() {
        task?.cancel(); task = nil
        if playing && speaker.isSpeaking { speaker.cancel() }
        playing = false
    }
}
