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

/// Where the round-39 overlays sit on the stage: in the card zone, never over Nutmeg (iPad landscape: the right side;
/// iPad portrait and iPhone: the lower part, below her).
struct PTStageCardZone {
    /// `low`: the conversation close-up on iPhone (she fills the screen), so the card sits lower, under her chin.
    static func center(in size: CGSize, isPhone: Bool, low: Bool = false) -> CGPoint {
        if isPhone { return CGPoint(x: size.width / 2, y: size.height * (low ? 0.76 : 0.6)) }
        if size.width > size.height { return CGPoint(x: size.width * 0.75, y: size.height * 0.56) }
        return CGPoint(x: size.width / 2, y: size.height * 0.74)
    }
}

/// "We already have <title> saved! Want to play that one?" Two big picture buttons: the saved game's card
/// with a green ▶ (play that one) and the yellow sparkles (make a new one). No words on it; Nutmeg says the question.
/// It never blocks: the leave X still works, and the sparkles carry on with the new game.
struct PTSoundsLikeCard: View {
    let game: SavedGame
    let cover: UIImage?
    let onReplay: () -> Void
    let onNew: () -> Void
    @Environment(\.layoutMetrics) private var metrics
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let cardW: CGFloat = metrics.isPhone ? min(210, geo.size.width * 0.5) : 260
            let card = CGSize(width: cardW, height: cardW * 2 / 3)
            let newSize: CGFloat = metrics.isPhone ? 96 : 120
            HStack(alignment: .center, spacing: metrics.isPhone ? Theme.Space.m : Theme.Space.xl) {
                Button(action: onReplay) {
                    ZStack(alignment: .bottomTrailing) {
                        PTCoverPicture(cover: cover, props: game.coverProps, size: card)
                        Image(systemName: "play.fill")
                            .font(.system(size: card.height * 0.2, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .offset(x: card.height * 0.012)
                            .frame(width: card.height * 0.42, height: card.height * 0.42)
                            .background(Circle().fill(Theme.lime))
                            .background(Circle().fill(Theme.limeShade).offset(y: Theme.depth))
                            .offset(x: card.height * 0.12, y: card.height * 0.12)
                    }
                }
                .buttonStyle(TileButtonStyle())
                .accessibilityLabel("Play \(game.title)")
                .accessibilityIdentifier("soundsLike.replay")
                PTBigIconButton(kind: .fresh, size: newSize, label: "Make a new game", action: onNew)
                    .accessibilityIdentifier("soundsLike.new")
            }
            .padding(.horizontal, Theme.Space.l).padding(.vertical, Theme.Space.l)
            .ptPanel(radius: 32)
            .scaleEffect(shown ? 1 : 0.85)
            .opacity(shown ? 1 : 0)
            .position(PTStageCardZone.center(in: geo.size, isPhone: metrics.isPhone, low: true))
        }
        .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { shown = true } }
    }
}
