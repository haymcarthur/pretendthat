import SwiftUI

// Start screen (Haylee, 2026-11-13): stage curtains part to reveal a toy chest on a cream floor under a soft sky.
// The chest wiggles, the lid pops, toys are tossed out, Nutmeg jumps up inside the chest, then the title card and the
// "Let's play!" button arrive. One clock drives everything: every frame is a pure function of `t`, so the sequence
// can be skipped (tap) or frozen (DEBUG screenshots) by just choosing `t`. Every view is persistent; beats only drive
// offset / scale / rotation / a path (no if/else swaps or identity changes mid-animation, which read as glitches).
// Tapping "Let's play!" runs the exit (`PTStartExit`): Nutmeg jumps out onto the stage where the conversation screen
// shows her, the chest and toys leave, and the same stage (`PTStageBackdrop`) carries on under the game screens.
// Crisp and flat: no gradients, no glows (motion-and-surface.md). Art: design/export/startscreen.

/// When each beat of the opening runs (seconds from launch), ~3.9 s. Round 11 (Haylee): ONE cohesive opening. The
/// chest starts wiggling WHILE the curtains draw back (not after), the lid pops as they finish, the toys overlap
/// (round 8's 0.1 s gap, kept), and the logo card and the "Let's play!" button pop in at the SAME moment as Nutmeg's
/// pop out of the chest, on the SAME curve (`pop(t)`), no staggered entrances after it. A tap skips to the end.
enum PTStartTimeline {
    /// The curtains hold closed for a moment so the launch screen (the same closed curtains) hands over invisibly.
    static let curtains = 0.15...1.95
    /// Round 11: starts while the curtains are still drawing back (they're ~60% open at 1.0 s).
    static let wiggle = 1.0...1.6
    /// Lid squash, swap at `lidSwap`, then the open lid stretches and settles (lid pop = 0.35 s).
    static let lidSquash = 1.6...1.72
    static let lidSwap = 1.72
    static let lidSettle = 1.72...1.95
    static let toysStart = 1.9
    /// Round 8 (Haylee): each toy's own arc is unchanged; the gap between toys is a third of round 7's 0.3 s, so they
    /// overlap.
    static let toyGap = 0.1
    static let toyFlight = 0.6
    static let toyLand = 0.15
    /// Nutmeg's jump (~0.65 s): the chest crouches (anticipation), she shoots up past her resting height, drops back
    /// into the opening and lands with a squash. Starts as the last toy lands (1.9 + 0.5 + 0.6 + 0.15 = 3.15).
    static let crouch = 3.1...3.2
    static let rise = 3.2...3.48
    static let fall = 3.48...3.62
    static let land = 3.62...3.75
    static var jump: ClosedRange<Double> { crouch.lowerBound...land.upperBound }
    /// Round 11: the card (with the logo already whole) and the button use her pop exactly: same start, same length.
    static var pop: ClosedRange<Double> { rise.lowerBound...fall.upperBound }
    static let end = 3.8

    /// Her pop as 0 → overshoot → 1: her rise (ease-out cubic) to the peak, then the drop back to rest. The card and the
    /// button scale on this same curve, so all three arrive as one move. `peak` is how far past 1 the top of the hop is.
    static func pop(_ t: Double, peak: Double) -> Double {
        if t < rise.lowerBound { return 0 }
        if t < fall.lowerBound { return peak * PTEase.outCubic(PTEase.progress(t, rise)) }
        let f = PTEase.progress(t, fall)
        return peak + (1 - peak) * f * f
    }
}

/// The "Let's play!" exit (seconds from the tap, ~1.05 s). Round 11 (Haylee): ONE move that starts on the tap: the
/// card and button pop away, Nutmeg crouches and hops out of the chest, the camera pushes in to the conversation's
/// close-up on the same move (her, the floor and the stage stars share ONE camera transform), the toys scoot off and
/// the step rail and control pill slide in (RootView, on `onExitBegan`), all starting in the same frame. The only
/// thing that waits is the chest's drop: it falls once her feet clear the rim (it would otherwise leave her standing
/// on air inside it).
enum PTStartExit {
    static let popAway = 0.0...0.16
    static let crouch = 0.0...0.16
    static let hop = 0.16...0.78
    static let land = 0.78...0.93
    /// The camera push (arrival framing → the game's first framing), eased like `Theme.stageMove`.
    static let camera = 0.0...1.0
    static let chestOff = 0.32...0.9
    static let toysStart = 0.0
    static let toyGap = 0.0
    static let toyOff = 0.75
    static let end = 1.05
}

/// Round 11: one of the game stage's stars, where the game's first framing draws it (global coordinates).
struct PTStartStageStar { let asset: String; let tilt: Double; let center: CGPoint; let side: CGFloat }

/// What the host should draw for Nutmeg at this moment of the start screen.
struct PTStartNutmeg {
    /// Her tail (hidden while she stands in the chest; it would stick up inside it).
    var tail: Bool
    /// Her ground oval (once she has landed on the stage floor, as the conversation screen draws her).
    var ground: Bool
}

/// The thrown-out toy art: the 8 new toys plus two household props drawn in the same style (style-matched).
enum PTStartArt {
    static let toys = ["toy-block", "toy-ball", "toy-drum", "toy-crown", "toy-star", "toy-rocket", "toy-duck", "toy-top",
                       "prop-stuffed-animal", "prop-toy-car"]
    /// A fixed, varied pick (screenshots and the gallery).
    static let demoToys = ["prop-stuffed-animal", "toy-ball", "toy-block", "prop-toy-car", "toy-duck", "toy-drum"]
}

/// Small easing helpers for the timeline (all take and return 0…1).
enum PTEase {
    static func progress(_ t: Double, _ r: ClosedRange<Double>) -> Double { min(max((t - r.lowerBound) / (r.upperBound - r.lowerBound), 0), 1) }
    static func outCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    /// Ease out with a small overshoot past 1 before settling.
    static func outBack(_ x: Double, _ s: Double = 1.4) -> Double { let p = x - 1; return 1 + (s + 1) * p * p * p + s * p * p }
    static func inOutCubic(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    /// A damped spring over 0…1 (no jitter: one smooth overshoot at most, exactly 1 at x = 1). `damping` 1 = none.
    static func spring(_ x: Double, damping z: Double = 0.7) -> Double {
        func raw(_ t: Double) -> Double {
            let w = 9.0
            if z >= 1 { return 1 - (1 + w * t) * exp(-w * t) }
            let wd = w * sqrt(1 - z * z)
            return 1 - exp(-z * w * t) * (cos(wd * t) + z * w / wd * sin(wd * t))
        }
        let c = min(max(x, 0), 1)
        return raw(c) + c * (1 - raw(1))
    }
    /// 0 → 1 → 0 bump.
    static func bump(_ x: Double) -> Double { sin(x * .pi) }
}

// MARK: - Stage

/// The shared stage every kid screen stands on (Haylee): sky, a cream floor oval, tied-back curtains and the valance.
/// The start screen draws the same pieces (with its curtains animating), so the hand-off into the game is seamless.
enum PTStage {
    /// iPhone version: a portrait stage is the phone's (the iPad app is landscape only, full screen).
    static func isPortrait(_ size: CGSize) -> Bool { size.height > size.width * 1.2 }

