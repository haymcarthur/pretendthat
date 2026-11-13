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
