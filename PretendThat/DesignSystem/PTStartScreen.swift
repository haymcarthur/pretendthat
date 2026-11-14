import SwiftUI

// Start screen (Haylee, 2026-11-13): stage curtains part to reveal a toy chest on a cream floor under a soft sky.
// The chest wiggles, the lid pops, toys are tossed out, Nutmeg hops up out of the chest and waves, then the title
// card and start button arrive. One clock drives everything: every frame is a pure function of `t`, so the
// sequence can be skipped (tap) or frozen (DEBUG screenshots) by just choosing `t`. Crisp and flat: no gradients,
// no glows (motion-and-surface.md). Art: design/export/startscreen (chest, lids and toys share their own frames).

/// When each beat of the opening runs (seconds from launch). Total under 4 s.
enum PTStartTimeline {
    static let curtains = 0.0...0.9
    static let wiggle = 0.95...1.35
    /// Lid squash, swap at `lidSwap`, then the open lid stretches and settles.
    static let lidSquash = 1.35...1.45
    static let lidSwap = 1.45
    static let lidSettle = 1.45...1.75
    static let toysStart = 1.55
    static let toyGap = 0.12
    static let toyFlight = 0.55
    static let jump = 2.45...2.95
    static let land = 2.95...3.15
    static let wave = 3.05...3.9
    static let card = 2.9...3.3
    /// The logo builds itself on the card from here (letters, then "that", then the marks; see `PTLogo`).
    static let logo = 3.1
    static let button = 3.3...3.65
    static let end = 3.1 + PTLogo.duration
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
    /// 0 → 1 → 0 bump.
    static func bump(_ x: Double) -> Double { sin(x * .pi) }
}

// MARK: - Curtains

/// The stage curtains. `progress` 0 = closed (two straight panels covering the screen), 1 = open and framed (tied-back
/// curtains at the left/right edges under a scalloped valance). The panels slide apart with a small overshoot and
/// crossfade into the tied-back art as they reach the edges. Art: curtain-closed-left/right (stretched vertically to
/// any screen; the folds are vertical so they don't distort), stage-curtain-left/right, stage-valance (tiled).
struct PTCurtain: View {
    var progress: Double

    /// Framed-state geometry, so content can stay clear of the curtains.
    struct Metrics { let width, height, visible, valance: CGFloat }
    static func metrics(_ size: CGSize) -> Metrics {
        let h = min(size.height, size.width * 1.15)
        let w = h * 238 / 448
        return Metrics(width: w, height: h, visible: w * 0.34, valance: min(size.height * 0.075, 70))
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size, m = Self.metrics(s)
            let panelW = s.width / 2 * 1.06, panelH = s.height / 0.97
            // The panels gather toward the edges (they narrow, folds bunching up) with a small overshoot.
            let gathered = m.visible * 0.9
            let slide = CGFloat(PTEase.outBack(min(max(progress, 0), 1), 1.1))
            let width = max(panelW + (gathered - panelW) * slide, gathered * 0.6)
            let framed = PTEase.progress(progress, 0.72...0.97)
            ZStack(alignment: .topLeading) {
                Image("curtain-closed-left").resizable()
                    .frame(width: width, height: panelH)
                    .offset(x: -width * 0.03)
                    .opacity(1 - framed)
                Image("curtain-closed-right").resizable()
                    .frame(width: width, height: panelH)
                    .offset(x: s.width - width * 0.97)
                    .opacity(1 - framed)
                Image("stage-curtain-left").resizable()
                    .frame(width: m.width, height: m.height)
                    .offset(x: m.visible - m.width)
                    .opacity(framed)
                Image("stage-curtain-right").resizable()
                    .frame(width: m.width, height: m.height)
                    .offset(x: s.width - m.visible)
                    .opacity(framed)
                PTValance(height: m.valance).frame(width: s.width, alignment: .leading).clipped()
            }
            .frame(width: s.width, height: s.height, alignment: .topLeading)
        }
        .allowsHitTesting(progress < 0.7)
        .accessibilityHidden(true)
    }
}

