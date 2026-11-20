#!/usr/bin/env python3
"""Turns the picked takes of the six other music families into the app's bundled music (no AI calls, no keys).

2026-11-21. Same method as tools/process_music.py (space adventure, design/music-test/space-adventure/PICKS.md),
whose helpers it reuses (load, measure, limiter, encode, finish, seam, make_oneshot). Picks and reasons per family:
design/music-test/<family>/PICKS.md.
  pip install numpy librosa
  python3 tools/process_music_families.py                 # all six
  python3 tools/process_music_families.py cozy-shop       # one

Differences from the space script:
- Tempo and beat grid are measured per take (librosa beat track + least-squares grid fit), and the bar origin is the
  beat phase with the strongest onsets (the downbeat guess).
- Tempo snaps to the prompt BPM when the fit is within 0.1 % (every pick was), so bar lengths are exact.
- The loop (start bar 0-3, a multiple of 4 bars, at least 36 s calm / 28 s tense, ending before any fade-out and
  2.5 s before the take's end) is the one whose 250 ms after its end
  best matches its own head (log-mel distance + 0.3 x RMS difference), as for space.
- 100 BPM bars happen to be whole AAC frames at 48 kHz; most other tempos are not, and a loop that isn't a whole
  number of 1024-sample frames decodes with padding (a gap at every seam). So after the seam crossfade the loop is
  resampled (soxr) up to the next whole frame count: at most 1023 samples over 30-60 s, under 0.05 % tempo/pitch
  (far below hearing). The decoded .m4a is then exactly the loop again (checked).
- Leading silence on a win take is trimmed to 10 ms before its first sound.
"""
import json
import os
import sys

import numpy as np
import librosa

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process_music as pm  # noqa: E402

SR, XF, CTX = pm.SR, pm.XF, pm.CTX
ROOT = pm.ROOT

# family: prompt BPM, calm take, tense take, win take (picks: design/music-test/<family>/PICKS.md)
PICKS = {
    'jungle-outdoors': (96, 'calm-4', 'tense-1', 'win-4'),
    'magical': (90, 'calm-2', 'tense-2', 'win-1'),
    'cozy-shop': (104, 'calm-4', 'tense-2', 'win-1'),
    'spooky-silly': (108, 'calm-2', 'tense-4', 'win-4'),
    'under-the-sea': (92, 'calm-4', 'tense-3', 'win-2'),
    'desert-western': (100, 'calm-1', 'tense-1', 'win-1'),
}


def beat_grid(mono, bpm):
    """Least-squares beat grid (period, first-beat offset, residual) and the downbeat phase (0-3)."""
    oenv = librosa.onset.onset_strength(y=mono, sr=SR, hop_length=256)
    _, b = librosa.beat.beat_track(onset_envelope=oenv, sr=SR, hop_length=256, start_bpm=bpm, tightness=400)
    bt = librosa.frames_to_time(b, sr=SR, hop_length=256)
    k = np.round((bt - bt[0]) / (60 / bpm))
    A = np.vstack([k, np.ones_like(k)]).T
    (p, o), *_ = np.linalg.lstsq(A, bt, rcond=None)
    resid = float(np.std(bt - A @ [p, o]))
    o %= p
    phase = []
    for j in range(4):
        idx = [librosa.time_to_frames(o + (4 * m + j) * p, sr=SR, hop_length=256)
               for m in range(int((len(mono) / SR - o) / (4 * p)))]
        phase.append(float(np.mean([oenv[i] for i in idx if i < len(oenv)])))
    return p, o, resid, int(np.argmax(phase))


def body_end(mono):
    """Seconds where the take's body ends: the first second in the last 12 s that falls 3 dB under the median."""
    r = 20 * np.log10(librosa.feature.rms(y=mono, frame_length=SR, hop_length=SR)[0] + 1e-9)
    med = np.median(r[2:-3])
    for i in range(max(2, len(r) - 12), len(r)):
        if r[i] < med - 3:
            return min(float(i), len(mono) / SR - 2.5)
    return len(mono) / SR - 2.5


def best_loop(mono, origin, bar, end_s, min_s):
    cands = []
    for sb in range(4):
        s = origin + sb * bar
        for nb in range(8, 33, 4):
            e = s + nb * bar
            if e + 0.3 > end_s or nb * bar < min_s:
                continue
            a, b = mono[int(e * SR):int((e + 0.25) * SR)], mono[int(s * SR):int((s + 0.25) * SR)]
            d = float(np.mean(np.abs(pm.mel(a) - pm.mel(b))))
            cands.append((d + 0.3 * abs(pm.db(a) - pm.db(b)), sb, nb, round(d, 3), round(pm.db(a) - pm.db(b), 2)))
    cands.sort()
    return cands


