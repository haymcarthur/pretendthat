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
    var leadingInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    var chatOpen = false
    /// Close-up anchor: her FACE center for her CURRENT pose (canvas px).
    var faceFocus: CGPoint = PTStageCamera.faceFocus
    /// The frame for this stage geometry (shot + lane).
    var frame: (PTStageGeometry) -> PTStageFrame
    /// Animates card count changes with the camera.
    var itemCount = 0
    @ViewBuilder var character: Character
    @ViewBuilder var overlay: (PTStageGeometry, PTStageCamera.Layout) -> Overlay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let full = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            let g = PTStageGeometry(size: geo.size, leadingInset: leadingInset, bottomInset: bottomInset,
                                    floor: PTStage.floor(full).offsetBy(dx: -geo.safeAreaInsets.leading, dy: -geo.safeAreaInsets.top),
                                    chatOpen: chatOpen)
            let f = frame(g)
            let comp = PTStageCamera.compose(f, g, faceFocus: faceFocus)
            let L = comp.nutmeg, ref = comp.reference, world = comp.world
            ZStack(alignment: .topLeading) {
                PTStageFloor(rect: comp.floor)
                ForEach(Array(PTStageCamera.stars.enumerated()), id: \.offset) { i, star in
                    let side = min(star.size * ref.k, star.maxPoints) * world.parallaxScale
                    let p = world.apply(ref.screen(star.point), parallax: 0.7)
                    PTStageStar(asset: star.asset, tilt: star.tilt, index: i)
                        .frame(width: side, height: side)
                        .position(p)
                        .opacity(L.starFits(p, side: side, in: geo.size, leadingInset: leadingInset, bottomInset: bottomInset)
                                 && !starHidden(p, side: side, f, g) ? 1 : 0)
                }
                let big = PTStageCamera.layout(.closeUp, PTStageGeometry(size: geo.size, leadingInset: leadingInset,
                                                                         bottomInset: bottomInset, floor: g.floor), faceFocus: faceFocus)
                character
                    .frame(width: big.canvas.width, height: big.canvas.height)
                    .scaleEffect(L.k / big.k)
                    .position(L.canvasCenter)
                overlay(g, L)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.9, dampingFraction: 0.82), value: f)
            #if DEBUG
            .onChange(of: f) { _, _ in Self.checkFeet(comp, f) }
            #endif
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.9, dampingFraction: 0.82), value: itemCount)
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
                        if item.huntButtons, let onHunt { PTHuntButtons { onHunt(item.id, $0) }.offset(y: 26) }
                    }
                    .rotationEffect(.degrees(slot.tilt))
                    .onTapGesture { onTapItem?(item.id) }
                    .position(slot.point)
                    .transition(.scale(scale: 0.2, anchor: .center).combined(with: .opacity))
                    .animation(Theme.bouncy.delay(reduceMotion ? 0 : Double(i) * 0.12), value: items.map(\.id))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
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
