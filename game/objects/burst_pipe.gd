class_name BurstPipe
extends Node2D
## The pipe from the bottom of pool 2 to the room beyond it (level 02, D169,
## reworked by D171; the name is from its first version, when the plug burst
## out). Its valve is missing from the start: the flange over the pit stands
## open, and the yellow handwheel (`PipePlug`) lies on the bottom of the empty
## pool 2. While the pool fills, the open pipe shakes and drips; at
## `leak_level` the water gushes out of the flange and fills the pit under it.
## The door at the bottom of the pit is the pipe's own: the pressure of a full
## pool opens it, but only while the valve is on and the pit is dry. So the
## heroine takes the handwheel from the empty pool under Shift and puts it on
## the flange before the gush, again under Shift; neither cuts the room's
## history (D171): the world replays its future, and the pit and the door
## follow the valve (`rerecord`), so the pipe holds and the door opens.
##
## The pipe records nothing of its own; the shaking, the needle, the drips and
## the gush are drawn from recorded levels and the world tick, so they play
## backwards under Shift. At the head it tells the pit whether water runs into
## it and the door whether it is powered.
##
## A level sets `leak_level`, `door_level`, `dry_level` and `shake_level`
## (0 … `Water.LEVEL_MAX`) through `objects.pipe` in `data/levels.json`.
## Temporal object contract: docs/architecture.md, section 4.1.

const IRON := Color("#3c3a3e")
const IRON_LIGHT := Color("#66636a")
const RUST := Color("#6e4130")
const GAUGE_FACE := Color("#d8d2c0")
const GAUGE_RED := Color("#b8352a")
const WATER := Color(0.74, 0.82, 0.86, 0.8)
const WIDTH := 22.0
const SHAKE_PX := 2.5
## Without the valve the pressure escapes: the needle climbs only this far.
const OPEN_PRESSURE := 0.45

@export var object_id := "pipe"
## The pipe from the pool to the flange, in this node's coordinates; the open
## flange is the last point.
@export var points := PackedVector2Array()
## Where the gauge sits, in this node's coordinates.
@export var gauge := Vector2.ZERO
@export var pool_path: NodePath
@export var pit_path: NodePath
@export var plug_path: NodePath
@export var door_path: NodePath

var leak_level := 9000
var door_level := 9800
var dry_level := 300
var shake_level := 300
var _world_tick := 0


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("world_clock")


func apply_settings(settings: Dictionary) -> void:
	leak_level = int(settings.get("leak_level", leak_level))
	door_level = int(settings.get("door_level", door_level))
	dry_level = int(settings.get("dry_level", dry_level))
	shake_level = int(settings.get("shake_level", shake_level))


func capture_state() -> Dictionary:
	return {}


func restore_state(_state: Dictionary) -> void:
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	var pool := _node(pool_path) as Water
	var plug := _node(plug_path) as PipePlug
	if pool == null or plug == null:
		return
	var pit := _node(pit_path) as Water
	if pit != null:
		pit.powered = leaking()
	var door := _node(door_path) as Door
	if door != null:
		door.powered = plug.seated and pool.level >= door_level and (pit == null or pit.level <= dry_level)


## The valve changed while the cursor is left of the head (D171): the pit and
## the door are simulated again over the recorded future, from the frame
## after the cursor to the head, with the pool's recorded levels and the valve
## as it is now; their new states are written into those frames. The rest of
## the room's history stays, so the world replays its own future (the press of
## button 1 included) with the valve on or off. At the head there is nothing to
## do.
func rerecord(timeline: Timeline) -> void:
	var pool := _node(pool_path) as Water
	var plug := _node(plug_path) as PipePlug
	var pit := _node(pit_path) as Water
	var door := _node(door_path) as Door
	if pool == null or plug == null or pit == null or door == null or timeline.is_empty() or timeline.at_head():
		return
	var pit_now := pit.capture_state()
	var door_now := door.capture_state()
	for number in range(timeline.cursor() + 1, timeline.head() + 1):
		var frame := timeline.frame_at(number)
		var pool_state: Dictionary = frame.get(pool.object_id, {})
		var level := int(pool_state.get("level", pool.level))
		pit.powered = not plug.seated and level >= leak_level
		pit.simulate_tick(number)
		door.powered = plug.seated and level >= door_level and pit.level <= dry_level
		door.simulate_tick(number)
		timeline.write_at(number, pit.object_id, pit.capture_state())
		timeline.write_at(number, door.object_id, door.capture_state())
	pit.restore_state(pit_now)
	door.restore_state(door_now)


