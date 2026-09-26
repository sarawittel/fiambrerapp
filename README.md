# Fiambrerapp · Graveyard Keeper

App nativa en SwiftUI para **iPhone**: una guía no oficial de *Graveyard Keeper* con estética pixel art. De momento cubre el primer juego; la idea es añadir *Graveyard Keeper 2* después.

- **Recetas**: buscador (ignora tildes), filtro por estación, ingredientes enlazados a su receta y "se usa en".
- **Qué necesito**: añade recetas a tu plan y calcula los materiales. Puede desglosarlos hasta materias primas, aprovechando el excedente de cada lote. Apuntas lo que tienes y te dice qué falta, dónde conseguirlo, quién lo vende y en qué orden fabricar.
- **Tecnologías**: árboles con coste, requisitos y lo que desbloquea; buscador por tecnología o por el objeto que desbloquea.
- **GK1 / GK2**: el botón de arriba cambia de juego en cualquier momento. Cada juego guarda su propia partida (plan, inventario, misiones, tecnologías y logros). GK2 tiene sus propios datos, sacados de la wiki de GK2: objetos, recetas, personajes, misiones, tecnologías, logros y la guía para principiantes (pasos que se pueden marcar como hechos). De momento no tiene días ni amistad.
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
- **Con [iloader](https://github.com/nab138/iloader) + LiveContainer** (recomendado sin Xcode): ver abajo.

### Instalar con iloader y LiveContainer

[iloader](https://github.com/nab138/iloader) firma apps con tu Apple ID (como Xcode) y las instala por USB. Con la opción **LiveContainer + SideStore** instala [LiveContainer](https://github.com/LiveContainer/LiveContainer), una app contenedor que ejecuta otras apps dentro sin instalarlas por separado. Así solo LiveContainer ocupa uno de los **3 huecos** de un Apple ID gratuito y solo hay que renovar su firma. [SideStore](https://sidestore.io) va integrado y renueva la firma desde el propio iPhone.

> [!Warning]
> El SideStore integrado en **LiveContainer 3.8.0** (la versión *Stable* que instala iloader) no deja iniciar sesión: al pulsar *Sign in* sale «The data couldn't be read because it isn't in the correct format» ([LiveContainer #1620](https://github.com/LiveContainer/LiveContainer/issues/1620)). Los mantenedores lo dan por arreglado en la **nightly** (3.8.10): descarga [`LiveContainer+SideStore.ipa`](https://github.com/LiveContainer/LiveContainer/releases/download/nightly/LiveContainer%2BSideStore.ipa) de la [release nightly](https://github.com/LiveContainer/LiveContainer/releases/tag/nightly) e instálala como `.ipa` propio en lugar de pulsar el botón *Stable*. Si iloader no deja elegir un `.ipa`, usa [Impactor](https://github.com/khcrysalis/Impactor/releases/latest): añade el Apple ID en el engranaje, arrastra el `.ipa`, marca **Only Register Main Bundle** y pulsa **Install**. La nightly se genera automáticamente con cada cambio y puede tener fallos; cuando salga una versión estable posterior, vuelve a la *Stable*.

Instalación (una vez):

1. Conecta el iPhone por cable, abre iloader, inicia sesión con tu Apple ID e instala **LiveContainer + SideStore** (la nightly, ver el aviso de arriba). Usa siempre el mismo Apple ID: así se instala encima sin perder datos.
2. **Confía en el certificado**: *Ajustes → General → VPN y gestión de dispositivos*, toca tu Apple ID (en «App de desarrollador») y pulsa *Confiar*. Sin esto la app se cierra al abrirla o sale «Desarrollador no fiable».
3. **Activa el Modo de desarrollador** (iOS 16+): *Ajustes → Privacidad y seguridad → Modo de desarrollador* (al final). El iPhone se reinicia y pide confirmarlo.
4. **Coloca el pairing file**: en iloader, *Manage Pairing File* → **Place** en la fila de LiveContainer (con el iPhone conectado). Es lo que permite al SideStore integrado hablar con el iPhone para instalar y renovar. No uses *Export*: ese archivo da acceso al iPhone a quien lo tenga.
5. **Conecta la VPN local**: instala **LocalDevVPN** desde la App Store, ábrela y pulsa *Connect* (debe salir el icono VPN en la barra de estado). En SideStore, *Settings → Health Check* debería mostrar en verde *VPN Tunnel*, *Device Reachability* y *Pairing file*. *Developer Disk Image* sin montar es normal: solo hace falta para JIT.
6. **Inicia sesión en el SideStore integrado**: en LiveContainer, pestaña *Apps*, toca el botón de SideStore (arriba a la izquierda) → *Settings* → inicia sesión con tu Apple ID (si ya aparece una sesión, cierra sesión y vuelve a entrar). El login no necesita la VPN, solo internet.
7. **Renueva la firma una vez**: con la VPN conectada, *My Apps* → **Refresh All**. Así SideStore guarda el certificado.
8. **Importa el certificado en LiveContainer**: sal de SideStore y, en los *Ajustes* de LiveContainer, pulsa **Import Certificate from SideStore**. Si ha ido bien, el botón pasa a decir *Remove Certificate*; puedes comprobarlo en *JIT-Less Mode Diagnose*. Sin certificado, LiveContainer no puede firmar las apps de dentro y avisa de que lo importes.

Si al iniciar sesión en SideStore falla:

- **«The data couldn't be read because it isn't in the correct format» nada más pulsar *Sign in***: si usas la 3.8.0, instala la nightly (aviso de arriba). Si no, el fallo está en el servidor de *anisette* (SideStore lo consulta antes de mandar nada a Apple): en *Settings → Anisette Server* pulsa **Reset adi.pb**, elige otro servidor (el oficial `ani.sidestore.io` o `ani.npeg.us`; evita los `http://`), cierra LiveContainer desde el multitarea y vuelve a intentarlo. Prueba también con datos móviles por si la wifi bloquea el servidor.
- **«Certificate not found» al importar**: en SideStore → *Settings*, al final, pulsa **Export Signing Certificate...**, ponle una contraseña y guárdalo. En LiveContainer → *Ajustes* → **Import Certificate**, elige ese archivo y escribe la contraseña.
- **Health Check se queda en «checking status»**: desconecta el cable USB, desconecta y vuelve a conectar LocalDevVPN y reabre LiveContainer.

Instalar o actualizar Fiambrerapp:

1. `./scripts/ipa.sh` genera `build/Fiambrerapp.ipa` sin firmar.
2. Pásalo al iPhone (AirDrop o Archivos).
3. En LiveContainer pulsa **+** y elige el `.ipa`.

Acceso directo en la pantalla de inicio (opcional):

1. En LiveContainer, mantén pulsada Fiambrerapp → *Add to Home Screen* → **Copy Launch URL**. Copia algo como `livecontainer://livecontainer-launch?bundle-name=local.gk2guia.app.app&container-folder-name=<UUID>`. Usa la URL tal cual: el `.app.app` es correcto.
2. Compruébala pegándola en Safari: debe abrir Fiambrerapp.
3. En la app **Atajos**, crea un atajo nuevo con la acción **Abrir URL** y pega la URL.
4. Ponle el nombre `Fiambrerapp` (y un icono, si quieres) y pulsa compartir → **Añadir a pantalla de inicio**.

El atajo abre LiveContainer un instante y luego lanza la app. Actualizar el `.ipa` normalmente conserva la URL. Si borras la app y la vuelves a instalar en LiveContainer, cambia el UUID del contenedor y hay que copiar la URL otra vez.

A tener en cuenta:

- Con Apple ID gratuito la firma de LiveContainer **caduca a los 7 días**: renuévala desde el SideStore integrado (necesita su VPN local activa). Las apps de dentro no caducan por separado. Si LiveContainer llega a caducar, vuelve a instalarlo con iloader y el cable.
- Usa siempre el mismo Apple ID; con otro, iOS lo trata como otra app.
- En iloader deja desmarcado **Don't use keyring**: en macOS el Llavero funciona, y con esa opción los certificados, el estado de anisette y los pairing files se guardan en disco sin cifrar.
- Los datos de Fiambrerapp viven dentro de LiveContainer: se conservan al actualizar el `.ipa`, pero se pierden si borras la app en LiveContainer o LiveContainer entero.
- Algunas apps (extensiones, widgets, ciertos permisos) no funcionan dentro del contenedor; esas se instalan aparte con SideStore y ocupan un hueco.

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
scripts/ipa.sh               Genera build/Fiambrerapp.ipa (Release, sin firmar) para iloader
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
