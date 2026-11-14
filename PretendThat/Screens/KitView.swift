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
    @State private var landed = false
    /// The papers fly out only once the WHOLE kit is final: every page's AI art landed or definitively fell back
    /// (never the fallback first and then a swap). Until then Nutmeg colors (no-text-overlays.md).
    private var revealed: Bool { model.kitFinal && model.kitBeat == .papers && cameraSettled }
    /// The papers launch once the camera has zoomed out (she looks up, the crayon goes down, then the zoom).
    @State private var cameraSettled = false
    private var store: AdventureStore { model.store }

    private var pages: [KitPage] { model.kitPages }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            // Pages in a slightly overlapped fan (Haylee fix round 1): every title visible, nothing clipped, sized to fit.
            GeometryReader { geo in
                let n = pages.count
                let g = PTPageFan(count: n, in: geo.size)
                PTPaperReveal(count: revealed ? n : 0, isRevealed: revealed,
                              origin: clipboard,
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
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(maxHeight: .infinity)
            .opacity(chatOpen ? 0 : 1)
            .scaleEffect(chatOpen ? 0.6 : 1, anchor: .topTrailing)
            .allowsHitTesting(!chatOpen)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: chatOpen)
            if landed && !chatOpen {
                HStack(spacing: Theme.Space.m) {
                    PTParentGate(label: "Hold to print") { model.printKit() }
                    Button("Let's play!") { store.beginPlay() }.buttonStyle(.ptSecondary)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(Theme.bouncy, value: landed)
        .overlay { if store.phase == .kitReady && landed { PTConfetti().ignoresSafeArea() } }
        .ptPagePreview($preview, count: pages.count) { i in
            KitPageView(page: pages[i], art: model.art.images[pages[i].item.id], cutouts: model.art.cutoutImages(pages[i].item))
        }
        .sensoryFeedback(.success, trigger: landed)
        #if DEBUG
        .onChange(of: landed) { _, l in if l, let i = DemoDriver.previewPage { preview = PTPreviewTarget(index: i) } }
        #endif
        .onChange(of: revealed) { _, r in if !r { landed = false } }
        .task(id: model.kitBeat == .papers) {
            guard model.kitBeat == .papers else { cameraSettled = false; return }
            try? await Task.sleep(for: .milliseconds(650))
            cameraSettled = true
        }
    }
}
