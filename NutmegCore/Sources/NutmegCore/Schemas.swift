/// JSON Schemas for structured outputs. Every object is strict: additionalProperties false, all fields required.
public enum Schemas {
    static func obj(_ props: [String: Any]) -> [String: Any] {
        ["type": "object", "properties": props, "required": props.keys.sorted(), "additionalProperties": false]
    }
    static func arr(_ items: [String: Any]) -> [String: Any] { ["type": "array", "items": items] }
    static var str: [String: Any] { ["type": "string"] }
    static var bool: [String: Any] { ["type": "boolean"] }
    static var int: [String: Any] { ["type": "integer"] }
    static func enumStr(_ v: [String]) -> [String: Any] { ["type": "string", "enum": v] }
    static let tokens = PlayerToken.allCases.map(\.rawValue)

    public static func gameIdeas() -> [String: Any] {
        obj(["nutmegSays": str, "ideas": arr(obj(["id": str, "title": str, "emoji": str, "pitch": str]))])
    }
    public static func plan() -> [String: Any] {
        obj(["gameTitle": str, "gameEmoji": str, "setting": str, "nutmegSays": str,
             "roles": arr(obj(["player": enumStr(tokens), "roleName": str, "emoji": str, "symbol": str, "job": str]))])
    }
    public static func props() -> [String: Any] {
        obj(["nutmegSays": str, "props": arr(obj(["id": str, "householdItem": str, "becomes": str, "emoji": str,
                                                   "forRole": enumStr(tokens + ["all"]), "safetyOK": bool]))])
    }
    public static func kit() -> [String: Any] {
        obj(["nutmegSays": str,
             "items": arr(obj(["id": str, "kind": enumStr(["card", "sheet"]),
                               "size": enumStr(["ticket", "badge", "bill", "keycard", "fullPage"]),
                               "title": str, "symbol": str, "lines": arr(str), "bigNumber": ["type": ["string", "null"]],
                               "perPlayer": bool, "copies": int, "colorMe": bool])),
             "scenes": arr(obj(["id": str, "owner": enumStr(tokens + ["all"]), "title": str, "emoji": str, "nutmegSays": str,
                                "steps": arr(obj(["emoji": str, "text": str]))]))])
    }
    public static func turn() -> [String: Any] {
        obj(["nutmegSays": str, "understood": bool, "choices": arr(obj(["id": str, "label": str, "emoji": str]))])
    }
}
