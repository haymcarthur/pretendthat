"""Prompt recipes for AI-drawn whole printable pages (PretendThat test, 2026-11-17).

Each recipe returns (prompt, words) where words is the list of exact strings the page must show (for the OCR check).
"""

PAGE = ("A printable US Letter portrait page (8.5 by 11 inches) for a kids' pretend-play game, drawn flat and "
        "straight-on and filling the whole image: the page itself, not a photo or mockup of paper. Plain white paper "
        "with a clean white margin of about half an inch on every side where nothing is drawn, so it prints on a home "
        "printer.")

STYLE = {
    "color": ("Art style for the whole kit: bright, friendly flat vector cartoon like a modern kids' picture-book app: "
              "bold clean dark purple outlines, flat cheerful fills in coral red, sunny yellow, lime green, sky blue, "
              "deep purple and cream, soft rounded shapes, no gradients, no shading texture, no photo effects, lots of "
              "white paper. Ink-friendly: color sits on white, no full-page dark background."),
    "outline": ("Art style for the whole kit: coloring-page version of a friendly flat vector cartoon: black outlines "
                "only on white paper, thick clean even lines, soft rounded shapes, no color, no gray, no shading, no "
                "filled black areas, every shape open for a 5-year-old to color in. Letters are bold outlined bubble "
                "letters that can be colored in too."),
}

def words_rule(words, extra=""):
    q = ", ".join(f'"{w}"' for w in words)
    return (f" The ONLY words on the page, spelled exactly letter for letter: {q}.{extra} Big, clear, rounded "
            "print letters, easy for a 5-year-old to read, dark on a light background, never curved along a path, "
            "never tiny. No other words, letters, numbers or signatures anywhere.")

SAFE = (" Kid-friendly and gentle, for ages 4 to 8: no guns, no knives, no real weapons (a toy sword is fine), no blood, "
        "nothing scary, no real people, no brands, no logos.")

CUT = " Thin gray dashed cut lines around each piece, with wide white gutters between pieces so scissors fit."


def head(game, style):
    return f'{PAGE} The game is "{game}". {STYLE[style]}'


# 1. Role badges, lanyard variant -------------------------------------------------------------------------------
def badges_lanyard(game, style, roles):
    """roles: list of (title, what the character wears/holds)."""
    n = len(roles)
    grid = {2: "1 column of 2", 3: "3 badges in one row across the top half, or 2 on top and 1 centered below",
            4: "2 columns and 2 rows", 5: "3 on top, 2 below", 6: "3 columns and 2 rows"}[n]
    lst = "; ".join(f'badge {i+1}: a cute cartoon character as the {t.lower()} ({w}), title "{t}"'
                    for i, (t, w) in enumerate(roles))
    prompt = (head(game, style) + f" Draw a sheet of exactly {n} lanyard name badges, laid out {grid}, all the same "
              "size: tall rounded-rectangle tags with a punched hole and a little clip at the top center, a themed "
              f"decorative border, one character picture in the upper half, the role title under it on a ribbon "
              f"banner, and at the bottom the word \"Name:\" followed by a long blank line to write on. In order: {lst}."
              + words_rule([t for t, _ in roles] + ["Name:"], f' "Name:" appears once on every badge ({n} times).')
              + " Every badge identical in shape and size so they look like a set." + CUT + SAFE)
    return prompt, [t for t, _ in roles] + ["Name:"] * n


# 2. Place sign, door variant ----------------------------------------------------------------------------------
def door_sign(game, style, place, tagline, picture):
    prompt = (head(game, style) + f" Draw ONE big door sign that fills the page inside the margin: a tall rounded "
              f"sign board with a hanging string at the top and a fun themed frame. Across the top in huge letters: "
              f"\"{place}\". In the middle a big cheerful picture of {picture}. Near the bottom on a ribbon: "
              f"\"{tagline}\"." + words_rule([place, tagline]) + SAFE)
    return prompt, [place, tagline]


# 3. Treasure map ----------------------------------------------------------------------------------------------
def treasure_map(game, style, title, place, stops):
    s = ", ".join(f'"{x}"' for x in stops)
    prompt = (head(game, style) + f" Draw ONE treasure map that fills the page inside the margin: an old paper "
              f"scroll with curled ends, a picture-book map of {place} seen from above, a winding dashed path that "
              f"visits {len(stops)} stops in order, each stop a big simple landmark drawing with its name on a little "
              f"flag or plaque beside it: {s}. The last stop has a big red X. A friendly compass rose with no letters. "
              f"Title across the top on a ribbon: \"{title}\"." + words_rule([title] + stops) + SAFE)
    return prompt, [title] + stops


