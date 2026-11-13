/// What Nutmeg is doing right now. Napping is the step-back screen.
enum NutmegState: String, CaseIterable, Identifiable {
    case idle, listening, thinking, talking, excited, napping
    var id: String { rawValue }
}
