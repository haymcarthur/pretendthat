import AVFoundation
import Observation
import QuartzCore
import NutmegCore

/// Hands-free voice conversation with Nutmeg over OpenAI's Realtime API (decisions D1, D2, D7).
/// WebSocket (URLSessionWebSocketTask) + AVAudioEngine, no third-party code.
/// - Mic (push-to-talk, decisions/2026-11-13-push-to-talk.md): input node → 24 kHz PCM16 mono →
///   `input_audio_buffer.append`, ONLY while the kid holds the red mic button (`beginTalk` / `endTalk`). Release →
///   `input_audio_buffer.commit` + `response.create`; a hold under `Realtime.minHoldSeconds` → `input_audio_buffer.clear`.
///   Pressing while Nutmeg talks interrupts her: `response.cancel`, playback stops, and her item is truncated at what
///   was actually heard. No server VAD, so background chatter never reaches the model or the transcript.
/// - Speaker (round D3a): playing her voice lives in `NutmegSpeaker` (owned by `AppModel`, shared engine): PCM16
///   deltas → player node → pitch unit (Varispeed 1.20) → mixer, the lip sync (`LipSyncAnalyzer` + `MouthShaper`,
///   each window stamped with when it leaves the speaker), the speaking state and the barge-in clear. This session
///   keeps the socket and the protocol (responses, tools, the cached prefix, `SpeechStop`) and hands it the audio.
///   `level`, `mouth` and `isSpeaking` here read the speaker.
/// - Voice-processing IO (echo cancellation) is OFF by default: on iOS it runs on the whole IO unit, so it also
///   processes (and dulls/ducks) the OUTPUT. The mic is gated while Nutmeg talks, so she never hears herself anyway.
/// Nothing is recorded or stored: audio buffers are sent and dropped.
@Observable @MainActor
final class RealtimeSession {
    enum Status: Equatable { case idle, connecting, live, failed(String) }

    private(set) var status: Status = .idle
    /// Round D3a: her speaker (playback, lip sync, speaking state). The session hands it the audio deltas.
    @ObservationIgnored let speaker: NutmegSpeaker
    /// 0…1 loudness of Nutmeg's voice (the mouth envelope, coarsely updated).
    var level: Float { speaker.level }
    /// The mouth shape to show right now, in sync with what the speaker is playing.
    var mouth: MouthShape { speaker.mouth }
    var isSpeaking: Bool { speaker.isSpeaking }

    init(speaker: NutmegSpeaker) {
        self.speaker = speaker
        speaker.live = self
        speaker.onStartedSpeaking = { [weak self] in self?.updateGate() }
        speaker.onScheduled = { [weak self] heardAt in
            guard let self, self.trace.running, !self.trace.has("heard") else { return }
            self.trace.mark("heard", at: heardAt)   // when the first sample actually leaves the speaker
            rtLog(self.trace.summary())
            self.trace.end()
        }
        speaker.onFinishedSpeaking = { [weak self] in
            guard let self else { return }
            if self.reminderAwaitingEnd { self.reminderAwaitingEnd = false; self.reminderDoneAt = Date(); rtLog("reminder finished playing") }
            self.startSilenceTimer()
            // Her turn's face ends with her turn (held at least 1 s).
            if Date().timeIntervalSince(self.expressionSetAt) >= 1 { self.expressionTask?.cancel(); self.expression = nil }
            self.updateGate()
        }
    }
    /// The kid is holding the mic button (ears perk, the button pulses).
    private(set) var kidIsTalking = false
    /// The kid finished a turn and her reply hasn't started yet (shown as thinking after a short beat, so a quick reply
    /// doesn't flash it).
    private(set) var thinkingGap = false
    /// The face for her current turn: set by the model's `set_expression`, or a blip from an exclamation ("Ooh!").
    private(set) var expression: NutmegExpression?
    /// Prop hunt (prop-gathering-flow.md): only changes how long she waits before a gentle check-in (the hunt takes a
    /// while). Push-to-talk replaced the old addressee gate: everything the kid says while holding is meant for her.
    var huntMode = false
    /// Tool-first kid turns (round 7): the app names the tools for the FIRST response to a kid turn (nil = normal).
    /// That response's audio is never played and its words never reach the chat (they'd be "let me set that up…");
    /// its item is truncated to 0 ms so the model knows nobody heard it. She speaks in the follow-up.
    @ObservationIgnored var onKidTurnTools: (@MainActor () -> [String]?)?
    @ObservationIgnored private var forcedTools: [String]?
    /// Round 20: the tools the running silent pass may call (any other is refused by the app, not run).
    @ObservationIgnored private var silentAllowed: [String]?
    /// Round 20: a system item after the stable prefix (today's ideas, a reconnect's state).
    func addNote(_ item: [String: Any]?) { if let item { socket?.send(item) } }
    @ObservationIgnored private var silentPending = false
    @ObservationIgnored private var silentResponse = false
    @ObservationIgnored private var silentItems: [String] = []
    /// Kit being made (round 7): the mic stays pressable, but a kid line gets only "Almost ready!".
    var quickReplyOnly = false
    /// After planning (print step, play): a silent context note goes before her reply.
    @ObservationIgnored var onPostPlanningTurn: (@MainActor () -> String?)?
    /// Serial of the latest response, and of the response whose audio is playing (card reveal timing).
    private(set) var responseSerial = 0
    private(set) var audioResponseSerial = 0
    /// Planning is over: no more push-to-talk (kids tap from here on, D3), keep the voice for Nutmeg's lines.
    var micWanted = true { didSet { updateGate() } }
    private(set) var lastError: String?

    /// Live transcript for the chat panel: in memory only, cleared when a new conversation starts (PretendThat
    /// stores nothing). Lives on this @Observable, @MainActor session, the same instance the panel reads.
    private(set) var chat = RealtimeTranscript()
    var transcript: [RealtimeTranscript.Line] { chat.lines }
    #if DEBUG
    /// Demo screenshots: a realistic transcript (Nutmeg / kid turns alternate).
    func debugSeedTranscript(_ turns: [String]) {
        for (i, t) in turns.enumerated() { _ = chat.apply(i % 2 == 0 ? .transcriptDone(t) : .kidTranscript(t)) }
    }
    #endif

    /// Function call handler: returns the output for the model and whether Nutmeg should answer afterwards.
    @ObservationIgnored var onCall: (@MainActor (String, String) async -> (output: String, respond: Bool))?
    /// Checks how her finished turn ended (conversation-structure.md); returns a silent nudge, or nil when it's fine.
    @ObservationIgnored var onTurnDone: (@MainActor (String) -> (note: String, complete: Bool)?)?
    /// The kids have been quiet ~20 s after her turn; returns the ONE reminder line (nil = don't). Round 7: a fixed
    /// out-of-band line in her voice (no context, so it can't improvise), shown in the chat as its own bubble (Haylee:
    /// everything she says out loud is in the chat).
    @ObservationIgnored var onSilence: (@MainActor () -> String?)?
    /// A planning beat (planning-beats.md): she colors on her clipboard; the function result waits for it.
    @ObservationIgnored var onPlanningBeat: (@MainActor (String) async -> Void)?
    @ObservationIgnored private var beatTask: Task<Void, Never>?
    @ObservationIgnored private var beatRunning = false
    @ObservationIgnored private var lastBeatAt = Date.distantPast
    /// The prop list is planned once per adventure (one writing beat before the first prop).
    @ObservationIgnored private var propsPlanned = false

