# noHeroes3 — Plan

Forward-looking execution plan: the *what next*. For *why* each decision was made and the
full constraint list, see [`CLAUDE.md`](./CLAUDE.md). The original brainstorm is archived in
[`docs/archive/`](./docs/archive/) (superseded).

## Goal

A personal Godot game that remakes a few **Heroes of Might and Magic III** maps for **one
player — the author's wife** — to play on her **Android tablet, in bed, at night**. Never
distributed.

## Non-goals

- Not a HoMM3 clone, not the full game (no towns / economy / campaigns for now).
- Not procedural map generation; not a map-analysis tool.
- No LLM / online opponent; no multiplayer.
- No distribution while using original assets.

## Definition of done (MVP)

She can pick a remade map on her tablet, explore it by touch, fight one battle against a
deterministic AI, and **put it down and resume across nights** — all in a **dark,
silent-friendly** UI that won't wake a sleeping spouse.

## Architecture (target)

```
core/   pure data, no rendering   → GameState (turn/seeded RNG), MapModel, Hero
map/    rendering & camera         → MapView, CameraRig, FogLayer
input/  touch → input actions      → TouchInput (tap-move, drag-pan, pinch-zoom)
combat/ battle scene + AI          → Battle, BattleAI (deterministic)
assets/ swappable layer            → AssetLibrary (logical name → file via manifest.json)
ui/                                → HUD
tooling/ Python, build-time only   → extract_lod, def_to_atlas, h3m_to_json
```

Principles that keep it reviewable:
1. **`core/` never touches rendering** — auditable, testable; the Python-converted JSON loads
   straight into `MapModel`.
2. **`AssetLibrary` is the swappable layer** — nothing references a file path, only logical
   names. Swap the manifest, swap the art (the distribution escape hatch).
3. **Deterministic seeded RNG** in `GameState` — reproducible AI and combat.

## Milestones (each leaves the game runnable + independently reviewable)

- **M0 — Scaffold.** ✅ `project.godot`, folder tree, stubbed GDScript with interfaces.
- **M1 — Map on screen.** ✅ `MapModel` → `MapView` renders real HD terrain tiles (placeholder
  colours remain as the fallback when `assets/` isn't built); camera pans/zooms by touch.
- **M2 — Move a hero.** ✅ Tap a tile → `Pathfinder` (A* over passability) → hero walks as far
  as movement points allow; End Turn refills. *Touch loop proven.*
- **M3 — The look + persistence.** ✅ Fog-of-war as a real mechanic (`FogModel`
  HIDDEN/EXPLORED/VISIBLE + `FogView` veil); luminous night lighting (`FogLayer` CanvasModulate +
  a warm hero `Light2D`); real HoMM3 terrain + directional animated hero via `AssetLibrary`; and
  autosave + instant resume (`SaveGame`, autosaves on move/turn/app-pause, resumes on launch).
- **M4 — Combat.** ⬜ Enter a hex battle scene, deterministic AI opponent, resolve, return to map.

## Asset pipeline (Python, build-time)

The game uses the **HD Edition** look (64px tiles, x2 art). Two sources feed `assets/` +
`manifest.json` (the swappable layer; kept out of any future distribution):
- **HD pixels** — `pak_to_atlas.py` unpacks the Steam HD `.pak` (DXT/DDS): zlib-inflate → Pillow
  DDS decode → crop sprite (rotating `rot=1` 90° CW).
- **Classic geometry** — `extract_lod.py` + `def_to_atlas.py` (GOG `.lod`/`.def`; supplies the
  per-frame group/margin layout the HD pak drops) + `pcx_to_png.py` for stills.

Per-game builders compose them: `build_terrain_assets.py` (cleanest 64px fill tile per terrain)
and `build_hero_assets.py` (HD pixels + classic layout → directional atlas). All ✅ and verified
in-game; both the Steam HD and GOG Complete installs are required to (re)build.

## Map pipeline (Python, build-time)

`h3m_to_json.py`: gzip-inflate `.h3m` → parse per VCMI semantics → emit map JSON into
`data/maps/`. Authority order for the format: VCMI > HeroWO/h3m2json > `h3m_description` spec.
Start with **one** hand-picked, simple map.

## Engine config (decided)

- **Godot 4.7 stable, Standard build (GDScript)** — not the .NET build. (Targeting the version
  installed at `C:\devel\godot`; M1 code validated against it headless.)
- **Compatibility renderer** (`gl_compatibility`) for broad Android safety. Consequence: no
  reliable `WorldEnvironment` glow on Android → get the bloom look via **additive-blend
  sprites/materials + `Light2D`** (renderer-agnostic; the ypilot trick), not post-processing.
- **`TileMapLayer`** nodes, never the deprecated `TileMap`.
- **Export/debug on the real Android tablet from M0 onward** — touch is designed in, not bolted on.

## Open items

- [x] **Godot version** — 4.7 stable / Standard / GDScript (see Engine config above).
- [ ] Which map(s) to remake first (a small, simple one for M1).
- [ ] Creature / army subset for the combat MVP (M4).
