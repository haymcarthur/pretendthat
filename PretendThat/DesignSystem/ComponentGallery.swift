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

    private let mia = Player(token: .P1, name: "Mia", colorIndex: 0, emoji: "💙")
    private let sam = Player(token: .P2, name: "Sam", colorIndex: 1, emoji: "🧡")
    private let ollie = Player(token: .P3, name: "", colorIndex: 2, emoji: "💚")
    private let ava = Player(token: .P4, name: "Ava", colorIndex: 3, emoji: "💜")
    private var plan: GamePlan { Fallback.airplane.plan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
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
                        PTChoiceTile(emoji: "🦕", label: "Tap me", size: Theme.Size.countTile) { bounces += 1 }
                        PTChecklistRow(emoji: "⭐", text: "Tap to check", isChecked: $checked).frame(width: 320)
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
                        PTChoiceTile(emoji: "✈️", label: "Airplane") {}
                        PTChoiceTile(emoji: "🍝", label: "Restaurant", isSelected: true) {}
                        PTChoiceTile(emoji: "🐶", label: "Animal Doctor with a long name") {}
                    }
                }
                section("PTCountPicker") { PTCountPicker(selected: 3) { _ in } }
                section("PTSpeechBubble") { PTSpeechBubble(text: "Ooh! Pretend that we're flying over the ocean!") }
                section("PTRoleBadge") {
                    HStack(spacing: Theme.Space.l) {
                        PTRoleBadge(player: mia, role: plan.roles[0])
                        PTRoleBadge(player: sam, role: plan.roles[1])
                        PTRoleBadge(player: ollie, role: plan.roles[2])
                        PTRoleBadge(player: ava, role: nil)
                    }
                }
                section("PTPropCard (found / not found)") {
                    HStack(spacing: Theme.Space.m) {
                        PTPropCard(prop: Fallback.airplane.props.props[1], found: $found)
                        PTPropCard(prop: Fallback.airplane.props.props[0], found: .constant(false))
                    }
                }
                section("PTChecklistRow") {
                    PTChecklistRow(emoji: "🎫", text: "Check each ticket", isChecked: $checked)
                    PTChecklistRow(emoji: "🪑", text: "Show everyone a seat", isChecked: .constant(true))
                }
                section("PTHandoffCard") { PTHandoffCard(player: mia, role: plan.roles[0]) {} }
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
                        PTWorkingIndicator()
                    }
                }
                section("PTPageThumbnail + KitPageView") {
                    let pages = KitLayout.pages(for: Fallback.airplane.kit, players: [.P1, .P2, .P3], directorMode: false)
                    let tokens = NameTokens(players: [mia, sam, ollie])
                    HStack(spacing: Theme.Space.m) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                            PTPageThumbnail(number: i + 1) {
                                KitPageView(page: page, tokens: tokens)
                                    .scaleEffect(Theme.Size.thumbnail / KitPageView.size.width)
                                    .frame(width: Theme.Size.thumbnail, height: Theme.Size.thumbnail * 11 / 8.5)
                            }
                        }
                    }
                }
                section("PTStageHeader / PTCard") {
                    PTStageHeader(emoji: "🛫", title: "Takeoff!")
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
