import SwiftUI
import NutmegCore

/// Round 33: the first-launch parent onboarding (6 screens, shown once; Grown-ups → Replay the intro opens it again).
/// The backstage stage behind a big white card on the left and Nutmeg on the right; a dots row and Back on top. Grown-up
/// text uses Dynamic Type text styles (large by default); Nutmeg speaks only on screen 1 and at the hand-off.
struct OnboardingView: View {
    let model: AppModel
    @State private var webPage: GUWebPage?
    @State private var micWorking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    private var flow: OnboardingFlow { model.onboarding ?? OnboardingFlow() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PTStageBackdrop()
                HStack(alignment: .center, spacing: Theme.Space.l) {
                    card
                        .frame(width: min(geo.size.width * 0.64, 900))
                    nutmeg
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, max(geo.size.width * 0.05, Theme.Space.l))
                .padding(.top, geo.size.height * 0.07)
                .padding(.bottom, Theme.Space.m)
            }
        }
        .ignoresSafeArea(.keyboard)
        .statusBarHidden()
        .guSafari($webPage)
        .animation(reduceMotion ? nil : Theme.gentle, value: flow.screen)
        .task(id: flow.screen) {
            if flow.screen == .hello && !flow.isReplay {
                try? await Task.sleep(for: .milliseconds(600))
                model.onboardingVoice.play(OnboardingCopy.getAGrownUp)
            }
        }
        .onDisappear { if flow.screen == .hello { model.onboardingVoice.stop() } }
    }

    // MARK: Nutmeg

    private var nutmeg: some View {
        NutmegCharacter(state: .idle, mouthLevel: model.onboardingVoice.level,
                        isSpeaking: model.onboardingVoice.speaking, showsGround: true,
                        holdsClipboard: flow.screen != .hello && flow.screen != .handOff)
            .aspectRatio(1178.0 / 1335.0, contentMode: .fit)
            .frame(maxHeight: 440)
    }

    // MARK: The card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.horizontal, Theme.Space.l).padding(.top, Theme.Space.m)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) { screen }
                    .padding(Theme.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(flow.screen)
                    .transition(.opacity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.white))
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.lavenderShade).offset(y: Theme.cardDepth))
        .shadow(color: Theme.panelShadow, radius: 12, y: 4)
    }

    private var topBar: some View {
        HStack {
            if flow.canGoBack {
                Button { model.onboardingUpdate { $0.back() } } label: {
                    Label("Back", systemImage: "chevron.left").font(OBType.button)
                }
                .foregroundStyle(Theme.purple)
                .frame(minHeight: 44)
                .accessibilityHint("Goes to the previous screen")
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<OnboardingScreen.dotCount, id: \.self) { i in
                    Capsule().fill(i == flow.screen.dot ? Theme.purple : Theme.lavenderShade)
                        .frame(width: i == flow.screen.dot ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(flow.screen.dot + 1) of \(OnboardingScreen.dotCount)")
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder private var screen: some View {
        switch flow.screen {
        case .hello: hello
        case .howItWorks: howItWorks
        case .privacy: privacy
        case .aiDeclined: declined
        case .microphone: microphone
        case .plans: PlansContent(model: model, mode: flow.isReplay && model.freePreview.exhausted ? .replay : .onboarding,
                                  onPrimary: { model.onboardingUpdate { $0.startFreePreview() } }, webPage: $webPage)
        case .handOff: handOff
        }
    }

    // 1
    private var hello: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                title(OnboardingCopy.helloTitle)
                Spacer()
                Button { model.onboardingVoice.play(OnboardingCopy.getAGrownUp) } label: {
                    Label("Hear Nutmeg again", systemImage: "speaker.wave.2.fill").font(OBType.small)
                }
                .foregroundStyle(Theme.purple).frame(minHeight: 44)
            }
            para(OnboardingCopy.helloBody)
            PTGrownUpGate(title: OnboardingCopy.gateTitle) { model.onboardingUpdate { $0.passGate() } }
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(Theme.lavender.opacity(0.6)))
        }
    }

    // 2
    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            title(OnboardingCopy.howTitle)
            Text(OnboardingCopy.tagline).font(OBType.lead).foregroundStyle(Theme.purple)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Theme.Space.s, alignment: .top)], spacing: Theme.Space.s) {
                ForEach(OnboardingCopy.steps, id: \.title) { stepCard($0) }
            }
            Text(OnboardingCopy.needTitle).font(OBType.section).foregroundStyle(Theme.ink).padding(.top, Theme.Space.xs)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), alignment: .leading)], alignment: .leading, spacing: Theme.Space.s) {
                ForEach(OnboardingCopy.needs, id: \.text) { n in iconLine(n.symbol, n.text, tint: Theme.nutmeg) }
            }
            primary(OnboardingCopy.next) { model.onboardingUpdate { $0.next() } }
        }
    }

    private func stepCard(_ s: (step: JourneyStep, title: String, body: String)) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: BackNav.symbol(s.step))
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.ink)
                    .frame(width: 46, height: 46).background(Circle().fill(Theme.yellow))
                    .accessibilityHidden(true)
                Text(s.title).font(OBType.section).foregroundStyle(Theme.ink)
            }
            Text(s.body).font(OBType.small).foregroundStyle(Theme.inkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Space.s)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(Theme.cream.opacity(0.55)))
        .accessibilityElement(children: .combine)
    }

    // 3
    private var privacy: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            title(OnboardingCopy.privacyTitle)
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                ForEach(OnboardingCopy.privacyLines, id: \.text) { l in iconLine(l.symbol, l.text, tint: Theme.purple) }
            }
            Button { webPage = GUWebPage(url: GrownUpsLinks.privacy) } label: {
                Label(OnboardingCopy.privacyLink, systemImage: "safari").font(OBType.button)
            }
            .foregroundStyle(Theme.purple).frame(minHeight: 44)
            .accessibilityHint("Opens pretendthat.app/privacy in a browser view")
            Divider()
            Text(OnboardingCopy.consentAsk).font(OBType.lead).foregroundStyle(Theme.ink)
            primary(OnboardingCopy.agree) { model.onboardingUpdate { $0.agree() } }
                .accessibilityHint("Agrees to send your child's words, with names removed, to OpenAI and Anthropic")
            secondary(OnboardingCopy.notNow) { model.onboardingUpdate { $0.notNow() } }
        }
    }

    // 3b: Not now
    private var declined: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            title(OnboardingCopy.declinedTitle)
            para(OnboardingCopy.declinedBody)
            iconLine("lock", OnboardingCopy.declinedHow, tint: Theme.purple)
            primary(OnboardingCopy.declinedBack) { model.onboardingUpdate { $0.back() } }
            secondary(OnboardingCopy.declinedClose) { model.onboardingUpdate { $0.closeWithoutConsent() } }
        }
    }

    // 4: pre-permission (HIG: one Continue, no "Allow", no cancel)
    private var microphone: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            title(OnboardingCopy.micTitle)
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "mic.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.white)
                    .frame(width: 72, height: 72).background(Circle().fill(Theme.micRed))
                Image(systemName: "waveform").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.purple)
                Image(systemName: "text.bubble.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.purple)
            }
            .accessibilityHidden(true)
            para(OnboardingCopy.micBody)
            if flow.micDenied {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(OnboardingCopy.micDeniedTitle).font(OBType.section).foregroundStyle(Theme.ink)
                    Text(OnboardingCopy.micDeniedBody).font(OBType.body).foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(OnboardingCopy.micDeniedSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(OBType.button).foregroundStyle(Theme.purple).frame(minHeight: 44)
                }
                .padding(Theme.Space.s)
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(Theme.cream.opacity(0.6)))
                .accessibilityElement(children: .contain)
                primary(OnboardingCopy.next) { model.onboardingUpdate { $0.next() } }
            } else if flow.micAsked {
                primary(OnboardingCopy.next) { model.onboardingUpdate { $0.next() } }
            } else {
                primary(OnboardingCopy.micContinue) {
                    guard !micWorking else { return }
                    micWorking = true
                    Task { await model.onboardingMicContinue(); micWorking = false }
                }
                .accessibilityHint("Next, your iPad asks to use the microphone and speech recognition")
            }
        }
    }

    // 6
    private var handOff: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            title(OnboardingCopy.handOffTitle)
            Text(OnboardingCopy.handOffBody).font(OBType.lead).foregroundStyle(Theme.ink)
            para(OnboardingCopy.handOffNote)
            primary(OnboardingCopy.handOffButton, symbol: "hand.wave.fill") { model.onboardingUpdate { $0.handOff() } }
        }
    }

    // MARK: Pieces

    private func title(_ s: String) -> some View {
        Text(s).font(OBType.title).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func para(_ s: String) -> some View {
        Text(s).font(OBType.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
    }
    private func iconLine(_ symbol: String, _ text: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
            Image(systemName: symbol).font(OBType.body).foregroundStyle(tint).frame(width: 30).accessibilityHidden(true)
            Text(text).font(OBType.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
    private func primary(_ label: String, symbol: String? = nil, action: @escaping () -> Void) -> some View {
        OBPrimaryButton(label: label, symbol: symbol, action: action)
    }
    private func secondary(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(OBType.button).foregroundStyle(Theme.purple)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().strokeBorder(Theme.purple.opacity(0.5), lineWidth: 2))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Grown-up type: Dynamic Type text styles in the rounded face, a size up from the Grown-ups menu.
enum OBType {
    static let title = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let lead = Font.system(.title2, design: .rounded, weight: .bold)
    static let section = Font.system(.title3, design: .rounded, weight: .heavy)
    static let body = Font.system(.title3, design: .rounded, weight: .medium)
    static let small = Font.system(.body, design: .rounded, weight: .medium)
    static let button = Font.system(.title3, design: .rounded, weight: .bold)
    static let price = Font.system(.title, design: .rounded, weight: .heavy)
    static let footnote = Font.system(.footnote, design: .rounded, weight: .medium)
}

/// The theater's big yellow pressable capsule (the start button's look), full width.
struct OBPrimaryButton: View {
    let label: String
    var symbol: String? = nil
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                Text(label)
            }
            .font(OBType.button).foregroundStyle(enabled ? Theme.ink : Theme.disabledInk)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, Theme.Space.m)
        }
        .buttonStyle(Style(enabled: enabled))
        .disabled(!enabled)
    }
    struct Style: ButtonStyle {
        var enabled: Bool
        func makeBody(configuration: Configuration) -> some View {
            let down = configuration.isPressed ? Theme.depth : 0
            configuration.label
                .background(Capsule().fill(enabled ? Theme.yellow : Theme.disabled))
                .offset(y: down)
                .background(Capsule().fill(enabled ? Theme.yellowShade : Theme.line).offset(y: Theme.depth))
                .contentShape(Capsule())
                .animation(Theme.press, value: configuration.isPressed)
        }
    }
}

