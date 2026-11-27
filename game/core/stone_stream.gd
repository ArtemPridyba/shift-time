class_name StoneStream
extends RefCounted
## The stream of pig iron out of the hopper of level 04 (card docs/levels/04.md,
## D168): pure arithmetic, no nodes. A pour is counted in world ticks since the
## hopper opened (`pour`); stone i leaves the gate at
## `delay + i * gap` ticks and falls faster and faster until it is `fall_px`
## below the gate (the bottom of the pit), where it is gone. Everything is a
## function of `pour`, so the stream rewinds and replays with its hopper and
## never needs a history of its own.
##
## Numbers: `hopper` in data/objects.json, seconds of the world clock (D96).

var count := 12
var delay_ticks := 0
var gap_ticks := 1.0
## Pixels a tick squared.
var gravity := 1.0
var fall_px := 480.0
var spread_px := 48.0


static func from_data(hopper: Dictionary, time_data: Dictionary, fall: float) -> StoneStream:
	var stream := StoneStream.new()
	var ticks := Content.world_ticks_per_second(time_data)
	stream.count = maxi(int(hopper.get("count", 12)), 1)
	stream.delay_ticks = int(round(float(hopper.get("delay_seconds", 0.0)) * ticks))
	var pour := float(hopper.get("pour_seconds", 3.0)) * ticks
	stream.gap_ticks = pour / float(maxi(stream.count - 1, 1))
	stream.gravity = float(hopper.get("gravity_px", 1800.0)) / (ticks * ticks)
	stream.spread_px = float(hopper.get("spread_px", 48.0))
	stream.fall_px = fall
	return stream


## The tick of the pour at which stone i leaves the gate.
func release_tick(i: int) -> float:
	return float(delay_ticks) + gap_ticks * float(i)


## Ticks a stone takes from the gate to the bottom.
func fall_ticks() -> float:
	return sqrt(2.0 * fall_px / gravity) if gravity > 0.0 else 0.0


## The pour tick after which every stone is gone.
func end_tick() -> int:
	return int(ceil(release_tick(count - 1) + fall_ticks())) + 1


## True while stone i is between the gate and the bottom at this pour tick
## (-1: the hopper never opened).
func in_air(i: int, pour: int) -> bool:
	if pour < 0:
		return false
	var t := float(pour) - release_tick(i)
	return t >= 0.0 and 0.5 * gravity * t * t < fall_px


## True while stone i still waits in the hopper.
func waiting(i: int, pour: int) -> bool:
	return pour < 0 or float(pour) < release_tick(i)


## Where stone i is, from the middle of the gate, in pixels.
func offset(i: int, pour: int) -> Vector2:
	var t := maxf(float(pour) - release_tick(i), 0.0)
	return Vector2(_lane(i), 0.5 * gravity * t * t)


## The stones across the gate: a fixed shuffle, never random.
func _lane(i: int) -> float:
	if count < 2:
		return 0.0
	var slot := float((i * 5) % count) / float(count - 1)
	return (slot - 0.5) * spread_px
