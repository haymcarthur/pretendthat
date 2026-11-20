#!/usr/bin/env python3
"""Turns picked AI music takes into the app's bundled music files (no AI calls, no keys; ffmpeg + numpy + librosa).

2026-11-21 (decisions/2026-11-21-one-scene-music-beats.md, design/music-test/space-adventure/PICKS.md).
  pip install numpy librosa
  python3 tools/process_music.py            # space adventure: calm-2 / tense-3 / win-4 + chime-1

What it does:
- Loops: a whole, even number of bars at the measured tempo (100 BPM, 4/4 = 2.4 s a bar), starting on a downbeat at
  an upward zero crossing. The 30 ms just past the loop's end is equal-power crossfaded into the head, so the last
  sample flows into the first the way the music itself continues. Two bars at 100 BPM / 48 kHz are exactly 225 AAC
  frames, so an even bar count needs no end padding.
- Loudness: a static gain to the target (calm/win -16 LUFS, tense -15, chime -14), then a look-ahead peak limiter
  (circular for loops, so the seam stays continuous) until the DECODED .m4a's true peak is <= -1 dBTP.
- Encode: AAC-LC 96 kbps 48 kHz .m4a (the takes are 48 kHz; iOS output hardware runs at 48 kHz). ffmpeg's AAC
  encoder smears the first frames of a file (about 10 dB worse error, a click at every loop), so each file is encoded
  with real context in front (the loop's own tail, or silence for one-shots) and then cut back to its exact start
  with an MP4 edit list (1024 priming samples), which AVFoundation honours. The decoded file is sample-exact.
- Writes 3x loop-test .m4a files of the processed loops and measurements.json.
"""
import json
import os
import re
import subprocess

import numpy as np
import librosa
from numpy.lib.stride_tricks import sliding_window_view

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR, BAR, XF, CTX = 48000, 2.4, 0.030, 16384


def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)


def save_wav(path, x):
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f64le', '-ac', '2', '-ar', str(SR), '-i', '-',
                    '-c:a', 'pcm_f32le', path], input=np.ascontiguousarray(x).tobytes(), check=True)


def measure(path):
    o = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', path, '-af', 'ebur128=peak=true', '-f', 'null', '-'],
                       capture_output=True, text=True).stderr
    return (float(re.findall(r'I:\s+(-?[\d.]+) LUFS', o)[-1]), float(re.findall(r'LRA:\s+(-?[\d.]+) LU', o)[-1]),
            float(re.findall(r'Peak:\s+(-?[\d.]+) dBFS', o)[-1]))


def upward_zero_crossing(mono, i, rad=96):
    seg = mono[i - rad:i + rad]
    s = np.where((seg[:-1] <= 0) & (seg[1:] > 0))[0]
    return i if len(s) == 0 else i - rad + int(s[np.argmin(np.abs(s - rad))])


def limiter(x, ceiling_db, circular, look=0.002, release=0.08):
    """Look-ahead peak limiter on 4x-oversampled peaks; the gain only dips where a peak would pass the ceiling."""
    n, pad = len(x), int(0.25 * SR)
    xx = np.vstack([x[-pad:], x, x[:pad]]) if circular else np.vstack([np.zeros((pad, 2)), x, np.zeros((pad, 2))])
    pk = np.abs(xx).max(1)
    for c in range(2):
        up = np.abs(librosa.resample(xx[:, c], orig_sr=SR, target_sr=SR * 4, res_type='soxr_hq'))
        m = min(len(up) // 4, len(xx))
        pk[:m] = np.maximum(pk[:m], up[:m * 4].reshape(-1, 4).max(1))
    g = np.minimum(1.0, 10 ** (ceiling_db / 20) / np.maximum(pk, 1e-9))
    L = int(look * SR)
    gm = sliding_window_view(np.concatenate([g, np.ones(L)]), L + 1).min(1)[:len(g)]
    a = np.exp(-1 / (release * SR))
    out = np.empty_like(gm)
    cur = 1.0
    for i, v in enumerate(gm):          # instant attack (the look-ahead covers it), smooth release
        cur = v if v < cur else a * cur + (1 - a) * v
        out[i] = cur
    out = np.minimum(np.convolve(out, np.ones(L) / L, mode='same'), gm)
    return (xx * out[:, None])[pad:pad + n]


def encode(x, dst, head, tail, bitrate='96k'):
    """AAC with real context around x, cut back to exactly x with an edit list."""
    tmp, enc = dst + '.ctx.wav', dst + '.ctx.m4a'
    save_wav(tmp, np.vstack([head, x, tail]))
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'aac', '-b:a', bitrate, enc], check=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', '%.6f' % ((len(head) - 1024) / SR), '-i', enc,
                    '-t', '%.6f' % ((len(x) + 1024) / SR), '-c', 'copy', '-output_ts_offset', '%.6f' % (-1024 / SR),
                    '-avoid_negative_ts', 'disabled', '-use_editlist', '1', '-map_metadata', '-1',
                    '-movflags', '+faststart', dst], check=True)
    os.remove(tmp)
    os.remove(enc)


def mel(x):
    return np.log(librosa.feature.melspectrogram(y=x, sr=SR, n_fft=4096, hop_length=1024, n_mels=64).mean(1) + 1e-10)


