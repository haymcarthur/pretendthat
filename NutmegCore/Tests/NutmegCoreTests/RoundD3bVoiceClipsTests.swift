import Foundation
import Testing
@testable import NutmegCore

/// Round D3b (Nutmeg's real recorded voice on replays, design 2026-11-15 §D4 + Haylee's answer 1).
@MainActor
struct RoundD3bVoiceClipsTests {
    let a = Fallback.airplane
    let voice = VoiceConfig.nutmeg.voiceID

    /// PCM16 of `seconds` of a tone (loud enough to pass the silence trim), with `pad` seconds of silence each side.
    func tone(_ seconds: Double, pad: Double = 0) -> Data {
        var d = Data()
        func silence(_ s: Double) { d.append(Data(count: Int(s * Realtime.sampleRate) * 2)) }
        silence(pad)
        let n = Int(seconds * Realtime.sampleRate)
        for i in 0..<n {
            var v = Int16(8000 * sin(Double(i) * 2 * .pi * 220 / Realtime.sampleRate)).littleEndian
            if abs(Int(v)) < 400 { v = Int16(500).littleEndian }   // never under the trim threshold inside the tone
            withUnsafeBytes(of: &v) { d.append(contentsOf: $0) }
        }
        silence(pad)
        return d
    }

    func fixture() -> SavedGame {
        SavedGame(createdAt: Date(timeIntervalSince1970: 1_800_000_000), title: "Airplane to the Beach", roles: a.plan.roles,
                  props: a.props.props.map(SavedProp.init), kit: a.kit, hasPrinter: true, printStyle: .colorIn, drawGuide: nil,
                  art: [], voiceID: voice)
    }

    // MARK: Normalizing + keys

    @Test func normalizeHandlesCasePunctuationNumeralsAndAmpersand() {
        let table: [(String, String)] = [
            ("Pass the iPad to the Captain, then tap I'm the Captain!", "pass the ipad to the captain then tap im the captain"),
            ("Make 3, one for each friend.", "make three one for each friend"),
            ("Make three, one for each friend!", "make three one for each friend"),
            ("Tap the number 47", "tap the number forty seven"),
            ("Cups & plates", "cups and plates"),
            ("Let\u{2019}s  play…", "lets play"),
            ("  WOW!!  ", "wow"),
        ]
        for (raw, want) in table { #expect(ClipText.normalize(raw) == want, "\(raw)") }
    }

    @Test func keysAreStableVoiceScopedAndIgnorePunctuation() {
        let k = ClipKey.make(line: "Three friends!", voiceID: voice)
        #expect(k.count == 32 && k.allSatisfy { $0.isHexDigit })
        #expect(k == ClipKey.make(line: "3 friends.", voiceID: voice))
        #expect(k != ClipKey.make(line: "Four friends!", voiceID: voice))
        #expect(k != ClipKey.make(line: "Three friends!", voiceID: "alloy@gpt-realtime-2.1"))   // the voice is in the key
        // The role is covered by the text: a hand-off for another role is another key.
        #expect(ClipKey.make(line: HandOffLines.handoff(spokenRole: "the Captain"), voiceID: voice)
                != ClipKey.make(line: HandOffLines.handoff(spokenRole: "the Navigator"), voiceID: voice))
    }

    // MARK: The transcript gate

    @Test func transcriptGateAcceptsTheScriptAndRejectsParaphrases() {
        let line = "Your kit is ready! Tap Print to print it, then tap Let's play when you're set!"
        #expect(TranscriptGate.accepts(requested: line, transcript: "Your kit is ready. Tap print to print it, then tap let's play when you're set."))
        #expect(TranscriptGate.accepts(requested: "Make 3, one for each friend.", transcript: "Make three, one for each friend!"))
        // Round 24's "tap Start" paraphrase is never saved.
        #expect(!TranscriptGate.accepts(requested: line, transcript: "Your kit is ready! Tap Print to print it, then tap Start when you're set!"))
        #expect(!TranscriptGate.accepts(requested: line, transcript: "Your kit is ready!"))   // cut short
        #expect(!TranscriptGate.accepts(requested: "Good job!", transcript: "Good job! Giggle!"))   // an added word
        #expect(!TranscriptGate.accepts(requested: "", transcript: ""))
    }

