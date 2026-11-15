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
            + "badge:R1..R4 for a role's badge, cutout:N for the Nth line of the cutouts item).",
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
             "roles": nonEmpty(obj(["id": enumStr(roleIDs), "roleName": str, "symbol": str, "job": str,
                                     "count": ["type": "integer", "description": "How many kids play this role (1 unless there are more kids than roles)."]]))])
    }
    public static func props() -> [String: Any] {
        // Props always come from the library (id is the library id; the app shows its hand-drawn art).
        obj(["nutmegSays": str, "props": nonEmpty(obj(["id": enumStr(PropLibrary.ids), "householdItem": str, "becomes": str,
                                                   "forRole": enumStr(roleIDs + ["all"]), "safetyOK": bool]))])
    }
    public static func kit() -> [String: Any] {
        obj(["nutmegSays": str,
             "items": nonEmpty(obj(["id": str,
                               "recipe": ["type": "string", "enum": KitRecipe.allCases.map(\.rawValue),
                                          "description": "Which of the 6 fixed kit item types this is. Use each exactly once, in this order: "
                                            + KitRecipe.allCases.map(\.rawValue).joined(separator: ", ") + "."],
                               "kind": enumStr(["card", "sheet"]),
                               "size": enumStr(["ticket", "badge", "bill", "keycard", "fullPage"]),
                               "title": str, "symbol": str, "lines": arr(str), "bigNumber": ["type": ["string", "null"]],
                               "perPlayer": bool, "copies": int, "colorMe": bool])),
             "scenes": nonEmpty(obj(["id": str, "owner": enumStr(roleIDs + ["all"]), "title": str,
                                "picture": picture("the scene title"), "nutmegSays": str,
                                "steps": nonEmpty(obj(["picture": picture("the main object or action named in this step's text"), "text": str]))]))])
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
