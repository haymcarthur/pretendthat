import SwiftUI
import NutmegCore

/// Wires the state machine to Nutmeg's voice, ears and kit art. One per app run; nothing is persisted.
@Observable @MainActor
final class AppModel {
    let store: AdventureStore
    let voice = NutmegVoice()
    let listener = Listener()
    let art: KitArtService
    let hasClaude: Bool
    let hasImages: Bool

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
    }

    /// Nutmeg's on-screen state, derived from everything that's happening.
    var nutmegState: NutmegState {
        if listener.isListening { return .listening }
        if store.isWorking { return .thinking }
        if voice.isSpeaking { return .talking }
        if store.lastError != nil { return .oops }
        switch store.phase {
        case .stepBack: return .napping
        case .kitReady, .end: return .excited
        default: return .idle
        }
    }

    var nutmegPose: NutmegPose? {
        switch store.phase {
        case .pickGame, .props, .players: .point
        case .stepBack: .sit
        default: nil
        }
    }

    func speak(_ text: String) { Task { await voice.say(text) } }

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
