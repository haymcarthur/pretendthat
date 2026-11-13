import SwiftUI
import UIKit
import NutmegCore

/// Nutmeg, drawn from layered art (spec §7): one shared head placed on a headless body pose.
/// BODY canvas: tail, body-<pose>. HEAD canvas: ears, head-base, face, mouth (all full-frame, so they stack).
///
/// Motion (decisions motion-and-surface.md, mascot-nutmeg.md): she mostly RESTS in the idle pose with subtle
/// breathing, a blink or an ear twitch every few seconds, and lively motion only on events. Body poses have no
/// joints, so a pose change is a cartoon "pop": squash (anticipation) → small hop with the body crossfading at the
/// peak → spring landing. The head is one continuous view that springs to the new neck anchor, so the eye follows
/// the face and the swap reads as motion. Swaps are throttled (`PoseRules.minSwapInterval`). Reduce Motion: crossfade.
struct NutmegCharacter: View {
    var state: NutmegState
    var mouthLevel: Float = 0
    /// While speaking, the amplitude mouth overrides the face's default mouth.
    var isSpeaking = false
    /// One-shot gesture (wave on hello/goodbye, point when presenting, celebrate when something's ready).
    var cue: NutmegCue? = nil
    /// Debug only: hold this pose.
    var forcedPose: NutmegPose? = nil
    var costume: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: NutmegPose = .idle
    @State private var squash = CGSize(width: 1, height: 1)
    @State private var hop: CGFloat = 0
    @State private var lastSwap: Date?
    @State private var gestureTask: Task<Void, Never>?
    @State private var swapTask: Task<Void, Never>?

