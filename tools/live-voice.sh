#!/bin/zsh
# Live Realtime test in a simulator (SIM=<udid>, default: booted): -PTLive with typed turns. Usage: tools/live-voice.sh <outdir> "turn1" "turn2"...
D=${SIM:-booted}
OUT=${1:?out}; shift; mkdir -p "$OUT"
ARGS=(-PTLive ${=EXTRA_ARGS}); for t in "$@"; do ARGS+=(-PTSay "$t"); done
xcrun simctl install $D build/DerivedData/Build/Products/Debug-iphonesimulator/PretendThat.app
xcrun simctl terminate $D app.pretendthat.ios 2>/dev/null
xcrun simctl launch --console-pty $D app.pretendthat.ios $ARGS > "$OUT/console.log" 2>&1 &
for i in $(seq 1 ${SHOTS:-8}); do sleep ${EVERY:-6}; xcrun simctl io $D screenshot "$OUT/live-$i.png" >/dev/null 2>&1; done
[ -z "$KEEP" ] && kill %1 2>/dev/null; true
