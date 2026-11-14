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
            guard let self, Self.isPlanning(self.store.phase) else { return nil }
            return TurnCheck.nudge(for: text, step: self.store.planningStep)
        }
        realtime.onSilence = { [weak self] in
            guard let self, Self.isPlanning(self.store.phase), self.store.planningStep != .finish else { return nil }
            return TurnCheck.silenceNudge(step: self.store.planningStep)
        }
        realtime.onPlanningBeat = { [weak self] topic in await self?.planningBeat(topic) }
        realtime.onCall = { [weak self] name, args in
            guard let self else { return ("ok", true) }
            return await self.handleCall(name: name, arguments: args)
        }
    }

    // MARK: Voice conversation

    var hasRealtime: Bool { openAIKey != nil }

    /// Grown-ups: hear `voice` say the sample line through the conversation's audio path and pitch settings.
    func auditionVoice(_ voice: String) async {
        guard let key = openAIKey else { return }
        await realtime.audition(apiKey: key, voice: voice, shape: voiceSettings.shape, speed: voiceSettings.speed)
    }
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
        store.beginConversation()
        guard let key = openAIKey else { await store.start(); return }
        let ok = await realtime.connect(apiKey: key, voice: voiceSettings.voice, shape: voiceSettings.shape,
                                        speed: voiceSettings.speed, echoCancel: voiceSettings.echoCancel)
        guard store.phase == .pickGame else { return }   // left while connecting
        if ok {
            realtime.micWanted = true
            gesture(.wave)
            realtime.kickOff()
        } else {
            await store.start()   // tap screens (and the bundled airplane game if Claude is off too)
        }
    }

    /// Leave activity: hang up and go home. Nothing is kept.
    func leave() {
        realtime.disconnect()
        shownProps = 0; beat = .none; kitBeatTask?.cancel(); kitBeat = .coloring; kitWriting = false; kitWritingTask?.cancel(); kitWritingTask = nil
        voice.stop()
        art.reset()
        stickers.reset()
        store.newGame()
    }

    /// Typed fallback goes into the live conversation when there is one.
    func typed(_ text: String) async {
        if realtime.isLive && Self.isPlanning(store.phase) { realtime.sendText(text) } else { await handleSpeech(text) }
    }

    func phaseChanged() {
        realtime.micWanted = Self.isPlanning(store.phase)
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
        // A long wait gets one or two short reassuring lines, never more.
        kitWait?.cancel()
        kitWait = Task { @MainActor in
            for line in ["Almost done! These are going to be so fun to color!", "Just a few more lines and they're ready!"] {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, !art.finished, store.kit != nil else { return }
                speak(line)
            }
        }
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
    /// Grown-up hold-to-print: the whole kit as one PDF to AirPrint.
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
        kitBeatTask?.cancel()
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
        }
    }

    private func handleCall(name: String, arguments: String) async -> (output: String, respond: Bool) {
        guard let call = PlanningCall.decode(name: name, arguments: arguments) else {
            return ("I couldn't use that. Try again with the right fields.", true)
        }
        let before = realtime.responseSerial
        let output = await store.apply(call)
        realtime.huntMode = store.huntActive
        if case .showNextProp = call { revealProps(after: before) }
        if store.props == nil { shownProps = 0 }
        return (output, call != .finishPlanning)
    }

    /// Nutmeg's on-screen state, derived from everything that's happening.
    var nutmegState: NutmegState {
        #if DEBUG
        if let s = DemoDriver.forcedState { return s }
        #endif
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
        case .stepBack: return .napping
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
        beat = .lookUp
        try? await Task.sleep(for: .milliseconds(550))
        beat = .none
    }

    /// Prop cards on stage. A new card waits until the turn that was playing when it was requested has finished (never
    /// mid-sentence about the roles): it appears with her prop line, or once playback drains.
    private(set) var shownProps = 0
    /// Without a live session (demo screenshots, tap fallback) every card shows at once.
    var visibleProps: Int { realtime.isLive ? shownProps : (store.props?.props.count ?? 0) }
    private func revealProps(after serial: Int) {
        Task { @MainActor in
            // A new prop card waits for the writing beat too: it appears as she looks up and announces it.
            while beat != .none || (realtime.isSpeaking && realtime.audioResponseSerial <= serial) { try? await Task.sleep(for: .milliseconds(50)) }
            shownProps = store.props?.props.count ?? 0
        }
    }

    /// Backup buttons on the current prop card (noisy rooms): the one planning tap.
    func huntReply(found: Bool) {
        guard let p = store.props?.props.first(where: { $0.id == store.currentPropID }) else { return }
        let name = p.householdItem.lowercased()
        realtime.sendText(found ? "Nutmeg, we found the \(name)!" : "Nutmeg, we don't have a \(name).")
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
    func gesture(_ g: NutmegGesture) { cue = NutmegCue(gesture: g) }

    /// Nutmeg's voice for app-written lines. With a live Realtime session she keeps her conversation voice;
    /// during planning she speaks for herself, so app lines are skipped there.
    func speak(_ text: String) {
        if realtime.isLive {
            if !Self.isPlanning(store.phase) { realtime.say(text) }
            return
        }
        Task { await voice.say(text) }
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
