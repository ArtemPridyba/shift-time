class_name WaterLook
extends RefCounted
## The look of a tank of water (task 2.3А): waves on the surface, drips from
## bodies that leave the water, the jet at the source, the turn of a valve.
## Decoration only: nothing here is recorded and nothing changes the world.
##
## Everything is a function of world time and of the recorded state (the level,
## the flow, where the bodies are), so the same world tick looks the same going
## forward and rewinding: under Shift drops fly back up onto the platform, waves
## run back into the point of contact and the jet runs back into its pipe.
##
## The only memory is a cache of marks: the world tick when a recorded body
## entered or left the water and when a drop fell. Marks are added only on
## ticks recorded at the head, so replay and rewind only show them; a branch
## drops the marks right of the new head. Waves made by live sources (the
## player) are aged by the player's own time, so they always spread outward.
##
## Pure rules: no nodes, no references to the game or the level. Tank
## coordinates: x = 0 in the middle, y = 0 at the bottom, up is negative.

const ENTER := 0
const EXIT := 1
const DROP := 2
## Seconds a drop may fall before it is dropped from the look.
const DROP_MAX_SECONDS := 2.0
## Seconds of marks kept behind the newest one: more than the room's history
## would never be shown again.
const KEEP_SECONDS := 30.0
const SPLASH_SECONDS := 0.5
const WAVE_RISE_SECONDS := 0.15

var ripple_px := 1.5
var ripple_length_px := 96.0
var wave_px := 5.0
var wave_length_px := 40.0
var wave_speed_px := 180.0
var wave_seconds := 1.6
var drip_seconds := 3.0
var drips_per_second := 5.0
var drip_gravity_px := 900.0
var streak_px := 14.0
var jet_drops := 16
var jet_cycles_per_second := 1.6
var splash_drops := 8
var outlet_inset_px := 64.0
var valve_turns_per_tank := 6.0

var _ticks := 60.0
## World marks: {"tick": int, "kind": ENTER | EXIT | DROP, "key": String, "x": float, "y": float}.
var _world: Array[Dictionary] = []
## Live waves: {"tick": int (the live clock), "x": float}.
var _live: Array[Dictionary] = []
## key -> bool: whether a body was in the water on the last observed head tick.
var _wet := {}
var _seen_tick := -100
var _live_wet := {}


func _init(look_data: Dictionary = {}, time_data: Dictionary = {}) -> void:
	configure(look_data, time_data)


func configure(look_data: Dictionary, time_data: Dictionary) -> void:
	_ticks = float(time_data.get("physics_ticks_per_second", 60))
	ripple_px = float(look_data.get("ripple_px", ripple_px))
	ripple_length_px = float(look_data.get("ripple_length_px", ripple_length_px))
	wave_px = float(look_data.get("wave_px", wave_px))
	wave_length_px = float(look_data.get("wave_length_px", wave_length_px))
	wave_speed_px = float(look_data.get("wave_speed_px", wave_speed_px))
	wave_seconds = float(look_data.get("wave_seconds", wave_seconds))
	drip_seconds = float(look_data.get("drip_seconds", drip_seconds))
	drips_per_second = float(look_data.get("drips_per_second", drips_per_second))
	drip_gravity_px = float(look_data.get("drip_gravity_px", drip_gravity_px))
	streak_px = float(look_data.get("streak_px", streak_px))
	jet_drops = int(look_data.get("jet_drops", jet_drops))
	jet_cycles_per_second = float(look_data.get("jet_cycles_per_second", jet_cycles_per_second))
	splash_drops = int(look_data.get("splash_drops", splash_drops))
	outlet_inset_px = float(look_data.get("outlet_inset_px", outlet_inset_px))
	valve_turns_per_tank = float(look_data.get("valve_turns_per_tank", valve_turns_per_tank))


# --- what happened: marks ----------------------------------------------------

