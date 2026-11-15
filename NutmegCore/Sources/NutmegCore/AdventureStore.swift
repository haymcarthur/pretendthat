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
    /// Round 20 (Haylee): full color, or pages to color in. Asked after the confirm step's yes; nil = not asked yet.
    /// The one source of truth for every kit image prompt.
    public private(set) var printStyle: PrintStyle?
    /// What the pages are drawn as (the coloring pages until the kids choose).
    public var currentPrintStyle: PrintStyle { printStyle ?? .colorIn }
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
    public nonisolated static func firstPropLine(item: String, becomes: String) -> String {
        "(Silent coaching, don't mention it.) The \(item.lowercased()) card is on screen now and you're pointing at it. You already said "
            + "\"\(huntTransition)\": start RIGHT AWAY with the first prop line (no second lead-in like \"let's start the hunt\"), like \"First, can you find a \(item.lowercased())? It'll be \(becomes)!\", then explain "
            + "ONCE: say 'found it' when you have it, or tell me if you don't. Don't repeat the roles, no check-in, no narration. "
            + "If you already named this prop, say only the 'found it' explanation."
    }

    /// What she says for a new prop card (prop-gathering-flow.md, fix round 2): only the FIRST prop explains how to
    /// answer; later props stay short ("Next, can you find a spoon? It'll be the big stirrer!").
    public nonisolated static func nextPropOutput(id: String, item: String, becomes: String, n: Int) -> String {
        let how = n == 1
            ? "This is the FIRST prop. Its card stays hidden for now. Speak ONLY the roles now, as a set of parts the kids share, then the hunt transition, word for word: \"\(Self.huntTransition)\" (\"We need a Captain, a Navigator, and an Island Explorer! \(Self.huntTransition)\"; for one kid: \"You'll be the Captain! \(Self.huntTransition)\"). Never \"You're the X, the Y, and the Z\" (that sounds like one kid gets every role), never \"Pick who's who\", no \"All set!\". Don't name this prop or describe the card yet, and don't ask anything: when your roles line finishes, the card appears, you point at it, and you'll be asked for the prop line."
            : n % 3 == 0
            // Round 13: "Pretend that" on about 1 prop in 3 (props 3 and 6), decided by the app so it really happens.
            ? "This is prop \(n): keep it SHORT and use the words \"pretend that\" this time, like \"Can you find a \(item.lowercased())? Let's pretend that it's \(becomes)!\" Do NOT repeat 'say found it' or 'tell me if you don't have it' (they already know)."
            : "This is prop \(n): keep it SHORT, like \"Next, can you find a \(item.lowercased())? It'll be \(becomes)!\" Do NOT repeat 'say found it' or 'tell me if you don't have it' (they already know). Don't say \"pretend that\" for this one."
        return "Card \(id) is ready (prop \(n)). \(how) Then wait. Found: mark_found then show_next_prop. Missing: "
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
        let gen = kitGeneration
        if let title {
            kitLeadIn = nil
            say(Self.remakeLine(title))
        } else {
            let lead = kitLeadIn.flatMap { Date().timeIntervalSince($0.at) < Self.leadInWindow ? $0.line + " " : nil } ?? ""
            kitLeadIn = nil
            say(lead + "Ooh, let me make your kit! Wait for it...")
        }
        await run("kit", kidSaid: nil) { [self] svc in
            // The context is read now (the current title, count, roles and props), and a newer remake wins.
            let made = try await svc.kit(ctx: context)
            if gen == kitGeneration { kit = made }
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
        playerCount = 0; gameTitle = nil; printStyle = nil; planningStep = .game; themeIdeas = []
        ideas = nil; plan = nil; props = nil; kit = nil
        choices = []; lastError = nil; usingFallback = false
        foundProps = []; checkedSteps = []; doneSnapshot = nil; failures = [:]; retryAction = nil; holder = nil
        nutmegLine = ""; presenting = .none; reachedStep = nil; lastPlayPhase = nil; steerIdeas = SteerIdeas()
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
            let n = max(1, min(count, Players.max))
            switch phase {
            case .makingKit, .kitReady, .handoff, .scene, .end:
                return "The kit is already made for \(playerCount). Say in ONE short, kind line that this adventure is all set, "
                    + "and they can tap New game to plan one for a different number of friends."
            default: break
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
            phase = .players; presenting = .none
            // Round 20: the color question comes next, unless the kids already chose (a correction re-opened the recap).
            guard printStyle != nil else { planningStep = .color; return ColorChoice.askOutput(playerCount: max(1, playerCount)) }
            planningStep = .roles
            return ConfirmStep.confirmedOutput(playerCount: max(1, playerCount))
        case .setPrintStyle(let style):
            return setPrintStyle(style)
        case .setRoles(let drafts):
            if planningStep == .confirm {
                return "Not yet: the kids haven't said yes to your recap. Say exactly: \"\(recapLine)\" and wait (yes → confirm_plan)."
            }
            if planningStep == .color {
                return "Not yet: ask the color question first. Say exactly: \"\(ColorChoice.question)\" and wait (their answer → set_print_style)."
            }
            if playerCount == 0 { playerCount = max(1, min(drafts.count, Players.max)) }
            let roles = drafts.enumerated().map { i, d in
                Role(id: RoleID.allCases[min(i, RoleID.allCases.count - 1)], roleName: d.roleName, emoji: "", symbol: "star", job: d.job)
            }
            let title = gameTitle ?? "Pretend"
            plan = Sanitizer.clean(GamePlan(gameTitle: title, gameEmoji: "", setting: title, roles: roles, nutmegSays: ""), playerCount: playerCount)
            phase = .players; presenting = .none; planningStep = .props
            let cast = plan!.roles.map { $0.count > 1 ? "\($0.count) \($0.roleName)s" : $0.roleName }.joined(separator: ", ")
            let short = drafts.count < playerCount ? " You gave \(drafts.count) roles for \(playerCount) kids, so the last role is shared." : ""
            return "Roles set: \(cast).\(short) Step 4: announce the roles with excitement (there are no role cards; kids pick their own badge after printing). Now, WITHOUT speaking yet and without waiting for the kids, call show_next_prop for the FIRST prop. Then, in ONE turn, announce the roles and end with \"\(Self.huntTransition)\" (the card and your prop line follow). Never ask \"Sound good?\", \"Okay?\" or \"Ready?\": there is nothing to approve."
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
            return "Checked off \(prop.householdItem). Don't speak yet: call " + (n >= 3 ? "show_next_prop (or finish_planning if that's enough props)" : "show_next_prop")
                + " FIRST, then cheer in a few words and ask about the new prop in the same turn. Never narrate (\"let me grab the next prop\")."
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
            return "Swapped (the card still uses id \(p.props[i].id)). Say what the new item becomes and ask if they can find it."
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
            if playerCount == 0 { playerCount = max(1, plan?.kidCount ?? 1) }
            Task { await self.makeKit() }
            return "Making the kit now. Say nothing."
        case .justTalk:
            return "Nothing changes. Reply kindly in ONE short line (no narration), then ask the current step's question again."
        case .startPlay:
            guard phase == .kitReady else { return "Not yet: the kit isn't ready. Say only \"Almost ready!\"" }
            beginPlay()
            return "Play started. The app runs the scenes now. Say nothing."
        case .confirmHandoff:
            guard case .handoff(let i) = phase, let owner = kit?.scenes[i].owner.role else {
                return "There's no hand-off right now. Answer in ONE short line."
            }
            badgeTapped(owner)
            return "Hand-off confirmed: the scene starts and the app says its line. Say nothing."
        case .printKit:
            return "The print screen is open. Say one short line like \"Here's the print screen!\""
        }
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
        case .game, .theme, .players, .confirm:
            return "Noted: the printables will be \(style.spoken). Carry on with the current step (don't ask about color again)."
        case .roles, .props, .finish:
            return was == style ? "Already \(style.spoken). Carry on with the current step in ONE short line."
                : "Got it: the printables will be \(style.spoken) (the app changes them). Say so in a few words, then carry on with the current step."
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
            kit = nil; kitRemakes += 1; phase = .makingKit
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
    public func debugReplaceScene(_ i: Int, with scene: Scene) { if kit?.scenes.indices.contains(i) == true { kit?.scenes[i] = scene } }
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
        guard let kit, i < kit.scenes.count else { phase = .end; sayInPlay(HandOffLines.end(canGoBack: canGoBackToChecklist)); return }
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
