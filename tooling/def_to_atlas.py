"""Convert HoMM III `.def` animated sprites → a PNG atlas + frame JSON (or loose frame PNGs).

Third pipeline stage (see PLAN.md), the one that feeds real art into the game: terrain
tilesets (replacing MapView's placeholder colours), hero/creature/object sprites.

Format and palette handling follow VCMI's `DefFile` / `ImageLoader` byte-for-byte — see
reference/vcmi/mapeditor/Animation.cpp (the authority). A `.def` is:

    uint32 type                 (DefType: 0x42 creature, 0x44 map hero, 0x45 terrain, ...)
    uint32 fullWidth, fullHeight   (defaults, unused per-frame)
    uint32 block_count
    palette[256]                256 RGB triplets (768 bytes)
    blocks[block_count]:
        uint32 block_id
        uint32 frame_count
        8 unused bytes
        char names[frame_count][13]      (skipped)
        uint32 frame_offset[frame_count] (from start of file)

Each frame begins with a 32-byte header (size, format, fullW/H, w/h, left/top margin) then
pixel data in one of four encodings (format 0 raw, 1 per-line RLE, 2/3 segment RLE). Pixels are
palette indices; the frame is `fullWidth x fullHeight` with the decoded `w x h` data placed at
the margin offset and the border left transparent.

Palette transparency: indices 0/1/4 are always remapped to transparent / shadow; indices 0..7
are remapped to their shadow/selection meaning when they match HoMM3's canonical special colours
(so e.g. the magenta background becomes transparent).

A "block" is an animation group (e.g. a hero's 8 facing directions); each holds ordered frames.
"""

from __future__ import annotations

import argparse
import json
import struct
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

from extract_lod import LodArchive

_PALETTE_AT = 16          # palette starts right after type/w/h/block_count
_PALETTE_BYTES = 256 * 3
_BLOCKS_AT = _PALETTE_AT + _PALETTE_BYTES
_FRAME_HEADER = struct.Struct("<IIIIIIii")  # size, format, fullW, fullH, w, h, leftMargin, topMargin

# HoMM3's canonical special palette colours (RGB) and what each becomes (RGBA). Index 0/1/4 are
# applied unconditionally; the rest only when the file's colour matches (within a small threshold).
_SOURCE_SPECIAL = [
    (0, 255, 255), (255, 150, 255), (255, 100, 255), (255, 50, 255),
    (255, 0, 255), (255, 255, 0), (180, 0, 255), (0, 255, 0),
]
_TARGET_SPECIAL = [
    (0, 0, 0, 0), (0, 0, 0, 64), (0, 0, 0, 64), (0, 0, 0, 128),
    (0, 0, 0, 128), (0, 0, 0, 0), (0, 0, 0, 128), (0, 0, 0, 64),
]
_ALWAYS_REMAP = (0, 1, 4)
_COLOR_THRESHOLD = 8


@dataclass
class Frame:
    group: int
    index: int
    image: Image.Image       # full_width x full_height, RGBA
    left_margin: int
    top_margin: int
    name: str = ""           # the def's 13-byte frame name (e.g. "AH00_14.pcx") — used to cross-
                             # reference the HD Edition's per-sprite naming (see build_hero_assets)
    full_w: int = 0          # the frame's full (padded) canvas size and the decoded data size,
    full_h: int = 0          # so callers can reconstruct exact placement at another scale
    width: int = 0
    height: int = 0


def _build_palette(data: bytes) -> np.ndarray:
    """256x4 RGBA palette with HoMM3's transparency/shadow remaps applied."""
    rgb = np.frombuffer(data, np.uint8, _PALETTE_BYTES, _PALETTE_AT).reshape(256, 3)
    palette = np.empty((256, 4), np.uint8)
    palette[:, :3] = rgb
    palette[:, 3] = 255
    for i in _ALWAYS_REMAP:
        palette[i] = _TARGET_SPECIAL[i]
    # Match VCMI: compare canonical source colour (opaque) against the CURRENT palette entry.
    for i in range(8):
        src = (*_SOURCE_SPECIAL[i], 255)
        if all(abs(int(a) - int(b)) < _COLOR_THRESHOLD for a, b in zip(src, palette[i])):
            palette[i] = _TARGET_SPECIAL[i]
    return palette


