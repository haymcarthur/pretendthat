import SwiftUI
import NutmegCore

/// A plain themed container.
struct PTCard<Content: View>: View {
    var fill: Color = Theme.surface
    @ViewBuilder var content: Content
    var body: some View { content.ptCard(fill: fill) }
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
/// A big tap tile. Text only (checklist-pictures.md: no emoji stand-ins); an optional picture sits above the label.
struct PTChoiceTile: View {
    var image: UIImage? = nil
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
            VStack(spacing: Theme.Space.s) {
                if let image { Image(uiImage: image).resizable().scaledToFit().frame(height: size * 0.4) }
                Text(label).font(Theme.headlineFont(image == nil ? Theme.TextSize.title : Theme.TextSize.body)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
            }
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

/// A role's badge: circle in the role's color with its emoji (or symbol), and the role title. No kids' names
/// anywhere (roles-not-names.md); a role played by several kids shows "×2".
struct PTRoleBadge: View {
    let role: Role
    var size: CGFloat = Theme.Size.badge
    var onTap: (() -> Void)?

    var body: some View {
        let color = role.id.index
        // The role title in the role color: no emoji or symbol stand-ins (checklist-pictures.md).
        let content = VStack(spacing: Theme.Space.xs) {
            Text(role.roleName)
                .font(Theme.headlineFont(size * 0.22)).foregroundStyle(Theme.white)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                .padding(.horizontal, size * 0.18).padding(.vertical, size * 0.1)
                .frame(minWidth: size * 1.2, minHeight: size * 0.5)
                .background(Capsule().fill(Theme.playerShade(color)).offset(y: Theme.cardDepth))
                .background(Capsule().fill(Theme.playerColor(color)))
            if role.count > 1 { PTText("×\(role.count)", .caption, tone: .muted) }
        }
        Group {
            if let onTap { Button(action: onTap) { content }.buttonStyle(TileButtonStyle()) } else { content }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(role.roleName)
    }
}

/// One checklist step: emoji + short text + a big check. Long-press hears it.
struct PTChecklistRow<Picture: View>: View {
    let text: String
    @Binding var isChecked: Bool
    /// Round 8: compact rows (many steps, or pinned in the chat panel) shrink padding and spacing first; the text
    /// never goes below 17 pt.
    var fontSize: CGFloat = Theme.TextSize.body
    var padding: CGFloat = Theme.Space.s
    /// Exactly one picture (prop, action or kit art; PTPictureTile).
    @ViewBuilder var picture: Picture

    var body: some View {
        Toggle(isOn: $isChecked) {
            HStack(spacing: padding < Theme.Space.s ? Theme.Space.s : Theme.Space.m) {
                picture
                Text(text).strikethrough(isChecked, color: Theme.inkMuted)
                    .font(Theme.bodyFont(fontSize)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                    .minimumScaleFactor(min(1, 17 / fontSize))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .toggleStyle(.ptCheck)
        .ptCard(fill: isChecked ? Theme.limeTint : Theme.white,
                edge: isChecked ? Theme.limeShade : nil, padding: padding)
        .animation(Theme.springy, value: isChecked)
        .ptSpeakOnLongPress(text)
    }
}

/// A prop to hunt for: the household item (big) and what it becomes (smaller line below), with a found check.
struct PTPropCard: View {
    let prop: Prop
    @Binding var found: Bool

    var body: some View {
        Toggle(isOn: $found) {
            // Compact so two rows of 2-line cards still leave room for the bottom controls.
            VStack(spacing: Theme.Space.xs) {
                // Library art only (props come from the library; never an emoji).
                if let id = prop.libraryID, let art = UIImage(named: PropLibrary.asset(id)) {
                    Image(uiImage: art).resizable().scaledToFit().frame(height: 64)
                }
                PTText(prop.householdItem, .headline).lineLimit(2).minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                // Round 23 (Haylee): no arrow; the pretend use is a smaller second line under the item's name.
                Text(prop.becomes)
                    .font(Theme.bodyFont(Theme.TextSize.body)).foregroundStyle(Theme.inkMuted)
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

/// "Pass the iPad to the Captain!" card (round 8, Haylee: "Tap your badge" was confusing; "badge" is also the printed
/// name badge). Round 26 (Haylee's button audit): the new holder taps ONE big green check (no "I'm the Captain!" text:
/// most players can't read), and there's no "Back to the checklist" on the card. Nutmeg points at the card from the
/// shared stage and says the line aloud ("…Tap the green check when you have the iPad!").
struct PTHandoffCard<Figure: View>: View {
    let role: Role
    @ViewBuilder var figure: Figure
    let onTap: () -> Void
    /// Round 10: chat open, the card is pinned at the top of the chat panel (panel width, same big button).
    var pinned = false
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if pinned {
            VStack(spacing: Theme.Space.m) {
                Text("Pass the iPad to \(role.spoken)!").font(Theme.headlineFont(26)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                checkButton
            }
            .padding(.vertical, Theme.Space.s)
            .ptPinnedCard()
        } else {
            VStack(spacing: Theme.Space.l) {
                Text("Pass the iPad to \(role.spoken)!").font(Theme.headlineFont(26)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if Figure.self != EmptyView.self { figure.frame(height: 200) }
                checkButton
            }
            .frame(maxWidth: .infinity)
            .ptCard(fill: Theme.white, edge: Theme.playerColor(role.id.index), padding: Theme.Space.m)
            .offset(x: shown || reduceMotion ? 0 : 700)
            .rotationEffect(.degrees(shown || reduceMotion ? 0 : 8))
            .opacity(shown || !reduceMotion ? 1 : 0)
            .onAppear { withAnimation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove) { shown = true } }
            .sensoryFeedback(.impact(weight: .medium), trigger: shown)
        }
    }

    private var checkButton: some View {
        PTBigIconButton(kind: .check, size: 104, label: "I'm \(role.spoken)! I have the iPad", action: onTap)
            .ptBounce(trigger: shown)
            .padding(.bottom, Theme.depth)
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
/// `.pill` is the black labelled CTA; it keeps `label` as the accessibility label.
struct PTParentGate: View {
    enum Style { case pill }
    let label: String
    var symbol = "printer.fill"
    var seconds: Double = 2
    var style: Style = .pill
    let onComplete: () -> Void
    @State private var progress = 0.0
    @State private var pressing = false

    var body: some View {
        face
            .scaleEffect(pressing ? 0.94 : 1)
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

    @ViewBuilder private var face: some View {
        switch style {
        case .pill:
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
        }
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

/// The big red push-to-talk mic (decisions/2026-11-13-push-to-talk.md), center of the control pill.
/// The whole circle is one press-and-hold target (DragGesture, minimumDistance 0): press → `onPress` with a haptic,
/// release (or the gesture being cancelled) → `onRelease`. `@GestureState` resets on its own, so a cancelled touch
/// always releases. Listening: it sinks a little and a red ring pulses. Disabled (connecting, after planning): gray.
struct PTMicButton: View {
    enum Mode: Equatable { case idle, listening, disabled }
    var mode: Mode
    var size: CGFloat = 92
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    @GestureState private var pressing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var enabled: Bool { mode != .disabled }
    private var listening: Bool { enabled && (mode == .listening || pressing) }

    var body: some View {
        ZStack {
            if listening {
                if reduceMotion {
                    Circle().strokeBorder(Theme.micRed.opacity(0.5), lineWidth: 5).padding(-9)
                } else {
                    TimelineView(.animation) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(0..<2, id: \.self) { i in
                                let phase = (t / 1.1 + Double(i) / 2).truncatingRemainder(dividingBy: 1)
                                Circle().stroke(Theme.micRed, lineWidth: 4)
                                    .scaleEffect(1 + phase * 0.45).opacity(0.7 * (1 - phase))
                            }
                        }
                    }
                }
            }
            Circle().fill(enabled ? Theme.micRed : Theme.disabled)
            Circle().strokeBorder(Theme.white.opacity(listening ? 0.9 : 0), lineWidth: 3).padding(5)
            Image(systemName: listening ? "waveform" : "mic.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(enabled ? Theme.white : Theme.disabledInk)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.variableColor.iterative, isActive: listening && !reduceMotion)
        }
        .frame(width: size, height: size)
        .scaleEffect(listening ? 0.92 : 1)
        .shadow(color: Theme.panelShadow, radius: 8, y: 3)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).updating($pressing) { _, state, _ in state = true },
                 including: enabled ? .all : .none)
        .onChange(of: pressing) { _, isDown in isDown ? onPress() : onRelease() }
        .sensoryFeedback(.impact(weight: .medium), trigger: pressing) { _, new in new }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pressing) { old, new in old && !new }
        .animation(Theme.press, value: listening)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode == .listening ? "Listening. Let go to send" : "Hold to talk to Nutmeg")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { mode == .listening ? onRelease() : onPress() }   // VoiceOver: tap to start, tap to send
        .disabled(!enabled)
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
                        .background { PTStageAccents(showsGround: false) }
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
    let selected: Int?
    let onPick: (Int) -> Void
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            ForEach(1...6, id: \.self) { n in
                // Round 23 (Haylee): 1 to 6 players (was "6+").
                PTChoiceTile(label: "\(n)",
                             isSelected: selected == n, size: Theme.Size.countTile) { onPick(n) }
            }
        }
    }
}

/// Stage title row: big emoji + title.
struct PTStageHeader<Picture: View>: View {
    let title: String
    @ViewBuilder var picture: Picture
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            picture
            PTText(title, .title)
        }
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Typing bubble (round 13)

/// Nutmeg is working on her reply: three dots in her chat-bubble style (left side, gray), pulsing in turn.
/// Replaced by her real line when it starts. Reduce Motion: the dots stay still.
struct PTTypingBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = reduceMotion ? 0 : (sin((t * 2 * .pi / 1.1) - Double(i) * 0.9) + 1) / 2
                    Circle().fill(Theme.inkMuted)
                        .frame(width: 9, height: 9)
                        .opacity(0.35 + 0.65 * phase)
                        .offset(y: -3 * phase)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.chipGray))
        }
        .accessibilityLabel("Nutmeg is thinking")
    }
}

/// Round 26 (Haylee's button audit): kids 4–8 mostly can't read, so the play buttons are big pictures. A round, chunky
/// icon-only button (≥ 64 pt, a pressable depth edge like the start button) with an accessibility label; Nutmeg says
/// what to tap ("Tap the green check…", "Tap the star…").
struct PTBigIconButton: View {
    enum Kind {
        case check, cross, print, play, star, home
        var symbol: String {
            switch self {
            case .check: "checkmark"; case .cross: "xmark"; case .print: "printer.fill"
            case .play: "play.fill"; case .star: "star.fill"; case .home: "house.fill"
            }
        }
        var face: Color {
            switch self {
            case .check, .play: Theme.lime; case .print: Theme.cta; case .cross, .star, .home: Theme.white
            }
        }
        var shade: Color {
            switch self {
            case .check, .play: Theme.limeShade; case .print: Color.black; case .star: Theme.yellowShade
            case .cross: Theme.line; case .home: Theme.lavenderShade
            }
        }
        var ink: Color {
            switch self {
            case .check, .play: Theme.ink; case .print: Theme.white; case .star: Theme.yellow
            case .cross: Theme.coralStrong; case .home: Theme.purple
            }
        }
    }
    let kind: Kind
    var size: CGFloat = 88
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: kind.symbol)
                .font(.system(size: size * (kind == .star ? 0.5 : 0.42), weight: .heavy, design: .rounded))
                .foregroundStyle(kind.ink)
                .offset(x: kind == .play ? size * 0.04 : 0)   // ▶ looks centered when nudged right
                .frame(width: size, height: size)
        }
        .buttonStyle(Style(face: kind.face, shade: kind.shade, outlined: kind.face == Theme.white))
        .accessibilityLabel(label)
    }

    private struct Style: ButtonStyle {
        let face: Color, shade: Color, outlined: Bool
        func makeBody(configuration: Configuration) -> some View {
            let down = configuration.isPressed ? Theme.depth : 0
            configuration.label
                .background(Circle().fill(face))
                .overlay(Circle().strokeBorder(outlined ? Theme.line : .clear, lineWidth: 1.5))
                .offset(y: down)
                .background(Circle().fill(shade).offset(y: Theme.depth))
                .contentShape(Circle())
                .animation(Theme.press, value: configuration.isPressed)
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: configuration.isPressed) { _, new in new }
        }
    }
}
