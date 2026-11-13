import SwiftUI
import NutmegCore

struct KitView: View {
    let model: AppModel
    static let thumb: CGFloat = 64
    private var revealed: Bool { store.phase == .kitReady && store.kit != nil }
    private var store: AdventureStore { model.store }

    private var pages: [KitPage] {
        guard let kit = store.kit else { return [] }
        return KitLayout.pages(for: kit, players: store.players.map(\.token), directorMode: store.directorMode)
    }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTSpeechBubble(text: store.nutmegLine)
            // D6: Nutmeg colors while the kit is made (her coloring pose); then the clipboard flips to reveal the pages.
            PTClipboardReveal(isRevealed: revealed, width: 280) {
                if revealed {
                    let cols = pages.count > 4 ? 3 : 2
                    Grid(horizontalSpacing: Theme.Space.s, verticalSpacing: Theme.Space.s) {
                        ForEach(Array(stride(from: 0, to: pages.count, by: cols)), id: \.self) { row in
                            GridRow {
                                ForEach(row..<min(row + cols, pages.count), id: \.self) { i in
                                    KitPageView(page: pages[i], tokens: store.tokens, art: model.art.images[pages[i].item.id])
                                        .scaleEffect(Self.thumb / KitPageView.size.width)
                                        .frame(width: Self.thumb, height: Self.thumb * 11 / 8.5)
                                        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
            }
            if store.phase == .makingKit || store.kit == nil {
                PTWorkingIndicator(caption: "Nutmeg is making your kit...")
            } else {
                if model.art.isGenerating { PTWorkingIndicator(caption: "Drawing your pictures...", progress: model.art.progress) }
                HStack(spacing: Theme.Space.l) {
                    PTParentGate(label: "Grown-up: hold to print") {
                        let pdf = KitPrinter.pdf(pages: pages, tokens: store.tokens, art: model.art.images)
                        KitPrinter.print(pdf, jobName: "PretendThat \(store.plan?.gameTitle ?? "kit")")
                    }
                    Button("Let's play!") { store.beginPlay() }.buttonStyle(.ptPrimary)
                }
            }
        }
        .overlay { if store.phase == .kitReady { PTConfetti().ignoresSafeArea() } }
        .sensoryFeedback(.success, trigger: store.phase == .kitReady)

    }
}
