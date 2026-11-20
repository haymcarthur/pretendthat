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

    /// 2026-11-20 (Haylee, checklist scenes): the bundled airplane game's play guide as checklist scenes (4 scenes, 2 to
    /// 3 items per role, a scenario each; `airplane-checklists.json`). The app's fallback and demo mode use it, so demo
    /// screenshots show the new scene format with no AI. `airplane` keeps the round 36 shape (an older game's path).
    public static let checklistScenes: [Scene] = {
        guard let url = Bundle.module.url(forResource: "airplane-checklists", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let scenes = try? JSONDecoder().decode([Scene].self, from: data) else {
            fatalError("airplane-checklists.json missing or invalid")   // covered by a test
        }
        return scenes
    }()

    /// 2026-11-21 (Haylee, one scene with music): the bundled airplane game's guide as ONE scene: the setup checklist
    /// (2 to 3 items per role) and the scene's opener, event pool (12 events across the 6 roles, fair at every count),
    /// finale and music family (`airplane-onescene.json`). The app's fallback and demo mode use it.
    public static let oneScenes: [Scene] = {
        guard let url = Bundle.module.url(forResource: "airplane-onescene", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let scenes = try? JSONDecoder().decode([Scene].self, from: data) else {
            fatalError("airplane-onescene.json missing or invalid")   // covered by a test
        }
        return scenes
    }()

    /// The fallback game with the one-scene guide (no setup scene; the story and the clean-up jobs stay).
    public static func oneSceneAirplane(playerCount: Int) -> Airplane {
        var a = airplane(playerCount: playerCount)
        a.kit.scenes = oneScenes
        a.kit.setup = nil
        a.kit.cleanup?.goals = nil
        return a
    }

    /// The fallback game with the checklist play guide (no setup scene; the story and the clean-up jobs stay).
    public static func checklistAirplane(playerCount: Int) -> Airplane {
        var a = airplane(playerCount: playerCount)
        a.kit.scenes = checklistScenes
        a.kit.setup = nil
        a.kit.cleanup?.goals = nil
        return a
    }

    /// The fallback game. Round C1: written for 6 ranked roles like every game; the count only says how many play.
    public static func airplane(playerCount: Int) -> Airplane {
        var a = airplane
        a.plan = Sanitizer.clean(a.plan, playerCount: max(1, playerCount))
        a.kit = Sanitizer.clean(a.kit)
        return a
    }
}
