class_name MapView
extends Node2D
## Renders a MapModel onto a TileMapLayer (Godot 4.5: TileMapLayer, not the deprecated TileMap).
##
## Each terrain id becomes one TileSet source. The tile texture is the real extracted HoMM3
## terrain tile (via AssetLibrary, built by tooling/build_terrain_assets.py) when present, and
## falls back to a solid placeholder colour when it isn't — so the game still renders on a fresh
## checkout before the gitignored assets/ folder has been generated. The painting loop is
## texture-agnostic; only _terrain_texture() decides real-vs-placeholder.

const TILE_SIZE := 32

# Terrain id (MapModel.*) -> placeholder colour. Dark and low-glare on purpose.
# A member var (not const): Color("hex") and cross-class const refs aren't constant expressions.
var _terrain_colors := {
	MapModel.DIRT:         Color("3a2e23"),
	MapModel.SAND:         Color("6b5d3e"),
	MapModel.GRASS:        Color("23401f"),
	MapModel.SNOW:         Color("4a5560"),
	MapModel.SWAMP:        Color("1f3a36"),
	MapModel.ROUGH:        Color("4a3f2a"),
	MapModel.SUBTERRANEAN: Color("241a2e"),
	MapModel.LAVA:         Color("4a1f1a"),
	MapModel.WATER:        Color("13283f"),
	MapModel.ROCK:         Color("121215"),
}

# Terrain id -> AssetLibrary logical name (matches the keys build_terrain_assets.py writes).
# A var, not const: cross-class const refs (MapModel.*) aren't constant expressions.
var _terrain_assets := {
	MapModel.DIRT:         "terrain.dirt",
	MapModel.SAND:         "terrain.sand",
	MapModel.GRASS:        "terrain.grass",
	MapModel.SNOW:         "terrain.snow",
	MapModel.SWAMP:        "terrain.swamp",
	MapModel.ROUGH:        "terrain.rough",
	MapModel.SUBTERRANEAN: "terrain.subterranean",
	MapModel.LAVA:         "terrain.lava",
	MapModel.WATER:        "terrain.water",
	MapModel.ROCK:         "terrain.rock",
}

@export var terrain_layer: TileMapLayer

var _model: MapModel

## Paint the whole map. Safe to call again to swap maps.
func show_map(model: MapModel) -> void:
	_model = model
	# Prefer the editor-wired export; fall back to the conventional child node so a
	# hand-authored scene works too (node-reference exports don't always resolve on load).
	if terrain_layer == null:
		terrain_layer = get_node_or_null(^"TerrainLayer") as TileMapLayer
	if terrain_layer == null:
		push_error("MapView: no terrain_layer assigned and no 'TerrainLayer' child found.")
		return

	terrain_layer.tile_set = _build_tileset()
	terrain_layer.clear()
	for y in model.height:
		for x in model.width:
			# source_id == terrain id (see _build_tileset); single 1x1 atlas tile at (0,0).
			terrain_layer.set_cell(Vector2i(x, y), model.terrain_at(x, y), Vector2i.ZERO)

	# TODO(M1+): place object sprites from model.objects via AssetLibrary, once art is extracted.

## Map size in world pixels — the camera uses this to frame and clamp.
func map_bounds() -> Rect2:
	if _model == null:
		return Rect2()
	return Rect2(Vector2.ZERO, Vector2(_model.width, _model.height) * TILE_SIZE)

# One TileSetAtlasSource per terrain, with the source id set to the terrain id so the painting
# loop can pass a terrain id straight to set_cell().
func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for terrain_id in _terrain_colors:
		var src := TileSetAtlasSource.new()
		src.texture = _terrain_texture(terrain_id)
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		src.create_tile(Vector2i.ZERO)
		ts.add_source(src, terrain_id)
	return ts

# The real extracted terrain tile when the pipeline has produced it; otherwise a solid
# placeholder colour, so the map still renders before assets/ has been built.
func _terrain_texture(terrain_id: int) -> Texture2D:
	var logical: String = _terrain_assets.get(terrain_id, "")
	if logical != "":
		var tex := AssetLibrary.texture(logical)
		if tex != null:
			return tex
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(_terrain_colors[terrain_id])
	return ImageTexture.create_from_image(img)
