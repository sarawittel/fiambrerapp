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


# plantillas en línea con valor: se quedan como texto antes de quitar el resto
INLINE_TEMPLATES = [
    # «{{Energy||20 -}} {{Energy||36}}» -> «20–36 energy»
    (r"\{\{\s*(?:Energy|Health)\s*\|\s*[+-]?\s*\|?\s*(\d+)\s*-\s*\}\}\s*", lambda m: f"{m.group(1)}–"),
    (r"\{\{\s*(Energy|Health)\s*\|\s*[+-]?\s*\|?\s*(\d+)\s*\}\}", lambda m: f"{m.group(2)} {m.group(1).lower()}"),
    (r"\{\{\s*Money\s*\|\s*(\d+)\s*\}\}", lambda m: " ".join(
        f"{n} {u}" for n, u in ((int(m.group(1)) // 10000, "gold"), (int(m.group(1)) // 100 % 100, "silver"),
                                (int(m.group(1)) % 100, "copper")) if n)),
    (r"\{\{\s*(Energy|Health|Fuel)\s*\}\}", lambda m: m.group(1).lower()),
    # icono de decoración de las tumbas: «provides +3 {{Grave Decor}}» (salvo si ya lo dice: «to Grave Decor {{Grave Decor}}»)
    (r"(?<!Grave Decor )\{\{\s*Grave Decor\s*\}\}", lambda m: "grave decor"),
    (r"\{\{\s*Techpoint\s*\|\s*(\w+)\s*\|\s*(\d+)\s*\}\}", lambda m: f"{m.group(2)} {m.group(1).lower()} tech points"),
    (r"\{\{\s*(?:Item|NPC)\s*\|([^|}]*)[^{}]*\}\}", lambda m: f"[[{m.group(1).strip()}]]"),
]
# «Ms. Charm»: el punto no acaba la frase
ABBREVIATIONS = r"(?<!\bMs\.)(?<!\bMr\.)(?<!\bSt\.)(?<!\bDr\.)"


def intro(text):
    """Primera frase del artículo."""
    for pattern, repl in INLINE_TEMPLATES:
        text = re.sub(pattern, repl, text, flags=re.I)
    body = re.sub(r"\{\{[^{}]*\}\}", "", re.sub(r"\{\{[^{}]*\}\}", "", text))
    for para in body.split("\n"):
        para = para.strip()
        # «[[pt-br:Óleo de semente]]»: enlaces a la wiki en otros idiomas
        if re.match(r"\[\[[a-z]{2}(?:-[a-z]+)?\s*:", para):
            continue
        # «<b>Hops</b> are…»: la negrita no es una etiqueta de bloque
        lead = re.sub(r"^<(?:b|i|strong)>", "", para)
        if para and not lead.startswith(("{", "|", "!", "=", "[[Category", "[[File", "<", "*", "__")):
            s = plain(para)
            if len(s) > 20 and not re.search(r"unimplemented", s, re.I):
                first = re.split(ABBREVIATIONS + r"(?<=[.!?])\s", s, maxsplit=1)[0]
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


# MARK: - Tecnologías

POINTS = ("red", "green", "blue", "soul", "violet")
TECHPOINT_RE = re.compile(r"\{\{\s*[Tt]echpoint\s*\|\s*(\w+)\s*\|\s*(\d+)\s*\}\}")
UNLOCK_RE = re.compile(r"^\s*(Blueprint|Create|Extract|Gathering|Perk|Recipe)\s*:\s*(.*)$", re.S)


def split_cells(line, sep):
    """Parte una línea de tabla por `||`/`!!` fuera de plantillas y enlaces."""
    out, buf, depth, i = [], "", 0, 0
    while i < len(line):
        if line.startswith(("{{", "[["), i):
            depth, buf, i = depth + 1, buf + line[i:i + 2], i + 2
        elif line.startswith(("}}", "]]"), i) and depth:
            depth, buf, i = depth - 1, buf + line[i:i + 2], i + 2
        elif not depth and line.startswith(sep, i):
            out, buf, i = out + [buf], "", i + len(sep)
        else:
            buf, i = buf + line[i], i + 1
    return out + [buf]


def grid(text):
    """Filas de una tabla con los `rowspan` repetidos; cada fila es [(es_cabecera, texto_celda)]."""
    rows, pending = [], {}  # columna -> [filas que faltan, celda]
    raw = []
    for line in text.split("\n"):
        s = line.strip()
        if s.startswith("{|") or s.startswith("|}") or s.startswith("|+"):
            continue
        if s.startswith("|-"):
            raw.append([])
        elif s.startswith(("|", "!")):
            if not raw:
                raw.append([])
            header = s.startswith("!")
            for cell in split_cells(s[1:], "!!" if header else "||"):
                m = re.match(r'^\s*((?:[a-z-]+\s*=\s*"[^"]*"\s*)+)\|(?!\|)(.*)$', cell, re.S)
                attrs, body = (m.group(1), m.group(2)) if m else ("", cell)
                span = re.search(r'rowspan\s*=\s*"(\d+)"', attrs)
                raw[-1].append([header, body.strip(), int(span.group(1)) if span else 1])
        elif raw and raw[-1]:
            raw[-1][-1][1] += "\n" + s
    for cells in (r for r in raw if r):
        row, col = [], 0
        cells = list(cells)
        while cells or any(c >= col for c in pending):
            if col in pending:
                left, cell = pending[col]
                row.append(cell)
                pending[col][0] -= 1
                if pending[col][0] == 0:
                    del pending[col]
            elif cells:
                header, body, span = cells.pop(0)
                row.append((header, body))
                if span > 1:
                    pending[col] = [span - 1, (header, body)]
            else:
                break
            col += 1
        rows.append(row)
    return rows


def table_blocks(text):
    """(posición, texto) de cada tabla de primer nivel."""
    out, depth, start = [], 0, 0
    for m in re.finditer(r"^\s*(\{\||\|\})", text, re.M):
        if m.group(1) == "{|":
            if depth == 0:
                start = m.start()
            depth += 1
        elif depth:
            depth -= 1
            if depth == 0:
                out.append((start, text[start:m.end()]))
    return out


def tech_cost(cell):
    cost = {}
    for color, n in TECHPOINT_RE.findall(cell):
        color = color.lower()
        if color in POINTS:
            cost[color] = cost.get(color, 0) + int(n)
    return cost


def tech_condition(cell):
    rest = TECHPOINT_RE.sub("", re.sub(r"<hr\s*/?>", " ", cell))
    text = rich(rest)
    return None if not text or re.fullmatch(r"none|-", text, re.I) else text


def unlock_from(cell):
    """[{kind, name, item?}] de una celda de «Unlocks»."""
    m = UNLOCK_RE.match(cell.strip())
    if m:
        kind, rest = m.group(1).lower(), m.group(2)
        rest = re.split(r"\s+See\s+\[\[", rest)[0]
        link = re.search(r"\[\[([^|\]]+)(?:\|([^\]]*))?\]\]", rest)
        name = plain(rest)
        entry = {"kind": kind, "name": name}
        if link and kind != "perk":
            title = canonical(link.group(1))
            if title in items and title not in TECH_POINTS:
                entry["item"] = items[title]["id"]
        return [entry] if name else []
    # Cookery: lista de {{Item|...}}
    out = []
    if not ITEM_RE.search(cell):
        link = re.search(r"\[\[(?![Ff]ile:|[Ii]mage:)([^|\]]+)(?:\|([^\]]*))?\]\]", cell)
        if not link:
            return []
        title = canonical(link.group(1))
        entry = {"kind": "create", "name": plain(link.group(0))}
        if title in items:
            entry["item"] = items[title]["id"]
        return [entry]
    for name, _, _ in items_in(cell):
        title = canonical(name)
        entry = {"kind": "recipe", "name": title}
        if title in items:
            entry["item"] = items[title]["id"]
        if entry not in out:
            out.append(entry)
    return out


def tech_tree(title):
    text = expand_pagename(PAGES[title]["text"], title)
    # el texto de la wiki está en inglés: «reaching {{Graveyard Rating}} 5»
    text = re.sub(r"\{\{\s*[Gg]raveyard [Rr]ating\s*\}\}", "graveyard rating", text)
    text = re.sub(r"\{\{\s*[Cc]hurch [Rr]ating\s*\}\}", "church rating", text)
    heads = [(m.start(), plain(m.group(2))) for m in HEAD_RE.finditer(text) if len(m.group(1)) == 2]
    first = min([p for p, _ in heads] + [p for p, _ in table_blocks(text)] + [len(text)])
    branches, techs_by_name = [], {}
    for pos, block in table_blocks(text):
        rows = grid(block)
        if not rows or not all(h for h, _ in rows[0]):
            continue
        labels = [plain(c).lower() for _, c in rows[0]]
        if "technology" not in labels:
            continue
        col = lambda *keys: next((i for i, l in enumerate(labels) if any(k in l for k in keys)), None)
        c_name, c_req, c_cost, c_unl = col("technology"), col("prerequisite"), col("cost", "requirement"), col("unlock")
        heading = next((h for p, h in reversed(heads) if p < pos), None)
        branch_text = ""
        if heading:
            start = next(p for p, h in heads if h == heading)
            branch_text = text[start:pos].split("\n", 1)[1] if "\n" in text[start:pos] else ""
        branch = {"name": heading, "text": paragraphs(branch_text), "techs": []}
        for row in rows[1:]:
            if len(row) <= c_name or all(h for h, _ in row):
                continue
            cell = lambda i: row[i][1] if i is not None and i < len(row) else ""
            name_cell = cell(c_name)
            dlc = next((v for k, v in DLCS.items() if k in name_cell.lower()), None)
            name = plain(re.sub(r"''?\(.*?\)''?|\(\[\[.*?\]\]\)", "", name_cell)).strip()
            if not name:
                continue
            tech = techs_by_name.get((heading, name.lower()))
            if tech is None:
                tech = {"id": slug(name), "name": name, "_requires": cell(c_req)}
                cost = tech_cost(cell(c_cost))
                if cost:
                    tech["cost"] = cost
                condition = tech_condition(cell(c_cost))
                if condition:
                    tech["condition"] = condition
                if dlc:
                    tech["dlc"] = dlc
                tech["unlocks"] = []
                techs_by_name[(heading, name.lower())] = tech
                branch["techs"].append(tech)
            # en las tablas de 5 columnas la imagen va en `c_unl` y el texto en la siguiente
            for i in range(c_unl, len(row)):
                for u in unlock_from(cell(i)):
                    if u not in tech["unlocks"]:
                        tech["unlocks"].append(u)
        if branch["techs"]:
            branches.append(branch)

    used = set()
    for b in branches:
        for t in b["techs"]:
            base, n = t["id"], 2
            while t["id"] in used:
                t["id"], n = f"{base}_{n}", n + 1
            used.add(t["id"])
    # prerrequisitos por nombre, dentro del mismo árbol
    by_name = {t["name"].lower(): t["id"] for b in branches for t in b["techs"]}
    for b in branches:
        for t in b["techs"]:
            req_cell = t.pop("_requires")
            names = [plain(p).strip().lower() for p in re.split(r"\+|<br\s*/?>|,", req_cell)]
            requires = [by_name[n] for n in names if n in by_name and by_name[n] != t["id"]]
            if any(n and n not in by_name and n != "none" for n in names):
                # «[[Undertaker]] from Refugee camp ([[Game of Crone]] DLC)»: es una condición, no otra tecnología
                t["condition"] = " · ".join(x for x in (rich(req_cell), t.get("condition")) if x)
                t.setdefault("dlc", next((v for k, v in DLCS.items() if k in req_cell.lower()), None))
                if not t["dlc"]:
                    del t["dlc"]
            if requires:
                t["requires"] = requires
            if not t["unlocks"]:
                del t["unlocks"]
        if not b["name"]:
            del b["name"]
        if not b["text"]:
            del b["text"]
    name = title.removesuffix(" (Tech Tree)")
    tree = {"id": slug(name), "name": name, "text": paragraphs(text[:first]), "branches": branches}
    if not tree["text"]:
        del tree["text"]
    # «it is part of the [[Better Save Soul]] DLC»
    dlc = re.search(r"\bis part of the \[*([^\]]+?)\]* DLC", text[:first])
    if dlc and dlc_of(dlc.group(1)):
        tree["dlc"] = dlc_of(dlc.group(1))
    return tree


# en el orden de la página «Technologies»
tech_titles = [canonical(m) for m in re.findall(r"\[\[([^|\]]+\(Tech Tree\))", PAGES["Technologies"]["text"])]
technologies = [tech_tree(t) for t in dict.fromkeys(tech_titles) if t in PAGES]


# MARK: - Guía de logros

GUIDE_PAGE = "100% Achievement Guide"


def achievement_guide():
    """Secciones de la guía de logros, cada una con sus logros en el orden de la wiki."""
    text = PAGES[GUIDE_PAGE]["text"]
    # notas de editores entre «###»: «### Someone please edit this… ###»
    text = re.sub(r"###.*?###", "", text, flags=re.S)
    sections, used = [], set()
    for level, heading, body in outline(text):
        if level != 2:
            continue
        blocks = table_blocks(body)
        if not blocks:
            continue
        pos, block = blocks[0]
        section = {"id": slug(heading), "name": plain(heading), "achievements": []}
        if "mw-collapsed" in block.split("\n", 1)[0] or re.search(r"spoiler", body[:pos], re.I):
            section["spoiler"] = True
        for row in grid(block):
            if len(row) < 3 or any(h for h, _ in row):
                continue
            icon, name, desc = (c for _, c in row[:3])
            name = plain(name)
            if not name:
                continue
            ach = {"id": slug(name), "name": name, "text": paragraphs(desc)}
            base, n = ach["id"], 2
            while ach["id"] in used:
                ach["id"], n = f"{base}_{n}", n + 1
            used.add(ach["id"])
            if re.search(r"missable", desc, re.I):
                ach["missable"] = True
            if dlc_of(desc):
                ach["dlc"] = dlc_of(desc)
            found_items, found_npcs = mentions(desc, None)
            if found_items:
                ach["items"] = found_items
            if found_npcs:
                ach["characters"] = found_npcs
            section["achievements"].append(ach)
        if section["achievements"]:
            sections.append(section)
    return sections


guide = achievement_guide() if GUIDE_PAGE in PAGES else []


# MARK: - Calidad y estudio de los objetos

QUALITIES = ("copper", "silver", "gold")
STAR_RE = re.compile(r"(Bronze|Silver|Gold) Star", re.I)
MONEY_RE = re.compile(r"\{\{\s*Money\s*\|\s*(\d+)\s*\}\}", re.I)
ENERGY_RE = re.compile(r"\{\{\s*Energy\s*\|\s*([+-])\s*\|\s*(\d+)\s*\}\}", re.I)


def expand_colspans(table):
    """`colspan="2"|N/A` -> `N/A||N/A` en las filas de datos, para que cada celda caiga en su columna."""
    def repl(m):
        return "||".join([m.group(2).strip()] * int(m.group(1)))
    return re.sub(r'colspan\s*=\s*"(\d+)"\s*\|(?!\|)\s*([^|\n]*)', repl, table)


def quality_levels(text):
    """{calidad: {energy, value}} de la tabla «Quality Levels»/«Quality»: una columna por calidad."""
    sec = section(text, r"Quality(?: Levels)?")
    out = {}
    for _, table in table_blocks(sec):
        for row in grid(table):
            cells = [c for h, c in row if not h]
            if len(cells) != len(QUALITIES):
                continue
            for q, cell in zip(QUALITIES, cells):
                e, m = ENERGY_RE.search(cell), MONEY_RE.search(cell)
                if e:
                    out.setdefault(q, {})["energy"] = int(e.group(2)) * (-1 if e.group(1) == "-" else 1)
                if m:
                    out.setdefault(q, {})["value"] = int(m.group(1))
    return out


def trading_prices(text):
    """{calidad: {buy, sell}} de la tabla «Trading»: la primera columna de precio es lo que cuesta
    comprarlo y la segunda lo que pagan al venderlo. Si lo comercian varios personajes, manda el primero."""
    out = {}
    for _, table in table_blocks(section(text, "Trading")):
        rows = grid(expand_colspans(table))
        head = next((r for r in rows if all(h for h, _ in r)), None)
        if not head:
            continue
        # «! NPC !! Quality || Buy Tier»: algunas cabeceras mezclan separadores
        columns = [c.strip().lower() for _, cell in head for c in re.split(r"\|\||!!", plain(cell))]
        prices = [i for i, c in enumerate(columns) if "cost" in c or "price" in c]
        if "quality" not in columns or not prices:
            continue
        qcol = columns.index("quality")
        for row in rows:
            if row is head or len(row) <= qcol:
                continue
            star = STAR_RE.search(row[qcol][1])
            if not star:
                continue
            q = QUALITIES[("bronze", "silver", "gold").index(star.group(1).lower())]
            if q in out:
                continue
            entry = {}
            for key, col in zip(("buy", "sell"), prices):
                m = MONEY_RE.search(row[col][1]) if col < len(row) else None
                if m:
                    entry[key] = int(m.group(1))
            if entry:
                out[q] = entry
    return out


def study_of(text):
    """Lo que da y cuesta estudiarlo en la mesa de estudio."""
    for _, table in table_blocks(section(text, "Study")):
        for row in grid(table):
            cells = [c for h, c in row if not h]
            if len(cells) < 2 or not TECHPOINT_RE.search(cells[0]):
                continue
            study = {"points": tech_cost(cells[0])}
            for name, qty, _ in items_in(cells[1]):
                if canonical(name) in ("Faith", "Science"):
                    study[canonical(name).lower()] = qty
            e = ENERGY_RE.search(" ".join(cells[2:3]))
            if e:
                study["energy"] = int(e.group(2))
            notes = " ".join(cells[3:4])
            if re.search(r"decompos", notes, re.I) and not re.search(r"not decompos", notes, re.I):
                parts = []
                for link in re.findall(r"\[\[([^|\]]+)", notes) + [n for n, _, _ in items_in(notes)]:
                    title = canonical(link)
                    if title in items and items[title]["id"] not in parts:
                        parts.append(items[title]["id"])
                if parts:
                    study["decomposes"] = parts
            if study["points"]:
                return study
    return None


for title in item_meta:
    text = expand_pagename(PAGES[title]["text"], title)
    levels, prices = quality_levels(text), trading_prices(text)
    if levels or prices or re.search(r"\{\{\s*Quality Sprite", section(text, r"Quality(?: Levels)?"), re.I):
        quality = [{"level": q, **levels.get(q, {}), **prices.get(q, {})} for q in QUALITIES]
        for entry in quality:  # el precio de la tabla de calidad suele ser el de compra
            if entry.get("value") == entry.get("buy"):
                entry.pop("value", None)
        items[title]["quality"] = quality
    study = study_of(text)
    if study:
        items[title]["study"] = study


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
for tree in technologies:
    with_image(tree, "tech_" + tree["id"])
for section in guide:
    for ach in section["achievements"]:
        with_image(ach, "ach_" + ach["id"])
stations = [with_image({"name": name}, "station_" + slug(name))
            for name in sorted({r["station"] for r in recipes})]


# MARK: - Traducción

# es.json: texto en inglés tal como sale de la conversión -> traducción al español.
# Los nombres de personajes y lugares se quedan en inglés, como en la wiki; los de objetos van en es_items.json
# y los de estaciones y tecnologías, en es_names.json.
# Si la wiki cambia un texto, su traducción deja de coincidir y sale en inglés hasta que se traduzca.
ES_PATH = os.path.join(HERE, "es.json")
ES = json.load(open(ES_PATH)) if os.path.exists(ES_PATH) else {}
LINK_RE = re.compile(r"\]\((gk2://[^)]+)\)")
untranslated = set()
DAY_SHORT_ID = {short: id for _, id, _, short, *_ in DAYS}
DAY_RE = re.compile(r"\b(" + "|".join(DAY_SHORT_ID) + r")\b")


def day_icons(source, text):
    """En el juego los días no tienen nombre: se escriben como icono, `![Orgullo](gk2://day/orgullo)`.
    Solo los que ya salían en el texto original (de {{Day|…}}): en español, «Ira» u «orgullo» también es el pecado."""
    days = set(DAY_RE.findall(source))
    return DAY_RE.sub(lambda m: f"![{m.group(1)}](gk2://day/{DAY_SHORT_ID[m.group(1)]})"
                      if m.group(1) in days else m.group(0), text)


def es(text):
    if not text:
        return text
    t = ES.get(text)
    # la traducción tiene que llevar los mismos enlaces, en el mismo orden
    if t and LINK_RE.findall(t) == LINK_RE.findall(text):
        return day_icons(text, t)
    untranslated.add(text)
    return day_icons(text, text)


def translate(entry, *keys):
    for key in keys:
        value = entry.get(key)
        if isinstance(value, list):
            entry[key] = [es(v) for v in value]
        elif isinstance(value, str):
            entry[key] = es(value)


# orígenes genéricos (actividades y recursos); los que son estaciones, personajes o lugares se quedan igual
SOURCE_ES = {
    "Alchemy": "Alquimia", "Apple trees": "Manzanos", "Autopsy": "Autopsia", "Bat": "Murciélagos",
    "Beekeeping": "Apicultura", "Berry bushes": "Arbustos de bayas", "Bushes": "Arbustos", "Cooking": "Cocina",
    "Corpse": "Cadáveres", "Daytime flowers": "Flores de día", "Dig": "Excavar", "Dig Spot": "Punto de excavación",
    "Dungeon pots": "Vasijas de la mazmorra", "Eel": "Anguilas", "Farming": "Cultivo", "Foraging": "Recolección",
    "Graves": "Tumbas", "Green slimes": "Limos verdes", "Hives": "Colmenas", "Iron Ore Deposit": "Veta de hierro",
    "Mining": "Minería", "NPCs": "Personajes", "Nighttime flowers": "Flores de noche", "Quest": "Encargos",
    "River": "Río", "Ruined Bookcases": "Estanterías en ruinas", "Sea": "Mar", "Sermon": "Sermones",
    "Sermons": "Sermones", "Stone Deposit": "Veta de piedra", "Tree": "Árboles", "Trees": "Árboles", "Well": "Pozo",
    "Wild hives": "Colmenas silvestres", "Workstations": "Estaciones de trabajo", "Writing": "Escritura",
}

for it in item_list:
    translate(it, "description")
    if "sources" in it:
        it["sources"] = list(dict.fromkeys(SOURCE_ES.get(s, s) for s in it["sources"]))
for n in npcs:
    translate(n, "title", "notes")
    for q in n.get("quests", []):
        translate(q, "text")
    for f in n.get("friendship", []):
        translate(f, "text")
for tree in technologies:
    translate(tree, "text")
    for b in tree["branches"]:
        translate(b, "text")
        for t in b["techs"]:
            translate(t, "condition")
for section in guide:
    for ach in section["achievements"]:
        translate(ach, "text")

# es_items.json: nombre del objeto en la wiki -> nombre en español; el de la wiki queda en `wikiName`
ES_ITEMS_PATH = os.path.join(HERE, "es_items.json")
ES_ITEMS = json.load(open(ES_ITEMS_PATH)) if os.path.exists(ES_ITEMS_PATH) else {}
wiki_name = {it["id"]: it["name"] for it in item_list}
untranslated_items = []
for it in item_list:
    name = ES_ITEMS.get(it["name"])
    if not name:
        untranslated_items.append(it["name"])
    elif name != it["name"]:
        it["wikiName"], it["name"] = it["name"], name
es_name = {it["id"]: it["name"] for it in item_list}


# es_labels.json: textos de enlace que no son el nombre del objeto o personaje («autopsies», «Clotho's»)
ES_LABELS_PATH = os.path.join(HERE, "es_labels.json")
ES_LABELS = json.load(open(ES_LABELS_PATH)) if os.path.exists(ES_LABELS_PATH) else {}


def relabel(text):
    """Textos de enlace en inglés: el nombre de la wiki pasa a ser el nombre en español;
    los demás se buscan en es_labels.json."""
    def repl(m):
        label, kind, iid = m.group(1), m.group(2), m.group(3)
        if kind == "item" and iid in es_name and label.strip().lower() == wiki_name[iid].lower():
            label = es_name[iid]
        else:
            label = ES_LABELS.get(label, label)
        return f"[**{label}**](gk2://{kind}/{iid})"
    return re.sub(r"\[\*\*([^*]+)\*\*\]\(gk2://(item|character)/(\w+)\)", repl, text) if text else text


def relabel_all(entry, *keys):
    for key in keys:
        value = entry.get(key)
        if isinstance(value, list):
            entry[key] = [relabel(v) for v in value]
        elif isinstance(value, str):
            entry[key] = relabel(value)


for n in npcs:
    for q in n.get("quests", []):
        relabel_all(q, "text")
    for f in n.get("friendship", []):
        relabel_all(f, "text")
for tree in technologies:
    relabel_all(tree, "text")
    for b in tree["branches"]:
        relabel_all(b, "text")
        for t in b["techs"]:
            relabel_all(t, "condition")
for section in guide:
    for ach in section["achievements"]:
        relabel_all(ach, "text")

# listas en orden alfabético del nombre en español; `sort` es estable, así que se mantiene
# el orden de las recetas de un mismo objeto (la primera es la que usa el planificador)
item_list.sort(key=lambda i: i["name"].lower())
recipes.sort(key=lambda r: es_name.get(r["output"], r["output"]).lower())

# es_names.json: estaciones y nombres de tecnologías (árboles, ramas, tecnologías y lo que desbloquean)
ES_NAMES_PATH = os.path.join(HERE, "es_names.json")
ES_NAMES = json.load(open(ES_NAMES_PATH)) if os.path.exists(ES_NAMES_PATH) else {}
untranslated_names = set()


def es_label(name):
    if name in ES_NAMES:
        return ES_NAMES[name]
    untranslated_names.add(name)
    return name


for r in recipes:
    r["station"] = es_label(r["station"])
for st in stations:
    name = es_label(st["name"])
    if name != st["name"]:
        st["wikiName"], st["name"] = st["name"], name
stations.sort(key=lambda s: s["name"].lower())
for it in item_list:
    if "sources" in it:
        # los orígenes pueden ser estaciones u objetos (p. ej. «Pail of apple juice»)
        it["sources"] = list(dict.fromkeys(ES_NAMES.get(s) or ES_ITEMS.get(s) or s for s in it["sources"]))
for tree in technologies:
    tree["name"] = es_label(tree["name"])
    for b in tree["branches"]:
        if b.get("name"):
            b["name"] = es_label(b["name"])
        for t in b["techs"]:
            t["name"] = es_label(t["name"])
            for u in t.get("unlocks", []):
                u["name"] = es_name[u["item"]] if u.get("item") else es_label(u["name"])

# es_quests.json: títulos de los encargos; si el título es el nombre de un objeto se usa su nombre en español.
# El id del encargo sigue saliendo del título en inglés (AppState.doneQuests depende de él).
ES_QUESTS_PATH = os.path.join(HERE, "es_quests.json")
ES_QUESTS = json.load(open(ES_QUESTS_PATH)) if os.path.exists(ES_QUESTS_PATH) else {}
item_by_wiki_name = {name.lower(): iid for iid, name in wiki_name.items()}
untranslated_quests = set()
for n in npcs:
    for q in n.get("quests", []):
        if q["name"] == "Encargos":
            continue
        iid = item_by_wiki_name.get(q["name"].lower())
        name = ES_QUESTS.get(q["name"]) or (es_name[iid] if iid else None)
        if name:
            q["name"] = name
        else:
            untranslated_quests.add(q["name"])

# es_achievements.json: nombres de los logros; el de la wiki queda en `wikiName` (el id sale del nombre en inglés)
ES_ACHS_PATH = os.path.join(HERE, "es_achievements.json")
ES_ACHS = json.load(open(ES_ACHS_PATH)) if os.path.exists(ES_ACHS_PATH) else {}
untranslated_achs = set()
for section in guide:
    for ach in section["achievements"]:
        name = ES_ACHS.get(ach["name"])
        if not name:
            untranslated_achs.add(ach["name"])
        elif name != ach["name"]:
            ach["wikiName"], ach["name"] = ach["name"], name

# en los textos, los logros citados en inglés («el logro "Night watch"») pasan a «Guardia nocturna»
ACH_EN = sorted(ES_ACHS, key=len, reverse=True)
ACH_RE = re.compile(r"[\"«“](" + "|".join(re.escape(n.rstrip("!.")) for n in ACH_EN) + r")[!.]*[\"»”]") if ACH_EN else None
ach_es = {n.rstrip("!.").lower(): es for n, es in ES_ACHS.items()}


def ach_names(text):
    if not text or not ACH_RE:
        return text
    return ACH_RE.sub(lambda m: f"«{ach_es[m.group(1).lower()]}»", text)

# es_characters.json: personajes sin nombre propio («Beekeeper» -> «Apicultor»); el de la wiki queda en `wikiName`.
# Los nombres propios (Clotho, Snake…) se quedan en inglés.
ES_CHARS_PATH = os.path.join(HERE, "es_characters.json")
ES_CHARS = json.load(open(ES_CHARS_PATH)) if os.path.exists(ES_CHARS_PATH) else {}
for n in npcs:
    name = ES_CHARS.get(n["name"])
    if name:
        n["wikiName"], n["name"] = n["name"], name
npcs.sort(key=lambda n: n["name"].lower())
for it in item_list:
    if "sources" in it:
        it["sources"] = list(dict.fromkeys(ES_CHARS.get(s, s) for s in it["sources"]))

# en los textos, «a Bishop» -> «al Obispo», «con [**Bishop**](…)» -> «con el [**Obispo**](…)».
# No se tocan los nombres compuestos («Barman Doll», «Farmer's light»).
# «Fresh Eggs» es una cesta y ya tiene su etiqueta en es_labels.json.
CHAR_EN = sorted((n for n in ES_CHARS if n != "Fresh Eggs"), key=len, reverse=True)
CHAR_FEM = {"Tanner"}
CHAR_RE = re.compile(r"(\(gk2://[^)]*\))|(?:\b(\w+) )?(\[\*\*)?\b(" + "|".join(map(re.escape, CHAR_EN)) + r")\b(?!'s| [A-Z])") if CHAR_EN else None
KEEP = {"el", "al", "del", "la", "su", "tu"}


def char_names(text):
    if not text or not CHAR_RE:
        return text

    def repl(m):
        if m.group(1):
            return m.group(1)  # destino de un enlace
        prev, link, en = m.group(2), m.group(3) or "", m.group(4)
        name, fem = ES_CHARS[en], en in CHAR_FEM
        if prev and prev.lower() in KEEP:
            return f"{prev} {link}{name}"
        if prev and prev.lower() in ("a", "de"):
            art = f"{prev} la" if fem else {"a": "al", "de": "del"}[prev.lower()]
            return f"{prev[0]}{art[1:]} {link}{name}"
        start = m.start(3) if link else m.start(4)
        before = text[:start].rstrip()
        art = "la" if fem else "el"
        if prev is None and (not before or before[-1] in ".:!?•◦"):
            art = art.capitalize()
        return (f"{prev} " if prev else "") + f"{art} {link}{name}"
    return CHAR_RE.sub(repl, text)

# en los textos traducidos, los nombres de estación que quedaron en inglés («en la Study table»)
STATION_EN = sorted({st["wikiName"] for st in stations if "wikiName" in st}, key=len, reverse=True)
STATION_RE = re.compile(r"(\[[^\]]*\]\([^)]*\))|\b(" + "|".join(map(re.escape, STATION_EN)) + r")\b") if STATION_EN else None
station_es = {st["wikiName"]: st["name"] for st in stations if "wikiName" in st}


def station_names(text):
    if not text or not STATION_RE:
        return char_names(ach_names(text))
    # los enlaces se dejan tal cual; solo se cambian los nombres sueltos
    return char_names(ach_names(STATION_RE.sub(lambda m: m.group(1) or station_es[m.group(2)], text)))


def station_names_all(entry, *keys):
    for key in keys:
        value = entry.get(key)
        if isinstance(value, list):
            entry[key] = [station_names(v) for v in value]
        elif isinstance(value, str):
            entry[key] = station_names(value)


for it in item_list:
    station_names_all(it, "description")
for n in npcs:
    station_names_all(n, "notes")
    for q in n.get("quests", []):
        station_names_all(q, "text")
    for f in n.get("friendship", []):
        station_names_all(f, "text")
for tree in technologies:
    station_names_all(tree, "text")
    for b in tree["branches"]:
        station_names_all(b, "text")
        for t in b["techs"]:
            station_names_all(t, "condition")
for section in guide:
    for ach in section["achievements"]:
        station_names_all(ach, "text")


def write(name, data):
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


write("items", item_list)
write("recipes", recipes)
write("days", days_json)
write("characters", npcs)
write("stations", stations)
write("technologies", technologies)
write("guide", guide)
n_techs = sum(len(b["techs"]) for t in technologies for b in t["branches"])
n_achs = sum(len(s["achievements"]) for s in guide)
print(f"{len(item_list)} objetos · {len(recipes)} recetas · {len(npcs)} personajes · {len(days_json)} días"
      f" · {n_techs} tecnologías en {len(technologies)} árboles · {n_achs} logros")
if untranslated:
    print(f"{len(untranslated)} textos sin traducir (añádelos a es.json)")
if untranslated_items:
    print(f"{len(untranslated_items)} nombres de objetos sin traducir (añádelos a es_items.json)")
if untranslated_names:
    print(f"{len(untranslated_names)} nombres de estaciones o tecnologías sin traducir (añádelos a es_names.json)")
if untranslated_quests:
    print(f"{len(untranslated_quests)} títulos de encargos sin traducir (añádelos a es_quests.json): {sorted(untranslated_quests)}")
if untranslated_achs:
    print(f"{len(untranslated_achs)} nombres de logros sin traducir (añádelos a es_achievements.json): {sorted(untranslated_achs)}")
