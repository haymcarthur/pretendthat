import Foundation

/// Swaps real names for {P1}…{P4} before anything is sent to an AI, and back again for display.
public struct NameTokens: Sendable {
    public let players: [Player]
    public init(players: [Player]) { self.players = players }

    public func tokenize(_ s: String) -> String {
        var out = s
        let named = players.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.name.count > $1.name.count }
        for p in named {
            let name = NSRegularExpression.escapedPattern(for: p.name.trimmingCharacters(in: .whitespaces))
            guard let re = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])\(name)(?![\\p{L}\\p{N}])", options: [.caseInsensitive]) else { continue }
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: NSRegularExpression.escapedTemplate(for: p.token.placeholder))
        }
        return out
    }

    public func untokenize(_ s: String) -> String {
        var out = s
        for t in PlayerToken.allCases {
            let name = players.first { $0.token == t }?.displayName ?? (out.contains(t.placeholder) ? "friend" : "")
            out = out.replacingOccurrences(of: t.placeholder, with: name)
        }
        return out
    }
}
