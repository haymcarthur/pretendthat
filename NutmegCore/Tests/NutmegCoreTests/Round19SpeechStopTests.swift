import Foundation
import Testing
@testable import NutmegCore

/// Round 19 (Haylee): a tap that moves on stops her speech; only the newest line plays; the chat keeps what was said.
struct Round19SpeechStopTests {
    @Test func whichActionsStopHer() {
        for a in UserAction.allCases where a != .chatTab && a != .toggleChat { #expect(a.stopsSpeech, "\(a)") }
        #expect(!UserAction.chatTab.stopsSpeech && !UserAction.toggleChat.stopsSpeech)
    }

    @Test func cancelsEveryInFlightResponseAndDropsTheirLateEvents() {
        var s = SpeechStop()
        s.created("resp_A")   // a cheer (out of band)
        s.created("resp_B")   // a scene line
        s.done("resp_A")      // the cheer finished on its own
        let ids = s.cancelAll()
        #expect(ids == ["resp_B"] && s.active.isEmpty)
        #expect(Realtime.json(Realtime.responseCancel(id: "resp_B")).contains("\"response_id\":\"resp_B\""))
        // Late audio / words from the cancelled line never play.
        #expect(s.drops(.audioDelta(Data([1, 2])), responseID: "resp_B"))
        #expect(s.drops(.transcriptDelta("and then"), responseID: "resp_B"))
        #expect(!s.drops(.responseDone, responseID: "resp_B"))   // its done still closes the gate
        // The newest line plays.
        s.created("resp_C")
        #expect(!s.drops(.audioDelta(Data([1])), responseID: "resp_C") && s.active == ["resp_C"])
        // A second stop with nothing playing cancels nothing.
        _ = s.cancelAll(); #expect(s.cancelAll().isEmpty)
    }

    @Test func responseIDFromServerEvents() {
        #expect(Realtime.responseID(#"{"type":"response.output_audio.delta","event_id":"event_1","response_id":"resp_9x","item_id":"item_2","delta":"AAA"}"#) == "resp_9x")
        #expect(Realtime.responseID(#"{"type":"response.created","event_id":"event_3","response":{"object":"realtime.response","id":"resp_77","status":"in_progress"}}"#) == "resp_77")
        #expect(Realtime.responseID(#"{"type":"session.updated"}"#) == nil)
    }

    @Test func transcriptKeepsWhatWasSaidMarkedCutOff() {
        var t = RealtimeTranscript()
        t.apply(.transcriptDone("Hooray, the whole list is done!"))
        t.kidTyped("Done!")
        t.apply(.transcriptDelta("Pass the iPad to the Captain, then tap"))
        t.cutOff()
        #expect(t.lines.last?.text == "Pass the iPad to the Captain, then tap…")
        // Late words of the cut line don't join it; the newest line is its own bubble.
        t.apply(.transcriptDelta("Pretend that the plane is landing!"))
        #expect(t.lines.last?.text == "Pretend that the plane is landing!" && t.lines.count == 4)
        // Cutting twice doesn't stack marks.
        t.cutOff(); t.cutOff()
        #expect(t.lines.last?.text == "Pretend that the plane is landing…")
    }
}
