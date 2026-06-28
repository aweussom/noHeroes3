"""Build the terrain fill tiles the game needs, straight from the GOG `.lod` archives.

Pipeline glue (extract_lod + def_to_atlas) with a project-specific job: for each of the ten
HoMM3 terrain types MapModel knows, pick ONE clean 32x32 fill tile and write it to
assets/terrain/<name>.png, then register it in assets/manifest.json under "terrain.<name>".

"Clean fill tile" = the most colour-uniform frame in the terrain's `.def`. A terrain def holds
both pure-ground tiles and transition/edge tiles; the pure ones have the lowest pixel variance,
so argmin(variance) reliably finds a tileable fill without hard-coding frame indices (which
differ per terrain). Variant/auto-tiling support comes later, once the .h3m parser supplies the
per-tile variant byte; one fill tile per terrain is the first real-art pass.

Run it whenever you (re)extract assets:  python tooling/build_terrain_assets.py
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from def_to_atlas import DefFile
from extract_lod import LodArchive

_DEFAULT_DATA = Path(r"C:\Program Files (x86)\GOG Galaxy\Games\HoMM 3 Complete\Data")
_REPO_ROOT = Path(__file__).resolve().parent.parent

# MapModel terrain name -> the terrain tile .def in H3sprite.lod (matched case-insensitively).
_TERRAIN_DEFS = {
    "dirt": "DIRTTL.def",
    "sand": "sandtl.def",
    "grass": "GRASTL.def",
    "snow": "Snowtl.def",
    "swamp": "Swmptl.def",
    "rough": "ROUGTL.def",
    "subterranean": "Subbtl.def",
    "lava": "Lavatl.def",
    "water": "watrtl.def",
    "rock": "rocktl.def",
}


def _cleanest_tile(deffile: DefFile) -> "np.ndarray | None":
    """The most colour-uniform 32x32 opaque frame in a terrain def (its pure fill tile)."""
    best_image, best_variance = None, None
    for frame in deffile.frames():
        if frame.image.size != (32, 32):
            continue
        rgb = np.asarray(frame.image.convert("RGB"), np.float32)
        variance = float(rgb.reshape(-1, 3).var(axis=0).sum())
        if best_variance is None or variance < best_variance:
            best_image, best_variance = frame.image, variance
    return best_image


def _main() -> None:
    parser = argparse.ArgumentParser(description="Build terrain fill tiles from the GOG .lod archives.")
    parser.add_argument("--data", type=Path, default=_DEFAULT_DATA, help="GOG HoMM3 'Data' folder")
    parser.add_argument("--out", type=Path, default=_REPO_ROOT / "assets" / "terrain", help="output tile folder")
    parser.add_argument("--manifest", type=Path, default=_REPO_ROOT / "assets" / "manifest.json", help="manifest to update")
    args = parser.parse_args()

    lod = LodArchive(args.data / "H3sprite.lod")
    by_upper = {e.name.upper(): e for e in lod.entries}
    args.out.mkdir(parents=True, exist_ok=True)

    manifest: dict = json.loads(args.manifest.read_text()) if args.manifest.exists() else {}
    written = 0
    for name, def_name in _TERRAIN_DEFS.items():
        entry = by_upper.get(def_name.upper())
        if entry is None:
            print(f"  WARN  {name}: {def_name} not found in H3sprite.lod — skipping")
            continue
        tile = _cleanest_tile(DefFile(lod.read(entry)))
        if tile is None:
            print(f"  WARN  {name}: no 32x32 frame in {def_name} — skipping")
            continue
        tile.save(args.out / f"{name}.png")
        manifest[f"terrain.{name}"] = f"res://assets/terrain/{name}.png"
        written += 1
        print(f"  ok    terrain.{name:<13} <- {def_name}")

    # Drop the scaffolding placeholder example key if it's still here.
    manifest.pop("example.hero.knight.idle", None)
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Wrote {written} terrain tile(s) -> {args.out}\nUpdated {args.manifest}")


if __name__ == "__main__":
    _main()
