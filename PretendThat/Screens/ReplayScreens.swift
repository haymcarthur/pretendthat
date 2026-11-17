import SwiftUI
import NutmegCore

// Round D1 (Haylee, design §D5): a replay's Pick and Props steps, in the same card zone as a first play's screens. No AI
// calls for content. Round 26 (Haylee's button audit): a replay reuses the FIRST-PLAY flows. Pick: the count is said
// out loud ("How many friends are playing this time? Tell me!"); number tiles only when there's no voice session (the
// fallback, so it can't dead-end). Props: one saved card at a time with the hunt card's ✓ / ✗. Print is the first
// play's KitView (printer + ▶).

/// Pick on a replay: the game's title; with no voice session, tiles 1–6 (a tile goes straight on to Props).
struct ReplayPickView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            // Round 28 (Haylee): the game's wide cover (round 27), framed on the stage where the title was; else its
            // color sign page (`AppModel.cover(for:)` falls back); the title text only when there's no picture at all.
            // Nutmeg still says the name.
            if let g = model.replayGame, let cover = model.cover(for: g) {
                PTReplayCover(image: cover, title: store.currentTitle)
            } else {
                PTText(store.currentTitle, .title).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
            }
            if model.noVoiceSession {
                // Two rows of three (six in a row reached Nutmeg's face in the card zone).
                VStack(spacing: Theme.Space.s) {
                    ForEach([1, 4], id: \.self) { first in
                        HStack(spacing: Theme.Space.s) {
                            ForEach(first..<(first + 3), id: \.self) { n in
                                PTChoiceTile(label: "\(n)", isSelected: store.playerCount == n, size: 92) { model.replayPick(n) }
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(Theme.springy, value: model.noVoiceSession)
    }
}

/// Round 28: the saved game's cover on the replay's Pick: a 3:2 picture in a white mat with a soft edge, like a
/// framed poster on the stage.
struct PTReplayCover: View {
    let image: UIImage
    let title: String
    var width: CGFloat = 360
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image(uiImage: image).resizable().scaledToFill()
            .frame(width: width, height: width * 2 / 3)
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius))
            .padding(10)
            .background(RoundedRectangle(cornerRadius: Theme.smallRadius + 8).fill(Theme.white))
            .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius + 8).strokeBorder(Theme.line, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: Theme.smallRadius + 8).fill(Theme.shadow.color).offset(y: Theme.cardDepth))
            .scaleEffect(shown || reduceMotion ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(reduceMotion ? Theme.stageMoveReduced : Theme.springy) { shown = true } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }
}

/// Props on a replay: the first play's hunt card, one saved prop at a time, with its big ✓ / ✗ (✗ offers the saved
/// alternate first, then pretends). The answered props sit above it as small round thumbnails.
struct ReplayPropsView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }

    private func item(_ p: Prop, index: Int, hunting: Bool) -> PTStageItem {
        let art = p.libraryID.flatMap { UIImage(named: PropLibrary.asset($0)) }
        return PTStageItem(id: "prop-\(p.id)", title: p.householdItem, subtitle: p.becomes, image: art,
                           tint: Theme.playerColor(index), flipKey: p.libraryID ?? p.householdItem, isPretend: p.isSkipped,
                           chip: p.isSkipped ? .pretend : (store.foundProps.contains(p.id) ? .found : (p.swapped == true ? .swapped : .none)),
                           huntButtons: hunting)
    }

    var body: some View {
        let props = store.props?.props ?? []
        VStack(spacing: Theme.Space.m) {
            let done = props.enumerated().filter { store.foundProps.contains($0.element.id) || $0.element.isSkipped }
            if !done.isEmpty {
                HStack(spacing: 10) {
                    ForEach(done, id: \.element.id) { i, p in PTPropDoneThumb(item: item(p, index: i, hunting: false)) }
                }
                .transition(.opacity)
            }
            if let cur = store.replayCurrentProp, let i = props.firstIndex(where: { $0.id == cur.id }) {
                PTPropActiveCard(item: item(cur, index: i, hunting: true), width: 340) { model.replayHunt(found: $0) }
                    .id(cur.id + (cur.libraryID ?? ""))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(Theme.stageMove, value: store.replayCurrentProp?.id)
        .animation(Theme.stageMove, value: store.replayCurrentProp?.libraryID)
    }
}
