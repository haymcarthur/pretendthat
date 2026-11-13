import SwiftUI
import NutmegCore

/// A plain themed container.
struct PTCard<Content: View>: View {
    var fill: Color = Theme.surface
    @ViewBuilder var content: Content
    var body: some View { content.ptCard(fill: fill) }
}

/// Nutmeg's current line, as a speech bubble. Tap to hear it again.
struct PTSpeechBubble: View {
    let text: String
    @Environment(\.speak) private var speak
    var body: some View {
        Button { speak(text) } label: {
            PTText(text, .headline)
                .frame(maxWidth: .infinity)
                .ptCard(fill: Theme.background)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityHint("Tap to hear Nutmeg again")
    }
}

/// A big picture choice. Tap chooses; long-press reads it aloud.
struct PTChoiceTile: View {
    let emoji: String
    let label: String
    var isSelected = false
    var tint: Color = Theme.surface
    var size: CGFloat = Theme.Size.choiceTile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label { Text(label) } icon: { Text(emoji) }
                .labelStyle(PTEmojiLabelStyle(emojiSize: size * 0.36))
                .frame(width: size, height: size)
                .ptCard(fill: isSelected ? Theme.accent : tint, stroke: isSelected ? Theme.ink : Theme.outline)
        }
        .buttonStyle(TileButtonStyle())
        .ptSpeakOnLongPress(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Squish feedback for tiles (the tile draws its own card).
struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(Theme.springy, value: configuration.isPressed)
    }
}

/// A player's role badge: colored circle with the role symbol, plus name and role.
struct PTRoleBadge: View {
    let player: Player
    var role: Role?
    var size: CGFloat = Theme.Size.badge
    var onTap: (() -> Void)?

    var body: some View {
        let content = VStack(spacing: Theme.Space.xs) {
            ZStack {
                Circle().fill(Theme.playerColor(player.colorIndex))
                Circle().strokeBorder(Theme.ink, lineWidth: Theme.outlineWidth)
                if let role {
                    Text(role.emoji).font(Theme.emojiFont(size * 0.45))
                    Image(systemName: role.symbol).font(Theme.displayFont(size * 0.16)).foregroundStyle(Theme.inkOnBrand)
                        .padding(Theme.Space.xs).background(Circle().fill(Theme.ink))
                        .offset(x: size * 0.32, y: size * 0.32)
                } else {
                    Text(player.emoji).font(Theme.emojiFont(size * 0.45))
                }
            }
            .frame(width: size, height: size)
            PTText(player.displayName, .headline)
            if let role { PTText(role.roleName, .caption, color: Theme.inkMuted) }
        }
        Group {
            if let onTap { Button(action: onTap) { content }.buttonStyle(TileButtonStyle()) } else { content }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([player.displayName, role?.roleName].compactMap { $0 }.joined(separator: ", "))
    }
}

/// One checklist step: emoji + short text + a big check. Long-press hears it.
struct PTChecklistRow: View {
    let emoji: String
    let text: String
    @Binding var isChecked: Bool

    var body: some View {
        Toggle(isOn: $isChecked) {
            Label { Text(text).strikethrough(isChecked, color: Theme.inkMuted) } icon: { Text(emoji) }
                .labelStyle(.ptRow)
        }
        .toggleStyle(.ptCheck)
        .ptCard(fill: isChecked ? Theme.success.opacity(0.25) : Theme.background)
        .ptSpeakOnLongPress(text)
    }
}

/// A prop to hunt for: household item → what it becomes, with a found check.
struct PTPropCard: View {
    let prop: Prop
    @Binding var found: Bool

