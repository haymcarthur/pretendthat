import Foundation
@testable import NutmegCore

extension AdventureStore {
    /// The confirm step's yes (round 25: no printer question; round 26: no color question, the roles come next).
    @MainActor func confirmYes() async -> String {
        await apply(.confirmPlan)
    }

    /// Round 26: a replay's one-card hunt with every saved prop found (✓ on each card), ending on Print.
    @MainActor func replayAllFound() {
        for _ in 0..<12 where replayHuntActive { replayHunt(found: true) }
    }
}