    /// Starts a writing beat; the pending function results go back when it ends (`.responseDone`).
    private func startBeat(_ topic: String) {
        guard !beatRunning else { return }
        // Round 7: one writing beat plans the roles AND the prop list, so the first prop follows the roles at once.
        propsPlanned = true
        let beat = onPlanningBeat
        beatRunning = true
        lastBeatAt = Date()
        beatTask = Task { await beat?(topic) }
    }

    @ObservationIgnored private var socket: RealtimeSocket?
    @ObservationIgnored private let mic = MicPump()
    @ObservationIgnored private var pendingOutputs: [(String, String)] = []
    /// Exactly one spoken reply per kid turn, never two responses at once (NutmegCore `ResponseGate`, round 6).
    @ObservationIgnored private var gate = ResponseGate()
    private var responseActive: Bool { gate.active }
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    @ObservationIgnored private var awaitingReply = false
    @ObservationIgnored private var gapTask: Task<Void, Never>?
    @ObservationIgnored private var expressionTask: Task<Void, Never>?
    /// The model chose a face this turn (blips never override it).
    @ObservationIgnored private var modelChoseExpression = false
    /// The current response produced audio (an expression-only response needs a follow-up to actually speak).
    @ObservationIgnored private var responseHadAudio = false
    @ObservationIgnored private var replyStarted = false
    @ObservationIgnored private var expressionSetAt = Date.distantPast
    @ObservationIgnored private var responseLineStart = 0
    @ObservationIgnored private var nudgesThisTurn = 0
    @ObservationIgnored private var reasks = 0
    @ObservationIgnored private var silenceTask: Task<Void, Never>?
    /// The silence reminder (round 7): sent, then playing (no turn check, no truncate: it isn't in the conversation).
    @ObservationIgnored private var reminderPending = false
    @ObservationIgnored private var reminderPlaying = false
    /// Round 7 choreography: the first prop's line waits for the roles line to finish playing + 0.4 s (round 10; was 1 s), then the card
    /// appears with her point (`onPropLine` reveals it and returns the note) and the prop line is requested.
    private(set) var propLinePending = false
    @ObservationIgnored private var propLineSerial = 0
    @ObservationIgnored var onPropLine: (@MainActor () -> String)?
    /// Round 19: what the kid said out loud (transcribed), for the app's local kid-safety check (never stored or logged).
    @ObservationIgnored var onKidTranscript: (@MainActor (String) -> Void)?
    /// Round 19: a note to add after a tool-first pass, before her spoken reply (nil = none).
    @ObservationIgnored var onSilentPassDone: (@MainActor () -> String?)?
    func holdFirstPropLine() { propLinePending = true; propLineSerial = responseSerial }

    /// The silent tool-first response ended: send its tool outputs and ask for her one spoken reply.
    private func silentTurnDone() {
        if !pendingOutputs.isEmpty, let socket {
            for (id, out) in pendingOutputs { socket.send(Realtime.functionOutput(callID: id, output: out)) }
            pendingOutputs = []
        }
        // Round 19: after all of this pass's tools ran (e.g. set_theme AND set_player_count), the app may add one
        // authoritative note (the newest recap), so her one reply uses the final state.
        if let note = onSilentPassDone?() { socket?.send(Realtime.systemNote(note)); rtLog("note after the silent pass") }
        let followUp = gate.done(allowFollowUp: holdStartedAt == nil && !dropAudio && !beatRunning)
        rtLog("tool-first done: followUp=\(followUp)")
        if followUp { trace.mark("spoken.create"); socket?.send(Realtime.responseCreateSpoken()) }
    }

    private func startPropLine() {
        Task { [weak self] in
            guard let self else { return }
            for _ in 0..<600 where self.isSpeaking { try? await Task.sleep(for: .milliseconds(50)) }   // roles audio ends
            try? await Task.sleep(for: .milliseconds(400))   // round 10 (Haylee): 1 s → ~0.4 s after the roles line
            guard self.propLinePending, self.isLive else { return }
            self.propLinePending = false
            let note = self.onPropLine?() ?? ""
            rtLog("prop line: card shown, asking for the first prop line")
            self.chat.breakTurn()   // the prop line comes after a pause: its own bubble
            if !note.isEmpty { self.socket?.send(Realtime.systemNote(note)) }
            self.gate.forceFollowUp()
            self.requestResponse()
        }
    }
    // Push-to-talk state.
    @ObservationIgnored private var holdStartedAt: Date?
    @ObservationIgnored private var releaseTask: Task<Void, Never>?
    /// Her in-conversation audio item that is playing (truncated on interrupt), and where it starts in player samples.
    @ObservationIgnored private var audioItemID: String?
    @ObservationIgnored private var audioItemStart: Double?
    /// Audio of a response the kid interrupted still trickles in: drop it until the next response starts.
    @ObservationIgnored private var dropAudio = false

    var isLive: Bool { status == .live }

    // MARK: Lock / background (round 9, Haylee: only fully closing the app ends the game)

    /// The app is in the background: audio is stopped, and a socket that drops meanwhile is only noted (no failure),
    /// so nothing in the game resets. `resumeIfAlive()` restarts the audio, or the app reconnects silently.
    private(set) var suspended = false
    @ObservationIgnored private var socketDropped = false
    @ObservationIgnored private var echoCancel = false
    /// The socket dropped while the app was in the foreground (session time limit, network): the app reconnects
    /// silently with the current state. Return true when it will (then the session doesn't fail).
    @ObservationIgnored var onDropped: (@MainActor () -> Bool)?
    /// Sleepy Nutmeg (round 9): when the ONE silence reminder finished playing (nil once anyone talks again).
    private(set) var reminderDoneAt: Date?
    @ObservationIgnored private var reminderAwaitingEnd = false
    /// A silent note sent with the next kid turn (the wake-up note after she dozed off).
    @ObservationIgnored var noteForNextKidTurn: String?

