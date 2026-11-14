import SwiftUI
import NutmegCore

struct HandoffView: View {
    let model: AppModel
    let sceneIndex: Int
    /// Chat open: pinned at the top of the chat panel (round 10), same card at full readable size.
    var pinned = false
    private var store: AdventureStore { model.store }

    var body: some View {
        if let id = store.kit?.scenes[sceneIndex].owner.role, let role = store.plan?.role(for: id) {
            // Nutmeg points at the card from the shared stage (no second Nutmeg inside the card).
            PTHandoffCard(role: role, figure: { EmptyView() }, onTap: { store.badgeTapped(id) },
                          onBack: store.canGoBackToChecklist ? { store.backToChecklist() } : nil, pinned: pinned)
                .id(sceneIndex)
        }
    }
}

/// "← Back to the checklist" (round 10, Haylee): undo a "Done!", restoring the checkmarks exactly as they were.
struct PTBackToChecklistButton: View {
    var compact = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Back to the checklist", systemImage: "arrow.left").frame(maxWidth: compact ? .infinity : nil)
        }
        .buttonStyle(.ptSecondary)
        .accessibilityLabel("Back to the checklist")
    }
}

/// The play step's scene checklist on the stage (chat closed). Round 8 (Haylee): it never scrolls; the paper is sized
/// to fit every step (scenes have ~3–6). Many steps shrink row padding and pictures before text (≥ 17 pt). "Done!" is a
/// full-width button under the paper, always visible (round 10: tapped early, it checks the rest for the kid, then the
/// next hand-off card comes). Round 10: it sits in the prop-card step's content zone (same camera as the hunt). With
/// the chat open the checklist is pinned at the top of the chat panel instead (`PTScenePinnedCard`).
struct SceneView: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }
    /// D6 (revised): one sheet of paper flies off Nutmeg's clipboard and becomes the checklist beside her.
    @State private var revealed = false

    static let width: CGFloat = 380
    /// Row metrics for `n` steps: (picture side, font size, row padding, estimated row height for a two-line step).
    static func rows(_ n: Int) -> (picture: CGFloat, font: CGFloat, padding: CGFloat, height: CGFloat) {
        n <= 4 ? (52, 22, Theme.Space.s, 84) : (n == 5 ? (44, 20, Theme.Space.xs, 72) : (38, 18, Theme.Space.xs, 64))
    }
    static func paper(_ n: Int) -> CGSize {
        let r = rows(n)
        return CGSize(width: width, height: 150 + CGFloat(n) * (r.height + Theme.Space.s) + Theme.Space.m)
    }

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            let n = scene.steps.count, paper = Self.paper(n), r = Self.rows(n)
            VStack(spacing: Theme.Space.m) {
                GeometryReader { geo in
                    PTPaperReveal(count: 1, isRevealed: revealed, origin: CGPoint(x: -geo.size.width / 2 - 150, y: 60),
                                  slot: { _ in (.zero, -1.5) }, paperSize: paper,
                                  onLanded: { model.gesture(.celebrate) }) { _ in
                        VStack(spacing: Theme.Space.s) {
                            PTStageHeader(title: scene.title) { model.pictureTile(scene.picture, size: n <= 4 ? 72 : 56) }
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(scene.steps.enumerated()), id: \.offset) { i, step in
                                PTChecklistRow(text: step.text, isChecked: Binding(
                                    get: { store.checkedSteps.contains(i) }, set: { _ in store.toggleStep(i) }),
                                               fontSize: r.font, padding: r.padding) {
                                    model.pictureTile(step.picture, size: r.picture)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(Theme.Space.m)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: paper.height + 20)
                PTSceneDoneButton(allChecked: store.checkedSteps.count == n, busy: store.autoChecking) { Task { await store.sceneDone() } }
                    .frame(width: Self.width)
            }
            .onAppear { revealed = true }   // round 11: in the same frame as the camera move (round 10: 60 ms after)
        }
    }
}

/// "Done!" as a real full-size button (round 8): full width of its card, 64 pt tall, big label; lime once every
/// step is checked. Round 10: always enabled (an early tap auto-checks the rest); ignored while that runs.
struct PTSceneDoneButton: View {
    var allChecked: Bool
    var busy = false
    var size: CGFloat = 26
    var action: () -> Void
    var body: some View {
        Button(action: action) { Text("Done!").frame(maxWidth: .infinity) }
            .buttonStyle(PTButtonStyle(kind: allChecked ? .success : .primary, size: size))
            .allowsHitTesting(!busy)
    }
}