// MARK: - Plans (screen 5, and again behind the gate when the Free Preview runs out)

struct PlansContent: View {
    enum Mode { case onboarding, replay, outOfShows }
    let model: AppModel
    let mode: Mode
    var onPrimary: () -> Void
    @Binding var webPage: GUWebPage?
    @State private var period: BillingPeriod = PlanCatalog.defaultPeriod
    @State private var selected = PlanCatalog.showPass.id
    @State private var restoring = false
    @State private var restoreResult: RestoreOutcome?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(mode == .outOfShows ? OnboardingCopy.outOfShowsTitle : OnboardingCopy.plansTitle)
                .font(OBType.title).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
            Text(mode == .outOfShows ? OnboardingCopy.outOfShowsBody : OnboardingCopy.plansBody)
                .font(OBType.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            if mode != .outOfShows {
                OBPrimaryButton(label: mode == .replay ? OnboardingCopy.continueButton : OnboardingCopy.freePreviewButton,
                                symbol: mode == .replay ? nil : "ticket.fill", action: onPrimary)
                    .accessibilityHint("\(PlanCatalog.freePreviewShows) free new shows, no card")
            }
            Picker("Billing", selection: $period) {
                ForEach(BillingPeriod.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .accessibilityLabel("Billing period")
            // Side by side (the text wraps); stacked at accessibility text sizes.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Theme.Space.s) { cards }
            } else {
                HStack(alignment: .top, spacing: Theme.Space.s) { cards }
            }
            OBPrimaryButton(label: OnboardingCopy.comingSoon, enabled: false) {}
                .accessibilityLabel("\(PlanCatalog.offers.first { $0.id == selected }?.name ?? "Plan"): coming soon")
            Text(OnboardingCopy.comingSoonNote).font(OBType.small).foregroundStyle(Theme.inkMuted)
            HStack(spacing: Theme.Space.m) {
                Button {
                    restoring = true
                    Task { restoreResult = await PTStore.restore(); restoring = false; model.planStatus = await PTStore.planStatus() }
                } label: { Text(restoring ? GrownUpsCopy.restoring : OnboardingCopy.restore) }
                    .disabled(restoring)
                Button(OnboardingCopy.terms) { webPage = GUWebPage(url: GrownUpsLinks.terms) }
                Button(OnboardingCopy.privacy) { webPage = GUWebPage(url: GrownUpsLinks.privacy) }
            }
            .font(OBType.small.weight(.bold)).foregroundStyle(Theme.purple)
            .frame(minHeight: 44)
            if let r = restoreResult {
                Text(r.message).font(OBType.small).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            Text(OnboardingCopy.plansFooter).font(OBType.footnote).foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var cards: some View {
        ForEach(PlanCatalog.offers) { offer in
            let on = selected == offer.id
            Button { selected = offer.id } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(offer.name).font(OBType.section).foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(on ? Theme.purple : Theme.line)
                    }
                    Text(offer.billedText(period)).font(OBType.price).foregroundStyle(Theme.ink)
                    // Monthly: the renewal price in body text (Apple: the regular price stays visible); yearly: the
                    // per-month line, smaller.
                    Text(offer.detailText(period)).font(period == .monthly ? OBType.small : OBType.footnote)
                        .foregroundStyle(period == .monthly ? Theme.ink : Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(offer.showsText) (\(OnboardingCopy.plannedNote))").font(OBType.small).foregroundStyle(Theme.ink)
                    Text(OnboardingCopy.replaysLine).font(OBType.small).foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(on ? Theme.lavender : Theme.white))
                .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius).strokeBorder(on ? Theme.purple : Theme.line, lineWidth: on ? 3 : 1.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(offer.name), \(period == .monthly ? offer.introOfferText : offer.billedText(period)), \(offer.showsText), planned")
            .accessibilityAddTraits(on ? .isSelected : [])
        }
    }
}

/// The plans behind the gate (New game with the Free Preview used up).
struct PlansSheet: View {
    let model: AppModel
    @State private var unlocked = false
    @State private var webPage: GUWebPage?
    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if unlocked {
                        PlansContent(model: model, mode: .outOfShows, onPrimary: {}, webPage: $webPage)
                    } else {
                        PTGrownUpGate(onPass: { withAnimation(Theme.gentle) { unlocked = true } }).frame(maxWidth: .infinity)
                    }
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.white)
            .navigationTitle(unlocked ? "Plans" : "")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { model.showingPlans = false } } }
        }
        .tint(Theme.purple)
        .guSafari($webPage)
        .modifier(GUPageSizing())
    }
}

