import Foundation
import Testing
@testable import NutmegCore

@Test func sessionUpdateShape() throws {
    let s = Realtime.sessionUpdate(voice: "nope", speed: 9)
    let session = try #require(s["session"] as? [String: Any])
    #expect(session["type"] as? String == "realtime")
    let audio = try #require(session["audio"] as? [String: Any])
    let output = try #require(audio["output"] as? [String: Any])
    #expect(output["voice"] as? String == Realtime.defaultVoice)   // unknown voice → default
    #expect((output["speed"] as? NSNumber)?.doubleValue == 1.5)                     // clamped
    let input = try #require(audio["input"] as? [String: Any])
    #expect(input["turn_detection"] is NSNull)   // push-to-talk: no server VAD
    let names = (session["tools"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
    #expect(names == ["show_game_ideas", "set_game", "set_theme", "set_player_count", "set_roles", "show_next_prop", "mark_found", "swap_prop", "skip_prop", "confirm_plan", "finish_planning", "just_talk", "start_play", "print_kit", "choose_print_set", "confirm_handoff", "finish_scene", "go_to_step", "start_planning"])
    #expect(Realtime.json(s).contains("\"laundry-basket\""))   // the prop library is an enum in the schema
    // Serializes cleanly: turn detection is an explicit JSON null, never server VAD.
    #expect(Realtime.json(s).contains("\"turn_detection\":null"))
    #expect(!Realtime.json(s).contains("server_vad") && !Realtime.json(s).contains("create_response"))
}

/// Push-to-talk client events (decisions/2026-11-13-push-to-talk.md).
@Test func pushToTalkEvents() throws {
    #expect(Realtime.inputCommit["type"] as? String == "input_audio_buffer.commit")
    #expect(Realtime.inputClear["type"] as? String == "input_audio_buffer.clear")
    #expect(Realtime.responseCancel["type"] as? String == "response.cancel")
    #expect(Realtime.appendAudio(Data([1, 2]))["type"] as? String == "input_audio_buffer.append")
    let t = Realtime.truncate(itemID: "item_1", audioEndMs: 1234)
    #expect(t["type"] as? String == "conversation.item.truncate" && t["item_id"] as? String == "item_1")
    #expect(t["content_index"] as? Int == 0 && t["audio_end_ms"] as? Int == 1234)
    #expect(Realtime.truncate(itemID: "x", audioEndMs: -5)["audio_end_ms"] as? Int == 0)
    #expect(Realtime.minHoldSeconds == 0.3)
    #expect(Realtime.parse(#"{"type":"response.output_item.added","item":{"id":"item_9","type":"message"}}"#) == .outputItemAdded(id: "item_9"))
    #expect(Realtime.parse(#"{"type":"response.output_item.added","item":{"id":"fc_1","type":"function_call"}}"#)
            == .other("response.output_item.added"))
}

/// She tells kids to hold the red button, never to "just talk"; prop descriptions stay short.
@Test func instructionsDescribePushToTalk() {
    #expect(Realtime.instructions.contains("Hold the red button and tell me"))
    #expect(Realtime.instructions.contains("ONLY in your very first question"))
    #expect(!Realtime.instructions.lowercased().contains("you only hear the lines meant for you"))
    let prop = Realtime.tools.first { $0["name"] as? String == "show_next_prop" }
    #expect((prop?["description"] as? String)?.contains("6 words or fewer") == true)
}

@Test func parsesServerEvents() {
    #expect(Realtime.parse(#"{"type":"session.updated"}"#) == .sessionReady)
    #expect(Realtime.parse(#"{"type":"response.output_audio.delta","delta":"AAEC"}"#) == .audioDelta(Data([0, 1, 2])))
    #expect(Realtime.parse(#"{"type":"conversation.item.input_audio_transcription.completed","transcript":"hi"}"#) == .kidTranscript("hi"))
    #expect(Realtime.parse(#"{"type":"response.function_call_arguments.done","name":"set_game","call_id":"c1","arguments":"{\"title\":\"Zoo\"}"}"#)
            == .functionCall(name: "set_game", callID: "c1", arguments: #"{"title":"Zoo"}"#))
    #expect(Realtime.parse(#"{"type":"error","error":{"code":"bad","message":"oops"}}"#) == .error("bad: oops"))
}

@Test func decodesPlanningCalls() {
    #expect(PlanningCall.decode(name: "set_game", arguments: #"{"title":" Zoo "}"#) == .setGame("Zoo"))
    #expect(PlanningCall.decode(name: "set_game", arguments: #"{"title":""}"#) == nil)
    #expect(PlanningCall.decode(name: "set_player_count", arguments: #"{"count":3}"#) == .setPlayerCount(3))
    #expect(PlanningCall.decode(name: "set_player_count", arguments: #"{"count":20}"#) == .setPlayerCount(20))   // round 23: the store answers the cap
    #expect(PlanningCall.decode(name: "set_players", arguments: #"{"names":["Mia"],"count":1}"#) == nil)   // no name capture anymore
    if case .showGameIdeas(let ideas)? = PlanningCall.decode(name: "show_game_ideas", arguments:
        #"{"ideas":[{"title":"A","pitch":""},{"title":"B","pitch":""},{"title":"C","pitch":""},{"title":"D","pitch":""}]}"#) {
        #expect(ideas.map(\.title) == ["A", "B", "C"])
    } else { Issue.record("ideas not decoded") }
    #expect(PlanningCall.decode(name: "finish_planning", arguments: "{}") == .finishPlanning)
    #expect(PlanningCall.decode(name: "show_props", arguments: #"{"props":[{"item_id":"tray","becomes":"cart","for_role":"all","alternates":["books","rocket"]}]}"#)
            == .showProps([.init(itemID: "tray", becomes: "cart", forRole: "all", alternates: ["books"])]))
    #expect(PlanningCall.decode(name: "skip_prop", arguments: #"{"id":"tray"}"#) == .skipProp("tray"))
    #expect(PlanningCall.decode(name: "unknown", arguments: "{}") == nil)
}

@Test @MainActor func conversationDrivesStore() async {
    let llm = FakeLLM(responses: ["Kit": Fallback.airplane.kit])
    let store = AdventureStore(service: PhaseService(llm: llm))
    store.beginConversation()
    #expect(store.phase == .pickGame)
    _ = await store.apply(.showGameIdeas([GameIdea(id: "a", title: "Zoo", emoji: "", pitch: "")]))
    #expect(store.presenting == .none)   // ideas are spoken, never carded (Haylee)
    _ = await store.apply(.setGame("Zoo"))
    #expect(store.phase == .pickGame && store.presenting == .none && store.gameTitle == "Zoo")   // theme step next
    _ = await store.apply(.setTheme("Zoo on the Moon"))
    #expect(store.phase == .players && store.gameTitle == "Zoo on the Moon")
    _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
    #expect(store.playerCount == 2)
    _ = await store.apply(.setRoles([.init(roleName: "Zookeeper", job: "Feed the lion"),
                                     .init(roleName: "Lion", job: "Roar")]))
    #expect(store.plan?.roles.count == 6 && store.playingRoles.map(\.roleName) == ["Zookeeper", "Lion"])
    #expect(store.plan?.role(for: .R2)?.roleName == "Lion")
    #expect(store.presenting == .none)   // no role cards (Haylee): roles are spoken, then printed on badges
    _ = await store.apply(.showProps([.init(itemID: "pillow", becomes: "Lion bed", forRole: "lion", alternates: ["cushion"]),
                                      .init(itemID: "kitchen knife", becomes: "Sword", forRole: "all"),
                                      .init(itemID: "tray", becomes: "Feeding tray", forRole: "all"),
                                      .init(itemID: "paper crown", becomes: "Lion crown", forRole: "all")]))
    #expect(store.props?.props.map(\.householdItem) == ["Pillow", "Tray"])   // off-list items (unsafe or not) dropped
    #expect(store.props?.props.first?.forRole == .R2)
    #expect(store.props?.props.first?.libraryID == "pillow")
    _ = await store.apply(.swapProp(oldID: "tray", newID: "books", becomes: "Snack tray"))
    #expect(store.props?.props[1].id == "tray" && store.props?.props[1].libraryID == "books" && store.props?.props[1].becomes == "Snack tray")
    _ = await store.apply(.skipProp("pillow"))
    #expect(store.props?.props.first?.isSkipped == true && store.props?.props.count == 2)   // stays on screen
    _ = await store.apply(.finishPlanning)
    for _ in 0..<50 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(20)) }
    #expect(store.phase == .kitReady)
    #expect(!llm.users.joined().contains("{P"))
}

