import Foundation
import Testing
@testable import NutmegCore

/// Round 37 (Haylee: every prop and printed item is used on purpose, tasks are short and broad, kids can't read): the
/// setup and clean-up scenes may give a role several rows (a solo kid 2 to 4), at most 2 items a row, and every row
/// has a real short label of 2 to 7 words that names its item(s), never "… and more".
@MainActor struct Round37Tests {
    let a = Fallback.airplane
    var roles: [Role] { a.plan.roles }
    var props: [Prop] { a.props.props }

    func view(_ k: Kit, _ n: Int, _ ps: [Prop]? = nil) -> [Scene] { PlayCast.kit(k, roles: roles, players: n, props: ps ?? props).scenes }

    /// The setup / clean-up items a row names (by the jobs' words).
    func named(_ st: Step, _ items: [CoverItem]) -> [CoverItem] { items.filter { Bookends.mentions(st.text, $0) } }

    func checkRows(_ sc: Scene, items: [CoverItem], n: Int, _ tag: String) {
        for st in sc.steps {
            let short = st.short ?? ""
            let w = short.split(separator: " ").count
            #expect(w >= 2 && w <= Bookends.maxRowShortWords, "\(tag) n=\(n) short '\(short)'")
            #expect(!short.lowercased().contains("and more"), "\(tag) n=\(n) '\(short)'")
            #expect(!st.text.contains("After that"), "\(tag) n=\(n) \(st.text)")
            let its = named(st, items)
            // At most 2 jobs a row ("A, then B"; a job's words may mention another item in passing).
            #expect(!its.isEmpty && st.text.components(separatedBy: ", then ").count <= Bookends.maxItemsPerRow, "\(tag) n=\(n) \(st.text)")
            // The label names what the row is about (at least one of its items; usually all).
            #expect(its.contains { Bookends.mentions(short, $0) }, "\(tag) n=\(n) '\(short)' vs \(st.text)")
            #expect(st.text.split(separator: " ").count <= 2 + 2 * Bookends.maxJobWords, "\(tag) n=\(n) long: \(st.text)")
        }
    }

    @Test func aSoloKidGetsTwoToFourShortRowsInTheSetup() {
        let v = view(a.kit, 1)
        let setup = v[1]
        #expect(setup.arc == .setup)
        #expect((2...4).contains(setup.steps.count), "\(setup.steps.map(\.text))")
        #expect(setup.steps.allSatisfy { $0.role == SceneOwner(.R1) })
        checkRows(setup, items: Bookends.setupItems(items: a.kit.items, props: props), n: 1, "setup")
        let all = Bookends.coverItems(items: a.kit.items, props: props)
        #expect(SetupCoverage.missing(v, items: all, roles: roles).isEmpty)
    }

    @Test func whenNoPlayTaskNamesAnythingASoloKidStillGetsShortRows() {
        // The worst case: every item must be set up by one kid. More rows, never more than 2 items a row.
        var k = a.kit
        k.scenes = k.scenes.map { s in var s = s; s.steps = s.steps.map { var st = $0; st.text = "Do a happy dance!"; st.short = "Dance"; return st }; return s }
        let v = view(k, 1)
        let setupItems = Bookends.setupItems(items: k.items, props: props)
        #expect(v[1].steps.count == Int((Double(setupItems.count) / 2).rounded(.up)) || v[1].steps.count == 4)
        checkRows(v[1], items: setupItems, n: 1, "setup")
        #expect(SetupCoverage.notInSetup(v, items: Bookends.coverItems(items: k.items, props: props), roles: roles).isEmpty)
    }

    @Test func everyCountHasRealLabelsAndAtMostTwoItemsARow() {
        let setupItems = Bookends.setupItems(items: a.kit.items, props: props)
        let all = Bookends.coverItems(items: a.kit.items, props: props)
        for n in 1...6 {
            let v = view(a.kit, n)
            checkRows(v[1], items: setupItems, n: n, "setup")
            checkRows(v[5], items: all, n: n, "clean-up")
            #expect(v[1].steps.count <= max(6, n), "n=\(n) \(v[1].steps.count) rows")
            #expect(SetupCoverage.missing(v, items: all, roles: roles).isEmpty, "n=\(n)")
        }
    }

