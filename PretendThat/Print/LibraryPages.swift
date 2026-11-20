import SwiftUI
import NutmegCore

// Round 45 (Haylee, decisions/2026-11-17-printables-library.md): every library printable is drawn by the app. The AI
// art is a PICTURE ONLY; the app draws the card shape, its border, the title, every line, number, tick box and blank
// Name line, in its own space BESIDE the picture (never on top of it). One view per type and layout variant. Text and
// lines are always black; the color set adds soft tints to the app's frames, the outline set leaves them white.

/// A whole US Letter page of one library printable.
struct LibraryPageView: View {
    let page: KitPage
    var art: UIImage?
    /// Per-entry pictures (a sheet sliced by the app) or, for badges, one character per ranked role.
    var pictures: [UIImage?] = []
    var style: PrintStyle = .colorIn

    static let size = KitPageView.size
    static let margin: CGFloat = 24

    private var item: KitItem { page.item }
    private var look: PrintLook { PrintLook(style: style, type: item.recipe ?? .sign) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.printPaper
            content
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private var content: some View {
        let inner = CGSize(width: Self.size.width - Self.margin * 2, height: Self.size.height - Self.margin * 2)
        switch item.recipe {
        case .sign?: SignPage(item: item, picture: art, look: look, size: inner).offset(x: Self.margin, y: Self.margin)
        case .menu?: MenuPage(item: item, pictures: entryPictures, look: look, size: inner).offset(x: Self.margin, y: Self.margin)
        case .cutouts?: CutoutPage(item: item, pictures: pictures, look: look, size: inner).offset(x: Self.margin, y: Self.margin)
        case .map?: MapPage(item: item, picture: art, look: look, size: inner).offset(x: Self.margin, y: Self.margin)
        case .log?: LogPage(item: item, picture: art, look: look, size: inner).offset(x: Self.margin, y: Self.margin)
        case .passport?: PassportPage(item: item, picture: art, look: look, size: inner).offset(x: Self.margin, y: Self.margin)
        case .decoder?: DecoderPage(item: item, look: look, size: inner, picture: art).offset(x: Self.margin, y: Self.margin)
        case .controlPanel?: ControlPanelPage(item: item, picture: art, look: look, size: inner).offset(x: Self.margin, y: Self.margin)
        default: cards
        }
    }

    /// The per-entry pictures in line order (nil where not drawn: the symbol shows instead).
    private var entryPictures: [UIImage?] {
        let n = max(1, PrintLibrary.subjects(item).count)
        return (0..<n).map { pictures.indices.contains($0) ? pictures[$0] : (pictures.isEmpty ? art : nil) }
    }

    /// Cards in a grid with dashed cut lines between them.
    private var cards: some View {
        let grid = KitLayout.grid(for: item)
        let cellW = (Self.size.width - Self.margin * 2) / CGFloat(grid.columns)
        let cellH = (Self.size.height - Self.margin * 2) / CGFloat(grid.rows)
        let cell = CGSize(width: cellW, height: cellH)
        return ForEach(Array(page.slots.enumerated()), id: \.offset) { i, slot in
            LibraryCard(item: item, slot: slot, picture: picture(for: slot), look: look,
                        size: CGSize(width: cell.width - 16, height: cell.height - 16), allPictures: entryPictures)
                .frame(width: cellW, height: cellH)
                .overlay(Rectangle().strokeBorder(Theme.printInk.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
                .offset(x: Self.margin + CGFloat(i % grid.columns) * cellW, y: Self.margin + CGFloat(i / grid.columns) * cellH)
        }
    }

    private func picture(for slot: KitSlot) -> UIImage? {
        if item.recipe == .badges {
            if let k = slot.roleID?.index, pictures.indices.contains(k), let p = pictures[k] { return p }
            return art
        }
        if let t = item.recipe, PrintLibrary.perEntryPictures(t) {
            let pics = entryPictures
            return pics.isEmpty ? art : pics[slot.index % pics.count]
        }
        return art
    }
}

/// The color set's tint for a type (and a deeper band color); white in the outline set.
struct PrintLook {
    let style: PrintStyle
    let type: KitRecipe
    var colored: Bool { style == .fullColor }
    private var index: Int { (KitRecipe.allCases.firstIndex(of: type) ?? 0) % Theme.printTints.count }
    var fill: Color { colored ? Theme.printTints[index] : Theme.printPaper }
    var band: Color { colored ? Theme.printBands[index] : Theme.printPaper }
    func tint(_ k: Int) -> Color { colored ? Theme.printTints[(index + k) % Theme.printTints.count] : Theme.printPaper }
    let ink = Theme.printInk
}

// MARK: - Shared pieces

/// The picture in its own box: the AI art fitted whole (never cropped, never under text), or the type's symbol while
/// there's no art (no key, or it didn't come back).
struct PicBox: View {
    var picture: UIImage?
    var symbol: String
    var round = false
    var frame = true
    var body: some View {
        GeometryReader { g in
            ZStack {
                if let picture {
                    Image(uiImage: picture).resizable().scaledToFit().blendMode(.multiply).padding(round ? g.size.width * 0.1 : 4)
                } else {
                    Image(systemName: symbol).resizable().scaledToFit().fontWeight(.light)
                        .foregroundStyle(Theme.printInk.opacity(0.75)).padding(min(g.size.width, g.size.height) * 0.22)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
            .background(round ? AnyShape(Circle()).fill(Theme.printPaper) : AnyShape(RoundedRectangle(cornerRadius: 8)).fill(Theme.printPaper))
            .clipShape(round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8)))
            .overlay(frame ? (round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8))).stroke(Theme.printInk, lineWidth: 1.5) : nil)
        }
    }
}

/// "Name: ________" as a label and a drawn line (kids write their own name; we never ask for it).
struct NameLine: View {
    var label = "Name:"
    var size: CGFloat
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(label).font(Theme.printFont(size)).foregroundStyle(Theme.printInk).lineLimit(1).fixedSize()
            Rectangle().fill(Theme.printInk).frame(height: 1.5).offset(y: -2)
        }
    }
}

