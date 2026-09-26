#!/usr/bin/env python3
"""Convierte las páginas de la wiki de Graveyard Keeper 2 (cache/pages, de fetch.py)
a GK2Core/Data/GK2/items.json, recipes.json, characters.json, technologies.json, walkthrough.json y
guide.json, y descarga sus
iconos a Data/GK2/Images.

- Páginas de «Items and Materials»: un objeto cada una.
- Páginas de «Crafting Recipes» (por familia de estaciones): solo recetas.
- Tablas de recetas (Output / Ingredients / Station and unlock, o su variante «per batch») y la de
  collares de la Mesa de joyería: recetas automáticas. Las repetidas entre páginas se juntan.
- Páginas que son guías en prosa: recetas y orígenes de guide.json, y su primer párrafo como descripción.
- Los ingredientes que no tienen página también son objetos (sin descripción).
- Páginas de «Technology Costs»: un árbol de tecnología cada una; lo que desbloquean sale de las recetas.
- «Talents and Inspirations»: un árbol más, con las inspiraciones de primer nivel de su tabla.
- «Beginner Walkthrough»: la guía para principiantes (hitos y pasos), con los objetos y personajes que nombra.
- «Graveyard Keeper 2 Achievements»: los logros, un apartado por tabla (guide.json).
- Guías que enlaza «Quests»: las misiones, en `quests` de quien las da (characters.json).

Traducciones: es_items.json (objetos), es_names.json (estaciones, extensiones, tecnologías y ventajas),
es_achievements.json (logros), es_quests.json (misiones; también en los textos), es.json (descripciones). Lo que falte se avisa al final.
"""
import html, json, os, re, shutil, sys, time, unicodedata, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
PAGES = os.path.join(HERE, "cache", "pages")
OUT = os.path.join(HERE, "..", "..", "Packages", "GK2Core", "Sources", "GK2Core", "Data", "GK2")
IMAGES = os.path.join(OUT, "Images")
# datos de GK1: solo para sacar la imagen de las construcciones que la wiki de GK2 no tiene
GK1_DATA = os.path.join(OUT, "..")
INDEX = "Items_and_Materials"
RECIPES_INDEX = "Crafting_Recipes"
# páginas de recetas que «Crafting Recipes» solo enlaza en «What to do next» (también en fetch.py)
EXTRA_RECIPE_PAGES = ["Cooking_Recipes", "Alchemy_Recipes"]
# categoría por defecto de lo que aparece por primera vez en una página de recetas
PAGE_CATEGORY = {"Cooking_Recipes": "comida", "Alchemy_Recipes": "alquimia"}
CHARACTERS_INDEX = "Characters"
# quién vende cada material y desde qué nivel de comercio (también en fetch.py)
BUY_PAGE = "Where_to_Buy_Materials"
# nombres que la wiki escribe de otra forma en otra página
ITEM_ALIASES = {"Flax Seed": "Flax Seeds"}
# costes de construcción por zona (también en fetch.py)
CONSTRUCTION_PAGE = "Workshop_Construction"
# zona de las tablas de construcción de otras páginas que no la dicen en la tabla
PAGE_AREA = {"Zombie_Gardening": "Garden"}
# construcciones que la wiki no sitúa en ninguna zona
NO_AREA = "Unknown area"
UA = {"User-Agent": "Mozilla/5.0 (Macintosh) gk-guia/1.0 (personal guide)"}


def load(name):
    with open(os.path.join(HERE, name)) as f:
        return json.load(f)


ES_ITEMS, ES_NAMES, ES = load("es_items.json"), load("es_names.json"), load("es.json")
GUIDE = load("guide.json")
missing = {"es_items.json": set(), "es_names.json": set(), "es.json": set()}


GRADES = {"bronze": "bronce", "silver": "plata", "gold": "oro"}
GRADE = re.compile(r"^(.+) \((bronze|silver|gold)\)$")


def item_es(name):
    # las calidades son objetos distintos: «Wine (silver)» → «Vino (plata)»
    if m := GRADE.match(name):
        return f"{item_es(m.group(1))} ({GRADES[m.group(2)]})"
    if name in ES_ITEMS:
        return ES_ITEMS[name]
    # las construcciones son también estaciones: se llaman como ellas
    if name in ES_NAMES:
        return ES_NAMES[name]
    missing["es_items.json"].add(name)
    return name


def name_es(name):
    if name not in ES_NAMES:
        missing["es_names.json"].add(name)
    return ES_NAMES.get(name, name)


def slug(title):  # igual que en scripts/wiki/convert.py
    s = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")


def text(fragment):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", fragment))).strip()


def content(page):
    with open(os.path.join(PAGES, page + ".html")) as f:
        s = f.read()
    return s[s.find('id="siteSub"'):s.find("NewPP limit report")]


