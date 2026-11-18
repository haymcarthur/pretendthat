import Foundation
import Testing
@testable import NutmegCore

/// A dictionary stand-in for UserDefaults.
final class FakeDefaults: OnboardingDefaults {
    var values: [String: Any] = [:]
    func bool(forKey k: String) -> Bool { values[k] as? Bool ?? false }
    func integer(forKey k: String) -> Int { values[k] as? Int ?? 0 }
    func string(forKey k: String) -> String? { values[k] as? String }
    func set(_ value: Bool, forKey k: String) { values[k] = value }
    func set(_ value: Int, forKey k: String) { values[k] = value }
    func set(_ value: Any?, forKey k: String) { values[k] = value }
    func removeObject(forKey k: String) { values[k] = nil }
}

/// Round 33: the parent onboarding (state machine, consent gating, the Free Preview counter, plans).
/// Onboarding v2 (2026-11-16): seven full-screen pages, no gate, two ways out of the last page.
@Suite struct Round33OnboardingTests {

    // MARK: The flow (v3, round 44: six pages, privacy + mic in one step, no "Not now")

    @Test func happyPathWalksAllSixPagesWithNoGate() {
        var f = OnboardingFlow()
        #expect(f.screen == .hello && !f.canGoBack)
        f.next()   // "Get started": no gate
        #expect(f.screen == .howItWorks && f.canGoBack)
        f.next()
        #expect(f.screen == .needs && f.canGoBack)
        f.next()
        #expect(f.screen == .privacy && f.canGoBack)
        f.next()   // consent is REQUIRED: Next doesn't skip it
        #expect(f.screen == .privacy && f.consent == nil)
        f.agree()   // "I agree, turn on the mic": consent, then the system prompts
        #expect(f.consent == true && f.screen == .privacy && !f.micAsked)
        f.micAnswered(granted: true)
        #expect(f.screen == .plans && !f.micDenied && !f.showsMicDenied)
        f.startFreePreview()
        #expect(f.screen == .handOff)
        f.startFirstGame()
        #expect(f.finished && f.exit == .firstGame && !f.canGoBack)
        f.goHome()   // already finished: the first answer stands
        #expect(f.exit == .firstGame)
    }

    @Test func handOffCanGoHomeInstead() {
        var f = OnboardingFlow()
        f.next(); f.next(); f.next(); f.agree(); f.micAnswered(granted: true); f.startFreePreview()
        f.goHome()
        #expect(f.finished && f.exit == .home)
    }

    @Test func micAnswersNeedTheConsentFirst() {
        var f = OnboardingFlow()
        f.next(); f.next(); f.next()
        f.micAnswered(granted: true)   // no consent yet: nothing happens
        #expect(f.screen == .privacy && !f.micAsked)
        #expect(OnboardingExit(rawValue: "closedWithoutConsent") == nil)   // v3: no way out without consent
    }

    @Test func deniedMicShowsKidsCanTypeThenNextGoesOn() {
        var f = OnboardingFlow()
        f.next(); f.next(); f.next(); f.agree()
        f.micAnswered(granted: false)
        #expect(f.screen == .privacy && f.micDenied && f.micAsked && f.showsMicDenied)
        #expect(f.screen.dot == OnboardingScreen.privacy.dot)
        f.next()
        #expect(f.screen == .plans && !f.showsMicDenied)
        f.back()
        #expect(f.screen == .privacy && f.showsMicDenied)
    }

    @Test func backWorksOnEveryPageOneAtATime() {
        var f = OnboardingFlow()
        f.next(); f.next(); f.next(); f.agree(); f.micAnswered(granted: true); f.startFreePreview()
        #expect(f.screen == .handOff)
        f.back(); #expect(f.screen == .plans)
        f.back(); #expect(f.screen == .privacy)
        f.back(); #expect(f.screen == .needs)
        f.back(); #expect(f.screen == .howItWorks)
        f.back(); #expect(f.screen == .hello)
        #expect(!f.canGoBack)
        f.back(); #expect(f.screen == .hello)
    }

    @Test func replayWalksTheSamePages() {
        let f = OnboardingFlow(replay: true)
        #expect(f.isReplay && f.screen == .hello)
    }