/// One line of printed text that shrinks to fit.
struct PrintText: View {
    let text: String
    var size: CGFloat
    var lines = 1
    var align: TextAlignment = .center
    var body: some View {
        Text(text).font(Theme.printFont(size)).foregroundStyle(Theme.printInk)
            .multilineTextAlignment(align).lineLimit(lines).minimumScaleFactor(0.45)
    }
}

/// A ribbon banner with notched ends (a title or a role).
struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        let n = min(r.height * 0.45, r.width * 0.08)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + n, y: r.midY)); p.closeSubpath()
        return p
    }
}

struct Ribbon: View {
    let text: String
    var look: PrintLook
    var fontSize: CGFloat
    var body: some View {
        PrintText(text: text, size: fontSize)
            .padding(.horizontal, fontSize * 1.1).padding(.vertical, fontSize * 0.2)
            .frame(maxWidth: .infinity)
            .background(RibbonShape().fill(look.band))
            .overlay(RibbonShape().stroke(Theme.printInk, lineWidth: 2))
    }
}

/// A tick box (kids tick it with a crayon).
struct TickBox: View {
    var side: CGFloat
    var body: some View { RoundedRectangle(cornerRadius: side * 0.18).stroke(Theme.printInk, lineWidth: 2).frame(width: side, height: side) }
}

/// A big number in a circle (clue 1, act 2…).
struct NumberDot: View {
    let text: String
    var side: CGFloat
    var look: PrintLook
    var body: some View {
        PrintText(text: text, size: side * 0.55)
            .frame(width: side, height: side)
            .background(Circle().fill(look.band))
            .overlay(Circle().stroke(Theme.printInk, lineWidth: 2))
    }
}

/// A card body: rounded, tinted in the color set, a black border.
struct CardBack: View {
    var look: PrintLook
    var radius: CGFloat = 14
    var line: CGFloat = 2.5
    var body: some View {
        RoundedRectangle(cornerRadius: radius).fill(look.fill)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.printInk, lineWidth: line))
    }
}

// MARK: - Cards (one copy each)

struct LibraryCard: View {
    let item: KitItem
    let slot: KitSlot
    var picture: UIImage?
    var look: PrintLook
    var size: CGSize
    /// Every entry's picture (an order slip shows them all, one by each tick box).
    var allPictures: [UIImage?] = []

    private var line: String { item.lines.isEmpty ? "" : item.lines[slot.index % item.lines.count] }
    private var number: String { KitLayout.copyNumber(for: item, slot: slot) ?? "\(slot.index + 1)" }
    private var symbol: String { item.recipe.map(PrintDefaults.symbol) ?? item.symbol }

