import Foundation

/// Bundled airplane game so the demo never dead-ends (no key, no network, or a refusal).
public enum Fallback {
    public struct Airplane: Codable, Sendable { public var ideas: GameIdeas; public var plan: GamePlan; public var props: Props; public var kit: Kit }

    public static let airplane: Airplane = {
        guard let url = Bundle.module.url(forResource: "airplane-fallback", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let a = try? JSONDecoder().decode(Airplane.self, from: data) else {
            fatalError("airplane-fallback.json missing or invalid")   // covered by fallbackDecodes test
        }
        return a
    }()

    /// The fallback game. Round C1: written for 6 ranked roles like every game; the count only says how many play.
    public static func airplane(playerCount: Int) -> Airplane {
        var a = airplane
        a.plan = Sanitizer.clean(a.plan, playerCount: max(1, playerCount))
        a.kit = Sanitizer.clean(a.kit)
        return a
    }
}
