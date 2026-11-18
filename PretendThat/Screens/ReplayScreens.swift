import SwiftUI
import NutmegCore

// Round D1 (Haylee, design §D5): a replay's Pick and Props steps, in the same card zone as a first play's screens. No AI
// calls for content. Round 26 (Haylee's button audit): a replay reuses the FIRST-PLAY flows. Pick: the count is said
// out loud ("How many friends are playing this time? Tell me!"). 2026-11-17 (Haylee): no number tiles, ever. With no
// voice session the kid types or speaks the count (keyboard and mic in the pill; on-device speech works offline) and
// the app reads it on the device (`ReplayCount`, `AppModel.replayCountAnswer`). Props: one saved card at a time with
// the hunt card's ✓ / ✗. Print is the first play's KitView (printer + ▶).

/// Pick on a replay: the game's cover (or title). The count is answered by voice or typing, never by tiles.
struct ReplayPickView: View {
    let model: AppModel
    /// Round 30: narrower in the chat panel's cover tab.
    var coverWidth: CGFloat = 360
    /// Round 40 (Haylee: the cover was cut off at the bottom on the iPhone): the room the card zone has; the cover
    /// shrinks to fit it whole.
    var maxHeight: CGFloat = .infinity
    private var store: AdventureStore { model.store }
    var body: some View {
        // Round 28 (Haylee): the game's wide cover (round 27), framed on the stage where the title was; else its
        // color sign page (`AppModel.cover(for:)` falls back); the title text only when there's no picture at all.
        // Nutmeg still says the name.
        if let g = model.replayGame, let cover = model.cover(for: g) {
            let room = maxHeight - PTReplayCover.matExtra
            PTReplayCover(image: cover, title: store.currentTitle,
                          width: max(120, min(coverWidth, room / PTReplayCover.aspect(cover).height * PTReplayCover.aspect(cover).width)))
        } else {
            PTText(store.currentTitle, .title).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
        }
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