@Test @MainActor func sixKidsGetSixDistinctRankedRoles() async {
    let store = AdventureStore(service: nil)
    store.beginConversation()
    _ = await store.apply(.setPlayerCount(6)); _ = await store.confirmYes()
    _ = await store.apply(.setRoles(["Captain", "Flight Attendant", "Co-Pilot", "Passenger", "Passenger", "Passenger"]
        .map { .init(roleName: $0, job: "") }))
    // Round C1: repeats are dropped and generic extras fill in: 6 different titles, one kid each.
    #expect(store.plan?.roles.map(\.roleName) == ["Captain", "Flight Attendant", "Co-Pilot", "Passenger", "Helper", "Lookout"])
    #expect(store.plan?.roles.allSatisfy { $0.count == 1 } == true && store.playingRoles.count == 6)
}

@Test func toolsNeverAskForNames() {
    let tools = Realtime.json(["t": Realtime.tools])
    #expect(!tools.contains("set_players") && !tools.contains("player_name") && !tools.contains("for_player") && !tools.contains("\"names\""))
    #expect(tools.contains("set_player_count"))
    #expect(Realtime.instructions.contains("NEVER ask for names"))
}

@Test @MainActor func stepRailJumpsBackWithoutLosingState() async {
    let store = await storeWithKit(owners: [.R1, .all, .all, .all], players: 2)
    #expect(store.reachedStep == .print)
    store.beginPlay()
    if case .handoff = store.phase { store.badgeTapped(.R1) }
    #expect(store.reachedStep == .play)
    let playPhase = store.phase
    store.goTo(.getReady)
    #expect(store.phase == .props && store.props != nil && store.presenting == .props)
    store.goTo(.print)
    #expect(store.phase == .kitReady && store.kit != nil)
    store.goTo(.play)
    #expect(store.phase == playPhase)          // back where they were
    store.newGame()
    #expect(store.reachedStep == nil)
    store.goTo(.play)
    #expect(store.phase == .hello)             // can't jump ahead
}

