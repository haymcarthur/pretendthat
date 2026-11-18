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
    /// iPhone version (mockup screen 7): the tall phone bookshelf (bookshelf-iphone.svg), 2 games a shelf on 4
    /// shelves, Nutmeg sitting on top of it looking down at the games.
    @Environment(\.layoutMetrics) private var metrics

    static let perShelf = 3
    static let perPage = 9
    private var perPage: Int { metrics.isPhone ? PTBookshelf.phonePerPage : Self.perPage }

    private var pages: [[SavedGame]] {
        let g = model.shelfGames
        let n = perPage
        return stride(from: 0, to: max(g.count, 1), by: n).map { Array(g[$0..<min($0 + n, g.count)]) }
    }

    var body: some View {
        GeometryReader { geo in
            let full = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            let L = metrics.isPhone ? PTShelfLayout(phone: full, safe: geo.safeAreaInsets) : PTShelfLayout(full)
            ZStack(alignment: .topLeading) {
                PTStageBackdrop()
                if !metrics.isPhone {
                // Nutmeg stands on the stage beside the shelf, pointing at it (the point pose points right).
                NutmegCharacter(state: .excited, forcedPose: .point, showsGround: true)
                    .frame(width: L.nutmeg.width, height: L.nutmeg.height)
                    .position(x: L.nutmeg.midX, y: L.nutmeg.midY)
                    .allowsHitTesting(false)
                }
                // The bookshelf: one page of 9 games, swiped or arrowed through.
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, games in
                        PTBookshelf(games: games, size: L.shelf.size, phone: metrics.isPhone, cover: { model.cover(for: $0) },
                                    onTap: { model.tapSavedGame($0) })
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: L.shelf.width, height: L.shelf.height)
                .position(x: L.shelf.midX, y: L.shelf.midY)
                if metrics.isPhone {
                    // Phone (mockup screen 7): she sits on top of the bookshelf, legs dangling over its front edge,
                    // clipboard on her lap, looking down at the games. Home stage polish (Haylee, 2026-11-17): the
                    // mockup's perky-sit still (her real art, focus face), not the rig's knees-hugged nap sit.
                    Image("shelf-nutmeg-sit-perky").resizable().interpolation(.high)
                        .frame(width: L.nutmeg.width, height: L.nutmeg.height)
                        .accessibilityHidden(true)
                        .position(x: L.nutmeg.midX, y: L.nutmeg.midY)
                        .allowsHitTesting(false)
                }
                if pages.count > 1 {
                    PTPageDots(count: pages.count, current: page)
                        .position(x: L.shelf.midX, y: L.dotsY)
                    if page < pages.count - 1 {
                        PTShelfArrow(symbol: "arrow.right", label: "Next bookshelf", size: L.arrowSize) { withAnimation(Theme.stageMove) { page += 1 } }
                            .position(x: L.nextArrow.x, y: L.nextArrow.y)
                    }
                    if page > 0 {
                        PTShelfArrow(symbol: "arrow.left", label: "Previous bookshelf", size: L.arrowSize) { withAnimation(Theme.stageMove) { page -= 1 } }
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
    /// The yellow arrows' size (smaller on the phone, beside the dots, so the shelf can be bigger).
    var arrowSize: CGFloat = 76
    /// iPhone version (mockup screen 7): the tall phone bookshelf centered under Nutmeg (sitting on its top), the back
    /// arrow top-left under the valance, the dots under it and the yellow arrow bottom-right.
    init(phone s: CGSize, safe: EdgeInsets) {
        let curtain = PTCurtain.metrics(s)
        let art = CGSize(width: 689, height: 1446)
        let top = max(curtain.valance, safe.top) + 8
        let back: CGFloat = 52
        self.back = CGRect(x: max(16, curtain.visible * 0.25), y: top, width: back, height: back)
        // Room: her sitting picture above the shelf, the dots + arrow row below it.
        // 2026-11-18 (Haylee: "make the bookshelf a little bigger so the images can be bigger on mobile"): she is a bit
        // smaller and the shelf uses nearly the whole width.
        let nutH: CGFloat = min(158, s.height * 0.18)
        // The perky sit's seat (the shelf's top edge) is 82.4% down her 1178 × 1335 canvas (mockup screen 7: canvas top
        // 88.5, shelf top 226, canvas 166.9 tall); her ear tips are ~2% down, so the shelf top sits 80% of her height
        // under the top row. Below the seat her legs hang in front of the shelf's crown.
        let seat: CGFloat = 0.824
        let bottomRoom = max(safe.bottom, 12) + 46   // the dots row, with smaller arrows beside the dots
        let maxH = s.height - top - nutH * (seat - 0.024) - bottomRoom
        var w = min(s.width - 16, 440)
        var h = w * art.height / art.width
        if h > maxH { h = maxH; w = h * art.width / art.height }
        let shelfTop = top + nutH * (seat - 0.024)
        shelf = CGRect(x: (s.width - w) / 2, y: shelfTop, width: w, height: h)
        // Centered on the shelf (as in the mockup), her seat on its top edge.
        let nw = nutH * 1178 / 1335
        nutmeg = CGRect(x: s.width / 2 - nw / 2, y: shelfTop - nutH * seat, width: nw, height: nutH)
        dotsY = shelf.maxY + 24
        nextArrow = CGPoint(x: min(shelf.maxX - 20, s.width - 36), y: shelf.maxY + 24)
        prevArrow = CGPoint(x: max(shelf.minX + 20, 36), y: shelf.maxY + 24)
        arrowSize = 52
    }

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
    /// iPhone version: the phone art (bookshelf-iphone.svg + bookshelf-iphone-slots.json), 4 shelves of 2.
    var phone = false
    var cover: (SavedGame) -> UIImage?
    var onTap: (SavedGame) -> Void

    /// The shelves' openings, as fractions of the art (design/export/stage/bookshelf-slots.json).
    struct Slot { let x, y, width, height, shelfBackY, shelfFrontY: CGFloat }
    static let slots = [
        Slot(x: 0.1061, y: 0.2175, width: 0.7869, height: 0.1424, shelfBackY: 0.3351, shelfFrontY: 0.3599),
        Slot(x: 0.1061, y: 0.397, width: 0.7869, height: 0.1636, shelfBackY: 0.5287, shelfFrontY: 0.5606),
        Slot(x: 0.1061, y: 0.5977, width: 0.7869, height: 0.16, shelfBackY: 0.7188, shelfFrontY: 0.7577)
    ]

    /// The phone shelf's 4 compartments (design/export/stage/bookshelf-iphone-slots.json).
    static let phoneSlots = [
        Slot(x: 0.1335, y: 0.1535, width: 0.7344, height: 0.1238, shelfBackY: 0.258, shelfFrontY: 0.2773),
        Slot(x: 0.1335, y: 0.3043, width: 0.7344, height: 0.139, shelfBackY: 0.4219, shelfFrontY: 0.4433),
        Slot(x: 0.1335, y: 0.4703, width: 0.7344, height: 0.1425, shelfBackY: 0.5913, shelfFrontY: 0.6127),
        Slot(x: 0.1335, y: 0.6404, width: 0.7344, height: 0.1452, shelfBackY: 0.76, shelfFrontY: 0.7856)
    ]
    static let phonePerShelf = 2
    static let phonePerPage = 8

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(phone ? "bookshelf-iphone" : "bookshelf").resizable().frame(width: size.width, height: size.height).accessibilityHidden(true)
            ForEach(Array(games.enumerated()), id: \.element.id) { i, g in
                let r = phone ? Self.phoneCard(i, in: size) : Self.card(i, in: size)
                PTGameCard(game: g, cover: cover(g), size: r.card.size) { onTap(g) }
                    .position(x: r.card.midX, y: r.card.midY)
                // 2026-11-18 (Haylee): always the SHORT title (an older game's long title is cut, never rewritten).
                PTShelfLabel(title: GameTitles.shelf(g.title), width: r.label.width, height: r.label.height)
                    .position(x: r.label.midX, y: r.label.midY)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// iPhone: card i on the phone shelf (2 a shelf, the same rules as `card`: they stand on the board and fill the
    /// compartment; the name label on the board's front face).
    static func phoneCard(_ i: Int, in size: CGSize) -> (card: CGRect, label: CGRect) {
        let slot = phoneSlots[min(i / phonePerShelf, phoneSlots.count - 1)], col = i % phonePerShelf
        let innerX = slot.x * size.width, innerW = slot.width * size.width
        let bottom = (slot.shelfBackY + slot.shelfFrontY) / 2 * size.height
        let shortest = phoneSlots.map { $0.shelfFrontY - $0.y }.min() ?? 0.12
        let side = min(shortest * 0.9 * size.height, bottom - slot.y * size.height)
        let gap = innerW * 0.05
        let w = (innerW - 3 * gap) / 2
        let x = innerX + gap + CGFloat(col) * (w + gap)
        let card = CGRect(x: x, y: bottom - side, width: w, height: side)
        // The board's front face (shelfFrontY → boardFaceBottomY ≈ +0.027 of the art) holds the label.
        // 2026-11-18: a bigger label for the short titles (nice and big, one line).
        let lh = max(22, size.height * 0.032), lw = w + gap * 1.5
        let label = CGRect(x: card.midX - lw / 2, y: (slot.shelfFrontY + 0.0135) * size.height - lh / 2, width: lw, height: lh)
        return (card, label)
    }

    /// Card i's frame (it stands on its shelf, bottom between the board's back and front edges) and its label's
    /// (on the board's front edge), in the art's frame.
    static func card(_ i: Int, in size: CGSize) -> (card: CGRect, label: CGRect) {
        let slot = slots[min(i / ShelfView.perShelf, slots.count - 1)], col = i % ShelfView.perShelf
        let innerX = slot.x * size.width, innerW = slot.width * size.width
        // Stand on the board: the card's bottom halfway between the board's back and front edges.
        let bottom = (slot.shelfBackY + slot.shelfFrontY) / 2 * size.height
        let h = (slot.shelfFrontY - slot.y) * size.height
        // Shelf fix (Haylee, "make them bigger", mockup states 3–4): the 3 cards FILL the compartment. Height: 90% of
        // the shortest compartment's opening (top of the opening to the board's front edge), the same on every shelf;
        // width: 3 cards with 4 even gaps across the opening. The square cover fills the card (centre-cropped).
        let shortest = slots.map { $0.shelfFrontY - $0.y }.min() ?? 0.14
        let side = min(shortest * 0.9 * size.height, bottom - slot.y * size.height)
        let gap = innerW * 0.035
        let w = (innerW - 4 * gap) / 3
        let x = innerX + gap + CGFloat(col) * (w + gap)
        let card = CGRect(x: x, y: bottom - side, width: w, height: side)
        let lh = max(18, h * 0.2), lw = w + gap * 0.5
        let label = CGRect(x: card.midX - lw / 2, y: slot.shelfFrontY * size.height + size.height * 0.022 - lh / 2, width: lw, height: lh)
        return (card, label)
    }
}

/// One saved game standing on the shelf: a white-framed picture card filling its third of the compartment (round 27:
/// its text-free wide 3:2 cover, aspect-filling the card with almost no crop; else its color sign page; else its prop stickers on cream).
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
        .accessibilityIdentifier("shelf.game")
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
    var size: CGFloat = 76
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size * 0.4, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
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
