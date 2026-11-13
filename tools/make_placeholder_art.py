#!/usr/bin/env python3
"""Placeholder Nutmeg art (flat vector SVGs) following the head-on-body contract (spec §7).
Two canvases, both 1024x1024, transparent:
  BODY canvas: nutmeg-tail + nutmeg-body-<pose> (headless). Each pose has a neck anchor (see NutmegPose.swift).
  HEAD canvas: nutmeg-ears-*, nutmeg-head-base, nutmeg-face-*, nutmeg-mouth-* stack with no offsets.
Haylee's Figma export replaces these files under the same names."""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "PretendThat", "Resources", "Assets.xcassets")
FUR, FUR_DARK, EAR, INK, WHITE, CREAM = "#B9774A", "#8E5634", "#FF8A78", "#24123F", "#FFFFFF", "#F6DDBF"
PURPLE, YELLOW, CORAL, LIME, IRIS = "#3A1F6B", "#FFC83D", "#FF5A4E", "#9BDB3F", "#4A2A18"
S = f'stroke="{INK}" stroke-width="14" stroke-linejoin="round" stroke-linecap="round"'
LINE = f'stroke="{INK}" stroke-linecap="round" fill="none"'

def star(cx, cy, r, fill=YELLOW):
    import math
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * 0.45
        a = -math.pi / 2 + i * math.pi / 5
        pts.append(f"{cx + rr * math.cos(a):.0f},{cy + rr * math.sin(a):.0f}")
    return f'<polygon points="{" ".join(pts)}" fill="{fill}" {S}/>'

# ---------- BODY canvas (neck around y=640) ----------
def torso(cy=800):
    return (f'<ellipse cx="512" cy="{cy}" rx="170" ry="165" fill="{FUR}" {S}/>'
            f'<ellipse cx="512" cy="{cy + 30}" rx="95" ry="105" fill="{CREAM}"/>'
            f'<path d="M352 {cy - 70} Q385 {cy - 140} 455 {cy - 150} L470 {cy + 110} Q400 {cy + 140} 355 {cy + 80} Z" fill="{PURPLE}" {S}/>'
            f'<path d="M672 {cy - 70} Q639 {cy - 140} 569 {cy - 150} L554 {cy + 110} Q624 {cy + 140} 669 {cy + 80} Z" fill="{PURPLE}" {S}/>'
            + star(612, cy - 50, 26))
def feet(y=965):
    return (f'<ellipse cx="440" cy="{y}" rx="70" ry="30" fill="{FUR_DARK}" {S}/>'
            f'<ellipse cx="584" cy="{y}" rx="70" ry="30" fill="{FUR_DARK}" {S}/>')
def clipboard(x=270, y=720, rot=0):
    return (f'<g transform="rotate({rot} {x + 90} {y + 120})"><rect x="{x}" y="{y}" width="180" height="230" rx="22" fill="{YELLOW}" {S}/>'
            f'<rect x="{x + 45}" y="{y - 20}" width="90" height="42" rx="14" fill="{CORAL}" {S}/>'
            + "".join(f'<line x1="{x + 30}" y1="{y + 70 + i * 45}" x2="{x + 150 - i * 15}" y2="{y + 70 + i * 45}" stroke="{INK}" stroke-width="12" stroke-linecap="round"/>' for i in range(3))
            + f'</g><circle cx="{x + 175}" cy="{y + 110}" r="40" fill="{FUR}" {S}/>')
def arm(x1, y1, x2, y2, hand=True):
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{INK}" stroke-width="58" stroke-linecap="round"/>'
            f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{FUR}" stroke-width="32" stroke-linecap="round"/>'
            + (f'<circle cx="{x2}" cy="{y2}" r="38" fill="{FUR}" {S}/>' if hand else ""))

bodies = {
    "nutmeg-body-wave": torso() + feet() + arm(660, 720, 800, 560) + clipboard(),
    "nutmeg-body-point": torso() + feet() + arm(660, 730, 880, 700) + clipboard(),
    "nutmeg-body-celebrate": torso() + feet() + arm(660, 720, 790, 520) + arm(364, 720, 234, 520) + star(800, 470, 40),
    "nutmeg-body-sit": torso(860) + (f'<ellipse cx="400" cy="985" rx="95" ry="34" fill="{FUR_DARK}" {S}/>'
                                      f'<ellipse cx="624" cy="985" rx="95" ry="34" fill="{FUR_DARK}" {S}/>') + clipboard(380, 800, -20),
}
tail = f'<path d="M640 900 C820 920 900 820 860 720 C830 650 760 680 790 730" fill="none" stroke="{FUR_DARK}" stroke-width="34" stroke-linecap="round"/>'

