import SwiftUI
import NutmegCore

// Setup screens: compose DesignSystem components only (no styling here).

struct HelloView: View {
    let model: AppModel
    /// Round 11: the tap on "Let's play!" (the exit starts): RootView slides the rail and pill in on the same move.
    var onExitBegan: () -> Void = {}
    /// Six of the ten toys, a new mix each launch (fixed while a DEBUG frame is frozen).
    @State private var toys: [String] = {
        #if DEBUG
        if DemoDriver.startFreeze != nil { return PTStartArt.demoToys }
        #endif
        return Array(PTStartArt.toys.shuffled().prefix(6))
    }()
    @Environment(\.layoutMetrics) private var metrics


    var body: some View {
        GeometryReader { geo in
            PTToyChestScene(toys: toys, frozenAt: freeze, handoff: handoff(geo, .arrival), camera: handoff(geo, firstFrame),
                            stageStars: stageStars(geo),
                            onExitBegan: onExitBegan,
                            onMyGames: model.shelfGames.isEmpty ? nil : { model.openShelf() },
                            onGrownUps: { model.openGrownUps() },
                            canStart: { model.canStartNewGame() },
                            onStart: { Task { await model.startConversation() } }) { look in
                NutmegCharacter(state: .idle, showsGround: look.ground, showsTail: look.tail)
            }
        }
    }

    /// Round 11: the game's first framing, so the exit's camera push lands on it and the game has nothing left to zoom:
    /// the talking close-up when the voice conversation will run, else the arrival (the tap screens take over there).
    private var firstFrame: PTStageFrame { model.opensInCloseUp ? .closeUp : .arrival }

    /// Where the conversation screen will draw Nutmeg for `frame` (chrome showing), in global coordinates: this view has
    /// the same frame the conversation stage gets, so she lands exactly there.
    private func handoff(_ geo: GeometryProxy, _ frame: PTStageFrame) -> CGRect {
        // iPhone version: the phone stage's first framing (whole body, filling the stage under the top bar).
        let frame = metrics.isPhone ? phoneFrame(geo) : frame
        let L = PTStageCamera.layout(frame, stageGeometry(geo), faceFocus: model.nutmegRestPose.faceFocus)
        let o = geo.frame(in: .global).origin
        return CGRect(x: o.x + L.origin.x, y: o.y + L.origin.y, width: L.canvas.width, height: L.canvas.height)
    }

    /// Round 11: the stage stars the game shows on its first framing (global), so the exit grows them in with the camera
    /// and the game stage takes them over in place (no pop after the landing). Same math as `PTStageView`.
    private func stageStars(_ geo: GeometryProxy) -> [PTStartStageStar] {
        let g = stageGeometry(geo)
        let comp = PTStageCamera.compose(metrics.isPhone ? phoneFrame(geo) : firstFrame, g, faceFocus: model.nutmegRestPose.faceFocus)
        let o = geo.frame(in: .global).origin
        return PTStageCamera.stars.compactMap { star in
            let side = star.size * comp.nutmeg.k   // round 11: same transform as Nutmeg (PTStageView)
            let p = comp.nutmeg.screen(star.point)
            guard comp.nutmeg.starFits(p, side: side, in: g.size, leadingInset: g.leadingInset, bottomInset: g.bottomInset) else { return nil }
            return PTStartStageStar(asset: star.asset, tilt: star.tilt, center: CGPoint(x: o.x + p.x, y: o.y + p.y), side: side)
        }
    }

    private func fullSize(_ geo: GeometryProxy) -> CGSize {
        CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
               height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
    }

    /// iPhone version: the same frame RootView's phone stage starts on.
    private func phoneFrame(_ geo: GeometryProxy) -> PTStageFrame {
        metrics.phoneFirstFrame(stage: geo.size, screen: fullSize(geo), safeTop: geo.safeAreaInsets.top)
    }

    private func stageGeometry(_ geo: GeometryProxy) -> PTStageGeometry {
        let full = fullSize(geo)
        let g = PTStageGeometry(size: geo.size, leadingInset: metrics.isPhone ? 0 : PTStageCamera.chromeLeading,
                                bottomInset: metrics.isPhone ? metrics.phoneChromeBottom : PTStageCamera.chromeBottom,
                                floor: PTStage.floor(full).offsetBy(dx: -geo.safeAreaInsets.leading, dy: -geo.safeAreaInsets.top))
        return g
    }

    private var freeze: Double? {
        #if DEBUG
        return DemoDriver.startFreeze
        #else
        return nil
        #endif
    }
}

struct PlayersView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            // Only the number of kids: we never ask for names. The number decides the roles (roles-not-names.md).
            if store.playerCount == 0 {
                PTCountPicker(selected: nil) { store.setPlayerCount($0) }
            } else {
                if case let roles = store.playingRoles, !roles.isEmpty {   // round C1: only the N playing roles
                    // Round 41 (the 4th tile ran under the curtain's tie-back on the iPad): one row up to 3 roles,
                    // then two columns (4 = 2 × 2, 5–6 = 3 rows), so every tile stays inside the card zone.
                    let size: CGFloat = metrics.isPhone ? (roles.count >= 5 ? 88 : 112) : Theme.Size.badge   // phone: 3 rows fit above the pill
                    if roles.count <= 3 {
                        HStack(spacing: metrics.isPhone ? Theme.Space.s : Theme.Space.l) {
                            ForEach(Array(roles.enumerated()), id: \.element.id) { i, r in
                                PTRoleBadge(role: r, size: roles.count == 3 && metrics.isPhone ? 96 : size).ptPopIn(index: i)
                            }
                        }
                    } else {
                        Grid(horizontalSpacing: Theme.Space.m, verticalSpacing: Theme.Space.m) {
                            ForEach(Array(stride(from: 0, to: roles.count, by: 2)), id: \.self) { row in
                                GridRow {
                                    ForEach(row..<min(row + 2, roles.count), id: \.self) { i in
                                        PTRoleBadge(role: roles[i], size: size).ptPopIn(index: i)
                                    }
                                }
                            }
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
                // Round 23 (Haylee): no "Skip" (it did the same as All set!); the hunt ends with All set!.
                Button("All set!") { Task { await store.confirmProps() } }
                    .buttonStyle(store.foundProps.count == props.props.count ? .ptSuccess : .ptPrimary)
            }
        }
    }
}
