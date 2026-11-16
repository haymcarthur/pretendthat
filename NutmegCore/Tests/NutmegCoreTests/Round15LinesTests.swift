import Foundation
import Testing
@testable import NutmegCore

/// Deterministic RNG for the line pickers.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: Item 2: kit commentary

@Test func kitCommentaryPoolIsBigAndCoversEveryPageKind() {
    #expect(KitProgress.allLines.count >= 30)
    #expect(Set(KitProgress.allLines).count == KitProgress.allLines.count)   // no duplicate wordings
    for topic in KitProgress.Topic.allCases {
        #expect((KitProgress.lines[topic]?.count ?? 0) >= 5, "\(topic)")
    }
    for line in KitProgress.allLines {
        #expect(line.split(separator: " ").count <= 10, "short: \(line)")
        #expect(!TurnCheck.mentionsGoPlay(line), "\(line)")
        #expect(!TurnCheck.hasSoundEffect(line), "\(line)")
        let l = line.lowercased()
        #expect(!l.contains("ready") && !l.contains("all set") && !l.contains("done!") && !l.contains("roles"), "\(line)")
        #expect(!line.contains("*") && !line.contains("("), "no stage directions: \(line)")
    }
    // Every real page kind has a topic.
    for recipe in KitRecipe.allCases { #expect(KitProgress.lines[KitProgress.Topic(recipe)] != nil) }
}

@Test func kitCommentaryOnlyTalksAboutWhatIsBeingMade() {
    var deck = LineDeck(); var rng = SeededRNG(7)
    // Nothing being drawn: no line.
    let none = KitProgress.next(inProgress: [], saidThisKit: 0, lastTopic: nil, deck: &deck, using: &rng)
    #expect(none == nil)
    // Content still being written: every page and the play guide are in progress.
    #expect(Set(KitProgress.inProgress(kitWritten: false, pendingPages: [])) == Set(KitProgress.Topic.allCases))
    // Content written: only pages whose art is still drawing (never the checklists).
    let t = KitProgress.inProgress(kitWritten: true, pendingPages: [.menu, .menu, .cutouts])
    #expect(Set(t) == [.menu, .cutouts])
    for _ in 0..<4 {
        let pick = KitProgress.next(inProgress: [.menu], saidThisKit: 0, lastTopic: .menu, deck: &deck, using: &rng)
        #expect(pick?.topic == .menu && KitProgress.lines[.menu]!.contains(pick!.line))
    }
    // At most maxLines per kit.
    let capped = KitProgress.next(inProgress: [.sign], saidThisKit: KitProgress.maxLines, lastTopic: nil, deck: &deck, using: &rng)
    #expect(capped == nil)
}

@Test func kitCommentaryIsRandomWithoutRepeatsInASession() {
    var deck = LineDeck(); var rng = SeededRNG(42)
    var said: [String] = []
    // Many kits in one session: no line repeats until the whole pool is used.
    var last: KitProgress.Topic?
    for _ in 0..<KitProgress.allLines.count {
        guard let p = KitProgress.next(inProgress: KitProgress.Topic.allCases, saidThisKit: 0, lastTopic: last,
                                       deck: &deck, using: &rng) else { Issue.record("ran dry"); return }
        said.append(p.line); last = p.topic
    }
    #expect(Set(said).count == said.count)
    #expect(Set(said) == Set(KitProgress.allLines))
    // Different sessions start differently (not always the badges line).
    var firsts = Set<String>()
    for seed in UInt64(1)...12 {
        var d = LineDeck(); var r = SeededRNG(seed)
        if let p = KitProgress.next(inProgress: KitProgress.Topic.allCases, saidThisKit: 0, lastTopic: nil, deck: &d, using: &r) { firsts.insert(p.line) }
    }
    #expect(firsts.count >= 5)
}

@Test func kitCommentaryAvoidsTheSameTopicTwiceInARow() {
    var deck = LineDeck(); var rng = SeededRNG(3)
    var last: KitProgress.Topic?
    for _ in 0..<20 {
        let p = KitProgress.next(inProgress: [.badges, .sign], saidThisKit: 0, lastTopic: last, deck: &deck, using: &rng)!
        if let last { #expect(p.topic != last || deck.exhausted("kit.\(last == .badges ? "sign" : "badges")",
                                                                 pool: KitProgress.lines[last == .badges ? .sign : .badges]!)) }
        last = p.topic
    }
}

