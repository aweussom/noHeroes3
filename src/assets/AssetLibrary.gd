extends Node
## The swappable asset layer. Everything asks for art by LOGICAL NAME
## (e.g. "hero.knight.idle"), never by file path — so swapping assets/manifest.json
## swaps the art without touching code. This is also the distribution escape hatch:
## the copyrighted originals stay hidden behind these logical names.
## Autoloaded as `AssetLibrary` (see project.godot).

const MANIFEST_PATH := "res://assets/manifest.json"

var _manifest: Dictionary = {}

func _ready() -> void:
	_load_manifest()

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("No asset manifest yet at %s" % MANIFEST_PATH)
		return
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_manifest = parsed

func texture(logical_name: String) -> Texture2D:
	# TODO(M1+): resolve logical_name -> file via _manifest, then load and cache.
	if not _manifest.has(logical_name):
		push_warning("Unknown asset: %s" % logical_name)
		return null
	return load(_manifest[logical_name])