def _decode_indices(data: bytes, frame_offset: int) -> tuple:
    """Decode one frame's palette-index buffer. Returns (indices[fullH,fullW], leftM, topM, fullW, fullH, w, h)."""
    size, fmt, full_w, full_h, w, h, left_m, top_m = _FRAME_HEADER.unpack_from(data, frame_offset)
    base = frame_offset + _FRAME_HEADER.size

    # "Old format" defs (SGTWMTA/B): margins folded in, header is 16 bytes shorter.
    if fmt == 1 and w > full_w and h > full_h:
        left_m = top_m = 0
        w, h = full_w, full_h
        base -= 16

    sub = np.zeros((h, w), np.uint8)  # decoded pixel-data area (placed into the full frame later)

    if fmt == 0:
        off = base
        for row in range(h):
            sub[row] = np.frombuffer(data, np.uint8, w, off)
            off += w

    elif fmt == 1:
        line_offsets = struct.unpack_from(f"<{h}I", data, base)
        for row in range(h):
            off = base + line_offsets[row]
            col = 0
            while col < w:
                segment_type = data[off]
                length = data[off + 1] + 1
                off += 2
                end = min(col + length, w)
                if segment_type == 0xFF:  # raw run
                    sub[row, col:end] = np.frombuffer(data, np.uint8, end - col, off)
                    off += length
                else:                      # RLE: `length` pixels of one colour
                    sub[row, col:end] = segment_type
                col += length

    elif fmt == 2:
        off = base + struct.unpack_from("<H", data, base)[0]
        for row in range(h):
            col = 0
            while col < w:
                segment = data[off]
                off += 1
                code, length = segment >> 5, (segment & 0x1F) + 1
                end = min(col + length, w)
                if code == 7:              # raw run
                    sub[row, col:end] = np.frombuffer(data, np.uint8, end - col, off)
                    off += length
                else:
                    sub[row, col:end] = code
                col += length

    elif fmt == 3:
        blocks_per_row = w // 32
        for row in range(h):
            off = base + struct.unpack_from("<H", data, base + row * 2 * blocks_per_row)[0]
            col = 0
            while col < w:
                segment = data[off]
                off += 1
                code, length = segment >> 5, (segment & 0x1F) + 1
                end = min(col + length, w)
                if code == 7:
                    sub[row, col:end] = np.frombuffer(data, np.uint8, end - col, off)
                    off += length
                else:
                    sub[row, col:end] = code
                col += length
    else:
        raise ValueError(f"unsupported def frame format {fmt}")

    full = np.zeros((full_h, full_w), np.uint8)
    full[top_m:top_m + h, left_m:left_m + w] = sub
    return full, left_m, top_m, full_w, full_h, w, h


class DefFile:
    """A decoded `.def`: its palette and ordered animation blocks (groups) of frames."""

    def __init__(self, data: bytes) -> None:
        self._data = data
        self.type = struct.unpack_from("<I", data, 0)[0]
        self.palette = _build_palette(data)
        self.blocks = self._read_block_table()

    def _read_block_table(self) -> dict[int, list[int]]:
        (block_count,) = struct.unpack_from("<I", self._data, 12)
        blocks: dict[int, list[int]] = {}
        self.frame_names: dict[int, list[str]] = {}
        pos = _BLOCKS_AT
        for _ in range(block_count):
            block_id, frame_count = struct.unpack_from("<II", self._data, pos)
            pos += 4 + 4 + 8                        # block_id + frame_count + 8 unused
            names = []
            for _ in range(frame_count):            # 13-byte NUL-padded name per frame
                names.append(self._data[pos:pos + 13].split(b"\x00", 1)[0].decode("ascii", "replace"))
                pos += 13
            self.frame_names[block_id] = names
            offsets = list(struct.unpack_from(f"<{frame_count}I", self._data, pos))
            pos += 4 * frame_count
            blocks[block_id] = offsets
        return blocks

    def frames(self) -> list[Frame]:
        out: list[Frame] = []
        for group in sorted(self.blocks):
            for index, offset in enumerate(self.blocks[group]):
                indices, left_m, top_m, full_w, full_h, w, h = _decode_indices(self._data, offset)
                rgba = self.palette[indices]
                image = Image.fromarray(np.ascontiguousarray(rgba), "RGBA")
                out.append(Frame(group, index, image, left_m, top_m,
                                 name=self.frame_names[group][index], full_w=full_w, full_h=full_h, width=w, height=h))
        return out


