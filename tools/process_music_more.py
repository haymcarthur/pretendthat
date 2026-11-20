#!/usr/bin/env python3
"""Measure, pick and process the 2-take music families superhero-city, pirate-adventure and rescue-team (2026-11-21).

No AI calls, no keys. Reuses tools/process_music.py (the space-adventure method: whole-bar loops, a 30 ms equal-power
seam crossfade, static gain + circular look-ahead limiter, AAC-LC 96 kbps 48 kHz with an edit list), with each
family's own measured beat grid instead of 100 BPM 4/4. (tools/process_music_families.py does the same for the six
other families; this file is separate so the two runs don't collide.)

  pip install numpy scipy librosa
  python3 tools/process_music_more.py analyze <family>      # measurements of every take (JSON)
  python3 tools/process_music_more.py grid <family> <take> <bpm_lo> <bpm_hi> <beats_per_bar>
  python3 tools/process_music_more.py search <family> <take> <bpm_lo> <bpm_hi> <unit_beats> <downbeat_phase>
  python3 tools/process_music_more.py process [family]      # the picks in FAMILIES -> PretendThat/Resources/Music

The shared chime (PretendThat/Resources/Music/chime.m4a) is not touched.
"""
import json
import os
import sys

import numpy as np
import librosa

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process_music as pm  # noqa: E402

ROOT, SR = pm.ROOT, pm.SR
KS_MAJ = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
KS_MIN = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
NOTES = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']

# The picks (reasons: design/music-test/<family>/PICKS.md). Loops: take, beat grid from comb_grid (bpm, first beat in
# s), the loop's start beat (a downbeat) and its length in beats (whole 4-bar phrases; pirate: whole 12-beat units, as
# its chords move every 4 beats and its drum pattern every 6). Win: take.
FAMILIES = {
    'superhero-city': dict(calm=dict(take='calm-1', bpm=112.002, first_beat=0.040, start_beat=28, beats=80),
                           tense=dict(take='tense-1', bpm=112.000, first_beat=0.040, start_beat=12, beats=64),
                           win='win-1'),
    'pirate-adventure': dict(calm=dict(take='calm-1', bpm=104.004, first_beat=0.308, start_beat=37, beats=48),
                             tense=dict(take='tense-1', bpm=103.994, first_beat=0.308, start_beat=25, beats=48),
                             win='win-1'),
    'rescue-team': dict(calm=dict(take='calm-1', bpm=107.988, first_beat=0.016, start_beat=12, beats=64),
                        tense=dict(take='tense-2', bpm=107.996, first_beat=0.020, start_beat=28, beats=48),
                        win='win-1'),
}


# ---------- measurements ----------

def chroma(mono):
    return librosa.feature.chroma_cqt(y=librosa.resample(mono, orig_sr=SR, target_sr=22050), sr=22050)


def key_corr(cv, tonic, minor):
    return float(np.corrcoef(cv, np.roll(KS_MIN if minor else KS_MAJ, tonic))[0, 1])


def keys(cv, n=3):
    c = sorted(((key_corr(cv, t, m), NOTES[t] + (' min' if m else ' maj')) for t in range(12) for m in (0, 1)),
               reverse=True)
    return [(k, round(v, 3)) for v, k in c[:n]]


def per_second_rms_db(mono):
    n = len(mono) // SR
    return np.array([pm.db(mono[i * SR:(i + 1) * SR]) for i in range(n)])


def body_end(mono):
    """Where the take stops being 'body' (fade-out or ring-out): the last second within 4 dB of the median level."""
    r = per_second_rms_db(mono)
    ok = np.where(r > np.median(r) - 4)[0]
    return float(ok[-1] + 1) if len(ok) else len(mono) / SR


def comb_grid(mono, bpm_lo, bpm_hi, step=0.002):
    """Exact beat grid: the period and phase whose beat positions collect the most onset strength (a comb search,
    sturdier than librosa's beat list on swung takes)."""
    y = librosa.resample(mono, orig_sr=SR, target_sr=22050)
    hop = 128
    oe = librosa.onset.onset_strength(y=y, sr=22050, hop_length=hop)
    fr = 22050 / hop
    best = (-1, 0, 0)
    for bpm in np.arange(bpm_lo, bpm_hi, step):
        per = 60 / bpm
        k = np.arange(0, int((len(oe) / fr - per) / per))
        for ph in np.arange(0, per, 0.004):
            v = oe[np.minimum(np.round((ph + k * per) * fr).astype(int), len(oe) - 1)].mean()
            if v > best[0]:
                best = (v, bpm, ph)
    return dict(bpm=round(float(best[1]), 3), period=60 / float(best[1]), first_beat=round(float(best[2]), 4))


