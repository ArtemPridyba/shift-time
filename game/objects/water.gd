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
## Temporal object contract: docs/architecture.md, section 4.1.

const WATER_COLOR := Color(0.32, 0.42, 0.5, 0.45)
const SURFACE_COLOR := Color("#7FE8FF")
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


func _init() -> void:
	var data := Content.objects()
	configure(data.get("water", {}), Content.time())
	_carry_margin = float(data.get("carry_margin_px", 8))
	# After RoomTime (-50), before the player (0): the player reads this tick's rise.
	process_physics_priority = -40


func configure(water_data: Dictionary, time_data: Dictionary) -> void:
	_ticks = float(time_data.get("physics_ticks_per_second", 60))
	_step = maxi(int(round(float(LEVEL_MAX) / (float(water_data.get("full_seconds", 12)) * _ticks))), 1)
	_draft = float(water_data.get("float_draft_px", 8))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("water")
	_apply()


func _physics_process(_delta: float) -> void:
	if _seen_level >= 0:
		rise_px_per_second = (level - _seen_level) * size.y / LEVEL_MAX * _ticks
	_seen_level = level


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


func _draw() -> void:
	var top := surface_local_y(level)
	draw_rect(Rect2(Vector2(-size.x / 2.0, top), Vector2(size.x, -top)), WATER_COLOR)
	draw_line(Vector2(-size.x / 2.0, top), Vector2(size.x / 2.0, top), SURFACE_COLOR, 2.0)
