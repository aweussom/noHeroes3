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

var _model: BattleModel
var _field: BattleField
var _reachable: Array[Vector2i] = []

func _ready() -> void:
	layer = 20   # above the adventure map and its HUD

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP   # eat taps so they don't reach the map underneath
	bg.gui_input.connect(_on_field_input)
	add_child(bg)

	_field = BattleField.new()
	add_child(_field)

	_add_button("Skip", -84, func() -> void: _skip())
	_add_button("End Battle", -20, func() -> void: finished.emit())

func _add_button(text: String, bottom_offset: float, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 56)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = -220
	b.offset_top = bottom_offset - 56
	b.offset_right = -20
	b.offset_bottom = bottom_offset
	b.pressed.connect(on_press)
	add_child(b)

## Show a battle and centre it on screen, then start the first turn.
func setup(model: BattleModel) -> void:
	_model = model
	_field.set_model(model)
	var field_size := _field.pixel_size()
	var view_size := get_viewport().get_visible_rect().size
	_field.position = (view_size - field_size) * 0.5
	_begin_turn()

# Advance to the next stack the player controls, auto-passing enemy turns (placeholder for the
# M4.4 AI), then highlight it and its movement range.
func _begin_turn() -> void:
	var guard := 0
	while _model.active_stack() != null and _model.active_stack().side == 1 and guard < 1000:
		_model.advance_turn()
		guard += 1
	var stack := _model.active_stack()
	_reachable = _model.reachable_hexes(stack) if stack != null else []
	_field.set_highlights(stack, _reachable)

func _skip() -> void:
	var stack := _model.active_stack()
	if stack != null and stack.side == 0:
		_model.advance_turn()
		_begin_turn()

func _on_field_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	var stack := _model.active_stack()
	if stack == null or stack.side != 0:
		return   # not the player's turn
	var hex := _field.hex_at(event.position - _field.position)
	var target := _model.stack_at(hex)
	if target != null and target.side != stack.side:
		_try_attack(stack, target)
	elif hex in _reachable:
		stack.hex = hex
		_end_turn()

func _end_turn() -> void:
	_model.advance_turn()
	_begin_turn()

# Attack a target: shoot if ranged and clear of melee; otherwise close to an adjacent hex (if
# reachable) and strike, taking one retaliation if the defender survives.
func _try_attack(attacker: CreatureStack, target: CreatureStack) -> void:
	if attacker.is_ranged() and attacker.shots_left > 0 and not _model.has_adjacent_enemy(attacker):
		attacker.shots_left -= 1
		_model.deal_damage(attacker, target)
		_end_turn()
		return

	if not _model.neighbors(attacker.hex).has(target.hex):
		var spot := _reachable_adjacent_to(target)
		if spot.x < 0:
			return   # can't reach the target this turn
		attacker.hex = spot

	_model.deal_damage(attacker, target)
	if target.is_alive() and not target.retaliated:
		target.retaliated = true
		_model.deal_damage(target, attacker)
	_end_turn()

# A reachable empty hex next to the target, or (-1, -1) if none.
func _reachable_adjacent_to(target: CreatureStack) -> Vector2i:
	for n in _model.neighbors(target.hex):
		if n in _reachable:
			return n
	return Vector2i(-1, -1)
