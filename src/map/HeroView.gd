class_name HeroView
extends Node2D
## The player's hero on the map. M2 draws a PLACEHOLDER luminous token (a glowing dot) — fitting
## the dark, luminous-on-black look — until real HoMM3 hero sprites are extracted and the draw is
## swapped for an animated sprite. Lives under MapView so its coordinates match the terrain grid.

const STEP_TIME := 0.14   # seconds per tile; gentle, un-rushed for sleepy play.

var _cell := Vector2i.ZERO
var _move_tween: Tween

func _ready() -> void:
	z_index = 10   # draw above the terrain layer

## Jump instantly to a cell (initial placement).
func set_cell(cell: Vector2i) -> void:
	_cell = cell
	position = _cell_to_world(cell)
	queue_redraw()

## Animate step-by-step along `cells` (the walk steps from Pathfinder.reachable_prefix).
func move_along(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	for cell in cells:
		_move_tween.tween_property(self, "position", _cell_to_world(cell), STEP_TIME)
	_cell = cells[-1]

func is_moving() -> bool:
	return _move_tween != null and _move_tween.is_valid() and _move_tween.is_running()

func _cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE

func _draw() -> void:
	# Soft halo + bright core. Additive-blend sprites/Light2D glow come with the M3 look pass.
	draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.85, 0.45, 0.18))
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.88, 0.55, 0.95))
