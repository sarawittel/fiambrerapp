#!/usr/bin/env python3
"""Descarga de la wiki de Graveyard Keeper 2 (fextralife) las páginas índice («Items and Materials»,
«Crafting Recipes», «Characters») y las que enlaza cada una, en HTML, a cache/pages/.

La wiki no sirve wikitext (`action=raw` está desactivado), así que convert.py lee el HTML.
"""
import json, os, re, sys, time, urllib.parse, urllib.request

BASE = "https://graveyardkeeper2.wiki.fextralife.com/"
HUBS = ["Items_and_Materials", "Crafting_Recipes", "Characters"]
# páginas de recetas que «Crafting Recipes» solo enlaza en «What to do next» (también en convert.py)
EXTRA = ["Cooking_Recipes", "Alchemy_Recipes", "Workshop_Construction", "Where_to_Buy_Materials"]
PAGES = os.path.join(os.path.dirname(__file__), "cache", "pages")
UA = {"User-Agent": "Mozilla/5.0 (Macintosh) gk-guia/1.0 (personal guide)"}


def get(page):
    req = urllib.request.Request(BASE + urllib.parse.quote(page), headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8")


def linked_pages(html):
    """páginas enlazadas desde las listas del artículo, antes de «What to do next»"""
    body = html[html.find('id="siteSub"'):html.find('id="What_to_do_next"')]
    return list(dict.fromkeys(re.findall(r'<li><a href="/([^"#]+)" title="[^"]+">', body)))


def all_images():
    """nombre de fichero → URL de todas las imágenes de la wiki (para los iconos que ninguna página enseña)"""
    out, cont = {}, {}
    while True:
        params = {"action": "query", "list": "allimages", "ailimit": 500, "format": "json", **cont}
        req = urllib.request.Request(BASE + "api.php?" + urllib.parse.urlencode(params), headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            d = json.load(r)
        out |= {i["name"]: i["url"] for i in d["query"]["allimages"]}
        if "continue" not in d:
            return out
        cont = d["continue"]


def save(page, html):
    with open(os.path.join(PAGES, page + ".html"), "w") as f:
        f.write(html)


def main():
    # --force vuelve a descargar las páginas que ya están en la caché
    force = "--force" in sys.argv
    os.makedirs(PAGES, exist_ok=True)
    for hub in HUBS:
        index = get(hub)
        save(hub, index)
        pages = linked_pages(index)
        for page in pages:
            if force or not os.path.exists(os.path.join(PAGES, page + ".html")):
                save(page, get(page))
                time.sleep(0.3)
        print(f"{hub}: {len(pages)} páginas")
    with open(os.path.join(PAGES, "..", "allimages.json"), "w") as f:
        json.dump(all_images(), f, indent=0)
    for page in EXTRA:
        if force or not os.path.exists(os.path.join(PAGES, page + ".html")):
            save(page, get(page))


if __name__ == "__main__":
    main()