    /// Background: end a push-to-talk hold (cleared, nothing sent), stop her mid-line (truncated at what was heard),
    /// stop the mic and the speaker. The socket stays open if it can; the chat and every game state stay in memory.
    func suspend() {
        guard status == .live || status == .connecting, !suspended else { return }
        suspended = true
        if holdStartedAt != nil {
            socket?.send(Realtime.inputClear)
            holdStartedAt = nil; kidIsTalking = false; releaseTask?.cancel(); releaseTask = nil
            rtLog("background: hold ended, input cleared")
        }
        if responseActive || isSpeaking { interrupt() }
        silenceTask?.cancel(); gapTask?.cancel(); thinkingGap = false
        stopAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        rtLog("background: audio stopped, socket kept")
        #if DEBUG
        // `-PTDropOnBackground`: close the socket on background, to exercise the silent reconnect in the simulator.
        if ProcessInfo.processInfo.arguments.contains("-PTDropOnBackground") { socket?.close() }
        #endif
    }

    /// Foreground: true when the socket is still alive (a ping answers) and the audio is back; false when the app must
    /// reconnect (`connect(..., keepChat: true)` with the resume instructions).
    func resumeIfAlive() async -> Bool {
        guard suspended else { return isLive }
        suspended = false
        let alive = !socketDropped && socket != nil ? await socket!.ping() : false
        guard alive, status == .live else {
            rtLog("foreground: socket gone (dropped=\(socketDropped)), reconnect needed")
            return false
        }
        do { try startAudio(echoCancel: echoCancel) } catch { rtLog("foreground: audio restart failed: \(error.localizedDescription)"); return false }
        updateGate()
        rtLog("foreground: socket alive, audio restarted")
        startSilenceTimer()
        return true
    }

    /// After a silent reconnect: the writing beat already planned the props if they exist (no second beat), and the
    /// normal silence rules continue (no re-ask if the one reminder was already used).
    func resumed(propsPlanned planned: Bool) {
        propsPlanned = planned
        startSilenceTimer()
    }

    private func stopAudio() {
        mic.stop()
        speaker.stop()   // the engine, the mic tap on it, the player, the mouth and the speaking state
    }
    /// A response is running, a writing beat is on, or her reply is still due (live-test driver waits on this).
    var isBusy: Bool { gate.active || beatRunning || awaitingReply || reminderPending }

    // MARK: Lifecycle

    /// Connects, configures the session and starts the audio. Returns false (with `status = .failed`) on any problem.
    func connect(auth: RealtimeAuth, config: VoiceConfig, echoCancel: Bool = false,
                 instructions: String = Realtime.instructions, keepChat: Bool = false) async -> Bool {
        // Round 13: a socket opened on the start screen with exactly this voice + instructions is used as is.
        if let p = preparing { await p.value }
        let reuse = prepared.flatMap { p -> RealtimeSocket? in
            p.config == config && p.instructions == instructions && p.socket.firstError == nil
                && Date().timeIntervalSince(p.at) < 15 * 60 ? p.socket : nil
        }
        if reuse == nil { prepared?.socket.close() }
        prepared = nil
        disconnect()
        if !keepChat { chat.clear() }   // a silent reconnect (round 9) keeps the transcript
        self.echoCancel = echoCancel
        status = .connecting
        lastError = nil
        guard await AVAudioApplication.requestRecordPermission() else {
            reuse?.close()
            return fail("Microphone permission is off")
        }
        let socket: RealtimeSocket
        let ready: Bool
        if let reuse {
            socket = reuse; ready = true
            rtLog("connect: pre-connected socket reused")
        } else {
            // Relay mode: a fresh ephemeral secret for every connect (first, silent reconnect).
            guard let bearer = try? await auth.bearer() else { return fail("Couldn't get a voice session from the relay") }
            socket = Self.openSocket(bearer: bearer)
            socket.send(config.sessionUpdate(instructions: instructions))
            ready = await Self.waitReady(socket)
        }
        self.socket = socket
        guard ready else { return fail(socket.firstError ?? "Couldn't reach OpenAI Realtime") }

        speaker.configure(VoiceShape(method: config.method, cents: config.cents, rate: config.rate))
        connectedConfig = config
        rtLog("voice: \(config)")
        do { try startAudio(echoCancel: echoCancel) } catch { return fail("Audio: \(error.localizedDescription)") }
        status = .live
        #if DEBUG
        rtLog("live; voice processing: \(speaker.inputNode?.isVoiceProcessingEnabled ?? false) input: \(speaker.inputNode?.outputFormat(forBus: 0).description ?? "-")")
        #endif
        receiveTask = Task { [weak self] in
            for await text in socket.messages { await self?.receive(text) }
            await self?.socketClosed()
        }
        updateGate()
        return true
    }

    /// The voice of the live session (DEBUG check: a silent reconnect must use the same one).
    private(set) var connectedConfig: VoiceConfig?

    // MARK: Pre-connect (round 13: the greeting fires the moment "Let's play!" is tapped)

    private struct Prepared { let socket: RealtimeSocket; let config: VoiceConfig; let instructions: String; let at: Date }
    @ObservationIgnored private var prepared: Prepared?
    @ObservationIgnored private var preparing: Task<Void, Never>?

    /// Opens the socket and sends session.update (voice + instructions) while the start screen shows. No audio and no
    /// mic permission yet: `connect` with the same config and instructions picks it up.
    func preconnect(auth: RealtimeAuth, config: VoiceConfig, instructions: String) {
        guard status == .idle || { if case .failed = status { return true }; return false }(), preparing == nil else { return }
        if let p = prepared, p.config == config, p.instructions == instructions, p.socket.firstError == nil,
           Date().timeIntervalSince(p.at) < 10 * 60 { return }
        prepared?.socket.close(); prepared = nil
        preparing = Task { [weak self] in
            guard let bearer = try? await auth.bearer() else {
                self?.preparing = nil; rtLog("pre-connect: no voice session from the relay"); return
            }
            let socket = Self.openSocket(bearer: bearer)
            socket.send(config.sessionUpdate(instructions: instructions))
            let ok = await Self.waitReady(socket)
            guard let self else { socket.close(); return }
            self.preparing = nil
            if ok { self.prepared = Prepared(socket: socket, config: config, instructions: instructions, at: Date()); rtLog("pre-connect: ready (\(config))") }
            else { socket.close(); rtLog("pre-connect: failed (\(socket.firstError ?? "-"))") }
        }
    }


    /// `bearer` is the personal key (dev mode) or a relay-minted ephemeral client secret.
    private static func openSocket(bearer: String) -> RealtimeSocket {
        var req = URLRequest(url: Realtime.url())
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        return RealtimeSocket(request: req)
    }

