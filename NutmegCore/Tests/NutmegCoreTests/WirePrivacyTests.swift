import Foundation
import Testing
@testable import NutmegCore

/// Answers every Claude call with a canned, schema-shaped reply and records every outgoing body.
final class RecordingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock(); private var _bodies: [String] = []
    var bodies: [String] { lock.withLock { _bodies } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        lock.withLock { _bodies.append(body) }
        let props = ((((try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any])?["output_config"]
            as? [String: Any])?["format"] as? [String: Any]).flatMap { ($0["schema"] as? [String: Any])?["properties"] as? [String: Any] } ?? [:]
        let answer: String
        if props["ideas"] != nil { answer = Self.encode(Fallback.airplane.ideas) }
        else if props["roles"] != nil { answer = Self.encode(Fallback.airplane.plan) }
        else if props["scenes"] != nil { answer = Self.encode(Fallback.airplane.kit) }
        else if props["props"] != nil { answer = Self.encode(Fallback.airplane.props) }
        else { answer = #"{"nutmegSays":"Ready, Captain?","understood":true,"choices":[]}"# }
        let envelope: [String: Any] = ["stop_reason": "end_turn", "content": [["type": "text", "text": answer]]]
        let data = try JSONSerialization.data(withJSONObject: envelope)
        return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    static func encode<T: Encodable>(_ v: T) -> String { String(decoding: try! JSONEncoder().encode(v), as: UTF8.self) }
}

/// End to end through AdventureStore → PhaseService → ClaudeClient: the app never asks for names, and nothing
/// on the wire carries a name field or a name placeholder (roles-not-names.md).
@Test @MainActor func requestsCarryRolesNeverNames() async throws {
    let wire = RecordingTransport()
    let client = ClaudeClient(config: .init(mode: .direct(apiKey: "test")), transport: wire)
    let store = AdventureStore(service: PhaseService(llm: client))
    await store.start()
    await store.askForIdeas("we want to fly")
    await store.chooseGame("Airplane")
    store.setPlayerCount(3)
    #expect(!store.nutmegLine.lowercased().contains("name"))   // Nutmeg never asks for names
    await store.confirmPlayers()
    #expect(store.plan?.roles.count == 3)
    await store.kidSaid("Can I be the captain?")
    await store.confirmRoles()
    await store.confirmProps()
    store.beginPlay()
    _ = await store.helpRequested()
    #expect(store.usingFallback == false)
    #expect(wire.bodies.count >= 6)
    for body in wire.bodies {
        #expect(!body.contains("{P") && !body.contains("playerName") && !body.contains("\"names\""), "leak: \(body.prefix(800))")
    }
    #expect(wire.bodies.contains { $0.contains("R1") && $0.contains("R3") })
}
