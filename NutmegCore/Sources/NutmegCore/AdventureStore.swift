import Foundation
import Observation

public enum Phase: Equatable, Sendable {
    case hello, pickGame, players, props, makingKit, kitReady
    case handoff(sceneIndex: Int), scene(Int), stepBack(Int), end

    /// Which of the 4 journey steps (step rail) this phase belongs to.
    public var step: JourneyStep? {
        switch self {
        case .hello: nil
        case .pickGame, .players: .game
        case .props: .getReady
        case .makingKit, .kitReady: .print
        case .handoff, .scene, .stepBack, .end: .play
        }
    }
}

/// The step rail (layout-toycad-style.md): Game → Get Ready → Print → Play.
public enum JourneyStep: Int, CaseIterable, Sendable {
    case game, getReady, print, play
    public var label: String {
        switch self { case .game: "Game"; case .getReady: "Get Ready"; case .print: "Print"; case .play: "Play" }
    }
}

/// The app-side state machine (spec C4): Nutmeg leads, the LLM fills in each phase.
/// Holds real names only in memory; everything sent out goes through `tokens`.
@Observable @MainActor
public final class AdventureStore {
    public private(set) var phase: Phase = .hello {
        didSet {
            if let st = phase.step, st.rawValue > (reachedStep?.rawValue ?? -1) { reachedStep = st }
            if phase.step == .play { lastPlayPhase = phase }
        }
    }
    /// The furthest journey step reached this adventure (the step rail lets kids jump back up to here).
    public private(set) var reachedStep: JourneyStep?
    @ObservationIgnored private var lastPlayPhase: Phase?
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
    /// What Nutmeg is showing around her in the voice conversation (D4): the camera zooms out while this isn't `.none`.
    public private(set) var presenting: Presentation = .none

