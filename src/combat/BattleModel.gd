class_name BattleModel
extends RefCounted
## The battlefield: a HoMM3-sized hex grid (15 wide x 11 tall) and the two armies on it.
## Pure logic / data — no rendering (BattleView draws it) and no turn or attack rules yet
## (those arrive in M4.2/M4.3). Hex coordinates are offset coords: (col, row), odd rows shifted
## half a hex right, which BattleView turns into pixels.

const COLS := 15
const ROWS := 11

var stacks: Array[CreatureStack] = []

# Turn order within a round: living stacks fastest-first, recomputed each round. _turn_index points
# at the stack currently acting.
var turn_order: Array[CreatureStack] = []
var _turn_index := 0

# Damage RNG, injected so battles stay reproducible (the game passes GameState.rng) and this pure
# class never reaches into an autoload — keeps it unit-testable in isolation.
var _rng: RandomNumberGenerator

## Build a battle from two armies, each an Array of { "creature": Creature, "count": int }.
## Player deploys down the left column, enemy down the right — HoMM3's starting layout.
func _init(player_army: Array, enemy_army: Array, rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_deploy(player_army, 0, 0)
	_deploy(enemy_army, 1, COLS - 1)
	_start_round()

func _deploy(army: Array, side: int, col: int) -> void:
	var start_row := (ROWS - army.size()) / 2   # vertically centred column of stacks
	for i in army.size():
		var unit: Dictionary = army[i]
		stacks.append(CreatureStack.new(unit["creature"], int(unit["count"]), side, Vector2i(col, start_row + i)))

func in_bounds(hex: Vector2i) -> bool:
	return hex.x >= 0 and hex.x < COLS and hex.y >= 0 and hex.y < ROWS

## The living stack on a hex, or null if it's empty.
func stack_at(hex: Vector2i) -> CreatureStack:
	for stack in stacks:
		if stack.is_alive() and stack.hex == hex:
			return stack
	return null

## Living stacks for a side (0 player, 1 enemy).
func living(side: int) -> Array[CreatureStack]:
	return stacks.filter(func(s: CreatureStack) -> bool: return s.is_alive() and s.side == side)

# --- Turn order ---

# Rebuild the round's order: fastest first, ties broken deterministically (player before enemy,
# then top-to-bottom) so the seeded game stays reproducible.
func _start_round() -> void:
	for s in stacks:
		s.retaliated = false
	turn_order = stacks.filter(func(s: CreatureStack) -> bool: return s.is_alive())
	turn_order.sort_custom(func(a: CreatureStack, b: CreatureStack) -> bool:
		if a.creature.speed != b.creature.speed:
			return a.creature.speed > b.creature.speed
		if a.side != b.side:
			return a.side < b.side
		return a.hex.y < b.hex.y)
	_turn_index = 0

## The stack whose turn it is (null only if a side has been wiped — battle is over).
func active_stack() -> CreatureStack:
	if _turn_index < turn_order.size() and turn_order[_turn_index].is_alive():
		return turn_order[_turn_index]
	return null

## End the active stack's turn: step to the next living stack, starting a fresh round at the end.
func advance_turn() -> void:
	_turn_index += 1
	while _turn_index < turn_order.size() and not turn_order[_turn_index].is_alive():
		_turn_index += 1
	if _turn_index >= turn_order.size():
		_start_round()

# --- Hex geometry ---

## The six neighbours of a hex in odd-r offset coords (odd rows shifted right), in-bounds only.
func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var deltas: Array
	if hex.y & 1:
		deltas = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	else:
		deltas = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	var out: Array[Vector2i] = []
	for d in deltas:
		var n: Vector2i = hex + d
		if in_bounds(n):
			out.append(n)
	return out

## Empty hexes a stack can reach this turn: a BFS out to its Speed in steps, blocked by any stack.
func reachable_hexes(stack: CreatureStack) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dist := {stack.hex: 0}
	var queue: Array[Vector2i] = [stack.hex]
	while not queue.is_empty():
		var hex: Vector2i = queue.pop_front()
		if dist[hex] >= stack.creature.speed:
			continue
		for n in neighbors(hex):
			if dist.has(n) or stack_at(n) != null:
				continue
			dist[n] = dist[hex] + 1
			result.append(n)
			queue.append(n)
	return result

# --- Attacks ---

## Is any enemy stack on a hex adjacent to this one? (A ranged stack in melee can't shoot.)
func has_adjacent_enemy(stack: CreatureStack) -> bool:
	for n in neighbors(stack.hex):
		var other := stack_at(n)
		if other != null and other.side != stack.side:
			return true
	return false

## Resolve `attacker` hitting `defender`: roll damage (HoMM3 formula, seeded RNG so battles are
## reproducible), apply casualties, and return the damage dealt. Retaliation is the caller's job.
func deal_damage(attacker: CreatureStack, defender: CreatureStack) -> int:
	var base := 0
	for _i in attacker.count:
		base += _rng.randi_range(attacker.creature.min_damage, attacker.creature.max_damage)

	# +5% per attack point over defense (cap +300%); -2.5% per defense point over attack (cap -70%).
	var diff := attacker.creature.attack - defender.creature.defense
	var mult: float = 1.0 + 0.05 * min(diff, 60) if diff >= 0 else 1.0 - 0.025 * min(-diff, 28)

	var damage := int(round(base * mult))
	_apply_casualties(defender, damage)
	return damage

# Subtract damage from a stack's total HP, killing whole creatures off the top and leaving the
# front creature partially wounded (top_hp).
func _apply_casualties(stack: CreatureStack, damage: int) -> void:
	var total := (stack.count - 1) * stack.creature.hp + stack.top_hp - damage
	if total <= 0:
		stack.count = 0
		stack.top_hp = 0
	else:
		stack.count = int(ceil(float(total) / stack.creature.hp))
		stack.top_hp = total - (stack.count - 1) * stack.creature.hp
