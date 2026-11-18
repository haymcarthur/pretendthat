import Foundation
import Testing
@testable import NutmegCore

// The plans / printables / saved-game-page round (2026-11-17): printables draw once and color in (with the light-color
// guardrails), plans 5/20 with no intro offers, the saved game page's gating, and the one-time Free Preview copy.

/// A fake image service: records every call; `edits` answers each edit in turn (nil = throws).
final class FakeImaging: PageImaging, @unchecked Sendable {
    private let lock = NSLock()
    private var _edits: [Data?]
    private(set) var editPrompts: [String] = []
    private(set) var editImages: [Data] = []
    private(set) var generates = 0
    init(edits: [Data?]) { _edits = edits }
    struct Failed: Error {}
    func generate(prompt: String, size: String, quality: String) async throws -> Data {
        lock.withLock { generates += 1 }
        return Data([0])
    }
    func edit(image: Data, prompt: String, size: String, quality: String) async throws -> Data {
        let next: Data? = lock.withLock {
            editPrompts.append(prompt); editImages.append(image)
            return _edits.isEmpty ? nil : _edits.removeFirst()
        }
        guard let next else { throw Failed() }
        return next
    }
}

@Suite struct ColorInFlowTests {
    let outline = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
    static let words = ["Moon Bakery", "002"]
    static func ok() -> PageInspection { PageInspection(words: PageWordCheck.check(words: words, lines: ["Moon Bakery", "002"]), lightBoxes: 0) }
    static func pale() -> PageInspection { PageInspection(words: PageWordCheck.check(words: words, lines: ["Moon Bakery", "002"]), lightBoxes: 2) }
    static func misread() -> PageInspection { PageInspection(words: PageWordCheck.check(words: words, lines: ["Moon Bakery", "202"]), lightBoxes: 0) }
    /// The fake device check: the first byte of a color page says what the device "saw".
    static func inspect(_ d: Data) -> PageInspection {
        switch d.first { case 1: ok(); case 2: pale(); default: misread() }
    }

    @Test func aGoodColorPageIsOneEditOfTheExactOutline() async {
        let f = FakeImaging(edits: [Data([1])])
        let r = await ColorInFlow.color(outline: outline, size: "1024x1536", quality: "low", client: f) { Self.inspect($0) }
        #expect(r.data == Data([1]) && r.calls == 1 && r.redraw == nil && !r.keptRedraw)
        #expect(f.editImages == [outline])   // colored in from THAT image
        #expect(f.generates == 0)            // never drawn again
        // The tuned v2 prompt + the letter guardrails.
        let p = f.editPrompts[0]
        #expect(p.hasPrefix("This is a finished coloring page. Color it in"))
        #expect(p.contains("\"002\" stays \"002\""))
        #expect(p.contains("Never fill letters with white, cream, pale yellow or any pastel"))
        #expect(p.contains("never put yellow letters on white"))
        #expect(p.contains("Keep the paper white"))
        #expect(!p.contains("pale cream"))   // v2's "white or a pale cream" paper is white only now
        #expect(!p.lowercased().contains("input_fidelity"))
    }

    /// 2026-11-18 (Haylee): pale letters are measured and logged, never re-colored (the re-color cost ~10¢ a game and
    /// fixed nothing). One edit, the page kept, flagged for the log.
    @Test func paleLettersAreLoggedNotRecolored() async {
        let f = FakeImaging(edits: [Data([2]), Data([1])])
        let r = await ColorInFlow.color(outline: outline, size: "1024x1536", quality: "low", client: f) { Self.inspect($0) }
        #expect(r.calls == 1 && r.redraw == nil && !r.keptRedraw && r.redrawReason == nil)
        #expect(r.data == Data([2]) && r.stillLight && r.first?.lightBoxes == 2)
        #expect(f.editPrompts.count == 1)
        #expect(!f.editPrompts[0].contains("too light to read"))
        // The no-pale-letters rule stays in the prompt.
        #expect(f.editPrompts[0].contains("Never fill letters with white, cream, pale yellow or any pastel"))
        #expect(!ColorInPrompt.prompt(missing: ["002"]).contains("too light to read"))
    }

