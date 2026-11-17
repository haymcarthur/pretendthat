import SwiftUI
import SafariServices
import NutmegCore

/// Round D2 + round 32: the Grown-ups corner. The start screen's "Grown-ups" pill opens this sheet; the parental gate
/// (D2, Haylee: hold 2 s, tap the spelled number) comes first, then the Grown-ups MENU: a list of rows, each opening its
/// own screen in the NavigationStack (Saved games, Manage subscription, Restore purchases, About what we save,
/// Help & contact) or an in-app Safari view (Privacy policy, Terms of use). Every outside link lives behind the gate.
struct GrownUpsSheet: View {
    let model: AppModel
    @State private var unlocked: Bool = {
        #if DEBUG
        if let s = DemoDriver.grownUps, !["holding", "grid"].contains(s) { return true }
        #endif
        return false
    }()
    @State private var path: [GrownUpsSection] = {
        #if DEBUG
        if let s = DemoDriver.grownUps {
            if ["confirm", "checked", "search", "lastPlayed", "deleteAll"].contains(s) { return [.savedGames] }
            if let section = GrownUpsSection(rawValue: s), section.webPage == nil { return [section] }
        }
        #endif
        return []
    }()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if unlocked {
                    GrownUpsMenuView(model: model)
                } else {
                    ScrollView {
                        PTGrownUpGate(onPass: { withAnimation(Theme.gentle) { unlocked = true } })
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Space.l)
                    }
                    .background(Theme.white)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { model.closeGrownUps() } } }
                }
            }
            .navigationDestination(for: GrownUpsSection.self) { section in
                GrownUpsDestination(section: section, model: model)
            }
        }
        .tint(Theme.purple)
        .modifier(GUPageSizing())
    }
}

/// iPadOS 18+: the taller page-size sheet, so the whole menu fits without scrolling (iOS 17 keeps the form sheet).
struct GUPageSizing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) { content.presentationSizing(.page) } else { content }
    }
}

// MARK: - Type (Dynamic Type text styles in the app's rounded face; grown-up screens scale with the system size)

enum GUType {
    // Round 39: Poppins on the grown-up side (headings SemiBold 600, body Regular / Medium), Dynamic Type relative.
    static let rowTitle = GrownUpFont.heading(20, relativeTo: .title3)
    static let rowSubtitle = GrownUpFont.font(.regular, size: 15, relativeTo: .subheadline)
    static let headline = GrownUpFont.heading(17, relativeTo: .headline)
    static let body = GrownUpFont.font(.regular, size: 17, relativeTo: .body)
    static let footnote = GrownUpFont.font(.regular, size: 13, relativeTo: .footnote)
    static let button = GrownUpFont.heading(17, relativeTo: .headline)
    /// About -0.02em on a heading.
    static let rowTitleKerning = GrownUpFont.headingKerning(20)
}

/// One outside page to show in the in-app Safari view.
struct GUWebPage: Identifiable, Equatable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - The menu

struct GrownUpsMenuView: View {
    let model: AppModel
    @State private var webPage: GUWebPage? = {
        #if DEBUG
        if let s = DemoDriver.grownUps, let url = GrownUpsSection(rawValue: s)?.webPage { return GUWebPage(url: url) }
        #endif
        return nil
    }()

    private var groups: [[GrownUpsSection]] {
        var show = GrownUpsFeatures.replayIntro
        #if DEBUG
        show = show || DemoDriver.showReplayIntroRow
        #endif
        return GrownUpsSection.groups(replayIntro: show)
    }

    var body: some View {
        List {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, rows in
                Section {
                    ForEach(rows, id: \.self) { row($0) }
                } footer: {
                    if index == groups.count - 1 { Text(GrownUpsCopy.menuFooter).font(GUType.footnote) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .navigationTitle("Grown-ups")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.closeGrownUps() }.bold() } }
        .guSafari($webPage)
    }

    @ViewBuilder private func row(_ section: GrownUpsSection) -> some View {
        if let url = section.webPage {
            Button { webPage = GUWebPage(url: url) } label: {
                GUMenuRow(section: section, trailing: "safari")
            }
            .accessibilityHint("Opens the web page in a browser view")
        } else if section == .replayIntro {
            Button { model.replayParentIntro() } label: { GUMenuRow(section: section, trailing: nil) }
        } else {
            NavigationLink(value: section) { GUMenuRow(section: section, trailing: nil) }
        }
    }
}

