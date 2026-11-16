import SwiftUI
import NutmegCore

/// Round D1 (Haylee, design section 11, approved mockup states 3 and 4): the My games bookshelf screen. The same
/// stage, Nutmeg beside the shelf pointing at it, and Haylee's bookshelf art with the saved games standing on its
/// shelves: 3 per shelf, newest first, each with its name on a shelf-edge label. A full bookshelf (9 games) moves to
/// the next one with the yellow arrow or a swipe, with page dots. A back arrow top-left. Tap a card to replay it.
/// No delete here (Grown-ups, round D2). No cap.
struct ShelfView: View {
    let model: AppModel
    @State private var page = 0

    static let perShelf = 3
    static let perPage = 9

    private var pages: [[SavedGame]] {
        let g = model.shelfGames
        return stride(from: 0, to: max(g.count, 1), by: Self.perPage).map { Array(g[$0..<min($0 + Self.perPage, g.count)]) }
    }

    var body: some View {
        GeometryReader { geo in
            let full = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            let L = PTShelfLayout(full)
            ZStack(alignment: .topLeading) {
                PTStageBackdrop()
                // Nutmeg stands on the stage beside the shelf, pointing at it (the point pose points right).
                NutmegCharacter(state: .excited, forcedPose: .point, showsGround: true)
                    .frame(width: L.nutmeg.width, height: L.nutmeg.height)
                    .position(x: L.nutmeg.midX, y: L.nutmeg.midY)
                    .allowsHitTesting(false)
                // The bookshelf: one page of 9 games, swiped or arrowed through.
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, games in
                        PTBookshelf(games: games, size: L.shelf.size, cover: { model.cover(for: $0) },
                                    onTap: { model.tapSavedGame($0) })
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: L.shelf.width, height: L.shelf.height)
                .position(x: L.shelf.midX, y: L.shelf.midY)
                if pages.count > 1 {
                    PTPageDots(count: pages.count, current: page)
                        .position(x: L.shelf.midX, y: L.dotsY)
                    if page < pages.count - 1 {
                        PTShelfArrow(symbol: "arrow.right", label: "Next bookshelf") { withAnimation(Theme.stageMove) { page += 1 } }
                            .position(x: L.nextArrow.x, y: L.nextArrow.y)
                    }
                    if page > 0 {
                        PTShelfArrow(symbol: "arrow.left", label: "Previous bookshelf") { withAnimation(Theme.stageMove) { page -= 1 } }
                            .position(x: L.prevArrow.x, y: L.prevArrow.y)
                    }
                }
                PTIconButton(symbol: "arrow.left", label: "Back", fill: Theme.white, size: L.back.width) { model.closeShelf() }
                    .shadow(color: Theme.panelShadow, radius: 8, y: 2)
                    .position(x: L.back.midX, y: L.back.midY)
            }
            .frame(width: full.width, height: full.height)
            .offset(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top)
        }
        .onChange(of: model.shelfGames.count) { _, _ in page = min(page, max(0, pages.count - 1)) }
    }
}

/// Where everything sits on the shelf screen (measured from the approved mockup, state 3: 2296 × 1624).
struct PTShelfLayout {
    let shelf: CGRect, nutmeg: CGRect, back: CGRect
    let nextArrow: CGPoint, prevArrow: CGPoint, dotsY: CGFloat
    init(_ s: CGSize) {
        let curtain = PTCurtain.metrics(s)
        let floor = PTStage.floor(s)
        // The bookshelf art is 990 × 1131: ~79% of the screen tall, its top just under the valance.
        var h = s.height * 0.79
        var w = h * 990 / 1131
        let right = s.width - curtain.visible - 16
        let maxW = right - s.width * 0.36
        if w > maxW { w = maxW; h = w * 1131 / 990 }
        let top = max(curtain.valance + 8, floor.maxY - h + floor.height * 0.12)
        shelf = CGRect(x: right - w, y: top, width: w, height: h)
        // Nutmeg's 1178 × 1335 canvas: her feet on the floor left of the shelf.
        let nh = s.height * 0.46, nw = nh * 1178 / 1335
        let nx = max(curtain.visible * 0.6, shelf.minX - nw * 0.98)
        nutmeg = CGRect(x: nx, y: floor.midY + floor.height * 0.12 - nh, width: nw, height: nh)
        let b: CGFloat = 64
        back = CGRect(x: curtain.visible + 24, y: curtain.valance + 24, width: b, height: b)
        nextArrow = CGPoint(x: min(shelf.maxX + 52, s.width - 40), y: shelf.midY + h * 0.1)
        prevArrow = CGPoint(x: shelf.minX - 30, y: shelf.midY + h * 0.1)
        dotsY = min(shelf.maxY + 22, s.height - 20)
    }
}

/// The bookshelf art with up to 9 game cards standing on its 3 shelves (slots from bookshelf-slots.json).
struct PTBookshelf: View {
    let games: [SavedGame]
    let size: CGSize
    var cover: (SavedGame) -> UIImage?
    var onTap: (SavedGame) -> Void

