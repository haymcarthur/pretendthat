import Foundation
import Testing
@testable import NutmegCore

/// A dictionary stand-in for UserDefaults.
final class FakeDefaults: OnboardingDefaults {
    var values: [String: Any] = [:]
    func bool(forKey k: String) -> Bool { values[k] as? Bool ?? false }
    func integer(forKey k: String) -> Int { values[k] as? Int ?? 0 }
    func set(_ value: Bool, forKey k: String) { values[k] = value }
    func set(_ value: Int, forKey k: String) { values[k] = value }
    func removeObject(forKey k: String) { values[k] = nil }
}

/// Round 33: the parent onboarding (state machine, consent gating, the Free Preview counter, plans).
@Suite struct Round33OnboardingTests {

    // MARK: The flow

    @Test func happyPathWalksAllSixScreens() {
        var f = OnboardingFlow()
        #expect(f.screen == .hello && !f.gatePassed && !f.canGoBack)
        f.next()   // nothing moves before the gate
        #expect(f.screen == .hello)
        f.passGate()
        #expect(f.screen == .howItWorks && f.gatePassed && !f.canGoBack)   // never back to the gate
        f.next()
        #expect(f.screen == .privacy && f.canGoBack)
        f.agree()
        #expect(f.consent == true && f.screen == .microphone)
        f.next()   // the mic screen's only way on is Continue (the system prompts)
        #expect(f.screen == .microphone)
        f.micAnswered(granted: true)
        #expect(f.screen == .plans && !f.micDenied)
        f.startFreePreview()
        #expect(f.screen == .handOff)
        f.handOff()
        #expect(f.finished && !f.canGoBack)
    }

    @Test func notNowShowsTheCalmScreenAndCanCloseOrGoBack() {
        var f = OnboardingFlow()
        f.passGate(); f.next()
        f.notNow()
        #expect(f.screen == .aiDeclined && f.consent == false && f.screen.dot == OnboardingScreen.privacy.dot)
        f.back()
        #expect(f.screen == .privacy)
        f.notNow(); f.closeWithoutConsent()
        #expect(f.finished && f.consent == false)
        // Or agree after reading it.
        var g = OnboardingFlow(); g.passGate(); g.next(); g.notNow(); g.agree()
        #expect(g.consent == true && g.screen == .microphone)
    }

    @Test func deniedMicStaysWithTheNoteThenNextGoesOn() {
        var f = OnboardingFlow()
        f.passGate(); f.next(); f.agree()
        f.micAnswered(granted: false)
        #expect(f.screen == .microphone && f.micDenied && f.micAsked)
        f.next()
        #expect(f.screen == .plans)
    }

    @Test func backStepsOneScreenAtATime() {
        var f = OnboardingFlow()
        f.passGate(); f.next(); f.agree(); f.micAnswered(granted: true); f.startFreePreview()
        #expect(f.screen == .handOff)
        f.back(); #expect(f.screen == .plans)
        f.back(); #expect(f.screen == .microphone)
        f.back(); #expect(f.screen == .privacy)
        f.back(); #expect(f.screen == .howItWorks)
        f.back(); #expect(f.screen == .howItWorks)   // the gate is never re-entered by back
        #expect(f.gatePassed)
    }

    @Test func replayStartsAfterTheGate() {
        let f = OnboardingFlow(replay: true)
        #expect(f.isReplay && f.gatePassed && f.screen == .howItWorks)
    }

    @Test func nutmegSpeaksOnlyOnTheFirstAndLastScreens() {
        #expect(OnboardingScreen.allCases.filter(\.nutmegSpeaks) == [.hello, .handOff])
        #expect(Set(OnboardingScreen.allCases.map(\.dot)).count == OnboardingScreen.dotCount)
    }