    /// The cream floor oval for a full-screen size.
    static func floor(_ size: CGSize) -> CGRect {
        if isPortrait(size) {
            // iPhone (the phone mockups): a broad floor across the lower stage, wider than the screen; it is drawn with
            // an apron (`PTStageFloor.apron`) so the floor reaches the bottom edge behind the cards and the pill.
            let w = size.width * 1.6, h = size.height * 0.30
            return CGRect(x: (size.width - w) / 2, y: size.height * 0.78 - h / 2, width: w, height: h)
        }
        let m = PTCurtain.metrics(size)
        let w = min(size.width - 2 * m.visible + 40, size.height * 1.25)
        let h = size.height * 0.2
        return CGRect(x: (size.width - w) / 2, y: size.height * 0.79 - h / 2, width: w, height: h)
    }
}

/// The wooden stage floor in a rect: a flat darker front rim peeking out below the floor ellipse (no gradient).
struct PTStageFloor: View {
    let rect: CGRect
    /// iPhone version: the floor runs on down to the bottom of the screen (its top stays the oval's curve), so the
    /// cards and the pill below Nutmeg stand on the stage floor (the phone mockups).
    var apron = false
    var body: some View {
        ZStack(alignment: .topLeading) {
            if apron {
                Rectangle().fill(Theme.stageFloor)
                    .frame(width: 6000, height: 3000)
                    .position(x: rect.midX, y: rect.midY + 1500)
            } else {
            Ellipse().fill(Theme.stageFloorEdge).frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY + rect.height * 0.07)
            }
            Ellipse().fill(Theme.stageFloor).frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
        .accessibilityHidden(true)
    }
}

/// Sky + floor (+ open curtains and valance unless `curtains` is false). Full screen; decorative. The conversation
/// stage draws its own floor (`floor: false` here) so the floor zooms with Nutmeg as one camera move.
struct PTStageBackdrop: View {
    var curtains = true
    var floor = true
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Theme.startSky
                if floor { PTStageFloor(rect: PTStage.floor(geo.size), apron: PTStage.isPortrait(geo.size)) }
                if curtains { PTCurtain(progress: 1) }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Curtains

/// The stage curtains as ONE continuous motion (Haylee): `progress` 0 = closed (two straight panels meeting in the
/// middle), 1 = open. Each half slides toward its edge while its inner bottom corner sweeps up and gathers toward the
/// tie-back point, ending as the tied-back swag; no fades and no art swap. Each half is a path we control
/// (`PTCurtainShape`), coral with darker coral folds that bunch up as it gathers, and a gold tie that grows in at the
/// end. The right half is the left half mirrored, so both sides always show exactly the same amount of curtain.
/// The valance art sits on top. The closed state is what LaunchScreen.storyboard shows.
struct PTCurtain: View {
    var progress: Double
    /// Round 18: the stage's above-the-floor curtain copy skips the valance (the backdrop already draws it; two read as a doubled valance).
    var showsValance = true
    /// Round 40 (iPhone): where the open curtains are tied back (y in this view), when the stage asks for a higher tie
    /// than the usual 45% of the height (Nutmeg shrunk above a card: the tie-backs stay beside her, never behind the card).
    var tieY: CGFloat? = nil

    /// Open-state geometry, so content can stay clear of the curtains: `visible` = how far the open swag reaches in
    /// from the screen edge at the top.
    struct Metrics { let width, height, visible, valance: CGFloat }
    static func metrics(_ size: CGSize) -> Metrics {
        let h = min(size.height, size.width * 1.15)
        let w = h * 238 / 448
        return Metrics(width: w, height: h, visible: w * 0.34, valance: min(size.height * 0.075, 70))
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size, m = Self.metrics(s)
            ZStack(alignment: .topLeading) {
                half(s, m)
                half(s, m).scaleEffect(x: -1, y: 1, anchor: .center)
                if showsValance { PTValance(height: m.valance).frame(width: s.width, alignment: .leading).clipped() }
            }
            .frame(width: s.width, height: s.height, alignment: .topLeading)
        }
        .allowsHitTesting(progress < 0.7)
        .accessibilityHidden(true)
    }

    /// The knot's center in tieback-left.svg (art point 604, 169 of 709 x 627).
    static let knot = UnitPoint(x: 0.852, y: 0.270)

