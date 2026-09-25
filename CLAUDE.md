# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Unofficial *Graveyard Keeper* guide as a native SwiftUI app for iOS 17+ / macOS 14+ with a pixel-art look. It currently covers the first game; GK2 content is planned. UI text, code comments and test names are in Spanish. Item and station names stay in English, as on the wiki.

## Commands

```bash
xcodegen generate                 # regenerate GK2Guia.xcodeproj (not versioned) after editing project.yml or adding/removing files
open GK2Guia.xcodeproj            # build/run from Xcode (My Mac, simulator or device)

./scripts/test.sh                 # GK2Core tests; also works with only the Command Line Tools (adds Testing.framework flags)
./scripts/test.sh --filter PlannerTests/deep   # single test (args are passed through to `swift test`)
swift test --package-path Packages/GK2Core     # what CI runs (.github/workflows/ci.yml, macos-15)
```

Tests use Swift Testing (`@Test`, `#expect`), not XCTest. Only `GK2Core` has tests. The app target has none.

Regenerate data from the wiki (requires network; the cache goes to `scripts/wiki/cache/`, which is gitignored):

```bash
python3 scripts/wiki/fetch.py && python3 scripts/wiki/convert.py && python3 scripts/wiki/images.py && ./scripts/test.sh
```

## Architecture

Two layers:

- **`Packages/GK2Core`** (SwiftPM, no UI): models, bundled JSON data and the planner. Everything that can be tested lives here.
  - `GameData` loads `Resources/*.json` via `Bundle.module` (`GameData.bundled`) and builds lookup indexes. `recipe(producing:)` returns the **first** recipe for an output item. Both the planner and the UI depend on this, so the order in `recipes.json` matters. `convert.py` controls that order (`recipe_rank`): the recipe listed first on the item's own wiki page wins.
  - `Planner.requirements(for:recipes:deep:)` is a pure function. With `deep`, it expands craftable ingredients down to raw materials, reuses batch surplus (`outputQty`), treats cycles as raw materials, and returns intermediate `steps` with dependencies first. The planned targets themselves are removed from `steps`. The plan is iterated in sorted key order so output is deterministic.
  - `Sprites.swift` holds 8×8 sprites as strings (one char per pixel, `.` = transparent) plus a palette. Entities have a wiki `image` (in `Resources/Images/<image>.png`) and fall back to the `icon` sprite when it is missing.
  - `DataIntegrityTests` check every cross-reference: item IDs in recipes/NPCs, day IDs, icons, image files, sprite dimensions, and that the planner terminates on all recipes. Run the tests after any JSON or converter change.
- **`GK2Guia/`** (app target, defined in `project.yml`, depends on GK2Core):
  - `State/AppState.swift`: `@Observable` player state (`plan` = recipeId → count, `owned` inventory, `today`, `deepBreakdown`). Each property persists to `UserDefaults` in `didSet` (keys `gk2.*`). `requirements` is computed on the fly from `Planner`.
  - `State/Router.swift`: shared navigation so screens can jump across tabs (e.g. ingredient → its recipe, → character). Wide layouts (Mac/iPad regular size class) use the selection (`recipeId`, `characterId`). iPhone uses the stack paths (`recipePath`, `characterPath`).
  - `Views/ContentView.swift` switches between the wide layout (header + top tabs, two columns) and the compact one (bottom tab bar), and exposes this through `\.isWideLayout`.
  - `Theme/`: palette, bundled pixel fonts (`.pixelTitle` = Press Start 2P, `.pixelBody` = VT323), `PixelBox` borders and `PixelIcon` (wiki image or sprite).

## Data

JSON in `Packages/GK2Core/Sources/GK2Core/Resources/` is **generated** by `scripts/wiki/convert.py`. Manual edits get overwritten on the next conversion, so persistent data fixes belong in the converter. Hand-editing is still supported (see the README table for fields). Notable conventions:
- `characters.json`: `days: []` means the character appears every day. `quests` come from the `Quests`/DLC sections of each NPC page and `friendship` from sentences like "At 20 {{Happiness}}…". Both are heuristic (`REWARD_RE`, `REQUIRES`, `GAINS` in `convert.py`); `rewards` vs `items` is a best guess. Completed quests persist in `AppState.doneQuests` as `"npcId/questId"`, so keep quest ids stable.
- `days.json` order is the in-game week order. `data.day(after:)` wraps around.
- Build recipes found on location pages get the station `"Construcción · <lugar>"`.
- To add a new icon, add an 8×8 sprite to `Sprites.all` using palette characters only.
