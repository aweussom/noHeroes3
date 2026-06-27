class_name FogLayer
extends CanvasModulate
## The night ambient tone. A CanvasModulate tints the whole world canvas (terrain, hero, fog veil)
## toward a cool, dim night so the hero's warm Light2D pool reads as a glow by contrast — the
## dark, luminous-on-black mood the game is built around. The HUD is on its own CanvasLayer and is
## unaffected, so UI stays readable.
##
## The fog-of-war *mechanic* (what's hidden vs explored vs visible) lives in FogModel + FogView.
## The "glow" is additive-blend sprites + Light2D (renderer-agnostic, the same trick as ypilot),
## NOT WorldEnvironment glow, which the Compatibility renderer can't be relied on for on Android.

# A bright, faintly cool wash — NOT a dimmer. Explored terrain should stay nearly as readable as
# active sight, so this barely darkens; the dark mood comes from the hidden-fog expanse and the
# already-muted terrain colours. The hero's warm Light2D pool reads as a glow against the cool tint.
const NIGHT_TONE := Color(0.86, 0.89, 0.97)

func _ready() -> void:
	color = NIGHT_TONE
