import SwiftUI
import NutmegCore

/// Print step. While the kit is made Nutmeg colors on her clipboard (coloring pose); when it's ready the pages fly
/// off her clipboard one after another and settle in a fanned row (PTPaperReveal). The black Print pill appears once
/// they've all landed. Tap a page to preview it.
struct KitView: View {
    let model: AppModel
    @State private var landed = false
    @State private var preview: Int?
    private var revealed: Bool { store.phase == .kitReady && store.kit != nil }
    private var store: AdventureStore { model.store }

    private var pages: [KitPage] {
        guard let kit = store.kit else { return [] }
        return KitLayout.pages(for: kit, players: store.players.map(\.token), directorMode: store.directorMode)
    }

    static let paper = CGSize(width: 124, height: 124 * 11 / 8.5)

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTSpeechBubble(text: store.nutmegLine)
            GeometryReader { geo in
                let n = pages.count
                let step = n > 1 ? min(112, (geo.size.width - Self.paper.width - 20) / CGFloat(n - 1)) : 0
                PTPaperReveal(count: revealed ? n : 0, isRevealed: revealed,
                              origin: CGPoint(x: -geo.size.width / 2 - 150, y: 40),
                              slot: { i in
                                  let c = CGFloat(i) - CGFloat(n - 1) / 2
                                  return (CGPoint(x: c * step, y: abs(c) * 7), Double(c) * 2.5)
                              },
                              paperSize: Self.paper,
                              onLanded: { landed = true; model.gesture(.celebrate) },
                              onTap: { i in preview = i }) { i in
                    KitPageView(page: pages[i], tokens: store.tokens, art: model.art.images[pages[i].item.id])
                        .scaleEffect(Self.paper.width / KitPageView.size.width)
                        .frame(width: Self.paper.width, height: Self.paper.height)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: Self.paper.height + 60)
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
        .overlay {
            if let i = preview, pages.indices.contains(i) {
                ZStack {
                    Theme.scrim.ignoresSafeArea().onTapGesture { preview = nil }
                    KitPageView(page: pages[i], tokens: store.tokens, art: model.art.images[pages[i].item.id])
                        .scaleEffect(0.75)
                        .frame(width: KitPageView.size.width * 0.75, height: KitPageView.size.height * 0.75)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture { preview = nil }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Page \(i + 1). Tap to close.")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: preview)
        .sensoryFeedback(.success, trigger: landed)
        .onChange(of: revealed) { _, r in if !r { landed = false } }
    }
}
