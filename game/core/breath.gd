class_name Breath
extends RefCounted
## The player's breath: a store of seconds that runs down while the head is
## under water and fills back up above it. Empty means drowned. The player is
## live, so the breath follows the player's own time and Shift never rewinds
## it; rewinding the water so the head comes out is what saves the player.
## Pure rules, no nodes.

## Seconds of air when full (`breath_seconds` in player.json).
var full_seconds := 5.0
## Seconds from empty to full above water (`breath_refill_seconds`).
var refill_seconds := 1.5
## Seconds of air left.
var left := 5.0


func _init(params: Dictionary) -> void:
	full_seconds = maxf(float(params.get("breath_seconds", 5)), 0.01)
	refill_seconds = maxf(float(params.get("breath_refill_seconds", 1.5)), 0.01)
	left = full_seconds


## One tick. Returns true on the tick the air runs out.
func step(head_under: bool, delta: float) -> bool:
	if head_under:
		var before := left
		left = maxf(left - delta, 0.0)
		return before > 0.0 and left <= 0.0
	left = minf(left + delta * full_seconds / refill_seconds, full_seconds)
	return false


## 1 when full, 0 when out of air.
func fraction() -> float:
	return left / full_seconds


func is_out() -> bool:
	return left <= 0.0


func reset() -> void:
	left = full_seconds
