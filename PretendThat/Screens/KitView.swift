import SwiftUI
import NutmegCore

struct KitView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }

    private var pages: [KitPage] {
        guard let kit = store.kit else { return [] }
        return KitLayout.pages(for: kit, players: store.players.map(\.token), directorMode: store.directorMode)
    }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTSpeechBubble(text: store.nutmegLine)
            if store.phase == .makingKit || store.kit == nil {
                PTWorkingIndicator(caption: "Making your kit...")
            } else {
                HStack(spacing: Theme.Space.m) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        PTPageThumbnail(number: i + 1) {
                            KitPageView(page: page, tokens: store.tokens, art: model.art.images[page.item.id])
                                .scaleEffect(Theme.Size.thumbnail / KitPageView.size.width)
                                .frame(width: Theme.Size.thumbnail, height: Theme.Size.thumbnail * 11 / 8.5)
                        }
                        .ptPopIn(index: i)
                    }
                }
                if model.art.isGenerating { PTWorkingIndicator(caption: "Drawing your pictures...") }
                HStack(spacing: Theme.Space.l) {
                    PTParentGate(label: "Grown-up: hold to print") {
                        let pdf = KitPrinter.pdf(pages: pages, tokens: store.tokens, art: model.art.images)
                        KitPrinter.print(pdf, jobName: "PretendThat \(store.plan?.gameTitle ?? "kit")")
                    }
                    Button("Let's play!") { store.beginPlay() }.buttonStyle(.ptPrimary)
                }
            }
        }
        .task(id: store.kit) {
            guard let kit = store.kit else { return }
            await model.art.generate(kit: kit, gameTitle: store.plan?.gameTitle ?? store.gameTitle ?? "Pretend")
        }
    }
}
