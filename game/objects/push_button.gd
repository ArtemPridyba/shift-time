class_name PushButton
extends Area2D
## A one-shot interaction point. The player presses E to activate it; it stays
## pressed. Pressing it sets `powered = true` on the linked door via
## `RoomTime.player_action`. Pressing again has no effect (one-way).
##
## State recorded: { "pressed": bool }
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#5a9e6f")
const PRESSED_COLOR := Color("#2d5c3a")
const SIZE := Vector2(48.0, 24.0)

@export var object_id := "button"
## The object_id of the object this button controls (older scenes).
@export var target_id := ""
## Every object this button powers.
@export var target_ids := PackedStringArray()

## Interaction radius in pixels, read from objects.json.
var _radius := 80.0

var pressed := false


func _init() -> void:
	_radius = float(Content.objects().get("button", {}).get("interact_radius_px", 80))


func _ready() -> void:
	add_to_group("temporal")


func capture_state() -> Dictionary:
	return {"pressed": pressed}


func restore_state(state: Dictionary) -> void:
	pressed = bool(state["pressed"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	pass  # Buttons do not change on their own.


func on_time_direction_changed(_direction: int) -> void:
	pass


## Buttons are not solid, so they never block the player.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## Returns the interaction candidate dict for InteractionSystem.
func interaction_candidate() -> Dictionary:
	return {"id": object_id, "position": global_position, "radius": _radius}


## Called by player.gd when the player presses `interact` near this button.
## Returns the state change to apply via RoomTime.player_action, or {} if no change.
func get_interaction_change(room_objects: Array) -> Array:
	if pressed:
		return []  # One-way: already pressed, nothing to do.
	# Change for self: mark as pressed.
	var self_change := {"id": object_id, "state": {"pressed": true}}
	var targets := InteractionSystem.target_list(target_id, target_ids)
	return [self_change] + InteractionSystem.power_changes(targets, room_objects, true)


func _draw() -> void:
	var color := PRESSED_COLOR if pressed else BODY_COLOR
	draw_rect(Rect2(-SIZE / 2.0, SIZE), color)
	# Small indicator dot.
	var dot_r := 6.0 if pressed else 8.0
	draw_circle(Vector2(0.0, -SIZE.y / 2.0 + SIZE.y * 0.4), dot_r, Color.WHITE)
