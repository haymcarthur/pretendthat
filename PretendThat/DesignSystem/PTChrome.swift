import SwiftUI
import UIKit
import NutmegCore

// ToyCAD-style layout and chrome (decision layout-toycad-style.md): flat angular color-block background,
// dark floating chrome (step rail, control pill, chat panel), big rounded item cards fanned around Nutmeg.
// Everything crisp: no blur, no gradients, no glows. Nutmeg stays flat.

// MARK: - Canvas

/// The app canvas (style revised): a clean very light warm gray, nothing else. The shard background was dropped.
struct PTCanvas: View {
    var body: some View { Theme.canvas.ignoresSafeArea().accessibilityHidden(true) }
}

/// Nutmeg's contact shadow: a crisp, low-contrast ellipse in a darker tone of the wooden floor (no blur, not gray).
struct PTGround: View {
    var body: some View {
        Ellipse().fill(Theme.stageFloorEdge.opacity(0.6)).accessibilityHidden(true)
    }
}

/// White rounded panel with the one allowed soft effect: a small, low-opacity shadow.
struct PTPanelModifier: ViewModifier {
    var radius: CGFloat = 26
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.white))
            .shadow(color: Theme.panelShadow, radius: 10, y: 3)
    }
}
extension View {
    func ptPanel(radius: CGFloat = 26) -> some View { modifier(PTPanelModifier(radius: radius)) }
}

/// A round light-gray icon button with a thin line icon. Selected: thin dark ring and/or a brand fill.
struct PTIconButton: View {
    let symbol: String
    let label: String
    var selected = false
    var fill: Color? = nil
    var size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .regular))
                .foregroundStyle(fill == nil || fill == Theme.chipGray ? Theme.ink : Theme.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .background(Circle().fill(fill ?? Theme.chipGray))
                .overlay(Circle().strokeBorder(selected ? Theme.ink : .clear, lineWidth: 1.5).padding(-4))
        }
        .buttonStyle(TileButtonStyle())
        .accessibilityLabel(label)
    }
}

/// Small deterministic RNG so each step's background is always the same.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

// MARK: - Step rail

/// Vertical white rounded panel with the 4 journey steps as round buttons and tiny labels. Done = lime with a check,
/// current = saturated brand yellow (the stage-star fill, FFC93C) with a thin dark ring and bold ink number/label,
/// upcoming = light gray. The current step is never `.disabled` (that dims it and made it read as inactive);
/// taps on it are ignored instead. A connector fills (lime) between steps as progress.
/// Reached steps are tappable (jump back).
struct PTStepRail: View {
    var current: JourneyStep?
    var reached: JourneyStep?
    var onTap: (JourneyStep) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(JourneyStep.allCases, id: \.self) { step in
                if step != .game { connector(filled: (current?.rawValue ?? -1) >= step.rawValue) }
                stepButton(step)
            }
        }
        .padding(.vertical, Theme.Space.m)
        .padding(.horizontal, Theme.Space.s)
        .ptPanel(radius: 28)
        .animation(Theme.springy, value: current)
    }

    private func stepButton(_ s: JourneyStep) -> some View {
        let cur = current?.rawValue ?? -1, max = reached?.rawValue ?? -1
        let done = s.rawValue < cur, isCurrent = s == current, reachable = s.rawValue <= max
        return Button { if !isCurrent { onTap(s) } } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(done ? Theme.lime : (isCurrent ? Theme.yellow : Theme.chipGray))
                    if isCurrent { Circle().strokeBorder(Theme.ink, lineWidth: 1.5).padding(-4) }
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.ink)
                    } else {
                        Text("\(s.rawValue + 1)").font(Theme.uiFont(20, isCurrent ? .heavy : .semibold)).foregroundStyle(Theme.ink.opacity(isCurrent || reachable ? 1 : 0.4))
                    }
                }
                .frame(width: 56, height: 56)
                Text(s.label).font(Theme.uiFont(12, isCurrent ? .bold : .medium))
                    .foregroundStyle(Theme.ink.opacity(isCurrent ? 1 : (reachable ? 0.8 : 0.35)))
                    .lineLimit(1).fixedSize()
            }
            .frame(minWidth: 72, minHeight: 64)
        }
        .buttonStyle(.plain)
        .disabled(!reachable && !isCurrent)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityLabel("\(s.label)\(done ? ", done" : isCurrent ? ", now" : "")")
    }

    private func connector(filled: Bool) -> some View {
        Capsule().fill(filled ? Theme.lime : Theme.chipGray)
            .frame(width: 4, height: 18)
            .padding(.vertical, 4)
    }
}

