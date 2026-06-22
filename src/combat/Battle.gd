class_name Battle
extends Node2D
## The hex-grid battle scene. Turn-based, no timers — fully pausable, like the rest
## of the game (she can stop mid-turn the moment she's drowsy). Returns a result.

signal battle_finished(result: Dictionary)

func start(attacker: Array, defender: Array) -> void:
	# TODO(M4): build hex grid, place stacks, run the turn loop.
	pass
