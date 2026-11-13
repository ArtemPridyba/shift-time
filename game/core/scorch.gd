class_name Scorch
extends RefCounted
## The player's heat in fire (task 2.7): it grows while the player stands in a
## burning zone and the player burns after `fire_seconds` (player.json). Out of
## the fire it cools back down in `fire_cool_seconds`, so stepping in and out
## does not cheat the rule. The player is live: the heat follows the player's
## own time and Shift never rewinds it. Pure rules, no nodes.

## Seconds in fire until the player burns.
var full_seconds := 3.0
## Seconds from the brink back to cool.
var cool_seconds := 1.5
## Seconds of fire taken so far.
var heat := 0.0


func _init(params: Dictionary) -> void:
	full_seconds = maxf(float(params.get("fire_seconds", 3)), 0.01)
	cool_seconds = maxf(float(params.get("fire_cool_seconds", 1.5)), 0.01)


## One tick. Returns true on the tick the player burns.
func step(in_fire: bool, delta: float) -> bool:
	if in_fire:
		var before := heat
		heat = minf(heat + delta, full_seconds)
		return before < full_seconds and heat >= full_seconds
	heat = maxf(heat - delta * full_seconds / cool_seconds, 0.0)
	return false


## 0 when cool, 1 when burnt.
func fraction() -> float:
	return heat / full_seconds


func reset() -> void:
	heat = 0.0
