import SwiftUI

/// Theater props placed AROUND Nutmeg as accents (brand rule: solid backdrop, props around the mascot, no scene art):
/// a spotlight glow behind her, a curtain corner, a ticket stub and a twinkling star.
/// Simple shapes and SF Symbols, with slow ambient motion (curtain sway, spotlight pulse) that stops with Reduce Motion.
/// Place it behind Nutmeg: `nutmeg.background { PTStageAccents() }`.
struct PTStageAccents: View {
    var showsCurtain = true
    @Environment(\.ptBackdrop) private var backdrop
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let pulse = 1 + 0.06 * sin(t * 2 * .pi / Theme.pulsePeriod)
                ZStack {
                    // Spotlight glow behind her.
                    Circle()
                        .fill(RadialGradient(colors: [backdrop.glow.opacity(backdrop.glowOpacity), backdrop.glow.opacity(0)],
                                             center: .center, startRadius: side * 0.05, endRadius: side * 0.55))
                        .frame(width: side * 1.1, height: side * 1.1)
                        .scaleEffect(pulse)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.52)
                    // Floor ellipse she stands on.
                    Ellipse().fill(backdrop.glow.opacity(backdrop.glowOpacity * 0.6))
                        .frame(width: side * 0.7, height: side * 0.1)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 + side * 0.44)
                    // Ticket stub, bobbing gently.
                    Image(systemName: "ticket.fill")
                        .font(.system(size: side * 0.13, weight: .black))
                        .foregroundStyle(Theme.coral)
                        .rotationEffect(.degrees(-18 + 4 * sin(t * 1.3)))
                        .position(x: geo.size.width / 2 + side * 0.42, y: geo.size.height / 2 + side * 0.3 + 4 * sin(t * 1.7))
                    // Twinkling star.
                    Image(systemName: "star.fill")
                        .font(.system(size: side * 0.1, weight: .black))
                        .foregroundStyle(backdrop == .spotlight ? Theme.coral : Theme.yellow)
                        .scaleEffect(1 + 0.18 * sin(t * 2.4))
                        .rotationEffect(.degrees(12 * sin(t * 0.8)))
                        .position(x: geo.size.width / 2 + side * 0.4, y: geo.size.height / 2 - side * 0.38)
                    Image(systemName: "sparkle")
                        .font(.system(size: side * 0.06, weight: .black))
                        .foregroundStyle(backdrop == .spotlight ? Theme.white : Theme.lime)
                        .opacity(0.6 + 0.4 * sin(t * 3.1))
                        .position(x: geo.size.width / 2 - side * 0.42, y: geo.size.height / 2 - side * 0.2)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A coral curtain swag tied back in the top-leading corner of the screen. Sways slowly.
struct PTCurtainCorner: View {
    var width: CGFloat = 220
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            let sway = 2.2 * sin(t * 2 * .pi / Theme.swayPeriod)
            ZStack(alignment: .topLeading) {
                CurtainDrape().fill(Theme.coral)
                CurtainFolds().stroke(Theme.coralShade, style: StrokeStyle(lineWidth: width * 0.035, lineCap: .round))
                // Valance across the top.
                Valance().fill(Theme.coralShade).frame(height: width * 0.16)
                // Gold tie-back.
                Capsule().fill(Theme.yellow)
                    .frame(width: width * 0.22, height: width * 0.07)
                    .rotationEffect(.degrees(-35))
                    .offset(x: width * 0.12, y: width * 0.95)
            }
            .frame(width: width, height: width * 1.5)
            .rotationEffect(.degrees(sway), anchor: .topLeading)
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
