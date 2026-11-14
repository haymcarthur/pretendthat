import SwiftUI

// Foundation of the component library: speech action, text styles, backdrop-aware ink, and view modifiers.
// Every value comes from Theme; screens never style things directly.

/// Lets any component read its words aloud (long-press to hear). Injected once at the root.
struct SpeakAction {
    var run: @MainActor (String) -> Void
    @MainActor func callAsFunction(_ text: String) { run(text) }
}

extension EnvironmentValues {
    @Entry var speak = SpeakAction { _ in }
    /// Text colors for whatever surface the view sits on (set by `ptScreen` and reset inside cards).
    @Entry var ptInk = Theme.ink
    @Entry var ptInkMuted = Theme.inkMuted
    /// The phase backdrop, so accents and cards can pick matching colors.
    @Entry var ptBackdrop = PTBackdrop.white
    /// Bumped on celebration moments (kit ready, the end): stage props bounce once.
    @Entry var ptCelebrate = 0
}

enum PTTextStyle {
    case hero, title, headline, body, caption, emoji(CGFloat)

    var font: Font {
        switch self {
        case .hero: Theme.displayFont(Theme.TextSize.hero)
        case .title: Theme.displayFont(Theme.TextSize.title)
        case .headline: Theme.headlineFont(Theme.TextSize.headline)
        case .body: Theme.bodyFont(Theme.TextSize.body)
        case .caption: Theme.bodyFont(Theme.TextSize.caption)
        case .emoji(let size): Theme.emojiFont(size)
        }
    }
}

enum PTTone { case primary, muted }

/// Text in one of the theme's styles. Its color follows the surface it sits on unless `color` is given.
struct PTText: View {
    let text: String
    var style: PTTextStyle = .body
    var tone: PTTone = .primary
    var color: Color?
    @Environment(\.ptInk) private var ink
    @Environment(\.ptInkMuted) private var inkMuted

    init(_ text: String, _ style: PTTextStyle = .body, tone: PTTone = .primary, color: Color? = nil) {
        self.text = text; self.style = style; self.tone = tone; self.color = color
    }
    var body: some View {
        Text(text).font(style.font).foregroundStyle(color ?? (tone == .muted ? inkMuted : ink))
            .multilineTextAlignment(.center)
    }
}

/// Flat chunky card: solid fill, soft border, and a solid bottom edge (no blur shadows, no dark outlines).
struct PTCardModifier: ViewModifier {
    var fill: Color = Theme.surface
    /// Border and bottom-edge color. nil = the backdrop's matching edge.
    var edge: Color?
    var padding: CGFloat = Theme.Space.m
    var depth: CGFloat = Theme.cardDepth
    @Environment(\.ptBackdrop) private var backdrop

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        let edgeColor = edge ?? backdrop.cardEdge
        content
            .environment(\.ptInk, Theme.ink)
            .environment(\.ptInkMuted, Theme.inkMuted)
            .padding(padding)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(edgeColor, lineWidth: Theme.borderWidth))
            .background(shape.fill(edgeColor).offset(y: depth))
            .padding(.bottom, depth)
    }
}

struct PTScreenModifier: ViewModifier {
    var backdrop: PTBackdrop
    func body(content: Content) -> some View {
        content
            .environment(\.ptBackdrop, backdrop)
            .environment(\.ptInk, backdrop.ink)
            .environment(\.ptInkMuted, backdrop.inkMuted)
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backdrop.color.ignoresSafeArea())
            .animation(Theme.gentle, value: backdrop)
    }
}

extension View {
    func ptCard(fill: Color = Theme.surface, edge: Color? = nil, padding: CGFloat = Theme.Space.m) -> some View {
        modifier(PTCardModifier(fill: fill, edge: edge, padding: padding))
    }
    func ptScreen(_ backdrop: PTBackdrop = .white) -> some View { modifier(PTScreenModifier(backdrop: backdrop)) }
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
            .offset(y: shown || reduceMotion ? 0 : 24)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove) { shown = true }   // round 11: together, no stagger
            }
    }
}
