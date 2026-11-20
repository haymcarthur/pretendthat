import SwiftUI
import NutmegCore

/// Saved game page (Haylee, decisions/2026-11-17-saved-game-page-and-play-bar.md; mockup design/mockups/after-cancel,
/// version A without the player picker). A bookshelf card opens the game's page for everyone: viewing and printing its
/// kit are always free; "Play with Nutmeg" needs an active pass (the Free Preview games are no exception, Haylee
/// 2026-11-17). No AI call anywhere on the page except Nutmeg's two short lines (her usual line path: a clip if one
/// exists, else her live voice once; never the device voice).
extension AppModel {
    /// An active Show Pass or Season Pass (StoreKit's verified, unexpired entitlement).
    var hasActivePass: Bool {
        #if DEBUG
        if debugFakePass { return true }
        #endif
        return purchases.entitlement != nil
    }

    /// The open page's printable pages: always the full 6-role badge / ticket sheets (no player picker).
    var savedPagePages: [KitPage] {
        guard let g = savedPage else { return [] }
        return KitLayout.pages(for: g.kit, roles: g.roles, playerCount: SavedGamePage.printPlayers)
    }

    /// Opens a saved game's page: its saved art comes back from disk into the page's own services (never drawn).
    func openSavedPage(_ g: SavedGame) {
        userAction(.openSavedGame)
        savedPageAsk = false; savedPageGrownUp = false
        savedPage = g
        pageColorArt.reset(); pageOutlineArt.reset()
        rtLog("SAVED PAGE open \"\(g.title)\" (pass \(hasActivePass ? "active" : "none"))")
        let files = savedGames.art(for: g)
        Task { @MainActor in
            let decoded = await Task.detached(priority: .userInitiated) { () -> [String: UIImage] in
                var out: [String: UIImage] = [:]
                for (k, d) in files { if let img = UIImage(data: d)?.preparedForDisplay() { out[k] = img } }
                return out
            }.value
            guard savedPage?.id == g.id else { return }
            var images: [PrintStyle: [String: UIImage]] = [:], cutouts: [PrintStyle: [String: [Int: UIImage]]] = [:]
            for (key, img) in decoded {
                guard let p = ArtKey.parse(key, plain: g.plainArtStyle) else { continue }
                if let n = p.index { cutouts[p.style, default: [:]][p.itemID, default: [:]][n] = img } else { images[p.style, default: [:]][p.itemID] = img }
            }
            for style in PrintStyle.sets { pageArtSet(style).restore(images: images[style] ?? [:], cutouts: cutouts[style] ?? [:]) }
            // A game saved before round 27 has one set: only that one is offered.
            let sets = PrintStyle.sets.filter { !(images[$0] ?? [:]).isEmpty }
            savedPageSets = sets.isEmpty ? [g.plainArtStyle] : sets
            if !savedPageSets.contains(savedPageStyle) { savedPageStyle = savedPageSets[0] }
        }
        // Nutmeg points the kids at the big button (they can't read it).
        sayOnPage(SavedGamePageCopy.hello(title: g.title))
    }

    func closeSavedPage() {
        guard savedPage != nil else { return }
        userAction(.goHome)
        savedPage = nil; savedPageAsk = false; savedPageGrownUp = false
        pageColorArt.reset(); pageOutlineArt.reset()
    }

    /// "Play with Nutmeg": a pass → today's replay (it asks how many); no consent → the existing card; no pass →
    /// Nutmeg's ask-a-grown-up card.
    func tapPlaySavedPage() {
        guard let g = savedPage else { return }
        let action = SavedGamePage.playAction(consent: aiConsent, hasPass: hasActivePass)
        rtLog("SAVED PAGE play \"\(g.title)\": \(action)")
        switch action {
        case .replay:
            savedPage = nil; savedPageAsk = false
            pageColorArt.reset(); pageOutlineArt.reset()
            playSavedGame(g)
        case .needsConsent:
            savedPage = nil
            kidBlock = .needsConsent; showingShelf = false
        case .askGrownUp:
            savedPageAsk = true
            sayOnPage(SavedGamePageCopy.askGrownUp(title: g.title))
        }
    }

    /// The ask card's speaker: her line again.
    func repeatSavedPageAsk() {
        guard let g = savedPage else { return }
        sayOnPage(SavedGamePageCopy.askGrownUp(title: g.title))
    }

    /// The ask card's Grown-ups: the existing gate, then the grown-up card.
    func savedPageGrownUps() {
        userAction(.openSavedGame)
        savedPageAsk = false
        savedPageGrownUp = true
    }

    /// Print: one tap, the chosen set (the iOS print sheet is the second tap, as on the Print step).
    func printSavedPage() {
        guard let g = savedPage else { return }
        let art = pageArtSet(savedPageStyle), pages = savedPagePages
        rtLog("SAVED PAGE print: the \(savedPageStyle.toolValue) set, \(pages.count) page(s)")
        KitPrinter.print(KitPrinter.pdf(pages: pages, set: art), jobName: "PretendThat \(g.title)")
    }

    /// One of the page's short lines: her clip if this game has one, else her live voice (the pre-connected session)
    /// once; never the device voice, never kept with the game. Silent when neither is there (demo, offline).
    private func sayOnPage(_ line: String) {
        speaker.remember(line)
        let route = speaker.say(line, echo: true, record: false)
        rtLog("SAVED PAGE line (\(route)): \"\(line)\"")
    }
}