// MARK: - The kid card on the start screen (New game was blocked; no prices)

struct KidBlockCard: View {
    let model: AppModel
    let block: NewGameGate
    var body: some View {
        ZStack {
            Theme.scrim.ignoresSafeArea().onTapGesture { model.kidBlock = nil }
            VStack(spacing: Theme.Space.m) {
                Image(systemName: block == .needsPlan ? "ticket.fill" : "person.2.fill")
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.purple)
                    .frame(width: 76, height: 76).background(Circle().fill(Theme.lavender))
                    .accessibilityHidden(true)
                Text(block == .needsPlan ? OnboardingCopy.kidOutOfShows : OnboardingCopy.kidNeedsGrownUp)
                    .font(Theme.headlineFont(Theme.TextSize.headline)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                if block == .needsConsent {
                    VStack(spacing: Theme.Space.xs) {
                        Text(OnboardingCopy.declinedTitle).font(OBType.section).foregroundStyle(Theme.ink)
                        Text(OnboardingCopy.declinedBody).font(OBType.small).foregroundStyle(Theme.inkMuted)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                if block == .needsPlan && !model.shelfGames.isEmpty {
                    Text("You can still play your saved games!").font(OBType.small).foregroundStyle(Theme.inkMuted)
                }
                HStack(spacing: Theme.Space.s) {
                    Button { model.kidBlock = nil } label: {
                        Text("OK").font(OBType.button).foregroundStyle(Theme.purple)
                            .frame(minWidth: 120, minHeight: 56)
                            .background(Capsule().strokeBorder(Theme.purple.opacity(0.5), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    OBPrimaryButton(label: OnboardingCopy.kidGrownUpsButton, symbol: "lock") { model.openGrownUpsFromKidCard() }
                        .frame(maxWidth: 240)
                }
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: 560)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.white))
            .accessibilityElement(children: .contain)
        }
        .transition(.opacity)
    }
}