@Test func lineDeckCyclesWithoutImmediateRepeat() {
    var deck = LineDeck(); var rng = SeededRNG(9)
    let pool = ["a", "b", "c"]
    var seq: [String] = []
    for _ in 0..<30 { seq.append(deck.draw("k", from: pool, using: &rng)!) }
    for chunk in stride(from: 0, to: 30, by: 3) { #expect(Set(seq[chunk..<chunk + 3]) == Set(pool)) }   // each round uses all
    for i in 1..<seq.count { #expect(seq[i] != seq[i - 1]) }
    let empty = deck.draw("empty", from: [], using: &rng)
    #expect(empty == nil)
}

// MARK: Item 1: skipping a prop

@Test func skipReassuranceSaysPretendThatWithASubstitute() {
    var deck = LineDeck(); var rng = SeededRNG(5)
    var seen = Set<String>()
    for _ in 0..<8 {
        let line = PropSkip.reassurance(item: "Pillow", becomes: "Cozy café seats", deck: &deck, using: &rng)
        #expect(line.contains("pretend that"))
        #expect(line.hasPrefix("That's okay") || line.hasPrefix("No problem"))
        #expect(line.contains("pillow") || line.contains("cozy café seats"))
        #expect(!TurnCheck.hasSoundEffect(line) && !TurnCheck.mentionsGoPlay(line))
        seen.insert(line)
    }
    #expect(seen.count == PropSkip.templates(item: "x", becomes: "y").count)   // varied
    #expect(!PropSkip.templates(item: "Hat", becomes: "the pilot cap").contains { $0.contains("the the") })
    let note = PropSkip.note(item: "Pillow", becomes: "seats", then: "call show_next_prop for the next prop")
    #expect(note.contains("That's okay, we'll just pretend that") && note.contains("show_next_prop") && note.contains("don't call skip_prop"))
}

@MainActor @Test func skipLeadInStartsTheKitLineOnlyWhenFresh() async {
    let store = AdventureStore(service: nil)
    store.kitLeadIn = ("That's okay, we'll just pretend that we have a magic pillow!", Date())
    await store.makeKit()
    #expect(store.nutmegLine.hasPrefix("That's okay, we'll just pretend that we have a magic pillow! Ooh, let me make your kit"))
    #expect(store.kitLeadIn == nil)
    let s2 = AdventureStore(service: nil)
    s2.kitLeadIn = ("That's okay!", Date().addingTimeInterval(-60))   // stale: a later finish by voice
    await s2.makeKit()
    #expect(s2.nutmegLine.hasPrefix("Ooh, let me make your kit"))
}

/// Haylee (round 15): the second "Don't have it" tap moved the card aside but she said nothing. The tap came while her
/// previous reply was still running: the interrupt blocked the follow-up, so the new turn's request was lost.
@Test func tapWhileHerReplyIsRunningStillGetsExactlyOneReply() {
    var g = ResponseGate()
    // Swap reply is running.
    g.newTurn(); let r0 = g.request(); #expect(r0); g.created(); g.spoke()
    // The skip tap: a new turn while that response is active → deferred.
    g.newTurn()
    let r1 = g.request(); #expect(!r1)
    #expect(g.deferredTurn)
    // The old (cancelled) response ends: the session takes the deferred turn and asks again.
    let t1 = g.takeDeferredTurn(); #expect(t1)
    #expect(!g.deferredTurn && !g.active)
    let r2 = g.request(); #expect(r2)          // the new turn's tool-first pass
    g.created(); g.toolCalled()
    let d1 = g.done(); #expect(d1)             // silent pass done: ONE spoken follow-up
    g.created(); g.spoke()
    let d2 = g.done(); #expect(!d2)            // spoke: nothing more
    // A request in the SAME turn while active is not a deferred turn (it follows on done as before).
    var h = ResponseGate(); h.newTurn(); _ = h.request(); h.created()
    let r3 = h.request(); #expect(!r3); #expect(!h.deferredTurn)
    let t2 = h.takeDeferredTurn(); #expect(!t2)
    // done() clears it too (no double ask).
    var k = ResponseGate(); k.newTurn(); _ = k.request(); k.created(); k.newTurn(); _ = k.request()
    let d3 = k.done(); #expect(d3)
    let t3 = k.takeDeferredTurn(); #expect(!t3)
}

// MARK: Item 3: checklist cheers

@Test func checklistCheerPraisesThenNamesTheNextStep() {
    var deck = LineDeck(); var rng = SeededRNG(11)
    let steps = ["Wave to the passengers.", "Check the tickets", "Hand out the snacks!"]
    let a = ChecklistCheers.afterCheck(index: 0, steps: steps, checked: [0], deck: &deck, using: &rng)!
    #expect(ChecklistCheers.praise.contains { a.hasPrefix($0) })
    #expect(a.contains("check the tickets") && !a.contains("tickets."))
    // The next step is the next open one after the checked one (or the first open one before it).
    let b = ChecklistCheers.afterCheck(index: 2, steps: steps, checked: [2], deck: &deck, using: &rng)!
    #expect(b.contains("wave to the passengers"))
    // Unchecked: says nothing.
    let unchecked = ChecklistCheers.afterCheck(index: 1, steps: steps, checked: [0], deck: &deck, using: &rng)
    #expect(unchecked == nil)
    // Last step (round 26): nothing here; the checklist moves on by itself and the congratulations leads the next line.
    #expect(ChecklistCheers.afterCheck(index: 1, steps: steps, checked: [0, 1, 2], deck: &deck, using: &rng) == nil)
    #expect(ChecklistCheers.congrats.allSatisfy { !$0.contains("Done") })
}

@Test func checklistCheersAreVaried() {
    var deck = LineDeck(); var rng = SeededRNG(2)
    let steps = ["One", "Two", "Three", "Four", "Five"]
    var lines: [String] = []
    for i in 0..<4 { lines.append(ChecklistCheers.afterCheck(index: i, steps: steps, checked: Set(0...i), deck: &deck, using: &rng)!) }
    let openers = lines.map { l in ChecklistCheers.praise.first { l.hasPrefix($0) }! }
    #expect(Set(openers).count == openers.count)       // no praise repeats
    #expect(ChecklistCheers.praise.count >= 10 && ChecklistCheers.congrats.count >= 6)
    for l in ChecklistCheers.praise + ChecklistCheers.congrats {
        #expect(!TurnCheck.hasSoundEffect(l), "\(l)")
    }
    #expect(ChecklistCheers.phrase("Captain, check the plane.") == "captain, check the plane")
    #expect(ChecklistCheers.phrase("I spy a cloud!") == "I spy a cloud")
}

@MainActor @Test func earlyDoneSaysOneCongratsWithTheNextLine() async {
    let store = await storeWithKit(owners: [.all, .all, .all], players: 1)
    store.beginPlay()
    guard case .scene = store.phase else { Issue.record("not in a scene: \(store.phase)"); return }
    store.autoCheckStep = .zero; store.autoCheckHold = .zero
    store.sceneLeadIn = "Hooray, you did the whole scene!"
    await store.sceneDone()
    #expect(store.nutmegLine.hasPrefix("Hooray, you did the whole scene! "))
    #expect(store.sceneLeadIn == nil)
    // The next line after that carries no congratulations.
    await store.sceneDone()
    #expect(!store.nutmegLine.hasPrefix("Hooray"))
}