    @Test func onlyPageOneHasAClipAndEveryPageHasASegment() {
        #expect(OnboardingScreen.allCases.filter(\.nutmegSpeaks) == [.hello])
        #expect(OnboardingScreen.hello.clip == OnboardingCopy.getAGrownUp)
        #expect(OnboardingScreen.allCases.map(\.dot) == Array(0..<OnboardingScreen.dotCount))
        #expect(OnboardingScreen.dotCount == 6)
    }

    @Test func settingsStoreOnlyDeviceFlagsAndFinishOnce() {
        let d = FakeDefaults(), s = ParentSettings(defaults: d)
        #expect(!s.onboardingDone && !s.aiConsent)
        var f = OnboardingFlow(); f.next(); f.next(); f.next(); f.agree()
        s.finish(f)   // not finished yet: nothing stored
        #expect(!s.onboardingDone)
        f.micAnswered(granted: false); f.next(); f.startFreePreview(); f.goHome()
        s.finish(f)
        #expect(s.onboardingDone && s.aiConsent)
        #expect(d.values.values.allSatisfy { $0 is Bool })   // booleans only, nothing about kids
        s.reset()
        #expect(!s.onboardingDone && !s.aiConsent)
    }

    @Test func progressSurvivesClosingTheAppMidway() {
        let d = FakeDefaults(), s = ParentSettings(defaults: d)
        #expect(s.resumeFlow() == OnboardingFlow())
        var f = OnboardingFlow(); f.next(); f.next(); f.next(); f.agree(); f.micAnswered(granted: false)
        s.saveProgress(f)
        // Only a page name and booleans (nothing about kids).
        #expect(d.values.values.allSatisfy { $0 is Bool || $0 is String })
        let back = s.resumeFlow()
        #expect(back.screen == .privacy && back.consent == true && back.micAsked && back.micDenied && back.showsMicDenied)
        // A replay isn't remembered; finishing clears it.
        f.next(); f.startFreePreview(); f.startFirstGame(); s.finish(f)
        #expect(s.resumeFlow() == OnboardingFlow())
        s.saveProgress(OnboardingFlow(replay: true))
        #expect(d.values[OnboardingKeys.page] == nil)
    }

    @Test func aV2FlowLeftOnAnOldPageResumesOnThePrivacyPage() {
        let d = FakeDefaults(), s = ParentSettings(defaults: d)
        for old in ["microphone", "aiDeclined"] {
            d.values[OnboardingKeys.page] = old
            d.values[OnboardingKeys.micAsked] = false
            #expect(s.resumeFlow().screen == .privacy)
        }
        d.values[OnboardingKeys.page] = "microphone"
        d.values[OnboardingKeys.micAsked] = true
        d.values[OnboardingKeys.micDenied] = true
        let f = s.resumeFlow()
        #expect(f.screen == .privacy && f.showsMicDenied && f.consent == true)
        d.values[OnboardingKeys.page] = "nonsense"
        #expect(s.resumeFlow() == OnboardingFlow())
    }

    // MARK: Consent gating of New game