## Called once per world tick with the recorded bodies near the tank:
## `bodies` is an Array of {"key": String, "rect": Rect2 in tank coordinates}.
## Only a tick recorded at the head adds marks; replay and rewind only show.
func observe(tick: int, recorded: bool, surface_y: float, half_width: float, bodies: Array) -> void:
	if not recorded:
		return
	_forget_after(tick - 1)
	var fresh := tick == _seen_tick + 1
	_seen_tick = tick
	var every := maxi(int(round(_ticks / maxf(drips_per_second, 0.001))), 1)
	for body: Dictionary in bodies:
		var key: String = body["key"]
		var rect: Rect2 = body["rect"]
		var wet := is_wet(rect, surface_y, half_width)
		if fresh and _wet.has(key) and bool(_wet[key]) != wet:
			_world.append({"tick": tick, "kind": ENTER if wet else EXIT, "key": key,
				"x": clampf(rect.get_center().x, -half_width, half_width), "y": 0.0})
		_wet[key] = wet
		if wet:
			continue
		var since := _since_exit(key, tick)
		if since > 0 and since <= int(round(drip_seconds * _ticks)) and since % every == 0:
			var x := rect.position.x + rect.size.x * _hash(float(tick) * 0.37 + float(key.hash() % 1000))
			_world.append({"tick": tick, "kind": DROP, "key": key, "x": x, "y": rect.end.y})
	_forget_before(tick - int(KEEP_SECONDS * _ticks))


## A live source (the player) at `live_tick` of its own clock: a wave where it
## enters or leaves the water. Never recorded, never undone by Shift.
func observe_live(live_tick: int, key: String, rect: Rect2, surface_y: float, half_width: float) -> void:
	var wet := is_wet(rect, surface_y, half_width)
	if _live_wet.has(key) and bool(_live_wet[key]) != wet:
		_live.append({"tick": live_tick, "x": clampf(rect.get_center().x, -half_width, half_width)})
	_live_wet[key] = wet
	var oldest := live_tick - int(ceil(wave_seconds * _ticks))
	_live = _live.filter(func(mark: Dictionary) -> bool: return int(mark["tick"]) >= oldest)


## A body is in the water when its bottom is under the surface inside the tank.
static func is_wet(rect: Rect2, surface_y: float, half_width: float) -> bool:
	return rect.end.y > surface_y + 0.5 and rect.position.y < 0.0 \
		and rect.end.x > -half_width and rect.position.x < half_width


func mark_count() -> int:
	return _world.size()


# --- what it looks like at a world tick -----------------------------------------

## How far the surface is moved at `x` (down is positive) at world tick `tick`,
## with live waves at `live_tick` of the player's clock.
## Pass a negative `live_tick` to leave the live waves out.
func surface_offset(x: float, tick: float, live_tick: float) -> float:
	var t := tick / _ticks
	var offset := ripple_px * sin(TAU * x / ripple_length_px + t * 1.7) \
		+ ripple_px * 0.5 * sin(TAU * x / (ripple_length_px * 0.43) - t * 2.3)
	for mark in _world:
		if int(mark["kind"]) != DROP:
			offset += _wave(x, float(mark["x"]), (tick - float(mark["tick"])) / _ticks)
	if live_tick >= 0.0:
		for mark in _live:
			offset += _wave(x, float(mark["x"]), (live_tick - float(mark["tick"])) / _ticks)
	return offset


