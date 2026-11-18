import Foundation

// Round 33: the first-launch parent onboarding (research 2026-11-16-onboarding-research.md, Haylee's decisions in
// decisions/2026-11-15-paid-app-direction.md). Shown once, replayable from Grown-ups. Nothing about kids is stored:
// device flags only (onboarding done, AI consent yes/no, a count of new games started).
//
// Onboarding v3 (round 44, Haylee approved design/mockups/onboarding-v3; decisions/2026-11-17-onboarding-v3-feedback.md):
// six calm pages, no gate:
//   1 Welcome to PretendThat · 2 How it works · 3 What you'll need · 4 Private by design (REQUIRED AI consent and the
//   microphone in one step: "I agree, turn on the mic", the only button; a denied mic shows "No mic? Kids can type.")
//   · 5 Start with 2 free games (plans) · 6 You're all set: "Start our first game" or "Go to the home page".
// AI is required, so there's no "Not now" and no decline page (consent can still be turned off in Grown-ups).

// MARK: - Screens and the flow

public enum OnboardingScreen: String, CaseIterable, Sendable {
    case hello, howItWorks, needs, privacy, plans, handOff

    /// The progress bar's segment (0-based; segments up to and including it are filled).
    public var dot: Int {
        switch self {
        case .hello: 0
        case .howItWorks: 1
        case .needs: 2
        case .privacy: 3
        case .plans: 4
        case .handOff: 5
        }
    }
    public static let dotCount = 6
    /// Nutmeg's bundled clip on this page (her real recorded voice, never TTS), played only while she's visible on it:
    /// page 1 only (her start-screen art). "Start our first game" opens the game, whose own greeting is the first thing
    /// she says; "Go to the home page" is silent.
    public var clip: String? { self == .hello ? OnboardingCopy.getAGrownUp : nil }
    public var nutmegSpeaks: Bool { clip != nil }

    /// A saved page name, including the v2 pages a first-launch flow may have been left on before v3 (the old consent
    /// and microphone pages fold into the privacy page).
    public static func restored(_ raw: String) -> OnboardingScreen? {
        if let s = OnboardingScreen(rawValue: raw) { return s }
        return raw == "aiDeclined" || raw == "microphone" ? .privacy : nil
    }
}

/// How the flow ended.
public enum OnboardingExit: String, Equatable, Sendable {
    /// "Start our first game": straight into a new game on the stage (Nutmeg visible and talking).
    case firstGame
    /// "Go to the home page": the start screen, with no voice at all.
    case home
}

/// The onboarding state machine (no gate). Back moves one page at a time on every page but the first.
/// A replay from Grown-ups walks the same pages (page 1's clip stays quiet: the grown-up asked for it).
public struct OnboardingFlow: Equatable, Sendable {
    public private(set) var screen: OnboardingScreen
    /// The grown-up's AI answer in this run (nil = not answered yet). v3: only ever true (AI is required).
    public private(set) var consent: Bool?
    /// The system mic / speech prompts came back denied (the privacy page then shows "No mic? Kids can type." + Next).
    public private(set) var micDenied = false
    /// "I agree, turn on the mic" ran the system prompts (or they were already answered).
    public private(set) var micAsked = false
    /// How the flow ended (nil = still running).
    public private(set) var exit: OnboardingExit?
    public var finished: Bool { exit != nil }
    public let isReplay: Bool

    public init(replay: Bool = false) {
        isReplay = replay
        screen = .hello
    }

    /// Restores a flow that was on `screen` when the app was closed (device flags only).
    public init(restoring screen: OnboardingScreen, consent: Bool?, micAsked: Bool, micDenied: Bool, replay: Bool = false) {
        isReplay = replay
        self.screen = screen
        let past = screen == .plans || screen == .handOff
        self.micAsked = micAsked && (past || screen == .privacy)
        self.consent = past || self.micAsked ? true : consent
        self.micDenied = micDenied && self.micAsked
    }

    /// The page's main forward button (Get started → How it works → What you'll need → Privacy; the privacy page's
    /// Next after a denied mic → the plans).
    public mutating func next() {
        switch screen {
        case .hello: screen = .howItWorks
        case .howItWorks: screen = .needs
        case .needs: screen = .privacy
        case .privacy where micAsked && consent == true: screen = .plans
        default: break
        }
    }

    /// "I agree, turn on the mic": consent on; the app then asks for the microphone (`micAnswered`).
    public mutating func agree() {
        guard screen == .privacy else { return }
        consent = true
    }

