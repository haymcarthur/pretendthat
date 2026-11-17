# Kids' voices stay on the iPad: on-device speech to text (Haylee, 2026-11-16)

**Decision:** stop sending kid AUDIO to OpenAI. Push-to-talk audio is transcribed ON THE DEVICE (Apple Speech, `requiresOnDeviceRecognition = true`), and only the TEXT is sent, as a text turn in the existing Realtime session. Nutmeg's replies still come back as Realtime AUDIO in the same coral voice, so her voice doesn't change.

**Why:** the COPPA voice rules and OpenAI's under-13 policy without ZDR. It's also the strongest privacy story ("your child's voice never leaves the iPad"). Haylee chose this over waiting for ZDR.

**Correction noted:** today the chat transcript of kid speech comes from OpenAI's server-side transcription (gpt-4o-mini-transcribe) of the uploaded audio, not on-device, so this is a real pipeline change. The app already has an on-device Speech fallback to build on.

**Details to build (queued):**
- push-to-talk records locally, then on-device recognition on release, then the text goes to the model (and the chat transcript), with the audio discarded right away
- strip name-like words from the text before sending
- keep barge-in, latency targets and the moderation gate (now on local text)
- handle on-device recognition being unavailable (needs the language asset; prompt a download or fall back to typing)
- update the mic/speech permission strings, the privacy page and the App Privacy label
- measure the accuracy with kid-like speech and the latency against today
- text sent to OpenAI/Anthropic still needs data terms; ask anyway
