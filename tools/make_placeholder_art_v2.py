#!/usr/bin/env python3
"""Placeholder art added for the voice redesign (D6, rest pose, stage props). Reuses the helpers in
make_placeholder_art.py WITHOUT rewriting the existing layers. Haylee's art replaces these under the same names."""
import os
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "make_placeholder_art.py")).read()
exec(src[:src.index("os.makedirs(ROOT")])   # helpers, palette and write() only

new_bodies = {
    # Rest pose: arms relaxed at her sides, clipboard tucked under her left arm.
    "nutmeg-body-idle": torso() + feet() + arm(664, 720, 700, 880) + clipboard(250, 740, 12),
    # Coloring: clipboard held in front, other hand drawing with a crayon.
    "nutmeg-body-coloring": torso() + feet()
        + f'<g transform="rotate(-8 512 820)"><rect x="392" y="700" width="240" height="250" rx="22" fill="{YELLOW}" {S}/>'
          f'<rect x="452" y="680" width="120" height="44" rx="14" fill="{CORAL}" {S}/>'
          f'<rect x="418" y="740" width="188" height="186" rx="10" fill="{WHITE}" {S}/></g>'
        + arm(364, 730, 420, 880) + arm(660, 730, 560, 800, hand=False)
        + f'<g transform="rotate(35 560 800)"><rect x="540" y="730" width="40" height="120" rx="8" fill="{CORAL}" {S}/></g>'
        + f'<circle cx="560" cy="800" r="38" fill="{FUR}" {S}/>',
}
clip = {
    "nutmeg-clipboard-back": f'<rect x="212" y="140" width="600" height="720" rx="56" fill="{YELLOW}" {S}/>'
        f'<rect x="372" y="90" width="280" height="110" rx="34" fill="{CORAL}" {S}/>' + star(512, 560, 120, CORAL),
    "nutmeg-clipboard-front": f'<rect x="212" y="140" width="600" height="720" rx="56" fill="{YELLOW}" {S}/>'
        f'<rect x="246" y="200" width="532" height="630" rx="20" fill="{WHITE}" {S}/>'
        f'<rect x="372" y="90" width="280" height="110" rx="34" fill="{CORAL}" {S}/>',
    # Head peeking in from the left edge of the clipboard (head canvas pieces, rotated and shifted).
    "nutmeg-peek": f'<g transform="translate(-300 0) rotate(20 512 560)">' + head_parts["nutmeg-ears-perked"]
        + head_parts["nutmeg-head-base"] + faces["nutmeg-face-happy"] + mouths["nutmeg-mouth-small"] + '</g>',
}
stage = {
    "stage-curtain-left": f'<path d="M0 0 H520 C470 300 360 640 420 1024 H0 Z" fill="{CORAL}" {S}/>'
        f'<path d="M150 0 C170 380 120 700 170 1024 M320 0 C330 360 260 700 300 1024" fill="none" stroke="#D9443A" stroke-width="22"/>',
    "stage-curtain-right": f'<path d="M1024 0 H504 C554 300 664 640 604 1024 H1024 Z" fill="{CORAL}" {S}/>'
        f'<path d="M874 0 C854 380 904 700 854 1024 M704 0 C694 360 764 700 724 1024" fill="none" stroke="#D9443A" stroke-width="22"/>',
    "stage-valance": f'<path d="M0 300 H1024 V560 ' + " ".join(f"Q{1024 - i * 128 - 64} 700 {1024 - (i + 1) * 128} 560" for i in range(8)) + f' Z" fill="{CORAL}" {S}/>'
        f'<rect x="0" y="300" width="1024" height="60" fill="{YELLOW}" {S}/>',
    "stage-lamp": f'<rect x="452" y="160" width="120" height="160" rx="20" fill="{PURPLE}" {S}/>'
        f'<path d="M352 320 H672 L740 620 H284 Z" fill="{PURPLE}" {S}/><ellipse cx="512" cy="620" rx="228" ry="50" fill="{YELLOW}" {S}/>',
    "stage-star": star(512, 512, 380),
    "stage-sparkle": f'<path d="M512 120 Q560 464 904 512 Q560 560 512 904 Q464 560 120 512 Q464 464 512 120 Z" fill="{LIME}" {S}/>',
    "stage-ticket": props["prop-ticket"],
    "stage-bulbs": f'<path d="M40 300 Q512 560 984 300" fill="none" stroke="{INK}" stroke-width="14"/>'
        + "".join(f'<circle cx="{x}" cy="{300 + 260 * (1 - ((x - 512) / 472) ** 2) * 0.5 + 40:.0f}" r="44" fill="{YELLOW}" {S}/>' for x in range(120, 1000, 160)),
    "stage-sandbag": f'<path d="M512 80 V420" stroke="{INK}" stroke-width="14"/><path d="M380 420 Q512 380 644 420 L700 860 Q512 930 324 860 Z" fill="#C9A26B" {S}/>',
    "stage-crown": f'<path d="M180 720 L220 340 L380 540 L512 280 L644 540 L804 340 L844 720 Z" fill="{YELLOW}" {S}/><rect x="180" y="700" width="664" height="90" rx="20" fill="{YELLOW}" {S}/>',
    "stage-scroll": f'<rect x="240" y="200" width="544" height="624" rx="20" fill="{CREAM}" {S}/>'
        f'<rect x="200" y="160" width="624" height="90" rx="45" fill="#E8C79A" {S}/><rect x="200" y="774" width="624" height="90" rx="45" fill="#E8C79A" {S}/>',
}
for n, b in {**new_bodies, **clip, **stage}.items(): write(n, b)
# Clipboards fill their own 4:5 canvas (viewBox cropped to the board), so content can sit on the paper.
for n in ["nutmeg-clipboard-back", "nutmeg-clipboard-front"]:
    f = os.path.join(ROOT, f"{n}.imageset", f"{n}.svg")
    txt = open(f).read(); open(f, "w").write(txt.replace('width="1024" height="1024" viewBox="0 0 1024 1024"', 'width="640" height="800" viewBox="192 80 640 800"'))
print("ok", len(new_bodies) + len(clip) + len(stage), "new layers")