    @Test func aSoloCleanUpPutsEachPropAwayInShortRows() {
        let v = view(a.kit, 1)
        let clean = v.last!
        #expect(clean.arc == .cleanup && clean.steps.count >= 2)
        for it in Bookends.coverItems(items: a.kit.items, props: props) where it.prop != nil {
            #expect(clean.steps.contains { Bookends.mentions($0.text, it) }, "\(it.id)")
        }
    }

    @Test func rowsSplitOneItemARowThenPairs() {
        #expect(Bookends.rows(["a", "b"], players: 1) == [["a"], ["b"]])
        #expect(Bookends.rows(["a", "b", "c", "d"], players: 1) == [["a"], ["b"], ["c"], ["d"]])
        #expect(Bookends.rows(["a", "b", "c", "d", "e", "f"], players: 1) == [["a", "b"], ["c", "d"], ["e"], ["f"]])
        #expect(Bookends.rows(["a", "b", "c", "d", "e", "f", "g", "h", "i"], players: 1).count == 5)
        #expect(Bookends.rows(["a", "b"], players: 3) == [["a"], ["b"]])
        #expect(Bookends.rows(["a", "b"], players: 4) == [["a", "b"]])
        #expect(Bookends.rows(["a", "b", "c"], players: 6) == [["a", "b"], ["c"]])
        #expect(Bookends.rows([], players: 2).isEmpty)
    }

    @Test func aTwoItemLabelNeverSaysAndMore() {
        let items = Bookends.setupItems(items: a.kit.items, props: props)
        let sign = items.first { $0.recipe == .sign }!, money = items.first { $0.recipe == .money }!
        let long1 = ItemJob(item: sign.id, short: "Hang up the big shiny sign", say: "hang up the sign")
        let long2 = ItemJob(item: money.id, short: "Stack all of the money neatly", say: "stack the money")
        let s = Bookends.rowShort([long1, long2], items: [sign, money], verb: "Set up")
        #expect(Bookends.isValidRowShort(s, items: [sign, money]) && s == "Set up the sign and the money", "\(s)")
        // The AI's own shorts are used when they fit and name their items.
        let ok = Bookends.rowShort([ItemJob(item: sign.id, short: "Hang the sign", say: "x"), ItemJob(item: money.id, short: "Stack money", say: "y")],
                                   items: [sign, money], verb: "Set up")
        #expect(ok == "Hang the sign and stack money")
        // A short that doesn't name its item is replaced.
        let vague = Bookends.rowShort([ItemJob(item: sign.id, short: "Make it nice", say: "x")], items: [sign], verb: "Set up")
        #expect(vague == "Set up the sign")
        let prop = items.first { $0.prop != nil }!
        let p = Bookends.rowShort([ItemJob(item: prop.id, short: "Do it", say: "x")], items: [prop], verb: "Put away", cleanup: true)
        #expect(Bookends.isValidRowShort(p, items: [prop]), "\(p)")
    }

    @Test func byVoiceARoleHearsAllItsRowsAndATapHearsOne() {
        let setup = view(a.kit, 1)[1]
        #expect(setup.steps.count >= 2)
        let whole = SceneRowTap.roleLine(rows: setup.steps, index: 1)!
        #expect(whole == setup.steps.map(HandOffLines.task).joined(separator: " "))
        #expect(SceneRowTap.line(rows: setup.steps, index: 1) == HandOffLines.task(setup.steps[1]))
    }

    @Test func theSameCountComposesTheSameWordsEveryTime() {
        // Replay parity: the rows are composed by the app, so a replay with the same count says the same words (clips).
        for n in [1, 3] {
            let x = view(a.kit, n), y = view(a.kit, n)
            #expect(x.map { $0.steps.map(\.text) } == y.map { $0.steps.map(\.text) })
            #expect(x.map { $0.steps.map(\.short) } == y.map { $0.steps.map(\.short) })
        }
    }
}
