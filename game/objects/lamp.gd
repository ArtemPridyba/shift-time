class_name Lamp
extends Node2D
## A recorded lamp. It hangs and shines until its own clock reaches
## `break_seconds`, then it tears loose and falls: on the way the light fades,
## on the floor the bulb shatters and the room goes dark. All of it is recorded
## history: under Shift the shards gather, the lamp flies back up and the light
## comes back, and after Shift is released the recorded fall plays again
## (rule «A»). Keeping the light needs interference.
##
## Everything is derived from `phase`, the ticks on the lamp's own clock, so a
## state is a few integers. State recorded:
## { "lit": bool, "broken": bool, "phase": int,
##   "drop": int (0..1000, how far it has fallen),
##   "light": int (0..1000, how bright it shines),
##   "shatter": int (0..1000, how far the shards have flown) }
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#6b717a")
const LIGHT_COLOR := Color("#f2d98a")
const CRACK_COLOR := Color("#2b2e33")
const CORD_COLOR := Color("#3a4048")
## Full value of `drop`, `light` and `shatter`.
const FULL := 1000
## Bulb centre below the node origin, in pixels.
const BULB_OFFSET := Vector2(0.0, 12.0)
## Where the shards fly (unit-ish offsets) and how big they are; fixed, never random.
const SHARDS: Array[Vector3] = [
	Vector3(-1.0, -0.7, 7.0), Vector3(-0.6, -1.0, 5.0), Vector3(-0.2, -0.5, 6.0),
	Vector3(0.3, -0.9, 5.0), Vector3(0.7, -0.6, 7.0), Vector3(1.0, -0.8, 5.0),
]
const SHARD_SPREAD := 70.0
const SHARD_HEIGHT := 60.0
const CORD_LENGTH := 200.0

@export var object_id := "lamp"
## Seconds on the lamp's own clock before it breaks; 0 takes the number from `data/objects.json`.
@export var break_seconds := 0.0
## How far it falls in pixels; 0 takes the number from `data/objects.json`.
@export var fall_distance := 0.0

var lit := true
var broken := false
## Ticks on the lamp's own clock.
var phase := 0
var drop := 0
var light := FULL
var shatter := 0
## +1 or -1, from TimeManager through TimeWorld; for looks and sound later.
var time_direction := 1

var _break_tick := 1
var _fall_ticks := 1
var _shatter_ticks := 1
var _fall_px := 356.0
var _radius := 560.0
var _hang_position := Vector2.ZERO
var _has_base := false


func _init() -> void:
	configure(Content.objects().get("lamp", {}), Content.time())


## Reads the times and sizes from data: seconds into ticks.
func configure(lamp_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := float(time_data.get("physics_ticks_per_second", 60))
	var seconds := break_seconds if break_seconds > 0.0 else float(lamp_data.get("break_seconds", 8))
	_break_tick = maxi(int(round(seconds * ticks)), 1)
	_fall_ticks = maxi(int(round(float(lamp_data.get("fall_seconds", 1.2)) * ticks)), 1)
	_shatter_ticks = maxi(int(round(float(lamp_data.get("shatter_seconds", 0.5)) * ticks)), 1)
	_fall_px = fall_distance if fall_distance > 0.0 else float(lamp_data.get("fall_distance_px", 356))
	_radius = float(lamp_data.get("light_radius_px", 560))


## `break_seconds` and `fall_distance` are exports, set after _init and before
## the room's RoomTime runs its prelude in _ready: read the data again as the
## lamp enters the tree.
func _enter_tree() -> void:
	configure(Content.objects().get("lamp", {}), Content.time())


func capture_state() -> Dictionary:
	return {"lit": lit, "broken": broken, "phase": phase, "drop": drop, "light": light, "shatter": shatter}


func restore_state(state: Dictionary) -> void:
	lit = bool(state["lit"])
	broken = bool(state["broken"])
	phase = int(state["phase"])
	drop = int(state["drop"])
	light = int(state["light"])
	shatter = int(state["shatter"])
	_apply()


func simulate_tick(_tick: int) -> void:
	phase += 1
	var fallen := clampi(phase - _break_tick, 0, _fall_ticks)
	var fraction := float(fallen) / float(_fall_ticks)
	# Falls with growing speed; the light fades evenly on the way down.
	drop = int(round(float(FULL) * fraction * fraction))
	light = int(round(float(FULL) * (1.0 - fraction)))
	broken = phase >= _break_tick + _fall_ticks
	lit = light > 0
	shatter = clampi(int(round(float(FULL) * float(phase - _break_tick - _fall_ticks) / float(_shatter_ticks))), 0, FULL)
	_apply()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## Lamps are not solid.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## The light this lamp gives now, or an empty Dictionary when it is dark.
## The position is in the parent's coordinates, like the player's rect.
func light_source() -> Dictionary:
	if light <= 0:
		return {}
	return {"position": position + BULB_OFFSET, "radius": _radius, "intensity": float(light) / float(FULL)}


func _apply() -> void:
	position = _hang() + Vector2(0.0, _fall_px * float(drop) / float(FULL))
	queue_redraw()


func _hang() -> Vector2:
	if not _has_base:
		_hang_position = position
		_has_base = true
	return _hang_position


func _draw() -> void:
	var rest_y := -_fall_px * float(drop) / float(FULL)
	# The cord stays on the ceiling: whole while the lamp hangs, a stub once torn.
	if drop == 0:
		draw_line(Vector2(0.0, rest_y - CORD_LENGTH), Vector2(0.0, -40.0), CORD_COLOR, 3.0)
	else:
		draw_line(Vector2(0.0, rest_y - CORD_LENGTH), Vector2(0.0, rest_y - CORD_LENGTH + 90.0), CORD_COLOR, 3.0)
	if shatter > 0:
		_draw_shattered()
		return
	draw_rect(Rect2(Vector2(-4.0, -40.0), Vector2(8.0, 28.0)), BODY_COLOR)
	draw_rect(Rect2(Vector2(-18.0, -12.0), Vector2(36.0, 10.0)), BODY_COLOR)
	var bulb := BODY_COLOR.lerp(LIGHT_COLOR, float(light) / float(FULL))
	draw_circle(BULB_OFFSET, 16.0, bulb)
	if light < FULL and light > 0:
		# A fading, flickering-free look: the bulb dims, the cracks stay hidden until it lands.
		draw_arc(BULB_OFFSET, 20.0, 0.0, TAU, 24, Color(bulb, 0.5), 2.0)


## The housing lies on the floor, the bulb is shards that fly out and settle.
func _draw_shattered() -> void:
	var t := float(shatter) / float(FULL)
	draw_rect(Rect2(Vector2(-18.0, 6.0), Vector2(36.0, 10.0)), BODY_COLOR)
	for shard in SHARDS:
		var x := shard.x * SHARD_SPREAD * t
		# Up then down: a parabola that ends on the floor.
		var y := BULB_OFFSET.y + 12.0 - shard.y * SHARD_HEIGHT * 4.0 * t * (1.0 - t)
		draw_rect(Rect2(Vector2(x - shard.z * 0.5, y - shard.z * 0.5), Vector2(shard.z, shard.z)), CRACK_COLOR.lerp(BODY_COLOR, 0.5))