# 4. Clue cards sheet ------------------------------------------------------------------------------------------
def clue_cards(game, style, clues):
    """clues: list of (clue text, picture hint)."""
    n = len(clues)
    lst = "; ".join(f'card {i+1}: a big number "{i+1}" in a circle in the top corner, a picture of {p}, and the clue '
                    f'"{c}"' for i, (c, p) in enumerate(clues))
    prompt = (head(game, style) + f" Draw a sheet of exactly {n} clue cards in a grid of 2 columns and "
              f"{(n+1)//2} rows, all the same size: rounded cards with a themed decorative border (rope, little stars "
              f"or seashells), each with one picture hint and one short clue under it. In order, left to right, top to "
              f"bottom: {lst}." + words_rule([c for c, _ in clues], " Plus the card numbers 1 to %d, one per card." % n)
              + CUT + SAFE)
    return prompt, [c for c, _ in clues] + [str(i + 1) for i in range(n)]


# 5. Menu card -------------------------------------------------------------------------------------------------
def menu_card(game, style, title, place, items):
    """items: list of (dish, price, picture)."""
    lst = "; ".join(f'"{d}" with a small picture of {p} on the left and the price "{pr}" on the right'
                    for d, pr, p in items)
    prompt = (head(game, style) + f" Draw ONE menu card for a pretend restaurant that fills the page inside the "
              f"margin: a decorative themed frame (little forks, spoons, hearts, checkered corners). At the top the "
              f"restaurant name \"{place}\" and under it the big word \"{title}\". Then {len(items)} rows, one dish per "
              f"row, evenly spaced, with a dotted leader between dish and price: {lst}."
              + words_rule([place, title] + [f"{d}" for d, _, _ in items] + [pr for _, pr, _ in items]) + SAFE)
    return prompt, [place, title] + [d for d, _, _ in items] + [pr for _, pr, _ in items]


# 6. Order slips sheet -----------------------------------------------------------------------------------------
def order_slips(game, style, items, copies=4):
    """items: list of (dish, picture). Each slip: 'Order', 'Table' + blank, tick box per dish."""
    lst = ", ".join(f'"{d}" (tiny picture of {p})' for d, p in items)
    prompt = (head(game, style) + f" Draw a sheet of exactly {copies} identical order slips in a grid of 2 columns "
              f"and {copies//2} rows: tall waiter's notepad slips with a little spiral at the top. On each slip: the "
              f"word \"Order\" at the top, then \"Table\" followed by a small empty box, then {len(items)} rows, each "
              f"an empty square tick box, a tiny picture and the dish name: {lst}."
              + words_rule(["Order", "Table"] + [d for d, _ in items], f" Every slip shows the same words ({copies} copies).")
              + CUT + SAFE)
    return prompt, (["Order", "Table"] + [d for d, _ in items]) * copies


# 7. Coins / money sheet ---------------------------------------------------------------------------------------
def coins_sheet(game, style, name, emblem, count=12):
    prompt = (head(game, style) + f" Draw a sheet of exactly {count} identical round play coins in a grid of 3 "
              f"columns and {count//3} rows, plus the title \"{name}\" across the top of the page in big letters. "
              f"Each coin: a thick rim, {emblem} in the middle, and a big \"1\" on it. Every coin is worth one: no other "
              f"amounts." + words_rule([name, "1"], f' "1" appears once on every coin ({count} times).') +
              " Thin gray dashed circle cut lines around each coin, wide white gaps between coins." + SAFE)
    return prompt, [name] + ["1"] * count


def bills_sheet(game, style, name, emblem, count=8):
    prompt = (head(game, style) + f" Draw a sheet of exactly {count} identical play-money bills in a grid of 2 "
              f"columns and {count//2} rows: wide rounded bills with a fancy border, {emblem} in an oval in the middle, "
              f"\"$1\" in two corners, and the money's name \"{name}\" across the top of each bill." +
              words_rule([name, "$1"], f" Every bill shows the same words ({count} copies).") + CUT + SAFE)
    return prompt, ([name] + ["$1", "$1"]) * count


# 8. Tickets / passes with a different number per copy ---------------------------------------------------------
def tickets_sheet(game, style, title, picture, numbers):
    n = len(numbers)
    lst = ", ".join(f'"{x}"' for x in numbers)
    prompt = (head(game, style) + f" Draw a sheet of exactly {n} admission passes in a grid of 2 columns and "
              f"{n//2} rows: wide ticket shapes with notched corners and a perforated stub on the right. Each pass shows "
              f"the title \"{title}\", a small picture of {picture}, and on the stub its OWN number, a different one "
              f"on each pass, in this order left to right, top to bottom: {lst}." +
              words_rule([title] + numbers, " Each number appears on exactly one pass.") + CUT + SAFE)
    return prompt, [title] * n + numbers


# 9. Cut-outs sheet --------------------------------------------------------------------------------------------
def cutouts_sheet(game, style, title, things):
    n = len(things)
    lst = ", ".join(f"{i+1}. {t}" for i, t in enumerate(things))
    prompt = (head(game, style) + f" Draw a sheet of exactly {n} big cut-out props to hold in pretend play, in a "
              f"grid of 2 columns and {(n+1)//2} rows, each one simple object filling its cell, in this order: {lst}. "
              f"Title across the top: \"{title}\". Each prop has a thick white cut-around border and a thin gray dashed "
              f"cut line around that border, with wide white gaps between props." + words_rule([title]) +
              " The props themselves have no writing on them." + SAFE)
    return prompt, [title]
