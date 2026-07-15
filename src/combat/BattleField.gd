class_name BattleField
extends Node2D
## Draws the battlefield from a BattleModel: the hex grid plus each stack as its real HD creature
## sprite (enemy side mirrored to face left) with a count badge and a soft side-coloured
## under-glow. Pointy-top hexes in offset rows, matching the HoMM3 layout.
##
## Rendering only — it never decides anything. Stacks idle by default; BattleAnimator drives the
## action by setting per-stack `overrides` (pose group / frame / pixel position / alpha) and the
## transient effects (damage `floaters`, the shot `tracer`) while it plays back resolved events.
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

# Animation group ids in the creature atlases (classic def blocks, VCMI ECreatureAnimType).
# A group a creature doesn't have falls back to IDLE when drawn.
const GROUP_MOVE := 0
const GROUP_IDLE := 2
const GROUP_HIT := 3
const GROUP_DEATH := 5
const GROUP_ATTACK_UP := 11
const GROUP_ATTACK := 12
const GROUP_ATTACK_DOWN := 13
const GROUP_SHOOT_UP := 14
const GROUP_SHOOT := 15
const GROUP_SHOOT_DOWN := 16

const FLOATER_LIFE := 1.1    # seconds a damage number lives
const FLOATER_RISE := 36.0   # pixels it drifts upward over that time

var model: BattleModel
var active: CreatureStack            # the stack whose turn it is (gets a bright ring)
var reachable: Array[Vector2i] = []  # hexes the active stack can move to (highlighted)

# --- BattleAnimator's canvas (see class doc) ---
# stack -> {"group": int, "frame": int, "pos": Vector2 (feet, px), "alpha": float}; every key
# optional. A DEAD stack with an entry here is still drawn (its death animation / fade-out).
var overrides: Dictionary = {}
var floaters: Array[Dictionary] = []   # {"text": String, "pos": Vector2, "age": float}
var tracer: Dictionary = {}            # {"from": Vector2, "to": Vector2, "t": float} while a shot flies

# creature id -> {"tex": Texture2D, "groups": {group id -> {y, w, h, count, anchor}}}, from the
# battle atlas + sidecar JSON, loaded once per battle. A creature missing here draws as a token.
var _sprites: Dictionary = {}
var _anim_time := 0.0
var _anim_frame := 0    # global idle tick; when nothing is animating we redraw only when it advances

func set_model(new_model: BattleModel) -> void:
	model = new_model
	_load_sprites()
	queue_redraw()

func set_highlights(active_stack: CreatureStack, reachable_hexes: Array[Vector2i]) -> void:
	active = active_stack
	reachable = reachable_hexes
	queue_redraw()

## A hex's ground point — where a creature standing on it plants its feet. BattleAnimator moves
## stacks between these.
func ground_of(hex: Vector2i) -> Vector2:
	return hex_center(hex.x, hex.y) + Vector2(0.0, GROUND_OFFSET)

## Frames in one of a creature's animation groups; 0 if the creature (or that group) has no art —
## BattleAnimator then just waits a beat instead of posing.
func group_frames(creature_id: String, group: int) -> int:
	var sprite: Dictionary = _sprites.get(creature_id, {})
	if sprite.is_empty():
		return 0
	return sprite["groups"].get(group, {}).get("count", 0)

## Spawn a floating damage number (the visible record of every hit — assume muted play).
func add_floater(text: String, pos: Vector2) -> void:
	floaters.append({"text": text, "pos": pos, "age": 0.0})
	queue_redraw()

# Resolve every creature type in the battle to its atlas texture + per-group frame metadata (or
# leave it out of _sprites, which means "draw the placeholder token").
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
		if typeof(meta) != TYPE_DICTIONARY or not meta.has("groups"):
			continue
		var groups := {}
		for gid in meta["groups"]:
			var g: Dictionary = meta["groups"][gid]
			groups[int(gid)] = {
				"y": int(g["y"]), "w": int(g["frame_w"]), "h": int(g["frame_h"]),
				"count": int(g["count"]),
				"anchor": Vector2(float(g["anchor_x"]), float(g["anchor_y"])),
			}
		_sprites[id] = {"tex": tex, "groups": groups}

# Advance the clocks. While BattleAnimator has anything in flight we redraw every frame; when the
# field is at rest, only on idle-frame boundaries (~6 fps).
func _process(delta: float) -> void:
	_anim_time += delta
	var redraw := not overrides.is_empty() or not tracer.is_empty()
	if not floaters.is_empty():
		for f in floaters:
			f["age"] += delta
		floaters = floaters.filter(func(f: Dictionary) -> bool: return f["age"] < FLOATER_LIFE)
		redraw = true
	var frame := int(_anim_time / IDLE_FRAME_TIME)
	if frame != _anim_frame:
		_anim_frame = frame
		redraw = redraw or not _sprites.is_empty()
	if redraw:
		queue_redraw()

# --- Hit-testing (input) ---

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

## The living stack whose drawn sprite (or token) covers a field-local point, topmost first.
## Creatures stand much taller than their hex, so tapping one MUST be tested against the art —
## by the grid alone, a tap on a griffin's head lands on the empty hex behind it.
func stack_at_point(local_pos: Vector2) -> CreatureStack:
	var living := model.stacks.filter(func(s: CreatureStack) -> bool: return s.is_alive())
	living.sort_custom(func(a: CreatureStack, b: CreatureStack) -> bool: return a.hex.y > b.hex.y)
	for stack: CreatureStack in living:   # drawn last = on top = tested first
		var feet := ground_of(stack.hex)
		var sprite: Dictionary = _sprites.get(stack.creature.id, {})
		if sprite.is_empty():
			if local_pos.distance_to(hex_center(stack.hex.x, stack.hex.y)) <= HEX_SIZE * 0.6:
				return stack
			continue
		var info: Dictionary = sprite["groups"][GROUP_IDLE]
		var anchor: Vector2 = info["anchor"]
		var size := Vector2(info["w"], info["h"]) * SPRITE_SCALE
		# The sprite's left edge depends on facing (enemy is mirrored around the anchor).
		var left := feet.x - (anchor.x * SPRITE_SCALE if stack.side == 0 else size.x - anchor.x * SPRITE_SCALE)
		if Rect2(Vector2(left, feet.y - anchor.y * SPRITE_SCALE), size).has_point(local_pos):
			return stack
	return null