    private func half(_ s: CGSize, _ m: Metrics) -> some View {
        let geo = PTCurtainShape.Geometry(size: s, visible: m.visible, progress: progress, tieY: tieY)
        let tie = CGFloat(max(0, (progress - 0.75) / 0.25))
        return ZStack(alignment: .topLeading) {
            PTCurtainShape(geometry: geo).fill(Theme.coral)
            ForEach(Array(PTCurtainShape.folds.enumerated()), id: \.offset) { _, f in
                PTCurtainShape(geometry: geo, fold: f).fill(Theme.curtainFold)
            }
            // Haylee's rope-and-tassel tie-back (round 8, replaces the code-drawn pill), growing in (scale, never alpha)
            // around its knot as the swag gathers. The knot (unit point 0.852, 0.270 of the left art) sits on the tie
            // point; the right half mirrors this whole view, so the left art flips into the right tie-back.
            let tw = m.visible * 1.1, th = tw * 627 / 709
            Image("tieback-left").resizable().accessibilityHidden(true)
                .frame(width: tw, height: th)
                .scaleEffect(max(PTEase.outBack(Double(tie), 1.6), 0.001), anchor: Self.knot)
                .position(x: geo.tieX - (Self.knot.x - 0.5) * tw, y: geo.tieY - (Self.knot.y - 0.5) * th)
        }
        .frame(width: s.width, height: s.height, alignment: .topLeading)
    }
}

/// The left curtain half (or one fold stripe in it) as a function of progress. The inner edge is x(y): a drape curve
/// from the top-inner corner down to the tie point (cosine swoop), then hanging to the bottom-inner corner. Closed,
/// all three points sit on one vertical line at the screen center and the tie point is at the bottom, so the panel is a
/// plain rectangle; opening moves them out and lifts the tie point, which reads as the corner sweeping up.
struct PTCurtainShape: Shape {
    struct Geometry {
        let size: CGSize
        let topX, tieX, tieY, bottomX: CGFloat
        init(size s: CGSize, visible v: CGFloat, progress: Double, tieY openTie: CGFloat? = nil) {
            size = s
            let p = min(max(progress, 0), 1)
            let slide = CGFloat(PTEase.inOutCubic(p))
            let gather = CGFloat(PTEase.inOutCubic(min(p * 1.15, 1)))
            let sweep = CGFloat(PTEase.inOutCubic(min(p * 1.4, 1)))
            let closed = s.width / 2 * 1.02
            topX = closed + (v - closed) * slide
            // Round 10 (Haylee): the tie point sits further in (0.2 → 0.34 of the swag) so the whole tassel shows on both sides.
            tieX = closed + (v * 0.34 - closed) * gather
            tieY = s.height + ((openTie ?? s.height * 0.45) - s.height) * gather
            bottomX = closed + (v * 0.26 - closed) * sweep
        }
        /// Inner edge x at height y.
        func edge(_ y: CGFloat) -> CGFloat {
            if y <= tieY {
                let u = tieY > 0 ? y / tieY : 1
                return tieX + (topX - tieX) * CGFloat(cos(Double(u) * .pi / 2))
            }
            let v = (y - tieY) / max(size.height - tieY, 1)
            return tieX + (bottomX - tieX) * CGFloat(pow(Double(v), 1.3))
        }
    }

    /// Fold stripes: center as a fraction of the local width, half-width as a fraction (from the closed panel art).
    static let folds: [(center: CGFloat, half: CGFloat)] = [(0.21, 0.055), (0.46, 0.05), (0.69, 0.048), (0.9, 0.035)]

    var geometry: Geometry
    var fold: (center: CGFloat, half: CGFloat)? = nil

    func path(in rect: CGRect) -> Path {
        let g = geometry, h = g.size.height
        let n = 72
        let ys = (0...n).map { CGFloat($0) / CGFloat(n) * (h + 2) - 1 }
        var p = Path()
        if let fold {
            // Tapered toward the top so the folds fan out from the rod.
            let left = ys.map { y in CGPoint(x: g.edge(y) * (fold.center - fold.half * (0.55 + 0.45 * y / h)), y: y) }
            let right = ys.map { y in CGPoint(x: g.edge(y) * (fold.center + fold.half * (0.55 + 0.45 * y / h)), y: y) }
            p.addLines(left + right.reversed())
        } else {
            p.move(to: CGPoint(x: -2, y: -1))
            p.addLines([CGPoint(x: -2, y: -1)] + ys.map { CGPoint(x: g.edge($0), y: $0) } + [CGPoint(x: -2, y: h + 1)])
        }
        p.closeSubpath()
        return p
    }
}

/// The scalloped valance art tiled across the top edge.
struct PTValance: View {
    let height: CGFloat
    var body: some View {
        let tile = height * 550 / 104
        HStack(spacing: -1) {
            ForEach(0..<12, id: \.self) { _ in Image("stage-valance").resizable().frame(width: tile, height: height) }
        }
        .fixedSize()
        // A solid band behind the tiles' top edge hides the hairline seams between tiles.
        .background(alignment: .top) { Rectangle().fill(Theme.coral).frame(height: height * 0.4) }
    }
}

// MARK: - Title card and start button

/// The white rounded title card holding the PretendThat logo. `logoTime` drives the logo's build-in (nil = shown).
/// The "Let's play pretend!" line was dropped once the logo arrived (cleaner; the logo already says it); pass a
/// `tagline` to show it small under the logo.
struct PTTitleCard: View {
    var logoTime: Double? = nil
    var logoWidth: CGFloat = 380
    var tagline: String? = nil
    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            PTLogo(time: logoTime).frame(width: logoWidth)
            if let tagline { Text(tagline).font(Theme.bodyFont(Theme.TextSize.body)).foregroundStyle(Theme.inkMuted) }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .ptPanel(radius: Theme.cornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PretendThat")
    }
}

/// Haylee's logo, assembled from its parts (design/export/logo, positions from logo-layout.json) so it can build
/// itself: the PRETEND letters pop in one at a time (quick scale-bounce, 40 ms apart) while "that" fades in and the
/// yellow marks pop, all within ~0.45 s. `time` is seconds since the build started; nil (or Reduce Motion) shows it complete.
struct PTLogo: View {
    var time: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 1484, height: 633)
    private struct Part { let asset: String; let rect: CGRect }
    private static let letters: [Part] = [
        Part(asset: "logo-letter-P", rect: CGRect(x: 0, y: 0, width: 306, height: 462)),
        Part(asset: "logo-letter-R", rect: CGRect(x: 290.3, y: 147.5, width: 217, height: 310)),
        Part(asset: "logo-letter-E1", rect: CGRect(x: 515, y: 155.6, width: 158, height: 297)),
        Part(asset: "logo-letter-T", rect: CGRect(x: 670.2, y: 156, width: 186, height: 299)),
        Part(asset: "logo-letter-E2", rect: CGRect(x: 859.5, y: 159, width: 161, height: 289)),
        Part(asset: "logo-letter-N", rect: CGRect(x: 1028.8, y: 165, width: 218, height: 279)),
        Part(asset: "logo-letter-D", rect: CGRect(x: 1258.8, y: 150.7, width: 225, height: 300))
    ]
    private static let that = Part(asset: "logo-that", rect: CGRect(x: 946, y: 465.3, width: 484, height: 168))
    private static let marks = Part(asset: "logo-marks", rect: CGRect(x: 780.2, y: 10.9, width: 201, height: 122))
    nonisolated static let stagger = 0.04, pop = 0.2
    nonisolated private static let thatFade = 0.18...0.36
    nonisolated private static let marksPop = 0.26...0.46
    nonisolated static var duration: Double { marksPop.upperBound }

