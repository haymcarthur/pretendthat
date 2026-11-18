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
                // Round 30 (Haylee): chat open, the panel's Props tab lists every prop (current, found, pretend), so
                // the stage hides its duplicate cards (round 14 did the same for the checklist).
                EmptyView()
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
                .overlay(alignment: .bottomTrailing) { PTPropCountBadge(count: item.count, side: 30).offset(x: 4, y: 4) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(Theme.displayFont(21)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.6)
                    if let sub = item.subtitle {
                        Text(sub).font(Theme.uiFont(15, .medium)).foregroundStyle(Theme.inkMuted)   // never truncated
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if let onHunt { PTHuntButtons(size: 64, action: onHunt) }
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

/// 2026-11-18: "×4" on a multiple prop's picture (nothing for a single prop).
struct PTPropCountBadge: View {
    let count: Int
    var side: CGFloat = 40
    var body: some View {
        if count > 1 {
            Text("×\(count)").font(Theme.headlineFont(side * 0.46)).foregroundStyle(Theme.ink)
                .padding(.horizontal, side * 0.22)
                .frame(minWidth: side, minHeight: side)
                .background(Capsule().fill(Theme.yellow))
                .overlay(Capsule().strokeBorder(Theme.white, lineWidth: 2.5))
                .accessibilityLabel("up to \(count)")
        }
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
            .overlay(alignment: .bottomTrailing) { PTPropCountBadge(count: item.count, side: 46) }
            Text(item.title).font(Theme.displayFont(28)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
            if let sub = item.subtitle {
                Text(sub).font(Theme.uiFont(19, .medium)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)   // never truncated: the card grows
            }
            if let onHunt {
                // Round 26 (Haylee's button audit): icon only, a big green ✓ and an ✗.
                PTHuntButtons(size: 76, action: onHunt).padding(.top, Theme.Space.xs)
            }
        }
        .padding(Theme.Space.m)
        .frame(width: width)
        .ptPanel(radius: 30)
        .accessibilityElement(children: .contain)
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


// MARK: - Round 30: the chat panel's Props tab

/// The hunt's props as a live list in the chat panel's Props tab (Haylee, round 30): the current prop highlighted with
/// its big ✓ / ✗, found ones checked, swapped ones with the swap arrows, missing ones faded with their pretend
/// stand-in ("We'll pretend: the pirate map"). Updates as the props are checked off. Only the cards already shown are
/// listed (the hunt stays one prop at a time).
struct PTPropListPanel: View {
    let items: [PTStageItem]
    /// The prop being hunted now (its row is highlighted and gets the buttons).
    var currentID: String?
    var onHunt: ((Bool) -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            ForEach(items) { item in
                row(item, current: item.id == currentID && !item.isDone)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.vertical, Theme.Space.xs)
        .animation(Theme.stageMove, value: items.map { "\($0.id)\($0.chip)\($0.isPretend)\($0.flipKey)" })
    }

    private func row(_ item: PTStageItem, current: Bool) -> some View {
        VStack(spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.s) {
                Group {
                    if let image = item.image { Image(uiImage: image).resizable().scaledToFit() } else { PTShimmer(tint: item.tint) }
                }
                .frame(width: current ? 84 : 64, height: current ? 84 : 64)
                .saturation(item.isPretend ? 0 : 1).opacity(item.isPretend ? 0.5 : 1)
                .overlay(alignment: .bottomTrailing) {
                    if item.isDone || item.chip == .swapped { PTPropBadge(item: item, side: 26).offset(x: 4, y: 4) }
                    else { PTPropCountBadge(count: item.count, side: 30).offset(x: 4, y: 4) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(Theme.displayFont(current ? 22 : 19)).foregroundStyle(Theme.ink)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    if item.isPretend {
                        // The missing prop's pretend stand-in: what it would have become.
                        Label(item.subtitle.map { "We'll pretend: \($0)" } ?? "We'll pretend!", systemImage: "sparkles")
                            .font(Theme.uiFont(15, .medium)).foregroundStyle(Theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let sub = item.subtitle {
                        Text(sub).font(Theme.uiFont(15, .medium)).foregroundStyle(Theme.inkMuted)   // never truncated
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if current, let onHunt { PTHuntButtons(size: 64, action: onHunt) }
        }
        .padding(Theme.Space.s)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(current ? Theme.white : Theme.white.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(current ? Theme.yellow : Theme.line, lineWidth: current ? 4 : 1.5))
        .opacity(item.isPretend ? 0.9 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title + (item.isPretend ? ", we'll pretend" : (item.chip == .found ? ", found" : (current ? ", find it now" : ""))))
    }
}
