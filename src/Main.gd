extends Node
## Root coordinator: boots the game and (later) switches between the adventure map and battle.
## Attached to the root of Main.tscn, which is the project's main scene.
##
## On launch it resumes the autosave if one exists, else starts a new game; from then on it
## autosaves after every move, every turn, and whenever the app is paused or closed — so the game
## is always safe to drop and resume cold (see SaveGame).

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
var _battle: BattleView   # the current battle, or null when on the adventure map

func _ready() -> void:
	# Camera gestures.
	_touch.panned.connect(_camera.pan_by)
	_touch.zoomed.connect(_camera.zoom_at)
	# Gameplay: tap to move, button to end the turn.
	_touch.tapped.connect(_on_tapped)
	_hud.end_turn_requested.connect(GameState.end_turn)
	_hud.battle_requested.connect(_start_battle)
	GameState.turn_changed.connect(_on_turn_changed)

	if SaveGame.has_save():
		_resume(SaveGame.read())
	if _hero == null:        # no save, or it was unusable — start fresh
		_new_game()

	_update_hud()

# Build the map render + pathfinder for a model (shared by new game and resume).
func _setup_map(model: MapModel) -> void:
	_model = model
	GameState.map = model
	_map_view.show_map(model)
	_pathfinder = Pathfinder.new(model)

func _new_game() -> void:
	var model := _load_map(SAMPLE_MAP)
	if model == null:
		return
	GameState.map_source = SAMPLE_MAP
	_setup_map(model)

	GameState.fog = FogModel.new(model.width, model.height)
	_fog_view.show_fog(GameState.fog)

	_hero = Hero.new()
	_hero.id = "player"
	_hero.place(HERO_START)
	_hero.max_movement_points = HERO_MOVEMENT
	_hero.refill_movement()
	GameState.heroes.clear()
	GameState.heroes.append(_hero)
	_hero_view.set_cell(_hero.cell())

	# Reveal the hero's starting surroundings.
	GameState.fog.reveal_disc(_hero.cell(), _hero.sight_radius, FogModel.VISIBLE)
	_fog_view.refresh()

	_camera.frame_map(_map_view.map_bounds())
	_autosave()

# Reconstruct a game from a save dict. Leaves _hero null (so _ready falls back to a new game) if
# the save is unusable.
func _resume(data: Dictionary) -> void:
	var model := _load_map(String(data.get("map", SAMPLE_MAP)))
	if model == null:
		return
	GameState.map_source = String(data.get("map", SAMPLE_MAP))
	_setup_map(model)

	GameState.current_player = int(data.get("current_player", 0))
	if data.has("rng_state"):
		GameState.rng.state = int(String(data["rng_state"]))

	GameState.heroes.clear()
	for hero_data in data.get("heroes", []):
		GameState.heroes.append(Hero.from_dict(hero_data))
	if GameState.heroes.is_empty():
		return   # corrupt save -> caller starts a new game
	_hero = GameState.heroes[0]

	var fog_data: Dictionary = data.get("fog", {})
	GameState.fog = FogModel.from_dict(fog_data) if not fog_data.is_empty() else FogModel.new(model.width, model.height)
	_fog_view.show_fog(GameState.fog)

	_hero_view.set_cell(_hero.cell())
	_apply_view(data.get("view", {}))

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
	_autosave()

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
	_autosave()

# M4.1 debug: stage a test battle. (Later this is triggered by walking into a map monster, with
# the hero's real army.) The BattleView overlay covers and blocks the map until it finishes.
func _start_battle() -> void:
	if _battle != null:
		return
	var player_army := [
		{"creature": Creature.make("griffin"), "count": 7},
		{"creature": Creature.make("swordsman"), "count": 12},
		{"creature": Creature.make("archer"), "count": 20},
		{"creature": Creature.make("pikeman"), "count": 30},
	]
	var enemy_army := [
		{"creature": Creature.make("wolf"), "count": 15},
		{"creature": Creature.make("orc"), "count": 18},
		{"creature": Creature.make("gnoll"), "count": 30},
	]
	_battle = BattleView.new()
	add_child(_battle)
	_battle.setup(BattleModel.new(player_army, enemy_army))
	_battle.finished.connect(_end_battle)

func _end_battle() -> void:
	if _battle != null:
		_battle.queue_free()
		_battle = null

func _update_hud() -> void:
	if _hero != null:
		_hud.update_movement(_hero.movement_points, _hero.max_movement_points)

# Persist now. Cheap (small JSON), so we can call it on every meaningful change.
func _autosave() -> void:
	SaveGame.write(_view_state())

# Save on the moments she actually puts the tablet down: app backgrounded or window closed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if GameState.map != null:
			_autosave()

func _view_state() -> Dictionary:
	return {"cam_x": _camera.position.x, "cam_y": _camera.position.y, "zoom": _camera.zoom.x}

func _apply_view(view: Dictionary) -> void:
	_camera.frame_map(_map_view.map_bounds())   # set limits + make current
	if view.has("zoom"):
		_camera.zoom = Vector2(float(view["zoom"]), float(view["zoom"]))
	if view.has("cam_x"):
		_camera.position = Vector2(float(view["cam_x"]), float(view["cam_y"]))

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