## Falling drops at world tick `tick`: a drop starts under the body when it
## falls and is gone when it reaches the water or the bottom.
func drops_at(tick: float, surface_y: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for mark in _world:
		if int(mark["kind"]) != DROP:
			continue
		var s := (tick - float(mark["tick"])) / _ticks
		if s < 0.0 or s > DROP_MAX_SECONDS:
			continue
		var y := float(mark["y"]) + 0.5 * drip_gravity_px * s * s
		if y < minf(surface_y, 0.0):
			result.append(Vector2(float(mark["x"]), y))
	return result


## Length of the streaks on a body's edges: full when it leaves the water,
## gone `drip_seconds` later; 0 while it is in the water.
func streak_at(key: String, tick: float) -> float:
	var last: Dictionary = {}
	for mark in _world:
		if String(mark["key"]) == key and int(mark["kind"]) != DROP and float(mark["tick"]) <= tick:
			last = mark
	if last.is_empty() or int(last["kind"]) != EXIT:
		return 0.0
	var s := (tick - float(last["tick"])) / _ticks
	return streak_px * maxf(1.0 - s / drip_seconds, 0.0)


## The jet at the source while the water flows: x, y and a size 0 … 1.
## Filling: a stream falls from a pipe at the top of the tank and splashes on
## the surface. Draining: water runs into a grate at the bottom. Every drop
## moves with world time, so under Shift the jet runs backward.
func jet_at(tick: float, flow: int, surface_y: float, size: Vector2, side: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	if flow == 0:
		return result
	var t := tick / _ticks
	var x0 := float(side) * (size.x / 2.0 - outlet_inset_px)
	if flow > 0:
		var top := -size.y
		for i in jet_drops:
			var p := fposmod(t * jet_cycles_per_second + float(i) / jet_drops, 1.0)
			var y := lerpf(top, surface_y, p * p)
			result.append(Vector3(x0 + (_hash(i) - 0.5) * 6.0, y, sin(PI * p)))
		for j in splash_drops:
			var p := fposmod(t * jet_cycles_per_second * 1.3 + float(j) / splash_drops, 1.0)
			var s := p * SPLASH_SECONDS
			var vx := (_hash(j + 11) - 0.5) * 240.0
			var vy := 120.0 + _hash(j + 23) * 120.0
			var y := surface_y - vy * s + 0.5 * drip_gravity_px * s * s
			if y <= surface_y:
				result.append(Vector3(x0 + vx * s, y, 1.0 - p))
	else:
		for i in jet_drops:
			var p := fposmod(t * jet_cycles_per_second + float(i) / jet_drops, 1.0)
			var angle := PI + _hash(i + 5) * PI
			var at := Vector2(x0, 0.0) + Vector2(cos(angle), sin(angle)) * 96.0 * (1.0 - p)
			if at.y > surface_y:
				result.append(Vector3(at.x, at.y, sin(PI * p)))
	return result


## The angle of a valve wheel for the level of its tank, 0 … 1: the wheel
## turns while the water flows and stops when the tank is full or empty.
func valve_angle(level_fraction: float) -> float:
	return -level_fraction * valve_turns_per_tank * TAU


## Everything the look shows at a world tick, for the tests: the surface at a
## few x, the drops, the streaks of `keys` and the jet. Live waves are left
## out: they follow the player's time, not the world's.
func snapshot(tick: int, surface_y: float, flow: int, size: Vector2, side: int, keys: Array) -> Dictionary:
	var surface: Array[float] = []
	for i in 17:
		var x := lerpf(-size.x / 2.0, size.x / 2.0, float(i) / 16.0)
		surface.append(snappedf(surface_offset(x, tick, -1.0), 0.001))
	var streaks := {}
	for key: String in keys:
		streaks[key] = snappedf(streak_at(key, tick), 0.001)
	return {"surface": surface, "drops": drops_at(tick, surface_y), "streaks": streaks,
		"jet": jet_at(tick, flow, surface_y, size, side)}


func _wave(x: float, from_x: float, age: float) -> float:
	if age < 0.0 or age >= wave_seconds:
		return 0.0
	var d := absf(x - from_x) - wave_speed_px * age
	var envelope := exp(-pow(d / wave_length_px, 2.0))
	# Grows from nothing, so a wave never pops in when its mark is passed.
	var fade := (1.0 - age / wave_seconds) * minf(age / WAVE_RISE_SECONDS, 1.0)
	return wave_px * fade * envelope * sin(TAU * d / wave_length_px)


func _since_exit(key: String, tick: int) -> int:
	for i in range(_world.size() - 1, -1, -1):
		var mark := _world[i]
		if String(mark["key"]) == key and int(mark["kind"]) != DROP:
			return tick - int(mark["tick"]) if int(mark["kind"]) == EXIT else -1
	return -1


func _forget_after(tick: int) -> void:
	_world = _world.filter(func(mark: Dictionary) -> bool: return int(mark["tick"]) <= tick)


func _forget_before(tick: int) -> void:
	if not _world.is_empty() and int(_world[0]["tick"]) < tick:
		_world = _world.filter(func(mark: Dictionary) -> bool: return int(mark["tick"]) >= tick)


static func _hash(n: float) -> float:
	return fposmod(sin(n * 12.9898 + 4.1414) * 43758.5453, 1.0)
