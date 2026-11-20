import Foundation
import Testing
@testable import NutmegCore

/// Round 19: guardrails on what kids can talk about or get made.
struct Round19SafetyTests {
    static let unsafe: [(String, Sanitizer.SafetyCategory)] = [
        ("let's play with guns", .violence), ("a game where we kill the bad guys", .violence), ("K1LL them all", .violence),
        ("k i l l", .violence), ("kiiiill", .violence), ("a knife fight", .violence), ("knife fight", .violence), ("a real sword to cut", .violence), ("real sword to cut", .violence), ("gun", .violence),
        ("blow it up with a bomb", .violence), ("I want to shoot people", .violence),
        ("I want to kill myself", .selfHarm), ("suicide game", .selfHarm),
        ("something sexy", .sexual), ("naked people", .sexual), ("$ex", .sexual),
        ("let's drink beer", .drugs), ("a weed shop", .drugs), ("we smoke cigarettes", .drugs),
        ("a zombie horror house with blood", .scary), ("gory monsters", .scary),
        ("I hate them, they're nazis", .hate),
        ("my address is 42 Maple Street", .personalInfo), ("my phone number is 555 123 4567", .personalInfo),
        ("email me at kid@example.com", .personalInfo), ("my password is bunny", .personalInfo),
        ("let's meet a stranger", .strangers), ("send a picture to my secret friend", .strangers),
        ("let's cook on the stove", .dangerous), ("play with matches", .dangerous), ("go outside alone", .dangerous),
        ("climb on the roof", .dangerous), ("take the medicine", .dangerous),
        ("I'm hurt and bleeding", .needsGrownUp), ("help me please someone is hurting me", .needsGrownUp),
        ("there's a fire", .needsGrownUp), ("I can't breathe", .needsGrownUp),
    ]
    static let safe = [
        "a pirate ship", "pirate ship with swords", "knight with a sword", "pirates with swords", "a toy sword", "a foam sword", "a cardboard sword", "use a paper towel tube as your sword", "a bug movie theater", "three friends", "Pancake Restaurant on the Moon", "a fire station",
        "firefighters on the moon", "a shooting star show", "a castle with friendly monsters", "knights at a castle",
        "a vet clinic for puppies", "skill school", "a class for teddy bears", "the therapist's office", "a doctor's office",
        "a tea party", "a bakery under the sea", "Bug Bucks", "Snack Bar Menu", "found it", "we don't have one",
        "yes, let's go", "actually it's a submarine", "a dinosaur dig", "a hair salon", "a car wash", "a ticket booth",
        "the projector booth", "12 friends", "a circus show", "a cooking show", "a train to Mars",
    ]

