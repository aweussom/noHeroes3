"""Extract HoMM III `.lod` archives → their raw `.pcx` / `.def` / etc. members.

First stage of the asset pipeline (see PLAN.md):

    extract_lod.py  (.lod → .pcx/.def)  →  def_to_atlas.py  (.def → PNG atlas)  →  assets/

Format follows VCMI's `CArchiveLoader::initLODArchive` (the authority — see
reference/vcmi/lib/filesystem/CArchiveLoader.cpp), byte-for-byte:

    offset 0x00  char   magic[4]      "LOD\\0"
    offset 0x08  uint32 file_count
    offset 0x5C  entries[file_count], 32 bytes each:
                 char   name[16]      NUL-padded
                 uint32 offset        from start of archive
                 uint32 full_size     uncompressed size
                 uint32 _unused
                 uint32 compressed_size   0 ⇒ stored raw

A member is zlib-deflated when compressed_size != 0; otherwise it's stored raw.

Stdlib only (struct + zlib), so it runs anywhere Python does. Import `LodArchive`
to reuse the reader from other tooling, or run this file as a CLI.
"""

from __future__ import annotations

import argparse
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path

_HEADER_FILE_COUNT_OFFSET = 0x08
_ENTRY_TABLE_OFFSET = 0x5C
_ENTRY_STRUCT = struct.Struct("<16s I I I I")  # name, offset, full_size, _unused, compressed_size


@dataclass(frozen=True)
class LodEntry:
    """One member file inside a `.lod` archive."""

    name: str
    offset: int
    full_size: int
    compressed_size: int

    @property
    def is_compressed(self) -> bool:
        return self.compressed_size != 0


class LodArchive:
    """Read-only view over a `.lod` archive: lists members and extracts their bytes.

    Reads the whole archive into memory once (the largest, H3bitmap.lod, is ~100 MB —
    trivial for a build-time tool) and slices members out on demand.
    """

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self._data = self.path.read_bytes()
        self.entries = self._read_table()

    def _read_table(self) -> list[LodEntry]:
        if self._data[:3] != b"LOD":
            raise ValueError(f"{self.path.name}: not a LOD archive (bad magic)")
        (count,) = struct.unpack_from("<I", self._data, _HEADER_FILE_COUNT_OFFSET)
        entries: list[LodEntry] = []
        pos = _ENTRY_TABLE_OFFSET
        for _ in range(count):
            raw_name, offset, full_size, _unused, compressed_size = _ENTRY_STRUCT.unpack_from(self._data, pos)
            name = raw_name.split(b"\x00", 1)[0].decode("ascii", "replace")
            entries.append(LodEntry(name, offset, full_size, compressed_size))
            pos += _ENTRY_STRUCT.size
        return entries

    def read(self, entry: LodEntry) -> bytes:
        """Return a member's uncompressed bytes."""
        blob = self._data[entry.offset : entry.offset + (entry.compressed_size or entry.full_size)]
        if entry.is_compressed:
            blob = zlib.decompress(blob)
        if len(blob) != entry.full_size:
            raise ValueError(f"{entry.name}: expected {entry.full_size} bytes, got {len(blob)}")
        return blob

    def extract_all(self, out_dir: Path, name_filter: str = "") -> int:
        """Write every member (optionally filtered by case-insensitive substring) to `out_dir`.

        Returns the number of files written.
        """
        out_dir.mkdir(parents=True, exist_ok=True)
        needle = name_filter.upper()
        written = 0
        for entry in self.entries:
            if needle and needle not in entry.name.upper():
                continue
            (out_dir / entry.name).write_bytes(self.read(entry))
            written += 1
        return written


def _main() -> None:
    parser = argparse.ArgumentParser(description="List or extract a HoMM III .lod archive.")
    parser.add_argument("archive", type=Path, help="path to the .lod file")
    parser.add_argument("--list", action="store_true", help="list members instead of extracting")
    parser.add_argument("--out", type=Path, help="output directory (required unless --list)")
    parser.add_argument("--filter", default="", help="only members whose name contains this (case-insensitive)")
    args = parser.parse_args()

    lod = LodArchive(args.archive)
    needle = args.filter.upper()
    members = [e for e in lod.entries if not needle or needle in e.name.upper()]

    if args.list or not args.out:
        print(f"{lod.path.name}: {len(lod.entries)} members ({len(members)} shown)")
        for e in sorted(members, key=lambda m: m.name.upper()):
            kind = "zlib" if e.is_compressed else "raw "
            print(f"  {e.name:<16} {kind} {e.full_size:>9,} B")
        return

    count = lod.extract_all(args.out, args.filter)
    print(f"Extracted {count} member(s) from {lod.path.name} -> {args.out}")


if __name__ == "__main__":
    try:
        _main()
    except BrokenPipeError:
        pass  # downstream closed the pipe early (e.g. piping --list into `head`); not an error
