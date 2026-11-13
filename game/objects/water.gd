class_name Water
extends Node2D
## A recorded tank of water: a level, not a fluid simulation. The node sits at
## the bottom centre of the tank; `size` is its width and its full height.
##
## The flow comes from the source (a valve, a lever, a gear): `powered` is set
## by the control through its targets, and `simulate_tick` moves the level by
## one step in `open_flow` direction while the source is open, until the tank
## is empty or full. Rewinding only restores frames, so a draining tank fills
## back up smoothly under Shift and drains again after (rule «A»).
##
## Child `WaterFloat` platforms ride the surface: their height is computed from
## the level, never recorded on its own, so a float always matches the water.
##
## The player is not blocked by water: the player reads the surface
## (`surface_global_y`, `rise_px_per_second`) and swims or drowns by its own
## rules (`PlayerMotion`, `Breath`).
##
## The look (task 2.3А) is decoration drawn by `WaterLook` from world time and
## the recorded state: waves, drips from bodies that leave the water, the jet
## at the source, a shader on the body. It is never recorded and changes
## nothing; `RoomTime` tells the tank the world tick (group `world_clock`).
##
## Temporal object contract: docs/architecture.md, section 4.1.

const WATER_COLOR := Color(0.32, 0.42, 0.5, 0.45)
## Not cyan: cyan belongs only to the mechanisms of time.
const SURFACE_COLOR := Color(0.74, 0.82, 0.86, 0.85)
const SPRAY_COLOR := Color(0.78, 0.85, 0.9, 0.9)
const PIPE_COLOR := Color("#5a6068")
const SHADER_PATH := "res://objects/water.gdshader"
## Surface points every this many pixels.
const SURFACE_STEP_PX := 16.0
## `level` runs from 0 (empty) to this (full). Finer than the door's 1000, so
## the drain time from data is kept to within a percent.
const LEVEL_MAX := 10000

@export var object_id := "water"
## Width and full height of the tank, pixels.
@export var size := Vector2(512, 384)
## The level when the room loads, 0 … LEVEL_MAX.
@export_range(0, 10000) var level := LEVEL_MAX
## True when the source is open at load.
@export var powered := false
## Where the water goes while the source is open: -1 drains, +1 fills.
@export_enum("Drain:-1", "Fill:1") var open_flow := -1
## The wall with the pipe (filling) or the grate (draining).
@export_enum("Left:-1", "Right:1") var outlet_side := 1

## -1, 0 or +1: how the level moved on the last simulated tick.
var flow := 0
var time_direction := 1
## The rise of the surface on the last physics tick, pixels per second; above
## zero while the water lifts what is in it (forward filling or rewinding a drain).
var rise_px_per_second := 0.0

var _step := 1
var _draft := 8.0
var _carry_margin := 8.0
var _seen_level := -1
var _ticks := 60.0
## The look; it keeps marks, never references to bodies.
var look := WaterLook.new()
## The world tick the tank shows, from `RoomTime`.
var _world_tick := 0
## The player's own clock: it always runs forward.
var _live_tick := 0
var _spray: Node2D


func _init() -> void:
	var data := Content.objects()
	configure(data.get("water", {}), Content.time())
	_carry_margin = float(data.get("carry_margin_px", 8))
	look.configure(data.get("water_look", {}), Content.time())
	# After RoomTime (-50), before the player (0): the player reads this tick's rise.
	process_physics_priority = -40


func configure(water_data: Dictionary, time_data: Dictionary) -> void:
	_ticks = float(time_data.get("physics_ticks_per_second", 60))
	_step = maxi(int(round(float(LEVEL_MAX) / (float(water_data.get("full_seconds", 12)) * _ticks))), 1)
	_draft = float(water_data.get("float_draft_px", 8))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("water")
	add_to_group("world_clock")
	var shader := load(SHADER_PATH) as Shader
	if shader != null:
		var body_material := ShaderMaterial.new()
		body_material.shader = shader
		material = body_material
	_spray = Node2D.new()
	_spray.name = "Spray"
	_spray.draw.connect(_draw_spray)
	add_child(_spray)
	_apply()


