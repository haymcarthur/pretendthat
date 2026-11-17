#!/bin/sh
# Build phase: a Release build must not carry personal API keys. Fails the build if OPENAI_API_KEY or
# ANTHROPIC_API_KEY is non-empty in the built Info.plist. Debug builds are skipped (dev keys are allowed there).
# Never prints key values.
[ "$CONFIGURATION" = "Release" ] || exit 0
PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
[ -f "$PLIST" ] || { echo "error: Release key check: built Info.plist not found at $PLIST"; exit 1; }
FAIL=0
for K in OPENAI_API_KEY ANTHROPIC_API_KEY; do
  V=$(/usr/libexec/PlistBuddy -c "Print :$K" "$PLIST" 2>/dev/null)
  if [ -n "$V" ]; then
    echo "error: Release key check: $K is set in the Release Info.plist. Personal keys must never ship; Release builds use the relay (Release.xcconfig)."
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "Release key check: no personal keys in the Info.plist."
exit $FAIL
