import SwiftUI
import NutmegCore

/// Onboarding v3 (round 44; Haylee approved design/mockups/onboarding-v3, decisions/2026-11-17-onboarding-v3-feedback.md).
/// Six calm pages in ONE layout: a light lavender-white page, a thin 6-part progress bar with a small round back button,
/// one simple visual that takes the free space, a short Poppins title, one gray line and one full-width purple pill.
/// Nothing scrolls on any iPhone (the iPhone 17e, 375 × 812, is the smallest) or iPad at the default text sizes; the
/// iPad shows the same single column, 460 pt wide and centered. At very large text sizes the page falls back to a
/// scroll view instead of clipping.
///
/// Nutmeg's voice: only page 1 has a clip (her bundled recording through her one speaker), played only while she's on
/// screen there (the start screen's toy chest), never on a replay, never TTS. Her mouth follows the clip.
struct OnboardingView: View {
    let model: AppModel
    @State private var webPage: GUWebPage?
    @State private var micWorking = false
    @State private var restoring = false
    @State private var restoreResult: RestoreOutcome?
    /// Round 38: page 5's purchases (no gate inside first-launch onboarding, Haylee). Monthly only here (no switch).
    @State private var purchaseOutcome: PurchaseOutcome?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.layoutMetrics) private var metrics

    private var flow: OnboardingFlow { model.onboarding ?? OnboardingFlow() }
    private var pad: Bool { !metrics.isPhone }
    /// The page id (the mic-denied state is its own page for the fade).
    private var pageID: String { "\(flow.screen.rawValue)\(flow.showsMicDenied ? "-denied" : "")" }

    var body: some View {
        ZStack {
            OB.page.ignoresSafeArea()
            page.id(pageID).transition(.opacity)
        }
        .guSafari($webPage)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: pageID)
        .task(id: flow.screen) {
            // Her clip plays only while she's visible on this page (page 1), never on a replay.
            guard let line = flow.screen.clip, !flow.isReplay else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, model.onboarding?.screen == flow.screen else { return }
            model.onboardingVoice.play(line)
        }
        .onChange(of: flow.screen) { _, new in if new.clip == nil { model.onboardingVoice.stop() } }
        .onDisappear { model.onboardingVoice.stop() }
    }

    @ViewBuilder private var page: some View {
        switch flow.screen {
        case .hello: hello
        case .howItWorks: howItWorks
        case .needs: needs
        case .privacy: if flow.showsMicDenied { micDenied } else { privacy }
        case .plans: plans
        case .handOff: handOff
        }
    }

    // MARK: 1 · Welcome to PretendThat

    private var hello: some View {
        OBPage(dot: 0, back: nil) {
            OBStartArt(model: model, maxWidth: pad ? 330 : 300).frame(maxHeight: 340)
        } copy: {
            OBCopy(title: OnboardingCopy.helloTitle) { Text(OnboardingCopy.helloBody) }
        } actions: {
            OBPill(label: OnboardingCopy.helloButton) { go { $0.next() } }
        }
    }

    // MARK: 2 · How it works (the title on top: the list is the visual)

    private var howItWorks: some View {
        OBPage(dot: 1, back: backAction, titleOnTop: true) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(OnboardingCopy.steps.enumerated()), id: \.offset) { i, step in
                    OBStepRow(title: step.title, line: step.body) { stepIcon(i) }
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } copy: {
            OBCopy(title: OnboardingCopy.howTitle)
        } actions: {
            OBPill(label: OnboardingCopy.next) { go { $0.next() } }
        }
    }

    @ViewBuilder private func stepIcon(_ i: Int) -> some View {
        switch i {
        case 0: Image("toy-crown").resizable().scaledToFit().frame(width: 38, height: 34)
        case 1: Image("prop-cardboard-box").resizable().scaledToFit().frame(width: 38, height: 34)
        case 2: OBPrinterIcon().frame(width: 34, height: 34 * 54 / 60)
        default: OBPlayBadge().frame(width: 32, height: 32)
        }
    }

    // MARK: 3 · What you'll need (three tiles, no game length)

    private var needs: some View {
        OBPage(dot: 2, back: backAction, titleOnTop: true) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(OnboardingCopy.needs.enumerated()), id: \.offset) { i, need in
                    OBNeedTile(title: need.title, detail: need.detail) { needIcon(i) }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } copy: {
            OBCopy(title: OnboardingCopy.needTitle) { Text(OnboardingCopy.needLead) }
        } actions: {
            OBPill(label: OnboardingCopy.next) { go { $0.next() } }
        }
    }

    @ViewBuilder private func needIcon(_ i: Int) -> some View {
        switch i {
        case 0: OBPrinterIcon().frame(width: 48, height: 48 * 54 / 60)
        case 1: Image("prop-crayons").resizable().scaledToFit().frame(width: 56, height: 48)
        default: Image("prop-rug").resizable().scaledToFit().frame(width: 56, height: 48)
        }
    }

    // MARK: 4 · Private by design: REQUIRED AI consent + the microphone, one button

    private var privacy: some View {
        OBPage(dot: 3, back: backAction) {
            OBGlowCluster(glow: 200, natural: CGSize(width: 220, height: 220)) {
                OBShield().frame(width: 112, height: 112)
            }
        } copy: {
            OBCopy(title: OnboardingCopy.privacyTitle) {
                Text(privacyLine)
            }
            .environment(\.openURL, OpenURLAction { url in
                if url == OB.privacyLinkURL { webPage = GUWebPage(url: GrownUpsLinks.privacy); return .handled }
                return .systemAction
            })
            .accessibilityHint("Includes a link to the privacy policy")
        } actions: {
            OBPill(label: OnboardingCopy.agree, busy: micWorking) {
                guard !micWorking else { return }
                micWorking = true
                go { $0.agree() }
                Task { await model.onboardingMicContinue(); micWorking = false }
            }
            .accessibilityHint("Agrees to send your child's words, with names removed, to OpenAI and Anthropic. Then your \(DeviceWord.noun) asks to use the microphone.")
            OBNote(text: OnboardingCopy.micFine)
        }
    }

    /// The gray line with the inline "Privacy policy" link (opens in the in-app browser).
    private var privacyLine: AttributedString {
        var s = AttributedString(OnboardingCopy.privacyBody + " ")
        var link = AttributedString(OnboardingCopy.privacyBodyLink)
        link.link = OB.privacyLinkURL
        link.foregroundColor = OB.purple
        link.underlineStyle = .single
        link.font = OB.font(15, .medium)
        s.append(link)
        return s
    }

    // 4b · the mic wasn't allowed (same progress step): Next goes on, Open Settings
    private var micDenied: some View {
        OBPage(dot: 3, back: backAction) {
            OBGlowCluster(glow: 200, natural: CGSize(width: 220, height: 220)) {
                Image(systemName: "mic.fill").font(.system(size: 46, weight: .bold)).foregroundStyle(OB.white)
                    .frame(width: 104, height: 104).background(Circle().fill(OB.micGray))
            }
        } copy: {
            OBCopy(title: OnboardingCopy.micDeniedTitle) { Text(OnboardingCopy.micDeniedBody) }
        } actions: {
            OBPill(label: OnboardingCopy.next) { go { $0.next() } }
            OBQuiet(label: OnboardingCopy.micDeniedSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        }
    }

    // MARK: 5 · Start with 2 free games (plans; no Monthly/Yearly switch)

    private var plans: some View {
        let continueOnly = (flow.isReplay && model.freePreview.exhausted) || model.purchases.entitlement != nil   // round 38: a plan is active
        return OBPage(dot: 4, back: backAction, minVisual: 100) {
            OBGlowCluster(glow: pad ? 170 : 120, natural: CGSize(width: 220, height: pad ? 190 : 150)) {
                Image("stage-ticket").resizable().scaledToFit().frame(width: pad ? 150 : 118).rotationEffect(.degrees(-8))
                Image("stage-sparkle").resizable().scaledToFit().frame(width: 22)
                    .offset(x: pad ? 82 : 66, y: pad ? -62 : -48)
            }
        } copy: {
            OBCopy(title: OnboardingCopy.plansV3Title, lineWidth: 340) { Text(OnboardingCopy.plansV3Lead) }
        } extra: {
            VStack(spacing: 8) {
                ForEach([PlanTier.showPass, .seasonPass], id: \.self) { planRow($0) }
            }
            .padding(.top, 16)
            .task { if model.purchases.products.isEmpty { await model.purchases.loadProducts() } }
        } actions: {
            OBPill(label: continueOnly ? OnboardingCopy.continueButton : OnboardingCopy.freeGamesButton) { go { $0.startFreePreview() } }
                .accessibilityHint(continueOnly ? "" : "\(PlanCatalog.freePreviewShows) free new games, no card")
            plansFine
        }
    }

    private func planRow(_ tier: PlanTier) -> some View {
        // Round 38: StoreKit's localized price and intro offer (PlanCatalog's numbers until the App Store answers).
        let price = PlanPrice(tier, .monthly, purchases: model.purchases)
        let row = price.row
        let isCurrent = model.purchases.entitlement?.tier == tier
        let buying = model.purchases.buying == price.productID
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(tier.name).font(OB.font(15, .semibold)).foregroundStyle(OB.ink)
                Text(OnboardingCopy.planGames(tier)).font(OB.font(12, .regular)).foregroundStyle(OB.gray)
                (Text(row.amount).font(OB.font(12.5, .semibold)).foregroundStyle(OB.ink)
                 + Text(row.then.map { " " + $0 } ?? "").font(OB.font(11.5, .regular)).foregroundStyle(OB.gray))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button {
                Task {
                    purchaseOutcome = nil; restoreResult = nil
                    let o = await model.purchases.purchase(price.productID)
                    purchaseOutcome = o
                    model.planStatus = model.purchases.status
                    // Bought (or already theirs): on to the last page.
                    if o.succeeded { go { $0.startFreePreview() } }
                }
            } label: {
                Group {
                    if buying { ProgressView().tint(OB.purple).controlSize(.small) }
                    else { Text(isCurrent ? OnboardingCopy.currentPlan : OnboardingCopy.getPlan) }
                }
                .font(OB.font(13, .semibold)).foregroundStyle(isCurrent ? OB.gray : OB.purple)
                .padding(.vertical, 8).padding(.horizontal, 13)
                .background(Capsule().fill(OB.glow))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(OBPressStyle())
            .disabled(model.purchases.buying != nil || isCurrent || !price.loaded)
            .opacity(price.loaded ? 1 : 0.5)
            .accessibilityLabel(isCurrent ? "\(tier.name) is your plan" : "Get \(tier.name), \(price.full)")
        }
        .padding(.vertical, 10).padding(.leading, 14).padding(.trailing, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OB.white))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(OB.line, lineWidth: 1))
    }

    /// "Billed by Apple. Renews until cancelled." + Restore · Terms · Privacy (a purchase or restore answer shows in
    /// place of the first line for a moment).
    private var plansFine: some View {
        VStack(spacing: 1) {
            if let o = purchaseOutcome, !o.succeeded {
                Text(o.message).foregroundStyle(OB.ink)
            } else if let r = restoreResult {
                Text(r.message).foregroundStyle(OB.ink)
            } else if model.purchases.pendingProductID != nil {
                Text(PurchaseOutcome.pending.message).foregroundStyle(OB.ink)
            } else {
                Text(OnboardingCopy.billedByApple)
            }
            HStack(spacing: 0) {
                OBFineLink(label: restoring ? GrownUpsCopy.restoring : OnboardingCopy.restoreShort) {
                    guard !restoring else { return }
                    restoring = true; purchaseOutcome = nil
                    Task {
                        restoreResult = await PTStore.restore()
                        await model.purchases.refresh()
                        model.planStatus = model.purchases.status
                        restoring = false
                    }
                }
                .accessibilityLabel(OnboardingCopy.restore)
                Text("·").padding(.horizontal, 5)
                OBFineLink(label: OnboardingCopy.termsShort) { webPage = GUWebPage(url: GrownUpsLinks.terms) }
                    .accessibilityLabel(OnboardingCopy.terms)
                Text("·").padding(.horizontal, 5)
                OBFineLink(label: OnboardingCopy.privacyShort) { webPage = GUWebPage(url: GrownUpsLinks.privacy) }
                    .accessibilityLabel(OnboardingCopy.privacy)
            }
        }
        .font(OB.font(11.5, .regular)).foregroundStyle(OB.gray)
        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
        .padding(.top, 10)
    }

    // MARK: 6 · You're all set (the logo)

    private var handOff: some View {
        OBPage(dot: 5, back: backAction) {
            OBGlowCluster(glow: pad ? 280 : 250, natural: CGSize(width: pad ? 340 : 300, height: pad ? 290 : 260)) {
                Image("logo-nutmeg-top").resizable().scaledToFit().frame(width: pad ? 320 : 290)
                    .accessibilityLabel("PretendThat")
            }
        } copy: {
            OBCopy(title: OnboardingCopy.handOffTitle) { Text(OnboardingCopy.handOffBody) }
        } actions: {
            OBPill(label: OnboardingCopy.startFirstGame, symbol: "play.fill") { model.onboardingStartFirstGame() }
                .accessibilityHint("Opens a new game with Nutmeg")
            OBQuiet(label: OnboardingCopy.goHome) { go { $0.goHome() } }
                .accessibilityHint("Goes to the home page quietly")
        }
    }

    // MARK: Pieces

    private var backAction: () -> Void { { go { $0.back() } } }

    private func go(_ change: (inout OnboardingFlow) -> Void) { model.onboardingUpdate(change) }
}

