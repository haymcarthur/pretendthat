import SwiftUI
import UIKit

/// Nutmeg, drawn from layered art (spec §7): one shared head placed on a headless body pose.
/// BODY canvas: tail, body-<pose>. HEAD canvas: ears, head-base, face, mouth (all full-frame, so they stack).
/// Personality: bouncy and excitable, so the defaults are springy (idle bob, happy hops, quick ear perks).
struct NutmegCharacter: View {
    var state: NutmegState
    var mouthLevel: Float = 0
    /// While speaking, the amplitude mouth overrides the face's default mouth.
    var isSpeaking = false
    var pose: NutmegPose? = nil
    var costume: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                figure(t: t, side: min(geo.size.width, geo.size.height))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .animation(Theme.springy, value: state)
        .accessibilityElement()
        .accessibilityLabel("Nutmeg the mouse")
    }

    private var look: NutmegLook {
        var l = state.look(talkingPose: pose ?? .wave)
        if let pose, state != .napping, state != .excited { l.pose = pose }
        return l
    }

    @ViewBuilder
    private func figure(t: Double, side: CGFloat) -> some View {
        let l = look
        let m = Motion(state: state, t: t, reduced: reduceMotion)
        let unit = side / 1024
        let headSide = side * l.pose.headScale
        // Place the head canvas so its neck point lands on the pose's neck anchor.
        let headX = l.pose.neckAnchor.x * side - Theme.nutmegHeadNeck.x * headSide
        let headY = l.pose.neckAnchor.y * side - Theme.nutmegHeadNeck.y * headSide

        ZStack(alignment: .topLeading) {
            layer("nutmeg-tail").frame(width: side, height: side)
                .rotationEffect(.degrees(m.tailSwing), anchor: UnitPoint(x: 0.62, y: 0.88))
            layer(l.pose.asset).frame(width: side, height: side)
                .scaleEffect(x: 1, y: m.breathe, anchor: .bottom)
            head(look: l, motion: m)
                .frame(width: headSide, height: headSide)
                .rotationEffect(.degrees(l.pose.headRotation + m.headTilt), anchor: Theme.nutmegHeadNeck)
                .offset(x: headX, y: headY + (1 - m.breathe) * side * 0.4)
            if state == .napping { zzz(t: t, unit: unit) }
            if state == .thinking { sparkle(t: t, unit: unit) }
        }
        .frame(width: side, height: side, alignment: .topLeading)
        .offset(y: m.bob * unit)
    }

    private func head(look l: NutmegLook, motion m: Motion) -> some View {
        ZStack {
            layer(l.ears.asset)
                .scaleEffect(m.earScale, anchor: UnitPoint(x: 0.5, y: 0.4))
                .animation(.spring(response: 0.18, dampingFraction: 0.45), value: l.ears)   // ears perk quickly
            layer("nutmeg-head-base")
            layer(m.blink && l.face != .nap && l.face != .yay ? NutmegFace.nap.asset : l.face.asset)
            layer(mouth(l, m).asset)
            if let costume, UIImage(named: "nutmeg-costume-\(costume)") != nil { layer("nutmeg-costume-\(costume)") }
        }
    }

    private func mouth(_ l: NutmegLook, _ m: Motion) -> NutmegMouth {
        isSpeaking ? NutmegMouth.forLevel(mouthLevel, oohBeat: m.oohBeat) : l.mouth
    }

    private func layer(_ name: String) -> some View {
        Image(name).resizable().scaledToFit().accessibilityHidden(true)
    }

    private func zzz(t: Double, unit: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let phase = (t / 2.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(Theme.displayFont(CGFloat(60 + i * 20) * unit * 2))
                    .foregroundStyle(Theme.backgroundBrand)
                    .opacity(1 - phase)
                    .position(x: (720 + phase * 120) * unit, y: (240 - phase * 200) * unit)
            }
        }
        .accessibilityHidden(true)
    }

    private func sparkle(t: Double, unit: CGFloat) -> some View {
        Image(systemName: "sparkles")
            .font(.system(size: 140 * unit))
            .foregroundStyle(Theme.accent)
            .scaleEffect(1 + 0.15 * sin(t * 6))
            .position(x: 830 * unit, y: 150 * unit)
            .accessibilityHidden(true)
    }
}

/// All the time-based motion, as plain numbers (degrees, scale, 1024-space points).
private struct Motion {
    var bob: CGFloat = 0, breathe: CGFloat = 1, headTilt: Double = 0, earScale: CGFloat = 1
    var tailSwing: Double = 0, blink = false, oohBeat = false

    init(state: NutmegState, t: Double, reduced: Bool) {
        let k: Double = reduced ? 0.25 : 1
        let breathPeriod = state == .napping ? 4.5 : 1.6
        breathe = 1 + 0.015 * CGFloat(sin(t * 2 * .pi / breathPeriod) * k)
        tailSwing = 6 * sin(t * 2.2) * k
        // Blink: once per ~3.6 s cycle at a jittered moment, 120 ms long.
        let cycle = floor(t / 3.6)
        let jitter = abs((sin(cycle * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1))
        blink = abs(t - cycle * 3.6 - (1.0 + jitter * 2.4)) < 0.06
        oohBeat = Int(t * 7) % 7 == 0

        switch state {
        case .idle:
            bob = CGFloat(-abs(sin(t * 2.4)) * 14 * k)            // springy little bounce
            headTilt = 2 * sin(t * 1.3) * k
        case .listening:
            headTilt = 6; earScale = 1.06; bob = CGFloat(-4 * abs(sin(t * 3)) * k)
        case .thinking:
            headTilt = -4 + 1.5 * sin(t * 2) * k
        case .talking:
            headTilt = 2 * sin(t * 5) * k; bob = CGFloat(-abs(sin(t * 4.5)) * 8 * k)
        case .excited:
            let hop = abs(sin(t * .pi * 1.6))                       // happy hops
            bob = CGFloat(-hop * 70 * k); earScale = 1 + 0.05 * CGFloat(hop); headTilt = 4 * sin(t * 5) * k
        case .oops:
            headTilt = -5 + sin(t * 9) * 1.5 * k
        case .napping:
            headTilt = 0
        }
    }
}

#Preview { NutmegCharacter(state: .idle).padding() }