    private var basePose: NutmegPose { forcedPose ?? state.basePose }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                figure(t: t, side: min(geo.size.height, geo.size.width * NutmegPose.canvas.height / NutmegPose.canvas.width))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(NutmegPose.canvas.width / NutmegPose.canvas.height, contentMode: .fit)
        }
        .animation(Theme.springy, value: state)
        .onAppear { shown = basePose }
        .onChange(of: basePose) { _, new in
            gestureTask?.cancel()
            requestSwap(to: new)
        }
        .onChange(of: cue) { _, cue in if let cue { play(cue.gesture) } }
        .accessibilityElement()
        .accessibilityLabel("Nutmeg the mouse")
    }

    // MARK: Pose swaps

    private func play(_ gesture: NutmegGesture) {
        guard forcedPose == nil, PoseRules.allowsGesture(over: PoseName(rawValue: basePose.rawValue) ?? .idle) else { return }
        gestureTask?.cancel()
        gestureTask = Task { @MainActor in
            await swap(to: NutmegPose(gesture.pose))
            try? await Task.sleep(for: .seconds(PoseRules.hold(gesture)))
            guard !Task.isCancelled else { return }
            await swap(to: basePose)
        }
    }

    private func requestSwap(to pose: NutmegPose) {
        swapTask?.cancel()
        swapTask = Task { @MainActor in await swap(to: pose) }
    }

    private func swap(to pose: NutmegPose) async {
        let wait = PoseRules.delay(lastSwap: lastSwap, now: Date())
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        guard !Task.isCancelled, pose != shown else { return }
        lastSwap = Date()
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { shown = pose }
            return
        }
        // 1. Anticipation: quick squash.
        withAnimation(.easeOut(duration: 0.09)) { squash = CGSize(width: 1.05, height: 0.92) }
        try? await Task.sleep(for: .milliseconds(90))
        // 2. Small hop with stretch; swap the body at the peak (100 ms crossfade). The head springs on its own.
        withAnimation(.easeOut(duration: 0.12)) { squash = CGSize(width: 0.97, height: 1.06); hop = -12 }
        try? await Task.sleep(for: .milliseconds(70))
        withAnimation(.linear(duration: 0.1)) { shown = pose }
        try? await Task.sleep(for: .milliseconds(60))
        // 3. Land with a spring overshoot.
        withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) { squash = CGSize(width: 1, height: 1); hop = 0 }
    }

    // MARK: Drawing

    @ViewBuilder
    private func figure(t: Double, side: CGFloat) -> some View {
        // Shared 1178×1335 canvas (Haylee's art): body and head layers stack full-frame.
        let l = state.look
        let pose = shown
        let m = Motion(state: state, t: t, reduced: reduceMotion)
        let h = side, w = side * NutmegPose.canvas.width / NutmegPose.canvas.height
        let px = h / NutmegPose.canvas.height
        let unit = h / 1024

        ZStack(alignment: .topLeading) {
            ZStack {
                layer(pose.asset).id(pose).transition(.opacity)
            }
            .frame(width: w, height: h)
            .scaleEffect(x: 1, y: m.breathe, anchor: .bottom)
            head(look: l, motion: m)
                .frame(width: w, height: h)
                .rotationEffect(.degrees(pose.headRotation + m.headTilt), anchor: pose.neckAnchor)
                .offset(x: pose.headOffset.width * px, y: pose.headOffset.height * px + (1 - m.breathe) * h * 0.4)
                // The head is continuous through a body swap: it springs to the new pose's offset and rotation.
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.34, dampingFraction: 0.62), value: pose)
            if state == .napping { zzz(t: t, unit: unit) }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .scaleEffect(x: squash.width, y: squash.height, anchor: .bottom)
        .offset(y: hop * unit * 4 + m.bob * unit)
    }

    private func head(look l: NutmegLook, motion m: Motion) -> some View {
        ZStack {
            layer("nutmeg-head-base")
            layer(m.blink && l.face != .nap && l.face != .yay ? NutmegFace.nap.asset : l.face.asset)
            layer(isSpeaking ? NutmegMouth.forLevel(mouthLevel, oohBeat: m.oohBeat).asset : l.face.mouthAsset)
            if let costume, UIImage(named: "nutmeg-costume-\(costume)") != nil { layer("nutmeg-costume-\(costume)") }
        }
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
                    .foregroundStyle(Theme.purple)
                    .opacity(1 - phase)
                    .position(x: (720 + phase * 120) * unit, y: (240 - phase * 200) * unit)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Time-based motion, as plain numbers (degrees, scale, 1024-space points). Resting is nearly still:
/// subtle breathing, a slow small tail sway, and a blink / ear twitch at pseudo-random moments several seconds apart.
/// Bigger motion only while talking (head bob with the voice) or listening (perked, tilted).
private struct Motion {
    var bob: CGFloat = 0, breathe: CGFloat = 1, headTilt: Double = 0, earScale: CGFloat = 1, earTwitch: Double = 0
    var tailSwing: Double = 0, blink = false, oohBeat = false

    /// Deterministic 0…1 noise per integer cycle.
    static func noise(_ n: Double, _ salt: Double) -> Double {
        abs((sin(n * 12.9898 + salt * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1))
    }

    init(state: NutmegState, t: Double, reduced: Bool) {
        let k: Double = reduced ? 0 : 1
        let breathPeriod = state == .napping ? 4.5 : 3.2
        breathe = 1 + 0.012 * CGFloat(sin(t * 2 * .pi / breathPeriod))
        tailSwing = 2.5 * sin(t * 0.9) * k
        // Blink: once per 4–7 s window at a random moment, 130 ms long.
        let bCycle = floor(t / 5.5)
        blink = abs(t - bCycle * 5.5 - (0.5 + Self.noise(bCycle, 1) * 4.5)) < 0.065
        // Ear twitch: about every 9 s, a quick 160 ms flick (not while napping).
        let eCycle = floor(t / 9)
        let eAt = eCycle * 9 + 1 + Self.noise(eCycle, 2) * 7
        if state != .napping, t >= eAt, t - eAt < 0.16 { headTilt += 1.5 * sin((t - eAt) / 0.16 * .pi) * k }
        oohBeat = Int(t * 7) % 7 == 0

        switch state {
        case .listening:
            headTilt += 5
        case .thinking:
            headTilt += -4
        case .talking:
            headTilt += 2 * sin(t * 5) * k; bob = CGFloat(-abs(sin(t * 4.5)) * 6 * k)
        case .excited:
            break
        case .oops:
            headTilt += -5
        case .coloring:
            headTilt += 3 * sin(t * 1.2) * k   // looking down at the page, a little busy
        case .idle, .napping:
            break
        }
    }
}

#Preview { NutmegCharacter(state: .idle).padding() }
