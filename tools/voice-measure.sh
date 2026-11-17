#!/bin/zsh
# Round 35 prep: converts each audio file to 16 kHz mono float (ffmpeg) and runs tools/voice_measure.swift on them.
# Usage: tools/voice-measure.sh [--ref "a.caf b.aac"] file...
ROOT=${0:A:h:h}; T=$(mktemp -d)
REFS=()
if [[ $1 == --ref ]]; then for r in ${=2}; do ffmpeg -v error -y -i $r -ac 1 -ar 16000 -f f32le $T/ref-${#REFS}-${r:t:r}.f32 && REFS+=$T/ref-${#REFS}-${r:t:r}.f32; done; shift 2; fi
FILES=()
for f in "$@"; do ffmpeg -v error -y -i $f -ac 1 -ar 16000 -f f32le $T/${f:h:t}__${f:t:r}.f32 && FILES+=$T/${f:h:t}__${f:t:r}.f32; done
if (( ${#REFS} )); then swift $ROOT/tools/voice_measure.swift --ref ${(j:,:)REFS} $FILES; else swift $ROOT/tools/voice_measure.swift $FILES; fi
rm -rf $T
