"""Builds the peek imagesets from Haylee's regenerated art (2026-11-18, v2): design/nutmeg/peek/regen/peek-body-v2.svg
(headless body, forearms cut flat, tail) -> nutmeg-peek-back, and peek-paws-v2.svg (two paws) -> nutmeg-peek-paws.
Both share one 1774x887 canvas. The SVGs are copied VERBATIM (no shape edits). The script refuses an export that still
carries the green #00C853 background (or any full-canvas background rectangle): remove it in the export, don't patch.

Usage: python3 tools/peek_v2_imagesets.py   (from the repo root)
Placement in the app (paw offset, card edge, head fit) lives in NutmegPeek in PretendThat/Nutmeg/NutmegCharacter.swift.
Supersedes tools/split_peek_parts.py (the v1 logo-frame split)."""
import json, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
src = root / "design/nutmeg/peek/regen"
cat = root / "PretendThat/Resources/Assets.xcassets"
sets = {"nutmeg-peek-back": "peek-body-v2.svg", "nutmeg-peek-paws": "peek-paws-v2.svg"}

for name, file in sets.items():
    svg = (src / file).read_text()
    if not re.search(r'<svg[^>]*viewBox="0 0 1774 887"', svg):
        sys.exit(f"{file}: expected the shared 1774x887 canvas")
    if re.search(r'#00C853', svg, re.I) or re.search(r'<rect\b', svg):
        sys.exit(f"{file}: a green / background rectangle is still in the export; re-export without it")
    d = cat / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    for old in d.glob("*.svg"):
        old.unlink()
    (d / f"{name}.svg").write_text(svg)
    (d / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True}}, indent=2) + "\n")
    print(name, "<-", file, len(re.findall(r"<path", svg)), "paths")
