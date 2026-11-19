"""Builds the peek imagesets from Haylee's body v3 (2026-11-18): design/nutmeg/peek/regen/peek-body-v3.svg (514x173,
15 flat paths, her own composition: tail, vest, cream V-neck, star, shoulders and both paws). A PATH SPLIT only, every
path copied verbatim and in its original order (no shape edits):
  nutmeg-peek-paws  (IN FRONT of the card's edge): each paw + its dark top arc + its two finger lines (paths 5-8, 10-13)
  nutmeg-peek-back  (BEHIND the card): everything else: vest, neck shading, cream V, shoulders, star, tail
Each path's fill is checked, so a re-export with a different path order fails loudly instead of splitting wrong.

Usage: python3 tools/peek_v3_imagesets.py   (from anywhere)
Placement in the app: NutmegPeek in PretendThat/Nutmeg/NutmegCharacter.swift (bodyScale / bodyOffset).
Supersedes tools/peek_v2_imagesets.py and tools/split_peek_parts.py."""
import json, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "design/nutmeg/peek/regen/peek-body-v3.svg").read_text()
cat = root / "PretendThat/Resources/Assets.xcassets"

head = re.match(r'<svg[^>]*>', src).group(0)
if 'viewBox="0 0 514 173"' not in head:
    sys.exit("peek-body-v3.svg: expected the 514x173 canvas")
if re.search(r'<rect\b|<g\b', src) or re.search(r'#00C853', src, re.I):
    sys.exit("peek-body-v3.svg: unexpected background rect / group / green; re-export")
paths = re.findall(r'<path\b[^>]*/>', src)
expected = ["#65217A", "#A0582A", "#FEE5CD", "#A0582A", "#AF6131", "#843912", "#843912", "#843912",
            "#A0582A", "#AF6131", "#843912", "#843912", "#843912", "#FEC602", "#AF6131"]
fills = [re.search(r'fill="([^"]+)"', p).group(1).upper() for p in paths]
if fills != expected:
    sys.exit(f"peek-body-v3.svg: path fills changed ({fills}); check the split indices")

paws = {5, 6, 7, 8, 10, 11, 12, 13}   # 1-based: right paw, arc, 2 fingers; left paw, arc, 2 fingers
sets = {"nutmeg-peek-paws": [p for i, p in enumerate(paths, 1) if i in paws],
        "nutmeg-peek-back": [p for i, p in enumerate(paths, 1) if i not in paws]}
for name, ps in sets.items():
    d = cat / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    for old in d.glob("*.svg"):
        old.unlink()
    (d / f"{name}.svg").write_text(head + "\n" + "\n".join(ps) + "\n</svg>\n")
    (d / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True}}, indent=2) + "\n")
    print(name, len(ps), "paths")
