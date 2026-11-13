import SwiftUI
import NutmegCore

/// One printable US Letter page (612×792 pt): black line art on white, dashed cut lines, names written by the app.
struct KitPageView: View {
    let page: KitPage
    let tokens: NameTokens
    var art: UIImage? = nil

    static let size = CGSize(width: 612, height: 792)
    private let margin: CGFloat = 24

    var body: some View {
        let grid = KitLayout.grid(for: page.item.size)
        let cellW = (Self.size.width - margin * 2) / CGFloat(grid.columns)
        let cellH = (Self.size.height - margin * 2) / CGFloat(grid.rows)
        ZStack(alignment: .topLeading) {
            Theme.printPaper
            ForEach(Array(page.slots.enumerated()), id: \.offset) { i, slot in
                KitCardView(item: page.item, slot: slot, tokens: tokens, art: art, fullPage: page.item.size == .fullPage)
                    .padding(grid.capacity == 1 ? 0 : 8)
                    .frame(width: cellW, height: cellH)
                    .overlay(Rectangle().strokeBorder(Theme.printInk.opacity(grid.capacity == 1 ? 0 : 0.6),
                                                      style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
                    .offset(x: margin + CGFloat(i % grid.columns) * cellW, y: margin + CGFloat(i / grid.columns) * cellH)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .light)
    }
}

/// A single card (or full sheet). AI art when available, otherwise app-drawn outline art.
struct KitCardView: View {
    let item: KitItem
    let slot: KitSlot
    let tokens: NameTokens
    var art: UIImage?
    var fullPage = false

    private var name: String? { slot.player.map { tokens.untokenize($0.placeholder) } }

    private func fill(_ line: String) -> String {
        guard let name else { return line.replacingOccurrences(of: #"\{P[1-4]\}"#, with: "______", options: .regularExpression) }
        return tokens.untokenize(line.replacingOccurrences(of: #"\{P[1-4]\}"#, with: name, options: .regularExpression))
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .top) {
                if let art {
                    Image(uiImage: art).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: h).clipped()
                    if !fullPage { nameBanner(height: h * 0.2).padding(.top, h * 0.04) }
                } else {
                    drawn(height: h)
                }
            }
            .frame(width: geo.size.width, height: h)
            .clipShape(RoundedRectangle(cornerRadius: fullPage ? 0 : 14))
            .overlay(RoundedRectangle(cornerRadius: fullPage ? 0 : 14).strokeBorder(Theme.printInk, lineWidth: fullPage ? 0 : 2))
        }
    }

    private func nameBanner(height: CGFloat) -> some View {
        Text(name ?? "Name: ________")
            .font(Theme.printFont(height * 0.55)).minimumScaleFactor(0.4).lineLimit(1)
            .foregroundStyle(Theme.printInk)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(Capsule().fill(Theme.printPaper))
            .overlay(Capsule().strokeBorder(Theme.printInk, lineWidth: 2))
    }

    @ViewBuilder
    private func drawn(height h: CGFloat) -> some View {
        let big = fullPage ? 3.0 : 1.0
        VStack(spacing: h * 0.03) {
            HStack(spacing: 8) {
                Image(systemName: item.symbol).font(.system(size: h * 0.16 / big, weight: .regular)).foregroundStyle(Theme.printInk)
                Text(item.title).font(Theme.printFont(h * 0.11 / big)).foregroundStyle(Theme.printInk).lineLimit(1).minimumScaleFactor(0.5)
                if item.colorMe { Image(systemName: "star").font(.system(size: h * 0.1 / big)).foregroundStyle(Theme.printInk) }
            }
            if !fullPage { nameBanner(height: h * 0.16) }
            ForEach(Array((fullPage ? item.lines : KitLayout.printedLines(for: item)).enumerated()), id: \.offset) { _, line in
                Text(fill(line)).font(Theme.printFont(h * 0.075 / (fullPage ? 1.8 : 1))).foregroundStyle(Theme.printInk)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            if let n = KitLayout.bigNumber(for: item, slot: slot) {
                Text(n).font(Theme.printFont(h * 0.2 / big)).foregroundStyle(Theme.printInk)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.printInk, lineWidth: 3))
            }
            if fullPage {
                Spacer()
                Image(systemName: item.symbol).font(.system(size: h * 0.3, weight: .ultraLight)).foregroundStyle(Theme.printInk)
                Spacer()
            }
        }
        .padding(fullPage ? 40 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.printPaper)
    }
}
