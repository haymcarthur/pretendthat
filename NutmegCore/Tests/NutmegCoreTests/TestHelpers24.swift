import Foundation
@testable import NutmegCore

extension AdventureStore {
    /// The confirm step's yes (round 25: no printer question any more; the color question follows, as in round 20).
    @MainActor func confirmYes() async -> String {
        await apply(.confirmPlan)
    }
}
