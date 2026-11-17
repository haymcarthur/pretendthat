import Foundation

// Round 33: the first-launch parent onboarding (research 2026-11-16-onboarding-research.md, Haylee's decisions in
// decisions/2026-11-15-paid-app-direction.md). Six screens, shown once, replayable from Grown-ups:
//   1 Hi, grown-up! (Nutmeg's recorded clip + the D2 gate) · 2 How it works · 3 Private by design + REQUIRED AI consent
//   (Not now → a calm "needs this" screen) · 4 Microphone pre-permission · 5 Plans (Free Preview first) · 6 Hand-off.
// Nothing about kids is stored: three device flags (onboarding done, AI consent yes/no, a count of new games started).

// MARK: - Screens and the flow

public enum OnboardingScreen: String, CaseIterable, Sendable {
    case hello, howItWorks, privacy, aiDeclined, microphone, plans, handOff

    /// The dots row (aiDeclined sits on the privacy dot).
    public var dot: Int {
        switch self {
        case .hello: 0
        case .howItWorks: 1
        case .privacy, .aiDeclined: 2
        case .microphone: 3
        case .plans: 4
        case .handOff: 5
        }
    }
    public static let dotCount = 6
    /// Nutmeg speaks only on the first screen and at the hand-off (Haylee).
    public var nutmegSpeaks: Bool { self == .hello || self == .handOff }
}

/// The onboarding state machine. The gate is passed once, on screen 1; after it, back moves one screen at a time
/// (never back to the gate). A replay from Grown-ups starts on screen 2 (the Grown-ups gate was just passed).
public struct OnboardingFlow: Equatable, Sendable {
    public private(set) var screen: OnboardingScreen
    public private(set) var gatePassed: Bool
    /// The grown-up's AI answer in this run (nil = not answered yet).
    public private(set) var consent: Bool?
    /// The system mic / speech prompts came back denied (the mic screen then shows the Settings note and Next).
    public private(set) var micDenied = false
    /// The mic screen's Continue ran (the system prompts were asked or already answered).
    public private(set) var micAsked = false
    /// The flow is over (hand-off done, or closed from the AI-declined screen).
    public private(set) var finished = false
    public let isReplay: Bool

    public init(replay: Bool = false) {
        isReplay = replay
        screen = replay ? .howItWorks : .hello
        gatePassed = replay
    }

    public mutating func passGate() {
        guard screen == .hello, !gatePassed else { return }
        gatePassed = true
        screen = .howItWorks
    }

