class_name MapView
extends Node2D
## Renders a MapModel onto TileMapLayer(s) + object sprites.
## Godot 4.5: use TileMapLayer nodes (TileMap is deprecated).

@export var terrain_layer: TileMapLayer

var _model: MapModel

func show_map(model: MapModel) -> void:
	_model = model
	# TODO(M1): paint terrain_layer from model.tiles, place object sprites
	#           (textures via AssetLibrary), and report map bounds to the camera.
	pass
