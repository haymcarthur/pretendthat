import json, html
D = "/Users/haymcarthur/PretendThat/design/printables-ai-test"
order = ["pirate-badges","pirate-map","pirate-clues","pirate-coins","pirate-passes","pirate-cutouts",
         "cafe-badges","cafe-sign","cafe-menu","cafe-slips","cafe-bills","cafe-cutouts",
         "pirate-badges-outline","cafe-menu-outline","stress-badges6","stress-clues6","stress-boarding"]
ocr = json.load(open(f"{D}/ocr-results.json"))
notes = {
 "pirate-badges": "4 lanyard tags, role title on a ribbon, Name line on every badge. Characters match the roles (key, map, magnifier, spyglass + parrot). Skull and crossbones on hats.",
 "pirate-map": "Scroll map, path visits the 4 stops in order, X under Treasure. Compass has no letters as asked.",
 "pirate-clues": "Numbered 1 to 4, picture hint matches each clue, rope + shell border.",
 "pirate-coins": "12 coins, every one says 1, title at the very top edge (margin ignored).",
 "pirate-passes": "8 passes, each with its OWN number 01 to 08 in order on the stub. Per-copy numbers work.",
 "pirate-cutouts": "6 props in order with white cut borders and dashed cut lines.",
 "cafe-badges": "3 badges (2 + 1 centered), each with its own awning color.",
 "cafe-sign": "Hanging door sign, the accent in Café drawn right.",
 "cafe-menu": "4 dishes, dotted leaders, prices $1 to $4 exactly as given.",
 "cafe-slips": "4 identical notepad slips, tick boxes, Table + empty box.",
 "cafe-bills": "8 bills, $1 twice on each, one emblem.",
 "cafe-cutouts": "6 foods, birthday cake has 5 candles (fine).",
 "pirate-badges-outline": "Same layout as the color badges, open shapes to color, plain (not bubble) title letters.",
 "cafe-menu-outline": "Bubble letters to color in. OCR read $3 as S3 (the page is right: hollow letters fool OCR).",
 "stress-badges6": "6 players: 3 x 2 tags, Ship's Cook with a curly apostrophe. OCR read the Name lines as 'Name:_' (the blank line).",
 "stress-clues6": "Longer clues (4 to 5 words) still spelled right and wrap neatly. OCR merged 'insidethe'.",
 "stress-boarding": "Seat codes 1A to 4B in order. OCR read 3A with a Cyrillic З (the page is right).",
}
def badge(s): return {"exact":"ok","ocr-tolerant":"tol","partial":"bad","missing":"bad"}[s]
cards = []
for i in order:
    r = json.load(open(f"{D}/{i}.json")); o = ocr[i]
    allok = all(x["status"] == "exact" for x in o["rows"])
    tolok = all(x["status"] in ("exact","ocr-tolerant") for x in o["rows"])
    verdict = "All words exact" if allok else ("Exact after tolerant matching (OCR misread, page is right)" if tolok else "Garbled")
    vcls = "ok" if allok else ("tol" if tolok else "bad")
    rows = "".join(f'<li class="{badge(x["status"])}"><code>{html.escape(x["word"])}</code> <span>{x["got"]}/{x["want"]}'
                   + (f' &middot; OCR saw &ldquo;{html.escape(x["ocr_saw"])}&rdquo;' if x["ocr_saw"] else "") + '</span></li>' for x in o["rows"])
    cards.append(f'''<article id="{i}">
 <a href="{i}.png" target="_blank"><img src="{i}.png" alt="{html.escape(r['game'])} {html.escape(r['type'])}" loading="lazy"></a>
 <div class="meta">
  <p class="tags"><span>{html.escape(r['game'])}</span><span>{html.escape(r['type'])}</span><span class="st-{r['style']}">{r['style']}</span></p>
  <p class="verdict {vcls}">{verdict}</p>
  <p class="note">{html.escape(notes.get(i,""))}</p>
  <ul class="words">{rows}</ul>
  <p class="small">OCR lines: {html.escape(" / ".join(o["ocr_lines"]))}</p>
  <p class="small">{r['model']} &middot; {r['size']} &middot; quality {r['quality']} &middot; {r['seconds']} s &middot; ${r['dollars']:.4f}</p>
  <details><summary>Prompt</summary><p class="prompt">{html.escape(r['prompt'])}</p></details>
 </div>
</article>''')
tot = sum(json.load(open(f"{D}/{i}.json"))["dollars"] for i in order)
page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AI-Drawn Printables Test</title>
<style>
:root{{--bg:#FFF8EF;--card:#fff;--ink:#2A1846;--muted:#6b5a80;--line:#eadfce;--ok:#3f8f1c;--okbg:#eaf7df;--tol:#9a6b00;--tolbg:#fff3cf;--bad:#c23a2b;--badbg:#ffe3df;--accent:#5B2A86}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--bg:#1b1226;--card:#251a33;--ink:#f3ecff;--muted:#b9a8cf;--line:#3a2c4d;--okbg:#20361a;--ok:#9fe07a;--tolbg:#3a2f12;--tol:#ffd36b;--badbg:#3d1d1a;--bad:#ff8f80;--accent:#c9a5ff}}}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--ink);font:16px/1.45 -apple-system,system-ui,sans-serif}}
header,main{{max-width:1200px;margin:0 auto;padding:16px}} h1{{margin:.4em 0 .2em;font-size:28px}} header p{{color:var(--muted);margin:.3em 0}}
.sum{{display:flex;flex-wrap:wrap;gap:10px;margin:12px 0}} .sum div{{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px 14px}} .sum b{{display:block;font-size:22px}}
nav a{{color:var(--accent);margin-right:12px}}
article{{display:grid;grid-template-columns:minmax(0,560px) minmax(0,1fr);gap:20px;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px;margin:18px 0}}
article img{{width:100%;height:auto;border-radius:8px;border:1px solid var(--line);background:#fff;display:block}}
@media (max-width:820px){{article{{grid-template-columns:1fr}}}}
.tags span{{display:inline-block;background:var(--bg);border:1px solid var(--line);border-radius:999px;padding:2px 10px;margin:0 6px 6px 0;font-size:14px}}
.st-outline{{font-style:italic}} .verdict{{font-weight:700;padding:6px 10px;border-radius:8px;display:inline-block}}
.verdict.ok{{background:var(--okbg);color:var(--ok)}} .verdict.tol{{background:var(--tolbg);color:var(--tol)}} .verdict.bad{{background:var(--badbg);color:var(--bad)}}
.words{{list-style:none;padding:0;display:flex;flex-wrap:wrap;gap:6px}} .words li{{border-radius:8px;padding:3px 8px;font-size:14px}}
.words li.ok{{background:var(--okbg)}} .words li.tol{{background:var(--tolbg)}} .words li.bad{{background:var(--badbg)}} .words span{{color:var(--muted)}}
.small{{color:var(--muted);font-size:13px;overflow-wrap:anywhere}} .prompt{{font-size:13px;white-space:pre-wrap;overflow-wrap:anywhere}} summary{{cursor:pointer;color:var(--accent)}}
</style></head><body>
<header><h1>AI-drawn printable pages: test</h1>
<p>The image model draws the whole page (frame, decorations, layout, every word); the app draws nothing on top. Two games: a pirate treasure hunt (4 roles) and a restaurant (3 roles), plus 2 outline pages and 3 stress tests. Called through the deployed PretendThat relay with the app's model and settings (gpt-image-2.6-flare, 1024x1536, quality low). OCR is Apple Vision (accurate, no language correction); "tolerant" ignores spaces, underscores, Cyrillic look-alikes and S-for-$.</p>
<div class="sum"><div><b>17</b>pages saved</div><div><b>19</b>calls billed (2 lost to a dropped connection)</div><div><b>${tot:.2f}</b>measured (~$0.42 with the 2 lost)</div><div><b>~2.2&cent;</b>per page</div><div><b>0</b>garbled words (visual check)</div><div><b>13 / 17</b>pages exact by strict OCR, 17 / 17 tolerant</div></div>
<p><a href="contact-sheet.png">Contact sheet (all pages)</a></p>
<nav>{" ".join(f'<a href="#{i}">{i}</a>' for i in order)}</nav></header>
<main>{"".join(cards)}</main></body></html>'''
open(f"{D}/index.html","w").write(page)
print("ok", round(tot,4))
