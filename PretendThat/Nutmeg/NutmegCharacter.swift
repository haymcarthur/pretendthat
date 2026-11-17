import SwiftUI
import UIKit
import NutmegCore

/// Nutmeg, drawn from layered art (spec §7): one shared head placed on a headless body pose.
/// BODY canvas: body-<pose> (tail drawn in). HEAD canvas, bottom to top: head-base, face (eyes), mouth, HEADSET
/// (round 3: its own layer on top, so the band sits cleanly over the forehead and the mic arm sits in front of her cheek). All
/// layers are full-frame and the whole head stack shares one transform (tilt, bob, nudge).
///
/// Motion (decisions motion-and-surface.md, mascot-nutmeg.md): she mostly RESTS in the idle pose with subtle
/// breathing, a blink or an ear twitch every few seconds, and lively motion only on events. Body poses have no
/// joints, so a pose change is a cartoon "pop": squash (anticipation) → small hop with the body crossfading at the
/// peak → spring landing. The head is one continuous view that springs to the new neck anchor, so the eye follows
/// the face and the swap reads as motion. Swaps are throttled (`PoseRules.minSwapInterval`). Reduce Motion: crossfade.
struct NutmegCharacter: View {
    var state: NutmegState
    var mouthLevel: Float = 0
    /// Lip-synced mouth from the live voice; overrides the amplitude mapping of `mouthLevel` while speaking.
    var mouthShape: NutmegMouth? = nil
    /// While speaking, the amplitude mouth overrides the face's default mouth.
    var isSpeaking = false
    /// One-shot gesture (wave on hello/goodbye, point when presenting, celebrate when something's ready).
    var cue: NutmegCue? = nil
    /// Debug only: hold this pose.
    var forcedPose: NutmegPose? = nil
    var costume: String? = nil
    /// Draw the flat ground oval under her feet INSIDE the figure, so it shares every transform and timing with her
    /// (zoom, position, squash, hop): nothing trails (Haylee fix round 1).
    var showsGround = false
    /// false: draw the tail-less body art (`<pose>-notail`, start screen where she stands in the chest) when it exists.
    var showsTail = true
    /// Kit step: rest in the both-hands clipboard pose instead of idle (`PoseRules.holdsClipboard`).
    var holdsClipboard = false
    /// The writing moment (round 5): in clipboardBoth, the crayon's top end wiggles above the clipboard's top edge.
    var writing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: NutmegPose = .idle
    @State private var squash = CGSize(width: 1, height: 1)
    @State private var hop: CGFloat = 0
    @State private var lastSwap: Date?
    @State private var gestureTask: Task<Void, Never>?
    @State private var swapTask: Task<Void, Never>?

