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
    /// Round 9: lock / background never ends the game; only the audio pauses (AppModel.scenePhaseChanged).
    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraShot: PTCameraShot = .wide   // the arrival shot
    @State private var lastShotChange = Date.distantPast
    @State private var shotTask: Task<Void, Never>?
    @Namespace private var huntSpace
    /// Full-size kit page preview (opened from the fan or from the chat panel's pinned papers).
    @State private var kitPreview: PTPreviewTarget?
    /// Close asks first (decisions/2026-11-13-push-to-talk.md).
    @State private var confirmLeave = false
    /// Kit-ready confetti, drawn as the topmost overlay (above the chat panel, step rail and control pill).
    @State private var confettiRun = 0
    @State private var confettiOn = false

    private var store: AdventureStore { model.store }

    var body: some View {
        // Layout (layout-toycad-style.md, style revised): light canvas, Nutmeg centered as the hero, a white step rail
        // on the left, a white control pill at the bottom, and a chat panel that slides in from the right.
        ZStack {
            // The same stage as the start screen (sky, floor, tied-back curtains, valance) under every game screen.
            // The floor is drawn by the shared stage (it moves with Nutmeg); the start screen draws its own.
            PTStageBackdrop(floor: false)
            #if DEBUG
            if let art = DemoDriver.requestedPhase, art.hasPrefix("art") { ArtCheckView(mode: art).zIndex(10) }
            #endif
            HStack(spacing: Theme.Space.m) {
                Group {
                    // The conversation stage spans the whole area left of the chat panel so Nutmeg centers on the
                    // screen (and the control pill); it keeps its cards clear of the rail and pill itself.
                    if store.phase == .hello {
                        // Start screen: full-bleed toy-chest scene, no step rail or control pill.
                        // Start screen → stage: the start screen's exit leaves Nutmeg exactly where the stage draws her
                        // (the arrival shot), so the swap is instant (no crossfade of two Nutmegs).
                        HelloView(model: model, onGrownUps: { showSettings = true })
                            .transition(reduceMotion ? .opacity : .identity)
                    } else {
                        // ONE stage for every phase (conversation, hunt, kit, play, hand-off): same Nutmeg, floor and
                        // stars, one camera; each phase only picks a frame.
                        sharedStage.transition(.asymmetric(insertion: reduceMotion ? .opacity : .identity, removal: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if chatOpen && chromeVisible {
                    PTChatPanel(lines: model.realtime.transcript.map { PTChatPanel.Line(id: $0.id, fromNutmeg: $0.fromNutmeg, text: $0.text) },
                                onSend: { text in Task { await model.typed(text) } },
                                onClose: { chatOpen = false },
                                pinnedKey: pinnedKey, pinned: pinnedCard)
                        .padding([.vertical, .trailing], Theme.Space.m)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            if chromeVisible {
                PTStepRail(current: store.phase.step, reached: store.reachedStep) { store.goTo($0) }
                    .padding(.leading, Theme.Space.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                PTControlBar(chatOpen: chatOpen, mic: micMode,
                             onChat: { chatOpen.toggle() },
                             onMicPress: { model.talkPressed() },
                             onMicRelease: { model.talkReleased() },
                             onClose: { confirmLeave = true })
                    .padding(.bottom, Theme.Space.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    // Writing moment: the pill steps aside so the screen's bottom edge crops just below the clipboard
                    // top (her paws out of frame, the crayon's top end visible). Hiding it releases a held mic.
                    .opacity(model.isWriting ? 0 : 1)
                    .allowsHitTesting(!model.isWriting)
                    .animation(.easeInOut(duration: 0.25), value: model.isWriting)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if confirmLeave {
                PTLeaveDialog(onStay: { confirmLeave = false },
                              onLeave: { confirmLeave = false; chatOpen = false; model.leave() })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(20)
            }
            // Confetti last: the topmost layer, never blocks a tap.
            if confettiOn {
                PTConfetti().id(confettiRun).ignoresSafeArea().allowsHitTesting(false).zIndex(30)
                    .accessibilityHidden(true)
            }
        }
        .animation(.easeOut(duration: 0.2), value: confirmLeave)
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
            case .handoff: model.gesture(.point)   // toward the hand-off card
            default: break
            }
        }
        .onChange(of: scenePhase) { _, phase in model.scenePhaseChanged(phase) }
        .onChange(of: store.phase) { _, _ in model.updateIdleTimer() }
        .onChange(of: model.kitPapersOut) { _, _ in model.updateIdleTimer() }
        .onChange(of: desiredShot) { _, _ in scheduleShot() }
        // Round 7: the point toward a prop card is tied to the card's reveal and her prop line (AppModel.pointAtCard).
        .onChange(of: model.inConversation) { _, live in
            if live { scheduleShot(arrival: true) } else { shotTask?.cancel(); cameraShot = .wide; lastShotChange = .distantPast }
        }
        .onChange(of: store.kit) { _, _ in model.kitChanged() }
        .onChange(of: model.kitFinal) { _, final in model.kitFinalChanged(final) }
        .onChange(of: model.isWriting) { _, on in
            model.scribble.setPlaying(on, ducked: model.isSpeaking)
            if on { model.talkReleased() }   // the pill steps aside: a held mic is let go (sent or cleared)
        }
        .onChange(of: model.isSpeaking) { _, talking in if model.isWriting { model.scribble.setPlaying(true, ducked: talking) } }
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

    // MARK: The shared stage (every phase)

    private var sharedStage: some View {
        PTStageView(leadingInset: chromeVisible ? PTStageCamera.chromeLeading : 0,
                    bottomInset: chromeVisible ? PTStageCamera.chromeBottom : 0,
                    chatOpen: chatOpen && chromeVisible,
                    faceFocus: (debugPose ?? model.nutmegRestPose).faceFocus,
                    frame: { g in stageFrame(g) }, itemCount: stageItems.count) {
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                            isSpeaking: model.isSpeaking, cue: model.cue, forcedPose: debugPose, showsGround: true,
                            holdsClipboard: model.nutmegHoldsClipboard, writing: model.isWriting)
                .onTapGesture { if case .stepBack = store.phase { Task { _ = await store.helpRequested() } } }
        } overlay: { g, L in
            if model.inConversation {
                if huntOnStage {
                    // Hidden while she writes in the close shot (the cards are laid out for the hunt's medium shot).
                    PTPropHuntStage(items: stageItems, geometry: g, nutmeg: L, curtainInset: curtainInset(g), namespace: huntSpace,
                                    onHunt: { _, found in model.huntReply(found: found) })
                        .opacity(model.isWriting ? 0 : 1)
                        .animation(.easeInOut(duration: 0.25), value: model.isWriting)
                } else if shot == .wide && !model.isWriting {
                    PTPresentedCards(items: stageItems, nutmeg: L, size: g.size, onTapItem: { silentTap($0) },
                                     onHunt: { _, found in model.huntReply(found: found) })
                }
            } else {
                classicContent(g, L)
            }
        }
    }

    private var debugPose: NutmegPose? {
        #if DEBUG
        return DemoDriver.forcedPose
        #else
        return nil
        #endif
    }

    /// The frame (shot + lane) this phase asks the one stage camera for.
    private func stageFrame(_ g: PTStageGeometry) -> PTStageFrame {
        // Round 8: chat open in a scene, the checklist is pinned in the panel, so she stands centered on the stage.
        if case .scene = store.phase, g.chatOpen, !model.inConversation { return PTStageFrame(shot: .wide) }
        return PTStageDirector.frame(phase: store.phase, conversation: model.inConversation, conversationShot: shot,
                              cards: stageItems.count, hunt: huntOnStage, kitBeat: model.kitBeat,
                              curtainInset: curtainInset(g), writing: model.isWriting, g)
    }

    /// What's docked at the top of the chat panel: the hunt's active prop, or the kit papers once they're out.
    private var pinnedKey: String? {
        if huntOnStage, let active = stageItems.last(where: { !$0.isDone }) { return active.id }
        if model.kitPapersOut { return "kit-papers" }
        if case .scene(let i) = store.phase { return "scene-\(i)" }   // round 8: the checklist docks in the chat panel
        return nil
    }
    private var pinnedCard: AnyView? {
        if case .scene(let i) = store.phase, !huntOnStage, !model.kitPapersOut { return AnyView(PTScenePinnedCard(model: model, index: i)) }
        if huntOnStage, let active = stageItems.last(where: { !$0.isDone }) {
            return AnyView(PTPropPinnedCard(item: active, onHunt: active.huntButtons ? { model.huntReply(found: $0) } : nil)
                .matchedGeometryEffect(id: ptHuntActiveID, in: huntSpace))
        }
        if model.kitPapersOut {
            let pages = model.kitPages
            return AnyView(PTKitPinnedCard(count: pages.count, onTap: { i in
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { kitPreview = PTPreviewTarget(index: i) }
            }, onPrint: { model.printKit() }, onPlay: { store.beginPlay() }) { i in
                KitPageView(page: pages[i], art: model.art.images[pages[i].item.id], cutouts: model.art.cutoutImages(pages[i].item))
                    .scaleEffect(PTKitPinnedCard<EmptyView>.thumb.width / KitPageView.size.width)
                    .frame(width: PTKitPinnedCard<EmptyView>.thumb.width, height: PTKitPinnedCard<EmptyView>.thumb.height)
            })
        }
        return nil
    }

    /// The prop hunt layout is on stage (the camera has moved to the hunt's medium shot).
    private var huntOnStage: Bool { model.inConversation && store.huntActive && shot == .medium }

    /// How far the tied-back curtain reaches in around card height.
    private func curtainInset(_ g: PTStageGeometry) -> CGFloat { PTCurtain.metrics(g.size).visible * 0.55 }

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
    private var desiredShot: PTCameraShot { store.huntActive ? .medium : (stageItems.isEmpty ? .closeUp : .wide) }
    private static let minShotGap: TimeInterval = 2

    private func scheduleShot(arrival: Bool = false) {
        shotTask?.cancel()
        shotTask = Task { @MainActor in
            let target = desiredShot
            guard target != cameraShot else { return }
            var wait = max(0, Self.minShotGap - Date().timeIntervalSince(lastShotChange))
            if target == .wide || target == .medium { wait = 0 }
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
            return (store.props?.props ?? []).prefix(model.visibleProps).enumerated().map { i, prop in
                // Library props use the hand-drawn art (prop-<id>); off-list props fall back to a generated sticker.
                let art = prop.libraryID.flatMap { UIImage(named: PropLibrary.asset($0)) } ?? model.stickers.art(.prop, prop.householdItem)
                return PTStageItem(id: "prop-\(prop.id)", title: prop.householdItem,
                                   subtitle: prop.becomes,
                                   image: art, tint: Theme.playerColor(i),
                                   flipKey: prop.libraryID ?? prop.householdItem, isPretend: prop.isSkipped,
                                   chip: prop.isSkipped ? .pretend : (store.foundProps.contains(prop.id) ? .found : (prop.swapped == true ? .swapped : .none)),
                                   huntButtons: store.huntActive && prop.id == store.currentPropID
                                       && !store.foundProps.contains(prop.id) && !prop.isSkipped)
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

    // MARK: Phase content beside Nutmeg (tap fallback, kit papers, play, hand-off)

    /// Screen-space content right of her lane. Kit: nothing while she colors in the close-up (the papers wait for the
    /// whole kit, no-text-overlays.md); the papers fly off her clipboard once the camera has zoomed out.
    @ViewBuilder private func classicContent(_ g: PTStageGeometry, _ L: PTStageCamera.Layout) -> some View {
        let kitStep = store.phase == .makingKit || store.phase == .kitReady
        let r = kitStep ? PTStageDirector.huntContent(g, nutmeg: L, curtainInset: curtainInset(g))   // the hunt card's zone
                        : PTStageDirector.sideContent(g, curtainInset: g.chatOpen ? 12 : curtainInset(g))   // the panel hides the curtain
        let minW = kitStep ? Self.kitContentWidth : Self.contentWidth
        let kitWaiting = (store.phase == .makingKit || store.phase == .kitReady) && model.kitBeat != .papers
        VStack(spacing: Theme.Space.m) {
            ViewThatFits(in: .vertical) {
                stage(clipboard: clipboard(L, in: r)).padding(.vertical, Theme.Space.s)
                ScrollView(.vertical) { stage(clipboard: clipboard(L, in: r)).padding(.vertical, Theme.Space.m) }.scrollIndicators(.visible)
            }
            .transition(.ptStage)
            .id(stageID)
            if store.lastError != nil { HStack(spacing: Theme.Space.l) { bottomBar } }
        }
        // Content needs ~460 pt; beside her (minimum size) with the chat open it scales down to fit.
        .frame(width: max(r.width, minW), height: r.height / min(1, r.width / minW))
        .scaleEffect(min(1, r.width / minW))
        .frame(width: r.width, height: r.height)
        .position(x: r.midX, y: r.midY)
        .opacity(kitWaiting ? 0 : 1)
        .animation(Theme.bouncy, value: stageID)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: stageID)
    }

    private static let contentWidth: CGFloat = 460
    /// The kit pages zone is the hunt card's (narrower): the fan and the stacked buttons need ~280 pt.
    private static let kitContentWidth: CGFloat = 280
    private func fit(_ r: CGRect) -> CGFloat { min(1, r.width / Self.contentWidth) }

    /// Her clipboard (idle pose, canvas px) relative to the content rect's center: where the papers fly from.
    private func clipboard(_ L: PTStageCamera.Layout, in r: CGRect) -> CGPoint {
        let p = L.screen(CGPoint(x: 521, y: 933))   // round 4 idle clipboard center
        return CGPoint(x: p.x - r.midX, y: p.y - r.midY)
    }

    @ViewBuilder private func stage(clipboard: CGPoint) -> some View {
        switch store.phase {
        case .hello: EmptyView()   // the start screen replaces the classic stage (see body)
        case .pickGame: EmptyView()   // games are talked about only: no idea cards, no caption (no-text-overlays.md)
        case .players: PlayersView(model: model)
        case .props: PropsView(model: model)
        case .makingKit, .kitReady: KitView(model: model, clipboard: clipboard, chatOpen: chatOpen && chromeVisible, preview: $kitPreview,
                                            onCelebrate: { celebrate() })
        case .handoff(let i): HandoffView(model: model, sceneIndex: i)
        case .scene(let i): if !(chatOpen && chromeVisible) { SceneView(model: model, index: i) }   // chat open: pinned in the panel
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

    /// Kit-ready confetti over everything for one run (PTConfetti draws ~2.6 s), then it's removed.
    private func celebrate() {
        confettiRun += 1
        confettiOn = true
        let run = confettiRun
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if run == confettiRun { confettiOn = false }
        }
    }

    private var micMode: PTMicButton.Mode {
        switch model.micState { case .idle: .idle; case .listening: .listening; case .disabled: .disabled }
    }

    /// Step rail and control pill show from the first step on (not on Hello).
    private var chromeVisible: Bool { store.phase != .hello }
}

extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
