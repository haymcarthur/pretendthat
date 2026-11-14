import SwiftUI
import UIKit

/// One thing Nutmeg presents during the voice conversation (a game idea, a role, a prop).
/// Pictured by a generated sticker illustration (D5): never an emoji or icon. `image == nil` shows a shimmer.
struct PTStageItem: Identifiable, Equatable {
    let id: String
    let title: String
    var subtitle: String? = nil
    var image: UIImage? = nil
    var tint: Color = Theme.coral
    /// Changing this flips the card over to the new picture (a swapped prop).
    var flipKey: String = ""
    /// A skipped prop: stays on stage in a soft "we'll pretend" state (never removed like a failure).
    var isPretend = false
    /// Card state chip (top-right).
    var chip: PTItemCard.Chip = .none
    /// The prop the hunt is on: shows the backup "Got it" / "Don't have it" buttons.
    var huntButtons = false
}

/// Where the "camera" is (D4): close on Nutmeg's face while she talks or listens, wide while she presents.
/// `hunt`: the prop hunt's medium shot with her right of center (active card left, done chips right).
enum PTCameraShot: Equatable { case closeUp, medium, wide, hunt }

/// The voice-mode screen (D1): Nutmeg big and centered on a calm stage with 2–3 static stars, the presented items in
/// two neat columns beside her, and the control pill at the bottom (drawn by the root). No tap targets during planning;
/// items accept a tap only as a silent backup (`onTapItem`).
///
/// Camera (D4, Haylee fix round 1): every shot names a FOCAL point in Nutmeg's 1178×1335 art canvas and a canvas
/// height in points; the focal point lands exactly on the stage center. Default (medium): her whole body, about 70% of
/// the screen height, her visual center (not the tail-skewed bounding box) centered. Close-up (talking/listening): her
/// head fills most of the screen, the head's center centered. Wide (presenting): zoomed out so the cards fit beside her.
/// Nutmeg is laid out once at the close-up size and moved/scaled by ONE render transform per shot, so every layer
/// (body, head, face, tail, ground) moves as a unit and the vectors stay crisp.
struct PTConversationStage<Character: View, Bar: View>: View {
    var backdrop: PTBackdrop = .white
    var shot: PTCameraShot
    var items: [PTStageItem] = []
    /// Floating chrome to keep cards clear of: the step rail on the left, the control pill at the bottom.
    var leadingInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    /// Close-up anchor: Nutmeg's FACE center (eyes and nose) in canvas px for her CURRENT pose (head offset and
    /// rotation about the neck applied). The close-up puts this point at the center of the free stage.
    var faceFocus: CGPoint = PTStageCamera.faceFocus
    /// The chat panel is open: center her between the rail and the panel (the stage is already narrowed by it).
    var centerBetweenChrome = false
    var onTapItem: ((String) -> Void)? = nil
    /// Backup hunt buttons on the current card (found: true / false).
    var onHunt: ((String, Bool) -> Void)? = nil
    @ViewBuilder var character: Character
    @ViewBuilder var bar: Bar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var huntSpace

