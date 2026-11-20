import SwiftUI
import UIKit
import NutmegCore

/// One thing Nutmeg presents during the voice conversation (a game idea, a role, a prop).
/// Pictured by a generated sticker illustration (D5): never an emoji or icon. `image == nil` shows a shimmer.
struct PTStageItem: Identifiable, Equatable {
    let id: String
    let title: String
    var subtitle: String? = nil
    var image: UIImage? = nil
    /// 2026-11-18: how many to find (a "×4" badge on the picture when more than 1; the title says "Up to 4 …").
    var count: Int = 1
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

/// The ONE stage every phase stands on (Haylee, fix round 2): the floor, 2–3 static stars and Nutmeg share one camera
/// (`PTStageCamera.compose`). A phase only picks a frame (shot + lane); the floor gets exactly her camera move, so it
/// is always under her feet; stars follow with ~70% parallax. The curtains and valance (the proscenium, drawn by the
/// backdrop) and all UI stay put. Phase content (cards, kit papers, checklists) is laid out in screen space by
/// `overlay`, which gets the stage geometry and her current layout.
///
/// Nutmeg is laid out once at the close-up size and moved/scaled by ONE render transform per frame, so every layer
/// (body, head, face, tail, contact shadow) moves as a unit and the vectors stay crisp.
struct PTStageView<Character: View, Overlay: View>: View {
    /// Round 11: the full chat-closed, keyboard-free stage size (the camera's reference): floor : Nutmeg stays constant.
    var referenceSize: CGSize? = nil
    /// Round 15: the full-screen size the backdrop's curtains are drawn at (nil: the stage's own full size).
    var screenSize: CGSize? = nil
    var leadingInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    var chatOpen = false
    /// Close-up anchor: her FACE center for her CURRENT pose (canvas px).
    var faceFocus: CGPoint = PTStageCamera.faceFocus
    /// The frame for this stage geometry (shot + lane).
    var frame: (PTStageGeometry) -> PTStageFrame
    /// Animates card count changes with the camera.
    var itemCount = 0
    /// Round 21: the on-screen keyboard is up: the stage keeps the size, insets and position it had before it opened
    /// (iPadOS also drops the stage's top inset then, which moved and rezoomed it).
    var keyboardUp = false
    @ViewBuilder var character: Character
    @ViewBuilder var overlay: (PTStageGeometry, PTStageCamera.Layout) -> Overlay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutMetrics) private var metrics
    @State private var calm: KeyboardProofGeometry.Calm?

