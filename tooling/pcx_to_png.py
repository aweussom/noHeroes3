"""Convert HoMM III `.pcx` images → PNG (RGBA).

Second pipeline stage for still images (backgrounds, icons, UI). `.def` animated
sprites are handled separately by def_to_atlas.py; both feed assets/.

HoMM3's `.pcx` is NOT standard PCX — it's a raw bitmap with a 12-byte header
(format per VCMI's BitmapHandler::loadH3PCX — see
reference/vcmi/client/render/CBitmapHandler.cpp):

    uint32 file_size
    uint32 width
    uint32 height
    pixels...                 (start at offset 12)

Two variants, distinguished by file_size:
  * file_size == w*h*3  → 24-bit, pixels stored B,G,R, no palette (opaque).
  * file_size == w*h    → 8-bit palette indices, with a 256*3 RGB palette as the
                          last 768 bytes. By HoMM3 convention a magenta (255,0,255)
                          palette entry 0 is the transparency key.

Reads members straight out of a `.lod` via extract_lod.LodArchive, or a loose
`.pcx` file on disk.
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

import numpy as np
from PIL import Image

from extract_lod import LodArchive

_TRANSPARENT_KEY = (255, 0, 255)  # magenta palette index 0 ⇒ transparent (HoMM3 convention)


def decode_pcx(data: bytes, color_key: bool = True) -> Image.Image:
    """Decode HoMM3 `.pcx` bytes into an RGBA Pillow image."""
    file_size, width, height = struct.unpack_from("<III", data, 0)
    pixels_at = 12
    count = width * height

    if file_size == count * 3:
        bgr = np.frombuffer(data, np.uint8, count * 3, pixels_at).reshape(height, width, 3)
        rgb = bgr[:, :, ::-1]  # B,G,R → R,G,B
        return Image.fromarray(np.ascontiguousarray(rgb), "RGB").convert("RGBA")

    if file_size == count:
        indices = np.frombuffer(data, np.uint8, count, pixels_at).reshape(height, width)
        palette = np.frombuffer(data, np.uint8, 256 * 3, len(data) - 256 * 3).reshape(256, 3)
        rgb = palette[indices]
        alpha = np.full((height, width, 1), 255, np.uint8)
        if color_key and tuple(palette[0]) == _TRANSPARENT_KEY:
            alpha[indices == 0] = 0
        rgba = np.concatenate([rgb, alpha], axis=2).astype(np.uint8)
        return Image.fromarray(rgba, "RGBA")

    raise ValueError(f"not an H3 PCX: file_size {file_size} != {width}x{height} (8/24-bit)")


def _main() -> None:
    parser = argparse.ArgumentParser(description="Convert HoMM III .pcx images to PNG.")
    parser.add_argument("source", type=Path, help="a .lod archive, or a loose .pcx file")
    parser.add_argument("--name", help="when source is a .lod: a single member to convert")
    parser.add_argument("--filter", default=".PCX", help="when source is a .lod: name substring to batch-convert")
    parser.add_argument("--out-dir", type=Path, default=Path("."), help="output directory for PNGs")
    parser.add_argument("--no-key", action="store_true", help="disable magenta transparency key")
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    color_key = not args.no_key

    if args.source.suffix.lower() == ".pcx":
        img = decode_pcx(args.source.read_bytes(), color_key)
        out = args.out_dir / (args.source.stem + ".png")
        img.save(out)
        print(f"{args.source.name} -> {out}  ({img.width}x{img.height})")
        return

    lod = LodArchive(args.source)
    needle = (args.name or args.filter).upper()
    members = [e for e in lod.entries if needle in e.name.upper() and e.name.upper().endswith(".PCX")]
    if args.name:
        members = [e for e in lod.entries if e.name.upper() == args.name.upper()]

    converted = 0
    for entry in members:
        try:
            img = decode_pcx(lod.read(entry), color_key)
        except ValueError as err:
            print(f"  skip {entry.name}: {err}")
            continue
        img.save(args.out_dir / (Path(entry.name).stem + ".png"))
        converted += 1
    print(f"Converted {converted}/{len(members)} .pcx member(s) -> {args.out_dir}")


if __name__ == "__main__":
    _main()
