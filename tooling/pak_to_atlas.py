"""Unpack HoMM III HD Edition `.pak` art (the upscaled x2/x3 textures) -> PNG.

The project switched from classic 8-bit art to the HD Edition look (see CLAUDE.md). HD art lives in
DXT-compressed PAK archives, a different format from the classic .lod/.def/.pcx pipeline:

    data/{bitmap,sprite}_DXT_{com,loc}_x{2,3}.pak   (x2 = 2x scale, x3 = 3x; com = common art)

Format per VCMI's PakLoader/DdsFormat (reference/vcmi/client/render/hdEdition/):
    u32 magic (==4); u32 headerOffset
    @headerOffset: u32 entryCount, then per entry:
        char name[20] (NUL-padded), u32 metaOffset, u32 metaSize, u32 sheetCount, u32 comp, u32 full,
        u32 sheetComp[sheetCount], u32 sheetFull[sheetCount]
    @metaOffset: a `metaSize`-byte text table (one line per sprite, see _Image), then the sheet
    blobs back to back; each is zlib-deflated -> a DDS file (DXT1/DXT5) Pillow decodes natively.

An entry groups all sprites that came from one original `.def`/`.pcx`; each sprite is a sub-rect of
one of the entry's sheets, optionally rotated 90deg and/or with a separate shadow rect.

Importable (PakArchive) and a CLI: --list, --info ENTRY, --extract ENTRY (loose PNGs per sprite).
"""

from __future__ import annotations

import argparse
import io
import struct
import zlib
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image


@dataclass
class _Image:
    name: str
    sheet: int
    canvas_x: int      # placement of the sprite within its logical (padded) canvas
    canvas_y: int
    sheet_x: int       # where the pixels live in the sheet
    sheet_y: int
    width: int
    height: int
    rotation: int      # 0 or 1 (stored rotated 90deg to pack tighter)
    has_shadow: int


@dataclass
class _Entry:
    name: str
    meta_offset: int
    meta_size: int
    sheet_offsets: list[int] = field(default_factory=list)   # absolute file offset per sheet blob
    sheet_sizes: list[int] = field(default_factory=list)     # compressed size per sheet blob
    images: list[_Image] = field(default_factory=list)


class PakArchive:
    """Read-only view over an HD `.pak`: lists entries/sprites and decodes sprite images."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self._data = self.path.read_bytes()
        self.entries: dict[str, _Entry] = {}
        self._sheet_cache: dict[tuple[str, int], Image.Image] = {}
        self._read_index()

    def _read_index(self) -> None:
        magic, header_off = struct.unpack_from("<II", self._data, 0)
        if magic != 4:
            raise ValueError(f"{self.path.name}: bad PAK magic {magic}")
        (count,) = struct.unpack_from("<I", self._data, header_off)
        pos = header_off + 4
        for _ in range(count):
            name = self._data[pos:pos + 20].split(b"\x00", 1)[0].decode("ascii", "replace").upper()
            pos += 20
            meta_off, meta_size, n_sheets = struct.unpack_from("<III", self._data, pos)
            pos += 12 + 8  # skip the entry-level comp/full pair too
            comp = list(struct.unpack_from(f"<{n_sheets}I", self._data, pos)); pos += 4 * n_sheets
            pos += 4 * n_sheets  # per-sheet full sizes (unused — DDS carries its own dimensions)

            entry = _Entry(name, meta_off, meta_size)
            sheet_at = meta_off + meta_size
            for size in comp:
                entry.sheet_offsets.append(sheet_at)
                entry.sheet_sizes.append(size)
                sheet_at += size
            entry.images = self._parse_metadata(meta_off, meta_size)
            self.entries[name] = entry

    def _parse_metadata(self, offset: int, size: int) -> list[_Image]:
        text = self._data[offset:offset + size].split(b"\x00", 1)[0].decode("ascii", "replace")
        images: list[_Image] = []
        for line in text.splitlines():
            t = line.split()
            if len(t) < 12:
                continue
            images.append(_Image(
                name=t[0].upper(), sheet=int(t[1]),
                canvas_x=int(t[2]), canvas_y=int(t[4]),
                sheet_x=int(t[6]), sheet_y=int(t[7]),
                width=int(t[8]), height=int(t[9]),
                rotation=int(t[10]), has_shadow=int(t[11]),
            ))
        return images

    def sheet(self, entry: _Entry, index: int) -> Image.Image:
        key = (entry.name, index)
        if key not in self._sheet_cache:
            blob = self._data[entry.sheet_offsets[index]:entry.sheet_offsets[index] + entry.sheet_sizes[index]]
            dds = zlib.decompress(blob)
            self._sheet_cache[key] = Image.open(io.BytesIO(dds)).convert("RGBA")
        return self._sheet_cache[key]

    def sprite(self, entry: _Entry, image: _Image) -> Image.Image:
        sheet = self.sheet(entry, image.sheet)
        # width/height are the dimensions AS STORED in the sheet. When rotation is set the sprite
        # was turned 90deg to pack tighter, so we crop the stored rect then rotate it upright.
        crop = sheet.crop((image.sheet_x, image.sheet_y, image.sheet_x + image.width, image.sheet_y + image.height))
        if image.rotation:
            crop = crop.transpose(Image.Transpose.ROTATE_270)   # clockwise, matching VCMI's Rotate90
        return crop


def _main() -> None:
    parser = argparse.ArgumentParser(description="Unpack HoMM III HD Edition .pak art to PNG.")
    parser.add_argument("pak", type=Path, help="path to a .pak archive")
    parser.add_argument("--list", action="store_true", help="list entries")
    parser.add_argument("--info", help="print one entry's sprites + dimensions")
    parser.add_argument("--extract", help="extract all sprites of an entry as loose PNGs")
    parser.add_argument("--out-dir", type=Path, default=Path("."), help="output dir for --extract")
    args = parser.parse_args()

    pak = PakArchive(args.pak)

    if args.list or (not args.info and not args.extract):
        print(f"{pak.path.name}: {len(pak.entries)} entries")
        for name in sorted(pak.entries):
            e = pak.entries[name]
            print(f"  {name:<16} {len(e.images):>4} sprites, {len(e.sheet_sizes)} sheet(s)")
        return

    if args.info:
        entry = pak.entries[args.info.upper()]
        print(f"{entry.name}: {len(entry.images)} sprites across {len(entry.sheet_sizes)} sheet(s)")
        for im in entry.images[:40]:
            print(f"  {im.name:<16} sheet{im.sheet} {im.width}x{im.height} rot={im.rotation} canvas=({im.canvas_x},{im.canvas_y})")
        return

    entry = pak.entries[args.extract.upper()]
    args.out_dir.mkdir(parents=True, exist_ok=True)
    for im in entry.images:
        pak.sprite(entry, im).save(args.out_dir / f"{im.name}.png")
    print(f"Extracted {len(entry.images)} sprite(s) from {entry.name} -> {args.out_dir}")


if __name__ == "__main__":
    _main()