    var body: some View {
        GeometryReader { proxy in
            // Round 21: the keyboard never makes the stage shorter (its framing stays; the keyboard covers the bottom).
            let geo = KeyboardProofGeometry(proxy, referenceSize: referenceSize, calm: calm)
            let screen = screenSize ?? CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                                              height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            // Round 41 (Haylee: in a game the side curtains stopped short of the bottom; on the start screen they run
            // to it): the root measures the screen without its bottom safe area, so the curtains are drawn down to the
            // real bottom edge (the stage's bottom plus its bottom inset), like the start screen's.
            let curtainScreen = CGSize(width: screen.width,
                                       height: max(screen.height, geo.originY + geo.size.height + geo.safeAreaInsets.bottom))
            let full = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            let g = PTStageGeometry(size: geo.size, leadingInset: leadingInset, bottomInset: bottomInset,
                                    // Round 14: the floor belongs to the REFERENCE stage (the full chat-closed one the arrival
                                    // framing is computed on); taking it from the narrower chat-open stage put it ~200 pt left
                                    // of her (the floor cut off on the left).
                                    // iPhone version: the full screen's floor, exactly the start screen's (its hand-off).
                                    floor: PTStage.floor(metrics.isPhone ? screen : (referenceSize ?? full)).offsetBy(dx: -geo.safeAreaInsets.leading, dy: -geo.safeAreaInsets.top),
                                    chatOpen: chatOpen, referenceSize: referenceSize)
            let f = frame(g)
            let comp = PTStageCamera.compose(f, g, faceFocus: faceFocus)
            let L = comp.nutmeg
            ZStack(alignment: .topLeading) {
                let origin = CGPoint(x: proxy.frame(in: .global).minX, y: geo.originY)
                if metrics.isPhone {
                    PTPhoneScenery(comp: comp, fullFloor: g.floor, screen: curtainScreen, origin: origin)
                } else {
                PTStageFloor(rect: comp.floor, apron: false)
                // Round 15 (Haylee: the floor ran in front of the curtains on The End): the proscenium (curtains,
                // tie-backs, valance) draws ABOVE the floor at every camera position. Same curtains as the backdrop's,
                // placed in screen space (the full-screen backdrop's frame, wherever this stage sits), so they line up
                // exactly; the floor moves under them, Nutmeg and the cards stay in front.
                PTCurtain(progress: 1, showsValance: false)
                    .frame(width: curtainScreen.width, height: curtainScreen.height)
                    .position(x: curtainScreen.width / 2 - origin.x, y: curtainScreen.height / 2 - origin.y)
                    .allowsHitTesting(false)
                }
                ForEach(Array(PTStageCamera.stars.enumerated()), id: \.offset) { i, star in
                    // Round 11: the stars are stage props: exactly the camera's transform (no parallax, no size cap).
                    let side = star.size * L.k
                    let p = L.screen(star.point)
                    PTStageStar(asset: star.asset, tilt: star.tilt, index: i)
                        .frame(width: side, height: side)
                        .position(p)
                        .opacity(L.starFits(p, side: side, in: geo.size, leadingInset: leadingInset, bottomInset: bottomInset)
                                 && !starHidden(p, side: side, f, g) ? 1 : 0)
                }
                let big = PTStageCamera.layout(.closeUp, PTStageGeometry(size: geo.size, leadingInset: leadingInset,
                                                                         bottomInset: bottomInset, floor: g.floor), faceFocus: faceFocus)
                // 2026-11-21 (Haylee: her face slid off her head during a zoom): the camera moves her as ONE piece. The
                // zoom/move is the scale + position below (on the container, animated by the stage's one transaction);
                // nothing inside the rig rides the camera's spring (a state change in the same update, like an event card
                // and her alarmed face, is not sprung layer by layer).
                character
                    .transaction(value: f) { $0.animation = nil }
                    .frame(width: big.canvas.width, height: big.canvas.height)
                    .scaleEffect(L.k / big.k)
                    .position(L.canvasCenter)
                overlay(g, L)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: f)
            .offset(y: geo.originY - proxy.frame(in: .global).minY)   // round 21: 0 unless the keyboard moved the stage
            // Round 21: the stage's own measurements follow the same rule as the reference: a new height/top only after
            // it held 0.4 s with the keyboard down (the windowed-iPad keyboard resizes the window first).
            .task(id: "\(KeyboardProofGeometry.Calm(proxy))-\(keyboardUp)") {
                let now = KeyboardProofGeometry.Calm(proxy)
                if calm == nil { calm = now; return }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, !keyboardUp, calm != now else { return }
                calm = now
            }
            #if DEBUG
            .onChange(of: f) { _, _ in Self.checkFeet(comp, f) }
            #endif
        }
        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: itemCount)
    }

    /// Stars stay out of the content zones beside her (kit papers, cards).
    private func starHidden(_ p: CGPoint, side: CGFloat, _ f: PTStageFrame, _ g: PTStageGeometry) -> Bool {
        let F = g.free
        if f.rightReserve > 0, p.x + side / 2 > F.maxX - f.rightReserve { return true }
        if f.leftReserve > 0, p.x - side / 2 < F.minX + f.leftReserve { return true }
        if f.topReserve > 0, p.y - side / 2 < F.minY + f.topReserve { return true }
        return false
    }

    #if DEBUG
    /// Debug check (Haylee): her feet sit on the floor surface in every frame.
    static func checkFeet(_ c: PTStageCamera.Composition, _ f: PTStageFrame) {
        let d = abs(c.nutmeg.feetPoint.y - c.floorLine)
        if d > 3 { print("⚠️ PTStageView: feet \(Int(d)) pt off the floor for \(f)") }
    }
    #endif
}