    @Test func theWordCheckRunsOnTheColorPage() async {
        // The test's real failure: the edit turned "002" into "202".
        let f = FakeImaging(edits: [Data([3]), Data([1])])
        let r = await ColorInFlow.color(outline: outline, size: "1024x1536", quality: "low", client: f) { Self.inspect($0) }
        #expect(r.first?.words?.missing == ["002"])
        #expect(r.redrawReason == "words" && r.keptRedraw && r.data == Data([1]))
        #expect(f.editPrompts[1].contains("letter for letter: \"002\""))
        #expect(f.editImages == [outline, outline])   // the redraw colors the SAME outline again
    }

    @Test func aWorseRedrawKeepsTheFirst() async {
        let f = FakeImaging(edits: [Data([3]), Data([2])])   // a misspelling, then a re-edit that's pale but no better on words
        let r = await ColorInFlow.color(outline: outline, size: "1024x1536", quality: "low", client: f) { Self.inspect($0) }
        #expect(r.calls == 2 && r.data == Data([2]) && r.keptRedraw)   // fewer word misses wins, pale or not
        let g = FakeImaging(edits: [Data([3]), Data([3])])
        let r2 = await ColorInFlow.color(outline: outline, size: "1024x1536", quality: "low", client: g) { Self.inspect($0) }
        #expect(!r2.keptRedraw && r2.data == Data([3]))   // no better: keep the first
    }

    @Test func editsThatFailTwiceLeaveNoPage() async {
        let f = FakeImaging(edits: [nil, nil])
        let r = await ColorInFlow.color(outline: outline, size: "1024x1536", quality: "low", client: f) { Self.inspect($0) }
        #expect(r.data == nil && f.editPrompts.count == 2)   // the edit and its one retry
        // A failed redraw keeps the first page.
        let g = FakeImaging(edits: [Data([3]), nil, nil])
        let r2 = await ColorInFlow.color(outline: outline, size: "1024x1536", quality: "low", client: g) { Self.inspect($0) }
        #expect(r2.data == Data([3]) && r2.redraw == nil)
    }
}

@Suite struct LetterContrastTests {
    typealias RGB = (UInt8, UInt8, UInt8)
    /// A 60 × 40 box: the surrounding is `paper`; inside (10, 10, 40 × 20) three 10-px letters with a 2-px `outline`
    /// and a `fill` inside each.
    static func box(paper: RGB, outline: RGB, fill: RGB) -> TextBoxPixels {
        let w = 60, h = 40
        var px = [UInt8](repeating: 0, count: w * h * 4)
        func set(_ x: Int, _ y: Int, _ c: RGB) { let o = (y * w + x) * 4; px[o] = c.0; px[o + 1] = c.1; px[o + 2] = c.2; px[o + 3] = 255 }
        for y in 0..<h { for x in 0..<w { set(x, y, paper) } }
        for l in 0..<3 {
            let x0 = 12 + l * 13
            for y in 10..<30 { for x in x0..<(x0 + 10) {
                let edge = x < x0 + 2 || x >= x0 + 8 || y < 12 || y >= 28
                set(x, y, edge ? outline : fill)
            } }
        }
        return TextBoxPixels(width: w, height: h, rgba: px, inner: (10, 10, 40, 20))
    }
    static let white: RGB = (255, 255, 255), purple: RGB = (60, 30, 110), ink: RGB = (40, 20, 70)

    @Test func paleFillsAreTooLight() {
        #expect(LetterContrast.judge(Self.box(paper: Self.white, outline: Self.purple, fill: (255, 210, 63))).tooLight)   // yellow on white
        #expect(LetterContrast.judge(Self.box(paper: Self.white, outline: Self.purple, fill: (255, 246, 220))).tooLight)  // cream on white
        #expect(LetterContrast.judge(Self.box(paper: (205, 235, 245), outline: Self.purple, fill: (255, 230, 120))).tooLight)   // pale yellow on light blue
    }

    @Test func strongFillsAndInkLettersAreFine() {
        #expect(!LetterContrast.judge(Self.box(paper: Self.white, outline: Self.ink, fill: Self.ink)).tooLight)            // dark ink letters
        #expect(!LetterContrast.judge(Self.box(paper: Self.white, outline: Self.purple, fill: (255, 107, 107))).tooLight) // coral
        #expect(!LetterContrast.judge(Self.box(paper: Self.white, outline: Self.purple, fill: (79, 195, 247))).tooLight)  // sky blue
        #expect(!LetterContrast.judge(Self.box(paper: Self.purple, outline: Self.ink, fill: Self.white)).tooLight)        // white on a purple board
        #expect(!LetterContrast.judge(Self.box(paper: Self.white, outline: Self.white, fill: Self.white)).tooLight)       // nothing to judge
    }