    /// Prop hunt zones (screen space, not stage space): the rail gutter + DONE stack on the left (≥ 24 pt from the
    /// rail), Nutmeg left of center, and the ACTIVE card on the right where she points, ≥ 32 pt inside the right
    /// curtain, vertically centered on her chest. A card that's done shrinks and flies left into the stack.
    @ViewBuilder private func huntLayout(_ size: CGSize, _ L: PTStageCamera.Layout, full: CGSize) -> some View {
        let done = items.filter(\.isDone)
        let active = items.last { !$0.isDone }
        // The tied-back swag is narrowest around the card's height: its inner edge there is about half the top reach.
        let curtainEdge = PTCurtain.metrics(full).visible * 0.55
        let nutRight = L.canvasCenter.x + PTStageCamera.halfWidth * L.k
        let zoneL = nutRight + 20, zoneR = size.width - curtainEdge - 32
        let cardW = max(220, min(zoneR - zoneL, size.width * 0.4, 440))
        let chestY = L.screen(CGPoint(x: 0, y: 860)).y
        let stackX = leadingInset + 24 + 90
        ZStack(alignment: .topLeading) {
            if let active {
                PTPropActiveCard(item: active, width: cardW, onHunt: active.huntButtons ? onHunt.map { f in { f(active.id, $0) } } : nil)
                    .matchedGeometryEffect(id: active.id, in: huntSpace)
                    .position(x: (zoneL + zoneR) / 2, y: min(max(chestY, 220), size.height - bottomInset - 200))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
            VStack(spacing: Theme.Space.s) {
                ForEach(done) { item in
                    PTPropDoneChip(item: item, width: 180).matchedGeometryEffect(id: item.id, in: huntSpace)
                }
            }
            .frame(width: 180)
            .position(x: stackX, y: 84 + CGFloat(done.count) * 36)   // fills top to bottom
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.55, dampingFraction: 0.8), value: done.map(\.id))
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.5, dampingFraction: 0.75), value: active?.id)
    }

    var body: some View {
        GeometryReader { geo in
            let L = PTStageCamera.layout(shot: shot, itemCount: items.count, size: geo.size,
                                         leadingInset: leadingInset, bottomInset: bottomInset,
                                         faceFocus: faceFocus, centerBetweenChrome: centerBetweenChrome)
            // The camera moves on the stage WORLD (Haylee): the floor and the stars get the same transform as Nutmeg,
            // relative to the medium shot (where the floor is exactly the start screen's / backdrop's floor), stars with
            // ~70% parallax. Curtains and valance (the proscenium, drawn by the backdrop) and all UI stay put.
            let mediumL = PTStageCamera.layout(shot: .medium, itemCount: 0, size: geo.size, leadingInset: leadingInset,
                                               bottomInset: bottomInset, faceFocus: faceFocus)
            let world = PTStageCamera.WorldMove(from: mediumL, to: L)
            let full = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            let floorFull = PTStage.floor(full)
            let floorRect = floorFull.offsetBy(dx: -geo.safeAreaInsets.leading, dy: -geo.safeAreaInsets.top)
            ZStack(alignment: .topLeading) {
                PTStageFloor(rect: world.apply(floorRect))
                // (Her ground oval is drawn inside NutmegCharacter(showsGround:) so it moves with her as one unit.)
                // 2–3 static stars around her, never over her face (positions in art-canvas px).
                ForEach(Array(PTStageCamera.stars.enumerated()), id: \.offset) { i, star in
                    let side = min(star.size * mediumL.k, star.maxPoints) * world.parallaxScale
                    let p = world.apply(mediumL.screen(star.point), parallax: 0.7)
                    PTStageStar(asset: star.asset, tilt: star.tilt, index: i)
                        .frame(width: side, height: side)
                        .position(p)
                        .opacity(L.starFits(p, side: side, in: geo.size, leadingInset: leadingInset, bottomInset: bottomInset) ? 1 : 0)
                }
                // One render transform for all of her (no per-layer layout animation, so nothing trails): she is laid
                // out once at the largest (close-up) size and scaled down per shot, which keeps the vectors crisp.
                let big = PTStageCamera.layout(shot: .closeUp, itemCount: 0, size: geo.size,
                                               leadingInset: leadingInset, bottomInset: bottomInset,
                                               faceFocus: faceFocus, centerBetweenChrome: false)
                character
                    .frame(width: big.canvas.width, height: big.canvas.height)
                    .scaleEffect(L.k / big.k)
                    .position(L.canvasCenter)

                if shot == .hunt {
                    huntLayout(geo.size, L, full: full)
                } else {
                // Presented items in two columns beside her (no overlap; every label readable).
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    let slot = L.slot(i, fallback: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                    PTItemCard(item: item, chip: item.chip, width: L.cardWidth)
                        .overlay(alignment: .bottom) {
                            if item.huntButtons, let onHunt { PTHuntButtons { onHunt(item.id, $0) }.offset(y: 26) }
                        }
                        .rotationEffect(.degrees(slot.tilt))
                        .onTapGesture { onTapItem?(item.id) }
                        .position(slot.point)
                        .transition(.scale(scale: 0.2, anchor: .center).combined(with: .opacity))
                        .animation(Theme.bouncy.delay(reduceMotion ? 0 : Double(i) * 0.12), value: items.map(\.id))
                }
                }

                VStack { Spacer(); bar }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .padding(.bottom, Theme.Space.l)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.9, dampingFraction: 0.82), value: shot)
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.9, dampingFraction: 0.82), value: items.count)
        .environment(\.ptBackdrop, backdrop)
    }
}

