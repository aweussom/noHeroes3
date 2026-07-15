class_name BattleView
extends CanvasLayer
## The battle screen. A CanvasLayer (not in the world canvas) so it's free of the adventure map's
## night-tint CanvasModulate and camera: it draws in screen space on an opaque dark background that
## both hides the map and swallows input meant for it. Built in code, like HUD, to stay auditable.
##
## The full turn loop runs here: player stacks act by tap (move / attack), enemy stacks act through
## BattleAI with a short beat between actions so the fight stays readable. When a side is wiped the
## view announces the outcome; End Battle closes it (M4 remaining: apply the result to the map).

signal finished

const BG_COLOR := Color(0.03, 0.04, 0.06, 1.0)
const AI_STEP_DELAY := 0.4   # seconds before each enemy action — a calm, followable pace

var _model: BattleModel
var _field: BattleField
var _ai := BattleAI.new()
var _animator: BattleAnimator
var _animating := false   # events are playing back — ignore taps until they finish
var _reachable: Array[Vector2i] = []
var _outcome: Label   # victory/defeat banner, created once the battle is decided

func _ready() -> void:
	layer = 20   # above the adventure map and its HUD

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP   # eat taps so they don't reach the map underneath
	bg.gui_input.connect(_on_field_input)
	add_child(bg)
	_add_background()

	_field = BattleField.new()
	add_child(_field)
	_animator = BattleAnimator.new(_field)
	add_child(_animator)

	_add_button("Skip", -84, func() -> void: _skip())
	_add_button("End Battle", -20, func() -> void: finished.emit())

# The real HoMM3 battlefield behind the hex grid, when the asset pipeline has built it (fresh
# checkouts just keep the dark ColorRect). The art is bright daylight; this CanvasLayer sits
# outside the world canvas (no CanvasModulate), so we dim it here with a cool modulate to keep
# the dark-room look. IGNORE mouse so taps still land on the input-eating ColorRect below.
func _add_background() -> void:
	var tex := AssetLibrary.texture("battle.background.grass")
	if tex == null:
		return
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.modulate = Color(0.38, 0.42, 0.56)   # night-dim, faintly cool — matches the map's mood
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

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

# Start the next stack's turn. Player stacks get highlights and wait for a tap; enemy stacks act
# through BattleAI after a short beat (ringed first, so she can see whose move it was), then the
# turn advances. Once a side is wiped, announce the outcome instead.
func _begin_turn() -> void:
	if _model.winner() != -1:
		_show_outcome()
		return
	var stack := _model.active_stack()
	if stack == null:
		return   # defensive; winner() above already covers a wiped side
	if stack.side == 1:
		_reachable = []
		_field.set_highlights(stack, [])
		await get_tree().create_timer(AI_STEP_DELAY).timeout
		if not is_inside_tree():
			return   # battle was closed while we waited
		await _play(_ai.take_turn(_model, stack))
		if not is_inside_tree():
			return
		_end_turn()
		return
	_reachable = _model.reachable_hexes(stack)
	_field.set_highlights(stack, _reachable)

func _skip() -> void:
	if _animating:
		return
	var stack := _model.active_stack()
	if stack != null and stack.side == 0:
		_model.advance_turn()
		_begin_turn()

func _on_field_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tapped or _animating or _model.winner() != -1:
		return
	var stack := _model.active_stack()
	if stack == null or stack.side != 0:
		return   # not the player's turn

	# What was tapped? The creatures themselves first (they stand tall over the grid — hex-only
	# hit-testing sent taps on an enemy's body to the empty hex behind its head), then the grid.
	var local: Vector2 = event.position - _field.position
	var target := _field.stack_at_point(local)
	var hex := target.hex if target != null else _field.hex_at(local)
	if target == null:
		target = _model.stack_at(hex)

	if target != null and target.side != stack.side:
		_try_attack(stack, target)
	elif target == null and hex in _reachable:
		_move_to(stack, hex)

func _end_turn() -> void:
	_model.advance_turn()
	_begin_turn()

# Walk the active stack to a reachable hex (route captured before the model moves it).
func _move_to(stack: CreatureStack, hex: Vector2i) -> void:
	var path := _model.path_to(stack, hex)
	stack.hex = hex
	await _play([{"kind": "move", "stack": stack, "path": path}])
	_end_turn()

# Attack a target: shoot if ranged and clear of melee; otherwise close to an adjacent hex (if
# reachable) and strike. Shot/retaliation rules live in BattleModel, shared with BattleAI.
func _try_attack(attacker: CreatureStack, target: CreatureStack) -> void:
	var events: Array[Dictionary] = []
	if _model.can_shoot(attacker):
		events = _model.shoot(attacker, target)
	else:
		if not _model.neighbors(attacker.hex).has(target.hex):
			var spot := _reachable_adjacent_to(target)
			if spot.x < 0:
				return   # can't reach the target this turn
			var path := _model.path_to(attacker, spot)
			attacker.hex = spot
			events.append({"kind": "move", "stack": attacker, "path": path})
		events.append_array(_model.melee(attacker, target))
	await _play(events)
	_end_turn()

# Play resolved events as animations, blocking input meanwhile. The model state is already final
# when this starts, so quitting the battle mid-playback is always safe.
func _play(events: Array[Dictionary]) -> void:
	_animating = true
	_field.set_highlights(_field.active, [])   # the old movement range is stale during playback
	await _animator.play(events)
	_animating = false

# The battle is decided: clear the highlights and announce it, dim and centred near the top.
# The End Battle button (always on screen) is the way out.
func _show_outcome() -> void:
	_field.set_highlights(null, [])
	if _outcome != null:
		return
	_outcome = Label.new()
	_outcome.text = "Victory!" if _model.winner() == 0 else "Defeat..."
	_outcome.add_theme_font_size_override("font_size", 48)
	_outcome.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))   # warm, dim (HUD tone)
	_outcome.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_outcome.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_outcome.offset_top = 48
	add_child(_outcome)

# A reachable empty hex next to the target, or (-1, -1) if none.
func _reachable_adjacent_to(target: CreatureStack) -> Vector2i:
	for n in _model.neighbors(target.hex):
		if n in _reachable:
			return n
	return Vector2i(-1, -1)
