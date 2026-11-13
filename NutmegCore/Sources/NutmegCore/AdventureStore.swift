import Foundation
import Observation

public enum Phase: Equatable, Sendable {
    case hello, pickGame, players, props, makingKit, kitReady
    case handoff(sceneIndex: Int), scene(Int), stepBack(Int), end
}

/// The app-side state machine (spec C4): Nutmeg leads, the LLM fills in each phase.
/// Holds real names only in memory; everything sent out goes through `tokens`.
@Observable @MainActor
public final class AdventureStore {
    public private(set) var phase: Phase = .hello
    public private(set) var players: [Player] = []
    public private(set) var directorMode = false
    public private(set) var gameTitle: String?
    public private(set) var ideas: GameIdeas?
    public private(set) var plan: GamePlan?
    public private(set) var props: Props?
    public private(set) var kit: Kit?
    /// What Nutmeg says next, always with real names (for TTS and display).
    public private(set) var nutmegLine = ""
    /// Tap choices from the last free-speech turn.
    public private(set) var choices: [Choice] = []
    public private(set) var isWorking = false
    public private(set) var lastError: String?
    public private(set) var usingFallback = false
    /// Which players' props have been checked off (prop ids).
    public var foundProps: Set<String> = []
    /// Checked steps for the current scene.
    public var checkedSteps: Set<Int> = []

    public var tokens: NameTokens { NameTokens(players: players) }

    @ObservationIgnored private let service: PhaseService?
    @ObservationIgnored private var failures: [String: Int] = [:]
    @ObservationIgnored private var retryAction: (() async -> Void)?
    @ObservationIgnored private var holder: PlayerToken?

    public static let oops = "Oops, my clipboard got mixed up! Let's try that again."

    public init(service: PhaseService?) { self.service = service }

    var context: AdventureContext {
        AdventureContext(gameTitle: gameTitle, plan: plan, props: props, playerCount: players.count, directorMode: directorMode)
    }

    // MARK: Setup flow

    public func start() async {
        phase = .pickGame
        await run("ideas", kidSaid: nil) { [self] svc in
            ideas = try await svc.ideas(kidSaid: nil)
        } fallback: { [self] in ideas = Fallback.airplane.ideas }
        if let ideas { say(ideas.nutmegSays) }
    }

    /// Kid asked for something specific ("I'm bored", "dinosaurs!") on the pick-game screen.
    public func askForIdeas(_ kidSaid: String) async {
        await run("ideas", kidSaid: nil) { [self] svc in
            ideas = try await svc.ideas(kidSaid: tokens.tokenize(kidSaid))
        } fallback: { [self] in ideas = Fallback.airplane.ideas }
        if let ideas { say(ideas.nutmegSays) }
    }

    public func chooseGame(_ title: String) async {
        gameTitle = title
        phase = .players
        say("Ooh, \(title)! How many friends are playing?")
    }

    public func setPlayerCount(_ n: Int) {
        directorMode = n >= 5
        let count = directorMode ? 4 : max(1, min(n, 4))
        players = PlayerToken.allCases.prefix(count).map {
            Player(token: $0, name: "", colorIndex: $0.index, emoji: Player.defaultEmojis[$0.index])
        }
        plan = nil
        say(directorMode ? "A big crew! One of you is the Director and holds the iPad." : "Yay! What's your name, player one?")
    }

    /// Back to the player-count question.
    public func resetPlayers() {
        players = []; directorMode = false; plan = nil
        say("How many friends are playing?")
    }

    public func setName(_ name: String, for token: PlayerToken) {
        guard let i = players.firstIndex(where: { $0.token == token }) else { return }
        players[i].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let next = players.first(where: { $0.name.isEmpty }), !directorMode {
            say("Hi \(players[i].displayName)! And what's your name, player \(next.token.index + 1)?")
        } else {
            say("Hi \(players[i].displayName)! Let's find your jobs!")
        }
    }

    public func confirmPlayers() async {
        let game = gameTitle ?? "Airplane"
        await run("plan", kidSaid: nil) { [self] svc in
            plan = try await svc.plan(game: game, ctx: context)
        } fallback: { [self] in useFallbackGame() }
        if let plan { say(plan.nutmegSays) }
    }

