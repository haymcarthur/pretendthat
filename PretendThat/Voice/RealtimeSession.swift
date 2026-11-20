import AVFoundation
import Observation
import os
import QuartzCore
import NutmegCore

/// Hands-free voice conversation with Nutmeg over OpenAI's Realtime API (decisions D1, D2, D7).
/// WebSocket (URLSessionWebSocketTask) + AVAudioEngine, no third-party code.
/// - Mic (push-to-talk, decisions/2026-11-13-push-to-talk.md; round 31, decisions/2026-11-16-on-device-speech.md): the
///   kid's audio NEVER leaves the iPad. The input node feeds `KidSpeechCapture` (pre-warmed for the whole game); while
///   the red mic is held (`beginTalk` / `endTalk`) it is turned into words ON THE DEVICE (Apple Speech, on-device only).
///   Release → the final words, the audio dropped at once → names scrubbed + the safety gate (`onSpokenWords`, the app)
///   → ONE text item + `response.create`. A hold under `Realtime.minHoldSeconds` sends nothing. Pressing while Nutmeg
///   talks interrupts her: `response.cancel`, playback stops, and her item is truncated at what was actually heard.
///   No audio-upload client event exists any more, and the session asks for no server transcription.
/// - Speaker (round D3a): playing her voice lives in `NutmegSpeaker` (owned by `AppModel`, shared engine): PCM16
///   deltas → player node → pitch unit (Varispeed 1.20) → mixer, the lip sync (`LipSyncAnalyzer` + `MouthShaper`,
///   each window stamped with when it leaves the speaker), the speaking state and the barge-in clear. This session
///   keeps the socket and the protocol (responses, tools, the cached prefix, `SpeechStop`) and hands it the audio.
///   `level`, `mouth` and `isSpeaking` here read the speaker.
/// - Voice-processing IO (echo cancellation) is OFF by default: on iOS it runs on the whole IO unit, so it also
///   processes (and dulls/ducks) the OUTPUT. The mic is gated while Nutmeg talks, so she never hears herself anyway.
/// Recording (round D3b, §D4.1): ONLY the app's own scripted lines, sent with `sayExactly` and a metadata tag, are
/// captured (`ClipRecorder`): her output audio for that response, kept with the game only if her transcript matches the
/// script. The kid's mic audio is never recorded (the recorder can't see the mic path), nor her conversational replies,
/// nor any transcript. Everything else is sent or played and dropped.
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
    func debugSeedTranscript(_ turns: [String], replace: Bool = false) {
        if replace { chat.clear() }
        for (i, t) in turns.enumerated() { _ = chat.apply(i % 2 == 0 ? .transcriptDone(t) : .kidTranscript(t)) }
    }
    /// Her line as its own bubble (demo mode: no voice, so nothing streams in).
    func debugAppendNutmeg(_ text: String) { chat.breakTurn(); _ = chat.apply(.transcriptDone(text)) }
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
    /// Round 31: the on-device speech capture fed by the shared engine's input (words only ever leave it).
    @ObservationIgnored let capture = KidSpeechCapture()
    /// Round 31: the words of a finished hold (on-device, name-scrubbed): the app screens them and sends them with
    /// `sendText(_:itemID:kind:)` ("voice"). nil = sent straight away (tests).
    @ObservationIgnored var onSpokenWords: (@MainActor (String) -> Void)?
    @ObservationIgnored private var pendingOutputs: [(String, String)] = []
    /// Exactly one spoken reply per kid turn, never two responses at once (NutmegCore `ResponseGate`, round 6).
    @ObservationIgnored private var gate = ResponseGate()
    private var responseActive: Bool { gate.active }
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    /// Round 39: her reply to the kid's turn is still due (`ReplyWait`: cleared when her audio starts OR when a response
    /// ends with nothing more requested, e.g. a tool-only "found it" pass where the app says the next prop line).
    @ObservationIgnored private var replyWait = ReplyWait()
    private var awaitingReply: Bool { replyWait.due }
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
            // Round 34: an empty note = the app said the first prop line itself (nothing to ask her for).
            if note.isEmpty { rtLog("prop line: card shown, the app says the first prop line"); return }
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
            capture.cancel()   // round 31: the words and the audio are dropped, nothing sent
            holdStartedAt = nil; kidIsTalking = false; releaseTask?.cancel(); releaseTask = nil
            rtLog("background: hold ended, nothing sent")
        }
        if responseActive || isSpeaking { interrupt() }
        silenceTask?.cancel(); gapTask?.cancel(); thinkingGap = false
        watchdog.disarm()
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
        // 2026-11-18 (device testing: taps and the mic did nothing after a lock): nothing from before the lock may
        // stay "on". A hold or a release still finishing, the thinking dots, a reminder that never played.
        clearAwayState()
        let alive = !socketDropped && socket != nil ? await socket!.ping() : false
        // 2026-11-20: locked again while the ping ran: stay asleep (no audio in the background); the app resumes again
        // when it is back in the foreground (`ResumeLoop`).
        guard !suspended else { voiceLog("foreground: back in the background during the ping, still suspended"); return false }
        guard alive, status == .live else {
            rtLog("foreground: socket gone (dropped=\(socketDropped)), reconnect needed")
            return false
        }
        do { try startAudio(echoCancel: echoCancel) } catch { rtLog("foreground: audio restart failed: \(error.localizedDescription)"); return false }
        health.reset()
        updateGate()
        rtLog("foreground: socket alive, audio restarted")
        startSilenceTimer()
        return true
    }

    /// 2026-11-18: the kid's words were handled on the device (the saved-game question): no reply is coming, so the
    /// thinking face and dots end now.
    func endThinking() { thinkingGap = false; gapTask?.cancel() }

    /// Per-turn state that can't carry over a background: the kid's hold, a release still being finished, the
    /// thinking gap, a reminder that was asked for but never played. The game's state is untouched.
    private func clearAwayState() {
        if holdStartedAt != nil || releaseTask != nil {
            capture.cancel()
            holdStartedAt = nil; releaseTask?.cancel(); releaseTask = nil
            rtLog("foreground: an unfinished hold was cleared")
        }
        kidIsTalking = false
        thinkingGap = false; gapTask?.cancel()
        if reminderPending && !reminderPlaying { reminderPending = false }
    }

    // MARK: Keepalive (2026-11-18, device testing)

    /// A ping every `SocketHealth.interval` s while the app is in the foreground: a socket that silently died while
    /// the phone sat idle (Wi-Fi / NAT drop, never reported) is closed after two missed pongs, so the normal drop path
    /// reconnects silently BEFORE the kids' next tap or mic press goes into a dead socket.
    @ObservationIgnored private var health = SocketHealth()
    @ObservationIgnored private var keepaliveTask: Task<Void, Never>?

    private func startKeepalive() {
        keepaliveTask?.cancel()
        health.reset()
        keepaliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(SocketHealth.interval))
                guard let self, !Task.isCancelled else { return }
                await self.pingLineSocket()   // 2026-11-20: the fixed-lines session too
                guard self.isLive, !self.suspended, let socket = self.socket else { continue }
                let ok = await socket.ping()
                guard !Task.isCancelled, socket === self.socket, !self.suspended else { continue }
                if self.health.pinged(ok: ok) {
                    rtLog("keepalive: \(SocketHealth.maxMissed) pongs missed, the socket is dead: closing it (silent reconnect)")
                    self.health.reset()
                    socket.close()   // the receive loop ends → socketClosed → onDropped → the app reconnects silently
                } else if !ok {
                    rtLog("keepalive: a pong was missed")
                }
            }
        }
    }

    /// After a silent reconnect: the writing beat already planned the props if they exist (no second beat), and the
    /// normal silence rules continue (no re-ask if the one reminder was already used).
    func resumed(propsPlanned planned: Bool) {
        propsPlanned = planned
        startSilenceTimer()
    }

    private func stopAudio() {
        capture.cancel(); capture.clearPreRoll()
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
            socket.send(VoiceSessionPlan.conversation(config, instructions: instructions).sessionUpdate)
            ready = await Self.waitReady(socket)
        }
        self.socket = socket
        guard ready else { return fail(socket.firstError ?? "Couldn't reach OpenAI Realtime") }

        speaker.configure(VoiceShape(method: config.method, cents: config.cents, rate: config.rate, shift: config.pitchShift))
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
        lineArgs = (auth, config, instructions)
        await openLineSocket(auth: auth, config: config, instructions: instructions)   // round 35 prep: flag, default off
        updateGate()
        startKeepalive()
        if suspended {
            // 2026-11-20: the app went to the background while this connect ran: the socket stays, the audio stops,
            // and the foreground resumes it (`ForegroundRecovery` → resume).
            stopAudio()
            voiceLog("connect: finished in the background, audio stopped until the app is back")
        }
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
            socket.send(VoiceSessionPlan.conversation(config, instructions: instructions).sessionUpdate)
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
        keepaliveTask?.cancel(); keepaliveTask = nil
        receiveTask?.cancel(); receiveTask = nil
        socket?.close(); socket = nil
        lineTask?.cancel(); lineTask = nil; lineSocket?.close(); lineSocket = nil
        lineReopenTask?.cancel(); lineReopenTask = nil; lineArgs = nil
        lineHealth.reset(); linePings.reset(); lineSends = [:]; lineResponseIDs = []
        watchdog.disarm(); watchdogLine = nil
        stopAudio()
        suspended = false; socketDropped = false; reminderAwaitingEnd = false; reminderDoneAt = nil
        pendingOutputs = []; gate = ResponseGate()   // (the speaker was cleared by stopAudio)
        kidIsTalking = false
        holdStartedAt = nil; releaseTask?.cancel(); releaseTask = nil; audioItemID = nil; audioItemStart = nil; dropAudio = false
        silenceTask?.cancel(); huntMode = false; beatTask?.cancel(); beatTask = nil; beatRunning = false; propsPlanned = false; lastBeatAt = .distantPast
        gapTask?.cancel(); expressionTask?.cancel(); expression = nil; thinkingGap = false; replyWait.reset()
        reminderPending = false; reminderPlaying = false; propLinePending = false; echoPending = false; echoActive = false
        forcedTools = nil; silentAllowed = nil; silentPending = false; silentResponse = false; silentItems = []; quickReplyOnly = false
        speech = SpeechStop()
        recorder = ClipRecorder()   // round D3b: a half-recorded line is dropped with the session
        if status != .idle, case .failed = status {} else { status = .idle }
    }

    /// Nutmeg speaks first (greeting) without waiting for the kid.
    /// Round 7: today's game ideas go IN the greeting (one response), so the intro bubble carries the suggestions.
    /// Round 33: `greetingClip` = the seconds of the greeting clip that just played (the new short opening); nil = the
    /// old opening (she says hi in her own words). Either way the first spoken response's length is logged.
    func kickOff(games: [Suggestion] = [], greetingClip: Double? = nil, returning: Bool = false) {
        guard let socket, isLive else { return }
        let ideas = games.isEmpty ? "" : " with today's ideas as open sparks (\"You can pick anything! Maybe \(Suggestions.spoken(games))?\")"
        if let greetingClip {
            // Round 34: a returning greeting clip already asked the question: she only offers the ideas (round 42: all 3).
            socket.send(Realtime.userText(GameGreeting.kickOffNote(ideas: Suggestions.spoken(games), returning: returning)))   // round 42: all three ideas
        } else {
            socket.send(Realtime.userText("(The kids just opened the app and can hear you now. They talk to you by holding the big red button. In ONE short turn: say hi in your own words, ask what they feel like playing,\(ideas), and tell them to hold the red button and tell you.)"))
        }
        greetingMeasure = (clip: greetingClip ?? 0, bytes: 0)
        gate.newTurn()
        nextResponseNoTools = true   // round 13: the greeting speaks at once (a face-only tool call cost ~1.4 s)
        requestResponse()
    }

    /// Typed turn (keyboard fallback, simulator, demo safety), or round 31's SPOKEN turn (`kind` "voice": the words the
    /// iPad heard, name-scrubbed and screened). Both are one text item.
    func sendText(_ text: String, itemID: String? = nil, kind: String = "typed") {
        guard let socket, isLive, micWanted else { return }
        trace.beginOrKeep(kind)
        // Round 20 (Haylee): a typed turn stops her at once, like the mic (greeting, replies, app lines).
        if SpeechStop.kidTurnStops(responseActive: responseActive, playing: speaker.hasAudioQueued, inFlight: speech.active) {
            stopSpeaking("typed turn")
        }
        for e in kind == "voice" ? Realtime.kidSpokenTurn(text, id: itemID) : [Realtime.userText(text, id: itemID)] { socket.send(e) }
        chat.kidTyped(text)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTLive") { rtLog("KID (\(kind)): \(text)") }
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
    /// Round 33: the opening's length (clip seconds + the first spoken response's audio bytes), logged once.
    @ObservationIgnored private var greetingMeasure: (clip: Double, bytes: Int)?
    /// Round 13: latency of the current turn (release / send / tap → first audio heard), DEBUG log only.
    @ObservationIgnored private var trace = LatencyTrace()
    func beginTrace(_ kind: String) { trace.begin(kind) }
    /// Round 21: a named moment in the current turn's trace (DEBUG log only).
    func markTrace(_ name: String) { trace.mark(name) }

    // MARK: Push-to-talk

    /// The kid pressed the mic button: interrupt her if she's talking, then listen ON THE iPAD until release.
    /// `touchHost`: the touch's own timestamp, so the capture keeps the audio from that moment (the pre-roll).
    func beginTalk(touchHost: Double = CACurrentMediaTime()) {
        guard isLive, micWanted else { return }
        guard holdStartedAt == nil else { rtLog("ptt: pressed while the last turn is still being finished (ignored)"); return }
        releaseTask?.cancel(); releaseTask = nil
        if SpeechStop.kidTurnStops(responseActive: responseActive, playing: speaker.hasAudioQueued, inFlight: speech.active) {
            stopSpeaking("mic pressed")
        }
        silenceTask?.cancel()
        reminderDoneAt = nil
        holdStartedAt = Date()
        kidIsTalking = true
        capture.begin(touchHost: touchHost)
        rtLog("ptt: hold (on-device listening)")
        updateGate()
    }

    /// The kid let go: a short tail keeps the last word, then the iPad finishes the words (the audio is dropped), and
    /// only the words go on (`onSpokenWords`: scrubbed + screened by the app, then `sendText(kind: "voice")`).
    /// A tap-length hold sends nothing.
    func endTalk() {
        guard let started = holdStartedAt, releaseTask == nil else { return }
        let held = Date().timeIntervalSince(started)
        kidIsTalking = false
        trace.begin("voice")
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))   // the mic tap delivers ~50 ms chunks: catch the last one
            guard let self, !Task.isCancelled else { return }
            let quick = self.quickReplyOnly
            let words: String
            if held < Realtime.minHoldSeconds || quick {
                self.capture.cancel(); words = ""
            } else {
                self.thinkingGap = true   // she's working on it from the release (the words, then her reply)
                words = await self.capture.finish()
                self.trace.mark("words")
            }
            self.holdStartedAt = nil
            self.updateGate()
            self.releaseTask = nil
            guard self.isLive, !Task.isCancelled else { self.thinkingGap = false; return }
            switch SpokenTurn.decide(words: words, held: held, quickReplyOnly: quick) {
            case .tooShort:
                rtLog("ptt: too short (\(String(format: "%.2f", held)) s), nothing sent")
                self.startSilenceTimer()
            case .almostReady:
                if !self.isSpeaking { self.say("Almost ready!") }
                rtLog("ptt: kit making, nothing sent + Almost ready")
            case .nothingHeard(let hint):
                self.thinkingGap = false
                rtLog("ptt: nothing heard (\(String(format: "%.2f", held)) s), nothing sent\(hint ? ", one hint line" : "")")
                if hint { self.say(SpokenTurn.didntCatch) }
                self.startSilenceTimer()
            case .send(let text):
                rtLog("ptt: words ready (\(String(format: "%.2f", held)) s hold), audio dropped, sending text")
                if let handle = self.onSpokenWords { handle(text) } else { self.sendText(text, kind: "voice") }
            }
        }
    }

    /// Stops her mid-sentence: cancel the response, silence the speaker, truncate her item at what was heard.
    private func interrupt(sendCancel: Bool = true) {
        if sendCancel && responseActive { socket?.send(Realtime.responseCancel); rtLog("ptt: response.cancel") }
        // 2026-11-20: the lines session's responses by id (a bare cancel there with nothing running is an error event).
        if sendCancel { for id in lineResponseIDs { lineSocket?.send(Realtime.responseCancel(id: id)) } }
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
    var voiceBusy: Bool { isSpeaking || gate.active || lineInFlight || Date().timeIntervalSince(lastSayAt) < 1.5 }

    /// `thinking`: a kid is waiting on this line (a hand-off or Let's play! tap): show the thinking face + dots until it plays.
    /// `echo` (round 17, the pill's Repeat): a line she already said, said again: heard, but not a second chat bubble.
    func say(_ line: String, thinking: Bool = false, echo: Bool = false, record: Bool = false) {
        guard let socket, isLive, !suspended, !line.isEmpty else { return }
        if thinking { thinkingGap = true }
        if echo { echoPending = true } else { chat.breakTurn() }   // each app line (kit progress, ready line) is its own bubble
        if !trace.running { trace.begin("app line") }
        lastSayAt = Date()
        if record {
            // Round D3b: the app's own line, tagged so the recorder captures exactly this response.
            let r = recorder.request(line: line, kind: ClipMeta.kind(of: line), role: recordRoles().flatMap { ClipMeta.role(of: line, roles: $0) })
            sendLine(Realtime.sayExactly(line, tag: r.tag), main: socket)
        } else {
            sendLine(Realtime.sayExactly(line), main: socket)
        }
        trace.mark("say.create")
        armWatchdog(line)
    }

    // MARK: Recording her app lines (round D3b)

    @ObservationIgnored private var recorder = ClipRecorder()
    /// A recorded app line passed the gate (the app encodes it and keeps it with the game).
    @ObservationIgnored var onRecorded: (@MainActor (RecordedLine) -> Void)?
    /// 2026-11-20: every FINISHED take of an app line (kept for saving or not), for this game's memory (`GameTakes`).
    @ObservationIgnored var onTake: (@MainActor (RecordedLine) -> Void)?
    /// 2026-11-20: an app line made no sound (the watchdog): the app says it again once the voice is back.
    @ObservationIgnored var onLineStalled: (@MainActor (String) -> Void)?
    /// A recorded line was rejected (counts only, for the hit-rate log).
    @ObservationIgnored var onRecordRejected: (@MainActor (ClipRecorder.Reason) -> Void)?
    /// The game's roles (clip metadata: which role a line is about).
    @ObservationIgnored var recordRoles: () -> [Role]? = { nil }
    var canSpeakLive: Bool { isLive && !suspended }

    /// Round D3b: a recorded clip started (played by the speaker, no response): her chat bubble (not for a Repeat), and
    /// nothing in the conversation to truncate on a barge-in.
    func clipStarted(_ text: String, echo: Bool) {
        audioItemID = nil; audioItemStart = nil
        silenceTask?.cancel(); thinkingGap = false; gapTask?.cancel()
        guard !echo else { return }
        chat.breakTurn()
        chat.apply(.transcriptDone(text))
        chat.breakTurn()
    }

    /// Round D3b: a replay starts a fresh chat (its first clip may play before the voice connects).
    func resetChat() { chat.clear() }

    /// 2026-11-17: her line as a text bubble only (an offline replay line she never recorded, or the "1 to 6" hint).
    func showLine(_ text: String) {
        chat.breakTurn()
        chat.apply(.transcriptDone(text))
        chat.breakTurn()
    }
    /// 2026-11-17: the kid's answer in the chat when it's read on the device (a replay's Pick with no voice session).
    func showKidLine(_ text: String) { chat.kidTyped(text) }

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
        try speaker.start(echoCancel: echoCancel) { [capture] input in
            let inFormat = input.outputFormat(forBus: 0)
            if inFormat.sampleRate > 0 && inFormat.channelCount > 0 {
                Self.installMicTap(on: input, format: inFormat, capture: capture)
            }
        }
    }

    private func updateGate() {
        // Round 31: nothing to gate on the way out (no audio is ever sent). A hold that outlives the session ends here.
        if !(isLive && micWanted), holdStartedAt != nil, releaseTask == nil { capture.cancel() }
    }

    // MARK: Expressions (decisions/conversation-camera-and-expressions.md)

    /// `tools`: nil = the step's usual tool-first rule; `.some(x)` = the caller decides (taps).
    private func kidTurnEnded(tools override: [String]?? = nil) {
        reminderDoneAt = nil; reminderAwaitingEnd = false
        if let note = noteForNextKidTurn { noteForNextKidTurn = nil; socket?.send(Realtime.systemNote(note)); rtLog("note: woke up") }
        gate.newTurn()
        if let override { forcedTools = override } else { forcedTools = onKidTurnTools?() }
        if override == nil, forcedTools == nil, let note = onPostPlanningTurn?() { socket?.send(Realtime.systemNote(note)) }
        replyWait.kidTurnEnded(); replyStarted = false
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
        replyWait.replyBegan(); gapTask?.cancel(); thinkingGap = false
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
            guard let s = self.socket else { return }
            // 2026-11-20: a reminder on the lines session never takes the main ResponseGate (its done never reaches it).
            if self.lineTarget(s) === s { guard self.gate.request() else { return } }
            self.chat.breakTurn()
            self.reasks += 1
            self.reminderPending = true
            rtLog("nudge: silence (fixed line, own chat bubble)")
            self.sendLine(Realtime.sayExactly(line), main: s)
        }
    }

    // MARK: Events

    /// Round 19: every response is tracked by id, so a kid's tap can cancel all of them (conversation replies and app
    /// lines), and late audio or words from a cancelled one never play or reach the chat.
    @ObservationIgnored private var speech = SpeechStop()
    // 2026-11-20: a response whose response.create was sent before the last stop is cancelled on arrival, by its
    // per-request tag (`CreateLedger`, one per socket, kept by `RealtimeSocket`). The old count matching went out of
    // step for good after one create that never got response.created, and then cancelled every new line.

    // MARK: Scripted lines on the mini model (cost v3; round 35 prep: behind `CostFlags.miniLines`, default OFF)
    // Both sockets are configured from ONE `VoiceSessionPlan` (the same VoiceConfig and instructions: identical
    // session.update, only the model differs) and both play through the one `NutmegSpeaker` (Varispeed 1.20).
    @ObservationIgnored private var lineSocket: RealtimeSocket?
    @ObservationIgnored private var lineTask: Task<Void, Never>?
    /// Counts of the fixed-lines session (numbers only).
    @ObservationIgnored private(set) var lineUsageTotals = RealtimeUsageTotals()
    /// The scripted-lines session is up (lines go to the mini model).
    var linesOnMini: Bool { lineSocket != nil && lineSocket?.firstError == nil }
    #if DEBUG
    /// A/B v2 driver (`-PTVoiceAB`): send the next app lines to the conversation session even with the mini one up.
    @ObservationIgnored var debugLinesOnMain = false
    #endif

    private func openLineSocket(auth: RealtimeAuth, config: VoiceConfig, instructions: String) async {
        guard let plan = VoiceSessionPlan.lines(config, instructions: instructions) else { return }
        lineTask?.cancel(); lineSocket?.close(); lineSocket = nil
        let main = socket
        guard let bearer = try? await auth.bearer(model: plan.model) else { rtLog("lines: no bearer for \(plan.model)"); return }
        var req = URLRequest(url: plan.url)
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        let s = RealtimeSocket(request: req)
        s.send(plan.sessionUpdate)
        guard await Self.waitReady(s) else {
            voiceLog("lines: session not ready (\(s.firstError?.prefix(80) ?? "-")), app lines stay on the main session")
            s.close(); return
        }
        // 2026-11-20: the main session was replaced or closed meanwhile (a reconnect, leaving the game): not ours.
        guard main != nil, socket === main else { s.close(); return }
        lineSocket = s
        lineHealth.ready(); linePings.reset()
        rtLog("lines: fixed app lines go to \(plan.model) (separate session, same voice config: \(plan.config))")
        lineTask = Task { [weak self] in
            for await text in s.messages { await self?.receive(text, line: true) }
            await self?.lineSocketEnded(s)   // 2026-11-20: never keep a lines session whose receive loop ended
        }
    }

    /// Where a fixed app line (`sayExactly`) is sent: the main session, or (lines flag on) the fixed-lines session while
    /// it is healthy (2026-11-20: `LineSocketHealth`).
    private func lineTarget(_ main: RealtimeSocket) -> RealtimeSocket {
        #if DEBUG
        if debugLinesOnMain { return main }
        #endif
        if let lineSocket, lineSocket.firstError == nil, lineHealth.routesLines { return lineSocket }
        return main
    }

    // MARK: Lines-session health and the line watchdog (2026-11-20, decisions/2026-11-20-voice-stall-fix.md)

    @ObservationIgnored private var lineHealth = LineSocketHealth()
    @ObservationIgnored private var linePings = SocketHealth()
    /// Lines sent to the lines session and not yet created there, by request tag (resent once on the main session).
    @ObservationIgnored private var lineSends: [String: [String: Any]] = [:]
    /// Responses running on the lines session (cancels go to the socket that owns the response).
    @ObservationIgnored private var lineResponseIDs: Set<String> = []
    @ObservationIgnored private var lineArgs: (auth: RealtimeAuth, config: VoiceConfig, instructions: String)?
    @ObservationIgnored private var lineReopenTask: Task<Void, Never>?
    @ObservationIgnored private var watchdog = LineWatchdog()
    @ObservationIgnored private var watchdogLine: String?
    @ObservationIgnored private var lastStallAt = Date.distantPast
    /// A line is on its way on the lines session (sent, or created and not done): app lines wait (`voiceBusy`).
    private var lineInFlight: Bool { !lineResponseIDs.isEmpty || lineHealth.hasPending }

    /// Sends one fixed app line: the lines session while it's healthy (watched for its response.created), else main.
    private func sendLine(_ event: [String: Any], main: RealtimeSocket) {
        let target = lineTarget(main)
        let tag = target.send(event)
        guard target !== main, let tag else { return }
        lineSends[tag] = event
        lineHealth.sent(tag: tag, at: CACurrentMediaTime())
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(LineSocketHealth.createdTimeout + 0.05))
            self?.checkLineSocket()
        }
    }

    private func checkLineSocket() {
        if let f = lineHealth.check(at: CACurrentMediaTime()) { lineSocketFailed(f) }
    }

    /// The lines session failed after it was ready: lines go to the main session from now on, the pending line is
    /// resent there once, and the lines session is reopened in the background.
    private func lineSocketFailed(_ f: LineSocketHealth.Failure) {
        voiceLog("lines: session failed (\(f.reason.rawValue)); app lines fall back to the main session, \(f.resend.count) resent")
        let dead = lineSocket
        lineTask?.cancel(); lineTask = nil; lineSocket = nil
        dead?.close()
        if !lineResponseIDs.isEmpty {
            // Whatever was running there is gone: never wait on it, never record it.
            for id in lineResponseIDs { speech.done(id) }
            recorder.cancel(Array(lineResponseIDs))
            lineResponseIDs = []
        }
        if let main = socket, isLive, !suspended {
            for tag in f.resend {
                guard let e = lineSends[tag] else { continue }
                main.send(e)
                watchdog.rearm(at: CACurrentMediaTime())
                armWatchdogCheck()
                voiceLog("lines: fallback, the pending line was resent on the main session")
            }
        }
        lineSends = [:]
        scheduleLineReopen()
    }

    /// Reopens the lines session after `LineSocketHealth.reopenDelays` (a few tries; lines stay on main meanwhile).
    private func scheduleLineReopen() {
        guard lineReopenTask == nil, lineArgs != nil, let wait = lineHealth.nextReopenDelay() else { return }
        lineReopenTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard let self, !Task.isCancelled else { return }
            self.lineReopenTask = nil
            guard self.isLive, !self.suspended, self.lineSocket == nil, let args = self.lineArgs else { return }
            await self.openLineSocket(auth: args.auth, config: args.config, instructions: args.instructions)
            if self.lineSocket == nil { self.scheduleLineReopen() } else { voiceLog("lines: session reopened") }
        }
    }

    /// The lines session's receive loop ended (closed by the server or the network).
    private func lineSocketEnded(_ s: RealtimeSocket) {
        guard s === lineSocket else { return }
        if let f = lineHealth.fail(.closed, at: CACurrentMediaTime()) { lineSocketFailed(f) } else { lineSocket = nil; lineTask = nil }
    }

    /// Keepalive for the lines session: two missed pongs in a row = failed.
    private func pingLineSocket() async {
        guard isLive, !suspended, let ls = lineSocket else { return }
        let ok = await ls.ping()
        guard ls === lineSocket, !suspended else { return }
        if linePings.pinged(ok: ok), let f = lineHealth.fail(.missedPongs, at: CACurrentMediaTime()) { lineSocketFailed(f) }
    }

    /// The safety net: an app line that makes no sound within `LineWatchdog.limit` s.
    private func armWatchdog(_ line: String) {
        watchdog.lineSent(at: CACurrentMediaTime())
        watchdogLine = line
        armWatchdogCheck()
    }

    private func armWatchdogCheck() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(LineWatchdog.limit + 0.05))
            self?.checkWatchdog()
        }
    }

    /// No sound: logged, the voice is marked unhealthy and reconnects silently (both sessions); the app says the line
    /// again once it's back.
    private func checkWatchdog() {
        guard watchdog.check(at: CACurrentMediaTime()) else { return }
        let line = watchdogLine
        watchdogLine = nil
        guard isLive, !suspended, let socket else { return }
        guard Date().timeIntervalSince(lastStallAt) > 20 else { voiceLog("watchdog: a line made no sound again (a reconnect ran moments ago)"); return }
        lastStallAt = Date()
        voiceLog("watchdog: an app line made no sound in \(Int(LineWatchdog.limit)) s; voice unhealthy, silent reconnect")
        if let line { onLineStalled?(line) }
        socket.close()   // the receive loop ends → socketClosed → onDropped → the app reconnects silently
    }

    /// Round 20: token counts from every response.done (never content), for the prompt-cache check.
    @ObservationIgnored private(set) var usageTotals = RealtimeUsageTotals()

    private func receive(_ text: String, line: Bool = false) async {
        let isLine = line
        let id = Realtime.responseID(text)
        let event = Realtime.parse(text)
        var lineFailure: LineSocketHealth.Failure?
        if line {
            // Cost v3: the fixed-lines session's counts are kept apart; its responses never count toward the main
            // socket's response.create bookkeeping (its own `CreateLedger`) and never drive the main ResponseGate.
            if event == .responseDone, let u = RealtimeUsage.parse(text) {
                lineUsageTotals.add(u)
                rtLog("USAGE-LINES #\(lineUsageTotals.responses): \(u.line)")
            }
            if event == .responseCreated {
                lineHealth.created(tag: CreateLedger.tag(in: text))
                if let tag = CreateLedger.tag(in: text) { lineSends[tag] = nil }
                if lineSocket?.cancelsOnArrival(text) == true, let id {
                    // Asked for before the kid's tap: cancel just this one the moment it exists.
                    speech.created(id)
                    if speech.cancel(id) { lineSocket?.send(Realtime.responseCancel(id: id)) }
                    rtLog("stop: a line asked for before the tap was cancelled on arrival (lines session)")
                    return
                }
                if let id { lineResponseIDs.insert(id) }
                speech.created(id); recorder.created(responseID: id, tag: Realtime.lineTag(text))
            }
            if case .sessionReady = event { return }
            if case .error(let m) = event {
                // 2026-11-20: an error after ready is a failure (lines move to the main session), except a benign cancel.
                if let f = lineHealth.error(m, at: CACurrentMediaTime()) {
                    voiceLog("lines: session error (\(m.prefix(80)))")
                    lineSocketFailed(f)
                } else {
                    rtLog("lines session error (benign): \(m)")
                }
                return
            }
            if event == .responseDone {
                if let id { lineResponseIDs.remove(id) }
                lineFailure = lineHealth.done(status: Realtime.responseStatus(text), at: CACurrentMediaTime())
            }
        }
        if !line, event == .responseDone, let m = greetingMeasure, m.bytes > 0 {
            greetingMeasure = nil
            let live = Double(m.bytes) / 2 / Realtime.sampleRate, rate = Realtime.defaultVarispeedRate
            rtLog(String(format: "GREETING heard %.1f s (clip %.1f s + live %.1f s, at Varispeed %.2f); audio before Varispeed %.1f s",
                         (m.clip + live) / rate, m.clip / rate, live / rate, rate, m.clip + live))
        }
        if !line, event == .responseDone, let u = RealtimeUsage.parse(text) {
            usageTotals.add(u)
            rtLog("USAGE #\(usageTotals.responses): \(u.line); session in \(usageTotals.input), cached \(usageTotals.cached) "
                  + String(format: "(%.0f%%)", usageTotals.cachedShare * 100))
        }
        if event == .responseCreated, !line {
            speech.created(id)
            if socket?.cancelsOnArrival(text) == true, let id {
                // Asked for before the kid moved on (e.g. a cheer already sent): cancel just this one the moment it
                // exists (2026-11-20: never everything running, which included the tap's own new line).
                if speech.cancel(id) { socket?.send(Realtime.responseCancel(id: id)) }
                rtLog("stop: a response asked for before the tap was cancelled on arrival")
            }
        }
        if event == .responseCreated, !line { recorder.created(responseID: id, tag: Realtime.lineTag(text)) }
        if speech.drops(event, responseID: id) { recorder.cancel(id.map { [$0] } ?? []); return }
        if recorder.isCapturing(id) {
            switch event {
            case .audioDelta(let d): recorder.audio(responseID: id, d)
            case .transcriptDone(let t): recorder.transcript(responseID: id, t)
            case .responseDone:
                let finished = recorder.finish(responseID: id, status: Realtime.responseStatus(text))
                // 2026-11-20: every finished take stays in this game's memory (repeat taps need no socket).
                if let take = finished.take { onTake?(take) }
                switch finished.outcome {
                case .kept(let line):
                    // Round 34: line lengths for the scene-opening and prop-line measurements (heard = ÷ Varispeed).
                    rtLog(String(format: "CLIP kept %.1f s (heard %.1f s) [%@]: %@", line.duration, line.duration / VoiceConfig.nutmeg.playbackRate,
                                 line.request.kind.rawValue, String(line.request.line.prefix(70))))
                    voiceLog(String(format: "clip kept for saving [%@, %.1f s, %@ session]", line.request.kind.rawValue, line.duration, isLine ? "lines" : "main"))
                    onRecorded?(line)
                case .rejected(let why):
                    voiceLog("clip not kept for saving (\(why.rawValue)) [\(isLine ? "lines" : "main") session]\(finished.take != nil ? "; kept for this game" : "")")
                    onRecordRejected?(why)
                case .notTracked: break
                }
            default: break
            }
        }
        if event == .responseDone { speech.done(id) }
        if line, event == .responseCreated || event == .responseDone {
            lineLifecycle(event)   // 2026-11-20: never the main ResponseGate
            if let lineFailure { lineSocketFailed(lineFailure) }
            return
        }
        await handle(event)
        // Round 39: a response ended and nothing more was asked for: no reply is coming this turn (isBusy goes false).
        if event == .responseDone, !line { replyWait.responseDone(gateActive: gate.active) }
    }

    /// 2026-11-20: a lines-session response starting or ending. Only its own playback state (the main ResponseGate,
    /// the turn checks and the tool outputs belong to the conversation session). Before, a line's response.done closed
    /// the gate under a running conversation response, and a line that never ended kept it shut.
    private func lineLifecycle(_ event: Realtime.Event) {
        switch event {
        case .responseCreated:
            if reminderPending { reminderPending = false; reminderPlaying = true }
            echoActive = echoPending; echoPending = false   // round 17: only the response the repeat asked for
            trace.mark("created")
            dropAudio = false
            responseHadAudio = false
            responseSerial += 1
        case .responseDone:
            if reminderPlaying {
                reminderPlaying = false
                reminderAwaitingEnd = true   // sleepy Nutmeg's clock starts when its audio has finished (round 9)
                chat.breakTurn()
            }
        default: break
        }
    }

    /// Round 19 (Haylee): the kid moved on (a tap that advances or changes the screen). Her current speech stops at once:
    /// every in-flight response is cancelled, the local player is cleared, her line is cut at what was heard (and marked
    /// "…" in the chat), and pending reminder/repeat lines are dropped. The newest line is whatever the app says next.
    func stopSpeaking(_ reason: String) {
        guard let socket, status == .live else {
            // Round D3b: no live session (an offline replay): a playing clip still stops at once, line cut in the chat.
            if speaker.hasAudioQueued { speaker.cancel(); chat.cutOff(); rtLog("stop (\(reason)): clip stopped (no session), line cut") }
            return
        }
        let wasSpeaking = speaker.hasAudioQueued
        let ids = speech.cancelAll()
        recorder.cancel(ids)   // round D3b: a cut line is never saved
        for id in ids {
            // 2026-11-20: each cancel goes to the socket that owns the response (a cancel for an unknown id is an
            // error event there).
            if lineResponseIDs.remove(id) != nil { lineSocket?.send(Realtime.responseCancel(id: id)) }
            else { socket.send(Realtime.responseCancel(id: id)) }
        }
        // Requests sent before this moment are cancelled when they arrive; the next line never is (`CreateLedger`).
        socket.markStop(); lineSocket?.markStop()
        lineHealth.stop()
        lineSends = [:]
        watchdog.disarm()
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
        case .audioDone:
            // Voice pitch build: the line's audio is all here, so the pitch shifter's held-back last ~60 ms plays now.
            speaker.endOfLine()
        case .audioDelta where dropAudio || holdStartedAt != nil || silentResponse || suspended:
            watchdog.heard()   // 2026-11-20: the voice is alive (this audio is just not for playing)
            // the kid interrupted this response (or is holding the mic): never play it
        case .audioDelta(let data):
            if !speaker.isRunning {
                // 2026-11-20: the engine was left down (a failed rebuild): start it rather than drop her line.
                do { try startAudio(echoCancel: echoCancel); voiceLog("speaker: engine was down, started for live audio") }
                catch { voiceLog("speaker: engine start for live audio failed: \(error.localizedDescription)") }
            }
            guard speaker.isRunning else { break }
            watchdog.heard()
            if audioItemStart == nil { audioItemStart = speaker.itemStart() }
            gate.spoke()
            responseHadAudio = true
            audioResponseSerial = responseSerial
            silenceTask?.cancel()
            if !reminderPlaying { reminderDoneAt = nil; reminderAwaitingEnd = false }
            replyBegan()
            thinkingGap = false
            if trace.running && !trace.has("first delta") { trace.mark("first delta") }
            if greetingMeasure != nil { greetingMeasure?.bytes += data.count }
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

    nonisolated private static func installMicTap(on input: AVAudioInputNode, format: AVAudioFormat, capture: KidSpeechCapture) {
        input.installTap(onBus: 0, bufferSize: 2400, format: format) { buffer, when in
            capture.push(buffer, host: when.isHostTimeValid ? AVAudioTime.seconds(forHostTime: when.hostTime) : nil)
        }
    }
}

