class_name HeroView
extends Node2D
## The player's hero on the map: a real HoMM3 adventure-map sprite that faces its travel direction
## and plays a walk cycle while moving. Lives under MapView so its coordinates match the grid.
##
## The sprite comes from AH00_.def via the asset pipeline (assets/sprites/hero_knight.*). If those
## assets aren't built yet (fresh checkout — assets/ is gitignored) it falls back to the old
## luminous placeholder dot so the hero is still visible. Either way a warm PointLight2D casts the
## reveal glow the look is built around (additive-blend + Light2D, not WorldEnvironment — see FogLayer).
##
## Direction -> def group follows HoMM3's convention (confirmed against VCMI MapRendererContext):
## five facings are stored (N, NE, E, SE, S; standing groups 0-4, walking groups 5-9), and the
## three left facings are those mirrored — so we flip NE/E/SE horizontally for NW/W/SW.

const STEP_TIME := 0.14            # seconds per tile; gentle, un-rushed for sleepy play.
const WALK_FRAMES := 8             # frames per walking group; one full stride per tile.

const LIGHT_COLOR := Color(1.0, 0.82, 0.5)
const LIGHT_ENERGY := 1.1
const LIGHT_RADIUS_TILES := 4.0

# Travel direction (sign of the step) -> [standing group, walking group, flip horizontally].
# A var, not const: Vector2i keys / mixed arrays aren't constant expressions.
var _facing := {
	Vector2i(0, -1):  [0, 5, false],   # N
	Vector2i(1, -1):  [1, 6, false],   # NE
	Vector2i(1, 0):   [2, 7, false],   # E
	Vector2i(1, 1):   [3, 8, false],   # SE
	Vector2i(0, 1):   [4, 9, false],   # S
	Vector2i(-1, 1):  [3, 8, true],    # SW = SE mirrored
	Vector2i(-1, 0):  [2, 7, true],    # W  = E  mirrored
	Vector2i(-1, -1): [1, 6, true],    # NW = NE mirrored
}

var _cell := Vector2i.ZERO
var _dir := Vector2i(0, 1)          # facing south by default (HoMM3's resting facing)
var _move_tween: Tween

var _sprite: Sprite2D
var _group_rects: Dictionary = {}   # def group -> Array[Rect2] of atlas regions, in frame order
var _moving := false
var _walk_t := 0.0

func _ready() -> void:
	z_index = 10   # draw above the terrain and fog layers
	_add_light()
	_load_sprite()

## Jump instantly to a cell (initial placement).
func set_cell(cell: Vector2i) -> void:
	_cell = cell
	position = _cell_to_world(cell)
	_show_standing()

## Animate step-by-step along `cells` (the walk steps from Pathfinder.reachable_prefix), turning
## to face each step and playing the walk cycle until the hero arrives.
func move_along(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_set_moving(true)
	_move_tween = create_tween()
	var from := _cell
	for cell in cells:
		_move_tween.tween_callback(_face.bind(_step_dir(cell - from)))
		_move_tween.tween_property(self, "position", _cell_to_world(cell), STEP_TIME)
		from = cell
	_move_tween.tween_callback(_set_moving.bind(false))
	_cell = cells[-1]

func is_moving() -> bool:
	return _move_tween != null and _move_tween.is_valid() and _move_tween.is_running()

func _process(delta: float) -> void:
	if not _moving or _group_rects.is_empty():
		return
	_walk_t += delta
	var walk_group: int = _facing[_dir][1]
	var rects: Array = _group_rects.get(walk_group, [])
	if rects.is_empty():
		return
	var index := int(_walk_t / (STEP_TIME / WALK_FRAMES)) % rects.size()
	_apply_frame(rects[index], _facing[_dir][2])

func _face(dir: Vector2i) -> void:
	_dir = dir

func _set_moving(moving: bool) -> void:
	_moving = moving
	_walk_t = 0.0
	if not moving:
		_show_standing()

# Show the standing frame for the current facing (no-op without a loaded sprite — the dot shows).
func _show_standing() -> void:
	if _group_rects.is_empty():
		return
	var info: Array = _facing[_dir]
	_apply_frame(_group_rects[info[0]][0], info[2])

func _apply_frame(region: Rect2, flip_h: bool) -> void:
	_sprite.region_rect = region
	_sprite.flip_h = flip_h

func _step_dir(delta: Vector2i) -> Vector2i:
	return Vector2i(signi(delta.x), signi(delta.y))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * MapView.TILE_SIZE

# Build the Sprite2D from the hero atlas + frame JSON. Leaves _group_rects empty (so _draw shows
# the placeholder dot) if the assets haven't been generated yet.
func _load_sprite() -> void:
	var atlas := AssetLibrary.texture("hero.knight.atlas")
	var frames_path := AssetLibrary.file_path("hero.knight.frames")
	if atlas == null or frames_path == "" or not FileAccess.file_exists(frames_path):
		_use_placeholder_glow()
		return
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(frames_path))
	if typeof(meta) != TYPE_DICTIONARY:
		_use_placeholder_glow()
		return

	for frame in meta["frames"]:
		var group := int(frame["group"])
		_group_rects.get_or_add(group, [])
		_group_rects[group].append(Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))

	_sprite = Sprite2D.new()
	_sprite.texture = atlas
	_sprite.region_enabled = true
	_sprite.centered = true
	# The 96x64 frame is 3 tiles wide x 2 tall with the figure bottom-centred; offset so its bottom
	# row sits on the hero's tile and it's horizontally centred.
	_sprite.offset = Vector2(0, MapView.TILE_SIZE * 0.5 - meta["cell_h"] * 0.5)
	add_child(_sprite)
	_show_standing()

func _draw() -> void:
	# Placeholder luminous token, only while the real sprite hasn't loaded (see _load_sprite).
	if not _group_rects.is_empty():
		return
	draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.85, 0.45, 0.18))
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.88, 0.55, 0.95))

# ADD-blend the node so the placeholder dot reads as emitted light. Only needed in fallback mode;
# the real sprite is lit art and renders normally.
func _use_placeholder_glow() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	queue_redraw()

# A warm PointLight2D pool over the terrain — the reveal glow, present in both modes.
func _add_light() -> void:
	var light := PointLight2D.new()
	light.texture = _radial_light_texture()
	light.color = LIGHT_COLOR
	light.energy = LIGHT_ENERGY
	# The gradient spans center->edge over half the texture, so scale 1 ≈ texture_width/2 pixels.
	var radius_px := LIGHT_RADIUS_TILES * MapView.TILE_SIZE
	light.texture_scale = radius_px / (light.texture.get_width() * 0.5)
	add_child(light)

# A soft round falloff texture for the point light (white center fading to transparent edge).
func _radial_light_texture() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
