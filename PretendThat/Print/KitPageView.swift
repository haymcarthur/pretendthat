import SwiftUI
import NutmegCore

/// One printable US Letter page (612×792 pt): black line art on white, dashed cut lines. Cards print a blank
/// "Name: ________" line for kids to write on, and badges their role title (we never ask for names).
struct KitPageView: View {
    let page: KitPage
    var art: UIImage? = nil
    /// Cut-outs page: one image per cut-out (checklist-pictures.md), tiled 2×4 under the title.
    var cutouts: [UIImage?] = []
    /// Round 45: the set this page is printed in (the color set tints the app-drawn frames; the outline set doesn't).
    var style: PrintStyle = .colorIn

    static let size = CGSize(width: 612, height: 792)
    private let margin: CGFloat = 24

    @ViewBuilder var body: some View {
        if page.item.pictureOnly {
            // Round 45: a library printable: picture-only art, every frame and word drawn by the app beside it.
            LibraryPageView(page: page, art: art, pictures: cutouts, style: style)
        } else if page.item.recipe == .cutouts, cutouts.contains(where: { $0 != nil }) {
            cutoutSheet
        } else {
            cards
        }
    }

    /// Title, then each cut-out in its own cell (dashed cut lines), like tickets.
    private var cutoutSheet: some View {
        let labels = KitLayout.printedLines(for: page.item)
        let cols = 2, rows = max(1, Int(ceil(Double(cutouts.count) / 2)))
        let top: CGFloat = 96
        let cellW = (Self.size.width - margin * 2) / CGFloat(cols)
        let cellH = (Self.size.height - margin - top) / CGFloat(rows)
        return ZStack(alignment: .topLeading) {
            Theme.printPaper
            Text(page.item.title).font(Theme.printFont(40)).foregroundStyle(Theme.printInk)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: Self.size.width - margin * 2, height: top - margin)
                .offset(x: margin, y: margin)
            ForEach(Array(cutouts.enumerated()), id: \.offset) { i, img in
                Group {
                    if let img { Image(uiImage: img).resizable().scaledToFit().blendMode(.multiply).padding(10) }
                    else { Text(labels.indices.contains(i) ? labels[i] : "").font(Theme.printFont(22)).foregroundStyle(Theme.printInk) }
                }
                .frame(width: cellW, height: cellH)
                .overlay(Rectangle().strokeBorder(Theme.printInk.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
                .offset(x: margin + CGFloat(i % cols) * cellW, y: top + CGFloat(i / cols) * cellH)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .light)
    }

    /// Round C1: a badge prints its role's slice of the 6-up badge sheet (the shared badge image if there's none).
    private func slotArt(_ slot: KitSlot) -> UIImage? {
        guard page.item.recipe == .badges, let k = slot.roleID?.index, cutouts.indices.contains(k), let slice = cutouts[k] else { return art }
        return slice
    }

    private var cards: some View {
        let grid = KitLayout.grid(for: page.item.size)
        let cellW = (Self.size.width - margin * 2) / CGFloat(grid.columns)
        let cellH = (Self.size.height - margin * 2) / CGFloat(grid.rows)
        return ZStack(alignment: .topLeading) {
            Theme.printPaper
            ForEach(Array(page.slots.enumerated()), id: \.offset) { i, slot in
                KitCardView(item: page.item, slot: slot, art: slotArt(slot), fullPage: page.item.size == .fullPage)
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
    var art: UIImage?
    var fullPage = false

    /// Any stray placeholder from older JSON prints as a blank line.
    private func fill(_ line: String) -> String {
        line.replacingOccurrences(of: #"\{[PR][1-4]\}"#, with: "______", options: .regularExpression)
    }

    /// Play money never gets a name field (Haylee fix round 1); full sheets don't either.
    private var showsName: Bool { !fullPage && item.recipe != .money && !(item.recipe == nil && item.size == .bill) }

    var body: some View {
        GeometryReader { geo in
            if let art {
                // AI art is ALWAYS fitted whole (never cropped), as large as the cell allows and centered; full sheets
                // (sign, menu) get the whole content area. Drawn flat on the white sheet (multiply): no tile card, no
                // shadow. The blank name line goes on its banner.
                let fit = Self.aspectFit(art.size, in: geo.size)
                ZStack(alignment: .top) {
                    Image(uiImage: art).resizable().scaledToFit()
                        .frame(width: fit.width, height: fit.height)
                        .blendMode(.multiply)
                    if showsName { nameBanner(height: fit.height * 0.17).padding(.top, fit.height * 0.05) }
                    if let role = roleText {   // the role title, on the shared badge art's bottom banner
                        roleBanner(role, height: fit.height * 0.13)
                            .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, fit.height * 0.06)
                    }
                }
                .frame(width: fit.width, height: fit.height)
                .clipShape(RoundedRectangle(cornerRadius: fullPage ? 0 : 12))
                .frame(width: geo.size.width, height: geo.size.height)
            } else {
                drawn(height: geo.size.height, narrow: !fullPage && geo.size.width < geo.size.height * 0.8)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: fullPage ? 0 : 14))
                    .overlay(RoundedRectangle(cornerRadius: fullPage ? 0 : 14).strokeBorder(Theme.printInk, lineWidth: fullPage ? 0 : 2))
            }
        }
    }

    static func aspectFit(_ image: CGSize, in box: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return box }
        let s = min(box.width / image.width, box.height / image.height)
        return CGSize(width: image.width * s, height: image.height * s)
    }

    /// Badges print their role title (the art is shared and role-neutral).
    private var roleText: String? {
        guard item.recipe == .badges || (item.recipe == nil && item.size == .badge) else { return nil }
        return slot.role ?? "Role: ______"
    }

    private func roleBanner(_ text: String, height: CGFloat) -> some View {
        Text(text)
            .font(Theme.printFont(height * 0.6)).minimumScaleFactor(0.4).lineLimit(1)
            .foregroundStyle(Theme.printInk)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: height * 0.3).fill(Theme.printPaper))
            .overlay(RoundedRectangle(cornerRadius: height * 0.3).strokeBorder(Theme.printInk, lineWidth: 2))
            .padding(.horizontal, 10)
    }

