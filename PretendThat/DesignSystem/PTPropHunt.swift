import SwiftUI

// Prop hunt layout (prop-gathering-flow.md, Haylee): one prop at a time. The ACTIVE prop is one big card on the left
// (big art, bold name, the full "becomes" line, and the two backup buttons inside it); found or pretend props shrink
// and fly to a column of small DONE chips on the right. Nutmeg stands right of center at a medium shot between them.

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
                    .multilineTextAlignment(.center).lineLimit(2).fixedSize(horizontal: false, vertical: true)
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
        huntButton("Found it!", symbol: "checkmark", fill: Theme.lime, edge: Theme.limeShade) { onHunt(true) }
        huntButton("Don't have it", symbol: "xmark", fill: Theme.white, edge: Theme.line) { onHunt(false) }
    }

    private func huntButton(_ title: String, symbol: String, fill: Color, edge: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 17, weight: .heavy))
                Text(title).lineLimit(1).fixedSize()
            }
            .font(Theme.uiFont(18)).foregroundStyle(Theme.ink)
            .padding(.horizontal, Theme.Space.m)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(edge, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// A small chip for a prop that's done: thumbnail, name and a badge (found check, swap arrows, or faded "pretend").
struct PTPropDoneChip: View {
    let item: PTStageItem
    var width: CGFloat = 180

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Group {
                if let image = item.image { Image(uiImage: image).resizable().scaledToFit() } else { PTShimmer(tint: item.tint) }
            }
            .frame(width: 44, height: 44)
            .saturation(item.isPretend ? 0 : 1).opacity(item.isPretend ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(Theme.uiFont(15)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                if item.isPretend {
                    Text("We'll pretend").font(Theme.uiFont(12, .medium)).foregroundStyle(Theme.inkMuted).lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            Spacer(minLength: 0)
            badge
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: width)
        .ptPanel(radius: 18)
        .opacity(item.isPretend ? 0.85 : 1)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var badge: some View {
        let (symbol, fill): (String, Color) = item.isPretend ? ("sparkles", Theme.chipGray)
            : (item.chip == .swapped ? ("arrow.triangle.2.circlepath", Theme.yellow) : ("checkmark", Theme.lime))
        Image(systemName: symbol).font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.ink)
            .frame(width: 26, height: 26).background(Circle().fill(fill))
    }
}

extension PTStageItem {
    /// Done in the hunt: found, or skipped (we'll pretend).
    var isDone: Bool { chip == .found || isPretend }
}
