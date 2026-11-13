import SwiftUI

/// Native Button, themed Duolingo-style: a solid face on a solid "3D" bottom edge. Pressing pushes the face down
/// onto the edge. White labels only on faces where they pass WCAG large-text contrast (see BrandPalette).
struct PTButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, success }
    var kind: Kind = .primary
    var size: CGFloat = Theme.TextSize.button

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous)
        let pressed = configuration.isPressed
        let depth = kind == .quiet ? Theme.depth * 0.7 : Theme.depth
        configuration.label
            .font(Theme.displayFont(size))
            .foregroundStyle(foreground)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
            .frame(minWidth: Theme.Size.minHit, minHeight: Theme.Size.minHit - depth)
            .background(shape.fill(face))
            .overlay(shape.strokeBorder(kind == .quiet && isEnabled ? Theme.line : .clear, lineWidth: Theme.borderWidth))
            .offset(y: pressed ? depth : 0)
            .background(shape.fill(edge).offset(y: depth))
            .padding(.bottom, depth)
            .contentShape(shape)
            .animation(Theme.press, value: pressed)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: pressed) { _, new in new }
    }

    private var face: Color {
        guard isEnabled else { return Theme.disabled }
        switch kind { case .primary: return Theme.primary; case .secondary: return Theme.accent
        case .quiet: return Theme.white; case .success: return Theme.success }
    }
    private var edge: Color {
        guard isEnabled else { return Theme.line }
        switch kind { case .primary: return Theme.coralShade; case .secondary: return Theme.yellowShade
        case .quiet: return Theme.line; case .success: return Theme.limeShade }
    }
    private var foreground: Color {
        guard isEnabled else { return Theme.disabledInk }
        return kind == .primary ? Theme.inkOnBrand : Theme.ink
    }
}

extension ButtonStyle where Self == PTButtonStyle {
    static var ptPrimary: PTButtonStyle { PTButtonStyle(kind: .primary) }
    static var ptSecondary: PTButtonStyle { PTButtonStyle(kind: .secondary) }
    static var ptQuiet: PTButtonStyle { PTButtonStyle(kind: .quiet, size: Theme.TextSize.body) }
    static var ptSuccess: PTButtonStyle { PTButtonStyle(kind: .success) }
}

/// Big emoji above a short title: the picture-first label kids read without reading.
struct PTEmojiLabelStyle: LabelStyle {
    var emojiSize: CGFloat = 72
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: Theme.Space.s) {
            configuration.icon.font(Theme.emojiFont(emojiSize))
            configuration.title.font(Theme.headlineFont(Theme.TextSize.body)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
        }
    }
}

/// Emoji leading, title trailing, for rows.
struct PTRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.m) {
            configuration.icon.font(Theme.emojiFont(40))
            configuration.title.font(Theme.bodyFont(Theme.TextSize.body)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }
}

extension LabelStyle where Self == PTEmojiLabelStyle { static var ptEmoji: PTEmojiLabelStyle { PTEmojiLabelStyle() } }
extension LabelStyle where Self == PTRowLabelStyle { static var ptRow: PTRowLabelStyle { PTRowLabelStyle() } }

/// Native ProgressView drawn as a chunky ring (parent gate hold, waiting).
struct PTRingProgressStyle: ProgressViewStyle {
    var color: Color = Theme.primary
    var lineWidth: CGFloat = 10
    func makeBody(configuration: Configuration) -> some View {
        let fraction = configuration.fractionCompleted ?? 0
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle().trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Native ProgressView as three bouncing dots ("Nutmeg is thinking"). With a fraction, a chunky bar shows below.
struct PTDotsProgressStyle: ProgressViewStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: Theme.Space.m) {
            TimelineView(.animation(paused: reduceMotion)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                HStack(spacing: Theme.Space.s) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill([Theme.coral, Theme.yellow, Theme.lime][i])
                            .frame(width: 22, height: 22)
                            .offset(y: reduceMotion ? 0 : -abs(sin(t * 4 + Double(i) * 0.7)) * 16)
                    }
                }
            }
            if let fraction = configuration.fractionCompleted {
                Capsule().fill(Theme.line).frame(width: 240, height: 16)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.lime).frame(width: max(16, 240 * fraction))
                            .animation(Theme.bouncy, value: fraction)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Working")
        .accessibilityValue(configuration.fractionCompleted.map { "\(Int($0 * 100)) percent" } ?? "")
    }
}

extension ProgressViewStyle where Self == PTRingProgressStyle { static var ptRing: PTRingProgressStyle { PTRingProgressStyle() } }
extension ProgressViewStyle where Self == PTDotsProgressStyle { static var ptDots: PTDotsProgressStyle { PTDotsProgressStyle() } }

/// Native Toggle as a big round check bubble (props found, checklist steps). Checking pops a little burst.
struct PTCheckToggleStyle: ToggleStyle {
    /// Corner = check bubble overlaid top-trailing (cards); otherwise trailing in a row.
    var corner = false
    func makeBody(configuration: Configuration) -> some View {
        Button { withAnimation(Theme.springy) { configuration.isOn.toggle() } } label: {
            Group {
                if corner {
                    configuration.label.overlay(alignment: .topTrailing) { bubble(configuration.isOn).offset(x: Theme.Space.s, y: -Theme.Space.s) }
                } else {
                    HStack(spacing: Theme.Space.m) { configuration.label; bubble(configuration.isOn) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: configuration.isOn) { _, new in new }
    }

    private func bubble(_ isOn: Bool) -> some View {
        ZStack {
            Circle().fill(isOn ? Theme.limeShade : Theme.line).offset(y: 4)
            Circle().fill(isOn ? Theme.success : Theme.white)
            Circle().strokeBorder(isOn ? Color.clear : Theme.line, lineWidth: Theme.borderWidth)
            Image(systemName: "checkmark").font(Theme.displayFont(26)).foregroundStyle(Theme.ink)
                .opacity(isOn ? 1 : 0)
                .scaleEffect(isOn ? 1 : 0.2)
                .rotationEffect(.degrees(isOn ? 0 : -30))
        }
        .frame(width: Theme.Size.check, height: Theme.Size.check)
        .scaleEffect(isOn ? 1.06 : 1)
        .ptBurst(isOn)
        .animation(Theme.springy, value: isOn)
    }
}

extension ToggleStyle where Self == PTCheckToggleStyle {
    static var ptCheck: PTCheckToggleStyle { PTCheckToggleStyle() }
    static var ptCheckCorner: PTCheckToggleStyle { PTCheckToggleStyle(corner: true) }
}