// MARK: - Tokens (the mockup's :root, from BrandPalette + the site)

enum OB {
    static let page = Color(hex: 0xFAF8FC)      // white with a breath of lavender
    static let glow = Color(hex: 0xF1EAF8)      // the soft circle behind each visual (and the Get pills)
    static let purple = Theme.purple            // #5B2A86, the buttons
    static let ink = Theme.ink                  // #2A1846
    static let head = Theme.purpleShade         // #3F1A60, the back chevron
    static let gray = Color(hex: 0x6B6578)
    static let line = Theme.line                // #E8E2F0
    static let white = Theme.white
    static let micGray = Color(hex: 0xC9C0D6)
    static let sky = Theme.startSky
    /// The inline privacy link's target (handled in the page: it opens the policy in the in-app browser).
    static let privacyLinkURL = URL(string: "pretendthat-onboarding://privacy")!

    /// Poppins (the grown-up font) at a mockup size, relative to a text style so Dynamic Type scales it.
    static func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        GrownUpFont.font(GrownUpFont.weight(for: weight), size: size, relativeTo: GrownUpFont.style(for: size))
    }
}

// MARK: - The one page layout

/// Top bar, then the visual in the free space (or the title first when the list is the visual), the copy, an optional
/// extra block, and the actions above the home indicator. Never scrolls at the default text sizes.
struct OBPage<Visual: View, Copy: View, Extra: View, Actions: View>: View {
    let dot: Int
    let back: (() -> Void)?
    var titleOnTop = false
    var minVisual: CGFloat = 150
    @ViewBuilder var visual: () -> Visual
    @ViewBuilder var copy: () -> Copy
    @ViewBuilder var extra: () -> Extra
    @ViewBuilder var actions: () -> Actions
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        let pad = !metrics.isPhone
        ViewThatFits(in: .vertical) {
            column(minVisual: minVisual)
            // Very large text: the same page in a scroll view (never clipped).
            ScrollView { column(minVisual: minVisual).padding(.bottom, 8) }
        }
        .padding(.horizontal, pad ? 0 : 24)
        .frame(maxWidth: pad ? 460 : .infinity)
        .frame(maxWidth: .infinity)
    }

    private func column(minVisual: CGFloat) -> some View {
        VStack(spacing: 0) {
            OBTopBar(dot: dot, back: back)
            if titleOnTop { copy().padding(.top, 28) }
            visual()
                .frame(maxWidth: .infinity, minHeight: minVisual, maxHeight: .infinity)
            if !titleOnTop { copy().padding(.top, 6) }
            extra()
            VStack(spacing: 0) { actions() }
                .padding(.top, 16).padding(.bottom, 8)
        }
    }
}

