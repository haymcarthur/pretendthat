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
    #expect(names == ["show_game_ideas", "set_game", "set_players", "set_roles", "show_props", "finish_planning"])
    // Serializes cleanly.
    #expect(Realtime.json(s).contains("\"server_vad\""))
    #expect(Realtime.json(s).contains("\"threshold\":0.6"))   // no 0.59999999999999998
}

@Test func parsesServerEvents() {
    #expect(Realtime.parse(#"{"type":"session.updated"}"#) == .sessionReady)
    #expect(Realtime.parse(#"{"type":"response.output_audio.delta","delta":"AAEC"}"#) == .audioDelta(Data([0, 1, 2])))
    #expect(Realtime.parse(#"{"type":"input_audio_buffer.speech_started"}"#) == .speechStarted)
    #expect(Realtime.parse(#"{"type":"response.function_call_arguments.done","name":"set_game","call_id":"c1","arguments":"{\"title\":\"Zoo\"}"}"#)
            == .functionCall(name: "set_game", callID: "c1", arguments: #"{"title":"Zoo"}"#))
    #expect(Realtime.parse(#"{"type":"error","error":{"code":"bad","message":"oops"}}"#) == .error("bad: oops"))
}

@Test func decodesPlanningCalls() {
    #expect(PlanningCall.decode(name: "set_game", arguments: #"{"title":" Zoo "}"#) == .setGame("Zoo"))
    #expect(PlanningCall.decode(name: "set_game", arguments: #"{"title":""}"#) == nil)
    #expect(PlanningCall.decode(name: "set_players", arguments: #"{"names":["Mia","Sam"],"count":2}"#) == .setPlayers(names: ["Mia", "Sam"], count: 2))
    #expect(PlanningCall.decode(name: "set_players", arguments: #"{"names":[],"count":6}"#) == .setPlayers(names: [], count: 6))
    if case .showGameIdeas(let ideas)? = PlanningCall.decode(name: "show_game_ideas", arguments:
        #"{"ideas":[{"title":"A","pitch":""},{"title":"B","pitch":""},{"title":"C","pitch":""},{"title":"D","pitch":""}]}"#) {
        #expect(ideas.map(\.title) == ["A", "B", "C"])
    } else { Issue.record("ideas not decoded") }
    #expect(PlanningCall.decode(name: "finish_planning", arguments: "{}") == .finishPlanning)
    #expect(PlanningCall.decode(name: "unknown", arguments: "{}") == nil)
}

@Test @MainActor func conversationDrivesStore() async {
    let llm = FakeLLM(responses: ["Kit": Fallback.airplane.kit])
    let store = AdventureStore(service: PhaseService(llm: llm))
    store.beginConversation()
    #expect(store.phase == .pickGame)
    _ = await store.apply(.showGameIdeas([GameIdea(id: "a", title: "Zoo", emoji: "", pitch: "")]))
    #expect(store.presenting == .ideas)
    _ = await store.apply(.setGame("Zoo"))
    #expect(store.phase == .players && store.presenting == .none && store.gameTitle == "Zoo")
    _ = await store.apply(.setPlayers(names: ["Mia", "Sam"], count: 2))
    #expect(store.players.map(\.name) == ["Mia", "Sam"])
    _ = await store.apply(.setRoles([.init(playerName: "sam", roleName: "Zookeeper", job: "Feed Mia's lion"),
                                     .init(playerName: "Mia", roleName: "Lion", job: "Roar")]))
    #expect(store.plan?.role(for: .P2)?.roleName == "Zookeeper")
    #expect(store.plan?.role(for: .P2)?.job == "Feed {P1}'s lion")   // names tokenized before Claude ever sees them
    #expect(store.presenting == .roles)
    _ = await store.apply(.showProps([.init(householdItem: "Pillow", becomes: "Lion bed", forPlayer: "Mia", safe: true),
                                      .init(householdItem: "Knife", becomes: "Sword", forPlayer: "all", safe: false)]))
    #expect(store.props?.props.map(\.householdItem) == ["Pillow"])
    #expect(store.props?.props.first?.forRole == .P1)
    #expect(store.props?.props.first?.emoji == "")
    _ = await store.apply(.finishPlanning)
    for _ in 0..<50 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(20)) }
    #expect(store.phase == .kitReady)
    #expect(!llm.users.joined().contains("Mia"))
}

@Test @MainActor func directorModeFromConversation() async {
    let store = AdventureStore(service: nil)
    store.beginConversation()
    _ = await store.apply(.setPlayers(names: [], count: 7))
    #expect(store.directorMode && store.players.count == 4)
}