    /// Waits for session.updated (or an error), at most 8 s.
    private static func waitReady(_ socket: RealtimeSocket) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { await socket.waitForReady() }
            group.addTask { try? await Task.sleep(for: .seconds(8)); return false }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    func disconnect() {
        receiveTask?.cancel(); receiveTask = nil
        socket?.close(); socket = nil
        stopAudio()
        suspended = false; socketDropped = false; reminderAwaitingEnd = false; reminderDoneAt = nil
        pendingOutputs = []; gate = ResponseGate()   // (the speaker was cleared by stopAudio)
        kidIsTalking = false
        holdStartedAt = nil; releaseTask?.cancel(); releaseTask = nil; audioItemID = nil; audioItemStart = nil; dropAudio = false
        silenceTask?.cancel(); huntMode = false; beatTask?.cancel(); beatTask = nil; beatRunning = false; propsPlanned = false; lastBeatAt = .distantPast
        gapTask?.cancel(); expressionTask?.cancel(); expression = nil; thinkingGap = false; awaitingReply = false
        reminderPending = false; reminderPlaying = false; propLinePending = false; echoPending = false; echoActive = false
        forcedTools = nil; silentAllowed = nil; silentPending = false; silentResponse = false; silentItems = []; quickReplyOnly = false
        speech = SpeechStop(); cancelThrough = 0; createdSeen = 0
        if status != .idle, case .failed = status {} else { status = .idle }
    }

    /// Nutmeg speaks first (greeting) without waiting for the kid.
    /// Round 7: today's game ideas go IN the greeting (one response), so the intro bubble carries the suggestions.
    func kickOff(games: [Suggestion] = []) {
        guard let socket, isLive else { return }
        let ideas = games.isEmpty ? "" : " with today's ideas as open sparks (\"You can pick anything! Maybe \(Suggestions.spoken(games))?\")"
        socket.send(Realtime.userText("(The kids just opened the app and can hear you now. They talk to you by holding the big red button. In ONE short turn: say hi in your own words, ask what they feel like playing,\(ideas), and tell them to hold the red button and tell you.)"))
        gate.newTurn()
        nextResponseNoTools = true   // round 13: the greeting speaks at once (a face-only tool call cost ~1.4 s)
        requestResponse()
    }

    /// Typed turn (keyboard fallback, simulator, demo safety).
    func sendText(_ text: String, itemID: String? = nil) {
        guard let socket, isLive, micWanted else { return }
        trace.beginOrKeep("typed")
        // Round 20 (Haylee): a typed turn stops her at once, like the mic (greeting, replies, app lines).
        if SpeechStop.kidTurnStops(responseActive: responseActive, playing: speaker.hasAudioQueued, inFlight: speech.active) {
            stopSpeaking("typed turn")
        }
        socket.send(Realtime.userText(text, id: itemID))
        chat.kidTyped(text)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTLive") { rtLog("KID: \(text)") }
        #endif
        kidTurnEnded()
        requestResponse()
    }

    /// Round 21: a typed turn that moderation flagged after it was sent: it leaves the conversation and the chat.
    func retractKidTurn(text: String, itemID: String) {
        socket?.send(Realtime.deleteItem(itemID))
        chat.retractKid(text)
    }

    /// Round 13: a tap on the prop card the app has ALREADY applied (the card changed at once). The kid's words go in
    /// the chat, the note tells her what happened. `requiring` = tools she still has to call first (the next prop is
    /// her pick: a cheap text-only pass); nil = she speaks straight away with no tools (one response).
    /// `speakWithTools` (round 19, the confirm step's Yes): she speaks at once but may still call tools (start_planning).
    func tapTurn(kidLine: String, note: String, requiring tools: [String]?, speakWithTools: Bool = false) {
        guard let socket, isLive, micWanted else { return }
        trace.beginOrKeep("tap")
        stopSpeaking("tap turn")
        socket.send(Realtime.userText(kidLine))
        chat.kidTyped(kidLine)
        socket.send(Realtime.systemNote(note))
        kidTurnEnded(tools: .some(tools))
        if tools == nil && !speakWithTools { nextResponseNoTools = true }
        requestResponse()
    }

    /// Speak a fixed line in Nutmeg's Realtime voice (kit ready, scene lines) without adding it to the chat.
    /// Only one in-conversation response may run at a time; ask again after the current one finishes.
    private func requestResponse() {
        // During a planning beat she's coloring silently; the beat's own result asks for her next turn.
        if beatRunning { return }
        // The kid is holding the mic: her reply waits for the release (which asks for it).
        if holdStartedAt != nil { return }
        guard gate.request() else { return }   // one is active: it follows on response.done if still owed
        if let tools = forcedTools {
            // Round 7: the kid's answer is handled by a tool FIRST; this response is silent (see onKidTurnTools).
            forcedTools = nil
            silentPending = true
            silentAllowed = tools
            // Round 20 (cost): the response keeps the session's one tools array (cached prefix); the step's tools are a
            // note after it, and the app refuses anything else this pass calls.
            socket?.send(Realtime.allowedToolsNote(tools))
            socket?.send(Realtime.responseCreate(requiring: tools))
            trace.mark("silent.create")
            rtLog("tool-first (silent, text-only) response: \(tools.joined(separator: ","))")
            return
        }
        let noTools = nextResponseNoTools
        nextResponseNoTools = false
        trace.mark("spoken.create")
        socket?.send(Realtime.responseCreateSpoken(tools: !noTools))
    }
    /// Round 13: the next spoken response gets no tools at all (greeting, a tap the app already handled).
    @ObservationIgnored private var nextResponseNoTools = false
    /// Round 13: latency of the current turn (release / send / tap → first audio heard), DEBUG log only.
    @ObservationIgnored private var trace = LatencyTrace()
    func beginTrace(_ kind: String) { trace.begin(kind) }
    /// Round 21: a named moment in the current turn's trace (DEBUG log only).
    func markTrace(_ name: String) { trace.mark(name) }

    // MARK: Push-to-talk

    /// The kid pressed the mic button: interrupt her if she's talking, then stream the mic until release.
    func beginTalk() {
        guard isLive, micWanted, holdStartedAt == nil else { return }
        releaseTask?.cancel(); releaseTask = nil
        if SpeechStop.kidTurnStops(responseActive: responseActive, playing: speaker.hasAudioQueued, inFlight: speech.active) {
            stopSpeaking("mic pressed")
        }
        silenceTask?.cancel()
        reminderDoneAt = nil
        holdStartedAt = Date()
        kidIsTalking = true
        rtLog("ptt: hold")
        updateGate()
    }

