# AI music options for the one-scene music beats (2026-11-21)

**Checked:** 2026-11-20 (web search). **For:** [one scene with music and Nutmeg's beats](../decisions/2026-11-21-one-scene-music-beats.md). **By:** Claude (research agent). Nothing was bought or signed up for.

**How this was checked:** the session's network blocked direct page fetches (elevenlabs.io, suno.com, stableaudio.com didn't resolve), so the terms below come from web-search extracts of the vendors' own pages (ElevenLabs music terms and docs, Suno blog, Stability explainer, Google docs, Soundraw license page) plus trade press for the lawsuits. **Before paying, open the ElevenLabs music terms page in a browser and re-read the "Studio Game / Indie Game" lines** (see caveat 1). Prices are what was listed in Oct–Nov 2026.

## What we need

- 7 theme families (space, jungle, magical, cozy shop/kitchen/diner, spooky-silly, under the sea, desert/western), each: **calm loop**, **tense loop**, **relief/win ending**; plus one shared **event chime**.
- Instrumental, kid-friendly, seamless loops of 1–3 min, bundled in the app (made once by us, not at runtime).
- Rights: use in a paid subscription iOS app plus App Store preview/marketing videos, kept after we cancel the plan.

## Comparison

| Service | Rights for our use (bundled in a paid app + App Store videos) | Survives cancel? | Training data / legal risk | Plan + price we'd need | Controls that matter | Output / API |
|---|---|---|---|---|---|---|
| **ElevenLabs Music (v2 / v2.5)** | Paid self-serve plans: "all online and offline commercial use permitted, except film, TV, radio, and Studio Games." Indie games are OK: lifetime revenue under $500k and the publisher's game revenue under $1M a year. If we pass that, we get 60 days to move to Enterprise or stop using the music in new copies. Ads and online video are fine. No attribution needed. | Yes: "Output remains subject to the plan in effect when that Output was created." | **Licensed**: Merlin (indie labels) + Kobalt (publishing) opt-in deals at launch (Aug 2025), plus production music. No label lawsuit. Their marketplace terms say AI music has no US copyright. | **Creator $22/mo** (121k credits; music ≈ 900 credits/min, so about 130 min). The API costs $0.15/min on any paid plan. Starter ($6, about 33 min) is too small. | Instrumental flag (`force_instrumental`). Length 3 s up to 5–10 min. **Composition plans**: named sections, each with its own styles and length (intro, loop, ending). **Inpainting/extend**. A documented **seamless loop recipe** ("glue" chunk). "Similar song" conditioning keeps a style. Stems on some tiers. | MP3, 44.1 kHz (PCM/WAV on higher tiers). Full API. |
| **Stable Audio 3.0 (Stability AI)** | Community License: free commercial use for organisations under **$1M annual revenue**, and users own their outputs. Enterprise license (with indemnity) above $1M. | Yes for open weights (the license isn't tied to a subscription). For the hosted app: rights attach at creation. | **Licensed** (AudioSparx library + licensed/CC data, per Stability and its paper). Partnership with UMG. No lawsuit. | Hosted app **from $12/mo** (Solo), or **free** if we run the open weights ourselves (Small/Medium; Large is API/paid). API about $0.20 per call. | Up to about 6 min. **Inpainting** of segments and **extend** past the end. LoRA fine-tuning (one style for all segments). No loop feature. Instrumental and production music is its strength; it does vocals less well. | WAV/MP3 44.1 kHz. API + open weights. |
| **Google Lyria 3 / 3 Pro (Vertex AI, Gemini API)** | Google says customers may use it commercially (Preview terms). Google has a general gen-AI copyright indemnity, but **we couldn't confirm Lyria is on the covered list**. | Yes (pay per call, no subscription). | Google says it was "trained on data it has the right to use". No lawsuit. Every output carries a **SynthID watermark** (inaudible) + C2PA data. | Pay as you go: **about $0.04 (Clip, 30 s) / $0.08 (Pro, up to about 3 min) per track**. No free tier. Needs a Google Cloud billing account. | Length is set in the prompt (Pro up to about 184 s). Negative prompt/instrumental control is unreliable on 3 Pro (Lyria 2 had it). No sections, inpainting or stems. | MP3 44.1 kHz. API only. |
| **Suno (v5.5 / v6)** | Pro/Premier: commercial use. Since **3 Sep 2026**, rights attach to songs **downloaded** while subscribed, and downloads are capped: **20/mo Pro, 60/mo Premier**. Suno "makes no representation… that any copyright will vest". | Yes for songs already downloaded on a paid plan (the terms say perpetual). | **Highest risk.** WMG settled (Nov 2025), and v6 (Sep 2026) is licensed from WMG, BMG and Believe. **UMG + Sony are still suing**: the first case is ongoing (dispositive motions Jan 2027), they added stream-ripping claims (Aug 2026) and filed a second suit (Sep 18, 2026). Discovery reportedly shows training on millions of label recordings. | **Pro $10/mo** (2,500 credits, 20 downloads). With 22 files plus retakes we'd need 2 months or Premier ($30). | Instrumental toggle. Good full-song quality. Extend/cover/remix. Stems on paid plans. Poor exact length/loop control. Style drifts between generations. | MP3/WAV. No official public API. |
| **Udio** | **Downloads suspended since Oct 30, 2025.** The licensed UMG/WMG platform is a "walled garden" (stream on-platform only). No launch confirmed as of late Oct 2026. | n/a | Settled with UMG (Oct 2025) and WMG. | n/a | Stems + inpainting API (Mar 2026), but we can't take files out. | **Not usable for bundling.** |
| **AIVA** | Only **Pro** gives "Copyright owned by YOU". Standard only allows monetising on YouTube/Twitch/TikTok/Instagram (games/apps need Pro). Free needs credit. | Yes for tracks made on Pro (ownership is assigned). | Trained on public-domain classical scores (low risk). Composition-based, not audio-trained. | **Pro €49/mo** (€33/mo yearly). | Strong control: MIDI, editing, tempo/key/length, consistent style presets, orchestral/cinematic. Loops need manual work. Sounds more "MIDI orchestra". | WAV/MP3/MIDI/stems. No API. |
| **Soundraw** | Video games and apps allowed as background music (Creator plan). Soundraw **keeps ownership**. Its license page says content made "as downloaded" can stay published **only while subscribed** (the blog says perpetual). The two conflict, so this is a risk for an app that ships for years. | **Unclear / maybe not** (see left). | Trained on music by its in-house producers (low risk). | Creator about **$11–17/mo**. API from $29.99/mo. | Length, tempo, energy per section, instrument swaps, loops. Good for steady background beds. Generic sound. | WAV/MP3, stems on some plans. API. |
| **Mubert** | Creator = personal/non-monetised only. Pro ($39) = commercial monetisation. **Apps & games need Business ($199/mo)**. No standalone release or Content ID on any plan. | Licence certificate per download. Cancel terms unclear. | Trained on samples licensed from its own creator community (low risk). | **Business $199/mo**. | Ambient/electronic loops by mood/BPM/length. Weak at "jungle/western/spooky" character. | MP3/WAV. API (custom pricing). |
| **Beatoven.ai** | **Consumer service shut down (Aug–Sep 2026).** Only enterprise licensing of its "Maestro" model now (Maestro launched Aug 2025 as "fully licensed"). | n/a | Licensed. | Enterprise only (no public price). | n/a | **Not an option for us now.** |
| **Adobe Firefly (Generate Soundtrack)** | Instrumental only. Marketed "commercially safe". IP indemnity only on qualifying enterprise plans. | Generally yes (Adobe gen-AI terms). | Licensed (Adobe Stock + content bought from IP owners). | Firefly/Creative Cloud plan (credits). | Built to score **an uploaded video** (up to 5 min, 4 variations). Not built for loop/section families. | Inside Adobe apps. No public music API found. |

Other newer names (Klay, Loudly, MiniMax Music, ACE-Step open source) didn't turn up anything with clearer licensing or better loop control than the options above, so they weren't researched further.

## Copyright: what "AI music may not be copyrightable" means for us

The US Copyright Office's Part 2 report (Jan 29, 2025) says prompts alone are not human authorship, re-rolling and picking the best take isn't either, and purely AI-generated material can't be registered. Human edits or arrangement on top can be protected (only the human part). Suno and ElevenLabs both say this in their own terms. In practice:

- **We can use the music freely; we just can't stop others copying it.** Someone could rip the loops from the app and reuse them. For background beds in a kids' app that's a small risk.
- **Don't claim copyright in the music** (no "© PretendThat music" line) and don't register it with Content ID or YouTube monetisation; most vendors forbid Content ID anyway. Our App Store preview videos are fine. A third party could, in theory, Content-ID-claim a similar track, so keep each track's generation record and license certificate.
- **The vendor license is what protects us**, not copyright: it promises *their* side won't come after us. That's why licensed training data matters more than "ownership".
- **Avoid soundalikes:** never name artists, films or franchises in prompts ("Star Wars-like", "Jaws theme", "Mario"). A listen check per track for melodies that sound famous is the one real infringement risk left.
- Our looping, editing and arrangement add a thin layer of human authorship. That's nice to have but not worth relying on.

## Recommendation

**Top pick: ElevenLabs Music (v2.5), Creator plan for one month ($22), then cancel.**
- Licensed training data and no label lawsuit, with clear paid-plan commercial terms that survive cancelling.
- It's the only tool with all three controls we need: **section control** (calm, tense and win inside one composition plan, so they share key, tempo and instruments), a **seamless-loop recipe**, and **inpainting** to fix a bad bar.
- It has an API, so an agent can script the 22 cues. We already know the vendor (voice research).
- **Caveat to settle before buying:** the Studio Game exclusion. We qualify as an "Indie Game" (lifetime revenue under $500k, publisher under $1M a year). If PretendThat ever passes that, we have 60 days to buy Enterprise Music or stop using the tracks in new builds (copies already shipped can keep them). It's also arguable whether a pretend-play guide counts as a "game" at all, and the Studio Game definition talks about "more than one platform" while we're iOS only. Either way, we're covered today.

**Runner-up: Stable Audio 3.0** (hosted Solo $12/mo, or free open weights). It has licensed training data, and its Community License is free commercial use under $1M revenue with no game exclusion. It does inpainting and extend, and LoRA keeps one style across segments. It loses on loop/section tooling (more manual DAW work) and has a smaller track record for "cute kids' cartoon" styles. It's the better choice if ElevenLabs' game clause worries us.

**Cheap backup: Google Lyria 3 Pro** at about $0.08/track (about $10–15 for the whole set). It's fine for the chime or extra variations, but has weak instrumental/negative-prompt control, no sections, and indemnity cover we couldn't confirm.

**Don't use:** Suno (UMG/Sony suits still live, download caps), Udio (no downloads), Beatoven (consumer service closed), Mubert ($199/mo for apps), Soundraw (rights may end when the subscription ends). AIVA Pro (€49) is a legally clean fallback if we wanted orchestral and MIDI control, but its sound is less playful.

**Runtime generation:** not worth it. Pre-made cues cost about $22 once. At runtime, ElevenLabs is $0.15/min, so a 10-minute scene is about $1.50 per game, more than a whole game costs now. It would also add latency and need a network connection. Stable Audio 3's small open model can run on-device, but quality, app size and CPU make it a later idea.

## Rough cost (7 families × 3 segments + chime)

| Item | Minutes |
|---|---|
| Final audio needed per family: calm 1.5–2 min + tense 1–1.5 min + win 15–25 s | about 3.5 min |
| 7 families | about 25 min |
| Chime (2–4 s; make 10 candidates) | under 1 min |
| Retakes (assume 4–5 tries per family) | **about 110–130 min generated** |

- **ElevenLabs Creator: $22 for one month** (about 130 min). If we run over: API top-up at $0.15/min (about $5 per extra 30 min), or a second month. **Budget: $22, worst case about $45.** (Pro at $99 isn't needed.)
- Stable Audio: $12 for a month (or $0 self-hosted). Lyria: about $10–15. Suno: $10–30 (not recommended).
- Per CLAUDE.md rule 7: generation is a one-time cost Haylee pays. An agent should prototype **one family first** (about 15–20 min of generation) and get Haylee's listen before making the other six.

## Workflow: matching calm/tense/win segments that loop cleanly

1. **Fix a recipe per family:** one style line shared by all segments (e.g. "playful cartoon space adventure, glockenspiel, pizzicato strings, soft synth pads, light percussion, instrumental, for young children"), plus a **fixed tempo and key** (e.g. 100 BPM, C major). Calm and tense keep the same instruments and key. Tense adds drive (staccato strings, toms, faster pulse) and win resolves (fanfare, cymbal swell, final chord). Spooky-silly stays silly (bassoon, xylophone, theremin-ish), never scary.
2. **Generate all three in one composition plan:** e.g. `Calm` 96 s → `Tense` 72 s → `Win` 20 s, `force_instrumental`, with section durations enforced. One generation means the segments are related by construction. Make 3–4 versions and pick the best.
3. **Cut at bar lines:** bar = 4 × 60 / BPM (2.4 s at 100 BPM). Cut calm and tense to whole numbers of bars (e.g. calm 40 bars = 96 s, tense 30 bars = 72 s) so the app can switch on a bar boundary. Keep the win sting as a one-shot with its natural tail (fade the last 0.5–1 s).
4. **Make each loop seamless:** use ElevenLabs' loop recipe (keep a slice, add a generated "glue" chunk, repeat the slice), or loop in post: take N bars + 1 extra bar, then do an equal-power crossfade of the extra bar's tail into the head (about 50–200 ms, at a zero crossing). Check by playing the loop 3 times in a row (an agent can render a 3× file and look for a click or level jump in the waveform/RMS).
5. **Fix a bad bar with inpainting** instead of regenerating the whole cue.
6. **Loudness:** two-pass `ffmpeg loudnorm` to **−16 LUFS integrated, −1.5 dBTP** for calm and win. Tense can sit about 1 LU louder (−15) so it feels urgent. Chime at about −16 LUFS short-term so it cuts through without startling. The app still ducks music under Nutmeg (about −12 dB).
7. **Encode:** `afconvert -f m4af -d aac -b 96000` (AAC-LC stereo 44.1 kHz). In the app, load each loop into an `AVAudioPCMBuffer` and play it with `AVAudioPlayerNode.scheduleBuffer(..., options: .loops)` so the loop is sample-exact (AAC encoder padding is handled by the .m4a priming info that AVAudioFile reads). Switch calm → tense with a 1–2 s crossfade on the next bar.
8. **Keep the paperwork:** save prompt, plan JSON, date, plan tier and generation ID per file in `assets/music/SOURCES.md`, plus a screenshot of the plan's terms on the day of generation.

**App size:** about 25 min total. AAC 96 kbps ≈ 0.72 MB/min, so **about 18 MB**. At 128 kbps ≈ 0.96 MB/min, about 24 MB. HE-AAC 64 kbps would be about 12 MB, but it dulls glockenspiel and bells, so 96 kbps AAC-LC is the pick. Optionally ship 2–3 families in the binary and put the rest in On-Demand Resources.

## Sources (checked 2026-11-20)

- ElevenLabs music terms: https://elevenlabs.io/music-terms · model-specific terms: https://elevenlabs.io/eleven-music-model-specific-terms · music page: https://elevenlabs.io/music · API pricing: https://elevenlabs.io/pricing/api · pricing: https://elevenlabs.io/pricing · inpainting + loop recipe: https://elevenlabs.io/docs/eleven-api/guides/how-to/music/inpainting · music API: https://elevenlabs.io/eleven-music-api
- ElevenLabs licensing deals: https://musicbusinessworldwide.com/eleven-music-new-ai-rival-to-suno-launches-with-merlin-kobalt-licensing-deals-in-the-bag · https://www.businesswire.com/news/home/20250805333301/en
- ElevenLabs plan prices (Oct 2026): https://dupple.com/pricing/elevenlabs · Music v2 launch: https://decrypt.co/369237/elevenlabs-stability-ai-new-music-models
- Stable Audio 3.0: https://stability.ai/explainers/stable-audio-vs-competitors-licensing-export-rights-and-self-hosting-compared · https://the-decoder.com/stability-ai-launches-stable-audio-3-0-with-up-to-six-minute-tracks-and-open-weights/ · https://www.digitalmusicnews.com/2026/05/21/stability-ai-3-0-release/ · paper: https://arxiv.org/html/2605.17991 · Stable Audio 2.5 launch: https://stability.ai/news/stability-ai-introduces-stable-audio-25-the-first-audio-model-built-for-enterprise-sound-production-at-scale
- Google Lyria: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/lyria/lyria-3 · https://ai.google.dev/gemini-api/docs/music-generation · https://invideo.io/blog/lyria-ai-music-generator/ · https://the-decoder.com/google-launches-ai-music-generator-lyria-3-pro-says-it-was-trained-on-data-it-has-the-right-to-use/
- Suno: downloads/ToS update https://blog.suno.com/blog/suno-updates-tos · v6 licensed launch https://musicbusinessworldwide.com/suno-v6-ai-music-models-launch-in-partnership-with-wmg-bmg-and-believe · WMG settlement https://billboard.com/pro/suno-warner-music-sign-ai-licensing-deal-settle-lawsuit/ · Sep 2026 download caps https://www.usagepricing.com/blueprint/activity/suno-2026-09-03-commercial-use-download-cap · pricing https://www.activepieces.com/blog/suno-pricing-2026-free-pro-and-premier-compared.md
- UMG/Sony vs Suno: https://completemusicupdate.com/universal-and-sony-file-amended-suno-lawsuit-after-judge-gives-all-clear-to-add-stream-ripping-claims/ · https://www.boston.com/news/local-news/2026/09/27/major-record-labels-sue-cambridge-based-ai-platform-again/ · https://musicbusinessworldwide.com/umg-and-sony-seek-to-add-61000-copyrighted-works-to-suno-lawsuit-after-discovery-reveals-suno-trained-on-millions-of-their-recordings
- Udio: https://www.digitalmusicnews.com/2025/10/31/udio-downloads-disabled-umg-deal/ · https://dynamoi.com/learn/ai-music-distribution/suno-vs-udio-for-commercial-distribution
- AIVA: https://toolradar.com/tools/aiva/pricing · https://costbench.com/software/ai-music-generators/aiva/
- Soundraw: https://soundraw.io/license · https://soundraw.io/blog/post/soundraw-licensing-explained · https://soundraw.io/api
- Mubert: https://mubert.com/render/pricing · https://www.costbench.com/software/ai-music-generators/mubert/
- Beatoven shutdown: https://routenote.com/radar/beatoven-ai-shuts-consumer-ai-music-service-as-core-team-joins-rusk-media/ · Maestro: https://www.musicbusinessworldwide.com/beatoven-ai-launches-fully-licensed-music-ai-model-with-artist-payouts
- Adobe Firefly audio: https://www.musicbusinessworldwide.com/adobes-new-firefly-can-create-custom-fully-licensed-ai-soundtracks-for-video · https://www.tubefilter.com/2026/10/02/adobe-firefly-ai-sound-features/
- US Copyright Office, Part 2 (copyrightability): https://www.copyright.gov/newsnet/2025/1060.html · summary https://copyrightalliance.org/ai-report-part-2-copyrightability/