struct GUMenuRow: View {
    let section: GrownUpsSection
    /// An SF Symbol after the text (web rows show "safari"); navigation rows get the system chevron.
    let trailing: String?
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 40

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: section.systemImage)
                .font(.system(size: iconSize * 0.48, weight: .semibold))
                .foregroundStyle(Theme.white)
                .frame(width: iconSize, height: iconSize)
                .background(RoundedRectangle(cornerRadius: iconSize * 0.25, style: .continuous).fill(color))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title).font(GUType.rowTitle).kerning(GUType.rowTitleKerning).foregroundStyle(Theme.ink)
                Text(section.subtitle).font(GUType.rowSubtitle).foregroundStyle(Theme.inkMuted)
            }
            Spacer(minLength: Theme.Space.xs)
            if let trailing {
                Image(systemName: trailing).font(.body.weight(.semibold)).foregroundStyle(Theme.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch section.group {
        case 0: Theme.coralStrong
        case 1: Theme.purple
        case 2: Theme.nutmeg
        default: Theme.limeShade
        }
    }
}

/// The screen each app row pushes.
struct GrownUpsDestination: View {
    let section: GrownUpsSection
    let model: AppModel

    var body: some View {
        switch section {
        case .savedGames: GUSavedGamesView(model: model)
        case .plans: GUPlansView(model: model)
        case .subscription: GUSubscriptionView()
        case .restorePurchases: GURestoreView()
        case .aboutWhatWeSave: GUAboutView(model: model)
        case .help: GUHelpView()
        case .aiPartners: GUAIPartnersView(model: model)
        case .reportProblem: GUReportView(model: model)
        case .privacyPolicy, .termsOfUse, .replayIntro: EmptyView()   // web rows / the intro never push
        }
    }
}

// MARK: - Plans (round 38: real products, behind the gate like everything in Grown-ups)

struct GUPlansView: View {
    let model: AppModel
    @State private var webPage: GUWebPage?
    var body: some View {
        ScrollView {
            PlansContent(model: model, mode: .grownUps, webPage: $webPage)
                .padding(Theme.Space.l)
        }
        .background(Theme.white)
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
        .guSafari($webPage)
        .onAppear { Analytics.send(.paywallShown(.grownUps)) }
    }
}

// MARK: - Saved games

struct GUSavedGamesView: View {
    let model: AppModel
    @State private var rows: [SavedGameRow] = []
    /// Round 39 (Haylee): the checkboxes are always there (no Select button): check games, then Delete (one confirm).
    @State private var checked: Set<UUID> = []
    @State private var confirmDelete: [SavedGameRow] = []
    @State private var query = ""
    @AppStorage("grownUps.savedGamesSort") private var sortRaw = SavedGameSort.newest.rawValue

    private var sort: SavedGameSort { SavedGameSort(rawValue: sortRaw) ?? .newest }
    private var shown: [SavedGameRow] { SavedGameSearch.filter(sort.apply(rows), query: query) }
    private var checkedRows: [SavedGameRow] { sort.apply(rows).filter { checked.contains($0.id) } }

