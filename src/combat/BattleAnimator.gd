class_name BattleAnimator
extends Node
## Plays back the events BattleModel resolves (instantly, deterministically) as slow, readable
## animations on BattleField: walks along the route, melee swings, shots with a luminous tracer,
## hit flinches, death animations with a fade, and floating damage numbers.
##
## Pure view, and deliberately AFTER the fact: by the time an event reaches this class the model
## state is already final, so closing the battle mid-playback can never corrupt anything — the
## animations are storytelling, not simulation. Every hit is shown on screen (silent-first:
## sound can never be the only feedback channel). Pacing is gentle on purpose.

const MOVE_HEX_TIME := 0.14      # per hex walked — matches the adventure hero's pace
const STRIDE_FRAMES := 4.0       # walk-cycle frames advanced per hex
const SWING_TIME := 0.5          # a melee swing or a shot release
const REACT_TIME := 0.45         # the defender's flinch or death animation
const FADE_TIME := 0.4           # a dead stack fading off the field
const TRACER_TIME := 0.22        # projectile flight, whole field in under a quarter second

var _field: BattleField

func _init(field: BattleField) -> void:
	_field = field

## Play resolved events in order; returns when the last one finishes.
func play(events: Array[Dictionary]) -> void:
	for ev in events:
		match ev["kind"]:
			"move":
				await _play_move(ev)
			"melee":
				await _play_melee(ev)
			"shot":
				await _play_shot(ev)

# Walk the stack hex-by-hex along its route, striding steadily across the whole walk.
func _play_move(ev: Dictionary) -> void:
	var stack: CreatureStack = ev["stack"]
	var path: Array = ev["path"]
	var frames := _field.group_frames(stack.creature.id, BattleField.GROUP_MOVE)
	for i in range(1, path.size()):
		var from: Vector2 = _field.ground_of(path[i - 1])
		var to: Vector2 = _field.ground_of(path[i])
		var leg := i - 1
		await _animate(MOVE_HEX_TIME, func(t: float) -> void:
			var ov := {"pos": from.lerp(to, t)}
			if frames > 0:
				ov["group"] = BattleField.GROUP_MOVE
				ov["frame"] = int((leg + t) * STRIDE_FRAMES)   # field wraps it into the cycle
			_field.overrides[stack] = ov)
	_field.overrides.erase(stack)

# A melee strike: the attacker swings (up/front/down by the target's row), then the impact lands.
func _play_melee(ev: Dictionary) -> void:
	var attacker: CreatureStack = ev["attacker"]
	var group := _directional(attacker, ev["defender"],
			BattleField.GROUP_ATTACK_UP, BattleField.GROUP_ATTACK, BattleField.GROUP_ATTACK_DOWN)
	await _play_pose(attacker, group, SWING_TIME)
	_field.overrides.erase(attacker)
	await _impact(ev)

# A shot: release animation, tracer flies to the target, then the impact lands.
func _play_shot(ev: Dictionary) -> void:
	var attacker: CreatureStack = ev["attacker"]
	var defender: CreatureStack = ev["defender"]
	var group := _directional(attacker, defender,
			BattleField.GROUP_SHOOT_UP, BattleField.GROUP_SHOOT, BattleField.GROUP_SHOOT_DOWN)
	await _play_pose(attacker, group, SWING_TIME)
	_field.overrides.erase(attacker)

	# The projectile leaves from chest height, not the feet.
	var lift := Vector2(0.0, -BattleField.HEX_SIZE)
	var from := _field.ground_of(attacker.hex) + lift
	var to := _field.ground_of(defender.hex) + lift
	await _animate(TRACER_TIME, func(t: float) -> void:
		_field.tracer = {"from": from, "to": to, "t": t})
	_field.tracer = {}
	await _impact(ev)

# The moment damage lands: the number floats up, and the defender flinches — or dies and fades.
func _impact(ev: Dictionary) -> void:
	var defender: CreatureStack = ev["defender"]
	_field.add_floater("-%d" % int(ev["damage"]), _field.ground_of(defender.hex) + Vector2(0.0, -BattleField.HEX_SIZE * 1.6))
	if ev["died"]:
		var frames := _field.group_frames(defender.creature.id, BattleField.GROUP_DEATH)
		await _play_pose(defender, BattleField.GROUP_DEATH, REACT_TIME)
		# Fade the fallen stack out on its death animation's final frame.
		await _animate(FADE_TIME, func(t: float) -> void:
			_field.overrides[defender] = {"group": BattleField.GROUP_DEATH,
					"frame": maxi(frames - 1, 0), "alpha": 1.0 - t})
	else:
		await _play_pose(defender, BattleField.GROUP_HIT, REACT_TIME)
	_field.overrides.erase(defender)

# Run one animation group over `duration`, first to last frame, holding the pose in overrides.
# Creatures without that group (or token fallback mode) just hold a beat, so pacing never skips.
func _play_pose(stack: CreatureStack, group: int, duration: float) -> void:
	var frames := _field.group_frames(stack.creature.id, group)
	if frames <= 0:
		await _animate(duration * 0.6, func(_t: float) -> void: pass)
		return
	await _animate(duration, func(t: float) -> void:
		_field.overrides[stack] = {"group": group, "frame": mini(int(t * frames), frames - 1)})

# Pick the up/front/down variant of a swing by the defender's row relative to the attacker
# (mirroring for the enemy side is the field's job; up stays up).
func _directional(attacker: CreatureStack, defender: CreatureStack, up: int, front: int, down: int) -> int:
	var dy := defender.hex.y - attacker.hex.y
	if dy < 0:
		return up
	if dy > 0:
		return down
	return front

# Drive `apply` with progress 0 -> 1 over `duration` seconds (linear), and await completion.
func _animate(duration: float, apply: Callable) -> void:
	var tween := create_tween()
	tween.tween_method(apply, 0.0, 1.0, duration)
	await tween.finished
