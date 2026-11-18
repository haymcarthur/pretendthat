import json, re, glob, os, difflib
D = "/Users/haymcarthur/PretendThat/design/printables-ai-test"
ocr = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ocr.json")))
def norm(s): return re.sub(r"\s+", " ", re.sub(r"[•·]|\.{2,}|(?<=\w)\s*\.(?=\s|$)", " ", s.replace("’", "'").replace("‘", "'"))).strip()
results = {}
for jf in sorted(glob.glob(f"{D}/*.json")):
    if jf.endswith("results.json"): continue
    r = json.load(open(jf)); png = r["id"] + ".png"
    lines = [x["text"] for x in ocr.get(png, [])]
    text = " " + norm(" ".join(lines)) + " "
    rows = []
    for w in dict.fromkeys(r["words"]):
        want = r["words"].count(w)
        got = len(re.findall(r"(?<![\w$])" + re.escape(norm(w)) + r"(?!\w)", text))
        near = ""
        if got < want:
            toks = text.split(); n = len(w.split())
            grams = [" ".join(toks[i:i+n]) for i in range(len(toks))]
            m = difflib.get_close_matches(w, grams, 1, 0.5); near = m[0] if m else ""
        # tolerant pass (what an in-app check should use): drop spaces/underscores/!/|, Cyrillic look-alikes, S before a digit = $
        def tol(x):
            x = x.translate(str.maketrans("АВСЕНКМОРТХЗаеорсх", "ABCEHKMOPTX3aeopcx"))
            x = re.sub(r"S(?=\d)", "$", x)
            return re.sub(r"[\s_!|]", "", x)
        tgot = tol(text).count(tol(norm(w)))
        rows.append({"tolerant": tgot, "word": w, "want": want, "got": got, "status": "exact" if got >= want else ("ocr-tolerant" if tgot >= want else ("partial" if got else "missing")), "ocr_saw": near})
    vocab = set(t for w in r["words"] for t in norm(w).split())
    extras = [t for t in norm(" ".join(lines)).split() if t not in vocab and t not in "|"]
    results[r["id"]] = {"rows": rows, "ocr_lines": lines, "extras": extras}
    print(r["id"], "|", ", ".join(f'{x["word"]} {x["got"]}/{x["want"]}' + (f' (saw "{x["ocr_saw"]}")' if x["ocr_saw"] else "") + f' [{x["status"]}]' for x in rows if x["status"] != "exact") or "all exact", "| extras:", extras)
json.dump(results, open(f"{D}/ocr-results.json", "w"), indent=1)