    public enum Presentation: Equatable, Sendable { case none, ideas, roles, props }

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
        nutmegLine = ""; presenting = .none; reachedStep = nil; lastPlayPhase = nil
    }

    // MARK: Step rail

    /// Jump to a reached step without losing anything (see props again, reprint, back to the game).
    public func goTo(_ step: JourneyStep) {
        guard let reached = reachedStep, step.rawValue <= reached.rawValue, step != phase.step else { return }
        switch step {
        case .game:
            phase = plan != nil || !players.isEmpty ? .players : .pickGame
            presenting = plan != nil ? .roles : (ideas != nil && gameTitle == nil ? .ideas : .none)
        case .getReady:
            guard props != nil else { return }
            phase = .props; presenting = .props
        case .print:
            guard kit != nil else { return }
            phase = .kitReady; presenting = .none
        case .play:
            guard kit != nil else { return }
            presenting = .none
            if let last = lastPlayPhase { phase = last } else { beginPlay() }
        }
    }

    // MARK: Voice conversation (D1, D2): the Realtime model's function calls drive the same state machine.
    // Nutmeg speaks for herself in the conversation, so these never set `nutmegLine` (no second voice).
    // Each returns a short note for the model (the function output).

    /// The voice conversation starts (Hello → planning).
    public func beginConversation() {
        newGame()
        phase = .pickGame
    }

    public func apply(_ call: PlanningCall) async -> String {
        switch call {
        case .showGameIdeas(let list):
            ideas = GameIdeas(nutmegSays: "", ideas: list)
            phase = .pickGame; presenting = .ideas
            return "The 3 ideas are on screen now. Tease one or two of them in your own words and let the kids choose."
        case .setGame(let title):
            gameTitle = title; plan = nil; props = nil
            phase = .players; presenting = .none
            return "Game set: \(title). React to it, then find out who is playing."
        case .setPlayers(let names, let count):
            directorMode = count >= 5
            let n = directorMode ? 4 : max(1, min(max(count, names.count), 4))
            players = PlayerToken.allCases.prefix(n).map {
                Player(token: $0, name: directorMode ? "" : (names.indices.contains($0.index) ? names[$0.index] : ""),
                       colorIndex: $0.index, emoji: Player.defaultEmojis[$0.index])
            }
            plan = nil; props = nil
            phase = .players; presenting = .none
            if directorMode { return "Director mode: 5 or more kids, one Director holds the iPad. When ready, call set_roles with 4 roles (player_name empty)." }
            return "Players: \(players.map(\.displayName).joined(separator: ", ")). Greet them by name, then invent their roles with set_roles."
        case .setRoles(let drafts):
            if players.isEmpty { players = [Player(token: .P1, name: "", colorIndex: 0, emoji: Player.defaultEmojis[0])] }
            var free = players.map(\.token)
            var roles: [Role] = []
            for d in drafts {
                let match = players.first { !d.playerName.isEmpty && $0.name.localizedCaseInsensitiveCompare(d.playerName) == .orderedSame && free.contains($0.token) }?.token
                guard let token = match ?? free.first else { break }
                free.removeAll { $0 == token }
                roles.append(Role(player: token, roleName: tokens.tokenize(d.roleName), emoji: "", symbol: "star", job: tokens.tokenize(d.job)))
            }
            let title = gameTitle ?? "Pretend"
            plan = Sanitizer.clean(GamePlan(gameTitle: title, gameEmoji: "", setting: title, roles: roles, nutmegSays: ""), playerCount: players.count)
            phase = .players; presenting = .roles
            let missing = free.isEmpty ? "" : " Still missing a role for: \(free.compactMap { t in players.first { $0.token == t }?.displayName }.joined(separator: ", "))."
            return "Roles are on screen.\(missing) Tell each kid their part with excitement and check they like it. Wait for their answer before show_props."
        case .showProps(let drafts):
            var used = Set<String>()
            let list: [Prop] = drafts.enumerated().compactMap { i, d in
                if !d.inLibrary && PropLibrary.looksUnsafe(d.itemID) { return nil }
                let owner = players.first { $0.name.localizedCaseInsensitiveCompare(d.forPlayer) == .orderedSame }
                    .map { SceneOwner(rawValue: $0.token.rawValue) ?? .all } ?? .all
                var id = d.inLibrary ? d.itemID : "custom\(i)"
                if used.contains(id) { id += "-\(i)" }
                used.insert(id)
                return Prop(id: id, householdItem: PropLibrary.name(d.itemID) ?? d.itemID, becomes: tokens.tokenize(d.becomes),
                            emoji: "", forRole: owner, safetyOK: true,
                            libraryID: d.inLibrary ? d.itemID : nil, alternates: d.alternates, skipped: false)
            }
            props = Props(nutmegSays: "", props: Array(list.prefix(Sanitizer.Limits.propsMax))); foundProps = []
            phase = .props; presenting = .props
            let ids = props!.props.map(\.id).joined(separator: ", ")
            return "Props are on screen (ids: \(ids)). Send them on a fun hunt. If they lack one, use swap_prop or skip_prop."
        case .swapProp(let oldID, let newID, let becomes):
            guard var p = props, let i = p.props.firstIndex(where: { $0.id == oldID || $0.libraryID == oldID }) else {
                return "No prop with id \(oldID). Ids: \(props?.props.map(\.id).joined(separator: ", ") ?? "none")."
            }
            guard PropLibrary.contains(newID) else { return "\(newID) isn't on the list. Pick another list item or skip_prop." }
            p.props[i].libraryID = newID
            p.props[i].householdItem = PropLibrary.name(newID) ?? newID
            if !becomes.isEmpty { p.props[i].becomes = tokens.tokenize(becomes) }
            p.props[i].skipped = false
            p.props[i].swapped = true
            p.props[i].alternates = p.props[i].alternates?.filter { $0 != newID }
            props = p; presenting = .props
            return "Swapped (the card still uses id \(p.props[i].id))."
        case .skipProp(let id):
            guard var p = props, let i = p.props.firstIndex(where: { $0.id == id || $0.libraryID == id }) else {
                return "No prop with id \(id)."
            }
            p.props[i].skipped = true
            props = p; presenting = .props
            return "Marked as pretend. Keep going cheerfully."
        case .finishPlanning:
            presenting = .none
            if gameTitle == nil { gameTitle = "Airplane" }
            if players.isEmpty { setPlayerCountQuietly(1) }
            Task { await self.makeKit() }
            return "Making the kit now. Say nothing."
        }
    }

    private func setPlayerCountQuietly(_ n: Int) {
        players = PlayerToken.allCases.prefix(n).map { Player(token: $0, name: "", colorIndex: $0.index, emoji: Player.defaultEmojis[$0.index]) }
    }

    #if DEBUG
    /// Screenshots only: hold a phase (e.g. .makingKit for the coloring loader).
    public func debugSetPhase(_ p: Phase) { phase = p }
    #endif

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