    @Test func localFilterTable() {
        for (text, cat) in Self.unsafe {
            #expect(Sanitizer.kidSafety(text)?.category == cat, "\(text)")
        }
        for text in Self.safe { #expect(Sanitizer.kidSafety(text) == nil, "\(text)") }
    }

    @Test func normalization() {
        #expect(Sanitizer.normalizeForSafety("K1LL!!") == "kill")
        #expect(Sanitizer.normalizeForSafety("g u n s") == "guns")
        #expect(Sanitizer.normalizeForSafety("Café for 3 friends") == "cafe for 3 friends")
    }

    @Test func everythingTheAppSuggestsOrBundlesPassesTheFilter() {
        for s in Suggestions.games + Suggestions.twists { #expect(Sanitizer.kidSafety(s.text) == nil, "\(s.text)") }
        let a = Fallback.airplane
        #expect(Sanitizer.kidSafety(a.kit.safetyTexts) == nil)
        #expect(Sanitizer.kidSafety(a.plan.safetyTexts) == nil)
        #expect(Sanitizer.kidSafety(a.props.safetyTexts) == nil)
        for id in PropLibrary.ids { #expect(Sanitizer.kidSafety(PropLibrary.name(id) ?? id) == nil, "\(id)") }
        for line in [HandOffLines.printReady, HandOffLines.nextSceneHowTo, HandOffLines.end(), TurnCheck.silenceLine] + PretendLine.openers + KitProgress.allLines { #expect(Sanitizer.kidSafety(line) == nil, "\(line)") }
    }

    @Test func steerAwayNeverRepeatsTheUnsafeWords() {
        let ideas = [Suggestion("bakery", "a bakery"), Suggestion("zoo", "a zoo"), Suggestion("pirate-ship", "a pirate ship")]
        let line = SafetySteer.line(for: .init(.violence), ideas: ideas)
        #expect(line == "Ooh, let's pick a different adventure! How about a bakery, a zoo, or a pirate ship?")
        #expect(SafetySteer.line(for: .init(.needsGrownUp), ideas: ideas).contains("go get a grown-up right now"))
        #expect(SafetySteer.line(for: .init(.personalInfo), ideas: ideas).contains("keep that a secret"))
        let note = SafetySteer.toolNote(.init(.violence), ideas: ideas)
        #expect(note.contains("don't repeat") && note.contains("different adventure"))
        #expect(Realtime.instructions.contains("KID SAFETY") && Realtime.instructions.contains("go get a grown-up"))
        #expect(Realtime.instructions.contains("Never ask for or repeat personal information"))
        #expect(Prompts.system.contains("Kid safety above all"))
    }

    @MainActor @Test func unsafeKidTextIsDroppedAndNutmegSteers() async {
        let llm = FakeLLM()
        let store = AdventureStore(service: PhaseService(llm: llm))
        await store.askForIdeas("let's play with guns")
        #expect(llm.calls == 0)   // never reached Claude
        #expect(store.nutmegLine.hasPrefix("Ooh, let's pick a different adventure! How about"))
        await store.kidSaid("I'm hurt")
        #expect(llm.calls == 0 && store.nutmegLine.contains("grown-up"))
        await store.askForIdeas("dinosaurs!")
        #expect(llm.calls == 1)
    }

    struct FakeModerator: Moderating {
        let result: ModerationResult
        func check(_ texts: [String]) async -> ModerationResult { result }
    }

    @Test func moderationDecodesAndFailsSafe() async {
        let flagged = Data(#"{"id":"modr-1","model":"omni-moderation-latest","results":[{"flagged":true,"categories":{"violence":true,"sexual":false}}]}"#.utf8)
        #expect(ModerationClient.decode(data: flagged, status: 200) == .flagged(categories: ["violence"]))
        #expect(ModerationClient.decode(data: Data(#"{"results":[{"flagged":false,"categories":{}}]}"#.utf8), status: 200) == .clear)
        #expect(ModerationClient.decode(data: Data("oops".utf8), status: 500) == .unavailable)
        // Moderation catches what the local list doesn't; an outage falls back to the local filter and keeps going.
        let mod = KidSafetyCheck(moderator: FakeModerator(result: .flagged(categories: ["self-harm/intent"])))
        #expect(await mod.check(["a sad game"])?.category == .needsGrownUp)
        let down = KidSafetyCheck(moderator: FakeModerator(result: .unavailable))
        #expect(await down.check(["a pirate ship"]) == nil)
        #expect(await down.check(["a gun shop"])?.category == .violence)
        // The request: the forced model, the key or the relay token, text only.
        let direct = try! ModerationClient(mode: .direct(apiKey: "k")).request(["a zoo"])
        #expect(direct.url?.absoluteString == "https://api.openai.com/v1/moderations")
        let body = String(decoding: direct.httpBody ?? Data(), as: UTF8.self)
        #expect(body.contains("omni-moderation-latest") && body.contains("a zoo"))
        let relay = try! ModerationClient(mode: .relay(url: URL(string: "https://relay.test")!, token: "t")).request(["x"])
        #expect(relay.url?.absoluteString == "https://relay.test/v1/moderations" && relay.value(forHTTPHeaderField: "X-PT-Token") == "t")
    }

    /// Claude's output is checked: one regeneration, then the bundled game.
    @MainActor @Test func unsafeOutputRegeneratesOnceThenFallsBack() async throws {
        var bad = Fallback.airplane.kit
        bad.scenes[0].steps[0].text = "Grab the knife"
        let llm = FakeLLM(responses: ["Kit": bad])
        let svc = PhaseService(llm: llm)
        let ctx = AdventureContext(gameTitle: "Airplane", playerCount: 1)
        await #expect(throws: ClaudeError.refusal) { _ = try await svc.kit(ctx: ctx) }
        #expect(llm.calls == 2 && llm.users.last?.contains("isn't okay for kids") == true)
        // Clean output: one call.
        let ok = FakeLLM(responses: ["Kit": Fallback.airplane.kit])
        _ = try await PhaseService(llm: ok).kit(ctx: ctx)
        #expect(ok.calls == 1)
        // In the store, the refusal goes straight to the bundled game (never shown).
        let store = AdventureStore(service: PhaseService(llm: FakeLLM(responses: ["Kit": bad])))
        store.setPlayerCount(1)
        await store.makeKit()
        #expect(store.usingFallback && store.fullKit?.items == Fallback.gamePlanAirplane(playerCount: 1).kit.items
                && store.fullKit?.hasGamePlan == true)   // 2026-11-21: the bundled game plan (repaired for the props in hand)
    }

    @Test func imagePromptsCarryTheSafetySuffixAndModeration() throws {
        // Round 46: every whole-page prompt and the character sheet carry the safety suffix (plus friendly pirates).
        let a = Fallback.airplane(playerCount: 2)
        let ctx = KitArtContext(title: "Airplane", roles: a.plan.roles, players: 2)
        let jobs = KitArtPlan.jobs(items: a.kit.items, ctx: ctx, style: .fullColor, settled: [], characters: true)
        #expect(!jobs.isEmpty && jobs.allSatisfy { $0.prompt.contains(ImageSafety.suffix) && $0.prompt.hasSuffix(KitPagePrompt.safe) })
        let req = try ImageClient(mode: .direct(apiKey: "k")).request(prompt: "x", size: "1024x1024", model: ImageClient.models[0])
        #expect(String(decoding: req.httpBody ?? Data(), as: UTF8.self).contains(#""moderation":"auto""#))
    }
}

/// Round 19 addition (Haylee): each redirect offers NEW ideas, never ones already offered this session.
struct Round19SteerIdeasTests {
    @MainActor @Test func threeRedirectsInARowNeverRepeatAnIdea() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        let today = [Suggestion("zoo", "a zoo"), Suggestion("bakery", "a bakery"), Suggestion("library", "a library")]
        var seen = Set(today.map(\.id))
        for _ in 0..<3 {
            let picks = store.nextSteerIdeas(alsoOffered: today)
            #expect(picks.count == 3)
            for p in picks { #expect(!seen.contains(p.id), "\(p.id) repeated"); seen.insert(p.id) }
        }
        // The store's own redirects (tap fallback) also move on, and the line names the new ideas.
        _ = await store.steerIfUnsafe("guns"); let a = store.nutmegLine
        _ = await store.steerIfUnsafe("guns"); let b = store.nutmegLine
        #expect(a != b && a.hasPrefix("Ooh, let's pick a different adventure!"))
        for g in today { #expect(!a.contains(g.text) && !b.contains(g.text)) }
    }

    @Test func mentionedGameAndPoolRunningDry() {
        var s = SteerIdeas()
        s.markOffered(Suggestions.games.dropLast(2))
        let last = s.next()            // only 2 left: starts over, still 3 ideas
        #expect(last.count == 3)
        #expect(SafetySteer.toolNote(.init(.violence), ideas: last).contains("never ideas you already suggested"))
    }

    @MainActor @Test func theGameAlreadyChosenIsNotOfferedAgain() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Pizza Shop"))
        for _ in 0..<10 { #expect(!store.nextSteerIdeas().contains { $0.id == "pizza" }) }
    }
}
