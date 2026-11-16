import SwiftUI
import NutmegCore

// Prop hunt layout (prop-gathering-flow.md, Haylee fix round 2): one prop at a time, Nutmeg at the medium shot.
// CHAT CLOSED: she stands left of center; the ACTIVE card is on the RIGHT where she points (vertically centered on her
// chest, ≥ 32 pt inside the curtain); DONE props are small cards stacked on the LEFT between the step rail and her.
// CHAT OPEN: the active card docks at the top of the chat panel (`PTPropPinnedCard`); done props become a row of small
// round thumbnails along the top of the stage (`PTPropDoneThumb`); she re-centers below them. Shared matched-geometry
// ids animate the cards between the two layouts when the panel toggles.

/// Matched-geometry id of the active hunt card (stage card ↔ pinned card in the chat panel).
let ptHuntActiveID = "hunt-active"

/// The hunt's screen-space layout on the stage (cards only; Nutmeg is drawn by `PTStageView`).
struct PTPropHuntStage: View {
    let items: [PTStageItem]
    let geometry: PTStageGeometry
    /// Nutmeg's current layout (the cards keep clear of her).
    let nutmeg: PTStageCamera.Layout
    /// How far the tied-back curtain reaches in at the card's height.
    let curtainInset: CGFloat
    let namespace: Namespace.ID
    var onHunt: ((String, Bool) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let g = geometry, L = nutmeg, F = g.free
        let done = items.filter(\.isDone)
        let active = items.last { !$0.isDone }
        let chestY = L.screen(CGPoint(x: 0, y: PTStageCamera.chestY)).y
        ZStack(alignment: .topLeading) {
            if g.chatOpen {
                // Done thumbnails along the top of the stage, right of the rail (Nutmeg stands below the row).
                HStack(spacing: 10) {
                    ForEach(done) { item in
                        PTPropDoneThumb(item: item).matchedGeometryEffect(id: item.id, in: namespace)
                    }
                }
                .fixedSize()
                .padding(.leading, F.minX + 8)
                .padding(.top, F.minY + (PTStageDirector.thumbRow - PTPropDoneThumb.side) / 2 - 4)
            } else {
                if let active {
                    let zoneL = L.maxX + 20, zoneR = g.size.width - curtainInset - PTStageDirector.curtainGap
                    let w = max(200, min(PTStageDirector.huntCardWidth(g), zoneR - zoneL))
                    PTPropActiveCard(item: active, width: w, onHunt: active.huntButtons ? onHunt.map { f in { f(active.id, $0) } } : nil)
                        .matchedGeometryEffect(id: ptHuntActiveID, in: namespace)
                        .position(x: zoneR - w / 2, y: min(max(chestY, F.minY + 200), F.maxY - 190))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                let stackH = CGFloat(done.count) * 72
                VStack(spacing: Theme.Space.s) {
                    ForEach(done) { item in
                        PTPropDoneChip(item: item, width: PTStageDirector.doneStackWidth).matchedGeometryEffect(id: item.id, in: namespace)
                    }
                }
                .frame(width: PTStageDirector.doneStackWidth)
                .position(x: F.minX + 8 + PTStageDirector.doneStackWidth / 2,
                          y: min(max(chestY, F.minY + stackH / 2 + 8), F.maxY - stackH / 2))
            }
        }
        .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: done.map(\.id))
        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: active?.id)
    }
}

/// The active prop docked at the top of the chat panel: art left, name + "becomes" right, the two backup buttons in a
/// row below (single-line labels).
struct PTPropPinnedCard: View {
    let item: PTStageItem
    var onHunt: ((Bool) -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.s) {
                Group {
                    if let image = item.image { Image(uiImage: image).resizable().scaledToFit() } else { PTShimmer(tint: item.tint) }
                }
                .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(Theme.displayFont(21)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                    if let sub = item.subtitle {
                        Text(sub).font(Theme.uiFont(15, .medium)).foregroundStyle(Theme.inkMuted)   // never truncated
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if let onHunt {
                HStack(spacing: Theme.Space.xs) {
                    PTHuntPill(title: "Found it!", symbol: "checkmark", fill: Theme.lime, edge: Theme.limeShade, compact: true) { onHunt(true) }
                    PTHuntPill(title: "Don't have it", symbol: "xmark", fill: Theme.white, edge: Theme.line, compact: true) { onHunt(false) }
                }
            }
        }
        .padding(Theme.Space.s)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.white))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
        .accessibilityElement(children: .contain)
    }
}

/// A done prop as a small round thumbnail with a check (or swap / pretend) badge (chat open).
struct PTPropDoneThumb: View {
    let item: PTStageItem
    static let side: CGFloat = 60

    var body: some View {
        Group {
            if let image = item.image { Image(uiImage: image).resizable().scaledToFit().padding(8) } else { PTShimmer(tint: item.tint) }
        }
        .frame(width: Self.side, height: Self.side)
        .saturation(item.isPretend ? 0 : 1).opacity(item.isPretend ? 0.6 : 1)
        .background(Circle().fill(Theme.white))
        .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1.5))
        .shadow(color: Theme.panelShadow, radius: 6, y: 2)
        .overlay(alignment: .bottomTrailing) { PTPropBadge(item: item, side: 22).offset(x: 3, y: 3) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title + (item.isPretend ? ", we'll pretend" : ", found"))
    }
}

