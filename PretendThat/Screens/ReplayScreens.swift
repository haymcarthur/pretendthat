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
    /// Round 30: narrower in the chat panel's cover tab.
    var coverWidth: CGFloat = 360
    /// Round 40 (Haylee: the cover was cut off at the bottom on the iPhone): the room the card zone has; the cover
    /// shrinks to fit it whole (with the number tiles under it when they show).
    var maxHeight: CGFloat = .infinity
    private var store: AdventureStore { model.store }
    /// Two rows of 92 pt tiles, their gap, and the gap above them.
    private static let tilesHeight: CGFloat = 2 * 92 + Theme.Space.s + Theme.Space.l
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            // Round 28 (Haylee): the game's wide cover (round 27), framed on the stage where the title was; else its
            // color sign page (`AppModel.cover(for:)` falls back); the title text only when there's no picture at all.
            // Nutmeg still says the name.
            if let g = model.replayGame, let cover = model.cover(for: g) {
                let room = maxHeight - (model.noVoiceSession ? Self.tilesHeight : 0) - PTReplayCover.matExtra
                PTReplayCover(image: cover, title: store.currentTitle,
                              width: max(120, min(coverWidth, room / PTReplayCover.aspect(cover).height * PTReplayCover.aspect(cover).width)))
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
    /// The mat (10 pt each side) and the card's depth edge below the picture.
    static let matExtra: CGFloat = 20 + Theme.cardDepth
    /// Round 40: the frame takes the picture's own shape (a 3:2 cover, a 4:3 sign page…), clamped to 1:1 … 2:1, and
    /// the whole picture shows (fit, never cropped).
    static func aspect(_ image: UIImage) -> CGSize {
        let w = max(image.size.width, 1), h = max(image.size.height, 1)
        let r = min(2, max(1, w / h))
        return CGSize(width: r, height: 1)
    }
    var body: some View {
        let a = Self.aspect(image)
        Image(uiImage: image).resizable().scaledToFit()
            .frame(width: width, height: width * a.height / a.width)
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
