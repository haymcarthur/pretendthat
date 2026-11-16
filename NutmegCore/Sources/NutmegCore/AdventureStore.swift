import Foundation
import Observation

public enum Phase: Equatable, Sendable {
    case hello, pickGame, players, props, makingKit, kitReady
    case handoff(sceneIndex: Int), scene(Int), end

    /// Which of the 4 journey steps (step rail) this phase belongs to.
    public var step: JourneyStep? {
        switch self {
        case .hello: nil
        case .pickGame, .players: .game
        case .props: .getReady
        case .makingKit, .kitReady: .print
        case .handoff, .scene, .end: .play
        }
    }
}

/// The step rail (layout-toycad-style.md): Pick → Props → Paper → Play (round 23, Haylee: "Game" → "Pick",
/// "Get Ready" → "Props", "Print" → "Paper"; the button that really prints still says Print).
public enum JourneyStep: Int, CaseIterable, Sendable {
    case game, getReady, print, play
    public var label: String {
        switch self { case .game: "Pick"; case .getReady: "Props"; case .print: "Paper"; case .play: "Play" }
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
    /// Round 20 (Haylee): full color, or pages to color in. Asked after the confirm step's yes; nil = not asked yet.
    /// The one source of truth for every kit image prompt.
    public private(set) var printStyle: PrintStyle?
    /// What the pages are drawn as (the coloring pages until the kids choose).
    public var currentPrintStyle: PrintStyle { printStyle ?? .colorIn }
    /// Round 24 (Haylee): "Do you have a printer?", asked after the confirm step's yes; nil = not asked yet.
    public private(set) var hasPrinter: Bool?
    /// No printer: no kit images; the Paper step is "Draw it!" (a hand-drawn kit, one piece at a time).
    public var drawMode: Bool { hasPrinter == false }
    /// The draw-your-own guide (no printer), once the kit is made.
    public private(set) var drawGuide: DrawGuide?
    /// The piece on the Draw it! card.
    public private(set) var drawIndex = 0
    /// What she reads for the current piece (and the pill's Repeat says again).
    public var drawLine: String? { drawGuide.map { DrawIt.line($0, drawIndex, players: playerCount) }.flatMap { $0.isEmpty ? nil : $0 } }
    /// The Draw it! card is up (no printer, the kit is made, the Paper step).
    public var drawing: Bool {
        drawMode && phase == .kitReady && drawGuide != nil && (replayGameID == nil || replayPrintables == nil || replayDrawChosen)
    }
    public private(set) var ideas: GameIdeas?
    public private(set) var plan: GamePlan?
    public private(set) var props: Props?
    /// Round C1: the kit as written, for all 6 ranked roles (every role has its own step in every scene).
    public private(set) var fullKit: Kit?
    /// The kit as the N playing kids see it: only their steps, hand-offs rotating through them, no line naming a role
    /// that isn't playing. A pure function of `fullKit`, the roles and the count, so a count change never needs an AI call.
    public var kit: Kit? { fullKit.map { PlayCast.kit($0, roles: plan?.roles ?? [], players: playerCount) } }
    /// Round C1: the roles playing now (the first N of the 6 ranked roles).
    public var playingRoles: [Role] { RoleCast.playing(plan?.roles ?? [], kids: playerCount) }
    /// What Nutmeg says next (for TTS and display).
    public private(set) var nutmegLine = ""
    /// Tap choices from the last free-speech turn.
    public private(set) var choices: [Choice] = []
    public private(set) var isWorking = false
    public private(set) var lastError: String?
    public private(set) var usingFallback = false
    /// Which players' props have been checked off (prop ids).
    public var foundProps: Set<String> = []
    /// The prop card being hunted is settled (found or skipped): the next show_next_prop is due (round 7).
    public var currentPropDone: Bool {
        guard let id = currentPropID, let p = props?.props.first(where: { $0.id == id }) else { return false }
        return foundProps.contains(id) || p.skipped == true
    }
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

    /// Today's theme ideas (round 7), picked by the app when the game is set and given to Nutmeg in the set_game result.
    public var themeIdeas: [Suggestion] = []

    @ObservationIgnored private let service: PhaseService?
    @ObservationIgnored private var failures: [String: Int] = [:]
    @ObservationIgnored private var retryAction: (() async -> Void)?
    @ObservationIgnored private var holder: RoleID?

    /// The one line when the whole kit has landed (print step): about the pages, never "go play" (Haylee).
    /// Round 16 (Haylee): it names both buttons, so the kid knows to tap Let's play! after printing.
    public nonisolated static let kitReadyLine = HandOffLines.printReady

    /// Round 20 (Haylee): the roles line ends with this, instead of "Pick who's who!" (kids pick badges after printing).
    public nonisolated static let huntTransition = "Now it's time to hunt for props!"

    /// The FIRST prop line (round 7 choreography): asked for separately, after the roles finished playing and the card
    /// appeared with her point.
    public nonisolated static func firstPropLine(item: String, becomes: String, reason: String? = nil) -> String {
        "(Silent coaching, don't mention it.) The \(item.lowercased()) card is on screen now and you're pointing at it. You already said "
            + "\"\(huntTransition)\": start RIGHT AWAY with the first prop line (no second lead-in like \"let's start the hunt\"), like \"First, can you find a \(item.lowercased())? It'll be \(becomes)!\""
            + (reason.map { " plus why it works, in a few words (\"\($0)\")," } ?? ",") + " then explain "
            + "ONCE: say 'found it' when you have it, or tell me if you don't. Don't repeat the roles, no check-in, no narration. "
            + "If you already named this prop, say only the 'found it' explanation."
    }

    /// What she says for a new prop card (prop-gathering-flow.md, fix round 2): only the FIRST prop explains how to
    /// answer; later props stay short ("Next, can you find a spoon? It'll be the big stirrer!").
    public nonisolated static func nextPropOutput(id: String, item: String, becomes: String, n: Int, reason: String? = nil) -> String {
        let how = n == 1
            ? "This is the FIRST prop. Its card stays hidden for now. Speak ONLY the roles now, as a set of parts the kids share, then the hunt transition, word for word: \"\(Self.huntTransition)\" (\"We need a Captain, a Navigator, and an Island Explorer! \(Self.huntTransition)\"; for one kid: \"You'll be the Captain! \(Self.huntTransition)\"). Never \"You're the X, the Y, and the Z\" (that sounds like one kid gets every role), never \"Pick who's who\", no \"All set!\". Don't name this prop or describe the card yet, and don't ask anything: when your roles line finishes, the card appears, you point at it, and you'll be asked for the prop line."
            : n % 3 == 0
            // Round 13: "Pretend that" on about 1 prop in 3 (props 3 and 6), decided by the app so it really happens.
            ? "This is prop \(n): keep it SHORT and use the words \"pretend that\" this time, like \"Can you find a \(item.lowercased())? Let's pretend that it's \(becomes)!\" Do NOT repeat 'say found it' or 'tell me if you don't have it' (they already know)."
            : "This is prop \(n): keep it SHORT, like \"Next, can you find a \(item.lowercased())? It'll be \(becomes)!\" Do NOT repeat 'say found it' or 'tell me if you don't have it' (they already know). Don't say \"pretend that\" for this one."
        // Round 24: she says why the item works, briefly, inside the same line (never a second sentence about it).
        let why = reason.map { " Inside that same line, say briefly why it works: \"\($0)\"" } ?? ""
        return "Card \(id) is ready (prop \(n)). \(how)\(n == 1 ? "" : why) Then wait. Found: mark_found then show_next_prop. Missing: "
            + "swap_prop (one alternate) or skip_prop, then show_next_prop. After 3 to 5 props, finish_planning."
            + (n >= 3 ? " (You have \(n); finishing after this one is fine.)" : "")
    }

    public static let oops = "Oops, my clipboard got mixed up! Let's try that again."

    /// Round 19: the line when a late theme fix remakes the kit.
    public nonisolated static func remakeLine(_ title: String) -> String {
        "Ooh, \(ConfirmStep.phrase(title))! Let me fix your kit to match. Wait for it..."
    }

    public init(service: PhaseService?) { self.service = service }

    /// Round 19 (Haylee: a corrected theme reached the roles and props but the kit used the old one): every request is
    /// built from THIS, at call time: the current game title and count, with the plan's title kept in step with it.
    public var context: AdventureContext {
        var p = plan
        if let t = gameTitle, var q = p, q.gameTitle != t {
            if q.setting == q.gameTitle { q.setting = t }   // the voice path's setting is the title itself
            q.gameTitle = t; p = q
        }
        return AdventureContext(gameTitle: gameTitle ?? plan?.gameTitle, plan: p, props: props, playerCount: max(1, playerCount))
    }

    /// The ONE game title every later step uses (kit pages, page art prompts, the print job, the recap).
    public var currentTitle: String { gameTitle ?? plan?.gameTitle ?? "Pretend" }

    /// Round 19: the recap line for the confirm step, from the current title and count.
    public var recapLine: String { ConfirmStep.recap(title: currentTitle, playerCount: max(1, playerCount)) }

    /// Bumped when a correction remakes the kit (the app resets the page art).
    public private(set) var kitRemakes = 0
    /// Round 20: bumped when a color change at the print step redraws the pages (same kit text, new art).
    public private(set) var kitRestyles = 0
    @ObservationIgnored private var kitGeneration = 0

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
        if await steerIfUnsafe(kidSaid) { return }
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
        countNewGame()   // round D1: the tap path's confirm (the roles are the first paid call)
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

    /// Round 15: a line the "making your kit" line starts with (the reassurance after a skipped prop, when the hunt
    /// ends right there). Only used within `leadInWindow` of being set.
    public var kitLeadIn: (line: String, at: Date)?
    public nonisolated static let leadInWindow: TimeInterval = 20
    /// Round 15: the one overall congratulations after an early Done!, said as the start of the next line (hand-off,
    /// next scene or the finale), so the tap gets ONE spoken reply.
    public var sceneLeadIn: String?

    public func makeKit(remakeFor title: String? = nil) async {
        phase = .makingKit
        kitGeneration += 1
        guidePending = false; playQueued = false
        let gen = kitGeneration
        if let title {
            kitLeadIn = nil
            say(Self.remakeLine(title))
        } else {
            let lead = kitLeadIn.flatMap { Date().timeIntervalSince($0.at) < Self.leadInWindow ? $0.line + " " : nil } ?? ""
            kitLeadIn = nil
            say(lead + "Ooh, let me make your kit! Wait for it...")
        }
        // Round 24: no printer → the draw-your-own guide, and never any kit image.
        if drawMode { await makeDrawKit(gen: gen, prefetch: title == nil); return }
        // Round 20: the pages were written during the hunt; only the play guide (and skipped props' cut-outs) is left.
        let pages = title == nil ? await draftForKit() : nil
        // Round 21: text still being moderated never reaches Claude (or the kit made from it).
        if let outboundGate, !(await outboundGate()) { return }
        guard gen == kitGeneration else { return }
        // Guide prefetch: the play guide was written during the hunt too; the Paper step never waits for it.
        if let pages, guideGeneration == draftGeneration, guideTask != nil || guideKit != nil {
            await finishWithPrefetchedGuide(pages: pages, gen: gen)
            return
        }
        await run("kit", kidSaid: nil) { [self] svc in
            // The context is read now (the current title, count, roles and props), and a newer remake wins.
            let made: Kit
            if let pages { made = try await svc.kitScenes(ctx: context, items: KitDraft.finalItems(pages, props: props)) }
            else { made = try await svc.kit(ctx: context) }
            if gen == kitGeneration { fullKit = made }
        } fallback: { [self] in if gen == kitGeneration { useFallbackGame() } }
        guard gen == kitGeneration else { return }
        if kit != nil {
            // Round 7: the ready line waits for the whole kit (pages and art), so the app says it at kitFinal
            // (`kitReadyLine`), and it's about printing, never "go play" (that's only the play step).
            phase = .kitReady
        }
    }

    // MARK: Play flow

    public func beginPlay() {
        // Guide prefetch: the pages are out but the play guide is still on its way: Play starts the moment it lands.
        if guidePending { playQueued = true; return }
        holder = nil
        goToScene(0)
    }

    public func badgeTapped(_ t: RoleID) {
        guard case .handoff(let i) = phase, kit?.scenes[i].owner.role == t else { return }
        holder = t
        enterScene(i)
    }

    /// Tap a step to check it; tap a checked step again to uncheck it (round 10).
    public func toggleStep(_ index: Int) {
        guard !autoChecking else { return }
        if checkedSteps.contains(index) { checkedSteps.remove(index) } else { checkedSteps.insert(index) }
    }

    /// The checklist as it was when "Done!" was tapped (before the auto-check), so the hand-off card's
    /// "← Back to the checklist" restores it exactly. Kept until the next role confirms (or the next scene starts).
    public struct DoneSnapshot: Equatable, Sendable { public let scene: Int; public let checked: Set<Int> }
    public private(set) var doneSnapshot: DoneSnapshot?
    /// "Done!" is quickly checking the remaining steps (the rows animate; taps are ignored meanwhile).
    public private(set) var autoChecking = false
    /// Auto-check timing: one step every `autoCheckStep`, then `autoCheckHold` before the hand-off card.
    public var autoCheckStep: Duration = .milliseconds(140)
    public var autoCheckHold: Duration = .milliseconds(350)

    /// Round 10 (Haylee): no "Go play!" screen. "Done!" is always available: steps not checked yet are checked
    /// quickly for the kid, then it moves straight on to the next "Pass the iPad to the …" card (or the next scene
    /// for the same role, or the finale after the last scene). The checklist from before the auto-check is kept.
    public func sceneDone() async {
        guard case .scene(let i) = phase, !autoChecking, let scene = kit?.scenes[i] else { return }
        doneSnapshot = DoneSnapshot(scene: i, checked: checkedSteps)
        let remaining = scene.steps.indices.filter { !checkedSteps.contains($0) }
        if !remaining.isEmpty {
            autoChecking = true
            for step in remaining {
                checkedSteps.insert(step)
                try? await Task.sleep(for: autoCheckStep)
            }
            try? await Task.sleep(for: autoCheckHold)
            autoChecking = false
            guard case .scene(i) = phase else { sceneLeadIn = nil; return }   // left the scene meanwhile (step rail, leave)
        }
        goToScene(i + 1)
        if case .scene = phase { doneSnapshot = nil }   // same role continues: no hand-off card to go back from
    }

    /// "← Back to the checklist" is offered (hand-off card or finale right after a Done!).
    public var canGoBackToChecklist: Bool {
        guard let snap = doneSnapshot else { return false }
        switch phase {
        case .handoff(let i): return i == snap.scene + 1
        case .end: return snap.scene == (kit?.scenes.count ?? 0) - 1
        default: return false
        }
    }

    /// Back to the previous scene's checklist, checkmarks restored exactly as they were before "Done!".
    public func backToChecklist() {
        guard canGoBackToChecklist, let snap = doneSnapshot else { return }
        doneSnapshot = nil
        checkedSteps = snap.checked
        phase = .scene(snap.scene)
        say(HandOffLines.backToChecklist)   // round 16: the checklist is back, so she says what to do
    }

    /// One quick idea for right now. Never throws; offline it uses a built-in idea.
    public func helpRequested() async -> String {
        guard case .scene(let i) = phase, let scene = kit?.scenes[i] else { return "" }
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
        checkedSteps = []; doneSnapshot = nil
        beginPlay()
    }

    public func newGame() {
        phase = .hello
        playerCount = 0; gameTitle = nil; printStyle = nil; hasPrinter = nil; planningStep = .game; themeIdeas = []
        drawGuide = nil; drawIndex = 0
        ideas = nil; plan = nil; props = nil; fullKit = nil
        choices = []; lastError = nil; usingFallback = false
        foundProps = []; checkedSteps = []; doneSnapshot = nil; failures = [:]; retryAction = nil; holder = nil
        nutmegLine = ""; presenting = .none; reachedStep = nil; lastPlayPhase = nil; steerIdeas = SteerIdeas()
        kitRemakes = 0; kitRestyles = 0; propMisfits = 0
        cancelDraft()
        cancelDrawDraft()
        guidePending = false; playQueued = false; guideCalls = 0
        // Round D1: a new adventure (or a replay that loads over this) starts clean.
        gameID = UUID(); countedNewGame = false; savedAs = nil
        replayGameID = nil; replaySaved = []; replayBase = []; replayPrintables = nil; replayPrinted = nil; replayDrawChosen = false
    }

    // MARK: Saved games and replays (round D1, Haylee)

    /// This adventure's id (a saved game keeps it; a replay uses the saved game's).
    public private(set) var gameID = UUID()
    /// Round D1 hook for section E: new games vs replays (no-op for now).
    @ObservationIgnored public var ledger: GameLedger = NoOpLedger()
    @ObservationIgnored private var countedNewGame = false
    private func countNewGame() {
        guard !countedNewGame, !isReplay else { return }
        countedNewGame = true
        ledger.newGameStarted(id: gameID)
    }
    /// The first play was saved at The End (its id): The End offers "Play it again" (a replay of it).
    public private(set) var savedAs: UUID?
    /// A first play can be saved at The End (round D1: never mid-game; a replay is already saved).
    public var canSave: Bool { phase == .end && !isReplay && savedAs == nil && fullKit?.scenes.isEmpty == false && plan != nil }
    public func markSaved(_ id: UUID) { savedAs = id }

    /// The saved game being replayed (nil on a first play).
    public private(set) var replayGameID: UUID?
    public var isReplay: Bool { replayGameID != nil }
    /// The saved props and play guide (the replay's prop answers are applied to these, never to each other).
    @ObservationIgnored private var replaySaved: [SavedProp] = []
    @ObservationIgnored private var replayBase: [Scene] = []
    /// A no-printer game that saved printables: Paper offers the print choices (and Draw it instead).
    public private(set) var replayPrintables: [KitItem]?
    /// The print choice made on this Paper visit (Let's play! shows after it).
    public private(set) var replayPrinted: PaperChoice?
    /// "Draw it instead" on a no-printer game with saved printables.
    public private(set) var replayDrawChosen = false

    /// Loads a saved game for a replay: Pick is current (only "how many are playing?"), nothing is generated.
    public func loadReplay(_ g: SavedGame) {
        newGame()
        replayGameID = g.id; gameID = g.id
        gameTitle = g.title
        plan = GamePlan(gameTitle: g.title, setting: g.title, roles: g.roles, nutmegSays: "")
        replaySaved = g.props
        let list = g.props.map(\.replayProp)
        props = Props(nutmegSays: "", props: list)
        foundProps = Set(list.map(\.id))   // every card starts as Got it (Haylee)
        hasPrinter = g.hasPrinter; printStyle = g.printStyle; drawGuide = g.drawGuide; drawIndex = 0
        replayBase = g.kit.scenes
        fullKit = Kit(nutmegSays: g.kit.nutmegSays, items: g.kit.items,
                      scenes: ReplayProps.apply(g.kit.scenes, saved: g.props, current: list, items: g.kit.items))
        replayPrintables = g.printablesMade ? g.printables : nil
        planningStep = .finish
        phase = .players
        say(ReplayLines.greeting(title: g.title))
        ledger.replayStarted(id: g.id)
    }

    /// Pick: how many are playing (1–6). The playing roles, badges and checklists follow, with no AI call.
    public func replayPick(_ n: Int) {
        guard isReplay else { return }
        playerCount = max(1, min(n, Players.max))
        resetPlayProgress()
        say(PlayCast.countChangeLine(roles: plan?.roles ?? [], players: playerCount))
    }

    /// Pick → Props: the whole saved list at once.
    public func replayPickDone() {
        guard isReplay, playerCount > 0 else { return }
        phase = .props
        say(ReplayLines.stillHave(props?.props ?? []))
    }

    /// Props: Got it (have) or Don't have it (a pretend swap: its steps say "the pretend …").
    public func replayProp(_ id: String, have: Bool) {
        guard isReplay, var p = props, let i = p.props.firstIndex(where: { $0.id == id }) else { return }
        guard p.props[i].isSkipped == have else { return }
        p.props[i].skipped = !have
        props = p
        if have { foundProps.insert(id) } else { foundProps.remove(id) }
        replayRefreshGuide()
        if !have { say(ReplayLines.pretend(p.props[i].becomes)) }
    }

    /// The missing prop's saved alternate, in one tap ("Use a towel instead?").
    public func replayAlternate(for id: String) -> String? {
        guard isReplay, let p = props?.props.first(where: { $0.id == id }), p.isSkipped else { return nil }
        return p.alternates?.first(where: PropLibrary.contains)
    }
    public func replayUseAlternate(_ id: String) {
        guard let alt = replayAlternate(for: id), var p = props, let i = p.props.firstIndex(where: { $0.id == id }) else { return }
        p.props[i].libraryID = alt
        p.props[i].householdItem = PropLibrary.name(alt) ?? alt
        p.props[i].reason = PropFit.reason(itemID: alt, becomes: p.props[i].becomes)
        p.props[i].skipped = false; p.props[i].swapped = true
        p.props[i].alternates = p.props[i].alternates?.filter { $0 != alt }
        props = p
        foundProps.insert(id)
        replayRefreshGuide()
        say(ReplayLines.useInstead(p.props[i].householdItem))
    }

    private func replayRefreshGuide() {
        guard var k = fullKit else { return }
        k.scenes = ReplayProps.apply(replayBase, saved: replaySaved, current: props?.props ?? [], items: k.items)
        fullKit = k
        resetPlayProgress()
    }

    /// Props → Paper: the print choices, or Draw it! again from the saved guide (no printer).
    public func replayPropsDone() {
        guard isReplay, phase == .props else { return }
        replayPrinted = nil; replayDrawChosen = false; drawIndex = 0
        phase = .kitReady
        if drawing, let line = drawLine { say(line) } else { say(ReplayLines.paperQuestion) }
    }

    /// Paper: print everything or just the badges (the app opens the print screen; Let's play! shows next), or skip
    /// straight to Play.
    public func replayPaper(_ choice: PaperChoice) {
        guard isReplay, phase == .kitReady else { return }
        if choice == .skip { beginPlay(); return }
        replayPrinted = choice
        say(ReplayLines.printed)
    }

    /// No printer, but printables were saved: draw the kit instead.
    public func replayDrawInstead() {
        guard isReplay, phase == .kitReady, drawMode, drawGuide != nil else { return }
        replayDrawChosen = true; drawIndex = 0
        if let line = drawLine { say(line) }
    }

    // MARK: Kit made during the hunt (round 20, Haylee)

    /// The kit pages written during the hunt (nil until they land). The app starts their art as soon as they do.
    public private(set) var draftItems: [KitItem]?
    /// Bumped whenever the pages are (re)started; results from an older start are dropped.
    public private(set) var draftGeneration = 0
    /// Live timing (DEBUG logs only): when the pages started and landed, when the kit call started.
    public private(set) var draftStartedAt: Date?
    public private(set) var draftReadyAt: Date?
    @ObservationIgnored private var draftInputs: KitInputs?
    @ObservationIgnored private var draftTask: Task<[KitItem]?, Never>?

    /// Round 21: awaited before anything goes out to Claude (the kit pages and the play guide): false = text in the plan
    /// was flagged by moderation after it ran ahead (`SafetyGate`), so the call is dropped.
    @ObservationIgnored public var outboundGate: (@MainActor () async -> Bool)?

    /// What the pages should be written for right now (nil: not yet, or no Claude).
    var wantedDraft: KitInputs? {
        guard service != nil, !usingFallback, planningStep == .props, hasPrinter != false else { return nil }
        return KitDraft.inputs(title: currentTitle, playerCount: playerCount, plan: plan, printStyle: printStyle, step: .props)
    }

    /// Starts, restarts or cancels the pages so they always match the current plan. Once the hunt is over (the kit is
    /// being made from them) they're left alone.
    public func refreshDraft() {
        guard planningStep != .finish, phase != .makingKit, phase != .kitReady else { return }
        refreshDrawDraft()
        let want = wantedDraft
        guard want != draftInputs else { return }
        cancelDraft()
        guard let want, let service else { return }
        draftGeneration += 1
        let gen = draftGeneration, ctx = context
        draftInputs = want; draftStartedAt = Date()
        let gate = outboundGate
        draftTask = Task { [weak self] in
            // Round 21: wait for any moderation still running on text in this plan (a flag restores the store and
            // restarts the draft).
            if let gate, !(await gate()) { return nil }
            guard !Task.isCancelled else { return nil }
            let items = try? await RetryOnce.run { try await service.kitPages(ctx: ctx) }
            guard let self, gen == self.draftGeneration, !Task.isCancelled else { return nil }
            if let items { self.draftItems = items; self.draftReadyAt = Date(); self.startGuide(items: items, gen: gen) }
            return items
        }
    }

    private func cancelDraft() {
        cancelGuide()
        draftTask?.cancel(); draftTask = nil
        if draftInputs != nil || draftItems != nil { draftGeneration += 1 }
        draftInputs = nil; draftItems = nil; draftStartedAt = nil; draftReadyAt = nil
    }

    /// The pages for the kit being made now: the hunt's pages when they were written for exactly this plan (waiting for
    /// them if they're still on the way), else nil (the whole kit is written in one call, as before round 20).
    private func draftForKit() async -> [KitItem]? {
        guard let d = draftInputs,
              d == KitDraft.inputs(title: currentTitle, playerCount: playerCount, plan: plan, printStyle: printStyle, step: .props)
        else { return nil }
        if let draftItems { return draftItems }
        let gen = draftGeneration
        let items = await draftTask?.value
        return gen == draftGeneration ? items : nil
    }

    // MARK: No printer: the draw-your-own guide (round 24, Haylee)

    /// The draw guide written during the hunt (no printer). No images, ever.
    @ObservationIgnored private var drawDraftInputs: KitInputs?
    @ObservationIgnored private var drawDraftTask: Task<DrawGuide?, Never>?
    @ObservationIgnored private var drawDraftGeneration = 0

    var wantedDrawDraft: KitInputs? {
        guard service != nil, !usingFallback, planningStep == .props, drawMode, let plan, !plan.roles.isEmpty else { return nil }
        return KitInputs(title: currentTitle, playerCount: RoleCast.count, roles: plan.roles.map(\.roleName))   // round C1: for 6
    }

    private func refreshDrawDraft() {
        let want = wantedDrawDraft
        guard want != drawDraftInputs else { return }
        cancelDrawDraft()
        guard let want, let service else { return }
        drawDraftGeneration += 1
        let gen = drawDraftGeneration, ctx = context, gate = outboundGate
        drawDraftInputs = want
        drawDraftTask = Task { [weak self] in
            if let gate, !(await gate()) { return nil }
            guard !Task.isCancelled else { return nil }
            let g = try? await RetryOnce.run { try await service.drawGuide(ctx: ctx) }
            guard let self, gen == self.drawDraftGeneration, !Task.isCancelled else { return nil }
            return g
        }
    }

    private func cancelDrawDraft() {
        drawDraftTask?.cancel(); drawDraftTask = nil; drawDraftInputs = nil; drawDraftGeneration += 1
    }

    /// The hunt's draw guide when it was written for exactly this plan (waiting for it), else nil.
    private func drawDraftForKit() async -> DrawGuide? {
        guard let d = drawDraftInputs, let plan,
              d == KitInputs(title: currentTitle, playerCount: RoleCast.count, roles: plan.roles.map(\.roleName))
        else { return nil }
        let gen = drawDraftGeneration
        let g = await drawDraftTask?.value
        return gen == drawDraftGeneration ? g : nil
    }

    /// No printer: the guide (from the hunt, or written now), then the play guide for the drawn pieces. No images.
    private func makeDrawKit(gen: Int, prefetch: Bool) async {
        let early = prefetch ? await drawDraftForKit() : nil
        if let outboundGate, !(await outboundGate()) { return }
        guard gen == kitGeneration else { return }
        let guide = early
        await run("kit", kidSaid: nil) { [self] svc in
            let ctx = context
            let g: DrawGuide
            if let guide { g = guide } else { g = (try? await svc.drawGuide(ctx: ctx)) ?? DrawIt.fallback(playerCount: ctx.playerCount) }
            let made = try await svc.kitScenes(ctx: context, items: DrawIt.kitItems(g), drawn: true)
            guard gen == kitGeneration else { return }
            drawGuide = g; drawIndex = 0; fullKit = made
        } fallback: { [self] in
            guard gen == kitGeneration else { return }
            let g = DrawIt.fallback(playerCount: max(1, playerCount))
            useFallbackGame()
            drawGuide = g; drawIndex = 0
            if var k = fullKit { k.items = DrawIt.kitItems(g); fullKit = k }
        }
        guard gen == kitGeneration else { return }
        if kit != nil { phase = .kitReady }
    }

    /// Next on the Draw it! card (or voice "next"): the next piece; after the last piece, on to Play.
    /// Returns the line to say (nil: play started, the app says the play line).
    @discardableResult
    public func drawNext() -> String? {
        guard drawing, let g = drawGuide else { return nil }
        if drawIndex + 1 < g.pieces.count { drawIndex += 1; return drawLine }
        beginPlay()
        return nil
    }

    /// Round 24: "Save printables for later" (no printer): the normal kit pages (coloring pages), with the play guide
    /// already written. Nil without Claude or when it fails (the button says so).
    public func makePrintables() async -> Kit? {
        guard let service, !usingFallback else { return nil }
        if let outboundGate, !(await outboundGate()) { return nil }
        guard let pages = try? await RetryOnce.run({ [ctx = context] in try await service.kitPages(ctx: ctx) }) else { return nil }
        return Kit(nutmegSays: "", items: KitDraft.finalItems(pages, props: props), scenes: [])
    }

    // MARK: Step rail

    /// Jump to a reached step without losing anything (see props again, reprint, back to the game).
    /// Round 23: true when `goTo` would move there (a reached step that isn't the current one, with its content ready).
    public func canGoTo(_ step: JourneyStep) -> Bool {
        guard let reached = reachedStep, step.rawValue <= reached.rawValue, step != phase.step else { return false }
        switch step {
        case .game: return true
        case .getReady: return props != nil
        case .print, .play: return kit != nil
        }
    }

    @discardableResult
    public func goTo(_ step: JourneyStep) -> Bool {
        guard canGoTo(step) else { return false }
        switch step {
        case .game:
            phase = plan != nil || playerCount > 0 ? .players : .pickGame
            presenting = .none
        case .getReady:
            phase = .props; presenting = .props
        case .print:
            phase = .kitReady; presenting = .none
            drawIndex = 0   // round 24: Draw it! starts again from the first piece
            replayPrinted = nil   // round D1: the replay's Paper choices again
        case .play:
            presenting = .none
            if let last = lastPlayPhase { phase = last } else { beginPlay() }
        }
        return true
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
        let output = await applyCall(call)
        refreshDraft()   // round 20: the kit pages follow the current color, roles, title and count
        refreshWeave()   // guide prefetch: each new prop is worked into the play guide as its card comes up
        return output
    }

    private func applyCall(_ call: PlanningCall) async -> String {
        // Round D1: a saved game never changes on a replay (no game, theme, roles, props, printer or color calls).
        if isReplay {
            switch call {
            case .showGameIdeas, .setGame, .setTheme, .setRoles, .showProps, .showNextProp, .markFound, .swapProp, .skipProp,
                 .finishPlanning, .confirmPlan, .setPrintStyle, .setPrinter:
                return ReplayLines.savedGameOutput
            case .startPlay where phase == .props:
                return "Not yet: they're checking the props. Say ONE short line: tap All set when they're ready."
            default: break
            }
        }
        switch call {
        case .showGameIdeas(let list):
            ideas = GameIdeas(nutmegSays: "", ideas: list)
            phase = .pickGame; presenting = .none
            return "Noted (there are no idea cards; the chat shows your words). Say the ideas in a fun way and end by asking which one they want to play."
        case .setGame(let title):
            if let late = lateCorrection(title: title, what: "game") { return late }
            if planningStep >= .players {
                // A fix while the count is asked or the plan is being confirmed (or after the roles): stay on track.
                return correct(title: title, what: "Game fixed: \(title).")
            }
            gameTitle = title; plan = nil; props = nil
            phase = .pickGame; presenting = .none; planningStep = .theme
            let ideas = themeIdeas.isEmpty ? "with 2 or 3 example themes that fit this game"
                : "suggesting ONLY today's theme ideas, and make it sound open (\"Any twist you like! Maybe \(Suggestions.spoken(themeIdeas))?\"; say them so they fit this game; no other examples)"
            return "Game set: \(title). Step 2: react in one short sentence, then ask what theme or twist it should have, \(ideas). If the kids say their own theme, take it. Call set_theme when they pick."
        case .setTheme(let title):
            if let late = lateCorrection(title: title, what: "theme") { return late }
            if planningStep >= .players { return correct(title: title, what: "Theme fixed: \(title).") }
            gameTitle = title; plan = nil; props = nil
            phase = .players; presenting = .none; planningStep = .players
            return "Theme set: \(title). Step 3: react in one short sentence, then ask an OPEN question like \"How many friends are playing today?\" (never a list of numbers like 'just you, or two, or three?': any number works). Never ask for names."
        case .setPlayerCount(let count):
            // Round 23 (Haylee): at most 6. More → she says so and asks again; nothing changes.
            if count > Players.max, phase.step == nil || phase.step == .game || phase.step == .getReady {
                return Players.overCapOutput(said: count)
            }
            let n = max(1, min(count, Players.max))
            // Round C1: once the roles exist (6 ranked roles; the kit, if made, is for 6 too) a count change keeps
            // everything and makes no AI call: the playing roles, badges and checklists follow the new count.
            if let plan, !plan.roles.isEmpty, planningStep >= .props || fullKit != nil {
                return changeCount(to: n)
            }
            let redo = planningStep >= .roles && (plan != nil || props != nil)
            playerCount = n
            // Round 19: the recap comes next (step 3b); the roles wait for a yes.
            clearPlanForRedo()
            let what = "\(n) kid\(n == 1 ? "" : "s")."
            return redo ? ConfirmStep.redoOutput(what: what, recap: recapLine)
                : ConfirmStep.recapAgainOutput(what: what, recap: recapLine)
        case .confirmPlan:
            guard planningStep == .confirm else {
                return planningStep < .confirm ? "Not yet: finish the current step first. Answer in ONE short line and ask its question."
                    : "Already confirmed. Carry on with the current step."
            }
            countNewGame()   // round D1: a new game counts at the confirm-step yes (design §7)
            phase = .players; presenting = .none
            // Round 24: the printer question comes next, unless the kids already answered it.
            guard let printer = hasPrinter else { planningStep = .printer; return PrinterChoice.askOutput(playerCount: max(1, playerCount)) }
            // Round 20: the color question comes next, unless the kids already chose (a correction re-opened the recap).
            if printer, printStyle == nil { planningStep = .color; return ColorChoice.askOutput(playerCount: max(1, playerCount)) }
            planningStep = .roles
            return ConfirmStep.confirmedOutput(playerCount: max(1, playerCount))
        case .setPrintStyle(let style):
            return setPrintStyle(style)
        case .setPrinter(let has):
            return setPrinter(has)
        case .drawStep(let next):
            guard drawing else {
                return "There's no drawing step right now. Answer in ONE short line."
            }
            if !next { return "Say exactly this and nothing else: \"\(drawLine ?? "")\"" }
            if let line = drawNext() { return "Next piece on screen. Say exactly this and nothing else: \"\(line)\"" }
            return "Play started. The app runs the scenes now. Say nothing."
        case .setRoles(let drafts):
            if planningStep == .confirm {
                return "Not yet: the kids haven't said yes to your recap. Say exactly: \"\(recapLine)\" and wait (yes → confirm_plan)."
            }
            if planningStep == .printer {
                return "Not yet: ask the printer question first. Say exactly: \"\(PrinterChoice.question)\" and wait (their answer → set_printer)."
            }
            if planningStep == .color {
                return "Not yet: ask the color question first. Say exactly: \"\(ColorChoice.question)\" and wait (their answer → set_print_style)."
            }
            // Round C1: the model gives 6 ranked roles (any fewer, or repeats, are filled from generic extras); the
            // first N play. A model that skipped the count and gave one role per kid sets it.
            if playerCount == 0 { playerCount = drafts.count < RoleCast.count ? max(1, drafts.count) : 1 }
            let roles = drafts.prefix(RoleCast.count + 2).map { d in
                Role(id: .R1, roleName: d.roleName, emoji: "", symbol: "star", job: d.job)
            }
            let title = gameTitle ?? "Pretend"
            plan = Sanitizer.clean(GamePlan(gameTitle: title, gameEmoji: "", setting: title, roles: roles, nutmegSays: ""), playerCount: playerCount)
            phase = .players; presenting = .none; planningStep = .props
            return Self.rolesSetOutput(plan!.roles, players: playerCount)
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
        case .showNextProp(let raw):
            guard raw.inLibrary else { return "\(raw.itemID) isn't on the item list. Pick a list item." }
            var p = props ?? Props(nutmegSays: "", props: [])
            if p.props.count >= Sanitizer.Limits.propsMax {
                return "That's enough props (\(p.props.count)). Call finish_planning now."
            }
            // Round 24: the item must make sense as what it becomes (one retry, then a curated sensible pair).
            let used = Set(p.props.compactMap(\.libraryID))
            guard let fit = fittingDraft(raw, used: used) else {
                return PropFit.retryOutput(itemID: raw.itemID, becomes: raw.becomes, preferring: raw.alternates)
            }
            let d = fit.0, fellBack = fit.1
            if props == nil { foundProps = [] }
            let owner = plan?.roles.first { $0.roleName.localizedCaseInsensitiveCompare(d.forRole) == .orderedSame }
                .map { SceneOwner(rawValue: $0.id.rawValue) ?? .all } ?? .all
            var id = d.itemID
            if p.props.contains(where: { $0.id == id }) { id += "-\(p.props.count)" }
            p.props.append(Prop(id: id, householdItem: PropLibrary.name(d.itemID) ?? d.itemID, becomes: d.becomes,
                                forRole: owner, safetyOK: true, libraryID: d.itemID, alternates: d.alternates, skipped: false,
                                reason: d.reason))
            props = p; currentPropID = id
            phase = .props; presenting = .props; planningStep = .props
            let n = p.props.count
            let swapNote = fellBack ? "(That pairing didn't fit, so the app picked a \((PropLibrary.name(d.itemID) ?? d.itemID).lowercased()) as \(d.becomes) instead: use THIS item and use.) " : ""
            return swapNote + Self.nextPropOutput(id: id, item: PropLibrary.name(d.itemID) ?? d.itemID, becomes: d.becomes, n: n, reason: d.reason)
        case .markFound(let id):
            guard let p = props, let prop = p.props.first(where: { $0.id == id || $0.libraryID == id }) ?? p.props.first(where: { $0.id == currentPropID }) else {
                return "No prop with id \(id)."
            }
            foundProps.insert(prop.id)
            let n = p.props.count
            return "Checked off \(prop.householdItem). Don't speak yet: call " + (n >= 3 ? "show_next_prop (or finish_planning if that's enough props)" : "show_next_prop")
                + " FIRST, then cheer in a few words and ask about the new prop in the same turn. Never narrate (\"let me grab the next prop\")."
        case .swapProp(let oldID, let newID, let becomes):
            guard var p = props, let i = p.props.firstIndex(where: { $0.id == oldID || $0.libraryID == oldID }) else {
                return "No prop with id \(oldID). Ids: \(props?.props.map(\.id).joined(separator: ", ") ?? "none")."
            }
            guard PropLibrary.contains(newID) else { return "\(newID) isn't on the list. Pick another list item or skip_prop." }
            // Round 24: the new item must make sense as the use too (one retry, then the best fitting item).
            let use = becomes.isEmpty ? p.props[i].becomes : becomes
            var newID = newID
            if !PropFit.fits(itemID: newID, becomes: use) {
                if propMisfits == 0 { propMisfits = 1; return PropFit.retryOutput(itemID: newID, becomes: use) }
                let used = Set(p.props.compactMap(\.libraryID))
                newID = PropFit.fallback(becomes: use, preferring: p.props[i].alternates ?? [], avoiding: used).itemID
            }
            propMisfits = 0
            p.props[i].reason = PropFit.reason(itemID: newID, becomes: use)
            p.props[i].libraryID = newID
            p.props[i].householdItem = PropLibrary.name(newID) ?? newID
            if !becomes.isEmpty { p.props[i].becomes = becomes }
            p.props[i].skipped = false
            p.props[i].swapped = true
            p.props[i].alternates = p.props[i].alternates?.filter { $0 != newID }
            props = p; presenting = .props
            return "Swapped (the card still uses id \(p.props[i].id)) to a \(p.props[i].householdItem.lowercased()). Say what the new item becomes and why it works, briefly (\"\(p.props[i].reason ?? "")\"), and ask if they can find it."
        case .skipProp(let id):
            guard var p = props, let i = p.props.firstIndex(where: { $0.id == id || $0.libraryID == id }) else {
                return "No prop with id \(id)."
            }
            p.props[i].skipped = true
            props = p; presenting = .props
            return "Marked as pretend. Don't speak yet: call show_next_prop (or finish_planning) FIRST, then say you'll pretend that one and ask about the new prop in the same turn."
        case .finishPlanning:
            presenting = .none; planningStep = .finish
            if gameTitle == nil { gameTitle = "Airplane" }
            if playerCount == 0 { playerCount = 1 }
            Task { await self.makeKit() }
            return "Making the kit now. Say nothing."
        case .justTalk:
            // Round 23: after the hunt just_talk is the plain-answer path of the tool-first turn.
            switch phase {
            case .kitReady:
                return "Nothing changes. Answer in ONE short line (no narration). If it fits, remind them to tap Print or Let's play (call that button exactly \"Let's play!\", never Start). No \"go play\" yet."
            case .handoff:
                return "Nothing changes. Answer in ONE short line and remind them to tap the I'm the ___! button."
            case .scene, .end:
                return "Nothing changes. Answer in ONE short, fun line that helps the current scene (no narration)."
            default:
                return "Nothing changes. Reply kindly in ONE short line (no narration), then ask the current step's question again."
            }
        case .startPlay:
            guard phase == .kitReady else { return "Not yet: the kit isn't ready. Say only \"Almost ready!\"" }
            beginPlay()
            // Guide prefetch: the checklists are still being finished; play starts by itself the moment they land.
            if playQueued { return Self.playQueuedOutput }
            return "Play started. The app runs the scenes now. Say nothing."
        case .confirmHandoff:
            guard case .handoff(let i) = phase, let owner = kit?.scenes[i].owner.role else {
                return "There's no hand-off right now. Answer in ONE short line."
            }
            badgeTapped(owner)
            return "Hand-off confirmed: the scene starts and the app says its line. Say nothing."
        case .printKit:
            if drawMode, phase == .kitReady {
                return "There's no printer: they're drawing their kit. Say ONE short line, and that they can tap \(DrawIt.saveLabel) to print it somewhere else."
            }
            // Round 23: "print it again" from the play step (or The End) goes back to the Print step.
            if phase.step == .play, goTo(.print) { return BackNav.output(moved: true, to: .print, current: .print, drawing: drawMode) }
            return "The print screen is open. Say one short line like \"Here's the print screen!\""
        case .goToStep(let step):
            let from = phase.step
            let moved = goTo(step)
            return BackNav.output(moved: moved, to: step, current: from, drawing: drawMode)
        }
    }

    // MARK: Ranked roles (round C1)

    /// The set_roles result: all 6 ranked roles, and the N playing ones she announces (and ONLY those).
    public nonisolated static func rolesSetOutput(_ roles: [Role], players: Int) -> String {
        let playing = RoleCast.playing(roles, kids: players)
        let ranked = roles.enumerated().map { "\($0.offset + 1). \($0.element.roleName)" }.joined(separator: ", ")
        let who = playing.count == 1
            ? "1 kid is playing: announce ONLY the \(playing[0].roleName) (\"You'll be the \(playing[0].roleName)! \(huntTransition)\")."
            : "\(playing.count) kids are playing: announce ONLY \(playing.map(\.roleName).joined(separator: ", ")) (\"We need \(PlayCast.crewList(playing))! \(huntTransition)\"), never the others."
        return "Roles set (ranked): \(ranked). \(who) Step 4: announce them with excitement (there are no role cards; kids pick their own badge after printing). Now, WITHOUT speaking yet and without waiting for the kids, call show_next_prop for the FIRST prop. Then, in ONE turn, announce the roles and end with \"\(huntTransition)\" (the card and your prop line follow). Never ask \"Sound good?\", \"Okay?\" or \"Ready?\": there is nothing to approve."
    }

    /// A count change once the roles exist: nothing is remade (no AI call). Play starts over from the first scene the
    /// next time, so the hand-offs rotate through the new crew. During play she points to Pick on the step rail.
    private func changeCount(to n: Int) -> String {
        switch phase {
        case .handoff, .scene, .end:
            return "Nothing changed yet. Say in ONE short, kind line that they can tap Pick on the steps at the top to change how many friends are playing."
        default: break
        }
        guard n != playerCount else { return "Already \(n). Carry on with the current step in ONE short line." }
        playerCount = n
        resetPlayProgress()
        let line = PlayCast.countChangeLine(roles: plan?.roles ?? [], players: n)
        return "Now \(n) playing. Nothing is remade: the roles, props and kit stay, and the badges and checklists follow the new count. Say exactly this and nothing else: \"\(line)\" Then carry on with the current step."
    }

    /// Round C1: the play progress is for the old crew (who holds the iPad, the checkmarks): Play starts over.
    private func resetPlayProgress() {
        holder = nil; lastPlayPhase = nil; checkedSteps = []; doneSnapshot = nil
    }

    /// The tap path: the count after the roles were made (no AI call; the roles and kit stay).
    public func changePlayerCount(_ n: Int) {
        let n = max(1, min(n, Players.max))
        playerCount = n
        resetPlayProgress()
        say(PlayCast.countChangeLine(roles: plan?.roles ?? [], players: n))
    }

    // MARK: Props that make sense (round 24)

    /// Misfit pairings in a row (show_next_prop / swap_prop): the first gets a retry, the second the app's fallback.
    @ObservationIgnored private var propMisfits = 0

    /// The draft to show: as given when the item fits the use (its reason kept if kid-friendly), nil on a first misfit
    /// (the model retries), or a curated sensible pair on a second misfit. Alternates are kept only when they fit too.
    private func fittingDraft(_ raw: PlanningCall.PropDraft, used: Set<String>) -> (PlanningCall.PropDraft, Bool)? {
        var d = raw, fellBack = false
        if PropFit.fits(itemID: d.itemID, becomes: d.becomes) {
            d.reason = PropFit.keptReason(d.reason, itemID: d.itemID, becomes: d.becomes)
        } else {
            guard propMisfits > 0 else { propMisfits += 1; return nil }
            let f = PropFit.fallback(becomes: d.becomes, preferring: d.alternates, avoiding: used)
            d.itemID = f.itemID; d.becomes = f.becomes; d.reason = f.reason; fellBack = true
        }
        propMisfits = 0
        var alts = d.alternates.filter { $0 != d.itemID && PropFit.fits(itemID: $0, becomes: d.becomes) }
        if alts.isEmpty { alts = Array(PropFit.candidates(for: d.becomes, avoiding: used.union([d.itemID])).prefix(1)) }
        d.alternates = Array(alts.prefix(2))
        return (d, fellBack)
    }

    // MARK: Color choice (round 20)

    /// The kids chose full color or coloring pages (voice: set_print_style; or a button). On the color step the roles
    /// start; earlier it's just kept; later it's a correction (the app redraws the pages; play keeps what was printed).
    private func setPrintStyle(_ style: PrintStyle) -> String {
        switch phase {
        case .handoff, .scene, .end:
            return "The kit is printed and the game is on. Say in ONE short, kind line that this adventure is all set, and "
                + "they can tap New game for a different one."
        case .makingKit, .kitReady:
            guard style != printStyle else { return "Already \(style.spoken). Answer in ONE short line." }
            printStyle = style
            kitRestyles += 1
            say(ColorChoice.restyleLine(style))
            return "The pages are now \(style.spoken): the app redraws them to match and says so. Say nothing."
        default: break
        }
        let was = printStyle
        printStyle = style
        switch planningStep {
        case .color:
            planningStep = .roles
            return ColorChoice.chosenOutput(style, playerCount: max(1, playerCount))
        case .game, .theme, .players, .confirm, .printer:
            return "Noted: the printables will be \(style.spoken). Carry on with the current step (don't ask about color again)."
        case .roles, .props, .finish:
            return was == style ? "Already \(style.spoken). Carry on with the current step in ONE short line."
                : "Got it: the printables will be \(style.spoken) (the app changes them). Say so in a few words, then carry on with the current step."
        }
    }

    // MARK: Printer (round 24)

    /// The kids said whether they have a printer (voice: set_printer; or a button). On the printer step: yes → the color
    /// question (or the roles if the color is known), no → the roles (no color question, no images). Earlier it's
    /// kept; during the hunt it switches which kit is written; after the hunt it stays (Save printables covers it).
    private func setPrinter(_ has: Bool) -> String {
        switch phase {
        case .makingKit, .kitReady, .handoff, .scene, .end:
            if has == hasPrinter { return "Already noted. Answer in ONE short line." }
            return has ? "The kit is already planned for drawing. Say in ONE short line that they can tap \(DrawIt.saveLabel) to get the printable pages."
                : "The kit is already made for printing. Say in ONE short, kind line that they can still play with it."
        default: break
        }
        let was = hasPrinter
        hasPrinter = has
        switch planningStep {
        case .printer, .color:
            if has, printStyle == nil { planningStep = .color } else { planningStep = .roles }
            return PrinterChoice.chosenOutput(has, colorKnown: printStyle != nil, playerCount: max(1, playerCount))
        case .game, .theme, .players, .confirm:
            return "Noted: \(has ? "they have a printer" : "no printer, they'll draw the kit"). Carry on with the current step (don't ask about the printer again)."
        case .roles, .props, .finish:
            if has, printStyle == nil { printStyle = .colorIn }
            return was == has ? "Already noted. Carry on with the current step in ONE short line."
                : "Got it: \(has ? "they'll print the kit" : "no printer, they'll draw the kit by hand") (the app changes it). Say so in a few words, then carry on with the current step."
        }
    }

