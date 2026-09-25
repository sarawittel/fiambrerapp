#!/usr/bin/env python3
"""Convierte cache/pages.json (wiki de Graveyard Keeper) en los JSON de GK2Core/Resources.

Uso: python3 fetch.py && python3 convert.py
"""
import json, os, re, unicodedata
from collections import defaultdict

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "..", "..", "Packages", "GK2Core", "Sources", "GK2Core", "Resources")

cache = json.load(open(os.path.join(HERE, "cache", "pages.json")))
PAGES, REDIRECTS = cache["pages"], cache["redirects"]
# fuera las subpáginas de traducción (p. ej. "Horadric/zh")
PAGES = {t: p for t, p in PAGES.items() if "/" not in t}
LOWER = {t.lower(): t for t in PAGES}
REDIR_LOWER = {k.lower(): v for k, v in REDIRECTS.items()}

# Semana de GK1, en el orden del juego.
DAYS = [
    ("Pride", "orgullo", "Día del Orgullo", "Orgullo", "crown", "#e0a83a"),
    ("Lust", "lujuria", "Día de la Lujuria", "Lujuria", "heart", "#a8322d"),
    ("Gluttony", "gula", "Día de la Gula", "Gula", "meat", "#e07a2a"),
    ("Envy", "envidia", "Día de la Envidia", "Envidia", "eye", "#7a8f4a"),
    ("Wrath", "ira", "Día de la Ira", "Ira", "skull", "#7a4a8a"),
    ("Sloth", "pereza", "Día de la Pereza", "Pereza", "moon", "#4a8ab0"),
]
DAY_ID = {en.lower(): id for en, id, *_ in DAYS}

SKIP_TYPES = ("unimpl",)


# MARK: - Utilidades de wikitext

def slug(title):
    s = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")


def canonical(name):
    """Título de página para un nombre enlazado, siguiendo redirecciones y sin distinguir mayúsculas."""
    name = name.split("#")[0].strip().replace("_", " ")
    if not name:
        return None
    for _ in range(3):
        if name in PAGES:
            return name
        if name.lower() in LOWER:
            return LOWER[name.lower()]
        target = REDIRECTS.get(name) or REDIR_LOWER.get(name.lower())
        if not target:
            break
        name = target.split("#")[0]
    return name[0].upper() + name[1:]


def expand_pagename(text, title):
    return re.sub(r"\{\{\s*(?:lc|lcfirst|uc|ucfirst)?:?\s*\{\{\s*PAGENAME\s*\}\}\s*\}\}|\{\{\s*PAGENAME\s*\}\}", title, text)


ITEM_RE = re.compile(r"\{\{\s*[Ii]tem\s*\|([^|}]*)(?:\|([^|}]*))?(?:\|([^|}]*))?[^}]*\}\}")


def items_in(text):
    """[(nombre, cantidad, calidad)] de las plantillas {{Item|...}}."""
    out = []
    for name, qty, quality in ITEM_RE.findall(text):
        name, qty = re.sub(r"^\s*1\s*=", "", name), re.sub(r"^\s*2\s*=", "", qty).strip()
        if not name.strip() or name.strip() == "?":
            continue
        n = int(qty) if qty.isdigit() else 1
        out.append((name.strip(), n, quality.strip().lower()))
    return out


def plain(text):
    """Wikitext -> texto legible."""
    t = re.sub(r"<br\s*/?>", ", ", text)
    t = re.sub(r"<[^>]+>", "", t)
    t = re.sub(r"\[\[(?:[Ff]ile|[Ii]mage):[^\]]*\]\]", "", t)
    t = re.sub(r"\{\{\s*(?:Item|NPC|Day)\s*\|([^|}]*)[^}]*\}\}", r"\1", t, flags=re.I)
    t = re.sub(r"\{\{\s*Money\s*\|([^|}]*)\}\}", r"\1 monedas", t, flags=re.I)
    t = re.sub(r"\{\{[^{}]*\}\}", "", t)
    t = re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]*)\]\]", r"\1", t)
    t = re.sub(r"\[https?://\S+\s*([^\]]*)\]", r"\1", t)
    t = re.sub(r"'{2,}", "", t)
    return re.sub(r"\s+", " ", t).strip(" ,;")