    /// The kid let go: a short tail keeps the last word, then commit + reply; a tap-length hold sends nothing.
    func endTalk() {
        guard let started = holdStartedAt else { return }
        let held = Date().timeIntervalSince(started)
        kidIsTalking = false
        trace.begin("voice")
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))   // the mic tap delivers ~50 ms chunks: catch the last one
            guard let self, !Task.isCancelled else { return }
            self.holdStartedAt = nil
            self.updateGate()
            self.releaseTask = nil
            guard let socket = self.socket, self.isLive else { return }
            if self.quickReplyOnly {
                // Kit being made: nothing to plan; one tiny line at most.
                socket.send(Realtime.inputClear)
                if !self.isSpeaking { self.say("Almost ready!") }
                rtLog("ptt: kit making, cleared + Almost ready")
                return
            }
            if held < Realtime.minHoldSeconds {
                socket.send(Realtime.inputClear)
                rtLog("ptt: too short (\(String(format: "%.2f", held)) s), cleared")
                self.startSilenceTimer()
                return
            }
            socket.send(Realtime.inputCommit)
            self.trace.mark("commit")
            rtLog("ptt: commit (\(String(format: "%.2f", held)) s) + response.create")
            self.kidTurnEnded()
            self.requestResponse()
        }
    }

    /// Stops her mid-sentence: cancel the response, silence the speaker, truncate her item at what was heard.
    private func interrupt(sendCancel: Bool = true) {
        if sendCancel && responseActive { socket?.send(Realtime.responseCancel); rtLog("ptt: response.cancel") }
        if let id = audioItemID, let start = audioItemStart {
            let ms = speaker.heardMs(itemStart: start)
            socket?.send(Realtime.truncate(itemID: id, audioEndMs: ms))
            rtLog("ptt: truncate at \(ms) ms")
        }
        audioItemID = nil; audioItemStart = nil
        dropAudio = true
        speaker.cancel()   // the player is cleared, the mouth resets, she stops speaking at once
        updateGate()
    }

    @ObservationIgnored private var lastSayAt = Date.distantPast
    /// Round 17: a Repeat (echo) line was sent / is the response playing now: its words stay out of the chat.
    @ObservationIgnored private var echoPending = false
    @ObservationIgnored private var echoActive = false
    /// Round 15: something is being said or is about to be (a response running, audio playing, or an app line sent in
    /// the last moment whose audio hasn't started): a new app line waits, so two lines never overlap.
    var voiceBusy: Bool { isSpeaking || gate.active || Date().timeIntervalSince(lastSayAt) < 1.5 }

    /// `thinking`: a kid is waiting on this line (a hand-off or Let's play! tap): show the thinking face + dots until it plays.
    /// `echo` (round 17, the pill's Repeat): a line she already said, said again: heard, but not a second chat bubble.
    func say(_ line: String, thinking: Bool = false, echo: Bool = false) {
        guard let socket, isLive, !suspended, !line.isEmpty else { return }
        if thinking { thinkingGap = true }
        if echo { echoPending = true } else { chat.breakTurn() }   // each app line (kit progress, ready line) is its own bubble
        if !trace.running { trace.begin("app line") }
        lastSayAt = Date()
        socket.send(Realtime.sayExactly(line))
        trace.mark("say.create")
    }

    /// Applies pitch changes right away (a method change takes effect on the next conversation).
    private func fail(_ reason: String) -> Bool {
        rtLog("failed: \(reason)")
        disconnect()
        lastError = reason
        status = .failed(reason)
        return false
    }

    private func socketClosed() {
        guard status == .live else { return }
        let reason = socket?.firstError ?? "Connection closed"
        if suspended {
            // Round 9: in the background a drop is only noted; the app reconnects silently on return.
            socketDropped = true
            rtLog("socket closed in background (\(reason)): reconnect on return")
            return
        }
        if onDropped?() == true {
            rtLog("socket closed (\(reason)): silent reconnect")
            return
        }
        _ = fail(reason)
    }

    // MARK: Audio

    private func startAudio(echoCancel: Bool) throws {
        try speaker.start(echoCancel: echoCancel) { [mic, socket] input in
            let inFormat = input.outputFormat(forBus: 0)
            if inFormat.sampleRate > 0 && inFormat.channelCount > 0 {
                mic.configure(from: inFormat, socket: socket)
                Self.installMicTap(on: input, format: inFormat, pump: mic)
            }
        }
    }

    private func updateGate() {
        // Push-to-talk: the mic only streams while the button is held (plus the short release tail).
        mic.open = isLive && micWanted && holdStartedAt != nil
    }

    // MARK: Expressions (decisions/conversation-camera-and-expressions.md)

    /// `tools`: nil = the step's usual tool-first rule; `.some(x)` = the caller decides (taps).
    private func kidTurnEnded(tools override: [String]?? = nil) {
        reminderDoneAt = nil; reminderAwaitingEnd = false
        if let note = noteForNextKidTurn { noteForNextKidTurn = nil; socket?.send(Realtime.systemNote(note)); rtLog("note: woke up") }
        gate.newTurn()
        if let override { forcedTools = override } else { forcedTools = onKidTurnTools?() }
        if override == nil, forcedTools == nil, let note = onPostPlanningTurn?() { socket?.send(Realtime.systemNote(note)) }
        awaitingReply = true; replyStarted = false
        nudgesThisTurn = 0; reasks = 0; silenceTask?.cancel()
        modelChoseExpression = false
        expressionTask?.cancel(); expression = nil
        gapTask?.cancel()
        // Round 13 (Haylee): she shows she's working on it from the moment the kid lets go (thinking face + typing
        // dots) until her first audio plays.
        thinkingGap = true
        rtLog("face thinking (gap)")
    }

    private func replyBegan() {
        guard !replyStarted else { return }
        replyStarted = true
        awaitingReply = false; gapTask?.cancel(); thinkingGap = false
    }

    private func setExpression(_ e: NutmegExpression, seconds: Double?, fromModel: Bool) {
        if fromModel { modelChoseExpression = true }
        rtLog("face \(e.rawValue)\(fromModel ? "" : " (blip)")")
        expression = e
        expressionSetAt = Date()
        expressionTask?.cancel()
        guard let seconds else { return }
        expressionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(1, seconds)))   // hold at least 1 s
            guard let self, !Task.isCancelled else { return }
            self.expression = nil
        }
    }

    /// After her turn, if the kids stay quiet ~20 s during planning (45 s in the hunt), ONE short "hold the red button"
    /// reminder (never the question again); then she waits for the kid.
    private func startSilenceTimer() {
        silenceTask?.cancel()
        let hunting = huntMode
        guard micWanted, reasks < 1 else { return }   // ONE short reminder per question, then quiet until the kid talks
        silenceTask = Task { [weak self] in
            var wait: Double = hunting ? 45 : 20
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-PTDozeFast") { wait = 4 }   // sleepy-Nutmeg check runs
            #endif
            try? await Task.sleep(for: .seconds(wait))   // push-to-talk: time to find the button   // the hunt takes a while: one gentle check-in
            guard let self, !Task.isCancelled, self.isLive, self.micWanted, !self.isSpeaking, self.holdStartedAt == nil,
                  !self.awaitingReply, !self.responseActive, !self.beatRunning, let line = self.onSilence?() else { return }
            // Round 7: a fixed out-of-band line in her voice; its own chat bubble.
            guard self.gate.request() else { return }
            self.chat.breakTurn()
            self.reasks += 1
            self.reminderPending = true
            rtLog("nudge: silence (fixed line, own chat bubble)")
            self.socket?.send(Realtime.sayExactly(line))
        }
    }

    // MARK: Events

    /// Round 19: every response is tracked by id, so a kid's tap can cancel all of them (conversation replies and app
    /// lines), and late audio or words from a cancelled one never play or reach the chat.
    @ObservationIgnored private var speech = SpeechStop()
    /// response.create events sent before the last stop whose response.created hasn't arrived yet are cancelled on arrival.
    @ObservationIgnored private var cancelThrough = 0
    @ObservationIgnored private var createdSeen = 0
    @ObservationIgnored private var stopAt = Date.distantPast

    /// Round 20: token counts from every response.done (never content), for the prompt-cache check.
    @ObservationIgnored private(set) var usageTotals = RealtimeUsageTotals()

    private func receive(_ text: String) async {
        let id = Realtime.responseID(text)
        let event = Realtime.parse(text)
        if event == .responseDone, let u = RealtimeUsage.parse(text) {
            usageTotals.add(u)
            rtLog("USAGE #\(usageTotals.responses): \(u.line); session in \(usageTotals.input), cached \(usageTotals.cached) "
                  + String(format: "(%.0f%%)", usageTotals.cachedShare * 100))
        }
        if event == .responseCreated {
            createdSeen += 1
            if createdSeen <= cancelThrough, Date().timeIntervalSince(stopAt) < 4, let id {
                // Asked for before the kid moved on (e.g. a cheer already sent): cancel it the moment it exists.
                speech.created(id)
                for c in speech.cancelAll() { socket?.send(Realtime.responseCancel(id: c)) }
                rtLog("stop: a line asked for before the tap was cancelled on arrival")
            } else {
                speech.created(id)
            }
        }
        if speech.drops(event, responseID: id) { return }
        if event == .responseDone { speech.done(id) }
        await handle(event)
    }

    /// Round 19 (Haylee): the kid moved on (a tap that advances or changes the screen). Her current speech stops at once:
    /// every in-flight response is cancelled, the local player is cleared, her line is cut at what was heard (and marked
    /// "…" in the chat), and pending reminder/repeat lines are dropped. The newest line is whatever the app says next.
    func stopSpeaking(_ reason: String) {
        guard let socket, status == .live else { return }
        let wasSpeaking = speaker.hasAudioQueued
        let ids = speech.cancelAll()
        for id in ids { socket.send(Realtime.responseCancel(id: id)) }
        cancelThrough = socket.createsSent
        stopAt = Date()
        interrupt(sendCancel: false)
        reminderPending = false; echoPending = false; echoActive = false
        lastSayAt = .distantPast
        thinkingGap = false; gapTask?.cancel()
        if wasSpeaking { chat.cutOff() } else { chat.breakTurn() }
        rtLog("stop (\(reason)): \(ids.count) response(s) cancelled, speaker cleared\(wasSpeaking ? ", line cut" : "")")
    }

    private func handle(_ event: Realtime.Event) async {
        #if DEBUG   // event kinds only (no audio, no transcripts): live-test diagnostics in the simulator console
        switch event {
        case .audioDelta, .transcriptDelta, .other: break
        case .functionCall(let name, _, _): rtLog("call \(name)"); trace.mark("tool \(name)")
        case .transcriptDone(let t):
            // Live tests only (typed turns): her words in the console for the transcript samples.
            if ProcessInfo.processInfo.arguments.contains("-PTLive") { rtLog(silentResponse ? "SILENT (never played, not in chat): \(t)" : "NUTMEG: \(t)") } else { rtLog("said a line") }
        default: rtLog("\(event)")
        }
        #endif
        switch event {
        case .audioDelta where dropAudio || holdStartedAt != nil || silentResponse || suspended || !speaker.isRunning:
            break   // the kid interrupted this response (or is holding the mic): never play it
        case .audioDelta(let data):
            if audioItemStart == nil { audioItemStart = speaker.itemStart() }
            gate.spoke()
            responseHadAudio = true
            audioResponseSerial = responseSerial
            silenceTask?.cancel()
            if !reminderPlaying { reminderDoneAt = nil; reminderAwaitingEnd = false }
            replyBegan()
            thinkingGap = false
            if trace.running && !trace.has("first delta") { trace.mark("first delta") }
            speaker.play(data)
        case .transcriptDelta where silentResponse, .transcriptDone where silentResponse:
            break   // the silent tool-first response: its words were never heard, so never in the chat
        case .outputItemAdded(let id) where silentResponse:
            silentItems.append(id)
        case .transcriptDelta where echoActive, .transcriptDone where echoActive:
            break   // round 17: a repeat of a line already in the chat (no duplicate bubble)
        case .outputItemAdded where reminderPlaying || echoActive:
            audioItemID = nil; audioItemStart = nil   // out of band: nothing in the conversation to truncate
        case .transcriptDelta where !modelChoseExpression && expression == nil:
            chat.apply(event)
            // Only the first few characters of her reply count ("Ooh!", "Wow,", "Yes!").
            let line = chat.lines.last(where: \.fromNutmeg)?.text ?? ""
            if line.count >= 3, line.count <= 14, let blip = NutmegExpression.blip(forReplyStart: line) {
                setExpression(blip, seconds: 1.2, fromModel: false)
            }
        case .kidTranscript(let text):
            chat.apply(event)
            onKidTranscript?(text)   // round 19: the app's local safety check on what the kid said
        case .transcriptDelta, .transcriptDone:
            // Out-of-band lines (sayExactly: kit ready, scene lines) also stream here; they're Nutmeg's words too.
            chat.apply(event)
        case .outputItemAdded(let id):
            audioItemID = id; audioItemStart = nil
        case .functionCall(let name, let callID, let args) where name == "start_planning":
            // Writing moment (round 5): she writes on her clipboard; the result waits for the beat (the pause is natural).
            let topic = (try? JSONSerialization.jsonObject(with: Data(args.utf8)) as? [String: Any])?["topic"] as? String ?? "props"
            // Props are planned ONCE (before the first prop, Haylee); a repeat call returns at once, no beat.
            if topic != "props" || !propsPlanned { startBeat(topic) }
            pendingOutputs.append((callID, topic == "roles" || !propsPlanned
                ? "You wrote the roles and the prop list on your clipboard. Look up, call set_roles, then show_next_prop "
                    + "for the first prop, then announce both in ONE turn (no \"Sound good?\")."
                : "Your prop list is already planned. Call show_next_prop now."))
        case .functionCall(let name, _, _) where !beatRunning && !propsPlanned
                && (name == "set_roles" || name == "show_next_prop"):
            // (Round 7: only if no beat ran yet this adventure: a second beat after the first made the writing flicker.)
            // She skipped start_planning: the app still runs the writing beat (EVERY planning moment, Haylee), holding
            // this call's result until it ends. Then handle the call as usual.
            startBeat(name == "set_roles" ? "roles" : "props")
            await handle(event)   // beatRunning is set now, so this lands in the generic case below
        case .functionCall(let name, let callID, let args) where name == "set_expression":
            // Silent and instant: never waits on the app, never blocks audio.
            if let d = NutmegExpression.decode(name: name, arguments: args) { setExpression(d.expression, seconds: d.seconds, fromModel: true) }
            pendingOutputs.append((callID, "ok"))   // never asks for a response by itself
        case .functionCall(let name, let callID, _) where silentResponse && !(silentAllowed?.contains(name) ?? true):
            // Round 20: every response now offers the whole tools array, so the step rule lives here.
            rtLog("silent pass: off-step \(name) refused")
            pendingOutputs.append((callID, Realtime.offStepOutput(name, allowed: silentAllowed ?? [])))
            gate.toolCalled()
        case .functionCall(let name, let callID, let args):
            let result = await onCall?(name, args) ?? (output: "ok", respond: true)
            // She already spoke before the tool (against the instructions): the follow-up must not react again, so the
            // two parts read as ONE reply (the chat panel joins them into one bubble).
            let spokeFirst = responseHadAudio
            pendingOutputs.append((callID, result.output + Realtime.outputSuffix(name: name, output: result.output, spokeFirst: spokeFirst)))
            if result.respond { gate.toolCalled() } else { gate.endTurn() }   // finish_planning: she stops talking   // a real step tool: her next words must follow its output
        case .responseCreated:
            if reminderPending { reminderPending = false; reminderPlaying = true }
            if silentPending { silentPending = false; silentResponse = true; silentItems = [] }
            echoActive = echoPending; echoPending = false   // round 17: only the response the repeat asked for
            trace.mark(silentResponse ? "silent.created" : "created")
            gate.created()
            dropAudio = false
            responseHadAudio = false
            responseSerial += 1
            responseLineStart = chat.lines.count
        case .responseDone where gate.deferredTurn && beatTask == nil:
            // Round 15 (Haylee: a second "Don't have it" got no reply): this is the OLD turn's response, cancelled by a
            // tap / typed line that arrived while it was still running. Close it out, then ask for the new turn's reply
            // (its tool-first pass if the tap set one); the interrupt would otherwise block that follow-up for good.
            if silentResponse {
                silentResponse = false
                for id in silentItems { socket?.send(Realtime.deleteItem(id)) }
                silentItems = []
            }
            reminderPlaying = false
            if !pendingOutputs.isEmpty, let socket {
                for (id, out) in pendingOutputs { socket.send(Realtime.functionOutput(callID: id, output: out)) }
                pendingOutputs = []
            }
            _ = gate.takeDeferredTurn()
            rtLog("deferred turn: the interrupted response is done, asking for the new turn's reply")
            requestResponse()
        case .responseDone where silentResponse:
            // Nobody heard it: cut its audio items to 0 ms, send the tool outputs, then her real (spoken) reply.
            silentResponse = false
            // Round 13: the pass is text-only, so its (unheard) words are deleted from the conversation.
            for id in silentItems { socket?.send(Realtime.deleteItem(id)) }
            silentItems = []
            silentTurnDone()
            if !gate.active { thinkingGap = false }   // her turn ended without a reply (finish_planning, start_play)
        case .responseDone where reminderPlaying:
            // The spoken-only reminder ended: no turn check, no follow-up unless the kid asked meanwhile.
            reminderPlaying = false
            reminderAwaitingEnd = true   // sleepy Nutmeg's clock starts when its audio has finished (round 9)
            chat.breakTurn()   // her next reply starts its own bubble too
            if gate.done(allowFollowUp: holdStartedAt == nil && !beatRunning) { socket?.send(Realtime.responseCreateSpoken()) }
        case .responseDone:
            if let beat = beatTask {
                _ = gate.done(allowFollowUp: false)
                // The pending result IS the pause: send it (and let her continue) only when the coloring beat ends.
                beatTask = nil
                let outs = pendingOutputs; pendingOutputs = []
                Task { [weak self] in
                    await beat.value
                    guard let self, let socket = self.socket else { return }
                    for (id, out) in outs { socket.send(Realtime.functionOutput(callID: id, output: out)) }
                    self.beatRunning = false
                    self.chat.breakTurn()   // speech after the writing moment is its own bubble (round 7)
                    self.gate.forceFollowUp()   // announcing the plan is this turn's answer
                    self.requestResponse()
                }
                return
            }
            if !pendingOutputs.isEmpty, let socket {
                for (id, out) in pendingOutputs { socket.send(Realtime.functionOutput(callID: id, output: out)) }
                pendingOutputs = []
            }
            if propLinePending && responseHadAudio && !dropAudio && holdStartedAt == nil {
                _ = gate.done(allowFollowUp: false)
                if propLineSerial < responseSerial {
                    rtLog("prop line: roles spoken, waiting for playback to end")
                    startPropLine()
                } else {
                    // She spoke before the tools in the same response (narration): now the roles only, then the prop.
                    socket?.send(Realtime.systemNote("(Silent coaching, don't mention it.) Now announce ONLY the roles in "
                        + "one or two excited sentences. Don't mention any prop yet, don't ask anything, no narration."))
                    gate.continueTurn()
                    requestResponse()
                }
                return
            }
            // One follow-up when this kid turn hasn't spoken yet (tools / face only so far), or (round 7) when she
            // spoke, called a step tool, and her words didn't finish the step ("let me grab the next prop." + mark_found).
            // Never while the mic is held or after an interrupt: the release asks.
            let canCheck = responseHadAudio && !dropAudio && holdStartedAt == nil && nudgesThisTurn < 1
            // Her latest line (a late kid transcript can land after it, so not simply the last line).
            let check = canCheck ? chat.lines.last(where: \.fromNutmeg).flatMap { onTurnDone?($0.text) } : nil
            let toolAfterSpeech = gate.toolThisResponse && gate.turnSpoke
            let followUp = gate.done(allowFollowUp: holdStartedAt == nil && !dropAudio && !beatRunning,
                                     spokenTurnIncomplete: check?.complete == true)
            #if DEBUG
            rtLog("turn check: followUp=\(followUp) audio=\(responseHadAudio) spoke=\(gate.turnSpoke) toolAfterSpeech=\(toolAfterSpeech)")
            #endif
            if followUp {
                if toolAfterSpeech, let check {
                    nudgesThisTurn += 1
                    socket?.send(Realtime.systemNote(check.note))
                    gate.continueTurn()   // a silent tool-only continuation still gets its spoken reply
                    rtLog("nudge: spoke then called a tool, turn unfinished: one continuation")
                }
                socket?.send(Realtime.responseCreateSpoken())
            }
            else if let check {
                nudgesThisTurn += 1
                socket?.send(Realtime.systemNote(check.note))
                if check.complete {
                    // No question and no instruction at all: ONE short continuation of the same turn (only the missing
                    // question; the note forbids repeating). Anything else is a silent note for her next turn: a
                    // follow-up there made her repeat the question 2-3 times (round 6).
                    rtLog("nudge: turn incomplete, one continuation")
                    gate.forceFollowUp()
                    requestResponse()
                } else {
                    rtLog("nudge: turn ending (silent, next turn)")
                }
            }
            if !gate.active && !responseHadAudio { thinkingGap = false }   // nothing more is coming this turn
        case .error(let message):
            lastError = message
        default: break
        }
    }

    // MARK: Off-main helpers

    nonisolated private static func installMicTap(on input: AVAudioInputNode, format: AVAudioFormat, pump: MicPump) {
        input.installTap(onBus: 0, bufferSize: 2400, format: format) { buffer, _ in pump.push(buffer) }
    }
}

