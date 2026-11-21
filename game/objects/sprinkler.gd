class_name Sprinkler
extends Node2D
## A recorded sprinkler pipe (level 04, D104): a lever opens it and water
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
## State recorded: { "powered": bool, "flow": int }
##
## The look is decoration from world time: drops fall from the nozzles, and
## under Shift they fly back up into the pipe.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const FLOW_MAX := 1000
const PIPE_COLOR := Color("#5a6068")
## The same water as the tanks; not cyan, cyan belongs to the time device.
const DROP_COLOR := Color(0.78, 0.85, 0.9, 0.9)

@export var object_id := "sprinkler"
## Pipe length and rain height, pixels.
@export var size := Vector2(640, 256)
@export var powered := false

var flow := 0
var _step := 28
var _nozzle_spacing := 64.0
var _drop_speed := 600.0
var _drops := 3
var _per_second := 60.0
var _world_tick := 0


func _init() -> void:
	configure(Content.objects().get("sprinkler", {}), Content.time())


func configure(data: Dictionary, time_data: Dictionary) -> void:
	_per_second = float(time_data.get("physics_ticks_per_second", 60))
	var spin_up := float(data.get("spin_up_seconds", 0.6))
	_step = maxi(int(ceil(float(FLOW_MAX) / (spin_up * _per_second))), 1)
	_nozzle_spacing = float(data.get("nozzle_spacing_px", 64))
	_drop_speed = float(data.get("drop_speed_px", 600))
	_drops = int(data.get("drops_per_nozzle", 3))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("water")
	add_to_group("world_clock")
	queue_redraw()


func capture_state() -> Dictionary:
	return {"powered": powered, "flow": flow}


func restore_state(state: Dictionary) -> void:
	powered = bool(state["powered"])
	flow = int(state["flow"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	if powered:
		flow = mini(flow + _step, FLOW_MAX)
	else:
		flow = maxi(flow - _step, 0)
	queue_redraw()


func on_time_direction_changed(_direction: int) -> void:
	pass


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
