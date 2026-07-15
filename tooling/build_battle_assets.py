"""Build the battle-screen art (HD Edition): creature idle sprites + a battlefield background.

Same recipe as build_hero_assets.py — **geometry from the classic def, pixels from the HD pak**
(the HD pak drops the per-frame canvas layout, so HD pixels alone can't be positioned):

  * Each creature's classic battle def (e.g. CPKMAN.def) gives the group/frame structure and the
    450x400 canvas placement. We take group 2 — HOLDING, the idle/standing animation (VCMI
    ECreatureAnimType) — which is all the battle screen draws for now.
  * The HD pak's entry gives the 2x pixels, keyed by the same frame names.

Classic battle defs share a standard canvas: every creature stands on a common ground line
(feet at y=267) with the body centred near x=197 (empirical across the roster, consistent with
VCMI's fixed per-hex frame offset in BattleStacksController::getStackPositionAtHex). We record
that point — scaled and made crop-relative — as the frame's ANCHOR, so BattleField.gd can pin it
to a hex's bottom-centre and creatures of any size stand correctly.

Frames are cropped to the creature's shared content bbox (union over the idle frames, so all
frames stay aligned) and packed into one atlas row per creature + a JSON sidecar.

The battlefield background is a straight HD bitmap extract (CMBKGRMT — the grass/hills field);
the game darkens it at draw time to fit the night look, art stays untouched.

Run whenever you (re)extract assets:  python tooling/build_battle_assets.py
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

from def_to_atlas import DefFile
from extract_lod import LodArchive
from pak_to_atlas import PakArchive

_GOG_DATA = Path(r"C:\Program Files (x86)\GOG Galaxy\Games\HoMM 3 Complete\Data")
_HD_DATA = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Heroes of Might & Magic III - HD Edition\data")
_REPO_ROOT = Path(__file__).resolve().parent.parent
_SCALE = 2                 # the x2 pak — matches the terrain/hero builders (64px tiles)
_IDLE_GROUP = 2            # HOLDING: the standing/idle animation (VCMI ECreatureAnimType)
_ANCHOR = (197, 267)       # classic-canvas ground point: body centre x, feet y (see module doc)
_CROP_PAD = 2              # transparent pixels kept around the content bbox

# Game creature id (Creature.gd _PRESETS key) -> classic battle def. The HD pak entry has the
# same stem. Def names from VCMI config/creatures/*.json ("animation"), the format authority.
_CREATURES = {
    "pikeman":   "CPKMAN.DEF",
    "archer":    "CLCBOW.DEF",
    "griffin":   "CGRIFF.DEF",
    "swordsman": "CSWORD.DEF",
    "gnoll":     "CGNOLL.DEF",
    "wolf":      "CBWLFR.DEF",
    "orc":       "CORC.DEF",
}

_BACKGROUND = "CMBKGRMT"   # grass/hills battlefield (VCMI config/battlefields.json)


def _build_creature(game_id: str, def_name: str, lod: LodArchive, pak: PakArchive, out_dir: Path) -> dict[str, str]:
    """One creature: compose HD idle frames on the classic canvas, crop, pack, describe."""
    entry = next((e for e in lod.entries if e.name.upper() == def_name.upper()), None)
    if entry is None:
        raise SystemExit(f"{def_name} not found in H3sprite.lod")
    classic = DefFile(lod.read(entry))

    hd_entry = pak.entries[Path(def_name).stem.upper()]
    hd_by_name = {im.name.upper(): im for im in hd_entry.images}

    # Compose each idle frame at HD scale on the full classic canvas (so placement is exact).
    composed: list[Image.Image] = []
    for cf in (f for f in classic.frames() if f.group == _IDLE_GROUP):
        key = cf.name.rsplit(".", 1)[0].upper()          # "CPKMAN01.pcx" -> "CPKMAN01"
        hd_im = hd_by_name.get(key)
        canvas = Image.new("RGBA", (cf.full_w * _SCALE, cf.full_h * _SCALE), (0, 0, 0, 0))
        if hd_im is not None:
            canvas.paste(pak.sprite(hd_entry, hd_im), (cf.left_margin * _SCALE, cf.top_margin * _SCALE))
        composed.append(canvas)

    # One shared crop = union of the frames' content, padded — keeps every frame aligned so the
    # anchor is the same point in each.
    boxes = [im.getbbox() for im in composed if im.getbbox()]
    left = max(0, min(b[0] for b in boxes) - _CROP_PAD)
    top = max(0, min(b[1] for b in boxes) - _CROP_PAD)
    right = min(composed[0].width, max(b[2] for b in boxes) + _CROP_PAD)
    bottom = min(composed[0].height, max(b[3] for b in boxes) + _CROP_PAD)
    frames = [im.crop((left, top, right, bottom)) for im in composed]
    frame_w, frame_h = frames[0].size

    atlas = Image.new("RGBA", (frame_w * len(frames), frame_h), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        atlas.paste(frame, (i * frame_w, 0))
    atlas.save(out_dir / f"{game_id}.png")

    (out_dir / f"{game_id}.json").write_text(json.dumps({
        "frame_w": frame_w, "frame_h": frame_h, "count": len(frames),
        "anchor_x": _ANCHOR[0] * _SCALE - left,     # crop-relative ground point: BattleField pins
        "anchor_y": _ANCHOR[1] * _SCALE - top,      # this to the hex's bottom-centre
    }, indent=2) + "\n")

    print(f"  {game_id:<10} {len(frames)} idle frames, {frame_w}x{frame_h} (from {def_name})")
    return {
        f"battle.creature.{game_id}": f"res://assets/battle/{game_id}.png",
        f"battle.creature.{game_id}.frames": f"res://assets/battle/{game_id}.json",
    }


def _main() -> None:
    parser = argparse.ArgumentParser(description="Build HD battle art: creature idle sprites + background.")
    parser.add_argument("--gog", type=Path, default=_GOG_DATA, help="GOG 'Data' folder (geometry source)")
    parser.add_argument("--hd", type=Path, default=_HD_DATA, help="HD Edition 'data' folder (pixel source)")
    parser.add_argument("--out", type=Path, default=_REPO_ROOT / "assets" / "battle", help="output folder")
    parser.add_argument("--manifest", type=Path, default=_REPO_ROOT / "assets" / "manifest.json", help="manifest to update")
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    lod = LodArchive(args.gog / "H3sprite.lod")
    sprite_pak = PakArchive(args.hd / f"sprite_DXT_com_x{_SCALE}.pak")

    new_entries: dict[str, str] = {}
    for game_id, def_name in _CREATURES.items():
        new_entries.update(_build_creature(game_id, def_name, lod, sprite_pak, args.out))

    # The battlefield background: a single HD bitmap, saved as-is (the game dims it at draw time).
    bitmap_pak = PakArchive(args.hd / f"bitmap_DXT_com_x{_SCALE}.pak")
    bg_entry = bitmap_pak.entries[_BACKGROUND]
    bg = bitmap_pak.sprite(bg_entry, bg_entry.images[0])
    bg.save(args.out / "background_grass.png")
    new_entries["battle.background.grass"] = "res://assets/battle/background_grass.png"
    print(f"  background {bg.width}x{bg.height} (from {_BACKGROUND})")

    manifest: dict = json.loads(args.manifest.read_text()) if args.manifest.exists() else {}
    manifest.update(new_entries)
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Built battle art -> {args.out}\nUpdated {args.manifest}")


if __name__ == "__main__":
    _main()