    /// The system prompts answered. Granted: on to the plans. Denied: stay with "No mic? Kids can type." (Next goes on).
    public mutating func micAnswered(granted: Bool) {
        guard screen == .privacy, consent == true else { return }
        micAsked = true
        micDenied = !granted
        if granted { screen = .plans }
    }

    /// The privacy page shows the denied state ("No mic? Kids can type.", Next, Open Settings).
    public var showsMicDenied: Bool { screen == .privacy && micAsked && micDenied }

    /// "Start with 2 free games" (or Continue on a replay with the games used up / a plan active): the last page.
    public mutating func startFreePreview() {
        guard screen == .plans else { return }
        screen = .handOff
    }

    /// "Start our first game".
    public mutating func startFirstGame() {
        guard screen == .handOff, !finished else { return }
        exit = .firstGame
    }

    /// "Go to the home page".
    public mutating func goHome() {
        guard screen == .handOff, !finished else { return }
        exit = .home
    }

    /// Back works on every page except the first (nothing before it).
    public var canGoBack: Bool { screen != .hello && !finished }

    public mutating func back() {
        guard canGoBack else { return }
        switch screen {
        case .howItWorks: screen = .hello
        case .needs: screen = .howItWorks
        case .privacy: screen = .needs
        case .plans: screen = .privacy
        case .handOff: screen = .plans
        case .hello: break
        }
    }
}

// MARK: - Device flags (nothing about kids)

/// Where the three flags live (UserDefaults in the app; a dictionary in tests).
public protocol OnboardingDefaults: AnyObject {
    func bool(forKey: String) -> Bool
    func integer(forKey: String) -> Int
    func set(_ value: Bool, forKey: String)
    func set(_ value: Int, forKey: String)
    func set(_ value: Any?, forKey: String)
    func string(forKey: String) -> String?
    func removeObject(forKey: String)
}

extension UserDefaults: OnboardingDefaults {}

public enum OnboardingKeys {
    public static let done = "pt.onboarding.done"
    /// A boolean only: the grown-up agreed to the AI partners (5.1.2(i)).
    public static let aiConsent = "pt.aiConsent"
    /// An integer only: NEW games started on the Free Preview (replays never count).
    public static let freePreviewUsed = "pt.freePreview.newGames"
    /// v2: the page a first-launch onboarding is on (a string), so closing the app mid-way comes back to it.
    public static let page = "pt.onboarding.page"
    /// v2: the mic page's Continue ran / came back denied (booleans), for the same restore.
    public static let micAsked = "pt.onboarding.micAsked"
    public static let micDenied = "pt.onboarding.micDenied"
}

/// The onboarding-done and AI-consent flags.
public final class ParentSettings {
    let defaults: OnboardingDefaults
    public init(defaults: OnboardingDefaults) { self.defaults = defaults }

    public var onboardingDone: Bool {
        get { defaults.bool(forKey: OnboardingKeys.done) }
        set { defaults.set(newValue, forKey: OnboardingKeys.done) }
    }
    public var aiConsent: Bool {
        get { defaults.bool(forKey: OnboardingKeys.aiConsent) }
        set { defaults.set(newValue, forKey: OnboardingKeys.aiConsent) }
    }

    /// The flow finished: remember it, and the consent answer (a closed-without-consent flow stores false).
    public func finish(_ flow: OnboardingFlow) {
        guard flow.finished else { return }
        onboardingDone = true
        if let c = flow.consent { aiConsent = c }
        clearProgress()
    }

    /// v2: remember where a first-launch flow is (the page and the mic answer), so the grown-up comes back to the same
    /// page after the app is closed in the background. Device flags only. Replays aren't remembered.
    public func saveProgress(_ flow: OnboardingFlow) {
        guard !flow.isReplay, !flow.finished else { return }
        defaults.set(flow.screen.rawValue, forKey: OnboardingKeys.page)
        defaults.set(flow.micAsked, forKey: OnboardingKeys.micAsked)
        defaults.set(flow.micDenied, forKey: OnboardingKeys.micDenied)
    }

    /// The first-launch flow to show: where it was left, or page 1.
    public func resumeFlow() -> OnboardingFlow {
        guard let raw = defaults.string(forKey: OnboardingKeys.page), let screen = OnboardingScreen.restored(raw) else {
            return OnboardingFlow()
        }
        return OnboardingFlow(restoring: screen, consent: nil, micAsked: defaults.bool(forKey: OnboardingKeys.micAsked),
                              micDenied: defaults.bool(forKey: OnboardingKeys.micDenied))
    }

