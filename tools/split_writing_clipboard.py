#!/usr/bin/env python3
"""Round 12 (Haylee, 2026-11-14): the writing clipboard is SOLID and in front of the crayon.
Source: design/export/nutmeg/nutmeg-body-writing.before-r12.svg (the vectorized art, backed up once).
1. Notch repair (mechanical, authorized by Haylee: "It should just be solid"): the vectorizer cut the crayon tip out of
   the board's left edge. The board path (16) bulged left around the tip and the edge highlight was split in two pieces
   (28 below, 31 above) with a tip-shaped bite and a tip shadow (29). The edge is a straight line in the art (both
   pieces are collinear, slope -0.414), so: the board's left outline is bridged straight from (694.6, 785.1) to
   (777.3, 586.3); the two edge pieces become one strip with straight edges; the tip shadow (29) is dropped.
1c. A vest-purple strip under the crayon-outline seam of the vest (no hairline as the crayon rocks).
2. The red sliver at the board's right edge behind the holding paw (20, a crayon-red piece) is dropped.
3. Layer split: nutmeg-writing-clipboard.svg = the board, its edge strip, bottom edge, clip, highlights and the holding
   paw that grips it (in front of the board), same viewBox. Stack: body -> head -> crayon -> clipboard -> fingers, so the
   crayon tip tucks behind the board edge as it rocks. Plain paths, no clipPaths (Apple's renderer ignores even-odd).
Nothing else in the art changes."""
import os, re, shutil
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "design", "export", "nutmeg")
BODY, SRC = os.path.join(D, "nutmeg-body-writing.svg"), os.path.join(D, "nutmeg-body-writing.before-r12.svg")
if not os.path.exists(SRC): shutil.copy(BODY, SRC)
svg = open(SRC).read()
paths = list(re.finditer(r'<path\b[^>]*?/>', svg, re.S))
el = [m.group(0) for m in paths]

# 1a. Board: bridge the bulge around the tip with the straight edge line.
bulge = re.compile(r'(694\.609 785\.114)C685\.085 770\.089.*?742\.525 670\.166C753\.425 642\.504 765\.837 613\.833 (777\.271 586\.285)', re.S)
assert len(bulge.findall(el[16])) == 1, "board bulge not found"
el[16] = bulge.sub(r'\1L\2', el[16])
# 1b. One straight edge strip (left edge 777.3,586.3 -> 694.6,785.1; right edge 788.4,594.6 -> 730.7,733.4).
assert el[28].startswith('<path d="M733.828 690.302') and el[31].startswith('<path d="M777.271 586.285')
el[28] = ('<path d="M777.271 586.285C781.105 589.047 784.69 591.623 788.367 594.604L730.653 733.376L701.063 805.654'
          'C694.935 820.855 684.72 840.769 685.189 856.336C681.343 852.542 677.757 848.331 675.254 843.514'
          'C674.576 844.778 674.602 847.281 674.491 848.885C672.04 834.316 688.462 801.195 694.609 785.114'
          'L777.271 586.285Z" fill="#FECE50"/>')
assert 'fill="#FCAE27"' in el[29] and 'fill="#CB2423"' in el[20]
# 1c. Seam: the vest piece cut around the crayon (22) meets the vest (2) along the crayon's old outline; as the crayon
# rocks, that anti-aliased seam showed a faint brown hairline. A plain vest-purple strip under both closes it (it lies
# wholly inside the two vest pieces, so it is never seen itself).
SEAM = ('<path d="M718.5 633.5L722 631L735.5 643L745 668L752 682.5L748 686L740 671.5L731 646.5Z" fill="#55157C"/>')
el[2] = SEAM + "\n" + el[2]
drop = {29, 31, 20}   # tip shadow, upper edge piece (merged into 28), red sliver

def build(keep):
    out, pos = [], 0
    for i, m in enumerate(paths):
        if keep is None: out.append(svg[pos:m.start()])
        if i not in drop and (keep is None or i in keep): out.append(el[i] + ("\n" if keep is not None else ""))
        pos = m.end()
    if keep is None: out.append(svg[pos:]); return "".join(out)
    return svg[:paths[0].start()] + "".join(out) + "</svg>\n"

open(BODY, "w").write(build(None))
CLIP = [16, 17, 18, 19, 21, 23, 24, 25, 26, 27, 28, 30, 32, 33, 34]   # board, holding paw + marks, clip, edges, highlights
open(os.path.join(D, "nutmeg-writing-clipboard.svg"), "w").write(build(set(CLIP)))
print("ok")
