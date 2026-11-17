import Testing
import Foundation
@testable import NutmegCore

/// Round 13: the voice must be identical on every connect (first, pre-connect, silent reconnect) and for every line.
@Suite struct VoiceConfigTests {
    private func output(_ update: [String: Any]) -> String {
        let s = update["session"] as? [String: Any]
        let audio = s?["audio"] as? [String: Any]
        let o = audio?["output"] as? [String: Any] ?? [:]
        let d = try! JSONSerialization.data(withJSONObject: o, options: [.sortedKeys])
        return String(decoding: d, as: UTF8.self)
    }

    @Test func defaultsAreCoralVarispeed120() {
        let c = VoiceConfig()
        #expect(c.voice == "coral" && c.method == .varispeed && c.rate == 1.20 && c.apiSpeed == 1.0 && c.playbackRate == 1.20)
    }

    @Test func firstConnectAndReconnectSendTheSameVoice() {
        let c = VoiceConfig()
        let games = Array(Suggestions.games.prefix(3))
        let first = c.sessionUpdate(instructions: Realtime.instructions(todayGames: games))
        let ctx = ResumeContext(step: .props, gameTitle: "Airplane", playerCount: 2, roles: ["Captain"],
                                props: [], kit: .notYet, recent: [(fromNutmeg: true, text: "Find a plate!")])
        let again = c.sessionUpdate(instructions: Realtime.resumeInstructions(todayGames: games, context: ctx))
        #expect(output(first) == output(again))
        #expect(output(first).contains("\"voice\":\"coral\""))
        let s1 = first["session"] as? [String: Any], s2 = again["session"] as? [String: Any]
        #expect(NSArray(array: s1?["tools"] as? [Any] ?? []) == NSArray(array: s2?["tools"] as? [Any] ?? []))
        #expect((s1?["output_modalities"] as? [String]) == (s2?["output_modalities"] as? [String]))
    }

    @Test func appLinesUseTheConversationVoiceDescription() {
        let r = Realtime.sayExactly("Your kit is ready!")["response"] as? [String: Any]
        // Round 20: the line is the only input item (no instructions override: the session prefix stays cached).
        #expect(r?["instructions"] == nil)
        let item = (r?["input"] as? [[String: Any]])?.first
        let text = ((item?["content"] as? [[String: Any]])?.first?["text"] as? String) ?? ""
        #expect(text.contains(Realtime.voiceStyle))
        #expect(Realtime.instructions.contains(Realtime.voiceStyle))
        #expect(text.contains("\"Your kit is ready!\""))
    }

    @Test func silentPassIsTextOnlyAndSpokenRepliesSkipTheFaceTool() {
        let silent = Realtime.responseCreate(requiring: ["set_game"])["response"] as? [String: Any]
        #expect((silent?["output_modalities"] as? [String]) == ["text"])
        let spoken = Realtime.responseCreateSpoken()["response"] as? [String: Any]
        // Round 20: no per-response tools at all (the session's one array is the cached prefix).
        #expect(spoken?["tools"] == nil && silent?["tools"] == nil && spoken?["tool_choice"] as? String == "auto")
        let direct = Realtime.responseCreateSpoken(tools: false)["response"] as? [String: Any]
        #expect(direct?["tool_choice"] as? String == "none")
    }
}

@Suite struct PretendLineTests {
    @Test func everySceneIntroSaysPretendThat() {
        #expect(PretendLine.ensure("Pretend that the plane takes off!", index: 0) == "Pretend that the plane takes off!")
        #expect(PretendLine.ensure("Captain, wave hello!", index: 1) == "Pretend that the curtain just went up! Captain, wave hello!")
        #expect(PretendLine.has(PretendLine.ensure("", index: 7)))
        #expect(Prompts.system.contains("EVERY scene's nutmegSays starts with \"Pretend that\""))
    }
    @Test func bundledGameScenesAllSayPretendThat() throws {
        let kit = Sanitizer.clean(Kit(nutmegSays: "", items: [], scenes: (0..<3).map { i in
            Scene(id: "s\(i)", owner: .all, title: "Scene \(i)", picture: .point, nutmegSays: "Go, team \(i)!", steps: [])
        }), roleCount: 2)
        #expect(kit.scenes.allSatisfy { PretendLine.has($0.nutmegSays) })
        #expect(Set(kit.scenes.map(\.nutmegSays)).count == 3)   // varied openers
    }
}

@Test func pretendThatOnAboutOnePropInThree() {
    let says = (1...5).map { AdventureStore.nextPropOutput(id: "p", item: "Towel", becomes: "a cape", n: $0).contains("use the words \"pretend that\"") }
    #expect(says == [false, false, true, false, false])
}