    @Test func aPageIsTooLightWhenAnyBoxIs() {
        #expect(LetterContrast.pageTooLight([.init(ratio: 3), .init(ratio: 1.2)]))
        #expect(!LetterContrast.pageTooLight([.init(ratio: 3), .init(ratio: nil)]))
        #expect(LetterContrast.ratio(1, 0) == 21)
    }
}

@Suite struct ImageEditRequestTests {
    @Test func theEditIsMultipartWithTheImageAndNoFidelity() async throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let t = FakeTransport(body: #"{"data":[{"b64_json":"\#(png.base64EncodedString())"}],"usage":{"input_tokens":1668,"output_tokens":664,"input_tokens_details":{"text_tokens":132,"image_tokens":1536}}}"#)
        let c = ImageClient(mode: .direct(apiKey: "k"), transport: t)
        let out = try await c.edit(image: Data([7, 7, 7]), prompt: "color it in", size: "1024x1536", quality: "low")
        #expect(out == png)
        let r = try #require(t.last)
        #expect(r.url?.absoluteString == "https://api.openai.com/v1/images/edits")
        #expect(r.value(forHTTPHeaderField: "content-type")?.hasPrefix("multipart/form-data; boundary=") == true)
        let body = String(decoding: try #require(r.httpBody), as: UTF8.self)
        #expect(body.contains("name=\"model\"\r\n\r\n\(ImageClient.models[0])"))
        #expect(body.contains("name=\"prompt\"\r\n\r\ncolor it in"))
        #expect(body.contains("name=\"quality\"\r\n\r\nlow") && body.contains("name=\"n\"\r\n\r\n1"))
        #expect(body.contains("name=\"image\"; filename=\"page.png\"") && body.contains("\u{07}\u{07}\u{07}"))
        #expect(!body.contains("input_fidelity"))   // gpt-image-2.6-flare rejects it
    }

    @Test func theRelayEditCarriesTheTokenAndTheShowTicket() {
        ShowTicket.set("tick")
        defer { ShowTicket.set(nil) }
        let c = ImageClient(mode: .relay(url: URL(string: "https://r.dev")!, token: "t"))
        let r = c.editRequest(image: Data([1]), prompt: "p", size: "1024x1536", model: "m")
        #expect(r.url?.absoluteString == "https://r.dev/v1/images/edits")
        #expect(r.value(forHTTPHeaderField: RelayConfig.tokenHeader) == "t")
        #expect(r.value(forHTTPHeaderField: "X-PT-Show") == "tick")
    }

    @Test func anEditCostsTheImageInputToo() {
        let s = ImageUsageLog.Snapshot(requests: 1, rateLimited: 0, inputTokens: 1668, outputTokens: 664, peakPerMinute: 1,
                                       imageInputTokens: 1536)
        // 132 text × $5 + 1536 image × $8 + 664 out × $30 per 1M ≈ 3.3¢ (the test's measured edit).
        #expect(abs(s.dollars - 0.0329) < 0.0002)
    }
}

@Suite struct PlansFiveTwentyTests {
    @Test func sizesAndPrices() {
        #expect(PlanTier.freePreview.allowance == 2 && PlanTier.showPass.allowance == 5 && PlanTier.seasonPass.allowance == 20)
        #expect(PlanCatalog.showPass.billedText(.monthly) == "$9.99/month" && PlanCatalog.showPass.billedText(.yearly) == "$99.99/year")
        #expect(PlanCatalog.seasonPass.billedText(.monthly) == "$24.99/month" && PlanCatalog.seasonPass.billedText(.yearly) == "$249.99/year")
        #expect(StoreProducts.storeDescription(StoreProducts.showPassMonthly) == "5 new games a month. Play your saved games again with Nutmeg anytime.")
        #expect(StoreProducts.storeDescription(StoreProducts.seasonPassYearly)?.hasPrefix("20 new games a month.") == true)
    }