def infobox(text, name):
    m = re.search(r"\{\{\s*" + name + r"(.*?)\n\s*\}\}", text, re.S)
    if not m:
        m = re.search(r"\{\{\s*" + name + r"(.*?)\}\}\s*\n", text, re.S)
    if not m:
        return None
    fields, depth, cur = {}, 0, ""
    # separa por "|" de primer nivel
    parts, buf = [], ""
    for ch in m.group(1):
        if ch in "{[":
            depth += 1
        elif ch in "}]":
            depth -= 1
        if ch == "|" and depth == 0:
            parts.append(buf)
            buf = ""
        else:
            buf += ch
    parts.append(buf)
    for p in parts:
        if "=" in p:
            k, v = p.split("=", 1)
            fields[k.strip().lower()] = v.strip()
    return fields


def section(text, heading, level=2):
    eq = "=" * level
    m = re.search(rf"^{eq}\s*{heading}\s*{eq}\s*$(.*?)(?=^={{1,{level}}}[^=]|\Z)", text, re.M | re.S | re.I)
    return m.group(1) if m else ""


def tables(text):
    """Tablas más internas como listas de filas; cada fila es [(es_cabecera, texto_celda)]."""
    result, stack = [], []
    for raw in text.split("\n"):
        line = raw.strip()
        if line.startswith("{|"):
            stack.append([[]])
            continue
        if not stack:
            continue
        rows = stack[-1]
        if line.startswith("|}"):
            done = stack.pop()
            result.append([r for r in done if r])
            continue
        if line.startswith("|-"):
            rows.append([])
        elif line.startswith("|+"):
            continue
        elif line.startswith("!") or line.startswith("|"):
            header = line.startswith("!")
            sep = "!!" if header else "||"
            for cell in line[1:].split(sep):
                # quita atributos tipo style="..."| (sin confundir con [[a|b]] o {{a|b}})
                m = re.match(r'^\s*((?:[a-z-]+\s*=\s*"[^"]*"\s*)+)\|(?!\|)(.*)$', cell, re.S)
                if m:
                    cell = m.group(2)
                rows[-1].append([header, cell.strip()])
        elif rows[-1]:
            rows[-1][-1][1] += "\n" + line
    return result


# MARK: - Objetos

CATEGORY_RULES = [
    ("herramienta", ("tool", "weapon", "armor", "equipment", "fishing", "repair", "bag")),
    ("funerario", ("grave", "church", "sermon", "embalming", "bodypart", "body")),
    ("alquimia", ("alchem", "metaphysical", "emulsion", "insect", "blessing", "soul")),
    ("comida", ("meal", "snack", "dessert", "beverage", "food", "crop", "seed", "fish", "bee", "apiary")),
]

ICON_RULES = [
    ("coffin", "coffin"), ("grave", "grave"), ("fence", "grave"), ("cross", "grave"), ("tomb", "grave"),
    ("skull", "skull"), ("bone", "bone"), ("heart", "heart"), ("eye", "eye"), ("blood", "potion_dark"),
    ("flesh", "meat"), ("meat", "meat"), ("fat", "fat"), ("skin", "fat"),
    ("candle", "candle"), ("wax", "wax"), ("honey", "wax"),
    ("plank", "plank"), ("beam", "plank"), ("board", "plank"), ("log", "log"), ("wood", "log"), ("flitch", "log"), ("stick", "log"),
    ("ingot", "ingot"), ("parts", "ingot"), ("nail", "nails"), ("ore", "ore"), ("coal", "ore"),
    ("stone", "stone"), ("marble", "stone"), ("rock", "stone"), ("clay", "stone"), ("sand", "stone"),
    ("water", "water"), ("wine", "potion"), ("beer", "potion"),
    ("flour", "sack"), ("wheat", "wheat"), ("grain", "wheat"), ("bread", "bread"), ("burger", "burger"),
    ("paper", "scroll"), ("scroll", "scroll"), ("book", "scroll"), ("ink", "potion_dark"), ("chapter", "scroll"), ("story", "scroll"),
    ("sermon", "scroll"), ("certificate", "scroll"), ("letter", "scroll"), ("note", "scroll"),
    ("powder", "sack"), ("extract", "potion"), ("solution", "potion"), ("potion", "potion"), ("elixir", "potion"),
    ("jug", "potion"), ("bottle", "potion"), ("vial", "potion"),
    ("seed", "herb"), ("herb", "herb"), ("grass", "herb"), ("leaf", "herb"), ("flower", "herb"), ("mushroom", "herb"),
    ("hammer", "anvil"), ("chisel", "anvil"), ("axe", "anvil"), ("sword", "anvil"), ("shovel", "anvil"), ("pickaxe", "anvil"),
    ("coin", "coin"), ("gold", "coin"), ("silver", "coin"),
]
CATEGORY_ICON = {"material": "stone", "comida": "bread", "alquimia": "potion", "funerario": "grave", "herramienta": "anvil"}


