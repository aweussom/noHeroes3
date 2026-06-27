class_name MapModel
extends RefCounted
## Pure map data — no nodes, no rendering. Populated from the JSON that
## tooling/h3m_to_json.py will emit into data/maps/. Kept plain so it reads and tests easily.
##
## Terrain ids are the canonical HoMM3 .h3m values (see the constants below), so the
## eventual parser maps straight onto them with no translation table.

# HoMM3 terrain type ids — the order the .h3m format itself uses (VCMI: ETerrainType).
const DIRT := 0
const SAND := 1
const GRASS := 2
const SNOW := 3
const SWAMP := 4
const ROUGH := 5
const SUBTERRANEAN := 6
const LAVA := 7
const WATER := 8
const ROCK := 9

var name: String = ""
var width: int = 0
var height: int = 0
var objects: Array = []        # TODO(M1+): map objects (towns, mines, ...) — needs extracted sprites.

# Terrain stored as a flat, row-major grid (index = y * width + x). Private so callers
# go through terrain_at()/is_passable() and never assume the backing layout.
var _terrain: PackedInt32Array = PackedInt32Array()

## Build a model from the converter's JSON. Schema (M1):
##   { "name": str, "tiles": [[int, ...], ...], "objects": [...] }
## `tiles` is an array of rows, each row an array of terrain ids; width/height derive from it.
static func from_json(data: Dictionary) -> MapModel:
	var m := MapModel.new()
	m.name = String(data.get("name", ""))

	var rows: Array = data.get("tiles", [])
	m.height = rows.size()
	m.width = (rows[0] as Array).size() if m.height > 0 else 0
	m._terrain.resize(m.width * m.height)

	for y in m.height:
		var row: Array = rows[y]
		if row.size() != m.width:
			push_error("MapModel: row %d has %d tiles, expected %d" % [y, row.size(), m.width])
			continue
		for x in m.width:
			m._terrain[y * m.width + x] = int(row[x])

	m.objects = data.get("objects", [])
	return m

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

## Terrain id at a cell. Out-of-bounds reads as ROCK (the natural impassable "edge of world").
func terrain_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return ROCK
	return _terrain[y * width + x]

## Terrain-only passability. Object-based blocking (towns, etc.) is added with the asset work.
func is_passable(x: int, y: int) -> bool:
	var t := terrain_at(x, y)
	return t != WATER and t != ROCK
