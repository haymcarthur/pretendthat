import SwiftUI
import NutmegCore

/// Switches on the adventure phase. Every kid screen shares one stage layout:
/// Nutmeg on the left third, the stage on the right, mic and "again" along the bottom.
struct RootView: View {
    @State private var model = AppModel()
    @State private var showSettings = false
    @State private var showTyping = false

    private var store: AdventureStore { model.store }

    var body: some View {
        PTStageLayout(backdrop: backdrop, nutmegColumn: nutmegIsHero ? Theme.nutmegHeroColumn : Theme.nutmegColumn) {
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.voice.level,
                            isSpeaking: model.voice.isSpeaking, pose: model.nutmegPose)
                .onTapGesture { if case .stepBack = store.phase { Task { _ = await store.helpRequested() } } }
        } stage: {
            stage.transition(.ptStage)
                .id(stageID)
        } bottom: {
            bottomBar
        }
        .animation(Theme.bouncy, value: stageID)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: stageID)
        .environment(\.speak, SpeakAction { model.speak($0) })
        .onChange(of: store.nutmegLine) { _, line in model.speak(line) }
        .task {
            #if DEBUG
            if let demo = DemoDriver.requestedPhase { await DemoDriver.drive(store, to: demo) }
            #endif
            await model.listener.requestAuth()
        }
        .sheet(isPresented: $showSettings) { ParentSettingsView(model: model) }
        .sheet(isPresented: $showTyping) { PTTypeSheet { text in Task { await model.handleSpeech(text) } } }
        .preferredColorScheme(.light)
        .statusBarHidden()
    }

    @ViewBuilder private var stage: some View {
        switch store.phase {
        case .hello: HelloView(model: model)
        case .pickGame: PickGameView(model: model)
        case .players: PlayersView(model: model)
        case .props: PropsView(model: model)
        case .makingKit, .kitReady: KitView(model: model)
        case .handoff(let i): HandoffView(model: model, sceneIndex: i)
        case .scene(let i): SceneView(model: model, index: i)
        case .stepBack: StepBackView(model: model)
        case .end: EndView(model: model)
        }
    }

    @ViewBuilder private var bottomBar: some View {
        if store.phase == .hello {
            PTParentGate(label: "Grown-ups", symbol: "gearshape.fill") { showSettings = true }
        }
        Spacer()
        if store.lastError != nil {
            Button { Task { await store.retry() } } label: { Label("Try again", systemImage: "arrow.clockwise") }.buttonStyle(.ptSecondary)
            Button { store.useFallback() } label: { Label("Play airplane", systemImage: "airplane") }.buttonStyle(.ptQuiet)
        }
        PTMicButton(isListening: model.listener.isListening, isAvailable: model.listener.available,
                    onPress: model.micPressed, onRelease: model.micReleased, onTypeInstead: { showTyping = true })
        PTReplayButton { if let line = model.voice.lastLine ?? store.nutmegLine.nilIfEmpty { model.speak(line) } }
        Spacer()
        if store.phase != .hello {
            Button { model.art.reset(); store.newGame() } label: { Label("Home", systemImage: "house.fill") }.buttonStyle(.ptQuiet)
        }
    }

    private var stageID: String {
        switch store.phase {
        case .handoff(let i): "handoff\(i)"
        case .scene(let i): "scene\(i)"
        case .stepBack(let i): "step\(i)"
        case .makingKit, .kitReady: "kit"
        default: "\(store.phase)"
        }
    }

    private var backdrop: PTBackdrop {
        switch store.phase {
        case .hello, .scene, .stepBack: .backstage      // the theater: purple for play mode
        case .kitReady, .end: .spotlight                // celebration moments
        case .handoff: .cream
        default: .white
        }
    }

    /// Nutmeg gets the big column when the stage has little else on it.
    private var nutmegIsHero: Bool {
        switch store.phase {
        case .hello, .stepBack, .end, .handoff: true
        default: false
        }
    }
}

extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