/// One static stage star: pops in once, a single bounce on `\.ptCelebrate` (motion-and-surface.md).
struct PTStageStar: View {
    let asset: String
    var tilt: Double = 0
    var index = 0
    @Environment(\.ptCelebrate) private var celebrate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var bounce = false

    var body: some View {
        Image(asset).resizable().scaledToFit()
            .rotationEffect(.degrees(tilt))
            .scaleEffect(appeared ? (bounce ? 1.18 : 1) : 0.2)
            .opacity(appeared ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.2)
                       : .spring(response: 0.42, dampingFraction: 0.55).delay(Double(index) * 0.08), value: appeared)
            .animation(.spring(response: 0.25, dampingFraction: 0.4), value: bounce)
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

/// The stage camera math (pure, so it can be checked): where Nutmeg's canvas goes for a shot, and the card slots.
enum PTStageCamera {
    /// Room the conversation screen keeps for its floating chrome (step rail on the left, control pill at the bottom).
    static let chromeLeading: CGFloat = 132, chromeBottom: CGFloat = 108
    /// Nutmeg's art canvas (all layers share it) and the focal points measured from Haylee's export
    /// (alpha bounds via tools: head-base x 61–1055, y 15–800; idle body + tail x 172–900, y 765–1311).
    static let art = CGSize(width: 1178, height: 1335)
    /// Her VISUAL center: the horizontal mass center of head and body (the tail on her left skews the bounding box).
    static let bodyFocus = CGPoint(x: 578, y: 663)
    /// Her head's center (ears included).
    static let headFocus = CGPoint(x: 566, y: 410)
    /// Her FACE center (eyes, brows and nose; face SVG bounds x 397–863, y 294–635, nose ~y 560) in the rest pose:
    /// the close-up anchor. The face is right of the head's center (3/4 view), so centering the head left it off-center.
    static let faceFocus = CGPoint(x: 630, y: 470)
    /// How far her head reaches from the face center (ears x 61–1055, top y 15, chin y ~800), canvas px.
    static let faceToLeftEar: CGFloat = 569, faceToRightEar: CGFloat = 425, faceToTop: CGFloat = 455
    /// Visible art height and her widest half-width from the visual center, in canvas px.
    static let visibleHeight: CGFloat = 1296
    static let halfWidth: CGFloat = 517
    static let headHeight: CGFloat = 785
    static let headWidth: CGFloat = 994

    struct Star { let asset: String; let point: CGPoint; let size: CGFloat; let maxPoints: CGFloat; let tilt: Double }
    /// Placed clear of her head (ears end at x 61 and 1055) and body; static.
    static let stars = [
        Star(asset: "stage-star", point: CGPoint(x: 1150, y: 170), size: 150, maxPoints: 84, tilt: 12),
        Star(asset: "stage-sparkle", point: CGPoint(x: -20, y: 560), size: 100, maxPoints: 56, tilt: 0),
        Star(asset: "stage-sparkle", point: CGPoint(x: 1090, y: 1010), size: 70, maxPoints: 40, tilt: 0)
    ]

    /// The camera move between two layouts as a world transform (screen points at `from` → screen points at `to`).
    struct WorldMove {
        let from: Layout, to: Layout
        var scale: CGFloat { to.k / from.k }
        /// Star scale with ~70% parallax.
        var parallaxScale: CGFloat { 1 + (scale - 1) * 0.7 }
        func apply(_ p: CGPoint, parallax: CGFloat = 1) -> CGPoint {
            let full = CGPoint(x: to.origin.x + (p.x - from.origin.x) * scale, y: to.origin.y + (p.y - from.origin.y) * scale)
            return CGPoint(x: p.x + (full.x - p.x) * parallax, y: p.y + (full.y - p.y) * parallax)
        }
        func apply(_ r: CGRect) -> CGRect {
            let o = apply(r.origin)
            return CGRect(x: o.x, y: o.y, width: r.width * scale, height: r.height * scale)
        }
    }

