#!/usr/bin/env python3
"""Imports Haylee's exported art (design/export) into Assets.xcassets as vector imagesets (Preserve Vector Data,
single scale). Faces are split into -eyes (the face asset) and -mouth (its default mouth) by fill color, so the
amplitude-driven mouth can replace the face's mouth while Nutmeg talks. stage-beam (a soft glow) is skipped."""
import json, os, re, shutil, glob
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "design", "export")
DST = os.path.join(HERE, "..", "PretendThat", "Resources", "Assets.xcassets")
MOUTH_FILLS = {"#761A2E", "#EC5C7C"}

def put(name, svg_text):
    d = os.path.join(DST, f"{name}.imageset")
    if os.path.isdir(d): shutil.rmtree(d)   # replaces placeholders (SVG or PNG)
    os.makedirs(d)
    open(os.path.join(d, f"{name}.svg"), "w").write(svg_text)
    json.dump({"images": [{"filename": f"{name}.svg", "idiom": "universal"}], "info": {"author": "xcode", "version": 1},
               "properties": {"preserves-vector-representation": True}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)

HIDDEN = re.compile(r'display\s*[:=]\s*"?\s*none|visibility\s*[:=]\s*"?\s*hidden|\bid="eyes-old"', re.I)

def strip_hidden(svg):
    """Drops hidden content (display:none, visibility:hidden, a group id'd eyes-old) so Figma's hidden layers never render."""
    tags = list(re.finditer(r'<(/?)([a-zA-Z]+)\b[^>]*?(/?)>', svg))
    skip_until, depth, res, pos = None, 0, [], 0
    for t in tags:
        closing, selfclose, tag = t.group(1) == "/", t.group(3) == "/" or t.group(0).endswith("/>"), t.group(0)
        if skip_until is None:
            if not closing and HIDDEN.search(tag):
                res.append(svg[pos:t.start()])
                if selfclose: pos = t.end(); continue
                skip_until, depth = t.group(2), 1; continue
        else:
            if t.group(2) == skip_until and not selfclose: depth += -1 if closing else 1
            if depth == 0: skip_until, pos = None, t.end()
    res.append(svg[pos:] if skip_until is None else "")
    return "".join(res)

def split_face(svg):
    head, body_end = svg[:svg.index(">") + 1], "</svg>"
    els = re.findall(r'<(?:path|ellipse|circle|rect)\b[^>]*?/>', svg, re.S)
    is_mouth = lambda e: (re.search(r'fill="([^"]+)"', e) or [None, ""])[1].upper() in MOUTH_FILLS
    eyes = head + "\n" + "\n".join(e for e in els if not is_mouth(e)) + "\n" + body_end + "\n"
    mouth = head + "\n" + "\n".join(e for e in els if is_mouth(e)) + "\n" + body_end + "\n"
    return eyes, mouth

def strip_tail(svg):
    """A tail-less body (start screen: she stands in the chest). The tail is the only shape reaching canvas x < 200;
    shapes drawn wholly inside its box (the tail tip) go with it."""
    paths = list(re.finditer(r'<path\b[^>]*?/>', svg, re.S))
    def box(m):
        nums = [float(x) for x in re.findall(r'-?\d+\.?\d*', (re.search(r' d="([^"]*)"', m.group(0)) or [None, ""])[1])]
        return (min(nums[0::2]), min(nums[1::2]), max(nums[0::2]), max(nums[1::2])) if nums else None
    tails = [box(m) for m in paths if box(m) and box(m)[0] < 200]
    if not tails: return svg
    tb = (min(b[0] for b in tails), min(b[1] for b in tails), max(b[2] for b in tails), max(b[3] for b in tails))
    inside = lambda b: b and b[0] >= tb[0] and b[1] >= tb[1] and b[2] <= tb[2] and b[3] <= tb[3]
    return re.sub(r'<path\b[^>]*?/>', lambda m: "" if inside(box(m)) else m.group(0), svg, flags=re.S)

def path_box(el):
    nums = [float(x) for x in re.findall(r'-?\d+\.?\d*', (re.search(r' d="([^"]*)"', el) or [None, ""])[1])]
    return (min(nums[0::2]), min(nums[1::2]), max(nums[0::2]), max(nums[1::2])) if nums else None

def split_box(svg, box):
    """(svg without, svg with only) the paths drawn wholly inside box (x0, y0, x1, y1)."""
    inside = lambda el: (b := path_box(el)) and b[0] >= box[0] and b[1] >= box[1] and b[2] <= box[2] and b[3] <= box[3]
    head = svg[:svg.index(">") + 1]
    only = head + "\n" + "\n".join(m.group(0) for m in re.finditer(r'<path\b[^>]*?/>', svg, re.S) if inside(m.group(0))) + "\n</svg>\n"
    return re.sub(r'<path\b[^>]*?/>', lambda m: "" if inside(m.group(0)) else m.group(0), svg, flags=re.S), only

# One clasp per chest state (Haylee): the body's rim clasp becomes its own layer (shown only while the lid is open,
# since the closed lid draws its own), and the open lid's copy is dropped.
CHEST_CLASP = (270, 365, 380, 440)
OPEN_LID_CLASP = (270, 10, 380, 106)

n = 0
for f in sorted(glob.glob(os.path.join(SRC, "nutmeg", "*.svg"))):
    name = os.path.basename(f)[:-4]; svg = strip_hidden(open(f).read())
    if name.startswith("nutmeg-face-"):
        eyes, mouth = split_face(svg)
        put(name, eyes); put(name + "-mouth", mouth); n += 2
    else:
        put(name, svg); n += 1
        if name in ("nutmeg-body-idle", "nutmeg-body-wave"):   # the start screen's poses
            put(name + "-notail", strip_tail(svg)); n += 1
for f in sorted(glob.glob(os.path.join(SRC, "stage", "*.svg"))):
    name = os.path.basename(f)[:-4]
    if name == "stage-beam": continue
    put(name, open(f).read()); n += 1
for f in sorted(glob.glob(os.path.join(SRC, "actions", "*.svg"))):   # checklist action pictures (action-<id>)
    put(os.path.basename(f)[:-4], strip_hidden(open(f).read())); n += 1
for f in sorted(glob.glob(os.path.join(SRC, "props", "*.svg"))):
    put(os.path.basename(f)[:-4], open(f).read()); n += 1
for f in sorted(glob.glob(os.path.join(SRC, "startscreen", "*.svg"))):   # start screen: chest, lids, toys, curtains
    name, svg = os.path.basename(f)[:-4], strip_hidden(open(f).read())
    if name == "chest-body":
        svg, clasp = split_box(svg, CHEST_CLASP); put("chest-clasp", clasp); n += 1
    elif name == "chest-lid-open":
        svg, _ = split_box(svg, OPEN_LID_CLASP)
    put(name, svg); n += 1
for f in sorted(glob.glob(os.path.join(SRC, "logo", "*.svg"))):   # logo: full + per-letter parts (logo-layout.json)
    put(os.path.basename(f)[:-4], open(f).read()); n += 1
# Placeholder layers the new art doesn't use (ears/tail are drawn into head-base and the bodies).
for old in ["nutmeg-tail", "nutmeg-ears-normal", "nutmeg-ears-perked", "nutmeg-peek"]:
    d = os.path.join(DST, f"{old}.imageset")
    if os.path.isdir(d): shutil.rmtree(d)
print("imported", n)
