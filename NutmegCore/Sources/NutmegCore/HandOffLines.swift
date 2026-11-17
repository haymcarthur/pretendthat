import Foundation

/// Round 16 (Haylee, after her daughter's test): every time the app hands control to the kid (a button appears or the
/// screen waits on them), Nutmeg says out loud what to do next, naming the real button labels. One line per moment;
/// "go play" words only once play has started; no stage directions.
public enum HandOffLines {
    /// Print step, once the whole kit has landed (a replay's Print too). Round 26 (Haylee's button audit): icon-only
    /// buttons, a printer and a green ▶ play button, so she names the pictures.
    /// Round 27 (Haylee): both sets are on screen, so she mentions the choice briefly.
    public static let printReady = "Your kit is ready! Want them in color, or plain to color yourself? Tap the ones you like, then the printer! Tap the green play button when you're set!"

    /// Round 29 (Haylee, ensemble scenes): a scene opens with ONE flowing line: the "Pretend that" setup, then every
    /// playing role's task by role name. Repeat (the pill) says it again. `scene` is the scene as the players see it.
    /// The first scene of a play also says how to move on (round 16: she names the button; most players can't read).
    public static func sceneOpen(_ scene: Scene, first: Bool = false) -> String {
        PlayCast.sceneSpeech(scene) + (first ? " " + nextSceneHowTo : "")
    }
    public static let nextSceneHowTo = "Tap the green play button for the next scene!"

    /// Round 29: a row's 🔊 reads just that role's task, word for word.
    public static func task(_ step: Step) -> String {
        let t = step.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = t.last else { return t }
        return ".!?".contains(last) ? t : t + "."
    }

    /// The End. Round 26 (Haylee's button audit): two icon buttons, a star (save it, then home) and a house (home without
    /// saving); a replay is already saved, so only the house.
    public static func end(replay: Bool = false) -> String {
        replay ? "The end! What a show! Take a bow! Tap the house to go home!"
            : "The end! What a show! Take a bow! Tap the star to save it, or the house to go home!"
    }
}