// MARK: - Control pill

/// Floating white control pill (decisions/2026-11-13-push-to-talk.md, Haylee round 6): close LEFT (asks first:
/// `PTLeaveDialog`) · the big red push-to-talk mic CENTER (`PTMicButton`, larger than the others) · chat toggle RIGHT
/// (dark ring when open). The white backing hugs the buttons: `PTMicPillShape`, a pill that swells into a circle
/// around the mic with smooth concave fillets.
struct PTControlBar: View {
    var chatOpen: Bool
    var mic: PTMicButton.Mode
    var onChat: () -> Void
    var onMicPress: () -> Void = {}
    var onMicRelease: () -> Void = {}
    var onClose: () -> Void

    static let side: CGFloat = 64, micSize: CGFloat = 92, inset: CGFloat = 10, gap: CGFloat = 20

    var body: some View {
        // Tight (Haylee): ~10 pt between a side button and the mic's circular backing.
        HStack(spacing: Self.gap) {
            PTIconButton(symbol: "xmark", label: "Leave the game", size: Self.side, action: onClose)
            PTMicButton(mode: mic, size: Self.micSize, onPress: onMicPress, onRelease: onMicRelease)
            PTIconButton(symbol: "bubble.left.and.bubble.right", label: chatOpen ? "Hide chat" : "Show chat",
                         selected: chatOpen, size: Self.side, action: onChat)
        }
        .padding(.horizontal, Self.inset)
        .padding(.vertical, Self.inset)
        .background(PTMicPillShape(pillHeight: Self.side + Self.inset * 2, circleRadius: Self.micSize / 2 + Self.inset)
            .fill(Theme.white)
            .shadow(color: Theme.panelShadow, radius: 10, y: 3))
    }
}

