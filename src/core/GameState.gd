extends Node
## Global game state: whose turn it is, the deterministic RNG, scene transitions.
## Autoloaded as `GameState` (see project.godot). A coordinator — never renders.

signal turn_changed(player_index: int)

var rng := RandomNumberGenerator.new()
var current_player: int = 0
var map: MapModel = null
var map_source: String = ""   # res:// path `map` was loaded from, so a save can reload it
var fog: FogModel = null   # fog-of-war state for `map`; rendered by FogView
var heroes: Array = []   # all heroes in play (just the player's, for now)

func _ready() -> void:
	# Deterministic by default so AI/combat are reproducible while developing.
	# TODO(later): seed from the loaded save instead of a constant.
	rng.seed = 1999

func end_turn() -> void:
	# Refill every hero's movement for the new turn.
	# TODO(M4): advance to other players and run AI before returning to the player.
	for hero in heroes:
		hero.refill_movement()
	turn_changed.emit(current_player)
