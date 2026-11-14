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
    }

    /// Kit art runs in its own task, NOT tied to the kit screen's lifetime: a `.task` on the view was cancelled
    /// as soon as the kids tapped "Let's play!" (or the stage re-rendered), which cancelled every image request
    /// and left the pages app-drawn.
    func kitChanged() {
        guard let kit = store.kit else { return }
        let title = store.plan?.gameTitle ?? store.gameTitle ?? "Pretend"
        Task { await art.generate(kit: kit, gameTitle: title) }
    }

    private func handleCall(name: String, arguments: String) async -> (output: String, respond: Bool) {
        guard let call = PlanningCall.decode(name: name, arguments: arguments) else {
            return ("I couldn't use that. Try again with the right fields.", true)
        }
        let output = await store.apply(call)
        return (output, call != .finishPlanning)
    }

    /// Nutmeg's on-screen state, derived from everything that's happening.
    var nutmegState: NutmegState {
        #if DEBUG
        if let s = DemoDriver.forcedState { return s }
        #endif
        if realtime.isLive {
            // Conversation faces (decisions/conversation-camera-and-expressions.md): listening while the kid talks,
            // thinking in the gap before her reply, then the face the model chose (eyes and brows; the live mouth
            // animates on top), happy by default.
            if realtime.kidIsTalking { return .listening }
            if let e = realtime.expression { return Self.state(for: e) }
            if realtime.thinkingGap { return .thinking }
            if realtime.isSpeaking { return .idle }
        }
        if listener.isListening { return .listening }
        if store.phase == .makingKit { return .coloring }
        if store.isWorking { return .thinking }
        if voice.isSpeaking { return .talking }
        if store.lastError != nil { return .oops }
        switch store.phase {
        case .makingKit: return .coloring
        case .stepBack: return .napping
        case .kitReady, .end: return .excited
        default: return .idle
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