    var body: some View {
        Group {
            switch (item.recipe, item.variant) {
            case (.badges?, .pin?): BadgePin(role: role, item: item, picture: picture, look: look, size: size)
            case (.badges?, .idCard?): BadgeID(role: role, item: item, slot: slot, picture: picture, look: look, size: size)
            case (.badges?, _): BadgeLanyard(role: role, picture: picture, look: look, size: size)
            case (.money?, .coins?): Coin(item: item, picture: picture, look: look, size: size)
            case (.money?, .tokens?): Token(item: item, picture: picture, look: look, size: size)
            case (.money?, _): Bill(item: item, picture: picture, look: look, size: size)
            case (.tickets?, .admission?): Admission(item: item, number: number, picture: picture, look: look, size: size)
            case (.tickets?, .keycard?): Keycard(item: item, number: number, picture: picture, look: look, size: size)
            case (.tickets?, _): Boarding(item: item, number: number, picture: picture, look: look, size: size)
            case (.orderSlips?, _): OrderSlip(item: item, number: number, look: look, size: size, pictures: allPictures)
            case (.clueCards?, _): ClueCard(text: line, number: number, picture: picture, symbol: symbol, look: look, size: size)
            case (.missionCards?, _): MissionCard(text: line, number: number, picture: picture, symbol: symbol, look: look, size: size)
            case (.medals?, _): Medal(text: line, picture: picture, symbol: symbol, look: look, size: size)
            case (.stickers?, _): Sticker(text: line, picture: picture, symbol: symbol, look: look, size: size)
            case (.labels?, _): Tag(text: line, picture: picture, symbol: symbol, look: look, size: size)
            default: BadgeLanyard(role: item.title, picture: picture, look: look, size: size)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    private var role: String { slot.role ?? "Role: ______" }
}

struct BadgeLanyard: View {
    let role: String; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        VStack(spacing: size.height * 0.03) {
            Capsule().stroke(Theme.printInk, lineWidth: 2).frame(width: size.width * 0.26, height: size.height * 0.035)
                .padding(.top, size.height * 0.035)
            PicBox(picture: picture, symbol: "person.crop.circle").frame(width: size.width * 0.82, height: size.height * 0.5)
            PrintText(text: role, size: size.height * 0.075, lines: 2)
                .padding(.horizontal, 8).frame(height: size.height * 0.15)
            NameLine(size: size.height * 0.05).padding(.horizontal, size.width * 0.08)
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .background(CardBack(look: look))
    }
}

struct BadgePin: View {
    let role: String; let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        let d = min(size.width - 8, size.height * 0.6)
        VStack(spacing: size.height * 0.025) {
            ZStack {
                Circle().fill(look.band).overlay(Circle().stroke(Theme.printInk, lineWidth: 3))
                PicBox(picture: picture, symbol: "person.crop.circle", round: true).padding(d * 0.09)
            }
            .frame(width: d, height: d)
            Ribbon(text: role, look: look, fontSize: size.height * 0.06).frame(width: size.width * 0.98)
            NameLine(size: size.height * 0.048).padding(.horizontal, size.width * 0.06)
        }
        .frame(width: size.width, height: size.height)
    }
}

struct BadgeID: View {
    let role: String; let item: KitItem; let slot: KitSlot; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        VStack(spacing: 0) {
            PrintText(text: item.title.uppercased(), size: size.height * 0.08)
                .padding(.horizontal, 10).frame(maxWidth: .infinity).frame(height: size.height * 0.2)
                .background(look.band)
                .overlay(Rectangle().frame(height: 2).foregroundStyle(Theme.printInk), alignment: .bottom)
            HStack(spacing: size.width * 0.04) {
                PicBox(picture: picture, symbol: "person.crop.square").frame(width: size.width * 0.4, height: size.height * 0.66)
                VStack(alignment: .leading, spacing: size.height * 0.06) {
                    PrintText(text: role, size: size.height * 0.1, lines: 2, align: .leading)
                    NameLine(size: size.height * 0.065)
                    PrintText(text: "ID \(String(format: "%03d", slot.index + 1))", size: size.height * 0.065, align: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(size.width * 0.04)
        }
        .frame(width: size.width, height: size.height)
        .background(CardBack(look: look, radius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.printInk, lineWidth: 2.5))
    }
}

struct Bill: View {
    let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        let corner = size.height * 0.24
        ZStack {
            CardBack(look: look, radius: 10)
            RoundedRectangle(cornerRadius: 6).stroke(Theme.printInk, style: StrokeStyle(lineWidth: 1, dash: [4, 3])).padding(6)
            VStack(spacing: 2) {
                PrintText(text: item.title, size: size.height * 0.12).padding(.horizontal, corner + 4)
                PicBox(picture: picture, symbol: "dollarsign.circle", round: true).frame(width: size.height * 0.52, height: size.height * 0.52)
                PrintText(text: "ONE DOLLAR", size: size.height * 0.08)
            }
            .padding(.vertical, 8)
            ForEach(0..<4, id: \.self) { k in
                PrintText(text: Money.bill, size: corner * 0.42)
                    .frame(width: corner, height: corner)
                    .background(Circle().fill(Theme.printPaper)).overlay(Circle().stroke(Theme.printInk, lineWidth: 1.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: k < 2 ? (k == 0 ? .topLeading : .topTrailing) : (k == 2 ? .bottomLeading : .bottomTrailing))
                    .padding(10)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

struct Coin: View {
    let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        let d = min(size.width, size.height) - 6
        ZStack {
            Circle().fill(look.band).overlay(Circle().stroke(Theme.printInk, lineWidth: 3))
            Circle().stroke(Theme.printInk, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).padding(d * 0.05)
            VStack(spacing: 0) {
                PrintText(text: Money.bill, size: d * 0.11).frame(height: d * 0.17)
                PicBox(picture: picture, symbol: "dollarsign.circle", round: true).frame(width: d * 0.56, height: d * 0.56)
                PrintText(text: item.title, size: d * 0.085).frame(width: d * 0.62, height: d * 0.15)
            }
        }
        .frame(width: d, height: d)
    }
}

struct Token: View {
    let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        let h = min(size.height * 0.72, size.width * 0.62)
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                Image(systemName: "star.fill").resizable().scaledToFit().frame(width: h * 0.28).foregroundStyle(look.colored ? Theme.yellow : Theme.printPaper)
                    .overlay(Image(systemName: "star").resizable().scaledToFit().frame(width: h * 0.28).foregroundStyle(Theme.printInk))
                PrintText(text: "1 TOKEN", size: h * 0.12)
                PrintText(text: item.title, size: h * 0.1, lines: 2)
            }
            .frame(maxWidth: .infinity)
            PicBox(picture: picture, symbol: "star.circle", round: true).frame(width: h * 0.62, height: h * 0.62)
        }
        .padding(.horizontal, h * 0.14)
        .frame(width: size.width, height: h)
        .background(TokenShape().fill(look.fill)).overlay(TokenShape().stroke(Theme.printInk, lineWidth: 2.5))
        .frame(width: size.width, height: size.height)
    }
}

/// A ticket with half-round notches on both sides.
struct TokenShape: Shape {
    func path(in r: CGRect) -> Path {
        let n = r.height * 0.16
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY - n))
        p.addArc(center: CGPoint(x: r.maxX, y: r.midY), radius: n, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY + n))
        p.addArc(center: CGPoint(x: r.minX, y: r.midY), radius: n, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct Boarding: View {
    let item: KitItem; let number: String; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                PicBox(picture: picture, symbol: "airplane").frame(width: size.height * 0.5, height: size.height * 0.5)
                VStack(alignment: .leading, spacing: 4) {
                    PrintText(text: item.title.uppercased(), size: size.height * 0.1, lines: 2, align: .leading)
                    if let l = item.lines.first { PrintText(text: l, size: size.height * 0.075, lines: 2, align: .leading) }
                    NameLine(size: size.height * 0.07)
                }
            }
            .padding(10).frame(width: size.width * 0.7, height: size.height)
            Rectangle().fill(Theme.printInk).frame(width: 1.5).mask(VStack(spacing: 4) { ForEach(0..<14, id: \.self) { _ in Rectangle().frame(height: 6) } })
            VStack(spacing: 2) {
                PrintText(text: "SEAT", size: size.height * 0.08)
                PrintText(text: number, size: size.height * 0.22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(look.band)
        }
        .frame(width: size.width, height: size.height)
        .background(look.fill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.printInk, lineWidth: 2.5))
    }
}

/// A ticket with scooped (concave) corners.
struct ScoopShape: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) * 0.12
        var p = Path()
        p.move(to: CGPoint(x: r.minX + s, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - s, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX, y: r.minY), radius: s, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - s))
        p.addArc(center: CGPoint(x: r.maxX, y: r.maxY), radius: s, startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
        p.addLine(to: CGPoint(x: r.minX + s, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX, y: r.maxY), radius: s, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + s))
        p.addArc(center: CGPoint(x: r.minX, y: r.minY), radius: s, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct Admission: View {
    let item: KitItem; let number: String; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                PrintText(text: "No.", size: size.height * 0.08)
                PrintText(text: number, size: size.height * 0.16)
            }
            .frame(width: size.width * 0.24)
            Rectangle().fill(Theme.printInk).frame(width: 1.5).mask(VStack(spacing: 4) { ForEach(0..<14, id: \.self) { _ in Rectangle().frame(height: 6) } })
            VStack(spacing: 3) {
                PrintText(text: "ADMIT ONE", size: size.height * 0.075)
                PrintText(text: item.title, size: size.height * 0.11, lines: 2)
                HStack(spacing: 8) {
                    PicBox(picture: picture, symbol: "ticket").frame(width: size.height * 0.36, height: size.height * 0.36)
                    if let l = item.lines.first { PrintText(text: l, size: size.height * 0.075, lines: 3) }
                }
            }
            .padding(.horizontal, 10).frame(maxWidth: .infinity)
        }
        .frame(width: size.width, height: size.height)
        .background(ScoopShape().fill(look.fill)).overlay(ScoopShape().stroke(Theme.printInk, lineWidth: 2.5))
    }
}