    var body: some View {
        let t = (reduceMotion ? nil : time) ?? Self.duration
        GeometryReader { geo in
            let k = geo.size.width / Self.size.width
            ZStack(alignment: .topLeading) {
                ForEach(Array(Self.letters.enumerated()), id: \.offset) { i, part in
                    let p = PTEase.progress(t, (Double(i) * Self.stagger)...(Double(i) * Self.stagger + Self.pop))
                    piece(part, k: k).scaleEffect(p > 0 ? PTEase.outBack(p, 2.4) : 0.01, anchor: .bottom).opacity(p > 0 ? 1 : 0)
                }
                piece(Self.that, k: k).opacity(PTEase.progress(t, Self.thatFade))
                let m = PTEase.progress(t, Self.marksPop)
                piece(Self.marks, k: k).scaleEffect(m > 0 ? PTEase.outBack(m, 2.4) : 0.01, anchor: .bottomLeading).opacity(m > 0 ? 1 : 0)
            }
        }
        .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
        .accessibilityLabel("PretendThat")
    }

    private func piece(_ part: Part, k: CGFloat) -> some View {
        Image(part.asset).resizable()
            .frame(width: part.rect.width * k, height: part.rect.height * k)
            .offset(x: part.rect.minX * k, y: part.rect.minY * k)
    }
}

/// The big start button (round 26, Haylee's button audit: "New game" with a ▶ play icon; grown-ups read the start
/// screen, so it keeps its words): a brand-yellow pill with a dark label, on the same chunky pressable bottom edge as
/// the other primary buttons.
struct PTStartButton: View {
    var title = "New game"
    var width: CGFloat = 300
    var height: CGFloat = 88
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: height * 0.14) {
                Image(systemName: "play.fill").font(.system(size: height * 0.3, weight: .heavy, design: .rounded))
                Text(title).font(Theme.displayFont(height * 0.34)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.ink)
            .frame(width: width, height: height)
        }
        .buttonStyle(StartButtonStyle())
        .accessibilityLabel(title)
    }

    private struct StartButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            let down = configuration.isPressed ? Theme.depth : 0
            configuration.label
                .background(Capsule().fill(Theme.yellow))
                .offset(y: down)
                .background(Capsule().fill(Theme.yellowShade).offset(y: Theme.depth))
                .animation(Theme.press, value: configuration.isPressed)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: configuration.isPressed)
        }
    }
}

/// Round D1 (Haylee, section 11 + mockup state 2): the white button beside the start button, on the same chunky
/// pressable edge (a soft lavender shade). Round 26 (Haylee's button audit): "Saved games" with a yellow ⭐ (the same
/// star that saves a game at The End).
struct PTMyGamesButton: View {
    var width: CGFloat = 252
    var height: CGFloat = 88
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: height * 0.14) {
                Image(systemName: "star.fill").font(.system(size: height * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.yellow)
                Text("Saved games").font(Theme.displayFont(height * 0.32)).foregroundStyle(Theme.purple)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: width, height: height)
        }
        .buttonStyle(MyGamesStyle())
        .accessibilityLabel("Saved games")
    }

    private struct MyGamesStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            let down = configuration.isPressed ? Theme.depth : 0
            configuration.label
                .background(Capsule().fill(Theme.white))
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1.5))
                .offset(y: down)
                .background(Capsule().fill(Theme.lavenderShade).offset(y: Theme.depth))
                .animation(Theme.press, value: configuration.isPressed)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: configuration.isPressed)
        }
    }
}

// MARK: - The scene

/// The start screen: the stage (`PTStageBackdrop` without curtains), sparkles, the toy chest with Nutmeg inside it,
/// tossed toys, the title card at the top and the "Let's play!" button under the chest, framed by `PTCurtain`.
/// Runs the opening once on appear; a tap anywhere skips to the final state; Reduce Motion shows the final state.
/// "Let's play!" runs the exit, then calls `onStart`. `handoff` is where the conversation screen draws Nutmeg's
/// 1178×1335 canvas (global coordinates), so she lands exactly there. `onIntroFinished` fires once the opening is over (or skipped).
struct PTToyChestScene<Nutmeg: View>: View {
    var toys: [String]
    /// DEBUG: hold the sequence at this time (seconds) for screenshots.
    var frozenAt: Double? = nil
    var handoff: CGRect? = nil
    /// Round 11: where the game's FIRST framing draws her (global; the talking close-up when voice is on). The exit
    /// pushes the camera from `handoff` (the arrival framing, the start screen's own scale) to this, so the game
    /// stage takes over at rest with nothing left to zoom. nil = `handoff`.
    var camera: CGRect? = nil
    /// Round 11: the game stage's stars for its first framing (global): they grow in on the exit's camera move.
    var stageStars: [PTStartStageStar] = []
    /// Fires on the tap, when the exit starts (RootView slides the rail and pill in on the same move).
    var onExitBegan: () -> Void = {}
    var onIntroFinished: () -> Void = {}
    /// Round D1 (Haylee, section 11): once a game is saved, a white "My games" button sits beside Let's play!.
    var onMyGames: (() -> Void)? = nil
    /// Round D2: the small "Grown-ups" pill in the top-right corner (always there on the start screen).
    var onGrownUps: (() -> Void)? = nil
    /// Round 33: asked on the tap, before the exit runs (no AI consent, or the Free Preview used up: false).
    var canStart: () -> Bool = { true }
    let onStart: () -> Void
    @ViewBuilder var nutmeg: (_ look: PTStartNutmeg) -> Nutmeg

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var skipped = false
    @State private var finished = false
    @State private var exitStart: Date?

    private typealias T = PTStartTimeline
    private typealias X = PTStartExit
    /// iPhone version: the window's safe area (this scene ignores it; the phone layout keeps its buttons inside).
    @Environment(\.ptSafeInsets) private var safeArea