def downbeat_phase(mono, period, first_beat, beats_per_bar):
    """Score each beat phase of the bar by harmonic change across it (chroma distance half a beat either side) and
    low-end onset strength: chord changes and kicks land on downbeats."""
    y = librosa.resample(mono, orig_sr=SR, target_sr=22050)
    hop = 256
    ch = librosa.feature.chroma_cqt(y=librosa.effects.harmonic(y, margin=2), sr=22050, hop_length=hop)
    S = np.abs(librosa.stft(y, n_fft=2048, hop_length=hop))
    lo = librosa.onset.onset_strength(
        S=librosa.amplitude_to_db(S[librosa.fft_frequencies(sr=22050, n_fft=2048) < 150]), sr=22050, hop_length=hop)
    fr, n = 22050 / hop, min(ch.shape[1], len(lo))
    hc, ho = np.zeros(beats_per_bar), np.zeros(beats_per_bar)
    half = int(period / 2 * fr)
    k = 1
    while True:
        i = int(round((first_beat + k * period) * fr))
        if i + half >= n:
            break
        a, b = ch[:, i - half:i].mean(1), ch[:, i:i + half].mean(1)
        hc[k % beats_per_bar] += 1 - np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9)
        ho[k % beats_per_bar] += lo[max(0, i - 2):i + 3].max()
        k += 1
    hc, ho = hc / hc.max(), ho / ho.max()
    return dict(harmonic=[round(float(v), 2) for v in hc], bass=[round(float(v), 2) for v in ho],
                combined=[round(float(v), 2) for v in (hc + ho) / 2])