/// Round D3a: her fixed app lines go out as `sayExactly` (the speaker's live voice).
extension RealtimeSession: NutmegLiveVoice {}

/// Converts mic buffers to 24 kHz mono PCM16 and sends them while the gate is open. Runs on the audio thread.
final class MicPump: @unchecked Sendable {
    private let lock = NSLock()
    private var _open = false
    private var converter: AVAudioConverter?
    private weak var socket: RealtimeSocket?
    private let outFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Realtime.sampleRate, channels: 1, interleaved: true)!

    var open: Bool {
        get { lock.withLock { _open } }
        set { lock.withLock { _open = newValue } }
    }

    func configure(from format: AVAudioFormat, socket: RealtimeSocket?) {
        lock.withLock {
            converter = AVAudioConverter(from: format, to: outFormat)
            self.socket = socket
        }
    }

    func stop() { lock.withLock { _open = false; converter = nil; socket = nil } }

    func push(_ buffer: AVAudioPCMBuffer) {
        let (isOpen, converter, socket) = lock.withLock { (_open, self.converter, self.socket) }
        guard isOpen, let converter, let socket else { return }
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0, let ch = out.int16ChannelData?[0] else { return }
        let data = Data(bytes: ch, count: Int(out.frameLength) * 2)
        socket.send(Realtime.appendAudio(data))
    }
}