extension OBPage where Extra == EmptyView {
    init(dot: Int, back: (() -> Void)?, titleOnTop: Bool = false, minVisual: CGFloat = 150,
         @ViewBuilder visual: @escaping () -> Visual, @ViewBuilder copy: @escaping () -> Copy,
         @ViewBuilder actions: @escaping () -> Actions) {
        self.init(dot: dot, back: back, titleOnTop: titleOnTop, minVisual: minVisual, visual: visual, copy: copy,
                  extra: { EmptyView() }, actions: actions)
    }
}

/// The small round back button, the thin 6-part progress bar, and a matching spacer (the bar stays centered).
struct OBTopBar: View {
    let dot: Int
    let back: (() -> Void)?
    var body: some View {
        HStack(spacing: 14) {
            Button { back?() } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).foregroundStyle(OB.head)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(OB.white))
                    .overlay(Circle().strokeBorder(OB.line, lineWidth: 1))
                    .shadow(color: Color(hex: 0x2A1846).opacity(0.06), radius: 3, y: 2)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(OBPressStyle())
            .frame(width: 36)
            .opacity(back == nil ? 0 : 1)
            .disabled(back == nil)
            .accessibilityHidden(back == nil)
            .accessibilityLabel("Back")
            .accessibilityHint("Goes to the previous page")
            HStack(spacing: 6) {
                ForEach(0..<OnboardingScreen.dotCount, id: \.self) { i in
                    Capsule().fill(i <= dot ? OB.purple : OB.line).frame(height: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(dot + 1) of \(OnboardingScreen.dotCount)")
            Color.clear.frame(width: 36, height: 1).accessibilityHidden(true)
        }
        .frame(height: 44)
        .padding(.top, 4)
    }
}

/// The centered title (Poppins SemiBold 26, 30 on the iPad) and one gray line (15).
struct OBCopy<Line: View>: View {
    let title: String
    /// The gray line's width (the mockup's 300; page 5's longer line uses the full column so it doesn't end on an
    /// orphan word).
    var lineWidth: CGFloat = 300
    @ViewBuilder var line: () -> Line
    @Environment(\.layoutMetrics) private var metrics
    var body: some View {
        let pad = !metrics.isPhone
        let size: CGFloat = pad ? 30 : 26
        VStack(spacing: 8) {
            Text(title).font(OB.font(size, .semibold)).kerning(-0.025 * size).foregroundStyle(OB.ink)
                .frame(maxWidth: pad ? 420 : 300)
                .accessibilityAddTraits(.isHeader)
            line().font(OB.font(15, .regular)).foregroundStyle(OB.gray).lineSpacing(1)
                .frame(maxWidth: lineWidth)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

extension OBCopy where Line == EmptyView {
    init(title: String) { self.init(title: title, line: { EmptyView() }) }
}

/// The one full-width purple pill (56 pt).
struct OBPill: View {
    let label: String
    var symbol: String? = nil
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy { ProgressView().tint(OB.white) }
                else if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .bold)).accessibilityHidden(true) }
                Text(label).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(OB.font(17, .semibold)).foregroundStyle(OB.white)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(Capsule().fill(OB.purple))
            .shadow(color: OB.purple.opacity(0.22), radius: 12, y: 10)
            .contentShape(Capsule())
        }
        .buttonStyle(OBPressStyle())
    }
}