def make_loop(src, dst, test_dst, bpm, target, min_s):
    y = pm.load(src)
    mono = y.mean(1)
    p, o, resid, down = beat_grid(mono, bpm)
    p_fit = p
    if abs(60 / p - bpm) / bpm < 0.001:   # the takes keep the asked tempo; use it exactly (bar-exact lengths)
        p = 60 / bpm
    bar = 4 * p
    origin = o + down * p
    end_s = body_end(mono)
    cands = best_loop(mono, origin, bar, end_s, min_s)
    _, sb, nb, _, _ = cands[0]
    n_src = int(round(nb * bar * SR))
    s = pm.upward_zero_crossing(mono, int(round((origin + sb * bar) * SR)))
    e = s + n_src
    k = int(XF * SR)
    t = np.linspace(0, np.pi / 2, k)[:, None]
    loop = y[s:e].copy()
    loop[:k] = loop[:k] * np.sin(t) + y[e:e + k] * np.cos(t)
    before = pm.seam(y[s:e], y, e)
    n = -(-n_src // 1024) * 1024           # next whole number of AAC frames
    if n != n_src:                          # circular resample so the seam stays continuous
        pad = 4096
        ext = np.vstack([loop[-pad:], loop, loop[:pad]])
        r = np.stack([librosa.resample(ext[:, c], orig_sr=n_src, target_sr=n, res_type='soxr_vhq') for c in range(2)], 1)
        off = int(round(pad * n / n_src))
        loop = r[off:off + n]
    _, info = pm.finish(loop, target, -1.0, dst, True, lambda z: z[-CTX:], lambda z: z[:CTX])
    dec = pm.load(dst)
    assert len(dec) == n, (len(dec), n)
    pm.encode(np.tile(dec, (3, 1)), test_dst, dec[-CTX:], dec[:CTX])
    src_after = np.vstack([dec, y[e:]])     # the source carrying on past the loop end, for the natural-seam target
    info.update(source=os.path.basename(src), bpm_measured=round(60 / p_fit, 3), bpm_used=round(60 / p, 3), beat_grid_resid_ms=round(resid * 1000, 1),
                downbeat_phase=down, start_s=round(s / SR, 4), start_bar=sb, bars=nb, body_end_s=end_s,
                length_s=round(n / SR, 4), samples_source=n_src, samples=n,
                resample_ppm=round((n / n_src - 1) * 1e6, 1), decoded_samples=len(dec),
                loop_candidates_top3=[list(c) for c in cands[:3]], seam_raw_cut=before,
                seam_processed_m4a=pm.seam(dec, src_after, n), bytes=os.path.getsize(dst))
    return info


def make_win(src, dst):
    y = pm.load(src)
    a = np.abs(y).max(1)
    first = int(np.argmax(a > 10 ** (-50 / 20)))
    lead = max(0, first - int(0.010 * SR))
    tmp = dst + '.trim.wav'
    pm.save_wav(tmp, y[lead:])
    info = pm.make_oneshot(tmp, dst, -16.0, -1.0, 0.003, 0.020)
    os.remove(tmp)
    info.update(source=os.path.basename(src), trimmed_lead_s=round(lead / SR, 3))
    return info


def process(fam):
    bpm, calm, tense, win = PICKS[fam]
    takes = os.path.join(ROOT, 'design/music-test', fam)
    out = os.path.join(ROOT, 'PretendThat/Resources/Music', fam)
    test = os.path.join(takes, 'processed')
    for d in (out, test):
        os.makedirs(d, exist_ok=True)
    report = {
        'calm': make_loop(f'{takes}/{calm}.mp3', f'{out}/calm.m4a', f'{test}/loop-test-calm-x3.m4a', bpm, -16.0, 36),
        'tense': make_loop(f'{takes}/{tense}.mp3', f'{out}/tense.m4a', f'{test}/loop-test-tense-x3.m4a', bpm, -15.0, 28),
        'win': make_win(f'{takes}/{win}.mp3', f'{out}/win.m4a'),
    }
    with open(os.path.join(test, 'measurements.json'), 'w') as f:
        json.dump(report, f, indent=1)
    return report


if __name__ == '__main__':
    for fam in sys.argv[1:] or PICKS:
        r = process(fam)
        print(fam, json.dumps({k: {kk: v[kk] for kk in ('source', 'lufs', 'true_peak_dbtp', 'length_s') if kk in v}
                               for k, v in r.items()}), flush=True)