# ---------- HEAD canvas (head center 512,560; neck point 512,820) ----------
def ears(lx, ly, rx, ry, r, rot=0):
    return (f'<g transform="rotate({-rot} {lx} {ly})"><ellipse cx="{lx}" cy="{ly}" rx="{r}" ry="{r}" fill="{FUR}" {S}/><ellipse cx="{lx}" cy="{ly}" rx="{r * 0.66:.0f}" ry="{r * 0.66:.0f}" fill="{EAR}"/></g>'
            f'<g transform="rotate({rot} {rx} {ry})"><ellipse cx="{rx}" cy="{ry}" rx="{r}" ry="{r}" fill="{FUR}" {S}/><ellipse cx="{rx}" cy="{ry}" rx="{r * 0.66:.0f}" ry="{r * 0.66:.0f}" fill="{EAR}"/></g>')
head_parts = {
    "nutmeg-ears-normal": ears(240, 300, 784, 300, 175),
    "nutmeg-ears-perked": ears(275, 225, 749, 225, 185),
    "nutmeg-ears-flop": f'<g transform="rotate(-35 210 420)"><ellipse cx="210" cy="420" rx="185" ry="140" fill="{FUR}" {S}/><ellipse cx="210" cy="420" rx="120" ry="85" fill="{EAR}"/></g>'
                        f'<g transform="rotate(35 814 420)"><ellipse cx="814" cy="420" rx="185" ry="140" fill="{FUR}" {S}/><ellipse cx="814" cy="420" rx="120" ry="85" fill="{EAR}"/></g>',
    "nutmeg-head-base": (f'<path d="M222 560 C222 300 802 300 802 560" fill="none" stroke="{YELLOW}" stroke-width="34" stroke-linecap="round"/>'
                         f'<ellipse cx="512" cy="570" rx="300" ry="250" fill="{FUR}" {S}/>'
                         f'<ellipse cx="512" cy="660" rx="165" ry="115" fill="{CREAM}"/>'
                         f'<path d="M470 340 Q500 300 520 345 Q545 300 560 350" fill="none" stroke="{FUR_DARK}" stroke-width="14" stroke-linecap="round"/>'
                         f'<ellipse cx="512" cy="618" rx="32" ry="24" fill="{EAR}" {S}/>'
                         f'<line x1="650" y1="640" x2="780" y2="618" {LINE} stroke-width="8"/><line x1="650" y1="662" x2="785" y2="672" {LINE} stroke-width="8"/>'
                         f'<line x1="374" y1="640" x2="244" y2="618" {LINE} stroke-width="8"/><line x1="374" y1="662" x2="239" y2="672" {LINE} stroke-width="8"/>'
                         f'<ellipse cx="370" cy="640" rx="36" ry="22" fill="{EAR}" opacity="0.6"/><ellipse cx="654" cy="640" rx="36" ry="22" fill="{EAR}" opacity="0.6"/>'
                         f'<rect x="196" y="500" width="78" height="140" rx="34" fill="{YELLOW}" {S}/><rect x="750" y="500" width="78" height="140" rx="34" fill="{YELLOW}" {S}/>'
                         f'<path d="M235 630 C250 720 350 740 420 725" fill="none" stroke="{YELLOW}" stroke-width="18" stroke-linecap="round"/><circle cx="430" cy="722" r="24" fill="{YELLOW}" {S}/>'
                         f'<path d="M370 330 L440 290 L445 380 Z M370 330 L300 290 L295 380 Z" fill="{CORAL}" {S}/><circle cx="370" cy="333" r="22" fill="{CORAL}" {S}/>'),
}
EL, ER, EY = 420, 604, 540
def eye(cx, cy, dx=0, dy=0, rx=56, ry=66, pupil=36):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{WHITE}" {S}/>'
            f'<circle cx="{cx + 6 + dx}" cy="{cy + 10 + dy}" r="{pupil}" fill="{IRIS}"/>'
            f'<circle cx="{cx + 18 + dx}" cy="{cy - 4 + dy}" r="12" fill="{WHITE}"/><circle cx="{cx - 4 + dx}" cy="{cy + 26 + dy}" r="6" fill="{WHITE}"/>')
def brows(l, r):
    return f'<path d="{l}" {LINE} stroke-width="11"/><path d="{r}" {LINE} stroke-width="11"/>'
