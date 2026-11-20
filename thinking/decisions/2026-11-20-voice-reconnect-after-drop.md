# The voice comes back after a drop in the foreground (the 60-minute limit, a dead socket)

**Date:** 2026-11-20 · **Who decided:** Claude's call (bug fix); Haylee found it (the speaker buttons did nothing)

**What happened:** OpenAI ends a Realtime session after 60 minutes ("session_expired"). The socket closed, the app logged "silent reconnect", but the voice never came back: every 🔊 and the mic did nothing until the app was restarted. The status stayed `.live` after the socket closed, so `reconnectSilently` saw "came back meanwhile" on its first check and returned without trying; the keepalive kept pinging the dead socket (closing it again started nothing); and a tap never asked for a reconnect (`foregroundRecovery` thought the voice was live). This was NOT the 2026-11-18 lock fix coming back: any foreground drop hit it (the time limit, a dead Wi-Fi socket the keepalive closes, the line watchdog), and a failed ping after a lock had the same gap.

**Fix:** `RealtimeSession.socketClosed` sets `status = .failed(reason)` before the drop handler starts the silent reconnect, and `resumeIfAlive` does the same when the socket is gone after the app was away. So the reconnect runs, the keepalive stops pinging the dead socket, and if the reconnect gives up the next tap or mic press tries again.

**Checked:** live on the iPad simulator with the new DEBUG switch `-PTDropAfter N` (closes the voice socket N s after each connect): drop at 25 s → "reconnect (try 1): live" 2.3 s later. Before the fix the same log showed only missed pongs for 4+ minutes.

**Also this round (Haylee):** no "1 of 3" on the checklist cards (a finished card still gets its green check).
