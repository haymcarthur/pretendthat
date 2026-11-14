import Foundation
import Testing
@testable import NutmegCore

@Test func kitDecodesFromSpecShape() throws {
    let k = try JSONDecoder().decode(Kit.self, from: Fixture.kitJSON)
    #expect(k.items.count == 3)
    #expect(k.scenes.first?.steps.count == 4)
    #expect(k.items[2].bigNumber == nil)
}

@Test func schemasAreStrict() {
    #expect((Schemas.kit()["additionalProperties"] as? Bool) == false)
    for s in [Schemas.gameIdeas(), Schemas.plan(), Schemas.props(), Schemas.kit(), Schemas.turn()] {
        #expect(JSONSerialization.isValidJSONObject(s))
        #expect((s["additionalProperties"] as? Bool) == false)
        let props = (s["properties"] as? [String: Any])?.keys.sorted() ?? []
        #expect(((s["required"] as? [String]) ?? []).sorted() == props)
    }
}

@Test func nestedSchemaObjectsAreStrict() throws {
    let data = try JSONSerialization.data(withJSONObject: Schemas.kit())
    let text = String(decoding: data, as: UTF8.self)
    let objects = text.components(separatedBy: "\"type\":\"object\"").count - 1
    let strict = text.components(separatedBy: "\"additionalProperties\":false").count - 1
    #expect(objects == strict && objects >= 4)
}

@Test func unknownSymbolBecomesStar() {
    #expect(PrintSymbols.safe("rocket.fake") == "star")
    #expect(PrintSymbols.safe("airplane") == "airplane")
}

/// Games are talked about only (no idea cards), so Nutmeg's spoken line names every idea.
@Test func spokenIdeasNameEveryIdea() {
    let i = Fallback.airplane.ideas
    #expect(i.spoken == "Ooh! Let's put on a show! Which one? Airplane, Restaurant, or Animal Doctor?")
    let named = GameIdeas(nutmegSays: "Airplane or Restaurant?", ideas: Array(i.ideas.prefix(2)))
    #expect(named.spoken == "Airplane or Restaurant?")
}