struct Keycard: View {
    let item: KitItem; let number: String; var picture: UIImage?; var look: PrintLook; var size: CGSize
    private var appointment: Bool {
        let t = (item.title + " " + item.lines.joined(separator: " ")).lowercased()
        return ["appointment", "visit", "checkup", "check-up", "booking"].contains { t.contains($0) }
    }
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(look.colored ? look.band : Theme.printPaper).frame(height: size.height * 0.14)
                .overlay(Rectangle().stroke(Theme.printInk, lineWidth: 1.5))
                .padding(.top, size.height * 0.08)
            HStack(spacing: 10) {
                PicBox(picture: picture, symbol: "key").frame(width: size.height * 0.46, height: size.height * 0.46)
                VStack(alignment: .leading, spacing: 4) {
                    PrintText(text: item.title, size: size.height * 0.1, lines: 2, align: .leading)
                    if appointment { NameLine(label: "Time:", size: size.height * 0.07) }
                    else { PrintText(text: "Room \(number)", size: size.height * 0.11, align: .leading) }
                    NameLine(size: size.height * 0.07)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
        }
        .frame(width: size.width, height: size.height)
        .background(CardBack(look: look, radius: 16))
    }
}

struct OrderSlip: View {
    let item: KitItem; let number: String; var look: PrintLook; var size: CGSize; var pictures: [UIImage?]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                PrintText(text: item.title, size: size.height * 0.085, align: .leading)
                Spacer()
                PrintText(text: "No. \(number)", size: size.height * 0.075)
            }
            NameLine(label: "Table", size: size.height * 0.075)
            let lines = Array(item.lines.prefix(4))
            let cols = lines.count > 2 ? 2 : 1
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: cols), alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                    HStack(spacing: 5) {
                        TickBox(side: size.height * 0.12)
                        PicBox(picture: pictures.indices.contains(i) ? pictures[i] : nil, symbol: "fork.knife")
                            .frame(width: size.height * 0.2, height: size.height * 0.2)
                        PrintText(text: Money.withoutPrice(l), size: size.height * 0.07, lines: 2, align: .leading)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: size.width, height: size.height)
        .background(CardBack(look: look, radius: 8))
    }
}

struct ClueCard: View {
    let text: String; let number: String; var picture: UIImage?; let symbol: String; var look: PrintLook; var size: CGSize
    var body: some View {
        VStack(spacing: size.height * 0.035) {
            HStack {
                NumberDot(text: number, side: size.height * 0.17, look: look)
                PrintText(text: "CLUE", size: size.height * 0.08)
                Spacer()
                Image(systemName: "magnifyingglass").font(.system(size: size.height * 0.08, weight: .bold)).foregroundStyle(Theme.printInk)
            }
            PicBox(picture: picture, symbol: symbol).frame(width: size.width * 0.6, height: size.height * 0.42)
            PrintText(text: text, size: size.height * 0.085, lines: 2)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: size.width, height: size.height)
        .background(CardBack(look: look))
    }
}

struct MissionCard: View {
    let text: String; let number: String; var picture: UIImage?; let symbol: String; var look: PrintLook; var size: CGSize
    var body: some View {
        VStack(spacing: size.height * 0.03) {
            PrintText(text: "MISSION \(number)", size: size.height * 0.085)
                .frame(maxWidth: .infinity).frame(height: size.height * 0.15).background(look.band)
                .overlay(Rectangle().frame(height: 2).foregroundStyle(Theme.printInk), alignment: .bottom)
            PicBox(picture: picture, symbol: symbol).frame(width: size.width * 0.58, height: size.height * 0.4)
            PrintText(text: text, size: size.height * 0.085, lines: 2).padding(.horizontal, 8)
            HStack(spacing: 6) { TickBox(side: size.height * 0.09); PrintText(text: "Done!", size: size.height * 0.07) }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .background(CardBack(look: look))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.printInk, lineWidth: 2.5))
    }
}

struct Medal: View {
    let text: String; var picture: UIImage?; let symbol: String; var look: PrintLook; var size: CGSize
    var body: some View {
        let d = min(size.width * 0.62, size.height * 0.5)
        VStack(spacing: 2) {
            ZStack(alignment: .bottom) {
                HStack(spacing: d * 0.1) {
                    RibbonTail().fill(look.band).overlay(RibbonTail().stroke(Theme.printInk, lineWidth: 2)).frame(width: d * 0.3, height: d * 0.42)
                    RibbonTail().fill(look.tint(2)).overlay(RibbonTail().stroke(Theme.printInk, lineWidth: 2)).frame(width: d * 0.3, height: d * 0.42)
                }
            }
            .frame(height: d * 0.36)
            ZStack {
                Circle().fill(look.colored ? Theme.yellow.opacity(0.55) : Theme.printPaper).overlay(Circle().stroke(Theme.printInk, lineWidth: 3))
                PicBox(picture: picture, symbol: symbol, round: true).padding(d * 0.1)
            }
            .frame(width: d, height: d)
            Ribbon(text: text, look: look, fontSize: size.height * 0.06).frame(width: size.width * 0.92)
            NameLine(label: "Awarded to", size: size.height * 0.05).padding(.horizontal, 8)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A ribbon tail hanging down to the medal (a strip with a V at the bottom... upside down: V at the top).
struct RibbonTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.22))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
        return p
    }
}