    public func clearProgress() {
        defaults.removeObject(forKey: OnboardingKeys.page)
        defaults.removeObject(forKey: OnboardingKeys.micAsked)
        defaults.removeObject(forKey: OnboardingKeys.micDenied)
    }

    /// DEBUG: show the onboarding again on the next launch (consent cleared too).
    public func reset() {
        defaults.removeObject(forKey: OnboardingKeys.done)
        defaults.removeObject(forKey: OnboardingKeys.aiConsent)
        clearProgress()
    }
}

/// The Free Preview: 2 free NEW shows, no card, counted on this iPad. Replays never count.
public final class FreePreviewCounter {
    let defaults: OnboardingDefaults
    public let allowance: Int
    public init(defaults: OnboardingDefaults, allowance: Int = PlanCatalog.freePreviewShows) {
        self.defaults = defaults; self.allowance = allowance
    }

    public var used: Int { defaults.integer(forKey: OnboardingKeys.freePreviewUsed) }
    public var remaining: Int { max(allowance - used, 0) }
    public var exhausted: Bool { remaining == 0 }

    /// A game started. Only a NEW game counts; a replay of a saved game never does. Returns the new count.
    @discardableResult
    public func gameStarted(isReplay: Bool) -> Int {
        guard !isReplay else { return used }
        let n = used + 1
        defaults.set(n, forKey: OnboardingKeys.freePreviewUsed)
        return n
    }

    /// DEBUG flag (`-PTResetFreePreview`): back to 2 free shows.
    public func reset() { defaults.removeObject(forKey: OnboardingKeys.freePreviewUsed) }
}

// MARK: - New game gating

public enum NewGameGate: Equatable, Sendable {
    /// Start the game.
    case start
    /// No AI consent: the calm explanation (PretendThat needs it; turn it on in Grown-ups), not the game.
    case needsConsent
    /// The Free Preview is used up and there's no plan: the plans screen (behind the gate), not a new game.
    case needsPlan
    /// Round 38: a paid plan's new shows for this month are used up: the plans screen (behind the gate) says when more
    /// arrive. Kids see only "That's all the new shows for now! Ask a grown-up."
    case outOfShows

    /// New game. Consent first (no AI calls without it), then the Free Preview count unless a plan is active.
    public static func newGame(consent: Bool, plan: PlanStatus, freeRemaining: Int) -> NewGameGate {
        guard consent else { return .needsConsent }
        if case .active = plan { return .start }
        return freeRemaining > 0 ? .start : .needsPlan
    }

    /// A saved game's replay: free (never counted), but Nutmeg's live voice still needs the AI consent.
    public static func replay(consent: Bool) -> NewGameGate { consent ? .start : .needsConsent }
}

// MARK: - Plans (config values; the limits are finalized after the cost decision)

public enum BillingPeriod: String, CaseIterable, Sendable {
    case monthly, yearly
    public var label: String { self == .monthly ? "Monthly" : "Yearly" }
}

public struct PlanOffer: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// New shows a month (planned: finalized after the cost decision).
    public let newShowsPerMonth: Int
    /// Monthly: the introductory price for the first `introMonths` months, then the regular price.
    public let monthlyIntro: Decimal
    public let introMonths: Int
    public let monthly: Decimal
    public let yearly: Decimal

    /// What's billed first: the intro price for monthly, the yearly price for yearly.
    public func price(_ period: BillingPeriod) -> Decimal { period == .monthly ? monthlyIntro : yearly }

    /// The billed price, the most prominent number (3.1.2): "$9.99/month", "$149.99/year".
    public func billedText(_ period: BillingPeriod) -> String {
        "\(PlanCatalog.dollars(price(period)))/\(period == .monthly ? "month" : "year")"
    }

    /// Apple's intro-offer wording with the regular price visible: "$9.99/month for 12 months, then $14.99/month".
    public var introOfferText: String {
        "\(PlanCatalog.dollars(monthlyIntro))/month for \(introMonths) months, then \(PlanCatalog.dollars(monthly))/month"
    }

    /// v2 plan cards, under the big monthly price: "for 12 months, then $14.99/month".
    public var introThenText: String {
        "for \(introMonths) months, then \(PlanCatalog.dollars(monthly))/month"
    }

    /// The line under the big price: monthly → "for your first 12 months, then $14.99/month" (the renewal price, in
    /// body text); yearly → "about $12.50 a month · save 17%" (smaller, subordinate to the billed price).
    public func detailText(_ period: BillingPeriod) -> String {
        switch period {
        case .monthly:
            return "for your first \(introMonths) months, then \(PlanCatalog.dollars(monthly))/month"
        case .yearly:
            let perMonth = NSDecimalNumber(decimal: yearly).doubleValue / 12
            let save = 1 - NSDecimalNumber(decimal: yearly).doubleValue / (NSDecimalNumber(decimal: monthly).doubleValue * 12)
            return String(format: "about $%.2f a month · save %d%%", perMonth, Int((save * 100).rounded()))
        }
    }

    /// "10 new shows a month (planned)": the cap is a config value until the cost decision.
    public var showsText: String { "\(newShowsPerMonth) new shows a month" }
}