    // MARK: The recorder

    @Test func recorderKeepsOnlyTaggedCompletedMatchingLines() {
        var rec = ClipRecorder()
        let line = "Pass the iPad to the Captain, then tap I'm the Captain!"
        let r = rec.request(line: line, kind: .handoff, role: "R1")
        // A conversation reply (no tag) and a response with an unknown tag are never captured.
        rec.created(responseID: "resp_chat", tag: nil)
        rec.created(responseID: "resp_other", tag: "pt999")
        rec.audio(responseID: "resp_chat", tone(2)); rec.transcript(responseID: "resp_chat", line)
        #expect(rec.done(responseID: "resp_chat", status: "completed") == .notTracked)
        #expect(rec.done(responseID: "resp_other", status: "completed") == .notTracked)
        // The app's line: kept, the leading silence trimmed to 60 ms (0.06 + 1 + 0.5 gap + 1 s).
        rec.created(responseID: "resp_1", tag: r.tag)
        #expect(rec.isCapturing("resp_1"))
        rec.audio(responseID: "resp_1", tone(1, pad: 0.5)); rec.audio(responseID: "resp_1", tone(1))
        rec.transcript(responseID: "resp_1", line)
        guard case .kept(let kept) = rec.done(responseID: "resp_1", status: "completed") else { Issue.record("not kept"); return }
        #expect(kept.request == r && kept.request.kind == .handoff && kept.request.role == "R1")
        #expect(abs(kept.duration - 2.56) < 0.02, "\(kept.duration)")
        // A tag is used once: a second response with the same tag isn't captured.
        rec.created(responseID: "resp_2", tag: r.tag)
        #expect(!rec.isCapturing("resp_2"))
    }

    @Test func recorderRejectsPartialCancelledShortLongAndParaphrasedClips() {
        func run(_ status: String?, audio: Data, transcript: String, cancel: Bool = false) -> ClipRecorder.Outcome {
            var rec = ClipRecorder()
            let r = rec.request(line: "Good job! Next, wave the flag!", kind: .cheer, role: nil)
            rec.created(responseID: "resp_x", tag: r.tag)
            rec.audio(responseID: "resp_x", audio); rec.transcript(responseID: "resp_x", transcript)
            if cancel { rec.cancel(["resp_x"]) }
            return rec.done(responseID: "resp_x", status: status)
        }
        let ok = "Good job! Next, wave the flag!"
        #expect(run("cancelled", audio: tone(2), transcript: ok) == .rejected(.cancelled))
        #expect(run("incomplete", audio: tone(2), transcript: ok) == .rejected(.incomplete))
        #expect(run("completed", audio: tone(2), transcript: ok, cancel: true) == .notTracked)   // a barge-in dropped it
        #expect(run("completed", audio: tone(0.2), transcript: ok) == .rejected(.tooShort))
        #expect(run("completed", audio: tone(31.5), transcript: ok) == .rejected(.tooLong))
        #expect(run("completed", audio: Data(), transcript: ok) == .rejected(.noAudio))
        #expect(run("completed", audio: Data(count: 48_000), transcript: ok) == .rejected(.tooShort))   // silence only
        #expect(run("completed", audio: tone(2), transcript: "Good job! Next, wave the banner!") == .rejected(.transcriptMismatch))
        if case .kept = run("completed", audio: tone(2), transcript: ok) {} else { Issue.record("a good line was rejected") }
    }

