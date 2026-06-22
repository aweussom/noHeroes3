class_name MapModel
extends RefCounted
## Pure map data — no nodes, no rendering. Populated from the JSON that
## tooling/h3m_to_json.py emits into data/maps/. Kept plain so it reads and tests easily.

var width: int = 0
var height: int = 0
var tiles: Array = []      # TODO(M1): typed grid of terrain + passability
var objects: Array = []    # TODO(M1): map objects (towns, mines, ...)

static func from_json(data: Dictionary) -> MapModel:
	var m := MapModel.new()
	# TODO(M1): fill width/height/tiles/objects from the converter's schema.
	return m

func is_passable(x: int, y: int) -> bool:
	# TODO(M1): real passability lookup.
	return true
