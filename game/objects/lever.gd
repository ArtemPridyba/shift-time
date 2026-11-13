class_name Lever
extends Area2D
## A toggle interaction point. Each press flips `on`; the `powered` of every
## target (a door, a water source) follows the lever's `on` state.
##
## State recorded: { "on": bool }
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#8b7355")
const ON_COLOR := Color("#d4a853")
const SIZE := Vector2(32.0, 64.0)

@export var object_id := "lever"
## The object_id of the object this lever controls (older scenes).
@export var target_id := ""
## Every object this lever controls, such as one valve for two tanks.
@export var target_ids := PackedStringArray()
## The lever's state when the room loads.
@export var on := false

## Interaction radius in pixels, read from objects.json.
var _radius := 80.0


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
	var targets := InteractionSystem.target_list(target_id, target_ids)
	return [{"id": object_id, "state": {"on": new_on}}] + InteractionSystem.power_changes(targets, room_objects, new_on)


func _draw() -> void:
	# Draw the base.
	draw_rect(Rect2(Vector2(-SIZE.x / 2.0, -SIZE.y * 0.3), Vector2(SIZE.x, SIZE.y * 0.3)), BODY_COLOR)
	# Draw the handle angled left (off) or right (on).
	var angle := -0.5 if on else 0.5
	var handle_len := SIZE.y * 0.65
	var tip := Vector2(sin(angle) * handle_len, -cos(angle) * handle_len)
	draw_line(Vector2.ZERO, tip, ON_COLOR if on else BODY_COLOR, 6.0, true)
	draw_circle(tip, 7.0, ON_COLOR if on else BODY_COLOR)
