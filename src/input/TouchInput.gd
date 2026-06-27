class_name TouchInput
extends Node
## Translates raw touch/mouse into game intents. Touch is the PRIMARY input (Android tablet);
## mouse + trackpad mirror it so the game is testable on the desktop without a tablet.
##
## M1 emits pan + zoom (driving the camera). `tapped` (tap-to-move) lands in M2.

signal tapped(world_position: Vector2)            # TODO(M2): single-tap to move a hero.
signal panned(screen_delta: Vector2)              # one-finger / left-drag, in screen pixels.
signal zoomed(factor: float, center: Vector2)     # pinch / wheel; factor > 1 zooms in.

# Active touch points: touch index -> last screen position. Drives the one-vs-two-finger split.
var _touches: Dictionary = {}
var _last_pinch_distance: float = 0.0
var _mouse_panning: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			_last_pinch_distance = 0.0   # reset so the next pinch starts clean
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_handle_pinch()
		else:
			panned.emit(event.relative)
	# --- Desktop testing: left-drag pans, wheel and trackpad-pinch zoom. ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoomed.emit(1.1, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoomed.emit(1.0 / 1.1, event.position)
	elif event is InputEventMouseMotion and _mouse_panning:
		panned.emit(event.relative)
	elif event is InputEventMagnifyGesture:
		zoomed.emit(event.factor, event.position)

# Pinch-zoom from the two active touches: change in finger spread -> zoom factor.
func _handle_pinch() -> void:
	var points: Array = _touches.values()
	var distance: float = points[0].distance_to(points[1])
	var center: Vector2 = (points[0] + points[1]) * 0.5
	if _last_pinch_distance > 0.0 and distance > 0.0:
		zoomed.emit(distance / _last_pinch_distance, center)
	_last_pinch_distance = distance
