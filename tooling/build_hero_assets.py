"""Build the player hero's adventure-map sprite atlas from the GOG `.lod` archives.

Runs AH00_.def (the default Knight adventure-map hero) through the def decoder and writes
assets/sprites/hero_knight.png (a packed frame atlas) + hero_knight.json (frame rects), then
registers them in the manifest as "hero.knight.atlas" / "hero.knight.frames".

The def's groups follow HoMM3's adventure-hero convention (confirmed against VCMI's
MapRendererContext move/idle group tables):
    groups 0..4  standing, 1 frame each — facings N, NE, E, SE, S
    groups 5..9  walking, 8 frames each — same five facings
The three left-facing directions (NW, W, SW) are drawn at runtime by horizontally mirroring the
NE, E, SE groups, so they aren't stored. HeroView.gd owns that mapping.

Run whenever you (re)extract assets:  python tooling/build_hero_assets.py
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from def_to_atlas import DefFile, write_atlas
from extract_lod import LodArchive

_DEFAULT_DATA = Path(r"C:\Program Files (x86)\GOG Galaxy\Games\HoMM 3 Complete\Data")
_REPO_ROOT = Path(__file__).resolve().parent.parent
_HERO_DEF = "AH00_.def"


def _main() -> None:
    parser = argparse.ArgumentParser(description="Build the player hero sprite atlas from the GOG .lod archives.")
    parser.add_argument("--data", type=Path, default=_DEFAULT_DATA, help="GOG HoMM3 'Data' folder")
    parser.add_argument("--out", type=Path, default=_REPO_ROOT / "assets" / "sprites", help="output folder")
    parser.add_argument("--manifest", type=Path, default=_REPO_ROOT / "assets" / "manifest.json", help="manifest to update")
    args = parser.parse_args()

    lod = LodArchive(args.data / "H3sprite.lod")
    entry = next((e for e in lod.entries if e.name.upper() == _HERO_DEF.upper()), None)
    if entry is None:
        raise SystemExit(f"{_HERO_DEF} not found in H3sprite.lod")

    frames = DefFile(lod.read(entry)).frames()
    png = write_atlas("hero_knight", frames, args.out)

    manifest: dict = json.loads(args.manifest.read_text()) if args.manifest.exists() else {}
    manifest["hero.knight.atlas"] = "res://assets/sprites/hero_knight.png"
    manifest["hero.knight.frames"] = "res://assets/sprites/hero_knight.json"
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Built hero atlas -> {png} ({len(frames)} frames)\nUpdated {args.manifest}")


if __name__ == "__main__":
    _main()
