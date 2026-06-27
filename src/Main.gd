extends Node
## Root coordinator: boots the game and (later) switches between the adventure map and battle.
## Attached to the root of Main.tscn, which is the project's main scene.

const SAMPLE_MAP := "res://data/maps/sample.json"
const HERO_START := Vector2i(2, 2)
const HERO_MOVEMENT := 2000   # ~20 straight tiles per turn (HoMM3 cost units; see Pathfinder).

@onready var _map_view: MapView = $MapView
@onready var _hero_view: HeroView = $MapView/HeroView
@onready var _fog_view: FogView = $MapView/FogView
@onready var _camera: CameraRig = $CameraRig
@onready var _touch: TouchInput = $TouchInput
@onready var _hud: HUD = $HUD

var _model: MapModel
var _pathfinder: Pathfinder
var _hero: Hero

func _ready() -> void:
	_model = _load_map(SAMPLE_MAP)
	if _model == null:
		return

	GameState.map = _model
	_map_view.show_map(_model)
	_camera.frame_map(_map_view.map_bounds())
	_pathfinder = Pathfinder.new(_model)

	GameState.fog = FogModel.new(_model.width, _model.height)
	_fog_view.show_fog(GameState.fog)

	_hero = Hero.new()
	_hero.id = "player"
	_hero.place(HERO_START)
	_hero.max_movement_points = HERO_MOVEMENT
	_hero.refill_movement()
	GameState.heroes.append(_hero)
	_hero_view.set_cell(_hero.cell())

	# Reveal the hero's starting surroundings.
	GameState.fog.reveal_disc(_hero.cell(), _hero.sight_radius, FogModel.VISIBLE)
	_fog_view.refresh()

	# Camera gestures.
	_touch.panned.connect(_camera.pan_by)
	_touch.zoomed.connect(_camera.zoom_at)
	# Gameplay: tap to move, button to end the turn.
	_touch.tapped.connect(_on_tapped)
	_hud.end_turn_requested.connect(GameState.end_turn)
	GameState.turn_changed.connect(_on_turn_changed)

	_update_hud()

# Tap a tile -> walk the hero as far along the path as movement allows.
func _on_tapped(screen_position: Vector2) -> void:
	if _hero_view.is_moving():
		return   # ignore taps mid-move; no queued orders (calmer for sleepy play)

	var target := _cell_at(screen_position)
	if not _model.in_bounds(target.x, target.y) or target == _hero.cell():
		return
	if not _model.is_passable(target.x, target.y):
		return

	var path := _pathfinder.find_path(_hero.cell(), target)
	if path.size() < 2:
		return   # unreachable

	var reach := _pathfinder.reachable_prefix(path, _hero.movement_points)
	var steps: Array[Vector2i] = reach["cells"]
	if steps.is_empty():
		return   # can't even afford the first step this turn

	_hero.movement_points -= int(reach["cost"])
	_hero.place(steps[-1])
	_hero_view.move_along(steps)
	_reveal_along(steps)
	_update_hud()

# Walking reveals terrain along the route: tiles passed become EXPLORED (remembered), and only
# the area around the hero's final cell stays VISIBLE.
func _reveal_along(steps: Array[Vector2i]) -> void:
	GameState.fog.demote_visible()
	for cell in steps:
		GameState.fog.reveal_disc(cell, _hero.sight_radius, FogModel.EXPLORED)
	GameState.fog.reveal_disc(_hero.cell(), _hero.sight_radius, FogModel.VISIBLE)
	_fog_view.refresh()

func _on_turn_changed(_player_index: int) -> void:
	_update_hud()

func _update_hud() -> void:
	_hud.update_movement(_hero.movement_points, _hero.max_movement_points)

# Screen point -> map cell, via the active camera's canvas transform.
func _cell_at(screen_position: Vector2) -> Vector2i:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_position
	return Vector2i((world / MapView.TILE_SIZE).floor())

# Read a converted map JSON into a MapModel. Returns null (and logs) on any failure.
func _load_map(path: String) -> MapModel:
	if not FileAccess.file_exists(path):
		push_error("Main: map not found at %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Main: %s is not valid map JSON" % path)
		return null
	return MapModel.from_json(parsed)
