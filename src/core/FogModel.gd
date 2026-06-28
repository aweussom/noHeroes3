class_name FogModel
extends RefCounted
## Fog-of-war state — pure data, one entry per map cell. Three states, ordered so that a
## higher value always wins when reveals overlap (see reveal_disc):
##   HIDDEN   (0) — never seen; the veil is near-opaque.
##   EXPLORED (1) — seen before, now out of sight; terrain is remembered under a thin veil.
##   VISIBLE  (2) — within a hero's sight this moment; no veil.
##
## The mechanic each move: demote_visible() drops last turn's VISIBLE to EXPLORED, then we
## reveal_disc() around where the hero walked (as EXPLORED) and its final cell (as VISIBLE).
## Rendering lives in FogView; this class never draws. Held by GameState so it travels in saves.

enum { HIDDEN, EXPLORED, VISIBLE }

var width: int
var height: int
var _state: PackedByteArray   # row-major, width*height; zero-filled => all HIDDEN

func _init(w: int, h: int) -> void:
	width = w
	height = h
	_state = PackedByteArray()
	_state.resize(w * h)

func state_at(x: int, y: int) -> int:
	return _state[y * width + x]

## Drop every currently-visible cell to explored. Call once before re-revealing for new positions.
func demote_visible() -> void:
	for i in _state.size():
		if _state[i] == VISIBLE:
			_state[i] = EXPLORED

## Raise every in-bounds cell within `radius` (rounded disc) of `center` to at least `min_state`.
## Never downgrades — so an EXPLORED sweep along a walk can't dim the VISIBLE disc laid after it.
func reveal_disc(center: Vector2i, radius: int, min_state: int) -> void:
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		var y := center.y + dy
		if y < 0 or y >= height:
			continue
		for dx in range(-radius, radius + 1):
			var x := center.x + dx
			if x < 0 or x >= width:
				continue
			if dx * dx + dy * dy > r2:
				continue
			var i := y * width + x
			if _state[i] < min_state:
				_state[i] = min_state

# --- Save/restore (see SaveGame) ---
# The per-cell state is a PackedByteArray; base64 keeps it compact and JSON-safe.

func to_dict() -> Dictionary:
	return {"w": width, "h": height, "state": Marshalls.raw_to_base64(_state)}

static func from_dict(d: Dictionary) -> FogModel:
	var fog := FogModel.new(int(d.get("w", 0)), int(d.get("h", 0)))
	var bytes := Marshalls.base64_to_raw(String(d.get("state", "")))
	if bytes.size() == fog._state.size():
		fog._state = bytes
	return fog
