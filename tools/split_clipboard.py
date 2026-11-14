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
# Round 10 (Haylee): the front layer is the clipboard board + clip ONLY: the arm path that crosses the board (idle,
# point) must never draw over the head. Round 10b: the round-10 cut used an even-odd clip (canvas minus the arm), but
# Apple's SVG renderer ignores clip-rule, so on device the arm's top still drew over her chin (a brown bump under the
# mic). Now no even-odd anywhere: the layer is split by the HEAD ZONE, the head-base silhouette as placed for the pose
# (headOffset +12, headRotation) pushed down by a margin for the bob, nod and state tilts. Outside the zone the layer
# draws every body path (board, arm, paw, fingers), exactly as before. Inside the zone it draws only the paths painted
# after the arm and its marks (the clip pieces, highlights), so the clipboard's top still sits in front of the chin while
# the arm there is drawn only by the body, behind the head. Both zones are simple polygons (nonzero-safe).
ARM = {"idle": [11, 12, 13, 14], "point": [11, 12, 13, 14]}   # the arm path + its finger/shade marks
HEAD_ROT = {"point": 3}
HEAD_DY, MARGIN = 12, 12
# Bottom edge of nutmeg-head-base (lowest opaque canvas y per x, rasterized at 1x), x 340..860 step 10.
HEAD_BOTTOM = [678, 693, 710, 723, 734, 743, 752, 760, 767, 773, 779, 784, 788, 793, 796, 800, 803, 805, 808, 810, 812,
               813, 815, 816, 817, 817, 818, 818, 818, 818, 817, 817, 816, 815, 814, 812, 810, 809, 806, 804, 801, 798,
               795, 792, 788, 784, 780, 775, 769, 764, 758, 751, 743]

def head_curve(pose):
    """The head zone's lower edge for a pose: the head bottom rotated about the neck anchor, offset, plus the margin
    (12 px for the breathing follow and nod, growing 0.1 px per px from the anchor for the ±5° state tilts)."""
    import math
    r = math.radians(HEAD_ROT.get(pose, 0))
    pts = []
    for i, y in enumerate(HEAD_BOTTOM):
        x = 340 + 10 * i
        dx, dy = x - 600, y - 788
        pts.append((600 + dx * math.cos(r) - dy * math.sin(r),
                    788 + dx * math.sin(r) + dy * math.cos(r) + HEAD_DY + MARGIN + 0.1 * abs(x - 600)))
    return pts

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
    cut = ARM.get(pose)
    if cut:
        c = head_curve(pose)
        def zone(dy, below):
            """A simple polygon bounded by the head curve shifted by dy: the canvas below it, or the head zone above it."""
            line = " ".join("L%.1f %.1f" % (x, y + dy) for x, y in c)
            x0, y0 = c[0][0], c[0][1] + dy
            return f'M0 0H{x0:.1f}V{y0:.1f}{line}V0H{W}V{H}H0Z' if below else f'M{x0:.1f} 0V{y0:.1f}{line}V0Z'
        # Apple's renderer clips each path on its own, so a shared anti-aliased edge would let the board under the arm
        # bleed through as a light hairline. The zones overlap by 3 px instead: the arm is drawn again 3 px higher (over
        # the board's soft edge) and the head-zone pieces reach 3 px lower (over the soft edge of everything else).
        arm = "\n".join(els[i] for i in cut)
        late = "\n".join(e for i, e in enumerate(els) if i > max(cut) and hit(box(e)))
        # Paths painted before the board (vest, legs) are hidden under it anyway; leaving them out keeps them from
        # bleeding through the soft edge of the lower zone.
        body = "\n".join(e for i, e in enumerate(els) if i >= min(idx) and hit(box(e)))
        out = (f'{head}\n<defs><clipPath id="cb-{pose}">{clip}</clipPath>'
               f'<clipPath id="lo-{pose}"><path d="{zone(0, True)}"/></clipPath>'
               f'<clipPath id="la-{pose}"><path d="{zone(-3, True)}"/></clipPath>'
               f'<clipPath id="hz-{pose}"><path d="{zone(3, False)}"/></clipPath></defs>\n<g clip-path="url(#cb-{pose})">\n'
               f'<g clip-path="url(#lo-{pose})">\n{body}\n</g>\n<g clip-path="url(#la-{pose})">\n{arm}\n</g>\n'
               f'<g clip-path="url(#hz-{pose})">\n{late}\n</g>\n</g>\n</svg>\n')
    else:
        out = f'{head}\n<defs><clipPath id="cb-{pose}">{clip}</clipPath></defs>\n<g clip-path="url(#cb-{pose})">\n{body}\n</g>\n</svg>\n'
    open(os.path.join(D, f"nutmeg-{pose}-clipboard.svg"), "w").write(out)
    print(pose, "silhouette box", [round(v) for v in B], "paths kept", sum(1 for e in els if hit(box(e))), "of", len(els))
