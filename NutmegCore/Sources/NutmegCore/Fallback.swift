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

    /// The fallback plan/kit cast for the current number of kids (5+ kids share roles: more Passengers).
    public static func airplane(playerCount: Int) -> Airplane {
        var a = airplane
        if playerCount > a.plan.roles.count, let i = a.plan.roles.firstIndex(where: { $0.roleName == "Passenger" }) {
            // Extra kids become extra Passengers: put Passenger last (normalize gives the last role the extras)
            // and keep scene owners and props pointing at the same roles.
            var order = a.plan.roles; order.append(order.remove(at: i))
            let map = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element.id.rawValue, RoleID.allCases[$0.offset].rawValue) })
            a.plan.roles = order
            a.kit.scenes = a.kit.scenes.map { var s = $0; s.owner = SceneOwner(rawValue: map[s.owner.rawValue] ?? "all") ?? .all; return s }
            a.props.props = a.props.props.map { var p = $0; p.forRole = SceneOwner(rawValue: map[p.forRole.rawValue] ?? "all") ?? .all; return p }
        }
        a.plan = Sanitizer.clean(a.plan, playerCount: max(1, playerCount))
        a.kit = Sanitizer.clean(a.kit, roleCount: a.plan.roles.count)
        return a
    }
}