    struct Layout {
        /// Points per canvas px.
        var k: CGFloat
        /// Screen position of canvas (0,0).
        var origin: CGPoint
        var canvas: CGSize
        var cardWidth: CGFloat
        var cards: [(point: CGPoint, tilt: Double)]
        func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * k, y: origin.y + p.y * k) }
        /// A star shows only on screen, clear of the rail, the pill and every card.
        func starFits(_ p: CGPoint, side: CGFloat, in size: CGSize, leadingInset: CGFloat, bottomInset: CGFloat) -> Bool {
            let r = CGRect(x: p.x - side / 2, y: p.y - side / 2, width: side, height: side)
            guard r.minX > leadingInset + 8, r.maxX < size.width - 8, r.minY > 8, r.maxY < size.height - bottomInset else { return false }
            let h = PTStageCamera.cardHeight(cardWidth)
            return !cards.contains { c in
                CGRect(x: c.point.x - cardWidth / 2 - 12, y: c.point.y - h / 2 - 12, width: cardWidth + 24, height: h + 24).intersects(r)
            }
        }
        func slot(_ i: Int, fallback: CGPoint) -> (point: CGPoint, tilt: Double) {
            cards.indices.contains(i) ? cards[i] : (fallback, 0)
        }
        var canvasCenter: CGPoint { CGPoint(x: origin.x + canvas.width / 2, y: origin.y + canvas.height / 2) }
    }

    /// Card height for a width (art square + tag strip + 2-line title + subtitle + padding).
    static func cardHeight(_ w: CGFloat) -> CGFloat { w * 0.72 + 128 }

    static func layout(shot: PTCameraShot, itemCount n: Int, size: CGSize, leadingInset: CGFloat, bottomInset: CGFloat,
                       faceFocus: CGPoint = faceFocus, centerBetweenChrome: Bool = false) -> Layout {
        let top: CGFloat = 16
        let availH = max(200, size.height - bottomInset - top)
        var center = CGPoint(x: size.width / 2, y: top + availH / 2)
        // Default: whole body ~70% of the screen height, kept above the control pill and inside the width.
        let mediumH = min(size.height * 0.70, availH * 0.94, (size.width / 2 - 24) / halfWidth * visibleHeight) / visibleHeight * art.height
        var canvasH: CGFloat
        var focus: CGPoint
        var cardW: CGFloat = 0
        var cards: [(CGPoint, Double)] = []
        switch shot {
        case .closeUp:
            // Her FACE centered both ways in the free stage (between the rail and the chat panel when it's open), the
            // head as big as fits: ears inside the stage (the far ear may crop by up to ~6%), top of the head inside.
            if centerBetweenChrome { center.x = (leadingInset + size.width) / 2 }
            let leftRoom = center.x - (centerBetweenChrome ? leadingInset + 8 : 0)
            let rightRoom = size.width - center.x
            let k = min(availH / 2 / faceToTop, leftRoom / (faceToLeftEar * 1.02), rightRoom / (faceToRightEar * 0.94),
                        size.height * 0.85 / headHeight)
            canvasH = k * art.height
            focus = faceFocus
        case .medium:
            canvasH = mediumH
            focus = bodyFocus
        case .hunt:
            // Left of center, facing and pointing (viewer's right) toward the active card.
            canvasH = mediumH * 0.74
            focus = bodyFocus
            center.x = leadingInset + (size.width - leadingInset) * 0.37
        case .wide:
            focus = bodyFocus
            let left = (n + 1) / 2, rows = max(1, left)
            let gap: CGFloat = 16
            let fitW = ((availH - CGFloat(rows - 1) * gap) / CGFloat(rows) - 128) / 0.72
            cardW = max(140, min(210, fitW, size.width * 0.19))
            let edgeL = leadingInset + 12, edgeR = size.width - 12
            // Room left for Nutmeg between the two columns.
            let half = min(center.x - edgeL - cardW - 20, edgeR - cardW - 20 - center.x)
            canvasH = max(art.height * 0.18, min(mediumH * 0.82, half / halfWidth * art.height))
            let nutHalf = halfWidth * canvasH / art.height
            let xl = max(edgeL + cardW / 2, center.x - nutHalf - 20 - cardW / 2)
            let xr = min(edgeR - cardW / 2, center.x + nutHalf + 20 + cardW / 2)
            let h = cardHeight(cardW)
            for i in 0..<n {
                let isLeft = i < left
                let count = isLeft ? left : n - left
                let j = isLeft ? i : i - left
                let c = CGFloat(j) - CGFloat(count - 1) / 2
                let y = center.y + c * (h + gap)
                let tilt = Double(c) * (isLeft ? -2.5 : 2.5)
                cards.append((CGPoint(x: isLeft ? xl : xr, y: y), tilt))
            }
        }
        let k = canvasH / art.height
        let canvas = CGSize(width: art.width * k, height: canvasH)
        let origin = CGPoint(x: center.x - focus.x * k, y: center.y - focus.y * k)
        return Layout(k: k, origin: origin, canvas: canvas, cardWidth: cardW, cards: cards.map { (point: $0.0, tilt: $0.1) })
    }
}

