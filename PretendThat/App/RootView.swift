import SwiftUI
import NutmegCore

/// Switches on the adventure phase. Every kid screen shares one stage layout:
/// Nutmeg on the left third, the stage on the right, mic and "again" along the bottom.
struct RootView: View {
    @State private var model = AppModel()
    @State private var showSettings = false
    @State private var showTyping = false
    @State private var chatOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cameraShot: PTCameraShot = .medium
    @State private var lastShotChange = Date.distantPast
    @State private var shotTask: Task<Void, Never>?

    private var store: AdventureStore { model.store }

    var body: some View {
        // Layout (layout-toycad-style.md, style revised): light canvas, Nutmeg centered as the hero, a white step rail
        // on the left, a white control pill at the bottom, and a chat panel that slides in from the right.
        ZStack {
            // The same stage as the start screen (sky, floor, tied-back curtains, valance) under every game screen.
            PTStageBackdrop(floor: !model.inConversation)
            #if DEBUG
            if let art = DemoDriver.requestedPhase, art.hasPrefix("art") { ArtCheckView(mode: art).zIndex(10) }
            #endif
            HStack(spacing: Theme.Space.m) {
                Group {
                    // The conversation stage spans the whole area left of the chat panel so Nutmeg centers on the
                    // screen (and the control pill); it keeps its cards clear of the rail and pill itself.
                    if store.phase == .hello {
                        // Start screen: full-bleed toy-chest scene, no step rail or control pill.
                        // Start screen → conversation: the start screen's exit leaves Nutmeg exactly where the conversation
                        // draws her on the same stage, so the swap is instant (no crossfade of two Nutmegs).
                        HelloView(model: model, onGrownUps: { showSettings = true })
                            .transition(reduceMotion ? .opacity : .identity)
                    } else if model.inConversation {
                        conversation.transition(.asymmetric(insertion: reduceMotion ? .opacity : .identity, removal: .opacity))
                    } else {
                        // From the start screen (no voice: tap screens) the stage is already there: no fade from empty.
                        classic.transition(.asymmetric(insertion: store.phase == .pickGame && !reduceMotion ? .identity : .opacity, removal: .opacity))
                            .padding(.leading, chromeVisible ? 104 : 0)
                            .padding(.bottom, chromeVisible ? 92 : 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if chatOpen && chromeVisible {
                    PTChatPanel(lines: model.realtime.transcript.map { PTChatPanel.Line(id: $0.id, fromNutmeg: $0.fromNutmeg, text: $0.text) },
                                onSend: { text in Task { await model.typed(text) } },
                                onClose: { chatOpen = false })
                        .padding([.vertical, .trailing], Theme.Space.m)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            if chromeVisible {
                PTStepRail(current: store.phase.step, reached: store.reachedStep) { store.goTo($0) }
                    .padding(.leading, Theme.Space.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                PTControlBar(isMuted: model.realtime.isMuted, isListening: model.realtime.kidIsTalking, chatOpen: chatOpen,
                             micAvailable: model.realtime.isLive,
                             onMute: { if model.realtime.isLive { model.realtime.isMuted.toggle() } else { chatOpen = true } },
                             onChat: { chatOpen.toggle() },
                             onLeave: { chatOpen = false; model.leave() })
                    .padding(.bottom, Theme.Space.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: chatOpen)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: chromeVisible)
        .animation(.easeInOut(duration: 0.4), value: model.inConversation)
        .environment(\.speak, SpeakAction { model.speak($0) })
        .environment(\.ptCelebrate, model.celebrations)
        .onChange(of: store.nutmegLine) { _, line in model.speak(line) }
        .onChange(of: store.phase) { _, phase in
            model.phaseChanged()
            switch phase {
            case .kitReady: model.celebrations += 1   // Nutmeg celebrates when the papers have landed (KitView)
            case .end: model.gesture(.celebrate); model.celebrations += 1
            case .hello: model.gesture(.wave)
            default: break
            }
        }
        .onChange(of: store.presenting) { _, p in if p != .none { model.gesture(.point) } }
        .onChange(of: desiredShot) { _, _ in scheduleShot() }
        .onChange(of: model.inConversation) { _, live in
            if live { scheduleShot(arrival: true) } else { shotTask?.cancel(); cameraShot = .medium; lastShotChange = .distantPast }
        }
        .onChange(of: store.kit) { _, _ in model.kitChanged() }
        .onChange(of: presentedSubjects) { _, _ in requestStickers() }
        .task {
            #if DEBUG
            if DemoDriver.chatOpen { chatOpen = true }
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
        PTConversationStage(backdrop: .clear, shot: shot, items: stageItems,
                            leadingInset: chromeVisible ? PTStageCamera.chromeLeading : 0, bottomInset: chromeVisible ? PTStageCamera.chromeBottom : 0,
                            faceFocus: model.nutmegState.basePose.faceFocus, centerBetweenChrome: chatOpen && chromeVisible,
                            onTapItem: { id in silentTap(id) }) {
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                            isSpeaking: model.isSpeaking, cue: model.cue, showsGround: true)
        } bar: {
            EmptyView()
        }
    }

    /// Camera (decisions/conversation-camera-and-expressions.md): stays close on her face for the whole planning
    /// chat (while she talks AND while the kid talks); zooms out only when cards need the room. She arrives from the
    /// start screen at the medium shot, then the camera eases in. Changes are at least `minShotGap` apart, except
    /// zooming out for cards (they must never cover her face).
    private var shot: PTCameraShot {
        #if DEBUG
        if let forced = DemoDriver.forcedShot { return forced }
        #endif
        return cameraShot
    }
    private var desiredShot: PTCameraShot { stageItems.isEmpty ? .closeUp : .wide }
    private static let minShotGap: TimeInterval = 2

    private func scheduleShot(arrival: Bool = false) {
        shotTask?.cancel()
        shotTask = Task { @MainActor in
            let target = desiredShot
            guard target != cameraShot else { return }
            var wait = max(0, Self.minShotGap - Date().timeIntervalSince(lastShotChange))
            if target == .wide { wait = 0 }
            if arrival { wait = max(wait, 0.9) }   // let her landing settle first
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled, desiredShot != cameraShot else { return }
            cameraShot = desiredShot
            lastShotChange = Date()
        }
    }

    private var stageItems: [PTStageItem] {
        switch store.presenting {
        case .none: return []
        case .props:
            return (store.props?.props ?? []).enumerated().map { i, prop in
                // Library props use the hand-drawn art (prop-<id>); off-list props fall back to a generated sticker.
                let art = prop.libraryID.flatMap { UIImage(named: PropLibrary.asset($0)) } ?? model.stickers.art(.prop, prop.householdItem)
                return PTStageItem(id: "prop-\(prop.id)", title: prop.householdItem,
                                   subtitle: prop.becomes,
                                   image: art, tint: Theme.playerColor(i),
                                   flipKey: prop.libraryID ?? prop.householdItem, isPretend: prop.isSkipped,
                                   chip: prop.isSkipped ? .pretend : (store.foundProps.contains(prop.id) ? .found : (prop.swapped == true ? .swapped : .none)))
            }
        }
    }

    /// Subjects on stage right now; a change starts their illustrations.
    private var presentedSubjects: [String] {
        store.props?.props.map(\.householdItem) ?? []
    }

    private func requestStickers() {
        let game = store.gameTitle
        var jobs: [(kind: StickerPrompt.Kind, subject: String, detail: String)] = []
        // No idea or role cards (Haylee): ideas are spoken and roles are printed on badges, so only props get art.
        // Props: only off-list ones get generated art (library props are hand-drawn).
        let offList = (store.props?.props ?? []).filter { $0.libraryID == nil }
        if !offList.isEmpty { rtLog("off-list props (generated art): \(offList.count)") }
        jobs += offList.map { (.prop, $0.householdItem, $0.becomes) }
        model.stickers.request(jobs, game: game)
    }

    /// Prop cards are display-only (D3: kids tap only to print and to play).
    private func silentTap(_ id: String) {}

    // MARK: Classic stage (setup fallback, kit and play)

    private var classic: some View {
        PTStageLayout(backdrop: .clear, nutmegColumn: nutmegIsHero ? Theme.nutmegHeroColumn : Theme.nutmegColumn) {
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                            isSpeaking: model.isSpeaking, cue: model.cue, showsGround: true)
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
        case .hello: EmptyView()   // the start screen replaces the classic stage (see body)
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
        if store.lastError != nil {
            Button { Task { await store.retry() } } label: { Label("Try again", systemImage: "arrow.clockwise") }.buttonStyle(.ptSecondary)
            Button { store.useFallback() } label: { Label("Play airplane", systemImage: "airplane") }.buttonStyle(.ptQuiet)
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

    /// Step rail and control pill show from the first step on (not on Hello).
    private var chromeVisible: Bool { store.phase != .hello }

    /// Nutmeg gets the big column when the stage has little else on it.
    private var nutmegIsHero: Bool {
        switch store.phase {
        case .hello, .stepBack, .end, .handoff: true
        default: false
        }
    }
}

extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
