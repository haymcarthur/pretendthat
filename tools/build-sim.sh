#!/bin/zsh
# Build the app for the booted iPad simulator into build/DerivedData. Prints only the result.
cd "$(dirname $0)/.." && xcodegen -q >/dev/null 2>&1
xcodebuild -project PretendThat.xcodeproj -scheme PretendThat -destination "platform=iOS Simulator,id=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)" \
  -derivedDataPath build/DerivedData build > .superpowers/sdd/build.log 2>&1
grep -E "error:|BUILD (SUCCEEDED|FAILED)" .superpowers/sdd/build.log | head -30