    var body: some View {
        let paused = (frozenAt != nil || skipped || finished || reduceMotion) && exitStart == nil
        TimelineView(.animation(minimumInterval: nil, paused: paused)) { ctx in
            let t = time(ctx.date)
            let e = exitStart.map { min(ctx.date.timeIntervalSince($0), X.end) } ?? -1
            GeometryReader { geo in scene(t: t, e: e, size: geo.size, origin: geo.frame(in: .global).origin) }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { if !skipped && !finished && exitStart == nil { skipped = true; onIntroFinished() } }
        .onAppear { start = Date() }
        .task {
            if let frozenAt { if frozenAt >= T.end { onIntroFinished() }; return }
            if !reduceMotion { try? await Task.sleep(for: .seconds(T.end + 0.05)) }
            finished = true
            if !skipped { onIntroFinished() }
            #if DEBUG
            if DemoDriver.autoStart { try? await Task.sleep(for: .seconds(1)); play() }
            #endif
        }
    }

    private func time(_ now: Date) -> Double {
        if let frozenAt { return frozenAt }
        if skipped || finished || reduceMotion { return T.end }
        return min(now.timeIntervalSince(start), T.end)
    }

    private func play() {
        guard exitStart == nil, canStart() else { return }
        if reduceMotion { onStart(); return }
        skipped = true
        exitStart = Date()
        onExitBegan()
        Task {
            try? await Task.sleep(for: .seconds(X.end))
            onStart()
        }
    }

    // MARK: Layout

    private struct Layout {
        let size: CGSize
        let curtain: PTCurtain.Metrics
        let floor: CGRect
        /// Chest frame (650×620 art frame shared by the body, lids and clasp).
        let chestW, chestH, cx, chestBottom, chestTop, frontY: CGFloat
        /// Nutmeg's canvas scale in the chest (1178×1335 canvas) and the screen y of her ear tips there.
        let nutmegScale, earsTop: CGFloat
        let toy: CGFloat
        /// Title card top and logo width (the card never reaches her ears), and the start button frame.
        let cardTop, logoW: CGFloat
        let button: CGRect
        /// Round D1: the "My games" button beside it (nil: no saved games, Let's play! stays centered).
        let myGames: CGRect?
        /// Both buttons together (toys keep clear of them).
        var buttons: CGRect { myGames.map { button.union($0) } ?? button }
        /// iPhone version (screens 1 and 1b of the phone mockups): one tall stage, the Grown-ups gear over the logo
        /// card, a bigger chest, two toys, and New game (+ Saved games under it) at the bottom where a thumb rests.
        let phone: Bool
        /// Home stage polish (Haylee, 2026-11-17): the Grown-ups gear, tucked into the top-trailing corner just under
        /// the safe area (clear of the Dynamic Island and the rounded screen corner), in front of the curtain.
        let gear: CGRect

        init(_ s: CGSize, pair: Bool = false, safeTop: CGFloat = 0, safeBottom: CGFloat = 0) {
            size = s
            curtain = PTCurtain.metrics(s)
            floor = PTStage.floor(s)
            phone = PTStage.isPortrait(s)
            let gearSide: CGFloat = phone ? 48 : 56, gearInset: CGFloat = phone ? 14 : 22
            let gearTop = phone ? max(safeTop, 12) + 4 : max(safeTop + 8, gearInset)
            gear = CGRect(x: s.width - gearInset - gearSide, y: gearTop, width: gearSide, height: gearSide)
            if phone {
                chestW = min(s.width * 0.62, s.height * 0.3)
                chestH = chestW * 620 / 650
                cx = s.width / 2
                chestBottom = floor.minY + floor.height * 0.36
                chestTop = chestBottom - chestH * 616 / 620
                frontY = chestTop + chestH * 378 / 620
                nutmegScale = 0.6 * chestW * 0.945 / 730
                earsTop = frontY - (1030 - 10) * nutmegScale
                toy = chestW * 0.3
                let bw = min(320, s.width * 0.66)
                let bottom = s.height - max(safeBottom, 16) - 22
                if pair {
                    // Screen 1b: New game moves up a little; a smaller Saved games sits under it.
                    let sw = min(260, s.width * 0.52), sh: CGFloat = 60
                    myGames = CGRect(x: cx - sw / 2, y: bottom - sh, width: sw, height: sh)
                    button = CGRect(x: cx - bw / 2, y: bottom - sh - Theme.Space.m - 76, width: bw, height: 76)
                } else {
                    button = CGRect(x: cx - bw / 2, y: bottom - 80, width: bw, height: 80)
                    myGames = nil
                }
                // The card sits under the gear's row (the phone is too narrow for both side by side).
                cardTop = max(gear.maxY, curtain.valance) + Theme.Space.s
                let pad = 2 * Theme.Space.m
                let maxCardH = max(earsTop - Theme.Space.m - 8 - cardTop, 80) / 1.05
                logoW = max(min(s.width * 0.6, 300, (maxCardH - pad) * PTLogo.size.width / PTLogo.size.height), 120)
                return
            }
            chestW = min(s.width * 0.36, s.height * 0.38)
            chestH = chestW * 620 / 650
            cx = s.width / 2
            chestBottom = floor.midY + floor.height * 0.1
            chestTop = chestBottom - chestH * 616 / 620
            // Front edge of the chest opening (art y 378 in the regenerated box): Nutmeg is hidden below this line.
            frontY = chestTop + chestH * 378 / 620
            // Her body (canvas 172–900 px wide) fills ~60% of the chest; at rest her waist (canvas y ≈ 1030) sits on
            // the front edge and her ear tips are at canvas y ≈ 10.
            nutmegScale = 0.6 * chestW * 0.945 / 730
            earsTop = frontY - (1030 - 10) * nutmegScale
            toy = chestW * 0.27
            // Start button: centered under the chest, above the bottom edge.
            let bw = min(300, s.width * 0.3), bh: CGFloat = 88
            if pair {
                // Round D1 (approved mockup state 2): the pair is centered under the chest, My games a little narrower.
                let gap = Theme.Space.m, mw = bw   // round 26: "Saved games" is as wide as "New game"
                let left = cx - (bw + gap + mw) / 2
                button = CGRect(x: left, y: s.height - 28 - bh, width: bw, height: bh)
                myGames = CGRect(x: left + bw + gap, y: s.height - 28 - bh, width: mw, height: bh)
            } else {
                button = CGRect(x: cx - bw / 2, y: s.height - 28 - bh, width: bw, height: bh)
                myGames = nil
            }
            // Card: under the valance, its bottom (with the pop's overshoot) clear of her ears.
            cardTop = curtain.valance + Theme.Space.m
            let pad = 2 * Theme.Space.m
            let maxCardH = max(earsTop - Theme.Space.m - 8 - cardTop, 80) / 1.05
            logoW = max(min(s.width * 0.32, 400, (maxCardH - pad) * PTLogo.size.width / PTLogo.size.height), 140)
        }

        /// Where toy i lands (its bottom center): left and right of the chest, inside the floor, clear of the curtains
        /// and of the start button.
        func spot(_ i: Int) -> CGPoint {
            if phone {
                // Two toys at the chest's front corners (the phone is too narrow for six).
                let dx: CGFloat = i % 2 == 0 ? -0.5 : 0.5
                return CGPoint(x: cx + dx * chestW, y: min(chestBottom + chestW * 0.1, button.minY - 8))
            }
            let spots: [(CGFloat, CGFloat)] = [(-0.64, 0.05), (0.66, 0.06), (-0.96, -0.14), (0.98, -0.13), (-1.16, 0.12), (1.16, 0.13)]
            let (dx, dy) = spots[i % spots.count]
            let maxDx = min(floor.width / 2 - toy * 0.6, size.width / 2 - curtain.visible * 1.25 - toy * 0.6)
            let k = min(1, maxDx / (chestW * 1.12))
            var y = chestBottom + dy * chestW
            let x = cx + dx * chestW * k
            // Never over the button: toys in its column stay above it.
            if x > buttons.minX - toy * 0.6 && x < buttons.maxX + toy * 0.6 { y = min(y, button.minY - 10) }
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: Exit camera

    /// The exit's camera push at time `e` as one uniform scale + move, in a view whose global origin is `origin`:
    /// identity before the tap, the arrival → first-framing move (`handoff` → `camera`) at the end. Nutmeg and the floor
    /// both go through it, so their relative size never changes.
    struct ExitCamera {
        var m: CGFloat = 1, t: CGPoint = .zero
        func apply(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * m + t.x, y: p.y * m + t.y) }
        func apply(_ r: CGRect) -> CGRect { let o = apply(r.origin); return CGRect(x: o.x, y: o.y, width: r.width * m, height: r.height * m) }
    }
    private func exitCamera(_ e: Double, origin: CGPoint) -> ExitCamera {
        guard e >= 0, let a = handoff, let b = camera, a.height > 0 else { return ExitCamera() }
        let c = CGFloat(PTEase.spring(PTEase.progress(e, X.camera), damping: 0.84))
        let k = b.height / a.height
        // Global: p' = b.origin + (p - a.origin) k; blended with identity by c; then expressed in local coordinates.
        let m = 1 + c * (k - 1)
        let tg = CGPoint(x: c * (b.minX - a.minX * k), y: c * (b.minY - a.minY * k))
        return ExitCamera(m: m, t: CGPoint(x: tg.x + origin.x * m - origin.x, y: tg.y + origin.y * m - origin.y))
    }

    // MARK: Drawing

    @ViewBuilder private func scene(t: Double, e: Double, size: CGSize, origin: CGPoint) -> some View {
        let L = Layout(size, pair: onMyGames != nil, safeTop: safeArea.top, safeBottom: safeArea.bottom)
        ZStack(alignment: .topLeading) {
            // Round 11: the floor is under the exit's camera (the same transform as Nutmeg), so it ends exactly where the
            // game stage draws it for its first framing.
            PTStageBackdrop(curtains: false, floor: false)
            PTStageFloor(rect: exitCamera(e, origin: origin).apply(L.floor), apron: L.phone)
            sky(L, e: e)
            chest(t: t, e: e, L, origin: origin)
                .position(x: L.cx, y: L.chestTop + L.chestH / 2)
            ZStack {
                ForEach(Array(toys.prefix(L.phone ? 2 : 6).enumerated()), id: \.offset) { i, name in
                    toyView(name, i: i, t: t, e: e, L).zIndex(Double(L.spot(i).y))   // nearer toys in front
                }
            }
            exitStars(e: e, origin: origin)
            startButton(t: t, e: e, L)
            myGamesButton(t: t, e: e, L)
            PTCurtain(progress: PTEase.progress(t, T.curtains))
            // Home stage polish (Haylee, 2026-11-17): the logo card is in front of the curtain panels (it pops in after
            // they have opened, so it's in front for the whole choreography), and so is the Grown-ups gear.
            titleCard(t: t, e: e, L)
            grownUpsGear(t: t, e: e, L)
        }
        .frame(width: size.width, height: size.height)
    }

    /// Round 11: the game stage's stars grow in on the exit's camera move, ending exactly where the game draws them.
    private func exitStars(e: Double, origin: CGPoint) -> some View {
        let c = e < 0 ? 0 : PTEase.spring(PTEase.progress(e, X.camera), damping: 0.84)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(stageStars.enumerated()), id: \.offset) { _, s in
                Image(s.asset).resizable().scaledToFit()
                    .rotationEffect(.degrees(s.tilt))
                    .frame(width: s.side, height: s.side)
                    .scaleEffect(max(0.001, 0.2 + 0.8 * c))
                    .opacity(min(c * 3, 1))
                    .position(x: s.center.x - origin.x, y: s.center.y - origin.y)
            }
        }
        .accessibilityHidden(true)
    }

