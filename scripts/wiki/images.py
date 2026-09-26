#!/usr/bin/env python3
"""Descarga de la wiki las imágenes de objetos, estaciones, personajes, días, tecnologías y logros a GK2Core/Data/Images.

Uso (después de convert.py): python3 images.py   — al terminar vuelve a ejecutar convert.py,
que añade el campo "image" a cada entrada con imagen descargada.
"""
import json, os, re, subprocess, sys, tempfile, time, unicodedata, urllib.parse, urllib.request

HERE = os.path.dirname(__file__)
RES = os.path.join(HERE, "..", "..", "Packages", "GK2Core", "Sources", "GK2Core", "Data")
IMAGES = os.path.join(RES, "Images")
API = "https://graveyardkeeper.fandom.com/api.php"
UA = {"User-Agent": "gk-guia/1.0 (personal guide)"}

PAGES = {t: p for t, p in json.load(open(os.path.join(HERE, "cache", "pages.json")))["pages"].items() if "/" not in t}


def get(params):
    params = {**params, "format": "json", "formatversion": "2"}
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(params), headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def field(text, name, title):
    m = re.search(r"\|\s*" + name + r"\s*=\s*([^\n|}]*)", text)
    if not m:
        return None
    value = re.sub(r"\{\{\s*PAGENAME\s*\}\}", title, m.group(1)).strip()
    value = re.sub(r"^\[\[(?:File|Image):([^|\]]+).*", r"\1", value, flags=re.I)
    return value or None


def candidates_for(title, infobox_field="image", prefer_item=True):
    page = PAGES.get(title, {}).get("text", "")
    out = []
    if prefer_item:
        out.append(f"{title} item.png")
    img = field(page, infobox_field, title)
    if img:
        out.append(img)
    out += [f"{title}.png", f"{title} item.gif", f"{title}.gif"]
    return list(dict.fromkeys(o[0].upper() + o[1:] for o in out))


def resolve(filenames):
    """nombre de archivo -> URL (sigue redirecciones; omite los que no existen)"""
    urls = {}
    names = list(dict.fromkeys(filenames))
    for i in range(0, len(names), 50):
        batch = names[i:i + 50]
        d = get({"action": "query", "prop": "imageinfo", "iiprop": "url", "redirects": 1,
                 "titles": "|".join("File:" + n for n in batch)})
        q = d["query"]
        alias = {}
        for n in q.get("normalized", []):
            alias[n["to"]] = n["from"]
        for r in q.get("redirects", []):
            alias[r["to"]] = alias.get(r["from"], r["from"])
        for p in q["pages"]:
            if p.get("missing") or "imageinfo" not in p:
                continue
            src = p["title"]
            while src in alias:
                src = alias[src]
            urls[src.removeprefix("File:")] = p["imageinfo"][0]["url"]
        time.sleep(0.2)
    return urls


def download(url, dest):
    # la CDN solo sirve imágenes pedidas desde la propia wiki
    req = urllib.request.Request(url, headers={**UA, "Referer": "https://graveyardkeeper.fandom.com/"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    if data[:4] == b"\x89PNG":
        open(dest, "wb").write(data)
        return
    # GIF/JPG/WebP -> PNG (primer fotograma) con sips, incluido en macOS
    with tempfile.NamedTemporaryFile(suffix=".img", delete=False) as tmp:
        tmp.write(data)
    subprocess.run(["sips", "-s", "format", "png", tmp.name, "--out", dest], check=True, capture_output=True)
    os.unlink(tmp.name)


def main():
    items = json.load(open(os.path.join(RES, "items.json")))
    recipes = json.load(open(os.path.join(RES, "recipes.json")))
    npcs = json.load(open(os.path.join(RES, "characters.json")))
    days = json.load(open(os.path.join(RES, "days.json")))
    day_en = {"orgullo": "Pride", "lujuria": "Lust", "gula": "Gluttony", "envidia": "Envy", "ira": "Wrath", "pereza": "Sloth"}

    # destino (sin extensión) -> archivos candidatos en orden de preferencia
    wanted = {}
    for it in items:
        wanted[it["id"]] = candidates_for(it["name"])
    # las "Construcción · lugar" no llevan imagen: en la wiki son capturas del mapa
    for station in {r["station"] for r in recipes if not r["station"].startswith("Construcción · ")}:
        wanted.setdefault(station_image_name(station), candidates_for(station))
    for n in npcs:
        title = next((t for t in PAGES if slug(t) == n["id"]), n["name"])
        wanted["npc_" + n["id"]] = candidates_for(title, prefer_item=False)
    for d in days:
        wanted["day_" + d["id"]] = [f"{day_en[d['id']]}.png"]
    # árboles de tecnología: la imagen de su apartado en la página «Technologies»
    tech_page = PAGES["Technologies"]["text"]
    for tree in json.load(open(os.path.join(RES, "technologies.json"))):
        m = re.search(r"^===\s*" + re.escape(tree["name"]) + r"\s*===\s*$.*?\[\[File:([^|\]]+)", tech_page, re.M | re.S)
        if m:
            wanted["tech_" + tree["id"]] = [m.group(1).strip()]
    for color, file in (("red", "Red Tech Symbol.png"), ("green", "Green Tech Symbol.png"),
                        ("blue", "Blue Tech Symbol.png"), ("soul", "Soul Point Symbol.png"),
                        ("violet", "Techpoint Purple.png")):
        wanted["techpoint_" + color] = [file]
    # estrellas de calidad (Item.quality)
    for level, file in (("copper", "Bronze Star.png"), ("silver", "Silver Star.png"), ("gold", "Gold Star.png")):
        wanted["star_" + level] = [file]
    # logros: la imagen de la primera columna de cada fila de la guía
    guide_page = PAGES.get("100% Achievement Guide", {}).get("text", "")
    for file, name in re.findall(r"^\|\s*\[\[File:([^|\]]+)[^\n]*\n\|\s*([^\n]+)", guide_page, re.M):
        wanted.setdefault("ach_" + slug(name.strip()), [file.strip()])

    urls = resolve([c for cs in wanted.values() for c in cs])
    os.makedirs(IMAGES, exist_ok=True)
    got, missing = 0, []
    for stem, cands in sorted(wanted.items()):
        url = next((urls[c] for c in cands if c in urls), None)
        dest = os.path.join(IMAGES, stem + ".png")
        if not url:
            missing.append(stem)
            continue
        if not os.path.exists(dest):
            download(url, dest)
            time.sleep(0.1)
        got += 1
    print(f"{got} imágenes · {len(missing)} sin imagen en la wiki")
    if missing:
        print("sin imagen:", ", ".join(missing))
    subprocess.run([sys.executable, os.path.join(HERE, "convert.py")], check=True)


def slug(title):  # igual que en convert.py
    s = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")


def station_image_name(station):
    return "station_" + slug(station)


if __name__ == "__main__":
    main()