def tables(body):
    """[[celdas de cada fila]] de cada tabla, cabecera incluida"""
    return [[[text(c) for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", tr, re.S)]
             for tr in re.findall(r"<tr>(.*?)</tr>", t, re.S)]
            for t in re.findall(r"<table.*?</table>", body, re.S)]


# MARK: - Índice

def linked_pages(page):
    """páginas enlazadas desde las listas del artículo, antes de «What to do next» (como fetch.py)"""
    body = content(page)
    return list(dict.fromkeys(re.findall(r'<li><a href="/([^"#]+)" title="[^"]+">', body[:body.find('id="What_to_do_next"')])))


def index_pages():
    """[(página, título, sección)] en el orden de «Items and Materials»"""
    body = content(INDEX)
    body = body[:body.find('id="What_to_do_next"')]
    out, section = [], None
    for m in re.finditer(r'<span class="mw-headline" id="[^"]+">(.*?)</span>|<li><a href="/([^"#]+)" title="([^"]+)">', body):
        if m.group(1):
            section = text(m.group(1))
        else:
            out.append((m.group(2), html.unescape(m.group(3)), section))
    return out


SECTION_CATEGORY = {
    "Wood, fuel and construction kits": "material",
    "Metals, glass and workshop materials": "material",
    "Faith, alchemy and quest supplies": "alquimia",
    "Crops, writing and tools": "material",
}
# categoría de los objetos que no la sacan de su sección (o la tienen mal)
CATEGORY = {
    "Basic Rod": "herramienta", "Blood": "funerario", "Skull": "funerario", "Fat": "funerario",
    "Tooth": "funerario", "Leaf": "alquimia", "Salt": "alquimia", "Wine": "alquimia",
    "Philosopher Stone": "alquimia", "Faith": "funerario", "Charged hypno-device": "alquimia",
    "Alchemy Flasks I": "alquimia", "Alchemy Flasks II": "alquimia", "Empty Bottle": "alquimia",
    "Prosthetic Hand": "funerario", "Elegant Prosthetic Hand": "funerario",
    "Wheat": "comida", "Beer": "comida", "Comet's Tail": "alquimia",
    "Flour": "comida", "Lacquer": "alquimia", "Spices": "alquimia", "Umami": "alquimia", "Firefly": "alquimia", "Flesh": "funerario",
}
# herramientas por palabra clave del nombre en inglés
TOOLS = ("Axe", "Pickaxe", "Hammer", "Shovel", "Rod", "Chisel", "tools")

# sprite de 8x8 (Sprites.all) para los objetos sin imagen, por palabra clave del nombre en inglés
SPRITES = [
    ("potion", "potion"), ("elixir", "potion"), ("alkali", "potion"), ("preservative", "potion"),
    ("goo", "potion_dark"), ("improver", "heart"), ("hops", "herb"),
    # comida primero: «Fish nuggets» no es una pepita ni «Breadcrumb Bait» un pan
    ("bait", "sack"), ("fish", "meat"), ("fillet", "meat"), ("salmon", "meat"), ("carp", "meat"),
    ("catfish", "meat"), ("kraken", "meat"), ("silverfin", "meat"), ("ghost", "meat"), ("flesh", "meat"),
    ("meat", "burger"), ("meal", "burger"), ("cutlet", "burger"), ("lasagna", "burger"), ("stew", "burger"),
    ("soup", "burger"), ("bread", "bread"), ("dough", "bread"), ("pie", "bread"), ("muffin", "bread"),
    ("croissant", "bread"), ("toast", "bread"), ("chocolate", "bread"), ("cacao", "wheat"), ("flour", "sack"),
    ("smoothie", "potion"), ("yogurt", "water"), ("milk", "water"), ("juice", "potion"), ("honey", "wax"),
    ("egg", "bone"), ("firefly", "candle"), ("lacquer", "potion"), ("spices", "sack"), ("umami", "sack"),
    ("sauerkraut", "herb"), ("salad", "herb"), ("apple", "herb"), ("berry", "herb"), ("beet", "herb"),
    ("carrot", "herb"), ("cabbage", "herb"), ("onion", "herb"), ("pumpkin", "herb"), ("mushroom", "herb"),
    ("frog", "herb"),
    ("collar", "crown"), ("prosthetic", "person"), ("chair", "chest"), ("supply", "chest"),
    ("axe", "anvil"), ("hammer", "anvil"), ("shovel", "anvil"), ("chisel", "anvil"), ("tools", "anvil"),
    ("press", "anvil"), ("mechanism", "anvil"), ("gear", "nails"), ("screws", "nails"), ("joint", "plank"),
    ("beam", "plank"), ("wedge", "plank"), ("trinkets", "coin"), ("money", "coin"), ("notebook", "scroll"),
    ("notes", "scroll"), ("science", "scroll"), ("bottle", "potion"), ("flask", "potion"), ("lens", "eye"),
    ("marble", "stone"), ("sculpture", "stone"), ("urn", "stone"), ("plate", "stone"), ("tableware", "stone"),
    ("molds", "stone"), ("containers", "water"), ("fabric", "sack"), ("crate", "chest"), ("power", "heart"),
    ("faith", "candle"), ("skull", "skull"), ("tooth", "bone"), ("blood", "heart"), ("fat", "fat"),
    ("board", "plank"), ("plank", "plank"), ("log", "log"), ("wood", "log"), ("stick", "log"),
    ("nugget", "ore"), ("ore", "ore"), ("scrap", "ore"), ("coal", "ore"), ("tin", "ore"),
    ("ingot", "ingot"), ("nails", "nails"), ("detail", "nails"), ("bronze", "ingot"),
    ("kit", "chest"), ("stone", "stone"), ("brick", "stone"), ("clay", "stone"), ("sand", "stone"),
    ("glass", "water"), ("water", "water"), ("paper", "scroll"), ("scroll", "scroll"), ("ink", "potion_dark"),
    ("liquid", "potion"), ("alcohol", "potion"), ("wine", "potion_dark"), ("oil", "potion"), ("paint", "potion"),
    ("dust", "sack"), ("leaf", "herb"), ("flax", "herb"), ("seed", "wheat"), ("salt", "sack"),
    ("fuel", "log"), ("crystal", "eye"), ("bell", "crown"), ("rod", "log"), ("device", "eye"),
]


def sprite(name):
    # por el nombre sin la calidad: «Wine (bronze)» no es un lingote
    low = (m.group(1) if (m := GRADE.match(name)) else name).lower()
    return next((s for key, s in SPRITES if key in low), "sack")


# MARK: - Recetas

AMOUNT = re.compile(r"^(\d+) × (.+?)(?: \((\d+) with (.+)\))?$")
# en la cocina el combustible va sin «×» y con su rebaja: «10 Fuel (5 with Heat Saver)»
FUEL = re.compile(r"^(\d+) (Fuel) \((\d+) with (.+)\)$")
# cabeceras de las tablas de recetas: en las páginas de objetos y en las de «Crafting Recipes»
RECIPE_HEADERS = (["Output", "Ingredients", "Station and unlock"],
                  ["Output per batch", "Inputs per batch", "Workstation and unlock"])
# cocina: la estación y el desbloqueo en columnas separadas
SPLIT_HEADER = ["Output", "Ingredients", "Station", "Unlock"]
# Mesa de joyería: «Bronze Zombie Collar | 1 Bronze Ingot + 1 Blue Crystal + 3 Faith | 4»
COLLAR_HEADER = ["Collar", "Ingredients", "Recipe mastery"]
PLUS_AMOUNT = re.compile(r"^(\d+) (.+)$")
# alquimia: «Healing Potion | 2/0/0 | Clay + Clay», una fórmula de runas con una combinación de ejemplo
FORMULA_HEADER = ["Product", "Red / green / blue", "Example ingredients"]
LABORATORIES = ["Laboratory I", "Laboratory II"]


def parse_station(cell):
    """«A, B; Technology: X; Extension: Y» → (estaciones, tecnología, extensión, desbloqueo aparte)"""
    stations, tech, extension, separate = [], None, None, False
    for i, part in enumerate(cell.split("; ")):
        if part.startswith("Technology: "):
            tech = part.removeprefix("Technology: ")
        elif part.startswith("Extension: "):
            extension = part.removeprefix("Extension: ")
        elif part in ("Separate recipe unlock required", "Recipe unlock required"):
            separate = True
        elif part == "Check station access":
            pass
        elif i == 0:
            stations = part.split(", ")
        else:
            sys.exit(f"parte desconocida en la estación: {part!r}")
    return stations, tech, extension, separate


def table_recipes(page):
    out = []
    for rows in tables(content(page)):
        if rows and rows[0] == COLLAR_HEADER:
            out += collar_recipes(page, rows[1:])
        if rows and rows[0] == FORMULA_HEADER:
            out += formula_recipes(page, rows[1:])
        if rows and rows[0] == SPLIT_HEADER:
            rows = [r[:2] + ["; ".join(r[2:])] for r in rows]
        elif not rows or rows[0][:3] not in RECIPE_HEADERS:
            continue
        for output, ingredients, station in rows[1:]:
            m = AMOUNT.match(output)
            if not m:
                sys.exit(f"{page}: salida desconocida {output!r}")
            stations, tech, extension, separate = parse_station(station)
            ings, cheaper = [], None
            for part in ingredients.split("; "):
                n = AMOUNT.match(part) or FUEL.match(part)
                if not n or (n.group(3) and n.group(2) != "Fuel"):
                    sys.exit(f"{page}: ingrediente desconocido {part!r}")
                ings.append([int(n.group(1)), n.group(2)])
                if n.group(3):
                    cheaper = [n.group(4), int(n.group(3))]
            out.append({
                "page": page, "output": m.group(2), "qty": int(m.group(1)), "stations": stations,
                "ingredients": ings, "tech": tech, "extension": extension, "separate": separate,
                "bonus": [m.group(4), int(m.group(3))] if m.group(3) else None, "fuel_bonus": cheaper,
            })
    return out


def collar_recipes(page, rows):
    out = []
    for collar, ingredients, mastery in rows:
        ings = []
        for part in ingredients.split(" + "):
            n = PLUS_AMOUNT.match(part)
            if not n:
                sys.exit(f"{page}: ingrediente desconocido {part!r}")
            ings.append([int(n.group(1)), n.group(2)])
        out.append({"page": page, "output": collar, "qty": 1, "stations": ["Jewelry Table"],
                    "ingredients": ings, "mastery": int(mastery)})
    return out


def formula_recipes(page, rows):
    """La wiki no dice cuántas unidades salen: se cuenta 1. Cada ingrediente ocupa un hueco,
    así que «Leaf + Leaf» son 2 Hojas."""
    out = []
    for product, runes, example in rows:
        if not re.fullmatch(r"\d+/\d+/\d+", runes):
            sys.exit(f"{page}: runas desconocidas {runes!r}")
        counts = {}
        for name in example.split(" + "):
            counts[name.strip()] = counts.get(name.strip(), 0) + 1
        out.append({"page": page, "output": product, "qty": 1, "stations": LABORATORIES,
                    "ingredients": [[n, name] for name, n in counts.items()], "runes": runes})
    return out


# MARK: - Personajes y comercio

TIERS = {"first": 1, "second": 2, "third": 3}


def trade(page):
    """[(personaje, objeto, nivel, vende, compra)] de las tablas «Trade by tier» de un personaje
    y de las de «Where to Buy Materials» («Builder — first trade level; Herm — second trade level»)."""
    out = []
    for rows in tables(content(page)):
        if rows[0] == ["Trade tier", "Ungraded goods and direction"]:
            for tier, goods in rows[1:]:
                for part in goods.split("; "):
                    m = re.fullmatch(r"(.+) \((sells and buys|sells|buys)\)", part)
                    if not m:
                        sys.exit(f"{page}: comercio desconocido {part!r}")
                    name = ITEM_ALIASES.get(m.group(1), m.group(1))
                    out.append((page.replace("_", " "), name, int(tier), "sells" in m.group(2), "buys" in m.group(2)))
        elif rows[0] == ["Supply", "Seller and first listed trade level"]:
            for supply, sellers in rows[1:]:
                for part in sellers.split("; "):
                    m = re.fullmatch(r"(.+) — (first|second|third) trade level", part)
                    if not m:
                        sys.exit(f"{page}: vendedor desconocido {part!r}")
                    out.append((m.group(1), ITEM_ALIASES.get(supply, supply), TIERS[m.group(2)], True, False))
    return out


def tier_summary(verb, tiers):
    """«Vende desde el nivel 1: A, B. Desde el nivel 2: C.»"""
    by_tier = {}
    for name, tier in tiers.items():
        by_tier.setdefault(tier, []).append(item_es(name))
    parts = [f"desde el nivel {t}: " + ", ".join(sorted(ns, key=str.casefold)) for t, ns in sorted(by_tier.items())]
    return f"{verb} " + ". ".join(p if i == 0 else p[0].upper() + p[1:] for i, p in enumerate(parts)) + "."


# MARK: - Construcciones

# como GameData.buildStationPrefix: estas «estaciones» son sitios donde se construye, no se guardan en baúles
BUILD_PREFIX = "Construcción · "

AREA_HEADING = re.compile(r"^(.+) placement costs$")


def construction_recipes(page):
    """Tablas de construcción: «Object | Placement materials | Technology» bajo «<zona> placement costs»,
    «Build | Placement materials» (sin zona) y «Construction | Materials» con «4 X + 2 Y» (zona de PAGE_AREA)."""
    out, area = [], PAGE_AREA.get(page)
    body = content(page)
    for m in re.finditer(r'<span class="mw-headline" id="[^"]+">(.*?)</span>|(<table.*?</table>)', body, re.S):
        if m.group(1):
            heading = AREA_HEADING.match(text(m.group(1)))
            if heading:
                area = heading.group(1)
            continue
        rows = tables(m.group(2))[0]
        header, plus = rows[0], False
        if header == ["Object", "Placement materials", "Technology"]:
            where = area
        elif header == ["Build", "Placement materials"]:
            where = None
        elif header == ["Construction", "Materials"]:
            where, plus = area, True
        else:
            continue
        for row in rows[1:]:
            ings = []
            for part in row[1].split(" + " if plus else "; "):
                n = (PLUS_AMOUNT if plus else AMOUNT).match(part)
                if not n:
                    sys.exit(f"{page}: material desconocido {part!r}")
                ings.append([int(n.group(1)), n.group(2)])
            tech = row[2] if len(row) > 2 and not row[2].startswith("Check ") else None
            out.append({"page": page, "output": row[0], "qty": 1, "areas": [where] if where else [],
                        "ingredients": ings, "tech": tech})
    return out


def merge_constructions(builds):
    """Junta las construcciones con los mismos materiales (sumando sus zonas). Si una construcción tiene
    zona en alguna fuente, se descartan los costes sin zona; si quedan costes distintos, se avisa."""
    groups = {}
    for b in builds:
        key = (b["output"], tuple(sorted(map(tuple, b["ingredients"]))))
        g = groups.setdefault(key, {**b, "areas": []})
        g["areas"] += [a for a in b["areas"] if a not in g["areas"]]
        g["tech"] = g.get("tech") or b.get("tech")
    by_output = {}
    for g in groups.values():
        by_output.setdefault(g["output"], []).append(g)
    out = []
    for output, gs in by_output.items():
        if any(g["areas"] for g in gs):
            gs = [g for g in gs if g["areas"]]
        for g in gs:
            if len(gs) > 1:
                g["note"] = "La wiki da costes distintos para esta construcción según la página"
            out.append({**g, "construction": True, "stations": g["areas"] or [NO_AREA]})
    return out


def station_es(r):
    return BUILD_PREFIX + name_es(r["stations"][0]) if r.get("construction") else name_es(r["stations"][0])


def merge(recipes):
    """Junta las recetas repetidas entre páginas (misma salida, cantidad, estaciones e ingredientes),
    completando lo que falte en la primera."""
    out, seen = [], {}
    for r in recipes:
        key = (r["output"], r["qty"], tuple(r["stations"]), tuple(map(tuple, r["ingredients"])))
        if key in seen:
            first = seen[key]
            for k, v in r.items():
                if v and not first.get(k):
                    first[k] = v
            continue
        seen[key] = r
        out.append(r)
    return out


def notes(r):
    parts = []
    if len(r["stations"]) > 1:
        parts.append("También en: " + ", ".join(name_es(s) for s in r["stations"][1:]))
    if r.get("tech"):
        parts.append("Tecnología: " + name_es(r["tech"]))
    if r.get("runes"):
        red, green, blue = r["runes"].split("/")
        parts.append(f"Runas: {red} rojas, {green} verdes y {blue} azules. Los ingredientes son un ejemplo:"
                     " valen otros que sumen las mismas runas")
    if r.get("separate"):
        parts.append("La receta se desbloquea aparte")
    if r.get("extension"):
        parts.append("Extensión: " + name_es(r["extension"]))
    if r.get("mastery"):
        parts.append(f"Maestría {r['mastery']}")
    if r.get("bonus"):
        perk, qty = r["bonus"]
        parts.append(f"{qty} con la ventaja {name_es(perk)}")
    if r.get("fuel_bonus"):
        perk, qty = r["fuel_bonus"]
        parts.append(f"{qty} de combustible con la ventaja {name_es(perk)}")
    if r.get("note"):
        parts.append(r["note"].rstrip("."))
    return ". ".join(parts) + "." if parts else None


# MARK: - Tecnologías

TECH_INDEX = "Technology_Costs"
TECH_HEADER = ["Technology", "Red / green / blue", "Prerequisites and visibility"]
# cocina: no cuestan puntos, cada una se desbloquea haciendo algo
TECH_UNLOCK_HEADER = ["Technology", "How to unlock it"]
REPUTATION = re.compile(r"^(.+) reputation (\d+)$")
# la wiki de GK2 no tiene iconos de los árboles: los de GK1 (Data/Images)
TREE_IMAGES = {
    "Building": "tech_building", "Metallurgy": "tech_smithing", "Farming": "tech_farming_and_nature",
    "Theology": "tech_theology", "Anatomy_and_Alchemy": "tech_anatomy_and_alchemy", "Cooking": "tech_cookery",
}
# artículo delante del nombre traducido del personaje («con la Monja»)
ARTICLES = {"Nun": "la "}
# tecnologías que se llaman igual en dos árboles: el de las recetas que las piden («Supply: Fabric» es de
# Construcción, tras el Banco de montaje; la «Fabric» de Agricultura viene del hilo de lino)
UNLOCK_TREE = {"Fabric": "Building"}


def tech_trees(recipes, characters):
    """Un árbol por página de «Technology Costs», en su orden, con una sola rama sin nombre.
    Lo que desbloquea cada tecnología sale de las recetas que la piden («Technology: X»)."""
    npc_id = {c.get("wikiName", c["name"]): c for c in characters}
    unlocks = {}  # nombre de la tecnología → [desbloqueos]
    for r in recipes:
        if not r.get("tech"):
            continue
        entry = {"kind": "blueprint" if r.get("construction") else "recipe",
                 "name": item_es(r["output"]), "item": slug(r["output"])}
        if entry not in unlocks.setdefault(r["tech"], []):
            unlocks[r["tech"]].append(entry)
    trees, used = [], set()
    for page in [p for p in linked_pages(TECH_INDEX) if p.endswith("_Technologies")]:
        body = content(page)
        rows = next(t for t in tables(body) if t[0] in (TECH_HEADER, TECH_UNLOCK_HEADER))
        ids = {slug(r[0]) for r in rows[1:]}
        if len(ids) != len(rows) - 1:
            sys.exit(f"{page}: tecnologías repetidas")
        techs, tree_name = [], page.removesuffix("_Technologies")
        for row in rows[1:]:
            tech = {"id": slug(row[0]), "name": name_es(row[0])}
            conditions, requires = [], []
            if rows[0] == TECH_HEADER:
                cost = dict(zip(("red", "green", "blue"), map(int, row[1].split(" / "))))
                if cost := {k: v for k, v in cost.items() if v}:
                    tech["cost"] = cost
                for part in row[2].split("; "):
                    if part == "No prerequisite listed":
                        pass
                    elif part == "Hidden at start":
                        conditions.append("Oculta al principio: aparece al avanzar en el juego.")
                    elif m := REPUTATION.match(part):
                        c = npc_id.get(m.group(1)) or sys.exit(f"{page}: personaje desconocido {m.group(1)!r}")
                        conditions.append(f"Necesita {m.group(2)} de reputación con {ARTICLES.get(m.group(1), '')}"
                                          f"[**{c['name']}**](gk2://character/{c['id']}).")
                    elif slug(part) in ids:
                        requires.append(slug(part))
                    else:
                        sys.exit(f"{page}: requisito desconocido {part!r}")
            elif row[1] in ES:
                conditions.append(ES[row[1]])
            else:
                missing["es.json"].add(row[1])
            if conditions:
                tech["condition"] = " ".join(conditions)
            if requires:
                tech["requires"] = requires
            if row[0] in unlocks and UNLOCK_TREE.get(row[0], tree_name) == tree_name:
                tech["unlocks"] = unlocks[row[0]]
                used.add(row[0])
            techs.append(tech)
        tree = {"id": slug(tree_name), "name": name_es(tree_name.replace("_", " ") + " Technologies")}
        first = text(re.search(r"<p>(?!<br />)(.*?)</p>", body, re.S).group(1))
        if first in ES:
            tree["text"] = [ES[first]]
        else:
            missing["es.json"].add(first)
        shutil.copyfile(os.path.join(GK1_DATA, "Images", TREE_IMAGES[tree_name] + ".png"),
                        os.path.join(IMAGES, f"tech_{tree['id']}.png"))
        tree["image"] = f"GK2/tech_{tree['id']}"
        trees.append(tree | {"branches": [{"techs": techs}]})
    if unknown := set(unlocks) - used:
        sys.exit(f"tecnologías de recetas que no están en «{TECH_INDEX}»: {sorted(unknown)}")
    return trees


# MARK: - Talentos

TALENTS_PAGE = "Talents_and_Inspirations"
INSPIRATION_HEADER = ["Inspiration", "Objective", "Goal", "Technology lock"]
NO_LOCK = "No technology lock listed"
# apartados de la página que explican cómo funcionan (texto del árbol)
TALENT_SECTIONS = ["Choose a use for points", "Zombie progression", "Claim completed inspirations with Faith"]
COUNTS = re.compile(r"^What counts for (.+)\?$")


def talent_tree():
    """«Talents and Inspirations» como un árbol más de la pestaña Tecnologías: las inspiraciones de primer
    nivel de su tabla, con el objetivo y la tecnología que las bloquea en `condition`. No cuestan puntos
    (se reclaman con Fe). El texto del árbol sale de la introducción y de los apartados que lo explican."""
    body = content(TALENTS_PAGE)
    body = re.sub(r"<aside.*?</aside>", "", body[:body.find('id="What_to_do_next"')], flags=re.S)
    parts = re.split(r'<h2>.*?<span class="mw-headline" id="[^"]+">(.*?)</span></h2>', body, flags=re.S)
    intro = [text(p) for p in re.findall(r"<p>(?!<br />)(.*?)</p>", parts[0], re.S)]
    paragraphs, counts, rows = [es(p) for p in intro if p], {}, None
    for title, section in zip(parts[1::2], parts[2::2]):
        title = text(title)
        prose = [text(p) for p in re.findall(r"<p>(.*?)</p>", section, re.S) if text(p)]
        if title in TALENT_SECTIONS:
            paragraphs += [es(p) for p in prose]
        elif m := COUNTS.match(title):
            counts[m.group(1)] = [es(p) for p in prose]
        rows = rows or next((t for t in tables(section) if t and t[0][-4:] == INSPIRATION_HEADER), None)
    if not rows:
        sys.exit(f"{TALENTS_PAGE}: falta la tabla de inspiraciones")
    techs = []
    for name, objective, goal, lock in (r[-4:] for r in rows[1:]):
        condition = [es(objective).rstrip(".") + f". Objetivo del primer nivel: {goal}."]
        if lock != NO_LOCK:
            condition.append(f"Necesita la tecnología {name_es(lock)}.")
        condition += counts.pop(name, [])
        techs.append({"id": slug(name), "name": name_es(name), "condition": " ".join(condition)})
    if counts:
        sys.exit(f"{TALENTS_PAGE}: «What counts for» de inspiraciones que no están en la tabla: {sorted(counts)}")
    tree = {"id": slug(TALENTS_PAGE), "name": name_es(TALENTS_PAGE.replace("_", " ")), "text": paragraphs}
    shutil.copyfile(os.path.join(GK1_DATA, "Images", "tech_spiritualism.png"), os.path.join(IMAGES, f"tech_{tree['id']}.png"))
    return tree | {"image": f"GK2/tech_{tree['id']}", "branches": [{"techs": techs}]}


# MARK: - Guía para principiantes

WALKTHROUGH_PAGE = "Beginner_Walkthrough"
CHECKLIST = "Early progression checklist"
MILESTONE_HEADER = ["Milestone", "Completion check"]


ES_QUESTS = load("es_quests.json")
missing["es_quests.json"] = set()
# campos de texto donde se cambian los nombres de misiones en inglés por «el español»
PROSE_KEYS = {"text", "description", "notes", "condition", "links", "check", "sources"}


def quest_es(name):
    if name not in ES_QUESTS:
        missing["es_quests.json"].add(name)
    return ES_QUESTS.get(name, name)


def swap_quests(value, key=None):
    """«Planted and Delivered» → «Sembrado y entregado» en los textos (sin comillas dobles si ya las lleva,
    y sin ellas en las etiquetas en negrita de los enlaces)"""
    if isinstance(value, dict):
        return {k: swap_quests(v, k) for k, v in value.items()}
    if isinstance(value, list):
        return [swap_quests(v, key) for v in value]
    if not isinstance(value, str) or key not in PROSE_KEYS:
        return value
    for en, es_name in sorted(ES_QUESTS.items(), key=lambda kv: -len(kv[0])):
        value = value.replace(f"«{en}»", f"«{es_name}»").replace(f"**{en}**", f"**{es_name}**")
        value = re.sub(r"(?<![«\w])" + re.escape(en) + r"(?![\w»])", f"«{es_name}»", value)
    return value


def es(english):
    if english not in ES:
        missing["es.json"].add(english)
    return ES.get(english, english)


def mentions(prose, names):
    """ids de los nombres (wiki → id) que salen en el texto, en orden de aparición; admite el plural en -s"""
    prose, found = prose.replace("’", "'"), []
    for name in sorted(names, key=len, reverse=True):
        pattern = r"\b" + re.escape(name) + r"s?\b"
        if m := re.search(pattern, prose):
            found.append((m.start(), names[name]))
            # todas las veces, para que «Clay» no salga de otro «Clay Plates»
            prose = re.sub(pattern, lambda m: "#" * len(m.group(0)), prose)
    return list(dict.fromkeys(i for _, i in sorted(found)))


def walkthrough(items, characters, page_item):
    """«Beginner Walkthrough»: la introducción, los hitos de la tabla y un paso por apartado. Los párrafos
    no enlazan nada: los objetos y personajes que nombran salen aparte. Cada enlace de la lista del apartado
    («Faith — …») apunta al objeto o personaje si existe."""
    item_ids = {i.get("wikiName", i["name"]): i["id"] for i in items}
    npc_ids = {c.get("wikiName", c["name"]): c["id"] for c in characters}
    known = {i["id"] for i in items}
    body = content(WALKTHROUGH_PAGE)
    body = body[:body.find('id="What_to_do_next"')]
    parts = re.split(r'<h2>.*?<span class="mw-headline" id="[^"]+">(.*?)</span></h2>', body, flags=re.S)
    intro = [text(p) for p in re.findall(r"<p>(?!<br />)(.*?)</p>", parts[0], re.S)]
    guide = {"name": "Guía para principiantes", "text": [es(p) for p in intro if p], "steps": []}
    for title, section in zip(parts[1::2], parts[2::2]):
        title = re.sub(r"^\d+\. ", "", text(title))
        prose = [text(p) for p in re.findall(r"<p>(.*?)</p>", section, re.S)]
        step = {"id": slug(title), "name": es(title), "text": [es(p) for p in prose if p], "links": []}
        for li, page in re.findall(r'<li>(<a href="/([^"#]+)" title="[^"]+">.*?)</li>', section, re.S):
            label, _, rest = es(text(li)).partition(" — ")
            target = page_item.get(page, page.replace("_", " "))
            if slug(target) in known:
                label = f"[**{label}**](gk2://item/{slug(target)})"
            elif target in npc_ids:
                label = f"[**{label}**](gk2://character/{npc_ids[target]})"
            else:
                label = f"**{label}**"
            step["links"].append(f"{label} — {rest}" if rest else label)
        english = " ".join(prose)
        if found := mentions(english, item_ids):
            step["items"] = found
        if found := mentions(english, npc_ids):
            step["characters"] = found
        if title == CHECKLIST:
            rows = next(t for t in tables(section) if t[0] == MILESTONE_HEADER)
            guide["milestones"] = [{"id": slug(r[0]), "name": es(r[0]), "check": es(r[1])} for r in rows[1:]]
            guide["checklist"] = step
        else:
            guide["steps"].append(step)
    if "milestones" not in guide:
        sys.exit(f"{WALKTHROUGH_PAGE}: falta la tabla «{CHECKLIST}»")
    return guide


# MARK: - Misiones

QUESTS_INDEX = "Quests"
GIVER = re.compile(r"^(.+) character portrait from the game\.$")


def quests(items, characters):
    """personaje → [misiones] de las guías que enlaza «Quests», en su orden. Cada página: un párrafo de
    introducción, el retrato de quien la da y un apartado por etapa («**Etapa.** texto»). El nombre
    se traduce con es_quests.json."""
    item_ids = {i.get("wikiName", i["name"]): i["id"] for i in items}
    npc_ids = {c.get("wikiName", c["name"]): c["id"] for c in characters}
    out = {}
    for page in linked_pages(QUESTS_INDEX):
        body = content(page)
        body = re.sub(r"<aside.*?</aside>", "", body[:body.find('id="What_to_do_next"')], flags=re.S)
        caption = text(re.search(r'<div class="kiln-core-caption">(.*?)</div>', body, re.S).group(1))
        if not (m := GIVER.match(caption)) or m.group(1) not in npc_ids:
            sys.exit(f"{page}: no se sabe quién da la misión ({caption!r})")
        parts = re.split(r'<h2>.*?<span class="mw-headline" id="[^"]+">(.*?)</span></h2>', body, flags=re.S)
        intro = [text(p) for p in re.findall(r"<p>(?!<br />)(.*?)</p>", parts[0], re.S)]
        english, paragraphs = [p for p in intro if p], [es(p) for p in intro if p]
        for title, section in zip(parts[1::2], parts[2::2]):
            prose = " ".join(text(p) for p in re.findall(r"<p>(.*?)</p>", section, re.S))
            english.append(prose)
            paragraphs.append(f"**{es(text(title))}.** {es(prose)}")
        name = html.unescape(page.replace("_", " "))
        # el id sale del nombre en inglés, que queda en `wikiName`
        quest = {"id": slug(name), "name": quest_es(name), "wikiName": name, "text": paragraphs}
        if found := mentions(" ".join(english), item_ids):
            quest["items"] = found
        giver = npc_ids[m.group(1)]
        if found := [c for c in mentions(" ".join(english), npc_ids) if c != giver]:
            quest["characters"] = found
        out.setdefault(giver, []).append(quest)
    return out


# MARK: - Logros

ACHIEVEMENTS_PAGE = "Graveyard_Keeper_2_Achievements"
ACHIEVEMENT_HEADER = ["Achievement", "Completion description"]
ES_ACHIEVEMENTS = load("es_achievements.json")
missing["es_achievements.json"] = set()


def achievement_guide(characters):
    """Un apartado por tabla de la página de logros, en su orden; los que van plegados como spoiler se marcan.
    La wiki de GK2 no tiene imágenes de logros: la app enseña el icono de la corona."""
    npc_ids = {c.get("wikiName", c["name"]): c["id"] for c in characters}
    body = content(ACHIEVEMENTS_PAGE)
    body = body[:body.find('id="What_to_do_next"')]
    parts = re.split(r'<h2><span class="mw-headline" id="[^"]+">(.*?)</span></h2>', body)
    sections, ids = [], set()
    for title, section in zip(parts[1::2], parts[2::2]):
        rows = next(t for t in tables(section) if t[0] == ACHIEVEMENT_HEADER)
        achievements = []
        for name, description in rows[1:]:
            if name not in ES_ACHIEVEMENTS:
                missing["es_achievements.json"].add(name)
            a = {"id": slug(name), "name": ES_ACHIEVEMENTS.get(name, name), "text": [es(description)]}
            if a["id"] in ids:
                sys.exit(f"{ACHIEVEMENTS_PAGE}: logro repetido {name!r}")
            ids.add(a["id"])
            if found := mentions(description, npc_ids):
                a["characters"] = found
            if a["name"] != name:
                a["wikiName"] = name
            achievements.append(a)
        # `name` ya en español: GuideSection.title solo traduce los apartados de GK1
        sections.append({"id": slug(text(title)), "name": es(text(title))}
                        | ({"spoiler": True} if "kiln-spoiler" in section else {})
                        | {"achievements": achievements})
    return sections


# MARK: - Imágenes

# iconos de la wiki de GK2 que ninguna página enseña junto al objeto (nombre → fichero, sin «Graveyard_Keeper_2_i_»)
GK2_ICON_FILES = {
    "Skull": "skull.png", "Bowl of sauerkraut": "bowl_sauerkraut.png", "Marble Plate": "marble_plate_2.png",
    "Wine": "bottle_red_vine_1.png",
}

# objetos de GK2 que en GK1 se llaman de otra forma (nombre de la wiki de GK2 → de GK1)
GK1_IMAGE_ALIASES = {
    "Beer": "A mug of beer", "Simple Candle": "Candle", "Simple Incense": "Incense", "Hop Seeds": "Hops seed",
    "Apple Tree Seedling": "Tree apple seedling", "Bush Seedling": "Bush berry seedling",
    "Grape Juice": "Bottle of grape juice",
    "Furnace I": "Furnace", "Writing Desk": "Desk", "Iron Anvil": "Anvil",
    "Woodworking Workbench I": "Carpenter's workbench", "Woodworking Workbench II": "Carpenter's workbench II",
    "Laboratory I": "Alchemy workbench (tier I)", "Laboratory II": "Alchemy workbench (tier II)",
    "Lantern I": "Lantern", "Embalming Table I": "Embalming table", "Resurrection Table I": "Resurrection table",
    "Flower Bed I": "Flowerbed", "Wine Barrel": "Wine making barrel",
}


def gk1_images():
    """nombre de la wiki (en minúsculas, sin signos) → imagen de GK1 en Data/Images; las estaciones primero"""
    norm = lambda n: re.sub(r"[^a-z0-9]", "", n.lower())
    out = {}
    for name in ("stations", "items"):
        with open(os.path.join(GK1_DATA, name + ".json")) as f:
            for e in json.load(f):
                if e.get("image"):
                    out.setdefault(norm(e.get("wikiName") or e["name"]), e["image"])
    return lambda n: out.get(norm(GK1_IMAGE_ALIASES.get(n, n)))

def icon_urls(page):
    """(url del icono del objeto de la página o None, {ingrediente: url} de los iconos en línea)"""
    body = content(page)
    core = None
    m = re.search(r'<div class="kiln-core-image">.*?src="([^"]+)"', body, re.S)
    if m and "Graveyard_Keeper_2_i_" in m.group(1):
        core = m.group(1)
    inline = {}
    # cada icono por separado: el nombre puede ser un enlace («<a>Dream Dust</a>»)
    for chunk in body.split('<span class="kiln-recipe-item">')[1:]:
        img = re.match(r'<span typeof="mw:File"><span><img [^>]*?src="([^"]+)"[^>]*?(?:srcset="(\S+) 1\.5x")?[^>]*/></span></span>(.*?)</span>', chunk, re.S)
        if not img:
            sys.exit(f"{page}: icono en línea desconocido {chunk[:120]!r}")
        inline.setdefault(text(img.group(3)), img.group(2) or img.group(1))
    return core, inline


IMAGE_CACHE = os.path.join(HERE, "cache", "images")


def download(url, dest):
    """copia a `dest` la imagen de `url`, guardada en cache/images para no volver a pedirla"""
    cached = os.path.join(IMAGE_CACHE, url.rsplit("/", 1)[1])
    if not os.path.exists(cached):
        req = urllib.request.Request(url, headers={**UA, "Referer": "https://graveyardkeeper2.wiki.fextralife.com/"})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    data = r.read()
                break
            except OSError:
                if attempt == 2:
                    raise
                time.sleep(2)
        if data[:4] != b"\x89PNG":
            sys.exit(f"no es PNG: {url}")
        os.makedirs(IMAGE_CACHE, exist_ok=True)
        with open(cached, "wb") as f:
            f.write(data)
        time.sleep(0.1)
    shutil.copyfile(cached, dest)


# MARK: -

def main():
    pages = index_pages()
    page_item = {p: GUIDE["pages"].get(p, title) for p, title, _ in pages}
    category = {page_item[p]: SECTION_CATEGORY[section] for p, _, section in pages}

    recipes = [r for r in GUIDE["recipes"] if not r.get("construction")]
    builds = [{**r, "areas": r["stations"]} for r in GUIDE["recipes"] if r.get("construction")]
    descriptions, images = {}, {}
    for page, _, _ in pages:
        found = table_recipes(page)
        recipes += found
        core, inline = icon_urls(page)
        if core:
            images[page_item[page]] = core
        for name, url in inline.items():
            images.setdefault(name, url)
        if not found and not any(r["page"] == page for r in GUIDE["recipes"]) and page_item[page] not in GUIDE["sources"]:
            sys.exit(f"{page}: sin receta ni origen (añádelo a guide.json)")
        if not found:
            # guía en prosa: su primer párrafo explica cómo conseguirlo
            first = text(re.search(r"<p>(?!<br />)(.*?)</p>", content(page), re.S).group(1))
            if first in ES:
                descriptions[page_item[page]] = ES[first]
            else:
                missing["es.json"].add(first)

    # recetas de las páginas de «Crafting Recipes» (Woodworking, Metalworking…), después de las de los objetos
    seen_on = {}  # objeto → páginas de recetas donde aparece
    for page in linked_pages(RECIPES_INDEX) + EXTRA_RECIPE_PAGES:
        found = table_recipes(page)
        recipes += found
        for r in found:
            for n in [r["output"]] + [i[1] for i in r["ingredients"]]:
                seen_on.setdefault(n, set()).add(page)
            if page in PAGE_CATEGORY:
                category.setdefault(r["output"], PAGE_CATEGORY[page])
        for name, url in icon_urls(page)[1].items():
            images.setdefault(name, url)
    recipes = merge(recipes)
    # construcciones: la página por zonas, las guías y las tablas «Construction uses» de cualquier página
    for page in sorted(f.removesuffix(".html") for f in os.listdir(PAGES)):
        builds += construction_recipes(page)
    for name, url in icon_urls(CONSTRUCTION_PAGE)[1].items():
        images.setdefault(name, url)
    builds = merge_constructions(sorted(builds, key=lambda b: b["page"] != CONSTRUCTION_PAGE))
    built = {b["output"] for b in builds}
    recipes += builds
    # los ingredientes que solo salen en una página de cocina o de alquimia son de su categoría
    for n, where in seen_on.items():
        if len(where) == 1 and (page := next(iter(where))) in PAGE_CATEGORY:
            category.setdefault(n, PAGE_CATEGORY[page])

    # personajes: los de «Characters» y los comerciantes de «Where to Buy Materials»
    deals = [d for page in linked_pages(CHARACTERS_INDEX) + [BUY_PAGE] for d in trade(page)]
    npc_names = list(dict.fromkeys(
        [p.replace("_", " ") for p in linked_pages(CHARACTERS_INDEX)] + [d[0] for d in deals]))
    traded = [d[1] for d in deals]

    # objetos: los de las páginas, en su orden, y luego los ingredientes que no tienen página
    names = list(dict.fromkeys(
        [page_item[p] for p, _, _ in pages]
        + [n for r in recipes for n in [r["output"]] + [i[1] for i in r["ingredients"]]]
        + list(GUIDE["sources"]) + traded))
    os.makedirs(IMAGES, exist_ok=True)
    gk1_image = gk1_images()
    with open(os.path.join(HERE, "cache", "allimages.json")) as f:
        wiki_files = json.load(f)
    items = []
    for name in names:
        item = {"id": slug(name), "name": item_es(name)}
        if item["name"] != name:
            item["wikiName"] = name
        item["category"] = (CATEGORY.get(name) or category.get(name) or ("material" if name in built else None)
                            or ("herramienta" if any(t in name.split() for t in TOOLS) else "material"))
        # las construcciones sin imagen se ven como un plano
        item["icon"] = "blueprint" if name in built else sprite(name)
        if name in GUIDE["sources"]:
            item["sources"] = GUIDE["sources"][name]
        if name in descriptions:
            item["description"] = descriptions[name]
        dest = os.path.join(IMAGES, item["id"] + ".png")
        # las calidades usan la imagen del objeto base: «Cabbage (gold)» → «Cabbage»
        base = m.group(1) if (m := GRADE.match(name)) else name
        own = GK2_ICON_FILES.get(name) or GK2_ICON_FILES.get(base)
        if name in images:
            download(images[name], dest)
            item["image"] = "GK2/" + item["id"]
        elif own:
            download(wiki_files["Graveyard_Keeper_2_i_" + own], dest)
            item["image"] = "GK2/" + item["id"]
        elif old := gk1_image(name) or gk1_image(base):
            # sin imagen en la wiki de GK2 (las estaciones no tienen ninguna): la de GK1, si existe allí
            shutil.copyfile(os.path.join(GK1_DATA, "Images", old + ".png"), dest)
            item["image"] = "GK2/" + item["id"]
        items.append(item)
    characters = []
    for npc in npc_names:
        meta = GUIDE["characters"].get(npc)
        if not meta:
            sys.exit(f"{npc}: falta en «characters» de guide.json")
        c = {"id": slug(npc), "name": meta.get("name", npc)}
        if c["name"] != npc:
            c["wikiName"] = npc
        # GK2 no tiene días: `days` vacío
        c |= {"title": meta["title"], "location": meta["location"], "icon": "person", "days": []}
        sells, buys = {}, {}  # objeto → primer nivel de comercio
        for who, name, tier, sell, buy in deals:
            if who != npc:
                continue
            if sell:
                sells[name] = min(tier, sells.get(name, tier))
            if buy:
                buys[name] = min(tier, buys.get(name, tier))
        if sells:
            c["sells"] = [slug(n) for n in sells]
        if buys:
            c["buys"] = [slug(n) for n in buys]
        npc_notes, page = [], npc.replace(" ", "_")
        if os.path.exists(os.path.join(PAGES, page + ".html")):
            # su página: el primer párrafo y el retrato
            first = text(re.search(r"<p>(?!<br />)(.*?)</p>", content(page), re.S).group(1))
            if first in ES:
                npc_notes.append(ES[first])
            else:
                missing["es.json"].add(first)
            m = re.search(r'<div class="kiln-core-image">.*?src="([^"]+)"', content(page), re.S)
            if m and "portrait_icon" in m.group(1):
                download(m.group(1), os.path.join(IMAGES, "npc_" + c["id"] + ".png"))
                c["image"] = "GK2/npc_" + c["id"]
        if sells:
            npc_notes.append(tier_summary("Vende", sells))
        if buys:
            npc_notes.append(tier_summary("Compra", buys))
        if npc_notes:
            c["notes"] = "\n\n".join(npc_notes)
        characters.append(c)
    for c in characters:
        c.pop("quests", None)
    for giver, found in quests(items, characters).items():
        next(c for c in characters if c["id"] == giver)["quests"] = found

    trees = tech_trees(recipes, characters) + [talent_tree()]
    guide = walkthrough(items, characters, page_item)
    achievements = achievement_guide(characters)
    ids = {i["id"] for i in items} | {"npc_" + c["id"] for c in characters} | {"tech_" + t["id"] for t in trees}
    for f in os.listdir(IMAGES):
        if f.removesuffix(".png") not in ids:
            os.remove(os.path.join(IMAGES, f))

    out, counts = [], {}
    for r in recipes:
        oid = slug(r["output"])
        counts[oid] = counts.get(oid, 0) + 1
        recipe = {
            "id": f"r_{oid}" + (f"_{counts[oid]}" if counts[oid] > 1 else ""),
            "output": oid, "outputQty": r["qty"], "station": station_es(r),
            "ingredients": [{"item": slug(n), "qty": q} for q, n in r["ingredients"]],
        }
        if note := notes(r):
            recipe["notes"] = note
        out.append(recipe)

    items, characters, trees = swap_quests(items), swap_quests(characters), swap_quests(trees)
    guide, achievements = swap_quests(guide), swap_quests(achievements)
    for name, data in (("items", items), ("recipes", out), ("characters", characters), ("technologies", trees)):
        with open(os.path.join(OUT, name + ".json"), "w") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
    with open(os.path.join(OUT, "guide.json"), "w") as f:
        json.dump(achievements, f, ensure_ascii=False, indent=2)
        f.write("\n")
    with open(os.path.join(OUT, "walkthrough.json"), "w") as f:
        json.dump(guide, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"GK2: {len(items)} objetos · {len(out)} recetas · {len(characters)} personajes · "
          f"{sum(len(t['branches'][0]['techs']) for t in trees)} tecnologías · {len(guide['steps'])} pasos de la guía · "
          f"{sum(len(g['achievements']) for g in achievements)} logros · "
          f"{sum(len(c.get('quests', [])) for c in characters)} misiones · "
          f"{len(os.listdir(IMAGES))} imágenes")
    for file, names in missing.items():
        if names:
            print(f"sin traducir en {file}:")
            for n in sorted(names):
                print("  " + json.dumps(n, ensure_ascii=False))


if __name__ == "__main__":
    main()