    /// 5 static stage stars and sparkles in the upper sky, clear of the curtains and the title card. They pop away on
    /// the exit (the conversation stage has its own).
    private func sky(_ L: Layout, e: Double) -> some View {
        let spots: [(String, CGFloat, CGFloat, CGFloat, Double)] = [
            ("stage-star", 0.08, 0.30, 0.075, -12), ("stage-sparkle", 0.22, 0.48, 0.045, 0),
            ("stage-star", 0.90, 0.26, 0.065, 14), ("stage-sparkle", 0.80, 0.47, 0.05, 0),
            ("stage-sparkle", 0.30, 0.22, 0.035, 0)
        ]
        let side = min(L.size.width, L.size.height)
        let left = L.curtain.visible, span = L.size.width - 2 * L.curtain.visible
        let away = max(0.001, 1 - PTEase.progress(e, X.popAway))
        // iPhone (Haylee, 2026-11-17: "a star behind the logo"): the tall layout's title card covers the upper sky, so the
        // stars and sparkles sit in the open sky between the card's bottom and Nutmeg's ears instead.
        let cardBottom = L.cardTop + (L.logoW * PTLogo.size.height / PTLogo.size.width + 2 * Theme.Space.m) * 1.05
        let gapTop = cardBottom + side * 0.04, gapBottom = max(L.earsTop - side * 0.02, gapTop + 1)
        func y(_ frac: CGFloat) -> CGFloat {
            guard L.phone else { return L.size.height * frac }
            // Map the iPad's 0.22…0.48 band onto the open sky under the card.
            let t = min(max((frac - 0.22) / 0.26, 0), 1)
            return gapTop + (gapBottom - gapTop) * t
        }
        return ZStack {
            ForEach(Array(spots.enumerated()), id: \.offset) { i, s in
                Image(s.0).resizable().scaledToFit()
                    .frame(width: side * s.3, height: side * s.3)
                    .rotationEffect(.degrees(s.4))
                    .scaleEffect(away)
                    .position(x: left + span * s.1, y: y(s.2))
            }
        }
        .accessibilityHidden(true)
    }

