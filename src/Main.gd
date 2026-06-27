extends Node
## Root coordinator: boots the game and (later) switches between the adventure map and battle.
## Attached to the root of Main.tscn, which is the project's main scene.

const SAMPLE_MAP := "res://data/maps/sample.json"

@onready var _map_view: MapView = $MapView
@onready var _camera: CameraRig = $CameraRig
@onready var _touch: TouchInput = $TouchInput

func _ready() -> void:
	var model := _load_map(SAMPLE_MAP)
	if model == null:
		return

	GameState.map = model
	_map_view.show_map(model)
	_camera.frame_map(_map_view.map_bounds())

	# Touch/mouse gestures drive the camera. (tapped -> hero move arrives in M2.)
	_touch.panned.connect(_camera.pan_by)
	_touch.zoomed.connect(_camera.zoom_at)

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
