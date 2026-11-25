class_name BurstPipe
extends Node2D
## The pipe from the bottom of pool 2 to the room beyond it (level 02, D169).
## The water in the pool presses on it: while the pool fills, the pipe shakes,
## spray comes out by its loose plug and the needle of its gauge climbs; at
## `burst_level` the plug flies out (`PipePlug.eject`) and the water from the
## hole fills the pit under it. The door at the bottom of the pit is the
## pipe's own: the pressure of a full pool opens it, but only while the plug
## holds and the pit is dry. So the heroine has to put the plug back before
## the burst: she carries it there from the future, under Shift (the plug in
## her hands stays with her), and puts it in: a new branch of history in
## which the pipe holds.
##
## The pipe keeps one recorded fact, whether it burst; the rest (the shaking,
## the needle, the jet from the hole) is drawn from recorded levels and the
## world tick, so it plays backwards under Shift. At the head it tells the pit
## whether water runs into it and the door whether it is powered.
##
## A level sets `burst_level`, `door_level`, `dry_level` and `shake_level`
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

@export var object_id := "pipe"
## The pipe from the pool to the hole, in this node's coordinates; the hole is
## the last point.
@export var points := PackedVector2Array()
## Where the gauge sits, in this node's coordinates.
@export var gauge := Vector2.ZERO
@export var pool_path: NodePath
@export var pit_path: NodePath
@export var plug_path: NodePath
@export var door_path: NodePath
## How the plug flies out, pixels per second.
@export var eject_speed := Vector2(-260.0, -380.0)

var burst := false
var burst_level := 9000
var door_level := 9800
var dry_level := 300
var shake_level := 300
var _world_tick := 0


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("world_clock")


func apply_settings(settings: Dictionary) -> void:
	burst_level = int(settings.get("burst_level", burst_level))
	door_level = int(settings.get("door_level", door_level))
	dry_level = int(settings.get("dry_level", dry_level))
	shake_level = int(settings.get("shake_level", shake_level))


func capture_state() -> Dictionary:
	return {"burst": burst}


func restore_state(state: Dictionary) -> void:
	burst = bool(state["burst"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	var pool := _node(pool_path) as Water
	var plug := _node(plug_path) as PipePlug
	if pool == null or plug == null:
		return
	if not burst and plug.seated and not plug.firm and not plug.held and pool.level >= burst_level:
		burst = true
		plug.eject(eject_speed)
	var pit := _node(pit_path) as Water
	if pit != null:
		pit.powered = not plug.seated and pool.level >= burst_level
	var door := _node(door_path) as Door
	if door != null:
		door.powered = plug.seated and pool.level >= door_level and (pit == null or pit.level <= dry_level)


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func on_world_tick(tick: int, _recorded: bool) -> void:
	_world_tick = tick
	queue_redraw()


func hole_global() -> Vector2:
	return to_global(points[points.size() - 1]) if not points.is_empty() else global_position


## True while the pool presses on a loose plug that still holds.
func shaking() -> bool:
	var pool := _node(pool_path) as Water
	var plug := _node(plug_path) as PipePlug
	return pool != null and plug != null and plug.seated and not plug.firm and not burst and pool.level >= shake_level


## The shake of the pipe and the plug now: a formula of the world tick, so it
## plays backwards and stands at frame 0.
func shake_offset() -> Vector2:
	if not shaking():
		return Vector2.ZERO
	var t := float(_world_tick)
	return Vector2(sin(t * 1.7), cos(t * 2.3)) * SHAKE_PX


func pressure() -> float:
	var pool := _node(pool_path) as Water
	return float(pool.level) / float(Water.LEVEL_MAX) if pool != null else 0.0


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
	draw_circle(hole, WIDTH * 0.45, Color("#0d0d10"))
	_draw_gauge(shake)
	_draw_water(hole)


func _draw_gauge(shake: Vector2) -> void:
	var c := gauge + shake
	draw_circle(c, 15.0, IRON)
	draw_circle(c, 12.0, GAUGE_FACE)
	draw_arc(c, 10.0, PI * 1.95, PI * 2.25, 6, GAUGE_RED, 3.0)
	var a := lerpf(PI * 0.75, PI * 2.25, clampf(pressure(), 0.0, 1.0))
	draw_line(c, c + Vector2(cos(a), sin(a)) * 10.0, IRON, 2.0)


## Spray by a shaking plug; the jet from the open hole while the pit fills.
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
