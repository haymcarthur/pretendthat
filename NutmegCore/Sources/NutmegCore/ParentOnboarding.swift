import Foundation

// Round 33: the first-launch parent onboarding (research 2026-11-16-onboarding-research.md, Haylee's decisions in
// decisions/2026-11-15-paid-app-direction.md). Six screens, shown once, replayable from Grown-ups:
//   1 Hi, grown-up! (Nutmeg's recorded clip + the D2 gate) · 2 How it works · 3 Private by design + REQUIRED AI consent
//   (Not now → a calm "needs this" screen) · 4 Microphone pre-permission · 5 Plans (Free Preview first) · 6 Hand-off.
// Nothing about kids is stored: three device flags (onboarding done, AI consent yes/no, a count of new games started).

// MARK: - Screens and the flow

// Onboarding v2 (Haylee, 2026-11-16, design/mockups/onboarding-v2 pages 1–7): full-screen pages, NO grown-up gate.
//   1 Hi, grown-up! · 2 How it works (4 cards) · 3 What you'll need · 4 Private by design + REQUIRED AI consent
//   (Not now → the calm "needs this" page) · 5 Hold to talk (mic pre-permission) · 6 Plans · 7 Hand the iPad to your
//   child: "Start our first game" (straight onto the stage, Nutmeg talking) or "Go to the home page" (silent).

public enum OnboardingScreen: String, CaseIterable, Sendable {
    case hello, howItWorks, needs, privacy, aiDeclined, microphone, plans, handOff

    /// The dots row (aiDeclined sits on the privacy dot).
    public var dot: Int {
        switch self {
        case .hello: 0
        case .howItWorks: 1
        case .needs: 2
        case .privacy, .aiDeclined: 3
        case .microphone: 4
        case .plans: 5
        case .handOff: 6
        }
    }
    public static let dotCount = 7
    /// Nutmeg's bundled clip on this page (her real recorded voice, never TTS), played only while she's visible on it.
    /// v2: only page 1 keeps a clip. The round 33 hand-off line played on the start screen after the cover closed; now
    /// "Start our first game" opens the game, whose own greeting is the first thing she says, and "Go to the home
    /// page" is silent (Haylee: never a voice without Nutmeg on screen, never TTS).
    public var clip: String? { self == .hello ? OnboardingCopy.getAGrownUp : nil }
    public var nutmegSpeaks: Bool { clip != nil }
}

/// How the flow ended.
public enum OnboardingExit: String, Equatable, Sendable {
    /// "Start our first game": straight into a new game on the stage (Nutmeg visible and talking).
    case firstGame
    /// "Go to the home page": the start screen, with no voice at all.
    case home
    /// "Close for now" on the AI-declined page (no consent): the start screen, silent.
    case closedWithoutConsent
}

