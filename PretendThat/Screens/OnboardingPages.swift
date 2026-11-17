import SwiftUI
import NutmegCore

/// Onboarding v2 (Haylee, 2026-11-16; design/mockups/onboarding-v2 pages 1–7). Full-screen pages, no grown-up gate:
/// a stage "art card" on the left (sky, valance, curtains, floor and Nutmeg's real layered art) and a calm text column
/// on the right (back arrow, progress dots, a big title, one short line, one big coral button). Page 2 is the one
/// full-width page (four step cards). Every size is the mockup's (1194 × 834 pt, the 11" iPad) times one scale, so the
/// 13" iPad gets the same page a little bigger; the art card stretches to the screen's height.
///
/// Nutmeg's voice: only page 1 has a clip (her bundled recording, through her one speaker), played only while she's on
/// screen there, never on a replay, never TTS. Her mouth follows the clip.
struct OnboardingView: View {
    let model: AppModel
    @State private var webPage: GUWebPage?
    @State private var micWorking = false
    @State private var restoring = false
    @State private var restoreResult: RestoreOutcome?
    /// Round 38: page 6's purchases (no gate inside first-launch onboarding, Haylee) and the billing period.
    @State private var purchaseOutcome: PurchaseOutcome?
    @State private var planPeriod: BillingPeriod = PlanCatalog.defaultPeriod
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    private var flow: OnboardingFlow { model.onboarding ?? OnboardingFlow() }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 1194, geo.size.height / 834)
            ZStack {
                (flow.screen == .howItWorks ? OB.warm : OB.paper).ignoresSafeArea()
                page(s: s, size: geo.size)
                    .id(flow.screen)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .guSafari($webPage)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: flow.screen)
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

    @ViewBuilder private func page(s: CGFloat, size: CGSize) -> some View {
        switch flow.screen {
        case .hello: hello(s)
        case .howItWorks: howItWorks(s)
        case .needs: needs(s)
        case .privacy: privacy(s)
        case .aiDeclined: declined(s)
        case .microphone: microphone(s)
        case .plans: plans(s)
        case .handOff: handOff(s)
        }
    }

    // MARK: 1 · Hi, grown-up!

    private func hello(_ s: CGFloat) -> some View {
        OBSplit(s: s, art: {
            OBArt(s: s, sky: OB.sky, valance: true, curtains: true, floor: true) {
                nutmeg(s, pose: .wave, state: .idle, height: 540, bottom: 96, x: 10, speaks: true)
                OBDeco(s: s, "stage-sparkle", width: 44, top: 120, left: 96)
                OBDeco(s: s, "stage-star", width: 44, top: 420, right: 28)
            }
        }, column: {
            OBColumn(s: s, back: nil, dot: flow.screen.dot) {
                OBEyebrow(s: s, text: OnboardingCopy.helloEyebrow)
                OBTitle(s: s, text: OnboardingCopy.helloTitle)
                OBLead(s: s, text: OnboardingCopy.helloBody)
            } actions: {
                OBButton(s: s, label: OnboardingCopy.helloButton) { go { $0.next() } }
            }
        })
    }

    // MARK: 2 · How it works (the one full-width page)

    private func howItWorks(_ s: CGFloat) -> some View {
        VStack(spacing: 0) {
            OBTopBar(s: s, back: backAction, dot: flow.screen.dot)
            VStack(spacing: 12 * s) {
                OBTitle(s: s, text: OnboardingCopy.howTitle, size: 52).multilineTextAlignment(.center)
                Text(OnboardingCopy.tagline).font(OB.font(25 * s, .bold)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, -28 * s)
            HStack(alignment: .top, spacing: 22 * s) {
                ForEach(Array(OnboardingCopy.steps.enumerated()), id: \.offset) { i, step in
                    stepCard(s, number: i + 1, title: step.title, body: step.body)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.top, 40 * s)
            OBButton(s: s, label: OnboardingCopy.next) { go { $0.next() } }
                .frame(width: 420 * s)
                .padding(.top, 28 * s)
        }
        .padding(.horizontal, 48 * s)
        .padding(.top, 40 * s)
        .padding(.bottom, 40 * s)
    }

    private func stepCard(_ s: CGFloat, number: Int, title: String, body: String) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24 * s, style: .continuous).fill(OB.stepTint[number - 1])
                stepPicture(s, number)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("\(number)").font(OB.font(20 * s, .black)).foregroundStyle(Theme.purple)
                    .frame(width: 40 * s, height: 40 * s).background(Circle().fill(Theme.white))
                    .padding(12 * s)
            }
            .frame(height: 230 * s)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
            .accessibilityHidden(true)
            Text(title).font(OB.font(34 * s, .black)).foregroundStyle(Theme.ink).padding(.top, 18 * s)
            Text(body).font(OB.font(21 * s, .bold)).foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center).lineSpacing(4 * s)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6 * s)
            Spacer(minLength: 0)
        }
        .padding(.top, 20 * s).padding(.horizontal, 18 * s).padding(.bottom, 24 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OBCardBackground(s: s, radius: 32, depth: 5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(number), \(title). \(body)")
    }

    @ViewBuilder private func stepPicture(_ s: CGFloat, _ n: Int) -> some View {
        switch n {
        case 1:
            ZStack(alignment: .topLeading) {
                OBDeco(s: s, "toy-crown", width: 96, top: 54, left: 34, rotation: -10)
                OBDeco(s: s, "prop-hat", width: 104, top: 70, right: 26, rotation: 8)
            }
        case 2:
            ZStack {
                OBDeco(s: s, "prop-cardboard-box", width: 120, left: 26, bottom: 26)
                OBDeco(s: s, "prop-pot", width: 92, right: 28, bottom: 30)
            }
        case 3:
            OBPrinter(s: s).frame(width: 170 * s, height: 150 * s)
        default:
            ZStack {
                NutmegCharacter(state: .excited, forcedPose: .celebrate)
                    .frame(height: 178 * s * OB.rigScale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: (12 + OB.rigFoot * 178) * s)
                OBDeco(s: s, "stage-sparkle", width: 28, top: 28, right: 34)
            }
        }
    }

    // MARK: 3 · What you'll need

    private func needs(_ s: CGFloat) -> some View {
        OBSplit(s: s, art: {
            OBArt(s: s, sky: OB.creamArt, valance: false, curtains: false, floor: false) {
                OBDeco(s: s, "prop-rug", width: 420, left: 70, bottom: 40)
                nutmeg(s, pose: .point, state: .talking, height: 500, bottom: 110, x: -40)
                OBDeco(s: s, "prop-crayons", width: 120, right: 44, bottom: 80, rotation: -8)
            }
        }, column: {
            OBColumn(s: s, back: backAction, dot: flow.screen.dot) {
                OBTitle(s: s, text: OnboardingCopy.needTitle)
                OBLead(s: s, text: OnboardingCopy.needLead)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16 * s), GridItem(.flexible(), spacing: 16 * s)], spacing: 16 * s) {
                    ForEach(Array(OnboardingCopy.needs.enumerated()), id: \.offset) { i, need in
                        needTile(s, i, need.title, need.detail)
                    }
                }
                .padding(.top, 30 * s)
            } actions: {
                OBButton(s: s, label: OnboardingCopy.next) { go { $0.next() } }
            }
        })
    }

    private func needTile(_ s: CGFloat, _ i: Int, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 16 * s) {
            ZStack {
                RoundedRectangle(cornerRadius: 20 * s, style: .continuous).fill(OB.needTint[i])
                switch i {
                case 0: OBPrinter(s: s * 0.36, compact: true).frame(width: 58 * s, height: 52 * s)
                case 1: Image("prop-crayons").resizable().scaledToFit().frame(maxWidth: 48 * s, maxHeight: 44 * s)
                case 2: Image("prop-rug").resizable().scaledToFit().frame(maxWidth: 48 * s, maxHeight: 44 * s)
                default: OBClock(s: s)
                }
            }
            .frame(width: 60 * s, height: 60 * s)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2 * s) {
                Text(title).font(OB.font(21 * s, .black)).foregroundStyle(Theme.ink)
                Text(detail).font(OB.font(17 * s, .bold)).foregroundStyle(Theme.inkMuted)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16 * s).padding(.horizontal, 14 * s)
        .background(OBCardBackground(s: s, radius: 26, depth: 4))
        .accessibilityElement(children: .combine)
    }

    // MARK: 4 · Private by design + REQUIRED AI consent

    private var privacyArt: (CGFloat) -> AnyView {
        { s in
            AnyView(OBArt(s: s, sky: OB.sky, valance: true, curtains: false, floor: true) {
                nutmeg(s, pose: .idle, state: .idle, height: 480, bottom: 96, x: -70)
                OBShield(s: s).frame(width: 140 * s, height: 162 * s)
                    .padding(.top, 96 * s).padding(.trailing, 44 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            })
        }
    }

    private func privacy(_ s: CGFloat) -> some View {
        OBSplit(s: s, art: { privacyArt(s) }, column: {
            OBColumn(s: s, back: backAction, dot: flow.screen.dot, leading: 56) {
                OBTitle(s: s, text: OnboardingCopy.privacyTitle, size: 48)
                VStack(alignment: .leading, spacing: 14 * s) {
                    ForEach(OnboardingCopy.privacyLines, id: \.text) { line in
                        HStack(alignment: .top, spacing: 14 * s) {
                            Image(systemName: "checkmark").font(.system(size: 15 * s, weight: .black))
                                .foregroundStyle(Theme.limeShade)
                                .frame(width: 34 * s, height: 34 * s).background(Circle().fill(Theme.limeTint))
                                .padding(.top, -2 * s)
                                .accessibilityHidden(true)
                            Text(line.text).font(OB.font(20 * s, .bold)).foregroundStyle(Theme.ink)
                                .lineSpacing(3 * s).fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 24 * s)
                Button { webPage = GUWebPage(url: GrownUpsLinks.privacy) } label: {
                    Text(OnboardingCopy.privacyLink).font(OB.font(19 * s, .heavy)).foregroundStyle(Theme.purple)
                        .underline().frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, 6 * s)
                .accessibilityHint("Opens the privacy policy in a browser view")
                // Anonymous usage counts: one short line, OFF until the grown-up turns it on (2026-11-17-analytics-build.md).
                Toggle(isOn: Binding(get: { model.analyticsSharing }, set: { model.setAnalyticsSharing($0) })) {
                    Text(OnboardingCopy.analyticsLine).font(OB.font(17 * s, .bold)).foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(Theme.purple)
                .padding(.top, 4 * s)
                .accessibilityIdentifier("analyticsToggle")
                .accessibilityHint("Off unless you turn it on. Sends simple counts, never anything about your child.")
            } actions: {
                OBButton(s: s, label: OnboardingCopy.agree) { go { $0.agree() } }
                    .accessibilityHint("Agrees to send your child's words, with names removed, to OpenAI and Anthropic")
                OBTextButton(s: s, label: OnboardingCopy.notNow) { go { $0.notNow() } }
            }
        })
    }

    // 4b · Not now (on the privacy dot)
    private func declined(_ s: CGFloat) -> some View {
        OBSplit(s: s, art: { privacyArt(s) }, column: {
            OBColumn(s: s, back: backAction, dot: flow.screen.dot, leading: 56) {
                OBTitle(s: s, text: OnboardingCopy.declinedTitle, size: 48)
                OBLead(s: s, text: OnboardingCopy.declinedBody, size: 22)
                Text(OnboardingCopy.declinedHow).font(OB.font(19 * s, .heavy)).foregroundStyle(Theme.purple)
                    .padding(.top, 16 * s)
            } actions: {
                OBButton(s: s, label: OnboardingCopy.agree) { go { $0.agree() } }
                OBTextButton(s: s, label: OnboardingCopy.declinedClose) { go { $0.closeWithoutConsent() } }
            }
        })
    }

    // MARK: 5 · Hold to talk (mic pre-permission: one Continue, no "Allow", no close)

    private func microphone(_ s: CGFloat) -> some View {
        OBSplit(s: s, art: {
            OBArt(s: s, sky: OB.sky, valance: true, curtains: true, floor: true) {
                nutmeg(s, pose: .idle, state: .amazed, height: 500, bottom: 96, x: -60)
                OBMicBadge(s: s).frame(width: 150 * s, height: 150 * s)
                    .padding(.trailing, 62 * s).padding(.bottom, 120 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }, column: {
            OBColumn(s: s, back: backAction, dot: flow.screen.dot) {
                OBTitle(s: s, text: OnboardingCopy.micTitle)
                OBLead(s: s, text: OnboardingCopy.micBody)
                if flow.micDenied {
                    VStack(alignment: .leading, spacing: 6 * s) {
                        Text(OnboardingCopy.micDeniedTitle).font(OB.font(21 * s, .black)).foregroundStyle(Theme.ink)
                        Text(OnboardingCopy.micDeniedBody).font(OB.font(17 * s, .bold)).foregroundStyle(Theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(OnboardingCopy.micDeniedSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .font(OB.font(19 * s, .heavy)).foregroundStyle(Theme.purple).frame(minHeight: 44)
                    }
                    .padding(16 * s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OBCardBackground(s: s, radius: 26, depth: 4))
                    .padding(.top, 24 * s)
                    .accessibilityElement(children: .contain)
                }
            } actions: {
                if flow.micAsked {
                    OBButton(s: s, label: OnboardingCopy.next) { go { $0.next() } }
                } else {
                    OBButton(s: s, label: OnboardingCopy.micContinue) {
                        guard !micWorking else { return }
                        micWorking = true
                        Task { await model.onboardingMicContinue(); micWorking = false }
                    }
                    .accessibilityHint("Next, your iPad asks to use the microphone and speech recognition")
                    Text(OnboardingCopy.micFine).font(OB.font(16 * s, .bold)).foregroundStyle(Theme.inkMuted)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 6 * s)
                }
            }
        })
    }

    // MARK: 6 · Plans (Free Preview first; prices from PlanCatalog, the one config place)

    private func plans(_ s: CGFloat) -> some View {
        let continueOnly = (flow.isReplay && model.freePreview.exhausted) || model.purchases.entitlement != nil   // round 38: a plan is active
        return OBSplit(s: s, artWidth: 470, art: {
            OBArt(s: s, sky: OB.sky, valance: true, curtains: false, floor: false, glow: false, width: 470) {
                // The mockup's perky sit (clipboard on her lap), a still picture of her real art on the same sky: the
                // game rig only sits for the nap (clipboard down). She doesn't speak here.
                Image("onboarding-nutmeg-sit-perky").resizable().scaledToFit().frame(width: 340 * s)
                    .padding(.bottom, 176 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .accessibilityHidden(true)
                OBDeco(s: s, "stage-ticket", width: 120, top: 110, left: 40, rotation: -14)
                OBDeco(s: s, "stage-sparkle", width: 40, top: 120, right: 60)
                OBDeco(s: s, "stage-star", width: 48, top: 200, right: 90)
                VStack(spacing: 8 * s) {
                    Text(OnboardingCopy.freeHeroTitle).font(OB.font(30 * s, .black)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center).lineSpacing(0)
                    Text(OnboardingCopy.freeHeroBody).font(OB.font(18 * s, .bold)).foregroundStyle(Theme.inkMuted)
                }
                .padding(.top, 22 * s).padding(.horizontal, 16 * s).padding(.bottom, 20 * s)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 28 * s, style: .continuous).fill(Theme.white))
                .padding(24 * s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .accessibilityElement(children: .combine)
            }
        }, column: {
            OBColumn(s: s, back: backAction, dot: flow.screen.dot, leading: 48, trailing: 36, bottom: 18) {
                OBTitle(s: s, text: OnboardingCopy.plansV2Title, size: 48)
                OBLead(s: s, text: OnboardingCopy.plansV2Lead, size: 21, top: 10, maxWidth: 600)
                Picker("Billing", selection: $planPeriod) {
                    ForEach(BillingPeriod.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260 * s)
                .padding(.top, 16 * s)
                .accessibilityLabel("Billing period")
                HStack(alignment: .top, spacing: 14 * s) {
                    ForEach(PlanCatalog.offers) { planCard(s, $0) }
                }
                .padding(.top, 18 * s)
                .task { if model.purchases.products.isEmpty { await model.purchases.loadProducts() } }
            } actions: {
                OBButton(s: s, label: continueOnly ? OnboardingCopy.continueButton : OnboardingCopy.freePreviewButton,
                         symbol: continueOnly ? nil : "ticket") { go { $0.startFreePreview() } }
                    .accessibilityHint("\(PlanCatalog.freePreviewShows) free new shows, no card")
                HStack(spacing: 28 * s) {
                    Button {
                        restoring = true
                        Task {
                            restoreResult = await PTStore.restore()
                            await model.purchases.refresh()
                            model.planStatus = model.purchases.status
                            restoring = false
                        }
                    } label: { Text(restoring ? GrownUpsCopy.restoring : OnboardingCopy.restore) }
                        .disabled(restoring)
                    Button(OnboardingCopy.terms) { webPage = GUWebPage(url: GrownUpsLinks.terms) }
                    Button(OnboardingCopy.privacy) { webPage = GUWebPage(url: GrownUpsLinks.privacy) }
                }
                .buttonStyle(.plain)
                .font(OB.font(15 * s, .heavy)).foregroundStyle(Theme.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                if let o = purchaseOutcome, !o.succeeded {
                    Text(o.message).font(OB.font(15 * s, .bold)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let r = restoreResult {
                    Text(r.message).font(OB.font(15 * s, .bold)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
            }
        })
    }

    private func planCard(_ s: CGFloat, _ offer: PlanOffer) -> some View {
        let season = offer.id == PlanCatalog.seasonPass.id
        let tier: PlanTier = season ? .seasonPass : .showPass
        // Round 38: StoreKit's localized price and intro offer (PlanCatalog's numbers until the App Store answers).
        let price = PlanPrice(tier, planPeriod, purchases: model.purchases)
        let isCurrent = model.purchases.entitlement?.productID == price.productID
        let busy = model.purchases.buying != nil
        return VStack(alignment: .leading, spacing: 0) {
            Text(offer.name).font(OB.font(22 * s, .black)).foregroundStyle(Theme.ink)
            (Text(price.billedAmount).font(OB.font(30 * s, .black))
             + Text("/\(PriceText.unit(planPeriod))").font(OB.font(17 * s, .heavy)))
                .foregroundStyle(Theme.ink).padding(.top, 8 * s)
            if let then = price.introThen {
                Text(then).font(OB.font(15 * s, .bold)).foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 2 * s)
            }
            VStack(alignment: .leading, spacing: 5 * s) {
                bullet(s, OnboardingCopy.cardShows(offer))
                bullet(s, OnboardingCopy.replaysBullet)
            }
            .padding(.top, 10 * s)
            Button {
                Task {
                    purchaseOutcome = nil
                    let o = await model.purchases.purchase(price.productID)
                    purchaseOutcome = o
                    model.planStatus = model.purchases.status
                    // Bought (or already theirs): on to the hand-off page.
                    if o.succeeded { go { $0.startFreePreview() } }
                }
            } label: {
                Text(isCurrent ? "Your plan" : (model.purchases.buying == price.productID ? "One moment…" : "Get \(offer.name)"))
                    .font(OB.font(17 * s, .black)).foregroundStyle(isCurrent ? Theme.inkMuted : Theme.purple)
                    .frame(maxWidth: .infinity).frame(height: max(48 * s, 44))
                    .background(Capsule().strokeBorder(isCurrent ? Theme.line : Theme.purple, lineWidth: 2.5 * s))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(busy || isCurrent || !price.loaded)
            .opacity(price.loaded ? 1 : 0.5)
            .padding(.top, 12 * s)
            .accessibilityLabel(isCurrent ? "\(offer.name) is your plan" : "Get \(offer.name), \(price.full)")
        }
        .padding(.top, 18 * s).padding(.horizontal, 18 * s).padding(.bottom, 16 * s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OBCardBackground(s: s, radius: 26, depth: 4))
        .overlay(alignment: .topTrailing) {
            if season {
                Text(OnboardingCopy.seasonTag.uppercased()).font(OB.font(13 * s, .black)).kerning(0.5 * s)
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 4 * s).padding(.horizontal, 10 * s)
                    .background(Capsule().fill(Theme.yellow))
                    .offset(x: -16 * s, y: -14 * s)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(offer.name), \(price.full). \(OnboardingCopy.cardShows(offer)). \(OnboardingCopy.replaysBullet).")
    }

    private func bullet(_ s: CGFloat, _ text: String) -> some View {
        HStack(spacing: 8 * s) {
            Circle().fill(Theme.lime).frame(width: 8 * s, height: 8 * s)
            Text(text).font(OB.font(16 * s, .heavy)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
    }

    // MARK: 7 · Hand the iPad to your child

    private func handOff(_ s: CGFloat) -> some View {
        OBSplit(s: s, art: {
            OBArt(s: s, sky: OB.sky, valance: true, curtains: true, floor: true, warmGlow: true) {
                nutmeg(s, pose: .celebrate, state: .excited, height: 550, bottom: 92, x: 0)
                OBDeco(s: s, "stage-star", width: 56, top: 110, left: 92, rotation: -12)
                OBDeco(s: s, "stage-sparkle", width: 42, top: 96, right: 110)
                OBDeco(s: s, "stage-sparkle", width: 30, top: 360, left: 40)
                OBDeco(s: s, "stage-star", width: 40, top: 340, right: 36, rotation: 14)
            }
        }, column: {
            OBColumn(s: s, back: backAction, dot: flow.screen.dot) {
                OBEyebrow(s: s, text: OnboardingCopy.handOffEyebrow, fill: Theme.limeTint, ink: OB.limeInk)
                OBTitle(s: s, text: OnboardingCopy.handOffTitle)
                OBLead(s: s, text: OnboardingCopy.handOffBody)
            } actions: {
                OBButton(s: s, label: OnboardingCopy.startFirstGame, symbol: "play.fill") { model.onboardingStartFirstGame() }
                    .accessibilityHint("Opens a new game with Nutmeg")
                OBQuietButton(s: s, label: OnboardingCopy.goHome) { go { $0.goHome() } }
                    .accessibilityHint("Goes to the home page quietly")
            }
        })
    }

    // MARK: Pieces

    private var backAction: () -> Void { { go { $0.back() } } }

    private func go(_ change: (inout OnboardingFlow) -> Void) { model.onboardingUpdate(change) }

    /// Nutmeg's real layered art (the game's rig), placed like the mockup's picture of her: `height` is the mockup's
    /// image height, `bottom` its distance from the card's bottom, `x` its nudge from the center.
    private func nutmeg(_ s: CGFloat, pose: NutmegPose, state: NutmegState, height: CGFloat, bottom: CGFloat, x: CGFloat,
                        speaks: Bool = false) -> some View {
        NutmegCharacter(state: state,
                        mouthLevel: speaks ? model.onboardingVoice.level : 0,
                        isSpeaking: speaks && model.onboardingVoice.speaking,
                        forcedPose: pose)
            .frame(height: height * s * OB.rigScale)
            .offset(x: x * s, y: OB.rigFoot * height * s)
            .padding(.bottom, bottom * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .accessibilityHidden(true)
    }
}

// MARK: - Tokens

/// The mockup's tokens (design/mockups/onboarding-v2/index.html :root) and the rounded face.
enum OB {
    static let paper = Color(hex: 0xFFFBF5)
    static let warm = Color(hex: 0xFFF7EC)
    static let sky = Color(hex: 0xCDEBF5)
    static let creamArt = Color(hex: 0xFFF1DE)
    static let limeInk = Color(hex: 0x3F6B16)
    static let dotDone = Color(hex: 0xB9A6D3)
    static let dotTodo = Color(hex: 0xDAD2E6)
    static let stepTint: [Color] = [sky, Color(hex: 0xFFE6C2), Theme.lavender, Theme.limeTint]
    static let needTint: [Color] = [Theme.lavender, Color(hex: 0xFFE6C2), sky, Theme.limeTint]
    /// The rig's 1178 × 1335 canvas vs the mockup's tight crop of her (tuned against the mockup in the simulator):
    /// the rig is drawn this much taller, and moved down by this share of the mockup height (blank canvas under her feet).
    static let rigScale: CGFloat = 1.0
    static let rigFoot: CGFloat = 0

    static func font(_ size: CGFloat, _ weight: Font.Weight) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

// MARK: - Layout

/// The split frame: the art card on the left, the text column on the right, 24 pt from every edge.
struct OBSplit<Art: View, Column: View>: View {
    let s: CGFloat
    var artWidth: CGFloat = 560
    @ViewBuilder var art: () -> Art
    @ViewBuilder var column: () -> Column
    var body: some View {
        HStack(spacing: 0) {
            art().frame(width: artWidth * s).frame(maxHeight: .infinity)
            column().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24 * s)
    }
}

/// The right column: top bar, the body centered in the free space, the actions at the bottom.
struct OBColumn<Content: View, Actions: View>: View {
    let s: CGFloat
    let back: (() -> Void)?
    let dot: Int
    var leading: CGFloat = 64
    var trailing: CGFloat = 40
    var bottom: CGFloat = 20
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OBTopBar(s: s, back: back, dot: dot)
            Spacer(minLength: 12 * s)
            VStack(alignment: .leading, spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 12 * s)
            VStack(spacing: 8 * s) { actions() }
        }
        .padding(.top, 28 * s).padding(.leading, leading * s).padding(.trailing, trailing * s).padding(.bottom, bottom * s)
    }
}

struct OBTopBar: View {
    let s: CGFloat
    let back: (() -> Void)?
    let dot: Int
    var body: some View {
        HStack {
            if let back {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.system(size: 24 * s, weight: .bold)).foregroundStyle(Theme.purple)
                        .frame(width: 64 * s, height: 64 * s)
                        .background(Circle().fill(Theme.white))
                        .overlay(Circle().strokeBorder(Theme.line, lineWidth: 3 * s))
                        .frame(minWidth: 64, minHeight: 64)
                        .contentShape(Circle())
                }
                .buttonStyle(OBPressStyle())
                .accessibilityLabel("Back")
                .accessibilityHint("Goes to the previous page")
            } else {
                Color.clear.frame(width: 64 * s, height: 64 * s).accessibilityHidden(true)
            }
            Spacer()
            HStack(spacing: 10 * s) {
                ForEach(0..<OnboardingScreen.dotCount, id: \.self) { i in
                    Capsule().fill(i == dot ? Theme.purple : (i < dot ? OB.dotDone : OB.dotTodo))
                        .frame(width: (i == dot ? 36 : 12) * s, height: 12 * s)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(dot + 1) of \(OnboardingScreen.dotCount)")
        }
        .frame(height: 64 * s)
    }
}

/// The stage art card: sky, an optional valance and curtains, a soft glow, an optional floor disc, then the content.
struct OBArt<Content: View>: View {
    let s: CGFloat
    let sky: Color
    let valance: Bool
    let curtains: Bool
    let floor: Bool
    var glow = true
    var warmGlow = false
    var width: CGFloat = 560
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            sky
            // The glow: centered, 420 pt, 110 pt from the top.
            if glow {
            RadialGradient(colors: [(warmGlow ? Color(hex: 0xFFECAA).opacity(0.95) : Color.white.opacity(0.75)), .clear],
                           center: .center, startRadius: 0, endRadius: 202 * s)
                .frame(width: 420 * s, height: 420 * s)
                .padding(.top, 110 * s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            if curtains {
                Image("stage-curtain-left").resizable().frame(width: 150 * s, height: 282 * s)
                    .padding(.top, 30 * s).offset(x: -46 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Image("stage-curtain-right").resizable().frame(width: 150 * s, height: 282 * s)
                    .padding(.top, 30 * s).offset(x: 46 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            if floor {
                ZStack {
                    Ellipse().fill(Theme.stageFloorEdge).offset(y: 12 * s)
                    Ellipse().fill(Theme.stageFloor)
                }
                .frame(width: 440 * s, height: 104 * s)
                .padding(.bottom, 58 * s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            content()
            if valance {
                Image("stage-valance").resizable().frame(width: width * s, height: width * s * 104 / 550)
                    .offset(y: -14 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 40 * s, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A picture from the asset catalog, pinned like the mockup's absolutely positioned images.
struct OBDeco: View {
    let s: CGFloat
    let name: String
    let width: CGFloat
    var top: CGFloat? = nil, left: CGFloat? = nil, right: CGFloat? = nil, bottom: CGFloat? = nil
    var rotation: Double = 0
    init(s: CGFloat, _ name: String, width: CGFloat, top: CGFloat? = nil, left: CGFloat? = nil, right: CGFloat? = nil,
         bottom: CGFloat? = nil, rotation: Double = 0) {
        self.s = s; self.name = name; self.width = width
        self.top = top; self.left = left; self.right = right; self.bottom = bottom; self.rotation = rotation
    }
    var body: some View {
        Image(name).resizable().scaledToFit().frame(width: width * s)
            .rotationEffect(.degrees(rotation))
            .padding(.top, (top ?? 0) * s).padding(.leading, (left ?? 0) * s)
            .padding(.trailing, (right ?? 0) * s).padding(.bottom, (bottom ?? 0) * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: Alignment(horizontal: right != nil ? .trailing : (left != nil ? .leading : .center),
                                        vertical: bottom != nil ? .bottom : (top != nil ? .top : .center)))
            .accessibilityHidden(true)
    }
}

// MARK: - Type and buttons

struct OBTitle: View {
    let s: CGFloat
    let text: String
    var size: CGFloat = 58
    var body: some View {
        Text(text).font(OB.font(size * s, .black)).kerning(-0.01 * size * s).foregroundStyle(Theme.ink)
            .lineSpacing(-4 * s).minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct OBLead: View {
    let s: CGFloat
    let text: String
    var size: CGFloat = 25
    var top: CGFloat = 18
    var maxWidth: CGFloat = 500
    var body: some View {
        Text(text).font(OB.font(size * s, .bold)).foregroundStyle(Theme.inkMuted)
            .lineSpacing(size * 0.3 * s)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: maxWidth * s, alignment: .leading)
            .padding(.top, top * s)
    }
}

struct OBEyebrow: View {
    let s: CGFloat
    let text: String
    var fill: Color = Theme.lavender
    var ink: Color = Theme.purple
    var body: some View {
        Text(text.uppercased()).font(OB.font(16 * s, .black)).kerning(1 * s).foregroundStyle(ink)
            .padding(.vertical, 9 * s).padding(.horizontal, 16 * s)
            .background(Capsule().fill(fill))
            .padding(.bottom, 22 * s)
    }
}

/// The big coral primary button (88 pt, 24 pt corners, a 6 pt shade that it sinks into when pressed).
struct OBButton: View {
    let s: CGFloat
    let label: String
    var symbol: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12 * s) {
                if let symbol { Image(systemName: symbol).font(.system(size: 26 * s, weight: .bold)).accessibilityHidden(true) }
                Text(label).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(OB.font(27 * s, .black)).foregroundStyle(Theme.white)
            .frame(maxWidth: .infinity).frame(height: max(88 * s, 60))
        }
        .buttonStyle(Style(s: s))
        .padding(.bottom, 6 * s)
    }
    struct Style: ButtonStyle {
        let s: CGFloat
        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: 24 * s, style: .continuous)
            configuration.label
                .background(shape.fill(Theme.coralStrong))
                .offset(y: configuration.isPressed ? 5 * s : 0)
                .background(shape.fill(Theme.coralShade).offset(y: 6 * s))
                .contentShape(shape)
                .animation(Theme.press, value: configuration.isPressed)
        }
    }
}

/// The white secondary button (page 7's "Go to the home page").
struct OBQuietButton: View {
    let s: CGFloat
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(OB.font(22 * s, .heavy)).foregroundStyle(Theme.purple)
                .frame(maxWidth: .infinity).frame(height: max(76 * s, 56))
        }
        .buttonStyle(QuietStyle(s: s))
    }
    struct QuietStyle: ButtonStyle {
        let s: CGFloat
        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: 22 * s, style: .continuous)
            configuration.label
                .background(shape.fill(Theme.white))
                .overlay(shape.strokeBorder(Theme.line, lineWidth: 3 * s))
                .offset(y: configuration.isPressed ? 3 * s : 0)
                .background(shape.fill(Theme.line).offset(y: 4 * s))
                .contentShape(shape)
                .animation(Theme.press, value: configuration.isPressed)
        }
    }
}

/// A plain purple text button ("Not now", "Close for now"): 64 pt tall.
struct OBTextButton: View {
    let s: CGFloat
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(OB.font(22 * s, .heavy)).foregroundStyle(Theme.purple)
                .frame(maxWidth: .infinity).frame(height: max(64 * s, 44)).contentShape(Rectangle())
        }
        .buttonStyle(OBPressStyle())
    }
}

struct OBPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1).animation(Theme.press, value: configuration.isPressed)
    }
}

/// White card with the 3 pt line border and a flat shade under it.
struct OBCardBackground: View {
    let s: CGFloat
    let radius: CGFloat
    let depth: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius * s, style: .continuous)
        ZStack {
            shape.fill(Theme.line).offset(y: depth * s)
            shape.fill(Theme.white)
            shape.strokeBorder(Theme.line, lineWidth: 3 * s)
        }
    }
}

// MARK: - Drawn pictures (the mockup's inline SVGs)

/// The purple printer (the mockup's 170 × 150 drawing).
struct OBPrinter: View {
    let s: CGFloat
    var compact = false
    var body: some View {
        Canvas { ctx, size in
            if compact {
                // 60 × 54 icon version.
                let k = min(size.width / 60, size.height / 54)
                func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * k, y: y * k, width: w * k, height: h * k) }
                ctx.fill(Path(roundedRect: r(14, 2, 32, 16), cornerRadius: 3 * k), with: .color(Color(hex: 0xFCEBD5)))
                ctx.fill(Path(roundedRect: r(2, 14, 56, 26), cornerRadius: 8 * k), with: .color(Theme.purple))
                ctx.fill(Path(ellipseIn: r(45, 21, 6, 6)), with: .color(Theme.lime))
                ctx.fill(Path(roundedRect: r(12, 34, 36, 18), cornerRadius: 2 * k), with: .color(Color(hex: 0xFCEBD5)))
                return
            }
            let k = min(size.width / 170, size.height / 150)
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * k, y: y * k, width: w * k, height: h * k) }
            let paper = Color(hex: 0xFCEBD5)
            ctx.fill(Path(roundedRect: r(38, 8, 94, 44), cornerRadius: 6 * k), with: .color(paper))
            ctx.fill(Path(roundedRect: r(10, 40, 150, 70), cornerRadius: 20 * k), with: .color(Theme.purple))
            ctx.fill(Path(roundedRect: r(10, 88, 150, 22), cornerRadius: 11 * k), with: .color(Theme.purpleShade))
            ctx.fill(Path(ellipseIn: r(129, 55, 14, 14)), with: .color(Theme.lime))
            ctx.fill(Path(roundedRect: r(34, 96, 102, 50), cornerRadius: 4 * k), with: .color(paper))
            var squiggle = Path()
            squiggle.move(to: CGPoint(x: 60 * k, y: 108 * k))
            squiggle.addLine(to: CGPoint(x: 70 * k, y: 118 * k))
            squiggle.addLine(to: CGPoint(x: 76 * k, y: 112 * k))
            squiggle.addLine(to: CGPoint(x: 84 * k, y: 120 * k))
            squiggle.move(to: CGPoint(x: 74 * k, y: 132 * k))
            squiggle.addLine(to: CGPoint(x: 96 * k, y: 132 * k))
            ctx.stroke(squiggle, with: .color(Color(hex: 0xC77841)), style: StrokeStyle(lineWidth: 4 * k, lineCap: .round, lineJoin: .round))
            ctx.fill(Path(ellipseIn: r(102, 108, 12, 12)), with: .color(Theme.yellow))
        }
        .accessibilityHidden(true)
    }
}

/// The time tile's clock.
struct OBClock: View {
    let s: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Theme.white)
            Circle().strokeBorder(Theme.limeShade, lineWidth: 5 * s * 52 / 54)
            Path { p in
                p.move(to: CGPoint(x: 26, y: 13)); p.addLine(to: CGPoint(x: 26, y: 27)); p.addLine(to: CGPoint(x: 35, y: 33))
            }
            .stroke(Theme.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            .frame(width: 52, height: 52)
            .scaleEffect(s)
        }
        .frame(width: 48 * s, height: 48 * s)
        .accessibilityHidden(true)
    }
}

/// The lime shield with a purple check (page 4).
struct OBShield: View {
    let s: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width / 170, size.height / 196)
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            var outer = Path()
            outer.move(to: pt(85, 6)); outer.addLine(to: pt(158, 32)); outer.addLine(to: pt(158, 90))
            outer.addCurve(to: pt(85, 190), control1: pt(158, 140), control2: pt(126, 174))
            outer.addCurve(to: pt(12, 90), control1: pt(44, 174), control2: pt(12, 140))
            outer.addLine(to: pt(12, 32)); outer.closeSubpath()
            ctx.fill(outer, with: .color(Theme.lime))
            var half = Path()
            half.move(to: pt(85, 6)); half.addLine(to: pt(158, 32)); half.addLine(to: pt(158, 90))
            half.addCurve(to: pt(85, 190), control1: pt(158, 140), control2: pt(126, 174)); half.closeSubpath()
            ctx.fill(half, with: .color(Theme.limeShade))
            var inner = Path()
            inner.move(to: pt(85, 28)); inner.addLine(to: pt(138, 46)); inner.addLine(to: pt(138, 90))
            inner.addCurve(to: pt(85, 166), control1: pt(138, 126), control2: pt(116, 152))
            inner.addCurve(to: pt(32, 90), control1: pt(54, 152), control2: pt(32, 126))
            inner.addLine(to: pt(32, 46)); inner.closeSubpath()
            ctx.fill(inner, with: .color(Theme.white))
            var check = Path()
            check.move(to: pt(58, 96)); check.addLine(to: pt(76, 114)); check.addLine(to: pt(112, 76))
            ctx.stroke(check, with: .color(Theme.purple), style: StrokeStyle(lineWidth: 12 * k, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// The red push-to-talk button with its listening rings (page 5).
struct OBMicBadge: View {
    let s: CGFloat
    var body: some View {
        ZStack {
            Circle().strokeBorder(Theme.micRed.opacity(0.18), lineWidth: 6 * s).padding(-26 * s)
            Circle().strokeBorder(Theme.micRed.opacity(0.3), lineWidth: 6 * s).padding(-12 * s)
            Circle().fill(Color(hex: 0xA3231B)).offset(y: 8 * s)
            Circle().fill(Theme.micRed)
            Image(systemName: "mic.fill").font(.system(size: 64 * s, weight: .bold)).foregroundStyle(Theme.white)
        }
        .accessibilityHidden(true)
    }
}
