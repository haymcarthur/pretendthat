import SwiftUI
import NutmegCore

/// Print step. While the kit is made Nutmeg colors on her clipboard (coloring pose); when it's ready the pages fly
/// off her clipboard one after another and settle in slightly overlapped fans (PTPaperReveal, PTPageFan). Tap a page
/// to preview it full-size (PTPagePreview).
/// Round 27 (Haylee): BOTH sets side by side, the color fan and the outline fan, with a highlight on the chosen one
/// (color by default). Tapping a set chooses it (a page also opens its preview); the printer prints the chosen set.
/// A set still drawing shows its pages in progress and a progress bar; the printer waits for the chosen set.
struct KitView: View {
    let model: AppModel
    /// Her clipboard relative to this view's center: the papers fly from there.
    var clipboard: CGPoint = CGPoint(x: -400, y: 40)
    /// Chat panel open: the papers dock in the panel's pinned card (with the Print pill) instead of the fan here.
    var chatOpen = false
    @Binding var preview: PTPreviewTarget?
    /// The papers have landed: RootView throws the confetti as its topmost overlay (above the chat panel, rail, pill).
    var onCelebrate: () -> Void = {}
    @State private var landed = false
    /// The papers fly out once the kit is final (round 27: one set final; the other may still be drawing).
    /// Round 11: the papers launch in the same frame as the camera's zoom-out (one move; round 10 waited 60 ms).
    private var revealed: Bool { model.kitFinal && model.kitBeat == .papers }
    private var store: AdventureStore { model.store }

    private var pages: [KitPage] { model.kitPages }
    /// The Print / Let's play row above the fans: its height and its gap to the pages.
    private static let buttonRow: CGFloat = 80, buttonGap: CGFloat = 24
    /// Round 27: the set chips under the fans, and the gap between the two sets.
    private static let chip: CGFloat = 40, setGap: CGFloat = 14

    var body: some View {
        printBody
    }

    private func page(_ i: Int, _ style: PrintStyle) -> some View {
        let art = model.artSet(style)
        return KitPageView(page: pages[i], art: art.images[pages[i].item.id], cutouts: art.cutoutImages(pages[i].item))
    }

