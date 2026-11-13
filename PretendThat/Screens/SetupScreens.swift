import SwiftUI
import NutmegCore

// Setup screens: compose DesignSystem components only (no styling here).

struct HelloView: View {
    let model: AppModel
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTText("PretendThat", .hero)
            PTSpeechBubble(text: "Hi! I'm Nutmeg! Let's put on a show!")
            Button("Let's play!") { Task { await model.startConversation() } }
                .buttonStyle(.ptSecondary)
                .ptPopIn(index: 1)
        }
    }
}

struct PickGameView: View {
    let model: AppModel
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTSpeechBubble(text: model.store.nutmegLine)
            if let ideas = model.store.ideas {
                HStack(spacing: Theme.Space.m) {
                    ForEach(Array(ideas.ideas.enumerated()), id: \.element.id) { i, idea in
                        PTChoiceTile(emoji: idea.emoji, label: idea.title) {
                            Task { await model.store.chooseGame(idea.title) }
                        }
                        .ptPopIn(index: i)
                    }
                }
            } else {
                PTWorkingIndicator()
            }
            PTText("Hold the mic and say your own idea!", .caption, tone: .muted)
        }
    }
}

struct PlayersView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTSpeechBubble(text: store.nutmegLine)
            if store.players.isEmpty {
                PTCountPicker(selected: nil) { store.setPlayerCount($0) }
            } else {
                HStack(spacing: Theme.Space.l) {
                    ForEach(Array(store.players.enumerated()), id: \.element.id) { i, p in
                        PTRoleBadge(player: p, role: store.plan?.role(for: p.token))
                            .ptPopIn(index: i)
                    }
                }
                if store.isWorking {
                    PTWorkingIndicator(caption: "Picking jobs...")
                } else if store.plan == nil {
                    HStack(spacing: Theme.Space.m) {
                        Button("Change") { store.resetPlayers() }.buttonStyle(.ptQuiet)
                        Button("Pick our jobs!") { Task { await store.confirmPlayers() } }.buttonStyle(.ptPrimary)
                    }
                    if !model.listener.available && !store.directorMode {
                        PTText("No mic? That's OK, we'll use player numbers.", .caption, tone: .muted)
                    }
                } else {
                    HStack(spacing: Theme.Space.m) {
                        if (store.plan?.roles.count ?? 0) > 1 {
                            Button { store.swapRoles() } label: { Label("Swap", systemImage: "arrow.triangle.2.circlepath") }
                                .buttonStyle(.ptSecondary)
                        }
                        Button("Let's go!") { Task { await store.confirmRoles() } }.buttonStyle(.ptPrimary)
                    }
                }
            }
        }
    }
}

struct PropsView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTSpeechBubble(text: store.nutmegLine)
            if let props = store.props {
                let columns = props.props.count == 4 ? 2 : 3
                Grid(horizontalSpacing: Theme.Space.m, verticalSpacing: Theme.Space.m) {
                    ForEach(Array(stride(from: 0, to: props.props.count, by: columns)), id: \.self) { row in
                        GridRow {
                            ForEach(props.props[row..<min(row + columns, props.props.count)]) { prop in
                                PTPropCard(prop: prop, found: Binding(
                                    get: { store.foundProps.contains(prop.id) },
                                    set: { _ in store.toggleProp(prop.id) }))
                            }
                        }
                    }
                }
                HStack(spacing: Theme.Space.m) {
                    Button("Skip") { Task { await store.confirmProps() } }.buttonStyle(.ptQuiet)
                    Button("All set!") { Task { await store.confirmProps() } }
                        .buttonStyle(store.foundProps.count == props.props.count ? .ptSuccess : .ptPrimary)
                }
            } else {
                PTWorkingIndicator(caption: "Finding props...")
            }
        }
    }
}
