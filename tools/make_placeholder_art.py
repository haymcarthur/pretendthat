#!/usr/bin/env python3
"""Generates placeholder Nutmeg layers (full-frame 1024x1024 SVGs) into Assets.xcassets.
Haylee's Figma export replaces these files under the same names (spec section 7)."""
import json, os, sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "PretendThat", "Resources", "Assets.xcassets")
FUR, FUR_DARK, PINK, INK, WHITE = "#C98A5B", "#9C6340", "#FF9AA2", "#24123F", "#FFFFFF"
PURPLE, YELLOW, CORAL, LIME = "#3A1F6B", "#FFC83D", "#FF5A4E", "#9BDB3F"
S = f'stroke="{INK}" stroke-width="14" stroke-linejoin="round" stroke-linecap="round"'

layers = {
 "nutmeg-tail": f'<path d="M640 900 C820 920 900 820 860 720 C830 650 760 680 790 730" fill="none" stroke="{FUR_DARK}" stroke-width="34" stroke-linecap="round"/>',
 "nutmeg-body": f'<ellipse cx="512" cy="820" rx="185" ry="175" fill="{FUR}" {S}/><ellipse cx="512" cy="850" rx="105" ry="110" fill="#E9B88E"/>'
                f'<ellipse cx="430" cy="985" rx="70" ry="30" fill="{FUR_DARK}" {S}/><ellipse cx="594" cy="985" rx="70" ry="30" fill="{FUR_DARK}" {S}/>',
 "nutmeg-arm-clipboard": f'<rect x="250" y="700" width="200" height="250" rx="22" fill="{YELLOW}" {S}/><rect x="300" y="680" width="100" height="44" rx="14" fill="{CORAL}" {S}/>'
                f'<line x1="285" y1="780" x2="415" y2="780" stroke="{INK}" stroke-width="12" stroke-linecap="round"/><line x1="285" y1="830" x2="395" y2="830" stroke="{INK}" stroke-width="12" stroke-linecap="round"/>'
                f'<line x1="285" y1="880" x2="405" y2="880" stroke="{INK}" stroke-width="12" stroke-linecap="round"/><circle cx="440" cy="820" r="42" fill="{FUR}" {S}/>',
 "nutmeg-head": f'<ellipse cx="512" cy="440" rx="250" ry="215" fill="{FUR}" {S}/><ellipse cx="512" cy="505" rx="120" ry="80" fill="#E9B88E"/>'
                f'<ellipse cx="512" cy="478" rx="30" ry="22" fill="{PINK}" {S}/>'
                f'<line x1="640" y1="500" x2="760" y2="480" stroke="{INK}" stroke-width="8" stroke-linecap="round"/><line x1="640" y1="520" x2="765" y2="530" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>'
                f'<line x1="384" y1="500" x2="264" y2="480" stroke="{INK}" stroke-width="8" stroke-linecap="round"/><line x1="384" y1="520" x2="259" y2="530" stroke="{INK}" stroke-width="8" stroke-linecap="round"/>'
                f'<ellipse cx="380" cy="520" rx="34" ry="20" fill="{PINK}" opacity="0.7"/><ellipse cx="644" cy="520" rx="34" ry="20" fill="{PINK}" opacity="0.7"/>',
 "nutmeg-ears": f'<circle cx="268" cy="205" r="125" fill="{FUR}" {S}/><circle cx="268" cy="205" r="76" fill="{PINK}"/>'
                f'<circle cx="756" cy="205" r="125" fill="{FUR}" {S}/><circle cx="756" cy="205" r="76" fill="{PINK}"/>'
                f'<path d="M640 120 L700 80 L705 160 Z M640 120 L580 80 L575 160 Z" fill="{CORAL}" {S}/><circle cx="640" cy="120" r="20" fill="{CORAL}" {S}/>',
 "nutmeg-headset": f'<path d="M290 420 C290 170 734 170 734 420" fill="none" stroke="{PURPLE}" stroke-width="30" stroke-linecap="round"/>'
                f'<rect x="250" y="380" width="70" height="120" rx="30" fill="{PURPLE}" {S}/><rect x="704" y="380" width="70" height="120" rx="30" fill="{PURPLE}" {S}/>'
                f'<path d="M285 490 C300 580 380 600 430 585" fill="none" stroke="{PURPLE}" stroke-width="16" stroke-linecap="round"/><circle cx="440" cy="582" r="22" fill="{CORAL}" {S}/>',
 "nutmeg-eyes-open": f'<ellipse cx="435" cy="410" rx="52" ry="62" fill="{WHITE}" {S}/><ellipse cx="589" cy="410" rx="52" ry="62" fill="{WHITE}" {S}/>'
                f'<circle cx="442" cy="420" r="30" fill="{INK}"/><circle cx="596" cy="420" r="30" fill="{INK}"/>'
                f'<circle cx="452" cy="407" r="10" fill="{WHITE}"/><circle cx="606" cy="407" r="10" fill="{WHITE}"/>'
                f'<path d="M385 340 Q430 315 470 335" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round"/><path d="M554 335 Q594 315 639 340" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>',
 "nutmeg-eyes-closed": f'<path d="M390 420 Q435 450 480 420" fill="none" stroke="{INK}" stroke-width="14" stroke-linecap="round"/><path d="M544 420 Q589 450 634 420" fill="none" stroke="{INK}" stroke-width="14" stroke-linecap="round"/>',
 "nutmeg-mouth-closed": f'<path d="M470 540 Q512 570 554 540" fill="none" stroke="{INK}" stroke-width="12" stroke-linecap="round"/>',
 "nutmeg-mouth-small": f'<path d="M475 535 Q512 585 549 535 Z" fill="{INK}" {S}/>',
 "nutmeg-mouth-open": f'<path d="M462 530 Q512 610 562 530 Z" fill="{INK}" {S}/><ellipse cx="512" cy="570" rx="26" ry="12" fill="{CORAL}"/>',
 "nutmeg-mouth-wide": f'<path d="M448 525 Q512 640 576 525 Z" fill="{INK}" {S}/><ellipse cx="512" cy="590" rx="36" ry="16" fill="{CORAL}"/>',
 "nutmeg-mouth-ooh": f'<ellipse cx="512" cy="555" rx="26" ry="32" fill="{INK}" {S}/>',
}