/// Thin thread-safe wrapper around URLSessionWebSocketTask: JSON out, text messages in as an AsyncStream.
final class RealtimeSocket: @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let lock = NSLock()
    private var _ready = false
    private var _firstError: String?
    private var readyWaiters: [CheckedContinuation<Bool, Never>] = []
    let messages: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    var firstError: String? { lock.withLock { _firstError } }

    init(request: URLRequest) {
        task = URLSession.shared.webSocketTask(with: request)
        task.maximumMessageSize = 16 * 1024 * 1024
        (messages, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .unbounded)
        task.resume()
        receive()
    }

    /// Round 19: how many response.create events were sent (a stop cancels the ones still on their way).
    var createsSent: Int { lock.withLock { _creates } }
    private var _creates = 0

    func send(_ obj: [String: Any]) {
        if obj["type"] as? String == "response.create" { lock.withLock { _creates += 1 } }
        task.send(.string(Realtime.json(obj))) { [weak self] error in
            if let error { self?.noteError(error.localizedDescription) }
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
        continuation.finish()
        resolveReady(false)
    }

    /// Round 9: is the socket still alive after the app was in the background? (a pong within 3 s)
    func ping() async -> Bool {
        final class Once: @unchecked Sendable {
            private let lock = NSLock(); private var done = false
            func claim() -> Bool { lock.withLock { if done { return false }; done = true; return true } }
        }
        let once = Once()
        return await withCheckedContinuation { c in
            task.sendPing { error in if once.claim() { c.resume(returning: error == nil) } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { if once.claim() { c.resume(returning: false) } }
        }
    }

    func waitForReady() async -> Bool {
        await withCheckedContinuation { c in
            let state: Bool? = lock.withLock {
                if _ready { return true }
                if _firstError != nil { return false }
                readyWaiters.append(c); return nil
            }
            if let state { c.resume(returning: state) }
        }
    }

    private func receive() {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                var text: String?
                switch message {
                case .string(let s): text = s
                case .data(let d): text = String(data: d, encoding: .utf8)
                @unknown default: break
                }
                if let text {
                    let event = Realtime.parse(text)
                    if event == .sessionReady { self.resolveReady(true) }
                    if case .error(let m) = event, !self.isReady { self.noteError(m) }
                    self.continuation.yield(text)
                }
                self.receive()
            case .failure(let error):
                self.noteError(error.localizedDescription)
                self.continuation.finish()
            }
        }
    }

    private var isReady: Bool { lock.withLock { _ready } }

    private func noteError(_ m: String) {
        lock.withLock { if _firstError == nil { _firstError = m } }
        resolveReady(false)
    }

    private func resolveReady(_ ok: Bool) {
        let waiters: [CheckedContinuation<Bool, Never>] = lock.withLock {
            if ok { _ready = true }
            let w = readyWaiters; readyWaiters = []; return w
        }
        waiters.forEach { $0.resume(returning: ok) }
    }
}

