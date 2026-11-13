#!/bin/zsh
# Live Realtime test in the booted simulator: -PTLive with typed turns. Usage: tools/live-voice.sh <outdir> "turn1" "turn2"...
OUT=${1:?out}; shift; mkdir -p "$OUT"
ARGS=(-PTLive); for t in "$@"; do ARGS+=(-PTSay "$t"); done
xcrun simctl install booted build/DerivedData/Build/Products/Debug-iphonesimulator/PretendThat.app
xcrun simctl terminate booted app.pretendthat.ios 2>/dev/null
xcrun simctl launch --console-pty booted app.pretendthat.ios $ARGS > "$OUT/console.log" 2>&1 &
for i in $(seq 1 ${SHOTS:-8}); do sleep ${EVERY:-6}; xcrun simctl io booted screenshot "$OUT/live-$i.png" >/dev/null 2>&1; done
kill %1 2>/dev/null; true
