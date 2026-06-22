class_name TouchInput
extends Node
## Translates raw touch/mouse into game intents (tap-to-move, drag-pan, pinch-zoom).
## Touch is the PRIMARY input (Android tablet); mouse mirrors it for desktop testing.

signal tapped(world_position: Vector2)
signal panned(delta: Vector2)
signal zoomed(factor: float, center: Vector2)

func _unhandled_input(event: InputEvent) -> void:
	# TODO(M2): gesture recognition — single tap, drag-pan, two-finger pinch-zoom.
	pass
