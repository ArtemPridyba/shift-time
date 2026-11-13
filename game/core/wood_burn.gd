class_name WoodBurn
extends RefCounted
## The rules of a wood zone (task 2.7): whole → burning → burnt. Burning lasts
## `burn_seconds` (objects.json, `wood`) and counts only in `tick()`, which the
## zone calls in `simulate_tick` at the head of history: fire itself is never
## reversed, so a zone lit under Shift burns out only after Shift is released.
## Rewinding restores the recorded frames, so a burnt zone comes back through
## burning to whole. Water and the reverse flamethrower in normal time put the
## fire out: the zone is whole again and can be lit once more.
## Pure rules, no nodes.

enum Phase { WHOLE, BURNING, BURNT }

## What a tick did, for the look and the tests.
enum Event { NONE, BURNT_OUT, DOUSED }

var phase := Phase.WHOLE
## Ticks the zone has been burning.
var burn := 0
## Ticks from lit to burnt.
var burn_ticks := 180


func _init(wood_data: Dictionary = {}, time_data: Dictionary = {}) -> void:
	var per_second := float(time_data.get("physics_ticks_per_second", 60))
	burn_ticks = maxi(int(round(float(wood_data.get("burn_seconds", 3)) * per_second)), 1)


## One tick at the head. `wet` is true while water covers the zone.
func tick(wet: bool) -> Event:
	if phase != Phase.BURNING:
		return Event.NONE
	if wet:
		douse()
		return Event.DOUSED
	burn += 1
	if burn >= burn_ticks:
		phase = Phase.BURNT
		burn = burn_ticks
		return Event.BURNT_OUT
	return Event.NONE


## Sets a whole zone burning. Returns false when there is nothing to light.
func ignite() -> bool:
	if phase != Phase.WHOLE:
		return false
	phase = Phase.BURNING
	burn = 0
	return true


## Puts the fire out: the zone is whole again. Returns false when nothing burns.
func douse() -> bool:
	if phase != Phase.BURNING:
		return false
	phase = Phase.WHOLE
	burn = 0
	return true


## Solid while whole or burning: a burnt bridge is a gap, a burnt wall a passage.
func is_solid() -> bool:
	return phase != Phase.BURNT


func is_burning() -> bool:
	return phase == Phase.BURNING


## 0 when just lit, 1 when burnt out; the look chars the wood by it.
func charred() -> float:
	if phase == Phase.BURNT:
		return 1.0
	return float(burn) / float(burn_ticks) if phase == Phase.BURNING else 0.0
