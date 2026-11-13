# PretendThat Implementation Plan (mascot: Nutmeg, she/her)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An iPad app where Nutmeg, a stage-manager mouse, takes ages 4–8 from "I'm bored" to a planned game with roles, household props, a printed personalized kit, and a scene-by-scene play guide with tablet hand-offs.

**Architecture:** A local Swift package `NutmegCore` holds all logic: models and schemas, name tokenizing, Claude client, phase service, adventure state machine, kit pagination. It's tested with `swift test` on the Mac, so no simulator is needed. The SwiftUI app target `PretendThat` holds the views, the voice in and out, Nutmeg's character, and the PDF/print code, and depends on `NutmegCore`. A stateless Cloudflare Worker relay holds the API key.

**Tech Stack:** Swift 6 / SwiftUI, iPadOS 17+, Swift Testing, XcodeGen (dev tool), AVFoundation (`AVSpeechSynthesizer`, `AVAudioEngine`), Speech (`SFSpeechRecognizer`, on-device), UIKit printing, Claude Messages API (raw HTTPS, `claude-opus-5-5`), Cloudflare Workers.

**Spec:** `docs/superpowers/specs/2026-11-13-pretendthat-design.md`. Read it first; section numbers below (§) refer to it.

**Toolchain check (2026-11-13):** `xcodebuild -version` → **Xcode 27.2 (27B52)**. `xcrun simctl list devices available | grep -i ipad` → **no iPad simulators listed** (the command also took >120 s). **Decision: demo on an iPad simulator.** Task 1 installs the iOS simulator runtime (`xcodebuild -downloadPlatform iOS`, run in the background; it's a large download) and creates an iPad simulator. The print step only needs to show the AirPrint sheet.

**Clock:** code freeze **Sat Nov 14 07:59:59**. Budget ≈ 13 h of work plus buffer. **Slice checkpoint (end of Task 11, ≈ 6 h): airplane end-to-end on a device.** If behind, cut M4 breadth before cutting M6 polish.

## Global Constraints

- iPadOS 17.0 minimum, landscape only, iPad only. Bundle id `app.pretendthat.ios` (Haylee may change it).
- No third-party runtime dependencies. XcodeGen is a dev tool only.
- API: `POST https://api.anthropic.com/v1/messages`, header `anthropic-version: 2026-10-21`, model `claude-opus-5-5`, `output_config.format = {type:"json_schema", schema}`, `output_config.effort` `"low"` (chat, help) or `"medium"` (ideas, plan, props, kit). Header `anthropic-beta: server-side-fallback-2026-07-01` and body `fallbacks: "default"`. Never send `temperature`, `thinking: disabled`, or an assistant prefill. `max_tokens` 16000.
- Real kid names never appear in any request to Claude. Use only tokens `{P1}`…`{P4}`. For OpenAI image prompts, see the spec C8 open question (default until Haylee decides: **blank name banner plus app overlay**, so names never leave the device).
- Images: `POST https://api.openai.com/v1/images/generations`, model `gpt-image-2` (verify the current ID at build time), black-and-white line art, portrait US Letter aspect.
- Nothing is persisted: no files, `UserDefaults` only for parent settings (voice choice, dev/relay mode).
- Limits (§5): ideas = 3, players 1–4 (or Director mode for 5+), props 3–5, kit items 2–4, pages ≤ 6, scenes 4–6, steps 3–5, `copies` 1–8.
- Colors, fonts, radii and shadows come only from `Theme`. Nutmeg art comes only from the asset names in §7.
- Every kid-facing element has an emoji/picture plus tap- or long-press-to-hear.
- **Components first** (Haylee, see `thinking/decisions/components-first.md`): use native SwiftUI/UIKit controls wherever one exists; style them via `ButtonStyle`/`LabelStyle`/`ProgressViewStyle`/`ViewModifier`s in `DesignSystem/` that read `Theme`. Screens compose only DesignSystem components: no one-off styling, colors, fonts or paddings in screen files.

## Review Focus

1. **The LLM returns over-limit or odd JSON** (7 scenes, 0 props, an unknown SF Symbol, `{P3}` when there are 2 players) → clamp, substitute and drop rather than crash. Test in Task 2.
2. **Network down, timeout or refusal mid-flow** → Nutmeg apologizes and offers retry, then the bundled airplane fallback. No spinner forever. Test in Task 4.
3. **Names with odd characters, or a name that's also a common word** ("Sky", "José", empty) → tokenizing and untokenizing round-trips, and empty becomes "Player N". Test in Task 2.
4. **Nutmeg hears herself / the kid talks while Nutmeg talks** → hold-to-talk stops TTS first. Covered by Task 6's `startListening` contract.
5. **Director mode and 1-player edge cases** → no hand-off cards in Director mode, and the 1-player hand-off never asks to "pass the tablet." Test in Task 8.

---

## File Structure

```
project.yml                         XcodeGen spec (app target PretendThat, depends on local package NutmegCore)
Secrets.example.xcconfig            committed template; Secrets.xcconfig is git-ignored
NutmegCore/Package.swift               platforms: iOS 17, macOS 14
NutmegCore/Sources/NutmegCore/
  Models.swift                      GameIdeas, GamePlan, Props, Kit, NutmegTurn, Player, PlayerToken (§6)
  Schemas.swift                     JSON-schema dictionaries for each model
  Sanitizer.swift                   clamps and fixes decoded models to spec limits
  NameTokens.swift                  real-name ⇄ {Pn} substitution
  PrintSymbols.swift                SF Symbol allowlist
  ClaudeClient.swift                request building, transport, stop_reason handling
  Prompts.swift                     system prompt (§9) + per-phase user prompts
  PhaseService.swift                one async func per phase → typed model
  Fallback.swift + Resources/airplane-fallback.json
  AdventureStore.swift              @Observable state machine
  KitLayout.swift                   pagination of kit items into pages
NutmegCore/Tests/NutmegCoreTests/*.swift
PretendThat/App/PretendThatApp.swift, RootView.swift
PretendThat/Theme/Theme.swift
PretendThat/Nutmeg/NutmegCharacter.swift, NutmegState.swift
PretendThat/Voice/NutmegVoice.swift, Listener.swift
PretendThat/Screens/HelloView, PickGameView, PlayersView, PropsView, KitView, HandoffView, SceneView, StepBackView, EndView, ParentSettingsView, Components/*.swift
PretendThat/Print/KitPageView.swift, KitPrinter.swift
PretendThat/DesignSystem/           component library: PT* views, ButtonStyle/LabelStyle/ProgressViewStyle/ViewModifiers on Theme tokens, ComponentGallery (DEBUG)
PretendThat/Resources/Assets.xcassets (nutmeg-* placeholders), Info.plist
relay/worker.js, relay/wrangler.toml
```

---

## M0 · Setup (≈ 0:30)

### Task 1: Project skeleton

**Files:** Create `project.yml`, `NutmegCore/Package.swift`, `PretendThat/App/PretendThatApp.swift`, `PretendThat/App/RootView.swift`, `PretendThat/Theme/Theme.swift`, `Secrets.example.xcconfig`, `.gitignore`, `PretendThat/Resources/Info.plist`

**Interfaces:**
- Produces: `enum Theme` with static `background, surface, ink, primary, accent, success: Color`, `playerColors: [Color]` (4), `displayFont(_ size: CGFloat) -> Font` (rounded, bold), `bodyFont(_:) -> Font`, `cornerRadius: CGFloat = 28`, `nutmegHeadNeck = UnitPoint(x: 0.5, y: 0.80)` (see spec §7 head-on-body contract). Values are placeholders.
- Produces: Info.plist keys `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `ANTHROPIC_API_KEY = $(ANTHROPIC_API_KEY)`, `RELAY_URL = $(RELAY_URL)`, `RELAY_TOKEN = $(RELAY_TOKEN)`. Landscape-only orientations.

- [ ] **Step 1:** `git init`. `.gitignore` covers `Secrets.xcconfig`, `*.xcodeproj` (it's generated), `.build/`, `DerivedData/`, `.superpowers/`.
- [ ] **Step 2:** `brew install xcodegen` (if missing). Write `project.yml`: iOS app `PretendThat`, deployment 17.0, `TARGETED_DEVICE_FAMILY: 2`, configFiles → `Secrets.xcconfig`, package dependency `NutmegCore` (path).
- [ ] **Step 3:** Create `NutmegCore` with one placeholder test `@Test func smoke() { #expect(true) }`. Run `cd NutmegCore && swift test` → PASS.
- [ ] **Step 4:** Simulator: run `xcodebuild -downloadPlatform iOS` in the background (it's a large download), or plug in the iPad. Run `xcodegen && xcodebuild -scheme PretendThat -destination 'generic/platform=iOS' build` → BUILD SUCCEEDED.
- [ ] **Step 5:** Commit `chore: project skeleton`.

---

## M1 · Brain (≈ 1:45)

### Task 2: Models, schemas, sanitizer, name tokens

**Files:** Create `Models.swift`, `Schemas.swift`, `Sanitizer.swift`, `NameTokens.swift`, `PrintSymbols.swift`. Test `ModelsTests.swift`, `NameTokensTests.swift`, `SanitizerTests.swift`.

**Interfaces:**
- Produces: `Codable, Equatable, Sendable` structs exactly matching §6 field names: `GameIdeas`, `GameIdea`, `GamePlan`, `Role`, `Props`, `Prop`, `Kit`, `KitItem`, `Scene`, `Step`, `NutmegTurn`, `Choice`. Enums `PlayerToken: String { P1, P2, P3, P4 }`, `SceneOwner` (`P1…P4`, `all`), `KitKind`, `KitSize`.
- Produces: `struct Player { token: PlayerToken; name: String; colorIndex: Int; emoji: String }`.
- Produces: `enum Schemas { static func gameIdeas() -> [String: Any]; plan(); props(); kit(); turn() }` (every object `additionalProperties:false` and every field `required`; `bigNumber` is `["type": ["string","null"]]`).
- Produces: `enum Sanitizer { static func clean(_: Kit, playerCount: Int) -> Kit; clean(_: Props) -> Props; clean(_: GamePlan, playerCount: Int) -> GamePlan; clean(_: GameIdeas) -> GameIdeas }`.
- Produces: `struct NameTokens { init(players: [Player]); func tokenize(_ s: String) -> String; func untokenize(_ s: String) -> String }`.
- Produces: `enum PrintSymbols { static let allowlist: Set<String>; static func safe(_ s: String) -> String }` (unknown → `"star"`).

- [ ] **Step 1: Failing tests**
```swift
@Test func kitDecodesFromSpecShape() throws { let k = try JSONDecoder().decode(Kit.self, from: Fixture.kitJSON); #expect(k.items.count == 3); #expect(k.scenes.first?.steps.count == 4) }
@Test func sanitizerClampsKit() { let k = Sanitizer.clean(Fixture.oversizedKit /* 6 items, 8 scenes, 7 steps, copies 20, symbol "rocket.fake" */, playerCount: 2)
  #expect(k.items.count == 4); #expect(k.scenes.count == 6); #expect(k.scenes.allSatisfy { (3...5).contains($0.steps.count) || $0.steps.count < 3 })
  #expect(k.items.allSatisfy { (1...8).contains($0.copies) }); #expect(k.items[0].symbol == "star")
  #expect(k.scenes.allSatisfy { $0.owner == .all || $0.owner == .P1 || $0.owner == .P2 }) }   // P3/P4 → all
@Test func propsDropUnsafe() { #expect(Sanitizer.clean(Fixture.propsWithUnsafe).props.allSatisfy(\.safetyOK)) }
@Test func tokenRoundTrip() { let t = NameTokens(players: [.init(token:.P1,name:"José",colorIndex:0,emoji:"💙"), .init(token:.P2,name:"Sky",colorIndex:1,emoji:"💚")])
  #expect(t.tokenize("José and Sky fly") == "{P1} and {P2} fly"); #expect(t.untokenize("Captain {P1}!") == "Captain José!") }
@Test func emptyNameBecomesPlayerN() { #expect(NameTokens(players:[.init(token:.P2,name:"  ",colorIndex:1,emoji:"💚")]).untokenize("{P2}") == "Player 2") }
@Test func schemasAreStrict() { #expect((Schemas.kit()["additionalProperties"] as? Bool) == false) }
```
- [ ] **Step 2:** `swift test` → FAIL (types undefined).
- [ ] **Step 3:** Implement. Tokenize matches whole words, case-insensitively, longest names first. Sanitizer: truncate arrays to max; if under the minimum, keep what there is (the UI handles it).
- [ ] **Step 4:** `swift test` → PASS.
- [ ] **Step 5:** Commit `feat(core): models, schemas, sanitizer, name tokens`.

### Task 3: ClaudeClient

**Files:** Create `ClaudeClient.swift`. Test `ClaudeClientTests.swift` (uses a `URLProtocol` stub).

**Interfaces:**
- Produces: `enum Effort: String { case low, medium }`.
- Produces: `struct ClaudeConfig { enum Mode { case direct(apiKey: String), relay(url: URL, token: String) }; var mode: Mode; var model = "claude-opus-5-5"; static func fromBundle() -> ClaudeConfig? }` (relay preferred when `RELAY_URL` is non-empty).
- Produces: `enum ClaudeError: Error { case refusal, truncated, http(Int), decoding(String), transport }`.
- Produces: `final class ClaudeClient: Sendable { init(config: ClaudeConfig, session: URLSession = .shared); func structured<T: Decodable>(_ type: T.Type, system: String, user: String, schema: [String: Any], effort: Effort) async throws -> T }`.
- Behavior: body `{model, max_tokens:16000, system, messages:[{role:"user",content:user}], output_config:{effort, format:{type:"json_schema", schema}}, fallbacks:"default"}`. Headers: `content-type`, `anthropic-version: 2026-10-21`, `anthropic-beta: server-side-fallback-2026-07-01`. Direct mode also sends `x-api-key`; relay mode sends `x-nutmeg-token`. Response: check `stop_reason` (`refusal` → `.refusal`, `max_tokens` → `.truncated`), take the first `content` block with `type=="text"`, and JSON-decode `T` from its `text`. Timeout 60 s.

- [ ] **Step 1: Failing tests:** `buildsRequestWithStructuredOutput` (asserts URL, headers, `output_config.format.type == "json_schema"`, no `temperature` key); `relayModeUsesTokenNotKey`; `decodesTextBlockJSON` (stub returns `{"stop_reason":"end_turn","content":[{"type":"text","text":"{\"nutmegSays\":\"Hi\",\"choices\":[],\"understood\":true}"}]}` → `NutmegTurn.nutmegSays == "Hi"`); `refusalThrows` (`stop_reason:"refusal"` → `.refusal`); `http500Throws`.
- [ ] **Step 2:** `swift test` → FAIL.
- [ ] **Step 3:** Implement with `JSONSerialization` for the body.
- [ ] **Step 4:** `swift test` → PASS. Then a manual smoke test with a real key: a tiny `swift run`-free test marked `.enabled(if: env KEY set)` that calls `structured(NutmegTurn.self, …)` → prints `nutmegSays`.
- [ ] **Step 5:** Commit `feat(core): Claude client with structured outputs`.

### Task 4: Prompts, PhaseService, fallback

**Files:** Create `Prompts.swift`, `PhaseService.swift`, `Fallback.swift`, `Resources/airplane-fallback.json` (declare it as a package resource). Test `PhaseServiceTests.swift`.

**Interfaces:**
- Consumes: `ClaudeClient.structured`, `Schemas.*`, `Sanitizer.*`.
- Produces: `protocol LLM: Sendable { func structured<T: Decodable>(_:system:user:schema:effort:) async throws -> T }` (`ClaudeClient` conforms; tests use `FakeLLM`).
- Produces: `struct AdventureContext: Codable { var gameTitle: String?; var plan: GamePlan?; var props: Props?; var playerCount: Int; var directorMode: Bool }` (tokens only, no names).
- Produces: `final class PhaseService { init(llm: LLM); func ideas(kidSaid: String?) async throws -> GameIdeas; func plan(game: String, ctx: AdventureContext) async throws -> GamePlan; func props(ctx:) async throws -> Props; func kit(ctx:) async throws -> Kit; func turn(kidSaid: String, phase: String, ctx:) async throws -> NutmegTurn; func help(scene: Scene, ctx:) async throws -> NutmegTurn }`. All inputs are already tokenized, and every result goes through `Sanitizer`.
- Produces: `enum Fallback { static let airplane: (ideas: GameIdeas, plan: GamePlan, props: Props, kit: Kit) }`.
- `Prompts.system`: the §9 rules + limits from Global Constraints + "players are {P1}…{P4}; always refer to kids by token" + "Nutmeg's lines ≤ 2 sentences, ≤ 20 words, age-4 vocabulary." Keep it byte-stable (cacheable).

- [ ] **Step 1: Failing tests:** `kitIsSanitized` (FakeLLM returns oversized kit → ≤ 4 items); `userPromptHasNoRealNames` (FakeLLM captures `user`; ctx built from tokenized data; assert it contains `{P1}` and not `"Mia"`); `fallbackDecodes` (all four fallback parts non-empty, kit pages ≤ 6 via `KitLayout`, so do this test after Task 10's KitLayout or stub the page check).
- [ ] **Step 2:** FAIL → **Step 3:** implement → **Step 4:** PASS. Manual: run a real `kit` call for "airplane, 3 players" and eyeball the JSON (save it as a test fixture).
- [ ] **Step 5:** Commit `feat(core): phase service, prompts, airplane fallback`.

---

## M2 · Nutmeg and voice (≈ 1:30)

### Task 5: NutmegVoice (TTS with live mouth level)

**Files:** Create `PretendThat/Voice/NutmegVoice.swift`.

**Interfaces:**
- Produces: `@Observable @MainActor final class NutmegVoice { var level: Float /* 0…1, smoothed */; var isSpeaking: Bool; func say(_ text: String) async; func stop(); var lastLine: String? }`.
- Approach: `AVSpeechSynthesizer.write(utterance) { buffer in … }` → schedule each `AVAudioPCMBuffer` on an `AVAudioPlayerNode` → `mainMixerNode` tap computes RMS → `level` (attack fast, release ~120 ms). Voice: best installed `en-US` voice with quality `.premium` > `.enhanced` > default; `pitchMultiplier 1.2`, rate `0.48`. `say` returns when playback finishes. Audio session `.playAndRecord`, `.defaultToSpeaker`.

- [ ] **Step 1:** Implement. **Step 2:** Manual check on device: a debug screen with "Say test line" and a bar bound to `level`. The bar moves with the syllables, and `isSpeaking` flips false at the end. **Step 3:** Commit `feat(voice): TTS with amplitude level`.

### Task 6: Listener (on-device STT, hold to talk)

**Files:** Create `PretendThat/Voice/Listener.swift`, `PretendThat/Screens/Components/MicButton.swift`.

**Interfaces:**
- Produces: `@Observable @MainActor final class Listener { var transcript: String; var isListening: Bool; var available: Bool; func requestAuth() async; func startListening(stopping voice: NutmegVoice); func stopListening() async -> String }`. `startListening` calls `voice.stop()` first, and `requiresOnDeviceRecognition = true`. If on-device recognition isn't supported, `available = false`.
- Produces: `struct MicButton: View { let listener: Listener; let voice: NutmegVoice; let onResult: (String) -> Void }`, a big round button. It listens on press (long-press gesture with `minimumDuration: 0`, using `onPressingChanged`), and on release calls `onResult` with the final text if it isn't empty. It pulses while listening.

- [ ] **Step 1:** Implement. **Step 2:** Device check: hold, say "airplane", release → the transcript shows "airplane". Airplane mode on: still works (proves on-device). **Step 3:** Commit `feat(voice): on-device hold-to-talk`.

### Task 7: NutmegCharacter (layered art and states)

**Files:** Create `PretendThat/Nutmeg/NutmegState.swift`, `PretendThat/Nutmeg/NutmegCharacter.swift`, and placeholder images `nutmeg-*` in `Assets.xcassets`, using the exact names from §7 (simple shapes are fine).

**Interfaces:**
- Produces: `enum NutmegState { case idle, listening, thinking, talking, excited, napping }` (napping = the step-back screen).
- Produces: `struct NutmegCharacter: View { var state: NutmegState; var mouthLevel: Float; var costume: String? /* gameKey */ }`. A `ZStack` of full-frame layers in §7 order. A `TimelineView(.animation)` drives:
  - breathing: body scaleY ±1.5 %, 3 s period
  - blinks: random 2.5–5 s, 120 ms closed
  - talking: mouth picks by level, <0.08 closed, <0.25 small, <0.5 open, else wide; "ooh" every ~7th switch for variety. Head bob ±2° around `Theme.nutmegHeadNeck`. (Layer structure: spec §7 head-on-body contract.)
  - listening: head tilt 6°, ears scale 1.08
  - thinking: eyes look up (offset −8 pt), small sparkle
  - excited: 2 hops
  - napping: eyes closed, slower breathing, "z" bubbles
  
  The costume layer is drawn only if the asset exists (`UIImage(named:) != nil`).

- [ ] **Step 1:** Implement with placeholders. **Step 2:** Add a debug screen (in the parent settings) with a state picker and a level slider, and check every state visually. **Step 3:** Hook up `NutmegVoice.level` so Nutmeg talks while `say` plays. **Step 4:** Commit `feat(nutmeg): layered character with states`.

---

### Task 7b: Verify API headers (before relying on them)

- [ ] Load the claude-api skill and confirm the `anthropic-version` header value and the `anthropic-beta: server-side-fallback-…` header/body (`fallbacks`) used in Global Constraints. Fix `ClaudeClient` if they differ, then run one live call. Also confirm the OpenAI image model ID with a live call.

## M3 · End-to-end airplane slice (≈ 2:15) → CHECKPOINT

### Task 8: AdventureStore (state machine)

**Files:** Create `NutmegCore/Sources/NutmegCore/AdventureStore.swift`. Test `AdventureStoreTests.swift`.

**Interfaces:**
- Consumes: `PhaseService`, `NameTokens`, models, `Fallback`.
- Produces: `enum Phase: Equatable { case hello, pickGame, players, props, makingKit, kitReady, handoff(sceneIndex: Int), scene(Int), stepBack(Int), end }`.
- Produces: `@Observable @MainActor final class AdventureStore { init(service: PhaseService); private(set) var phase: Phase; var players: [Player]; var directorMode: Bool; var ideas: GameIdeas?; var plan: GamePlan?; var props: Props?; var kit: Kit?; var nutmegLine: String; var isWorking: Bool; var lastError: String?; var usingFallback: Bool; var tokens: NameTokens { get }`, plus actions `start()`, `chooseGame(_ title: String)`, `setPlayerCount(_ n: Int)` (n ≥ 5 → directorMode, 4 tokens, no names), `setName(_ name: String, for: PlayerToken)`, `confirmPlayers()`, `confirmProps()`, `makeKit()`, `beginPlay()`, `badgeTapped(_ t: PlayerToken)`, `sceneDone()`, `nextScene()`, `helpRequested() async -> String`, `playAgain()`, `newGame()` (wipes everything), `useFallback()`.
- Rules:
  - `beginPlay` / `nextScene` go to `.handoff(i)` only when `!directorMode && players.count > 1 && kit.scenes[i].owner != .all` **and** the owner differs from the previous scene's owner. Otherwise they go straight to `.scene(i)`.
  - `badgeTapped` only advances if the token matches the owner.
  - `sceneDone` → `.stepBack(i)`. `nextScene` after the last scene → `.end`.
  - On any service error, set `lastError` and a Nutmeg apology line. The second failure in the same phase → `useFallback()`.
  - `nutmegLine` is always untokenized (real names) for TTS and display.

- [ ] **Step 1: Failing tests (FakeLLM):**
  - `directorModeSkipsHandoff`
  - `singlePlayerSkipsHandoff`
  - `handoffOnlyWhenOwnerChanges` (owners P1, P1, P2, all → phases scene, scene, handoff, scene)
  - `wrongBadgeDoesNotAdvance`
  - `secondFailureUsesFallback`
  - `newGameClearsNamesAndKit`
  - `nutmegLineShowsRealNames` (LLM returns "Ready, Captain {P1}?" → `nutmegLine == "Ready, Captain Mia?"`)
- [ ] **Step 2:** FAIL → **Step 3:** implement → **Step 4:** PASS → **Step 5:** commit `feat(core): adventure state machine`.

### Task 8b: Component library (DesignSystem) and gallery

**Files:** Create `PretendThat/DesignSystem/` (`Spacing` tokens in `Theme`, `PTButtonStyle` (primary/secondary/quiet), `PTLabelStyle`, `PTProgressViewStyle`, `PTCardModifier`, `PTChoiceTile`, `PTCard`, `PTRoleBadge`, `PTChecklistRow`, `PTPropCard`, `PTHandoffCard`, `PTMicButton`, `PTPageThumbnail`, `PTParentGate`, `PTStageLayout`), and `ComponentGallery.swift` (`#if DEBUG`, opened from parent settings, shows every component in every state).

- [ ] **Step 1:** Build native-first components that read only `Theme` tokens. **Step 2:** Gallery screenshot on the simulator. **Step 3:** Refactor anything already built (MicButton, debug screens) onto the library. **Step 4:** Commit `feat(ds): component library and gallery`.

### Task 9: Setup screens (Hello → PickGame → Players → Props)

**Files:** Create `RootView` (switches on `store.phase`; Nutmeg on the left third, stage on the right, mic at the bottom, "🔊 again" button), `HelloView`, `PickGameView`, `PlayersView`, `PropsView`, `Components/ChoiceCard.swift` (emoji + label, tap selects, long-press speaks), `Components/ParentGate.swift` (hold 2 s with a progress ring).

**Interfaces:**
- Consumes: `AdventureStore`, `NutmegVoice`, `Listener`, `MicButton`, `NutmegCharacter`, `Theme`.
- Produces: `ChoiceCard(emoji:label:speak:onTap:)`, `ParentGate(label:onComplete:)`.
- Behavior:
  - Whenever `store.nutmegLine` changes, call `voice.say`. Nutmeg's state follows: `listener.isListening` → listening, `store.isWorking` → thinking, `voice.isSpeaking` → talking, otherwise idle.
  - Players screen: count buttons 1-2-3-4-5+. For each player, Nutmeg asks the name; the mic result → `setName`. Shows colored badges with role emoji once the plan arrives, plus a "swap" button that rotates roles.
  - Props screen: cards with a big check; "All set!" → `confirmProps()`.
  - A spoken free answer on any screen goes to `service.turn`, and the reply's choices show up as `ChoiceCard`s.

- [ ] **Step 1:** Build the screens in order. **Step 2:** Device run with a real key, from Hello through Props for airplane with 3 players. Nutmeg talks on every screen, and choices work by tap and by voice. **Step 3:** Commit `feat(ui): setup flow`.

### Task 10: Kit rendering, PDF and print

**Files:** Create `NutmegCore/Sources/NutmegCore/KitLayout.swift` (+ test `KitLayoutTests.swift`), `PretendThat/Print/KitPageView.swift`, `PretendThat/Print/KitPrinter.swift`, `PretendThat/Screens/KitView.swift`.

**Interfaces:**
- Produces: `struct KitPage { var item: KitItem; var slots: [KitSlot] }`, `struct KitSlot { var player: PlayerToken?; var index: Int }`, `enum KitLayout { static func pages(for kit: Kit, players: [PlayerToken], directorMode: Bool) -> [KitPage] }`. Rules:
  - per-page capacity: ticket/bill/keycard 8, badge 6, fullPage 1
  - `perPlayer` → one slot per player × `copies` (Director mode: `copies` slots with `player=nil`)
  - otherwise `copies` slots
  - hard cap 6 pages: drop trailing slots first, and never drop an item entirely
- Produces: `struct KitPageView: View { let page: KitPage; let tokens: NameTokens }`, US Letter at 612×792 pt. Black line art only: 2 pt outlines, dashed cut lines, `Image(systemName:)` outline symbols in `.foregroundStyle(.black)`, big rounded font, untokenized text, a blank "Name: ____" when `player == nil`, and a "color me" star badge when `colorMe`.
- Produces: `enum KitPrinter { @MainActor static func pdf(pages: [KitPage], tokens: NameTokens) -> Data; @MainActor static func print(_ pdf: Data, jobName: String) }` (`ImageRenderer` per page into one `CGContext` PDF; `UIPrintInteractionController` with `printingItem = pdf`).
- `KitView`: thumbnails animate in, then `ParentGate("Grown-up: hold to print")` → `KitPrinter.print`, then a "Let's play!" button → `store.beginPlay()`.

- **Change (spec C8):** each `KitPage` is now rendered by **`KitArtService`** (OpenAI Images: one image per page, generated in parallel, prompt built from the item spec), and `KitPageView` shows the generated image (plus the app-drawn name overlay on the banner area, if that option is chosen). `KitPrinter` assembles the images into one PDF. Bundle pre-generated airplane page images in `Fallback`. Files: add `NutmegCore/Sources/NutmegCore/ImageClient.swift`, `PretendThat/Print/KitArtService.swift`.
- [ ] **Step 1: Failing tests (KitLayout):**
  - `perPlayerTickets3Players` (1 ticket item, `perPlayer`, copies 1, 3 players → 1 page, 3 slots)
  - `badgesSixPerPage`
  - `capsAtSixPages` (4 items × 20 slots → `pages.count == 6`, every item present)
  - `directorModeBlankSlots`
- [ ] **Step 2:** FAIL → implement → PASS.
- [ ] **Step 3:** Simulator: generate the airplane kit (AI images) and open the AirPrint sheet. Check that names are right, the cut lines show, and nothing is clipped (Save-to-PDF if available).
- [ ] **Step 4:** Commit `feat(print): kit layout, PDF, AirPrint`.

### Task 11: Play screens (Handoff, Scene, StepBack, End)

**Files:** Create `HandoffView`, `SceneView`, `StepBackView`, `EndView`, `Components/RoleBadge.swift`.

**Interfaces:**
- Consumes: `AdventureStore` phases `.handoff/.scene/.stepBack/.end`, `NutmegCharacter`, `NutmegVoice`.
- Produces: `RoleBadge(player: Player, role: Role, size: CGFloat, onTap:)`, a colored circle with the role symbol plus the player's name.
- Behavior:
  - **Handoff:** a slide-in badge, and Nutmeg says "Pass the tablet to {role} {name}!"; tapping the badge calls `badgeTapped`.
  - **Scene:** Nutmeg says the scene's `nutmegSays`. Step rows (emoji + text; tap → speak; check box). When every step is checked → "Done!" → `sceneDone()`.
  - **StepBack:** dimmed background, Nutmeg `.napping`, buttons "Next scene ▶" and "Help, Nutmeg!" (`helpRequested` → speak the answer).
  - **End:** confetti, plus "Play again" and "New game".

- [ ] **Step 1:** Build. **Step 2: CHECKPOINT.** On the device, run the full airplane game for 3 players, end to end, with real AI, printing included. Then run it again with Wi-Fi off after the kit is made (play still works) and with a forced error (fallback works). **Step 3:** Commit `feat(ui): play flow, end-to-end slice`.

---

## M4 · Breadth and robustness (≈ 1:15)

### Task 12: Any-game hardening

**Files:** Modify `Prompts.swift`. Create `NutmegCore/Tests/NutmegCoreTests/LiveGamesTests.swift` (enabled only when a key env var is set).

- [ ] **Step 1:** Live test: for each of `restaurant`, `vet clinic`, `hotel`, `grocery store`, `space station`, `submarine bakery`, call `plan → props → kit` for 2 players and assert that `Sanitizer` changed nothing (the prompt already respects the limits), that every symbol is in the allowlist, and that no prop is `safetyOK=false`. Write each kit to `/tmp/nutmeg-kits/<game>.json`.
- [ ] **Step 2:** Tune `Prompts` until all 6 pass. Eyeball 2 kits as PDFs (debug "render fixture" button).
- [ ] **Step 3:** Commit `test: live multi-game prompt check`.

---

## M5 · Relay (≈ 0:45)

### Task 13: Cloudflare Worker relay

**Files:** Create `relay/worker.js`, `relay/wrangler.toml`, `relay/README.md`.

**Interfaces:**
- Produces: `POST /v1/messages`. It rejects a request (401) unless `x-nutmeg-token === env.NUTMEG_TOKEN`, then forwards the body to `https://api.anthropic.com/v1/messages` with `x-api-key: env.ANTHROPIC_API_KEY` and the same `anthropic-version` and `anthropic-beta` headers, and returns the response untouched. Also `POST /v1/images/generations`, forwarded to `https://api.openai.com/v1/images/generations` with `Authorization: Bearer env.OPENAI_API_KEY`, under the same token check. No `console.log` of bodies, no KV or storage. Methods other than POST → 405.

- [ ] **Step 1:** `npx wrangler dev`. Run a `curl` with the right token → 200 with JSON; a wrong token → 401.
- [ ] **Step 2:** `wrangler secret put ANTHROPIC_API_KEY`, `wrangler secret put OPENAI_API_KEY`, `wrangler secret put NUTMEG_TOKEN`, `wrangler deploy`. Set `RELAY_URL`/`RELAY_TOKEN` in `Secrets.xcconfig`. On the device, the parent settings show "Relay ✓".
- [ ] **Step 3:** Commit `feat(relay): stateless key relay`.

---

## M6 · Polish and brand (≈ 3:00)

### Task 14: Nutmeg and motion polish

- [ ] Tune the timing curves for every `NutmegState`. Add the screen transitions:
  - choice cards spring in with a stagger
  - the badge slides in on hand-off
  - kit thumbnails "fly out of the clipboard"
- [ ] Add haptics on check-off and badge tap. Add short UI sounds (system sounds only).
- [ ] Accessibility: every button gets a VoiceOver label; hit targets ≥ 88 pt.
- [ ] Commit `polish: motion and feedback`.

### Task 15: Brand drop-in (Haylee's Figma)

- [ ] Replace the placeholder `nutmeg-*` assets with the Figma exports (§7 contract: same names, 1024² full-frame, Preserve Vector Data). Confirm the layers line up in the debug state screen. Tune `NutmegPose` neck anchors/rotation/scale and `Theme.nutmegHeadNeck` so the head sits right on each pose.
- [ ] Put the brand tokens into `Theme.swift`: colors, the 4 player colors (colorblind-safe check), fonts (add the font file plus `UIAppFonts` if it's custom), radius, shadow.
- [ ] App icon and launch screen. Display name: PretendThat.
- [ ] Grep for hard-coded colors/fonts outside `Theme` (`grep -rn "Color(red\|Color(\.\|\.font(.system" Nutmeg/ | grep -v Theme`) → none.
- [ ] Commit `brand: Nutmeg art and theme`.

### Task 15b: Ambient stage scene (backstage theater)

- [ ] Add flat-vector theater props (`prop-curtain-corner`, `prop-spotlight`, `prop-ticket`, `prop-star`; spec §7b) to `Assets.xcassets`. Backgrounds are solid colors from `Theme` (white or a brand color), not images.
- [ ] Build `AmbientStageView`: a solid background with props placed around the mascot as accents, with subtle motion (curtain-corner sway on a slow sine, spotlight pulse). A curtain-rise intro on Hello. Respect Reduce Motion. All screens sit on top of it.
- [ ] Commit `brand: ambient stage scene`.

### Task 16: Parent settings and privacy screen

- [ ] `ParentSettingsView` (behind `ParentGate`) holds:
  - a voice picker (installed en-US voices) plus a test line
  - "Print test page"
  - relay or dev mode status
  - Nutmeg's state debug
  - a privacy card with the §8 text
- [ ] Commit `feat: parent settings`.

---

## M7 · Stretch (only if M0–M6 are green)

- **S1:** Costume layer per game (`nutmeg-costume-<gameKey>`). `GamePlan` gets `gameKey` chosen from a small known list, with nil when it doesn't match.
- **S2:** (Moved into core: printables now use OpenAI image generation, Task 10.)
- **S3:** Cloud TTS voice through the relay, keeping the RMS mouth driven from the received audio.
- **S4:** "Nutmeg, help!" voice wake word ("Hey Nutmeg") on the step-back screen.

---

## M8 · Ship (≈ 0:45, start by 06:30 Sat at the latest)

### Task 17: Demo and submission checklist

- [ ] Release build on the iPad simulator (and on a physical iPad as backup if Haylee brings one), volume up, Do Not Disturb on.
- [ ] The AirPrint sheet opens in the simulator. Optional: a pre-printed, colored airplane kit in hand.
- [ ] Rehearse the §10 script 2× with a timer (≤ 3 min). Test the fallback path once (relay token off → fallback works).
- [ ] **Team profile (competition rule): list libraries and services:** Apple SwiftUI/AVFoundation/Speech/UIKit, Anthropic Claude API (`claude-opus-5-5`), OpenAI Images API (`gpt-image-2`), Cloudflare Workers, XcodeGen (dev tool), SF Symbols, and any font or art sources.
- [ ] Push the repo. Have the source ready to show the judges (open `PhaseService.swift`, `AdventureStore.swift`, `NutmegCharacter.swift`).
- [ ] Code freeze 07:59:59: final commit and tag `v1.0-codecamp`.
