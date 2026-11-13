import SwiftUI

// Foundation of the component library: speech action, text styles, and view modifiers.
// Every value comes from Theme; screens never style things directly.

/// Lets any component read its words aloud (long-press to hear). Injected once at the root.
struct SpeakAction {
    var run: @MainActor (String) -> Void
    @MainActor func callAsFunction(_ text: String) { run(text) }
}

extension EnvironmentValues {
    @Entry var speak = SpeakAction { _ in }
}

enum PTTextStyle {
    case hero, title, headline, body, caption, emoji(CGFloat)

    var font: Font {
        switch self {
        case .hero: Theme.displayFont(Theme.TextSize.hero)
        case .title: Theme.displayFont(Theme.TextSize.title)
        case .headline: Theme.displayFont(Theme.TextSize.headline)
        case .body: Theme.bodyFont(Theme.TextSize.body)
        case .caption: Theme.bodyFont(Theme.TextSize.caption)
        case .emoji(let size): Theme.emojiFont(size)
        }
    }
}

/// Text in one of the theme's styles.
struct PTText: View {
    let text: String
    var style: PTTextStyle = .body
    var color: Color = Theme.ink
    init(_ text: String, _ style: PTTextStyle = .body, color: Color = Theme.ink) {
        self.text = text; self.style = style; self.color = color
    }
    var body: some View {
        Text(text).font(style.font).foregroundStyle(color).multilineTextAlignment(.center)
    }
}

struct PTCardModifier: ViewModifier {
    var fill: Color = Theme.surface
    var stroke: Color = Theme.outline
    var padding: CGFloat = Theme.Space.m
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(stroke, lineWidth: Theme.outlineWidth))
            .compositingGroup()
            .shadow(color: Theme.shadow.color, radius: Theme.shadow.radius, y: Theme.shadow.y)
    }
}

struct PTScreenModifier: ViewModifier {
    var background: Color
    func body(content: Content) -> some View {
        content
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background.ignoresSafeArea())
    }
}

extension View {
    func ptCard(fill: Color = Theme.surface, stroke: Color = Theme.outline, padding: CGFloat = Theme.Space.m) -> some View {
        modifier(PTCardModifier(fill: fill, stroke: stroke, padding: padding))
    }
    func ptScreen(_ background: Color = Theme.background) -> some View { modifier(PTScreenModifier(background: background)) }
    /// Long-press anywhere on the view to hear `text`.
    func ptSpeakOnLongPress(_ text: String) -> some View { modifier(SpeakOnLongPress(text: text)) }
    /// Pops in with a springy stagger (index-based delay).
    func ptPopIn(index: Int = 0) -> some View { modifier(PopIn(index: index)) }
}

private struct SpeakOnLongPress: ViewModifier {
    let text: String
    @Environment(\.speak) private var speak
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in speak(text) })
            .accessibilityAction(named: "Hear it") { speak(text) }
    }
}

private struct PopIn: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(Theme.springy.delay(Double(index) * 0.08)) { shown = true } }
    }
}
