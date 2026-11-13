import Testing
@testable import NutmegCore

@Test func tokenRoundTrip() {
    let t = NameTokens(players: [.init(token: .P1, name: "José", colorIndex: 0, emoji: "💙"),
                                 .init(token: .P2, name: "Sky", colorIndex: 1, emoji: "💚")])
    #expect(t.tokenize("José and Sky fly") == "{P1} and {P2} fly")
    #expect(t.untokenize("Captain {P1}!") == "Captain José!")
}

@Test func tokenizeIsCaseInsensitiveWholeWord() {
    let t = NameTokens(players: [.init(token: .P1, name: "Sky", colorIndex: 0, emoji: "💙")])
    #expect(t.tokenize("sky is in the skyline") == "{P1} is in the skyline")
}

@Test func longestNameFirst() {
    let t = NameTokens(players: [.init(token: .P1, name: "Ann", colorIndex: 0, emoji: "💙"),
                                 .init(token: .P2, name: "Ann Marie", colorIndex: 1, emoji: "💚")])
    #expect(t.tokenize("Ann Marie and Ann") == "{P2} and {P1}")
}

@Test func emptyNameBecomesPlayerN() {
    #expect(NameTokens(players: [.init(token: .P2, name: "  ", colorIndex: 1, emoji: "💚")]).untokenize("{P2}") == "Player 2")
}

@Test func unknownTokenBecomesFriendlyWord() {
    #expect(NameTokens(players: []).untokenize("Hi {P3}!") == "Hi friend!")
}
