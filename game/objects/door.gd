class_name Door
extends AnimatableBody2D
## A recorded door that slides up to open. Place it closed in the scene; `travel`
## is how far it rises when fully open. Until buttons exist (task 2.1) it runs
## its own cycle from `data/objects.json`: opens, stays open, closes, stays closed.
## A locked door stands still.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#6b717a")
const ACCENT_COLOR := Color("#7FE8FF")
## `open` runs from 0 (closed) to this (fully open).
const OPEN_MAX := 1000

@export var object_id := "door"
@export var travel := 192.0

var open := 0
var locked := false
## Tick on the door's own cycle.
var phase := 0
## +1 or -1, from TimeManager through TimeWorld; for looks and sound later.
var time_direction := 1

var _closed_position := Vector2.ZERO
var _has_base := false
var _open_ticks := 1
var _hold_open_ticks := 1
var _close_ticks := 1
var _hold_closed_ticks := 1


func _init() -> void:
	sync_to_physics = true
	configure(Content.objects().get("door", {}), Content.time())


## Reads the cycle from data: seconds into ticks.
func configure(door_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := float(time_data.get("physics_ticks_per_second", 60))
	_open_ticks = maxi(int(round(float(door_data.get("open_seconds", 3)) * ticks)), 1)
	_hold_open_ticks = maxi(int(round(float(door_data.get("hold_open_seconds", 4)) * ticks)), 1)
	_close_ticks = maxi(int(round(float(door_data.get("close_seconds", 3)) * ticks)), 1)
	_hold_closed_ticks = maxi(int(round(float(door_data.get("hold_closed_seconds", 4)) * ticks)), 1)


func _ready() -> void:
	_base()


func capture_state() -> Dictionary:
	return {"open": open, "locked": locked, "phase": phase}


func restore_state(state: Dictionary) -> void:
	open = int(state["open"])
	locked = bool(state["locked"])
	phase = int(state["phase"])
	_apply()


func simulate_tick(_tick: int) -> void:
	if locked:
		return
	phase = (phase + 1) % cycle_ticks()
	open = open_at(phase)
	_apply()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## True when the door in `state` would overlap the player (rects in the
## parent's coordinates). Touching is not overlapping.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	return rect_at(int(state["open"])).intersects(player_rect)


func cycle_ticks() -> int:
	return _open_ticks + _hold_open_ticks + _close_ticks + _hold_closed_ticks


## How open the door is at a tick of its cycle: opening, open, closing, closed.
func open_at(cycle_phase: int) -> int:
	var p := cycle_phase
	if p < _open_ticks:
		return int(round(float(OPEN_MAX) * p / _open_ticks))
	p -= _open_ticks
	if p < _hold_open_ticks:
		return OPEN_MAX
	p -= _hold_open_ticks
	if p < _close_ticks:
		return int(round(float(OPEN_MAX) * (_close_ticks - p) / _close_ticks))
	return 0


## The door's body in the parent's coordinates when it is `amount` open.
func rect_at(amount: int) -> Rect2:
	var size := _size()
	return Rect2(_base() + Vector2(-size.x / 2.0, -size.y / 2.0 - travel * amount / OPEN_MAX), size)


func _apply() -> void:
	position = _base() + Vector2(0.0, -travel * open / OPEN_MAX)


func _base() -> Vector2:
	if not _has_base:
		_closed_position = position
		_has_base = true
	return _closed_position


func _size() -> Vector2:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		return (shape.shape as RectangleShape2D).size
	return Vector2(32, 192)


func _draw() -> void:
	var size := _size()
	draw_rect(Rect2(-size / 2.0, size), BODY_COLOR)
	draw_rect(Rect2(Vector2(-4.0, -size.y / 2.0 + 8.0), Vector2(8.0, size.y - 16.0)), ACCENT_COLOR)
