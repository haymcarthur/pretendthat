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

def split_face(svg):
    head, body_end = svg[:svg.index(">") + 1], "</svg>"
    els = re.findall(r'<(?:path|ellipse|circle|rect)\b[^>]*?/>', svg, re.S)
    is_mouth = lambda e: (re.search(r'fill="([^"]+)"', e) or [None, ""])[1].upper() in MOUTH_FILLS
    eyes = head + "\n" + "\n".join(e for e in els if not is_mouth(e)) + "\n" + body_end + "\n"
    mouth = head + "\n" + "\n".join(e for e in els if is_mouth(e)) + "\n" + body_end + "\n"
    return eyes, mouth

n = 0
for f in sorted(glob.glob(os.path.join(SRC, "nutmeg", "*.svg"))):
    name = os.path.basename(f)[:-4]; svg = open(f).read()
    if name.startswith("nutmeg-face-"):
        eyes, mouth = split_face(svg)
        put(name, eyes); put(name + "-mouth", mouth); n += 2
    else:
        put(name, svg); n += 1
for f in sorted(glob.glob(os.path.join(SRC, "stage", "*.svg"))):
    name = os.path.basename(f)[:-4]
    if name == "stage-beam": continue
    put(name, open(f).read()); n += 1
for f in sorted(glob.glob(os.path.join(SRC, "actions", "*.svg"))):   # checklist action pictures (action-<id>)
    put(os.path.basename(f)[:-4], open(f).read()); n += 1
for f in sorted(glob.glob(os.path.join(SRC, "props", "*.svg"))):
    put(os.path.basename(f)[:-4], open(f).read()); n += 1
# Placeholder layers the new art doesn't use (ears/tail are drawn into head-base and the bodies).
for old in ["nutmeg-tail", "nutmeg-ears-normal", "nutmeg-ears-perked", "nutmeg-peek"]:
    d = os.path.join(DST, f"{old}.imageset")
    if os.path.isdir(d): shutil.rmtree(d)
print("imported", n)