    /// The screen's main forward button (How it works → Privacy; Mic after a denial → Plans).
    public mutating func next() {
        switch screen {
        case .howItWorks: screen = .privacy
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

    /// "Not now": consent off, the calm screen.
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

    /// "Start my Free Preview" (or Continue on a replay / with a plan): the hand-off.
    public mutating func startFreePreview() {
        guard screen == .plans else { return }
        screen = .handOff
    }

    /// "Hand it over" on the last screen.
    public mutating func handOff() {
        guard screen == .handOff else { return }
        finished = true
    }

    /// "Close for now" on the AI-declined screen: the flow ends without consent (turn it on later in Grown-ups).
    public mutating func closeWithoutConsent() {
        guard screen == .aiDeclined else { return }
        finished = true
    }

    /// Back is offered on every screen after the gate except the first one after it (and never on the gate).
    public var canGoBack: Bool {
        switch screen {
        case .hello, .howItWorks: false
        default: !finished
        }
    }

    public mutating func back() {
        guard canGoBack else { return }
        switch screen {
        case .privacy: screen = .howItWorks
        case .aiDeclined: screen = .privacy
        case .microphone: screen = .privacy
        case .plans: screen = .microphone
        case .handOff: screen = .plans
        case .hello, .howItWorks: break
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
    func removeObject(forKey: String)
}

extension UserDefaults: OnboardingDefaults {}

public enum OnboardingKeys {
    public static let done = "pt.onboarding.done"
    /// A boolean only: the grown-up agreed to the AI partners (5.1.2(i)).
    public static let aiConsent = "pt.aiConsent"
    /// An integer only: NEW games started on the Free Preview (replays never count).
    public static let freePreviewUsed = "pt.freePreview.newGames"
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
    }

    /// DEBUG: show the onboarding again on the next launch (consent cleared too).
    public func reset() {
        defaults.removeObject(forKey: OnboardingKeys.done)
        defaults.removeObject(forKey: OnboardingKeys.aiConsent)
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

    // 1
    public static let helloTitle = "Hi, grown-up!"
    public static let helloBody = "A quick minute on how PretendThat works and how we keep your child's info private."
    public static let gateTitle = "Grown-ups: please unlock"

    // 2
    public static let howTitle = "How it works"
    public static let steps: [(step: JourneyStep, title: String, body: String)] = [
        (.game, "Pick", "Your child tells Nutmeg what to play, like a pancake restaurant on the moon."),
        (.getReady, "Props", "She sends them hunting for things around the house."),
        (.print, "Print", "A custom kit of badges, signs and play money, in color or to color in."),
        (.play, "Play", "Nutmeg guides each scene, then steps back while the kids play."),
    ]
    public static let needTitle = "What you'll need"
    public static let needs: [(symbol: String, text: String)] = [
        ("printer.fill", "A printer"),
        ("scissors", "Crayons and scissors"),
        ("figure.play", "Room to move"),
        ("clock.fill", "About 15–25 minutes"),
    ]

    // 3
    public static let privacyTitle = "Private by design"
    public static let privacyLines: [(symbol: String, text: String)] = [
        ("person.crop.circle.badge.xmark", "No accounts. Nothing to sign up for."),
        ("lock.fill", "Nothing about your kids is saved."),
        ("waveform", "Your child's voice is turned into words on this iPad. The sound of their voice is never sent."),
        ("bubble.left.and.text.bubble.right.fill", "Only those words, with names removed, go to our AI partners, OpenAI and Anthropic, so Nutmeg can answer."),
        ("ipad.landscape", "Saved games stay on this iPad."),
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

    // 4
    public static let micTitle = "Nutmeg needs to hear your child"
    public static let micBody = "Kids talk to Nutmeg by holding the big mic button, like a walkie-talkie. She only listens while it's held, and their voice is turned into words right on this iPad. Next, your iPad will ask to use the microphone and speech recognition."
    public static let micContinue = "Continue"
    public static let micDeniedTitle = "No problem. Kids can type instead."
    public static let micDeniedBody = "To turn the mic on later, open Settings → Apps → PretendThat and switch on Microphone and Speech Recognition."
    public static let micDeniedSettings = "Open Settings"
    public static let next = "Next"

    // 5
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
    public static let outOfShowsTitle = "Your Free Preview is used up"
    public static let outOfShowsBody = "Your 2 free new shows are done. Pick a plan for more new shows. Saved games are still free to replay."

    // 6
    public static let handOffTitle = "You're all set!"
    public static let handOffBody = "Now hand the iPad to your child and tap New game!"
    public static let handOffNote = "You'll find saved games, plans, AI partners and this intro in Grown-ups (top corner)."
    public static let handOffButton = "Hand it over"

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
    public static let short = [
        "Hi again, friends!",
        "Welcome back to the stage!",
        "Ooh, time for a new show!",
        "Hooray, you're back!",
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
    public static func kickOffNote(ideas: String) -> String {
        let example = ideas.isEmpty ? "What should we play? Hold the red button and tell me!"
            : "What should we play? Maybe \(ideas)? Hold the red button and tell me!"
        return "(The kids just opened the app and can hear you now. You ALREADY said hi out loud, so do NOT greet them, say "
            + "your name or introduce yourself. Say ONLY the game question, as short as this, in your own words: \"\(example)\")"
    }
}