/// A horizontal pill (height `pillHeight`, capsule ends) whose middle swells into a circle (`circleRadius`), joined by
/// concave fillets (`fillet`) so there are no hard corners. Drawn in the frame's full height (the circle's diameter),
/// the pill centered vertically. Arcs are sampled as points so the geometry is explicit (y down, angles clockwise).
struct PTMicPillShape: Shape {
    var pillHeight: CGFloat
    var circleRadius: CGFloat
    var fillet: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let a = min(pillHeight / 2, rect.height / 2), R = max(circleRadius, a), f = fillet
        let cx = rect.midX, cy = rect.midY, L = rect.minX + a, Rt = rect.maxX - a
        // Fillet centers sit outside the pill edge (distance a + f from the axis) and touch the circle externally.
        let xf = ((R + f) * (R + f) - (a + f) * (a + f)).squareRoot()
        var p = Path()
        func arc(_ c: CGPoint, _ r: CGFloat, _ from: Double, _ to: Double) {
            let steps = 24
            for k in 0...steps {
                let t = (from + (to - from) * Double(k) / Double(steps)) * .pi / 180
                let pt = CGPoint(x: c.x + r * CGFloat(cos(t)), y: c.y + r * CGFloat(sin(t)))
                if p.isEmpty { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
        func deg(_ y: CGFloat, _ x: CGFloat) -> Double { Double(atan2(y, x)) * 180 / .pi }
        guard R > a + 0.5, cx - xf > L, cx + xf < Rt else {   // no swell (or too narrow): a plain capsule
            return Capsule().path(in: CGRect(x: rect.minX, y: cy - a, width: rect.width, height: 2 * a))
        }
        arc(CGPoint(x: L, y: cy), a, 90, 270)                                              // left cap
        p.addLine(to: CGPoint(x: cx - xf, y: cy - a))
        arc(CGPoint(x: cx - xf, y: cy - a - f), f, 90, deg(a + f, xf))                     // top-left fillet
        arc(CGPoint(x: cx, y: cy), R, deg(-(a + f), -xf) + 360, deg(-(a + f), xf) + 360)   // circle, top
        arc(CGPoint(x: cx + xf, y: cy - a - f), f, deg(a + f, -xf), 90)                    // top-right fillet
        p.addLine(to: CGPoint(x: Rt, y: cy - a))
        arc(CGPoint(x: Rt, y: cy), a, 270, 450)                                            // right cap
        p.addLine(to: CGPoint(x: cx + xf, y: cy + a))
        arc(CGPoint(x: cx + xf, y: cy + a + f), f, 270, deg(-(a + f), -xf) + 360)          // bottom-right fillet
        arc(CGPoint(x: cx, y: cy), R, deg(a + f, xf), deg(a + f, -xf))                     // circle, bottom
        arc(CGPoint(x: cx - xf, y: cy + a + f), f, deg(-(a + f), xf), -90)                 // bottom-left fillet
        p.closeSubpath()
        return p
    }
}

/// "Leave the game?" (decisions/2026-11-13-push-to-talk.md): a friendly kid-and-grown-up confirm in the app's style
/// (white rounded panel over a soft scrim, big words, the black primary pill to stay). Tapping the scrim keeps playing.
struct PTLeaveDialog: View {
    var onStay: () -> Void
    var onLeave: () -> Void

    var body: some View {
        ZStack {
            Theme.scrim.ignoresSafeArea()
                .onTapGesture(perform: onStay)
                .accessibilityLabel("Keep playing")
                .accessibilityAddTraits(.isButton)
            VStack(spacing: Theme.Space.m) {
                HStack(spacing: Theme.Space.s) {
                    Image("stage-star").resizable().scaledToFit().frame(width: 36, height: 36).rotationEffect(.degrees(-12))
                    Text("Leave the game?").font(Theme.displayFont(34)).foregroundStyle(Theme.ink)
                    Image("stage-star").resizable().scaledToFit().frame(width: 36, height: 36).rotationEffect(.degrees(12))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Text("If you leave now, you'll start a new game next time.")
                    .font(Theme.uiFont(20, .medium)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Space.s) {
                    Button("Leave", action: onLeave).buttonStyle(.ptSecondary)
                    Button("Keep playing", action: onStay).buttonStyle(.ptPrimary)
                }
                .padding(.top, Theme.Space.xs)
            }
            .padding(.horizontal, Theme.Space.l).padding(.vertical, Theme.Space.l)
            .frame(maxWidth: 460)
            .ptPanel(radius: 32)
            .padding(Theme.Space.m)
            .accessibilityAddTraits(.isModal)
        }
    }
}

// MARK: - Chat panel

/// Dark rounded panel from the right: the live transcript as bubbles and a native TextField to type to Nutmeg.
struct PTChatPanel: View {
    struct Line: Identifiable, Equatable { let id: UUID; let fromNutmeg: Bool; let text: String }
    var lines: [Line]
    var onSend: (String) -> Void
    var onClose: () -> Void
    /// A card docked at the top while the panel is open: the hunt's active prop (prop-gathering-flow.md) or the kit
    /// papers with the Print pill. The transcript scrolls beneath it. `pinnedKey` changes animate it in place.
    var pinnedKey: String? = nil
    var pinned: AnyView? = nil
    @State private var draft = ""
    @FocusState private var focused: Bool
    @State private var following = true
    @State private var hasUnseen = false
    private static let bottomID = "chat-bottom"
    /// Changes when a line is added or the last line's text grows (streaming).
    private var followKey: String { "\(lines.count)-\(lines.last?.text.count ?? 0)" }

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack {
                Text("Chat with Nutmeg").font(Theme.uiFont(18)).foregroundStyle(Theme.ink)
                Spacer()
                PTIconButton(symbol: "xmark", label: "Close chat", size: 44, action: onClose)
            }
            if let pinned, let pinnedKey {
                pinned
                    // Sticky above the transcript; the next prop animates in place; it slides away when it ends.
                    .id(pinnedKey)
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity),
                                            removal: .move(edge: .top).combined(with: .opacity)))
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Space.s) {
                        if lines.isEmpty {
                            Text("Talk or type. Nutmeg's words show up here.")
                                .font(Theme.uiFont(15, .medium)).foregroundStyle(Theme.inkMuted)
                                .frame(maxWidth: .infinity).padding(.top, Theme.Space.l)
                        }
                        ForEach(lines) { line in bubble(line).id(line.id) }
                    }
                    .padding(.vertical, Theme.Space.xs)
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .scrollIndicators(.hidden)
                // Follow the newest entry (a new line, or Nutmeg's streaming text growing) unless the reader scrolled up
                // to read older messages; then a "New" pill jumps back and following resumes at the bottom.
                .modifier(ScrolledToBottom { atBottom in
                    following = atBottom
                    if atBottom { hasUnseen = false }
                })
                .onChange(of: followKey) { _, _ in
                    if following { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) } }
                    else { hasUnseen = true }
                }
                .onAppear { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                // The newest line stays in view when the panel opens or the pinned hunt card appears / changes height.
                .task(id: "\(pinnedKey ?? "")-\(lines.isEmpty)") {
                    try? await Task.sleep(for: .milliseconds(150))
                    following = true; hasUnseen = false
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
                .overlay(alignment: .bottom) {
                    if hasUnseen && !following {
                        Button {
                            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                        } label: {
                            Label("New", systemImage: "arrow.down").font(Theme.uiFont(14)).foregroundStyle(Theme.white)
                                .padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(Theme.cta))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, Theme.Space.xs)
                        .transition(.opacity)
                    }
                }
            }
            HStack(spacing: Theme.Space.s) {
                TextField("Type to Nutmeg", text: $draft)
                    .font(Theme.uiFont(17, .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, Theme.Space.m).frame(height: 52)
                    .background(Capsule().fill(Theme.chipGray))
                    .focused($focused).submitLabel(.send).onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.white)
                        .frame(width: 52, height: 52).background(Circle().fill(Theme.cta))
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Send")
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: pinnedKey)
        .padding(Theme.Space.m)
        .frame(width: 360)
        .frame(maxHeight: .infinity)
        .ptPanel(radius: 28)
    }

    private func bubble(_ line: Line) -> some View {
        HStack {
            if !line.fromNutmeg { Spacer(minLength: 40) }
            Text(line.text).font(Theme.uiFont(16, .medium))
                .foregroundStyle(line.fromNutmeg ? Theme.ink : Theme.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(line.fromNutmeg ? Theme.chipGray : Theme.cta))
            if line.fromNutmeg { Spacer(minLength: 40) }
        }
        .accessibilityLabel("\(line.fromNutmeg ? "Nutmeg" : "You"): \(line.text)")
    }

    private func send() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSend(t); draft = ""
        following = true
        focused = true   // keep typing without tapping the field again
    }
}

