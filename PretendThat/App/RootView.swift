import SwiftUI
import NutmegCore

/// Round 21: the root's keyboard-free size and global top (see `keyboardUp`).
struct RootMeasure: Equatable { var size: CGSize; var top: CGFloat }

/// Switches on the adventure phase. Every kid screen shares one stage layout:
/// Nutmeg on the left third, the stage on the right, mic and "again" along the bottom.
struct RootView: View {
    @State private var model = AppModel()
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
    /// Round 11: the start screen's exit is running (from the tap): the rail and pill already slide in on its move.
    @State private var startExiting = false
    /// Round 11: the full, keyboard-free root size: the stage camera's reference (floor : Nutmeg never changes).
    @State private var rootSize: CGSize = .zero
    /// Round 15: the full-screen (safe-area-ignoring) size the curtains are drawn at.
    @State private var screenSize: CGSize = .zero
    /// Round 14: the chat panel's Checklist | Chat tabs during play (a new hand-off / scene opens on Checklist).
    @State private var chatTabs = PTChatTabState()
    /// Round 21: the on-screen keyboard is up. The stage's reference size and framing stay as they were before it opened.
    @State private var keyboardUp = false
    @State private var measuredRoot = RootMeasure(size: .zero, top: 0)
    /// Round 21: the stage area's and the root's global tops (the choice row hangs at the same line as the corner X).
    @State private var stageTop: CGFloat = 0
    @State private var rootTop: CGFloat = 0
    /// Round 21: the step-choice row's height (measured; her close-up keeps clear of it).
    @State private var choiceRowHeight: CGFloat = 80

    private var store: AdventureStore { model.store }

