import SwiftUI
import NutmegCore

// Onboarding v2: the pages themselves are in OnboardingPages.swift. This file keeps the shared grown-up type,
// the round 33 plans content (behind the gate when the Free Preview is used up) and the kid card.

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