    private var printBody: some View {
        VStack(spacing: Theme.Space.l) {
            GeometryReader { geo in
                let sets = model.printSets
                let rowH = Self.buttonRow + Theme.depth
                let row = rowH + Self.buttonGap
                // Round 27: the two sets stacked in the card zone (color on top), each one row of pages like a hand of
                // cards. [Claude's call: the shared card zone is ~350 pt wide, so two fans side by side left ~60 pt
                // pages; one above the other keeps them ~110 pt, about the old size.]
                let two = sets.count > 1
                let setW = geo.size.width
                let setH = (max(160, geo.size.height - row) - Self.setGap * CGFloat(sets.count - 1)) / CGFloat(max(1, sets.count))
                let fanBox = CGSize(width: setW - 24, height: max(80, setH - Self.chip - 18))
                let g = PTPageFan(count: pages.count, in: fanBox, oneRow: two, step: two ? 0.42 : PTPageFan.step)
                ZStack {
                    ForEach(Array(sets.enumerated()), id: \.element) { k, style in
                        let cy = -geo.size.height / 2 + row + setH / 2 + CGFloat(k) * (setH + Self.setGap)
                        setPanel(style, fan: g, box: CGSize(width: setW, height: setH), fanBox: fanBox,
                                 origin: CGPoint(x: clipboard.x, y: clipboard.y - cy + (Self.chip + 10) / 2), single: !two)
                            .offset(y: cy)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay {
                    // Round 26 (Haylee's button audit): icon only, a printer and a green ▶ (she names the pictures).
                    HStack(spacing: Theme.Space.l) {
                        // One tap opens the iOS print screen with the CHOSEN set (round 27); it waits while that set draws.
                        PTBigIconButton(kind: .print, size: Self.buttonRow, label: "Print") { model.tapPrint() }
                            .opacity(model.printReady ? 1 : 0.45)
                            .overlay { if !model.printReady { ProgressView().tint(Theme.white).controlSize(.large) } }
                            .allowsHitTesting(model.printReady)
                        PTBigIconButton(kind: .play, size: Self.buttonRow, label: "Let's play") { model.tapLetsPlay() }
                    }
                    .frame(height: rowH)
                    // Round 11: the buttons come in WITH the papers (one move), not after they land. Round 26: hidden
                    // while a page preview is open (they showed behind it as a duplicate Print / Let's play).
                    .opacity(revealed && !chatOpen && preview == nil ? 1 : 0)
                    .scaleEffect(revealed && !chatOpen ? 1 : 0.8)
                    .allowsHitTesting(revealed && !chatOpen && preview == nil)
                    .animation(Theme.stageMove, value: revealed)
                    .position(x: geo.size.width / 2, y: rowH / 2 + 4)
                }
            }
            .frame(maxHeight: .infinity)
            .opacity(chatOpen ? 0 : 1)
            .scaleEffect(chatOpen ? 0.6 : 1, anchor: .topTrailing)
            .allowsHitTesting(!chatOpen)
            .animation(Theme.stageMove, value: chatOpen)   // round 11: the chat panel's own spring
        }
        .animation(Theme.bouncy, value: landed)
        .animation(Theme.bouncy, value: store.printSet)
        .ptPagePreview($preview, count: pages.count) { i in page(i, store.printSet) }   // round 27: a page tap chooses its set first
        .sensoryFeedback(.success, trigger: landed)
        .sensoryFeedback(.selection, trigger: store.printSet)
        #if DEBUG
        .onChange(of: landed) { _, l in if l, let i = DemoDriver.previewPage { preview = PTPreviewTarget(index: i) } }
        #endif
        .onChange(of: revealed) { _, r in if !r { landed = false } }
        .onChange(of: landed) { _, l in if l && store.phase == .kitReady { onCelebrate() } }
    }

    /// One set: its fan of pages over a selection card (highlighted when chosen), and a chip saying which look it is.
    private func setPanel(_ style: PrintStyle, fan g: PTPageFan, box: CGSize, fanBox: CGSize, origin: CGPoint, single: Bool) -> some View {
        let chosen = store.printSet == style
        let art = model.artSet(style)
        return ZStack {
            // The selection card: a soft white card and a thick yellow ring on the chosen set.
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(chosen && !single ? Theme.white.opacity(0.6) : Color.white.opacity(0.001))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(chosen && !single ? Theme.yellow : .clear, lineWidth: 5))
                .opacity(revealed ? 1 : 0)
                .contentShape(Rectangle())
                .onTapGesture { model.tapPrintSet(style) }
            PTPaperReveal(count: revealed ? pages.count : 0, isRevealed: revealed,
                          origin: origin,
                          slot: { i in g.slot(i) },
                          paperSize: g.paper,
                          onLanded: { if style == PrintStyle.sets.first || single { landed = true; model.gesture(.celebrate) } },
                          onTap: { i in
                              model.tapPrintSet(style)
                              var tx = Transaction(); tx.disablesAnimations = true
                              withTransaction(tx) { preview = PTPreviewTarget(index: i) }
                          }) { i in
                page(i, style)
                    .scaleEffect(g.paper.width / KitPageView.size.width)
                    .frame(width: g.paper.width, height: g.paper.height)
                    .overlay { if model.pageDrawing(pages[i], in: art) { PTPageDrawing() } }
            }
            .frame(width: fanBox.width, height: fanBox.height)
            .offset(y: -(Self.chip + 10) / 2)
            PTPrintSetChip(style: style, chosen: chosen && !single, progress: art.finished ? nil : art.progress)
                .frame(height: Self.chip)
                .opacity(revealed ? 1 : 0)
                .offset(y: box.height / 2 - Self.chip / 2 - 8)
                .onTapGesture { model.tapPrintSet(style) }
        }
        .frame(width: box.width, height: box.height)
        .scaleEffect(chosen || single ? 1 : 0.96)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(style == .fullColor ? "Color pages" : "Outline pages to color")
        .accessibilityAddTraits(chosen ? [.isSelected, .isButton] : .isButton)
    }
}

/// Round 27: a page whose art is still drawing (its set isn't final yet): a soft white veil and a spinner.
struct PTPageDrawing: View {
    var body: some View {
        ZStack {
            Color.white.opacity(0.72)
            ProgressView().tint(Theme.purple)
        }
        .accessibilityLabel("Still drawing")
    }
}

/// Round 27: the chip under a set: what it looks like, with no words (kids can't read): a rainbow crayon swatch for
/// color, a black outline swatch for the coloring pages. A progress bar while the set is still drawing; a check on
/// the chosen set.
struct PTPrintSetChip: View {
    let style: PrintStyle
    let chosen: Bool
    /// nil = every page is drawn.
    let progress: Double?
    var body: some View {
        HStack(spacing: 8) {
            if style == .fullColor {
                HStack(spacing: -6) {
                    ForEach([Theme.coral, Theme.yellow, Theme.lime, Theme.purple], id: \.self) { c in
                        Circle().fill(c).frame(width: 22, height: 22).overlay(Circle().strokeBorder(Theme.white, lineWidth: 2))
                    }
                }
            } else {
                HStack(spacing: -6) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle().fill(Theme.white).frame(width: 22, height: 22).overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2.5))
                    }
                }
            }
            if let progress {
                ProgressView(value: max(0.05, progress)).tint(Theme.purple).frame(width: 60)
            } else if chosen {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.lime)
                    .background(Circle().fill(Theme.white).padding(3))
            }
        }
        .padding(.horizontal, 14).frame(maxHeight: .infinity)
        .background(Capsule().fill(Theme.white))
        .overlay(Capsule().strokeBorder(chosen ? Theme.yellow : Theme.line, lineWidth: chosen ? 3 : 1.5))
        .shadow(color: Theme.panelShadow, radius: 6, y: 2)
        .accessibilityElement()
        .accessibilityLabel(style == .fullColor ? "Color pages" : "Outline pages to color")
    }
}