/// Round D3a: her fixed app lines go out as `sayExactly` (the speaker's live voice).
extension RealtimeSession: NutmegLiveVoice {}

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

    /// 2026-11-20: every response.create carries a per-request tag (`CreateLedger`); a stop marks the ones sent before
    /// it, and those are cancelled when they arrive (round 19's rule, without counting).
    private var ledger = CreateLedger()

    /// Sends one client event. Returns the request tag for a response.create (nil for anything else).
    @discardableResult
    func send(_ obj: [String: Any]) -> String? {
        var obj = obj
        var tag: String?
        if obj["type"] as? String == "response.create" {
            let t = lock.withLock { ledger.nextTag() }
            obj = CreateLedger.stamp(obj, tag: t)
            tag = t
        }
        task.send(.string(Realtime.json(obj))) { [weak self] error in
            if let error { self?.noteError(error.localizedDescription) }
        }
        return tag
    }

    /// A stop: every response.create sent so far is stale.
    func markStop() { lock.withLock { ledger.stop() } }
    /// A response.created whose request was sent before the last stop.
    func cancelsOnArrival(_ text: String) -> Bool {
        let tag = CreateLedger.tag(in: text)
        return lock.withLock { ledger.cancelsOnArrival(tag) }
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
                    if event == .sessionReady {
                        self.resolveReady(true)
                        rtLog("SESSION ready: \(Realtime.sessionEcho(text))")   // round 35 prep: model + voice the server confirmed
                    }
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

/// 2026-11-20: the few voice diagnostics that also show in Release (Console.app, subsystem "PretendThat", category
/// "voice"): clip kept / not kept and why, lines-session failures and the fallback, the watchdog, resume. Fixed app
/// text only: never anything a kid said, never a transcript, never a line's words.
private let voiceLogger = Logger(subsystem: "PretendThat", category: "voice")
func voiceLog(_ message: String) {
    voiceLogger.notice("\(message, privacy: .public)")
    rtLog(message)
}

/// Nutmeg's on-device pitch shaping (D7, revised in conversation-voice.md).
struct VoiceShape: Equatable {
    var method: Realtime.PitchMethod = Realtime.defaultPitchMethod
    var cents: Double = Realtime.defaultPitchCents
    var rate: Double = Realtime.defaultVarispeedRate
    /// Voice pitch build (2026-11-17): Signalsmith Stretch +2 semitones before the player (0 = off).
    var shift: PitchShift = VoiceConfig.nutmeg.pitchShift
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
