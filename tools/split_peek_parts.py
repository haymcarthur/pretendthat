"""Builds the peek imagesets from design/nutmeg/peek/nutmeg-peek-parts.svg: groups copied verbatim (same 1536x1024
canvas, no shape edits). back = tail + body, paws = paw-left + paw-right."""
import re, sys, pathlib, json
src = pathlib.Path(sys.argv[1]).read_text()
cat = pathlib.Path(sys.argv[2])
m = re.match(r'(<svg[^>]*>)(.*)</svg>\s*$', src, re.S)
head, body = m.group(1), m.group(2)
depth = 0; start = None; groups = {}
for t in re.finditer(r'<(/?)g\b[^>]*?(/?)>', body):
    if t.group(2): continue
    if not t.group(1):
        if depth == 0: start = t.start()
        depth += 1
    else:
        depth -= 1
        if depth == 0:
            g = body[start:t.end()]
            groups[re.match(r'<g id="([^"]+)"', g).group(1)] = g
sets = {"nutmeg-peek-back": ["tail", "body"], "nutmeg-peek-paws": ["paw-left", "paw-right"]}
for name, ids in sets.items():
    d = cat / f"{name}.imageset"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{name}.svg").write_text(head + "".join(groups[i] for i in ids) + "</svg>\n")
    (d / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True}}, indent=2) + "\n")
    print(name, [len(groups[i]) for i in ids])
