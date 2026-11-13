import SwiftUI
import NutmegCore

struct HandoffView: View {
    let model: AppModel
    let sceneIndex: Int
    private var store: AdventureStore { model.store }

    var body: some View {
        if let token = store.kit?.scenes[sceneIndex].owner.token, let player = store.players.first(where: { $0.token == token }) {
            PTHandoffCard(player: player, role: store.plan?.role(for: token)) { store.badgeTapped(token) }
                .id(sceneIndex)
        }
    }
}

struct SceneView: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }
    /// D6: the checklist arrives on Nutmeg's clipboard, which flips around to reveal it (her head peeks in).
    @State private var revealed = false

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            VStack(spacing: Theme.Space.m) {
                PTClipboardReveal(isRevealed: revealed, peek: true, width: 400, contentScale: 0.72) {
                    ScrollView {
                        VStack(spacing: Theme.Space.s) {
                            PTStageHeader(emoji: scene.emoji, title: store.tokens.untokenize(scene.title))
                            ForEach(Array(scene.steps.enumerated()), id: \.offset) { i, step in
                                PTChecklistRow(emoji: step.emoji, text: store.tokens.untokenize(step.text), isChecked: Binding(
                                    get: { store.checkedSteps.contains(i) }, set: { _ in store.toggleStep(i) }))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                Button("Done!") { store.sceneDone() }
                    .buttonStyle(store.checkedSteps.count == scene.steps.count ? .ptSuccess : .ptPrimary)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(450))
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
            PTSpeechBubble(text: store.nutmegLine)
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
            PTText("🎉 The End! 🎉", .hero)
            PTSpeechBubble(text: model.store.nutmegLine)
            HStack(spacing: Theme.Space.l) {
                Button { model.store.playAgain() } label: { Label("Play again", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(.ptSecondary)
                Button { model.art.reset(); model.store.newGame() } label: { Label("New game", systemImage: "sparkles") }
                    .buttonStyle(.ptPrimary)
            }
        }
    }
}
