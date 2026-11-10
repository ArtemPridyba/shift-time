class_name Lamp
extends Node2D
## A recorded lamp. It shines until its own clock reaches `break_seconds`, then
## it breaks and goes dark. The break is part of the recorded history: under
## Shift the lamp reassembles and shines again, and after Shift is released
## the recorded future plays on and it breaks again (rule «A»). Keeping the
## light needs interference.
##
## State recorded: { "lit": bool, "broken": bool, "phase": int }
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#6b717a")
const LIGHT_COLOR := Color("#f2d98a")
const CRACK_COLOR := Color("#2b2e33")

@export var object_id := "lamp"
## Seconds on the lamp's own clock before it breaks; 0 takes the number from `data/objects.json`.
@export var break_seconds := 0.0

var lit := true
var broken := false
## Ticks on the lamp's own clock.
var phase := 0
## +1 or -1, from TimeManager through TimeWorld; for looks and sound later.
var time_direction := 1

var _break_tick := 1
var _radius := 280.0


func _init() -> void:
	configure(Content.objects().get("lamp", {}), Content.time())


## Reads the break time and the light radius from data: seconds into ticks.
func configure(lamp_data: Dictionary, time_data: Dictionary) -> void:
	var ticks := float(time_data.get("physics_ticks_per_second", 60))
	var seconds := break_seconds if break_seconds > 0.0 else float(lamp_data.get("break_seconds", 8))
	_break_tick = maxi(int(round(seconds * ticks)), 1)
	_radius = float(lamp_data.get("light_radius_px", 280))


## `break_seconds` is an export, set after _init and before the room's RoomTime
## runs its prelude in _ready: read the data again as the lamp enters the tree.
func _enter_tree() -> void:
	configure(Content.objects().get("lamp", {}), Content.time())


func capture_state() -> Dictionary:
	return {"lit": lit, "broken": broken, "phase": phase}


func restore_state(state: Dictionary) -> void:
	lit = bool(state["lit"])
	broken = bool(state["broken"])
	phase = int(state["phase"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	phase += 1
	if phase >= _break_tick:
		broken = true
		lit = false
	queue_redraw()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## Lamps are not solid.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## The light this lamp gives now, or an empty Dictionary when it is dark.
## The position is in the parent's coordinates, like the player's rect.
func light_source() -> Dictionary:
	if not lit:
		return {}
	return {"position": position, "radius": _radius}


func _draw() -> void:
	# Housing on a short stem; a lit bulb with a halo, or a cracked dark bulb.
	draw_rect(Rect2(Vector2(-4.0, -40.0), Vector2(8.0, 28.0)), BODY_COLOR)
	draw_rect(Rect2(Vector2(-18.0, -12.0), Vector2(36.0, 10.0)), BODY_COLOR)
	if lit:
		draw_circle(Vector2(0.0, 12.0), 16.0, LIGHT_COLOR)
	else:
		draw_circle(Vector2(0.0, 12.0), 16.0, BODY_COLOR)
		draw_line(Vector2(-8.0, 4.0), Vector2(2.0, 14.0), CRACK_COLOR, 3.0)
		draw_line(Vector2(2.0, 14.0), Vector2(-3.0, 24.0), CRACK_COLOR, 3.0)
		draw_line(Vector2(2.0, 14.0), Vector2(10.0, 20.0), CRACK_COLOR, 3.0)