    private var basePose: NutmegPose { forcedPose ?? state.basePose(holdingClipboard: holdsClipboard) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                figure(t: t, side: min(geo.size.height, geo.size.width * NutmegPose.canvas.height / NutmegPose.canvas.width))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(NutmegPose.canvas.width / NutmegPose.canvas.height, contentMode: .fit)
        }
        // No view-wide animation here: a separate spring on the figure made her inner layers trail the stage camera's
        // spring on zoom. Only the intentional head tilt eases on its own (scoped below).
        .onAppear { shown = basePose }
        .onChange(of: basePose) { _, new in
            gestureTask?.cancel()
            requestSwap(to: new)
        }
        .onChange(of: cue) { _, cue in if let cue { play(cue.gesture, hold: cue.hold) } }
        .accessibilityElement()
        .accessibilityLabel("Nutmeg the mouse")
    }

    // MARK: Pose swaps

    private func play(_ gesture: NutmegGesture, hold: TimeInterval? = nil) {
        guard forcedPose == nil, PoseRules.allowsGesture(over: PoseName(rawValue: basePose.rawValue) ?? .idle) else { return }
        gestureTask?.cancel()
        gestureTask = Task { @MainActor in
            await swap(to: NutmegPose(gesture.pose))
            try? await Task.sleep(for: .seconds(hold ?? PoseRules.hold(gesture)))
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
        let m = Motion(state: state, t: t, reduced: reduceMotion, speaking: isSpeaking,
                       level: mouthShape.map { $0 == .closed ? 0 : ($0 == .small ? 0.4 : 0.9) } ?? mouthLevel * 2)
        let h = side, w = side * NutmegPose.canvas.width / NutmegPose.canvas.height
        let px = h / NutmegPose.canvas.height
        let unit = h / 1024

        ZStack(alignment: .topLeading) {
        // Her contact shadow on the floor (Haylee): a small low-contrast ellipse in a darker floor tone, ~1.1x her
        // stance (round 4 idle: feet span canvas x ~400–805, soles at y ~1310), centered under her feet. It stays on the floor when she
        // hops (outside the hop offset) and shrinks a little while she's in the air.
        if showsGround {
            let air = min(1, abs(hop) / 12)
            PTGround()
                .frame(width: pose.shadow.width * px, height: (pose == .sit ? 52 : 46) * px)
                .scaleEffect(1 - 0.2 * air)
                .position(x: pose.shadow.x * px, y: 1306 * px)
        }
        // Round 14/22: seated, her clipboard lies flat on the floor beside her feet on her right (drawn behind her).
        if pose == .sit {
            layer("nutmeg-sit-clipboard")
                .frame(width: w, height: h)
                .offset(x: NutmegPose.sitClipboardShift * px)
                .transition(.opacity)
        }
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                // Neck plug behind the body (fur color), riding the head nudge.
                Ellipse().fill(Color(red: 0xAD / 255, green: 0x5E / 255, blue: 0x36 / 255))   // round 4 fur
                    .frame(width: NutmegPose.neckPlug.width * px, height: NutmegPose.neckPlug.height * px)
                    .position(x: (NutmegPose.neckPlug.midX + pose.headOffset.width) * px,
                              y: (NutmegPose.neckPlug.midY + pose.headOffset.height) * px)
                layer(bodyAsset(pose))
                .transformEffect(pose.bodyTransform.px(px))
                .id(pose).transition(.opacity)
            }
            .frame(width: w, height: h)
            .scaleEffect(x: 1 - (m.breathe - 1) * 0.42, y: m.breathe, anchor: .bottom)
            head(look: l, motion: m)
                .scaleEffect(pose.headScale, anchor: pose.neckAnchor)
                .frame(width: w, height: h)
                // Pose rotation/offset change in the SAME transaction as the body swap (no separate spring, so the
                // head never trails the body). Only the small intentional state tilt eases, scoped to the rotation.
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25)) { $0.rotationEffect(.degrees(m.stateTilt), anchor: pose.neckAnchor) }
                .rotationEffect(.degrees(pose.headRotation + m.headTilt), anchor: pose.neckAnchor)
                .offset(x: pose.headOffset.width * px,
                        // The head rides the breathing neck with at most ~2 pt of follow, plus the talking nod.
                        y: pose.headOffset.height * px + max(pose.headBobsUp ? -2 : 0, min(2, (1 - m.breathe) * h * 0.41))
                            + (pose.headBobsUp ? m.nod : max(0, m.nod)))
            // In front of the head: the crayon (behind the clipboard, so only its top end shows above the edge), then
            // the clipboard and her gripping paws (clipboardBoth layer split, round 5). They breathe with the body.
            ZStack(alignment: .topLeading) {
                crayon(t: t, px: px)
                ForEach(pose.frontLayers, id: \.self) { name in
                    layer(name)
                        // Round 19: the writing fingers rock with the crayon (one writing hand), around the wrist.
                        .rotationEffect(.degrees(name == Self.writingFingers ? writingRock(t: t) : 0), anchor: Self.wrist)
                        .transformEffect(pose.bodyTransform.px(px))
                }
            }
            .frame(width: w, height: h)
            .scaleEffect(x: 1 - (m.breathe - 1) * 0.42, y: m.breathe, anchor: .bottom)
            // Round 22 (Haylee): the Zzz shows in the real doze flow's `.asleep` too (not drowsy/sitting); it fades in as
            // she falls asleep and out when she wakes.
            zzz(t: t, unit: unit)
                .opacity(state.showsZzz ? 1 : 0)
                .animation(.easeInOut(duration: 0.8), value: state.showsZzz)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .scaleEffect(x: squash.width, y: squash.height, anchor: .bottom)
        .offset(y: hop * unit * 4)   // deliberate gestures only (pose-swap hop); no idle/talk bounce
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    private static let writingCrayonAvailable = UIImage(named: "nutmeg-writing-crayon") != nil
    private static let writingShadowAvailable = UIImage(named: "nutmeg-writing-crayon-shadow") != nil
    private static let headsetAvailable = UIImage(named: "nutmeg-headset") != nil

    private func bodyAsset(_ pose: NutmegPose) -> String {
        guard !showsTail, UIImage(named: pose.asset + "-notail") != nil else { return pose.asset }
        return pose.asset + "-notail"
    }

    private func head(look l: NutmegLook, motion m: Motion) -> some View {
        ZStack {
            layer("nutmeg-head-base")   // round 4: head only (no body parts in the export)
            // Oops: the right ear flops over (Haylee's nutmeg-ears-flop art draws over the normal ear).
            if l.ears == .flop { layer(NutmegEars.flop.asset) }
            layer(m.blink && l.face != .nap && l.face != .yay ? NutmegFace.nap.asset : l.face.asset)
            layer(isSpeaking ? (mouthShape ?? NutmegMouth.forLevel(mouthLevel, oohBeat: m.oohBeat)).asset : l.face.mouthAsset)
            if Self.headsetAvailable { layer("nutmeg-headset") }   // on top of the face; moves with the head
            if let costume, UIImage(named: "nutmeg-costume-\(costume)") != nil { layer("nutmeg-costume-\(costume)") }
        }
    }

    /// The writing crayon (round 8: the one-paw writing body's own crayon, drawn under her fingers), in the writing
    /// body's transform. Round 18 stopped its rock (~2.5° around the tip) because the paw (the fingers layer, drawn over
    /// the crayon's middle) stayed still, so only the crayon's ends moved and the middle looked glued to her hand.
    /// Round 19 (Haylee): the writing hand moves as ONE unit: the crayon AND the fingers layer get the same small
    /// scribble, pivoting at the wrist (where the body's arm meets the fingers layer), while the body and clipboard
    /// stay still. Layer order is unchanged (body → crayon → clipboard → fingers). Reduce Motion: still.
    @ViewBuilder private func crayon(t: Double, px: CGFloat) -> some View {
        if shown == .coloring, Self.writingCrayonAvailable {
            // Round 41 (Haylee: the shadow on her vest moved with the hand): the vest shadow (the crayon art's one
            // #470D62 path, moved unchanged into its own layer) stays put on the vest, right under the rocking crayon.
            if Self.writingShadowAvailable {
                layer("nutmeg-writing-crayon-shadow")
                    .transformEffect(NutmegPose.coloring.bodyTransform.px(px))
            }
            layer("nutmeg-writing-crayon")
                .rotationEffect(.degrees(writingRock(t: t)), anchor: Self.wrist)
                .transformEffect(NutmegPose.coloring.bodyTransform.px(px))
        }
    }

    private static let writingFingers = "nutmeg-writing-fingers"
    /// The wrist in the writing art's own canvas (before the body transform): the left edge of the fingers layer
    /// (x 582–675, y 565–682), where the body's arm takes over. Checked at ±3.2° (tools render, round 19): no gap at
    /// the seam (the body art has the paw underneath), and the tip stays at the clipboard's edge.
    private static let wrist = UnitPoint(x: 592 / NutmegPose.canvas.width, y: 640 / NutmegPose.canvas.height)

    /// The writing scribble in degrees: a quick rock (~0.3 s) with a slower drift on top, so it reads as little
    /// strokes rather than a metronome; at most ±3.2°. 0 when not writing or with Reduce Motion.
    private func writingRock(t: Double) -> Double {
        guard writing, !reduceMotion, shown == .coloring else { return 0 }
        return 2.4 * sin(t * 2 * .pi / 0.3) + 0.8 * sin(t * 2 * .pi / 1.3)
    }

    private func layer(_ name: String) -> some View {
        // A layer swap (face, mouth, blink) is instant: never a crossfade riding a camera or pose animation
        // (that showed double eyes during zooms).
        Image(name).resizable().scaledToFit().accessibilityHidden(true)
            .transaction(value: name) { $0.animation = nil }
    }

    private func zzz(t: Double, unit: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                // Reduce Motion: the three z's hold still at staggered spots (no drift), still fading in/out with sleep.
                let phase = reduceMotion ? 0.12 + Double(i) * 0.28
                    : (t / 2.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(Theme.displayFont(CGFloat(60 + i * 20) * unit * 2))
                    .foregroundStyle(Theme.purple)
                    .opacity(1 - phase)
                    // Round 22: a tighter, lower drift hugging her head (was x 720→840, y 240→40), so it stays clear of the
                    // stage star upper right of her (chat open) and the choice buttons at the top.
                    .position(x: (710 + phase * 50) * unit, y: (280 - phase * 170) * unit)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Time-based motion, as plain numbers (degrees, scale, 1024-space points). Resting is nearly still:
/// subtle breathing, a slow small tail sway, and a blink / ear twitch at pseudo-random moments several seconds apart.
/// Bigger motion only while talking (head bob with the voice) or listening (perked, tilted).
private struct Motion {
    var bob: CGFloat = 0, breathe: CGFloat = 1, headTilt: Double = 0, stateTilt: Double = 0, earScale: CGFloat = 1, earTwitch: Double = 0
    var tailSwing: Double = 0, blink = false, oohBeat = false

    /// Deterministic 0…1 noise per integer cycle.
    static func noise(_ n: Double, _ salt: Double) -> Double {
        abs((sin(n * 12.9898 + salt * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1))
    }

    /// Head nod while talking, in screen points (≤ 2).
    var nod: CGFloat = 0

    init(state: NutmegState, t: Double, reduced: Bool, speaking: Bool = false, level: Float = 0) {
        let k: Double = reduced ? 0 : 1
        // Breathing (Haylee): a very subtle scale on the BODY only, anchored at her feet; no vertical translation.
        breathe = CGFloat(IdleMotion.breathe(t, napping: state == .napping || state == .drowsy, reduced: reduced, asleep: state == .asleep))
        tailSwing = 2.5 * sin(t * 0.9) * k
        // Blink: once per 4–7 s window at a random moment, 130 ms long.
        blink = IdleMotion.blink(t)
        // Drowsy (round 9): eyes droop: slow, heavy blinks that stay shut longer each time (0.5 s → 1.1 s of a 1.9 s cycle).
        if state == .drowsy {
            let c = t.truncatingRemainder(dividingBy: 1.9)
            let shut = 0.5 + 0.6 * (0.5 + 0.5 * sin(t * 0.7))
            blink = c > 1.9 - shut
        }
        // Ear twitch: about every 9 s, a quick 160 ms flick (not while napping).
        let eCycle = floor(t / 9)
        let eAt = eCycle * 9 + 1 + Self.noise(eCycle, 2) * 7
        if !state.isSeated, t >= eAt, t - eAt < 0.16 { headTilt += 1.5 * sin((t - eAt) / 0.16 * .pi) * k }
        oohBeat = Int(t * 7) % 7 == 0

        switch state {
        case .listening:
            stateTilt = 3
        case .thinking:
            stateTilt = -4
        case .talking:
            break
        case .excited, .amazed:
            break
        case .oops:
            stateTilt = -5
        case .coloring:
            // Writing: eyes down at the clipboard, an occasional tiny nod (a quick dip about every 1.7 s).
            let c = (t / 1.7).truncatingRemainder(dividingBy: 1)
            if c < 0.18 { nod = CGFloat(2 * sin(c / 0.18 * .pi) * k) }
            headTilt += 1 * sin(t * 1.1) * k
        case .idle, .napping, .sitting:
            break
        case .drowsy:
            stateTilt = -2   // the head starts to nod down
        case .asleep:
            stateTilt = -3
        }
        // Talking: only a very small head nod (≤ 2 pt, ≤ 2°) loosely tied to speech energy; the body stays planted
        // (no whole-body bounce, whatever face she's making).
        if speaking || state == .talking {
            headTilt += 1.5 * sin(t * 5) * k
            nod = -CGFloat(min(1, max(0, level))) * 2 * CGFloat(0.6 + 0.4 * abs(sin(t * 7))) * CGFloat(k)
        }
    }
}

#Preview { NutmegCharacter(state: .idle).padding() }

private extension CGAffineTransform {
    /// This canvas-px transform in screen points (the layers are drawn `px` points per canvas px).
    func px(_ px: CGFloat) -> CGAffineTransform { CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx * px, ty: ty * px) }
}
