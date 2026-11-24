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
	if _draw_kit():
		return
	var color := PRESSED_COLOR if pressed else BODY_COLOR
	draw_rect(Rect2(-SIZE / 2.0, SIZE), color)
	# Small indicator dot.
	var dot_r := 6.0 if pressed else 8.0
	draw_circle(Vector2(0.0, -SIZE.y / 2.0 + SIZE.y * 0.4), dot_r, Color.WHITE)


## The signal-yellow floor button of the kit (D65, task Д4): the base sits on
## the lower edge of the old box, the cap on top sinks when pressed. False
## without the pictures (the old drawing then).
func _draw_kit() -> bool:
	var base := ObjectLook.picture("button_base")
	var cap := ObjectLook.picture("button_cap")
	if base == null or cap == null:
		return false
	var look := ObjectLook.of("button")
	var base_size := ObjectLook.fit(base, ObjectLook.number(look, "base_px", 52.0))
	var cap_size := ObjectLook.fit(cap, ObjectLook.number(look, "cap_px", 36.0))
	var bottom := SIZE.y / 2.0
	var sink := ObjectLook.number(look, "pressed_px", 9.0) if pressed else 0.0
	var cap_top := bottom - base_size.y - cap_size.y * 0.75 + sink
	draw_texture_rect(cap, Rect2(Vector2(-cap_size.x / 2.0, cap_top), cap_size), false)
	draw_texture_rect(base, Rect2(Vector2(-base_size.x / 2.0, bottom - base_size.y), base_size), false)
	return true
