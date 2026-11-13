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
            Text(text).font(Theme.uiFont(22)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(Theme.Space.m)
                .ptPanel(radius: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityHint("Tap to hear Nutmeg again")
    }
}

/// Little triangle on the speech bubble pointing back at Nutmeg.
private struct BubbleTail: View {
    @Environment(\.ptBackdrop) private var backdrop
    var body: some View {
        Triangle().fill(Theme.white)
            .overlay(Triangle().stroke(backdrop.cardEdge, lineWidth: Theme.borderWidth).mask(Rectangle().padding(.trailing, 4)))
            .frame(width: Theme.Space.m, height: Theme.Space.l)
            .accessibilityHidden(true)
    }
    private struct Triangle: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)) }
        }
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
    @State private var picks = 0

    var body: some View {
        Button {
            picks += 1
            action()
        } label: {
            Label { Text(label) } icon: { Text(emoji) }
                .labelStyle(PTEmojiLabelStyle(emojiSize: size * 0.36))
                .frame(width: size - Theme.Space.m * 2, height: size - Theme.Space.m * 2)
                .ptCard(fill: isSelected ? Theme.accent : tint, edge: isSelected ? Theme.yellowShade : nil)
        }
        .buttonStyle(TileButtonStyle())
        .ptBounce(trigger: picks)
        .sensoryFeedback(.selection, trigger: picks)
        .ptSpeakOnLongPress(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Press feedback for tiles (the tile draws its own card): the card sinks onto its edge.
struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? Theme.cardDepth * 0.6 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.press, value: configuration.isPressed)
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
                Circle().fill(Theme.playerShade(player.colorIndex)).offset(y: Theme.cardDepth)
                Circle().fill(Theme.playerColor(player.colorIndex))
                Circle().strokeBorder(Theme.white.opacity(0.9), lineWidth: Theme.borderWidth * 2).padding(Theme.borderWidth)
                if let role {
                    Text(role.emoji).font(Theme.emojiFont(size * 0.45))
                    Image(systemName: role.symbol).font(Theme.displayFont(size * 0.15)).foregroundStyle(Theme.playerColor(player.colorIndex))
                        .padding(size * 0.06).background(Circle().fill(Theme.white))
                        .offset(x: size * 0.32, y: size * 0.32)
                } else {
                    Text(player.emoji).font(Theme.emojiFont(size * 0.45))
                }
            }
            .frame(width: size, height: size)
            PTText(player.displayName, .headline)
            if let role { PTText(role.roleName, .caption, tone: .muted) }
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
        .ptCard(fill: isChecked ? Theme.limeTint : Theme.white,
                edge: isChecked ? Theme.limeShade : nil, padding: Theme.Space.s)
        .animation(Theme.springy, value: isChecked)
        .ptSpeakOnLongPress(text)
    }
}

/// A prop to hunt for: household item → what it becomes, with a found check.
struct PTPropCard: View {
    let prop: Prop
    @Binding var found: Bool

    var body: some View {
        Toggle(isOn: $found) {
            // Compact so two rows of 2-line cards still leave room for the bottom controls.
            VStack(spacing: Theme.Space.xs) {
                PTText(prop.emoji, .emoji(48))
                PTText(prop.householdItem, .headline).lineLimit(2).minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Label { Text(prop.becomes) } icon: { Image(systemName: "arrow.right") }
                    .font(Theme.bodyFont(Theme.TextSize.body)).foregroundStyle(Theme.inkMuted)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(2).minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .toggleStyle(.ptCheckCorner)
        .ptCard(fill: found ? Theme.limeTint : Theme.white, edge: found ? Theme.limeShade : nil)
        .animation(Theme.springy, value: found)
        .ptSpeakOnLongPress("\(prop.householdItem) becomes \(prop.becomes)")
    }
}

/// "Pass the iPad to Captain Mia!" card with the badge to tap.
struct PTHandoffCard: View {
    let player: Player
    let role: Role?
    let onTap: () -> Void
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTText("Pass the iPad to", .headline, tone: .muted)
            PTRoleBadge(player: player, role: role, size: Theme.Size.badge * 1.6, onTap: onTap)
                .ptBounce(trigger: shown)
            PTText("Tap your badge!", .headline)
        }
        .ptCard(fill: Theme.white, edge: Theme.playerColor(player.colorIndex), padding: Theme.Space.xl)
        .offset(x: shown || reduceMotion ? 0 : 700)
        .rotationEffect(.degrees(shown || reduceMotion ? 0 : 8))
        .opacity(shown || !reduceMotion ? 1 : 0)
        .onAppear { withAnimation(reduceMotion ? Theme.gentle : Theme.bouncy) { shown = true } }
        .sensoryFeedback(.impact(weight: .medium), trigger: shown)
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
                .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius / 2).strokeBorder(Theme.line, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius / 2).fill(Theme.shadow.color).offset(y: Theme.shadow.y))
            PTText("Page \(number)", .caption, tone: .muted)
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
        // Primary CTA style: black pill, white text; a white ring fills while held.
        HStack(spacing: Theme.Space.s) {
            ZStack {
                Circle().stroke(Theme.white.opacity(0.25), lineWidth: 3)
                Circle().trim(from: 0, to: progress).stroke(Theme.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol.replacingOccurrences(of: ".fill", with: "")).font(.system(size: 18, weight: .regular)).foregroundStyle(Theme.white)
            }
            .frame(width: 40, height: 40)
            Text(label).font(Theme.uiFont(20)).foregroundStyle(Theme.white)
        }
        .padding(.leading, Theme.Space.s).padding(.trailing, Theme.Space.l)
        .frame(minHeight: 64)
        .background(Capsule().fill(Theme.cta))
        .scaleEffect(pressing ? 0.97 : 1)
        .animation(Theme.press, value: pressing)
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