struct Sticker: View {
    let text: String; var picture: UIImage?; let symbol: String; var look: PrintLook; var size: CGSize
    var body: some View {
        let d = min(size.width, size.height) - 4
        VStack(spacing: 0) {
            PicBox(picture: picture, symbol: symbol, round: true, frame: false).frame(width: d * 0.58, height: d * 0.58)
            PrintText(text: text, size: d * 0.12).frame(width: d * 0.7)
        }
        .frame(width: d, height: d)
        .background(Scallop().fill(look.fill)).overlay(Scallop().stroke(Theme.printInk, lineWidth: 2))
    }
}

/// A scalloped sticker edge.
struct Scallop: Shape {
    func path(in r: CGRect) -> Path {
        let n = 16, c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2
        var p = Path()
        for i in 0...(n * 4) {
            let a = Double(i) / Double(n * 4) * 2 * .pi
            let rr = R * (0.94 + 0.06 * cos(Double(n) * a))
            let pt = CGPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct Tag: View {
    let text: String; var picture: UIImage?; let symbol: String; var look: PrintLook; var size: CGSize
    var body: some View {
        let h = size.height * 0.62
        HStack(spacing: 6) {
            Circle().stroke(Theme.printInk, lineWidth: 2).frame(width: h * 0.16, height: h * 0.16).padding(.leading, h * 0.22)
            PicBox(picture: picture, symbol: symbol).frame(width: h * 0.62, height: h * 0.62)
            VStack(spacing: 2) {
                PrintText(text: Money.withoutPrice(text), size: h * 0.16, lines: 2)
                if let p = Money.price(text) { PrintText(text: p, size: h * 0.24) }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.trailing, 6)
        .frame(width: size.width, height: h)
        .background(TagShape().fill(look.fill)).overlay(TagShape().stroke(Theme.printInk, lineWidth: 2.5))
        .frame(width: size.width, height: size.height)
    }
}

/// A gift / price tag: a pointed left end.
struct TagShape: Shape {
    func path(in r: CGRect) -> Path {
        let n = r.height * 0.32
        var p = Path()
        p.move(to: CGPoint(x: r.minX + n, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX - 8, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 8), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 8))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 8, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.midY)); p.closeSubpath()
        return p
    }
}

// MARK: - Full pages

struct SignPage: View {
    let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    private var tagline: [String] { Array(item.lines.filter { $0.caseInsensitiveCompare(item.title) != .orderedSame }.prefix(2)) }
    var body: some View {
        switch item.variant {
        case .banner?: banner
        case .marquee?: marquee
        default: door
        }
    }
    private var door: some View {
        VStack(spacing: 18) {
            PicBox(picture: picture, symbol: item.symbol).frame(width: size.width * 0.82, height: size.height * 0.46).padding(.top, 34)
            PrintText(text: item.title, size: 60, lines: 2).padding(.horizontal, 36)
            ForEach(tagline, id: \.self) { PrintText(text: $0, size: 30, lines: 2).padding(.horizontal, 40) }
            Spacer(minLength: 0)
            HStack(spacing: 18) { ForEach(0..<5, id: \.self) { _ in Image(systemName: "star").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.printInk) } }
                .padding(.bottom, 34)
        }
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: 22).fill(look.fill))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.printInk, lineWidth: 5))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.printInk, lineWidth: 1.5).padding(12))
    }
    private var banner: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Path { p in
                    p.move(to: CGPoint(x: 30, y: 46)); p.addLine(to: CGPoint(x: size.width / 2, y: 6)); p.addLine(to: CGPoint(x: size.width - 30, y: 46))
                }.stroke(Theme.printInk, lineWidth: 2)
                Circle().stroke(Theme.printInk, lineWidth: 2).frame(width: 14, height: 14).offset(y: -1)
            }
            .frame(width: size.width, height: 46)
            VStack(spacing: 16) {
                PrintText(text: item.title, size: 56, lines: 2).padding(.horizontal, 40).padding(.top, 26)
                PicBox(picture: picture, symbol: item.symbol).frame(width: size.width * 0.72, height: size.height * 0.4)
                Spacer(minLength: 0)
            }
            .frame(width: size.width, height: size.height * 0.8)
            .background(PennantShape().fill(look.fill)).overlay(PennantShape().stroke(Theme.printInk, lineWidth: 4))
            VStack(spacing: 6) { ForEach(tagline, id: \.self) { PrintText(text: $0, size: 30, lines: 2).padding(.horizontal, 40) } }
                .frame(maxHeight: .infinity)
        }
        .frame(width: size.width, height: size.height)
    }
    private var marquee: some View {
        let archH = size.height * 0.36
        return VStack(spacing: 20) {
            ZStack {
                ArchShape().fill(look.fill).overlay(ArchShape().stroke(Theme.printInk, lineWidth: 4))
                BulbRing(count: 22).frame(width: size.width - 30, height: archH - 18).offset(y: 4)
                PrintText(text: item.title, size: 52, lines: 2).padding(.horizontal, 70).padding(.top, archH * 0.22)
            }
            .frame(width: size.width, height: archH)
            PicBox(picture: picture, symbol: item.symbol).frame(width: size.width * 0.78, height: size.height * 0.42)
            ForEach(tagline, id: \.self) { PrintText(text: $0, size: 30, lines: 2).padding(.horizontal, 40) }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A pennant: a wide flag with a V at the bottom.
struct PennantShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.12)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.12)); p.closeSubpath()
        return p
    }
}

/// A marquee arch (a half circle on a box).
struct ArchShape: Shape {
    func path(in r: CGRect) -> Path {
        let rad = min(r.width / 2, r.height * 0.75)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad * 0.55))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + rad * 0.55), control: CGPoint(x: r.midX, y: r.minY - rad * 0.45))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.closeSubpath()
        return p
    }
}

/// Little "light bulbs" around the marquee's arch.
struct BulbRing: View {
    let count: Int
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ForEach(0..<count, id: \.self) { i in
                let t = Double(i) / Double(count - 1)
                // Along the same curve as the arch (a quad curve), then down the sides.
                let x = w * t
                let base = h * 0.42, lift = h * 0.6
                let y = base - lift * (1 - pow(2 * t - 1, 2)) * 0.75 + 6
                Circle().stroke(Theme.printInk, lineWidth: 1.5).frame(width: 12, height: 12).position(x: x, y: max(8, y))
            }
        }
    }
}

