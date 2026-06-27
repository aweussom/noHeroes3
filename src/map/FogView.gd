class_name FogView
extends Node2D
## Draws the fog-of-war veil from a FogModel: one dark quad per non-visible tile, mirroring the
## model exactly so what she sees IS the mechanic. Lives under MapView so it shares the terrain
## grid. The warm reveal glow is a separate Light2D (HeroView) — this veil is the hard edge.
##
## light_mask = 0 keeps the hero's light from lifting the veil: the model alone decides visibility,
## the light only flatters the terrain underneath the clear (VISIBLE) tiles.

# Explored terrain stays nearly as bright as active sight (HoMM3-style: once seen, you see it) —
# only a whisper of cool veil marks it as "remembered, not watched". Hidden stays near-opaque
# black; that large unexplored expanse is what keeps the screen dark, not dimming what she sees.
const EXPLORED_VEIL := Color(0.03, 0.04, 0.07, 0.10)
const HIDDEN_VEIL := Color(0.01, 0.01, 0.02, 0.99)

var _fog: FogModel

func _ready() -> void:
	z_index = 5        # above terrain (0), below the hero (10)
	light_mask = 0     # immune to Light2D; the veil is authoritative

## Bind the model and draw. Safe to call again when the map changes.
func show_fog(fog: FogModel) -> void:
	_fog = fog
	queue_redraw()

## Redraw after the model changed (e.g. the hero revealed new tiles).
func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if _fog == null:
		return
	var ts := MapView.TILE_SIZE
	for y in _fog.height:
		for x in _fog.width:
			var s := _fog.state_at(x, y)
			if s == FogModel.VISIBLE:
				continue
			var veil := HIDDEN_VEIL if s == FogModel.HIDDEN else EXPLORED_VEIL
			draw_rect(Rect2(Vector2(x, y) * ts, Vector2(ts, ts)), veil)
