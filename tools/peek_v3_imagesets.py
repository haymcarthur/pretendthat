"""Builds the peek imagesets from Haylee's headless peek body (design/nutmeg/peek/regen/peek-body-v4.svg; v3 had the same
layout, v4 redrew the paws: 514x173, 15 flat paths: tail, vest, cream V-neck, star, shoulders and both paws). A PATH
SPLIT only: every path copied verbatim, in its original stacking order (no shape edits):
  nutmeg-peek-paws  (IN FRONT of the card's edge): each paw shape + its dark top arc + its finger lines
  nutmeg-peek-back  (BEHIND the card): everything else: vest, neck shading, cream V, shoulders, star, tail

The paws are found by GEOMETRY, not position (v4 reordered the paths):
  paw shape = a #AF6131 path that reaches the canvas bottom (bbox bottom >= 165) and isn't the tail (bbox left > 100)
  paw marks = #843912 paths whose bbox centre lies inside a paw shape's bbox x-range (its arc and finger lines)
The script checks it finds exactly 2 paws with 3 marks each, and that the split doesn't reorder anything that overlaps.

Usage: python3 tools/peek_v3_imagesets.py [svg]   (default: the v4 file)
Placement in the app: NutmegPeek in PretendThat/Nutmeg/NutmegCharacter.swift (bodyScale / bodyOffset)."""
import json, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
svg = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root / "design/nutmeg/peek/regen/peek-body-v4.svg"
src = svg.read_text()
cat = root / "PretendThat/Resources/Assets.xcassets"

head = re.match(r'<svg[^>]*>', src).group(0)
if 'viewBox="0 0 514 173"' not in head:
    sys.exit(f"{svg.name}: expected the 514x173 canvas")
if re.search(r'<rect\b|<g\b', src) or re.search(r'#00C853', src, re.I):
    sys.exit(f"{svg.name}: unexpected background rect / group / green; re-export")
paths = re.findall(r'<path\b[^>]*/>', src)


def info(p):
    d = re.search(r'\bd="([^"]+)"', p).group(1)
    if re.search(r'[a-y]', d.replace("e", "")):   # relative commands would break the bbox read
        sys.exit(f"{svg.name}: relative path commands; re-export with absolute ones")
    nums = [float(n) for n in re.findall(r'-?\d*\.?\d+(?:e-?\d+)?', d)]
    xs, ys = nums[0::2], nums[1::2]
    fill = re.search(r'fill="([^"]+)"', p).group(1).upper()
    return fill, (min(xs), min(ys), max(xs), max(ys))


infos = [info(p) for p in paths]
paw_shapes = [i for i, (f, b) in enumerate(infos) if f == "#AF6131" and b[3] >= 165 and b[0] > 100]
if len(paw_shapes) != 2:
    sys.exit(f"{svg.name}: expected 2 paw shapes, found {len(paw_shapes)}")
front = set(paw_shapes)
for s in paw_shapes:
    lo, hi = infos[s][1][0], infos[s][1][2]
    marks = [i for i, (f, b) in enumerate(infos) if f == "#843912" and lo <= (b[0] + b[2]) / 2 <= hi]
    if len(marks) != 3:
        sys.exit(f"{svg.name}: expected an arc + 2 finger lines on the paw at x {lo:.0f}..{hi:.0f}, found {len(marks)}")
    front.update(marks)


def overlaps(a, b):
    return not (a[2] < b[0] or b[2] < a[0] or a[3] < b[1] or b[3] < a[1])


# Moving a front path above a back path that came after it in the file must not change what's on top.
for i in front:
    for j in range(i + 1, len(paths)):
        if j not in front and overlaps(infos[i][1], infos[j][1]):
            sys.exit(f"{svg.name}: path {j + 1} sits over paw path {i + 1}; the split would change the stacking")

sets = {"nutmeg-peek-paws": [p for i, p in enumerate(paths) if i in front],
        "nutmeg-peek-back": [p for i, p in enumerate(paths) if i not in front]}
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
    print(name, len(ps), "paths", sorted(i + 1 for i in (front if name.endswith("paws") else set(range(len(paths))) - front)))
