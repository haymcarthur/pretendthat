#!/usr/bin/env python3
"""Round 14: split the clipboard (its yellow/orange paths) out of nutmeg-body-sit.svg into nutmeg-sit-clipboard.svg,
so the app can draw it next to her on the floor (it lay far to her left). Mechanical layer split, no redraw.
Usage: tools/split_sit_clipboard.py <in-body.svg> <out-body.svg> <out-clipboard.svg>"""
import re, sys
src, out_body, out_clip = sys.argv[1:4]
s = open(src).read()
head = s[:s.index('<path')]
tail = '</svg>\n'
clip_fills = {'#FFC93C', '#F5AD27', '#FDA304'}
body, clip = [], []
for m in re.finditer(r'<path[^>]*?/>', s, re.S):
    p = m.group(0)
    f = re.search(r'fill="(#\w+)"', p)
    (clip if f and f.group(1).upper() in clip_fills else body).append(p)
open(out_body, 'w').write(head + '\n'.join(body) + '\n' + tail)
open(out_clip, 'w').write(head + '\n'.join(clip) + '\n' + tail)
print(f'body {len(body)} paths, clipboard {len(clip)} paths')
