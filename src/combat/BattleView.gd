class_name BattleView
extends CanvasLayer
## The battle screen. A CanvasLayer (not in the world canvas) so it's free of the adventure map's
## night-tint CanvasModulate and camera: it draws in screen space on an opaque dark background that
## both hides the map and swallows input meant for it. Built in code, like HUD, to stay auditable.
##
## M4.1 just stages the battle (grid + armies) with an End Battle button. Turn order, movement,
## attacks and AI land in M4.2-M4.4; this view grows to handle their input and animation.

signal finished

const BG_COLOR := Color(0.03, 0.04, 0.06, 1.0)

var _field: BattleField

func _ready() -> void:
	layer = 20   # above the adventure map and its HUD

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP   # eat taps so they don't reach the map underneath
	add_child(bg)

	_field = BattleField.new()
	add_child(_field)

	var leave := Button.new()
	leave.text = "End Battle"
	leave.custom_minimum_size = Vector2(200, 64)
	leave.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	leave.offset_left = -220
	leave.offset_top = -84
	leave.offset_right = -20
	leave.offset_bottom = -20
	leave.pressed.connect(func() -> void: finished.emit())
	add_child(leave)

## Show a battle and centre it on screen.
func setup(model: BattleModel) -> void:
	_field.set_model(model)
	var field_size := _field.pixel_size()
	var view_size := get_viewport().get_visible_rect().size
	_field.position = (view_size - field_size) * 0.5
