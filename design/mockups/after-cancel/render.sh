#!/bin/zsh
# Renders each screen to a 1320x2868 PNG (440x956 pt at 3x) with headless Chrome. Run from this folder.
cd "$(dirname "$0")"
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
shot() { "$C" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=3 \
  --window-size=440,$3 --virtual-time-budget=3000 --screenshot="$PWD/$2" "file://$PWD/screens.html?s=$1" 2>/dev/null; }
shot 2  2-game-page-a.png 956        # first: screens 3-5 use it as their background
shot 1  1-bookshelf.png 956
shot 2b 2b-game-page-b-recap.png 1640
shot 3  3-nutmeg-ask-grown-up.png 956
shot 4  4-grown-ups-check.png 956
shot 5  5-grown-up-card.png 956
"$C" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=2 \
  --window-size=3000,1330 --virtual-time-budget=3000 --screenshot="$PWD/strip.png" "file://$PWD/strip.html" 2>/dev/null
