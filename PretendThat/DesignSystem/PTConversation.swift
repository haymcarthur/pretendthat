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
    /// Card pill tag (top-left), e.g. the player's name or "Prop".
    var tag: String? = nil
    /// Card state chip (top-right).
    var chip: PTItemCard.Chip = .none
}

/// Where the "camera" is (D4): close on Nutmeg's face while she talks or listens, wide while she presents.
enum PTCameraShot: Equatable { case closeUp, medium, wide }

/// The voice-mode screen (D1): Nutmeg big in the center of a calm, solid-color stage with a few floating theater
/// props, the presented items arranged around her, and a ChatGPT-style bottom bar. No tap targets during planning;
/// items accept a tap only as a silent backup (`onTapItem`).
struct PTConversationStage<Character: View, Bar: View>: View {
    var backdrop: PTBackdrop = .white
    var shot: PTCameraShot
    var items: [PTStageItem] = []
    var onTapItem: ((String) -> Void)? = nil
    @ViewBuilder var character: Character
    @ViewBuilder var bar: Bar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let side = min(size.width * 0.6, size.height * 0.74)
            ZStack {
                // Camera layer: Nutmeg and her floating props move together.
                ZStack {
                    PTStageAccents()
                        .frame(width: side * 1.3, height: side * 1.05)
                    character
                        .frame(width: side, height: side)
                }
                .scaleEffect(camera.scale, anchor: Self.faceAnchor)
                .offset(y: camera.offsetY * side)
                .position(x: size.width / 2, y: size.height * 0.43)

                // Presented items fan out in an arc around her (ToyCAD layout), slightly tilted and overlapping.
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    let cw = min(200, size.width * 0.18)
                    let slot = PTFan.slot(i, of: items.count, in: size, cardWidth: cw)
                    PTItemCard(item: item, tag: item.tag, chip: item.chip, width: cw)
                        .rotationEffect(.degrees(slot.tilt))
                        .onTapGesture { onTapItem?(item.id) }
                        .position(slot.point)
                        .transition(.scale(scale: 0.2, anchor: .center).combined(with: .opacity))
                        .animation(Theme.bouncy.delay(reduceMotion ? 0 : Double(i) * 0.12), value: items.map(\.id))
                }

                VStack { Spacer(); bar }
                    .padding(.bottom, Theme.Space.l)
            }
            .frame(width: size.width, height: size.height)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.9, dampingFraction: 0.82), value: shot)
        .environment(\.ptBackdrop, backdrop)
    }

    /// Nutmeg's face on her 1024² canvas (head sits high on the body).
    static var faceAnchor: UnitPoint { UnitPoint(x: 0.5, y: 0.36) }

    private var camera: (scale: CGFloat, offsetY: CGFloat) {
        switch shot {
        case .closeUp: (1.5, 0.16)    // push in toward her face
        case .medium: (0.95, -0.02)
        case .wide: (0.72, -0.02)     // pull back so the fanned cards fit around her
        }
    }

    /// Items sit on an arc around Nutmeg: left, over the top, right (up to 5).
    static func slot(_ i: Int, of n: Int, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
        let rx = size.width * 0.36, ry = size.height * 0.30
        let (from, to): (Double, Double) = n <= 3 ? (170, 10) : (190, -10)
        let a = n == 1 ? 90 : from + (to - from) * Double(i) / Double(n - 1)
        let rad = a * .pi / 180
        return CGPoint(x: center.x + rx * cos(rad), y: center.y - ry * sin(rad))
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
