import SwiftUI
import NutmegCore

/// Print step. While the kit is made Nutmeg colors on her clipboard (coloring pose); when it's ready the pages fly
/// off her clipboard one after another and settle in a slightly overlapped fan (PTPaperReveal, PTPageFan). The black Print pill appears once
/// they've all landed. Tap a page to preview it full-size (PTPagePreview).
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
    /// The papers fly out only once the WHOLE kit is final: every page's AI art landed or definitively fell back
    /// (never the fallback first and then a swap). Until then Nutmeg colors (no-text-overlays.md).
    /// Round 11: the papers launch in the same frame as the camera's zoom-out (one move; round 10 waited 60 ms).
    private var revealed: Bool { model.kitFinal && model.kitBeat == .papers }
    private var store: AdventureStore { model.store }

    private var pages: [KitPage] { model.kitPages }
    /// The Print / Let's play row above the fan: its height and its gap to the pages.
    private static let buttonRow: CGFloat = 56, buttonGap: CGFloat = 24

    var body: some View {
        // Round 24: no printer → the Paper step is "Draw it!" (no pages, no images).
        if store.drawMode { drawBody } else { printBody }
    }

    private var drawBody: some View {
        PTDrawItCard(model: model)
            .opacity(revealed && !chatOpen ? 1 : 0)
            .scaleEffect(revealed && !chatOpen ? 1 : 0.8)
            .allowsHitTesting(revealed && !chatOpen)
            .animation(Theme.stageMove, value: revealed)
            .animation(Theme.stageMove, value: chatOpen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: revealed) { _, r in
                if r { model.gesture(.celebrate); if store.phase == .kitReady { onCelebrate() } }
            }
    }

    private var printBody: some View {
        VStack(spacing: Theme.Space.l) {
            // Pages in a slightly overlapped fan (Haylee fix round 1): every title visible, nothing clipped, sized to fit.
            // Buttons ABOVE the fan (Haylee): a row centered over the pages, 24 pt above the fan's top, so they stay off
            // the floor and the control pill. The fan keeps the row's room below it, so nothing shifts when they pop in.
            GeometryReader { geo in
                let n = pages.count
                // A narrow zone (the prop-card step's camera, Haylee) stacks the two buttons.
                let stacked = geo.size.width < 400
                let rowH = stacked ? Self.buttonRow * 2 + Theme.Space.s : Self.buttonRow
                let row = rowH + Self.buttonGap
                let g = PTPageFan(count: n, in: CGSize(width: geo.size.width, height: max(120, geo.size.height - row)))
                let fanTop = row / 2 - (CGFloat(g.rows - 1) / 2 * g.paper.height * PTPageFan.rowStep + g.paper.height / 2) - 6
                PTPaperReveal(count: revealed ? n : 0, isRevealed: revealed,
                              origin: CGPoint(x: clipboard.x, y: clipboard.y - row / 2),
                              slot: { i in g.slot(i) },
                              paperSize: g.paper,
                              onLanded: { landed = true; model.gesture(.celebrate) },
                              onTap: { i in
                                  var tx = Transaction(); tx.disablesAnimations = true
                                  withTransaction(tx) { preview = PTPreviewTarget(index: i) }
                              }) { i in
                    KitPageView(page: pages[i], art: model.art.images[pages[i].item.id], cutouts: model.art.cutoutImages(pages[i].item))
                        .scaleEffect(g.paper.width / KitPageView.size.width)
                        .frame(width: g.paper.width, height: g.paper.height)
                }
                .offset(y: row / 2)
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay {
                    let layout = stacked ? AnyLayout(VStackLayout(spacing: Theme.Space.s)) : AnyLayout(HStackLayout(spacing: Theme.Space.m))
                    layout {
                        // One tap opens the iOS print screen (decisions/2026-11-13-single-tap-print.md).
                        Button { model.tapPrint() } label: { Label("Print", systemImage: "printer") }.buttonStyle(.ptPrimary)
                        Button("Let's play!") { model.tapLetsPlay() }.buttonStyle(.ptSecondary)
                    }
                    .frame(height: rowH)
                    // Round 11: the buttons come in WITH the papers (one move), not after they land.
                    .opacity(revealed && !chatOpen ? 1 : 0)
                    .scaleEffect(revealed && !chatOpen ? 1 : 0.8)
                    .allowsHitTesting(revealed && !chatOpen)
                    .animation(Theme.stageMove, value: revealed)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + fanTop - Self.buttonGap - rowH / 2)
                }
            }
            .frame(maxHeight: .infinity)
            .opacity(chatOpen ? 0 : 1)
            .scaleEffect(chatOpen ? 0.6 : 1, anchor: .topTrailing)
            .allowsHitTesting(!chatOpen)
            .animation(Theme.stageMove, value: chatOpen)   // round 11: the chat panel's own spring
        }
        .animation(Theme.bouncy, value: landed)
        .ptPagePreview($preview, count: pages.count) { i in
            KitPageView(page: pages[i], art: model.art.images[pages[i].item.id], cutouts: model.art.cutoutImages(pages[i].item))
        }
        .sensoryFeedback(.success, trigger: landed)
        #if DEBUG
        .onChange(of: landed) { _, l in if l, let i = DemoDriver.previewPage { preview = PTPreviewTarget(index: i) } }
        #endif
        .onChange(of: revealed) { _, r in if !r { landed = false } }
        .onChange(of: landed) { _, l in if l && store.phase == .kitReady { onCelebrate() } }
    }
}
