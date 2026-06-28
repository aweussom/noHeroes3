# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A personal Godot game with exactly **one player — the author's wife** — that remakes a few **Heroes of Might and Magic III (1999)** maps for her to play on her **Android tablet** at night. Not a clone, not commercial, **not distributed**. Single-audience hobby project. The Norwegian `NOTES-*.md` files are the original brainstorm; the decisions below supersede them where they conflict.

## Play context (drives design)

She plays **in bed, in the dark, late at night, next to a sleeping person**, for long sessions spread across many nights. Concrete constraints:

- **Dark by default, luminous-on-black.** Low screen brightness; no large bright/white surfaces (would light the room / wake the spouse). The glow/lighting layer is functional, not just aesthetic.
- **Silent-first.** Audio fully optional and never the only channel for feedback — anything conveyed by sound must also be visible. Assume muted play.
- **Pausable & resumable to the second.** Turn-based suits this perfectly. **Autosave constantly + instant resume** is first-class — she drops it the moment she's drowsy and picks it up cold another night.
- **Sleepy one-handed play.** Generous touch targets, relaxed pacing, no timers or twitch reflexes.

## Working arrangement (read this first)

- **Claude writes the code (GDScript). The author reviews it.** The author reads code fluently but prefers not to write it. Optimize for **readable, well-structured, explained code over clever code** — code that can be audited at a glance. Keep it **modular from the start** (the sibling `ypilot` project is one 3,367-line file — explicitly avoid that here).
- **Build-time tooling is Python** — the author's strength, and it mirrors the `.map`→JSON converter pattern in the sibling `ypilot` repo (`retrorocket/*.py`).

## Firm decisions

- **Engine: Godot 4.x (2D).** Chosen deliberately — the author has wanted to use Godot for years, and a low-stakes personal project is the right place. Key practical win: one-click **native Android APK** to sideload onto the tablet. GDScript reads like Python.
- **Target: Android tablet.** Touch-first input designed in from the start, not retrofitted.
- **Scope:** a few hand-picked HoMM3 maps, remade — load/render a map, move a hero, fight. **NOT** procedural generation, the full game, towns/economy/campaigns, or a map statistics tool (those were notes tangents). This is the map-based direction, not an abstract standalone battle engine.
- **Assets: use the HD Edition's upscaled art** (reverses the original 8-bit plan — after play-testing, the HD art looks notably better and still reads as retro). Extracted from a copy the author owns (GOG, Steam HD, floppy, CD); legal because purely personal and never distributed. **Pixels come from the Steam "HD Edition" `.pak` archives** (DXT/DDS, the `x2` scale → 64px tiles), unpacked by `tooling/pak_to_atlas.py`. **The GOG "Complete" `.lod`/`.def` install is still required** as the *geometry* source for animated sprites: the HD `.pak` repacks every sprite left-aligned and drops the per-frame group/margin layout, so hero sprites take **pixels from HD + group/frame/margins from the classic def** (see `tooling/build_hero_assets.py`). **Keep assets behind a swappable layer**: an asset folder + a manifest mapping logical names → files, so code is never welded to the art.
  - **Hard constraint this creates:** the project must **not be distributed** (public hosting, shared APK, screenshots-at-scale) while it uses original assets. If distribution is ever wanted, an own/generated-asset pipeline becomes mandatory again — replace the asset folder, not the code.
- **Look:** HD Edition art **plus Godot lighting on top** — CanvasModulate + Light2D for fog-of-war / night mood, CanvasItem ADD blend for glow (NOT WorldEnvironment glow: the Android Compatibility renderer can't be relied on for it). Gets "nicer than the original" for free. (The author built the equivalent glow/additive look in `ypilot` via Phaser 4 filters — translate the *concepts*, not the code.)
- **Opponent AI: deterministic heuristic/minimax.** No browser/LLM opponent. (Chrome Prompt API / Gemini Nano is moot anyway: desktop-only, so dead on the Android target.)

## Asset pipeline (mechanical Python work, not creative)

Two sources feed the swappable asset folder (all stdlib + Pillow/numpy):
- **HD pixels** — Steam HD `.pak` (DXT-compressed DDS sheets) → `tooling/pak_to_atlas.py` (`PakArchive`: zlib-inflate sheet → Pillow-decode DDS → crop sprite per metadata, rotating `rot=1` sprites 90° CW).
- **Classic geometry** — GOG `.lod` → `tooling/extract_lod.py` + `def_to_atlas.py` (also exposes per-frame names/margins, used to place HD hero pixels) + `pcx_to_png.py` for stills.

Per-game builders compose them: `build_terrain_assets.py` (cleanest 64px fill tile per terrain) and `build_hero_assets.py` (HD pixels + classic layout → directional atlas). Output PNGs land in `assets/` (gitignored) and register logical names in `assets/manifest.json` (tracked).

## `.h3m` map format references (authority order)

For loading the real maps. The `.h3m` format is well reverse-engineered. Trust in this order:

1. **VCMI** (open-source reimplementation) — code is ground truth; on conflict, VCMI wins over docs.
2. **HeroWO-js/h3m2json** — readable, executable field reference (RoE/AB/SoD full; HotA partial).
3. **`h3m_description.english.txt`** (Antoshkiv/Ershov) — byte-for-byte dictionary, aging.

Caveats: `.h3m` is gzip-compressed on disk (specs describe the uncompressed stream); HotA diverges heavily with its own template format; `.h3c` campaigns are containers around multiple `.h3m` + metadata — read VCMI source directly.

## Status

Godot project scaffolded and playable. M1 (map render), M2 (hero movement), and M3 (the look + persistence) are done: fog-of-war, luminous night lighting, HD-Edition terrain + a directional animated hero (64px tiles, x2 art) via the `AssetLibrary`/manifest layer, and autosave + instant resume (`SaveGame`). The Python asset pipeline is complete and verified (HD `.pak` + classic `.lod` — see Asset pipeline above). Next is M4 (combat). See `PLAN.md` for milestone detail and `README.md` for layout + how to run. Sibling `ypilot` (`C:\devel\aweussom\javascript\ypilot`) remains the reference for the glow/additive-blend look.

Engine: **Godot 4.7-stable, Compatibility renderer** → no reliable WorldEnvironment glow on Android, so the glow is **additive-blend + Light2D** (renderer-agnostic), not post-processing.
