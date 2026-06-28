"""Build the game's terrain fill tiles from the HD Edition art (see CLAUDE.md).

For each of MapModel's ten terrain types, pick ONE clean 64x64 fill tile from the HD pak and write
it to assets/terrain/<name>.png, registering "terrain.<name>" in the manifest. The HD pak groups a
terrain's tiles under an entry named like the classic def (GRASTL, DIRTTL, ...).

"Clean fill tile" = the most colour-uniform tile in the terrain's entry: a terrain holds both
pure-ground and transition/edge tiles, and the pure ones have the lowest pixel variance, so
argmin(variance) finds a tileable fill without hard-coding indices. (Variant/auto-tiling support
comes later, once the .h3m parser supplies per-tile variant bytes.) Tiles are 64px — the x2 HD
scale, matching MapView.TILE_SIZE.

Run whenever you (re)extract assets:  python tooling/build_terrain_assets.py
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from pak_to_atlas import PakArchive

_HD_DATA = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Heroes of Might & Magic III - HD Edition\data")
_REPO_ROOT = Path(__file__).resolve().parent.parent
_SCALE = 2
_TILE = 32 * _SCALE   # 64px

# MapModel terrain name -> HD pak entry (same stem as the classic terrain def, uppercased).
_TERRAIN_ENTRIES = {
    "dirt": "DIRTTL", "sand": "SANDTL", "grass": "GRASTL", "snow": "SNOWTL", "swamp": "SWMPTL",
    "rough": "ROUGTL", "subterranean": "SUBBTL", "lava": "LAVATL", "water": "WATRTL", "rock": "ROCKTL",
}


def _cleanest_tile(pak: PakArchive, entry) -> "Image.Image | None":
    """The most colour-uniform _TILE-sized sprite in an entry (its pure fill tile)."""
    best_image, best_variance = None, None
    for im in entry.images:
        sprite = pak.sprite(entry, im)
        if sprite.size != (_TILE, _TILE):
            continue
        rgb = np.asarray(sprite.convert("RGB"), np.float32)
        variance = float(rgb.reshape(-1, 3).var(axis=0).sum())
        if best_variance is None or variance < best_variance:
            best_image, best_variance = sprite, variance
    return best_image


def _main() -> None:
    parser = argparse.ArgumentParser(description="Build HD terrain fill tiles.")
    parser.add_argument("--hd", type=Path, default=_HD_DATA, help="HD Edition 'data' folder")
    parser.add_argument("--out", type=Path, default=_REPO_ROOT / "assets" / "terrain", help="output tile folder")
    parser.add_argument("--manifest", type=Path, default=_REPO_ROOT / "assets" / "manifest.json", help="manifest to update")
    args = parser.parse_args()

    pak = PakArchive(args.hd / f"sprite_DXT_com_x{_SCALE}.pak")
    args.out.mkdir(parents=True, exist_ok=True)

    manifest: dict = json.loads(args.manifest.read_text()) if args.manifest.exists() else {}
    written = 0
    for name, entry_name in _TERRAIN_ENTRIES.items():
        entry = pak.entries.get(entry_name)
        if entry is None:
            print(f"  WARN  {name}: entry {entry_name} not in pak — skipping")
            continue
        tile = _cleanest_tile(pak, entry)
        if tile is None:
            print(f"  WARN  {name}: no {_TILE}x{_TILE} tile in {entry_name} — skipping")
            continue
        tile.save(args.out / f"{name}.png")
        manifest[f"terrain.{name}"] = f"res://assets/terrain/{name}.png"
        written += 1
        print(f"  ok    terrain.{name:<13} <- {entry_name}")

    manifest.pop("example.hero.knight.idle", None)
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Wrote {written} terrain tile(s) at {_TILE}px -> {args.out}\nUpdated {args.manifest}")


if __name__ == "__main__":
    _main()
