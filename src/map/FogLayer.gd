class_name FogLayer
extends CanvasModulate
## Fog-of-war + the dark, luminous-on-black mood (won't light a dark bedroom).
## Built from CanvasModulate (global darkening) + Light2D reveal around heroes.
##
## IMPORTANT: the "glow" look comes from ADDITIVE-blend sprites/materials + Light2D
## (renderer-agnostic — the same trick as ypilot), NOT WorldEnvironment glow, which
## the Compatibility renderer doesn't reliably support on Android. See CLAUDE.md.

# TODO(M3): reveal explored tiles, dim the unexplored, soft light around heroes.
