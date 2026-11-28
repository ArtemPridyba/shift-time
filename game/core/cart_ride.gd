class_name CartRide
extends RefCounted
## The ride of the minecart of level 04 (card docs/levels/04.md, D168). The
## cart is out of time, like the heroine: it is never recorded and Shift never
## turns it back; it runs on the player's own clock. While Shift is held it
## rolls on at the same speed while the switches, plates and shutters around it
## show the past. This class keeps only where the cart is and what it does;
## `Minecart` draws it and carries the heroine.
##
## The ride: parked at the top of the ramp, held by a stopper. The heroine
## lands on its platform (`board`): the stopper drops after `launch_seconds`
## and the cart rolls, speeding up to `speed_px`. At a switch it takes the main
## or the side segment by the switch's blade at that tick (`step` asks). At a
## dead end it hits the buffer and bounces back `bounce_px` while it shakes
## for `bump_seconds`; then the hoist hooks it and takes it up to `hoist_y`,
## along under the walkway and up the shaft back to the park, with the heroine.
## At the station it brakes to a stop and lets her off.
##
## The intro ride may start on the hoist (`drop_from_hoist`): from the park
## along the hoist to a point of the rails, where the hook lets it go.
##
## Numbers: `minecart` in data/objects.json.

enum Mode { PARKED, LAUNCHING, ROLLING, BUMPED, HOISTED, STOPPED }

var track: RailTrack
var segment := ""
var distance := 0.0
## Pixels a second along the rails; 0 while parked or stopped.
var speed := 0.0
var mode := Mode.PARKED

var _params := {}
var _park_segment := ""
var _hoist_y := 0.0
var _timer := 0.0
var _bump_at := 0.0
var _route := PackedVector2Array()
var _route_marks := PackedFloat32Array()
var _route_d := 0.0
var _last_move := Vector2.LEFT
## Where the hoist lets the cart down onto the rails; "" to the park.
var _drop_segment := ""
var _drop_distance := 0.0


func _init(rails: RailTrack, params: Dictionary, park_segment: String, hoist_y: float) -> void:
	track = rails
	_params = params
	_park_segment = park_segment
	_hoist_y = hoist_y
	park()


## Back at the top of the ramp, held by the stopper.
func park() -> void:
	segment = _park_segment
	distance = 0.0
	speed = 0.0
	mode = Mode.PARKED
	_timer = 0.0
	_drop_segment = ""
	_route = PackedVector2Array()
	_last_move = track.direction_at(segment, 0.0) if track != null else Vector2.LEFT


## The heroine landed on the platform of the parked cart: the stopper drops
## and the ride begins. False if the cart is not parked.
func board() -> bool:
	if mode != Mode.PARKED:
		return false
	mode = Mode.LAUNCHING
	_timer = _number("launch_seconds")
	return true


## The intro ride from the hoist: from the park along the hoist and down onto
## `drop_segment` at `drop_distance`, where the hook lets it roll. False if
## the cart is not parked or the place is not on the rails.
func drop_from_hoist(drop_segment: String, drop_distance: float) -> bool:
	if mode != Mode.PARKED or not track.has(drop_segment):
		return false
	var park_at := track.point_at(_park_segment, 0.0)
	var drop_at := track.point_at(drop_segment, drop_distance)
	_set_route([park_at, Vector2(park_at.x, _hoist_y), Vector2(drop_at.x, _hoist_y), drop_at])
	_drop_segment = drop_segment
	_drop_distance = drop_distance
	speed = 0.0
	mode = Mode.HOISTED
	return true


## True where the heroine may get off: parked at the ramp or at the station.
func can_get_off() -> bool:
	return mode == Mode.PARKED or mode == Mode.STOPPED


## True while the stopper still holds the cart.
func is_held() -> bool:
	return mode == Mode.PARKED or mode == Mode.LAUNCHING


## How far the stopper has dropped, 0 up, 1 down (for the look).
func stopper_fraction() -> float:
	if mode == Mode.PARKED:
		return 0.0
	if mode == Mode.LAUNCHING:
		var total := _number("launch_seconds")
		return 1.0 - _timer / total if total > 0.0 else 1.0
	return 1.0


## True while the wheels are on the rails (they can press a plate).
func on_rails() -> bool:
	return mode != Mode.HOISTED