struct MenuPage: View {
    let item: KitItem; var pictures: [UIImage?]; var look: PrintLook; var size: CGSize
    private var entries: [(name: String, price: String?, pic: UIImage?)] {
        item.lines.prefix(6).enumerated().map { i, l in (Money.withoutPrice(l), Money.price(l), pictures.indices.contains(i) ? pictures[i] : nil) }
    }
    var body: some View {
        switch item.variant {
        case .program?: program
        case .chalkboard?: board
        default: card
        }
    }
    private var card: some View {
        let two = entries.count > 3
        let cols = Array(repeating: GridItem(.flexible(), spacing: 14), count: two ? 2 : 1)
        return VStack(spacing: 18) {
            Ribbon(text: item.title, look: look, fontSize: 40).padding(.horizontal, 30).padding(.top, 28)
            LazyVGrid(columns: cols, spacing: 18) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, e in
                    VStack(spacing: 8) {
                        PicBox(picture: e.pic, symbol: item.symbol).frame(width: two ? 130 : 190, height: entries.count > 4 ? 92 : (two ? 120 : 140))
                        PrintText(text: e.name, size: 24, lines: 1)
                        if let p = e.price { NumberDot(text: p, side: 44, look: look) }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(look.tint(1)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.printInk, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 26)
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.printInk, lineWidth: 4))
    }
    private var board: some View {
        VStack(spacing: 14) {
            PrintText(text: item.title, size: 48, lines: 2).padding(.top, 40).padding(.horizontal, 40)
            ForEach(Array(entries.enumerated()), id: \.offset) { _, e in
                HStack(spacing: 14) {
                    PicBox(picture: e.pic, symbol: item.symbol).frame(width: 86, height: 86)
                    PrintText(text: e.name, size: 30, align: .leading).fixedSize(horizontal: false, vertical: true)
                    Rectangle().fill(Theme.printInk).frame(height: 2).mask(HStack(spacing: 5) { ForEach(0..<40, id: \.self) { _ in Circle().frame(width: 3, height: 3) } })
                    if let p = e.price { PrintText(text: p, size: 44) }
                }
                .padding(.horizontal, 44)
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: 10).fill(look.fill).padding(14))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(look.colored ? Theme.nutmeg : Theme.printPaper, lineWidth: 18))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.printInk, lineWidth: 2))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.printInk, lineWidth: 2).padding(18))
    }
    private var program: some View {
        VStack(spacing: 16) {
            PrintText(text: "TONIGHT'S SHOW", size: 26).padding(.top, 34)
            Ribbon(text: item.title, look: look, fontSize: 40).padding(.horizontal, 30)
            ForEach(Array(entries.enumerated()), id: \.offset) { i, e in
                HStack(spacing: 16) {
                    NumberDot(text: "\(i + 1)", side: 54, look: look)
                    PicBox(picture: e.pic, symbol: item.symbol).frame(width: 96, height: 86)
                    PrintText(text: e.name, size: 32, lines: 2, align: .leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 40)
            }
            Spacer(minLength: 0)
            HStack(spacing: 18) { ForEach(0..<7, id: \.self) { _ in Image(systemName: "star").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.printInk) } }
                .padding(.bottom, 30)
        }
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: 18).fill(look.fill))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.printInk, lineWidth: 4))
    }
}

struct CutoutPage: View {
    let item: KitItem; var pictures: [UIImage?]; var look: PrintLook; var size: CGSize
    var body: some View {
        let labels = KitLayout.printedLines(for: item)
        let n = max(pictures.count, labels.count)
        let cols = 2, rows = max(1, Int(ceil(Double(n) / 2)))
        let top: CGFloat = 70
        let cellW = size.width / CGFloat(cols), cellH = (size.height - top) / CGFloat(rows)
        return ZStack(alignment: .topLeading) {
            PrintText(text: item.title, size: 40).frame(width: size.width, height: top - 12)
            ForEach(0..<n, id: \.self) { i in
                Group {
                    if pictures.indices.contains(i), let img = pictures[i] { Image(uiImage: img).resizable().scaledToFit().blendMode(.multiply).padding(10) }
                    else { PrintText(text: labels.indices.contains(i) ? labels[i] : "", size: 22) }
                }
                .frame(width: cellW, height: cellH)
                .overlay(Rectangle().strokeBorder(Theme.printInk.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
                .offset(x: CGFloat(i % cols) * cellW, y: top + CGFloat(i / cols) * cellH)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

struct MapPage: View {
    let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        VStack(spacing: 14) {
            Ribbon(text: item.title, look: look, fontSize: 38).padding(.horizontal, 40)
            PicBox(picture: picture, symbol: "map").frame(width: size.width, height: size.height * 0.6)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.printInk, lineWidth: 3))
            HStack(alignment: .top, spacing: 18) {
                Compass().frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(item.lines.prefix(4).enumerated()), id: \.offset) { i, l in
                        HStack(spacing: 10) { NumberDot(text: "\(i + 1)", side: 34, look: look); PrintText(text: l, size: 24, align: .leading).fixedSize() }
                    }
                    HStack(spacing: 10) {
                        PrintText(text: "✕", size: 26).frame(width: 34, height: 34).overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.printInk, lineWidth: 2))
                        PrintText(text: "Draw an X on the map!", size: 22, align: .leading)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A compass rose (drawn by the app, in the margin, never on the map picture).
struct Compass: View {
    var body: some View {
        ZStack {
            Circle().stroke(Theme.printInk, lineWidth: 2)
            Path { p in
                p.move(to: CGPoint(x: 52, y: 14)); p.addLine(to: CGPoint(x: 60, y: 52)); p.addLine(to: CGPoint(x: 52, y: 90))
                p.addLine(to: CGPoint(x: 44, y: 52)); p.closeSubpath()
                p.move(to: CGPoint(x: 14, y: 52)); p.addLine(to: CGPoint(x: 52, y: 44)); p.addLine(to: CGPoint(x: 90, y: 52))
                p.addLine(to: CGPoint(x: 52, y: 60)); p.closeSubpath()
            }.stroke(Theme.printInk, lineWidth: 2)
            ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { i, d in
                Text(d).font(Theme.printFont(14)).foregroundStyle(Theme.printInk)
                    .offset(x: [0, 44, 0, -44][i], y: [-44, 0, 44, 0][i])
            }
        }
        .frame(width: 104, height: 104)
    }
}

struct LogPage: View {
    let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                PicBox(picture: picture, symbol: "book").frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 10) {
                    PrintText(text: item.title, size: 40, lines: 2, align: .leading)
                    HStack(spacing: 20) { NameLine(label: "By:", size: 20); NameLine(label: "Day:", size: 20) }
                }
            }
            if item.variant == .chart { chart } else { ruled }
            Spacer(minLength: 0)
        }
        .padding(26)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(look.fill))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.printInk, lineWidth: 4))
    }
    private var ruled: some View {
        let rows = Array(item.lines.prefix(6))
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<9, id: \.self) { i in
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    PrintText(text: "\(i + 1).", size: 22).frame(width: 34, alignment: .leading)
                    if rows.indices.contains(i) { PrintText(text: rows[i], size: 22, align: .leading).fixedSize() }
                    Rectangle().fill(Theme.printInk).frame(height: 1.5)
                }
                .frame(height: 38)
            }
        }
    }
    private var chart: some View {
        let rows = Array(item.lines.prefix(6))
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 190, height: 50)
                ForEach(1...5, id: \.self) { d in NumberDot(text: "\(d)", side: 38, look: look).frame(maxWidth: .infinity) }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 0) {
                    PrintText(text: r, size: 22, lines: 2, align: .leading).frame(width: 190, alignment: .leading)
                    ForEach(0..<5, id: \.self) { _ in TickBox(side: 40).frame(maxWidth: .infinity) }
                }
                .frame(height: 70)
                .overlay(Rectangle().frame(height: 1.5).foregroundStyle(Theme.printInk.opacity(0.6)), alignment: .bottom)
            }
        }
        .padding(.top, 8)
    }
}

