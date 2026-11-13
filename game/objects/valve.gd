class_name Valve
extends Area2D
## A valve with a wheel: an interaction point that opens and closes the water
## source. Each press flips `open`; the target water's `source_open` follows.
## The wheel turns while the valve is open; its angle is recorded, so under
## Shift it turns back.
##
## State recorded: { "open": bool, "angle": int (thousandths of a turn, grows while open) }
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#5b616b")
const SPOKE_COLOR := Color("#c9ced6")
## Cyan belongs to mechanisms tied to time (docs/style.md).
const ACCENT_COLOR := Color("#7FE8FF")
const RADIUS := 26.0

@export var object_id := "valve"
## The object_id of the Water this valve feeds.
@export var target_id := ""
## Open when the room starts. Set the water's `source_open` the same way.
@export var open := false

var angle := 0

var _radius := 80.0
var _turn_step := 8


func _init() -> void:
	configure(Content.objects().get("valve", {}), Content.time())


func configure(valve_data: Dictionary, time_data: Dictionary) -> void:
	_radius = float(valve_data.get("interact_radius_px", 80))
	var ticks := float(valve_data.get("turn_seconds", 2)) * float(time_data.get("physics_ticks_per_second", 60))
	_turn_step = maxi(1, int(round(1000.0 / maxf(ticks, 1.0))))


func _ready() -> void:
	add_to_group("temporal")
	queue_redraw()


func capture_state() -> Dictionary:
	return {"open": open, "angle": angle}


func restore_state(state: Dictionary) -> void:
	open = bool(state["open"])
	angle = int(state["angle"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	if open:
		angle += _turn_step
		queue_redraw()


func on_time_direction_changed(_direction: int) -> void:
	pass


## A valve is not solid.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func interaction_candidate() -> Dictionary:
	return {"id": object_id, "position": global_position, "radius": _radius}


## Called through RoomTime.player_interact when the player presses `interact`
## near this valve: the changes to apply via RoomTime.player_action.
func get_interaction_change(room_objects: Array) -> Array:
	var new_open := not open
	var self_change := {"id": object_id, "state": {"open": new_open, "angle": angle}}
	if target_id == "":
		return [self_change]
	for obj: Variant in room_objects:
		if obj is Object and (obj as Object).has_method("capture_state") and str((obj as Object).get("object_id")) == target_id:
			var water_state: Dictionary = ((obj as Object).call("capture_state") as Dictionary).duplicate(true)
			water_state["source_open"] = new_open
			return [self_change, {"id": target_id, "state": water_state}]
	return [self_change]


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, BODY_COLOR)
	if open:
		draw_arc(Vector2.ZERO, RADIUS + 4.0, 0.0, TAU, 32, ACCENT_COLOR, 3.0)
	var turn := float(angle) / 1000.0 * TAU
	for i in 3:
		var a := turn + float(i) * TAU / 3.0
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * RADIUS, SPOKE_COLOR, 4.0)
