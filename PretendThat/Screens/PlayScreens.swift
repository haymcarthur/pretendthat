import SwiftUI
import NutmegCore

struct HandoffView: View {
    let model: AppModel
    let sceneIndex: Int
    private var store: AdventureStore { model.store }

    var body: some View {
        if let id = store.kit?.scenes[sceneIndex].owner.role, let role = store.plan?.role(for: id) {
            // Nutmeg points at the card from the shared stage (no second Nutmeg inside the card).
            PTHandoffCard(role: role, figure: { EmptyView() }, onTap: { store.badgeTapped(id) })
                .id(sceneIndex)
        }
    }
}

/// The play step's scene checklist on the stage (chat closed). Round 8 (Haylee): it never scrolls; the paper is sized
/// to fit every step (scenes have ~3–6). Many steps shrink row padding and pictures before text (≥ 17 pt). "Done!" is a
/// full-width button under the paper. With the chat open the checklist is pinned at the top of the chat panel instead
/// (`PTScenePinnedCard`), like the prop and kit cards.
struct SceneView: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }
    /// D6 (revised): one sheet of paper flies off Nutmeg's clipboard and becomes the checklist beside her.
    @State private var revealed = false

    static let width: CGFloat = 440
    /// Row metrics for `n` steps: (picture side, font size, row padding, estimated row height for a two-line step).
    static func rows(_ n: Int) -> (picture: CGFloat, font: CGFloat, padding: CGFloat, height: CGFloat) {
        n <= 4 ? (56, 22, Theme.Space.s, 84) : (n == 5 ? (46, 20, Theme.Space.xs, 72) : (40, 18, Theme.Space.xs, 64))
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
                PTSceneDoneButton(allChecked: store.checkedSteps.count == n) { store.sceneDone() }
                    .frame(width: Self.width)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(350))
                revealed = true
            }
        }
    }
}

/// "Done!" as a real full-size button (round 8): full width of its card, 64 pt tall, big label; lime once every
/// step is checked.
struct PTSceneDoneButton: View {
    var allChecked: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) { Text("Done!").frame(maxWidth: .infinity) }
            .buttonStyle(PTButtonStyle(kind: allChecked ? .success : .primary, size: 26))
    }
}

/// The scene checklist pinned at the top of the chat panel (round 8, chat open), like the prop and kit cards: compact
/// rows (small pictures and padding, 17 pt text), every step visible, a full-width "Done!".
struct PTScenePinnedCard: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            VStack(spacing: Theme.Space.xs) {
                HStack(spacing: Theme.Space.s) {
                    model.pictureTile(scene.picture, size: 44)
                    Text(scene.title).font(Theme.displayFont(21)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                ForEach(Array(scene.steps.enumerated()), id: \.offset) { i, step in
                    PTChecklistRow(text: step.text, isChecked: Binding(
                        get: { store.checkedSteps.contains(i) }, set: { _ in store.toggleStep(i) }),
                                   fontSize: 17, padding: Theme.Space.xs) {
                        model.pictureTile(step.picture, size: 36)
                    }
                }
                PTSceneDoneButton(allChecked: store.checkedSteps.count == scene.steps.count) { store.sceneDone() }
                    .padding(.top, Theme.Space.xs)
            }
            .padding(Theme.Space.s)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.white))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
            .accessibilityElement(children: .contain)
        }
    }
}

struct StepBackView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTText("Go play!", .hero)
            HStack(spacing: Theme.Space.l) {
                Button { Task { _ = await store.helpRequested() } } label: { Label("Help, Nutmeg!", systemImage: "questionmark.bubble.fill") }
                    .buttonStyle(.ptSecondary)
                Button { store.nextScene() } label: { Label("Next scene", systemImage: "play.fill") }
                    .buttonStyle(.ptPrimary)
            }
        }
    }
}

struct EndView: View {
    let model: AppModel
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTText("The End!", .hero)
            HStack(spacing: Theme.Space.l) {
                Button { model.store.playAgain() } label: { Label("Play again", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(.ptSecondary)
                Button { model.art.reset(); model.store.newGame() } label: { Label("New game", systemImage: "sparkles") }
                    .buttonStyle(.ptPrimary)
            }
        }
    }
}
