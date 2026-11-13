import SwiftUI

/// Theater props placed AROUND Nutmeg as accents (brand rule: clean light base, brand color only on accents).
/// Crisp and flat (decision motion-and-surface.md): no glows, no gradients, and STATIC by default. They pop in once
/// when they appear and do a single bounce when `celebrate` changes (e.g. the kit is ready). Art: `stage-*`
/// placeholders until Haylee's vectors arrive (reference design/nutmeg/stage-props-v1.webp).
/// Place it behind Nutmeg: `nutmeg.background { PTStageAccents() }`.
struct PTStageAccents: View {
    var showsCurtain = true
    /// Changes make the props do one quick bounce (set app-wide with `.environment(\.ptCelebrate, n)`).
    @Environment(\.ptCelebrate) private var celebrate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var bounce = false

    private struct Spot { let asset: String; let x: CGFloat; let y: CGFloat; let size: CGFloat; let tilt: Double }
    private let spots = [
        Spot(asset: "stage-star", x: 0.42, y: -0.36, size: 0.13, tilt: 12),
        Spot(asset: "stage-sparkle", x: -0.42, y: -0.2, size: 0.08, tilt: 0),
        Spot(asset: "stage-ticket", x: 0.43, y: 0.3, size: 0.15, tilt: -18)
    ]

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                // Flat ground oval she stands on (crisp, no blur).
                PTGround()
                    .frame(width: side * 0.62, height: side * 0.1)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + side * 0.43)
                ForEach(Array(spots.enumerated()), id: \.offset) { i, spot in
                    Image(spot.asset).resizable().scaledToFit()
                        .frame(width: side * spot.size, height: side * spot.size)
                        .rotationEffect(.degrees(spot.tilt))
                        .scaleEffect(appeared ? (bounce ? 1.18 : 1) : 0.2)
                        .opacity(appeared ? 1 : 0)
                        .animation(reduceMotion ? .easeOut(duration: 0.2)
                                   : .spring(response: 0.42, dampingFraction: 0.55).delay(Double(i) * 0.08), value: appeared)
                        .animation(.spring(response: 0.25, dampingFraction: 0.4), value: bounce)
                        .position(x: geo.size.width / 2 + side * spot.x, y: geo.size.height / 2 + side * spot.y)
                }
            }
        }
        .onAppear { appeared = true }
        .onChange(of: celebrate) { _, _ in
            guard !reduceMotion else { return }
            bounce = true
            Task { try? await Task.sleep(for: .milliseconds(180)); bounce = false }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A coral curtain swag tied back in the top-leading corner of the screen. Static; one quick bounce on `celebrate`.
struct PTCurtainCorner: View {
    var width: CGFloat = 220
    @Environment(\.ptCelebrate) private var celebrate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swing: Double = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            CurtainDrape().fill(Theme.coral)
            CurtainFolds().stroke(Theme.coralShade, style: StrokeStyle(lineWidth: width * 0.035, lineCap: .round))
            Valance().fill(Theme.coralShade).frame(height: width * 0.16)
            Capsule().fill(Theme.yellow)
                .frame(width: width * 0.22, height: width * 0.07)
                .rotationEffect(.degrees(-35))
                .offset(x: width * 0.12, y: width * 0.95)
        }
        .frame(width: width, height: width * 1.5)
        .rotationEffect(.degrees(swing), anchor: .topLeading)
        .onChange(of: celebrate) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { swing = 5 }
            Task {
                try? await Task.sleep(for: .milliseconds(160))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.45)) { swing = 0 }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Drape: full at the top edge, pinched in at the tie-back, flaring out to the bottom left.
private struct CurtainDrape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: r.width, y: 0))
        p.addQuadCurve(to: CGPoint(x: r.width * 0.2, y: r.height * 0.64), control: CGPoint(x: r.width * 0.55, y: r.height * 0.45))
        p.addQuadCurve(to: CGPoint(x: r.width * 0.32, y: r.height), control: CGPoint(x: r.width * 0.12, y: r.height * 0.82))
        p.addLine(to: CGPoint(x: 0, y: r.height))
        p.closeSubpath()
        return p
    }
}

private struct CurtainFolds: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for (top, bottom) in [(0.25, 0.06), (0.5, 0.13), (0.74, 0.2)] {
            p.move(to: CGPoint(x: r.width * top, y: r.height * 0.1))
            p.addQuadCurve(to: CGPoint(x: r.width * bottom, y: r.height * 0.6), control: CGPoint(x: r.width * (top * 0.7), y: r.height * 0.4))
        }
        return p
    }
}

/// Scalloped valance strip.
private struct Valance: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let scallops = 4
        let w = r.width / CGFloat(scallops)
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: r.width, y: 0))
        p.addLine(to: CGPoint(x: r.width, y: r.height * 0.55))
        for i in (0..<scallops).reversed() {
            p.addQuadCurve(to: CGPoint(x: CGFloat(i) * w, y: r.height * 0.55), control: CGPoint(x: (CGFloat(i) + 0.5) * w, y: r.height * 1.25))
        }
        p.closeSubpath()
        return p
    }
}
