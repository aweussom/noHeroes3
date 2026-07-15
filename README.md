# noHeroes3

A personal Godot 4 game that remakes a few **Heroes of Might and Magic III** maps for **one
player** to play on an **Android tablet, in bed, at night**. Not a clone, not commercial,
**never distributed**. The *why* behind every decision — and the play-context constraints that
drive the design (dark, silent, pausable-to-the-second) — live in [`CLAUDE.md`](./CLAUDE.md);
the forward plan and milestones live in [`PLAN.md`](./PLAN.md).

> **Assets are original HoMM III art** (the **HD Edition** look), extracted locally from owned
> copies — HD pixels from the Steam HD `.pak`, sprite geometry from the GOG `.lod`. Legal only
> because this is purely personal and never published. The extracted art is gitignored
> (`assets/`) and the game references it through a swappable manifest, never by hard path — so
> the art can be replaced without touching code if distribution is ever wanted.

## Status

| Milestone | State |
|-----------|-------|
| **M1** — map on screen (model, placeholder terrain, touch camera) | ✅ done |
| **M2** — move a hero (A* pathfinding, tap-to-move, movement budget) | ✅ done |
| **M3** — the look + persistence (fog-of-war, night lighting, real art, autosave/resume) | ✅ done |
| **M4** — combat (hex battlefield, turn order, movement, attacks/damage/retaliation) | 🟡 in progress |

M4 so far (M4.1–M4.5): a battle runs end-to-end against a deterministic AI opponent — real HD
creature sprites on a night-dimmed HoMM3 battlefield — entered via a debug HUD button with test
armies. Still to come: the result applied back to the map, battles triggered by map monsters,
and battle state in the autosave — see [`PLAN.md`](./PLAN.md).

**Asset pipeline (Python, build-time):** ✅ complete and verified in-game (HD `.pak` pixels +
classic `.lod`/`.def` geometry — see below).

## Layout

```
src/        Godot game (GDScript)
  core/     pure data, no rendering — GameState, MapModel, Hero, FogModel, Pathfinder, SaveGame
  map/      rendering & camera — MapView, HeroView, FogView, FogLayer, CameraRig
  input/    touch → intents — TouchInput
  combat/   hex battle — BattleModel, BattleView, BattleField, Creature, CreatureStack, BattleAI
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

The game uses the **HD Edition** look: HD pixels from the Steam HD `.pak` archives, with sprite
geometry (group/frame layout, margins) from the classic GOG `.lod`/`.def`. To (re)generate the
in-game assets — needs both installs, plus Pillow/numpy:

```sh
# regenerate everything the game loads (writes assets/ + manifest.json)
python tooling/build_terrain_assets.py     # cleanest 64px fill tile per terrain (HD pak)
python tooling/build_hero_assets.py        # HD hero pixels + classic layout -> directional atlas
python tooling/build_battle_assets.py      # creature idle atlases + battlefield background
```

Underlying tools (run directly to inspect/extract):

```sh
HD="C:/Program Files (x86)/Steam/steamapps/common/Heroes of Might & Magic III - HD Edition/data"
LOD="C:/Program Files (x86)/GOG Galaxy/Games/HoMM 3 Complete/Data"

python tooling/pak_to_atlas.py "$HD/sprite_DXT_com_x2.pak" --list          # HD .pak: entries
python tooling/pak_to_atlas.py "$HD/sprite_DXT_com_x2.pak" --extract AH00_ --out-dir _out
python tooling/extract_lod.py  "$LOD/H3sprite.lod" --list                   # classic .lod members
python tooling/def_to_atlas.py "$LOD/H3sprite.lod" --name GRASTL.def --out-dir _out
python tooling/pcx_to_png.py   "$LOD/H3bitmap.lod" --name GamSelBk.pcx --out-dir _out
```

Format authority order when references disagree: **VCMI** > **HeroWO/h3m2json** >
`h3m_description` spec (see [`reference/README.md`](./reference/README.md)).