## One tick of the player's clock. `leads_main` answers for a switch id
## whether its blade leads to the main segment now.
func step(delta: float, leads_main: Callable) -> void:
	var before := position()
	match mode:
		Mode.LAUNCHING:
			_timer -= delta
			if _timer <= 0.0:
				mode = Mode.ROLLING
		Mode.ROLLING:
			_roll(delta, leads_main)
		Mode.BUMPED:
			_timer -= delta
			var total := _number("bump_seconds")
			var u := clampf(1.0 - _timer / total, 0.0, 1.0) if total > 0.0 else 1.0
			distance = maxf(_bump_at - _number("bounce_px") * (1.0 - (1.0 - u) * (1.0 - u)), 0.0)
			if _timer <= 0.0:
				_start_hoist()
		Mode.HOISTED:
			_route_d += _number("hoist_speed_px") * delta
			if _route_d >= _route_marks[_route_marks.size() - 1]:
				if _drop_segment != "":
					segment = _drop_segment
					distance = _drop_distance
					_drop_segment = ""
					speed = 0.0
					mode = Mode.ROLLING
				else:
					park()
	var moved := position() - before
	if moved.length() > 0.01:
		_last_move = moved.normalized()


## Where the cart stands now, in room pixels: the point on the rails under its
## middle, or on the hoist.
func position() -> Vector2:
	if mode == Mode.HOISTED:
		return _route_point(_route_d)
	return track.point_at(segment, distance)


## Which way the front of the cart faces: along the rails, level on the hoist.
func facing() -> Vector2:
	if mode == Mode.HOISTED:
		return Vector2.LEFT
	return track.direction_at(segment, distance)


## Which way the cart last moved (the camera looks ahead along it).
func motion() -> Vector2:
	return _last_move


## How hard the cart shakes after hitting a buffer, in pixels; 0 otherwise.
func shake_px() -> float:
	if mode != Mode.BUMPED:
		return 0.0
	var total := _number("bump_seconds")
	return _number("shake_px") * clampf(_timer / total, 0.0, 1.0) if total > 0.0 else 0.0


## The stop the cart came to rest at: "" while it rolls.
func stop_kind() -> String:
	if mode == Mode.BUMPED:
		return RailTrack.STOP_DEAD_END
	if mode == Mode.STOPPED:
		return RailTrack.STOP_STATION
	return ""


func _roll(delta: float, leads_main: Callable) -> void:
	speed = move_toward(speed, _number("speed_px"), _number("accel_px") * delta)
	var end := track.end_of(segment)
	if str(end.get("kind", "")) == RailTrack.END_STOP and str(end.get("stop", "")) == RailTrack.STOP_STATION:
		# Brakes so that it comes to rest at the buffer of the station.
		var left := track.length(segment) - distance
		speed = minf(speed, maxf(sqrt(2.0 * _number("brake_px") * maxf(left, 0.0)), _number("creep_px")))
	distance += speed * delta
	while distance >= track.length(segment):
		end = track.end_of(segment)
		var kind := str(end.get("kind", ""))
		if kind == RailTrack.END_NEXT:
			distance -= track.length(segment)
			segment = str(end["to"])
		elif kind == RailTrack.END_SWITCH:
			distance -= track.length(segment)
			var main := bool(leads_main.call(str(end["switch"]))) if leads_main.is_valid() else true
			segment = str(end["main"] if main else end["side"])
		else:
			distance = track.length(segment)
			speed = 0.0
			if str(end.get("stop", "")) == RailTrack.STOP_DEAD_END:
				_bump()
			else:
				mode = Mode.STOPPED
			break


## It hit a buffer: it bounces back from here and shakes.
func _bump() -> void:
	speed = 0.0
	mode = Mode.BUMPED
	_timer = _number("bump_seconds")
	_bump_at = distance


## Up from where the cart rests to the hoist line, along it to the park, and
## up the shaft onto the ramp.
func _start_hoist() -> void:
	var from := track.point_at(segment, distance)
	var park_at := track.point_at(_park_segment, 0.0)
	_set_route([from, Vector2(from.x, _hoist_y), Vector2(park_at.x, _hoist_y), park_at])
	_drop_segment = ""
	speed = 0.0
	mode = Mode.HOISTED


func _set_route(points: Array) -> void:
	_route = PackedVector2Array(points)
	_route_marks = PackedFloat32Array([0.0])
	for i in range(1, _route.size()):
		_route_marks.append(_route_marks[i - 1] + _route[i - 1].distance_to(_route[i]))
	_route_d = 0.0


func _route_point(d: float) -> Vector2:
	for i in range(_route.size() - 1):
		if d <= _route_marks[i + 1] or i == _route.size() - 2:
			var span := _route_marks[i + 1] - _route_marks[i]
			var t := clampf((d - _route_marks[i]) / span, 0.0, 1.0) if span > 0.0 else 1.0
			return _route[i].lerp(_route[i + 1], t)
	return _route[0] if _route.size() > 0 else Vector2.ZERO


func _number(key: String) -> float:
	var value: Variant = _params.get(key, 0.0)
	return float(value) if value is float or value is int else 0.0
