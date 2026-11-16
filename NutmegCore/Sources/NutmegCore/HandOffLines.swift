import Foundation

/// Round 16 (Haylee, after her daughter's test): every time the app hands control to the kid (a button appears or the
/// screen waits on them), Nutmeg says out loud what to do next, naming the real button labels. One line per moment;
/// "go play" words only once play has started; no stage directions.
public enum HandOffLines {
    /// Print step, once the whole kit has landed (a replay's Print too). Round 26 (Haylee's button audit): icon-only
    /// buttons, a printer and a green ▶ play button, so she names the pictures.
    /// Round 27 (Haylee): both sets are on screen, so she mentions the choice briefly.
    public static let printReady = "Your kit is ready! Want them in color, or plain to color yourself? Tap the ones you like, then the printer! Tap the green play button when you're set!"

    /// The hand-off card. `spokenRole` is `Role.spoken` ("the Captain"). Round 26: the card's one button is a big green
    /// check (no "I'm the Captain!" text: most players can't read).
    public static func handoff(spokenRole: String) -> String {
        "Pass the iPad to \(spokenRole)! Tap the green check when you have the iPad!"
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
        let saysHow = l.contains("tap") && (l.contains("step") || l.contains("check"))
        if !saysHow {
            // Round 26 (Haylee): no Done button; the checklist moves on by itself once every step is checked.
            parts.append(firstScene ? "Tap each step when you do it!" : "Tap the steps as you go!")
        }
        return parts.joined(separator: " ")
    }

    private static func normalized(_ s: String) -> String {
        String(s.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }).split(separator: " ").joined(separator: " ")
    }

    /// The End. Round 26 (Haylee's button audit): two icon buttons, a star (save it, then home) and a house (home without
    /// saving); a replay is already saved, so only the house.
    public static func end(replay: Bool = false) -> String {
        replay ? "The end! What a show! Take a bow! Tap the house to go home!"
            : "The end! What a show! Take a bow! Tap the star to save it, or the house to go home!"
    }

    /// Back to the last checklist from The End (the rail's Play step, or "back to the checklist"). Round 26: the steps
    /// start unchecked again (no Done button: checking them all moves on to The End again).
    public static let backToChecklist = "Here's your checklist again! Tap each step as you play it!"

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
