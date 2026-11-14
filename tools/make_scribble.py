#!/usr/bin/env python3
"""Generates PretendThat/Resources/scribble.wav: a soft, loopable crayon/pencil scribble (filtered noise bursts),
used under Nutmeg's writing moment. Deterministic (seeded), 2.4 s, 22.05 kHz mono 16-bit."""
import math, os, random, struct, wave
SR, DUR = 22050, 2.4
random.seed(7)
n = int(SR * DUR)
out = [0.0] * n

def biquad_bandpass(f0, q):
    w = 2 * math.pi * f0 / SR; a = math.sin(w) / (2 * q); c = math.cos(w)
    b0, b1, b2, a0, a1, a2 = a, 0, -a, 1 + a, -2 * c, 1 - a
    return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]

t = int(0.01 * SR)
while t < n - int(0.12 * SR):
    length = int(random.uniform(0.07, 0.17) * SR)
    f0 = random.uniform(2600, 4200)
    b = biquad_bandpass(f0, 0.9)
    x1 = x2 = y1 = y2 = 0.0
    gain = random.uniform(0.6, 1.0)
    grain_f = random.uniform(28, 55)   # paper tooth: a fast amplitude flutter
    for i in range(length):
        if t + i >= n: break
        x = random.uniform(-1, 1)
        y = b[0] * x + b[1] * x1 + b[2] * x2 - b[3] * y1 - b[4] * y2
        x2, x1, y2, y1 = x1, x, y1, y
        p = i / length
        env = min(1, p / 0.12) * min(1, (1 - p) / 0.3) * (0.75 + 0.25 * math.sin(2 * math.pi * grain_f * i / SR))
        out[t + i] += y * env * gain
    t += length + int(random.uniform(0.03, 0.10) * SR)

peak = max(abs(v) for v in out) or 1
scale = 10 ** (-10 / 20) / peak
dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "PretendThat", "Resources", "scribble.wav")
with wave.open(dst, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in out))
print("wrote", dst)