    @Test func sayExactlyTagIsMetadataOnlyAndParses() throws {
        let line = "Here's your checklist again! Tap Done when you're finished."
        let plain = Realtime.sayExactly(line), tagged = Realtime.sayExactly(line, tag: "pt7")
        var r = try #require(tagged["response"] as? [String: Any])
        #expect((r["metadata"] as? [String: String]) == ["pt_line": "pt7"])
        r["metadata"] = nil
        // Everything else (the model's input, the cached prefix) is byte-for-byte the same.
        #expect(Realtime.json(["type": "response.create", "response": r]) == Realtime.json(plain))
        let created = #"{"type":"response.created","response":{"id":"resp_A","status":"in_progress","metadata":{"pt_line":"pt7"}}}"#
        #expect(Realtime.lineTag(created) == "pt7" && Realtime.responseID(created) == "resp_A")
        #expect(Realtime.lineTag(#"{"type":"response.created","response":{"id":"resp_B","metadata":null}}"#) == nil)
        let done = #"{"type":"response.done","response":{"id":"resp_A","status":"cancelled","usage":{"output_tokens":40,"output_token_details":{"audio_tokens":30,"text_tokens":10}}}}"#
        #expect(Realtime.responseStatus(done) == "cancelled")
        #expect(RealtimeUsage.parse(done)?.outAudio == 30)
    }

    @Test func trimSilenceKeeps60msAndChunksAre100ms() {
        let d = ClipAudio.trimSilence(tone(1, pad: 1))
        #expect(abs(Double(d.count / 2) / Realtime.sampleRate - 1.12) < 0.01)
        #expect(ClipAudio.trimSilence(Data(count: 4800)).isEmpty)
        #expect(ClipAudio.chunks(count: 5000) == [0..<2400, 2400..<4800, 4800..<5000])
        #expect(ClipAudio.floats(Data([0x00, 0x40])) == [0.5])
    }

    // MARK: Matching + routes

    @Test func clipIndexMatchesNormalizedTextAndAnOlderVoiceStillPlays() {
        let old = SavedClip(key: ClipKey.make(line: "Three friends!", voiceID: "coral@gpt-realtime-1"), text: "Three friends!",
                            kind: "replay", role: nil, duration: 1, file: "clips/x.aac")
        let idx = ClipIndex(clips: [old], commonKeys: ["Almost ready!": CommonLines.key("Almost ready!")])
        #expect(idx.hit(for: "three friends.") == .game(old))   // her voice never changes inside a game
        #expect(idx.hit(for: "Almost ready!") == .common(key: CommonLines.key("Almost ready!")))
        #expect(idx.hit(for: "Four friends!") == nil)
    }

    @Test func routesAreClipFirstThenLiveThenWiFiPauseNeverAnotherVoice() {
        #expect(LineRoute.choose(hasClip: true, live: true, replay: true, recordable: true) == .clip)
        #expect(LineRoute.choose(hasClip: true, live: false, replay: true, recordable: true) == .clip)
        #expect(LineRoute.choose(hasClip: false, live: true, replay: true, recordable: true) == .live(record: true))
        #expect(LineRoute.choose(hasClip: false, live: true, replay: false, recordable: false) == .live(record: false))
        // Offline on a replay with no clip: the Wi-Fi pause (Haylee's answer 1), never silent text or the device voice.
        #expect(LineRoute.choose(hasClip: false, live: false, replay: true, recordable: true) == .waitForNetwork)
        #expect(LineRoute.choose(hasClip: false, live: false, replay: false, recordable: true) == .unavailable)
    }

    @Test func wifiPauseHoldsTheLineUntilTheVoiceIsBack() {
        var p = WiFiPause()
        #expect(!p.isPaused && p.resume(live: true) == nil)
        p.owe("Three friends! Our crew is a Captain, a Navigator and a Parrot Keeper!")
        #expect(p.isPaused)
        #expect(p.resume(live: false) == nil && p.isPaused)   // still offline: stays paused on that line
        p.owe("Four friends! Our crew is a Captain, a Navigator, a Parrot Keeper and a Cook!")   // the newest line wins
        #expect(p.resume(live: true) == "Four friends! Our crew is a Captain, a Navigator, a Parrot Keeper and a Cook!")
        #expect(!p.isPaused)
        #expect(CommonLines.all.contains(WiFiPause.spokenNote))   // the note itself is in her recorded voice
        #expect(WiFiPause.note.contains("Wi-Fi") && WiFiPause.spokenNote.contains("Wi-Fi"))
    }

    // MARK: Live once, then saved