def category_for(type_):
    t = type_.lower()
    for cat, keys in CATEGORY_RULES:
        if any(k in t for k in keys):
            return cat
    return "material"


def icon_for(name, category):
    n = name.lower()
    for key, icon in ICON_RULES:
        if re.search(r"\b" + key, n):
            return icon
    return CATEGORY_ICON[category]


def split_list(text):
    parts = re.split(r"\s*(?:,|;|/| or )\s*", plain(text))
    return [p for p in (x.strip() for x in parts) if p and p.lower() not in ("n/a", "none", "-", "?")]


items = {}          # título -> dict
item_meta = {}      # título -> infobox


def add_item(title, category="material", sources=None, description=None):
    if title in items:
        return items[title]
    same = next((t for t in items if slug(t) == slug(title)), None)
    if same:  # mismo objeto escrito con otras mayúsculas
        items[title] = items[same]
        return items[same]
    items[title] = {"id": slug(title), "name": title, "category": category, "icon": icon_for(title, category)}
    if sources:
        items[title]["sources"] = sources
    if description:
        items[title]["description"] = description
    return items[title]


def intro(text):
    """Primera frase del artículo."""
    body = re.sub(r"\{\{[^{}]*\}\}", "", re.sub(r"\{\{[^{}]*\}\}", "", text))
    for para in body.split("\n"):
        para = para.strip()
        if para and not para.startswith(("{", "|", "!", "=", "[[Category", "[[File", "<", "*", "__")):
            s = plain(para)
            if len(s) > 20:
                first = re.split(r"(?<=[.!?])\s", s, maxsplit=1)[0]
                return first[:240]
    return None


for title, page in PAGES.items():
    text = expand_pagename(page["text"], title)
    box = infobox(text, "Item Infobox")
    if not box:
        continue
    type_ = plain(box.get("type", ""))
    if any(s in type_.lower() for s in SKIP_TYPES):
        continue
    item_meta[title] = box
    cat = category_for(type_)
    sources = split_list(box.get("source", ""))
    add_item(title, cat, sources or None, intro(text))


# MARK: - Recetas

# puntos de tecnología: no son objetos
TECH_POINTS = {"Science", "Faith", "Nature"}
# estaciones que en realidad son lugares donde se construye
STATION_ALIASES = {"Cooking": "Cooking table", "GoC Cooking table": "Cooking table (Game of Crone)"}
BUILD_PLACES = {t for t, p in PAGES.items() if "Location Infobox" in p["text"] or "Locations" in p["categories"]} | {
    "The Graveyard", "Workyard", "Church", "Alchemy Lab", "Morgue", "Farming", "Beekeeping", "Cabin in the woods"}

WORKSTATIONS = {t for t, p in PAGES.items() if "Workstations" in p["categories"] or "Workstation-Infobox" in p["text"]}

recipes = []
seen = {}  # (estación, producto, ingredientes) -> receta


def resolve_item(name):
    title = canonical(name)
    if not title:
        return None
    if title not in items:
        add_item(title)
    return items[title]["id"]


def station_from_header(cell, page_title):
    found = items_in(cell)
    if found:
        return canonical(found[0][0])
    m = re.search(r"\[\[(?![Ff]ile:)([^|\]]+)", cell)
    if m:
        return canonical(m.group(1))
    if "tab_" in cell or "tab " in cell:
        return page_title if page_title in WORKSTATIONS else None
    return None


def parse_time(cell):
    m = re.fullmatch(r"\s*(\d+:\d{2})\s*", cell)
    return m.group(1) if m else None