    var body: some View {
        // Layout (layout-toycad-style.md, style revised): light canvas, Nutmeg centered as the hero, a white step rail
        // on the left, a white control pill at the bottom, and a chat panel that slides in from the right.
        ZStack {
            // The same stage as the start screen (sky, floor, tied-back curtains, valance) under every game screen.
            // The floor is drawn by the shared stage (it moves with Nutmeg); the start screen draws its own.
            PTStageBackdrop(floor: false)
                .background {
                    // Round 15: the backdrop's full-screen size (the stage redraws its curtains over the floor).
                    Color.clear.ignoresSafeArea().onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
                }
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
                        HelloView(model: model, onExitBegan: { startExit() })
                            .transition(reduceMotion ? .opacity : .identity)
                    } else {
                        // ONE stage for every phase (conversation, hunt, kit, play, hand-off): same Nutmeg, floor and
                        // stars, one camera; each phase only picks a frame.
                        sharedStage.transition(.asymmetric(insertion: reduceMotion ? .opacity : .identity, removal: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { stageTop = $0 }
                // Round 19: the confirm step's Yes / Change buttons. Round 21 (Haylee: "show up on top"): every step-choice
                // row sits at the TOP of the stage, under the valance, centered over the stage (between the corner X and
                // the right curtain, or the chat panel), clear of Nutmeg's head and the control pill.
                .overlay(alignment: .top) {
                    if model.showsConfirm && chromeVisible {
                        PTConfirmButtons(onYes: { model.confirmYes() }, onChange: { model.confirmChange() })
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { choiceRowHeight = $0 }
                            .padding(.horizontal, Theme.Space.xl)
                            .padding(.top, choiceRowTop)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    // Round 24: the printer question's two big buttons, in the same place.
                    if model.showsPrinterChoice && chromeVisible {
                        PTPrinterChoiceButtons(onChoose: { model.choosePrinter($0) })
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { choiceRowHeight = $0 }
                            .padding(.horizontal, Theme.Space.xl)
                            .padding(.top, choiceRowTop)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    // Round 20: the color question's two big buttons, in the same place.
                    if model.showsColorChoice && chromeVisible {
                        PTColorChoiceButtons(onChoose: { model.chooseColor($0) })
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { choiceRowHeight = $0 }
                            .padding(.horizontal, Theme.Space.xl)
                            .padding(.top, choiceRowTop)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.showsConfirm)
                .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.showsColorChoice)
                .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.showsPrinterChoice)
                // The chat panel's slot (the panel itself is drawn in its own layer below, so it can rise above the
                // keyboard while the stage can't).
                if chatOpen && chromeVisible {
                    Color.clear.frame(width: PTChatPanel.width)
                        .padding([.vertical, .trailing], Theme.Space.m)
                        .transition(.move(edge: .trailing))
                }
            }
            // Round 11/14 (Haylee): the keyboard never re-frames the stage; it just covers its bottom. Round 21: the
            // stage row is its own layer that ignores the keyboard (inside a row shared with the chat panel the
            // keyboard inset still reached it and Nutmeg rezoomed tiny).
            .ignoresSafeArea(.keyboard)
            // Only the chat panel (and its text field) rises above the keyboard.
            HStack(spacing: Theme.Space.m) {
                Spacer(minLength: 0)
                if chatOpen && chromeVisible {
                    PTChatPanel(lines: model.realtime.transcript.map { PTChatPanel.Line(id: $0.id, fromNutmeg: $0.fromNutmeg, text: $0.text) },
                                onSend: { text in Task { await model.typed(text) } },
                                onClose: { chatOpen = false },
                                pinnedKey: pinnedKey, pinned: pinnedCard, typing: model.realtime.thinkingGap,
                                tab: tabbed ? Binding(get: { chatTabs.tab }, set: { chatTabs.select($0) }) : nil)
                        .padding([.vertical, .trailing], Theme.Space.m)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            if chromeVisible {
                PTStepRail(current: store.phase.step, reached: store.reachedStep) { model.tapStepRail($0) }
                    .padding(.leading, Theme.Space.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .ignoresSafeArea(.keyboard)   // round 11: stays put under the keyboard
                // Round 17 (Haylee): the close (X) lives in the top-left corner, below the valance and above the rail.
                PTCornerClose { confirmLeave = true }
                    .padding(.top, PTCurtain.metrics(screenSize == .zero ? rootSize : screenSize).valance + Theme.Space.s)
                    .padding(.leading, Theme.Space.m + Theme.Space.s + (72 - PTCornerClose.size) / 2)   // centered over the rail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .ignoresSafeArea(.keyboard)
                PTControlBar(chatOpen: chatOpen, mic: micMode, canRepeat: model.repeatTarget.isAvailable,
                             onChat: { chatOpen.toggle() },
                             onMicPress: { model.talkPressed() },
                             onMicRelease: { model.talkReleased() },
                             onRepeat: { model.repeatTapped() })
                    .padding(.bottom, Theme.Space.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    // Writing moment: the pill steps aside so the screen's bottom edge crops just below the clipboard
                    // top (her paws out of frame, the crayon's top end visible). Hiding it releases a held mic.
                    .opacity(model.isWriting ? 0 : 1)
                    .allowsHitTesting(!model.isWriting)
                    .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.isWriting)   // round 11: with the writing shot
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .ignoresSafeArea(.keyboard)   // round 11: the keyboard covers it (the chat panel has its own field)
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
        .background {
            Color.clear.ignoresSafeArea(.keyboard)
                // Round 21: in a windowed iPad app the keyboard RESIZES the window (782 → 814 → 406 pt tall here,
                // before the keyboard notification arrives), which rezoomed Nutmeg tiny. The reference only takes a
                // new size once it has held for 0.4 s with the keyboard down (rotation, a window resize).
                .onGeometryChange(for: RootMeasure.self) { RootMeasure(size: $0.size, top: $0.frame(in: .global).minY) } action: { m in
                    measuredRoot = m
                    if rootSize == .zero { rootSize = m.size; rootTop = m.top }
                }
        }
        .task(id: "\(measuredRoot)-\(keyboardUp)") {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, !keyboardUp else { return }
            if rootSize != measuredRoot.size { rootSize = measuredRoot.size }
            if rootTop != measuredRoot.top { rootTop = measuredRoot.top }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .animation(.easeOut(duration: 0.2), value: confirmLeave)
        // Round 10: the panel/rail slide on the same spring as the camera move they cause (one shared animation).
        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: chatOpen)
        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: chromeVisible)
        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.inConversation)   // round 11: one move
        .environment(\.speak, SpeakAction { model.speak($0) })
        .environment(\.ptCelebrate, model.celebrations)
        .onChange(of: store.nutmegLine) { _, line in model.speak(line) }
        .onChange(of: store.phase) { _, phase in
            model.phaseChanged()
            switch phase {
            case .kitReady: model.celebrations += 1   // Nutmeg celebrates when the papers have landed (KitView)
            case .end: model.gesture(.celebrate); model.celebrations += 1
            case .hello: model.gesture(.wave); startExiting = false
            case .handoff: model.gesture(.point)   // toward the hand-off card
            default: break
            }
        }
        .onChange(of: scenePhase) { _, phase in model.scenePhaseChanged(phase) }
        // Round 13: pre-connect the voice session while the start screen shows.
        .task(id: store.phase == .hello) { if store.phase == .hello { model.preconnect() } }
        .onChange(of: store.phase) { _, _ in model.updateIdleTimer() }
        .onChange(of: PTChatTabState.cardKey(for: store.phase), initial: true) { _, key in
            chatTabs.show(cardKey: key)
            #if DEBUG
            if DemoDriver.chatTabChat { chatTabs.select(.chat) }
            #endif
        }
        .onChange(of: model.kitPapersOut) { _, _ in model.updateIdleTimer() }
        .onChange(of: desiredShot) { _, _ in scheduleShot() }
        // Round 7: the point toward a prop card is tied to the card's reveal and her prop line (AppModel.pointAtCard).
        .onChange(of: model.inConversation) { _, live in
            if live { scheduleShot(arrival: true) } else { shotTask?.cancel(); cameraShot = .wide; lastShotChange = .distantPast }
        }
        .onChange(of: store.kit) { _, _ in model.kitChanged() }
        .onChange(of: store.guidePending) { _, pending in model.guidePendingChanged(pending) }
        .onChange(of: store.guideWrittenAt) { _, _ in model.guideTimingChanged() }
        .onChange(of: store.guideFinalAt) { _, _ in model.guideTimingChanged() }
        // Round 20: the kit pages are written during the hunt; their art follows (and the color choice).
        .onChange(of: store.draftItems) { _, _ in model.draftChanged() }
        .onChange(of: store.draftGeneration) { _, _ in model.draftChanged() }
        .onChange(of: store.currentPrintStyle) { _, _ in model.draftChanged() }
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
        .sheet(isPresented: $showTyping) { PTTypeSheet { text in Task { await model.typed(text) } } }
        // Round 24: Save printables for later (no printer): Save to Files, AirDrop, send to a grown-up.
        .sheet(isPresented: Binding(get: { model.printablesShare != nil }, set: { if !$0 { model.printablesShareClosed() } })) {
            if let url = model.printablesShare { PTShareSheet(items: [url]) }
        }
        .preferredColorScheme(.light)
        .statusBarHidden()
    }

    /// Round 21: the step-choice row's top: just under the valance (the same line the corner X hangs from).
    private var choiceRowTop: CGFloat {
        PTCurtain.metrics(screenSize == .zero ? rootSize : screenSize).valance + Theme.Space.s + (rootTop - stageTop)
    }

    // MARK: The shared stage (every phase)

    private var sharedStage: some View {
        PTStageView(referenceSize: rootSize == .zero ? nil : rootSize,
                    screenSize: screenSize == .zero ? nil : screenSize,
                    leadingInset: chromeVisible ? PTStageCamera.chromeLeading : 0,
                    bottomInset: chromeVisible ? PTStageCamera.chromeBottom : 0,
                    chatOpen: chatOpen && chromeVisible,
                    faceFocus: (debugPose ?? model.nutmegRestPose).faceFocus,
                    frame: { g in stageFrame(g) }, itemCount: stageItems.count, keyboardUp: keyboardUp) {
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                            isSpeaking: model.isSpeaking, cue: model.cue, forcedPose: debugPose, showsGround: true,
                            holdsClipboard: model.nutmegHoldsClipboard, writing: model.isWriting)
        } overlay: { g, L in
            if model.inConversation {
                if huntOnStage {
                    // Hidden while she writes in the close shot (the cards are laid out for the hunt's medium shot).
                    PTPropHuntStage(items: stageItems, geometry: g, nutmeg: L, curtainInset: curtainInset(g), namespace: huntSpace,
                                    onHunt: { _, found in model.huntReply(found: found) })
                        .opacity(model.isWriting ? 0 : 1)
                        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.isWriting)   // round 11: with the writing shot
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
    /// Round 11 (Haylee: one way everywhere): every phase goes through `PTStageDirector.preset` (talk, writing, prop
    /// card, prop card + chat, hop, presented cards); no per-screen framing here.
    private func stageFrame(_ g: PTStageGeometry) -> PTStageFrame {
        var f = directorFrame(g)
        // Round 21: the step-choice row hangs along the top: her head keeps clear of it.
        if (model.showsConfirm || model.showsColorChoice || model.showsPrinterChoice) && chromeVisible && f.shot == .closeUp && !f.writing {
            f.topReserve = max(f.topReserve, choiceRowTop + choiceRowHeight + Theme.Space.s - PTStageGeometry.topMargin)
        }
        return f
    }
    private func directorFrame(_ g: PTStageGeometry) -> PTStageFrame {
        return PTStageDirector.frame(phase: store.phase, conversation: model.inConversation, conversationShot: shot,
                              cards: stageItems.count, hunt: huntOnStage, kitBeat: model.kitBeat,
                              curtainInset: curtainInset(g), writing: model.isWriting, g)
    }

    /// What's docked at the top of the chat panel: the hunt's active prop, or the kit papers once they're out.
    private var pinnedKey: String? {
        if huntOnStage, let active = stageItems.last(where: { !$0.isDone }) { return active.id }
        if model.kitPapersOut { return "kit-papers" }
        if case .scene(let i) = store.phase { return "scene-\(i)" }   // round 8: the checklist docks in the chat panel
        if case .handoff(let i) = store.phase { return "handoff-\(i)" }   // round 10: so does the hand-off card
        if store.phase == .end { return "end" }   // round 11: and the finale (the chat-open prop-card framing has no side zone)
        return nil
    }
    /// Round 14: the play step's checklist / hand-off card gets the panel's Checklist | Chat tabs (not the pinned card).
    private var tabbed: Bool { PTChatTabState.cardKey(for: store.phase) != nil && !huntOnStage && !model.kitPapersOut }

    /// Round 10 rule (Haylee): every interactive card (prop, kit, checklist, hand-off) has ONE chat-open treatment:
    /// pinned at the top of the chat panel at full readable size (`.ptPinnedCard()`), never shrunk into the stage gap.
    private var pinnedCard: AnyView? {
        if case .scene(let i) = store.phase, !huntOnStage, !model.kitPapersOut { return AnyView(PTScenePinnedCard(model: model, index: i)) }
        if case .handoff(let i) = store.phase { return AnyView(HandoffView(model: model, sceneIndex: i, pinned: true)) }
        if store.phase == .end { return AnyView(EndView(model: model).padding(.vertical, Theme.Space.s).ptPinnedCard()) }
        if huntOnStage, let active = stageItems.last(where: { !$0.isDone }) {
            return AnyView(PTPropPinnedCard(item: active, onHunt: active.huntButtons ? { model.huntReply(found: $0) } : nil)
                .matchedGeometryEffect(id: ptHuntActiveID, in: huntSpace))
        }
        if model.kitPapersOut && store.drawing {
            return AnyView(PTDrawItCard(model: model).ptPinnedCard())
        }
        if model.kitPapersOut {
            let pages = model.kitPages
            return AnyView(PTKitPinnedCard(count: pages.count, onTap: { i in
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { kitPreview = PTPreviewTarget(index: i) }
            }, onPrint: { model.tapPrint() }, onPlay: { model.tapLetsPlay() }) { i in
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
    /// Round 10: the hunt's zoom-out waits for the card it makes room for (it used to zoom during the roles line, then
    /// the card popped in later), so the camera, Nutmeg and the card move in one animation.
    private var desiredShot: PTCameraShot {
        store.huntActive ? (model.visibleProps > 0 ? .medium : .closeUp) : (stageItems.isEmpty ? .closeUp : .wide)
    }
    private static let minShotGap: TimeInterval = 2

    private func scheduleShot(arrival: Bool = false) {
        shotTask?.cancel()
        shotTask = Task { @MainActor in
            let target = desiredShot
            guard target != cameraShot else { return }
            var wait = max(0, Self.minShotGap - Date().timeIntervalSince(lastShotChange))
            if target == .wide || target == .medium { wait = 0 }
            // Round 11: no arrival wait: the start screen's exit already landed her on the first framing.
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
        Task { @MainActor in
            // Round 21: a prop's text may still be in moderation (it ran ahead of the check): images wait for it, and
            // the jobs are read after the wait (a flag has put the props back by then).
            guard await model.gate.cleared() else { return }
            let game = store.gameTitle
            // No idea or role cards (Haylee): ideas are spoken and roles are printed on badges, so only props get art.
            // Props: only off-list ones get generated art (library props are hand-drawn).
            let offList = (store.props?.props ?? []).filter { $0.libraryID == nil }
            if !offList.isEmpty { rtLog("off-list props (generated art): \(offList.count)") }
            let jobs: [(kind: StickerPrompt.Kind, subject: String, detail: String)] = offList.map { (.prop, $0.householdItem, $0.becomes) }
            model.stickers.request(jobs, game: game)
        }
    }

    /// Prop cards are display-only (D3: kids tap only to print and to play).
    private func silentTap(_ id: String) {}

    // MARK: Phase content beside Nutmeg (tap fallback, kit papers, play, hand-off)

    /// Screen-space content right of her lane. Kit: nothing while she colors in the close-up (the papers wait for the
    /// whole kit, no-text-overlays.md); the papers fly off her clipboard once the camera has zoomed out.
    @ViewBuilder private func classicContent(_ g: PTStageGeometry, _ L: PTStageCamera.Layout) -> some View {
        // Round 11: every phase's content sits in the prop-card step's card zone (one framing, one zone).
        let r = PTStageDirector.huntContent(g, nutmeg: L, curtainInset: curtainInset(g))
        // Round 14 (Haylee: the cards got smaller): every phase's content draws at its NATURAL size in the shared card
        // zone (`PTStageDirector.cardZoneWidth`); it only scales down on a stage too narrow for ~300 pt.
        let fit = min(1, r.width / Self.minContentWidth)
        let w = r.width / fit, h = r.height / fit
        let kitWaiting = (store.phase == .makingKit || store.phase == .kitReady) && model.kitBeat != .papers
        VStack(spacing: Theme.Space.m) {
            ViewThatFits(in: .vertical) {
                stage(clipboard: clipboard(L, in: r), width: w, height: h - 2 * Theme.Space.s).padding(.vertical, Theme.Space.s)
                ScrollView(.vertical) { stage(clipboard: clipboard(L, in: r), width: w, height: .infinity).padding(.vertical, Theme.Space.m) }.scrollIndicators(.visible)
            }
            .transition(.ptStage)
            .id(stageID)
            if store.lastError != nil { HStack(spacing: Theme.Space.l) { bottomBar } }
        }
        .frame(width: w, height: h)
        .scaleEffect(fit)
        .frame(width: r.width, height: r.height)
        .position(x: r.midX, y: r.midY)
        .opacity(kitWaiting ? 0 : 1)
        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: stageID)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: stageID)
    }

    private var isScene: Bool { if case .scene = store.phase { return true } else { return false } }
    /// Below this zone width the content scales down instead of squeezing (round 14).
    private static let minContentWidth: CGFloat = 300

    /// Her clipboard (idle pose, canvas px) relative to the content rect's center: where the papers fly from.
    private func clipboard(_ L: PTStageCamera.Layout, in r: CGRect) -> CGPoint {
        let p = L.screen(CGPoint(x: 521, y: 933))   // round 4 idle clipboard center
        return CGPoint(x: p.x - r.midX, y: p.y - r.midY)
    }

    @ViewBuilder private func stage(clipboard: CGPoint, width: CGFloat, height: CGFloat) -> some View {
        switch store.phase {
        case .hello: EmptyView()   // the start screen replaces the classic stage (see body)
        case .pickGame: EmptyView()   // games are talked about only: no idea cards, no caption (no-text-overlays.md)
        case .players: PlayersView(model: model)
        case .props: PropsView(model: model)
        case .makingKit, .kitReady: KitView(model: model, clipboard: clipboard, chatOpen: chatOpen && chromeVisible, preview: $kitPreview,
                                            onCelebrate: { celebrate() })
        case .handoff(let i): if !(chatOpen && chromeVisible) { HandoffView(model: model, sceneIndex: i).frame(width: width) }   // chat open: pinned
        case .scene(let i): if !(chatOpen && chromeVisible) { SceneView(model: model, index: i, width: width, maxHeight: height) }   // chat open: pinned in the panel
        case .end: if !(chatOpen && chromeVisible) { EndView(model: model) }   // chat open: pinned in the panel
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
    private var chromeVisible: Bool { store.phase != .hello || startExiting }

    /// Round 11 (Haylee: one move): the tap on "Let's play!" starts everything at once. The start screen's exit pushes
    /// its camera to the game's first framing (the close-up when voice is on), so the camera is set there now, without
    /// animation (the stage isn't on screen yet), and the rail and pill slide in on the same `Theme.stageMove` move.
    private func startExit() {
        if model.opensInCloseUp {
            var tx = Transaction(); tx.disablesAnimations = true
            withTransaction(tx) { shotTask?.cancel(); cameraShot = .closeUp; lastShotChange = Date() }
        }
        startExiting = true
    }
}

extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