/// The onboarding state machine (v2: no gate). Back moves one page at a time on every page but the first.
/// A replay from Grown-ups walks the same pages (page 1's clip stays quiet: the grown-up asked for it).
public struct OnboardingFlow: Equatable, Sendable {
    public private(set) var screen: OnboardingScreen
    /// The grown-up's AI answer in this run (nil = not answered yet).
    public private(set) var consent: Bool?
    /// The system mic / speech prompts came back denied (the mic page then shows the Settings note and Next).
    public private(set) var micDenied = false
    /// The mic page's Continue ran (the system prompts were asked or already answered).
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
        switch screen {
        case .microphone, .plans, .handOff: self.consent = true
        case .aiDeclined: self.consent = false
        default: self.consent = consent
        }
        let pastMic = screen == .microphone || screen == .plans || screen == .handOff
        self.micAsked = micAsked && pastMic
        self.micDenied = micDenied && self.micAsked
    }

    /// The page's main forward button (Hi → How it works → What you'll need → Privacy; Mic after a denial → Plans).
    public mutating func next() {
        switch screen {
        case .hello: screen = .howItWorks
        case .howItWorks: screen = .needs
        case .needs: screen = .privacy
        case .microphone where micAsked: screen = .plans
        default: break
        }
    }

    /// "I agree, let's play": consent on, then the microphone.
    public mutating func agree() {
        guard screen == .privacy || screen == .aiDeclined else { return }
        consent = true
        screen = .microphone
    }

    /// "Not now": consent off, the calm page.
    public mutating func notNow() {
        guard screen == .privacy else { return }
        consent = false
        screen = .aiDeclined
    }

    /// The system prompts answered. Granted: on to the plans. Denied: stay with the note (Next goes on).
    public mutating func micAnswered(granted: Bool) {
        guard screen == .microphone else { return }
        micAsked = true
        micDenied = !granted
        if granted { screen = .plans }
    }

    /// "Start my Free Preview" (or Continue on a replay with the preview used up): the hand-off page.
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

    /// "Close for now" on the AI-declined page: the flow ends without consent (turn it on later in Grown-ups).
    public mutating func closeWithoutConsent() {
        guard screen == .aiDeclined, !finished else { return }
        exit = .closedWithoutConsent
    }

    /// Back works on every page except the first (nothing before it).
    public var canGoBack: Bool { screen != .hello && !finished }

    public mutating func back() {
        guard canGoBack else { return }
        switch screen {
        case .howItWorks: screen = .hello
        case .needs: screen = .howItWorks
        case .privacy: screen = .needs
        case .aiDeclined: screen = .privacy
        case .microphone: screen = .privacy
        case .plans: screen = .microphone
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
        guard let raw = defaults.string(forKey: OnboardingKeys.page), let screen = OnboardingScreen(rawValue: raw) else {
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

    // 1 (v2)
    public static let helloEyebrow = "For grown-ups · 1 minute"
    public static let helloTitle = "Hi, grown-up!"
    public static let helloBody = "This part is for grown-ups. A quick look at how PretendThat works and how we keep it private."
    public static let helloButton = "Let's get started"

    // 2 (v2: one page, four cards)
    public static let howTitle = "How it works"
    public static let steps: [(step: JourneyStep, title: String, body: String)] = [
        (.game, "Pick", "Your child picks a story and a role with Nutmeg."),
        (.getReady, "Props", "Nutmeg finds things you already have at home."),
        (.print, "Print", "Print a kit: masks, signs, tickets to color."),
        (.play, "Play", "Nutmeg guides each scene, then steps back."),
    ]

    // 3 (v2: its own page)
    public static let needTitle = "What you'll need"
    public static let needLead = "Nothing fancy. Most of it is already in your home."
    public static let needs: [(title: String, detail: String)] = [
        ("A printer", "For the kit"),
        ("Crayons", "To color it in"),
        ("Space", "Room to move"),
        ("15–25 min", "Per show"),
    ]

    // 4
    public static let privacyTitle = "Private by design"
    public static let privacyLines: [(symbol: String, text: String)] = [
        ("checkmark", "No accounts, no sign-up."),
        ("checkmark", "Nothing about your kids is saved."),
        ("checkmark", "Your child's voice turns into words right on this iPad. Audio is never sent."),
        ("checkmark", "Only the words, with names removed, go to our AI partners, OpenAI and Anthropic."),
    ]
    public static let privacyLink = "Read our privacy policy"
    public static let consentAsk = "PretendThat uses AI to talk with your child and make each game. Is that OK?"
    public static let agree = "I agree, let's play"
    public static let notNow = "Not now"

    // Not now (and New game without consent)
    public static let declinedTitle = "PretendThat needs this to work"
    public static let declinedBody = "Nutmeg uses our AI partners to listen, talk and make each game, so PretendThat can't play without them. That's OK. You can turn it on any time in Grown-ups."
    public static let declinedHow = "Grown-ups (top corner) → AI partners"
    public static let declinedBack = "Go back"
    public static let declinedClose = "Close for now"

    // 5 (v2)
    public static let micTitle = "Hold to talk"
    public static let micBody = "Nutmeg listens while your child holds the mic button. Let go, and she stops listening."
    public static let micFine = "Next, your iPad will ask to use the microphone."
    public static let micContinue = "Continue"
    public static let micDeniedTitle = "No problem. Kids can type instead."
    public static let micDeniedBody = "To turn the mic on later, open Settings → Apps → PretendThat and switch on Microphone and Speech Recognition."
    public static let micDeniedSettings = "Open Settings"
    public static let next = "Next"

    // 6 (v2 page)
    public static let plansV2Title = "Start free, upgrade anytime"
    public static let plansV2Lead = "Want more new shows later? Pick a pass whenever you like."
    public static var freeHeroTitle: String { "\(PlanCatalog.freePreviewShows) free shows,\non the house!" }
    public static let freeHeroBody = "No card. Nothing to cancel."
    public static let seasonTag = "About one a day"
    public static let replaysBullet = "Unlimited replays"
    /// The card's shows line: the Season Pass is a cap ("Up to 30 …").
    public static func cardShows(_ offer: PlanOffer) -> String {
        offer.id == PlanCatalog.seasonPass.id ? "Up to \(offer.showsText)" : offer.showsText
    }

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

    // 7 (v2)
    public static let handOffEyebrow = "All set"
    public static let handOffTitle = "Hand the iPad to your child"
    public static let handOffBody = "Nutmeg will take it from here."
    public static let startFirstGame = "Start our first game"
    public static let goHome = "Go to the home page"

    // Kid-facing cards on the start screen (no prices; the grown-up opens the gate)
    public static let kidNeedsGrownUp = "Ask a grown-up to finish setting up."
    public static let kidOutOfShows = "That's all the new shows for now! Ask a grown-up."
    public static let kidGrownUpsButton = "Grown-ups"

    // The Grown-ups row
    public static let consentRowTitle = "AI partners"
    public static func consentRowSubtitle(_ on: Bool) -> String { on ? "On: Nutmeg can talk and make games" : "Off: turn on so Nutmeg can play" }
    public static let consentScreenBody = "Nutmeg uses our AI partners, OpenAI and Anthropic, to listen, talk and make each game. Your child's voice is turned into words on this iPad and never sent. Only those words, with names removed, are sent so Nutmeg can answer. PretendThat needs this to work."
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

    /// Her live turn after the greeting clip: the game question only (no hi, no name, no introduction), with two of
    /// today's ideas. `ideas` = e.g. "a pizza shop or a castle" ("" = none).
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
            + "your name or introduce yourself. Say ONLY the game question, as short as this, in your own words: \"\(example)\")"
    }
}
