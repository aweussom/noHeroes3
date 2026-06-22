class_name BattleAI
extends RefCounted
## Deterministic opponent AI — heuristic now, minimax later if needed.
## No LLM, no network. Uses GameState.rng so behaviour is reproducible during review.

func choose_action(state: Dictionary) -> Dictionary:
	# TODO(M4): score legal actions, pick the best deterministically.
	return {}
