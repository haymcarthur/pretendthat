"""Generate the test pages through the deployed PretendThat relay, the app's way (model fallbacks, low, 1024x1536, png).
Usage: python3 -I generate.py <job-id> [<job-id> ...]   (or "all"). Never regenerates an existing PNG.
"""
import base64, json, os, re, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import recipes as R

ROOT = "/Users/haymcarthur/PretendThat"
OUT = f"{ROOT}/design/printables-ai-test"
MODELS = ["gpt-image-2.6-flare", "gpt-image-2.5-flare", "gpt-image-2"]   # ImageClient.models
SIZE, QUALITY = "1024x1536", "low"                                       # portrait page; ImageQuality.kit

cfg = open(f"{ROOT}/Relay.xcconfig").read()
HOST = re.search(r"^RELAY_HOST = (\S+)", cfg, re.M).group(1)
TOKEN = re.search(r"^RELAY_TOKEN = (\S+)", cfg, re.M).group(1)

PG, RS = "Pirate Treasure Hunt", "Cozy Café"
PIRATE_ROLES = [("Captain", "pirate hat and a treasure chest key"), ("Map Reader", "holding a rolled map"),
                ("Clue Finder", "holding a magnifying glass"), ("Lookout", "holding a spyglass, parrot on shoulder")]
CAFE_ROLES = [("Chef", "tall white chef hat, holding a wooden spoon"), ("Waiter", "bow tie, holding a notepad and a tray"),
              ("Customer", "napkin tucked in, holding a fork, smiling")]
MENU = [("Pancakes", "$3", "a stack of pancakes"), ("Pizza", "$4", "a slice of pizza"),
        ("Soup", "$2", "a bowl of soup"), ("Cupcake", "$1", "a cupcake")]

def jobs():
    j = {}
    for st in ("color", "outline"):
        s = "" if st == "color" else "-outline"
        j[f"pirate-badges{s}"] = ("Treasure hunt", "Role badges (lanyard)", st, R.badges_lanyard(PG, st, PIRATE_ROLES))
        j[f"cafe-menu{s}"] = ("Restaurant", "Menu card", st, R.menu_card(RS, st, "Menu", "Cozy Café", MENU))
    j["pirate-map"] = ("Treasure hunt", "Treasure map", "color", R.treasure_map(PG, "color", "Treasure Map",
                       "a sunny little island", ["Big Rock", "Palm Tree", "Cave", "Treasure"]))
    j["pirate-clues"] = ("Treasure hunt", "Clue cards sheet", "color", R.clue_cards(PG, "color", [
        ("Look under a pillow", "a pillow"), ("Peek behind a chair", "a chair"),
        ("Check inside a box", "a cardboard box"), ("Find the teddy bear", "a teddy bear")]))
    j["pirate-coins"] = ("Treasure hunt", "Coins (money)", "color", R.coins_sheet(PG, "color", "Island Gold", "a palm tree"))
    j["pirate-passes"] = ("Treasure hunt", "Tickets / passes (numbered)", "color", R.tickets_sheet(PG, "color",
                          "Ship Pass", "a pirate ship", ["01", "02", "03", "04", "05", "06", "07", "08"]))
    j["pirate-cutouts"] = ("Treasure hunt", "Cut-outs sheet", "color", R.cutouts_sheet(PG, "color", "Hunt Gear",
                           ["a treasure chest", "a spyglass", "a shovel", "a parrot", "a pirate hat", "a golden key"]))
    j["cafe-badges"] = ("Restaurant", "Role badges (lanyard)", "color", R.badges_lanyard(RS, "color", CAFE_ROLES))
    j["cafe-sign"] = ("Restaurant", "Place sign (door)", "color", R.door_sign(RS, "color", "Cozy Café", "Now Open",
                      "a little café with a striped awning and flower pots"))
    j["cafe-slips"] = ("Restaurant", "Order slips sheet", "color", R.order_slips(RS, "color", [(d, p) for d, _, p in MENU]))
    j["cafe-bills"] = ("Restaurant", "Bills (money)", "color", R.bills_sheet(RS, "color", "Cozy Bucks", "a smiling cupcake"))
    j["cafe-cutouts"] = ("Restaurant", "Cut-outs sheet", "color", R.cutouts_sheet(RS, "color", "Pretend Food",
                         ["pancakes on a plate", "a pizza slice", "a bowl of soup", "a cupcake", "an ice cream cone", "a birthday cake"]))
    # stress tests (6 players, longer clues, letter+number codes)
    j["stress-badges6"] = ("Treasure hunt (stress)", "Role badges, 6 players", "color", R.badges_lanyard(PG, "color",
        PIRATE_ROLES + [("First Mate", "holding a coil of rope"), ("Ship's Cook", "holding a pot and a ladle")]))
    j["stress-clues6"] = ("Treasure hunt (stress)", "Clue cards, 6 longer clues", "color", R.clue_cards(PG, "color", [
        ("Look under the couch cushion", "a couch cushion"), ("Peek behind the bedroom door", "a door"),
        ("Check inside the laundry basket", "a laundry basket"), ("Find the teddy bear", "a teddy bear"),
        ("Search beside the bookshelf", "a bookshelf"), ("Lift up the bath towel", "a folded towel")]))
    j["stress-boarding"] = ("Treasure hunt (stress)", "Passes with seat codes", "color", R.tickets_sheet(PG, "color",
        "Boarding Pass", "a pirate ship", ["1A", "1B", "2A", "2B", "3A", "3B", "4A", "4B"]))
    return j