    private func nameBanner(height: CGFloat) -> some View {
        Text("Name: ________")
            .font(Theme.printFont(height * 0.55)).minimumScaleFactor(0.4).lineLimit(1)
            .foregroundStyle(Theme.printInk)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(Capsule().fill(Theme.printPaper))
            .overlay(Capsule().strokeBorder(Theme.printInk, lineWidth: 2))
    }

    @ViewBuilder
    private func drawn(height h: CGFloat, narrow: Bool = false) -> some View {
        let big = fullPage ? 3.0 : 1.0
        VStack(spacing: h * 0.03) {
            if narrow {   // tall badge cells: symbol above a wrapping title, so the title is never squeezed to "C…"
                Image(systemName: item.symbol).font(.system(size: h * 0.12, weight: .regular)).foregroundStyle(Theme.printInk)
                Text(item.title).font(Theme.printFont(h * 0.07)).foregroundStyle(Theme.printInk)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.5)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: item.symbol).font(.system(size: h * 0.16 / big, weight: .regular)).foregroundStyle(Theme.printInk)
                    Text(item.title).font(Theme.printFont(h * 0.11 / big)).foregroundStyle(Theme.printInk).lineLimit(1).minimumScaleFactor(0.5)
                    if item.colorMe { Image(systemName: "star").font(.system(size: h * 0.1 / big)).foregroundStyle(Theme.printInk) }
                }
            }
            if showsName { nameBanner(height: h * 0.16) }
            if let role = roleText { roleBanner(role, height: h * 0.1) }
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
