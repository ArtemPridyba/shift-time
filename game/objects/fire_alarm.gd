class_name FireAlarm
extends Node2D
## The fire alarm handle on a wall (level 03, D155): a red box with a
## signal-yellow pull handle (D65). Pulling it (E) powers its sprinklers; it
## only pulls, never shuts them again, so pulling it once more changes
## nothing. Under Shift the pull is interference: the rain runs from that
## frame on in a new branch.
##
## The node stands on the floor under the box, like a lever, so the player in
## front of it is in reach; the box hangs `box_height_px` above the floor.
## While a sprinkler it powers rains, a lamp on the box blinks from world time.
##
## State recorded: { "pulled": bool }
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BOX_COLOR := Color("#9a2a22")
const DARK_COLOR := Color("#5a1a16")
const HANDLE_COLOR := Color("#e0b43a")
const LIGHT_COLOR := Color("#ff5a3a")
const BOX_SIZE := Vector2(30.0, 40.0)

@export var object_id := "alarm"
## Every sprinkler this handle powers.
@export var target_ids := PackedStringArray()
## Height of the box's middle above the floor, pixels.
@export var box_height_px := 72.0

var pulled := false
var _radius := 80.0
var _per_second := 60.0
var _world_tick := 0


func _init() -> void:
	_radius = float(Content.objects().get("lever", {}).get("interact_radius_px", 80))
	_per_second = float(Content.time().get("physics_ticks_per_second", 60))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("world_clock")


func capture_state() -> Dictionary:
	return {"pulled": pulled}


func restore_state(state: Dictionary) -> void:
	pulled = bool(state["pulled"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	pass


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func on_world_tick(tick: int, _recorded: bool) -> void:
	if tick != _world_tick:
		_world_tick = tick
		queue_redraw()


## A pull point until pulled; then out of reach (radius below 0).
func interaction_candidate() -> Dictionary:
	return {"id": object_id, "position": global_position, "radius": -1.0 if pulled else _radius}


func get_interaction_change(room_objects: Array) -> Array:
	if pulled:
		return []
	return [{"id": object_id, "state": {"pulled": true}}] + InteractionSystem.power_changes(target_ids, room_objects, true)


## True while a sprinkler of this handle rains: the alarm sounds.
func is_ringing() -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group("water"):
		if node is Sprinkler and target_ids.has((node as Sprinkler).object_id) and (node as Sprinkler).powered:
			return true
	return false


func _draw() -> void:
	var centre := Vector2(0.0, -box_height_px)
	draw_rect(Rect2(centre - BOX_SIZE / 2.0, BOX_SIZE), BOX_COLOR)
	draw_rect(Rect2(centre - BOX_SIZE / 2.0, BOX_SIZE), DARK_COLOR, false, 2.0)
	# The handle: up when ready, down when pulled.
	var grip := centre + Vector2(0.0, 10.0 if pulled else -6.0)
	draw_rect(Rect2(grip - Vector2(10.0, 4.0), Vector2(20.0, 8.0)), HANDLE_COLOR)
	# The lamp on top blinks by world time while the alarm sounds, so it runs
	# the same backwards and stands at frame 0.
	var lamp := centre + Vector2(0.0, -BOX_SIZE.y / 2.0 - 5.0)
	var on := is_ringing() and fmod(float(_world_tick) / _per_second, 0.5) < 0.25
	draw_circle(lamp, 5.0, LIGHT_COLOR if on else DARK_COLOR)