/// Chat panel transcript from Realtime event fixtures: typed, spoken and streamed turns, in order.
@Test func transcriptShowsEveryTurnInOrder() {
    var t = RealtimeTranscript()
    let fixtures = [
        #"{"type":"response.output_audio_transcript.delta","delta":"Hi! I'm "}"#,
        #"{"type":"response.output_audio_transcript.delta","delta":"Nutmeg!"}"#,
        #"{"type":"response.output_audio_transcript.done","transcript":"Hi! I'm Nutmeg!"}"#,
    ]
    for f in fixtures { t.apply(Realtime.parse(f)) }
    #expect(t.lines.map(\.text) == ["Hi! I'm Nutmeg!"])
    t.kidTyped("A vet clinic for dinosaurs!")
    #expect(t.lines.last == .init(id: t.lines.last!.id, fromNutmeg: false, text: "A vet clinic for dinosaurs!"))
    // Nutmeg starts answering, then the kid's spoken turn finishes transcribing: it lands before her reply.
    t.apply(Realtime.parse(#"{"type":"response.output_audio_transcript.delta","delta":"Ooh, dinos"}"#))
    t.apply(Realtime.parse(#"{"type":"conversation.item.input_audio_transcription.completed","transcript":"There are 3 of us"}"#))
    t.apply(Realtime.parse(#"{"type":"response.output_audio_transcript.delta","delta":"aurs!"}"#))
    t.apply(Realtime.parse(#"{"type":"response.output_audio_transcript.done","transcript":"Ooh, dinosaurs!"}"#))
    t.apply(Realtime.parse(#"{"type":"conversation.item.input_audio_transcription.completed","transcript":"  "}"#))   // empty: ignored
    #expect(t.lines.map(\.text) == ["Hi! I'm Nutmeg!", "A vet clinic for dinosaurs!", "There are 3 of us", "Ooh, dinosaurs!"])
    #expect(t.lines.map(\.fromNutmeg) == [true, false, false, true])
    // Her next response in the same turn (after a tool) joins the same bubble: one reply per kid turn.
    t.apply(Realtime.parse(#"{"type":"response.output_audio_transcript.delta","delta":"How many "}"#))
    t.apply(Realtime.parse(#"{"type":"response.output_audio_transcript.done","transcript":"How many kids?"}"#))
    #expect(t.lines.last?.text == "Ooh, dinosaurs! How many kids?" && t.lines.count == 4)
    // A done without deltas still lands (joined, too).
    t.apply(Realtime.parse(#"{"type":"response.output_audio_transcript.done","transcript":"Let's go!"}"#))
    #expect(t.lines.last?.text == "Ooh, dinosaurs! How many kids? Let's go!" && t.lines.count == 4)
}

@Test func sessionTranscribesKidSpeech() {
    let json = Realtime.json(Realtime.sessionUpdate(voice: "marin", speed: 1))
    #expect(json.contains("\"transcription\""))
}

@Test func varispeedAndApiSpeedNeverStack() {
    #expect(Realtime.apiSpeed(method: .varispeed, requested: 1.3) == 1.0)
    #expect(Realtime.apiSpeed(method: .timePitch, requested: 1.3) == 1.3)
    #expect(Realtime.defaultPitchMethod == .varispeed && Realtime.defaultVarispeedRate == 1.20 && Realtime.defaultVoice == "coral")
    #expect(Realtime.instructions.contains("8–9 years old"))
}

/// Round 6 regression (Haylee): she repeated the question 2-3 times in one turn. Exactly one spoken reply per kid turn.
@Test func oneSpokenReplyPerKidTurn() {
    var g = ResponseGate()
    var creates = 0, spoken = 0
    func create(_ yes: Bool) { if yes { creates += 1 } }
    // Greeting: one response that speaks; no follow-up (the turn-ending nudge no longer asks for one).
    g.newTurn(); create(g.request()); g.created(); g.spoke(); spoken += 1
    create(g.done())
    #expect(creates == 1 && spoken == 1)
    // Kid turn with tools: response 1 calls set_expression + set_game silently (no audio) → ONE follow-up that speaks.
    creates = 0; spoken = 0
    g.newTurn(); create(g.request()); g.created()
    create(g.done())                                  // no audio yet: she still owes her answer
    g.created(); g.spoke(); spoken += 1
    create(g.done())                                  // spoke: nothing more, even if it also called set_expression
    #expect(creates == 2 && spoken == 1)
    // A response that speaks AND calls a tool never gets a second spoken response.
    creates = 0
    g.newTurn(); create(g.request()); g.created(); g.spoke()
    create(g.done())
    #expect(creates == 1)
    // No overlapping responses: a request while one is active waits for done.
    var h = ResponseGate()
    h.newTurn(); let r1 = h.request(); #expect(r1); h.created()
    let r2 = h.request(); #expect(!r2)                             // second request while active: not sent
    let r3 = h.done(); #expect(r3)                                 // sent once the first is done (nothing spoken yet)
    h.created(); h.spoke(); let r4 = h.done(); #expect(!r4)
    // Silent tool loops are capped.
    var k = ResponseGate(); k.newTurn(); _ = k.request(); k.created()
    var loops = 0; while k.done() { loops += 1; k.created() }
    #expect(loops == ResponseGate.maxFollowUps)
    // The writing beat's announcement is the one deliberate second part.
    var b = ResponseGate(); b.newTurn(); _ = b.request(); b.created(); b.spoke(); _ = b.done()
    b.forceFollowUp(); let r5 = b.request(); #expect(r5)
    // Held mic / interrupt: no follow-up (the release asks).
    var p = ResponseGate(); p.newTurn(); _ = p.request(); p.created(); let r6 = p.done(allowFollowUp: false); #expect(!r6)
    // A typed turn while her previous reply is still streaming still gets its own answer.
    var t = ResponseGate(); t.newTurn(); _ = t.request(); t.created()
    t.newTurn(); let r7 = t.request(); #expect(!r7); t.spoke()      // old response's audio: not this turn's
    let r8 = t.done(); #expect(r8)
}

/// A silence re-ask is its own bubble, never glued onto her last reply (it read as repetition, round 6).
@Test func silenceReaskGetsItsOwnBubble() {
    var t = RealtimeTranscript()
    t.apply(.transcriptDone("What should we play: a rocket, a bakery, or a zoo?"))
    t.breakTurn()
    t.apply(.transcriptDelta("Still here! "))
    t.apply(.transcriptDone("Still here! A rocket, a bakery, or a zoo?"))
    #expect(t.lines.count == 2 && t.lines[1].text == "Still here! A rocket, a bakery, or a zoo?")
}
