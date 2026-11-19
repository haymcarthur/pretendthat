import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-18 (Haylee's dinner game, decisions/2026-11-18-printables-after-lock.md): she locked the phone during the
/// hunt, opened it an hour later on cellular, and a couple of printables' color pages were the app-drawn fallback while
/// their coloring pages were AI pictures. The image calls cut off by the lock were treated as real failures (the color
/// edit had no wait-for-the-app-to-come-back retry, and the color set stopped waiting for its outline after 6 wall-clock
/// minutes and drew a different picture of its own). Now: a call cut off while the app was away is retried once it's
/// back, the two sets of a page are always the same AI picture, and a page that really fails shows "not ready" with
/// Try again (Haylee: no fallback art in live games, show an error).

/// A fake image service that fails like a locked phone: every call while the app is away (or `down`) throws a
/// network error; otherwise generate returns `outline-N` and edit returns "color:" + the image it was given.
final class LockedPhoneImaging: PageImaging, @unchecked Sendable {
    private let lock = NSLock()
    let presence: AppPresence
    private var _down = false
    private(set) var generates = 0, edits = 0
    private(set) var editImages: [Data] = []
    init(presence: AppPresence) { self.presence = presence }
    var down: Bool { get { lock.withLock { _down } } set { lock.withLock { _down = newValue } } }

    func generate(prompt: String, size: String, quality: String) async throws -> Data {
        let n = lock.withLock { generates += 1; return generates }
        try await Task.sleep(for: .milliseconds(5))
        if !presence.isForeground || down { throw URLError(.networkConnectionLost) }
        return Data("outline-\(n)".utf8)
    }
    func edit(image: Data, prompt: String, size: String, quality: String) async throws -> Data {
        lock.withLock { edits += 1; editImages.append(image) }
        try await Task.sleep(for: .milliseconds(5))
        if !presence.isForeground || down { throw URLError(.notConnectedToInternet) }
        return Data("color:".utf8) + image
    }
}

@Suite struct PrintablesAfterLockTests {
    static func fast(_ p: AppPresence) -> AwayPolicy { AwayPolicy(presence: p, pause: .milliseconds(1)) }
    static let ok: @Sendable (Data) async -> PageInspection = { _ in PageInspection(words: nil, lightBoxes: 0) }

    // MARK: AwayRetry

    @Test func aCallCutOffWhileAwayIsRetriedWhenTheAppIsBack() async throws {
        let p = AppPresence()
        let f = LockedPhoneImaging(presence: p)
        p.setForeground(false)   // the phone locks while the page is drawing
        let task = Task { try await AwayRetry.run(Self.fast(p)) { try await f.generate(prompt: "", size: "", quality: "") } }
        try await Task.sleep(for: .milliseconds(150))
        #expect(f.generates <= 2)   // it waits for the app: no burst of calls while locked
        p.setForeground(true)    // back at dinner
        let data = try await task.value
        #expect(String(decoding: data, as: UTF8.self).hasPrefix("outline-"))
    }

    @Test func awayFailuresDoNotUseUpTheRealRetries() async throws {
        let p = AppPresence()
        let f = LockedPhoneImaging(presence: p)
        // Locked and unlocked several times while the call keeps getting cut off: still no give-up.
        let task = Task { try await AwayRetry.run(Self.fast(p)) { try await f.generate(prompt: "", size: "", quality: "") } }
        for _ in 0..<3 {
            p.setForeground(false); try await Task.sleep(for: .milliseconds(30))
            p.setForeground(true); try await Task.sleep(for: .milliseconds(5))
        }
        let data = try await task.value
        #expect(!data.isEmpty)
    }

    @Test func aRealFailureInTheForegroundGivesUpAfterItsRetries() async {
        let p = AppPresence()
        let f = LockedPhoneImaging(presence: p)
        f.down = true   // no network at all, app in the foreground
        await #expect(throws: URLError.self) {
            try await AwayRetry.run(Self.fast(p)) { try await f.generate(prompt: "", size: "", quality: "") }
        }
        #expect(f.generates == 1 + AwayPolicy.defaultForegroundRetries)
    }

    @Test func anUnusableAccountGivesUpAtOnce() async {
        let p = AppPresence()
        let f = LockedPhoneImaging(presence: p)
        f.down = true
        var policy = Self.fast(p)
        policy.giveUp = { _ in true }   // e.g. no OpenAI credits
        await #expect(throws: URLError.self) {
            try await AwayRetry.run(policy) { try await f.generate(prompt: "", size: "", quality: "") }
        }
        #expect(f.generates == 1)
    }

    // MARK: The color page after a lock

    @Test func theColorEditCutOffByTheLockIsRetriedFromTheSameOutline() async throws {
        let p = AppPresence()
        let f = LockedPhoneImaging(presence: p)
        let outline = Data("outline-7".utf8)
        p.setForeground(false)
        let task = Task { await ColorInFlow.color(outline: outline, size: "1024x1536", quality: "low", client: f, away: Self.fast(p), inspect: Self.ok) }
        try await Task.sleep(for: .milliseconds(100))
        p.setForeground(true)
        let r = await task.value
        #expect(r.data == Data("color:".utf8) + outline)   // the AI color page, from THAT outline
        #expect(f.editImages.allSatisfy { $0 == outline })
        #expect(f.generates == 0)                          // never a different picture of its own
    }

    // MARK: The two sets of a page always match

    @Test func theColorSetWaitsForItsOutlineAndNeverDrawsItsOwn() {
        var pairs = PrintablePairs()
        #expect(pairs.colorStart("menu") == .wait)            // however long the phone was locked
        pairs.set("menu", .colorIn, .landed)
        #expect(pairs.colorStart("menu") == .colorIn)
        pairs.set("sign", .colorIn, .failed)
        #expect(pairs.colorStart("sign") == .notReady)        // no picture of its own: both sets show "not ready"
    }

    @Test func aPageOneSetGaveUpOnIsNotReadyInBoth() {
        var pairs = PrintablePairs()
        pairs.set("menu", .colorIn, .landed)
        pairs.set("menu", .fullColor, .failed)               // the coloring page is an AI picture, the color page failed
        #expect(pairs.state("menu", style: .fullColor, live: true) == .notReady)
        #expect(pairs.state("menu", style: .colorIn, live: true) == .notReady)   // not shown alone: they match
        #expect(!PrintablePairs.printable([pairs.state("menu", style: .colorIn, live: true)]))
    }

    @Test func demoModeKeepsTheBuiltInArt() {
        let pairs = PrintablePairs()
        #expect(pairs.state("menu", style: .fullColor, live: false) == .builtIn)
        #expect(PrintablePairs.printable([.builtIn, .ready]))
        #expect(!PrintablePairs.printable([.ready, .drawing]))
    }

    // MARK: The whole page: fails for real → "not ready" → Try again → both AI pictures

    @Test func aPictureThatReallyFailsShowsNotReadyThenTryAgainGivesBothTheAIPicture() async {
        let p = AppPresence()
        let f = LockedPhoneImaging(presence: p)
        let policy = Self.fast(p)
        var pairs = PrintablePairs()
        f.down = true   // the network stays down even with the app open

        // First try: the outline fails after its real retries; the color set never draws its own.
        let first = try? await AwayRetry.run(policy) { try await f.generate(prompt: "menu", size: "", quality: "") }
        #expect(first == nil)
        pairs.set("menu", .colorIn, .failed)
        #expect(pairs.colorStart("menu") == .notReady)
        pairs.set("menu", .fullColor, .failed)
        #expect(pairs.state("menu", style: .fullColor, live: true) == .notReady)   // an error, never fallback art
        #expect(pairs.state("menu", style: .colorIn, live: true) == .notReady)
        #expect(!PrintablePairs.printable([pairs.state("menu", style: .fullColor, live: true)]))   // can't print it

        // The kid taps Try again with the network back: both sides redraw.
        f.down = false
        #expect(pairs.retry("menu") == .both)
        #expect(pairs.state("menu", style: .fullColor, live: true) == .drawing)
        #expect(pairs.state("menu", style: .colorIn, live: true) == .drawing)
        let outline = try? await AwayRetry.run(policy) { try await f.generate(prompt: "menu", size: "", quality: "") }
        #expect(outline != nil)
        pairs.set("menu", .colorIn, .landed)
        #expect(pairs.colorStart("menu") == .colorIn)
        let color = await ColorInFlow.color(outline: outline!, size: "1024x1536", quality: "low", client: f, away: policy, inspect: Self.ok)
        pairs.set("menu", .fullColor, color.data == nil ? .failed : .landed)
        #expect(color.data == Data("color:".utf8) + outline!)   // the color page is THAT outline colored in
        #expect(pairs.state("menu", style: .fullColor, live: true) == .ready)
        #expect(pairs.state("menu", style: .colorIn, live: true) == .ready)
        #expect(PrintablePairs.printable([pairs.state("menu", style: .fullColor, live: true),
                                          pairs.state("menu", style: .colorIn, live: true)]))
    }

    @Test func tryAgainOnAFailedColorPageOnlyRecolorsTheKeptOutline() {
        var pairs = PrintablePairs()
        pairs.set("menu", .colorIn, .landed)
        pairs.set("menu", .fullColor, .failed)
        #expect(pairs.retry("menu") == .colorOnly)          // the outline is kept: one edit, no new drawing
        #expect(pairs.state("menu", style: .fullColor, live: true) == .drawing)
        #expect(pairs.colorStart("menu") == .colorIn)
        #expect(pairs.retry("menu") == PrintablePairs.Redraw.none)   // nothing failed: nothing to redo
    }
}
