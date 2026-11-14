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
    #expect((input["turn_detection"] as? [String: Any])?["type"] as? String == "server_vad")
    let names = (session["tools"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
    #expect(names == ["show_game_ideas", "set_game", "set_player_count", "set_roles", "show_props", "swap_prop", "skip_prop", "finish_planning"])
    #expect(Realtime.json(s).contains("\"laundry-basket\""))   // the prop library is an enum in the schema
    // Serializes cleanly.
    #expect(Realtime.json(s).contains("\"server_vad\""))
    #expect(Realtime.json(s).contains("\"threshold\":0.6"))   // no 0.59999999999999998
}

@Test func parsesServerEvents() {
    #expect(Realtime.parse(#"{"type":"session.updated"}"#) == .sessionReady)
    #expect(Realtime.parse(#"{"type":"response.output_audio.delta","delta":"AAEC"}"#) == .audioDelta(Data([0, 1, 2])))
    #expect(Realtime.parse(#"{"type":"input_audio_buffer.speech_started"}"#) == .speechStarted)
    #expect(Realtime.parse(#"{"type":"conversation.item.input_audio_transcription.completed","transcript":"hi"}"#) == .kidTranscript("hi"))
    #expect(Realtime.parse(#"{"type":"response.function_call_arguments.done","name":"set_game","call_id":"c1","arguments":"{\"title\":\"Zoo\"}"}"#)
            == .functionCall(name: "set_game", callID: "c1", arguments: #"{"title":"Zoo"}"#))
    #expect(Realtime.parse(#"{"type":"error","error":{"code":"bad","message":"oops"}}"#) == .error("bad: oops"))
}

@Test func decodesPlanningCalls() {
    #expect(PlanningCall.decode(name: "set_game", arguments: #"{"title":" Zoo "}"#) == .setGame("Zoo"))
    #expect(PlanningCall.decode(name: "set_game", arguments: #"{"title":""}"#) == nil)
    #expect(PlanningCall.decode(name: "set_player_count", arguments: #"{"count":3}"#) == .setPlayerCount(3))
    #expect(PlanningCall.decode(name: "set_player_count", arguments: #"{"count":20}"#) == .setPlayerCount(Players.max))
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
    #expect(store.phase == .players && store.presenting == .none && store.gameTitle == "Zoo")
    _ = await store.apply(.setPlayerCount(2))
    #expect(store.playerCount == 2)
    _ = await store.apply(.setRoles([.init(roleName: "Zookeeper", job: "Feed the lion"),
                                     .init(roleName: "Lion", job: "Roar")]))
    #expect(store.plan?.roles.map(\.roleName) == ["Zookeeper", "Lion"])
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

@Test @MainActor func sevenKidsShareFourRoles() async {
    let store = AdventureStore(service: nil)
    store.beginConversation()
    _ = await store.apply(.setPlayerCount(7))
    _ = await store.apply(.setRoles(["Captain", "Flight Attendant", "Co-Pilot", "Passenger", "Passenger", "Passenger", "Passenger"]
        .map { .init(roleName: $0, job: "") }))
    #expect(store.plan?.roles.map(\.roleName) == ["Captain", "Flight Attendant", "Co-Pilot", "Passenger"])
    #expect(store.plan?.roles.map(\.count) == [1, 1, 1, 4])
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
    // A done without deltas still adds the line.
    t.apply(Realtime.parse(#"{"type":"response.output_audio_transcript.done","transcript":"Let's go!"}"#))
    #expect(t.lines.last?.text == "Let's go!" && t.lines.count == 5)
}

@Test func sessionTranscribesKidSpeech() {
    let json = Realtime.json(Realtime.sessionUpdate(voice: "marin", speed: 1))
    #expect(json.contains("\"transcription\""))
}

@Test func varispeedAndApiSpeedNeverStack() {
    #expect(Realtime.apiSpeed(method: .varispeed, requested: 1.3) == 1.0)
    #expect(Realtime.apiSpeed(method: .timePitch, requested: 1.3) == 1.3)
    #expect(Realtime.defaultPitchMethod == .varispeed && Realtime.defaultVarispeedRate == 1.12)
    #expect(Realtime.instructions.contains("8–9 years old"))
}
