class_name BattleModel
extends RefCounted
## The battlefield: a HoMM3-sized hex grid (15 wide x 11 tall) and the two armies on it.
## Pure logic / data — no rendering (BattleView draws it) and no turn or attack rules yet
## (those arrive in M4.2/M4.3). Hex coordinates are offset coords: (col, row), odd rows shifted
## half a hex right, which BattleView turns into pixels.

const COLS := 15
const ROWS := 11

var stacks: Array[CreatureStack] = []

## Build a battle from two armies, each an Array of { "creature": Creature, "count": int }.
## Player deploys down the left column, enemy down the right — HoMM3's starting layout.
func _init(player_army: Array, enemy_army: Array) -> void:
	_deploy(player_army, 0, 0)
	_deploy(enemy_army, 1, COLS - 1)

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
