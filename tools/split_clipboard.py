#!/usr/bin/env python3
"""Round 8 (Haylee): the clipboard in front of the head. For each pose that holds the clipboard at her side, writes
design/export/nutmeg/nutmeg-<pose>-clipboard.svg: the body's own paths (unchanged, same order) clipped to the
clipboard's silhouette (the clipboard paths, plus the gripping paw where it reaches past the clipboard). Drawn above
the head (body → head → face → headset → clipboard layer), it shows exactly the body's pixels there, so the clipboard
and the paw over it sit in front of the chin. A layer split by clipPath only: the body SVG is not modified."""
import re, os
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "design", "export", "nutmeg")
# Path indexes (in document order) of the clipboard silhouette in each body SVG.
POSES = {
    "idle": [10, 15, 23, 24, 25, 28],            # board, lower edge, clip (3), highlight
    "point": [10, 16, 17, 21, 22, 23, 24, 25],   # board, lower edge, clip pieces, highlights
    "celebrate": [16, 17, 22, 25, 26, 27, 29, 30, 31, 32],   # raised board + the paw gripping its side
}
# Round 10 (Haylee): the front layer is the clipboard board + clip ONLY. The arm path that crosses the board (idle,
# point) is cut OUT of the layer with a second, nested clip (the canvas minus the arm, even-odd), so the arm is drawn
# only by the body, behind the head. The paw/fingers on the board are part of that arm path; they sit far below the
# chin, so the body draws them unchanged. Celebrate keeps its gripping paw (it is away from the head).
ARM = {"idle": [11], "point": [11]}
EL = re.compile(r'<(?:path|rect|circle|ellipse)\b[^>]*?/>', re.S)

def box(el):
    nums = [float(x) for x in re.findall(r'-?\d+\.?\d*', (re.search(r' d="([^"]*)"', el) or [None, ""])[1])]
    return (min(nums[0::2]), min(nums[1::2]), max(nums[0::2]), max(nums[1::2])) if nums else None

for pose, idx in POSES.items():
    svg = open(os.path.join(D, f"nutmeg-body-{pose}.svg")).read()
    els = [m.group(0) for m in EL.finditer(svg)]
    sil = [els[i] for i in idx]
    bs = [box(e) for e in sil]
    B = (min(b[0] for b in bs), min(b[1] for b in bs), max(b[2] for b in bs), max(b[3] for b in bs))
    hit = lambda b: b and b[0] <= B[2] and b[2] >= B[0] and b[1] <= B[3] and b[3] >= B[1]
    clip = "".join('<path d="%s"/>' % re.search(r' d="([^"]*)"', e).group(1) for e in sil)
    head = svg[:svg.index(">", svg.index("<svg")) + 1]
    body = "\n".join(e for e in els if hit(box(e)))
    W, H = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', head).groups()
    arms = "".join(re.search(r' d="([^"]*)"', els[i]).group(1) for i in ARM.get(pose, []))
    if arms:
        noarm = f'<clipPath id="na-{pose}"><path clip-rule="evenodd" fill-rule="evenodd" d="M0 0H{W}V{H}H0Z{arms}"/></clipPath>'
        out = (f'{head}\n<defs><clipPath id="cb-{pose}">{clip}</clipPath>{noarm}</defs>\n<g clip-path="url(#cb-{pose})">\n'
               f'<g clip-path="url(#na-{pose})">\n{body}\n</g>\n</g>\n</svg>\n')
    else:
        out = f'{head}\n<defs><clipPath id="cb-{pose}">{clip}</clipPath></defs>\n<g clip-path="url(#cb-{pose})">\n{body}\n</g>\n</svg>\n'
    open(os.path.join(D, f"nutmeg-{pose}-clipboard.svg"), "w").write(out)
    print(pose, "silhouette box", [round(v) for v in B], "paths kept", sum(1 for e in els if hit(box(e))), "of", len(els))
