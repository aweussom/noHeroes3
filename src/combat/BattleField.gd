class_name BattleField
extends Node2D
## Draws the battlefield from a BattleModel: the hex grid plus a placeholder luminous token per
## stack (side-coloured, with its creature count). Pointy-top hexes in offset rows, matching the
## HoMM3 layout. Real HD battlefield + creature sprites replace the placeholders in M4.5; the hex
## geometry (hex_center) stays so input/animation keep working.

const HEX_SIZE := 34.0   # centre-to-corner radius
const PLAYER_COLOR := Color(0.45, 0.85, 0.95)   # cool teal
const ENEMY_COLOR := Color(0.95, 0.55, 0.45)    # warm red

var model: BattleModel
var active: CreatureStack            # the stack whose turn it is (gets a bright ring)
var reachable: Array[Vector2i] = []  # hexes the active stack can move to (highlighted)

func set_model(new_model: BattleModel) -> void:
	model = new_model
	queue_redraw()

func set_highlights(active_stack: CreatureStack, reachable_hexes: Array[Vector2i]) -> void:
	active = active_stack
	reachable = reachable_hexes
	queue_redraw()

## The hex under a field-local point, or (-1, -1) if the point isn't on any hex.
func hex_at(local_pos: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := HEX_SIZE
	for row in BattleModel.ROWS:
		for col in BattleModel.COLS:
			var d := local_pos.distance_to(hex_center(col, row))
			if d < best_dist:
				best_dist = d
				best = Vector2i(col, row)
	return best

# Total drawn size, so BattleView can centre the field on screen.
func pixel_size() -> Vector2:
	var w := sqrt(3.0) * HEX_SIZE
	var h := 2.0 * HEX_SIZE
	return Vector2(w * (BattleModel.COLS + 0.5), h * 0.75 * (BattleModel.ROWS - 1) + h)

# Centre pixel of an offset-coordinate hex (odd rows shifted half a hex right).
func hex_center(col: int, row: int) -> Vector2:
	var w := sqrt(3.0) * HEX_SIZE
	var h := 2.0 * HEX_SIZE
	return Vector2(w * (col + 0.5 * (row & 1)) + w * 0.5, h * 0.75 * row + h * 0.5)

func _draw() -> void:
	if model == null:
		return
	for row in BattleModel.ROWS:
		for col in BattleModel.COLS:
			_draw_hex(hex_center(col, row))

	# Movement range for the active stack: a soft teal wash over reachable hexes.
	for hex in reachable:
		_fill_hex(hex_center(hex.x, hex.y), Color(0.45, 0.85, 0.95, 0.16))

	var font := ThemeDB.fallback_font
	for stack in model.stacks:
		if not stack.is_alive():
			continue
		var c := hex_center(stack.hex.x, stack.hex.y)
		var color := PLAYER_COLOR if stack.side == 0 else ENEMY_COLOR
		draw_circle(c, HEX_SIZE * 0.55, Color(color.r, color.g, color.b, 0.20))  # soft halo
		draw_circle(c, HEX_SIZE * 0.38, color)                                    # token
		if stack == active:
			draw_arc(c, HEX_SIZE * 0.7, 0.0, TAU, 32, Color(1.0, 0.95, 0.7, 0.95), 2.5)  # active ring
		var label := str(stack.count)
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		draw_string(font, c + Vector2(-size.x * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.05, 0.06, 0.09))

# A single hex: faint dark fill + a soft luminous outline (fits the dark, glow-on-black look).
func _draw_hex(center: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 90.0)   # vertex pointing up = pointy-top
		pts.append(center + Vector2(cos(a), sin(a)) * HEX_SIZE)
	draw_colored_polygon(pts, Color(0.11, 0.13, 0.19, 0.55))
	var outline := pts
	outline.append(pts[0])
	draw_polyline(outline, Color(0.4, 0.55, 0.72, 0.28), 1.5, true)

func _fill_hex(center: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 90.0)
		pts.append(center + Vector2(cos(a), sin(a)) * HEX_SIZE)
	draw_colored_polygon(pts, color)
