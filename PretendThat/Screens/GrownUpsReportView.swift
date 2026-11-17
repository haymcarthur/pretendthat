import SwiftUI
import MessageUI
import UIKit
import NutmegCore

/// Round 37 (App Store 1.2: a way to report AI-made content): Grown-ups (behind the gate) → Report a problem. The grown-up
/// picks a game (the one just played this launch, or a saved one) and the part (a printed page, the story, a scene), and
/// their mail app opens addressed to support@pretendthat.app with that part's AI-made text filled in. Nothing about the
/// kids goes in it, and the app sends nothing itself: the grown-up reads it and sends it (or not).
struct GUReportView: View {
    let model: AppModel
    @State private var games: [ContentReport.Game] = []
    @State private var mail: GUReportMail?
    @State private var noMail: GUReportMail?

    var body: some View {
        List {
            Section {
                Text(ReportCopy.intro).font(GUType.body).foregroundStyle(Theme.ink).padding(.vertical, 4)
            }
            if games.isEmpty {
                Section { Text(ReportCopy.none).font(GUType.body).foregroundStyle(Theme.inkMuted) }
            }
            ForEach(games) { game in
                Section {
                    DisclosureGroup {
                        ForEach(game.parts) { part in
                            Button { report(game, part) } label: {
                                HStack {
                                    Text(part.label).font(GUType.body).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                                    Spacer(minLength: Theme.Space.xs)
                                    Image(systemName: "flag").foregroundStyle(Theme.inkMuted).accessibilityHidden(true)
                                }
                            }
                            .accessibilityHint("Opens an email to PretendThat about this part")
                        }
                    } label: {
                        Text(game.title).font(GUType.headline).foregroundStyle(Theme.ink)
                    }
                } header: {
                    Text(game.id == "last" ? ReportCopy.justPlayed : (game.id == games.first(where: { $0.id != "last" })?.id ? ReportCopy.savedHeader : ""))
                }
            }
            Section {} footer: { Text(ReportCopy.footer).font(GUType.footnote) }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Report a problem")
        .onAppear(perform: load)
        .sheet(item: $mail) { m in GUMailView(mail: m) { mail = nil }.ignoresSafeArea() }
        .alert(ReportCopy.noMailTitle, isPresented: Binding(get: { noMail != nil }, set: { if !$0 { noMail = nil } }), presenting: noMail) { m in
            Button(ReportCopy.copyButton) { UIPasteboard.general.string = "To: \(ContentReport.address)\nSubject: \(m.subject)\n\n\(m.body)"; noMail = nil }
            Button("Close", role: .cancel) { noMail = nil }
        } message: { _ in
            Text(ReportCopy.noMailBody(ContentReport.address))
        }
    }

    private func load() {
        Analytics.send(.reportProblemOpened)
        model.refreshShelf()
        var out: [ContentReport.Game] = []
        if let last = model.lastPlayedReport { out.append(last) }
        out += model.shelfGames.map { ContentReport.Game(id: $0.id.uuidString, title: $0.title, kit: $0.kit) }
        games = out
        rtLog("grown-ups: report screen (\(out.count) games, just played: \(model.lastPlayedReport != nil))")
    }

    private func report(_ game: ContentReport.Game, _ part: ContentReport.Part) {
        let m = GUReportMail(subject: ContentReport.subject(game: game.title, part: part),
                             body: ContentReport.body(game: game.title, part: part, appVersion: AppModel.appVersion))
        rtLog("grown-ups: report \(part.id)")   // the part id only, never the text
        if MFMailComposeViewController.canSendMail() { mail = m; return }
        if let url = ContentReport.mailURL(game: game.title, part: part, appVersion: AppModel.appVersion) {
            UIApplication.shared.open(url) { ok in if !ok { noMail = m } }
        } else {
            noMail = m
        }
    }
}

struct GUReportMail: Identifiable {
    let id = UUID()
    let subject: String
    let body: String
}

/// The system mail sheet, prefilled (the grown-up sends it from their own account).
struct GUMailView: UIViewControllerRepresentable {
    let mail: GUReportMail
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([ContentReport.address])
        vc.setSubject(mail.subject)
        vc.setMessageBody(mail.body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onDone()
        }
    }
}
