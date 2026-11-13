class_name PlayerMotion
extends RefCounted
## Movement rules of the player: acceleration, friction, gravity, jump with
## coyote time and jump buffer, and in water: the player walks slower, sinks
## slowly and jumps lower from the bottom, but rising water carries the player
## up on its surface (the world moves the player). There is no swimming: a
## player under water who cannot get out runs out of breath (`Breath`).
## Pure rules, no nodes: testable headless.
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
## `water` is the player's contact with water (`water_contact`), empty on land.
func step(
	velocity: Vector2, axis: float, jump_pressed: bool, on_floor: bool, delta: float,
	water: Dictionary = {}
) -> Vector2:
	var v := velocity
	var depth := float(water.get("depth", 0.0))
	var in_water := depth > 0.0
	# Rising water carries the player on its surface, like a platform.
	var carried := in_water and float(water.get("rise", 0.0)) > 0.0
	var walk := float(_params["walk_speed"])
	if in_water:
		walk *= float(_params["water_walk_factor"])

	# Horizontal: accelerate towards the target speed, or slow down by friction.
	if axis != 0.0:
		v.x = move_toward(v.x, axis * walk, float(_params["acceleration"]) * delta)
	else:
		v.x = move_toward(v.x, 0.0, float(_params["friction"]) * delta)

	# Timers: coyote time after leaving the floor, buffer before landing.
	if on_floor or carried:
		_coyote_left = float(_params["coyote_seconds"])
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
	if jump_pressed:
		_buffer_left = float(_params["jump_buffer_seconds"])
	else:
		_buffer_left = maxf(0.0, _buffer_left - delta)

	# Vertical: gravity in the air, rest on the floor; in water the surface
	# lifts the player while it rises, otherwise the player sinks slowly.
	if carried:
		v.y = minf(v.y, -minf(depth / delta, float(_params["water_float_up_speed"])))
	elif on_floor:
		v.y = minf(v.y, 0.0)
	elif in_water:
		var sink := float(_params["water_max_sink_speed"])
		if v.y > sink:
			v.y = move_toward(v.y, sink, float(_params["water_drag"]) * delta)
		else:
			v.y = minf(v.y + float(_params["water_gravity"]) * delta, sink)
	else:
		v.y = minf(v.y + float(_params["gravity"]) * delta, float(_params["max_fall_speed"]))

	# Jump: from the floor, from the surface of rising water, lower from the
	# bottom of a tank.
	if _buffer_left > 0.0 and _coyote_left > 0.0:
		var in_deep := in_water and not carried
		v.y = -float(_params["water_jump_velocity" if in_deep else "jump_velocity"])
		_buffer_left = 0.0
		_coyote_left = 0.0

	return v


func reset() -> void:
	_coyote_left = 0.0
	_buffer_left = 0.0


## How the player's body (global rect, feet at the bottom) meets one tank:
## `depth` is how far the feet are below the surface (0 when out of the water),
## `rise` the surface's speed upwards in px/s, `head_under` is true when the
## surface is above the middle of the head (the top `head_px` of the body).
static func water_contact(body: Rect2, tank: Rect2, surface_y: float, rise: float, head_px: float) -> Dictionary:
	var centre := body.get_center().x
	var inside := centre >= tank.position.x and centre <= tank.end.x \
			and body.end.y > surface_y and body.position.y < tank.end.y
	if not inside:
		return {"depth": 0.0, "rise": 0.0, "head_under": false}
	var depth := minf(body.end.y, tank.end.y) - surface_y
	return {
		"depth": maxf(depth, 0.0),
		"rise": rise,
		"head_under": surface_y < body.position.y + head_px / 2.0,
	}
