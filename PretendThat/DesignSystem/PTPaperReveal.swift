import SwiftUI

/// The reveal (D6, revised 2026-11-13): white sheets of paper fly off Nutmeg's clipboard. Each lifts from `origin`
/// (her clipboard, in this view's coordinates relative to its center), arcs out with a slight spin and settles in
/// its slot beside her, facing the user. Several papers launch one after another (~150 ms apart).
/// Crisp white sheets with rounded corners and the panel shadow. Reduce Motion: fade in place.
struct PTPaperReveal<Paper: View>: View {
    var count: Int
    var isRevealed: Bool
    /// Clipboard position relative to this view's center.
    var origin: CGPoint
    /// Final slot for paper i (relative to center) and its resting tilt.
    var slot: (Int) -> (point: CGPoint, tilt: Double)
    var paperSize: CGSize
    var onLanded: (() -> Void)? = nil
    var onTap: ((Int) -> Void)? = nil
    @ViewBuilder var paper: (Int) -> Paper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flown: Set<Int> = []

    static var stagger: Double { 0.15 }
    static var flight: Double { 0.75 }

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let s = slot(i)
                paper(i)
                    .frame(width: paperSize.width, height: paperSize.height)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.white))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Theme.panelShadow, radius: 10, y: 3)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(i) }
                    .modifier(ArcFlight(progress: flown.contains(i) ? 1 : 0, from: origin, to: s.point, tilt: s.tilt,
                                        reduced: reduceMotion))
                    .zIndex(Double(i))
            }
        }
        .onAppear { if isRevealed { launch() } }
        .onChange(of: isRevealed) { _, r in if r { launch() } else { flown = [] } }
        .onChange(of: count) { _, _ in if isRevealed { launch() } }
    }

    private func launch() {
        for i in 0..<count where !flown.contains(i) {
            let delay = reduceMotion ? 0 : Double(i) * Self.stagger
            withAnimation(reduceMotion ? .easeOut(duration: 0.3).delay(delay)
                          : .spring(response: Self.flight, dampingFraction: 0.78).delay(delay)) {
                _ = flown.insert(i)
            }
        }
        let total = (reduceMotion ? 0.3 : Double(max(0, count - 1)) * Self.stagger + Self.flight)
        Task { try? await Task.sleep(for: .seconds(total)); onLanded?() }
    }
}

/// Moves a paper along a quadratic arc from the clipboard to its slot, spinning slightly and growing as it flies.
private struct ArcFlight: @MainActor ViewModifier, @MainActor Animatable {
    var progress: Double
    var from: CGPoint
    var to: CGPoint
    var tilt: Double
    var reduced: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = progress
        if reduced {
            content.rotationEffect(.degrees(tilt)).offset(x: to.x, y: to.y).opacity(p)
        } else {
            // Control point above the midpoint: lift, arc out, settle.
            let control = CGPoint(x: (from.x + to.x) / 2, y: min(from.y, to.y) - 140)
            let q = 1 - p
            let x = q * q * from.x + 2 * q * p * control.x + p * p * to.x
            let y = q * q * from.y + 2 * q * p * control.y + p * p * to.y
            content
                .scaleEffect(0.2 + 0.8 * min(1, p))
                .rotationEffect(.degrees(tilt + (1 - p) * -38))
                .offset(x: x, y: y)
                .opacity(min(1, p * 4))
        }
    }
}

/// Page thumbnails as a slightly overlapped fan (Haylee prefers it to a grid): 1 row for up to 4 pages, else 2 rows,
/// each page overlapping its neighbor by ~22% with a small tilt and a gentle arc, as big as fits the box with room for
/// the tilt (nothing clipped). Later pages sit on top, so every page's title area (top center) stays visible.
/// Slot centers are relative to the box center (for PTPaperReveal).
struct PTPageFan {
    let columns: Int, rows: Int
    let paper: CGSize
    let count: Int
    /// Horizontal step between neighbors as a fraction of the page width (1 - overlap).
    static let step: CGFloat = 0.78
    /// Vertical step between rows as a fraction of the page height (the next row overlaps the bottom of the first).
    static let rowStep: CGFloat = 0.86

    init(count n: Int, in box: CGSize, aspect: CGFloat = 8.5 / 11) {
        count = max(1, n)
        rows = count > 4 ? 2 : 1
        columns = Int(ceil(Double(count) / Double(rows)))
        let usableW = box.width * 0.92, usableH = box.height * 0.9          // room for tilt and arc
        let byW = usableW / (1 + CGFloat(columns - 1) * Self.step)
        let byH = usableH / (1 + CGFloat(rows - 1) * Self.rowStep) * aspect
        let w = max(40, min(byW, byH, 240))
        paper = CGSize(width: w, height: w / aspect)
    }

    func slot(_ i: Int) -> (point: CGPoint, tilt: Double) {
        let r = i / columns
        let inRow = r == rows - 1 ? count - r * columns : columns
        let c = CGFloat(i % columns) - CGFloat(inRow - 1) / 2
        let y = (CGFloat(r) - CGFloat(rows - 1) / 2) * paper.height * Self.rowStep
        return (CGPoint(x: c * paper.width * Self.step, y: y + abs(c) * paper.height * 0.03), Double(c) * 3)
    }
}
