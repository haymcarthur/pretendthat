import SwiftUI

/// Full-screen page preview (Haylee fix round 1): one printable page shown whole at its true letter-paper aspect
/// (no cropping, no inner frame) on a dimmed backdrop. Close with the round X (top-right), a tap on the backdrop, or
/// a swipe down. Swipe or tap the chevrons to page left/right. Present it with
/// `.fullScreenCover(item:)` + `.presentationBackground(.clear)` (see `ptPagePreview`).
struct PTPagePreview<Page: View>: View {
    let count: Int
    @State var index: Int
    /// The page's natural size (US Letter, 612×792 pt); the page is scaled to fit the screen.
    var pageSize = CGSize(width: 612, height: 792)
    var onClose: () -> Void
    @ViewBuilder var page: (Int) -> Page
    @State private var drag: CGFloat = 0
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = 32
            let scale = min((geo.size.width - 2 * 120) / pageSize.width, (geo.size.height - 2 * pad) / pageSize.height)
            ZStack {
                Theme.scrim.opacity(shown ? max(0.3, 1 - Double(drag) / 400) : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Close preview")

                TabView(selection: $index) {
                    ForEach(0..<count, id: \.self) { i in
                        page(i)
                            .frame(width: pageSize.width, height: pageSize.height)
                            .scaleEffect(scale)
                            .frame(width: pageSize.width * scale, height: pageSize.height * scale)
                            // ONE clean white sheet, rounded like the stack's papers, one subtle shadow.
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14 * max(1, scale), style: .continuous))
                            .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
                            .contentShape(Rectangle())
                            .onTapGesture {}   // taps on the page itself don't close it
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Page \(i + 1) of \(count)")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: close)   // the margins beside the page act as backdrop
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .offset(y: drag)
                .scaleEffect(shown ? 1 : 0.92)
                .opacity(shown ? 1 : 0)
                .simultaneousGesture(DragGesture(minimumDistance: 20)
                    .onChanged { v in if v.translation.height > abs(v.translation.width) { drag = max(0, v.translation.height) } }
                    .onEnded { v in
                        if v.translation.height > 120 || v.predictedEndTranslation.height > 300 { close() }
                        else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drag = 0 } }
                    })

                // Chevrons for paging and the page count.
                HStack {
                    chevron("chevron.left", label: "Previous page", enabled: index > 0) { index -= 1 }
                    Spacer()
                    chevron("chevron.right", label: "Next page", enabled: index < count - 1) { index += 1 }
                }
                .padding(.horizontal, Theme.Space.l)
                .opacity(shown && count > 1 ? 1 : 0)

                VStack {
                    HStack {
                        Text("Page \(index + 1) of \(count)")
                            .font(Theme.uiFont(15, .medium)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14).frame(height: 36)
                            .background(Capsule().fill(Theme.white))
                        Spacer()
                        PTIconButton(symbol: "xmark", label: "Close preview", size: 56, action: close)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                    }
                    Spacer()
                }
                .padding(Theme.Space.m)
                .opacity(shown ? 1 : 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.85)) { shown = true } }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: index)
        .accessibilityAction(.escape, close)
        .statusBarHidden()
    }

    private func chevron(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        PTIconButton(symbol: symbol, label: label, size: 64, action: action)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .opacity(enabled ? 1 : 0)
            .disabled(!enabled)
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.18)) { shown = false }
        Task { try? await Task.sleep(for: .milliseconds(180)); onClose() }
    }
}

/// A page index to preview (fullScreenCover needs Identifiable).
struct PTPreviewTarget: Identifiable, Equatable { let index: Int; var id: Int { index } }

extension View {
    /// Presents `PTPagePreview` natively over everything (fullScreenCover with a clear background, no slide-in:
    /// the preview fades and scales itself).
    func ptPagePreview<Page: View>(_ target: Binding<PTPreviewTarget?>, count: Int,
                                   @ViewBuilder page: @escaping (Int) -> Page) -> some View {
        fullScreenCover(item: target) { t in
            PTPagePreview(count: count, index: t.index, onClose: {
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { target.wrappedValue = nil }
            }, page: page)
            .presentationBackground(.clear)
        }
    }
}

/// The kit papers docked at the top of the chat panel (chat open): a horizontal strip of page thumbnails (tap to open
/// the full-size preview) and the black Print pill (one tap opens the iOS print screen). Chat closed keeps the fan beside Nutmeg.
struct PTKitPinnedCard<Page: View>: View {
    let count: Int
    var onTap: (Int) -> Void
    var onPrint: () -> Void
    var onPlay: () -> Void
    /// Page i drawn at `PTKitPinnedCard.thumb` size.
    @ViewBuilder var page: (Int) -> Page
    static var thumb: CGSize { CGSize(width: 74, height: 96) }

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            // Buttons above the paper thumbnails (same order as the stage's kit reveal).
            // Round 26: icon only, the same printer and green ▶ as the stage.
            HStack(spacing: Theme.Space.l) {
                PTBigIconButton(kind: .print, size: 72, label: "Print", action: onPrint)   // single tap
                PTBigIconButton(kind: .play, size: 72, label: "Let's play", action: onPlay)
            }
            .padding(.bottom, Theme.depth)
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.xs) {
                    ForEach(0..<count, id: \.self) { i in
                        page(i)
                            .frame(width: Self.thumb.width, height: Self.thumb.height)
                            .background(Theme.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                            .rotationEffect(.degrees(i % 2 == 0 ? -2 : 2))
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(i) }
                            .accessibilityLabel("Page \(i + 1)")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(Theme.Space.s)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.white))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
    }
}
