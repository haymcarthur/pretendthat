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
    static var int: [String: Any] { ["type": "integer"] }
    static func enumStr(_ v: [String]) -> [String: Any] { ["type": "string", "enum": v] }
    static let tokens = PlayerToken.allCases.map(\.rawValue)

    public static func gameIdeas() -> [String: Any] {
        obj(["nutmegSays": str, "ideas": nonEmpty(obj(["id": str, "title": str, "emoji": str, "pitch": str]))])
    }
    public static func plan() -> [String: Any] {
        obj(["gameTitle": str, "gameEmoji": str, "setting": str, "nutmegSays": str,
             "roles": nonEmpty(obj(["player": enumStr(tokens), "roleName": str, "emoji": str, "symbol": str, "job": str]))])
    }
    public static func props() -> [String: Any] {
        obj(["nutmegSays": str, "props": nonEmpty(obj(["id": str, "householdItem": str, "becomes": str, "emoji": str,
                                                   "forRole": enumStr(tokens + ["all"]), "safetyOK": bool]))])
    }
    public static func kit() -> [String: Any] {
        obj(["nutmegSays": str,
             "items": nonEmpty(obj(["id": str, "kind": enumStr(["card", "sheet"]),
                               "size": enumStr(["ticket", "badge", "bill", "keycard", "fullPage"]),
                               "title": str, "symbol": str, "lines": arr(str), "bigNumber": ["type": ["string", "null"]],
                               "perPlayer": bool, "copies": int, "colorMe": bool])),
             "scenes": nonEmpty(obj(["id": str, "owner": enumStr(tokens + ["all"]), "title": str, "emoji": str, "nutmegSays": str,
                                "steps": nonEmpty(obj(["emoji": str, "text": str]))]))])
    }
    public static func turn() -> [String: Any] {
        obj(["nutmegSays": str, "understood": bool, "choices": arr(obj(["id": str, "label": str, "emoji": str]))])
    }
}