## True while water gushes out of the open flange: no valve and the pool high.
func leaking() -> bool:
	var pool := _node(pool_path) as Water
	var plug := _node(plug_path) as PipePlug
	return pool != null and plug != null and not plug.seated and pool.level >= leak_level


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func on_world_tick(tick: int, _recorded: bool) -> void:
	_world_tick = tick
	queue_redraw()


func hole_global() -> Vector2:
	return to_global(points[points.size() - 1]) if not points.is_empty() else global_position


## True while the pool presses on the open pipe before it gushes: it shakes and drips.
func shaking() -> bool:
	var pool := _node(pool_path) as Water
	var plug := _node(plug_path) as PipePlug
	return pool != null and plug != null and not plug.seated and pool.level >= shake_level and pool.level < leak_level


## The shake of the pipe now: a formula of the world tick, so it plays
## backwards and stands at frame 0.
func shake_offset() -> Vector2:
	if not shaking():
		return Vector2.ZERO
	var t := float(_world_tick)
	return Vector2(sin(t * 1.7), cos(t * 2.3)) * SHAKE_PX


## What the gauge shows, 0..1: the pool's pressure, held in only by the valve.
func pressure() -> float:
	var pool := _node(pool_path) as Water
	var plug := _node(plug_path) as PipePlug
	if pool == null:
		return 0.0
	var full := float(pool.level) / float(Water.LEVEL_MAX)
	return full if plug != null and plug.seated else full * OPEN_PRESSURE


func _node(path: NodePath) -> Node:
	return get_node_or_null(path) if not path.is_empty() else null


func _draw() -> void:
	if points.size() < 2:
		return
	var shake := shake_offset()
	var line := PackedVector2Array()
	for p in points:
		line.append(p + shake)
	draw_polyline(line, IRON, WIDTH)
	draw_polyline(line, IRON_LIGHT, 3.0)
	# Flanges at the joints, a rust streak under the hole.
	for i in range(1, points.size()):
		draw_rect(Rect2(line[i] - Vector2(WIDTH, WIDTH) * 0.7, Vector2(WIDTH, WIDTH) * 1.4), IRON)
	var hole := line[line.size() - 1]
	draw_rect(Rect2(hole + Vector2(-WIDTH * 0.5, WIDTH * 0.7), Vector2(WIDTH, 26.0)), Color(RUST, 0.6))
	# The open flange where the valve belongs: a wide collar with four bolts.
	draw_rect(Rect2(hole + Vector2(-WIDTH, -5.0), Vector2(WIDTH * 2.0, 10.0)), IRON_LIGHT)
	for x in [-WIDTH * 0.8, -WIDTH * 0.3, WIDTH * 0.3, WIDTH * 0.8]:
		draw_circle(hole + Vector2(x, 0.0), 2.2, IRON)
	draw_circle(hole + Vector2(0.0, 5.0), WIDTH * 0.4, Color("#0d0d10"))
	_draw_gauge(shake)
	_draw_water(hole)


func _draw_gauge(shake: Vector2) -> void:
	var c := gauge + shake
	draw_circle(c, 15.0, IRON)
	draw_circle(c, 12.0, GAUGE_FACE)
	draw_arc(c, 10.0, PI * 1.95, PI * 2.25, 6, GAUGE_RED, 3.0)
	var a := lerpf(PI * 0.75, PI * 2.25, clampf(pressure(), 0.0, 1.0))
	draw_line(c, c + Vector2(cos(a), sin(a)) * 10.0, IRON, 2.0)


## Drips from the shaking open pipe; the gush from the flange while the pit fills.
func _draw_water(hole: Vector2) -> void:
	var plug := _node(plug_path) as PipePlug
	var pit := _node(pit_path) as Water
	var t := float(_world_tick)
	if shaking():
		for i in 5:
			var phase := fposmod(t / 14.0 + float(i) / 5.0, 1.0)
			draw_circle(hole + Vector2((i - 2) * 5.0 * phase, -8.0 * phase + 30.0 * phase * phase), 1.6, Color(WATER, 1.0 - phase))
	if pit == null or plug == null or plug.seated or pit.flow <= 0:
		return
	var bottom := to_local(Vector2(0.0, pit.surface_global_y())).y
	if bottom <= hole.y:
		return
	draw_rect(Rect2(hole + Vector2(-7.0, 0.0), Vector2(14.0, bottom - hole.y)), Color(WATER, 0.55))
	for i in 6:
		var phase := fposmod(t / 10.0 + float(i) / 6.0, 1.0)
		draw_circle(hole + Vector2((i % 3 - 1) * 5.0, (bottom - hole.y) * phase), 2.2, WATER)
