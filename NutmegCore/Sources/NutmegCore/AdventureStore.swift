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
/// There are no kids' names anywhere (roles-not-names.md): only how many kids, and the roles that number decides.
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
    /// How many kids are playing (0 = not asked yet). Decides the number of roles and badges.
    public private(set) var playerCount = 0
    /// Where the planning conversation is (conversation-structure.md); driven by the function calls.
    public private(set) var planningStep: PlanningStep = .game
    public private(set) var gameTitle: String?
    public private(set) var ideas: GameIdeas?
    public private(set) var plan: GamePlan?
    public private(set) var props: Props?
    public private(set) var kit: Kit?
    /// What Nutmeg says next (for TTS and display).
    public private(set) var nutmegLine = ""
    /// Tap choices from the last free-speech turn.
    public private(set) var choices: [Choice] = []
    public private(set) var isWorking = false
    public private(set) var lastError: String?
    public private(set) var usingFallback = false
    /// Which players' props have been checked off (prop ids).
    public var foundProps: Set<String> = []
    /// The prop the hunt is on right now (one at a time, prop-gathering-flow.md).
    public private(set) var currentPropID: String?
    /// The sequential hunt is running: Nutmeg answers only lines meant for her.
    public var huntActive: Bool { planningStep == .props && props != nil && phase == .props }
    /// Checked steps for the current scene.
    public var checkedSteps: Set<Int> = []
    /// What Nutmeg is showing around her in the voice conversation (D4): the camera zooms out while this isn't `.none`.
    /// Only prop cards are ever shown (Haylee): ideas and roles are spoken, not carded.
    public private(set) var presenting: Presentation = .none

    public enum Presentation: Equatable, Sendable { case none, props }

    @ObservationIgnored private let service: PhaseService?
    @ObservationIgnored private var failures: [String: Int] = [:]
    @ObservationIgnored private var retryAction: (() async -> Void)?
    @ObservationIgnored private var holder: RoleID?

    /// What she says for a new prop card (prop-gathering-flow.md, fix round 2): only the FIRST prop explains how to
    /// answer; later props stay short ("Next, can you find a spoon? It'll be the big stirrer!").
    public nonisolated static func nextPropOutput(id: String, item: String, becomes: String, n: Int) -> String {
        let how = n == 1
            ? "This is the FIRST prop: say what to find and what it becomes, then explain ONCE: say 'found it' when you have it, or tell me if you don't."
            : "This is prop \(n): keep it SHORT, like \"Next, can you find a \(item.lowercased())? It'll be \(becomes)!\" Do NOT repeat 'say found it' or 'tell me if you don't have it' (they already know)."
        return "Card \(id) is on screen (prop \(n)). \(how) Then wait. Found: mark_found then show_next_prop. Missing: "
            + "swap_prop (one alternate) or skip_prop, then show_next_prop. After 3 to 5 props, finish_planning."
            + (n >= 3 ? " (You have \(n); finishing after this one is fine.)" : "")
    }

    public static let oops = "Oops, my clipboard got mixed up! Let's try that again."

    public init(service: PhaseService?) { self.service = service }

    var context: AdventureContext {
        AdventureContext(gameTitle: gameTitle, plan: plan, props: props, playerCount: max(1, playerCount))
    }

    // MARK: Setup flow

    public func start() async {
        phase = .pickGame
        await run("ideas", kidSaid: nil) { [self] svc in
            ideas = try await svc.ideas(kidSaid: nil)
        } fallback: { [self] in ideas = Fallback.airplane.ideas }
        if let ideas { say(ideas.spoken) }
    }

    /// Kid asked for something specific ("I'm bored", "dinosaurs!") on the pick-game screen.
    public func askForIdeas(_ kidSaid: String) async {
        await run("ideas", kidSaid: nil) { [self] svc in
            ideas = try await svc.ideas(kidSaid: kidSaid)
        } fallback: { [self] in ideas = Fallback.airplane.ideas }
        if let ideas { say(ideas.spoken) }
    }

    public func chooseGame(_ title: String) async {
        gameTitle = title
        phase = .players
        say("Ooh, \(title)! How many friends are playing?")
    }

    public func setPlayerCount(_ n: Int) {
        playerCount = max(1, min(n, Players.max))
        plan = nil
        say(playerCount == 1 ? "Just you? Yay! Let's find your job!" : "\(playerCount) friends! Yay! Let's find your jobs!")
    }

    /// Back to the player-count question.
    public func resetPlayers() {
        playerCount = 0; plan = nil
        say("How many friends are playing?")
    }

    public func confirmPlayers() async {
        let game = gameTitle ?? "Airplane"
        await run("plan", kidSaid: nil) { [self] svc in
            plan = try await svc.plan(game: game, ctx: context)
        } fallback: { [self] in useFallbackGame() }
        if let plan { say(plan.nutmegSays) }
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

    public func badgeTapped(_ t: RoleID) {
        guard case .handoff(let i) = phase, kit?.scenes[i].owner.role == t else { return }
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
            if let turn = try? await service.help(scene: scene, ctx: context) { line = turn.nutmegSays }
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
        playerCount = 0; gameTitle = nil; planningStep = .game
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
            phase = plan != nil || playerCount > 0 ? .players : .pickGame
            presenting = .none
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
            phase = .pickGame; presenting = .none
            return "Noted (there are no idea cards; the chat shows your words). Say the ideas in a fun way and end by asking which one they want to play."
        case .setGame(let title):
            gameTitle = title; plan = nil; props = nil
            phase = .pickGame; presenting = .none; planningStep = .theme
            return "Game set: \(title). Step 2: react in one short sentence, then ask what theme or twist it should have, with 2 or 3 example themes that fit this game. Call set_theme when they pick."
        case .setTheme(let title):
            gameTitle = title; plan = nil; props = nil
            phase = .players; presenting = .none; planningStep = .players
            return "Theme set: \(title). Step 3: react in one short sentence, then ask how many kids are playing, with an example (just you, or two, or three friends?). Never ask for names."
        case .setPlayerCount(let count):
            playerCount = max(1, min(count, Players.max))
            plan = nil; props = nil
            phase = .players; presenting = .none; planningStep = .roles
            let shared = playerCount > RoleID.allCases.count ? " With more than 4 kids, repeat a role that makes sense to share." : ""
            return "\(playerCount) kid\(playerCount == 1 ? "" : "s"). Invent exactly \(playerCount) role\(playerCount == 1 ? "" : "s") for this game and call set_roles.\(shared) Never ask for names."
        case .setRoles(let drafts):
            if playerCount == 0 { playerCount = max(1, min(drafts.count, Players.max)) }
            let roles = drafts.enumerated().map { i, d in
                Role(id: RoleID.allCases[min(i, RoleID.allCases.count - 1)], roleName: d.roleName, emoji: "", symbol: "star", job: d.job)
            }
            let title = gameTitle ?? "Pretend"
            plan = Sanitizer.clean(GamePlan(gameTitle: title, gameEmoji: "", setting: title, roles: roles, nutmegSays: ""), playerCount: playerCount)
            phase = .players; presenting = .none; planningStep = .props
            let cast = plan!.roles.map { $0.count > 1 ? "\($0.count) \($0.roleName)s" : $0.roleName }.joined(separator: ", ")
            let short = drafts.count < playerCount ? " You gave \(drafts.count) roles for \(playerCount) kids, so the last role is shared." : ""
            return "Roles set: \(cast).\(short) Step 4: announce the roles with excitement (there are no role cards; kids pick their own badge after printing) and end with a quick \"Sound good?\". Do NOT name any prop in this turn: wait for their answer, then step 5: show_next_prop."
        case .showProps(let drafts):
            var used = Set<String>()
            let list: [Prop] = drafts.enumerated().compactMap { i, d in
                // Props come from the library only (checklist-pictures.md): off-list suggestions are dropped.
                guard d.inLibrary else { return nil }
                let owner = plan?.roles.first { $0.roleName.localizedCaseInsensitiveCompare(d.forRole) == .orderedSame }
                    .map { SceneOwner(rawValue: $0.id.rawValue) ?? .all } ?? .all
                var id = d.inLibrary ? d.itemID : "custom\(i)"
                if used.contains(id) { id += "-\(i)" }
                used.insert(id)
                return Prop(id: id, householdItem: PropLibrary.name(d.itemID) ?? d.itemID, becomes: d.becomes,
                            forRole: owner, safetyOK: true,
                            libraryID: d.inLibrary ? d.itemID : nil, alternates: d.alternates, skipped: false)
            }
            props = Props(nutmegSays: "", props: Array(list.prefix(Sanitizer.Limits.propsMax))); foundProps = []
            phase = .props; presenting = .props
            let ids = props!.props.map(\.id).joined(separator: ", ")
            planningStep = .props
            return "Props are on screen (ids: \(ids)). Step 5: tell them exactly what to go find and to tell you when they've found them or if they don't have something. If they lack one, use swap_prop or skip_prop. When they're ready, step 6: finish_planning."
        case .showNextProp(let d):
            guard d.inLibrary else { return "\(d.itemID) isn't on the item list. Pick a list item." }
            var p = props ?? Props(nutmegSays: "", props: [])
            if p.props.count >= Sanitizer.Limits.propsMax {
                return "That's enough props (\(p.props.count)). Call finish_planning now."
            }
            if props == nil { foundProps = [] }
            let owner = plan?.roles.first { $0.roleName.localizedCaseInsensitiveCompare(d.forRole) == .orderedSame }
                .map { SceneOwner(rawValue: $0.id.rawValue) ?? .all } ?? .all
            var id = d.itemID
            if p.props.contains(where: { $0.id == id }) { id += "-\(p.props.count)" }
            p.props.append(Prop(id: id, householdItem: PropLibrary.name(d.itemID) ?? d.itemID, becomes: d.becomes,
                                forRole: owner, safetyOK: true, libraryID: d.itemID, alternates: d.alternates, skipped: false))
            props = p; currentPropID = id
            phase = .props; presenting = .props; planningStep = .props
            let n = p.props.count
            return Self.nextPropOutput(id: id, item: PropLibrary.name(d.itemID) ?? d.itemID, becomes: d.becomes, n: n)
        case .markFound(let id):
            guard let p = props, let prop = p.props.first(where: { $0.id == id || $0.libraryID == id }) ?? p.props.first(where: { $0.id == currentPropID }) else {
                return "No prop with id \(id)."
            }
            foundProps.insert(prop.id)
            let n = p.props.count
            return "Checked off \(prop.householdItem). Cheer in a few words, then " + (n >= 3 ? "show_next_prop or finish_planning." : "show_next_prop.")
        case .swapProp(let oldID, let newID, let becomes):
            guard var p = props, let i = p.props.firstIndex(where: { $0.id == oldID || $0.libraryID == oldID }) else {
                return "No prop with id \(oldID). Ids: \(props?.props.map(\.id).joined(separator: ", ") ?? "none")."
            }
            guard PropLibrary.contains(newID) else { return "\(newID) isn't on the list. Pick another list item or skip_prop." }
            p.props[i].libraryID = newID
            p.props[i].householdItem = PropLibrary.name(newID) ?? newID
            if !becomes.isEmpty { p.props[i].becomes = becomes }
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
            presenting = .none; planningStep = .finish
            if gameTitle == nil { gameTitle = "Airplane" }
            if playerCount == 0 { playerCount = max(1, plan?.kidCount ?? 1) }
            Task { await self.makeKit() }
            return "Making the kit now. Say nothing."
        }
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
            let turn = try await service.turn(kidSaid: text, phase: phaseName, ctx: context)
            choices = turn.choices
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
        case .pickGame: if let ideas { say(ideas.spoken) }
        case .players: if let plan { say(plan.nutmegSays) }
        case .props: if let props { say(props.nutmegSays) }
        case .makingKit: phase = .kitReady; if let kit { say(kit.nutmegSays) }
        default: break
        }
    }

    private func useFallbackGame() {
        let a = Fallback.airplane(playerCount: max(1, playerCount))
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
        case "ideas": if let ideas { say(ideas.spoken) }
        case "plan": if let plan { say(plan.nutmegSays) }
        case "props": if let props { say(props.nutmegSays) }
        case "kit": if kit != nil { phase = .kitReady; say(kit!.nutmegSays) }
        default: break
        }
    }

    private func goToScene(_ i: Int) {
        guard let kit, i < kit.scenes.count else { phase = .end; say("The end! What a show! Take a bow!"); return }
        // Hand-offs are by role: "Pass the tablet to the Captain!" (kids wear the badges they picked).
        let owner = kit.scenes[i].owner.role
        if playerCount > 1, let owner, owner != holder, let role = plan?.role(for: owner) {
            phase = .handoff(sceneIndex: i)
            say("Pass the tablet to \(role.spoken)!")
        } else {
            enterScene(i)
        }
    }

    private func enterScene(_ i: Int) {
        checkedSteps = []
        phase = .scene(i)
        if let s = kit?.scenes[i] { say(s.nutmegSays) }
    }

    private func say(_ line: String) {
        nutmegLine = line
    }

    private var phaseName: String {
        switch phase {
        case .hello, .pickGame: "pick a game"
        case .players: "how many kids and their roles"
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