    /// The shelves' openings, as fractions of the art (design/export/stage/bookshelf-slots.json).
    struct Slot { let x, y, width, height, shelfBackY, shelfFrontY: CGFloat }
    static let slots = [
        Slot(x: 0.1061, y: 0.2175, width: 0.7869, height: 0.1424, shelfBackY: 0.3351, shelfFrontY: 0.3599),
        Slot(x: 0.1061, y: 0.397, width: 0.7869, height: 0.1636, shelfBackY: 0.5287, shelfFrontY: 0.5606),
        Slot(x: 0.1061, y: 0.5977, width: 0.7869, height: 0.16, shelfBackY: 0.7188, shelfFrontY: 0.7577)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("bookshelf").resizable().frame(width: size.width, height: size.height).accessibilityHidden(true)
            ForEach(Array(games.enumerated()), id: \.element.id) { i, g in
                let r = Self.card(i, in: size)
                PTGameCard(game: g, cover: cover(g), size: r.card.size) { onTap(g) }
                    .position(x: r.card.midX, y: r.card.midY)
                PTShelfLabel(title: g.title, width: r.label.width, height: r.label.height)
                    .position(x: r.label.midX, y: r.label.midY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Card i's frame (it stands on its shelf, bottom between the board's back and front edges) and its label's
    /// (on the board's front edge), in the art's frame.
    static func card(_ i: Int, in size: CGSize) -> (card: CGRect, label: CGRect) {
        let slot = slots[min(i / ShelfView.perShelf, slots.count - 1)], col = i % ShelfView.perShelf
        let innerX = slot.x * size.width, innerW = slot.width * size.width
        let bottom = (slot.shelfBackY + slot.shelfFrontY) / 2 * size.height
        let top = (slot.y + 0.01) * size.height
        let h = bottom - top
        // Round 27: every card is the game's square cover, all the same size (the shortest shelf's opening).
        let shortest = slots.map { ($0.shelfBackY + $0.shelfFrontY) / 2 - ($0.y + 0.01) }.min() ?? 0.13
        let side = min(shortest * size.height, innerW * 0.29)
        let w = side
        let gap = (innerW - 3 * w) / 4
        let x = innerX + gap + CGFloat(col) * (w + gap)
        let card = CGRect(x: x, y: bottom - side, width: w, height: side)
        let lh = max(18, h * 0.2), lw = w + gap * 0.7
        let label = CGRect(x: card.midX - lw / 2, y: slot.shelfFrontY * size.height + size.height * 0.022 - lh / 2, width: lw, height: lh)
        return (card, label)
    }
}

/// One saved game standing on the shelf: a white-framed square picture card (round 27: its text-free cover; else its
/// color sign page; else its prop stickers on cream).
struct PTGameCard: View {
    let game: SavedGame
    let cover: UIImage?
    let size: CGSize
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: size.height * 0.1, style: .continuous).fill(Theme.cream)
                if let cover {
                    Image(uiImage: cover).resizable().scaledToFill()
                        .frame(width: size.width - 10, height: size.height - 10)
                        .clipShape(RoundedRectangle(cornerRadius: size.height * 0.08, style: .continuous))
                } else {
                    HStack(spacing: size.width * 0.03) {
                        ForEach(game.coverProps, id: \.self) { id in
                            if let img = UIImage(named: PropLibrary.asset(id)) {
                                Image(uiImage: img).resizable().scaledToFit().frame(maxWidth: size.width * 0.3, maxHeight: size.height * 0.62)
                            }
                        }
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .overlay(RoundedRectangle(cornerRadius: size.height * 0.1, style: .continuous).strokeBorder(Theme.white, lineWidth: 5))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(game.title)
        .accessibilityHint("Play it again")
    }
}

/// The name label on the shelf's front edge: a cream pill with dark text.
struct PTShelfLabel: View {
    let title: String
    let width: CGFloat, height: CGFloat
    var body: some View {
        Text(title)
            .font(Theme.headlineFont(height * 0.56)).foregroundStyle(Theme.ink)
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, height * 0.4)
            .frame(width: width, height: height)
            .background(Capsule().fill(Theme.cream))
            .overlay(Capsule().strokeBorder(Theme.creamShade, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

/// The yellow round arrow that moves to the next (or previous) bookshelf.
struct PTShelfArrow: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Theme.yellow))
                .background(Circle().fill(Theme.yellowShade).offset(y: Theme.depth))
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(label)
    }
}

/// Page dots under the bookshelf (the current one purple).
struct PTPageDots: View {
    let count: Int
    let current: Int
    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { i in
                Circle().fill(i == current ? Theme.purple : Theme.purple.opacity(0.25)).frame(width: 14, height: 14)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Bookshelf \(current + 1) of \(count)")
    }
}
