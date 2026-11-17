import Foundation
import Testing
@testable import NutmegCore

/// Round 32: the Grown-ups menu (rows, links, the saved-games sort, the plan status and the restore result mapping).
@Suite struct Round32GrownUpsMenuTests {

    // MARK: The menu

    @Test func menuRowsInOrderWithReplayIntroHidden() {
        // Round 33: the intro row is on, and the AI partners row joins the privacy group.
        #expect(GrownUpsFeatures.replayIntro == true)
        #expect(GrownUpsSection.visible(replayIntro: false) == [.savedGames, .subscription, .restorePurchases, .aiPartners,
                                              .privacyPolicy, .aboutWhatWeSave, .termsOfUse, .help])
        #expect(GrownUpsSection.visible(replayIntro: true).last == .replayIntro)
        #expect(GrownUpsSection.groups(replayIntro: false) == [[.savedGames], [.subscription, .restorePurchases],
                                             [.aiPartners, .privacyPolicy, .aboutWhatWeSave, .termsOfUse], [.help]])
        #expect(GrownUpsSection.groups().last == [.help, .replayIntro])
        #expect(GrownUpsSection.groups(replayIntro: true).last == [.help, .replayIntro])
        for s in GrownUpsSection.allCases {
            #expect(!s.title.isEmpty && !s.subtitle.isEmpty && !s.systemImage.isEmpty)
        }
        #expect(Set(GrownUpsSection.allCases.map(\.title)).count == GrownUpsSection.allCases.count)
    }

    @Test func webRowsOpenTheSitePagesOverHTTPS() {
        #expect(GrownUpsSection.privacyPolicy.webPage?.absoluteString == "https://pretendthat.app/privacy")
        #expect(GrownUpsSection.termsOfUse.webPage?.absoluteString == "https://pretendthat.app/terms")
        #expect(GrownUpsSection.savedGames.webPage == nil && GrownUpsSection.help.webPage == nil)
        #expect(GrownUpsLinks.support.absoluteString == "https://pretendthat.app/support")
        #expect(GrownUpsLinks.reportAProblem.host == "reportaproblem.apple.com")
        #expect(GrownUpsLinks.all.allSatisfy { $0.scheme == "https" })
    }

    @Test func aboutCopyMatchesRound31() {
        let about = GrownUpsCopy.about.map { $0.title + " " + $0.body }.joined(separator: " ")
        #expect(about.contains("right on this iPad") && about.contains("never sent"))
        #expect(about.contains("Only words go to our AI partners") && about.contains("Names are removed"))
        #expect(about.contains("game content only") && about.contains("No accounts, ads or tracking"))
        #expect(!about.lowercased().contains("audio is sent"))
        #expect(GrownUpsCopy.billingNote == "Billing and refunds go through Apple.")
    }

    // MARK: Sort

    func row(_ title: String, _ t: TimeInterval) -> SavedGameRow {
        SavedGameRow(id: UUID(), title: title, savedAt: Date(timeIntervalSince1970: t), bytes: 1)
    }

    @Test func sortNewestFirstThenByName() {
        let rows = [row("Bug Theater", 100), row("apple Shop", 300), row("Zoo", 300), row("Cozy Café", 200)]
        #expect(SavedGameSort.newest.apply(rows).map(\.title) == ["apple Shop", "Zoo", "Cozy Café", "Bug Theater"])
        #expect(SavedGameSort.allCases.first == .newest)
    }

    @Test func sortByNameIgnoresCaseAccentsAndOrdersNumbers() {
        let rows = [row("Éclair Bakery", 1), row("bug theater", 2), row("Room 10", 3), row("Room 2", 4),
                    row("Apple Shop", 5), row("Apple Shop", 9)]
        let sorted = SavedGameSort.name.apply(rows)
        #expect(sorted.map(\.title) == ["Apple Shop", "Apple Shop", "bug theater", "Éclair Bakery", "Room 2", "Room 10"])
        #expect(sorted[0].savedAt > sorted[1].savedAt)   // same name: newest first
        #expect(SavedGameSort.name.apply([]).isEmpty)
        #expect(SavedGameSort.name.label == "Name" && SavedGameSort.newest.label == "Newest")
    }

    // MARK: Plans and restore

    @Test func planStatusFromEntitlements() {
        #expect(PlanStatus.from(productIDs: []) == .none)
        #expect(PlanStatus.none.headline == "No active plan yet")
        #expect(PlanStatus.from(productIDs: ["app.pretendthat.showpass.monthly"]) == .active(name: "Show Pass"))
        #expect(PlanStatus.from(productIDs: ["app.pretendthat.show_pass.yearly", "app.pretendthat.SeasonPass.monthly"])
                == .active(name: "Season Pass"))
        #expect(PlanStatus.from(productIDs: ["something.else"]).headline == "Your plan is active")
    }

    @Test func restoreResultMapping() {
        #expect(RestoreOutcome.after(.success(0)) == .nothingToRestore)
        #expect(RestoreOutcome.after(.success(2)) == .restored(count: 2))
        #expect(RestoreOutcome.after(.failure(.userCancelled)) == .cancelled)
        #expect(RestoreOutcome.after(.failure(.network)) == .offline)
        #expect(RestoreOutcome.after(.failure(.notAvailable)) == .unavailable)
        #expect(RestoreOutcome.after(.failure(.other)) == .failed)
        #expect(RestoreOutcome.nothingToRestore.message.hasPrefix("Nothing to restore yet"))
        #expect(RestoreOutcome.restored(count: 1).message.hasPrefix("Restored"))
        #expect(RestoreOutcome.nothingToRestore.finished && RestoreOutcome.restored(count: 1).finished)
        #expect(!RestoreOutcome.failed.finished && !RestoreOutcome.cancelled.finished && !RestoreOutcome.offline.finished)
        let all: [RestoreOutcome] = [.restored(count: 1), .nothingToRestore, .cancelled, .offline, .unavailable, .failed]
        #expect(Set(all.map(\.message)).count == all.count)
    }
}