# --- Geometry ---

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

# --- Drawing ---

func _draw() -> void:
	if model == null:
		return
	for row in BattleModel.ROWS:
		for col in BattleModel.COLS:
			_draw_hex(hex_center(col, row))

	# Movement range for the active stack: a soft teal wash over reachable hexes.
	for hex in reachable:
		_fill_hex(hex_center(hex.x, hex.y), Color(0.45, 0.85, 0.95, 0.16))

	# Stacks, top row first so creatures on lower hexes overlap the ones behind (painter's order).
	# Dead stacks still in `overrides` are drawn too — that's their death animation playing out.
	var drawable := model.stacks.filter(
		func(s: CreatureStack) -> bool: return s.is_alive() or overrides.has(s))
	drawable.sort_custom(func(a: CreatureStack, b: CreatureStack) -> bool: return a.hex.y < b.hex.y)
	for stack: CreatureStack in drawable:
		_draw_stack(stack)
	# Rings and badges in a second pass so no sprite can cover them (dead stacks get neither).
	for stack: CreatureStack in drawable:
		if not stack.is_alive():
			continue
		var c := hex_center(stack.hex.x, stack.hex.y)
		if stack == active:
			draw_arc(c, HEX_SIZE * 0.7, 0.0, TAU, 32, Color(1.0, 0.95, 0.7, 0.95), 2.5)  # active ring
		_draw_count_badge(stack, c, PLAYER_COLOR if stack.side == 0 else ENEMY_COLOR)

	_draw_tracer()
	_draw_floaters()

# One stack's creature: soft side-coloured under-glow + the sprite (or fallback token), honouring
# any BattleAnimator override (pose, position, alpha).
func _draw_stack(stack: CreatureStack) -> void:
	var ov: Dictionary = overrides.get(stack, {})
	var color := PLAYER_COLOR if stack.side == 0 else ENEMY_COLOR
	var feet: Vector2 = ov.get("pos", ground_of(stack.hex))
	var alpha: float = ov.get("alpha", 1.0)

	# A soft side-coloured pool under the creature — the luminous marker of whose it is, readable
	# at a glance in the dark (the sprites themselves aren't tinted).
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.45))   # squash a circle into a ground ellipse
	draw_circle(Vector2.ZERO, HEX_SIZE * 0.55, Color(color.r, color.g, color.b, 0.22 * alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	var sprite: Dictionary = _sprites.get(stack.creature.id, {})
	if sprite.is_empty():
		draw_circle(feet - Vector2(0.0, GROUND_OFFSET), HEX_SIZE * 0.38, color)   # fallback token
		return

	var groups: Dictionary = sprite["groups"]
	var group: int = ov.get("group", GROUP_IDLE)
	if not groups.has(group):
		group = GROUP_IDLE   # e.g. a melee creature asked for a shoot pose it doesn't have
	var info: Dictionary = groups[group]
	var frame: int
	if ov.has("frame"):
		frame = ov["frame"] % int(info["count"])   # animator counts up; wrap for looping strides
	else:
		# Idle, phase-shifted by hex so the field doesn't tick in unison.
		frame = (_anim_frame + stack.hex.x * 3 + stack.hex.y * 5) % int(info["count"])
	var src := Rect2(frame * int(info["w"]), int(info["y"]), int(info["w"]), int(info["h"]))
	# Pin the frame's anchor (body centre, ground line) to the feet point. Classic sprites face
	# right (the player side); mirror around the anchor for the enemy.
	var flip := Vector2(-1.0, 1.0) if stack.side == 1 else Vector2(1.0, 1.0)
	var anchor: Vector2 = info["anchor"]
	draw_set_transform(feet, 0.0, flip)
	draw_texture_rect_region(sprite["tex"], Rect2(-anchor * SPRITE_SCALE, src.size * SPRITE_SCALE),
			src, Color(1.0, 1.0, 1.0, alpha))
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

# Floating damage numbers: drift up and fade — warm and luminous, but small (dark-room rules).
func _draw_floaters() -> void:
	var font := ThemeDB.fallback_font
	for f: Dictionary in floaters:
		var t: float = f["age"] / FLOATER_LIFE
		var alpha := 1.0 - t * t   # hold early, fade late
		var size := font.get_string_size(f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var at: Vector2 = f["pos"] + Vector2(-size.x * 0.5, -FLOATER_RISE * t)
		draw_string(font, at + Vector2(1.0, 1.0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.0, 0.0, 0.0, 0.7 * alpha))
		draw_string(font, at, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.88, 0.6, alpha))

# A shot in flight: a small luminous head with a fading tail — the glow language, not a sprite.
func _draw_tracer() -> void:
	if tracer.is_empty():
		return
	var from: Vector2 = tracer["from"]
	var to: Vector2 = tracer["to"]
	for i in 4:
		var t: float = clampf(float(tracer["t"]) - 0.06 * i, 0.0, 1.0)
		draw_circle(from.lerp(to, t), 4.5 - i, Color(1.0, 0.9, 0.6, 0.9 - 0.22 * i))

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
