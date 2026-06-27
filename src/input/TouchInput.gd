class_name TouchInput
extends Node
## Translates raw touch/mouse into game intents. Touch is the PRIMARY input (Android tablet);
## mouse + trackpad mirror it so the game is testable on the desktop without a tablet.
##
## Emits pan + zoom (camera) and tap (M2: tap-to-move). A tap is a press that releases without
## moving far and without a second finger — a drag pans instead, a pinch zooms instead.

signal tapped(screen_position: Vector2)           # consumer converts screen -> world.
signal panned(screen_delta: Vector2)              # one-finger / left-drag, in screen pixels.
signal zoomed(factor: float, center: Vector2)     # pinch / wheel; factor > 1 zooms in.

## A press that moves more than this (screen pixels) is a drag, not a tap.
const TAP_MAX_MOVE := 10.0

# Active touch points: touch index -> last screen position. Drives the one-vs-two-finger split.
var _touches: Dictionary = {}
var _last_pinch_distance: float = 0.0
var _mouse_panning: bool = false

# Tap tracking for the primary pointer.
var _press_position: Vector2 = Vector2.ZERO
var _press_moved: bool = false
var _multi_touch: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_begin_press(event.position)
			else:
				_multi_touch = true   # a second finger -> pinch, never a tap
		else:
			_touches.erase(event.index)
			_last_pinch_distance = 0.0   # reset so the next pinch starts clean
			if _touches.is_empty():
				_end_press(event.position)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_multi_touch = true
			_handle_pinch()
		else:
			_track_move(event.position)
			panned.emit(event.relative)
	# --- Desktop testing: left-click taps / left-drag pans, wheel + trackpad-pinch zoom. ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_panning = event.pressed
			if event.pressed:
				_begin_press(event.position)
			else:
				_end_press(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoomed.emit(1.1, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoomed.emit(1.0 / 1.1, event.position)
	elif event is InputEventMouseMotion and _mouse_panning:
		_track_move(event.position)
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

func _begin_press(at: Vector2) -> void:
	_press_position = at
	_press_moved = false
	_multi_touch = false

func _track_move(to: Vector2) -> void:
	if _press_position.distance_to(to) > TAP_MAX_MOVE:
		_press_moved = true

func _end_press(at: Vector2) -> void:
	if not _press_moved and not _multi_touch:
		tapped.emit(at)
