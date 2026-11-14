import SwiftUI
import NutmegCore

/// Wires the state machine to Nutmeg's voice, ears and kit art. One per app run; nothing is persisted.
@Observable @MainActor
final class AppModel {
    let store: AdventureStore
    let voice = NutmegVoice()
    let listener = Listener()
    let art: KitArtService
    let stickers: ItemArtService
    let hasClaude: Bool
    let hasImages: Bool
    /// Hands-free planning conversation (D1, D2) and its Grown-ups tuning (D7).
    let realtime = RealtimeSession()
    /// The writing moment's quiet scribble loop (round 5).
    @ObservationIgnored let scribble = ScribbleSound()
    let voiceSettings = VoiceSettings()
    @ObservationIgnored private let openAIKey: String?
    /// Only the IDs of last session's suggested games/themes (UserDefaults), so the next session differs. Nothing about kids.
    @ObservationIgnored private let suggestionMemory = SuggestionMemory()

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        let config = ClaudeConfig.from(info: info)
        hasClaude = config != nil
        var service = config.map { PhaseService(llm: ClaudeClient(config: $0)) }
        #if DEBUG
        if DemoDriver.requestedPhase != nil { service = nil }   // demo screens use the bundled game, no network
        #endif
        store = AdventureStore(service: service)
        var images = ImageClient.from(info: info)
        #if DEBUG
        // Demo screens skip paid image calls unless asked: -PTDemoArt 1
        if DemoDriver.requestedPhase != nil, !ProcessInfo.processInfo.arguments.contains("-PTDemoArt") { images = nil }
        #endif
        hasImages = images != nil
        art = KitArtService(client: images)
        stickers = ItemArtService(client: images)
        openAIKey = (info["OPENAI_API_KEY"] as? String).flatMap { k in
            let k = k.trimmingCharacters(in: .whitespaces); return k.isEmpty || k.hasPrefix("$(") ? nil : k
        }
        realtime.onTurnDone = { [weak self] text in
            guard let self, Self.isPlanning(self.store.phase), !self.realtime.propLinePending else { return nil }
            // Round 7: roles set but no prop yet → she continues straight into the first prop (no "Sound good?" wait).
            return TurnCheck.review(text, step: self.store.planningStep, rolesSet: self.store.plan != nil,
                                    propsShown: self.store.props?.props.count ?? 0, currentPropDone: self.store.currentPropDone)
        }
        realtime.onSilence = { [weak self] in
            guard let self, Self.isPlanning(self.store.phase), self.store.planningStep != .finish else { return nil }
            return TurnCheck.silenceLine   // spoken only, never in the chat (round 7)
        }
        realtime.onPlanningBeat = { [weak self] topic in await self?.planningBeat(topic) }
        realtime.onPropLine = { [weak self] in self?.revealFirstProp() ?? "" }
        // Tool-first kid turns (round 7): no narration is ever heard; she speaks after the tool result.
        realtime.onKidTurnTools = { [weak self] in
            guard let self, Self.isPlanning(self.store.phase) else { return nil }
            return Realtime.kidTurnTools(step: self.store.planningStep, huntActive: self.store.huntActive)
        }
        realtime.onPostPlanningTurn = { [weak self] in
            guard let self else { return nil }
            switch self.store.phase {
            case .kitReady:
                return "(Silent coaching, don't mention it.) The kit is ready on screen (print step). If they want to play, "
                    + "call start_play; if they want to print, call print_kit. Otherwise answer in ONE short line. No \"go play\" yet."
            case .handoff, .scene, .stepBack, .end:
                return "(Silent coaching, don't mention it.) They're playing now. Answer in ONE short, fun line that helps the "
                    + "current scene. No tools."
            default: return nil
            }
        }
        realtime.onCall = { [weak self] name, args in
            guard let self else { return ("ok", true) }
            return await self.handleCall(name: name, arguments: args)
        }
    }

    // MARK: Voice conversation

    var hasRealtime: Bool { openAIKey != nil }

    /// Grown-ups: hear `voice` say the sample line through the conversation's audio path and pitch settings.
    func auditionVoice(_ voice: String) async {
        guard let key = openAIKey else { return }
        await realtime.audition(apiKey: key, voice: voice, shape: voiceSettings.shape, speed: voiceSettings.speed)
    }
    /// DEBUG screenshots: show the conversation stage without a live session.
    var forceConversation = false

    /// The planning phases run as a voice conversation while the Realtime session is up.
    var inConversation: Bool {
        if forceConversation { return Self.isPlanning(store.phase) }
        guard realtime.status == .live || realtime.status == .connecting else { return false }
        return Self.isPlanning(store.phase)
    }

    static func isPlanning(_ phase: Phase) -> Bool {
        switch phase { case .pickGame, .players, .props: true; default: false }
    }

    /// "Let's play!": start the conversation; if Realtime can't connect, fall back to the tap screens.
    func startConversation() async {
        store.beginConversation()
        guard let key = openAIKey else { await store.start(); return }
        // Fresh suggestions every session (round 7): 3 games picked now (never last session's), injected as today's ideas.
        let games = suggestionMemory.pickGames()
        #if DEBUG
        rtLog("today's games: \(games.map(\.id).joined(separator: ", "))")
        #endif
        let ok = await realtime.connect(apiKey: key, voice: voiceSettings.voice, shape: voiceSettings.shape,
                                        speed: voiceSettings.speed, echoCancel: voiceSettings.echoCancel,
                                        instructions: Realtime.instructions(todayGames: games))
        guard store.phase == .pickGame else { return }   // left while connecting
        if ok {
            realtime.micWanted = true
            gesture(.wave)
            realtime.kickOff(games: games)
        } else {
            await store.start()   // tap screens (and the bundled airplane game if Claude is off too)
        }
    }

    /// Leave activity: hang up and go home. Nothing is kept.
    func leave() {
        realtime.disconnect()
        shownProps = 0; beat = .none; kitBeatTask?.cancel(); kitBeat = .coloring; kitWriting = false; kitWritingTask?.cancel(); kitWritingTask = nil
        voice.stop()
        art.reset()
        stickers.reset()
        store.newGame()
    }

    /// Typed fallback goes into the live conversation when there is one.
    func typed(_ text: String) async {
        if realtime.isLive && Self.isPlanning(store.phase) { realtime.sendText(text); return }
        if realtime.isLive && store.phase != .makingKit { realtime.sendText(text); return }   // print step, play
        // Kit being made (round 7): a tiny "Almost ready!" at most, never a new conversation turn.
        if realtime.isLive && store.phase == .makingKit { if !realtime.isSpeaking { realtime.say("Almost ready!") }; return }
        await handleSpeech(text)
    }

    func phaseChanged() {
        // Round 7 (Haylee): the mic only looks disabled while connecting. Kit making: pressable, "Almost ready!" at most.
        realtime.micWanted = true
        realtime.quickReplyOnly = store.phase == .makingKit
        if store.phase == .makingKit { startKitProgress() } else if store.phase != .kitReady { kitWait?.cancel() }
        // (A fast kit can skip straight to kitReady between two observations; it still gets its writing beat.)
        if (store.phase == .makingKit || store.phase == .kitReady) && kitBeat == .coloring && !kitWriting && kitWritingTask == nil {
            startKitWriting()
        }
        if !(store.phase == .makingKit || store.phase == .kitReady) { kitWritingTask?.cancel(); kitWritingTask = nil; kitWriting = false }
    }

    /// Kit writing (round 5): once she has finished saying she's making the kit, she writes on her clipboard until the
    /// whole kit is final (at least `PoseRules.minKitWriting`).
    private(set) var kitWriting = false
    @ObservationIgnored private var kitWritingSince = Date.distantPast
    @ObservationIgnored private var kitWritingTask: Task<Void, Never>?
    private func startKitWriting() {
        kitWritingTask?.cancel()
        kitWritingTask = Task { @MainActor in
            for _ in 0..<120 where isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // her line first (≤ 6 s)
            guard !Task.isCancelled, store.phase == .makingKit || store.phase == .kitReady, kitBeat == .coloring else {
                kitWritingTask = nil; return
            }
            kitWritingSince = Date()
            kitWriting = true
            kitWritingTask = nil
        }
    }

    /// Kit art runs in its own task, NOT tied to the kit screen's lifetime: a `.task` on the view was cancelled
    /// as soon as the kids tapped "Let's play!" (or the stage re-rendered), which cancelled every image request
    /// and left the pages app-drawn.
    func kitChanged() {
        guard let kit = store.kit else { return }
        let title = store.plan?.gameTitle ?? store.gameTitle ?? "Pretend"
        Task { await art.generate(kit: kit, gameTitle: title) }
    }

    /// Round 7: light progress commentary while the kit is being made (KitProgress): every ~13 s, about a page still
    /// being drawn, at most 4, never repeated; stops as soon as the whole kit has landed.
    private func startKitProgress() {
        kitWait?.cancel()
        kitWait = Task { @MainActor in
            var said: [String] = []
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(KitProgress.interval))
                guard !Task.isCancelled, store.phase == .makingKit || store.phase == .kitReady, !kitFinal else { return }
                if isSpeaking { continue }
                // While the kit's pages are still being written, every page is in progress; then the ones still drawing.
                let pending = store.kit == nil ? KitRecipe.allCases : (store.kit?.items ?? []).filter { item in
                    item.recipe == .cutouts ? art.cutoutImages(item).contains { $0 == nil } : art.images[item.id] == nil
                }.compactMap(\.recipe)
                guard said.count < KitProgress.maxLines else { return }
                guard let line = KitProgress.line(pending: pending, said: said) else { continue }   // keep waiting
                rtLog("kit progress: \(line)")
                said.append(line)
                speak(line)
            }
        }
    }
    @ObservationIgnored private var kitWait: Task<Void, Never>?

    /// Kit step beats (no-text-overlays.md, fix round 2): she colors in the close-up until the WHOLE kit is final, then
    /// looks up (crayon down), the camera zooms out, and the papers fly off her clipboard.
    private(set) var kitBeat: PTStageDirector.KitBeat = .coloring
    @ObservationIgnored private var kitBeatTask: Task<Void, Never>?
    /// The printable pages for the current kit.
    var kitPages: [KitPage] {
        guard let kit = store.kit else { return [] }
        return KitLayout.pages(for: kit, roles: store.plan?.roles ?? [], playerCount: store.playerCount)
    }
    /// Print (single tap, decisions/2026-11-13-single-tap-print.md): the whole kit as one PDF to the iOS print screen.
    func printKit() {
        let pdf = KitPrinter.pdf(pages: kitPages, art: art.images,
                                 cutouts: Dictionary(uniqueKeysWithValues: (store.kit?.items ?? []).map { ($0.id, art.cutoutImages($0)) }))
        KitPrinter.print(pdf, jobName: "PretendThat \(store.plan?.gameTitle ?? "kit")")
    }
    /// The papers are out (kit final, she looked up, the camera zoomed out).
    var kitPapersOut: Bool { kitFinal && kitBeat == .papers }

    /// Every page's art has landed or definitively fallen back.
    var kitFinal: Bool { store.phase == .kitReady && store.kit != nil && art.finished }
    func kitFinalChanged(_ final: Bool) {
        #if DEBUG
        // `-PTPDFOut`: write the print-path PDF (exactly what AirPrint gets) to tmp/kit.pdf once the kit is final.
        if final, ProcessInfo.processInfo.arguments.contains("-PTPDFOut") {
            let pdf = KitPrinter.pdf(pages: kitPages, art: art.images,
                                     cutouts: Dictionary(uniqueKeysWithValues: (store.kit?.items ?? []).map { ($0.id, art.cutoutImages($0)) }))
            try? pdf.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("kit.pdf"))
        }
        #endif
        kitBeatTask?.cancel()
        guard final else { kitBeat = .coloring; return }
        kitBeatTask = Task { @MainActor in
            // Writing never reads as a flicker: at least minKitWriting on the clipboard, even for an instant kit.
            for _ in 0..<100 where !kitWriting && (store.phase == .makingKit || store.phase == .kitReady) && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))   // her "making your kit" line, then the writing (≤ 10 s)
            }
            let left = PoseRules.minKitWriting - Date().timeIntervalSince(kitWritingSince)
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            guard !Task.isCancelled else { return }
            kitWriting = false
            kitBeat = .lookUp                                   // eyes up (happy), crayon drops out of frame
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            kitBeat = .papers                                   // zoom out; the papers fly once the camera settles
            // Round 7: the ready line only now that the whole kit exists; about printing, never "go play".
            speak(AdventureStore.kitReadyLine)
        }
    }

    private func handleCall(name: String, arguments: String) async -> (output: String, respond: Bool) {
        guard let call = PlanningCall.decode(name: name, arguments: arguments) else {
            return ("I couldn't use that. Try again with the right fields.", true)
        }
        let before = realtime.responseSerial
        if case .printKit = call {
            guard store.phase == .kitReady || kitFinal else { return ("Not yet: the kit isn't ready. Say only \"Almost ready!\"", true) }
            printKit()
        }
        if case .setGame = call {
            // Theme ideas for this game (round 7): 3 twists, never last time's; delivered in the set_game result.
            store.themeIdeas = suggestionMemory.pickTwists()
            #if DEBUG
            rtLog("today's themes: \(store.themeIdeas.map(\.id).joined(separator: ", "))")
            #endif
        }
        let output = await store.apply(call)
        realtime.huntMode = store.huntActive
        if case .showNextProp = call {
            if realtime.isLive && (store.props?.props.count ?? 0) == 1 && shownProps == 0 {
                // First prop (round 7): she says the roles first; the card waits for that line to finish + 1 s.
                realtime.holdFirstPropLine()
            } else {
                revealProps(after: before)
            }
        }
        if store.props == nil { shownProps = 0 }
        // finish_planning and start_play end her turn: the app speaks the kit and scene lines.
        return (output, call != .finishPlanning && call != .startPlay)
    }

    /// Nutmeg's on-screen state, derived from everything that's happening.
    var nutmegState: NutmegState {
        #if DEBUG
        if let s = DemoDriver.forcedState { return s }
        #endif
        // Writing moment (round 5): focus face (eyes down at the clipboard) while she writes; she looks up happy after.
        if isWriting { return .coloring }
        if beat == .lookUp { return .idle }
        if store.phase == .makingKit || store.phase == .kitReady {
            switch kitBeat { case .coloring: return realtime.isSpeaking ? .idle : .thinking; case .lookUp: return .excited; case .papers: break }
        }
        if realtime.isLive {
            // Conversation faces (decisions/conversation-camera-and-expressions.md): listening while the kid talks,
            // thinking in the gap before her reply, then the face the model chose (its eyes; the live mouth
            // animates on top), happy by default.
            if realtime.kidIsTalking { return .listening }
            if let e = realtime.expression { return Self.state(for: e) }
            if realtime.thinkingGap { return .thinking }
            if realtime.isSpeaking { return .idle }
        }
        if listener.isListening { return .listening }
        // Kit: she colors until every page is final (the papers wait for it, no-text-overlays.md).
        if store.isWorking { return .thinking }
        if voice.isSpeaking { return .talking }
        if store.lastError != nil { return .oops }
        switch store.phase {
        case .makingKit: return .thinking
        case .stepBack: return .napping
        case .kitReady, .end: return .excited
        default: return .idle
        }
    }

    /// Kit step (round 3): she holds the clipboard in front with both hands from "let me make your pages" until the
    /// whole kit is final, then pops back to idle (excited) for the paper reveal.
    var nutmegHoldsClipboard: Bool { PoseRules.holdsClipboard(phase: store.phase, kitBeat: kitBeat) || beat != .none }
    /// The writing moment is on (planning beat or the kit being made): clipboardBoth, focus face, crayon top, scribble.
    var isWriting: Bool {
        #if DEBUG
        if DemoDriver.forceWriting { return true }
        #endif
        return PoseRules.isWriting(phase: store.phase, planningBeat: beat == .writing, kitWriting: kitWriting)
    }
    /// The resting body pose on the stage (the camera's face focus follows it).
    var nutmegRestPose: NutmegPose { nutmegState.basePose(holdingClipboard: nutmegHoldsClipboard) }

    /// Planning beat (round 5 writing moment): she writes on her clipboard, then looks up and announces the plan.
    enum Beat { case none, writing, lookUp }
    private(set) var beat: Beat = .none

    /// Her lead-in (if any) finishes, she writes with her eyes down for ~1.8–2.6 s, looks up happy (crayon drops out of
    /// frame, the camera returns to the normal shot), and only then does the function result go back so she announces it.
    func planningBeat(_ topic: String) async {
        for _ in 0..<80 where realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // lead-in done
        beat = .writing
        let base = topic == "roles" ? 2.3 : PoseRules.minPlanningBeat
        try? await Task.sleep(for: .seconds(Double.random(in: base...(base + 0.6))))
        // Round 7: ONE continuous writing state. The beat's result goes back now (set_roles → show_next_prop run
        // silently), but she keeps writing until her roles line actually starts playing; only then does she look up.
        beatEndTask?.cancel()
        beatEndTask = Task { @MainActor in
            for _ in 0..<240 where !realtime.isSpeaking && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }   // ≤ 12 s
            guard !Task.isCancelled else { return }
            beat = .lookUp
            try? await Task.sleep(for: .milliseconds(550))
            beat = .none
        }
    }
    @ObservationIgnored private var beatEndTask: Task<Void, Never>?

    /// Prop cards on stage. A new card waits until the turn that was playing when it was requested has finished (never
    /// mid-sentence about the roles): it appears with her prop line, or once playback drains.
    private(set) var shownProps = 0
    /// Without a live session (demo screenshots, tap fallback) every card shows at once.
    var visibleProps: Int { realtime.isLive ? shownProps : (store.props?.props.count ?? 0) }
    private func revealProps(after serial: Int) {
        Task { @MainActor in
            // A new prop card waits for the writing beat too: it appears as she looks up and announces it.
            while beat != .none || (realtime.isSpeaking && realtime.audioResponseSerial <= serial) { try? await Task.sleep(for: .milliseconds(50)) }
            let n = store.props?.props.count ?? 0
            if n > shownProps { shownProps = n; pointAtCard() }   // the card appears as her prop line starts
        }
    }

    /// The roles line finished playing (+1 s): show the first card, point at it, and return the note for her prop line.
    private func revealFirstProp() -> String {
        shownProps = store.props?.props.count ?? 0
        pointAtCard()
        let p = store.props?.props.first
        return AdventureStore.firstPropLine(item: p?.householdItem ?? "prop", becomes: p?.becomes ?? "something fun")
    }

    /// Backup buttons on the current prop card (noisy rooms): the one planning tap.
    func huntReply(found: Bool) {
        guard let p = store.props?.props.first(where: { $0.id == store.currentPropID }) else { return }
        let name = p.householdItem.lowercased()
        realtime.sendText(found ? "Nutmeg, we found the \(name)!" : "Nutmeg, we don't have a \(name).")
    }

    static func state(for e: NutmegExpression) -> NutmegState {
        switch e {
        case .happy: .idle
        case .excited: .excited
        case .ooh: .amazed
        case .thinking: .thinking
        case .listening: .listening
        case .oops: .oops
        }
    }

    /// One-shot body gesture (wave, point, celebrate). Poses rest on idle otherwise.
    var cue: NutmegCue?
    /// Bumped on celebration moments; stage props bounce once.
    var celebrations = 0
    func gesture(_ g: NutmegGesture, hold: TimeInterval? = nil) { cue = NutmegCue(gesture: g, hold: hold) }

    /// Round 7 choreography: the card appears and she points; the point holds through her prop line (until it has
    /// finished playing) plus a few seconds, then she rests.
    @ObservationIgnored private var pointTask: Task<Void, Never>?
    func pointAtCard() {
        gesture(.point, hold: 60)
        pointTask?.cancel()
        pointTask = Task { @MainActor in
            for _ in 0..<160 where !realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // her line starts (≤ 8 s)
            while realtime.isSpeaking && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            gesture(.point, hold: 0)   // release
        }
    }

    /// Nutmeg's voice for app-written lines. With a live Realtime session she keeps her conversation voice;
    /// during planning she speaks for herself, so app lines are skipped there.
    func speak(_ text: String) {
        if realtime.isLive {
            if !Self.isPlanning(store.phase) { realtime.say(text) }
            return
        }
        Task { await voice.say(text) }
    }

    // MARK: Checklist and scene pictures (checklist-pictures.md)

    func resolve(_ picture: Picture) -> ResolvedPicture {
        PictureResolver.resolve(picture, kit: store.kit, roles: store.plan?.roles ?? [])
    }

    /// The tile for one picture: library/action art, or this game's own kit art (one ticket, one bill, a role's
    /// badge with its title, one cut-out). Falls back to a placeholder word while art is missing.
    func pictureTile(_ picture: Picture, size: CGFloat = 56) -> PTPictureTile {
        let r = resolve(picture)
        switch r {
        case .prop(let id):
            return PTPictureTile(image: UIImage(named: PropLibrary.asset(id)), placeholder: PropLibrary.name(id) ?? id, size: size)
        case .action(let id):
            return PTPictureTile(image: UIImage(named: ActionArt.asset(id)), placeholder: id.replacingOccurrences(of: "-", with: " "), size: size)
        case .kitItem(let itemID, _, let role):
            let title = store.kit?.items.first { $0.id == itemID }?.title ?? ""
            return PTPictureTile(image: art.images[itemID], placeholder: title, roleTitle: role?.roleName,
                                 roleTint: Theme.playerColor(role?.id.index ?? 0), size: size)
        case .cutout(let itemID, let index, let label):
            return PTPictureTile(image: art.cutout(itemID, index), placeholder: label, size: size)
        }
    }

    var mouthLevel: Float { realtime.isLive ? realtime.level : voice.level }
    /// The live voice's lip-synced mouth (nil: fall back to the amplitude mouth from `mouthLevel`).
    var mouthShape: NutmegMouth? { realtime.isLive ? NutmegMouth(rawValue: realtime.mouth.rawValue) : nil }
    var isSpeaking: Bool { realtime.isLive ? realtime.isSpeaking : voice.isSpeaking }

    // MARK: Push-to-talk (decisions/2026-11-13-push-to-talk.md)

    /// The red mic in the control pill. Live conversation: stream to Realtime while held. Without one (tap fallback):
    /// the on-device listener, same hold gesture.
    enum MicState { case idle, listening, disabled }
    var micState: MicState {
        if realtime.isLive {
            // Round 7: never disabled in a live session (only while connecting): print step and play take voice too.
            return realtime.kidIsTalking ? .listening : .idle
        }
        if realtime.status == .connecting { return .disabled }
        guard listener.available, store.phase != .hello else { return .disabled }
        return listener.isListening ? .listening : .idle
    }
    func talkPressed() {
        if realtime.isLive { realtime.beginTalk() } else if listener.available { micPressed() }
    }
    func talkReleased() {
        if realtime.isLive { realtime.endTalk() } else if listener.isListening { micReleased() }
    }

    func micPressed() { listener.startListening(stopping: voice) }

    func micReleased() {
        Task {
            let text = await listener.stopListening()
            guard !text.isEmpty else { return }
            await handleSpeech(text)
        }
    }

    /// Routes a spoken answer by phase (ideas on pick-game, chat elsewhere). Names are never captured.
    func handleSpeech(_ text: String) async {
        switch store.phase {
        case .hello:
            await store.start()
        case .pickGame:
            if let idea = store.ideas?.ideas.first(where: { text.localizedCaseInsensitiveContains($0.title) }) {
                await store.chooseGame(idea.title)
            } else {
                await store.askForIdeas(text)
            }
        default:
            await store.kidSaid(text)
        }
    }
}
