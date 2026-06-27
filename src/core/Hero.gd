class_name Hero
extends RefCounted
## A hero on the adventure map — pure data.

var id: String = ""
var x: int = 0
var y: int = 0
var movement_points: int = 0       # remaining this turn (in HoMM3 cost units; see Pathfinder)
var max_movement_points: int = 0   # refilled to this at the start of each turn
var sight_radius: int = 4          # tiles revealed around the hero (fog-of-war; see FogModel)
var army: Array = []               # TODO(M4): stacks of creatures

func cell() -> Vector2i:
	return Vector2i(x, y)

func place(cell: Vector2i) -> void:
	x = cell.x
	y = cell.y

func refill_movement() -> void:
	movement_points = max_movement_points
