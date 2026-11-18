import Foundation
import Testing
@testable import NutmegCore

@Test func imageRequestShapeAndDecode() async throws {
    let png = Data([0x89, 0x50, 0x4E, 0x47])
    let t = FakeTransport(body: #"{"data":[{"b64_json":"\#(png.base64EncodedString())"}]}"#)
    let c = ImageClient(mode: .direct(apiKey: "k"), transport: t)
    let out = try await c.generate(prompt: "line art", size: "1024x1536")
    #expect(out == png)
    let r = try #require(t.last)
    #expect(r.url?.absoluteString == "https://api.openai.com/v1/images/generations")
    #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer k")
    let body = try bodyJSON(r)
    #expect(body["model"] as? String == ImageClient.models[0])
    #expect(body["size"] as? String == "1024x1536")
}

@Test func imageClientFallsThroughOnUnknownModel() async {
    let c = ImageClient(mode: .direct(apiKey: "k"), transport: FakeTransport(status: 404, body: "{}"))
    await #expect(throws: ClaudeError.http(404)) { _ = try await c.generate(prompt: "x", size: "1024x1536") }
}

@Test func imageClientStopsOnNoCredits() async {
    let t = FakeTransport(status: 429, body: #"{"error":{"code":"credit_balance_exhausted","message":"You have no credits remaining."}}"#)
    let c = ImageClient(mode: .direct(apiKey: "k"), transport: t)
    await #expect(throws: ClaudeError.http(429)) { _ = try await c.generate(prompt: "x", size: "1024x1536") }
    #expect(c.unavailableReason == "no OpenAI credits")
    await #expect(throws: ClaudeError.self) { _ = try await c.generate(prompt: "x", size: "1024x1536") }
}

@Test func imageClientFlagsUnverifiedOrg() async {
    let t = FakeTransport(status: 403, body: #"{"error":{"code":null,"message":"Your organization must be verified to use the model."}}"#)
    let c = ImageClient(mode: .direct(apiKey: "k"), transport: t)
    await #expect(throws: ClaudeError.http(403)) { _ = try await c.generate(prompt: "x", size: "1024x1536") }
    #expect(c.unavailableReason == "organization not verified")
}

@Test func imageClientDoesNotFallThroughOnOtherBadRequest() async {
    let t = FakeTransport(status: 400, body: #"{"error":{"code":"moderation_blocked","message":"Your request was rejected by the safety system."}}"#)
    let c = ImageClient(mode: .direct(apiKey: "k"), transport: t)
    await #expect(throws: ClaudeError.http(400)) { _ = try await c.generate(prompt: "x", size: "1024x1536") }
}

/// Live image check: LIVE_IMAGES=1 tools/with-keys.sh swift test --filter liveImage. Costs one image.
@Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_IMAGES"] == "1"
               && ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.isEmpty == false), .timeLimit(.minutes(4)))
func liveImage() async throws {
    let c = ImageClient(mode: .direct(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!))
    let item = KitItem(id: "menu", recipe: .menu, kind: .sheet, size: .fullPage, title: "Café Menu", symbol: "cup.and.saucer", lines: ["Cocoa $1", "Cupcake $2"],
                       bigNumber: nil, perPlayer: false, copies: 1, colorMe: true, variant: .menuCard, wholePage: true)
    let prompt = KitPagePrompt.prompt(for: item, ctx: KitArtContext(title: "Cozy Café"), style: .fullColor)!.prompt
    do {
        let started = Date()
        let png = try await c.generate(prompt: prompt, size: KitPagePrompt.size)
        try? FileManager.default.createDirectory(atPath: "/tmp/pt-shots2/img", withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: "/tmp/pt-shots2/img/live-image.png"))
        print("LIVE image OK, bytes:", png.count, "model:", c.workingModel ?? "?", "seconds:", Int(Date().timeIntervalSince(started)))
    } catch {
        print("LIVE image FAILED:", error, "reason:", c.unavailableReason ?? "-")
        throw error
    }
}
