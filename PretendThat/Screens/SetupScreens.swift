import SwiftUI
import NutmegCore

// Setup screens: compose DesignSystem components only (no styling here).

struct HelloView: View {
    let model: AppModel
    var onGrownUps: () -> Void = {}
    /// Six of the ten toys, a new mix each launch (fixed while a DEBUG frame is frozen).
    @State private var toys: [String] = {
        #if DEBUG
        if DemoDriver.startFreeze != nil { return PTStartArt.demoToys }
        #endif
        return Array(PTStartArt.toys.shuffled().prefix(6))
    }()

    var body: some View {
        PTToyChestScene(toys: toys, frozenAt: freeze, onStart: { Task { await model.startConversation() } }) { waving in
            NutmegCharacter(state: .idle, forcedPose: waving ? .wave : nil)
        }
        .overlay(alignment: .topTrailing) {
            // Over the right curtain, under the valance: clear of the toys and the title card.
            PTParentGate(label: "Grown-ups", symbol: "gearshape", onComplete: onGrownUps)
                .padding(.top, 84).padding(.trailing, Theme.Space.m)
        }
    }

    private var freeze: Double? {
        #if DEBUG
        return DemoDriver.startFreeze
        #else
        return nil
        #endif
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
                        PTChoiceTile(label: idea.title) {
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
            // Only the number of kids: we never ask for names. The number decides the roles (roles-not-names.md).
            if store.playerCount == 0 {
                PTCountPicker(selected: nil) { store.setPlayerCount($0) }
            } else {
                if let roles = store.plan?.roles {
                    HStack(spacing: Theme.Space.l) {
                        ForEach(Array(roles.enumerated()), id: \.element.id) { i, r in
                            PTRoleBadge(role: r).ptPopIn(index: i)
                        }
                    }
                }
                if store.isWorking {
                    PTWorkingIndicator(caption: "Picking jobs...")
                } else if store.plan == nil {
                    HStack(spacing: Theme.Space.m) {
                        Button("Change") { store.resetPlayers() }.buttonStyle(.ptQuiet)
                        Button("Pick our jobs!") { Task { await store.confirmPlayers() } }.buttonStyle(.ptPrimary)
                    }
                } else {
                    PTText("Pick your badge after printing!", .caption, tone: .muted)
                    Button("Let's go!") { Task { await store.confirmRoles() } }.buttonStyle(.ptPrimary)
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