/// The quiet text button under the pill ("Go to the home page", "Open Settings").
struct OBQuiet: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(OB.font(15, .medium)).foregroundStyle(OB.purple)
                .frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
        }
        .buttonStyle(OBPressStyle())
        .padding(.top, 2)
    }
}

/// The small gray line under a pill.
struct OBNote: View {
    let text: String
    var body: some View {
        Text(text).font(OB.font(12.5, .regular)).foregroundStyle(OB.gray)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 10)
    }
}

/// An underlined link in the fine print (Restore · Terms · Privacy).
struct OBFineLink: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).underline().padding(.vertical, 6).contentShape(Rectangle())
        }
        .buttonStyle(OBPressStyle())
    }
}

struct OBPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1).scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.press, value: configuration.isPressed)
    }
}

/// A visual on a soft lavender circle, scaled down as one piece when the free space is shorter than its natural size.
struct OBGlowCluster<Content: View>: View {
    let glow: CGFloat
    let natural: CGSize
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { geo in
            let k = min(1, geo.size.height / natural.height, geo.size.width / natural.width)
            ZStack {
                Circle().fill(OB.glow).frame(width: glow, height: glow)
                content()
            }
            .frame(width: natural.width, height: natural.height)
            .scaleEffect(k)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Page 1's art: the start screen's toy chest

/// The start screen (`PTToyChestScene`, phone layout) composed from the app's own pieces, with no curtains: the sky as a
/// soft circle, the wood floor oval, the open chest, Nutmeg (her real layered art, the start screen's idle pose) cut
/// off at the chest's front edge, a block and a spinning top at the chest's front corners, two sparkles. Her mouth
/// follows the page-1 clip.
struct OBStartArt: View {
    let model: AppModel
    let maxWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let W = min(maxWidth, geo.size.width, geo.size.height / 0.98)
            art(W)
                .frame(width: W, height: W * 0.98)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nutmeg the mouse in her toy chest")
    }

    private func art(_ W: CGFloat) -> some View {
        let H = W * 0.98
        let cw = W * 0.62, ch = cw * 620 / 650, cx = W / 2
        let floorY = H * 0.82
        let chestBottom = floorY + H * 0.02
        let chestTop = chestBottom - ch * 616 / 620
        let frontY = chestTop + ch * 378 / 620
        // The start screen's numbers: her body fills ~60% of the chest; her waist (canvas y ≈ 1030) on the front edge.
        let s = 0.6 * cw * 0.945 / 730
        let nW = 1178 * s, nH = 1335 * s
        let nX = cx + 19 * s, nTop = frontY - 1030 * s
        let toy = cw * 0.3, sky = W * 0.86
        let floorW = W * 0.92, floorH = W * 0.2
        return ZStack(alignment: .topLeading) {
            Circle().fill(OB.sky).frame(width: sky, height: sky).offset(x: (W - sky) / 2, y: H * 0.13)
            Ellipse().fill(Theme.stageFloorEdge).frame(width: floorW, height: floorH).offset(x: W * 0.04, y: floorY - floorH / 2 + 5)
            Ellipse().fill(Theme.stageFloor).frame(width: floorW, height: floorH).offset(x: W * 0.04, y: floorY - floorH / 2)
            Image("chest-lid-open").resizable().frame(width: cw, height: ch).offset(x: cx - cw / 2, y: chestTop)
            Image("chest-body").resizable().frame(width: cw, height: ch).offset(x: cx - cw / 2, y: chestTop)
            NutmegCharacter(state: .idle, mouthLevel: model.onboardingVoice.level,
                            isSpeaking: model.onboardingVoice.speaking, showsTail: false)
                .frame(width: nW, height: nH)
                .offset(x: nX - nW / 2, y: nTop)
                .mask(alignment: .topLeading) {
                    Rectangle().frame(width: W, height: frontY + 400).offset(y: -400)
                }
            Image("toy-block").resizable().scaledToFit().frame(width: toy, height: toy).rotationEffect(.degrees(-8))
                .offset(x: cx - cw * 0.5 - toy / 2, y: chestBottom + cw * 0.1 - toy)
            Image("toy-top").resizable().scaledToFit().frame(width: toy, height: toy).rotationEffect(.degrees(6))
                .offset(x: cx + cw * 0.5 - toy / 2, y: chestBottom + cw * 0.1 - toy)
            Image("stage-sparkle").resizable().scaledToFit().frame(width: W * 0.06).offset(x: W * 0.12, y: H * 0.30)
            Image("stage-sparkle").resizable().scaledToFit().frame(width: W * 0.07).offset(x: W * 0.82, y: H * 0.22)
        }
        .frame(width: W, height: H, alignment: .topLeading)
    }
}

// MARK: - Rows, tiles and drawn icons

/// Page 2's row: an icon on a soft tile, one word, one line.
struct OBStepRow<Icon: View>: View {
    let title: String
    let line: String
    @ViewBuilder var icon: () -> Icon
    var body: some View {
        HStack(spacing: 16) {
            icon()
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(OB.glow))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(OB.font(17, .semibold)).kerning(-0.17).foregroundStyle(OB.ink)
                Text(line).font(OB.font(14, .regular)).foregroundStyle(OB.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Page 3's tile: an icon, a title and a detail on a white card.
struct OBNeedTile<Icon: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var icon: () -> Icon
    var body: some View {
        VStack(spacing: 0) {
            icon().frame(height: 52).padding(.bottom, 8).accessibilityHidden(true)
            Text(title).font(OB.font(14.5, .semibold)).foregroundStyle(OB.ink)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(OB.font(12.5, .regular)).foregroundStyle(OB.gray)
                .multilineTextAlignment(.center).padding(.top, 2)
        }
        .padding(.top, 16).padding(.horizontal, 8).padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(OB.white))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(OB.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// The purple printer icon (the mockup's 60 × 54 drawing).
struct OBPrinterIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width / 60, size.height / 54)
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * k, y: y * k, width: w * k, height: h * k) }
            let paper = Color(hex: 0xFCEBD5)
            ctx.fill(Path(roundedRect: r(14, 2, 32, 16), cornerRadius: 3 * k), with: .color(paper))
            ctx.fill(Path(roundedRect: r(2, 14, 56, 26), cornerRadius: 8 * k), with: .color(Theme.purple))
            ctx.fill(Path(ellipseIn: r(45, 21, 6, 6)), with: .color(Theme.lime))
            ctx.fill(Path(roundedRect: r(12, 34, 36, 18), cornerRadius: 2 * k), with: .color(paper))
            var squiggle = Path()
            squiggle.move(to: CGPoint(x: 20 * k, y: 41 * k))
            squiggle.addLine(to: CGPoint(x: 24 * k, y: 45 * k))
            squiggle.addLine(to: CGPoint(x: 27 * k, y: 42 * k))
            squiggle.addLine(to: CGPoint(x: 31 * k, y: 46 * k))
            ctx.stroke(squiggle, with: .color(Color(hex: 0xC77841)), style: StrokeStyle(lineWidth: 2 * k, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// The purple play badge (page 2's Play row).
struct OBPlayBadge: View {
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 48
            ctx.fill(Path(ellipseIn: CGRect(x: 2 * k, y: 2 * k, width: 44 * k, height: 44 * k)), with: .color(Theme.purple))
            var tri = Path()
            tri.move(to: CGPoint(x: 19 * k, y: 14.5 * k)); tri.addLine(to: CGPoint(x: 19 * k, y: 33.5 * k))
            tri.addLine(to: CGPoint(x: 34 * k, y: 24 * k)); tri.closeSubpath()
            ctx.fill(tri, with: .color(Theme.white))
        }
        .accessibilityHidden(true)
    }
}

/// The green shield with a white check (page 4; the mockup's 64 × 64 drawing).
struct OBShield: View {
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 64
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            var outer = Path()
            outer.move(to: p(32, 5)); outer.addLine(to: p(54, 13)); outer.addLine(to: p(54, 29))
            outer.addCurve(to: p(32, 59), control1: p(54, 44), control2: p(44.5, 54.5))
            outer.addCurve(to: p(10, 29), control1: p(19.5, 54.5), control2: p(10, 44))
            outer.addLine(to: p(10, 13)); outer.closeSubpath()
            ctx.fill(outer, with: .color(Theme.lime))
            var half = Path()
            half.move(to: p(32, 5)); half.addLine(to: p(54, 13)); half.addLine(to: p(54, 29))
            half.addCurve(to: p(32, 59), control1: p(54, 44), control2: p(44.5, 54.5)); half.closeSubpath()
            ctx.fill(half, with: .color(Theme.limeShade.opacity(0.35)))
            var check = Path()
            check.move(to: p(21, 32)); check.addLine(to: p(29, 40)); check.addLine(to: p(44, 24))
            ctx.stroke(check, with: .color(Theme.white), style: StrokeStyle(lineWidth: 5.5 * k, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