/// Round 21: the stage's GeometryProxy, held at its keyboard-free measurements while the keyboard is up (height, safe
/// insets and global top), and never shorter than the reference stage.
struct KeyboardProofGeometry {
    struct Calm: Equatable {
        var height: CGFloat, insets: EdgeInsets, minY: CGFloat
        init(_ proxy: GeometryProxy) { height = proxy.size.height; insets = proxy.safeAreaInsets; minY = proxy.frame(in: .global).minY }
    }
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    /// Where the stage's top sits on screen (the content is offset there).
    let originY: CGFloat
    init(_ proxy: GeometryProxy, referenceSize: CGSize?, calm: Calm?) {
        if let calm {
            size = CGSize(width: proxy.size.width, height: calm.height)
            var insets = calm.insets
            insets.leading = proxy.safeAreaInsets.leading; insets.trailing = proxy.safeAreaInsets.trailing
            safeAreaInsets = insets
            originY = calm.minY
        } else {
            size = PTStageGeometry.keyboardProofSize(proxy.size, reference: referenceSize)
            safeAreaInsets = proxy.safeAreaInsets
            originY = proxy.frame(in: .global).minY
        }
    }
}

/// Presented cards in two columns beside Nutmeg (wide shot with cards): no overlap, every label readable.
struct PTPresentedCards: View {
    let items: [PTStageItem]
    let nutmeg: PTStageCamera.Layout
    let size: CGSize
    var onTapItem: ((String) -> Void)? = nil
    var onHunt: ((String, Bool) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                let slot = nutmeg.slot(i, fallback: CGPoint(x: size.width / 2, y: size.height / 2))
                PTItemCard(item: item, chip: item.chip, width: nutmeg.cardWidth)
                    .overlay(alignment: .bottom) {
                        if item.huntButtons, let onHunt { PTHuntButtons(size: 64) { onHunt(item.id, $0) }.offset(y: 40) }
                    }
                    .rotationEffect(.degrees(slot.tilt))
                    .onTapGesture { onTapItem?(item.id) }
                    .position(slot.point)
                    .transition(.scale(scale: 0.2, anchor: .center).combined(with: .opacity))
                    .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: items.map(\.id))   // round 10: with the camera, no stagger
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// One static stage star: pops in once, a single bounce on `\.ptCelebrate` (motion-and-surface.md). Round 10 (Haylee):
/// no twinkle; stars and sparkles are static (round 8's PTTwinkle removed).
struct PTStageStar: View {
    let asset: String
    var tilt: Double = 0
    var index = 0
    @Environment(\.ptCelebrate) private var celebrate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Round 11: no pop-in of its own: the start screen's exit grows the stars in on its camera move, and later framings
    /// show / hide them with the camera (opacity on `Theme.stageMove`), so nothing pops after a move.
    @State private var appeared = true
    @State private var bounce = false

