class_name Sprinkler
extends Node2D
## A recorded sprinkler pipe (level 03, D104): a lever opens it and water
## rains from its nozzles onto what lies below. It wets wood (group `water`,
## `water_global_rect`), so a burning bridge under it is put out; it is not a
## tank, so the player never wades or drowns in it (the player reads only
## `Water`).
##
## The node is the middle of the pipe; `size.x` is the pipe's length and
## `size.y` how far the rain falls. `flow` runs from 0 (shut) to FLOW_MAX
## (full rain) in `spin_up_seconds` while `powered`, and back while not; the
## rain wets only at full flow.
##
## A level can make it automatic (level 03, part two: the hall's fire system):
## `start_seconds` in the level's `objects` entry (`apply_settings`) holds the
## rain back until that world frame, so a sprinkler powered from the start
## opens on its own a moment into the room's history, in every branch the
## same. A lever that unpowers it before then keeps it shut.
##
## A level can also stop it (level 03 «Нить», D177): `stop_seconds` shuts the
## rain from that frame on, in every branch the same, and `start_full` (an
## export) makes a powered sprinkler rain at full flow from the first frame.
##
## A level can give it a fire sensor (level 03, D155): `sensor_id` names a
## wood zone, and the first tick at the head that zone burns the sprinkler is
## powered on its own, as if the fire alarm went off. Only at the head, so a
## replay shows what was recorded and a branch decides anew.
##
## A level can give it a fire detector instead (level 03 «Нить», D178):
## `torch_sensor` (an export) watches the rain's own span, and a burning
## torch in the hands that comes into it powers the sprinkler through
## `apply_change` (group `torch_lightable`), like a rope: at the head it is
## recording, left of the head interference. So under Shift the detector sees
## her and its lamp lights, but the rain comes only once time runs forward
## from that frame again. `rain_seconds` (level settings, real seconds) shuts
## it again after that long, and the detector is armed once more.
## `spin_up_seconds` in the settings overrides the one in objects.json.
##
## State recorded: { "powered": bool, "flow": int, "run": int }
##
## The look is decoration from world time: drops fall from the nozzles, and
## under Shift they fly back up into the pipe.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const FLOW_MAX := 1000
const PIPE_COLOR := Color("#5a6068")
## The same water as the tanks; not cyan, cyan belongs to the time device.
const DROP_COLOR := Color(0.78, 0.85, 0.9, 0.9)
const DETECTOR_BOX := Color("#7a221c")
const DETECTOR_LAMP := Color("#ff4a32")
const DETECTOR_WATCH := Color(1.0, 0.3, 0.2, 0.14)

@export var object_id := "sprinkler"
## Pipe length and rain height, pixels.
@export var size := Vector2(640, 256)
@export var powered := false
## False when a WaterPipe draws the pipe along the nozzles (level 03, D108).
@export var draw_pipe := true
## The object_id of the wood zone the fire sensor watches; empty: no sensor.
@export var sensor_id := ""
## Raining at full flow on the first frame (powered and no start).
@export var start_full := false
## A fire detector over the rain (see above).
@export var torch_sensor := false

var flow := 0
var _step := 28
var _nozzle_spacing := 64.0
var _drop_speed := 600.0
var _drops := 3
var _per_second := 60.0
var _world_tick := 0
## Ticks the rain has run since it was powered (only with `rain_seconds`).
var run := 0
## Ticks a powered rain runs before it shuts; 0 never.
var _rain_ticks := 0
## The first world frame the rain may run on; 0 for a plain sprinkler.
var _start_tick := 0
## The first world frame the rain is shut again; -1 never.
var _stop_tick := -1


func _init() -> void:
	configure(Content.objects().get("sprinkler", {}), Content.time())


func configure(data: Dictionary, time_data: Dictionary) -> void:
	_per_second = float(time_data.get("physics_ticks_per_second", 60))
	var spin_up := float(data.get("spin_up_seconds", 0.6))
	_step = maxi(int(ceil(float(FLOW_MAX) / (spin_up * _per_second))), 1)
	_nozzle_spacing = float(data.get("nozzle_spacing_px", 64))
	_drop_speed = float(data.get("drop_speed_px", 600))
	_drops = int(data.get("drops_per_nozzle", 3))


func apply_settings(settings: Dictionary) -> void:
	if settings.has("start_seconds"):
		_start_tick = maxi(int(round(float(settings["start_seconds"]) * _per_second)), 0)
	if settings.has("stop_seconds"):
		_stop_tick = maxi(int(round(float(settings["stop_seconds"]) * _per_second)), 0)
	if settings.has("rain_seconds"):
		_rain_ticks = maxi(int(round(float(settings["rain_seconds"]) * _per_second)), 0)
	if settings.has("spin_up_seconds"):
		var spin_up := maxf(float(settings["spin_up_seconds"]), 1.0 / _per_second)
		_step = maxi(int(ceil(float(FLOW_MAX) / (spin_up * _per_second))), 1)