/// Hold-to-talk microphone: a chunky coral button that sinks while held and pulses rings while listening.
/// When speech isn't available it becomes a keyboard button: tap to type instead (`onTypeInstead`).
struct PTMicButton: View {
    let isListening: Bool
    let isAvailable: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    var onTypeInstead: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isAvailable {
            face(symbol: isListening ? "waveform" : "mic.fill", fill: isListening ? Theme.accent : Theme.primary,
                 edge: isListening ? Theme.yellowShade : Theme.coralShade, ink: isListening ? Theme.ink : Theme.inkOnBrand,
                 sunk: isListening)
                .onLongPressGesture(minimumDuration: 600, maximumDistance: 200, perform: {}) { pressing in
                    pressing ? onPress() : onRelease()
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: isListening)
                .accessibilityLabel(isListening ? "Listening" : "Hold to talk to Nutmeg")
                .accessibilityAddTraits(.isButton)
        } else {
            Button { onTypeInstead?() } label: {
                face(symbol: "keyboard.fill", fill: Theme.white, edge: Theme.line, ink: Theme.ink, sunk: false)
            }
            .buttonStyle(TileButtonStyle())
            .disabled(onTypeInstead == nil)
            .accessibilityLabel("Type to Nutmeg")
        }
    }

    private func face(symbol: String, fill: Color, edge: Color, ink: Color, sunk: Bool) -> some View {
        TimelineView(.animation(paused: !isListening || reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                if isListening && !reduceMotion {
                    ForEach(0..<2, id: \.self) { i in
                        let phase = (t / 1.2 + Double(i) / 2).truncatingRemainder(dividingBy: 1)
                        Circle().stroke(Theme.accent, lineWidth: 6)
                            .scaleEffect(1 + phase * 0.5).opacity(1 - phase)
                    }
                }
                Circle().fill(edge).offset(y: Theme.depth)
                ZStack {
                    Circle().fill(fill)
                    Circle().strokeBorder(fill == Theme.white ? Theme.line : .clear, lineWidth: Theme.borderWidth)
                    Image(systemName: symbol).font(Theme.displayFont(44)).foregroundStyle(ink)
                        .symbolEffect(.variableColor.iterative, isActive: isListening && !reduceMotion)
                }
                .offset(y: sunk ? Theme.depth : 0)
            }
        }
        .frame(width: Theme.Size.mic, height: Theme.Size.mic)
        .padding(.bottom, Theme.depth)
        .animation(Theme.press, value: sunk)
    }
}

/// "Type instead": a native sheet with a TextField, for when the mic is off (permission, simulator) or a grown-up
/// wants to type what a kid said.
struct PTTypeSheet: View {
    let onSend: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Space.l) {
                PTText("What do you want to tell Nutmeg?", .headline)
                TextField("Type here", text: $text)
                    .font(Theme.bodyFont(Theme.TextSize.headline))
                    .foregroundStyle(Theme.ink)
                    .padding(Theme.Space.m)
                    .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.cream))
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                Button { send() } label: { Label("Tell Nutmeg", systemImage: "paperplane.fill") }
                    .buttonStyle(.ptPrimary)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer(minLength: 0)
            }
            .padding(Theme.Space.l)
            .background(Theme.white)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }

    private func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSend(t)
        dismiss()
    }
}

/// The shared kid-screen layout: Nutmeg (the hero) on the left with stage props around her, the stage on the right,
/// controls along the bottom. One solid backdrop per phase.
struct PTStageLayout<Nutmeg: View, Stage: View, Bottom: View>: View {
    var backdrop: PTBackdrop = .white
    /// Share of the width Nutmeg gets (`Theme.nutmegHeroColumn` when she's the star of the screen).
    var nutmegColumn: CGFloat = Theme.nutmegColumn
    @ViewBuilder var nutmeg: Nutmeg
    @ViewBuilder var stage: Stage
    @ViewBuilder var bottom: Bottom

    var body: some View {
        GeometryReader { geo in
            let nutmegWidth = geo.size.width * nutmegColumn
            VStack(spacing: Theme.Space.m) {
                HStack(alignment: .center, spacing: Theme.Space.l) {
                    nutmeg
                        .padding(Theme.Space.m)
                        .background { PTStageAccents() }
                        .frame(width: nutmegWidth)
                    // Long AI content (5 steps, 2-line props) scrolls instead of pushing the mic off screen.
                    ViewThatFits(in: .vertical) {
                        stage.padding(.vertical, Theme.Space.s)
                        ScrollView(.vertical) { stage.padding(.vertical, Theme.Space.m) }
                            .scrollIndicators(.visible)
                    }
                    .frame(width: max(0, geo.size.width - nutmegWidth - Theme.Space.l))
                    .frame(maxHeight: .infinity)
                }
                HStack(spacing: Theme.Space.l) { bottom }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
            }
        }
        .ptScreen(backdrop)
        .animation(Theme.bouncy, value: nutmegColumn)
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
                             isSelected: selected == n, size: Theme.Size.countTile) { onPick(n) }
            }
        }
    }
}

/// Inline "thinking" indicator with a short caption.
struct PTWorkingIndicator: View {
    var caption = "Nutmeg is thinking..."
    /// 0...1 shows a chunky progress bar under the dots.
    var progress: Double? = nil
    var body: some View {
        VStack(spacing: Theme.Space.m) {
            if let progress { ProgressView(value: progress).progressViewStyle(.ptDots) }
            else { ProgressView().progressViewStyle(.ptDots) }
            PTText(caption, .body, tone: .muted)
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