happy_brows = brows("M368 455 Q415 430 462 448", "M562 448 Q609 430 656 455")
faces = {
    "nutmeg-face-happy": eye(EL, EY) + eye(ER, EY) + happy_brows,
    "nutmeg-face-talking": eye(EL, EY, ry=70) + eye(ER, EY, ry=70) + brows("M368 448 Q415 420 462 440", "M562 440 Q609 420 656 448"),
    "nutmeg-face-listening": eye(EL, EY, dx=12) + eye(ER, EY, dx=12) + brows("M368 440 Q415 410 462 430", "M562 430 Q609 410 656 440"),
    "nutmeg-face-thinking": eye(EL, EY, dx=8, dy=-26) + eye(ER, EY, dx=8, dy=-26) + brows("M368 455 Q415 445 462 452", "M562 430 Q609 400 656 425"),
    "nutmeg-face-ooh": eye(EL, EY, rx=62, ry=74, pupil=40) + eye(ER, EY, rx=62, ry=74, pupil=40) + brows("M362 432 Q415 400 466 425", "M558 425 Q609 400 662 432"),
    "nutmeg-face-yay": f'<path d="M370 560 Q420 495 470 560" {LINE} stroke-width="16"/><path d="M554 560 Q604 495 654 560" {LINE} stroke-width="16"/>' + happy_brows,
    "nutmeg-face-oops": eye(EL, EY, dy=6) + eye(ER, EY, dy=6) + brows("M370 440 Q415 455 462 470", "M562 470 Q609 455 654 440"),
    "nutmeg-face-nap": f'<path d="M372 545 Q420 580 468 545" {LINE} stroke-width="16"/><path d="M556 545 Q604 580 652 545" {LINE} stroke-width="16"/>',
}
MY = 700
mouths = {
    "nutmeg-mouth-closed": f'<path d="M466 {MY} Q512 {MY + 34} 558 {MY}" {LINE} stroke-width="12"/>',
    "nutmeg-mouth-small": f'<path d="M474 {MY - 6} Q512 {MY + 46} 550 {MY - 6} Z" fill="{INK}" {S}/>',
    "nutmeg-mouth-open": f'<path d="M460 {MY - 10} Q512 {MY + 80} 564 {MY - 10} Z" fill="{INK}" {S}/><ellipse cx="512" cy="{MY + 30}" rx="26" ry="12" fill="{CORAL}"/>',
    "nutmeg-mouth-wide": f'<path d="M444 {MY - 16} Q512 {MY + 110} 580 {MY - 16} Z" fill="{INK}" {S}/><ellipse cx="512" cy="{MY + 48}" rx="38" ry="16" fill="{CORAL}"/>',
    "nutmeg-mouth-ooh": f'<ellipse cx="512" cy="{MY + 14}" rx="26" ry="32" fill="{INK}" {S}/>',
}

props = {
 "prop-curtain-corner": f'<path d="M0 0 H1024 V120 C800 160 520 120 300 220 C180 280 120 520 160 1024 H0 Z" fill="{CORAL}"/>'
                f'<path d="M120 0 C140 400 100 700 160 1024" fill="none" stroke="#D9443A" stroke-width="24"/><path d="M0 120 H1024" stroke="{YELLOW}" stroke-width="30"/>',
 "prop-spotlight": f'<path d="M512 80 L860 1000 H164 Z" fill="{YELLOW}" opacity="0.35"/><rect x="432" y="40" width="160" height="110" rx="30" fill="{PURPLE}" {S}/>',
 "prop-ticket": f'<path d="M150 330 H874 V450 A62 62 0 0 0 874 574 V694 H150 V574 A62 62 0 0 0 150 450 Z" fill="{YELLOW}" {S}/>'
                f'<line x1="680" y1="350" x2="680" y2="674" stroke="{INK}" stroke-width="10" stroke-dasharray="24 18"/><path d="M300 470 L400 512 L300 554" fill="none" stroke="{CORAL}" stroke-width="22" stroke-linecap="round"/>',
 "prop-star": star(512, 512, 390),
}

def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>\n'
def write(name, body):
    d = os.path.join(ROOT, f"{name}.imageset"); os.makedirs(d, exist_ok=True)
    open(os.path.join(d, f"{name}.svg"), "w").write(svg(body))
    json.dump({"images": [{"filename": f"{name}.svg", "idiom": "universal"}], "info": {"author": "xcode", "version": 1},
               "properties": {"preserves-vector-representation": True}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)

os.makedirs(ROOT, exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(ROOT, "Contents.json"), "w"), indent=2)
cs = os.path.join(ROOT, "LaunchBackground.colorset"); os.makedirs(cs, exist_ok=True)
json.dump({"colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {"red": "0.227", "green": "0.122", "blue": "0.420", "alpha": "1.000"}}}],
           "info": {"author": "xcode", "version": 1}}, open(os.path.join(cs, "Contents.json"), "w"), indent=2)
everything = {"nutmeg-tail": tail, **bodies, **head_parts, **faces, **mouths, **props}
for n, b in everything.items(): write(n, b)

# Composite for the app icon / previews: wave pose, neck (0.5,0.625), head scale 0.7, head neck point (0.5,0.80).
scale, nx, ny, hx, hy = 0.70, 512, 640, 512, 820
tx, ty = nx - hx * scale, ny - hy * scale
head = head_parts["nutmeg-ears-normal"] + head_parts["nutmeg-head-base"] + faces["nutmeg-face-happy"] + mouths["nutmeg-mouth-open"]
open(os.path.join(HERE, "nutmeg-composite.svg"), "w").write(svg(
    f'<g transform="translate(0 60)">{tail}{bodies["nutmeg-body-wave"]}<g transform="translate({tx:.1f} {ty:.1f}) scale({scale})">{head}</g></g>'))
print("ok", len(everything), "layers")
