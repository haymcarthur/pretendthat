#!/bin/zsh
# Runs a command with the API keys taken from the BUILT app's Info.plist (filled from the git-ignored
# Secrets.xcconfig at build time). Never prints the values. Usage: tools/with-keys.sh swift test --filter Live
set -e
ROOT=${0:A:h:h}
PLIST="$ROOT/build/DerivedData/Build/Products/Debug-iphonesimulator/PretendThat.app/Info.plist"
[[ -f $PLIST ]] || { echo "Build the app first (xcodebuild ... -derivedDataPath build/DerivedData)"; exit 1; }
export ANTHROPIC_API_KEY="$(/usr/libexec/PlistBuddy -c 'Print :ANTHROPIC_API_KEY' "$PLIST" 2>/dev/null)"
export OPENAI_API_KEY="$(/usr/libexec/PlistBuddy -c 'Print :OPENAI_API_KEY' "$PLIST" 2>/dev/null)"
exec "$@"
