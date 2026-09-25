#!/usr/bin/env python3
"""Descarga el wikitext de todos los artículos de la wiki de Graveyard Keeper a cache/pages.json."""
import json, os, time, urllib.parse, urllib.request

API = "https://graveyardkeeper.fandom.com/api.php"
OUT = os.path.join(os.path.dirname(__file__), "cache", "pages.json")


def get(params):
    params = {**params, "format": "json", "formatversion": "2"}
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(params), headers={"User-Agent": "gk-guia/1.0 (personal guide)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def all_titles():
    titles, cont = [], {}
    while True:
        d = get({"action": "query", "list": "allpages", "apnamespace": 0, "apfilterredir": "nonredirects", "aplimit": 500, **cont})
        titles += [p["title"] for p in d["query"]["allpages"]]
        if "continue" not in d:
            return titles
        cont = d["continue"]


def redirects():
    """alias -> título destino"""
    out, cont = {}, {}
    while True:
        d = get({"action": "query", "generator": "allredirects", "garnamespace": 0, "garlimit": 500, "prop": "info", "redirects": 1, **cont})
        for r in d["query"].get("redirects", []):
            out[r["from"]] = r["to"]
        if "continue" not in d:
            return out
        cont = d["continue"]


def main():
    titles = all_titles()
    pages = {}
    for i in range(0, len(titles), 50):
        d = get({"action": "query", "prop": "revisions|categories", "rvprop": "content", "rvslots": "main", "cllimit": "max", "titles": "|".join(titles[i:i + 50])})
        for p in d["query"]["pages"]:
            if "revisions" in p:
                pages[p["title"]] = {
                    "text": p["revisions"][0]["slots"]["main"]["content"],
                    "categories": [c["title"].removeprefix("Category:") for c in p.get("categories", [])],
                }
        time.sleep(0.3)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump({"pages": pages, "redirects": redirects()}, f, ensure_ascii=False)
    print(f"{len(pages)} páginas")


if __name__ == "__main__":
    main()