    @Test func settingsStoreOnlyBooleansAndFinishOnce() {
        let d = FakeDefaults(), s = ParentSettings(defaults: d)
        #expect(!s.onboardingDone && !s.aiConsent)
        var f = OnboardingFlow(); f.passGate(); f.next(); f.agree()
        s.finish(f)   // not finished yet: nothing stored
        #expect(!s.onboardingDone)
        f.micAnswered(granted: false); f.next(); f.startFreePreview(); f.handOff()
        s.finish(f)
        #expect(s.onboardingDone && s.aiConsent)
        #expect(d.values.values.allSatisfy { $0 is Bool })   // booleans only, nothing about kids
        // A replay that declines turns consent off.
        var r = OnboardingFlow(replay: true); r.next(); r.notNow(); r.closeWithoutConsent()
        s.finish(r)
        #expect(s.onboardingDone && !s.aiConsent)
        s.reset()
        #expect(!s.onboardingDone && !s.aiConsent)
    }

    // MARK: Consent gating of New game

    @Test func newGameNeedsConsentFirst() {
        #expect(NewGameGate.newGame(consent: false, plan: .none, freeRemaining: 2) == .needsConsent)
        #expect(NewGameGate.newGame(consent: false, plan: .active(name: "Show Pass"), freeRemaining: 0) == .needsConsent)
        #expect(NewGameGate.newGame(consent: true, plan: .none, freeRemaining: 2) == .start)
        #expect(NewGameGate.newGame(consent: true, plan: .none, freeRemaining: 0) == .needsPlan)
        #expect(NewGameGate.newGame(consent: true, plan: .active(name: "Season Pass"), freeRemaining: 0) == .start)
        #expect(NewGameGate.replay(consent: true) == .start)
        #expect(NewGameGate.replay(consent: false) == .needsConsent)
    }

    // MARK: The Free Preview counter

    @Test func freePreviewCountsNewGamesNotReplays() {
        let d = FakeDefaults(), c = FreePreviewCounter(defaults: d)
        #expect(c.allowance == 2 && c.remaining == 2 && !c.exhausted)
        c.gameStarted(isReplay: true)
        c.gameStarted(isReplay: true)
        #expect(c.used == 0 && c.remaining == 2)
        c.gameStarted(isReplay: false)
        #expect(c.used == 1 && c.remaining == 1)
        c.gameStarted(isReplay: true)
        #expect(c.used == 1)
        c.gameStarted(isReplay: false)
        #expect(c.exhausted && c.remaining == 0)
        #expect(NewGameGate.newGame(consent: true, plan: .none, freeRemaining: c.remaining) == .needsPlan)
        c.gameStarted(isReplay: false)   // never negative
        #expect(c.remaining == 0)
        #expect(d.values.values.allSatisfy { $0 is Int })   // an integer only
    }

    @Test func freePreviewResetGivesTwoAgain() {
        let d = FakeDefaults(), c = FreePreviewCounter(defaults: d)
        c.gameStarted(isReplay: false); c.gameStarted(isReplay: false)
        #expect(c.exhausted)
        c.reset()
        #expect(c.used == 0 && c.remaining == 2)
        #expect(NewGameGate.newGame(consent: true, plan: .none, freeRemaining: c.remaining) == .start)
    }

    // MARK: Plans

