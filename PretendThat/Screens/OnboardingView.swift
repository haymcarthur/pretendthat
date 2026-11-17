import SwiftUI
import NutmegCore

// Onboarding v2: the pages themselves are in OnboardingPages.swift. This file keeps the shared grown-up type,
// the round 33 plans content (behind the gate when the Free Preview is used up) and the kid card.

/// Grown-up type: Dynamic Type text styles in the rounded face, a size up from the Grown-ups menu.
enum OBType {
    // Round 39: Poppins on the grown-up side (headings SemiBold, body Regular / Medium), Dynamic Type relative sizes.
    static let title = GrownUpFont.heading(34, relativeTo: .largeTitle)
    static let lead = GrownUpFont.font(.medium, size: 22, relativeTo: .title2)
    static let section = GrownUpFont.heading(20, relativeTo: .title3)
    static let body = GrownUpFont.font(.regular, size: 20, relativeTo: .title3)
    static let small = GrownUpFont.font(.regular, size: 17, relativeTo: .body)
    static let button = GrownUpFont.heading(20, relativeTo: .title3)
    static let price = GrownUpFont.heading(28, relativeTo: .title)
    static let footnote = GrownUpFont.font(.regular, size: 13, relativeTo: .footnote)
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

// MARK: - Plans (behind the gate: the Free Preview or the month ran out, and Grown-ups → Plans)

/// Round 38: real products. Localized prices and the intro offer (when eligible) come from StoreKit; Buy runs Apple's
/// purchase sheet; Restore (AppStore.sync) and Manage (showManageSubscriptions). Always behind the grown-up gate here.
struct PlansContent: View {
    enum Mode { case outOfShows, grownUps }
    let model: AppModel
    let mode: Mode
    @Binding var webPage: GUWebPage?
    @State private var period: BillingPeriod = PlanCatalog.defaultPeriod
    @State private var selected: PlanTier = .showPass
    @State private var restoring = false
    @State private var restoreResult: RestoreOutcome?
    @State private var outcome: PurchaseOutcome?
    @State private var manageFailed = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// iPhone version: the two plan cards stack (side by side they wrapped a letter a line on the smallest phone).
    @Environment(\.layoutMetrics) private var metrics