    /// Rotates roles between players (the "swap" button).
    public func swapRoles() {
        guard var p = plan, p.roles.count > 1 else { return }
        let tokens = p.roles.map(\.player)
        let rotated = Array(p.roles[1...] + p.roles[..<1])
        p.roles = zip(tokens, rotated).map { t, r in var r = r; r.player = t; return r }
        plan = p
        if let first = p.roles.first, let name = players.first(where: { $0.token == first.player })?.displayName {
            say("Swap! Now \(name) is the \(first.roleName)!")
        }
    }

    public func confirmRoles() async {
        phase = .props
        await run("props", kidSaid: nil) { [self] svc in
            props = try await svc.props(ctx: context)
        } fallback: { [self] in useFallbackGame() }
        foundProps = []
        if let props { say(props.nutmegSays) }
    }

    public func toggleProp(_ id: String) {
        if foundProps.contains(id) { foundProps.remove(id) } else {
            foundProps.insert(id)
            if foundProps.count == props?.props.count { say("You found everything! Hooray!") }
            else { say(["Yes!", "Great find!", "Ooh, perfect!", "Woohoo!"][foundProps.count % 4]) }
        }
    }

    public func confirmProps() async {
        await makeKit()
    }

    public func makeKit() async {
        phase = .makingKit
        say("Ooh, let me make your kit! Wait for it...")
        await run("kit", kidSaid: nil) { [self] svc in
            kit = try await svc.kit(ctx: context)
        } fallback: { [self] in useFallbackGame() }
        if kit != nil {
            phase = .kitReady
            say(kit!.nutmegSays)
        }
    }

    // MARK: Play flow

    public func beginPlay() {
        holder = nil
        goToScene(0)
    }

    public func badgeTapped(_ t: PlayerToken) {
        guard case .handoff(let i) = phase, kit?.scenes[i].owner.token == t else { return }
        holder = t
        enterScene(i)
    }

    public func toggleStep(_ index: Int) {
        if checkedSteps.contains(index) { checkedSteps.remove(index) } else { checkedSteps.insert(index) }
    }

    public func sceneDone() {
        guard case .scene(let i) = phase else { return }
        phase = .stepBack(i)
        say("Go play! Tap me when you're ready for more.")
    }

    public func nextScene() {
        guard case .stepBack(let i) = phase else { return }
        goToScene(i + 1)
    }

    /// One quick idea for right now. Never throws; offline it uses a built-in idea.
    public func helpRequested() async -> String {
        guard case .stepBack(let i) = phase, let scene = kit?.scenes[i] else { return "" }
        var line = Self.offlineHelp[i % Self.offlineHelp.count]
        if let service, !usingFallback {
            isWorking = true
            if let turn = try? await service.help(scene: scene, ctx: context) { line = tokens.untokenize(turn.nutmegSays) }
            isWorking = false
        }
        nutmegLine = line
        return line
    }

    public func playAgain() {
        checkedSteps = []
        beginPlay()
    }

    public func newGame() {
        phase = .hello
        players = []; directorMode = false; gameTitle = nil
        ideas = nil; plan = nil; props = nil; kit = nil
        choices = []; lastError = nil; usingFallback = false
        foundProps = []; checkedSteps = []; failures = [:]; retryAction = nil; holder = nil
        nutmegLine = ""
    }

    // MARK: Free speech

    /// A spoken answer on any screen: Nutmeg replies and offers tap choices.
    public func kidSaid(_ text: String) async {
        guard let service, !usingFallback else {
            say("Ooh, I love that! Tap a picture to keep going!")
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let turn = try await service.turn(kidSaid: tokens.tokenize(text), phase: phaseName, ctx: context)
            choices = turn.choices.map { Choice(id: $0.id, label: tokens.untokenize($0.label), emoji: $0.emoji) }
            say(turn.nutmegSays)
        } catch {
            say("Hmm, I didn't catch that. Tap a picture instead!")
        }
    }

