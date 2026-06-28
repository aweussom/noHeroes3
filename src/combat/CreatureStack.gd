class_name CreatureStack
extends RefCounted
## One stack of identical creatures on the battlefield — the unit the player moves and fights with.
## A stack of N creatures has N*hp total; damage kills whole creatures off the top, and `top_hp`
## tracks the partially-wounded front creature so damage carries over between hits.

var creature: Creature
var count: int
var side: int          # 0 = player (left), 1 = enemy (right)
var hex: Vector2i      # (col, row) on the battle grid

var top_hp: int        # remaining HP of the front creature
var shots_left: int    # ranged ammo remaining (depletes per shot; persists across rounds)
var retaliated: bool   # already struck back this round? (reset each round)

func _init(p_creature: Creature, p_count: int, p_side: int, p_hex: Vector2i) -> void:
	creature = p_creature
	count = p_count
	side = p_side
	hex = p_hex
	top_hp = p_creature.hp
	shots_left = p_creature.shots

func is_alive() -> bool:
	return count > 0

func is_ranged() -> bool:
	return creature.shots > 0