for title, page in PAGES.items():
    text = expand_pagename(page["text"], title)
    for sec_name in ("Cost",):  # costes de construcción, no son recetas
        text = text.replace(section(text, sec_name), "")
    default_station = title if title in WORKSTATIONS else None
    for table in tables(text):
        station, columns = default_station, []
        for row in table:
            if all(h for h, _ in row):
                labels = [plain(c).lower() for _, c in row]
                if len(row) == 1 or any("colspan" in c for _, c in row):
                    s = station_from_header(row[0][1], title)
                    if s:
                        station = s
                elif labels:
                    columns = labels
                continue
            cells = [c for h, c in row if not h]
            if len(cells) < 2 or not station:
                continue
            if columns and not any("produced" in c for c in columns):
                continue
            out = items_in(cells[0])
            ins = items_in(cells[1])
            if len(out) != 1 or not ins or re.search(r"tech|study", " ".join(columns)):
                continue
            out_name, out_qty, quality = out[0]
            if canonical(out_name) in TECH_POINTS:
                continue
            output = resolve_item(out_name)
            ingredients = []
            for name, qty, _ in ins:
                iid = None if canonical(name) in TECH_POINTS else resolve_item(name)
                if iid:
                    ingredients.append({"item": iid, "qty": qty})
            if not output or not ingredients:
                continue
            station_name = canonical(station)
            station_name = STATION_ALIASES.get(station_name, station_name)
            if station_name in BUILD_PLACES:
                station_name = f"Construcción · {station_name}"
            key = (station_name, output, tuple(sorted((i["item"], i["qty"]) for i in ingredients)))
            # misma receta en varias páginas: manda la página de la estación, luego la del producto
            priority = 0 if canonical(station) == title else 1 if items.get(title, {}).get("id") == output else 2
            notes = []
            if quality in ("copper", "silver", "gold"):
                notes.append({"copper": "Calidad bronce", "silver": "Calidad plata", "gold": "Calidad oro"}[quality])
            if cells[0].lstrip().startswith("*"):
                notes.append("Requiere un perk")
            recipe = {"output": output, "outputQty": out_qty, "station": station_name, "ingredients": ingredients}
            if "time" in columns and columns.index("time") < len(row):
                t = parse_time(row[columns.index("time")][1])
                if t:
                    recipe["time"] = t
            if notes:
                recipe["notes"] = ". ".join(notes) + "."
            # orden en la página del producto: la primera suele ser la principal
            recipe["_order"] = len(recipes) if priority == 1 else 10**6
            recipe["_priority"] = priority
            old = seen.get(key)
            if old is None:
                seen[key] = recipe
                recipes.append(recipe)
                continue
            if priority < old["_priority"]:
                recipe.setdefault("time", old.get("time"))
                recipe["_order"] = min(recipe["_order"], old["_order"])
                old.clear()
                old.update({k: v for k, v in recipe.items() if v is not None})
            else:
                if "time" not in old and "time" in recipe:
                    old["time"] = recipe["time"]
                old["_order"] = min(old["_order"], recipe["_order"])


def recipe_rank(r):
    self_ref = any(i["item"] == r["output"] for i in r["ingredients"])
    return (self_ref, "notes" in r, r["_order"], len(r["ingredients"]))


# la primera receta de cada objeto es la que usa el planificador
by_output = defaultdict(list)
for r in recipes:
    by_output[r["output"]].append(r)
recipes = []
for output in sorted(by_output):
    for n, r in enumerate(sorted(by_output[output], key=recipe_rank)):
        clean = {k: v for k, v in r.items() if not k.startswith("_")}
        recipes.append({"id": f"r_{output}" + (f"_{n + 1}" if n else ""), **clean})


# MARK: - Personajes

NPC_ICONS = {
    "bishop": "crown", "merchant": "coin", "inquisitor": "skull", "astrologer": "moon", "ms_charm": "heart",
    "snake": "eye", "clotho": "cauldron", "tress": "log", "cory": "stone", "farmer": "wheat", "miller": "sack",
    "beekeeper": "wax", "barman": "burger", "koukol": "anvil", "lighthouse_keeper": "water", "rosa": "water",
    "cook": "bread", "adam": "potion", "donkey": "sack", "gerry": "skull", "yorick": "skull",
}

