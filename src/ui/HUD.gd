class_name HUD
extends CanvasLayer
## On-screen UI. Dark, high-contrast, large touch targets for sleepy one-handed play.
## Anything signalled by sound MUST also appear here — assume the game is muted.
##
## Built in code (not a .tscn) so it stays auditable in one file. M2: a movement readout and an
## End Turn button. TODO(M3): theme pass + resource/hero panels.

signal end_turn_requested
signal battle_requested   # M4 debug: start a test battle (no map monsters yet)

const TEXT_COLOR := Color(0.85, 0.78, 0.55)   # warm, dim — readable at low brightness.

var _movement_label: Label

func _ready() -> void:
	layer = 10

	# Full-rect, click-through container so map taps pass to the game; only the button stops input.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -260
	box.offset_top = -150
	box.offset_right = -20
	box.offset_bottom = -20
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)

	_movement_label = Label.new()
	_movement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_movement_label.add_theme_color_override("font_color", TEXT_COLOR)
	box.add_child(_movement_label)

	var end_turn := Button.new()
	end_turn.text = "End Turn"
	end_turn.custom_minimum_size = Vector2(240, 72)   # generous touch target
	end_turn.pressed.connect(func() -> void: end_turn_requested.emit())
	box.add_child(end_turn)

	var battle := Button.new()
	battle.text = "Battle (debug)"
	battle.custom_minimum_size = Vector2(240, 56)
	battle.pressed.connect(func() -> void: battle_requested.emit())
	box.add_child(battle)

func update_movement(current: int, maximum: int) -> void:
	_movement_label.text = "Movement  %d / %d" % [current, maximum]
