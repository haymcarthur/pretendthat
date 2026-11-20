#!/usr/bin/env python3
"""Second calm loops (calm2) for every music family, four new families, and two win redos (2026-11-20).

No AI calls, no keys. The same method as tools/process_music_families.py (which reuses tools/process_music.py):
librosa beat grid snapped to the asked tempo, a whole-bar loop starting on a downbeat at an upward zero crossing,
picked by how well the music just past its end matches its head; a 30 ms equal-power seam crossfade; resampled by
< 0.05 % to a whole number of 1024-sample AAC frames; static gain to calm -16 / tense -15 / win -16 LUFS, circular
look-ahead limiter to <= -1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list (sample-exact when decoded).
Picks and reasons: design/music-test/<family>/PICKS.md.

  pip install numpy scipy librosa
  python3 tools/process_music_calm2.py analyze <family> <take> [<take> ...]   # measurements (JSON)
  python3 tools/process_music_calm2.py calm2 [family ...]       # CALM2 picks -> <family>/calm2.m4a + A+B+A test
  python3 tools/process_music_calm2.py family [family ...]      # NEW families -> calm/calm2/tense/win.m4a
  python3 tools/process_music_calm2.py win <family> <take>      # one win take -> <family>/win.m4a
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process_music as pm  # noqa: E402
import process_music_families as pf  # noqa: E402
import process_music_more as pmm  # noqa: E402

ROOT, SR, XF, CTX = pm.ROOT, pm.SR, pm.XF, pm.CTX
MUSIC = os.path.join(ROOT, 'PretendThat/Resources/Music')
TESTS = os.path.join(ROOT, 'design/music-test')

# family: (bpm of the picked calm A, calm A take, its measured key, bars allowed per loop or None = 8..32 step 4)
# Pirate's 6-beat drum groove over 4-beat chords repeats every 12 beats, so its loops are whole 12-bar (48-beat) units.
FAMILY_A = {
    'space-adventure': (100, 'calm-2', 'C maj', None),
    'jungle-outdoors': (96, 'calm-4', 'D maj', None),
    'magical': (90, 'calm-2', 'F maj', None),
    'cozy-shop': (104, 'calm-4', 'G maj', None),
    'spooky-silly': (108, 'calm-2', 'E min', None),
    'under-the-sea': (92, 'calm-4', 'C maj', None),
    'desert-western': (100, 'calm-1', 'E maj', None),
    'superhero-city': (112, 'calm-1', 'C maj', None),
    'pirate-adventure': (104, 'calm-1', 'D maj', (12, 24)),
    'rescue-team': (108, 'calm-1', 'G maj', None),
}

# The calm2 picks (filled in after analysis; reasons in each PICKS.md).
CALM2 = {
    'space-adventure': 'calm2-1',
    'jungle-outdoors': 'calm2-1',
    'magical': 'calm2-1',          # the only take (the other generation failed); C major, the dominant of calm A's F
    'cozy-shop': 'calm2-2',
    'spooky-silly': 'calm2-1',
    'under-the-sea': 'calm2-1',
    'desert-western': 'calm2-2',
    'superhero-city': 'calm2-1',
    'pirate-adventure': 'calm2-2',
    'rescue-team': 'calm2-1',
}

# New families: bpm, calm, calm2, tense, win takes.
NEW = {
    'snowy-north': (96, 'calm-1', 'calm2-2', 'tense-1', 'win-1'),       # asked A major; every pick came out in C
    'robot-lab': (108, 'calm-1', 'calm2-1', 'tense-1', 'win-1'),
    'circus-carnival': (112, 'calm-1', 'calm2-2', 'tense-1', 'win-1'),
    'race-day': (120, 'calm-1', 'calm2-1', 'tense-2', 'win-2'),
}


def analyze_take(path, bpm, asked=None):
    y = pm.load(path)
    m = y.mean(1)
    lufs, lra, tp = pm.measure(path)
    p, o, resid, down = pf.beat_grid(m, bpm)
    be = pmm.body_end(m)
    r = pmm.per_second_rms_db(m)
    body = r[1:max(2, int(be) - 1)]
    cv = pmm.chroma(m[:int(be * SR)]).mean(1)
    info = dict(length_s=round(len(m) / SR, 2), lufs=lufs, lra=lra, tp=tp, bpm_fit=round(60 / p, 3),
                grid_ms=round(resid * 1000, 1), keys=pmm.keys(cv), body_end_s=be,
                spread_db=round(float(np.std(body)), 2),
                drift_db=round(float(np.mean(body[-6:]) - np.mean(body[:6])), 1) if len(body) > 12 else None)
    if asked:
        t, mode = asked.split()
        info['asked_key_corr'] = round(pmm.key_corr(cv, pmm.NOTES.index(t), mode == 'min'), 3)
    return info, cv


def analyze(fam, takes, bpm, asked):
    out, cvs = {}, {}
    for t in takes:
        info, cv = analyze_take(os.path.join(TESTS, fam, t + '.mp3'), bpm, asked.get(t.split('-')[0]))
        if t.startswith('win'):
            m = pm.load(os.path.join(TESTS, fam, t + '.mp3')).mean(1)
            r = pmm.per_second_rms_db(m)
            info['last_notes'] = pmm.final_notes(m, info['body_end_s'] - 1.5, info['body_end_s'])
            info['last_notes_final_1s'] = pmm.final_notes(m, len(m) / SR - 2.0, len(m) / SR - 0.5)
            info['rms_last_3s_vs_median'] = np.round(r[-3:] - np.median(r), 1).tolist()
            info['tail_db_last_100ms'] = round(pm.db(m[-int(0.1 * SR):]), 1)
        out[t], cvs[t] = info, cv
    names = list(cvs)
    out['chroma_similarity'] = {f'{a}~{b}': round(float(np.dot(cvs[a], cvs[b]) /
                                                     (np.linalg.norm(cvs[a]) * np.linalg.norm(cvs[b]))), 3)
                                for i, a in enumerate(names) for b in names[i + 1:]}
    return out


def best_loop(mono, origin, bar, end_s, min_s, nbs):
    cands = []
    for sb in range(4):
        s = origin + sb * bar
        for nb in nbs:
            e = s + nb * bar
            if e + 0.3 > end_s or nb * bar < min_s:
                continue
            a, b = mono[int(e * SR):int((e + 0.25) * SR)], mono[int(s * SR):int((s + 0.25) * SR)]
            d = float(np.mean(np.abs(pm.mel(a) - pm.mel(b))))
            cands.append((d + 0.3 * abs(pm.db(a) - pm.db(b)), sb, nb, round(d, 3), round(pm.db(a) - pm.db(b), 2)))
    cands.sort()
    return cands


def make_loop(src, dst, test_dst, bpm, target, min_s, nbs=None):
    """process_music_families.make_loop with a choice of bar counts (pirate needs 12-bar units)."""
    if nbs is None:
        return pf.make_loop(src, dst, test_dst, bpm, target, min_s)
    import librosa
    y = pm.load(src)
    mono = y.mean(1)
    p, o, resid, down = pf.beat_grid(mono, bpm)
    p_fit = p
    if abs(60 / p - bpm) / bpm < 0.001:
        p = 60 / bpm
    bar = 4 * p
    origin = o + down * p
    end_s = pf.body_end(mono)
    cands = best_loop(mono, origin, bar, end_s, min_s, nbs)
    _, sb, nb, _, _ = cands[0]
    n_src = int(round(nb * bar * SR))
    s = pm.upward_zero_crossing(mono, int(round((origin + sb * bar) * SR)))
    e = s + n_src
    k = int(XF * SR)
    t = np.linspace(0, np.pi / 2, k)[:, None]
    loop = y[s:e].copy()
    loop[:k] = loop[:k] * np.sin(t) + y[e:e + k] * np.cos(t)
    before = pm.seam(y[s:e], y, e)
    n = -(-n_src // 1024) * 1024
    if n != n_src:
        pad = 4096
        ext = np.vstack([loop[-pad:], loop, loop[:pad]])
        r = np.stack([librosa.resample(ext[:, c], orig_sr=n_src, target_sr=n, res_type='soxr_vhq') for c in range(2)], 1)
        off = int(round(pad * n / n_src))
        loop = r[off:off + n]
    _, info = pm.finish(loop, target, -1.0, dst, True, lambda z: z[-CTX:], lambda z: z[:CTX])
    dec = pm.load(dst)
    assert len(dec) == n, (len(dec), n)
    pm.encode(np.tile(dec, (3, 1)), test_dst, dec[-CTX:], dec[:CTX])
    info.update(source=os.path.basename(src), bpm_measured=round(60 / p_fit, 3), bpm_used=round(60 / p, 3),
                beat_grid_resid_ms=round(resid * 1000, 1), downbeat_phase=down, start_s=round(s / SR, 4),
                start_bar=sb, bars=nb, body_end_s=end_s, length_s=round(n / SR, 4), samples_source=n_src, samples=n,
                resample_ppm=round((n / n_src - 1) * 1e6, 1), decoded_samples=len(dec),
                loop_candidates_top3=[list(c) for c in cands[:3]], seam_raw_cut=before,
                seam_processed_m4a=pm.seam(dec, np.vstack([dec, y[e:]]), n), bytes=os.path.getsize(dst))
    return info


def aba_test(fam):
    """calm, calm2, calm played back to back (as the app alternates them), and the two joins measured."""
    a = pm.load(os.path.join(MUSIC, fam, 'calm.m4a'))
    b = pm.load(os.path.join(MUSIC, fam, 'calm2.m4a'))
    dst = os.path.join(TESTS, fam, 'processed', 'loop-test-calm-aba.m4a')
    pm.encode(np.vstack([a, b, a]), dst, a[-CTX:], a[:CTX])
    w = int(0.2 * SR)
    ma, mb = a.mean(1), b.mean(1)
    joins = {}
    for name, x, z in (('A_to_B', ma, mb), ('B_to_A', mb, ma)):
        joins[name] = dict(rms_jump_db=round(pm.db(z[:w]) - pm.db(x[-w:]), 2),
                           mel_dist=round(float(np.mean(np.abs(pm.mel(x[-w:]) - pm.mel(z[:w])))), 3))
    la, lb = pm.measure(os.path.join(MUSIC, fam, 'calm.m4a'))[0], pm.measure(os.path.join(MUSIC, fam, 'calm2.m4a'))[0]
    return dict(file=os.path.relpath(dst, ROOT), seams_s=[round(len(a) / SR, 2), round((len(a) + len(b)) / SR, 2)],
                calm_lufs=la, calm2_lufs=lb, joins=joins)


def save_report(fam, key, report):
    p = os.path.join(TESTS, fam, 'processed', 'measurements.json')
    d = {}
    if os.path.exists(p):
        with open(p) as f:
            d = json.load(f)
    d.update({key: report} if key else report)
    with open(p, 'w') as f:
        json.dump(d, f, indent=1, default=float)


def do_calm2(fam):
    bpm, _, _, nbs = FAMILY_A[fam]
    take = CALM2[fam]
    os.makedirs(os.path.join(TESTS, fam, 'processed'), exist_ok=True)
    info = make_loop(os.path.join(TESTS, fam, take + '.mp3'), os.path.join(MUSIC, fam, 'calm2.m4a'),
                     os.path.join(TESTS, fam, 'processed', 'loop-test-calm2-x3.m4a'), bpm, -16.0, 24 if nbs else 36, nbs)
    info['aba'] = aba_test(fam)
    save_report(fam, 'calm2', info)
    return info


def do_win(fam, take):
    info = pf.make_win(os.path.join(TESTS, fam, take + '.mp3'), os.path.join(MUSIC, fam, 'win.m4a'))
    save_report(fam, 'win', info)
    return info


# Loops placed by hand on the comb beat grid (process_music_more.comb_grid + loop_search) where librosa's beat list
# wobbles: circus calm-1's oompah off-beats gave a 41 ms grid residual and a weaker seam (mel 0.81 vs 0.55 here).
OVERRIDE = {('circus-carnival', 'calm'): dict(bpm=112.0, first_beat=0.292, start_beat=14, beats=96)}


def loop(fam, seg, take, bpm, target, min_s):
    t, out = os.path.join(TESTS, fam), os.path.join(MUSIC, fam)
    src, dst, test = f'{t}/{take}.mp3', f'{out}/{seg}.m4a', f'{t}/processed/loop-test-{seg}-x3.m4a'
    o = OVERRIDE.get((fam, seg))
    if not o:
        return pf.make_loop(src, dst, test, bpm, target, min_s)
    per = 60 / o['bpm']
    info = pmm.make_loop(src, dst, test, o['first_beat'] + o['start_beat'] * per, o['beats'] * per, target)
    info.update(o, bars=o['beats'] // 4, bpm_used=o['bpm'], grid='comb (process_music_more)')
    return info


def do_family(fam):
    bpm, calm, calm2, tense, win = NEW[fam]
    t, out = os.path.join(TESTS, fam), os.path.join(MUSIC, fam)
    for d in (out, os.path.join(t, 'processed')):
        os.makedirs(d, exist_ok=True)
    report = {
        'calm': loop(fam, 'calm', calm, bpm, -16.0, 36),
        'calm2': loop(fam, 'calm2', calm2, bpm, -16.0, 36),
        'tense': loop(fam, 'tense', tense, bpm, -15.0, 28),
        'win': pf.make_win(f'{t}/{win}.mp3', f'{out}/win.m4a'),
    }
    report['calm2']['aba'] = aba_test(fam)
    save_report(fam, None, report)
    return report


def brief(r):
    keys = ('source', 'lufs', 'true_peak_dbtp', 'length_s', 'bars', 'bpm_measured', 'resample_ppm')
    return {k: r[k] for k in keys if k in r}


if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == 'analyze':
        fam, takes = args[0], args[1:]
        bpm = int(os.environ.get('BPM', FAMILY_A.get(fam, (0,))[0] or 100))
        asked = json.loads(os.environ.get('ASKED', '{}'))
        print(json.dumps(analyze(fam, takes, bpm, asked), indent=1, default=float))
    elif cmd == 'calm2':
        for fam in args or CALM2:
            r = do_calm2(fam)
            print(fam, json.dumps(dict(brief(r), aba=r['aba'])), flush=True)
    elif cmd == 'family':
        for fam in args or NEW:
            r = do_family(fam)
            print(fam, json.dumps({k: brief(v) for k, v in r.items()}), flush=True)
    elif cmd == 'win':
        print(json.dumps(do_win(args[0], args[1]), default=float))
