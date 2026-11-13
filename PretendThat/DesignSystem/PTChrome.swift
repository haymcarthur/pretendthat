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

/// A soft flat ground oval under Nutmeg (crisp edge, no blur).
struct PTGround: View {
    var body: some View {
        Ellipse().fill(Theme.ground).accessibilityHidden(true)
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

/// Floating white pill with round gray icon buttons: mute/unmute (coral when muted, a small lime listening dot),
/// chat panel toggle (dark ring when open), leave.
struct PTControlBar: View {
    var isMuted: Bool
    var isListening: Bool
    var chatOpen: Bool
    var micAvailable = true
    var onMute: () -> Void
    var onChat: () -> Void
    var onLeave: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            PTIconButton(symbol: isMuted || !micAvailable ? "mic.slash" : "mic", label: isMuted ? "Unmute" : "Mute",
                         fill: isMuted ? Theme.coral : nil, action: onMute)
                .overlay(alignment: .topTrailing) {
                    if isListening && !isMuted {
                        Circle().fill(Theme.lime).frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(Theme.white, lineWidth: 2.5))
                            .transition(.scale)
                    }
                }
            PTIconButton(symbol: "bubble.left.and.bubble.right", label: chatOpen ? "Hide chat" : "Show chat",
                         selected: chatOpen, action: onChat)
            PTIconButton(symbol: "xmark", label: "Leave", action: onLeave)
        }
        .padding(10)
        .background(Capsule().fill(Theme.white))
        .shadow(color: Theme.panelShadow, radius: 10, y: 3)
        .animation(Theme.springy, value: isListening)
    }
}

// MARK: - Chat panel

/// Dark rounded panel from the right: the live transcript as bubbles and a native TextField to type to Nutmeg.
struct PTChatPanel: View {
    struct Line: Identifiable, Equatable { let id: UUID; let fromNutmeg: Bool; let text: String }
    var lines: [Line]
    var onSend: (String) -> Void
    var onClose: () -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Theme.Space.s) {
            HStack {
                Text("Chat with Nutmeg").font(Theme.uiFont(18)).foregroundStyle(Theme.ink)
                Spacer()
                PTIconButton(symbol: "xmark", label: "Close chat", size: 44, action: onClose)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Space.s) {
                        if lines.isEmpty {
                            Text("Talk or type. Nutmeg's words show up here.")
                                .font(Theme.uiFont(15, .medium)).foregroundStyle(Theme.inkMuted)
                                .frame(maxWidth: .infinity).padding(.top, Theme.Space.l)
                        }
                        ForEach(lines) { line in bubble(line).id(line.id) }
                    }
                    .padding(.vertical, Theme.Space.xs)
                }
                .scrollIndicators(.hidden)
                .onChange(of: lines.count) { _, _ in
                    if let last = lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
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
    }
}

// MARK: - Item card

/// A presented thing (game idea, role, prop): white rounded card, the illustration as the hero, a small medium-weight
/// label, a small light-gray tag pill (top-left) and state chip (top-right). Subtle panel shadow. Brand color only as
/// a thin accent bar (the role/player color).
struct PTItemCard: View {
    enum Chip: Equatable { case none, found, swapped, pretend }
    let item: PTStageItem
    var tag: String? = nil
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
            .frame(width: width * 0.72, height: width * 0.72)
            .padding(.top, 34)
            .animation(.easeOut(duration: 0.3), value: item.image != nil)
            // Wraps to 2 lines and shrinks a long single word instead of truncating it ("Airplan…").
            Text(item.title).font(Theme.uiFont(18)).foregroundStyle(Theme.ink)
                .lineLimit(2).minimumScaleFactor(0.5).allowsTightening(true).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
            if let sub = item.isPretend ? "We'll pretend!" : item.subtitle {
                Text(sub).font(Theme.uiFont(14, .medium)).foregroundStyle(Theme.inkMuted).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, Theme.Space.s).padding(.bottom, Theme.Space.m)
        .frame(width: width)
        .ptPanel(radius: 26)
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])).opacity(item.isPretend ? 1 : 0))
        .overlay(alignment: .topLeading) {
            if let tag {
                HStack(spacing: 5) {
                    Circle().fill(item.tint).frame(width: 8, height: 8)
                    Text(tag).font(Theme.uiFont(12, .medium)).foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Theme.chipGray)).padding(12)
            }
        }
        .overlay(alignment: .topTrailing) { chipView.padding(10) }
        .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .animation(.easeInOut(duration: 0.3), value: item.isPretend)
        .onChange(of: item.flipKey) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { flip += 360 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([tag, item.title, item.isPretend ? "pretend" : item.subtitle].compactMap { $0 }.joined(separator: ", "))
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
