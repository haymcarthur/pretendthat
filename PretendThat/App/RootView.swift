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
        Group {
            if model.inConversation { conversation.transition(.opacity) } else { classic.transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.4), value: model.inConversation)
        .environment(\.speak, SpeakAction { model.speak($0) })
        .environment(\.ptCelebrate, model.celebrations)
        .onChange(of: store.nutmegLine) { _, line in model.speak(line) }
        .onChange(of: store.phase) { _, phase in
            model.phaseChanged()
            switch phase {
            case .kitReady, .end: model.gesture(.celebrate); model.celebrations += 1
            case .hello: model.gesture(.wave)
            default: break
            }
        }
        .onChange(of: store.presenting) { _, p in if p != .none { model.gesture(.point) } }
        .onChange(of: store.kit) { _, _ in model.kitChanged() }
        .onChange(of: presentedSubjects) { _, _ in requestStickers() }
        .task {
            #if DEBUG
            if let demo = DemoDriver.requestedPhase { await DemoDriver.drive(store, model: model, to: demo) }
            if let turns = DemoDriver.liveTurns { await DemoDriver.live(model, turns: turns) }
            #endif
            await model.listener.requestAuth()
        }
        .sheet(isPresented: $showSettings) { ParentSettingsView(model: model) }
        .sheet(isPresented: $showTyping) { PTTypeSheet { text in Task { await model.typed(text) } } }
        .preferredColorScheme(.light)
        .statusBarHidden()
    }

    // MARK: Voice conversation (D1, D4, D5)

    private var conversation: some View {
        PTConversationStage(backdrop: .white, shot: shot, items: stageItems,
                            onTapItem: { id in silentTap(id) }) {
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel,
                            isSpeaking: model.isSpeaking, cue: model.cue)
        } bar: {
            PTVoiceBar(isMuted: model.realtime.isMuted, isListening: model.realtime.kidIsTalking,
                       onMute: { model.realtime.isMuted.toggle() },
                       onLeave: { model.leave() },
                       onType: { showTyping = true })
        }
    }

    private var shot: PTCameraShot {
        if store.presenting != .none { return .wide }
        if model.realtime.isSpeaking || model.realtime.kidIsTalking { return .closeUp }
        return .medium
    }

    private var stageItems: [PTStageItem] {
        switch store.presenting {
        case .none: return []
        case .ideas:
            return (store.ideas?.ideas ?? []).enumerated().map { i, idea in
                PTStageItem(id: "idea-\(idea.title)", title: idea.title,
                            image: model.stickers.image(.idea, idea.title), tint: Theme.playerColor(i))
            }
        case .roles:
            return (store.plan?.roles ?? []).map { r in
                let p = store.players.first { $0.token == r.player }
                return PTStageItem(id: "role-\(r.player.rawValue)-\(r.roleName)", title: store.tokens.untokenize(r.roleName),
                                   subtitle: store.directorMode ? nil : p?.displayName,
                                   image: model.stickers.image(.role, r.roleName), tint: Theme.playerColor(r.player.index))
            }
        case .props:
            return (store.props?.props ?? []).enumerated().map { i, prop in
                // Library props use the hand-drawn art (prop-<id>); off-list props fall back to a generated sticker.
                let art = prop.libraryID.flatMap { UIImage(named: PropLibrary.asset($0)) } ?? model.stickers.image(.prop, prop.householdItem)
                return PTStageItem(id: "prop-\(prop.id)", title: prop.householdItem,
                                   subtitle: store.tokens.untokenize(prop.becomes),
                                   image: art, tint: Theme.playerColor(i),
                                   flipKey: prop.libraryID ?? prop.householdItem, isPretend: prop.isSkipped)
            }
        }
    }

    /// Subjects on stage right now; a change starts their illustrations.
    private var presentedSubjects: [String] {
        (store.ideas?.ideas.map(\.title) ?? []) + (store.plan?.roles.map(\.roleName) ?? []) + (store.props?.props.map(\.householdItem) ?? [])
    }

    private func requestStickers() {
        let game = store.gameTitle
        var jobs: [(kind: StickerPrompt.Kind, subject: String, detail: String)] = []
        jobs += (store.ideas?.ideas ?? []).map { (.idea, $0.title, $0.pitch) }
        // Roles and props: role/prop text only (names are tokenized out and never sent).
        jobs += (store.plan?.roles ?? []).map { (.role, $0.roleName, "") }
        // Props: only off-list ones get generated art (library props are hand-drawn).
        let offList = (store.props?.props ?? []).filter { $0.libraryID == nil }
        if !offList.isEmpty { rtLog("off-list props (generated art): \(offList.count)") }
        jobs += offList.map { (.prop, $0.householdItem, $0.becomes.replacingOccurrences(of: #"\{P\d\}"#, with: "a kid", options: .regularExpression)) }
        model.stickers.request(jobs, game: game)
    }

    /// Silent backup: tapping an idea picks it, as if the kid had said it.
    private func silentTap(_ id: String) {
        guard store.presenting == .ideas, let title = store.ideas?.ideas.first(where: { "idea-\($0.title)" == id })?.title else { return }
        model.realtime.sendText("Let's play \(title)!")
    }

    // MARK: Classic stage (setup fallback, kit and play)

    private var classic: some View {
        PTStageLayout(backdrop: backdrop, nutmegColumn: nutmegIsHero ? Theme.nutmegHeroColumn : Theme.nutmegColumn) {
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel,
                            isSpeaking: model.isSpeaking, cue: model.cue)
                .onTapGesture { if case .stepBack = store.phase { Task { _ = await store.helpRequested() } } }
        } stage: {
            stage.transition(.ptStage)
                .id(stageID)
        } bottom: {
            bottomBar
        }
        .animation(Theme.bouncy, value: stageID)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: stageID)
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
            Button { model.leave() } label: { Label("Home", systemImage: "house.fill") }.buttonStyle(.ptQuiet)
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

    /// One clean white base everywhere (Haylee, motion-and-surface.md); brand colors live on accents only.
    private var backdrop: PTBackdrop { .white }

    /// Nutmeg gets the big column when the stage has little else on it.
    private var nutmegIsHero: Bool {
        switch store.phase {
        case .hello, .stepBack, .end, .handoff: true
        default: false
        }
    }
}

extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
