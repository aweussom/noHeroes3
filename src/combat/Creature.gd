class_name Creature
extends RefCounted
## A creature type's combat stats (HoMM3 Shadow of Death values). Pure data — one shared instance
## per type, referenced by many CreatureStacks. Damage is a min..max range rolled at attack time.

var id: String
var display_name: String
var attack: int
var defense: int
var min_damage: int
var max_damage: int
var hp: int            # hit points per single creature
var speed: int         # hexes per turn + turn-order key
var shots: int         # ranged ammo; 0 means melee-only

func _init(p_id: String, p_name: String, att: int, def: int, dmin: int, dmax: int, php: int, spd: int, sh: int = 0) -> void:
	id = p_id
	display_name = p_name
	attack = att
	defense = def
	min_damage = dmin
	max_damage = dmax
	hp = php
	speed = spd
	shots = sh

# A small roster to fight with (real SoD stats): [name, att, def, dmgMin, dmgMax, hp, speed, shots].
const _PRESETS := {
	"pikeman":   ["Pikeman", 4, 5, 1, 3, 10, 4, 0],
	"archer":    ["Archer", 6, 3, 2, 3, 10, 4, 12],
	"griffin":   ["Griffin", 8, 8, 3, 6, 25, 6, 0],
	"swordsman": ["Swordsman", 10, 12, 6, 9, 35, 5, 0],
	"gnoll":     ["Gnoll", 3, 5, 2, 4, 6, 4, 0],
	"wolf":      ["Wolf Rider", 7, 5, 2, 4, 10, 6, 0],
	"orc":       ["Orc", 8, 4, 2, 5, 15, 4, 8],
}

static func make(id: String) -> Creature:
	var p: Array = _PRESETS[id]
	return Creature.new(id, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7])