/// DEBUG-only diagnostics (event kinds and errors; never audio or transcripts).
func rtLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    NSLog("[RT] %@", message())
    #endif
}

/// Nutmeg's on-device pitch shaping (D7, revised in conversation-voice.md).
struct VoiceShape: Equatable {
    var method: Realtime.PitchMethod = Realtime.defaultPitchMethod
    var cents: Double = Realtime.defaultPitchCents
    var rate: Double = Realtime.defaultVarispeedRate
}


/// Round 13: one turn's timing, from the kid's release / send / tap (or an app line) to the first sample heard.
/// DEBUG log only ("LAT voice: commit +0.12 s, silent.create +0.12 s, ...").
struct LatencyTrace {
    private(set) var kind = ""
    private var t0: Double?
    private var marks: [(String, Double)] = []
    var running: Bool { t0 != nil }
    mutating func begin(_ kind: String) { self.kind = kind; t0 = CACurrentMediaTime(); marks = [] }
    /// Round 21: keep a trace the app began moments ago (at the send / tap itself, before any local work), else begin.
    mutating func beginOrKeep(_ kind: String, within seconds: Double = 3) {
        if let t0, self.kind == kind, CACurrentMediaTime() - t0 < seconds, !has("heard") { mark("sent"); return }
        begin(kind)
    }
    mutating func mark(_ name: String, at time: Double = CACurrentMediaTime()) {
        guard t0 != nil, marks.count < 24 else { return }
        marks.append((name, time))
    }
    func has(_ name: String) -> Bool { marks.contains { $0.0 == name } }
    mutating func end() { t0 = nil; marks = [] }
    func summary() -> String {
        guard let t0 else { return "LAT -" }
        return "LAT \(kind): " + marks.map { "\($0.0) +\(String(format: "%.2f", $0.1 - t0)) s" }.joined(separator: ", ")
    }
}