## The first world frame the rain may run on.
func start_tick() -> int:
	return _start_tick


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("water")
	add_to_group("world_clock")
	if torch_sensor:
		add_to_group("torch_lightable")
	if start_full and powered and _start_tick == 0:
		flow = FLOW_MAX
	queue_redraw()


func capture_state() -> Dictionary:
	return {"powered": powered, "flow": flow, "run": run}


func restore_state(state: Dictionary) -> void:
	powered = bool(state["powered"])
	flow = int(state["flow"])
	run = int(state.get("run", 0))
	queue_redraw()


func simulate_tick(tick: int) -> void:
	if not powered and sensor_fires():
		powered = true
	if powered and _rain_ticks > 0:
		run += 1
		if run > _rain_ticks:
			powered = false
			run = 0
	if powered and tick >= _start_tick and (_stop_tick < 0 or tick < _stop_tick):
		flow = mini(flow + _step, FLOW_MAX)
	else:
		flow = maxi(flow - _step, 0)
	queue_redraw()


## True while the wood zone under the fire sensor burns.
func sensor_fires() -> bool:
	if sensor_id == "" or not is_inside_tree():
		return false
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("flammable"):
		if room.is_ancestor_of(node) and str(node.get("object_id")) == sensor_id:
			var burn: Variant = node.get("burn")
			return burn is WoodBurn and (burn as WoodBurn).is_burning()
	return false


func on_time_direction_changed(_direction: int) -> void:
	pass


## The detector's watch in global pixels: the rain's span from the pipe down.
func light_rect() -> Rect2:
	return Rect2(global_position - Vector2(size.x / 2.0, 0.0), size)


## What a burning torch in the detector's watch changes: it powers an armed
## sprinkler, once per contact.
func torch_change() -> Dictionary:
	if not torch_sensor or powered:
		return {}
	return {"powered": true, "run": 0}


## Seconds a powered rain runs before it shuts; 0 never.
func rain_seconds() -> float:
	return float(_rain_ticks) / _per_second


## Rain is not solid.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func on_world_tick(tick: int, _recorded: bool) -> void:
	if tick != _world_tick:
		_world_tick = tick
		queue_redraw()


## The rain in global pixels while it runs at full flow; empty otherwise.
func water_global_rect() -> Rect2:
	if flow < FLOW_MAX:
		return Rect2()
	return Rect2(global_position - Vector2(size.x / 2.0, 0.0), size)


func is_raining() -> bool:
	return flow >= FLOW_MAX


func _draw() -> void:
	if draw_pipe:
		draw_rect(Rect2(Vector2(-size.x / 2.0, -10.0), Vector2(size.x, 12.0)), PIPE_COLOR)
	var nozzles := maxi(int(size.x / _nozzle_spacing), 1)
	var gap := size.x / float(nozzles)
	var reach := size.y * float(flow) / float(FLOW_MAX)
	var seconds := float(_world_tick) / _per_second
	for n in nozzles:
		var x := -size.x / 2.0 + gap * (n + 0.5)
		draw_rect(Rect2(Vector2(x - 5.0, 2.0), Vector2(10.0, 8.0)), PIPE_COLOR.darkened(0.3))
		if reach <= 0.0:
			continue
		for d in _drops * 3:
			# Each drop's height is a function of world time only, so the rain
			# runs backwards under Shift and stands still at frame 0.
			var phase := float(d) / float(_drops * 3) + float(n % 3) * 0.13
			var y := fposmod(seconds * _drop_speed / size.y + phase, 1.0) * size.y
			if y > reach:
				continue
			var dx := (float(d % 3) - 1.0) * 6.0
			draw_line(Vector2(x + dx, 10.0 + y), Vector2(x + dx, 10.0 + y + 14.0), DROP_COLOR, 2.0)
	if torch_sensor:
		_draw_detector(seconds)


## The fire detector in the middle of the pipe: a red box with a lamp, and
## its watch drawn as two faint lines down to the floor's corners, so the
## player sees where fire is noticed. While powered the lamp blinks by world
## time and the watch glows.
func _draw_detector(seconds: float) -> void:
	var at := Vector2(0.0, -26.0)
	var half := size.x / 2.0
	var watch := DETECTOR_WATCH
	if powered:
		watch = Color(DETECTOR_LAMP, 0.35)
	draw_line(at, Vector2(-half, size.y), watch, 2.0)
	draw_line(at, Vector2(half, size.y), watch, 2.0)
	draw_line(Vector2(-half, size.y - 2.0), Vector2(half, size.y - 2.0), watch, 2.0)
	draw_rect(Rect2(at - Vector2(16.0, 10.0), Vector2(32.0, 20.0)), DETECTOR_BOX)
	draw_rect(Rect2(Vector2(-3.0, -16.0), Vector2(6.0, 8.0)), PIPE_COLOR)
	var lamp := DETECTOR_LAMP.darkened(0.6)
	if powered and fposmod(seconds * 4.0, 1.0) < 0.6:
		lamp = DETECTOR_LAMP
	draw_circle(at, 6.0, lamp)
