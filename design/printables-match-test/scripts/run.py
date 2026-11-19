"""python3 -I run.py outline|color <type> [tag]  -- one OpenAI image call; never overwrites; logs usage (no key)."""
import json, sys, re, base64, time, uuid, urllib.request, urllib.error, os
S = os.path.dirname(os.path.abspath(__file__))
OUT = "/Users/haymcarthur/PretendThat/design/printables-match-test"
MODEL, SIZE, QUALITY = "gpt-image-2.6-flare", "1024x1536", "low"
cfg = open("/Users/haymcarthur/PretendThat/Secrets.xcconfig").read()
KEY = re.search(r"^OPENAI_API_KEY\s*=\s*(\S+)", cfg, re.M).group(1)
P = json.load(open(os.path.join(S, "prompts.json")))
COLOR_STYLE = P["_style"]["fullColor"].replace("Art style for the whole kit: ", "")
EDIT_V1 = ("Color in this exact coloring page with the kit's color style: " + COLOR_STYLE +
           " Do not change, move, add or remove any line, shape, character or letter; only fill the white areas with flat colors.")
EDIT_V2 = ("This is a finished coloring page. Color it in, exactly like a child filling a coloring book with flat paint: "
           "keep every existing line exactly where it is and fill only the enclosed shapes. Color style: " + COLOR_STYLE +
           " Copy every word, letter and number exactly as it is drawn, character for character (for example \"002\" stays \"002\"); "
           "never redraw, flip or rewrite any text. Keep the thin gray dashed cut lines exactly as they are. Keep the paper "
           "background and the big empty areas white or a pale cream; no full dark or saturated background fill. "
           "Do not change, move, add or remove any line, shape, character or letter.")

def post(req):
    try:
        with urllib.request.urlopen(req, timeout=300) as r: return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")

def log(rec):
    with open(os.path.join(OUT, "calls.jsonl"), "a") as f: f.write(json.dumps(rec) + "\n")

def save(kind, typ, tag, code, obj, extra):
    u = obj.get("usage", {}); d = u.get("input_tokens_details", {})
    txt, img, out = d.get("text_tokens", u.get("input_tokens", 0)), d.get("image_tokens", 0), u.get("output_tokens", 0)
    rec = dict(kind=kind, type=typ, tag=tag, http=code, model=MODEL, size=SIZE, quality=QUALITY, **extra,
               text_in=txt, image_in=img, out=out, dollars=round(txt*5e-6 + img*8e-6 + out*30e-6, 4))
    if code != 200: rec["error"] = obj.get("error", {}).get("message", "")[:300]
    log(rec); print(json.dumps(rec))
    if code == 200:
        name = f"{kind}-{typ}{('-' + tag) if tag else ''}.png"
        open(os.path.join(OUT, name), "wb").write(base64.b64decode(obj["data"][0]["b64_json"]))

kind, typ = sys.argv[1], sys.argv[2]; tag = sys.argv[3] if len(sys.argv) > 3 else ""
target = os.path.join(OUT, f"{kind}-{typ}{('-' + tag) if tag else ''}.png")
if os.path.exists(target): sys.exit("exists: " + target)
t0 = time.time()
if kind == "outline":
    body = {"model": MODEL, "prompt": P[typ]["outline"], "size": SIZE, "n": 1, "quality": QUALITY, "output_format": "png", "moderation": "auto"}
    req = urllib.request.Request("https://api.openai.com/v1/images/generations", data=json.dumps(body, sort_keys=True).encode(),
                                 headers={"Authorization": "Bearer " + KEY, "content-type": "application/json"})
    code, obj = post(req); save(kind, typ, tag, code, obj, {"secs": round(time.time()-t0, 1)})
else:
    prompt = EDIT_V2 if tag == "v2" else EDIT_V1
    png = open(os.path.join(OUT, f"outline-{typ}.png"), "rb").read()
    for fid in ["high", None]:
        fields = {"model": MODEL, "prompt": prompt, "size": SIZE, "n": "1", "quality": QUALITY, "output_format": "png", "moderation": "auto"}
        if fid: fields["input_fidelity"] = fid
        b = uuid.uuid4().hex; parts = []
        for k, v in fields.items():
            parts.append(f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode())
        parts.append(f"--{b}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"outline.png\"\r\nContent-Type: image/png\r\n\r\n".encode() + png + b"\r\n")
        parts.append(f"--{b}--\r\n".encode())
        req = urllib.request.Request("https://api.openai.com/v1/images/edits", data=b"".join(parts),
                                     headers={"Authorization": "Bearer " + KEY, "content-type": f"multipart/form-data; boundary={b}"})
        code, obj = post(req)
        msg = obj.get("error", {}).get("message", "") if code != 200 else ""
        if code == 400 and fid and "fidelity" in msg.lower():
            log({"kind": kind, "type": typ, "note": "input_fidelity rejected (400, not billed): " + msg[:200]}); print("fidelity rejected:", msg[:200]); continue
        save(kind, typ, tag, code, obj, {"secs": round(time.time()-t0, 1), "input_fidelity": fid, "prompt_version": "v2" if tag == "v2" else "v1"})
        break