public enum PlanCatalog {
    /// The Free Preview's allowance of new shows (no card).
    public static let freePreviewShows = 2
    /// Config values: Show Pass 10, Season Pass 30 for now (marked "planned" on screen).
    public static let showPassShows = 10
    public static let seasonPassShows = 30
    public static let defaultPeriod: BillingPeriod = .monthly

    // THE one place for prices (Haylee, 2026-11-16): StoreKit's products replace these later.
    public static let introMonths = 12
    public static var showPass: PlanOffer {
        PlanOffer(id: "showpass", name: "Show Pass", newShowsPerMonth: showPassShows, monthlyIntro: Decimal(string: "9.99")!,
                  introMonths: introMonths, monthly: Decimal(string: "14.99")!, yearly: Decimal(string: "149.99")!)
    }
    public static var seasonPass: PlanOffer {
        PlanOffer(id: "seasonpass", name: "Season Pass", newShowsPerMonth: seasonPassShows, monthlyIntro: Decimal(string: "19.99")!,
                  introMonths: introMonths, monthly: Decimal(string: "29.99")!, yearly: Decimal(string: "299.99")!)
    }
    public static var offers: [PlanOffer] { [showPass, seasonPass] }

    /// "$9.99" (v2 plan cards draw the "/month" smaller beside it).
    public static func dollarsText(_ d: Decimal) -> String { dollars(d) }

    static func dollars(_ d: Decimal) -> String {
        String(format: "$%.2f", NSDecimalNumber(decimal: d).doubleValue)
    }
}

// MARK: - Words

public enum OnboardingCopy {
    // Nutmeg's two lines (bundled clips recorded from her real voice; never TTS).
    public static let getAGrownUp = "Hi! I'm Nutmeg. Can you get a grown-up? This part is just for them."
    public static let greetKid = "Hi! I'm Nutmeg, your pretend-play stage manager. Tap the big play button, and let's make up a game!"

    public static let tagline = "Turn your living room into a pretend-play adventure."
    public static let nutmegIntro = "Meet Nutmeg, your pretend-play stage manager."


    // Onboarding v3 (design/mockups/onboarding-v3; one title, one gray line, one purple button per page).

    // 1 · Welcome
    public static let helloTitle = "Welcome to PretendThat"
    public static let helloBody = tagline
    public static let helloButton = "Get started"

    // 2 · How it works (four rows: an icon, one word, one short line)
    public static let howTitle = "How it works"
    public static let steps: [(step: JourneyStep, title: String, body: String)] = [
        (.game, "Pick", "Pick a game by talking with Nutmeg"),
        (.getReady, "Props", "Find props around the house"),
        (.print, "Print", "Print your custom kit"),
        (.play, "Play", "Play scene by scene, off the screen"),
    ]

    // 3 · What you'll need (three tiles; no game length anywhere)
    public static let needTitle = "What you'll need"
    public static let needLead = "Most of it is already in your home."
    public static let needs: [(title: String, detail: String)] = [
        ("A printer", "For the kit"),
        ("Crayons & scissors", "To color and cut"),
        ("Space to play", "Room to move"),
    ]

    // 4 · Private by design: the REQUIRED AI consent and the microphone, one button (no "Not now")
    public static let privacyTitle = "Private by design"
    public static let privacyBody = "Nutmeg uses AI. Words, with names removed, go to OpenAI and Anthropic."
    /// The inline link after `privacyBody` (opens the policy in the in-app browser).
    public static let privacyBodyLink = "Privacy policy"
    /// Grown-ups → AI partners' link to the policy.
    public static let privacyLink = "Read our privacy policy"
    public static let agree = "I agree, turn on the mic"
    /// Under the button: the system prompt comes next, so it's never a surprise.
    public static let micFine = "Your \(DeviceWord.noun) will ask to use the microphone next."
    // 4b · the mic was not allowed (same progress step)
    public static let micDeniedTitle = "No mic? Kids can type."
    public static let micDeniedBody = "Turn on the microphone in Settings anytime."
    public static let micDeniedSettings = "Open Settings"
    public static let next = "Next"