def call(prompt, model):
    import subprocess, tempfile
    body = json.dumps({"model": model, "prompt": prompt, "size": SIZE, "n": 1, "quality": QUALITY,
                       "output_format": "png", "moderation": "auto"})
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f: f.write(body); bp = f.name
    outp = bp + ".out"
    code = subprocess.run(["curl", "-s", "-o", outp, "-w", "%{http_code}", "-X", "POST", "--max-time", "180",
                           f"https://{HOST}/v1/images/generations", "-H", "content-type: application/json",
                           "-H", f"X-PT-Token: {TOKEN}", "--data-binary", "@" + bp], capture_output=True, text=True).stdout
    try: obj = json.load(open(outp))
    except Exception: obj = {}
    for x in (bp, outp):
        try: os.remove(x)
        except OSError: pass
    return int(code or 0), obj

def run(jid, meta, out_name=None):
    game, typ, st, (prompt, words) = meta
    name = out_name or jid
    png = f"{OUT}/{name}.png"
    if os.path.exists(png): return name, "exists"
    t0 = time.time()
    for m in MODELS:
        code, obj = call(prompt, m)
        err = (obj.get("error") or {}) if isinstance(obj, dict) else {}
        if code == 404 or (code == 400 and (err.get("code") == "model_not_found" or "model" in str(err.get("message", "")).lower())):
            continue
        if code != 200:
            return name, f"HTTP {code} {err.get('code')} {str(err.get('message'))[:200]}"
        open(png, "wb").write(base64.b64decode(obj["data"][0]["b64_json"]))
        u = obj.get("usage", {})
        rec = {"id": name, "job": jid, "game": game, "type": typ, "style": st, "prompt": prompt, "words": words,
               "model": m, "size": SIZE, "quality": QUALITY, "seconds": round(time.time() - t0, 1),
               "input_tokens": u.get("input_tokens", 0), "output_tokens": u.get("output_tokens", 0),
               "dollars": u.get("input_tokens", 0) * 5e-6 + u.get("output_tokens", 0) * 30e-6}
        json.dump(rec, open(f"{OUT}/{name}.json", "w"), indent=1)
        return name, f"ok {m} {rec['seconds']}s ${rec['dollars']:.4f}"
    return name, "no model worked"

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    J = jobs()
    ids = list(J) if sys.argv[1:] == ["all"] else sys.argv[1:]
    # "id@name" = redraw of job id saved as name (the redraw-once safety net)
    work = [(a.split("@")[0], a.split("@")[1] if "@" in a else None) for a in ids]
    with ThreadPoolExecutor(6) as ex:
        for name, res in ex.map(lambda w: run(w[0], J[w[0]], w[1]), work): print(name, res, flush=True)