/// A presented item: a white sticker card with the generated illustration and a short label.
struct PTStageItemCard: View {
    let item: PTStageItem
    var width: CGFloat = 200
    @State private var flip: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Neutral on purpose (white, crisp light border): Haylee restyles this component in Figma.
    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            Group {
                if let image = item.image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .saturation(item.isPretend ? 0 : 1)
                        .opacity(item.isPretend ? 0.45 : 1)
                        .transition(.opacity)
                } else {
                    PTShimmer(tint: item.tint)
                }
            }
            .frame(width: width - Theme.Space.m * 2, height: width - Theme.Space.m * 2)
            .animation(.easeOut(duration: 0.3), value: item.image != nil)
            PTText(item.title, .headline)
                .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
            if let subtitle = item.isPretend ? "We'll pretend!" : item.subtitle {
                PTText(subtitle, .caption, tone: .muted).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .padding(Theme.Space.s)
        .frame(width: width - Theme.Space.s * 2)
        .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.white))
        .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
            .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 2, dash: item.isPretend ? [8, 6] : [])))
        .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .animation(.easeInOut(duration: 0.3), value: item.isPretend)
        .onChange(of: item.flipKey) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { flip += 360 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([item.title, item.isPretend ? "pretend" : item.subtitle].compactMap { $0 }.joined(separator: ", "))
    }
}

/// Loading placeholder for an illustration that's still being drawn (not an icon): a flat tinted tile that
/// breathes softly while waiting. Crisp and flat, no gradients.
struct PTShimmer: View {
    var tint: Color = Theme.coral
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
            .fill(tint.opacity(on ? 0.22 : 0.1))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
            .accessibilityHidden(true)
    }
}

/// ChatGPT-voice-mode bottom bar: mute and leave, nothing else. Long-press mute to type instead (simulator, demo safety).
struct PTVoiceBar: View {
    let isMuted: Bool
    let isListening: Bool
    let onMute: () -> Void
    let onLeave: () -> Void
    var onType: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Theme.Space.l) {
            PTRoundControl(symbol: isMuted ? "mic.slash.fill" : "mic.fill",
                           fill: isMuted ? Theme.coral : Theme.white,
                           ink: isMuted ? Theme.inkOnBrand : Theme.ink,
                           pulsing: isListening && !isMuted,
                           label: isMuted ? "Unmute" : "Mute", action: onMute)
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.8).onEnded { _ in onType?() })
                .accessibilityAction(named: "Type instead") { onType?() }
            PTRoundControl(symbol: "xmark", fill: Theme.white, ink: Theme.ink, pulsing: false,
                           label: "Leave", action: onLeave)
        }
        .padding(Theme.Space.s)
        .background(Capsule().fill(Theme.white))
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 2))
    }
}

/// A big round control in the voice bar (native Button).
struct PTRoundControl: View {
    let symbol: String
    let fill: Color
    let ink: Color
    let pulsing: Bool
    let label: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                if pulsing {   // the kid is talking: a crisp ring (event, not a loop)
                    Circle().stroke(Theme.yellow, lineWidth: 5).padding(-6)
                }
                Circle().fill(fill)
                Circle().strokeBorder(Theme.line, lineWidth: fill == Theme.white ? Theme.borderWidth : 0)
                Image(systemName: symbol).font(Theme.displayFont(34)).foregroundStyle(ink)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: Theme.Size.minHit, height: Theme.Size.minHit)
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(label)
    }
}

/// The backup buttons under the current prop card ("Got it" / "Don't have it") for noisy rooms.
struct PTHuntButtons: View {
    let action: (Bool) -> Void
    var body: some View {
        HStack(spacing: 8) {
            button("Got it", symbol: "checkmark", fill: Theme.lime, found: true)
            button("Don't have it", symbol: "xmark", fill: Theme.white, found: false)
        }
    }
    private func button(_ title: String, symbol: String, fill: Color, found: Bool) -> some View {
        Button { action(found) } label: {
            Label(title, systemImage: symbol).font(Theme.uiFont(14)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).frame(height: 40)
                .background(Capsule().fill(fill))
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(found ? "We found it" : "We don't have it")
    }
}
