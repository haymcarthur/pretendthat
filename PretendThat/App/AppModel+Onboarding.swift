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
            || DemoDriver.startFreeze != nil
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
        if args.contains("-PTResetFreePreview") { freePreview.reset(); rtLog("FREE PREVIEW reset (-PTResetFreePreview)") }
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
        planStatus = await PTStore.planStatus()
        rtLog("ONBOARDING launch: done \(parentSettings.onboardingDone), AI consent \(aiConsent), free preview \(freePreview.used)/\(freePreview.allowance) used")
        if debugDriving {
            aiConsent = true   // in memory only: the drivers need the voice
            await listener.requestAuth()
            return
        }
        if !parentSettings.onboardingDone {
            var flow = OnboardingFlow()
            #if DEBUG
            if let i = args.firstIndex(of: "-PTOnboarding"), i + 1 < args.count {
                flow = Self.debugFlow(at: args[i + 1])
            }
            #endif
            onboarding = flow
            return
        }
        if aiConsent { await listener.requestAuth() } else { listener.refresh() }
        if aiConsent { preconnect() }
    }

    #if DEBUG
    /// `-PTOnboarding <screen>[Denied]`: open the flow on a screen (for screenshots).
    static func debugFlow(at name: String) -> OnboardingFlow {
        var f = OnboardingFlow()
        let target = OnboardingScreen(rawValue: name.replacingOccurrences(of: "Denied", with: "")) ?? .hello
        if target == .hello { return f }
        f.passGate()
        if target == .howItWorks { return f }
        f.next()
        if target == .privacy { return f }
        if target == .aiDeclined { f.notNow(); return f }
        f.agree()
        if target == .microphone { if name.hasSuffix("Denied") { f.micAnswered(granted: false) }; return f }
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
        change(&f)
        onboarding = f
        if f.screen != before { rtLog("ONBOARDING \(before.rawValue) → \(f.screen.rawValue)") }
        if f.finished { finishOnboarding(f) }
    }

    /// The mic screen's Continue: the system prompts (microphone, then speech recognition), then on.
    func onboardingMicContinue() async {
        let micOK = await AVAudioApplication.requestRecordPermission()
        let speech = await Listener.speechAuth()
        listener.refresh(speech: speech, mic: micOK)
        let granted = micOK && speech == .authorized
        rtLog("ONBOARDING mic: \(micOK ? "granted" : "denied"), speech: \(speech == .authorized ? "granted" : "denied")")
        onboardingUpdate { $0.micAnswered(granted: granted) }
    }

    private func finishOnboarding(_ f: OnboardingFlow) {
        parentSettings.finish(f)
        aiConsent = parentSettings.aiConsent
        onboarding = nil
        rtLog("ONBOARDING finished (\(f.isReplay ? "replay" : "first launch")), AI consent \(aiConsent)")
        if f.consent == true && f.screen == .handOff {
            // The hand-off: Nutmeg greets the kid (her recorded clip) once the start screen is back.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                onboardingVoice.play(OnboardingCopy.greetKid)
            }
        }
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
        let gate = NewGameGate.newGame(consent: aiConsent, plan: planStatus, freeRemaining: freePreview.remaining)
        rtLog("NEW GAME gate: \(gate) (consent \(aiConsent), free left \(freePreview.remaining))")
        guard gate == .start else { kidBlock = gate; return false }
        return true
    }

    /// The kid card's "Grown-ups" button: the gate, then the plans (Free Preview used up) or the AI partners screen.
    func openGrownUpsFromKidCard() {
        let block = kidBlock
        kidBlock = nil
        if block == .needsPlan { showingPlans = true } else { openGrownUps() }
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
        realtime.kickOff(games: games, greetingClip: clipSeconds)
    }
}

/// Round 33: Nutmeg's two onboarding lines, from her bundled recorded clips (never TTS), on a playback-only engine: no
/// microphone input is touched, so nothing asks for the mic before the pre-permission screen. Same Varispeed shape.
@Observable @MainActor
final class OnboardingVoice {
    private(set) var speaking = false
    private(set) var level: Float = 0
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var task: Task<Void, Never>?

    func play(_ line: String) {
        stop()
        guard let key = ClipStore.bundledCommon[line],
              let url = Bundle.main.url(forResource: "common-\(key)", withExtension: "aac"),
              let samples = ClipStore.decode(url), !samples.isEmpty else {
            rtLog("ONBOARDING clip missing for \"\(line.prefix(24))…\": she stays quiet (never TTS)")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            if session.category != .playAndRecord { try session.setCategory(.playback, mode: .spokenAudio) }
            try session.setActive(true)
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let pitch = SpeakerGraph.makePitchUnit(.nutmeg)
            engine.attach(player)
            if let pitch { engine.attach(pitch) }
            SpeakerGraph.wire(engine, player: player, pitchUnit: pitch)
            engine.prepare()
            try engine.start()
            for b in SpeakerGraph.clipBuffers(samples) { player.scheduleBuffer(b) }
            player.play()
            self.engine = engine
        } catch {
            rtLog("ONBOARDING clip engine failed: \(error.localizedDescription)")
            return
        }
        let rate = VoiceConfig.nutmeg.playbackRate
        let step = 0.05, chunk = Int(Realtime.sampleRate * step)
        let envelope: [Float] = stride(from: 0, to: samples.count, by: chunk).map { i in
            let s = samples[i..<min(i + chunk, samples.count)]
            return min(sqrt(s.reduce(0) { $0 + $1 * $1 } / Float(max(s.count, 1))) * 5, 1)
        }
        rtLog(String(format: "ONBOARDING clip play (%.1f s heard)", Double(samples.count) / Realtime.sampleRate / rate))
        speaking = true
        task = Task { @MainActor [weak self] in
            for e in envelope {
                guard !Task.isCancelled else { return }
                self?.level = e
                try? await Task.sleep(for: .seconds(step / rate))
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        task?.cancel(); task = nil
        engine?.stop(); engine = nil
        speaking = false; level = 0
    }
}
