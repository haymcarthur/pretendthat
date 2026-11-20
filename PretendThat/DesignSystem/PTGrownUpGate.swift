import SwiftUI
import NutmegCore

/// Round D2: the parental gate (Haylee: hold a button for 2 seconds, then tap the number that's spelled out in words).
/// A wrong number is a gentle reset: back to the hold, with a new number. No voice (Nutmeg stays quiet). Reusable in
/// front of anything grown-ups-only (section E: purchases, outside links). The logic lives in NutmegCore `GrownUpGate`.
struct PTGrownUpGate: View {
    /// What's behind the gate, for the heading ("Grown-ups only").
    var title = "Grown-ups only"
    var onPass: () -> Void
    var onCancel: (() -> Void)? = nil

    @State private var gate = GrownUpGate()
    @State private var pressing = false
    @State private var pressStart: Date?
    @State private var progress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(title: String = "Grown-ups only", onPass: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.title = title; self.onPass = onPass; self.onCancel = onCancel
        #if DEBUG
        // Screenshots: -PTGrownUps holding (ring part filled) / grid (the number question).
        switch DemoDriver.grownUps {
        case "holding": _progress = State(initialValue: 0.6); _pressing = State(initialValue: true)
        case "grid": var g = GrownUpGate(seed: 47); g.holdEnded(after: 2); _gate = State(initialValue: g)
        default: break
        }
        #endif
    }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .semibold)).foregroundStyle(Theme.purple)
                .frame(width: 64, height: 64).background(Circle().fill(Theme.lavender))
                .accessibilityHidden(true)
            Text(title).font(GrownUpFont.heading(Theme.TextSize.headline, relativeTo: .title)).kerning(GrownUpFont.headingKerning(Theme.TextSize.headline)).foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            switch gate.step {
            case .hold: holdStep
            case .question(_, let options): questionStep(options)
            case .passed: EmptyView()
            }
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: 520)
        .animation(reduceMotion ? nil : Theme.gentle, value: gate.step)
        .onChange(of: gate.step) { _, step in if step == .passed { onPass() } }
    }

    // MARK: Step 1: hold

    private var holdStep: some View {
        VStack(spacing: Theme.Space.m) {
            Text(gate.misses > 0 ? "Not quite. Let's try again." : "Press and hold the button for 2 seconds.")
                .font(GrownUpFont.font(.medium, size: Theme.TextSize.body, relativeTo: .title3)).foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
            holdButton
        }
        .transition(.opacity)
    }

    private var holdButton: some View {
        HStack(spacing: Theme.Space.s) {
            ZStack {
                Circle().stroke(Theme.white.opacity(0.25), lineWidth: 4)
                Circle().trim(from: 0, to: progress).stroke(Theme.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "hand.tap").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.white)
            }
            .frame(width: 44, height: 44)
            Text(pressing ? "Keep holding…" : "Hold for 2 seconds").font(GrownUpFont.heading(22, relativeTo: .title2)).foregroundStyle(Theme.white)
        }
        .padding(.leading, Theme.Space.s).padding(.trailing, Theme.Space.l)
        .frame(minHeight: 72)
        .background(Capsule().fill(Theme.cta))
        .scaleEffect(pressing ? 0.96 : 1)
        .animation(Theme.press, value: pressing)
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: GrownUpGate.holdSeconds, maximumDistance: 60) {
            let held = pressStart.map { Date().timeIntervalSince($0) } ?? GrownUpGate.holdSeconds
            // The gesture fires at 2 s; a tiny early fire (timer rounding) still counts as the full hold.
            gate.holdEnded(after: max(held, GrownUpGate.holdSeconds))
            pressing = false; pressStart = nil; progress = 0
        } onPressingChanged: { isPressing in
            pressing = isPressing
            if isPressing {
                pressStart = Date()
                withAnimation(.linear(duration: GrownUpGate.holdSeconds)) { progress = 1 }
            } else if gate.step == .hold {
                pressStart = nil
                withAnimation(Theme.gentle) { progress = 0 }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: pressing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grown-ups: hold for 2 seconds")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to continue to the grown-up question")
        .accessibilityAction { gate.holdEnded(after: GrownUpGate.holdSeconds) }
    }

    // MARK: Step 2: the spelled-out number

    private func questionStep(_ options: [Int]) -> some View {
        VStack(spacing: Theme.Space.m) {
            (Text("Tap the number ").foregroundStyle(Theme.inkMuted)
             + Text(gate.words ?? "").foregroundStyle(Theme.purple))
                .font(GrownUpFont.font(.medium, size: Theme.TextSize.headline, relativeTo: .title))
                .multilineTextAlignment(.center)
                .accessibilityLabel("Tap the number \(gate.words ?? "")")
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(104), spacing: Theme.Space.s), count: 3), spacing: Theme.Space.s) {
                ForEach(options, id: \.self) { n in
                    Button { gate.answer(n) } label: {
                        Text("\(n)").font(GrownUpFont.heading(34, relativeTo: .largeTitle)).foregroundStyle(Theme.ink)
                            .frame(width: 104, height: 76)
                    }
                    .buttonStyle(NumberKey())
                    .accessibilityLabel("\(n)")
                }
            }
            if let onCancel {
                Button("Cancel", action: onCancel).font(GrownUpFont.font(.medium, size: 18, relativeTo: .body)).foregroundStyle(Theme.inkMuted)
                    .frame(minHeight: 44)
            }
        }
        .transition(.opacity)
    }

    private struct NumberKey: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            let down = configuration.isPressed ? Theme.edge(44) : 0   // 2026-11-20: the slim edge (`Theme.edge`)
            configuration.label
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.white))
                .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
                .offset(y: down)
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.lavenderShade).offset(y: Theme.edge(44)))
                .animation(Theme.press, value: configuration.isPressed)
        }
    }
}

/// The Grown-ups corner button (round D2's "Grown-ups" pill; home stage polish, Haylee 2026-11-17: a gear icon only,
/// tucked into the top corner). The app's icon-button look (white circle, ink symbol, soft shadow, like the bookshelf's
/// Back), so it reads over the curtain and the valance. VoiceOver still says "Grown-ups"; the same gate is behind it.
struct PTGrownUpsGear: View {
    var size: CGFloat = 48
    let action: () -> Void
    var body: some View {
        PTIconButton(symbol: "gearshape.fill", label: "Grown-ups", fill: Theme.white, size: size, action: action)
            .shadow(color: Theme.panelShadow, radius: 8, y: 2)
            .accessibilityHint("For grown-ups: manage saved games")
            .accessibilityIdentifier("home.grownUps")
    }
}