/// Round 10 rule (Haylee): every interactive card pinned in the chat panel (prop, kit, checklist, hand-off) shares
/// one treatment: the panel's full width, a white rounded card with a hairline, readable sizes.
struct PTPinnedCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Space.s)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.white))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
    }
}
extension View { func ptPinnedCard() -> some View { modifier(PTPinnedCardStyle()) } }

/// The most a pinned card may take of the chat panel's height (round 10: ~50%, so the transcript stays readable).
private struct PTPinnedCapKey: EnvironmentKey { static let defaultValue: CGFloat = .infinity }
extension EnvironmentValues {
    var ptPinnedCap: CGFloat {
        get { self[PTPinnedCapKey.self] }
        set { self[PTPinnedCapKey.self] = newValue }
    }
}

/// The scene checklist pinned at the top of the chat panel (chat open). Round 10 (Haylee: it hogged the panel):
/// compact rows (28 pt pictures, 17 pt text, tight padding), the title on one line, at most ~50% of the panel. If the
/// steps don't fit in that, it collapses to a summary row ("Set the Rainbow Table · 1 of 4 ✓", tap to expand) instead of
/// scrolling. "Done!" is always visible.
struct PTScenePinnedCard: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }
    @State private var expanded = false
    @Environment(\.ptPinnedCap) private var cap

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            Group {
                if expanded {
                    full(scene, collapsible: true)
                } else if Self.estimatedHeight(scene) <= cap {
                    full(scene, collapsible: false)
                } else {
                    summary(scene)
                }
            }
            .ptPinnedCard()
            .accessibilityElement(children: .contain)
        }
    }

    /// Height of the full compact card (pt): header, rows (one line ≈ 46, two lines ≈ 66 at ~26 characters a line
    /// in the 360 pt panel), Done and padding. Over the cap → the summary row.
    static func estimatedHeight(_ scene: KitScene) -> CGFloat {
        let rows = scene.steps.reduce(CGFloat(0)) { $0 + ($1.text.count > 26 ? 66 : 46) + 6 }
        return 44 + rows + 64 + 2 * Theme.Space.s + 8
    }

    private func title(_ scene: KitScene) -> some View {
        Text(scene.title).font(Theme.displayFont(19)).foregroundStyle(Theme.ink)
            .lineLimit(1).minimumScaleFactor(0.7)
    }

    private func full(_ scene: KitScene, collapsible: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: Theme.Space.s) {
                model.pictureTile(scene.picture, size: 32)
                title(scene)
                Spacer(minLength: 0)
                if collapsible {
                    Button { withAnimation(Theme.stageMove) { expanded = false } } label: {
                        Image(systemName: "chevron.up").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.inkMuted)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain).accessibilityLabel("Show less")
                }
            }
            ForEach(Array(scene.steps.enumerated()), id: \.offset) { i, step in
                PTChecklistRow(text: step.text, isChecked: Binding(
                    get: { store.checkedSteps.contains(i) }, set: { _ in store.toggleStep(i) }),
                               fontSize: 17, padding: 6) {
                    model.pictureTile(step.picture, size: 28)
                }
            }
            done(scene)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func summary(_ scene: KitScene) -> some View {
        VStack(spacing: 6) {
            Button { withAnimation(Theme.stageMove) { expanded = true } } label: {
                HStack(spacing: Theme.Space.s) {
                    model.pictureTile(scene.picture, size: 32)
                    Text("\(scene.title) · \(store.checkedSteps.count) of \(scene.steps.count) ✓")
                        .font(Theme.bodyFont(17)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.inkMuted)
                }
                .padding(.vertical, 6).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(scene.title), \(store.checkedSteps.count) of \(scene.steps.count) done. Show the steps")
            done(scene)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func done(_ scene: KitScene) -> some View {
        PTSceneDoneButton(allChecked: store.checkedSteps.count == scene.steps.count, busy: store.autoChecking, size: 22) {
            Task { await store.sceneDone() }
        }
        .padding(.top, 2)
    }
}

struct EndView: View {
    let model: AppModel
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTText("The End!", .hero)
            // Round 10: right after the last "Done!", the finale can still go back to that checklist.
            if model.store.canGoBackToChecklist { PTBackToChecklistButton { model.store.backToChecklist() } }
            HStack(spacing: Theme.Space.l) {
                Button { model.store.playAgain() } label: { Label("Play again", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(.ptSecondary)
                Button { model.art.reset(); model.store.newGame() } label: { Label("New game", systemImage: "sparkles") }
                    .buttonStyle(.ptPrimary)
            }
        }
    }
}
