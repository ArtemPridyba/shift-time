class_name Lever
extends Area2D
## A toggle interaction point. Each press flips `on`; the linked door's
## `powered` follows the lever's `on` state.
##
## State recorded: { "on": bool }
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#8b7355")
const ON_COLOR := Color("#d4a853")
const SIZE := Vector2(32.0, 64.0)

@export var object_id := "lever"
## The object_id of the Door this lever controls.
@export var target_id := ""

## Interaction radius in pixels, read from objects.json.
var _radius := 80.0

var on := false


func _init() -> void:
	_radius = float(Content.objects().get("lever", {}).get("interact_radius_px", 80))


func _ready() -> void:
	add_to_group("temporal")


func capture_state() -> Dictionary:
	return {"on": on}


func restore_state(state: Dictionary) -> void:
	on = bool(state["on"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	pass  # Levers do not change on their own.


func on_time_direction_changed(_direction: int) -> void:
	pass


## Levers are not solid.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## Returns the interaction candidate dict for InteractionSystem.
func interaction_candidate() -> Dictionary:
	return {"id": object_id, "position": global_position, "radius": _radius}


## Called by player.gd when the player presses `interact` near this lever.
## Returns the list of state changes to apply via RoomTime.player_action.
func get_interaction_change(room_objects: Array) -> Array:
	var new_on := not on
	var self_change := {"id": object_id, "state": {"on": new_on}}
	if target_id == "":
		return [self_change]
	var door_state := _find_state(target_id, room_objects)
	if door_state.is_empty():
		return [self_change]
	door_state["powered"] = new_on
	return [self_change, {"id": target_id, "state": door_state}]


func _find_state(id: String, objects: Array) -> Dictionary:
	for obj in objects:
		if obj.has_method("capture_state") and obj.get("object_id") == id:
			return obj.capture_state()
	return {}


func _draw() -> void:
	# Draw the base.
	draw_rect(Rect2(Vector2(-SIZE.x / 2.0, -SIZE.y * 0.3), Vector2(SIZE.x, SIZE.y * 0.3)), BODY_COLOR)
	# Draw the handle angled left (off) or right (on).
	var angle := -0.5 if on else 0.5
	var handle_len := SIZE.y * 0.65
	var tip := Vector2(sin(angle) * handle_len, -cos(angle) * handle_len)
	draw_line(Vector2.ZERO, tip, ON_COLOR if on else BODY_COLOR, 6.0, true)
	draw_circle(tip, 7.0, ON_COLOR if on else BODY_COLOR)
