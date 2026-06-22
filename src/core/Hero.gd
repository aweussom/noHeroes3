class_name Hero
extends RefCounted
## A hero on the adventure map — pure data.

var id: String = ""
var x: int = 0
var y: int = 0
var movement_points: int = 0
var army: Array = []   # TODO(M4): stacks of creatures

func cell() -> Vector2i:
	return Vector2i(x, y)