item_by_id = {i["id"]: i for i in items.values()}
npcs = []
npc_title_to_id = {}
for title, page in PAGES.items():
    text = expand_pagename(page["text"], title)
    box = infobox(text, "NPC Infobox")
    if not box:
        continue
    id_ = slug(title)
    npc_title_to_id[title] = id_
    day_field = box.get("day", "")
    if "later:" in day_field:
        day_field = day_field.split("later:")[1]
    days = [DAY_ID[d.lower()] for d in re.findall(r"\{\{\s*Day\s*\|([^}|]*)", day_field) if d.lower() in DAY_ID]
    npc = {
        "id": id_,
        "name": plain(box.get("name", "")) or title,
        "title": plain(box.get("role", "")) or plain(box.get("vendor", "")) or "Personaje",
        "location": plain(box.get("location", "")) or "?",
        "icon": NPC_ICONS.get(id_, "person"),
        "days": [d for _, d, *_ in DAYS if d in days],
    }
    sells, buys = [], []
    trading = section(text, "Trading") or section(text, "Trades")
    for sub, target in (("Selling", sells), ("Purchasing", buys)):
        for name, _, _ in items_in(section(trading, sub, 3)):
            iid = resolve_item(name)
            if iid and iid not in target:
                target.append(iid)
    npc["_sells"], npc["_buys"] = sells, buys
    npc["_text"] = text
    notes = []
    vendor = plain(box.get("vendor", ""))
    if vendor:
        notes.append(f"Comercia con: {vendor}.")
    if not days and day_field.strip() and "every" in day_field:
        notes.append(plain(box.get("day", "")))
    if notes:
        npc["notes"] = " ".join(notes)
    npcs.append(npc)

# "buy"/"sell" del infobox del objeto: desde el punto de vista del jugador
for title, box in item_meta.items():
    iid = items[title]["id"]
    for field, key in (("buy", "_sells"), ("sell", "_buys")):
        for link in re.findall(r"\[\[([^|\]]+)", box.get(field, "")):
            npc_id = npc_title_to_id.get(canonical(link))
            npc = next((n for n in npcs if n["id"] == npc_id), None)
            if npc and iid not in npc[key]:
                npc[key].append(iid)

for npc in npcs:
    sells, buys = npc.pop("_sells"), npc.pop("_buys")
    if sells:
        npc["sells"] = sells
    if buys:
        npc["buys"] = buys


# MARK: - Misiones y amistad

HEAD_RE = re.compile(r"^(={2,6})\s*(.*?)\s*=+\s*$", re.M)
HAPPY_RE = re.compile(
    r"\{\{\s*happiness\s*\|\s*(\+?)\s*\|?\s*(\d+)\s*\}\}"   # {{Happiness|+20}}, {{Happiness|+|10}}
    r"|(\+?)(\d+)\s*\{\{\s*happiness\s*\}\}"                # 10 {{Happiness}}
    r"|\{\{\s*happiness\s*\}\}\s*(\d+)"                     # {{Happiness}}30
    r"|(\+)(\d+)\s+(?:reputation|happiness)\b",             # +20 reputation
    re.I)
# ⟦+10⟧ = 10 de amistad que se ganan; ⟦10⟧ = nivel de amistad
TOKEN_RE = re.compile(r"⟦(\+?)(\d+)⟧")
DLCS = {"stranger sins": "Stranger Sins", "breaking dead": "Breaking Dead", "game of crone": "Game of Crone",
        "better save soul": "Better Save Soul"}
NOT_QUEST = re.compile(r"trad|sell|purchas|buying|trivia|notes?$|history|easter|loan|gallery|other cutscenes", re.I)
# frases que describen lo que te dan (los objetos que siguen a la palabra clave son la recompensa)
REWARD_RE = re.compile(
    r"\breward|\breceiv|(?<!need to )(?<!have to )(?<!must )\bget\b|\bgives? (?:you|him)\b|\bhands? (?:you|over)\b"
    r"|\bteach|\brecipes? (?:for|of)\b|\boffers? you\b|\bunlock|\bwill give\b|\bgrab", re.I)
REWARD_CUT = re.compile(r"\b(?:using|requires?|in exchange for|made (?:with|from)|if you bring)\b", re.I)
NEVER_GAIN = re.compile(r"should|total|now have|end up|up to|reset", re.I)
REQUIRES = re.compile(r"(?:\bat|reach\w*|need\w*|requir\w*|least|have|has|once|when)\W*(?:\w+\W+){0,2}$", re.I)
GAINS = re.compile(r"(?:earn|gain|receiv|get|reward|another|for|by|give[sn]?|increas|raise)\w*\W*(?:\w+\W+){0,3}$", re.I)
QUALITY_ES = {"copper": "bronce", "silver": "plata", "gold": "oro"}
DAY_ES = {en.lower(): short for en, _, _, short, *_ in DAYS}
npc_by_title = dict(npc_title_to_id)