def write_atlas(name: str, frames: list[Frame], out_dir: Path, cols: int = 0) -> Path:
    """Pack frames into a uniform grid PNG + a JSON sidecar describing each frame."""
    cell_w = max(f.image.width for f in frames)
    cell_h = max(f.image.height for f in frames)
    if cols <= 0:
        cols = min(len(frames), 16)
    rows = (len(frames) + cols - 1) // cols

    atlas = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    meta_frames = []
    for i, frame in enumerate(frames):
        col, row = i % cols, i // cols
        x, y = col * cell_w, row * cell_h
        atlas.paste(frame.image, (x, y))
        meta_frames.append({
            "group": frame.group, "frame": frame.index,
            "x": x, "y": y, "w": frame.image.width, "h": frame.image.height,
            "left_margin": frame.left_margin, "top_margin": frame.top_margin,
        })

    out_dir.mkdir(parents=True, exist_ok=True)
    png_path = out_dir / f"{name}.png"
    atlas.save(png_path)
    (out_dir / f"{name}.json").write_text(json.dumps({
        "name": name, "cell_w": cell_w, "cell_h": cell_h, "cols": cols,
        "frames": meta_frames,
    }, indent=2))
    return png_path


def write_frames(name: str, frames: list[Frame], out_dir: Path) -> int:
    """Dump loose per-frame PNGs (NAME_group_frame.png), like VCMI's exportBitmaps."""
    sub = out_dir / name
    sub.mkdir(parents=True, exist_ok=True)
    for frame in frames:
        frame.image.save(sub / f"{name}_{frame.group}_{frame.index}.png")
    return len(frames)


def _load_def_bytes(source: Path, name: str | None) -> tuple[str, bytes]:
    if source.suffix.lower() == ".def":
        return source.stem, source.read_bytes()
    if not name:
        raise SystemExit("a .lod source needs --name MEMBER.def")
    lod = LodArchive(source)
    entry = next((e for e in lod.entries if e.name.upper() == name.upper()), None)
    if entry is None:
        raise SystemExit(f"{name} not found in {source.name}")
    return Path(entry.name).stem, lod.read(entry)


def _main() -> None:
    parser = argparse.ArgumentParser(description="Convert a HoMM III .def sprite to a PNG atlas or frames.")
    parser.add_argument("source", type=Path, help="a .lod archive, or a loose .def file")
    parser.add_argument("--name", help="when source is a .lod: the member to convert")
    parser.add_argument("--out-dir", type=Path, default=Path("."), help="output directory")
    parser.add_argument("--mode", choices=("atlas", "frames"), default="atlas", help="packed atlas (default) or loose frames")
    parser.add_argument("--cols", type=int, default=0, help="atlas columns (default: up to 16)")
    args = parser.parse_args()

    name, data = _load_def_bytes(args.source, args.name)
    deffile = DefFile(data)
    frames = deffile.frames()
    groups = sorted(deffile.blocks)
    print(f"{name}: type 0x{deffile.type:02x}, {len(groups)} group(s), {len(frames)} frame(s)")

    if args.mode == "atlas":
        out = write_atlas(name, frames, args.out_dir, args.cols)
        print(f"  atlas -> {out}  (+ {out.with_suffix('.json').name})")
    else:
        count = write_frames(name, frames, args.out_dir)
        print(f"  {count} frame(s) -> {args.out_dir / name}")


if __name__ == "__main__":
    _main()
