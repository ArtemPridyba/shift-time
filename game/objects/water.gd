class_name Water
extends Node2D
## A recorded body of water in a tank: a level plus a flow, not a fluid
## simulation. The node stands at the tank's bottom-left corner; the water
## fills `size` at level 1000.
##
## The flow comes from the source (a valve): `source_open` is part of the
## state and the valve sets it through `RoomTime.player_action`. While the
## source is open the water drains (or fills, with `fills`) at a constant rate
## from `data/objects.json` until it reaches `min_level` or `max_level`.
##
## The water is not solid and never hurts the hero: the hero sinks to the
## bottom, walks slower and cannot jump out, so deep water blocks the way;
## rising water lifts the hero to its surface (rules in `core/player_motion.gd`,
## the contact in `player.gd`).
##
## State recorded: { "level": int 0..1000, "flow": -1, 0 or +1, "source_open": bool }
## Temporal object contract: docs/architecture.md, section 4.1.

const LEVEL_MAX := 1000
const WATER_COLOR := Color(0.31, 0.44, 0.54, 0.7)
const SURFACE_COLOR := Color("#a9bccb")
const PIPE_COLOR := Color("#4a5059")
const STRIPE_COLOR := Color("#a9bccb")
## Pipe stripes: the gap between them and how far they move per level unit.
const STRIPE_SPACING := 24.0
const STRIPE_PX_PER_LEVEL := 0.6

@export var object_id := "water"
## Width and the depth at level 1000, in px.
@export var size := Vector2(384, 384)
@export_range(0, 1000) var level := LEVEL_MAX
## True while the source lets the water flow. Set it together with the
## source's own state in the scene (a valve's `open`).
@export var source_open := false
## An open source fills the tank instead of draining it.
@export var fills := false
@export_range(0, 1000) var min_level := 0
@export_range(0, 1000) var max_level := LEVEL_MAX
## Where the pipe is drawn, relative to the node; an empty rect draws none.
## Stripes run along it with the flow, and backwards under Shift.
@export var pipe := Rect2()

## -1 draining, +1 filling, 0 standing: what the water did on the last tick.
var flow := 0
## +1 or -1, from TimeManager through TimeWorld; for looks.
var time_direction := 1

var _step := 1


func _init() -> void:
	configure(Content.objects().get("water", {}), Content.time())


func configure(water_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := float(water_data.get("drain_seconds", 8)) * float(time_data.get("physics_ticks_per_second", 60))
	_step = maxi(1, int(round(float(LEVEL_MAX) / maxf(ticks, 1.0))))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("water")
	queue_redraw()


func capture_state() -> Dictionary:
	return {"level": level, "flow": flow, "source_open": source_open}


func restore_state(state: Dictionary) -> void:
	level = int(state["level"])
	flow = int(state["flow"])
	source_open = bool(state["source_open"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	flow = flow_now()
	level = clampi(level + flow * _step, mini(min_level, level), maxi(max_level, level))
	queue_redraw()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction
	queue_redraw()


## Water is never solid: it carries the hero up or lets the hero sink, it
## never crushes.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## Which way the water would move on the next tick at the head.
func flow_now() -> int:
	if not source_open:
		return 0
	if fills:
		return 1 if level < max_level else 0
	return -1 if level > min_level else 0


## The surface's height above the bottom at `at_level`, in px.
func height_at(at_level: int) -> float:
	return size.y * float(at_level) / float(LEVEL_MAX)


## The surface in global coordinates.
func surface_y() -> float:
	return global_position.y - height_at(level)


## How far `feet` (global) are below the surface, in px: negative above it,
## -INF when the feet are not over this tank or below its bottom.
func depth_of(feet: Vector2) -> float:
	var left := global_position.x
	if feet.x < left or feet.x > left + size.x or feet.y > global_position.y + 1.0:
		return -INF
	return feet.y - surface_y()


func _draw() -> void:
	var height := height_at(level)
	if height > 0.0:
		draw_rect(Rect2(Vector2(0.0, -height), Vector2(size.x, height)), WATER_COLOR)
		draw_line(Vector2(0.0, -height), Vector2(size.x, -height), SURFACE_COLOR, 3.0)
	if pipe.has_area():
		draw_rect(pipe, PIPE_COLOR)
		# The stripes follow the recorded level, so they run with the flow and
		# backwards when the world rewinds, without a state of their own.
		var offset := fmod(float(level) * STRIPE_PX_PER_LEVEL, STRIPE_SPACING)
		var x := pipe.position.x + STRIPE_SPACING - offset
		while x < pipe.end.x:
			draw_rect(Rect2(Vector2(x, pipe.position.y + pipe.size.y * 0.35), Vector2(8.0, pipe.size.y * 0.3)), STRIPE_COLOR)
			x += STRIPE_SPACING
