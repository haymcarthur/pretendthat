import SwiftUI

/// Nutmeg's clipboard as a reveal (D6): the back shows while something is being made; when `isRevealed` turns
/// true it flips around (rotation3DEffect) to show `content` on the clipboard front.
/// Art: `nutmeg-clipboard-back`, `nutmeg-clipboard-front` (placeholders until Haylee's art).
struct PTClipboardReveal<Content: View>: View {
    var isRevealed: Bool
    /// Optional `nutmeg-peek` head peeking in from the leading side (checklists).
    var peek = false
    var width: CGFloat = 560
    /// Lay content out larger and shrink it onto the paper (long checklists).
    var contentScale: CGFloat = 1
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    var body: some View {
        // Fits the space it's given (up to `width`), keeping the clipboard's 4:5 shape; content scales with it.
        GeometryReader { geo in
            let w = min(geo.size.width, geo.size.height * 0.8), h = w * 1.25
            ZStack {
                Image("nutmeg-clipboard-back").resizable().scaledToFit()
                    .frame(width: w, height: h)
                    .opacity(angle < 90 ? 1 : 0)
                ZStack {
                    Image("nutmeg-clipboard-front").resizable().scaledToFit()
                        .frame(width: w, height: h)
                    content
                        .frame(width: w * 0.8 / contentScale, height: h * 0.72 / contentScale)
                        .scaleEffect(contentScale)
                        .offset(y: h * 0.04)
                }
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(angle >= 90 ? 1 : 0)
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .overlay(alignment: .leading) {
                if peek {
                    Image("nutmeg-peek").resizable().scaledToFit()
                        .frame(width: w * 0.55)
                        .offset(x: -w * 0.16, y: -h * 0.2)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(0.8, contentMode: .fit)
        .frame(maxWidth: width)
        .onAppear { if isRevealed { angle = 180 } }
        .onChange(of: isRevealed) { _, revealed in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.7, dampingFraction: 0.72)) {
                angle = revealed ? 180 : 0
            }
        }
        .accessibilityElement(children: .contain)
    }
}