def outline(text):
    """[(nivel, título, cuerpo)] de cada encabezado, en orden."""
    heads = list(HEAD_RE.finditer(text))
    return [(len(m.group(1)), m.group(2), text[m.end():heads[i + 1].start() if i + 1 < len(heads) else len(text)])
            for i, m in enumerate(heads)]


def mark_happiness(text):
    def repl(m):
        sign = m.group(1) or m.group(3) or m.group(6) or ""
        return f"⟦{sign}{m.group(2) or m.group(4) or m.group(5) or m.group(7)}⟧"
    return HAPPY_RE.sub(repl, text)


def money(copper):
    g, rest = divmod(int(copper), 10000)
    s, c = divmod(rest, 100)
    parts = [f"{n} {u}" for n, u in ((g, "oro"), (s, "plata"), (c, "cobre")) if n]
    return " ".join(parts) or "0 cobre"


def strip_tables(text):
    out, depth = [], 0
    for line in text.split("\n"):
        s = line.strip()
        if s.startswith("{|"):
            depth += 1
        elif s.startswith("|}"):
            depth = max(0, depth - 1)
        elif not depth:
            out.append(line)
    return "\n".join(out)


def rich(text):
    """Wikitext -> Markdown en línea: objetos y personajes como enlaces `gk2://item/<id>` y
    `gk2://character/<id>` (o en negrita si no existen), amistad como «10 ♥»."""
    def link(target, label):
        # ⟪tipo:id|texto⟫ hasta el final, para que no lo toquen las demás sustituciones
        title = canonical(target)
        if title in items and title not in TECH_POINTS:
            return f"⟪item:{items[title]['id']}|{label}⟫"
        if title in npc_by_title:
            return f"⟪character:{npc_by_title[title]}|{label}⟫"
        return None

    def item(m):
        name, qty, quality = m.group(1).strip(), (m.group(2) or "").strip(), (m.group(3) or "").strip().lower()
        out = link(name, name) or f"**{name}**"
        if qty.isdigit() and int(qty) > 1:
            out = f"{qty} × {out}"
        if quality in QUALITY_ES:
            out += f" ({QUALITY_ES[quality]})"
        return out
    t = re.sub(r"\[\[(?:[Ff]ile|[Ii]mage):(?:[^\[\]]|\[\[[^\]]*\]\])*\]\]", "", text)
    t = re.sub(r"<s>.*?</s>", "", t, flags=re.S)
    t = re.sub(r"<br\s*/?>", " ", t)
    t = re.sub(r"<[^>]+>", "", t)
    t = re.sub(r"\{\{\s*[Ii]tem\s*\|([^|}]*)(?:\|([^|}]*))?(?:\|([^|}]*))?[^}]*\}\}", item, t)
    t = re.sub(r"\{\{\s*[Mm]oney\s*\|\s*(\d+)\s*\}\}", lambda m: money(m.group(1)), t)
    t = re.sub(r"\{\{\s*[Dd]ay\s*\|([^|}]*)\}\}", lambda m: DAY_ES.get(m.group(1).strip().lower(), m.group(1)), t)
    t = re.sub(r"\{\{\s*[Qq]uality\s*\|([^|}]*)\}\}", lambda m: f"({QUALITY_ES.get(m.group(1).strip().lower(), m.group(1))})", t)
    t = re.sub(r"\{\{\s*[Tt]echpoint\s*\|([^|}]*)[^}]*\}\}", r"\1", t)
    t = re.sub(r"\{\{\s*[Gg]raveyard [Rr]ating\s*\}\}", "de valoración del cementerio", t)
    t = re.sub(r"\{\{\s*[Cc]hurch [Rr]ating\s*\}\}", "de valoración de la iglesia", t)
    t = re.sub(r"\{\{[^{}]*\}\}", "", t)
    t = re.sub(r"\[\[([^|\]]*)(?:\|([^\]]*))?\]\]",
               lambda m: link(m.group(1), (m.group(2) or m.group(1)).strip()) or (m.group(2) or m.group(1)), t)
    t = re.sub(r"\[https?://\S+\s*([^\]]*)\]", r"\1", t)
    t = re.sub(r"'''(.+?)'''", r"**\1**", t)
    t = t.replace("''", "")
    t = TOKEN_RE.sub(lambda m: f"{m.group(1)}{m.group(2)} ♥", t)
    t = re.sub(r"\*\*\s*\*\*", "", t)
    t = re.sub(r"⟪(\w+):(\w+)\|([^⟫]*)⟫",
               lambda m: f"[**{m.group(3).strip() or m.group(2)}**](gk2://{m.group(1)}/{m.group(2)})", t)
    return re.sub(r"\s+", " ", t).strip(" ,;")


