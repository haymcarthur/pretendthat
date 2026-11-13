import SwiftUI
import NutmegCore

/// Print step. While the kit is made Nutmeg colors on her clipboard (coloring pose); when it's ready the pages fly
/// off her clipboard one after another and settle in a neat grid (PTPaperReveal, PTPageGrid). The black Print pill appears once
/// they've all landed. Tap a page to preview it full-size (PTPagePreview).
struct KitView: View {
    let model: AppModel
    @State private var landed = false
    @State private var preview: PTPreviewTarget?
    private var revealed: Bool { store.phase == .kitReady && store.kit != nil }
    private var store: AdventureStore { model.store }

    private var pages: [KitPage] {
        guard let kit = store.kit else { return [] }
        return KitLayout.pages(for: kit, players: store.players.map(\.token), directorMode: store.directorMode)
    }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTSpeechBubble(text: store.nutmegLine)
            // Every page fully visible as a neat thumbnail grid (Haylee fix round 1), sized to the space beside Nutmeg.
            GeometryReader { geo in
                let n = pages.count
                let g = PTPageGrid(count: n, in: geo.size)
                PTPaperReveal(count: revealed ? n : 0, isRevealed: revealed,
                              origin: CGPoint(x: -geo.size.width / 2 - 150, y: 40),
                              slot: { i in (g.center(i), 0) },
                              paperSize: g.paper,
                              onLanded: { landed = true; model.gesture(.celebrate) },
                              onTap: { i in
                                  var tx = Transaction(); tx.disablesAnimations = true
                                  withTransaction(tx) { preview = PTPreviewTarget(index: i) }
                              }) { i in
                    KitPageView(page: pages[i], tokens: store.tokens, art: model.art.images[pages[i].item.id])
                        .scaleEffect(g.paper.width / KitPageView.size.width)
                        .frame(width: g.paper.width, height: g.paper.height)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(maxHeight: .infinity)
            if store.phase == .makingKit || store.kit == nil {
                PTWorkingIndicator(caption: "Nutmeg is making your kit...")
            } else if landed {
                if model.art.isGenerating { PTWorkingIndicator(caption: "Drawing your pictures...", progress: model.art.progress) }
                HStack(spacing: Theme.Space.m) {
                    PTParentGate(label: "Grown-up: hold to print") {
                        let pdf = KitPrinter.pdf(pages: pages, tokens: store.tokens, art: model.art.images)
                        KitPrinter.print(pdf, jobName: "PretendThat \(store.plan?.gameTitle ?? "kit")")
                    }
                    Button("Let's play!") { store.beginPlay() }.buttonStyle(.ptSecondary)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(Theme.bouncy, value: landed)
        .overlay { if store.phase == .kitReady && landed { PTConfetti().ignoresSafeArea() } }
        .ptPagePreview($preview, count: pages.count) { i in
            KitPageView(page: pages[i], tokens: store.tokens, art: model.art.images[pages[i].item.id])
        }
        .sensoryFeedback(.success, trigger: landed)
        #if DEBUG
        .onChange(of: landed) { _, l in if l, let i = DemoDriver.previewPage { preview = PTPreviewTarget(index: i) } }
        #endif
        .onChange(of: revealed) { _, r in if !r { landed = false } }
    }
}
