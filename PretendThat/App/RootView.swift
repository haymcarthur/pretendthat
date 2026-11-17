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
    /// Onboarding v2: "Go to the home page" restarts the start screen's intro (it ran unseen under the onboarding).
    @State private var homeIntroRun = 0
    /// iPhone version: the safe-area insets (for full-screen layers that ignore the safe area), measured once here.
    @State private var safeInsets = EdgeInsets()
    /// iPhone version (2026-11-17): the ONE layout decision (`LayoutMetrics`), from the size class: regular = the iPad
    /// (every iPad layout unchanged), compact = the iPhone in portrait (Nutmeg on top, cards below, top bar, sheet chat).
    @Environment(\.horizontalSizeClass) private var horizontalSize
    private var metrics: LayoutMetrics { LayoutMetrics(horizontal: horizontalSize) }

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
                        ZStack {
                            HelloView(model: model, onExitBegan: { startExit() })
                                .id(homeIntroRun)
                            // Round D1: the My games bookshelf screen, over the start screen (which keeps its state).
                            if model.showingShelf {
                                ShelfView(model: model).transition(.opacity)
                            }
                            // Round 33: New game was blocked (no AI consent, or the Free Preview is used up).
                            if let block = model.kidBlock { KidBlockCard(model: model, block: block).zIndex(5) }
                        }
                        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.showingShelf)
                        .transition(reduceMotion ? .opacity : .identity)
                    } else {
                        // ONE stage for every phase (conversation, hunt, kit, play, hand-off): same Nutmeg, floor and
                        // stars, one camera; each phase only picks a frame.
                        sharedStage.transition(.asymmetric(insertion: reduceMotion ? .opacity : .identity, removal: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { stageTop = $0 }
                // (Round 26, Haylee's button audit: the confirm and color steps are voice only; their button row is gone.)
                // The chat panel's slot (the panel itself is drawn in its own layer below, so it can rise above the
                // keyboard while the stage can't).
                if chatOpen && chromeVisible && !metrics.isPhone {
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
            if metrics.isPhone {
                // iPhone (Haylee): the chat is a full-height sheet under the top bar that covers the stage; the pill
                // stays on top of it. Her small live head sits in its header (she's never heard unless she's visible).
                if chatOpen && chromeVisible {
                    phoneChatSheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else {
            HStack(spacing: Theme.Space.m) {
                Spacer(minLength: 0)
                if chatOpen && chromeVisible {
                    PTChatPanel(lines: model.realtime.transcript.map { PTChatPanel.Line(id: $0.id, fromNutmeg: $0.fromNutmeg, text: $0.text) },
                                onSend: { text in Task { await model.typed(text) } },
                                onClose: { chatOpen = false },
                                pinnedKey: pinnedKey, pinned: pinnedCard, typing: model.realtime.thinkingGap,
                                tab: tabbed ? Binding(get: { chatTabs.tab }, set: { chatTabs.select($0) }) : nil,
                                stepTab: stepTab ?? .scene)
                        .padding([.vertical, .trailing], Theme.Space.m)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            }
            if chromeVisible && metrics.isPhone {
                // iPhone (mockups): the X and the compact step rail in one row under the valance.
                HStack(spacing: Theme.Space.s) {
                    PTCornerClose(size: LayoutMetrics.phoneClose) { confirmLeave = true }
                    Spacer(minLength: 0)
                    PTStepRail(current: store.phase.step, reached: store.reachedStep, allDone: store.playFinished) { model.tapStepRail($0) }
                }
                .frame(height: LayoutMetrics.phoneTopBar)
                .padding(.horizontal, LayoutMetrics.phoneSide)
                .padding(.top, LayoutMetrics.phoneTopInset(screen: screenSize == .zero ? rootSize : screenSize, safeTop: rootTop))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
                .ignoresSafeArea(.keyboard)
            }
            if chromeVisible && !metrics.isPhone {
                PTStepRail(current: store.phase.step, reached: store.reachedStep, allDone: store.playFinished) { model.tapStepRail($0) }
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
            }
            // Round 40 (Haylee): on the iPhone the chat shelf hides the pill (typing is the chat's input; closing the
            // chat brings the pill back, the mic one tap away). The iPad keeps it.
            if chromeVisible && !(metrics.isPhone && chatOpen) {
                PTControlBar(chatOpen: chatOpen, mic: micMode, canRepeat: model.repeatTarget.isAvailable,
                             onChat: { chatOpen.toggle() },
                             onMicPress: { model.talkPressed(touchHost: $0) },
                             onMicRelease: { model.talkReleased() },
                             onRepeat: { model.repeatTapped() })
                    .padding(.bottom, metrics.pillBottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    // Writing moment: the pill steps aside so the screen's bottom edge crops just below the clipboard
                    // top (her paws out of frame, the crayon's top end visible). Hiding it releases a held mic.
                    .opacity(model.isWriting ? 0 : 1)
                    .allowsHitTesting(!model.isWriting)
                    .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.isWriting)   // round 11: with the writing shot
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .ignoresSafeArea(.keyboard)   // round 11: the keyboard covers it (the chat panel has its own field)
            }
            // Round D3b: offline on a replay, a line she never said: paused on it until the Wi-Fi is back.
            if model.wifiPause.isPaused && store.phase != .hello {
                PTWiFiNote(note: WiFiPause.note, onLeave: { chatOpen = false; model.leave() })
                    .transition(.opacity)
                    .zIndex(19)
            }
            // Round 39: the bookshelf moment (kit made) and "sounds like a game you have" (Pick confirm).
            if let m = model.shelfMoment {
                PTShelfMomentOverlay(moment: m)
                    .transition(.opacity)
                    .zIndex(17)
            }
            if let g = model.soundsLike {
                PTSoundsLikeCard(game: g, cover: model.cover(for: g),
                                 onReplay: { model.chooseSavedInstead() }, onNew: { model.chooseNewGame() })
                    .transition(.opacity)
                    .zIndex(18)
            }
            if confirmLeave {
                PTLeaveDialog(onShelf: LeaveDialogMode.current(isReplay: store.isReplay, savedAs: store.savedAs) == .onShelf
                                ? (model.currentCoverPicture(), model.currentCoverProps) : nil,
                              onStay: { confirmLeave = false },
                              onLeave: { confirmLeave = false; chatOpen = false; model.leave() })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(20)
            }
            // Onboarding v2 (Haylee): full-screen pages over everything, not a dialog over home. "Start our first game"
            // keeps them up until the stage takes over (no home page in between); "Go to the home page" fades to the
            // start screen, silent.
            if model.onboarding != nil {
                OnboardingView(model: model)
                    .transition(.opacity)
                    .zIndex(40)
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
        #if DEBUG
        .onChange(of: model.debugLeaveDialog) { _, v in confirmLeave = v }
        #endif
        .animation(.easeOut(duration: 0.25), value: model.wifiPause.isPaused)
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
            default: break
            }
        }
        .onChange(of: scenePhase) { _, phase in model.scenePhaseChanged(phase) }
        // Round 13: pre-connect the voice session while the start screen shows.
        .task(id: store.phase == .hello && model.aiConsent && model.onboarding == nil) { if store.phase == .hello { model.preconnect() } }
        .onChange(of: store.phase) { _, _ in model.updateIdleTimer() }
        .onChange(of: PTChatTabState.cardKey(for: stepTab, phase: store.phase), initial: true) { _, key in
            chatTabs.show(cardKey: key)
            #if DEBUG
            if DemoDriver.chatTabChat { chatTabs.select(.chat) }
            #endif
        }
        // Round 30 (Haylee): opening the panel always starts on the step tab (the transcript is one tap away).
        .onChange(of: chatOpen) { _, open in
            if open { chatTabs.panelOpened() }
            #if DEBUG
            if open, DemoDriver.chatTabChat { chatTabs.select(.chat) }   // round 40 shots: the transcript and its field
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
            model.writingChanged(on, reduceMotion: reduceMotion)   // round 28: the scribble waits for the writing shot
            if on { model.talkReleased() }   // the pill steps aside: a held mic is let go (sent or cleared)
        }
        .onChange(of: model.isSpeaking) { _, talking in if model.writingOnScreen { model.scribble.setPlaying(true, ducked: talking) } }
        .onChange(of: presentedSubjects) { _, _ in requestStickers() }
        .task {
            model.refreshShelf()   // round D1: the start screen shows My games once a game is saved
            #if DEBUG
            if DemoDriver.chatOpen { chatOpen = true }
            if let demo = DemoDriver.requestedPhase { await DemoDriver.drive(store, model: model, to: demo) }
            if ProcessInfo.processInfo.arguments.contains("-PTLeaveDialog") { try? await Task.sleep(for: .seconds(2)); confirmLeave = true }
            if let turns = DemoDriver.liveTurns { await DemoDriver.live(model, turns: turns) }
            if let file = DemoDriver.voiceRenderFile { await DemoDriver.voiceRender(model, file: file) }
            if DemoDriver.grownUps != nil { try? await Task.sleep(for: .seconds(4)); model.openGrownUps() }   // round D2 shots
            #endif
            await model.launchOnboardingCheck()   // round 33: the parent onboarding on first launch (asks for the mic itself)
        }
        // Round D2: the Grown-ups corner (gate first). Nutmeg stays quiet.
        .sheet(isPresented: Binding(get: { model.showingGrownUps }, set: { if !$0 { model.closeGrownUps() } })) {
            GrownUpsSheet(model: model)
        }
        // Round 33 / onboarding v2: the onboarding is a full-screen layer above (first launch; Grown-ups → Replay the
        // intro); the plans behind the gate stay a sheet.
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.3), value: model.onboarding == nil)
        .onChange(of: model.onboarding?.exit) { _, exit in if exit == .firstGame { startExit() } }
        .onChange(of: model.onboarding == nil) { _, gone in if gone && store.phase == .hello { homeIntroRun += 1 } }
        .sheet(isPresented: Binding(get: { model.showingPlans }, set: { model.showingPlans = $0 })) { PlansSheet(model: model) }
        .sheet(isPresented: $showTyping) { PTTypeSheet { text in Task { await model.typed(text) } } }
        // Round 31: the iPad can't listen on the device: a friendly note for a grown-up, then the chat's typing.
        .modifier(SpeechHelpAlert(model: model) { chatOpen = true })
        // Round 34: the in-app speech model download (iPadOS 26+), a grown-up sheet.
        .sheet(isPresented: Binding(get: { model.speechModel.showingSheet }, set: { model.speechModel.showingSheet = $0 })) {
            SpeechModelSheet(installer: model.speechModel, onType: { model.speechModel.showingSheet = false; chatOpen = true })
        }
        .preferredColorScheme(.light)
        .statusBarHidden()
        // iPhone version: Nutmeg holds her clipboard (no pointing) while a card is below her on the phone.
        .onChange(of: metrics.isPhone, initial: true) { _, phone in model.phoneLayout = phone }
        .onChange(of: phoneCardBelow, initial: true) { _, below in model.phoneCardBelow = below }
        .environment(\.layoutMetrics, metrics)
        .environment(\.ptSafeInsets, safeInsets)
        .background { Color.clear.onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { if $0 != safeInsets { safeInsets = $0 } } }
    }

    // MARK: iPhone (portrait)

    /// The phone's chat shelf (round 40, Haylee): edge to edge, attached to the bottom of the screen (rounded top
    /// corners only), under the X + step rail; the control pill is hidden while it's open, so its field sits just above
    /// the home indicator.
    private var phoneChatSheet: some View {
        let safeBottom = max(0, (screenSize == .zero ? rootSize.height : screenSize.height) - rootSize.height - rootTop)
        return PTChatPanel(lines: model.realtime.transcript.map { PTChatPanel.Line(id: $0.id, fromNutmeg: $0.fromNutmeg, text: $0.text) },
                           onSend: { text in Task { await model.typed(text) } },
                           onClose: { chatOpen = false },
                           pinnedKey: pinnedKey, pinned: pinnedCard, typing: model.realtime.thinkingGap,
                           tab: tabbed ? Binding(get: { chatTabs.tab }, set: { chatTabs.select($0) }) : nil,
                           stepTab: stepTab ?? .scene,
                           header: AnyView(PTNutmegAvatar(model: model)),
                           bottomClearance: keyboardUp ? 0 : safeBottom)
            .padding(.top, LayoutMetrics.phoneTopInset(screen: screenSize == .zero ? rootSize : screenSize, safeTop: rootTop)
                     + LayoutMetrics.phoneTopBar + Theme.Space.xs)
            .ignoresSafeArea(.container, edges: .bottom)
    }

    /// What the phone shows in the content zone under Nutmeg right now (its height comes from `LayoutMetrics`).
    private var phoneContent: LayoutMetrics.PhoneContent {
        if model.isWriting { return .none }
        if model.inConversation {
            if huntOnStage { return stageItems.isEmpty ? .none : .hunt }
            if shot == .wide && !stageItems.isEmpty { return .cards }
            return .none
        }
        if replayHuntOnStage { return .hunt }
        switch store.phase {
        case .players: return store.isReplay ? .cover : .players
        case .props: return store.isReplay ? .none : .propsGrid
        case .makingKit, .kitReady: return (model.kitBeat == .papers || store.isReplay) ? .print : .none
        case .scene(let i):
            if store.inStory { return .none }
            let rows = store.kit?.scenes.indices.contains(i) == true ? store.kit!.scenes[i].steps.count : 3
            return .scene(rows: rows)
        case .end: return .end
        default: return .none
        }
    }

    /// A card she should hold her clipboard and look at (The End's buttons aren't one: she celebrates there).
    private var phoneCardBelow: Bool {
        guard metrics.isPhone else { return false }
        switch phoneContent { case .none, .end: return false; default: return true }
    }

    /// Her box and the content zone on the phone stage (stage coordinates).
    private func phoneSplit(_ g: PTStageGeometry) -> (nutmeg: CGRect, content: CGRect) {
        let band = metrics.phoneBand(stage: g.size, screen: screenSize == .zero ? g.size : screenSize, safeTop: rootTop)
        let split = PTPhoneStage.split(width: g.size.width, top: band.top, bottom: band.bottom,
                                       content: LayoutMetrics.phoneContentHeight(phoneContent, noVoice: model.noVoiceSession))
        return (split.nutmeg, split.content.insetBy(dx: LayoutMetrics.phoneSide, dy: 0))
    }

    /// The phone stage's overlay: the hunt card, the legacy prop grid, or the phase content in the zone under her.
    @ViewBuilder private func phoneOverlay(_ g: PTStageGeometry, _ L: PTStageCamera.Layout) -> some View {
        let zone = phoneSplit(g).content
        if model.inConversation {
            if huntOnStage {
                PTPhonePropHunt(items: stageItems, total: store.props?.props.count, onHunt: { model.huntReply(found: $0) })
                    .frame(width: zone.width, height: zone.height)
                    .position(x: zone.midX, y: zone.midY)
                    .opacity(model.isWriting ? 0 : 1)
                    .transition(.opacity)
            } else if shot == .wide && !model.isWriting && !stageItems.isEmpty {
                PTPhoneCardGrid(items: stageItems, onHunt: { _, found in model.huntReply(found: found) })
                    .frame(width: zone.width, height: zone.height)
                    .position(x: zone.midX, y: zone.midY)
                    .transition(.opacity)
            }
        } else if replayHuntOnStage {
            PTPhonePropHunt(items: propListItems, total: store.props?.props.count, onHunt: { model.replayHunt(found: $0) })
                .frame(width: zone.width, height: zone.height)
                .position(x: zone.midX, y: zone.midY)
                .transition(.opacity)
        } else {
            classicContent(g, L)
        }
    }

    // MARK: The shared stage (every phase)

    private var sharedStage: some View {
        PTStageView(referenceSize: rootSize == .zero ? nil : rootSize,
                    screenSize: screenSize == .zero ? nil : screenSize,
                    // iPhone: no side rail (it's in the top bar); the pill's room at the bottom; the chat is a sheet over
                    // the stage, so the stage never narrows for it.
                    leadingInset: chromeVisible && !metrics.isPhone ? PTStageCamera.chromeLeading : 0,
                    bottomInset: metrics.isPhone ? metrics.phoneChromeBottom : (chromeVisible ? PTStageCamera.chromeBottom : 0),
                    chatOpen: chatOpen && chromeVisible && !metrics.isPhone,
                    faceFocus: (debugPose ?? model.nutmegRestPose).faceFocus,
                    frame: { g in stageFrame(g) }, itemCount: stageItems.count, keyboardUp: keyboardUp) {
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                            isSpeaking: model.isSpeaking, cue: model.cue, forcedPose: debugPose, showsGround: true,
                            holdsClipboard: model.nutmegHoldsClipboard, writing: model.isWriting)
        } overlay: { g, L in
            if metrics.isPhone {
                phoneOverlay(g, L)
            } else if model.inConversation {
                if huntOnStage {
                    // Hidden while she writes in the close shot (the cards are laid out for the hunt's medium shot).
                    PTPropHuntStage(items: stageItems, geometry: g, nutmeg: L, curtainInset: curtainInset(g), namespace: huntSpace,
                                    onHunt: { _, found in model.huntReply(found: found) })
                        .opacity(model.isWriting ? 0 : 1)
                        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: model.isWriting)   // round 11: with the writing shot
                } else if shot == .wide && !model.isWriting && !(chatOpen && chromeVisible && stepTab == .props) {
                    PTPresentedCards(items: stageItems, nutmeg: L, size: g.size, onTapItem: { silentTap($0) },
                                     onHunt: { _, found in model.huntReply(found: found) })
                }
            } else if replayHuntOnStage {
                // Round 34 (Haylee: replays look identical to new games): the replay's Props is the first play's hunt
                // layout: the same active card (component, place, size, ✓ / ✗), the same done stack, the same camera.
                PTPropHuntStage(items: propListItems, geometry: g, nutmeg: L, curtainInset: curtainInset(g), namespace: huntSpace,
                                onHunt: { _, found in model.replayHunt(found: found) })
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
        if metrics.isPhone {
            // iPhone: whole body in her box (the band above the content zone; the whole band when nothing's below her).
            let d = directorFrame(g)
            return PTStageFrame(shot: d.shot, writing: model.isWriting, phoneRegion: phoneSplit(g).nutmeg)
        }
        return directorFrame(g)
    }
    private func directorFrame(_ g: PTStageGeometry) -> PTStageFrame {
        return PTStageDirector.frame(phase: store.phase, conversation: model.inConversation, conversationShot: shot,
                              cards: stageItems.count, hunt: huntOnStage || replayHuntOnStage, kitBeat: model.kitBeat,
                              curtainInset: curtainInset(g), writing: model.isWriting, story: store.inStory, g)
    }

    /// What's docked at the top of the chat panel: the hunt's active prop, or the kit papers once they're out.
    private var pinnedKey: String? {
        if let key = PTChatTabState.cardKey(for: stepTab, phase: store.phase) { return key }   // round 30: the step tab
        if huntOnStage, let active = stageItems.last(where: { !$0.isDone }) { return active.id }
        if model.kitPapersOut { return "kit-papers" }
        if case .scene(let i) = store.phase, !store.inStory { return "scene-\(i)" }   // round 8: the scene card docks in the chat panel (round 36: not the story)
        if store.phase == .end { return "end" }   // round 11: and the finale (the chat-open prop-card framing has no side zone)
        return nil
    }
    /// Round 14: the play step's scene card gets the panel's Scene | Chat tabs (not the pinned card). Round 30
    /// (Haylee): every step with something to show has its step tab: Props | Chat, Print | Chat, Scene | Chat, and a
    /// replay's Pick shows the cover. A first play's Pick is Chat only.
    private var tabbed: Bool { stepTab != nil }
    private var stepTab: PTStepTab? {
        PTStepTab.forPhase(store.phase, replay: store.isReplay, propsShown: propListItems.count, papersOut: model.kitPapersOut, arc: store.currentArc ?? .play)
    }

    /// Round 30: the Props tab's rows: a first play's shown hunt cards (one at a time, as on the stage), or a replay's
    /// answered props and the current one.
    private var propListItems: [PTStageItem] {
        if store.isReplay {
            let props = store.props?.props ?? []
            return props.enumerated().compactMap { i, p in
                let answered = store.foundProps.contains(p.id) || p.isSkipped
                let current = p.id == store.replayCurrentProp?.id
                guard answered || current else { return nil }
                let art = p.libraryID.flatMap { UIImage(named: PropLibrary.asset($0)) } ?? model.stickers.art(.prop, p.householdItem)
                return PTStageItem(id: "prop-\(p.id)", title: p.householdItem, subtitle: p.becomes, image: art,
                                   tint: Theme.playerColor(i), flipKey: p.libraryID ?? p.householdItem, isPretend: p.isSkipped,
                                   chip: p.isSkipped ? .pretend : (store.foundProps.contains(p.id) ? .found : (p.swapped == true ? .swapped : .none)),
                                   huntButtons: current)
            }
        }
        guard model.inConversation, store.presenting == .props else { return [] }
        return stageItems
    }
    private var propListCurrentID: String? {
        if store.isReplay { return store.replayCurrentProp.map { "prop-\($0.id)" } }
        return propListItems.first(where: \.huntButtons)?.id
    }
    private func propListHunt(_ found: Bool) {
        if store.isReplay { model.replayHunt(found: found) } else { model.huntReply(found: found) }
    }

    /// Round 10 rule (Haylee): every interactive card (prop, kit, checklist, hand-off) has ONE chat-open treatment:
    /// pinned at the top of the chat panel at full readable size (`.ptPinnedCard()`), never shrunk into the stage gap.
    private var pinnedCard: AnyView? {
        // Round 30: the step tabs' content.
        switch stepTab {
        case .props:
            return AnyView(PTPropListPanel(items: propListItems, currentID: propListCurrentID,
                                           onHunt: propListCurrentID == nil ? nil : { propListHunt($0) }))
        case .print:
            return AnyView(PrintTabView(model: model, onPreview: { i in
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { kitPreview = PTPreviewTarget(index: i) }
            }))
        case .cover:
            let panelW = metrics.isPhone ? min(360, rootSize.width - 2 * Theme.Space.s) : PTChatPanel.width
            return AnyView(ReplayPickView(model: model, coverWidth: panelW - 2 * Theme.Space.m - 24).padding(.top, Theme.Space.s))
        case .scene, .setup, .cleanup, nil: break
        }
        if case .scene(let i) = store.phase, !store.inStory, !huntOnStage, !model.kitPapersOut { return AnyView(PTScenePinnedCard(model: model, index: i)) }
        if store.phase == .end { return AnyView(EndView(model: model).padding(.vertical, Theme.Space.s).ptPinnedCard()) }
        if huntOnStage, let active = stageItems.last(where: { !$0.isDone }) {
            return AnyView(PTPropPinnedCard(item: active, onHunt: active.huntButtons ? { model.huntReply(found: $0) } : nil)
                .matchedGeometryEffect(id: ptHuntActiveID, in: huntSpace))
        }
        if model.kitPapersOut {
            let pages = model.kitPages
            return AnyView(PTKitPinnedCard(count: pages.count, onTap: { i in
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { kitPreview = PTPreviewTarget(index: i) }
            }, onPrint: { model.tapPrint() }, onPlay: { model.tapLetsPlay() }) { i in
                // Round 27: the chat-open pinned card shows the chosen set (the stage shows both).
                KitPageView(page: pages[i], art: model.printArt.images[pages[i].item.id], cutouts: model.printArt.cutoutImages(pages[i].item))
                    .scaleEffect(PTKitPinnedCard<EmptyView>.thumb.width / KitPageView.size.width)
                    .frame(width: PTKitPinnedCard<EmptyView>.thumb.width, height: PTKitPinnedCard<EmptyView>.thumb.height)
            })
        }
        return nil
    }

    /// The prop hunt layout is on stage (the camera has moved to the hunt's medium shot).
    private var huntOnStage: Bool { model.inConversation && store.huntActive && shot == .medium }
    /// Round 34: a replay's hunt uses the same stage layout and camera as the first play's.
    private var replayHuntOnStage: Bool { store.isReplay && store.replayHuntActive }

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
        // iPhone: the content zone under her.
        let r = metrics.isPhone ? phoneSplit(g).content : PTStageDirector.huntContent(g, nutmeg: L, curtainInset: curtainInset(g))
        // Round 14 (Haylee: the cards got smaller): every phase's content draws at its NATURAL size in the shared card
        // zone (`PTStageDirector.cardZoneWidth`); it only scales down on a stage too narrow for ~300 pt.
        let fit = min(1, r.width / Self.minContentWidth)
        let w = r.width / fit, h = r.height / fit
        let kitWaiting = (store.phase == .makingKit || store.phase == .kitReady) && model.kitBeat != .papers && !store.isReplay
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
        // Round D1: a replay's Pick and Props (round 26: the first play's flows; its Print is the first play's KitView).
        // Round 30: chat open, a replay's cover and props are in the panel's step tab (the stage hides the duplicate).
        case .players: if store.isReplay { if !(chatOpen && chromeVisible) { ReplayPickView(model: model, coverWidth: min(360, width - 8), maxHeight: height) } } else { PlayersView(model: model) }
        // Round 34: a replay's hunt is drawn by the stage overlay (`PTPropHuntStage`), exactly like a first play's.
        case .props: if store.isReplay { EmptyView() } else { PropsView(model: model) }
        case .makingKit, .kitReady: KitView(model: model, clipboard: clipboard, chatOpen: chatOpen && chromeVisible, preview: $kitPreview,
                                            onCelebrate: { celebrate() })
        // Round 36: the story is Nutmeg alone (the talking close-up), no card.
        case .scene(let i): if !(chatOpen && chromeVisible) && !store.inStory { SceneView(model: model, index: i, width: width, maxHeight: height) }   // chat open: pinned in the panel
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
        switch model.micState { case .idle: .idle; case .listening: .listening; case .disabled: .disabled; case .unavailable: .unavailable }
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

/// Round 31: the iPad can't listen on the device (permission, or no on-device English speech): a friendly note for a
/// grown-up, with "Type instead" opening the chat's text field. Never an audio fallback.
struct SpeechHelpAlert: ViewModifier {
    @Bindable var model: AppModel
    var onType: () -> Void
    private var prompt: (title: String, message: String)? { model.speechHelp?.grownUpPrompt }
    func body(content: Content) -> some View {
        content.alert(prompt?.title ?? "", isPresented: Binding(get: { prompt != nil }, set: { if !$0 { model.speechHelp = nil } })) {
            Button("Type instead") { model.speechHelp = nil; onType() }
            Button("OK", role: .cancel) { model.speechHelp = nil }
        } message: {
            Text(prompt?.message ?? "")
        }
    }
}