    @Test func aNeverSaidLineIsLiveOnceThenAClipInTheSavedGame() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pt-d3b-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SavedGameStore(root: root)
        let g = fixture()
        // First play recorded the Captain's hand-off; saved with the game.
        let captain = HandOffLines.handoff(spokenRole: "the Captain")
        let c1 = SavedClip(key: ClipKey.make(line: captain, voiceID: voice), text: captain, kind: "handoff", role: "R1", duration: 2.1, file: "")
        var saved = g; saved.clips = [c1]
        try store.save(saved, art: [:], cover: nil, clips: [c1.key: Data([1, 2, 3])])
        var idx = ClipIndex(clips: store.game(g.id)!.clips)
        #expect(store.game(g.id)!.clips.map(\.file) == ["clips/\(c1.key).aac"])
        #expect(FileManager.default.fileExists(atPath: store.clipURL(c1, in: g.id).path))
        // Replay at 5: the Cook (R5) never played. Its hand-off is live once (recorded)…
        let cook = HandOffLines.handoff(spokenRole: "the Cook")
        #expect(LineRoute.choose(hasClip: idx.has(cook), live: true, replay: true, recordable: true) == .live(record: true))
        var rec = ClipRecorder()
        let r = rec.request(line: cook, kind: ClipMeta.kind(of: cook), role: ClipMeta.role(of: cook, roles: a.plan.roles))
        rec.created(responseID: "resp_c", tag: r.tag); rec.audio(responseID: "resp_c", tone(2)); rec.transcript(responseID: "resp_c", cook)
        guard case .kept(let line) = rec.done(responseID: "resp_c", status: "completed") else { Issue.record("not kept"); return }
        let c5 = SavedClip(key: ClipKey.make(line: cook, voiceID: voice), text: cook, kind: line.request.kind.rawValue,
                           role: line.request.role, duration: line.duration, file: "")
        #expect(store.addClip(c5, data: Data([4]), to: g.id))
        #expect(!store.addClip(c5, data: Data([5]), to: g.id))   // append-only, the first one saved wins
        // …and the next replay finds it: a clip now.
        idx = ClipIndex(clips: store.game(g.id)!.clips)
        #expect(LineRoute.choose(hasClip: idx.has(cook), live: true, replay: true, recordable: true) == .clip)
        #expect(store.game(g.id)!.clips.count == 2 && (try? Data(contentsOf: store.clipURL(c5, in: g.id))) == Data([4]))
        // touch() (a replay started) keeps the clips.
        store.touch(g.id)
        #expect(store.game(g.id)!.clips.count == 2)
        #expect(line.request.kind == .handoff)
    }

    @Test func metadataKindsAndRoles() {
        let roles = a.plan.roles
        let r2 = roles[1]
        #expect(ClipMeta.role(of: HandOffLines.handoff(spokenRole: r2.spoken), roles: roles) == r2.id.rawValue)
        #expect(ClipMeta.role(of: "Good job! Next, wave!", roles: roles) == nil)
        #expect(ClipMeta.kind(of: HandOffLines.printReady) == .printReady)
        #expect(ClipMeta.kind(of: HandOffLines.end(canGoBack: false, replay: true)) == .end)
        #expect(ClipMeta.kind(of: "Wonderful! Next, serve the snacks!") == .cheer)
        #expect(ClipMeta.kind(of: ChecklistCheers.congrats[0] + " " + ChecklistCheers.doneTails[0]) == .congrats)
        #expect(ClipMeta.kind(of: ReplayLines.greeting(title: "Airplane to the Beach")) == .replay)
        #expect(ClipMeta.kind(of: WiFiPause.spokenNote) == .wifi)
        #expect(ClipMeta.kind(of: BackNav.arrivalLine(.play)) == .arrival)
    }

    // MARK: Clip-aware decks

    @Test func clipAwareCheersAndDecksPreferRecordedVariants() {
        var rng = SystemRandomNumberGenerator()
        let steps = ["Wave the flag.", "Hand out the snacks.", "Fasten your seatbelts."]
        let recorded: Set<String> = ["Bravo! Up next: hand out the snacks!"]
        for _ in 0..<20 {
            var deck = LineDeck()
            #expect(ChecklistCheers.afterCheck(index: 0, steps: steps, checked: [0], deck: &deck, using: &rng,
                                               recorded: { recorded.contains($0) }) == "Bravo! Up next: hand out the snacks!")
        }
        // Nothing recorded for this step: the first-play draw (a praise + next wording).
        var deck = LineDeck()
        let free = ChecklistCheers.afterCheck(index: 1, steps: steps, checked: [0, 1], deck: &deck, using: &rng, recorded: { recorded.contains($0) })
        #expect(free?.hasSuffix("fasten your seatbelts!") == true)
        // The finished list: a recorded congrats + tail wins.
        let fin = ChecklistCheers.congrats[3] + " " + ChecklistCheers.doneTails[2]
        #expect(ChecklistCheers.afterCheck(index: 2, steps: steps, checked: [0, 1, 2], deck: &deck, using: &rng, recorded: { $0 == fin }) == fin)
        // The generic deck.
        var d2 = LineDeck()
        for _ in 0..<10 { #expect(d2.drawPreferring("kit", from: ["a", "b", "c"], recorded: { $0 == "b" }, using: &rng) == "b") }
        #expect(["a", "b", "c"].contains(d2.drawPreferring("kit2", from: ["a", "b", "c"], recorded: { _ in false }, using: &rng) ?? ""))
    }

    @Test func replayLeadInPrefersTheRecordedCongratsWholeLine() async {
        let store = AdventureStore(service: nil)
        store.loadReplay(fixture())
        store.replayPick(3); store.replayPickDone(); store.replayPropsDone(); store.replayPaper(.skip)
        store.autoCheckStep = .zero; store.autoCheckHold = .zero
        store.beginPlay()
        if case .handoff(let i) = store.phase, let r = store.kit?.scenes[i].owner.role { store.badgeTapped(r) }
        guard case .scene = store.phase else { Issue.record("not in a scene"); return }
        // What the line after Done! will be, with the recorded congrats (any one of the 8).
        let recordedLead = ChecklistCheers.congrats[5]
        var heard: [String] = []
        store.isRecorded = { line in
            heard.append(line)
            return line.hasPrefix(recordedLead + " ")
        }
        store.sceneLeadIn = ChecklistCheers.congrats[0]
        await store.sceneDone()
        #expect(store.nutmegLine.hasPrefix(recordedLead + " "), "\(store.nutmegLine)")
        #expect(!heard.isEmpty)
    }

    // MARK: A whole replay, twice (the hit rate a second play at the same count reaches)

    @Test func aSecondReplayAtTheSameCountIsAllClipsAndAnotherCountIsLiveOnceThenClips() async {
        var index = ClipIndex()
        var log1 = ClipHitLog(), log2 = ClipHitLog(), log3 = ClipHitLog(), log4 = ClipHitLog()
        func run(_ n: Int, log: inout ClipHitLog) async {
            let store = AdventureStore(service: nil)
            store.loadReplay(fixture())
            store.autoCheckStep = .zero; store.autoCheckHold = .zero
            var lines: [String] = []
            func take() { if !store.nutmegLine.isEmpty, lines.last != store.nutmegLine { lines.append(store.nutmegLine) } }
            take()
            store.replayPick(n); take(); store.replayPickDone(); take(); store.replayPropsDone(); take(); store.replayPaper(.skip); take()
            store.beginPlay(); take()
            for _ in 0..<40 {
                switch store.phase {
                case .handoff(let i): if let r = store.kit?.scenes[i].owner.role { store.badgeTapped(r) }
                case .scene: await store.sceneDone()
                default: break
                }
                take()
                if store.phase == .end { break }
            }
            for line in lines {
                let route = LineRoute.choose(hasClip: index.has(line), live: true, replay: true, recordable: true)
                log.note(route, kind: ClipMeta.kind(of: line))
                if case .live = route {   // live once, then saved
                    index.add(SavedClip(key: ClipKey.make(line: line, voiceID: voice), text: line, kind: "line", role: nil, duration: 1, file: ""))
                    log.savedOne()
                }
            }
        }
        await run(3, log: &log1)
        await run(3, log: &log2)
        await run(5, log: &log3)
        await run(5, log: &log4)
        #expect(log1.total > 4 && log1.live > 0 && log1.hitRate < 0.5, "\(log1.line)")   // only lines said twice in one play hit
        #expect(log2.hitRate == 1, "\(log2.line)")
        #expect(log3.live > 0 && log3.hitRate > 0 && log3.hitRate < 1, "\(log3.line)")   // the new roles' lines
        #expect(log4.hitRate == 1, "\(log4.line)")
        #expect(!log2.line.contains("Airplane"))   // the log is counts only
    }

    // MARK: Privacy (CLAUDE.md rule 6): clips are only app-scripted lines

    @Test func savedClipsHoldOnlyAppLinesNeverAnythingAboutKids() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pt-d3b-p-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SavedGameStore(root: root)
        var g = fixture()
        let kidText = "My name is Zelda Quokkabottom"
        // The recorder only takes responses the app started with a tag: the kid's turn and her reply to it never are.
        var rec = ClipRecorder()
        rec.created(responseID: "resp_reply", tag: nil)
        rec.audio(responseID: "resp_reply", tone(2)); rec.transcript(responseID: "resp_reply", "Hi Zelda! " + kidText)
        #expect(rec.done(responseID: "resp_reply", status: "completed") == .notTracked)
        // Even a tagged line is only kept when she said the SCRIPT, not something else.
        let r = rec.request(line: HandOffLines.backToChecklist, kind: .checklistIntro, role: nil)
        rec.created(responseID: "resp_line", tag: r.tag); rec.audio(responseID: "resp_line", tone(2))
        rec.transcript(responseID: "resp_line", "Hi Zelda Quokkabottom!")
        #expect(rec.done(responseID: "resp_line", status: "completed") == .rejected(.transcriptMismatch))
        // A saved clip has exactly the design's fields, and its text is the app's own line.
        let c = SavedClip(key: ClipKey.make(line: HandOffLines.backToChecklist, voiceID: voice), text: HandOffLines.backToChecklist,
                          kind: "checklistIntro", role: nil, duration: 2, file: "")
        g.clips = [c]
        try store.save(g, art: [:], cover: nil, clips: [c.key: Data([7])])
        let data = try Data(contentsOf: root.appendingPathComponent(g.id.uuidString).appendingPathComponent("game.json"))
        let json = String(decoding: data, as: UTF8.self)
        let top = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(Set(top.keys).isSubset(of: SavedGame.allowedKeys))
        let clipKeys = Set(((top["clips"] as? [[String: Any]]) ?? []).flatMap(\.keys))
        #expect(clipKeys == ["key", "text", "kind", "role", "duration", "file"] || clipKeys == ["key", "text", "kind", "duration", "file"])
        #expect(!json.contains("Zelda") && !json.contains("transcript") && !json.contains("playerCount"))
        // Clip files live only under clips/ in the game folder (nothing else is written).
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(g.id.uuidString).appendingPathComponent("clips").path)
        #expect(files == ["\(c.key).aac"])
    }

    @Test func savingWithoutClipFilesDropsDanglingEntries() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pt-d3b-d-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SavedGameStore(root: root)
        var g = fixture()
        g.clips = [SavedClip(key: "abc", text: "Almost ready!", kind: "line", role: nil, duration: 1, file: "")]
        try store.save(g, art: [:], cover: nil)
        #expect(store.game(g.id)!.clips.isEmpty)
    }

    @Test func voiceStaysFrozenForRecordedClips() {
        // The clips are stored before Varispeed; the one pitch unit applies 1.20 once at playback (§D4.4).
        #expect(VoiceConfig.nutmeg.voice == "coral" && VoiceConfig.nutmeg.method == .varispeed && VoiceConfig.nutmeg.rate == 1.20)
        #expect(VoiceConfig.nutmeg.apiSpeed == 1.0)   // never a server speed on top
        #expect(CommonLines.key(WiFiPause.spokenNote) == ClipKey.make(line: WiFiPause.spokenNote, voiceID: "coral@gpt-realtime-2.1"))
    }
}
