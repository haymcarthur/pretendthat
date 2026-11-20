#!/usr/bin/env python3
"""PLACEHOLDER scene music (2026-11-21, decisions/2026-11-21-round-one-scene-build.md).

Writes tiny synthesized tones into PretendThat/Resources/Music/ so the one scene's music engine can be heard in demo
mode before the real AI-made music exists (thinking/research/2026-11-21-ai-music-options.md). Every file is clearly a
placeholder: soft sine notes, a few KB each (mono AAC, 24 kbps).

  Music/<family>/calm.m4a   a gentle 4-beat arpeggio loop (seamless: whole beats, no fade at the seam)
  Music/<family>/tense.m4a  the same key, faster pulsing notes (loop)
  Music/<family>/win.m4a    a short rising fanfare (plays once)
  Music/chime.m4a           the shared two-note event chime

Each family gets its own key so they sound different. Needs numpy and ffmpeg. Re-run any time; replace the files with
the real music (same names) when it's ready.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "PretendThat", "Resources", "Music")

# family → root note (MIDI) and a scale flavor
FAMILIES = {
    "space-adventure": (64, "major"),
    "jungle-outdoors": (62, "major"),
    "magical": (67, "major"),
    "cozy-shop": (60, "major"),
    "spooky-silly": (57, "minor"),
    "under-the-sea": (65, "major"),
    "desert-western": (59, "minor"),
}
SCALES = {"major": [0, 4, 7, 12, 7, 4], "minor": [0, 3, 7, 12, 7, 3]}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def note(freq, dur, vol=0.25, attack=0.01, release=0.08, bell=False):
    """One soft note (a sine with a quiet octave), with a tiny attack/release so notes join without clicks."""
    n = int(RATE * dur)
    t = np.arange(n) / RATE
    w = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * 2 * freq * t)
    env = np.ones(n)
    a, r = int(RATE * attack), int(RATE * min(release, dur / 2))
    env[:a] = np.linspace(0, 1, a)
    env[n - r:] = np.linspace(1, 0, r)
    if bell:
        env *= np.exp(-3.5 * t)
    return vol * w * env


def calm(root, scale):
    beat = 0.5  # 120 notes a minute, 8 notes = 4 s
    notes = [note(hz(root + scale[i % len(scale)]), beat, 0.18) for i in range(8)]
    return np.concatenate(notes)


def tense(root, scale):
    step = 0.25  # twice as fast, low and pulsing
    seq = [0, 0, scale[1], 0, 0, scale[2], 0, scale[1]] * 2
    return np.concatenate([note(hz(root - 12 + s), step, 0.22, release=0.05) for s in seq])


def win(root, scale):
    seq = [0, 4 if scale[1] == 4 else 3, 7, 12]
    parts = [note(hz(root + s), 0.18, 0.25) for s in seq]
    parts.append(note(hz(root + 12), 0.9, 0.28, release=0.6))
    return np.concatenate(parts)


def chime():
    return np.concatenate([note(hz(84), 0.35, 0.3, bell=True), note(hz(91), 0.6, 0.3, bell=True)])


def is_real_music(path):
    """True when path exists and is NOT one of our placeholder tones (real music never carries title=PLACEHOLDER)."""
    if not os.path.exists(path):
        return False
    tags = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format_tags=title", "-of", "default=nw=1:nk=1", path],
                          capture_output=True, text=True).stdout.strip()
    return tags != "PLACEHOLDER"


def write(path, samples):
    if is_real_music(path):
        print(f"{os.path.relpath(path, ROOT)}: real music, kept")
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(samples, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav = tmp.name
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "aac", "-b:a", "24k",
                    "-metadata", "title=PLACEHOLDER", "-metadata", "comment=PLACEHOLDER tone, replace with the real music",
                    path], check=True)
    os.unlink(wav)
    print(f"{os.path.relpath(path, ROOT)}: {os.path.getsize(path)} bytes")


def main():
    for fam, (root, flavor) in FAMILIES.items():
        sc = SCALES[flavor]
        write(os.path.join(ROOT, fam, "calm.m4a"), calm(root, sc))
        write(os.path.join(ROOT, fam, "tense.m4a"), tense(root, sc))
        write(os.path.join(ROOT, fam, "win.m4a"), win(root, sc))
    write(os.path.join(ROOT, "chime.m4a"), chime())


if __name__ == "__main__":
    sys.exit(main())
