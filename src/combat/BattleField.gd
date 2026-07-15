class_name BattleField
extends Node2D
## Draws the battlefield from a BattleModel: the hex grid plus each stack as its real HD creature
## sprite (idle animation, enemy side mirrored to face left) with a count badge and a soft
## side-coloured under-glow. Pointy-top hexes in offset rows, matching the HoMM3 layout.
##
## Sprites come from assets/battle/ (tooling/build_battle_assets.py) via AssetLibrary. On a fresh
## checkout without built assets, stacks fall back to the old luminous tokens — same rule as the
## map's terrain and hero.

const HEX_SIZE := 34.0   # centre-to-corner radius
const PLAYER_COLOR := Color(0.45, 0.85, 0.95)   # cool teal
const ENEMY_COLOR := Color(0.95, 0.55, 0.45)    # warm red
const TEXT_COLOR := Color(0.85, 0.78, 0.55)     # warm, dim (HUD tone) — count badges

# Classic battle hexes are 44px wide and the atlas pixels are the x2 HD scale, so this factor
# renders creatures at their authentic size relative to our hexes (relative sizes preserved).
const SPRITE_SCALE := sqrt(3.0) * HEX_SIZE / (44.0 * 2.0)
const GROUND_OFFSET := HEX_SIZE * 0.5   # a creature's feet stand this far below its hex centre
const IDLE_FRAME_TIME := 0.18           # gentle idle pace; stacks are phase-shifted, not in sync

var model: BattleModel
var active: CreatureStack            # the stack whose turn it is (gets a bright ring)
var reachable: Array[Vector2i] = []  # hexes the active stack can move to (highlighted)

# creature id -> { tex, frame_w/h, count, anchor } from the battle atlas + sidecar JSON, loaded
# once per battle. A creature missing here draws as a fallback token.
var _sprites: Dictionary = {}
var _anim_time := 0.0
var _anim_frame := 0    # global idle tick; redraw only when it advances, not every frame

func set_model(new_model: BattleModel) -> void:
	model = new_model
	_load_sprites()
	queue_redraw()

# Resolve every creature type in the battle to its atlas texture + frame metadata (or leave it
# out of _sprites, which means "draw the placeholder token").
func _load_sprites() -> void:
	_sprites.clear()
	for stack in model.stacks:
		var id := stack.creature.id
		if _sprites.has(id):
			continue
		var tex := AssetLibrary.texture("battle.creature.%s" % id)
		var meta_path := AssetLibrary.file_path("battle.creature.%s.frames" % id)
		if tex == null or meta_path == "" or not FileAccess.file_exists(meta_path):
			continue
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if typeof(meta) != TYPE_DICTIONARY:
			continue
		_sprites[id] = {
			"tex": tex,
			"frame_w": int(meta["frame_w"]), "frame_h": int(meta["frame_h"]),
			"count": int(meta["count"]),
			"anchor": Vector2(float(meta["anchor_x"]), float(meta["anchor_y"])),
		}

# Advance the shared idle clock; redraw only on frame boundaries (~6 fps), not every _process.
func _process(delta: float) -> void:
	if _sprites.is_empty():
		return
	_anim_time += delta
	var frame := int(_anim_time / IDLE_FRAME_TIME)
	if frame != _anim_frame:
		_anim_frame = frame
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

	# Stacks, top row first so creatures on lower hexes overlap the ones behind (painter's order);
	# then rings and badges in a second pass so no sprite can cover them.
	var living := model.stacks.filter(func(s: CreatureStack) -> bool: return s.is_alive())
	living.sort_custom(func(a: CreatureStack, b: CreatureStack) -> bool: return a.hex.y < b.hex.y)
	for stack: CreatureStack in living:
		_draw_stack(stack)
	for stack: CreatureStack in living:
		var c := hex_center(stack.hex.x, stack.hex.y)
		var color := PLAYER_COLOR if stack.side == 0 else ENEMY_COLOR
		if stack == active:
			draw_arc(c, HEX_SIZE * 0.7, 0.0, TAU, 32, Color(1.0, 0.95, 0.7, 0.95), 2.5)  # active ring
		_draw_count_badge(stack, c, color)

# One stack's creature: soft side-coloured under-glow + the sprite (or fallback token).
func _draw_stack(stack: CreatureStack) -> void:
	var c := hex_center(stack.hex.x, stack.hex.y)
	var color := PLAYER_COLOR if stack.side == 0 else ENEMY_COLOR
	var feet := c + Vector2(0.0, GROUND_OFFSET)

	# A soft side-coloured pool under the creature — the luminous marker of whose it is, readable
	# at a glance in the dark (the sprites themselves aren't tinted).
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.45))   # squash a circle into a ground ellipse
	draw_circle(Vector2.ZERO, HEX_SIZE * 0.55, Color(color.r, color.g, color.b, 0.22))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	var sprite: Dictionary = _sprites.get(stack.creature.id, {})
	if sprite.is_empty():
		draw_circle(c, HEX_SIZE * 0.38, color)   # fallback token (assets not built)
	else:
		# Idle frame for this stack, phase-shifted by hex so the field doesn't tick in unison.
		var frame := (_anim_frame + stack.hex.x * 3 + stack.hex.y * 5) % int(sprite["count"])
		var src := Rect2(frame * int(sprite["frame_w"]), 0, int(sprite["frame_w"]), int(sprite["frame_h"]))
		# Pin the frame's anchor (body centre, ground line) to the hex's ground point. Classic
		# sprites face right (the player side); mirror around the anchor for the enemy.
		var flip := Vector2(-1.0, 1.0) if stack.side == 1 else Vector2(1.0, 1.0)
		var anchor: Vector2 = sprite["anchor"]
		draw_set_transform(feet, 0.0, flip)
		draw_texture_rect_region(sprite["tex"], Rect2(-anchor * SPRITE_SCALE, src.size * SPRITE_SCALE), src)
		draw_set_transform_matrix(Transform2D.IDENTITY)

# The stack's creature count in a small dark box at the bottom of its hex — HoMM3's badge, in the
# game's dim warm text so it reads at low brightness without glowing.
func _draw_count_badge(stack: CreatureStack, center: Vector2, side_color: Color) -> void:
	var font := ThemeDB.fallback_font
	var label := str(stack.count)
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var box := Rect2(center + Vector2(-size.x * 0.5 - 5.0, HEX_SIZE * 0.55), Vector2(size.x + 10.0, 19.0))
	draw_rect(box, Color(0.04, 0.05, 0.08, 0.88))
	draw_rect(box, Color(side_color.r, side_color.g, side_color.b, 0.55), false, 1.0)
	draw_string(font, box.position + Vector2(5.0, 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_COLOR)

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
