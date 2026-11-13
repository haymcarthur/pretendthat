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
        realtime.onCall = { [weak self] name, args in
            guard let self else { return ("ok", true) }
            return await self.handleCall(name: name, arguments: args)
        }
    }

    // MARK: Voice conversation

    var hasRealtime: Bool { openAIKey != nil }
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
        let ok = await realtime.connect(apiKey: key, voice: voiceSettings.voice,
                                        pitchCents: voiceSettings.pitchCents, speed: voiceSettings.speed)
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
        if realtime.isLive {
            if realtime.kidIsTalking { return .listening }
            if realtime.isSpeaking { return .talking }
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

    var mouthLevel: Float { realtime.isLive ? realtime.level : voice.level }
    var isSpeaking: Bool { realtime.isLive ? realtime.isSpeaking : voice.isSpeaking }

    func micPressed() { listener.startListening(stopping: voice) }

    func micReleased() {
        Task {
            let text = await listener.stopListening()
            guard !text.isEmpty else { return }
            await handleSpeech(text)
        }
    }

    /// Routes a spoken answer by phase (names on the players screen, ideas on pick-game, chat elsewhere).
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
        case .players where store.plan == nil:
            if let next = store.players.first(where: { $0.name.isEmpty }) {
                store.setName(Self.firstName(from: text), for: next.token)
            }
        default:
            await store.kidSaid(text)
        }
    }

    /// "My name is Mia" → "Mia".
    static func firstName(from text: String) -> String {
        let words = text.split(separator: " ").map(String.init)
        let skip: Set<String> = ["my", "name", "is", "i'm", "im", "i", "am", "it's", "its", "called"]
        return words.first { !skip.contains($0.lowercased()) }?.capitalized ?? text
    }
}
