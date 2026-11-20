#!/usr/bin/env python3
"""Writes design/prop-stand-ins.md from the Swift table in NutmegCore/Sources/NutmegCore/PropStandIns.swift.

The Swift table is the source of truth; PropStandInsTests checks the Markdown matches `PropStandIns.markdown()`
(on the Mac, where the design folder is next to the package). Run from the repo root: python3 tools/prop_stand_ins.py
"""
import re, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
src = (root / "NutmegCore/Sources/NutmegCore/PropStandIns.swift").read_text()
lib = (root / "NutmegCore/Sources/NutmegCore/PropLibrary.swift").read_text()
names = dict(re.findall(r'\("([a-z-]+)", "([^"]+)"\)', lib))
table = src[src.index("public static let table"):src.index("static let byID")]
rows = re.findall(r'\("([a-z-]+)", \[([^\]]*)\]\)', table)
out = """# Prop stand-ins (for Haylee's review)

Generated from `NutmegCore/Sources/NutmegCore/PropStandIns.swift` (a test fails when this file and the table differ;
regenerate with `python3 tools/prop_stand_ins.py`). Each household prop may only become one of these pretend things
(judged by shape and function for a 4 to 8 year old). Edit the Swift table, then regenerate.

| Prop | Can become |
|---|---|
"""
for pid, items in rows:
    stand = ", ".join(re.findall(r'"([^"]+)"', items))
    out += f"| {names.get(pid, pid)} (`{pid}`) | {stand} |\n"
(root / "design/prop-stand-ins.md").write_text(out)
print(f"wrote design/prop-stand-ins.md ({len(rows)} props)")
