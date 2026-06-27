# noHeroes3

A personal Godot 4 game that remakes a few **Heroes of Might and Magic III** maps for **one
player** to play on an **Android tablet, in bed, at night**. Not a clone, not commercial,
**never distributed**. The *why* behind every decision — and the play-context constraints that
drive the design (dark, silent, pausable-to-the-second) — live in [`CLAUDE.md`](./CLAUDE.md);
the forward plan and milestones live in [`PLAN.md`](./PLAN.md).

> **Assets are original HoMM III art**, extracted locally from an owned GOG copy. Legal only
> because this is purely personal and never published. The extracted art is gitignored
> (`assets/`) and the game references it through a swappable manifest, never by hard path — so
> the art can be replaced without touching code if distribution is ever wanted.

## Status

| Milestone | State |
|-----------|-------|
| **M1** — map on screen (model, placeholder terrain, touch camera) | ✅ done |
| **M2** — move a hero (A* pathfinding, tap-to-move, movement budget) | ✅ done |
| **M3** — the look (fog-of-war + luminous night lighting) | 🟡 part 1 done; real sprites + persistence pending |
| **M4** — combat | ⬜ not started |

**Asset pipeline (Python, build-time):** stage 1 `extract_lod` ✅ · stage 2 `pcx_to_png` ✅ ·
stage 3 `def_to_atlas` 🟡 in progress.

## Layout

```
src/        Godot game (GDScript)
  core/     pure data, no rendering — GameState, MapModel, Hero, FogModel, Pathfinder
  map/      rendering & camera — MapView, HeroView, FogView, FogLayer, CameraRig
  input/    touch → intents — TouchInput
  ui/       HUD
tooling/    Python, build-time only — the asset & map pipelines (see below)
data/maps/  converted map JSON (loaded by MapModel)
assets/     extracted art (gitignored) + manifest.json (tracked)
reference/  local clones of HoMM3 format authorities (VCMI, h3m2json) — gitignored
docs/       archived original brainstorm notes
```

## Running the game

Godot 4.7-stable (Standard build) lives at `C:\devel\godot\Godot_v4.7-stable_win64_console.exe`.

```sh
# play in the editor
"C:/devel/godot/Godot_v4.7-stable_win64_console.exe" --path .
# headless sanity boot (parses every script/scene, then quits)
"C:/devel/godot/Godot_v4.7-stable_win64_console.exe" --headless --quit-after 40 --path .
```

## Asset pipeline

Original art lives in the GOG **Complete** install's `Data/*.lod` archives. Three stages turn it
into PNGs Godot can load (all stdlib + Pillow/numpy; run with the system `python`):

```sh
LOD="C:/Program Files (x86)/GOG Galaxy/Games/HoMM 3 Complete/Data"

# 1. inspect / extract raw members from a .lod archive
python tooling/extract_lod.py "$LOD/H3bitmap.lod" --list
python tooling/extract_lod.py "$LOD/H3sprite.lod" --out _extracted --filter .def

# 2. still images: .pcx → PNG (reads a .lod member directly, or a loose .pcx)
python tooling/pcx_to_png.py "$LOD/H3bitmap.lod" --name GamSelBk.pcx --out-dir _out

# 3. animated sprites: .def → PNG atlas + frame JSON  (terrain tiles, heroes, creatures)
python tooling/def_to_atlas.py "$LOD/H3sprite.lod" --name GRASTL.def --out-dir _out
```

Format authority order when references disagree: **VCMI** > **HeroWO/h3m2json** >
`h3m_description` spec (see [`reference/README.md`](./reference/README.md)).
```