props = {
 "prop-curtain-corner": f'<path d="M0 0 H1024 V120 C800 160 520 120 300 220 C180 280 120 520 160 1024 H0 Z" fill="{CORAL}"/>'
                f'<path d="M120 0 C140 400 100 700 160 1024" fill="none" stroke="#D9443A" stroke-width="24"/><path d="M0 120 H1024" stroke="{YELLOW}" stroke-width="30"/>',
 "prop-spotlight": f'<path d="M512 80 L860 1000 H164 Z" fill="{YELLOW}" opacity="0.35"/><rect x="432" y="40" width="160" height="110" rx="30" fill="{PURPLE}" {S}/>',
 "prop-ticket": f'<path d="M150 330 H874 V450 A62 62 0 0 0 874 574 V694 H150 V574 A62 62 0 0 0 150 450 Z" fill="{YELLOW}" {S}/>'
                f'<line x1="680" y1="350" x2="680" y2="674" stroke="{INK}" stroke-width="10" stroke-dasharray="24 18"/><path d="M300 470 L400 512 L300 554" fill="none" stroke="{CORAL}" stroke-width="22" stroke-linecap="round"/>',
 "prop-star": f'<path d="M512 120 L620 380 L900 400 L686 580 L756 860 L512 710 L268 860 L338 580 L124 400 L404 380 Z" fill="{YELLOW}" {S}/>',
}

def write(name, body):
    d = os.path.join(ROOT, f"{name}.imageset"); os.makedirs(d, exist_ok=True)
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>\n'
    open(os.path.join(d, f"{name}.svg"), "w").write(svg)
    json.dump({"images": [{"filename": f"{name}.svg", "idiom": "universal"}],
               "info": {"author": "xcode", "version": 1},
               "properties": {"preserves-vector-representation": True}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)

os.makedirs(ROOT, exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}}, open(os.path.join(ROOT, "Contents.json"), "w"), indent=2)
cs = os.path.join(ROOT, "LaunchBackground.colorset"); os.makedirs(cs, exist_ok=True)
json.dump({"colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {"red": "0.227", "green": "0.122", "blue": "0.420", "alpha": "1.000"}}}],
           "info": {"author": "xcode", "version": 1}}, open(os.path.join(cs, "Contents.json"), "w"), indent=2)
for n, b in {**layers, **props}.items(): write(n, b)
# Full composite for previews/tools
open(os.path.join(os.path.dirname(__file__), "nutmeg-composite.svg"), "w").write(
    '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">' +
    "".join(layers[k] for k in ["nutmeg-tail","nutmeg-body","nutmeg-arm-clipboard","nutmeg-head","nutmeg-ears","nutmeg-headset","nutmeg-eyes-open","nutmeg-mouth-open"]) + "</svg>")
print("ok", len(layers), "layers,", len(props), "props")