    @Test func newGameNeedsConsentFirst() {
        #expect(NewGameGate.newGame(consent: false, plan: .none, freeRemaining: 2) == .needsConsent)
        #expect(NewGameGate.newGame(consent: false, plan: .active(name: "Show Pass"), freeRemaining: 0) == .needsConsent)
        #expect(NewGameGate.newGame(consent: true, plan: .none, freeRemaining: 2) == .start)
        #expect(NewGameGate.newGame(consent: true, plan: .none, freeRemaining: 0) == .needsPlan)
        #expect(NewGameGate.newGame(consent: true, plan: .active(name: "Season Pass"), freeRemaining: 0) == .start)
        #expect(NewGameGate.replay(consent: true, hasPass: true) == .start)
        #expect(NewGameGate.replay(consent: false, hasPass: true) == .needsConsent)
        #expect(NewGameGate.replay(consent: true, hasPass: false) == .needsPlan)   // saved game page round
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
        #expect(PlanCatalog.showPass.newShowsPerMonth == 5 && PlanCatalog.seasonPass.newShowsPerMonth == 20)
        // Plans 5/20 (Haylee, 2026-11-17): regular prices only, no intro offers.
        #expect(PlanCatalog.showPass.billedText(.monthly) == "$9.99/month")
        #expect(PlanCatalog.showPass.billedText(.yearly) == "$99.99/year")
        #expect(PlanCatalog.seasonPass.billedText(.monthly) == "$24.99/month")
        #expect(PlanCatalog.seasonPass.billedText(.yearly) == "$249.99/year")
        #expect(PlanCatalog.showPass.detailText(.monthly) == nil)
        #expect(PlanCatalog.showPass.detailText(.yearly) == "about $8.33 a month")
        #expect(PlanCatalog.seasonPass.detailText(.yearly) == "about $20.83 a month")
        // Config values: the cards read the caps.
        #expect(PlanCatalog.seasonPass.showsText == "\(PlanCatalog.seasonPassShows) new games a month")
        // Never "Unlimited" as a plan name; never "trial".
        for o in PlanCatalog.offers { #expect(!o.name.lowercased().contains("unlimited")) }
        for l in [OnboardingCopy.plansTitle, OnboardingCopy.plansBody, OnboardingCopy.freePreviewButton] {
            #expect(!l.lowercased().contains("trial") && !l.lowercased().contains("unlimited"))
        }
    }

    // MARK: Words (onboarding v3, the approved mockup)

    @Test func v3CopyIsTheApprovedMockupsWords() {
        #expect(OnboardingCopy.helloTitle == "Welcome to PretendThat")
        #expect(OnboardingCopy.helloBody == "Plan it, print it, play it")   // 2026-11-18: the new tagline
        #expect(OnboardingCopy.helloButton == "Get started")
        #expect(OnboardingCopy.steps.map(\.title) == JourneyStep.allCases.map(\.label))
        #expect(OnboardingCopy.steps.map(\.body) == ["Plan a game by talking with Nutmeg", "Hunt for props around the house",
                                                     "Print a kit made for your game", "Act it out together, scene by scene"])
        #expect(OnboardingCopy.needs.map(\.title) == ["A printer", "Crayons & scissors", "Space to play"])
        // No game length anywhere (Haylee, follow-up 2).
        let all = ([OnboardingCopy.needLead] + OnboardingCopy.needs.flatMap { [$0.title, $0.detail] }).joined(separator: " ")
        #expect(!all.contains("min") && !all.contains("15"))
        #expect(OnboardingCopy.privacyTitle == "Private by design")
        #expect(OnboardingCopy.privacyBody.contains("OpenAI and Anthropic") && OnboardingCopy.privacyBody.contains("names removed"))
        #expect(OnboardingCopy.agree == "I agree, turn on the mic")
        #expect(OnboardingCopy.micFine.contains("microphone next") && !OnboardingCopy.micFine.contains("Allow"))
        #expect(OnboardingCopy.micDeniedTitle == "No mic? Kids can type.")
        #expect(OnboardingCopy.handOffTitle == "You're all set")
        #expect(OnboardingCopy.handOffBody.hasPrefix("Hand your \(DeviceWord.noun) to your child."))
        // Her two lines are bundled clips (recorded from her real voice).
        #expect(CommonLines.all.contains(OnboardingCopy.getAGrownUp) && CommonLines.all.contains(OnboardingCopy.greetKid))
    }

    @Test func v3PlansPageSaysGamesAndTheRenewalPricePlainly() {
        // Plans 5/20: the Free Preview reads as one-time ("to try"), never per month.
        #expect(OnboardingCopy.plansV3Title == "2 free games to try")
        #expect(OnboardingCopy.freeGamesButton == "Try 2 free games")
        // The saved game page round: printables are always theirs (no promise of free replays).
        #expect(OnboardingCopy.plansV3Lead == "Each new game is a fresh story and printable kit made just for your kids. Every game saves itself, and its printables are always yours to view and print.")
        #expect(OnboardingCopy.planGames(.showPass) == "5 new games a month")
        #expect(OnboardingCopy.planGames(.seasonPass) == "20 new games a month")   // no "Up to" (Haylee)
        #expect(OnboardingCopy.billedByApple == "Billed by Apple. Renews until cancelled.")
        #expect(PriceText.rowAmount(regular: "$9.99", period: .monthly) == "$9.99/mo")
        for l in [OnboardingCopy.plansV3Title, OnboardingCopy.plansV3Lead, OnboardingCopy.freeGamesButton] {
            let w = l.lowercased()
            #expect(!w.contains("trial") && !w.contains("show") && !w.contains("replay"))
        }
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