    // New game without consent (Grown-ups → AI partners turned off): the kid card's grown-up note
    public static let declinedTitle = "PretendThat needs this to work"
    public static let declinedBody = "Nutmeg uses our AI partners to listen, talk and make each game, so PretendThat can't play without them. That's OK. You can turn it on any time in Grown-ups."

    // 5 · Start with 2 free games (no Monthly/Yearly switch: yearly lives in Grown-ups → Plans)
    public static var plansV3Title: String { "Start with \(PlanCatalog.freePreviewShows) free games" }
    /// Haylee's follow-up 3 wording (decisions/2026-11-17-onboarding-v3-feedback.md).
    public static let plansV3Lead = "Each new game is a fresh story and printable kit made just for your kids. Every game saves itself, so they can play it again as many times as they like, free."
    /// The plan row's line: "10 new games a month" / "30 new games a month" (no "Up to", Haylee).
    public static func planGames(_ tier: PlanTier) -> String { "\(tier.allowance) new games a month" }
    public static let getPlan = "Get"
    public static var freeGamesButton: String { "Start with \(PlanCatalog.freePreviewShows) free games" }
    public static let billedByApple = "Billed by Apple. Renews until cancelled."
    public static let restoreShort = "Restore"
    public static let termsShort = "Terms"
    public static let privacyShort = "Privacy"

    // Plans behind the gate (the Free Preview used up)
    public static let plansTitle = "Start with your Free Preview"
    public static let plansBody = "Your first 2 brand-new shows are free. No card, nothing to cancel. Replays of saved games are always free."
    public static let freePreviewButton = "Start my Free Preview"
    public static let continueButton = "Continue"
    public static let plansFooter = "Show Pass and Season Pass are subscriptions billed by Apple. They renew automatically until cancelled in Settings, at least 24 hours before renewal."
    public static let plannedNote = "planned"
    public static let comingSoon = "Coming soon"
    public static let comingSoonNote = "Plans can't be bought yet. They're coming soon."
    public static let replaysLine = "Replay saved games as often as you like"
    public static let restore = "Restore purchases"
    public static let terms = "Terms of Use"
    public static let privacy = "Privacy Policy"
    // Round 38: real purchases.
    public static let plansGrownUpsTitle = "Plans"
    public static let plansGrownUpsBody = "Every plan includes unlimited replays of saved games. Plans are billed by Apple to your Apple ID."
    public static func planOutTitle(_ tier: PlanTier) -> String { "This month's new shows are used up" }
    public static func planOutBody(_ tier: PlanTier, refill: String?) -> String {
        "\(tier.name) includes \(tier.allowance) new shows a month. \(refill ?? "More arrive when your plan renews.") Saved games are still free to replay."
            + (tier == .showPass ? " Want more? Season Pass has up to \(PlanTier.seasonPass.allowance) a month." : "")
    }
    public static let buying = "Talking to the App Store…"
    public static let loadingPrices = "Loading prices from the App Store…"
    public static let pricesUnavailable = "Prices couldn't be loaded from the App Store. Check the Wi-Fi and try again."
    public static let currentPlan = "Your plan"
    public static let manage = "Manage subscription"
    public static let introNote = "Introductory price for new subscribers"
    public static let yearlyLink = "Yearly plans"
    public static let monthlyLink = "Monthly plans"
    public static let outOfShowsTitle = "Your Free Preview is used up"
    public static let outOfShowsBody = "Your 2 free new shows are done. Pick a plan for more new shows. Saved games are still free to replay."

    // 6 · You're all set (the logo; "your device" is the device word)
    public static let handOffTitle = "You're all set"
    public static let handOffBody = "Hand your \(DeviceWord.noun) to your child. Nutmeg will take it from here."
    public static let startFirstGame = "Start our first game"
    public static let goHome = "Go to the home page"

    // Kid-facing cards on the start screen (no prices; the grown-up opens the gate)
    public static let kidNeedsGrownUp = "Ask a grown-up to finish setting up."
    public static let kidOutOfShows = "That's all the new shows for now! Ask a grown-up."
    public static let kidGrownUpsButton = "Grown-ups"

