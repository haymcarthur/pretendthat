import Foundation
@testable import NutmegCore

extension AdventureStore {
    /// Round 24: the confirm step's yes, then "Do you have a printer?" → yes (the round 20 flow, as before).
    @MainActor func confirmWithPrinter() async -> String {
        _ = await apply(.confirmPlan)
        return await apply(.setPrinter(true))
    }
}
