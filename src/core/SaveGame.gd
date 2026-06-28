extends Node
## Autosave + instant resume. The play context demands it: she drops the game the moment she's
## drowsy and picks it up cold another night, so we save constantly and resume to (near) the second.
## Autoloaded as `SaveGame` (see project.godot).
##
## One slot, JSON, in user:// (writable on Android, survives reinstalls of the app's code). The
## save holds only model state — which map, whose turn, the RNG position, heroes, fog, and the
## camera view; the map tiles themselves are reloaded from data/maps via the stored path. Main
## owns the scene nodes, so it calls write()/read() and applies the result.

const SAVE_PATH := "user://savegame.json"
const VERSION := 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Serialize the current GameState (+ an opaque `view` dict from Main, e.g. camera) to disk.
func write(view: Dictionary = {}) -> void:
	var heroes: Array = []
	for hero in GameState.heroes:
		heroes.append(hero.to_dict())

	var data := {
		"version": VERSION,
		"map": GameState.map_source,
		"current_player": GameState.current_player,
		"rng_state": str(GameState.rng.state),   # 64-bit; string-encoded to dodge JSON float precision
		"heroes": heroes,
		"fog": GameState.fog.to_dict() if GameState.fog != null else {},
		"view": view,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: cannot write %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))

## Parsed save dict, or {} if there's no (valid) save. Main reconstructs the game from it.
func read() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
