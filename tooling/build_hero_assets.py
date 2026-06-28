"""Build the player hero's HD adventure-map sprite atlas (HD Edition art).

The project uses the HD Edition look (see CLAUDE.md), but the HD `.pak` repacks every sprite
left-aligned (canvas_x always 0) and drops the per-frame layout, so HD pixels alone can't be
positioned or grouped. We therefore take **geometry from the classic def, pixels from the HD pak**:

  * The classic AH00_.def (GOG) gives the authoritative group/frame structure, per-frame name,
    full canvas size, and left/top margins — the same data that made the classic hero look right.
  * The HD pak's AH00_ entry gives the 2x sprite pixels, keyed by the same frame name.

For each classic frame we paste its HD sprite onto a (full_w x full_h) * SCALE canvas at
(left_margin, top_margin) * SCALE, then emit one atlas + frame JSON with the classic group/frame
indices — identical in shape to the old output, so HeroView.gd is unchanged.

Run whenever you (re)extract assets:  python tooling/build_hero_assets.py
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from def_to_atlas import DefFile, Frame, write_atlas
from extract_lod import LodArchive
from pak_to_atlas import PakArchive

_GOG_DATA = Path(r"C:\Program Files (x86)\GOG Galaxy\Games\HoMM 3 Complete\Data")
_HD_DATA = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Heroes of Might & Magic III - HD Edition\data")
_REPO_ROOT = Path(__file__).resolve().parent.parent
_HERO_DEF = "AH00_.def"
_HERO_PAK_ENTRY = "AH00_"
_SCALE = 2   # the x2 pak -> 64px tiles (matches MapView.TILE_SIZE)


def _main() -> None:
    parser = argparse.ArgumentParser(description="Build the HD player-hero sprite atlas.")
    parser.add_argument("--gog", type=Path, default=_GOG_DATA, help="GOG 'Data' folder (geometry source)")
    parser.add_argument("--hd", type=Path, default=_HD_DATA, help="HD Edition 'data' folder (pixel source)")
    parser.add_argument("--out", type=Path, default=_REPO_ROOT / "assets" / "sprites", help="output folder")
    parser.add_argument("--manifest", type=Path, default=_REPO_ROOT / "assets" / "manifest.json", help="manifest to update")
    args = parser.parse_args()

    lod = LodArchive(args.gog / "H3sprite.lod")
    entry = next((e for e in lod.entries if e.name.upper() == _HERO_DEF.upper()), None)
    if entry is None:
        raise SystemExit(f"{_HERO_DEF} not found in {args.gog}\\H3sprite.lod")
    classic = DefFile(lod.read(entry))

    pak = PakArchive(args.hd / f"sprite_DXT_com_x{_SCALE}.pak")
    hd_entry = pak.entries[_HERO_PAK_ENTRY]
    hd_by_name = {im.name.upper(): im for im in hd_entry.images}

    frames: list[Frame] = []
    missing = 0
    for cf in classic.frames():
        key = cf.name.rsplit(".", 1)[0].upper()      # "AH00_14.pcx" -> "AH00_14"
        hd_im = hd_by_name.get(key)
        canvas = Image.new("RGBA", (cf.full_w * _SCALE, cf.full_h * _SCALE), (0, 0, 0, 0))
        if hd_im is None:
            missing += 1
        else:
            canvas.paste(pak.sprite(hd_entry, hd_im), (cf.left_margin * _SCALE, cf.top_margin * _SCALE))
        frames.append(Frame(cf.group, cf.index, canvas, cf.left_margin * _SCALE, cf.top_margin * _SCALE))

    png = write_atlas("hero_knight", frames, args.out)
    if missing:
        print(f"  WARN  {missing} classic frame(s) had no HD sprite (left transparent)")

    # Manifest keys are stable; only re-add if absent so we don't clobber other entries.
    import json
    manifest: dict = json.loads(args.manifest.read_text()) if args.manifest.exists() else {}
    manifest["hero.knight.atlas"] = "res://assets/sprites/hero_knight.png"
    manifest["hero.knight.frames"] = "res://assets/sprites/hero_knight.json"
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Built HD hero atlas -> {png} ({len(frames)} frames, scale x{_SCALE})\nUpdated {args.manifest}")


if __name__ == "__main__":
    _main()