    /// Body + lids + Nutmeg, in the chest's own 650×620 frame. Layering: open lid (behind) → body (interior and front
    /// panel) → Nutmeg (masked at the opening's front edge so the front panel hides her below it) → closed lid. The
    /// brackets and clasp exist once, on the lids. Both lids are always in the tree; the swap at `lidSwap` is opacity
    /// only (same frame, no layout change).
    private func chest(t: Double, e: Double, _ L: Layout, origin: CGPoint) -> some View {
        let w = L.chestW, h = L.chestH
        // (1) Wiggle: two small shakes.
        let wp = PTEase.progress(t, T.wiggle)
        let wiggle = (wp > 0 && wp < 1) ? sin(wp * .pi * 4) * 4 * (1 - wp * 0.4) : 0
        // (2) Lid pop: squash down, then the body stretches up as the lid flies open.
        let sq = PTEase.bump(PTEase.progress(t, T.lidSquash))
        let st = PTEase.bump(PTEase.progress(t, T.lidSwap...(T.lidSwap + 0.15)))
        // (4) Nutmeg's anticipation: the chest crouches, then springs up as she launches.
        let cr = PTEase.bump(PTEase.progress(t, T.crouch))
        let kick = PTEase.bump(PTEase.progress(t, T.rise.lowerBound...(T.rise.lowerBound + 0.12)))
        let bodyScale = CGSize(width: 1 + 0.05 * sq - 0.02 * st + 0.04 * cr - 0.015 * kick,
                               height: 1 - 0.07 * sq + 0.05 * st - 0.06 * cr + 0.03 * kick)
        let open = t >= T.lidSwap
        let lp = PTEase.progress(t, T.lidSettle)
        let lidStretch = 0.6 + 0.4 * PTEase.outBack(lp, 2.2)
        // Exit: the chest (not Nutmeg) drops away off the bottom, shrinking back a little.
        let off = PTEase.progress(e, X.chestOff)
        let drop = CGFloat(off * off) * (L.size.height - L.chestTop + 40)
        let back = 1 - 0.12 * off
        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Image("chest-lid-open").resizable().frame(width: w, height: h)
                    .scaleEffect(x: 1, y: lidStretch, anchor: UnitPoint(x: 0.5, y: 307 / 620))
                    .opacity(open ? 1 : 0)
                Image("chest-body").resizable().frame(width: w, height: h)
            }
            .scaleEffect(back, anchor: .bottom).offset(y: drop)
            nutmegLayer(t: t, e: e, L, origin: origin)
            // The box has no top hardware (Haylee's regenerated chest-body); the clasp and brackets live on the lids, so
            // they show once whether the lid is closed or open.
            Image("chest-lid-closed").resizable().frame(width: w, height: h)
                .opacity(open ? 0 : 1)
                .scaleEffect(back, anchor: .bottom).offset(y: drop)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .scaleEffect(x: bodyScale.width, y: bodyScale.height, anchor: UnitPoint(x: 0.5, y: 616 / 620))
        .rotationEffect(.degrees(wiggle), anchor: UnitPoint(x: 0.5, y: 616 / 620))
        .accessibilityHidden(true)
    }

    /// Nutmeg, one persistent view (idle pose holding her clipboard throughout; no pose swaps on this screen).
    /// (4) Intro: hidden below the front edge, she shoots up (stretching) until most of her body is above the rim, drops
    /// back and lands waist-deep with a squash. Exit: crouch, a big hop up and out of the chest, landing on the stage
    /// exactly at `handoff` (her conversation-screen frame), growing to that size on the way. She is laid out at the
    /// larger of the two sizes and scaled down, so her vectors stay crisp at the end. The mask's bottom edge is the
    /// chest's front edge until she is above it on the way out; then it drops away (offset, not a modifier swap).
    private func nutmegLayer(t: Double, e: Double, _ L: Layout, origin: CGPoint) -> some View {
        let s = L.nutmegScale
        let nW = 1178 * s, nH = 1335 * s
        // Chest-local frame of the conversation canvas (bottom center + height).
        let chestOrigin = CGPoint(x: L.cx - L.chestW / 2 - origin.x, y: L.chestTop - origin.y)
        let target = handoff.map { CGRect(x: $0.minX - chestOrigin.x, y: $0.minY - chestOrigin.y, width: $0.width, height: $0.height) }
        let bigH = max(nH, target?.height ?? nH, camera?.height ?? nH)
        let base = nH / bigH
        // Intro (relative to her resting bottom-center: x = chest center + 19 canvas px, waist on the front edge).
        let hidden = (1335 - 10) * s + 6
        let rest = (1335 - 1030) * s
        let peak = rest - 0.16 * nH
        // Round 11: the same pop curve the card and the button use (T.pop), so all three arrive as one move.
        let y = hidden + (rest - hidden) * CGFloat(T.pop(t, peak: Double((hidden - peak) / (hidden - rest))))
        let stretch = PTEase.bump(PTEase.progress(t, T.rise.lowerBound...T.fall.upperBound))
        let landing = PTEase.bump(PTEase.progress(t, T.land))
        var sx = 1 - 0.05 * stretch + 0.07 * landing, sy = 1 + 0.07 * stretch - 0.08 * landing
        var x = L.chestW / 2 + 19 * s
        var bottom = L.frontY - L.chestTop + y
        var scale = base
        // Exit hop.
        let crouch = PTEase.bump(PTEase.progress(e, X.crouch))
        let hp = PTEase.progress(e, X.hop)
        let land2 = PTEase.bump(PTEase.progress(e, X.land))
        if e >= 0, let target {
            let to = CGPoint(x: target.midX, y: target.maxY)
            let ease = CGFloat(PTEase.inOutCubic(hp))
            x += (to.x - x) * ease
            // Just high enough that her feet clear the rim at the top of the hop (she grows on the way, so a bigger arc
            // would carry her head off the top of the screen).
            let from = bottom, rim = L.frontY - L.chestTop
            let lift = max(0, (from + to.y) / 2 - (rim - 12)) + nH * 0.02
            bottom = from + (to.y - from) * CGFloat(hp) - lift * CGFloat(4 * hp * (1 - hp))
            // Grows mostly on the way down (smaller at the top of the hop, so her ears stay on screen).
            scale = base + (target.height / bigH - base) * CGFloat(hp * hp)
            sx *= 1 + 0.06 * crouch - 0.04 * PTEase.bump(hp) + 0.06 * land2
            sy *= 1 - 0.09 * crouch + 0.07 * PTEase.bump(hp) - 0.07 * land2
        }
        let out = hp > 0.5
        // Round 11: the camera push (same transform as the floor), in chest-local coordinates.
        let cam = exitCamera(e, origin: CGPoint(x: origin.x + L.cx - L.chestW / 2, y: origin.y + L.chestTop))
        let foot = cam.apply(CGPoint(x: x, y: bottom))
        x = foot.x; bottom = foot.y; scale *= cam.m
        return nutmeg(PTStartNutmeg(tail: e >= 0, ground: hp >= 1))
            .frame(width: 1178 / 1335 * bigH, height: bigH)
            .scaleEffect(x: scale * sx, y: scale * sy, anchor: .bottom)
            .frame(width: 1178 / 1335 * bigH, height: bigH)
            .position(x: x, y: bottom - bigH / 2)
            .mask(alignment: .topLeading) {
                Rectangle()
                    .frame(width: 8000, height: 8000)
                    .offset(x: -4000, y: L.frontY - L.chestTop - 8000 + (out ? 6000 : 0))
            }
            .frame(width: L.chestW, height: L.chestH, alignment: .topLeading)
    }

    /// (3) Toy i is tossed out of the chest in an arc with a spin and lands on the floor with a little bounce; on the
    /// exit it scoots off its side of the screen. Always in the tree (hidden until its throw).
    private func toyView(_ name: String, i: Int, t: Double, e: Double, _ L: Layout) -> some View {
        let t0 = T.toysStart + Double(i) * T.toyGap
        let p = PTEase.progress(t, t0...(t0 + T.toyFlight))
        let end = L.spot(i)
        let from = CGPoint(x: L.cx + CGFloat(i % 2 == 0 ? -1 : 1) * L.chestW * 0.08, y: L.frontY)
        let x = from.x + (end.x - from.x) * CGFloat(p)
        let base = from.y + (end.y - L.toy / 2 - from.y) * CGFloat(p)
        let arc = L.size.height * 0.24 * CGFloat(4 * p * (1 - p))
        let dir: Double = end.x < L.cx ? -1 : 1
        let tilt = [-8.0, 6, 10, -6, 4, -10][i % 6]
        let spin = dir * 360 * (1 - PTEase.outCubic(p)) + tilt
        let land = PTEase.bump(PTEase.progress(t, (t0 + T.toyFlight)...(t0 + T.toyFlight + T.toyLand)))
        let grow = 0.45 + 0.55 * min(p * 3, 1)
        // Exit: nearest-to-the-edge toys go first, slightly staggered.
        let order = Double(5 - min(i, 5)) * X.toyGap
        let q = PTEase.progress(e, (X.toysStart + order)...(X.toysStart + order + X.toyOff))
        let scoot = CGFloat(dir) * (L.size.width / 2 + L.toy) * CGFloat(q * q)
        return Image(name).resizable().scaledToFit()
            .frame(width: L.toy, height: L.toy)
            .scaleEffect(x: grow * (1 + 0.08 * land), y: grow * (1 - 0.1 * land), anchor: .bottom)
            .rotationEffect(.degrees(spin + dir * 20 * q))
            .position(x: x + scoot, y: base - arc)
            .opacity(p > 0 ? 1 : 0)
            .accessibilityHidden(true)
    }

    /// The card and button overshoot a little less than her hop (her peak is ~1.2 of the way; UI 1.15 reads as a pop).
    private static var uiPeak: Double { 1.15 }

    /// (5) The title card pops (scales up from small) centered at the top while the logo builds on it; it pops away on
    /// the exit. Fixed layout: only scale and opacity change.
    private func titleCard(t: Double, e: Double, _ L: Layout) -> some View {
        // Round 11: pops with Nutmeg (same start, same curve); the logo is whole as it arrives (no letter build after).
        let k = T.pop(t, peak: Self.uiPeak)
        let away = PTEase.progress(e, X.popAway)
        let scale = (0.4 + 0.6 * k) * (1 - 0.6 * away)
        return PTTitleCard(logoTime: nil, logoWidth: L.logoW)
            .scaleEffect(max(scale, 0.001))
            .opacity(min(k * 6, 1) * (1 - away))
            .frame(width: L.size.width)
            .padding(.top, L.cardTop)
            .frame(width: L.size.width, height: L.size.height, alignment: .top)
    }

    /// Round D1: "My games" pops in with Let's play! and pops away on its exit.
    @ViewBuilder private func myGamesButton(t: Double, e: Double, _ L: Layout) -> some View {
        if let r = L.myGames, let onMyGames {
            let k = T.pop(t, peak: Self.uiPeak)
            let away = PTEase.progress(e, X.popAway)
            let scale = (k > 0 ? 0.4 + 0.6 * k : 0.001) * (1 - 0.6 * away)
            PTMyGamesButton(width: r.width, height: r.height, action: onMyGames)
                .scaleEffect(max(scale, 0.001))
                .opacity(min(k * 6, 1) * (1 - away))
                .allowsHitTesting(t >= T.pop.upperBound && e < 0)
                .position(x: r.midX, y: r.midY)
        }
    }

    /// Round D2: the quiet Grown-ups corner; home stage polish (Haylee, 2026-11-17): a gear icon only, tucked into the
    /// top-trailing corner. It fades in with the buttons and away on the exit.
    @ViewBuilder private func grownUpsGear(t: Double, e: Double, _ L: Layout) -> some View {
        if let onGrownUps {
            let k = T.pop(t, peak: Self.uiPeak)
            let away = PTEase.progress(e, X.popAway)
            PTGrownUpsGear(size: L.gear.width, action: onGrownUps)
                .opacity(min(k * 3, 1) * (1 - away))
                .allowsHitTesting(t >= T.pop.upperBound && e < 0)
                .position(x: L.gear.midX, y: L.gear.midY)
        }
    }

    /// The "Let's play!" button pops in last, centered under the chest, and pops away when tapped.
    private func startButton(t: Double, e: Double, _ L: Layout) -> some View {
        // Round 11: pops with Nutmeg and the card (same start, same curve).
        let k = T.pop(t, peak: Self.uiPeak)
        let away = PTEase.progress(e, X.popAway)
        let scale = (k > 0 ? 0.4 + 0.6 * k : 0.001) * (1 - 0.6 * away)
        return PTStartButton(width: L.button.width, height: L.button.height, action: play)
            .scaleEffect(max(scale, 0.001))
            .opacity(min(k * 6, 1) * (1 - away))
            .allowsHitTesting(t >= T.pop.upperBound && e < 0)
            .position(x: L.button.midX, y: L.button.midY)
    }
}
