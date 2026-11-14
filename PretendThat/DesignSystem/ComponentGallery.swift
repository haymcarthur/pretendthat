#if DEBUG
import SwiftUI
import NutmegCore

/// Every DesignSystem component in every state, for review and design (DEBUG only; opened from parent settings).
struct ComponentGallery: View {
    @State private var checked = false
    @State private var found = true
    @State private var listening = false
    @State private var bounces = 0
    @State private var confetti = 0
    @State private var typing = false
    @State private var paperRun = 0
    @State private var startRun = 0
    @State private var curtain = 0.5

    private var plan: GamePlan { Fallback.airplane.plan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                section("Start screen: PTToyChestScene (tap Replay), PTTitleCard + PTLogo (builds in), PTStartButton, PTCurtain (slider: closed → framed)") {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        PTToyChestScene(toys: PTStartArt.demoToys, onStart: {}) { look in
                            NutmegCharacter(state: .idle, showsGround: look.ground, showsTail: look.tail)
                        }
                        .id(startRun)
                        .frame(width: 900, height: 620).clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius))
                        Button("Replay") { startRun += 1 }.buttonStyle(.ptSecondary)
                        HStack(spacing: Theme.Space.l) {
                            PTTitleCard(logoTime: nil, logoWidth: 300)
                            PTStartButton {}
                            PTLogo().frame(width: 200)
                        }
                        Slider(value: $curtain, in: 0...1).frame(width: 300)
                        ZStack { PTStageBackdrop(curtains: false); PTCurtain(progress: curtain) }
                            .frame(width: 600, height: 400).clipped()
                    }
                    .padding().background(Theme.canvas)
                }
                section("Layout chrome (Emote style): PTStepRail states (current = star-yellow FFC93C, bold ink), PTControlBar states") {
                    HStack(alignment: .top, spacing: Theme.Space.l) {
                        PTStepRail(current: .game, reached: .game) { _ in }
                        PTStepRail(current: .getReady, reached: .print) { _ in }
                        PTStepRail(current: .play, reached: .play) { _ in }
                        VStack(spacing: Theme.Space.m) {
                            PTControlBar(isMuted: false, isListening: false, chatOpen: false, onMute: {}, onChat: {}, onLeave: {})
                            PTControlBar(isMuted: false, isListening: true, chatOpen: true, onMute: {}, onChat: {}, onLeave: {})
                            PTControlBar(isMuted: true, isListening: false, chatOpen: false, onMute: {}, onChat: {}, onLeave: {})
                            HStack {
                                Button("Print") {}.buttonStyle(.ptPrimary)
                                Button { } label: { Label("Chat", systemImage: "bubble.left") }.buttonStyle(.ptSecondary)
                                Button("Quiet") {}.buttonStyle(.ptQuiet)
                                Button("Done!") {}.buttonStyle(.ptSuccess)
                            }
                        }
                    }
                    .padding().background(Theme.canvas)
                }
                section("PTItemCard states (plain, found, swapped, pretend)") {
                    HStack(spacing: Theme.Space.m) {
                        PTItemCard(item: PTStageItem(id: "a", title: "Chair", subtitle: "Plane seats", image: UIImage(named: "prop-chair"), tint: Theme.playerColor(0)))
                        PTItemCard(item: PTStageItem(id: "b", title: "Tray", subtitle: "Snack cart", image: UIImage(named: "prop-tray"), tint: Theme.playerColor(1)), chip: .found)
                        PTItemCard(item: PTStageItem(id: "c", title: "Books", subtitle: "Snack cart", image: UIImage(named: "prop-books"), tint: Theme.playerColor(2)), chip: .swapped)
                        PTItemCard(item: PTStageItem(id: "d", title: "Backpack", image: UIImage(named: "prop-backpack"), tint: Theme.playerColor(3), isPretend: true), chip: .pretend)
                    }
                    .padding().background(Theme.canvas)
                }
                section("Prop hunt: PTPropActiveCard (with backup buttons), PTPropDoneChip (found, swapped, pretend)") {
                    HStack(alignment: .top, spacing: Theme.Space.l) {
                        PTPropActiveCard(item: PTStageItem(id: "p", title: "Plastic plate", subtitle: "the ship's steering wheel",
                                                           image: UIImage(named: "prop-plate"), tint: Theme.playerColor(0)),
                                         width: 400, onHunt: { _ in })
                        VStack(spacing: Theme.Space.s) {
                            PTPropDoneChip(item: PTStageItem(id: "a", title: "Tray", image: UIImage(named: "prop-tray"), chip: .found))
                            PTPropDoneChip(item: PTStageItem(id: "b", title: "Books", image: UIImage(named: "prop-books"), chip: .swapped))
                            PTPropDoneChip(item: PTStageItem(id: "c", title: "Hat", image: UIImage(named: "prop-hat"), isPretend: true, chip: .pretend))
                        }
                    }
                    .padding().background(Theme.startSky)
                }
                section("PTChatPanel, PTPaperReveal (papers fly off Nutmeg's clipboard; tap Replay)") {
                    HStack(alignment: .top, spacing: Theme.Space.l) {
                        PTChatPanel(lines: [.init(id: UUID(), fromNutmeg: true, text: "Ooh, a pancake restaurant on the moon?! Do the pancakes float?"),
                                            .init(id: UUID(), fromNutmeg: false, text: "Yes! And they're blue!")],
                                    onSend: { _ in }, onClose: {})
                            .frame(height: 420)
                        VStack {
                            NutmegCharacter(state: .coloring, forcedPose: .coloring).frame(height: 200)
                            Button("Replay") { paperRun += 1 }.buttonStyle(.ptSecondary)
                        }
                        PTPaperReveal(count: 4, isRevealed: true, origin: CGPoint(x: -260, y: 40),
                                      slot: { i in (CGPoint(x: (CGFloat(i) - 1.5) * 80, y: abs(CGFloat(i) - 1.5) * 6), (Double(i) - 1.5) * 2.5) },
                                      paperSize: CGSize(width: 90, height: 116)) { i in PTText("Page \(i + 1)", .caption) }
                            .id(paperRun)
                            .frame(width: 420, height: 280)
                    }
                    .padding().background(Theme.canvas)
                }
                section("Text styles") {
                    PTText("Hero", .hero); PTText("Title", .title); PTText("Headline", .headline)
                    PTText("Body text for kids", .body); PTText("Caption", .caption, tone: .muted)
                }
                section("Colors") {
                    HStack {
                        ForEach(Array([Theme.coral, Theme.coralStrong, Theme.purple, Theme.yellow, Theme.lime, Theme.nutmeg, Theme.cream, Theme.ink].enumerated()), id: \.offset) { _, c in
                            Circle().fill(c).frame(width: 60, height: 60).overlay(Circle().strokeBorder(Theme.line, lineWidth: 2))
                        }
                        ForEach(0..<4, id: \.self) { i in Circle().fill(Theme.playerColor(i)).frame(width: 60, height: 60) }
                    }
                }
                section("Backdrops + PTStageAccents (props around Nutmeg) + PTCurtainCorner") {
                    HStack(spacing: Theme.Space.m) {
                        ForEach(PTBackdrop.allCases, id: \.self) { b in
                            ZStack(alignment: .topLeading) {
                                NutmegCharacter(state: .idle).padding(Theme.Space.l).background { PTStageAccents() }
                                PTCurtainCorner(width: 70)
                            }
                            .frame(width: 230, height: 230)
                            .background(b.color)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .environment(\.ptBackdrop, b)
                        }
                    }
                }
                section("Motion: bounce, check burst, confetti") {
                    HStack(spacing: Theme.Space.l) {
                        PTChoiceTile(label: "Tap me", size: Theme.Size.countTile) { bounces += 1 }
                        PTChecklistRow(text: "Tap to check", isChecked: $checked) { PTPictureTile(image: UIImage(named: "action-clap"), placeholder: "clap") }.frame(width: 320)
                        Button("Confetti!") { confetti += 1 }.buttonStyle(.ptSecondary)
                    }
                    .overlay { PTConfetti().id(confetti) }
                }
                section("PTTypeSheet (typing when the mic is off)") {
                    Button { typing = true } label: { Label("Open", systemImage: "keyboard") }.buttonStyle(.ptQuiet)
                        .sheet(isPresented: $typing) { PTTypeSheet { _ in } }
                }
                section("Buttons (native Button + PTButtonStyle)") {
                    HStack(spacing: Theme.Space.m) {
                        Button("Primary") {}.buttonStyle(.ptPrimary)
                        Button("Secondary") {}.buttonStyle(.ptSecondary)
                        Button("Success") {}.buttonStyle(.ptSuccess)
                        Button("Quiet") {}.buttonStyle(.ptQuiet)
                        Button("Disabled") {}.buttonStyle(.ptPrimary).disabled(true)
                        Button { } label: { Label("With icon", systemImage: "airplane") }.buttonStyle(.ptSecondary)
                    }
                }
                section("PTChoiceTile") {
                    HStack(spacing: Theme.Space.m) {
                        PTChoiceTile(image: UIImage(named: "prop-chair"), label: "Airplane") {}
                        PTChoiceTile(label: "Restaurant", isSelected: true) {}
                        PTChoiceTile(label: "Animal Doctor with a long name") {}
                    }
                }
                section("PTCountPicker") { PTCountPicker(selected: 3) { _ in } }
                section("PTRoleBadge") {
                    HStack(spacing: Theme.Space.l) {
                        ForEach(plan.roles) { PTRoleBadge(role: $0) }
                    }
                }
                section("PTPropCard (found / not found)") {
                    HStack(spacing: Theme.Space.m) {
                        PTPropCard(prop: Fallback.airplane.props.props[1], found: $found)
                        PTPropCard(prop: Fallback.airplane.props.props[0], found: .constant(false))
                    }
                }
                section("PTChecklistRow") {
                    PTChecklistRow(text: "Check each ticket", isChecked: $checked) { PTPictureTile(image: nil, placeholder: "Boarding Pass") }
                    PTChecklistRow(text: "Show everyone a seat", isChecked: .constant(true)) { PTPictureTile(image: UIImage(named: "prop-chair")) }
                }
                section("PTHandoffCard") { PTHandoffCard(role: plan.roles[0], figure: { Image("nutmeg-body-point").resizable().scaledToFit() }, onTap: {}) }
                section("PTMicButton (idle / listening / unavailable = type instead)") {
                    HStack(spacing: Theme.Space.l) {
                        PTMicButton(isListening: false, isAvailable: true, onPress: {}, onRelease: {})
                        PTMicButton(isListening: true, isAvailable: true, onPress: {}, onRelease: {})
                        PTMicButton(isListening: false, isAvailable: false, onPress: {}, onRelease: {}, onTypeInstead: { typing = true })
                    }
                }
                section("PTParentGate / PTReplayButton") {
                    HStack(spacing: Theme.Space.l) {
                        PTParentGate(label: "Grown-up: hold to print") {}
                        PTReplayButton {}
                    }
                }
                section("Progress (native ProgressView styles)") {
                    HStack(spacing: Theme.Space.xl) {
                        ProgressView(value: 0.66).progressViewStyle(.ptRing).frame(width: 60, height: 60)
                    }
                }
                section("PTPageThumbnail + KitPageView") {
                    let pages = KitLayout.pages(for: Fallback.airplane.kit, roles: Fallback.airplane(playerCount: 3).plan.roles, playerCount: 3)
                    HStack(spacing: Theme.Space.m) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                            PTPageThumbnail(number: i + 1) {
                                KitPageView(page: page)
                                    .scaleEffect(Theme.Size.thumbnail / KitPageView.size.width)
                                    .frame(width: Theme.Size.thumbnail, height: Theme.Size.thumbnail * 11 / 8.5)
                            }
                        }
                    }
                }
                section("PTStageHeader / PTCard") {
                    PTStageHeader(title: "Takeoff!") { PTPictureTile(image: nil, placeholder: "cheer", size: 72) }
                    PTCard { PTText("A plain card", .body) }
                }
                section("Nutmeg: every state") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(220)), count: 4), spacing: Theme.Space.m) {
                        ForEach(NutmegState.allCases) { s in
                            VStack { NutmegCharacter(state: s, mouthLevel: 0.4, isSpeaking: s == .talking).frame(width: 200, height: 200); PTText(s.rawValue, .caption) }
                        }
                    }
                }
            }
            .padding(Theme.Space.l)
        }
        .background(Theme.background)
        .navigationTitle("Component gallery")
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            PTText(title, .headline, tone: .muted)
            content()
        }
    }
}

#Preview { NavigationStack { ComponentGallery() } }
#endif
