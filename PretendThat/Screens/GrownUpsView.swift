import SwiftUI
import NutmegCore

/// Round D2 (design §D6, Haylee): the Grown-ups corner. The start screen's "Grown-ups" pill opens this sheet; the
/// parental gate comes first, then the Saved games list (delete + confirm) and About saved games. Section E's items
/// (Manage subscription, Restore purchases, Privacy policy, Help) have their slots here, hidden behind
/// `GrownUpsFeatures.storeSections`.
struct GrownUpsSheet: View {
    let model: AppModel
    @State private var unlocked: Bool = {
        #if DEBUG
        if let s = DemoDriver.grownUps, ["list", "confirm", "deleteAll"].contains(s) { return true }
        #endif
        return false
    }()

    var body: some View {
        NavigationStack {
            Group {
                if unlocked {
                    GrownUpsView(model: model)
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
        }
        .tint(Theme.purple)
        .interactiveDismissDisabled(false)
    }
}

struct GrownUpsView: View {
    let model: AppModel
    @State private var rows: [SavedGameRow] = []
    @State private var pendingDelete: SavedGameRow?

    var body: some View {
        List {
            ForEach(GrownUpsSection.visible(), id: \.self) { section in
                switch section {
                case .savedGames: savedGames
                case .aboutSavedGames: about
                case .subscription, .restorePurchases, .privacyPolicy, .help: storePlaceholder(section)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Grown-ups")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.closeGrownUps() }.bold() } }
        .alert(pendingDelete.map { GrownUpsCopy.deleteTitle($0.title) } ?? "",
               isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { row in
            Button("Delete", role: .destructive) { delete(row) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text(GrownUpsCopy.deleteMessage)
        }
        .onAppear(perform: reload)
        .task { await runDemo() }
    }

    // MARK: Saved games

    private var savedGames: some View {
        Section {
            if rows.isEmpty {
                Text(GrownUpsCopy.emptySavedGames).font(Theme.bodyFont(17)).foregroundStyle(Theme.inkMuted)
                    .padding(.vertical, Theme.Space.xs)
            }
            ForEach(rows) { row in
                HStack(spacing: Theme.Space.m) {
                    thumbnail(row)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title).font(Theme.headlineFont(20)).foregroundStyle(Theme.ink).lineLimit(2)
                        Text("Saved \(row.dateText()) · \(row.sizeText)").font(Theme.bodyFont(15)).foregroundStyle(Theme.inkMuted)
                    }
                    Spacer(minLength: Theme.Space.s)
                    Button { pendingDelete = row } label: {
                        Image(systemName: "trash").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.coralStrong)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete \(row.title)")
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(row.accessibilityLabel)
                .accessibilityAction(named: "Delete") { pendingDelete = row }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { pendingDelete = row } label: { Label("Delete", systemImage: "trash") }
                }
            }
        } header: {
            Text(GrownUpsSection.savedGames.title)
        } footer: {
            if !rows.isEmpty { Text("Saved on this iPad. Kids can't delete games; only you can, here.") }
        }
    }

    @ViewBuilder private func thumbnail(_ row: SavedGameRow) -> some View {
        let size = CGSize(width: 76, height: 56)
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.cream)
            if let g = model.shelfGames.first(where: { $0.id == row.id }) {
                if let cover = model.cover(for: g) {
                    Image(uiImage: cover).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
                } else {
                    HStack(spacing: 2) {
                        ForEach(g.coverProps, id: \.self) { id in
                            if let img = UIImage(named: PropLibrary.asset(id)) { Image(uiImage: img).resizable().scaledToFit().frame(maxWidth: 22, maxHeight: 36) }
                        }
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityHidden(true)
    }

    // MARK: About saved games

    private var about: some View {
        Section(GrownUpsSection.aboutSavedGames.title) {
            ForEach(GrownUpsCopy.about, id: \.title) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(Theme.headlineFont(17)).foregroundStyle(Theme.ink)
                    Text(item.body).font(Theme.bodyFont(15)).foregroundStyle(Theme.inkMuted)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Section E slots (hidden: `GrownUpsFeatures.storeSections` is off)

    private func storePlaceholder(_ section: GrownUpsSection) -> some View {
        // Section E replaces each with its real row (StoreKit manage/restore, the privacy policy link behind
        // `PTGrownUpGate`, help & contact).
        Section(section.title) { Text("Coming soon").foregroundStyle(Theme.inkMuted) }
    }

    // MARK: Actions

    private func reload() {
        model.refreshShelf()
        rows = model.grownUpRows()
    }

    private func delete(_ row: SavedGameRow) {
        pendingDelete = nil
        withAnimation(Theme.gentle) {
            model.deleteSavedGame(row.id)
            rows = model.grownUpRows()
        }
    }

    /// DEBUG screenshots: -PTGrownUps confirm (the confirm for the first game) / deleteAll (delete every game, close).
    private func runDemo() async {
        #if DEBUG
        switch DemoDriver.grownUps {
        case "confirm":
            try? await Task.sleep(for: .seconds(1))
            pendingDelete = rows.first
        case "deleteAll":
            try? await Task.sleep(for: .seconds(1.5))
            for row in rows { delete(row); try? await Task.sleep(for: .milliseconds(600)) }
            try? await Task.sleep(for: .seconds(1))
            rtLog("GROWNUPS: deleted all, left=\(model.grownUpRows().count) myGamesButton=\(!model.shelfGames.isEmpty)")
            model.closeGrownUps()
        default: break
        }
        #endif
    }
}