    // MARK: Corrections (round 19)

    /// The roles and props were made for the old plan (or the count/theme just changed): clear them and wait on the recap.
    private func clearPlanForRedo() {
        plan = nil; props = nil; foundProps = []; currentPropID = nil
        phase = .players; presenting = .none; planningStep = .confirm
    }

    /// A game or theme fix from the player-count step on. Before the count is known it stays on the count question;
    /// with a count it (re)opens the confirm step; roles and props made for the old plan are cleared and redone.
    private func correct(title: String, what: String) -> String {
        gameTitle = title
        if planningStep == .players && playerCount == 0 {
            phase = .players; presenting = .none
            return "\(what) Now ask how many friends are playing (an OPEN question, never a list of numbers), unless they "
                + "already told you: then call set_player_count."
        }
        let redo = planningStep >= .roles && (plan != nil || props != nil)
        if playerCount == 0 { playerCount = 1 }
        clearPlanForRedo()
        return redo ? ConfirmStep.redoOutput(what: what, recap: recapLine) : ConfirmStep.recapAgainOutput(what: what, recap: recapLine)
    }

    /// A game or theme fix after planning: while the kit is being made or waits to print, the kit is remade for the
    /// new title (the app says so out loud); once play has started the adventure stays as printed.
    private func lateCorrection(title: String, what: String) -> String? {
        switch phase {
        case .makingKit, .kitReady:
            gameTitle = title
            fullKit = nil; drawGuide = nil; drawIndex = 0; kitRemakes += 1; phase = .makingKit
            presenting = .none; planningStep = .finish
            Task { await self.makeKit(remakeFor: title) }
            return "The \(what) is now \(title): the app is remaking the kit to match and says so. Say nothing."
        case .handoff, .scene, .end:
            return "The kit is printed and the game is on. Say in ONE short, kind line that this adventure is all set, and "
                + "they can tap New game for a different one."
        default:
            return nil
        }
    }

