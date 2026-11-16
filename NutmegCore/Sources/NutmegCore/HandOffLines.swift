import Foundation

/// Round 16 (Haylee, after her daughter's test): every time the app hands control to the kid (a button appears or the
/// screen waits on them), Nutmeg says out loud what to do next, naming the real button labels. One line per moment;
/// "go play" words only once play has started; no stage directions.
public enum HandOffLines {
    /// Print step, once the whole kit has landed. Buttons: "Print" and "Let's play!".
    public static let printReady = "Your kit is ready! Tap Print to print it, then tap Let's play when you're set!"

    /// The hand-off card. `spokenRole` is `Role.spoken` ("the Captain"); the card's button reads "I'm the Captain!".
    public static func handoff(spokenRole: String) -> String {
        "Pass the iPad to \(spokenRole), then tap I'm \(spokenRole)!"
    }

    /// The scene's checklist appears: the scene line, then the first step (round 18: she names step 1, the way
    /// ChecklistCheers names each next step), then how to use the list (unless the line already says it).
    /// The first scene of a game gets the full how-to; later scenes a short reminder. The first step is skipped if
    /// the scene line already names it.
    public static func checklist(sceneLine: String, firstScene: Bool, firstStep: String? = nil) -> String {
        let line = sceneLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = line.lowercased()
        var parts: [String] = line.isEmpty ? [] : [endSentence(line)]
        if let step = firstStep {
            let p = ChecklistCheers.phrase(step)
            if !p.isEmpty && !normalized(line).contains(normalized(p)) { parts.append("First, " + p + "!") }
        }
        let saysHow = l.contains("tap") && (l.contains("done") || l.contains("step") || l.contains("check"))
        if !saysHow {
            parts.append(firstScene ? "Tap each step when you do it, then tap Done!" : "Tap the steps as you go, then tap Done!")
        }
        return parts.joined(separator: " ")
    }

    private static func normalized(_ s: String) -> String {
        String(s.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }).split(separator: " ").joined(separator: " ")
    }

    /// The End. Round D1 (Haylee): "Save it to play again" replaces "Play again" on a first play; a replay (already
    /// saved) has "Play it again". Plus "New game", and (right after the last Done!) "Back to the checklist".
    public static func end(canGoBack: Bool, replay: Bool = false) -> String {
        (replay ? "The end! What a show! Take a bow! Tap Play it again to do it again, or New game for a new adventure!"
            : "The end! What a show! Take a bow! Tap Save it to play again, or New game for a new adventure!")
            + (canGoBack ? " " + endBackHint : "")
    }

    /// Round 25 (Haylee): The End has no Back to the checklist button; the Play step on the step rail goes back.
    public static let endBackHint = "Tap Play at the top to see your checklist again."

    /// Back to the checklist from the hand-off card or The End (the checkmarks are restored).
    public static let backToChecklist = "Here's your checklist again! Tap Done when you're finished."

    /// "Hear it again" on the checklist: the scene title, then the steps not checked yet, in order; all the steps
    /// if every one is checked.
    public static func repeatText(title: String, steps: [String], checked: Set<Int>) -> String {
        let open = steps.indices.filter { !checked.contains($0) }
        let read = (open.isEmpty ? Array(steps.indices) : open).map { steps[$0] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = t.isEmpty ? [] : [endSentence(t)]
        if read.count == 1 {
            parts.append(open.isEmpty ? endSentence(read[0]) : "Last step: " + endSentence(ChecklistCheers.phrase(read[0])))
        } else {
            for (n, s) in read.enumerated() {
                let lead = n == 0 ? "First, " : (n == read.count - 1 ? "Last, " : "Then, ")
                parts.append(lead + endSentence(ChecklistCheers.phrase(s)))
            }
        }
        return parts.joined(separator: " ")
    }

    private static func endSentence(_ s: String) -> String {
        guard let last = s.last else { return s }
        return ".!?".contains(last) ? s : s + "."
    }
}