struct PassportPage: View {
    let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        let w = size.width / 2, h = size.height / 2
        let stops = Array(item.lines.prefix(6))
        return ZStack(alignment: .topLeading) {
            // Cover (top right when folded: fold the page in half top to bottom, then left to right).
            VStack(spacing: 10) {
                PrintText(text: "PASSPORT", size: 34)
                PrintText(text: item.title, size: 22, lines: 2)
                PicBox(picture: picture, symbol: "book.closed").frame(width: w * 0.7, height: h * 0.5)
            }
            .frame(width: w - 20, height: h - 20).background(RoundedRectangle(cornerRadius: 12).fill(look.band))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.printInk, lineWidth: 3))
            .offset(x: w + 10, y: 10)
            VStack(alignment: .leading, spacing: 14) {
                PrintText(text: "This passport belongs to", size: 18, lines: 2, align: .leading)
                NameLine(size: 20)
                PrintText(text: "Draw yourself!", size: 16, align: .leading)
                RoundedRectangle(cornerRadius: 8).stroke(Theme.printInk, lineWidth: 2).frame(width: w * 0.5, height: h * 0.42)
            }
            .padding(18).frame(width: w, height: h, alignment: .topLeading)
            stampPanel(Array(stops.prefix(3)), from: 0).frame(width: w, height: h).offset(y: h)
            stampPanel(Array(stops.dropFirst(3)), from: 3).frame(width: w, height: h).offset(x: w, y: h)
            Path { p in
                p.move(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: size.height))
                p.move(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: size.width, y: h))
            }.stroke(Theme.printInk.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
    private func stampPanel(_ names: [String], from: Int) -> some View {
        VStack(spacing: 10) {
            PrintText(text: "STAMPS", size: 20).padding(.top, 10)
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8).stroke(Theme.printInk, style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(width: 96, height: 76)
                    PrintText(text: names.indices.contains(i) ? names[i] : "Stop \(from + i + 1)", size: 20, lines: 2, align: .leading)
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
            Spacer(minLength: 0)
        }
    }
}

struct DecoderPage: View {
    let item: KitItem; var look: PrintLook; var size: CGSize
    /// 2026-11-20 (Haylee: "add some AI elements and make the colors match"): the AI's picture for this page (no words
    /// or symbols), printed under the code key; nil = the page as before.
    var picture: UIImage? = nil

    /// The color set uses the kit's AI palette (the page style every AI page is drawn in: coral, sunny yellow, lime,
    /// sky blue, deep purple, cream, dark purple outlines) instead of the app's pastel print tints; the coloring set
    /// stays black on white.
    private var colored: Bool { look.colored }
    private var line: Color { colored ? Theme.purple : Theme.printInk }
    private static let keyFills: [Color] = [Theme.yellow, Theme.coral, Theme.lime, Color(hex: 0x7CC8EA)].map { $0.opacity(0.45) }
    private func keyFill(_ i: Int) -> Color { colored ? Self.keyFills[i % Self.keyFills.count] : Theme.printPaper }

