import SwiftUI
import NutmegCore

struct HandoffView: View {
    let model: AppModel
    let sceneIndex: Int
    private var store: AdventureStore { model.store }

    var body: some View {
        if let id = store.kit?.scenes[sceneIndex].owner.role, let role = store.plan?.role(for: id) {
            PTHandoffCard(role: role, figure: {
                NutmegCharacter(state: .idle, forcedPose: .point)
            }, onTap: { store.badgeTapped(id) })
                .id(sceneIndex)
        }
    }
}

struct SceneView: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }
    /// D6 (revised): one sheet of paper flies off Nutmeg's clipboard and becomes the checklist beside her.
    @State private var revealed = false

    static let paper = CGSize(width: 440, height: 470)

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            VStack(spacing: Theme.Space.m) {
                GeometryReader { geo in
                    PTPaperReveal(count: 1, isRevealed: revealed, origin: CGPoint(x: -geo.size.width / 2 - 150, y: 60),
                                  slot: { _ in (.zero, -1.5) }, paperSize: Self.paper,
                                  onLanded: { model.gesture(.celebrate) }) { _ in
                        ScrollView {
                            VStack(spacing: Theme.Space.s) {
                                PTStageHeader(title: scene.title) { model.pictureTile(scene.picture, size: 72) }
                                ForEach(Array(scene.steps.enumerated()), id: \.offset) { i, step in
                                    PTChecklistRow(text: step.text, isChecked: Binding(
                                        get: { store.checkedSteps.contains(i) }, set: { _ in store.toggleStep(i) })) {
                                        model.pictureTile(step.picture)
                                    }
                                }
                            }
                            .padding(Theme.Space.m)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: Self.paper.height + 20)
                Button("Done!") { store.sceneDone() }
                    .buttonStyle(store.checkedSteps.count == scene.steps.count ? .ptSuccess : .ptPrimary)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(350))
                revealed = true
            }
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
