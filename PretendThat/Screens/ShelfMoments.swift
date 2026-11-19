import SwiftUI
import NutmegCore

// Round 39 (Haylee, auto-save): the "sounds like a game you have" card at the Pick confirm and the little shelf in the
// leave dialog (round 41: the kit-time bookshelf moment was removed). Pictures only on the kid side (kids can't read).

/// A game's card picture (the shelf look without the button): its cover, else its prop stickers on cream.
struct PTCoverPicture: View {
    let cover: UIImage?
    let props: [String]
    let size: CGSize
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.height * 0.1, style: .continuous).fill(Theme.cream)
            if let cover {
                Image(uiImage: cover).resizable().scaledToFill()
                    .frame(width: max(size.width - 10, 1), height: max(size.height - 10, 1))
                    .clipShape(RoundedRectangle(cornerRadius: size.height * 0.08, style: .continuous))
            } else {
                HStack(spacing: size.width * 0.03) {
                    ForEach(props, id: \.self) { id in
                        if let img = UIImage(named: PropLibrary.asset(id)) {
                            Image(uiImage: img).resizable().scaledToFit().frame(maxWidth: size.width * 0.3, maxHeight: size.height * 0.62)
                        }
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(RoundedRectangle(cornerRadius: size.height * 0.1, style: .continuous).strokeBorder(Theme.white, lineWidth: max(2, size.height * 0.04)))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .accessibilityHidden(true)
    }
}

/// The game's cover card shrinks and slides onto a small bookshelf, which pops (the bookshelf art, no words).
/// `shelfHeight` sizes the shelf; `delay` = how long the big card shows before it moves (0 in the leave dialog).
struct PTShelfMomentView: View {
    let cover: UIImage?
    let props: [String]
    var shelfHeight: CGFloat = 220
    var delay: Double = 0.6
    var bigCardWidth: CGFloat = 280
    @State private var shown = false
    @State private var landed = false
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shelfSize: CGSize { CGSize(width: shelfHeight * 990 / 1131, height: shelfHeight) }
    private var slot: CGRect { PTBookshelf.card(4, in: shelfSize).card }   // the middle shelf, middle spot
    private var bigCard: CGSize { CGSize(width: bigCardWidth, height: bigCardWidth * 2 / 3) }
    /// The whole view: the big card above the shelf.
    private var frameSize: CGSize { CGSize(width: max(shelfSize.width, bigCard.width) + 40, height: shelfSize.height + bigCard.height + 30) }

    var body: some View {
        let shelfOrigin = CGPoint(x: (frameSize.width - shelfSize.width) / 2, y: frameSize.height - shelfSize.height)
        let target = CGPoint(x: shelfOrigin.x + slot.midX, y: shelfOrigin.y + slot.midY)
        let start = CGPoint(x: frameSize.width / 2, y: bigCard.height / 2 + 6)
        ZStack(alignment: .topLeading) {
            Image("bookshelf").resizable().frame(width: shelfSize.width, height: shelfSize.height)
                .scaleEffect(pop ? 1.1 : 1, anchor: .bottom)
                .position(x: shelfOrigin.x + shelfSize.width / 2, y: shelfOrigin.y + shelfSize.height / 2)
            PTCoverPicture(cover: cover, props: props, size: landed ? slot.size : bigCard)
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .position(landed ? target : start)
                .scaleEffect(pop ? 1.1 : 1, anchor: .bottom)
            if pop {
                ForEach(0..<3, id: \.self) { i in
                    Image("stage-star").resizable().scaledToFit().frame(width: 30, height: 30)
                        .rotationEffect(.degrees(Double(i - 1) * 18))
                        .position(x: target.x + CGFloat(i - 1) * slot.width * 0.9, y: shelfOrigin.y + slot.minY - 18 - (i == 1 ? 12 : 0))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("The game goes onto your bookshelf")
        .task {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.7)) { shown = true }
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .easeInOut(duration: 0.6)) { landed = true }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 650))
            withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) { pop = true }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pop = false }
        }
    }
}

/// "We already have <title> saved! Do you want to play that one, or make a new game?" (2026-11-18, Haylee: "All I
/// wanted is the picture. No buttons."). Only the saved game's cover picture, just above the control bar (never over
/// the mic, Repeat or chat buttons): no card behind it, no ▶, no title, no "New game" button, no words. Nutmeg asks out
/// loud; the kids answer by voice or typing (`SavedOrNew`). Claude's call: tapping the picture itself still plays the
/// saved game, a quiet shortcut with nothing that looks like a button.
struct PTSoundsLikeOffer: View {
    let game: SavedGame
    let cover: UIImage?
    let onReplay: () -> Void
    @Environment(\.layoutMetrics) private var metrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let w: CGFloat = metrics.isPhone ? 240 : 340
        let size = CGSize(width: w, height: w * 2 / 3)
        let shape = RoundedRectangle(cornerRadius: size.height * 0.1, style: .continuous)
        Button(action: onReplay) {
            ZStack {
                shape.fill(Theme.cream)
                if let cover {
                    Image(uiImage: cover).resizable().scaledToFill()
                        .frame(width: size.width, height: size.height)
                } else {
                    // No cover drawn for that game: its props, like its spot on the bookshelf.
                    HStack(spacing: size.width * 0.03) {
                        ForEach(game.coverProps, id: \.self) { id in
                            if let img = UIImage(named: PropLibrary.asset(id)) {
                                Image(uiImage: img).resizable().scaledToFit()
                                    .frame(maxWidth: size.width * 0.3, maxHeight: size.height * 0.62)
                            }
                        }
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .contentShape(shape)
            .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
            .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel("Play \(game.title)")
        .accessibilityIdentifier("soundsLike.replay")
        .scaleEffect(shown ? 1 : 0.9, anchor: .bottom)
        .opacity(shown ? 1 : 0)
        .onAppear { withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.75)) { shown = true } }
    }
}

