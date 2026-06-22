class_name CameraRig
extends Camera2D
## Touch-first camera: drag to pan, pinch to zoom. Mouse wheel/drag mirror it for
## desktop testing. Tuned for sleepy one-handed play — gentle, no snapping.

@export var min_zoom := 0.5
@export var max_zoom := 2.0

# TODO(M1): pan/zoom driven by TouchInput gestures; clamp to map bounds.
