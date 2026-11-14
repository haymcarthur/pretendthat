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

    @State private var introDone = false

    var body: some View {
        GeometryReader { geo in
            PTToyChestScene(toys: toys, frozenAt: freeze, handoff: handoff(geo),
                            onIntroFinished: { withAnimation(.easeOut(duration: 0.35)) { introDone = true } },
                            onGrownUps: onGrownUps,
                            onStart: { Task { await model.startConversation() } }) { look in
                NutmegCharacter(state: .idle, showsGround: look.ground, showsTail: look.tail)
            }
            .overlay(alignment: .topTrailing) {
                // A tiny faint gear, shown only once the opening is over (grown-ups can also hold the logo card).
                if Theme.showSettingsGear {
                    PTParentGate(label: "Grown-ups", symbol: "gearshape", style: .gear, onComplete: onGrownUps)
                        .opacity(introDone ? 1 : 0)
                        .allowsHitTesting(introDone)
                        .padding(.top, Theme.Space.s).padding(.trailing, Theme.Space.s)
                }
            }
        }
    }

    /// Where the conversation screen will draw Nutmeg (medium shot, chrome showing), in global coordinates: this view
    /// has the same frame the conversation stage gets, so she lands exactly there.
    private func handoff(_ geo: GeometryProxy) -> CGRect {
        let L = PTStageCamera.layout(shot: .medium, itemCount: 0, size: geo.size,
                                     leadingInset: PTStageCamera.chromeLeading, bottomInset: PTStageCamera.chromeBottom)
        let o = geo.frame(in: .global).origin
        return CGRect(x: o.x + L.origin.x, y: o.y + L.origin.y, width: L.canvas.width, height: L.canvas.height)
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
            if let ideas = model.store.ideas {
                HStack(spacing: Theme.Space.m) {
                    ForEach(Array(ideas.ideas.enumerated()), id: \.element.id) { i, idea in
                        PTChoiceTile(label: idea.title) {
                            Task { await model.store.chooseGame(idea.title) }
                        }
                        .ptPopIn(index: i)
                    }
                }
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
                    EmptyView()   // Nutmeg's thinking pose says it (no loading text, no-text-overlays.md)
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
            }
        }
    }
}