    var body: some View {
        List {
            if rows.count > 1 {
                Section {
                    Picker("Sort by", selection: $sortRaw) {
                        ForEach(SavedGameSort.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Sort saved games")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                } header: {
                    Text(summary).font(GUType.footnote).textCase(nil)
                }
            }
            Section {
                if rows.isEmpty {
                    Text(GrownUpsCopy.emptySavedGames).font(GUType.body).foregroundStyle(Theme.inkMuted)
                        .padding(.vertical, Theme.Space.xs)
                } else if shown.isEmpty {
                    Text(GrownUpsCopy.noSearchResults(query)).font(GUType.body).foregroundStyle(Theme.inkMuted)
                        .padding(.vertical, Theme.Space.xs)
                }
                ForEach(shown) { row in
                    GUSavedGameRow(row: row, game: model.shelfGames.first { $0.id == row.id }, model: model,
                                   checked: checked.contains(row.id)) { toggle(row) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { confirmDelete = [row] } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            } footer: {
                if !rows.isEmpty { Text(GrownUpsCopy.savedGamesFooter).font(GUType.footnote) }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search saved games")
        .navigationTitle("Saved games")
        .safeAreaInset(edge: .bottom) {
            if !rows.isEmpty {
                Button(role: .destructive) { confirmDelete = checkedRows } label: {
                    Label(checked.isEmpty ? "Delete" : "Delete (\(checked.count))", systemImage: "trash")
                        .font(GUType.button)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.coralStrong)
                .disabled(checked.isEmpty)
                .padding(.horizontal, Theme.Space.m).padding(.vertical, Theme.Space.s)
                .background(.bar)
                .accessibilityIdentifier("savedGames.delete")
            }
        }
        .alert(GrownUpsCopy.deleteTitle(for: confirmDelete.map(\.title)),
               isPresented: Binding(get: { !confirmDelete.isEmpty }, set: { if !$0 { confirmDelete = [] } })) {
            Button("Delete", role: .destructive) { delete(confirmDelete) }
            Button("Cancel", role: .cancel) { confirmDelete = [] }
        } message: {
            Text(GrownUpsCopy.deleteMessage)
        }
        .onAppear(perform: reload)
        .task { await runDemo() }
    }

    private var summary: String {
        let total = ByteCountFormatter.string(fromByteCount: Int64(rows.reduce(0) { $0 + $1.bytes }), countStyle: .file)
        return "\(rows.count) games · \(total)"
    }

    private func toggle(_ row: SavedGameRow) {
        if checked.contains(row.id) { checked.remove(row.id) } else { checked.insert(row.id) }
    }

    private func reload() {
        model.refreshShelf()
        rows = model.grownUpRows()
        checked.formIntersection(rows.map(\.id))
    }

    private func delete(_ list: [SavedGameRow]) {
        confirmDelete = []
        withAnimation(Theme.gentle) {
            for row in list { model.deleteSavedGame(row.id); checked.remove(row.id) }
            rows = model.grownUpRows()
        }
    }

    /// DEBUG screenshots: -PTGrownUps confirm (two games checked, the confirm) / checked (two checked) / search (a
    /// query) / deleteAll (check every game, delete, close).
    private func runDemo() async {
        #if DEBUG
        switch DemoDriver.grownUps {
        case "confirm", "checked":
            try? await Task.sleep(for: .seconds(1))
            for r in shown.prefix(2) { checked.insert(r.id) }
            if DemoDriver.grownUps == "confirm" { try? await Task.sleep(for: .seconds(0.5)); confirmDelete = checkedRows }
        case "search":
            try? await Task.sleep(for: .seconds(1))
            query = "moon"
        case "lastPlayed":
            sortRaw = SavedGameSort.lastPlayed.rawValue
        case "deleteAll":
            try? await Task.sleep(for: .seconds(1.5))
            checked = Set(rows.map(\.id))
            try? await Task.sleep(for: .seconds(0.6))
            delete(checkedRows)
            try? await Task.sleep(for: .seconds(1))
            rtLog("GROWNUPS: deleted all, left=\(model.grownUpRows().count) myGamesButton=\(!model.shelfGames.isEmpty)")
            model.closeGrownUps()
        default: break
        }
        #endif
    }
}

struct GUSavedGameRow: View {
    let row: SavedGameRow
    let game: SavedGame?
    let model: AppModel
    let checked: Bool
    let onToggle: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var thumbWidth: CGFloat = 132

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.s))
                                                  : AnyLayout(HStackLayout(spacing: Theme.Space.m))
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: Theme.Space.s) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(checked ? Theme.coralStrong : Theme.inkMuted)
                    .frame(minWidth: 44, minHeight: 44)
                layout {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title).font(GUType.rowTitle).kerning(GUType.rowTitleKerning).foregroundStyle(Theme.ink).lineLimit(3)
                        Text("Saved \(row.dateText())").font(GUType.rowSubtitle).foregroundStyle(Theme.inkMuted)
                        Text(row.sizeText).font(GUType.rowSubtitle).foregroundStyle(Theme.inkMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(checked ? "Checked" : "Not checked")
        .accessibilityAddTraits(checked ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Check it to delete")
        .accessibilityIdentifier("savedGames.row")
    }

    /// A wide 3:2 cover (the square cover art fills it, centered), else the prop stickers.
    private var thumbnail: some View {
        let size = CGSize(width: thumbWidth, height: thumbWidth * 2 / 3)
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cream)
            if let g = game {
                if let cover = model.cover(for: g) {
                    Image(uiImage: cover).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
                } else {
                    HStack(spacing: 4) {
                        ForEach(g.coverProps, id: \.self) { id in
                            if let img = UIImage(named: PropLibrary.asset(id)) {
                                Image(uiImage: img).resizable().scaledToFit().frame(maxWidth: size.width / 4, maxHeight: size.height * 0.7)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Manage subscription

struct GUSubscriptionView: View {
    @State private var status: PlanStatus?
    @State private var opening = false
    @State private var failed = false

    var body: some View {
        List {
            Section {
                Text(GrownUpsCopy.subscriptionIntro).font(GUType.body).foregroundStyle(Theme.ink)
                    .padding(.vertical, 4)
            }
            Section("Your plan") {
                HStack(spacing: Theme.Space.s) {
                    if let status {
                        Image(systemName: status == .none ? "sparkles" : "checkmark.seal.fill")
                            .font(.title2).foregroundStyle(status == .none ? Theme.purple : Theme.limeShade)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(status.headline).font(GUType.headline).foregroundStyle(Theme.ink)
                            Text(status.detail).font(GUType.rowSubtitle).foregroundStyle(Theme.inkMuted)
                        }
                    } else {
                        ProgressView()
                        Text("Checking…").font(GUType.body).foregroundStyle(Theme.inkMuted)
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
            Section {
                Button {
                    Task { await openManage() }
                } label: {
                    HStack {
                        Text(GrownUpsCopy.manageButton).font(GUType.button)
                        Spacer()
                        if opening { ProgressView() } else { Image(systemName: "arrow.up.forward.app").accessibilityHidden(true) }
                    }
                }
                .disabled(opening)
            } footer: {
                if failed { Text(GrownUpsCopy.manageFailed).font(GUType.footnote).foregroundStyle(Theme.coralStrong) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Manage subscription")
        .task {
            status = await PTStore.planStatus()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-PTAutoStore") { await openManage() }   // simulator check
            #endif
        }
    }

    private func openManage() async {
        opening = true; failed = false
        let ok = await PTStore.showManageSubscriptions()
        opening = false
        failed = !ok
        status = await PTStore.planStatus()
    }
}

// MARK: - Restore purchases

struct GURestoreView: View {
    enum Phase: Equatable { case idle, working, done(RestoreOutcome) }
    @State private var phase: Phase = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTRestoreShowResult") { return .done(.nothingToRestore) }
        #endif
        return .idle
    }()

    var body: some View {
        List {
            Section {
                Text(GrownUpsCopy.restoreIntro).font(GUType.body).foregroundStyle(Theme.ink).padding(.vertical, 4)
            }
            Section {
                Button {
                    Task { await restore() }
                } label: {
                    HStack {
                        Text(phase == .working ? GrownUpsCopy.restoring : GrownUpsCopy.restoreButton).font(GUType.button)
                        Spacer()
                        if phase == .working { ProgressView() } else { Image(systemName: "arrow.clockwise").accessibilityHidden(true) }
                    }
                }
                .disabled(phase == .working)
            }
            if case .done(let outcome) = phase {
                Section("Result") {
                    HStack(alignment: .top, spacing: Theme.Space.s) {
                        Image(systemName: outcome.finished ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.title2).foregroundStyle(outcome.finished ? Theme.limeShade : Theme.coralStrong)
                            .accessibilityHidden(true)
                        Text(outcome.message).font(GUType.body).foregroundStyle(Theme.ink)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Restore purchases")
        .animation(Theme.gentle, value: phase)
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-PTAutoStore") { await restore() }   // simulator check
            #endif
        }
    }

    private func restore() async {
        phase = .working
        let outcome = await PTStore.restore()
        phase = .done(outcome)
        UIAccessibility.post(notification: .announcement, argument: outcome.message)
    }
}

// MARK: - About what we save

struct GUAboutView: View {
    let model: AppModel
    var body: some View {
        List {
            // Anonymous usage counts (2026-11-17-analytics-build.md): OFF until a grown-up turns it on.
            Section {
                Toggle(isOn: Binding(get: { model.analyticsSharing }, set: { model.setAnalyticsSharing($0) })) {
                    Text(GrownUpsCopy.analyticsToggle).font(GUType.button)
                }
                .tint(Theme.purple)
                .accessibilityIdentifier("analyticsToggle")
            } footer: {
                Text(GrownUpsCopy.analyticsFooter).font(GUType.footnote)
            }
            ForEach(GrownUpsCopy.about, id: \.title) { item in
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title).font(GUType.headline).foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text(item.body).font(GUType.body).foregroundStyle(Theme.inkMuted)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
            // Voice pitch build (2026-11-17): open-source credits (Signalsmith Stretch + Linear, MIT).
            Section {
                ForEach(GrownUpsCopy.credits) { credit in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(credit.line).font(GUType.headline).foregroundStyle(Theme.ink)
                        Text(credit.copyright).font(GUType.body).foregroundStyle(Theme.inkMuted)
                        Text(credit.url).font(GUType.footnote).foregroundStyle(Theme.inkMuted)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("credit-\(credit.name)")
                }
                DisclosureGroup {
                    Text(GrownUpsCopy.mitLicense).font(GUType.footnote).foregroundStyle(Theme.inkMuted).padding(.vertical, 4)
                } label: {
                    Text(GrownUpsCopy.mitLicenseName).font(GUType.button)
                }
                // Round 39: the Poppins license, the file that ships with the font.
                DisclosureGroup {
                    Text(Self.oflText).font(GUType.footnote).foregroundStyle(Theme.inkMuted).padding(.vertical, 4)
                } label: {
                    Text(GrownUpsCopy.oflLicenseName).font(GUType.button)
                }
            } header: {
                Text(GrownUpsCopy.creditsTitle).accessibilityAddTraits(.isHeader)
            } footer: {
                Text(GrownUpsCopy.creditsFooter).font(GUType.footnote)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About what we save")
    }

    /// The SIL Open Font License text bundled with Poppins (Fonts/Poppins-OFL.txt).
    static let oflText: String = Bundle.main.url(forResource: "Poppins-OFL", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "SIL Open Font License 1.1: openfontlicense.org"
}

// MARK: - Help & contact

struct GUHelpView: View {
    @State private var webPage: GUWebPage?

    var body: some View {
        List {
            Section {
                Text(GrownUpsCopy.helpIntro).font(GUType.body).foregroundStyle(Theme.ink).padding(.vertical, 4)
                Button { webPage = GUWebPage(url: GrownUpsLinks.support) } label: {
                    HStack {
                        Text(GrownUpsCopy.helpButton).font(GUType.button)
                        Spacer()
                        Image(systemName: "safari").accessibilityHidden(true)
                    }
                }
                .accessibilityHint("Opens pretendthat.app/support in a browser view")
            }
            Section {
                Text(GrownUpsCopy.billingNote).font(GUType.body).foregroundStyle(Theme.ink).padding(.vertical, 4)
                Button { webPage = GUWebPage(url: GrownUpsLinks.reportAProblem) } label: {
                    HStack {
                        Text(GrownUpsCopy.billingLink).font(GUType.button)
                        Spacer()
                        Image(systemName: "safari").accessibilityHidden(true)
                    }
                }
                .accessibilityHint("Opens reportaproblem.apple.com in a browser view")
            } header: {
                Text("Billing")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Help & contact")
        .guSafari($webPage)
    }
}

// MARK: - AI partners (round 33: grant or revoke the consent; a boolean only)

struct GUAIPartnersView: View {
    let model: AppModel
    @State private var webPage: GUWebPage?
    var body: some View {
        List {
            Section {
                Text(OnboardingCopy.consentScreenBody).font(GUType.body).foregroundStyle(Theme.ink).padding(.vertical, 4)
            }
            Section {
                Toggle(isOn: Binding(get: { model.aiConsent }, set: { model.setAIConsent($0) })) {
                    Text(OnboardingCopy.consentToggle).font(GUType.button)
                }
                .tint(Theme.purple)
            } footer: {
                Text(model.aiConsent ? OnboardingCopy.consentRowSubtitle(true) : OnboardingCopy.consentOffNote).font(GUType.footnote)
            }
            Section {
                Button { webPage = GUWebPage(url: GrownUpsLinks.privacy) } label: {
                    Label(OnboardingCopy.privacyLink, systemImage: "safari").font(GUType.button)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(OnboardingCopy.consentRowTitle)
        .guSafari($webPage)
    }
}

// MARK: - In-app Safari

extension View {
    /// Presents `page` in an in-app Safari view (SFSafariViewController); Done clears it.
    func guSafari(_ page: Binding<GUWebPage?>) -> some View {
        sheet(item: page) { p in
            GUSafariView(url: p.url) { page.wrappedValue = nil }.ignoresSafeArea().modifier(GUPageSizing())
        }
    }
}

struct GUSafariView: UIViewControllerRepresentable {
    let url: URL
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(Theme.purple)
        vc.dismissButtonStyle = .done
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onDone() }
    }
}
