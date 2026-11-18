class_name RewindSpeed
extends RefCounted
## How many frames of history the world goes back on one tick while Shift is
## held (decision D62). The first `delay` seconds of a hold rewind at 1x, so
## the player can stop on the exact moment; then the speed grows evenly to
## `max_speed` over `ramp` seconds. Releasing Shift starts the next hold at 1x
## again. A fractional speed is kept between ticks, so 1.5x is 1, 2, 1, 2 ...
## frames and the motion stays even.

var max_speed := 1.0
var delay_ticks := 0
var ramp_ticks := 1

var _held_ticks := 0
var _carry := 0.0
## The speed of the last rewound tick, 1.0 while time runs forward.
var speed := 1.0


static func from_config(time_data: Dictionary) -> RewindSpeed:
	var result := RewindSpeed.new()
	var per_second := float(time_data.get("physics_ticks_per_second", 60))
	result.max_speed = maxf(float(time_data.get("rewind_speed_max", 1.0)), 1.0)
	result.delay_ticks = maxi(int(round(float(time_data.get("rewind_ramp_delay_seconds", 0.0)) * per_second)), 0)
	result.ramp_ticks = maxi(int(round(float(time_data.get("rewind_ramp_seconds", 0.0)) * per_second)), 1)
	return result


## Frames to go back on this tick: 0 while time runs forward (and the hold is
## forgotten), at least 1 while rewinding.
func frames_for(direction: int) -> int:
	if direction >= 0:
		reset()
		return 0
	_held_ticks += 1
	var t := clampf(float(_held_ticks - delay_ticks) / float(ramp_ticks), 0.0, 1.0)
	speed = lerpf(1.0, max_speed, t)
	_carry += speed
	var frames := maxi(int(floor(_carry)), 1)
	_carry -= float(frames)
	return frames


func reset() -> void:
	_held_ticks = 0
	_carry = 0.0
	speed = 1.0
