# Guía del Guardián · Graveyard Keeper 2

Guía interactiva no oficial de **Graveyard Keeper 2** con estética pixel art. Funciona como web, como app de iOS y como app de macOS a partir del mismo código.

- **Recetas**: buscador y filtro por estación, ingredientes enlazados y "se usa en".
- **Qué necesito**: añade recetas a tu plan y calcula los materiales. Puede desglosarlos hasta materias primas, aprovechando el excedente de cada lote. Apunta lo que ya tienes y te dice dónde conseguir el resto y quién lo vende hoy.
- **Calendario**: el día actual de la semana, quién está hoy, quién llega mañana y una tabla semanal.
- **Personajes**: fichas con ubicación, días de visita y qué compran y venden.

El plan, el inventario y el día actual se guardan en el navegador (`localStorage`).

> ⚠️ Los datos incluidos son **de ejemplo**. Sustitúyelos por los del juego en `src/data/`.

## Web

```bash
npm install
npm run dev        # http://localhost:5173
npm test           # tests del calculador e integridad de datos
npm run build      # genera dist/
```

## iOS y macOS

`apple/` contiene una app SwiftUI multiplataforma que empaqueta `dist/` en un `WKWebView`. Los archivos se sirven con un esquema propio, `gk2://`. No hace falta publicarla.

Requisitos: **Xcode** (App Store) y [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
npm run apple      # build web + genera apple/GK2Guia.xcodeproj + abre Xcode
```

En Xcode:
- **Mac**: elige el destino *My Mac* y pulsa ▶.
- **iPhone/iPad**: en *Signing & Capabilities* elige tu *Team*; basta un Apple ID gratuito. Conecta el dispositivo y pulsa ▶. Con una cuenta gratuita la app caduca a los 7 días y hay que volver a instalarla desde Xcode.

Xcode recompila la web en cada build (fase *Build web*), así que los cambios en `src/` llegan a la app. El `.xcodeproj` se genera y no se versiona: si tocas `apple/project.yml`, vuelve a ejecutar `xcodegen generate`.

## Añadir datos

| Archivo | Contenido |
| --- | --- |
| `src/data/items.ts` | Objetos: id, nombre, icono, dónde se consiguen |
| `src/data/recipes.ts` | Recetas: estación, ingredientes, unidades por lote |
| `src/data/days.ts` | Días de la semana, en orden |
| `src/data/characters.ts` | Personajes: días (`[]` = todos), qué venden y compran |
| `src/components/icons.ts` | Sprites de 8×8 píxeles (un carácter por píxel) |

`npm test` avisa si una receta o un personaje hacen referencia a un objeto o día que no existe.

---

Proyecto de fans sin relación con Lazy Bear Games ni tinyBuild.