def paragraphs(text):
    """Párrafos y viñetas de un cuerpo de sección."""
    out, buf = [], []
    for line in strip_tables(text).split("\n"):
        s = line.strip()
        if not s or s.startswith(("[[Category", "{{Navbox", "__")) or re.match(r"\[\[[a-z-]{2,5}:", s):
            if buf:
                out.append(" ".join(buf))
                buf = []
            continue
        m = re.match(r"^([*#:]+)\s*(.*)", s)
        if m:
            if buf:
                out.append(" ".join(buf))
                buf = []
            out.append(("• " if len(m.group(1)) == 1 else "   ◦ ") + m.group(2))
        else:
            buf.append(s)
    if buf:
        out.append(" ".join(buf))
    return [p for p in (rich(x) for x in out) if p.strip("•◦ ")]


def sentences(text):
    for line in strip_tables(text).split("\n"):
        yield from (s for s in re.split(r"(?<=[.!?])\s+(?=[A-Z\[{])", line) if s.strip())


def mentions(text, self_id):
    """Objetos y personajes enlazados en el texto, en orden de aparición."""
    items_found, npcs_found = [], []
    for m in re.finditer(r"\{\{\s*[Ii]tem\s*\|([^|}]*)|\[\[(?![Ff]ile:|[Ii]mage:|[Cc]ategory:)([^|\]]+)", text):
        title = canonical(m.group(1) or m.group(2))
        if not title or title in TECH_POINTS:
            continue
        if title in items and items[title]["id"] not in items_found:
            items_found.append(items[title]["id"])
        npc_id = npc_by_title.get(title)
        if npc_id and npc_id != self_id and npc_id not in npcs_found:
            npcs_found.append(npc_id)
    return items_found, npcs_found


def reward_items(text):
    found = []
    for s in sentences(text):
        m = REWARD_RE.search(s)
        if not m:
            continue
        tail = s[m.start():]
        cut = REWARD_CUT.search(tail)
        for iid in mentions(tail[:cut.start()] if cut else tail, None)[0]:
            if iid not in found:
                found.append(iid)
    return found


def happiness_marks(text):
    """[(valor, es_ganancia, es_requisito, posición)] de cada mención de amistad."""
    out = []
    for m in TOKEN_RE.finditer(text):
        before = plain(TOKEN_RE.sub(r"\2", text[max(0, m.start() - 80):m.start()]))[-50:]
        value, signed = int(m.group(2)), m.group(1) == "+"
        if NEVER_GAIN.search(before[-25:]):
            out.append((value, False, False, m.start()))
        elif signed:
            out.append((value, True, False, m.start()))
        elif REQUIRES.search(before):
            out.append((value, False, True, m.start()))
        else:
            out.append((value, bool(GAINS.search(before)), False, m.start()))
    return out


def dlc_of(title):
    return next((name for key, name in DLCS.items() if key in title.lower()), None)


def quest_sections(text):
    """(título, cuerpo, dlc) de cada misión: subsecciones de «Quests» o de las secciones de DLC."""
    ol = outline(text)

    def descendants(i):
        j = i + 1
        while j < len(ol) and ol[j][0] > ol[i][0]:
            j += 1
        return list(range(i + 1, j))

    def body(i):
        return ol[i][2] + "".join(f"\n'''{ol[k][1]}'''\n{ol[k][2]}" for k in descendants(i))

    def walk(i, dlc):
        title = plain(ol[i][1])
        dlc = dlc_of(title) or dlc
        desc = descendants(i)
        if not desc:
            if re.search(r"quest", title, re.I):
                yield "", ol[i][2], dlc
            return
        top = min(ol[k][0] for k in desc)
        for k in desc:
            if ol[k][0] != top:
                continue
            name = plain(re.sub(r"\{\{\s*happiness[^}]*\}\}", "", ol[k][1], flags=re.I))
            if NOT_QUEST.search(name) and "quest" not in name.lower():
                continue
            if re.fullmatch(r"quests?", name, re.I) or (dlc_of(name) and descendants(k)):
                yield from walk(k, dlc_of(name) or dlc)
            else:
                yield ol[k][1], body(k), dlc_of(name) or dlc

    for i, (level, title, _) in enumerate(ol):
        if level == 2 and (re.search(r"quest", title, re.I) or dlc_of(title)):
            yield from walk(i, None)