    var body: some View {
        Toggle(isOn: $found) {
            VStack(spacing: Theme.Space.s) {
                PTText(prop.emoji, .emoji(64))
                PTText(prop.householdItem, .headline)
                Label { Text(prop.becomes) } icon: { Image(systemName: "arrow.right") }
                    .font(Theme.bodyFont(Theme.TextSize.body)).foregroundStyle(Theme.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .toggleStyle(.ptCheck)
        .ptCard(fill: found ? Theme.success.opacity(0.3) : Theme.surface)
        .ptSpeakOnLongPress("\(prop.householdItem) becomes \(prop.becomes)")
    }
}

/// "Pass the iPad to Captain Mia!" card with the badge to tap.
struct PTHandoffCard: View {
    let player: Player
    let role: Role?
    let onTap: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTText("Pass the iPad to", .headline, color: Theme.inkMuted)
            PTRoleBadge(player: player, role: role, size: Theme.Size.badge * 1.6, onTap: onTap)
            PTText("Tap your badge!", .headline)
        }
        .ptCard(fill: Theme.playerColor(player.colorIndex).opacity(0.18), padding: Theme.Space.xl)
        .offset(x: shown ? 0 : 600)
        .onAppear { withAnimation(Theme.springy) { shown = true } }
        .sensoryFeedback(.impact, trigger: shown)
    }
}

/// Small numbered page preview for the kit.
struct PTPageThumbnail<Page: View>: View {
    let number: Int
    @ViewBuilder var page: Page
    var body: some View {
        VStack(spacing: Theme.Space.xs) {
            page
                .frame(width: Theme.Size.thumbnail, height: Theme.Size.thumbnail * 11 / 8.5)
                .background(Theme.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius / 2))
                .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius / 2).strokeBorder(Theme.outline, lineWidth: 2))
                .shadow(color: Theme.shadow.color, radius: Theme.shadow.radius, y: Theme.shadow.y)
            PTText("Page \(number)", .caption, color: Theme.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(number)")
    }
}

/// Hold for 2 seconds to continue (keeps a tap-happy 4-year-old from printing 6 pages).
struct PTParentGate: View {
    let label: String
    var symbol = "printer.fill"
    var seconds: Double = 2
    let onComplete: () -> Void
    @State private var progress = 0.0
    @State private var pressing = false

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            ZStack {
                ProgressView(value: progress).progressViewStyle(.ptRing)
                Image(systemName: symbol).font(Theme.displayFont(22)).foregroundStyle(Theme.ink)
            }
            .frame(width: 56, height: 56)
            PTText(label, .headline)
        }
        .padding(.horizontal, Theme.Space.l).padding(.vertical, Theme.Space.s)
        .frame(minHeight: Theme.Size.minHit)
        .background(Capsule().fill(Theme.accent))
        .scaleEffect(pressing ? 0.96 : 1)
        .onLongPressGesture(minimumDuration: seconds, maximumDistance: 60) {
            progress = 1
            onComplete()
            withAnimation(Theme.gentle.delay(0.4)) { progress = 0 }
        } onPressingChanged: { isPressing in
            pressing = isPressing
            if isPressing { withAnimation(.linear(duration: seconds)) { progress = 1 } }
            else if progress < 1 { withAnimation(Theme.gentle) { progress = 0 } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint("Grown-ups: hold for \(Int(seconds)) seconds")
        .accessibilityAction { onComplete() }
    }
}

/// "🔊 again": replays Nutmeg's last line.
struct PTReplayButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label("Again", systemImage: "speaker.wave.2.fill") }
            .buttonStyle(.ptQuiet)
            .accessibilityLabel("Hear Nutmeg again")
    }
}

/// Hold-to-talk microphone. Pulses while listening. Dimmed (but still visible) when speech isn't available.
struct PTMicButton: View {
    let isListening: Bool
    let isAvailable: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        TimelineView(.animation(paused: !isListening)) { ctx in
            let pulse = isListening ? 1 + 0.08 * sin(ctx.date.timeIntervalSinceReferenceDate * 8) : 1
            ZStack {
                Circle().fill(Theme.primary.opacity(0.25)).scaleEffect(isListening ? pulse * 1.25 : 1)
                Circle().fill(isListening ? Theme.accent : Theme.primary)
                Circle().strokeBorder(Theme.ink, lineWidth: Theme.outlineWidth)
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(Theme.displayFont(48)).foregroundStyle(isListening ? Theme.ink : Theme.inkOnBrand)
            }
            .scaleEffect(pulse)
        }
        .frame(width: Theme.Size.mic, height: Theme.Size.mic)
        .opacity(isAvailable ? 1 : 0.4)
        .onLongPressGesture(minimumDuration: 600, maximumDistance: 200, perform: {}) { pressing in
            pressing ? onPress() : onRelease()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isListening)
        .accessibilityLabel(isListening ? "Listening" : "Hold to talk to Nutmeg")
        .accessibilityAddTraits(.isButton)
    }
}

/// The shared kid-screen layout: Nutmeg on the left third, the stage on the right, controls along the bottom.
struct PTStageLayout<Nutmeg: View, Stage: View, Bottom: View>: View {
    var background: Color = Theme.background
    @ViewBuilder var nutmeg: Nutmeg
    @ViewBuilder var stage: Stage
    @ViewBuilder var bottom: Bottom

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: Theme.Space.m) {
                HStack(alignment: .center, spacing: Theme.Space.l) {
                    nutmeg.frame(width: geo.size.width * 0.3)
                    stage.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(spacing: Theme.Space.l) { bottom }
                    .frame(maxWidth: .infinity)
            }
        }
        .ptScreen(background)
    }
}

/// A row of big count buttons (1 2 3 4 5+).
struct PTCountPicker: View {
    static let emoji = ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "🎬"]
    let selected: Int?
    let onPick: (Int) -> Void
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            ForEach(1...5, id: \.self) { n in
                PTChoiceTile(emoji: Self.emoji[n - 1], label: n == 5 ? "5 or more" : "\(n)",
                             isSelected: selected == n, size: Theme.Size.choiceTile * 0.72) { onPick(n) }
            }
        }
    }
}

/// Inline "thinking" indicator with a short caption.
struct PTWorkingIndicator: View {
    var caption = "Nutmeg is thinking..."
    var body: some View {
        VStack(spacing: Theme.Space.m) {
            ProgressView().progressViewStyle(.ptDots)
            PTText(caption, .body, color: Theme.inkMuted)
        }
    }
}

/// Stage title row: big emoji + title.
struct PTStageHeader: View {
    let emoji: String
    let title: String
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            PTText(emoji, .emoji(56))
            PTText(title, .title)
        }
        .accessibilityElement(children: .combine)
    }
}
