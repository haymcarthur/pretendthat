/// JSON Schemas for structured outputs. Every object is strict: additionalProperties false, all fields required.
public enum Schemas {
    static func obj(_ props: [String: Any]) -> [String: Any] {
        ["type": "object", "properties": props, "required": props.keys.sorted(), "additionalProperties": false]
    }
    static func arr(_ items: [String: Any]) -> [String: Any] { ["type": "array", "items": items] }
    /// Non-empty array. The API accepts only minItems 0 or 1 and no maxItems, so other limits live in
    /// the prompt, `Sanitizer` (too many) and `Validate` (too few).
    static func nonEmpty(_ items: [String: Any]) -> [String: Any] { ["type": "array", "items": items, "minItems": 1] }
    static var str: [String: Any] { ["type": "string"] }
    static var bool: [String: Any] { ["type": "boolean"] }
    /// One picture (checklist-pictures.md): kind + id, both enums. Which ids fit which kind is in the description and
    /// the prompt; `PictureResolver` falls back to action "point" for a mismatch.
    static func picture(_ of: String) -> [String: Any] {
        ["type": "object", "description": "The ONE picture for \(of). kind prop: id is a household-prop library id; "
            + "kind action: id is an action id; kind kit: id is a printed item of THIS kit (ticket, money, menu, sign, "
            + "badge:R1..R6 for a role's badge, cutout:N for the Nth line of the cutouts item).",
         "properties": ["kind": enumStr(PictureKind.allCases.map(\.rawValue)), "id": enumStr(PictureResolver.allIDs)],
         "required": ["id", "kind"], "additionalProperties": false]
    }
    static var int: [String: Any] { ["type": "integer"] }
    static func enumStr(_ v: [String]) -> [String: Any] { ["type": "string", "enum": v] }
    static let roleIDs = RoleID.allCases.map(\.rawValue)

    public static func gameIdeas() -> [String: Any] {
        obj(["nutmegSays": str, "ideas": nonEmpty(obj(["id": str, "title": str, "pitch": str]))])
    }
    public static func plan() -> [String: Any] {
        obj(["gameTitle": str, "setting": str, "nutmegSays": str,
             // Round C1: exactly 6 ranked roles (R1 the lead … R6), one kid each; the first N play.
             "roles": nonEmpty(obj(["id": enumStr(roleIDs), "roleName": str, "symbol": str, "job": str]))])
    }
    public static func props() -> [String: Any] {
        // Props always come from the library (id is the library id; the app shows its hand-drawn art).
        obj(["nutmegSays": str, "props": nonEmpty(obj(["id": enumStr(PropLibrary.ids), "householdItem": str, "becomes": str,
                                                   "forRole": enumStr(roleIDs + ["all"]), "safetyOK": bool,
                                                   // Round 24: a short kid-friendly "why it works".
                                                   "reason": str]))])
    }
    public static func kit() -> [String: Any] {
        obj(["nutmegSays": str,
             // Round 45: the type comes from the printables library; the app fixes each type's shape (size, copies,
             // numbers, layout), so the answer only says what's ON it: title, lines and the pictures to draw.
             "items": nonEmpty(obj(["id": str,
                               "recipe": ["type": "string", "enum": KitRecipe.allCases.map(\.rawValue),
                                          "description": "Which printables-library type this is (each type at most once; badges first)."],
                               "title": str, "symbol": str, "lines": arr(str),
                               "pictures": ["type": "array", "items": ["type": "string"],
                                            "description": "The things to draw for it (short noun phrases, never words): one, or one per line for a menu, order slips, clue cards, mission cards, medals, stickers or labels; none for badges, cutouts and the decoder."],
                               // Round 36 (Haylee): every page is used on purpose; the play guide receives it.
                               "purpose": ["type": "string", "description": "ONE short sentence: what the kids do with this page while they play."]])),
             // Round 29 (ensemble scenes): no scene owner and no pictures (the rows show each role's character);
             // every task belongs to one role, or is the scene's solo task.
             "scenes": nonEmpty(obj(["id": str, "title": str, "nutmegSays": str,
                                "steps": nonEmpty(obj(["text": ["type": "string", "description": "What Nutmeg SAYS for this task (round 34: the role title, the job, then 1 or 2 concrete ideas with their props or pages)."], "short": ["type": "string", "description": "What the row SHOWS: 3 to 7 words, broad, no role title."],
                                                       "role": ["type": "string", "enum": roleIDs + ["solo"],
                                                                "description": "Who this task is for (its text calls that role by its title): ONE task per role R1 to R6 per scene, plus one solo task (one kid playing alone as R1)."]]))]))])
    }
    /// Round 20: the kit in two parts, the pages (at the roles) and the play guide (when the hunt ends).
    public static func kitPages() -> [String: Any] {
        var k = kit(); var p = k["properties"] as! [String: Any]
        p["scenes"] = nil; k["properties"] = p; k["required"] = ["items", "nutmegSays"]
        return k
    }
    public static func kitScenes() -> [String: Any] {
        var k = kit(); var p = k["properties"] as! [String: Any]
        p["items"] = nil; k["properties"] = p; k["required"] = ["nutmegSays", "scenes"]
        return k
    }
    public static func turn() -> [String: Any] {
        obj(["nutmegSays": str, "understood": bool, "choices": arr(obj(["id": str, "label": str]))])
    }
}