for npc in npcs:
    text = mark_happiness(npc.pop("_text"))
    quests, used = [], set()
    for heading, body, dlc in quest_sections(text):
        name = plain(re.sub(r"\(.*?DLC\)|⟦[^⟧]*⟧", "", heading)).strip() or "Encargos"
        qid = slug(name) or "encargos"
        n = 2
        while qid in used:
            qid, n = f"{slug(name)}_{n}", n + 1
        used.add(qid)
        paras = paragraphs(body)
        if not paras:
            continue
        mentioned, people = mentions(body, npc["id"])
        rewards = [i for i in reward_items(body) if i in mentioned]
        gain = sum(v for v, g, _, _ in happiness_marks(heading) + happiness_marks(body) if g)
        quest = {"id": qid, "name": name, "text": paras}
        if dlc:
            quest["dlc"] = dlc
        if gain:
            quest["friendship"] = gain
        if rewards:
            quest["rewards"] = rewards
        others = [i for i in mentioned if i not in rewards]
        if others:
            quest["items"] = others
        if people:
            quest["characters"] = people
        quests.append(quest)
    if quests:
        npc["quests"] = quests

    # niveles de amistad que desbloquean algo, en cualquier parte de la página salvo el comercio
    milestones = {}
    own_names = {npc["name"].lower(), npc["id"].replace("_", " ")}
    for level, title, body in outline(text):
        if NOT_QUEST.search(plain(title)):
            continue
        for s in sentences(body):
            marks = [v for v, _, req, _ in happiness_marks(s) if req]
            if not marks:
                continue
            items_found, people = mentions(s, npc["id"])
            # «con Snake» en la página de Horadric: es la amistad de otro personaje
            if people and not any(n in s.lower() for n in own_names):
                continue
            # «20 ♥ with [[Gerry]]» en la página de Gunter
            other = re.search(r"⟧\s*with (?:the )?\[\[([^|\]]+)", s)
            if other and npc_by_title.get(canonical(other.group(1))) not in (None, npc["id"]):
                continue
            if s.lstrip().startswith("("):  # aclaraciones sueltas entre paréntesis
                continue
            entry = {"level": max(marks), "text": rich(s)}
            if items_found:
                entry["items"] = items_found
            milestones.setdefault((entry["level"], entry["text"]), entry)
    if milestones:
        npc["friendship"] = sorted(milestones.values(), key=lambda m: m["level"])

# NPC sin comercio, días, misiones ni ubicación útil no aportan nada a la guía
npcs = [n for n in npcs if n.get("sells") or n.get("buys") or n.get("quests") or n["days"] or n["location"] != "?"]
npcs.sort(key=lambda n: n["name"])


# MARK: - Escritura

item_list = sorted({i["id"]: i for i in items.values()}.values(), key=lambda i: i["name"].lower())
ids = [i["id"] for i in item_list]
dupes = {i for i in ids if ids.count(i) > 1}
assert not dupes, f"ids duplicados: {dupes}"

days_json = [{"id": id, "name": name, "short": short, "icon": icon, "color": color} for _, id, name, short, icon, color in DAYS]


IMAGES = os.path.join(OUT, "Images")


def with_image(entry, stem):
    if os.path.exists(os.path.join(IMAGES, stem + ".png")):
        entry["image"] = stem
    return entry


for it in item_list:
    with_image(it, it["id"])
for n in npcs:
    with_image(n, "npc_" + n["id"])
for d in days_json:
    with_image(d, "day_" + d["id"])
stations = [with_image({"name": name}, "station_" + slug(name))
            for name in sorted({r["station"] for r in recipes})]


def write(name, data):
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


write("items", item_list)
write("recipes", recipes)
write("days", days_json)
write("characters", npcs)
write("stations", stations)
print(f"{len(item_list)} objetos · {len(recipes)} recetas · {len(npcs)} personajes · {len(days_json)} días")