    @Test func theFreePreviewReadsAsOneTimeEverywhere() {
        // Every grown-up string that mentions the free games: never "a month" / "per month" / "monthly".
        let free = ShowAllowance(tier: .freePreview, used: 1, refillsAt: nil)
        let lines = [OnboardingCopy.plansV3Title, OnboardingCopy.plansV3Lead, OnboardingCopy.freeGamesButton, OnboardingCopy.plansTitle,
                     OnboardingCopy.plansBody, OnboardingCopy.freePreviewButton, OnboardingCopy.outOfShowsTitle,
                     OnboardingCopy.outOfShowsBody, free.summary]
        for l in lines where l.lowercased().contains("free") {
            let w = l.lowercased()
            #expect(!w.contains("a month") && !w.contains("per month") && !w.contains("monthly") && !w.contains("/mo"), "\(l)")
        }
        #expect(free.summary == "1 of 2 free games to try left")
        #expect(free.refillText() == nil)
        #expect(OnboardingCopy.plansV3Title == "2 free games to try")
        #expect(OnboardingCopy.plansBody.hasPrefix("2 free games to try."))
    }

    @Test func noCopyPromisesFreeReplays() {
        // Saved game page round (Haylee): printables are always yours; playing with Nutmeg is part of a pass; the
        // Free Preview games don't replay for free either.
        let all = [OnboardingCopy.plansV3Lead, OnboardingCopy.plansBody, OnboardingCopy.replaysLine, OnboardingCopy.plansGrownUpsBody,
                   OnboardingCopy.outOfShowsBody, OnboardingCopy.planOutBody(.showPass, refill: nil),
                   PurchaseOutcome.purchased(.seasonPass).message, StoreProducts.storeDescription(StoreProducts.showPassMonthly) ?? "",
                   SavedGamePageCopy.grownUpTitle, SavedGamePageCopy.grownUpBody] + GrownUpsCopy.about.map { $0.body }
        for l in all {
            let w = l.lowercased()
            #expect(!w.contains("always free") && !w.contains("still free") && !w.contains("free to play")
                    && !w.contains("as many times as they like, free") && !w.contains("free preview games always"), "\(l)")
        }
    }
}

@Suite struct SavedGamePageGatingTests {
    @Test func aPassPlaysTheReplay() {
        #expect(SavedGamePage.playAction(consent: true, hasPass: true) == .replay)
    }
    @Test func noPassAsksAGrownUpEvenForAFreePreviewGame() {
        // Haylee (2026-11-17): the 2 Free Preview games get the same experience: no pass → ask a grown-up.
        #expect(SavedGamePage.playAction(consent: true, hasPass: false) == .askGrownUp)
        #expect(SavedGamePage.playAction(consent: false, hasPass: false) == .askGrownUp)
        #expect(NewGameGate.replay(consent: true, hasPass: false) == .needsPlan)
    }
    @Test func aPassWithoutConsentShowsTheConsentCard() {
        #expect(SavedGamePage.playAction(consent: false, hasPass: true) == .needsConsent)
    }
    @Test func thePageAlwaysPrintsAllSixRoles() {
        #expect(SavedGamePage.printPlayers == 6)
    }
    @Test func nutmegsLinesAndTheGrownUpCard() {
        #expect(SavedGamePageCopy.hello(title: "Bakery on the Moon") == "Want to play Bakery on the Moon again? Tap play!")
        #expect(SavedGamePageCopy.askGrownUp(title: "Bakery on the Moon") == "Ooh, Bakery on the Moon! Let's ask a grown-up to help us play this one again.")
        #expect(SavedGamePageCopy.grownUpTitle == "Your saved games are still yours.")
        #expect(SavedGamePageCopy.grownUpBody == "View and print this game's kit anytime. Playing saved games with Nutmeg is part of the Show Pass and the Season Pass.")
        // Kids never see prices on the page or the kid card.
        for l in [SavedGamePageCopy.play, SavedGamePageCopy.askGrownUp(title: "X"), SavedGamePageCopy.hello(title: "X"), SavedGamePageCopy.grownUps] {
            #expect(!l.contains("$") && !l.lowercased().contains("pass"))
        }
    }
    @Test func replaysNeverCountAndNewGamesCountOnce() {
        // The counting rule still holds: a NEW game counts (when its kit is made); a replay never does.
        let d = FakeDefaults(), free = FreePreviewCounter(defaults: d)
        #expect(free.gameStarted(isReplay: true) == 0)
        #expect(free.gameStarted(isReplay: false) == 1)
        #expect(free.gameStarted(isReplay: true) == 1)
        let plan = PlanShowCounter(defaults: d)
        let w = ShowWindow.containing(Date(), anchor: Date().addingTimeInterval(-86400), tier: .showPass)
        #expect(plan.gameStarted(in: w, isReplay: true) == 0)
        #expect(plan.gameStarted(in: w, isReplay: false) == 1)
    }
}