// MARK: - Round 30: the chat panel's Print tab

/// The full print panel in the chat panel's Print tab (Haylee, round 30), roomier than the stage card: the printer
/// and the green ▶ on top, then BOTH sets (color and outline), each a strip of its pages over a selection card with
/// the set's chip. Tapping a set chooses it; tapping a page chooses its set and opens the full-size preview. The
/// printer prints the chosen set (and waits while that set is still drawing).
struct PrintTabView: View {
    let model: AppModel
    /// Opens the full-size preview of page i (of the chosen set).
    var onPreview: (Int) -> Void
    private var store: AdventureStore { model.store }
    private static let thumb = CGSize(width: 92, height: 119)

    var body: some View {
        let pages = model.kitPages
        let sets = model.printSets
        VStack(spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.l) {
                PTBigIconButton(kind: .print, size: 76, label: "Print") { model.tapPrint() }
                    .opacity(model.printReady ? 1 : 0.45)
                    .overlay { if !model.printReady { ProgressView().tint(Theme.white).controlSize(.large) } }
                    .allowsHitTesting(model.printReady)
                PTBigIconButton(kind: .play, size: 76, label: "Let's play") { model.tapLetsPlay() }
            }
            .padding(.bottom, Theme.depth)
            ForEach(sets, id: \.self) { style in
                setCard(style, pages: pages, single: sets.count < 2)
            }
        }
        .padding(.vertical, Theme.Space.xs)
        .animation(Theme.bouncy, value: store.printSet)
        .sensoryFeedback(.selection, trigger: store.printSet)
    }

    private func setCard(_ style: PrintStyle, pages: [KitPage], single: Bool) -> some View {
        let chosen = store.printSet == style && !single
        let art = model.artSet(style)
        return VStack(spacing: Theme.Space.s) {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(pages.indices, id: \.self) { i in
                        KitPageView(page: pages[i], art: art.images[pages[i].item.id], cutouts: art.cutoutImages(pages[i].item))
                            .scaleEffect(Self.thumb.width / KitPageView.size.width)
                            .frame(width: Self.thumb.width, height: Self.thumb.height)
                            .background(Theme.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                            .overlay { if model.pageDrawing(pages[i], in: art) { PTPageDrawing().clipShape(RoundedRectangle(cornerRadius: 8)) } }
                            .rotationEffect(.degrees(i % 2 == 0 ? -2 : 2))
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.tapPrintSet(style)
                                onPreview(i)
                            }
                            .accessibilityLabel("Page \(i + 1)")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.horizontal, 6)
            }
            .scrollIndicators(.hidden)
            PTPrintSetChip(style: style, chosen: chosen, progress: art.finished ? nil : art.progress)
                .frame(height: 44)
                .onTapGesture { model.tapPrintSet(style) }
        }
        .padding(Theme.Space.s)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.white.opacity(chosen ? 1 : 0.7)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(chosen ? Theme.yellow : Theme.line, lineWidth: chosen ? 5 : 1.5))
        .scaleEffect(chosen || single ? 1 : 0.97)
        .contentShape(Rectangle())
        .onTapGesture { model.tapPrintSet(style) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(style == .fullColor ? "Color pages" : "Outline pages to color")
        .accessibilityAddTraits(chosen ? [.isSelected, .isButton] : .isButton)
    }
}
