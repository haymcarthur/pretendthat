import SwiftUI

/// Native Button, themed. Kinds map to brand colors; presses squish like a toy.
struct PTButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, success }
    var kind: Kind = .primary
    var size: CGFloat = Theme.TextSize.headline

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.displayFont(size))
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
            .frame(minWidth: Theme.Size.minHit, minHeight: Theme.Size.minHit)
            .background(Capsule().fill(background))
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(kind == .quiet ? 0.15 : 0), lineWidth: Theme.outlineWidth))
            .compositingGroup()
            .shadow(color: kind == .quiet ? .clear : Theme.shadow.color, radius: Theme.shadow.radius,
                    y: configuration.isPressed ? 1 : Theme.shadow.y)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(Theme.springy, value: configuration.isPressed)
            .contentShape(Capsule())
    }

    private var background: Color {
        switch kind { case .primary: Theme.primary; case .secondary: Theme.accent; case .quiet: Theme.background; case .success: Theme.success }
    }
    private var foreground: Color {
        switch kind { case .primary: Theme.inkOnBrand; default: Theme.ink }
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
            configuration.title.font(Theme.displayFont(Theme.TextSize.body)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
        }
    }
}

/// Emoji leading, title trailing, for rows.
struct PTRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.m) {
            configuration.icon.font(Theme.emojiFont(44))
            configuration.title.font(Theme.bodyFont(Theme.TextSize.body)).foregroundStyle(Theme.ink)
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

/// Native ProgressView as three bouncing dots ("Nutmeg is thinking").
struct PTDotsProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: Theme.Space.s) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill([Theme.primary, Theme.accent, Theme.success][i])
                        .frame(width: 22, height: 22)
                        .offset(y: -abs(sin(t * 4 + Double(i) * 0.7)) * 16)
                }
            }
        }
        .accessibilityLabel("Working")
    }
}

extension ProgressViewStyle where Self == PTRingProgressStyle { static var ptRing: PTRingProgressStyle { PTRingProgressStyle() } }
extension ProgressViewStyle where Self == PTDotsProgressStyle { static var ptDots: PTDotsProgressStyle { PTDotsProgressStyle() } }

/// Native Toggle as a big round check bubble (props found, checklist steps).
struct PTCheckToggleStyle: ToggleStyle {
    /// Corner = check bubble overlaid top-trailing (cards); otherwise trailing in a row.
    var corner = false
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
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
                    Circle().fill(isOn ? Theme.success : Theme.background)
                    Circle().strokeBorder(Theme.ink.opacity(isOn ? 0 : 0.25), lineWidth: Theme.outlineWidth)
                    Image(systemName: "checkmark").font(Theme.displayFont(30)).foregroundStyle(Theme.ink)
                        .opacity(isOn ? 1 : 0)
                        .scaleEffect(isOn ? 1 : 0.3)
                }
                .frame(width: 64, height: 64)
                .animation(Theme.springy, value: isOn)
    }
}

extension ToggleStyle where Self == PTCheckToggleStyle {
    static var ptCheck: PTCheckToggleStyle { PTCheckToggleStyle() }
    static var ptCheckCorner: PTCheckToggleStyle { PTCheckToggleStyle(corner: true) }
}
