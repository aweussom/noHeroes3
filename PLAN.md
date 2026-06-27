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

- **M0 — Scaffold.** `project.godot`, folder tree, stubbed GDScript with interfaces. *Blocked
  on: Godot version choice.*
- **M1 — Map on screen.** `h3m_to_json.py` converts one map → `MapModel` → `MapView` renders
  tiles + objects; camera pans/zooms by touch. *Proves parser + renderer + coordinate system.*
- **M2 — Move a hero.** Tap a tile → hero pathfinds and moves, movement points spent. *Proves
  the touch loop.*
- **M3 — The look + persistence.** Dark luminous-on-black theme, fog-of-war (CanvasModulate +
  Light2D), glow layer; autosave + instant resume. *Proves it's pleasant to play in bed.*
- **M4 — Combat.** Enter a hex battle scene, deterministic AI opponent, resolve, return to map.

## Asset pipeline (Python, build-time)

`extract_lod.py` (GOG `.lod` → `.def`/`.pcx`) → `def_to_atlas.py` (`.def` → PNG atlas + frame
JSON) → drop into `assets/` and register in `manifest.json`. Source: the **GOG Complete
(RoE+AB+SoD)** install — *not* the Steam HD Edition. Output is the swappable layer; kept out of
any future distribution.

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
