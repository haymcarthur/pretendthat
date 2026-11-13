import SwiftUI

// Motion building blocks: bounce on pick, check-off burst, kit-ready confetti, phase transitions.
// Bouncy but not chaotic; every one of them calms down (or turns off) with Reduce Motion.

extension AnyTransition {
    /// Phase change: the new stage springs in from the trailing side, the old one shrinks away.
    static var ptStage: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.92)).combined(with: .opacity),
                    removal: .scale(scale: 0.94).combined(with: .opacity))
    }
    /// Hand-off card: slides in from the side.
    static var ptSlideIn: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)
    }
}

extension View {
    /// A quick squash-and-stretch bounce every time `trigger` changes (picking a choice).
    func ptBounce<T: Equatable>(trigger: T) -> some View { modifier(Bounce(trigger: trigger)) }
    /// Little dots burst out of the view each time `trigger` becomes true (check-offs).
    func ptBurst(_ trigger: Bool, color: Color = Theme.lime) -> some View { modifier(BurstModifier(trigger: trigger, color: color)) }
}

private struct Bounce<T: Equatable>: ViewModifier {
    let trigger: T
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGSize(width: 1, height: 1), trigger: trigger) { view, scale in
                view.scaleEffect(x: scale.width, y: scale.height, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.width) {
                    SpringKeyframe(1.12, duration: 0.12)
                    SpringKeyframe(0.94, duration: 0.14)
                    SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                }
                KeyframeTrack(\.height) {
                    SpringKeyframe(0.88, duration: 0.12)
                    SpringKeyframe(1.08, duration: 0.14)
                    SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                }
            }
        }
    }
}

private struct BurstModifier: ViewModifier {
    let trigger: Bool
    let color: Color
    @State private var count = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion { PTBurst(trigger: count, color: color).allowsHitTesting(false) }
            }
            .onChange(of: trigger) { _, on in if on { count += 1 } }
    }
}

/// Eight dots and stars that fly outward and fade. Purely decorative.
struct PTBurst: View {
    let trigger: Int
    var color: Color = Theme.lime
    var radius: CGFloat = 54

    var body: some View {
        let colors = [color, Theme.yellow, Theme.coral, color]
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                Group {
                    if i.isMultiple(of: 2) { Circle().fill(colors[i % 4]).frame(width: 10, height: 10) }
                    else { Image(systemName: "star.fill").font(Theme.displayFont(12)).foregroundStyle(colors[i % 4]) }
                }
                .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, p in
                    view.offset(x: cos(angle) * radius * p, y: sin(angle) * radius * p)
                        .scaleEffect(p == 0 ? 0 : 1.2 - p * 0.6)
                        .opacity(p == 0 || p >= 1 ? 0 : 1 - p * 0.8)
                } keyframes: { _ in
                    KeyframeTrack { CubicKeyframe(0.01, duration: 0.01); CubicKeyframe(1, duration: 0.5) }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Celebration: brand-colored confetti that pops up and floats down once, then stops. Reduce Motion: a few still stars.
struct PTConfetti: View {
    var pieces = 36
    var duration: Double = 2.6
    @State private var start = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                ForEach(0..<5, id: \.self) { i in
                    Image(i % 2 == 0 ? "stage-star" : "stage-sparkle").resizable().scaledToFit().frame(width: 32, height: 32)
                        .position(x: geo.size.width * (0.15 + 0.17 * Double(i)), y: geo.size.height * 0.12)
                }
            } else {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSince(start)
                    // Haylee's stage-star / stage-sparkle art, not SF Symbols or plain chips (checklist-pictures.md).
                    Canvas { gc, size in
                        guard t < duration else { return }
                        let art = [gc.resolve(Image("stage-star")), gc.resolve(Image("stage-sparkle"))]
                        for i in 0..<pieces {
                            let seed = Double(i) * 12.9898
                            let r1 = abs(sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                            let r2 = abs(sin(seed * 1.7) * 24634.6345).truncatingRemainder(dividingBy: 1)
                            let x0 = size.width * (0.2 + 0.6 * r1)
                            let vx = (r1 - 0.5) * size.width * 0.9
                            let vy = -size.height * (0.9 + 0.6 * r2)
                            let g = size.height * 2.2
                            let x = x0 + vx * t
                            let y = size.height * 0.75 + vy * t + 0.5 * g * t * t
                            let fade = max(0, 1 - t / duration)
                            var piece = gc
                            piece.opacity = fade
                            piece.translateBy(x: x, y: y)
                            piece.rotate(by: .radians(t * (4 + r2 * 6) + seed))
                            let side: CGFloat = i % 2 == 0 ? 22 : 16
                            piece.draw(art[i % 2], in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { start = .now }
    }
}
