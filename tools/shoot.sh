#!/bin/zsh
# Screenshot every main screen via the DEBUG -PTDemo launch argument.
# Usage: tools/shoot.sh <out-dir>   (app must already be built into build/DerivedData)
set -e
OUT=${1:?out dir}; mkdir -p "$OUT"
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/PretendThat.app
xcrun simctl install booted "$APP"
for p in ${=PHASES:-hello pickGame players roles props kitReady handoff scene doneFlow end}; do
  xcrun simctl terminate booted co.crimsonfoundry.pretendthat 2>/dev/null || true
  xcrun simctl launch booted co.crimsonfoundry.pretendthat -PTDemo $p ${=EXTRA_ARGS} >/dev/null
  sleep ${SHOT_WAIT:-4}
  xcrun simctl io booted screenshot "$OUT/$p.png" >/dev/null 2>&1
  echo "$OUT/$p.png"
done
