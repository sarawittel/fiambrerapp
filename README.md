# Fiambrera · Graveyard Keeper

App nativa en SwiftUI para **iPhone**: una guía no oficial de *Graveyard Keeper* con estética pixel art. De momento cubre el primer juego; la idea es añadir *Graveyard Keeper 2* después.

- **Recetas**: buscador (ignora tildes), filtro por estación, ingredientes enlazados a su receta y "se usa en".
- **Qué necesito**: añade recetas a tu plan y calcula los materiales. Puede desglosarlos hasta materias primas, aprovechando el excedente de cada lote. Apuntas lo que tienes y te dice qué falta, dónde conseguirlo, quién lo vende y en qué orden fabricar.
- **Tecnologías**: árboles con coste, requisitos y lo que desbloquea; buscador por tecnología o por el objeto que desbloquea.
- **GK1 / GK2**: el botón de arriba cambia de juego en cualquier momento. Cada juego guarda su propia partida (plan, inventario, misiones, tecnologías y logros). GK2 comparte con GK1 objetos, recetas, tecnologías, personajes y días, pero no misiones, amistad ni logros.
- **Personajes**: buscador (nombre, papel o lugar), filtro por día, días de visita y qué compran y venden.

El plan, el inventario y el día actual se guardan en el dispositivo. Se navega con pantallas apiladas y una barra de pestañas inferior.