    @Test func plansAreConfigWithBilledPriceFirst() {
        #expect(PlanCatalog.freePreviewShows == 2)
        #expect(PlanCatalog.defaultPeriod == .monthly)
        #expect(PlanCatalog.showPass.newShowsPerMonth == 10 && PlanCatalog.seasonPass.newShowsPerMonth == 30)
        // Haylee's pricing (2026-11-16): an intro price for 12 months, then the regular price; yearly at the regular rate.
        #expect(PlanCatalog.showPass.billedText(.monthly) == "$9.99/month")
        #expect(PlanCatalog.showPass.introOfferText == "$9.99/month for 12 months, then $14.99/month")
        #expect(PlanCatalog.showPass.detailText(.monthly) == "for your first 12 months, then $14.99/month")
        #expect(PlanCatalog.showPass.billedText(.yearly) == "$149.99/year")
        #expect(PlanCatalog.seasonPass.billedText(.monthly) == "$19.99/month")
        #expect(PlanCatalog.seasonPass.introOfferText == "$19.99/month for 12 months, then $29.99/month")
        #expect(PlanCatalog.seasonPass.billedText(.yearly) == "$299.99/year")
        #expect(PlanCatalog.showPass.detailText(.yearly) == "about $12.50 a month · save 17%")
        #expect(PlanCatalog.seasonPass.detailText(.yearly) == "about $25.00 a month · save 17%")
        // Config values: the cards read the caps.
        #expect(PlanCatalog.seasonPass.showsText == "\(PlanCatalog.seasonPassShows) new shows a month")
        // Never "Unlimited" as a plan name; never "trial".
        for o in PlanCatalog.offers { #expect(!o.name.lowercased().contains("unlimited")) }
        for l in [OnboardingCopy.plansTitle, OnboardingCopy.plansBody, OnboardingCopy.freePreviewButton] {
            #expect(!l.lowercased().contains("trial") && !l.lowercased().contains("unlimited"))
        }
    }

    // MARK: Words

    @Test func privacyCopyMatchesRound31() {
        let all = OnboardingCopy.privacyLines.map(\.text).joined(separator: " ")
        #expect(all.contains("turned into words on this iPad"))
        #expect(all.contains("never sent"))
        #expect(all.contains("OpenAI") && all.contains("Anthropic"))
        #expect(all.contains("names removed"))
        #expect(all.contains("No accounts"))
        #expect(all.contains("Saved games stay on this iPad"))
        // The mic pre-permission never says "Allow"; one Continue button.
        #expect(!OnboardingCopy.micContinue.contains("Allow") && !OnboardingCopy.micBody.contains("Allow"))
        #expect(OnboardingCopy.tagline == "Turn your living room into a pretend-play adventure.")
        #expect(OnboardingCopy.steps.map(\.title) == JourneyStep.allCases.map(\.label))
        // Her two lines are bundled clips (recorded from her real voice).
        #expect(CommonLines.all.contains(OnboardingCopy.getAGrownUp) && CommonLines.all.contains(OnboardingCopy.greetKid))
    }

    // MARK: The New game greeting (round 33 addition)

    @Test func firstGameGetsTheIntroWithTheDisclosure() {
        var rng = SeededGenerator(seed: 1)
        let p = GameGreeting.pick(hasPlayedBefore: false, lastShort: nil, using: &rng)
        #expect(p.line == GameGreeting.firstIntro && p.shortIndex == nil)
        #expect(p.line.contains("a pretend helper made by a computer") && p.line.contains("Nutmeg"))
    }

    @Test func laterGamesGetAShortLineWithNoIntroAndNoRepeat() {
        var rng = SeededGenerator(seed: 7)
        var last: Int? = nil
        for _ in 0..<40 {
            let p = GameGreeting.pick(hasPlayedBefore: true, lastShort: last, using: &rng)
            #expect(p.shortIndex != nil && p.shortIndex != last)
            #expect(!p.line.contains("Nutmeg") && !p.line.contains("computer") && !p.line.contains("I'm"))
            #expect(p.line.split(separator: " ").count <= 8 && p.line.contains("What should we play"))   // round 34: one sentence + the question
            last = p.shortIndex
        }
    }

    @Test func greetingFlagTurnsOnAfterTheFirstGreeting() {
        let d = FakeDefaults()
        #expect(GameGreeting.next(d) == GameGreeting.firstIntro)
        #expect(d.bool(forKey: GameGreeting.hasPlayedKey))
        var prev = GameGreeting.next(d)
        #expect(GameGreeting.short.contains(prev))
        for _ in 0..<10 {
            let n = GameGreeting.next(d)
            #expect(n != prev && GameGreeting.short.contains(n))
            prev = n
        }
        #expect(d.values.values.allSatisfy { $0 is Bool || $0 is Int })
    }

    @Test func greetingsAreBundledLinesAndTheNoteForbidsReintroducing() {
        for l in GameGreeting.all { #expect(CommonLines.all.contains(l)) }
        let note = GameGreeting.kickOffNote(ideas: "")
        #expect(note.contains("do NOT greet") && note.contains("introduce yourself"))
    }

    @Test func grownUpsHasTheConsentRowAndTheIntroRow() {
        #expect(GrownUpsSection.visible().contains(.aiPartners))
        #expect(GrownUpsSection.visible().contains(.replayIntro))
        #expect(GrownUpsSection.aiPartners.webPage == nil)
    }
}
