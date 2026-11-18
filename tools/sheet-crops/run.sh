#!/bin/zsh
# Round 47: build and run the sheet-crops renderer (NutmegCore's SheetCells + PageFit, no AI calls).
# Usage: tools/sheet-crops/run.sh <out-dir> <expected>:<label>:<drawn.png> ...
set -e
here=${0:A:h}
core=$here/../../NutmegCore/Sources/NutmegCore
bin=${TMPDIR:-/tmp}/sheet-crops-bin
swiftc -O -o $bin $here/main.swift $core/SheetCells.swift $core/CutoutSheet.swift $core/PageFit.swift
$bin "$@"
