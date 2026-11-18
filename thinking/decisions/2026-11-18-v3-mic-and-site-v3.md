# v3 slides without the gray slashed mic; site restyled to v3

**Date:** 2026-11-18 · **Who decided:** Haylee chose v3 and asked for both; the how is Claude's call.

**Mic (slides v3):** the gray slashed mic is not a missing-keys state: it shows when on-device speech isn't ready
(`Listener.readiness`). There's no demo flag for it. On a fresh throwaway simulator (iPhone 17 Pro Max, no keys),
allowing the speech prompt and tapping the app's own "Download now" (Apple's on-device English model, free, no AI
call) turns the mic red. Retaken: iPhone slide 2 (`-PTDemo convClose -PTShot closeUp -PTState amazed`, silent) →
`raw-v4/iphone/02-talk-sparkle-redmic.png`, used as `slides-v3/src/img/iphone-02s.png`.
Not retaken (Haylee was in a meeting; simulators stopped, and the Pet Hotel replay plays Nutmeg's voice): iPad 02,
and iPhone/iPad 03 + 04. Those slides now hide the control bar with real pieces instead (no pixel edits):
iPhone 3: the found props (Towel, Bag; the iPad's real prop list items) under the Hat card; iPhone 4: the two
printed pages lower and overlapping; iPad 2: Nutmeg's reply over the bar; iPad 3: a kid bubble "We found a hat!";
iPad 4: a third page (tickets) lying sideways in front. To retake them later: replay Pet Hotel with
`-PTConsent -PTLive -PTStayHome -PTFakePass -PTSay "#replaytitle Pet" "#count 4" "#waithunt" "#found"×4 …`
plus a trailing `-PTSay "#heard done"` so the driver asks for speech auth first (it speaks: do it when audio is OK).

**Site:** pretendthat.app restyled to v3 (commit 62c2192 on top of 85829fe/fe9f72f, not pushed). The hero drops its two
chat bubbles (slide 1 has none); the bubbles stay in the Pick section.
