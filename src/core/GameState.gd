extends Node
## Global game state: whose turn it is, the deterministic RNG, scene transitions.
## Autoloaded as `GameState` (see project.godot). A coordinator — never renders.

signal turn_changed(player_index: int)

var rng := RandomNumberGenerator.new()
var current_player: int = 0
var map: MapModel = null

func _ready() -> void:
	# Deterministic by default so AI/combat are reproducible while developing.
	# TODO(later): seed from the loaded save instead of a constant.
	rng.seed = 1999

func end_turn() -> void:
	# TODO(M2): advance turn, refill hero movement, run AI players.
	turn_changed.emit(current_player)