def final_notes(mono, a, b):
    """Sounding pitches (harmonic part, peaks at semitone centres) between a and b seconds."""
    y = librosa.effects.harmonic(librosa.resample(mono, orig_sr=SR, target_sr=22050), margin=4)
    C = np.abs(librosa.cqt(y, sr=22050, fmin=librosa.note_to_hz('C3'), n_bins=144, bins_per_octave=36,
                           hop_length=512))
    t = librosa.frames_to_time(np.arange(C.shape[1]), sr=22050, hop_length=512)
    s = C[:, (t >= a) & (t < b)].mean(1)
    return [librosa.midi_to_note(48 + i // 3, unicode=False) for i in range(1, len(s) - 1)
            if s[i] > s[i - 1] and s[i] >= s[i + 1] and s[i] > 0.2 * s.max() and i % 3 == 0]


def analyze(family):
    d = os.path.join(ROOT, 'design/music-test', family)
    out, cvs = {}, {}
    for seg in ('calm', 'tense', 'win'):
        for k in (1, 2):
            name = f'{seg}-{k}'
            p = os.path.join(d, name + '.mp3')
            m = pm.load(p).mean(1)
            lufs, lra, tp = pm.measure(p)
            be = body_end(m)
            r = per_second_rms_db(m)
            body = r[1:int(be) - 1]
            cv = chroma(m[:int(be * SR)]).mean(1)
            cvs[name] = cv
            info = dict(length_s=round(len(m) / SR, 2), lufs=lufs, lra=lra, peak_dbfs=tp, keys=keys(cv),
                        body_end_s=be, rms_spread_db=round(float(np.std(body)), 2),
                        rms_per_s_vs_median=np.round(r - np.median(r), 1).tolist())
            if seg == 'win':
                info['last_notes'] = final_notes(m, be - 1.5, be)
            out[name] = info
    names = list(cvs)
    out['chroma_similarity'] = {f'{a}~{b}': round(float(np.dot(cvs[a], cvs[b]) /
                                                     (np.linalg.norm(cvs[a]) * np.linalg.norm(cvs[b]))), 3)
                                for i, a in enumerate(names) for b in names[i + 1:] if a[:4] != b[:4]}
    return out


def loop_search(path, period, first_beat, unit, phase, beats_per_bar=4, min_len=24.0):
    """Every loop that starts on a downbeat (beat index = phase mod beats_per_bar) and lasts a whole number of
    `unit` beats (>= min_len s, ending 0.5 s before any fade), scored by how well the 250 ms after its end matches
    its own head (log-mel distance + 0.1 x RMS difference in dB), as for space adventure."""
    m = pm.load(path).mean(1)
    be = body_end(m)
    w = int(0.25 * SR)
    res = []
    j = phase
    while first_beat + j * period < be / 2:
        s = int(round((first_beat + j * period) * SR))
        L = unit
        while (first_beat + (j + L) * period) + 0.5 <= be:
            if L * period >= min_len:
                e = s + int(round(L * period * SR))
                d = float(np.mean(np.abs(pm.mel(m[e:e + w]) - pm.mel(m[s:s + w]))))
                rj = abs(pm.db(m[e:e + w]) - pm.db(m[s:s + w]))
                res.append((round(d + 0.1 * rj, 3), j, L, round(d, 3), round(rj, 2),
                            round(s / SR, 3), round(L * period, 2)))
            L += unit
        j += beats_per_bar
    res.sort()
    return res[:8]


# ---------- processing ----------

def make_loop(src_path, dst, test_dst, start_s, length_s, target):
    """process_music.make_loop with any length: the cut loop (seam crossfaded) is resampled circularly (FFT, exact for
    a periodic signal) to the nearest whole number of 1024-sample AAC frames, a speed change of < 0.05 %, so the
    copied AAC packets end exactly on the loop end (otherwise ffmpeg pads to the next frame: a gap at every seam)."""
    from scipy.signal import resample
    y = pm.load(src_path)
    n0 = int(round(length_s * SR))
    n = int(round(n0 / 1024)) * 1024
    s = pm.upward_zero_crossing(y.mean(1), int(round(start_s * SR)))
    e = s + n0
    k = int(pm.XF * SR)
    t = np.linspace(0, np.pi / 2, k)[:, None]
    loop = y[s:e].copy()
    loop[:k] = loop[:k] * np.sin(t) + y[e:e + k] * np.cos(t)
    before = pm.seam(y[s:e], y, e)
    loop = resample(loop, n, axis=0)
    _, info = pm.finish(loop, target, -1.0, dst, True, lambda z: z[-pm.CTX:], lambda z: z[:pm.CTX])
    dec = pm.load(dst)
    assert len(dec) == n, (len(dec), n)
    pm.encode(np.tile(dec, (3, 1)), test_dst, dec[-pm.CTX:], dec[:pm.CTX])
    info.update(source=os.path.basename(src_path), start_s=round(s / SR, 4), cut_samples=n0, samples=n,
                length_s=round(n / SR, 4), speed_change_pct=round((n0 / n - 1) * 100, 4), decoded_samples=len(dec),
                seam_raw_cut=before, seam_processed_m4a=pm.seam(dec), bytes=os.path.getsize(dst))
    return info


def process(family):
    cfg = FAMILIES[family]
    takes = os.path.join(ROOT, 'design/music-test', family)
    fam = os.path.join(ROOT, 'PretendThat/Resources/Music', family)
    test = os.path.join(takes, 'processed')
    for d in (fam, test):
        os.makedirs(d, exist_ok=True)
    report = {}
    for seg, target in (('calm', -16.0), ('tense', -15.0)):
        c = cfg[seg]
        per = 60 / c['bpm']
        start, length = c['first_beat'] + c['start_beat'] * per, c['beats'] * per
        report[seg] = make_loop(f'{takes}/{c["take"]}.mp3', f'{fam}/{seg}.m4a', f'{test}/loop-test-{seg}-x3.m4a',
                                start, length, target)
        report[seg].update(bpm=c['bpm'], start_beat=c['start_beat'], beats=c['beats'])
    report['win'] = pm.make_oneshot(f'{takes}/{cfg["win"]}.mp3', f'{fam}/win.m4a', -16.0, -1.0, 0.003, 0.020)
    with open(os.path.join(test, 'measurements.json'), 'w') as f:
        json.dump(report, f, indent=1, default=float)
    print(json.dumps(report, indent=1, default=float))


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'analyze':
        print(json.dumps(analyze(sys.argv[2]), indent=1))
    elif cmd == 'grid':
        fam, take, lo, hi, bpb = sys.argv[2:7]
        m = pm.load(os.path.join(ROOT, 'design/music-test', fam, take + '.mp3')).mean(1)
        g = comb_grid(m, float(lo), float(hi))
        print(json.dumps(dict(g, downbeat=downbeat_phase(m, g['period'], g['first_beat'], int(bpb)))))
    elif cmd == 'search':
        fam, take, lo, hi, unit, phase = sys.argv[2:8]
        p = os.path.join(ROOT, 'design/music-test', fam, take + '.mp3')
        g = comb_grid(pm.load(p).mean(1), float(lo), float(hi))
        print(g, loop_search(p, g['period'], g['first_beat'], int(unit), int(phase)))
    else:
        for f in ([sys.argv[2]] if len(sys.argv) > 2 else FAMILIES):
            process(f)
