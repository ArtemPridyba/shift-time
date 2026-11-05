class_name PlayerMotion
extends RefCounted
## Movement rules of the player: acceleration, friction, gravity, jump with
## coyote time and jump buffer. Pure rules, no nodes: testable headless.
##
## The player's time always runs forward, so nothing here knows about the
## direction of world time (see docs/architecture.md, sections 1 and 2).

var _params: Dictionary
var _coyote_left := 0.0
var _buffer_left := 0.0


func _init(params: Dictionary) -> void:
	_params = params


## Returns the new velocity for one physics tick.
## `axis` is -1..1 (left..right), `jump_pressed` is true on the tick of the press.
func step(
	velocity: Vector2, axis: float, jump_pressed: bool, on_floor: bool, delta: float
) -> Vector2:
	var v := velocity

	# Horizontal: accelerate towards the target speed, or slow down by friction.
	if axis != 0.0:
		v.x = move_toward(v.x, axis * float(_params["walk_speed"]), float(_params["acceleration"]) * delta)
	else:
		v.x = move_toward(v.x, 0.0, float(_params["friction"]) * delta)

	# Timers: coyote time after leaving the floor, buffer before landing.
	if on_floor:
		_coyote_left = float(_params["coyote_seconds"])
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
	if jump_pressed:
		_buffer_left = float(_params["jump_buffer_seconds"])
	else:
		_buffer_left = maxf(0.0, _buffer_left - delta)

	# Vertical: gravity in the air, rest on the floor.
	if on_floor:
		v.y = minf(v.y, 0.0)
	else:
		v.y = minf(v.y + float(_params["gravity"]) * delta, float(_params["max_fall_speed"]))

	# Jump.
	if _buffer_left > 0.0 and _coyote_left > 0.0:
		v.y = -float(_params["jump_velocity"])
		_buffer_left = 0.0
		_coyote_left = 0.0

	return v


func reset() -> void:
	_coyote_left = 0.0
	_buffer_left = 0.0
