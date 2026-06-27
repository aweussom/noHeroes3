class_name CameraRig
extends Camera2D
## Touch-first camera: drag to pan, pinch to zoom. Mouse drag / wheel mirror it for desktop
## testing. Driven by TouchInput's panned/zoomed signals (wired up in Main). Tuned gentle for
## sleepy one-handed play — no snapping, generous zoom range, clamped to the map.

@export var min_zoom := 0.5
@export var max_zoom := 2.0

## Centre on the map and clamp the view to its edges. Call once after the map is shown.
func frame_map(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)
	position = bounds.get_center()
	make_current()

## Pan by a screen-space drag. Divide by zoom so the map tracks the finger 1:1 on screen.
## Camera2D's limits clamp the resulting view to the map automatically.
func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom

## Multiply the current zoom, clamped. Anchored on the view centre for M1.
## TODO(M2 polish): zoom toward the pinch/cursor focal point for a more natural feel.
func zoom_at(factor: float, _center: Vector2) -> void:
	var z := clampf(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(z, z)