    #if DEBUG
    /// Screenshots only: hold a phase (e.g. .makingKit for the coloring loader).
    public func debugSetPhase(_ p: Phase) { phase = p }
    /// Screenshots (round 14): replace one scene of the kit (e.g. a long Sunset-style checklist).
    public func debugReplaceScene(_ i: Int, with scene: Scene) { if fullKit?.scenes.indices.contains(i) == true { fullKit?.scenes[i] = scene } }
    #endif

    // MARK: Free speech

    /// A spoken answer on any screen: Nutmeg replies and offers tap choices.
    public func kidSaid(_ text: String) async {
        if await steerIfUnsafe(text) { return }
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

    /// Round 19: the app's steer line when there's no live voice session (spoken through the usual line path).
    public func steerLine(_ line: String) { say(line) }

    /// Round 21: the planning state before a tool call that ran ahead of its remote moderation (`SafetyGate`). A late
    /// flag puts it back, so flagged text never stays in the game (and never reaches the kit or images).
    public struct SafeSnapshot: Equatable {
        let phase: Phase, reachedStep: JourneyStep?, playerCount: Int, planningStep: PlanningStep
        let gameTitle: String?, printStyle: PrintStyle?, hasPrinter: Bool?, plan: GamePlan?, props: Props?
        let foundProps: Set<String>, currentPropID: String?, presenting: Presentation, themeIdeas: [Suggestion]
    }
    public func safeSnapshot() -> SafeSnapshot {
        SafeSnapshot(phase: phase, reachedStep: reachedStep, playerCount: playerCount, planningStep: planningStep,
                     gameTitle: gameTitle, printStyle: printStyle, hasPrinter: hasPrinter, plan: plan, props: props, foundProps: foundProps,
                     currentPropID: currentPropID, presenting: presenting, themeIdeas: themeIdeas)
    }
    public func restore(_ s: SafeSnapshot) {
        phase = s.phase; reachedStep = s.reachedStep; playerCount = s.playerCount; planningStep = s.planningStep
        gameTitle = s.gameTitle; printStyle = s.printStyle; hasPrinter = s.hasPrinter; plan = s.plan; props = s.props; foundProps = s.foundProps
        currentPropID = s.currentPropID; presenting = s.presenting; themeIdeas = s.themeIdeas
    }

    /// Round 19: kid text is checked before it's used or sent to Claude (local filter, then moderation; fails safe to
    /// local). Unsafe: it's dropped and Nutmeg cheerfully steers to new ideas (or says to get a grown-up).
    public func steerIfUnsafe(_ text: String) async -> Bool {
        let verdict = await (service?.checkKidText(text)) ?? Sanitizer.kidSafety(text)
        guard let verdict else { return false }
        say(SafetySteer.line(for: verdict, ideas: nextSteerIdeas()))
        return true
    }

    /// Round 19: ideas already offered this session never come back in a redirect (in memory only).
    @ObservationIgnored public var steerIdeas = SteerIdeas()
    /// A fresh set of 3 never-offered game ideas (today's ideas, theme ideas, earlier redirects and the idea list so far
    /// are all excluded).
    public func nextSteerIdeas(alsoOffered: [Suggestion] = []) -> [Suggestion] {
        steerIdeas.markOffered(alsoOffered + themeIdeas)
        let mentioned = (ideas?.ideas.map(\.title) ?? []) + [gameTitle].compactMap { $0 }
        steerIdeas.markOffered(Suggestions.games.filter { g in
            let core = g.text.split(separator: " ").drop { ["a", "an", "the"].contains($0.lowercased()) }.joined(separator: " ")
            return mentioned.contains { $0.localizedCaseInsensitiveContains(core) }
        })
        return steerIdeas.next()
    }

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
            if phase == .makingKit { fullKit = a.kit }
        }
    }

    // MARK: Play guide written during the hunt (guide prefetch, 2026-11-15, Haylee: "fix it first")

    /// The start_play result while the guide is still being finished (the app starts play when it lands).
    public nonisolated static let playQueuedOutput = "Play starts by itself in a moment (the app is finishing the scene checklists and says a line). Say nothing."
    /// The pages are out (Paper) but the play guide is still being finished: Play waits for it (`playQueued`).
    public private(set) var guidePending = false
    /// Let's play! was tapped (or said) while `guidePending`: play starts as soon as the guide lands.
    public private(set) var playQueued = false
    /// Live timing (DEBUG logs only): the guide's start, when it was written, when the final guide was in the kit.
    public private(set) var guideStartedAt: Date?
    public private(set) var guideWrittenAt: Date?
    public private(set) var guideFinalAt: Date?
    /// Guide calls made this adventure (tests: no regeneration on a skip).
    public private(set) var guideCalls = 0
    @ObservationIgnored private var guideGeneration = -1
    @ObservationIgnored private var guideTask: Task<Kit?, Never>?
    /// The guide as written (no props), then with the props woven in as their cards came up.
    @ObservationIgnored private(set) var guideKit: Kit?
    @ObservationIgnored private(set) var guideUses: [PropUse] = []
    /// The guide exactly as written (it passed the safety check): used if the props' final wording ever fails it.
    @ObservationIgnored private var guideBase: [Scene] = []
    @ObservationIgnored private var weaveAttempted: Set<String> = []
    @ObservationIgnored private var weaveTask: Task<Void, Never>?

    /// The pages for this plan just landed: write the play guide for them now, while the kids hunt.
    private func startGuide(items: [KitItem], gen: Int) {
        guard let service, !drawMode else { return }
        cancelGuide()
        guideGeneration = gen; guideStartedAt = Date(); guideCalls += 1
        let ctx = context, gate = outboundGate
        guideTask = Task { [weak self] in
            if let gate, !(await gate()) { return nil }
            guard !Task.isCancelled else { return nil }
            let kit = try? await RetryOnce.run { try await service.earlyGuide(ctx: ctx, items: items) }
            guard let self, gen == self.guideGeneration, !Task.isCancelled else { return nil }
            if let kit { self.guideKit = kit; self.guideBase = kit.scenes; self.guideWrittenAt = Date(); self.refreshWeave() }
            return kit
        }
    }

    private func cancelGuide() {
        guideTask?.cancel(); guideTask = nil; weaveTask?.cancel(); weaveTask = nil
        guideGeneration = -1; guideKit = nil; guideBase = []; guideUses = []; weaveAttempted = []
        guideStartedAt = nil; guideWrittenAt = nil; guideFinalAt = nil
    }

    /// Props on the cards that aren't in the guide yet are woven in, one small call at a time (a skip or swap later
    /// is applied at the hunt's end with no call).
    func refreshWeave() {
        guard let service, weaveTask == nil, let guide = guideKit, guideGeneration == draftGeneration else { return }
        let todo = GuideWeave.pending(props, attempted: weaveAttempted)
        guard !todo.isEmpty else { return }
        weaveAttempted.formUnion(todo.map(\.id))
        let gen = guideGeneration, taken = guideUses, ctx = context, gate = outboundGate
        weaveTask = Task { [weak self] in
            var answer: PropWeave?
            var allowed = true
            if let gate { allowed = await gate() }
            if allowed {
                answer = try? await service.weaveProps(scenes: guide.scenes, props: todo, taken: taken, ctx: ctx)
            }
            guard let self, gen == self.guideGeneration, !Task.isCancelled else { return }
            if let answer, var k = self.guideKit {
                let woven = GuideWeave.apply(answer, to: k.scenes, props: todo, taken: self.guideUses)
                k.scenes = woven.scenes; self.guideKit = k; self.guideUses += woven.uses
            }
            self.weaveTask = nil
            self.refreshWeave()
        }
    }

    /// The hunt is over and the guide was started during it: the pages go out now (Paper never waits for the guide);
    /// the guide is finished (any last prop woven in, skips and swaps applied, the safety check run) and Play starts
    /// as soon as it's in, if the kids already tapped Let's play!.
    private func finishWithPrefetchedGuide(pages: [KitItem], gen: Int) async {
        let items = KitDraft.finalItems(pages, props: props)
        if let scenes = await finalGuideIfReady(items: items), gen == kitGeneration {
            fullKit = Kit(nutmegSays: guideKit?.nutmegSays ?? "", items: items, scenes: scenes)
            guideFinalAt = Date(); phase = .kitReady
            return
        }
        guard gen == kitGeneration else { return }
        fullKit = Kit(nutmegSays: "", items: items, scenes: [])
        guidePending = true
        phase = .kitReady
        // Wait for the guide (and any weave still running), one more weave for a prop that came up at the very end.
        var scenes: [Scene]?
        if guideKit == nil { _ = await guideTask?.value }
        if gen == kitGeneration, guideKit != nil {
            for _ in 0..<3 {
                if let w = weaveTask { await w.value }
                refreshWeave()
                if weaveTask == nil { break }
            }
            scenes = await finalGuideIfReady(items: items, waitForWeave: false)
        }
        guard gen == kitGeneration else { return }
        if scenes == nil, let service, !usingFallback {
            // The early guide failed: write it now with the props, as before the prefetch.
            guideCalls += 1
            scenes = (try? await RetryOnce.run { [ctx = context] in try await service.kitScenes(ctx: ctx, items: items) })?.scenes
            guard gen == kitGeneration else { return }
        }
        let final = scenes ?? Fallback.airplane(playerCount: max(1, playerCount)).kit.scenes
        fullKit = Kit(nutmegSays: guideKit?.nutmegSays ?? "", items: items, scenes: final)
        guideFinalAt = Date()
        guidePending = false
        if playQueued, phase == .kitReady { playQueued = false; beginPlay() }
    }

    /// The finished guide (no call: skips and swaps applied, the safety check run), or nil while it isn't written yet or
    /// a weave is still running. A final text that fails the safety check falls back to the guide as written (no props).
    private func finalGuideIfReady(items: [KitItem], waitForWeave: Bool = true) async -> [Scene]? {
        guard let guide = guideKit, guideGeneration == draftGeneration else { return nil }
        if waitForWeave, weaveTask != nil || !GuideWeave.pending(props, attempted: weaveAttempted).isEmpty { return nil }
        let scenes = GuideWeave.finalize(guide.scenes, uses: guideUses, props: props, items: items)
        if let service, !(await service.guideIsSafe(scenes)) {
            #if DEBUG
            NSLog("[CLAUDE] final play guide failed the kid-safety check: props left out")
            #endif
            return guideBase
        }
        return scenes
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
        guard let kit, i < kit.scenes.count else { phase = .end; sayInPlay(HandOffLines.end(canGoBack: canGoBackToChecklist, replay: isReplay)); return }
        // Hand-offs are by role (round 8: "iPad", and she says which button to tap; the card's button reads "I'm the Captain!").
        let owner = kit.scenes[i].owner.role
        if playerCount > 1, let owner, owner != holder, let role = plan?.role(for: owner) {
            phase = .handoff(sceneIndex: i)
            sayInPlay(HandOffLines.handoff(spokenRole: role.spoken))
        } else {
            enterScene(i)
        }
    }

    private func enterScene(_ i: Int) {
        checkedSteps = []; doneSnapshot = nil
        phase = .scene(i)
        if let s = kit?.scenes[i] { sayInPlay(HandOffLines.checklist(sceneLine: s.nutmegSays, firstScene: i == 0, firstStep: s.steps.first?.text)) }
    }

    private func say(_ line: String) {
        nutmegLine = line
    }

    /// A play-step line, starting with the pending congratulations if there is one.
    private func sayInPlay(_ line: String) {
        let lead = sceneLeadIn.map { $0 + " " } ?? ""
        sceneLeadIn = nil
        say(lead + line)
    }

    private var phaseName: String {
        switch phase {
        case .hello, .pickGame: "pick a game"
        case .players: "how many kids and their roles"
        case .props: "props hunt"
        case .makingKit, .kitReady: "printable kit"
        case .handoff, .scene: "playing"
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
