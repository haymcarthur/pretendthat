import SwiftUI
import UIKit
import NutmegCore

/// Round 24 (Haylee): the no-printer Paper step, "Draw it!". One piece at a time: a big built-in SF Symbol of the shape
/// (no AI images), the piece's title and its one or two very short instructions, Next (Let's play! on the last piece),
/// and "Save printables for later" (the normal kit as coloring pages, to the share sheet). Nutmeg reads each piece;
/// the pill's Repeat reads it again; voice "next" / "again" work too.
struct PTDrawItCard: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var store: AdventureStore { model.store }

    var body: some View {
        if let guide = store.drawGuide, guide.pieces.indices.contains(store.drawIndex) {
            let i = store.drawIndex, piece = guide.pieces[i], last = i == guide.pieces.count - 1
            VStack(spacing: Theme.Space.m) {
                HStack(spacing: Theme.Space.s) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "doc").font(.system(size: 26, weight: .bold))
                        Image(systemName: "pencil").font(.system(size: 15, weight: .heavy)).offset(x: 6, y: 2)
                    }
                    .foregroundStyle(Theme.ink)
                    Text(DrawIt.title).font(Theme.displayFont(34)).foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    Text("\(i + 1) of \(guide.pieces.count)").font(Theme.headlineFont(Theme.TextSize.caption))
                        .foregroundStyle(Theme.inkMuted)
                }
                // The shape to draw, big and simple.
                Image(systemName: piece.symbol)
                    .font(.system(size: 92, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(Theme.paper))
                    .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius).stroke(Theme.line, lineWidth: 2))
                    .id(piece.id)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                    .accessibilityHidden(true)
                VStack(spacing: Theme.Space.xs) {
                    Text(piece.title).font(Theme.headlineFont(Theme.TextSize.headline)).foregroundStyle(Theme.ink)
                    Text(([piece.instruction, DrawIt.countLine(piece, players: store.playerCount)].filter { !$0.isEmpty }).joined(separator: " "))
                        .font(Theme.bodyFont(Theme.TextSize.body)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Theme.Space.xs) {
                    ForEach(guide.pieces.indices, id: \.self) { n in
                        Circle().fill(n <= i ? Theme.lime : Theme.line).frame(width: 10, height: 10)
                    }
                }
                .accessibilityHidden(true)
                Button { model.tapDrawNext() } label: {
                    Label(last ? DrawIt.playLabel : DrawIt.nextLabel, systemImage: last ? "play.fill" : "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.ptPrimary)
                // Round D1: hidden on a replay (it would be an image call; section E decides).
                if !store.isReplay { saveButton }
            }
            .frame(maxWidth: 420)
            .ptCard(fill: Theme.white, edge: Theme.lime, padding: Theme.Space.m)
            .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: store.drawIndex)
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder private var saveButton: some View {
        switch model.printablesState {
        case .making:
            HStack(spacing: Theme.Space.s) {
                ProgressView()
                Text(DrawIt.savingLabel).font(Theme.bodyFont(Theme.TextSize.caption)).foregroundStyle(Theme.inkMuted)
            }
            .frame(minHeight: 44)
        case .idle, .failed:
            Button { model.tapSavePrintables() } label: {
                Label(model.printablesState == .failed ? "Try saving again" : DrawIt.saveLabel, systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ptQuiet)
        }
    }
}

/// The iOS share sheet (Save to Files, AirDrop, Mail…) for the printables PDF.
struct PTShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
