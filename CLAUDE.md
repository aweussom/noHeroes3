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
- **Assets: use the ORIGINAL HoMM3 assets**, extracted from a copy the author owns (he owns it several times over: GOG, Steam HD, floppy, CD). Legal here because it is purely personal and never distributed — this dissolves the project's single biggest former blocker (asset creation/consistency). **Extract from the GOG "Complete" (RoE+AB+SoD) install** — it has the classic `.lod` archives and is what VCMI/tooling expects. **Do NOT use the Steam "HD Edition"** as a source: it's RoE-only, reworked art, incompatible layout. **Keep assets behind a swappable layer**: an asset folder + a manifest mapping logical names → files, so the code is never welded to the stolen art.
  - **Hard constraint this creates:** the project must **not be distributed** (public hosting, shared APK, screenshots-at-scale) while it uses original assets. If distribution is ever wanted, the own/generated-asset pipeline becomes mandatory again — replace the asset folder, not the code.
- **Look:** original 1999 art **plus Godot lighting on top** — WorldEnvironment 2D Glow, CanvasModulate + Light2D for fog-of-war / day-night, CanvasItem ADD blend. Gets "nicer than 1999" without redrawing a pixel. (The author has already built the equivalent glow/additive-blend look in `ypilot` via Phaser 4 filters — translate the *concepts*, not the code.)
- **Opponent AI: deterministic heuristic/minimax.** No browser/LLM opponent. (Chrome Prompt API / Gemini Nano is moot anyway: desktop-only, so dead on the Android target.)

## Asset pipeline (mechanical Python work, not creative)

Original art lives in `.lod` archives as `.def` animated sprites + `.pcx` images. Extract → convert to PNG atlases Godot can load → drop into the swappable asset folder. Tooling work in the author's wheelhouse.

## `.h3m` map format references (authority order)

For loading the real maps. The `.h3m` format is well reverse-engineered. Trust in this order:

1. **VCMI** (open-source reimplementation) — code is ground truth; on conflict, VCMI wins over docs.
2. **HeroWO-js/h3m2json** — readable, executable field reference (RoE/AB/SoD full; HotA partial).
3. **`h3m_description.english.txt`** (Antoshkiv/Ershov) — byte-for-byte dictionary, aging.

Caveats: `.h3m` is gzip-compressed on disk (specs describe the uncompressed stream); HotA diverges heavily with its own template format; `.h3c` campaigns are containers around multiple `.h3m` + metadata — read VCMI source directly.

## Status

Godot project scaffolded and playable. M1 (map render) and M2 (hero movement: A* pathfinding, tap-to-move, movement budget) are done; M3 part 1 (fog-of-war mechanic + luminous night lighting) is done — real sprites and autosave still pending. The Python asset pipeline is two-thirds built: `extract_lod` and `pcx_to_png` work and are verified; `def_to_atlas` is in progress. See `PLAN.md` for milestone detail and `README.md` for layout + how to run. Sibling `ypilot` (`C:\devel\aweussom\javascript\ypilot`) remains the reference for the glow/additive-blend look.

Engine: **Godot 4.7-stable, Compatibility renderer** → no reliable WorldEnvironment glow on Android, so the glow is **additive-blend + Light2D** (renderer-agnostic), not post-processing.