func _physics_process(_delta: float) -> void:
	if _seen_level >= 0:
		rise_px_per_second = (level - _seen_level) * size.y / LEVEL_MAX * _ticks
	_seen_level = level
	_live_tick += 1
	var half := size.x / 2.0
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and node.has_method("body_rect"):
			look.observe_live(_live_tick, str(node.get_instance_id()), _to_tank(node, node.call("body_rect")), surface_local_y(level), half)


func _process(_delta: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("world_time", _world_tick / _ticks)
	queue_redraw()
	if _spray != null:
		_spray.queue_redraw()


## From `RoomTime` every tick: the cursor and whether this tick was recorded at
## the head. Marks of the look are taken only on recorded ticks.
func on_world_tick(tick: int, recorded: bool) -> void:
	_world_tick = tick
	look.observe(tick, recorded, surface_local_y(level), size.x / 2.0, bodies_in_tank())


## The recorded bodies that may touch the water, in tank coordinates: this
## tank's floats and the room's moving platforms. Found anew on every call.
func bodies_in_tank() -> Array:
	var result: Array = []
	for float_body in floats():
		var body_size := float_body.body_size()
		result.append({"key": "float:" + float_body.name,
			"rect": Rect2(float_local_position(float_body, level) - body_size / 2.0, body_size)})
	var room := get_parent()
	if room == null or not is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group("temporal"):
		var platform := node as MovingPlatform
		if platform != null and room.is_ancestor_of(platform):
			result.append({"key": "platform:" + platform.object_id,
				"rect": _to_tank(platform, platform.rect_at(platform.position))})
	return result


## What the look shows now, for the tests (live waves left out).
func look_snapshot() -> Dictionary:
	var keys: Array = []
	for body: Dictionary in bodies_in_tank():
		keys.append(body["key"])
	var shot := look.snapshot(_world_tick, surface_local_y(level), flow, size, outlet_side, keys)
	shot["tick"] = _world_tick
	return shot


## A rect in `node`'s parent's coordinates, in the tank's (no rotation or scale).
func _to_tank(node: Node, rect: Rect2) -> Rect2:
	var parent := node.get_parent() as Node2D
	var origin := parent.global_position if parent != null else Vector2.ZERO
	return Rect2(rect.position + origin - global_position, rect.size)


func capture_state() -> Dictionary:
	return {"level": level, "flow": flow, "powered": powered}


func restore_state(state: Dictionary) -> void:
	level = int(state["level"])
	flow = int(state["flow"])
	powered = bool(state["powered"])
	_apply()


func simulate_tick(_tick: int) -> void:
	flow = 0
	if powered:
		var next := clampi(level + open_flow * _step, 0, LEVEL_MAX)
		flow = signi(next - level)
		level = next
	_apply()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## Water itself never crushes; a float rising under a ceiling does, like a
## platform: standing on it is riding, anything deeper is crushing.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var body := Rect2(player_rect.position, player_rect.size - Vector2(0.0, _carry_margin))
	for float_body in floats():
		if float_rect_at(float_body, int(state["level"])).intersects(body):
			return true
	return false


## Level units per simulated tick.
func step() -> int:
	return _step


## The surface in the tank's own coordinates (0 at the bottom, up is negative).
func surface_local_y(at_level: int) -> float:
	return -size.y * at_level / LEVEL_MAX


func surface_global_y() -> float:
	return global_position.y + surface_local_y(level)


## The whole tank, full, in global coordinates.
func tank_global_rect() -> Rect2:
	return Rect2(global_position + Vector2(-size.x / 2.0, -size.y), size)


## The water that is there now, in global coordinates.
func water_global_rect() -> Rect2:
	var top := surface_global_y()
	return Rect2(Vector2(global_position.x - size.x / 2.0, top), Vector2(size.x, global_position.y - top))


func floats() -> Array[WaterFloat]:
	var result: Array[WaterFloat] = []
	for child in get_children():
		if child is WaterFloat:
			result.append(child)
	return result


## Where a float stands for a level, in the tank's coordinates: it sits
## `float_draft_px` deep in the water and rests on the bottom of an empty tank.
func float_local_position(float_body: WaterFloat, at_level: int) -> Vector2:
	var half := float_body.body_size().y / 2.0
	var bottom := minf(surface_local_y(at_level) + _draft, 0.0)
	return Vector2(float_body.position.x, bottom - half)


## A float's body for a level, in the room's coordinates (the tank's parent).
func float_rect_at(float_body: WaterFloat, at_level: int) -> Rect2:
	var body_size := float_body.body_size()
	return Rect2(position + float_local_position(float_body, at_level) - body_size / 2.0, body_size)


func _apply() -> void:
	for float_body in floats():
		float_body.position = float_local_position(float_body, level)
	queue_redraw()


## The body with a wavy surface; the shader shades it by depth and world time.
func _draw() -> void:
	if level <= 0:
		return
	var points := _surface_points()
	var uvs := PackedVector2Array()
	var top := surface_local_y(level)
	points.append(Vector2(size.x / 2.0, 0.0))
	points.append(Vector2(-size.x / 2.0, 0.0))
	for point in points:
		# Pixels / 256: the shader's bands keep their size in any tank.
		uvs.append(Vector2(point.x, point.y - top) / 256.0)
	draw_polygon(points, PackedColorArray([WATER_COLOR]), uvs)


## The surface line, the pipe or grate, the jet, the streaks and the drops.
## Drawn on the child `Spray`, without the body's shader.
func _draw_spray() -> void:
	var tick := float(_world_tick)
	var top := surface_local_y(level)
	var outlet_x := outlet_side * (size.x / 2.0 - look.outlet_inset_px)
	if open_flow > 0:
		_spray.draw_rect(Rect2(Vector2(outlet_x - 14.0, -size.y - 18.0), Vector2(28.0, 18.0)), PIPE_COLOR)
	else:
		_spray.draw_rect(Rect2(Vector2(outlet_x - 24.0, -6.0), Vector2(48.0, 6.0)), PIPE_COLOR)
		for i in 4:
			_spray.draw_line(Vector2(outlet_x - 18.0 + i * 12.0, -6.0), Vector2(outlet_x - 18.0 + i * 12.0, 0.0), WATER_COLOR.darkened(0.5), 2.0)
	if level > 0:
		_spray.draw_polyline(_surface_points(), SURFACE_COLOR, 2.0, true)
	for drop in look.jet_at(tick, flow, top, size, outlet_side):
		_spray.draw_circle(Vector2(drop.x, drop.y), 1.0 + 1.5 * drop.z, Color(SPRAY_COLOR, SPRAY_COLOR.a * drop.z))
	for body: Dictionary in bodies_in_tank():
		var length := look.streak_at(String(body["key"]), tick)
		if length <= 0.0:
			continue
		var rect: Rect2 = body["rect"]
		for x in [rect.position.x + 6.0, rect.get_center().x, rect.end.x - 6.0]:
			_spray.draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + length), SPRAY_COLOR, 2.0)
	for drop in look.drops_at(tick, top):
		_spray.draw_circle(drop, 2.5, SPRAY_COLOR)


func _surface_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var top := surface_local_y(level)
	var count := maxi(int(ceil(size.x / SURFACE_STEP_PX)), 1)
	for i in count + 1:
		var x := lerpf(-size.x / 2.0, size.x / 2.0, float(i) / count)
		points.append(Vector2(x, minf(top + look.surface_offset(x, _world_tick, _live_tick), 0.0)))
	return points
