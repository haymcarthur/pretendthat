import SwiftUI
import UIKit

/// Nutmeg, drawn from full-frame 1024² layers (spec §7) and animated in code.
/// Personality: bouncy and excitable, so the defaults are springy (idle bob, happy hops, quick ear perks).
struct NutmegCharacter: View {
    var state: NutmegState
    var mouthLevel: Float = 0
    var costume: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let unit = geo.size.width / 1024
                figure(t: t, unit: unit)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .animation(Theme.springy, value: state)
        .accessibilityElement()
        .accessibilityLabel("Nutmeg the mouse")
    }

    // MARK: Composition

    @ViewBuilder
    private func figure(t: Double, unit: CGFloat) -> some View {
        let m = Motion(state: state, t: t, reduced: reduceMotion)
        ZStack {
            layer("nutmeg-tail").rotationEffect(.degrees(m.tailSwing), anchor: UnitPoint(x: 0.62, y: 0.88))
            layer("nutmeg-body").scaleEffect(x: 1, y: m.breathe, anchor: .bottom)
            layer("nutmeg-arm-clipboard").rotationEffect(.degrees(m.armWave), anchor: UnitPoint(x: 0.43, y: 0.8))
            headGroup(m: m, unit: unit)
            if state == .napping { zzz(t: t, unit: unit) }
            if state == .thinking { sparkle(t: t, unit: unit) }
        }
        .offset(y: m.bob * unit)
    }

    private func headGroup(m: Motion, unit: CGFloat) -> some View {
        ZStack {
            layer("nutmeg-head")
            layer("nutmeg-ears").scaleEffect(m.earScale, anchor: UnitPoint(x: 0.5, y: 0.25))
            layer("nutmeg-headset")
            layer(eyesClosed(m) ? "nutmeg-eyes-closed" : "nutmeg-eyes-open")
                .offset(y: (state == .thinking ? -8 : 0) * unit * 4)
            layer(mouthName(m))
            if let costume, UIImage(named: "nutmeg-costume-\(costume)") != nil { layer("nutmeg-costume-\(costume)") }
        }
        .rotationEffect(.degrees(m.headTilt), anchor: Theme.nutmegNeckPivot)
    }

    private func layer(_ name: String) -> some View {
        Image(name).resizable().scaledToFit().accessibilityHidden(true)
    }

    private func eyesClosed(_ m: Motion) -> Bool { state == .napping || m.blink }

    private func mouthName(_ m: Motion) -> String {
        switch state {
        case .talking:
            let l = mouthLevel
            if l < 0.08 { return "nutmeg-mouth-closed" }
            if l < 0.25 { return "nutmeg-mouth-small" }
            if m.oohBeat { return "nutmeg-mouth-ooh" }
            return l < 0.5 ? "nutmeg-mouth-open" : "nutmeg-mouth-wide"
        case .excited: return "nutmeg-mouth-wide"
        case .thinking: return "nutmeg-mouth-ooh"
        case .listening: return "nutmeg-mouth-small"
        default: return "nutmeg-mouth-closed"
        }
    }

    private func zzz(t: Double, unit: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let phase = (t / 2.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(Theme.displayFont(CGFloat(60 + i * 20) * unit * 2))
                    .foregroundStyle(Theme.backgroundBrand)
                    .opacity(1 - phase)
                    .offset(x: (700 - 512 + phase * 120) * unit, y: (200 - 512 - phase * 220) * unit)
            }
        }
        .accessibilityHidden(true)
    }

    private func sparkle(t: Double, unit: CGFloat) -> some View {
        Image(systemName: "sparkles")
            .font(.system(size: 140 * unit))
            .foregroundStyle(Theme.accent)
            .scaleEffect(1 + 0.15 * sin(t * 6))
            .offset(x: 330 * unit, y: -380 * unit)
            .accessibilityHidden(true)
    }
}

/// All the time-based motion, as plain numbers (degrees, scale, 1024-space points).
private struct Motion {
    var bob: CGFloat = 0, breathe: CGFloat = 1, headTilt: Double = 0, earScale: CGFloat = 1
    var tailSwing: Double = 0, armWave: Double = 0, blink = false, oohBeat = false

    init(state: NutmegState, t: Double, reduced: Bool) {
        let k: Double = reduced ? 0.25 : 1
        let breathPeriod = state == .napping ? 4.5 : 1.6
        breathe = 1 + 0.02 * CGFloat(sin(t * 2 * .pi / breathPeriod) * k)
        tailSwing = 6 * sin(t * 2.2) * k
        // Blink: once every 2.5–5 s for 120 ms (deterministic jitter per cycle).
        let cycle = floor(t / 3.6)
        let offset = (sin(cycle * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
        let blinkAt = 1.0 + abs(offset) * 2.4
        blink = (t - cycle * 3.6 - blinkAt).magnitude < 0.06
        oohBeat = Int(t * 7) % 7 == 0

        switch state {
        case .idle:
            bob = CGFloat(-abs(sin(t * 2.4)) * 14 * k)            // springy little bounce
            headTilt = 2 * sin(t * 1.3) * k
        case .listening:
            headTilt = 6; earScale = 1.08; bob = CGFloat(-4 * abs(sin(t * 3)) * k)
        case .thinking:
            headTilt = -4 + 1.5 * sin(t * 2) * k
        case .talking:
            headTilt = 2 * sin(t * 5) * k; bob = CGFloat(-abs(sin(t * 4.5)) * 8 * k)
        case .excited:
            let hop = abs(sin(t * .pi * 1.6))                       // happy hops
            bob = CGFloat(-hop * 70 * k); earScale = 1 + 0.06 * CGFloat(hop)
            armWave = 8 * sin(t * 10) * k; headTilt = 4 * sin(t * 5) * k
        case .napping:
            headTilt = 8; bob = 10
        }
    }
}

#Preview { NutmegCharacter(state: .idle).padding() }
