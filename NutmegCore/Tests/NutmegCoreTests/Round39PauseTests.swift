import Foundation
import Testing
@testable import NutmegCore

/// Round 39: a spoken/typed "found it" → silent pass (mark_found + show_next_prop, the app says the next prop line)
/// → no spoken follow-up. Before the fix the reply stayed "due" and the app's prop line waited ~10 s.
@Test func foundItSilentPassWithNoFollowUpEndsTheWait() {
    var g = ResponseGate(); var w = ReplyWait()
    g.newTurn(); w.kidTurnEnded()
    let r = g.request(); #expect(r); g.created()
    g.toolCalled()      // mark_found (respond: true)
    g.endTurn()         // show_next_prop: the app says the line (respond: false)
    let followUp = g.done(allowFollowUp: true)
    #expect(!followUp)
    #expect(w.due)                       // the old behavior stopped here: still busy
    w.responseDone(gateActive: g.active)
    #expect(!w.due)                      // nothing is coming: the prop line can play now
}

/// A silent pass that DOES ask for her spoken reply keeps waiting until her audio starts.
@Test func silentPassWithSpokenFollowUpStillWaitsForHerAudio() {
    var g = ResponseGate(); var w = ReplyWait()
    g.newTurn(); w.kidTurnEnded()
    let r = g.request(); #expect(r); g.created(); g.toolCalled()
    let followUp = g.done(allowFollowUp: true)
    #expect(followUp)
    w.responseDone(gateActive: g.active)
    #expect(w.due)                       // the spoken follow-up is on its way
    g.created(); g.spoke(); w.replyBegan()
    #expect(!w.due)
    let d = g.done(); #expect(!d)
    w.responseDone(gateActive: g.active)
    #expect(!w.due)
}