    var body: some View {
        let messages = Array(item.lines.prefix(3))
        let letters = Decoder.letters(messages)
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: min(7, max(1, letters.count)))
        let art = picture.flatMap(PictureTrim.trimmed)
        return VStack(spacing: art == nil ? 18 : 12) {
            title
            PrintText(text: "THE CODE KEY", size: 22)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Array(letters.enumerated()), id: \.element) { i, l in
                    VStack(spacing: 2) {
                        Image(systemName: Decoder.symbol(l)).font(.system(size: 30, weight: .regular)).foregroundStyle(Theme.printInk).frame(height: 36)
                        PrintText(text: String(l), size: 24)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(keyFill(i))).overlay(RoundedRectangle(cornerRadius: 8).stroke(line, lineWidth: colored ? 2.5 : 1.5))
                }
            }
            .padding(.horizontal, 20)
            PrintText(text: "SECRET MESSAGES", size: 22).padding(.top, 6)
            ForEach(Array(messages.enumerated()), id: \.offset) { i, m in
                HStack(spacing: 6) {
                    numberDot(i)
                    ForEach(Array(m.enumerated()), id: \.offset) { _, ch in
                        if ch == " " { Color.clear.frame(width: 14) }
                        else {
                            VStack(spacing: 4) {
                                Image(systemName: Decoder.symbol(ch)).font(.system(size: 22)).foregroundStyle(Theme.printInk).frame(height: 26)
                                RoundedRectangle(cornerRadius: 4).stroke(line, lineWidth: colored ? 2 : 1.5).frame(width: 30, height: 32)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
            }
            if let art {
                // The AI picture fills the room left under the messages (whole, never cropped).
                Image(uiImage: art).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16).padding(.bottom, 12)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(line, lineWidth: 4))
    }

    @ViewBuilder private var title: some View {
        if colored {
            PrintText(text: item.title, size: 38)
                .padding(.horizontal, 38 * 1.1).padding(.vertical, 38 * 0.2)
                .frame(maxWidth: .infinity)
                .background(RibbonShape().fill(Theme.yellow))
                .overlay(RibbonShape().stroke(line, lineWidth: 3))
                .padding(.horizontal, 40).padding(.top, 10)
        } else {
            Ribbon(text: item.title, look: look, fontSize: 38).padding(.horizontal, 40).padding(.top, 10)
        }
    }

    @ViewBuilder private func numberDot(_ i: Int) -> some View {
        if colored {
            PrintText(text: "\(i + 1)", size: 20)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Self.keyFills[(i + 1) % Self.keyFills.count]))
                .overlay(Circle().stroke(line, lineWidth: 2.5))
        } else {
            NumberDot(text: "\(i + 1)", side: 34, look: look)
        }
    }
}

/// 2026-11-20: an AI picture drawn in the middle of a white page, cut down to the drawing (the white paper around it
/// trimmed off), so the app can place it in its own space.
enum PictureTrim {
    static func trimmed(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return image }
        let w = 96, h = max(1, Int(Double(cg.height) / Double(cg.width) * 96))
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.setFillColor(UIColor.white.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h { for x in 0..<w {
            let i = (y * w + x) * 4
            if min(px[i], px[i + 1], px[i + 2]) < 235 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
        } }
        guard maxX >= minX, maxY >= minY else { return nil }   // a blank picture: print the page without it
        let sx = Double(cg.width) / Double(w), sy = Double(cg.height) / Double(h)
        // CGContext rows run bottom-up; the crop rect runs top-down.
        let rect = CGRect(x: Double(max(0, minX - 1)) * sx, y: Double(max(0, h - 1 - maxY - 1)) * sy,
                          width: Double(min(w, maxX - minX + 3)) * sx, height: Double(min(h, maxY - minY + 3)) * sy).integral
        guard let crop = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: crop, scale: image.scale, orientation: image.imageOrientation)
    }
}

/// The decoder's picture alphabet (app-drawn SF Symbols, friendly shapes only).
enum Decoder {
    static let symbols = ["star", "heart", "moon", "sun.max", "cloud", "leaf", "drop", "bolt", "bell", "key", "music.note",
                          "flag", "tree", "fish", "pawprint", "crown", "gift", "house", "car", "airplane", "bicycle", "umbrella",
                          "camera", "cup.and.saucer", "balloon", "snowflake"]
    static func symbol(_ c: Character) -> String {
        guard let a = c.uppercased().unicodeScalars.first?.value, (65...90).contains(a) else { return "circle" }
        return symbols[Int(a - 65) % symbols.count]
    }
    static func letters(_ messages: [String]) -> [Character] {
        Array(Set(messages.joined().uppercased().filter { $0.isLetter })).sorted()
    }
}

struct ControlPanelPage: View {
    let item: KitItem; var picture: UIImage?; var look: PrintLook; var size: CGSize
    var body: some View {
        let buttons = Array(item.lines.prefix(6))
        return VStack(spacing: 18) {
            PrintText(text: item.title, size: 40).padding(.top, 20)
            PicBox(picture: picture, symbol: "dial.medium").frame(width: size.width * 0.8, height: size.height * 0.3)
                .padding(10).background(RoundedRectangle(cornerRadius: 18).fill(look.band))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.printInk, lineWidth: 3))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(Array(buttons.enumerated()), id: \.offset) { i, b in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(look.tint(i)).overlay(Circle().stroke(Theme.printInk, lineWidth: 3))
                            Circle().stroke(Theme.printInk, lineWidth: 1.5).padding(12)
                        }
                        .frame(width: 84, height: 84)
                        PrintText(text: b, size: 20)
                    }
                }
            }
            .padding(.horizontal, 30)
            HStack(spacing: 34) {
                Dial(); Dial()
                Switch(look: look); Switch(look: look)
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: 24).fill(look.fill))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.printInk, lineWidth: 5))
    }
}

struct Dial: View {
    var body: some View {
        ZStack {
            Circle().stroke(Theme.printInk, lineWidth: 2.5)
            ForEach(0..<9, id: \.self) { i in
                Rectangle().fill(Theme.printInk).frame(width: 2, height: 8).offset(y: -30).rotationEffect(.degrees(-120 + Double(i) * 30))
            }
            Rectangle().fill(Theme.printInk).frame(width: 3, height: 26).offset(y: -12).rotationEffect(.degrees(35))
            Circle().fill(Theme.printInk).frame(width: 8, height: 8)
        }
        .frame(width: 76, height: 76)
    }
}

struct Switch: View {
    var look: PrintLook
    var body: some View {
        VStack(spacing: 4) {
            PrintText(text: "ON", size: 14)
            ZStack(alignment: .top) {
                Capsule().fill(look.tint(3)).overlay(Capsule().stroke(Theme.printInk, lineWidth: 2.5)).frame(width: 30, height: 60)
                Circle().fill(Theme.printPaper).overlay(Circle().stroke(Theme.printInk, lineWidth: 2)).frame(width: 24, height: 24).padding(.top, 4)
            }
            PrintText(text: "OFF", size: 14)
        }
    }
}