/// The found check / swap arrows / pretend sparkle badge.
struct PTPropBadge: View {
    let item: PTStageItem
    var side: CGFloat = 26
    var body: some View {
        let (symbol, fill): (String, Color) = item.isPretend ? ("sparkles", Theme.chipGray)
            : (item.chip == .swapped ? ("arrow.triangle.2.circlepath", Theme.yellow) : ("checkmark", Theme.lime))
        Image(systemName: symbol).font(.system(size: side * 0.5, weight: .heavy)).foregroundStyle(Theme.ink)
            .frame(width: side, height: side).background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(Theme.white, lineWidth: 2))
    }
}

/// A backup hunt button ("Found it!" / "Don't have it"): one line, never truncated.
struct PTHuntPill: View {
    let title: String
    let symbol: String
    let fill: Color
    let edge: Color
    var compact = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 4 : 6) {
                Image(systemName: symbol).font(.system(size: compact ? 14 : 17, weight: .heavy))
                Text(title).lineLimit(1).fixedSize()
            }
            .font(Theme.uiFont(compact ? 15 : 18)).foregroundStyle(Theme.ink)
            .padding(.horizontal, compact ? 10 : Theme.Space.m)
            .frame(maxWidth: .infinity, minHeight: compact ? 50 : 56)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(edge, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// The big card for the prop the kids are hunting right now.
struct PTPropActiveCard: View {
    let item: PTStageItem
    var width: CGFloat = 420
    /// Backup buttons for noisy rooms (found: true / false). nil hides them.
    var onHunt: ((Bool) -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            Group {
                if let image = item.image { Image(uiImage: image).resizable().scaledToFit() } else { PTShimmer(tint: item.tint) }
            }
            .frame(width: width * 0.62, height: width * 0.62)
            Text(item.title).font(Theme.displayFont(28)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let sub = item.subtitle {
                Text(sub).font(Theme.uiFont(19, .medium)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)   // never truncated: the card grows
            }
            if let onHunt {
                // Side by side when the card is wide enough, stacked otherwise: labels never truncate or wrap.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Space.s) { buttons(onHunt) }
                    VStack(spacing: Theme.Space.s) { buttons(onHunt) }
                }
                .padding(.top, Theme.Space.xs)
            }
        }
        .padding(Theme.Space.m)
        .frame(width: width)
        .ptPanel(radius: 30)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func buttons(_ onHunt: @escaping (Bool) -> Void) -> some View {
        PTHuntPill(title: "Found it!", symbol: "checkmark", fill: Theme.lime, edge: Theme.limeShade) { onHunt(true) }
        PTHuntPill(title: "Don't have it", symbol: "xmark", fill: Theme.white, edge: Theme.line) { onHunt(false) }
    }
}

/// A small chip for a prop that's done: thumbnail, name and a badge (found check, swap arrows, or faded "pretend").
struct PTPropDoneChip: View {
    let item: PTStageItem
    var width: CGFloat = 180

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let image = item.image { Image(uiImage: image).resizable().scaledToFit() } else { PTShimmer(tint: item.tint) }
            }
            .frame(width: 42, height: 42)
            .saturation(item.isPretend ? 0 : 1).opacity(item.isPretend ? 0.5 : 1)
            .overlay(alignment: .bottomTrailing) { PTPropBadge(item: item, side: 20).offset(x: 5, y: 5) }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(Theme.uiFont(14)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                if item.isPretend {
                    Text("We'll pretend").font(Theme.uiFont(11, .medium)).foregroundStyle(Theme.inkMuted).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: width)
        .ptPanel(radius: 18)
        .opacity(item.isPretend ? 0.85 : 1)
        .accessibilityElement(children: .combine)
    }

}

extension PTStageItem {
    /// Done in the hunt: found, or skipped (we'll pretend).
    var isDone: Bool { chip == .found || isPretend }
}

/// Round 19 (Haylee): the confirm step's two big buttons under Nutmeg's recap ("So it's a bug movie theater for three
/// friends! Ready, or want to change something?"). Voice answers work too.
struct PTConfirmButtons: View {
    let onYes: () -> Void
    let onChange: () -> Void
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            PTHuntPill(title: ConfirmStep.yesLabel, symbol: "checkmark", fill: Theme.lime, edge: Theme.limeShade, action: onYes)
            PTHuntPill(title: ConfirmStep.changeLabel, symbol: "pencil", fill: Theme.white, edge: Theme.line, action: onChange)
        }
        .frame(maxWidth: 560)
        .padding(Theme.Space.s)
        .ptPanel(radius: 40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Is the plan right?")
    }
}

/// Round 20 (Haylee): the color question's two big buttons ("Do you want your printables in full color, or do you want
/// to color them yourself?"). Voice answers work too.
struct PTColorChoiceButtons: View {
    let onChoose: (PrintStyle) -> Void
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            PTHuntPill(title: ColorChoice.fullColorLabel, symbol: "paintpalette", fill: Theme.lime, edge: Theme.limeShade) { onChoose(.fullColor) }
            PTHuntPill(title: ColorChoice.colorInLabel, symbol: "pencil.and.scribble", fill: Theme.white, edge: Theme.line) { onChoose(.colorIn) }
        }
        .frame(maxWidth: 560)
        .padding(Theme.Space.s)
        .ptPanel(radius: 40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Full color, or color them yourself?")
    }
}