/// The scalloped valance art tiled across the top edge.
private struct PTValance: View {
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
/// itself: the PRETEND letters pop in one at a time (quick scale-bounce, 60 ms apart), then "that" fades in, then the
/// yellow marks pop. `time` is seconds since the build started; nil (or Reduce Motion) shows it complete.
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
    nonisolated static let stagger = 0.06, pop = 0.24
    nonisolated private static let thatFade = (7 * stagger + 0.1)...(7 * stagger + 0.35)
    nonisolated private static let marksPop = (thatFade.upperBound - 0.08)...(thatFade.upperBound + 0.2)
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

/// The big round yellow start button with a dark arrow (chunky 3D bottom edge like the other buttons).
struct PTStartButton: View {
    var size: CGFloat = 120
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.right")
                .font(.system(size: size * 0.4, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
        }
        .buttonStyle(StartButtonStyle(size: size))
        .accessibilityLabel("Start")
    }

    private struct StartButtonStyle: ButtonStyle {
        let size: CGFloat
        func makeBody(configuration: Configuration) -> some View {
            let down = configuration.isPressed ? Theme.depth : 0
            configuration.label
                .background(Circle().fill(Theme.yellow))
                .offset(y: down)
                .background(Circle().fill(Theme.yellowShade).offset(y: Theme.depth))
                .animation(Theme.press, value: configuration.isPressed)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: configuration.isPressed)
        }
    }
}

// MARK: - The scene

/// The start screen: sky, floor, sparkles, the toy chest with Nutmeg inside it, tossed toys, the title card and
/// start button, framed by `PTCurtain`. Runs the opening once on appear; a tap anywhere skips to the final state;
/// Reduce Motion fades straight to the final state. `nutmeg(waving)` draws her (the scene positions and masks her).
struct PTToyChestScene<Nutmeg: View>: View {
    var toys: [String]
    /// DEBUG: hold the sequence at this time (seconds) for screenshots.
    var frozenAt: Double? = nil
    let onStart: () -> Void
    @ViewBuilder var nutmeg: (_ waving: Bool) -> Nutmeg

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var skipped = false
    @State private var finished = false
    @State private var shown = false

