class_name TimePlate
extends Node2D
## A pressure plate that takes the direction of time (level 08, D118). The
## player presses it by stepping onto it, never with a key. Stepped on in
## normal time, it closes its shutters; stepped on with Shift held, it sends
## the closing into the past: once time runs forward, they open.
##
## Only the step counts: standing on the plate and pressing Shift does nothing,
## the plate works again after the player steps off. A step left of the head
## of history is interference (`RoomTime.apply_change` branches the room); at
## the head it is ordinary recording.
##
## The flag beside the plate shows what the last step did: down, the shutters
## close; up, they open. It is recorded, so it rewinds with the world.
##
## State recorded: { "mark": int } — 0 never stepped on, +1 closes, -1 opens.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const MARK_NONE := 0
const MARK_CLOSE := 1
const MARK_OPEN := -1
const BODY_COLOR := Color("#d9b400")
const EDGE_COLOR := Color("#5a4a10")
const FLAG_COLOR := Color("#e8e2d0")
const POST_COLOR := Color("#3c4148")

@export var object_id := "plate"
## The shutters this plate drives.
@export var target_ids := PackedStringArray()
## Width of the plate in pixels; its top is at the node's position.
@export var width := 192.0
## The letter shared with its shutters (blockout look).
@export var label := ""

var mark := MARK_NONE

## Whether the player stood on the plate last tick. Not recorded: the step is
## the player's, and the player is never in history.
var _touching := false
var _tolerance := 6.0


func _init() -> void:
	_tolerance = float(Content.objects().get("time_plate", {}).get("contact_px", 6))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("plate")


func capture_state() -> Dictionary:
	return {"mark": mark}


func restore_state(state: Dictionary) -> void:
	mark = int(state["mark"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	pass  # The plate changes only by a step.


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## True when the player's feet (a rect in the parent's coordinates) stand on
## the plate.
func touches(player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var feet := player_rect.end.y
	var left := position.x - width / 2.0
	var right := position.x + width / 2.0
	return absf(feet - position.y) <= _tolerance and player_rect.end.x > left and player_rect.position.x < right


## The state changes of a step in `direction`: the plate's flag and every
## shutter's target. `[{id, state}]`, partial states.
func step_changes(direction: int) -> Array:
	var closes := direction >= 0
	var changes: Array = [{"id": object_id, "state": {"mark": MARK_CLOSE if closes else MARK_OPEN}}]
	for id in target_ids:
		changes.append({"id": id, "state": {"target": Shutter.CLOSED_MAX if closes else 0}})
	return changes


## Called by RoomTime after every tick with the player's rect. A new step
## applies the plate's changes through `room.apply_change`; the room is an
## argument, never kept.
func sense(room: Object, direction: int, player_rect: Rect2) -> void:
	var now := touches(player_rect)
	if now and not _touching:
		for change: Variant in step_changes(direction):
			var c := change as Dictionary
			room.call("apply_change", str(c["id"]), c["state"])
	_touching = now


## Back to the room as loaded: no step in progress.
func forget_step() -> void:
	_touching = false


func _draw() -> void:
	var rect := Rect2(Vector2(-width / 2.0, -6.0), Vector2(width, 6.0))
	draw_rect(rect, BODY_COLOR)
	draw_rect(rect, EDGE_COLOR, false, 2.0)
	for i in range(1, 6):
		var x := -width / 2.0 + width * i / 6.0
		draw_line(Vector2(x, -6.0), Vector2(x, 0.0), EDGE_COLOR, 2.0)
	# The flag on a post at the plate's left end: down closes, up opens.
	var post := Vector2(-width / 2.0 - 10.0, 0.0)
	draw_line(post, post + Vector2(0.0, -48.0), POST_COLOR, 3.0)
	if mark != MARK_NONE:
		var tip := post + Vector2(0.0, -16.0 if mark == MARK_CLOSE else -48.0)
		var dir := 1.0 if mark == MARK_CLOSE else -1.0
		var arrow := PackedVector2Array([tip + Vector2(2.0, 0.0), tip + Vector2(18.0, -dir * 14.0), tip + Vector2(-14.0, -dir * 14.0)])
		draw_colored_polygon(arrow, FLAG_COLOR)
	if label != "":
		draw_string(ThemeDB.fallback_font, Vector2(-6.0, 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, BODY_COLOR)