    private var purchases: PTPurchases { model.purchases }
    private var allowance: ShowAllowance { model.allowance }
    private var current: PlanEntitlement? { purchases.entitlement }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(title).font(OBType.title).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
            Text(bodyText).font(OBType.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            yourPlan
            Picker("Billing", selection: $period) {
                ForEach(BillingPeriod.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .accessibilityLabel("Billing period")
            // Side by side (the text wraps); stacked at accessibility text sizes.
            if dynamicTypeSize.isAccessibilitySize || metrics.isPhone {
                VStack(spacing: Theme.Space.s) { cards }
            } else {
                HStack(alignment: .top, spacing: Theme.Space.s) { cards }
            }
            buyButton
            if purchases.productsFailed && !purchases.loadingProducts {
                Text(OnboardingCopy.pricesUnavailable).font(OBType.small).foregroundStyle(Theme.coralStrong)
            }
            if let outcome {
                Text(outcome.message).font(OBType.small.weight(.bold)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else if purchases.pendingProductID != nil {
                Text(PurchaseOutcome.pending.message).font(OBType.small).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Theme.Space.m) {
                Button {
                    restoring = true
                    Task {
                        restoreResult = await PTStore.restore()
                        await purchases.refresh()
                        model.planStatus = purchases.status
                        restoring = false
                    }
                } label: { Text(restoring ? GrownUpsCopy.restoring : OnboardingCopy.restore) }
                    .disabled(restoring)
                if current != nil {
                    Button(OnboardingCopy.manage) {
                        Task {
                            manageFailed = !(await PTStore.showManageSubscriptions())
                            await purchases.refresh()
                        }
                    }
                }
                Button(OnboardingCopy.terms) { webPage = GUWebPage(url: GrownUpsLinks.terms) }
                Button(OnboardingCopy.privacy) { webPage = GUWebPage(url: GrownUpsLinks.privacy) }
            }
            .font(OBType.small.weight(.bold)).foregroundStyle(Theme.purple)
            .frame(minHeight: 44)
            if let r = restoreResult {
                Text(r.message).font(OBType.small).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if manageFailed { Text(GrownUpsCopy.manageFailed).font(OBType.small).foregroundStyle(Theme.coralStrong) }
            Text(OnboardingCopy.plansFooter).font(OBType.footnote).foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            if let c = current {
                // Suggest the step up when the month ran out on Show Pass; else the plan they have.
                selected = mode == .outOfShows && c.tier == .showPass ? .seasonPass : c.tier
                period = StoreProducts.period(for: c.productID) ?? period
            }
        }
        .task { if purchases.products.isEmpty { await purchases.loadProducts() } }
    }

    private var title: String {
        switch mode {
        case .grownUps: OnboardingCopy.plansGrownUpsTitle
        case .outOfShows: current.map { OnboardingCopy.planOutTitle($0.tier) } ?? OnboardingCopy.outOfShowsTitle
        }
    }

    private var bodyText: String {
        switch mode {
        case .grownUps: OnboardingCopy.plansGrownUpsBody
        case .outOfShows: current.map { OnboardingCopy.planOutBody($0.tier, refill: allowance.refillText()) } ?? OnboardingCopy.outOfShowsBody
        }
    }

    /// The current plan and what's left (the Free Preview's count, or this month's).
    private var yourPlan: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: "ticket.fill").font(.title2).foregroundStyle(Theme.purple).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(OnboardingCopy.currentPlan): \(allowance.tier.name)").font(OBType.section).foregroundStyle(Theme.ink)
                Text([allowance.summary, allowance.refillText()].compactMap { $0 }.joined(separator: ". "))
                    .font(OBType.small).foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(Theme.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.smallRadius).fill(Theme.lavender.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }

    private var selectedPrice: PlanPrice { PlanPrice(selected, period, purchases: purchases) }
    private var selectedIsCurrent: Bool { current?.productID == selectedPrice.productID }

    @ViewBuilder private var buyButton: some View {
        let p = selectedPrice
        let busy = purchases.buying != nil
        OBPrimaryButton(label: busy ? OnboardingCopy.buying : (selectedIsCurrent ? "\(selected.name) is your plan" : PriceText.buyLabel(selected, billed: p.billed)),
                        symbol: selectedIsCurrent ? "checkmark" : "ticket.fill",
                        enabled: !busy && !selectedIsCurrent && p.loaded) {
            Task {
                outcome = nil
                let o = await purchases.purchase(p.productID)
                outcome = o
                model.planStatus = purchases.status
                UIAccessibility.post(notification: .announcement, argument: o.message)
            }
        }
        .accessibilityLabel(selectedIsCurrent ? "\(selected.name) is your plan" : "Get \(selected.name), \(p.full)")
    }

    @ViewBuilder private var cards: some View {
        ForEach([PlanTier.showPass, .seasonPass], id: \.self) { tier in
            let on = selected == tier
            let price = PlanPrice(tier, period, purchases: purchases)
            let isCurrent = current?.productID == price.productID
            Button { selected = tier; outcome = nil } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(tier.name).font(OBType.section).foregroundStyle(Theme.ink)
                        if isCurrent {
                            Text("Current").font(OBType.footnote.weight(.heavy)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 8).padding(.vertical, 2).background(Capsule().fill(Theme.yellow))
                        }
                        Spacer()
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(on ? Theme.purple : Theme.line)
                    }
                    Text(price.billed).font(OBType.price).foregroundStyle(Theme.ink)
                        .redacted(reason: price.loaded ? [] : .placeholder)
                    // The renewal price in body text (Apple: the regular price stays visible).
                    if let then = price.introThen {
                        Text(then).font(OBType.small).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    Text(OnboardingCopy.cardShows(tier == .seasonPass ? PlanCatalog.seasonPass : PlanCatalog.showPass))
                        .font(OBType.small).foregroundStyle(Theme.ink)
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
            .accessibilityLabel("\(tier.name), \(price.full), \(tier.allowance) new shows a month\(isCurrent ? ", your current plan" : "")")
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
                        PlansContent(model: model, mode: .outOfShows, webPage: $webPage)
                            .onAppear { Analytics.send(.paywallShown(.showsUsedUp)) }
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
                Image(systemName: block == .needsConsent ? "person.2.fill" : "ticket.fill")
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.purple)
                    .frame(width: 76, height: 76).background(Circle().fill(Theme.lavender))
                    .accessibilityHidden(true)
                // Kids never see prices or plan names: just "ask a grown-up" (round 38: also when the month ran out).
                Text(block == .needsConsent ? OnboardingCopy.kidNeedsGrownUp : OnboardingCopy.kidOutOfShows)
                    .font(GrownUpFont.heading(Theme.TextSize.headline, relativeTo: .title)).kerning(GrownUpFont.headingKerning(Theme.TextSize.headline)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                if block == .needsConsent {
                    VStack(spacing: Theme.Space.xs) {
                        Text(OnboardingCopy.declinedTitle).font(OBType.section).foregroundStyle(Theme.ink)
                        Text(OnboardingCopy.declinedBody).font(OBType.small).foregroundStyle(Theme.inkMuted)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                if block != .needsConsent && !model.shelfGames.isEmpty {
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
                        .accessibilityIdentifier("kidCard.grownUps")
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