    public func clearChoices() { choices = [] }

    // MARK: Errors and fallback

    public func retry() async {
        guard let action = retryAction else { return }
        await action()
    }

    /// Switch the whole show to the bundled airplane game.
    public func useFallback() {
        useFallbackGame()
        switch phase {
        case .pickGame: if let ideas { say(ideas.nutmegSays) }
        case .players: if let plan { say(plan.nutmegSays) }
        case .props: if let props { say(props.nutmegSays) }
        case .makingKit: phase = .kitReady; if let kit { say(kit.nutmegSays) }
        default: break
        }
    }

    private func useFallbackGame() {
        let a = Fallback.airplane(playerCount: players.count, directorMode: directorMode)
        usingFallback = true
        lastError = nil
        retryAction = nil
        if ideas == nil || phase == .pickGame { ideas = a.ideas }
        if phase != .pickGame {
            gameTitle = a.plan.gameTitle
            if plan == nil || plan?.gameTitle != a.plan.gameTitle { plan = a.plan }
            if phase == .props || phase == .makingKit { props = a.props }
            if phase == .makingKit { kit = a.kit }
        }
    }

    /// Runs one phase call. First failure: apologize and offer retry. Second failure in that phase: fallback.
    private func run(_ key: String, kidSaid: String?, _ body: @escaping (PhaseService) async throws -> Void,
                     fallback: @escaping () -> Void) async {
        guard let service, !usingFallback else { usingFallback = true; fallback(); return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await body(service)
            lastError = nil
            retryAction = nil
        } catch {
            failures[key, default: 0] += 1
            // A bad key or a refusal (after the server-side fallback already tried) won't fix itself on retry:
            // go straight to the bundled game.
            let notRetryable = (error as? ClaudeError).map { [.http(401), .http(403), .refusal].contains($0) } ?? false
            if notRetryable || failures[key, default: 0] >= 2 {
                usingFallback = true; lastError = nil; retryAction = nil
                fallback()
            } else {
                lastError = String(describing: error)
                say(Self.oops)
                retryAction = { [weak self] in
                    await self?.run(key, kidSaid: kidSaid, body, fallback: fallback)
                    self?.afterRetry(key)
                }
            }
        }
    }

    private func afterRetry(_ key: String) {
        switch key {
        case "ideas": if let ideas { say(ideas.nutmegSays) }
        case "plan": if let plan { say(plan.nutmegSays) }
        case "props": if let props { say(props.nutmegSays) }
        case "kit": if kit != nil { phase = .kitReady; say(kit!.nutmegSays) }
        default: break
        }
    }

    private func goToScene(_ i: Int) {
        guard let kit, i < kit.scenes.count else { phase = .end; say("The end! What a show! Take a bow!"); return }
        let owner = kit.scenes[i].owner.token
        if !directorMode, players.count > 1, let owner, owner != holder {
            phase = .handoff(sceneIndex: i)
            let role = plan?.role(for: owner)?.roleName ?? ""
            let name = players.first { $0.token == owner }?.displayName ?? ""
            say("Pass the iPad to \(role) \(name)!".replacingOccurrences(of: "  ", with: " "))
        } else {
            enterScene(i)
        }
    }

    private func enterScene(_ i: Int) {
        checkedSteps = []
        phase = .scene(i)
        if let s = kit?.scenes[i] { say(s.nutmegSays) }
    }

    private func say(_ tokenized: String) {
        nutmegLine = tokens.untokenize(tokenized)
    }

    private var phaseName: String {
        switch phase {
        case .hello, .pickGame: "pick a game"
        case .players: "who's playing"
        case .props: "props hunt"
        case .makingKit, .kitReady: "printable kit"
        case .handoff, .scene, .stepBack: "playing"
        case .end: "the end"
        }
    }

    static let offlineHelp = [
        "Ooh! Pretend that a silly surprise just happened. What do you do?",
        "Switch jobs for one minute! Who wants to try?",
        "Pretend that everything is in slow motion. Go!",
        "Make a big announcement in your best voice!"
    ]
}