def db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def seam(loop, src=None, end=None):
    """First vs last 200 ms of the loop (RMS jump, log-mel distance), the 10 ms RMS step and the sample step right at
    the seam; with src/end, the same numbers where the source itself carries on past the loop end (the target)."""
    m, w, h = loop.mean(1), int(0.2 * SR), int(0.01 * SR)
    r = dict(rms_jump_db=round(db(m[:w]) - db(m[-w:]), 2),
             mel_dist=round(float(np.mean(np.abs(mel(m[-w:]) - mel(m[:w])))), 3),
             rms10_step_db=round(abs(db(m[:h]) - db(m[-h:])), 2),
             sample_step=round(float(abs(m[0] - m[-1])), 4),
             median_sample_step=round(float(np.median(np.abs(np.diff(m)))), 4))
    if src is not None:
        s = src.mean(1)
        r['natural_rms_jump_db'] = round(db(s[end:end + w]) - db(s[end - w:end]), 2)
        r['natural_mel_dist'] = round(float(np.mean(np.abs(mel(s[end - w:end]) - mel(s[end:end + w])))), 3)
    return r


def finish(x, target, tp_max, dst, circular, head_fn, tail_fn, release=0.08):
    """Static gain to the target loudness, then limit until the decoded .m4a's true peak is <= tp_max."""
    tmp = dst + '.m.wav'
    save_wav(tmp, x)
    i0 = measure(tmp)[0]
    os.remove(tmp)
    x = x * 10 ** ((target - i0) / 20)
    ceiling = tp_max - 0.5
    for _ in range(8):
        y = limiter(x, ceiling, circular, release=release)
        encode(y, dst, head_fn(y), tail_fn(y))
        lufs, lra, tp = measure(dst)
        if tp <= tp_max:
            break
        ceiling -= (tp - tp_max) + 0.2
    return y, dict(source_lufs=i0, lufs=lufs, lra=lra, true_peak_dbtp=tp, limiter_ceiling_db=round(ceiling, 2))


def make_loop(src_path, dst, test_dst, offset, start_bar, bars, target):
    assert bars % 2 == 0, 'an even bar count keeps the loop a whole number of AAC frames at 48 kHz'
    y = load(src_path)
    n = int(round(bars * BAR * SR))
    s = upward_zero_crossing(y.mean(1), int(round((offset + start_bar * BAR) * SR)))
    e = s + n
    k = int(XF * SR)
    t = np.linspace(0, np.pi / 2, k)[:, None]
    loop = y[s:e].copy()
    loop[:k] = loop[:k] * np.sin(t) + y[e:e + k] * np.cos(t)
    before = seam(y[s:e], y, e)
    _, info = finish(loop, target, -1.0, dst, True, lambda z: z[-CTX:], lambda z: z[:CTX])
    dec = load(dst)
    assert len(dec) == n, (len(dec), n)
    encode(np.tile(dec, (3, 1)), test_dst, dec[-CTX:], dec[:CTX])
    info.update(source=os.path.basename(src_path), start_s=round(s / SR, 4), start_bar=start_bar, bars=bars,
                length_s=round(n / SR, 4), samples=n, decoded_samples=len(dec), seam_raw_cut=before,
                seam_processed_m4a=seam(dec, y[s:].copy(), n), bytes=os.path.getsize(dst))
    return info


def make_oneshot(src_path, dst, target, tp_max, fade_in, fade_out, release=0.08):
    y = load(src_path)
    a, b = int(fade_in * SR), int(fade_out * SR)
    y[:a] *= np.linspace(0, 1, a)[:, None]
    y[-b:] *= np.linspace(1, 0, b)[:, None]
    zeros = lambda _: np.zeros((CTX, 2))
    _, info = finish(y, target, tp_max, dst, False, zeros, zeros, release)
    info.update(source=os.path.basename(src_path), length_s=round(len(y) / SR, 3), samples=len(y),
                decoded_samples=len(load(dst)), bytes=os.path.getsize(dst))
    return info


if __name__ == '__main__':
    takes = os.path.join(ROOT, 'design/music-test/space-adventure')
    music = os.path.join(ROOT, 'PretendThat/Resources/Music')
    fam, test = os.path.join(music, 'space-adventure'), os.path.join(takes, 'processed')
    for d in (fam, test):
        os.makedirs(d, exist_ok=True)
    # Beat grids measured with librosa (PICKS.md): both takes are 100.00 BPM, first beat at 12.1 / 9.6 ms.
    report = {
        'calm': make_loop(f'{takes}/calm-2.mp3', f'{fam}/calm.m4a', f'{test}/loop-test-calm-x3.m4a', 0.0121, 3, 20, -16.0),
        'tense': make_loop(f'{takes}/tense-3.mp3', f'{fam}/tense.m4a', f'{test}/loop-test-tense-x3.m4a', 0.0096, 0, 16, -15.0),
        'win': make_oneshot(f'{takes}/win-4.mp3', f'{fam}/win.m4a', -16.0, -1.0, 0.003, 0.020),
        'chime': make_oneshot(f'{takes}/chime-1.mp3', f'{music}/chime.m4a', -14.0, -1.0, 0.0015, 0.030, release=0.015),
    }
    with open(os.path.join(test, 'measurements.json'), 'w') as f:
        json.dump(report, f, indent=1)
    print(json.dumps(report, indent=1))
