import Foundation
import Testing
@testable import NutmegCore

// Round 31 (decisions/2026-11-16-on-device-speech.md): kids' voices stay on the iPad.

/// The name-scrubbing table: what the iPad heard → what leaves it.
@Test(arguments: [
    ("My name is Mia", "My name is [name]"),
    ("my name is Mia Lopez and I want a bakery", "my name is [name] and I want a bakery"),
    ("I'm Theo.", "I'm [name]."),
    ("I’m Theo and I'm 6", "I’m [name] and I'm 6"),          // curly apostrophe from the recognizer
    ("I am Ava", "I am [name]"),
    ("Call me Jayden!", "Call me [name]!"),
    ("my brother Sam wants to be the doctor", "my brother [name] wants to be the doctor"),
    ("My best friend is Olivia", "My best friend is [name]"),
    ("This is Noah, he's 4", "This is [name], he's 4"),
    ("It's Mia's turn", "It's [name] turn"),
    ("Her name is Ella Rose", "Her name is [name]"),
    // Left alone: no lead-in, lowercase words, pretend names, roles.
    ("I'm hungry", "I'm hungry"),
    ("I'm the doctor", "I'm the doctor"),
    ("I'm ready", "I'm ready"),
    ("A dragon named Sparkle", "A dragon named Sparkle"),
    ("Let's play bakery", "Let's play bakery"),
    ("We have 3 kids", "We have 3 kids"),
    ("I'm OK", "I'm OK"),
    ("", ""),
])
func scrubsNames(_ heard: String, _ sent: String) {
    #expect(NameScrubber.scrub(heard) == sent)
}

/// The text-turn protocol: a spoken turn is ONE text item, the same shape as a typed turn, and carries no audio.
@Test func spokenTurnIsOneTextItem() throws {
    let events = Realtime.kidSpokenTurn("We want a pet shop", id: "kid_1")
    #expect(events.count == 1)
    let e = try #require(events.first)
    #expect(e["type"] as? String == "conversation.item.create")
    let item = try #require(e["item"] as? [String: Any])
    #expect(item["role"] as? String == "user" && item["id"] as? String == "kid_1")
    let content = try #require(item["content"] as? [[String: Any]])
    #expect(content.count == 1 && content[0]["type"] as? String == "input_text" && content[0]["text"] as? String == "We want a pet shop")
    let json = Realtime.json(e)
    #expect(!json.contains("input_audio") && !json.contains("\"audio\""))
}

/// Every client event the app builds for a kid's turn, then her reply, contains no audio upload.
@Test func noAudioAppendInTheEventStream() {
    var stream: [[String: Any]] = []
    stream.append(VoiceConfig.nutmeg.sessionUpdate(instructions: Realtime.instructions))
    stream += Realtime.kidSpokenTurn(NameScrubber.scrub("My name is Mia and I want a zoo"))
    stream.append(Realtime.allowedToolsNote(["set_game"]))
    stream.append(Realtime.responseCreate(requiring: ["set_game"]))
    stream.append(Realtime.responseCreateSpoken())
    stream.append(Realtime.responseCancel)
    stream.append(Realtime.truncate(itemID: "i", audioEndMs: 10))
    for e in stream {
        let type = e["type"] as? String ?? ""
        #expect(!type.hasPrefix("input_audio_buffer"), "\(type)")
        #expect(!Realtime.json(e).contains("input_audio_buffer"))
    }
    // The name never leaves the iPad.
    #expect(!stream.map(Realtime.json).joined().contains("Mia"))
}

/// A guard on the app's own code: nothing in PretendThat/ builds an audio upload to Realtime any more.
@Test func appSourceNeverAppendsAudio() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("PretendThat")
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
        .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
    #expect(files.count > 20)
    for f in files {
        let text = try String(contentsOf: f, encoding: .utf8)
        #expect(!text.contains("input_audio_buffer"), "\(f.lastPathComponent)")
        #expect(!text.contains("appendAudio"), "\(f.lastPathComponent)")
        // On-device only: Apple's server recognizer is never allowed either.
        #expect(!text.contains("requiresOnDeviceRecognition = false"), "\(f.lastPathComponent)")
        #expect(!text.contains("requiresOnDeviceRecognition = !"), "\(f.lastPathComponent)")
    }
}

/// What a finished hold does.
@Test func spokenTurnDecisions() {
    #expect(SpokenTurn.decide(words: "a zoo", held: 0.1, quickReplyOnly: false) == .tooShort)
    #expect(SpokenTurn.decide(words: "a zoo", held: 1, quickReplyOnly: true) == .almostReady)
    #expect(SpokenTurn.decide(words: "  ", held: 0.5, quickReplyOnly: false) == .nothingHeard(sayHint: false))
    #expect(SpokenTurn.decide(words: "", held: 1.5, quickReplyOnly: false) == .nothingHeard(sayHint: true))
    #expect(SpokenTurn.decide(words: " I'm Theo, let's do a zoo ", held: 1.2, quickReplyOnly: false) == .send("I'm [name], let's do a zoo"))
}

/// Fallback states: only "ready" listens; every other state types, with a grown-up note. Never a server fallback.
@Test func speechReadinessFallbacks() {
    typealias R = SpeechReadiness
    #expect(R.decide(speech: .authorized, mic: true, recognizerExists: true, supportsOnDevice: true) == .ready)
    #expect(R.decide(speech: .authorized, mic: true, recognizerExists: true, supportsOnDevice: false) == .onDeviceUnavailable)
    #expect(R.decide(speech: .authorized, mic: true, recognizerExists: false, supportsOnDevice: true) == .onDeviceUnavailable)
    #expect(R.decide(speech: .authorized, mic: false, recognizerExists: true, supportsOnDevice: true) == .micDenied)
    #expect(R.decide(speech: .denied, mic: true, recognizerExists: true, supportsOnDevice: true) == .speechDenied)
    #expect(R.decide(speech: .restricted, mic: true, recognizerExists: true, supportsOnDevice: true) == .restricted)
    #expect(R.decide(speech: .notDetermined, mic: true, recognizerExists: true, supportsOnDevice: true) == .notAskedYet)
    #expect(R.ready.canListen && !R.ready.typingFallback && R.ready.grownUpPrompt == nil)
    for r in [R.notAskedYet, .speechDenied, .micDenied, .restricted, .onDeviceUnavailable] {
        #expect(!r.canListen && r.typingFallback)
        let p = r.grownUpPrompt
        #expect(p != nil && p!.title.hasPrefix("Grown-ups") && p!.message.contains("type"))
    }
    #expect(R.onDeviceUnavailable.grownUpPrompt!.message.contains("Dictation"))
}