    // The Grown-ups row
    public static let consentRowTitle = "AI partners"
    public static func consentRowSubtitle(_ on: Bool) -> String { on ? "On: Nutmeg can talk and make games" : "Off: turn on so Nutmeg can play" }
    public static let consentScreenBody = "Nutmeg uses our AI partners, OpenAI and Anthropic, to listen, talk and make each game. Your child's voice is turned into words on this \(DeviceWord.noun) and never sent. Only those words, with names removed, are sent so Nutmeg can answer. PretendThat needs this to work."
    public static let consentToggle = "Allow AI partners"
    public static let consentOffNote = "While this is off, New game explains that PretendThat needs it."
}

// MARK: - The game's opening greeting (round 33 addition, Haylee: shorter, no re-introduction)

/// The New game greeting. The FIRST game ever gets the short full introduction (with the AI disclosure, Anthropic's
/// minors rule); every later new game gets one short line from a rotating set, with no self-introduction. Both are
/// bundled clips recorded from her real voice (never TTS). Then her live turn asks the game question only.
public enum GameGreeting {
    /// Kept short: the hand-off already said "your pretend-play stage manager"; this keeps the AI disclosure.
    public static let firstIntro = "Hi! I'm Nutmeg, a pretend helper made by a computer!"
    /// Round 34 (Haylee: the later-game greeting was still 8.8–9.1 s): ONE short sentence with the game question in
    /// it, no re-introduction; her live turn then only offers two of today's ideas.
    public static let short = [
        "Hi again! What should we play today?",
        "Welcome back! What should we play today?",
        "Yay, you're back! What should we play?",
        "Hooray, a new show! What should we play?",
    ]
    public static var all: [String] { [firstIntro] + short }

    /// UserDefaults keys: a boolean and the last variant's index (nothing about kids).
    public static let hasPlayedKey = "pt.hasPlayedBefore"
    public static let lastShortKey = "pt.greeting.lastShort"

    /// The line for this game: the intro on the first game ever, else a short one that isn't the last one used.
    public static func pick<G: RandomNumberGenerator>(hasPlayedBefore: Bool, lastShort: Int?, using rng: inout G) -> (line: String, shortIndex: Int?) {
        guard hasPlayedBefore else { return (firstIntro, nil) }
        var choices = Array(short.indices)
        if let lastShort, choices.count > 1 { choices.removeAll { $0 == lastShort } }
        let i = choices.randomElement(using: &rng) ?? 0
        return (short[i], i)
    }

    /// Picks with the stored flags and updates them (the flag turns on with the first greeting).
    public static func next(_ defaults: OnboardingDefaults) -> String {
        var rng = SystemRandomNumberGenerator()
        let played = defaults.bool(forKey: hasPlayedKey)
        let stored = defaults.integer(forKey: lastShortKey)
        let p = pick(hasPlayedBefore: played, lastShort: stored > 0 ? stored - 1 : nil, using: &rng)
        defaults.set(true, forKey: hasPlayedKey)
        if let i = p.shortIndex { defaults.set(i + 1, forKey: lastShortKey) }   // stored 1-based (0 = none yet)
        return p.line
    }

    /// Her live turn after the greeting clip: the game question only (no hi, no name, no introduction), with today's
    /// ideas. `ideas` = e.g. "a pizza shop, a castle, or a zoo" ("" = none). Round 42 (Haylee: she offered only two
    /// games): all three of today's ideas, word for word, on both paths.
    public static func kickOffNote(ideas: String, returning: Bool = false) -> String {
        if returning {
            // Round 34: the greeting clip already asked "What should we play?": only the two ideas, one short line.
            let example = ideas.isEmpty ? "Tell me anything!" : "Maybe \(ideas)?"
            return "(The kids just opened the app and can hear you now. You ALREADY said hi AND asked what to play, out "
                + "loud, so do NOT greet them, ask again, say your name or introduce yourself. Say ONLY this, word for word: \"\(example)\")"
        }
        let example = ideas.isEmpty ? "What should we play? Hold the red button and tell me!"
            : "What should we play? Maybe \(ideas)? Hold the red button and tell me!"
        return "(The kids just opened the app and can hear you now. You ALREADY said hi out loud, so do NOT greet them, say "
            + "your name or introduce yourself. Say ONLY this, word for word: \"\(example)\")"
    }
}