Los datos (≈570 objetos, ≈670 recetas, 41 personajes y la semana de 6 días) se extraen de la [wiki de Graveyard Keeper](https://graveyardkeeper.fandom.com/wiki/Graveyard_Keeper_Wiki) (CC BY-SA). Los nombres de objetos y estaciones están en inglés, como en la wiki.

## Ejecutar (sin publicar nada)

Requisitos: **Xcode** (gratis en la App Store) y [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
open GK2Guia.xcodeproj
```

- **iPhone**: en *Signing & Capabilities* elige tu *Team*; basta un Apple ID gratuito. Conecta el dispositivo, actívale el *Modo desarrollador* y pulsa ▶. Con cuenta gratuita la instalación caduca a los 7 días; se reinstala con otro ▶.
- **Simulador**: elige cualquier iPhone del menú de destinos.

El `.xcodeproj` no se versiona. Si cambias `project.yml` o añades archivos, vuelve a ejecutar `xcodegen generate`.

## Estructura

```
project.yml                  Definición del proyecto Xcode (XcodeGen)
GK2Guia/                     App SwiftUI (iOS)
  Theme/                     Colores, fuentes, bordes de píxel, iconos
  State/                     Estado persistente y navegación
  Views/                     Pantallas y componentes
  Resources/                 Fuentes pixeladas (OFL) e icono
Packages/GK2Core/            Modelos, datos y calculador (sin UI, con tests)
  Sources/GK2Core/Data/      items.json, recipes.json, days.json, characters.json, stations.json, technologies.json, guide.json, Images/
  Sources/GK2Core/Sprites.swift   Sprites de 8×8 (un carácter por píxel)
scripts/test.sh              Tests; funciona también sin Xcode
scripts/wiki/                fetch.py + convert.py: importan los datos desde la wiki
```

## Actualizar los datos desde la wiki

```bash
python3 scripts/wiki/fetch.py     # descarga todos los artículos a scripts/wiki/cache/ (no se versiona)
python3 scripts/wiki/convert.py   # regenera los JSON de GK2Core/Data
python3 scripts/wiki/images.py    # descarga las imágenes a GK2Core/Data/Images y vuelve a ejecutar convert.py
./scripts/test.sh
```

Cada objeto, personaje, día y estación de trabajo lleva un campo `image` con su imagen de la wiki (`Data/Images/<image>.png`). Si no tiene imagen, la app dibuja el sprite de `icon`.

`convert.py` lee las plantillas de la wiki (`Item Infobox`, `NPC Infobox`, tablas *Item Produced / Materials Required*, secciones *Selling/Purchasing*). Las recetas de construcción que aparecen en páginas de lugares salen como estación *"Construcción · lugar"*. Si una receta aparece en varias páginas, se da prioridad a la página de la estación. La primera receta de cada objeto (la que usa el planificador) es la que aparece primero en la página del objeto.

Los textos de la wiki (descripciones, encargos, amistad, tecnologías y logros) se traducen con `scripts/wiki/es.json`: texto en inglés tal como sale de la conversión → traducción. Los nombres de objetos se traducen con `scripts/wiki/es_items.json` (el de la wiki queda en `wikiName` y también se puede buscar por él); los de estaciones y tecnologías, con `scripts/wiki/es_names.json`; los títulos de los encargos, con `scripts/wiki/es_quests.json` (si el título es el nombre de un objeto se usa su nombre en español; el `id` sigue saliendo del título en inglés); los nombres de los logros, con `scripts/wiki/es_achievements.json` (el de la wiki queda en `wikiName`, el `id` sale del nombre en inglés y los logros citados entre comillas en los textos también se traducen). Los textos de enlace que no son el nombre exacto («autopsies», «Clotho's») se traducen en `scripts/wiki/es_labels.json`. Los personajes sin nombre propio (Beekeeper, Bishop…) se traducen con `scripts/wiki/es_characters.json` (el de la wiki queda en `wikiName`, y en los textos se cambian también, con su artículo: «a Bishop» → «al Obispo»); los nombres propios y los de lugares se quedan en inglés. Si la wiki cambia un texto, `convert.py` avisa de cuántos quedan sin traducir y los deja en inglés hasta que se añadan; una traducción solo se usa si conserva los mismos enlaces `gk2://` en el mismo orden.

## Añadir datos a mano

| Archivo | Contenido |
| --- | --- |
| `items.json` | Objetos: `id`, `name` (en español), `wikiName` (el de la wiki, si es distinto), `category`, `icon`, `sources` (dónde se consiguen), `quality` (bronce/plata/oro: `energy`, `buy`, `sell` y `value` en monedas de cobre), `study` (puntos de tecnología, fe, ciencia, energía y `decomposes`) |
| `recipes.json` | Recetas: `output`, `outputQty` (unidades por lote), `station`, `ingredients` |
| `days.json` | Días de la semana, en orden, con `icon` y `color` |
| `characters.json` | Personajes: `days` (`[]` = todos los días), `sells`, `buys`, `quests` (encargos: `text` en Markdown con enlaces `gk2://item/<id>` y `gk2://character/<id>`, `rewards`, `items`, `characters`, `friendship` = ♥ que se ganan, `dlc`) y `friendship` (niveles de amistad: `level`, `text`, `items`) |
| `technologies.json` | Árboles de tecnología en el orden de la wiki: `branches` → `techs` con `cost` (`red`, `green`, `blue`, `soul`), `condition` (Markdown, como las misiones), `requires` (ids de tecnologías del mismo árbol) y `unlocks` (`kind` = `blueprint`/`create`/`extract`/`gathering`/`perk`/`recipe`, `name`, `item` si existe) |
| `guide.json` | Guía de logros al 100 % (página «100% Achievement Guide»): apartados con `spoiler` y `achievements` (`text` en Markdown, como las misiones; `missable`, `dlc`, `items`, `characters`). Los logros conseguidos se guardan por `id` |

Para un icono nuevo, añade un sprite en `Sprites.swift`: 8 filas de 8 caracteres con los colores de la paleta.

```bash
./scripts/test.sh
```

Los tests avisan si una receta o un personaje hacen referencia a un objeto, día o icono que no existe.

## Créditos

Fuentes [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P) y [VT323](https://fonts.google.com/specimen/VT323), con licencia SIL Open Font License (incluida en `GK2Guia/Resources/Fonts`).

Proyecto de fans sin relación con Lazy Bear Games ni tinyBuild.
