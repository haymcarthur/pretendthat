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
}

/// Where the "camera" is (D4): close on Nutmeg's face while she talks or listens, wide while she presents.
enum PTCameraShot: Equatable { case closeUp, medium, wide }

/// The voice-mode screen (D1): Nutmeg big in the center of a calm, solid-color stage with a few floating theater
/// props, the presented items arranged around her, and a ChatGPT-style bottom bar. No tap targets during planning;
/// items accept a tap only as a silent backup (`onTapItem`).
struct PTConversationStage<Character: View, Bar: View>: View {
    var backdrop: PTBackdrop = .backstage
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
                        .frame(width: side * 1.5, height: side * 1.2)
                    character
                        .frame(width: side, height: side)
                }
                .scaleEffect(camera.scale, anchor: Self.faceAnchor)
                .offset(y: camera.offsetY * side)
                .position(x: size.width / 2, y: size.height * 0.43)

                // Presented items fan out around her in the wide shot.
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    let p = Self.slot(i, of: items.count, in: size)
                    PTStageItemCard(item: item, width: min(220, size.width * 0.19))
                        .onTapGesture { onTapItem?(item.id) }
                        .position(p)
                        .transition(.scale(scale: 0.2, anchor: .center).combined(with: .opacity))
                        .animation(Theme.bouncy.delay(reduceMotion ? 0 : Double(i) * 0.12), value: items.map(\.id))
                }

                VStack { Spacer(); bar }
                    .padding(.bottom, Theme.Space.l)
            }
            .frame(width: size.width, height: size.height)
        }
        .ptScreen(backdrop)
        .overlay(alignment: .topLeading) { PTCurtainCorner(width: 150).ignoresSafeArea() }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.9, dampingFraction: 0.82), value: shot)
        .environment(\.ptBackdrop, backdrop)
    }

    /// Nutmeg's face on her 1024² canvas (head sits high on the body).
    static var faceAnchor: UnitPoint { UnitPoint(x: 0.5, y: 0.36) }

    private var camera: (scale: CGFloat, offsetY: CGFloat) {
        switch shot {
        case .closeUp: (1.5, 0.16)    // push in toward her face
        case .medium: (0.95, -0.02)
        case .wide: (0.6, -0.06)      // pull back so items fit around her
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
    @Environment(\.ptBackdrop) private var backdrop

    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            Group {
                if let image = item.image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    PTShimmer(tint: item.tint)
                }
            }
            .frame(width: width - Theme.Space.m * 2, height: width - Theme.Space.m * 2)
            .animation(.easeOut(duration: 0.35), value: item.image != nil)
            PTText(item.title, .headline)
                .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
            if let subtitle = item.subtitle {
                PTText(subtitle, .caption, tone: .muted).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(width: width - Theme.Space.s * 2)
        .ptCard(edge: item.tint, padding: Theme.Space.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([item.title, item.subtitle].compactMap { $0 }.joined(separator: ", "))
    }
}

/// A soft loading shimmer for an illustration that's still being drawn (not an icon).
struct PTShimmer: View {
    var tint: Color = Theme.coral
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let x = CGFloat((t / 1.4).truncatingRemainder(dividingBy: 1)) * 2.4 - 1.2
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay {
                    LinearGradient(colors: [.clear, Theme.white.opacity(0.75), .clear],
                                   startPoint: UnitPoint(x: x, y: 0), endPoint: UnitPoint(x: x + 0.6, y: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                }
        }
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
        .background(Capsule().fill(Theme.purpleShade.opacity(0.85)))
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
                if pulsing && !reduceMotion {
                    TimelineView(.animation) { ctx in
                        let phase = (ctx.date.timeIntervalSinceReferenceDate / 1.4).truncatingRemainder(dividingBy: 1)
                        Circle().stroke(Theme.yellow, lineWidth: 5).scaleEffect(1 + phase * 0.4).opacity(1 - phase)
                    }
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