/// Reports whether a scroll view is at (or near) its bottom (iOS 18+; on 17 it always follows).
private struct ScrolledToBottom: ViewModifier {
    let onChange: (Bool) -> Void
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { g in
                g.contentOffset.y + g.containerSize.height >= g.contentSize.height - 24
            } action: { _, atBottom in onChange(atBottom) }
        } else {
            content
        }
    }
}

// MARK: - Item card

/// A presented thing (game idea, role, prop): white rounded card, the illustration as the hero, a small medium-weight
/// label, a small light-gray tag pill (top-left) and state chip (top-right). Subtle panel shadow. Brand color only as
/// a thin accent bar (the role/player color).
struct PTItemCard: View {
    enum Chip: Equatable { case none, found, swapped, pretend }
    let item: PTStageItem
    var chip: Chip = .none
    var width: CGFloat = 210
    @State private var flip: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let image = item.image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .saturation(item.isPretend ? 0 : 1).opacity(item.isPretend ? 0.45 : 1)
                        .transition(.opacity)
                } else {
                    PTShimmer(tint: item.tint)
                }
            }
            // No tag pill (Haylee): the card is just the art, the name and the "becomes" line; art sits a bit higher.
            .frame(width: width * 0.76, height: width * 0.76)
            .padding(.top, Theme.Space.m)
            .animation(.easeOut(duration: 0.3), value: item.image != nil)
            // Wraps to 2 lines and shrinks a long single word instead of truncating it ("Airplan…").
            Text(item.title).font(Theme.uiFont(18)).foregroundStyle(Theme.ink)
                .lineLimit(2).minimumScaleFactor(0.5).allowsTightening(true).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
            if let sub = item.isPretend ? "We'll pretend!" : item.subtitle {
                // Never truncated (Haylee, round 6): wraps and the card grows.
                Text(sub).font(Theme.uiFont(14, .medium)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Space.s).padding(.bottom, Theme.Space.m)
        .frame(width: width)
        .ptPanel(radius: 26)
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])).opacity(item.isPretend ? 1 : 0))
        .overlay(alignment: .topTrailing) { chipView.padding(10) }
        .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .animation(.easeInOut(duration: 0.3), value: item.isPretend)
        .onChange(of: item.flipKey) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { flip += 360 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([item.title, item.isPretend ? "pretend" : item.subtitle].compactMap { $0 }.joined(separator: ", "))
    }

    @ViewBuilder private var chipView: some View {
        switch chip {
        case .none: EmptyView()
        case .found: chipCircle("checkmark", fill: Theme.lime)
        case .swapped: chipCircle("arrow.triangle.2.circlepath", fill: Theme.chipGray)
        case .pretend:
            Text("pretend").font(Theme.uiFont(12, .medium)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(height: 28).background(Capsule().fill(Theme.chipGray))
        }
    }

    private func chipCircle(_ symbol: String, fill: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            .frame(width: 28, height: 28).background(Circle().fill(fill))
    }
}

// MARK: - Fan layout

/// Cards fanned in an arc around a center (Nutmeg): slight rotation per card, overlapping a little.
enum PTFan {
    /// Position and tilt for card i of n: half the cards on Nutmeg's left, half on her right, each side a gentle arc.
    static func slot(_ i: Int, of n: Int, in size: CGSize, cardWidth: CGFloat) -> (point: CGPoint, tilt: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.47)
        let rx = size.width * 0.34, ry = size.height * 0.36
        let leftCount = (n + 1) / 2
        let isLeft = i < leftCount
        let count = isLeft ? leftCount : n - leftCount
        let k = isLeft ? i : i - leftCount
        let t = count <= 1 ? 0.5 : Double(k) / Double(count - 1)          // 0 = top of the arc
        let deg = isLeft ? 142 + 76 * t : 38 - 76 * t                      // left: 142°→218°, right: 38°→-38°
        let rad = deg * .pi / 180
        let point = CGPoint(x: center.x + rx * CGFloat(cos(rad)), y: center.y - ry * CGFloat(sin(rad)))
        let tilt = (isLeft ? -1.0 : 1.0) * (-7 + 14 * t)                   // fan: tops lean out, bottoms lean in
        return (point, tilt)
    }
}