    private typealias T = PTStartTimeline

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: frozenAt != nil || skipped || finished || reduceMotion)) { ctx in
            let t = time(ctx.date)
            GeometryReader { geo in scene(t: t, size: geo.size) }
        }
        .ignoresSafeArea()
        .opacity(reduceMotion ? (shown ? 1 : 0) : 1)
        .contentShape(Rectangle())
        .onTapGesture { skipped = true }
        .onAppear {
            start = Date()
            withAnimation(.easeOut(duration: 0.5)) { shown = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(T.end + 0.05))
            finished = true
        }
    }

    private func time(_ now: Date) -> Double {
        if let frozenAt { return frozenAt }
        if skipped || finished || reduceMotion { return T.end }
        return min(now.timeIntervalSince(start), T.end)
    }

    // MARK: Layout

    private struct Layout {
        let size: CGSize
        let curtain: PTCurtain.Metrics
        /// Chest frame (650×620 art frame shared by the body and both lids).
        let chestW, chestH, cx, chestBottom, chestTop, frontY: CGFloat
        let toy: CGFloat
        let floorW, floorH, floorY: CGFloat

        init(_ s: CGSize) {
            size = s
            curtain = PTCurtain.metrics(s)
            chestW = min(s.width * 0.42, s.height * 0.44)
            chestH = chestW * 620 / 650
            cx = s.width / 2
            chestBottom = s.height * 0.9
            chestTop = chestBottom - chestH * 616 / 620
            // Front edge of the chest opening (art y 372): Nutmeg is hidden below this line.
            frontY = chestTop + chestH * 372 / 620
            toy = chestW * 0.27
            floorW = min(s.width - 2 * curtain.visible + 40, chestW * 3.2)
            floorH = max(floorW * 0.18, s.height * 0.12)
            floorY = chestBottom - floorH * 0.1
        }

        /// Where toy i lands (its bottom center): left and right of the chest on the floor.
        func spot(_ i: Int) -> CGPoint {
            // Inner, back and outer-front spots on each side, spaced at least a toy apart.
            let spots: [(CGFloat, CGFloat)] = [(-0.64, 0.05), (0.66, 0.06), (-0.94, -0.07), (0.96, -0.06), (-1.1, 0.13), (1.1, 0.14)]
            let (dx, dy) = spots[i % spots.count]
            let maxDx = floorW / 2 - toy * 0.5
            let k = min(1, maxDx / (chestW * 1.1))
            return CGPoint(x: cx + dx * chestW * k, y: chestBottom + dy * chestW)
        }
    }

    // MARK: Drawing

    @ViewBuilder private func scene(t: Double, size: CGSize) -> some View {
        let L = Layout(size)
        ZStack(alignment: .topLeading) {
            Theme.startSky
            sky(L)
            Ellipse().fill(Theme.startFloor)
                .frame(width: L.floorW, height: L.floorH)
                .position(x: L.cx, y: L.floorY)
            chest(t: t, L)
                .position(x: L.cx, y: L.chestTop + L.chestH / 2)
            ZStack {
                ForEach(Array(toys.prefix(6).enumerated()), id: \.offset) { i, name in
                    toyView(name, i: i, t: t, L).zIndex(Double(L.spot(i).y))   // nearer toys in front
                }
            }
            titleRow(t: t, L)
            PTCurtain(progress: PTEase.progress(t, T.curtains))
        }
        .frame(width: size.width, height: size.height)
    }

    /// 5 static stage stars and sparkles scattered in the upper sky, clear of the curtains and the title card.
    private func sky(_ L: Layout) -> some View {
        let spots: [(String, CGFloat, CGFloat, CGFloat, Double)] = [
            ("stage-star", 0.08, 0.30, 0.075, -12), ("stage-sparkle", 0.22, 0.48, 0.045, 0),
            ("stage-star", 0.90, 0.26, 0.065, 14), ("stage-sparkle", 0.80, 0.47, 0.05, 0),
            ("stage-sparkle", 0.30, 0.22, 0.035, 0)
        ]
        let side = min(L.size.width, L.size.height)
        let left = L.curtain.visible, span = L.size.width - 2 * L.curtain.visible
        return ZStack {
            ForEach(Array(spots.enumerated()), id: \.offset) { _, s in
                Image(s.0).resizable().scaledToFit()
                    .frame(width: side * s.3, height: side * s.3)
                    .rotationEffect(.degrees(s.4))
                    .position(x: left + span * s.1, y: L.size.height * s.2)
            }
        }
        .accessibilityHidden(true)
    }

    /// Body + lids + Nutmeg, in the chest's own 650×620 frame. Layering: open lid (behind) → body (interior and front
    /// panel) → Nutmeg, clipped at the opening's front edge so the front panel hides her below it → closed lid.
    private func chest(t: Double, _ L: Layout) -> some View {
        let w = L.chestW, h = L.chestH
        // (1) Wiggle: two small shakes.
        let wp = PTEase.progress(t, T.wiggle)
        let wiggle = (wp > 0 && wp < 1) ? sin(wp * .pi * 4) * 4 * (1 - wp * 0.4) : 0
        // (2) Lid pop: squash down, then the body stretches up as the lid flies open.
        let sq = PTEase.bump(PTEase.progress(t, T.lidSquash))
        let st = PTEase.bump(PTEase.progress(t, 1.45...1.62))
        let bodyScale = CGSize(width: 1 + 0.05 * sq - 0.02 * st, height: 1 - 0.07 * sq + 0.05 * st)
        let open = t >= T.lidSwap
        let lp = PTEase.progress(t, T.lidSettle)
        let lidStretch = 0.6 + 0.4 * PTEase.outBack(lp, 2.2)
        return ZStack(alignment: .topLeading) {
            if open {
                Image("chest-lid-open").resizable().frame(width: w, height: h)
                    .scaleEffect(x: 1, y: lidStretch, anchor: UnitPoint(x: 0.5, y: 307 / 620))
            }
            Image("chest-body").resizable().frame(width: w, height: h)
            nutmegLayer(t: t, L)
            if !open { Image("chest-lid-closed").resizable().frame(width: w, height: h) }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .scaleEffect(x: bodyScale.width, y: bodyScale.height, anchor: UnitPoint(x: 0.5, y: 616 / 620))
        .rotationEffect(.degrees(wiggle), anchor: UnitPoint(x: 0.5, y: 616 / 620))
        .accessibilityHidden(true)
    }

    /// Nutmeg pops up out of the chest: hidden below the front edge, rises with a stretch and a small overshoot,
    /// lands waist-deep in the opening with a squash, then waves.
    private func nutmegLayer(t: Double, _ L: Layout) -> some View {
        // Her body (canvas 172–900 px wide) fills ~60% of the chest; canvas 1178×1335.
        let s = 0.6 * L.chestW * 0.945 / 730
        let nW = 1178 * s, nH = 1335 * s
        let hidden = (1335 - 10) * s + 6       // top of her ears just below the edge
        let final = (1335 - 1030) * s          // waist (canvas y ≈ 1030) at the edge
        let jp = PTEase.progress(t, T.jump)
        let y = hidden + (final - hidden) * PTEase.outBack(jp, 1.2)
        let rise = PTEase.bump(jp) * (1 - jp)
        let landing = PTEase.bump(PTEase.progress(t, T.land))
        let scale = CGSize(width: 1 - 0.05 * rise + 0.06 * landing, height: 1 + 0.08 * rise - 0.07 * landing)
        let boxH = L.frontY - L.chestTop + nH
        let waving = T.wave.contains(t) && t < T.end
        return ZStack(alignment: .bottom) {
            nutmeg(waving)
                .frame(width: nW, height: nH)
                .scaleEffect(x: scale.width, y: scale.height, anchor: .bottom)
                .offset(x: (589 - 570) * s, y: y)
        }
        .frame(width: L.chestW * 2, height: boxH, alignment: .bottom)
        .clipped()
        .position(x: L.chestW / 2, y: L.frontY - L.chestTop - boxH / 2)
        .opacity(t >= T.jump.lowerBound ? 1 : 0)
    }

    /// (3) Toy i is tossed out of the chest in an arc with a spin and lands on the floor with a little bounce.
    @ViewBuilder private func toyView(_ name: String, i: Int, t: Double, _ L: Layout) -> some View {
        let t0 = T.toysStart + Double(i) * T.toyGap
        let p = PTEase.progress(t, t0...(t0 + T.toyFlight))
        if p > 0 {
            let end = L.spot(i)
            let from = CGPoint(x: L.cx + CGFloat(i % 2 == 0 ? -1 : 1) * L.chestW * 0.08, y: L.frontY)
            let x = from.x + (end.x - from.x) * CGFloat(p)
            let base = from.y + (end.y - L.toy / 2 - from.y) * CGFloat(p)
            let arc = L.size.height * 0.28 * CGFloat(4 * p * (1 - p))
            let dir: Double = end.x < L.cx ? -1 : 1
            let tilt = [-8.0, 6, 10, -6, 4, -10][i % 6]
            let spin = dir * 360 * (1 - PTEase.outCubic(p)) + tilt
            let land = PTEase.bump(PTEase.progress(t, (t0 + T.toyFlight)...(t0 + T.toyFlight + 0.18)))
            Image(name).resizable().scaledToFit()
                .frame(width: L.toy, height: L.toy)
                .scaleEffect(x: (0.45 + 0.55 * min(p * 3, 1)) * (1 + 0.08 * land),
                             y: (0.45 + 0.55 * min(p * 3, 1)) * (1 - 0.1 * land), anchor: .bottom)
                .rotationEffect(.degrees(spin))
                .position(x: x, y: base - arc)
                .accessibilityHidden(true)
        }
    }

    /// (5) The title card slides down from the top; the start button pops in beside it.
    private func titleRow(t: Double, _ L: Layout) -> some View {
        let cp = PTEase.progress(t, T.card)
        let bp = PTEase.progress(t, T.button)
        return HStack(spacing: Theme.Space.l) {
            PTTitleCard(logoTime: t - T.logo, logoWidth: min(L.size.width * 0.32, 400))
            PTStartButton(action: onStart)
                .scaleEffect(bp > 0 ? PTEase.outBack(bp, 2.0) : 0.01)
                .opacity(bp > 0 ? 1 : 0)
        }
        .offset(y: -(L.curtain.valance + 260) * (1 - PTEase.outBack(cp, 1.3)))
        .opacity(cp > 0 ? 1 : 0)
        .frame(width: L.size.width)
        .padding(.top, L.curtain.valance + Theme.Space.l)
        .frame(width: L.size.width, height: L.size.height, alignment: .top)
    }
}
