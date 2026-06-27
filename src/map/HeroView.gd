class_name HeroView
extends Node2D
## The player's hero on the map. M2 draws a PLACEHOLDER luminous token (a glowing dot) — fitting
## the dark, luminous-on-black look — until real HoMM3 hero sprites are extracted and the draw is
## swapped for an animated sprite. Lives under MapView so its coordinates match the terrain grid.

const STEP_TIME := 0.14   # seconds per tile; gentle, un-rushed for sleepy play.

# Warm reveal pool cast on the terrain around the hero. Its radius is tuned to roughly match the
# hero's sight (Hero.sight_radius) so the lit area and the un-veiled area line up.
const LIGHT_COLOR := Color(1.0, 0.82, 0.5)
const LIGHT_ENERGY := 1.1
const LIGHT_RADIUS_TILES := 4.0

var _cell := Vector2i.ZERO
var _move_tween: Tween

func _ready() -> void:
	z_index = 10   # draw above the terrain layer
	_add_glow()

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
	# Luminous token: soft halo + bright core, ADD-blended (see _add_glow) so it reads as emitted
	# light on the dark map rather than a flat dot. Real HoMM3 hero sprites replace this later.
	draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.85, 0.45, 0.18))
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.88, 0.55, 0.95))

# A PointLight2D pool over the terrain, plus ADD blend on the token itself. This is the
# additive-blend + Light2D glow the project commits to (not WorldEnvironment glow, which the
# Android Compatibility renderer can't be relied on for — see FogLayer).
func _add_glow() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

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