    var body: some View {
        Image(asset).resizable().scaledToFit()
            .rotationEffect(.degrees(tilt))
            .scaleEffect(appeared ? (bounce ? 1.18 : 1) : 0.2)
            .opacity(appeared ? 1 : 0)
            .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: appeared)   // round 11: together, no 80 ms stagger
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
                PTText(subtitle, .caption, tone: .muted)   // never truncated: wraps, the card grows
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
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

/// The hunt buttons on the current prop card (round 26, Haylee's button audit: icon only): a big green ✓ (found it)
/// and an ✗ (don't have it). Voice works too ("found it", "we don't have one").
struct PTHuntButtons: View {
    var size: CGFloat = 72
    let action: (Bool) -> Void
    var body: some View {
        HStack(spacing: Theme.Space.l) {
            PTBigIconButton(kind: .check, size: size, label: "We found it") { action(true) }
            PTBigIconButton(kind: .cross, size: size, label: "We don't have it") { action(false) }
        }
        .padding(.bottom, Theme.depth)   // the depth edge stays inside the card
    }
}


// MARK: - iPhone stage scenery (round 40)

/// Round 40 (Haylee: "the iPhone stage looks odd when Nutmeg is shrunk"): how the phone's stage scenery (sky, floor,
/// curtains) follows Nutmeg when she shrinks to make room for a card below her.
/// - `settle` (shipped): she shrinks and steps back; the floor stays as wide as the stage (its edge is a gentle curve
///   right under her feet, never a small round platform with a straight line beside it), and the curtains' tie-backs
///   rise with her so they sit beside her, above the card. The card then covers the lower stage cleanly.
/// - `zoom`: the camera pulls back: the whole proscenium (sky, floor, curtains) shrinks with her, inside the coral
///   "house" curtains (compared in screenshots, not shipped: a stage inside a stage, tiny tassels, a big coral frame).
/// - `old`: round 39 (the floor shrinks with her: the platform floats mid-screen, the sky ends in a hard line).
enum PTPhoneStageLook: String {
    case settle, zoom, old
    static var current: PTPhoneStageLook {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-PTStageLook"), i + 1 < args.count, let l = PTPhoneStageLook(rawValue: args[i + 1]) { return l }
        #endif
        return .settle
    }
}

/// The phone stage's scenery under Nutmeg (stage coordinates; `origin` = the stage's top-left on the screen).
struct PTPhoneScenery: View {
    let comp: PTStageCamera.Composition
    /// The floor at the reference (arrival) framing, stage coordinates.
    let fullFloor: CGRect
    let screen: CGSize
    let origin: CGPoint
    var look = PTPhoneStageLook.current

    var body: some View {
        let s = comp.world.scale
        switch look {
        case .old:
            PTStageFloor(rect: comp.floor, apron: true)
            curtains(tie: nil, valance: false)
        case .settle:
            // Her own sky (it hides the backdrop's curtains, which can't follow the tie), so the valance is drawn here.
            Theme.startSky.frame(width: screen.width, height: screen.height)
                .position(x: screen.width / 2 - origin.x, y: screen.height / 2 - origin.y)
            let w = max(comp.floor.width, fullFloor.width)
            PTStageFloor(rect: CGRect(x: comp.floor.midX - w / 2, y: comp.floor.minY, width: w, height: comp.floor.height), apron: true)
            // The tie-backs keep their height above the floor line, in her scale (stage coords → screen coords).
            let fullTie = screen.height * 0.45
            let fullFeet = fullFloor.midY + origin.y, feet = comp.floor.midY + origin.y
            curtains(tie: s < 0.999 ? min(fullTie, feet - (fullFeet - fullTie) * s) : nil, valance: true)
        case .zoom:
            // The house: coral all round; the whole full-size proscenium scaled with her (floor → her floor).
            Theme.coral.frame(width: screen.width, height: screen.height)
                .position(x: screen.width / 2 - origin.x, y: screen.height / 2 - origin.y)
            let tl = CGPoint(x: comp.floor.minX + (-origin.x - fullFloor.minX) * s, y: comp.floor.minY + (-origin.y - fullFloor.minY) * s)
            ZStack(alignment: .topLeading) {
                Theme.startSky
                PTStageFloor(rect: fullFloor.offsetBy(dx: origin.x, dy: origin.y), apron: true)
                PTCurtain(progress: 1, showsValance: false)
            }
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
            .scaleEffect(s, anchor: .topLeading)
            .position(x: tl.x + screen.width / 2, y: tl.y + screen.height / 2)
            curtainsValanceOnly
        }
    }

    private func curtains(tie: CGFloat?, valance: Bool) -> some View {
        PTCurtain(progress: 1, showsValance: valance, tieY: tie)
            .frame(width: screen.width, height: screen.height)
            .position(x: screen.width / 2 - origin.x, y: screen.height / 2 - origin.y)
            .allowsHitTesting(false)
    }

    private var curtainsValanceOnly: some View {
        PTValance(height: PTCurtain.metrics(screen).valance)
            .frame(width: screen.width, alignment: .leading).clipped()
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
            .position(x: screen.width / 2 - origin.x, y: screen.height / 2 - origin.y)
            .allowsHitTesting(false)
    }
}
