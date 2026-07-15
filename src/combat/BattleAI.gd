class_name BattleAI
extends RefCounted
## The deterministic opponent (M4.4). Heuristic, not minimax — plenty for map monsters, and every
## choice is rule-based with deterministic tie-breaks, so a seeded battle always replays the same
## way (the only randomness is the damage roll inside BattleModel, on the injected RNG).
##
## Pure logic: acts on a BattleModel, never touches rendering. Side-agnostic (targets whatever the
## acting stack's enemy side is), so it can also drive a "player" army in headless tests.
##
## Priorities each turn, HoMM3-monster-ish and simple enough to audit:
##   1. Shoot the biggest threat, if clear to shoot.
##   2. Strike the biggest threat already adjacent (this is also the pinned-shooter case).
##   3. Charge: move next to the biggest threat we can reach this turn, and strike it.
##   4. Otherwise advance toward the nearest enemy as far as movement allows.
## "Biggest threat" = the enemy stack with the highest expected damage output (average roll x
## count) — neutralize what hurts most first.

## Play out the acting stack's whole turn on the model (move and/or attack, or pass if boxed in).
## The caller advances the turn afterwards.
func take_turn(model: BattleModel, stack: CreatureStack) -> void:
	var enemies := model.living(1 - stack.side)
	if enemies.is_empty():
		return   # battle is over; nothing to do

	# 1. Clear shot: pick off the biggest threat from range.
	if model.can_shoot(stack):
		model.shoot(stack, _biggest_threat(enemies))
		return

	# 2. Already in melee: strike the biggest adjacent threat.
	var adjacent := enemies.filter(
		func(e: CreatureStack) -> bool: return model.neighbors(stack.hex).has(e.hex))
	if not adjacent.is_empty():
		model.melee(stack, _biggest_threat(adjacent))
		return

	# 3. Charge: of the enemies with a free reachable hex beside them, go for the biggest threat.
	var reachable := model.reachable_hexes(stack)
	var in_range := enemies.filter(
		func(e: CreatureStack) -> bool: return _charge_hex(model, reachable, e, stack.hex).x >= 0)
	if not in_range.is_empty():
		var target := _biggest_threat(in_range)
		stack.hex = _charge_hex(model, reachable, target, stack.hex)
		model.melee(stack, target)
		return

	# 4. Nobody reachable: advance toward the nearest enemy. (Boxed in entirely -> pass.)
	var advance := _step_toward_enemies(model, reachable, enemies)
	if advance.x >= 0:
		stack.hex = advance

# The enemy stack expected to deal the most damage per attack; ties go to the topmost-then-leftmost
# hex so the choice is deterministic.
func _biggest_threat(stacks: Array) -> CreatureStack:
	var best: CreatureStack = null
	for s: CreatureStack in stacks:
		if best == null or _threat(s) > _threat(best) \
				or (_threat(s) == _threat(best) and (s.hex.y < best.hex.y
					or (s.hex.y == best.hex.y and s.hex.x < best.hex.x))):
			best = s
	return best

# Expected damage output: average damage roll times creatures in the stack.
func _threat(stack: CreatureStack) -> float:
	return (stack.creature.min_damage + stack.creature.max_damage) * 0.5 * stack.count

# The reachable hex adjacent to `target` that's the shortest charge from `from`, or (-1, -1) if
# none. First-wins on ties (neighbors() order is fixed), keeping the charge deterministic.
func _charge_hex(model: BattleModel, reachable: Array[Vector2i], target: CreatureStack, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 0
	for n in model.neighbors(target.hex):
		if not n in reachable:
			continue
		var d := model.hex_distance(from, n)
		if best.x < 0 or d < best_dist:
			best = n
			best_dist = d
	return best

# The reachable hex closest to any enemy, or (-1, -1) if the stack can't move at all. First-wins
# on ties; reachable_hexes() is BFS order, so nearer hexes are considered first — deterministic.
func _step_toward_enemies(model: BattleModel, reachable: Array[Vector2i], enemies: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 0
	for hex in reachable:
		var d := _distance_to_nearest(model, hex, enemies)
		if best.x < 0 or d < best_dist:
			best = hex
			best_dist = d
	return best

func _distance_to_nearest(model: BattleModel, hex: Vector2i, enemies: Array) -> int:
	var nearest := -1
	for e: CreatureStack in enemies:
		var d := model.hex_distance(hex, e.hex)
		if nearest < 0 or d < nearest:
			nearest = d
	return nearest
