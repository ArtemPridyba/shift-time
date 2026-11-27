class_name Hopper
extends Node2D
## The hopper of pig iron over the pit of level 04 (card docs/levels/04.md,
## D168): a recorded object. The launch of the minecart pulls its gate open by
## a rope (`open`): after `delay_seconds` the pigs pour out one by one for
## `pour_seconds` and fall into the pit just before the cart gets there. Under
## Shift the pour rewinds: the pigs fly up out of the pit back into the hopper,
## and those that pass through the cart's body stay in it.
##
## A pig the cart caught is out of time with the cart (D216): it leaves the
## stream at every world time, so a rewind never shows it twice. The hopper
## keeps the caught ones apart (`take`), never in history; nothing recorded
## depends on them, so a catch cuts no branch. A room reset forgets them.
##
## State recorded: { "pour": int (world ticks since it opened, -1 closed; it
## stops counting once the last pig is gone), "batch": int (how many times it
## opened; names the pigs of each pour) }.
##
## Numbers: `hopper` in data/objects.json. Temporal object contract:
## docs/architecture.md, section 4.1.

const BOX_COLOR := Color("#4a4f57")
const EDGE_COLOR := Color("#23262b")
const GATE_COLOR := Color("#d9b400")
const PIG_COLOR := Color("#7d6a5a")
const PIG_EDGE := Color("#2e2620")
const ROPE_COLOR := Color("#8a7a5a")

@export var object_id := "hopper"
## From the gate down to the bottom of the pit, where a pig is gone.
@export var fall_px := 480.0
## The box above the gate, in pixels: width and height.
@export var box := Vector2(128, 96)

var pour := -1
var batch := 0
var stream: StoneStream

## Keys "batch:i" of the pigs the cart took; out of time, never recorded.
var _taken := {}
var _params := {}


func _init() -> void:
	_params = Content.objects().get("hopper", {})
	stream = StoneStream.from_data(_params, Content.time(), fall_px)


func _ready() -> void:
	stream = StoneStream.from_data(_params, Content.time(), fall_px)
	add_to_group("temporal")
	add_to_group("hopper")


func capture_state() -> Dictionary:
	return {"pour": pour, "batch": batch}


func restore_state(state: Dictionary) -> void:
	pour = int(state["pour"])
	batch = int(state["batch"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	if pour >= 0 and pour < stream.end_tick():
		pour += 1
	queue_redraw()


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## The launch pulls the rope: a new pour starts now (`room.apply_change`;
## the room is an argument, never kept).
func open(room: Object) -> void:
	room.call("apply_change", object_id, {"pour": 0, "batch": batch + 1})


## True while the gate stands open (from the rope's pull until the last pig
## left).
func is_pouring() -> bool:
	return pour >= 0 and stream.waiting(stream.count - 1, pour)


## The pigs in the air now that nobody took: [{ "key": String, "position":
## Vector2 global }].
func pigs_in_air() -> Array:
	var result: Array = []
	for i in stream.count:
		if stream.in_air(i, pour) and not _taken.has(_key(i)):
			result.append({"key": _key(i), "position": to_global(stream.offset(i, pour))})
	return result


## The cart took this pig: it is gone from the stream at every world time.
func take(key: String) -> void:
	_taken[key] = true
	queue_redraw()


func taken_count() -> int:
	return _taken.size()


## Back to the room as loaded: no pig was ever taken.
func forget_taken() -> void:
	_taken.clear()
	queue_redraw()


func _key(i: int) -> String:
	return "%d:%d" % [batch, i]


func _draw() -> void:
	var w := box.x
	var h := box.y
	# The box narrows to the gate at the bottom.
	var outline := PackedVector2Array([
		Vector2(-w / 2.0, -h), Vector2(w / 2.0, -h), Vector2(w / 2.0, -h * 0.45),
		Vector2(stream.spread_px / 2.0 + 10.0, 0.0), Vector2(-stream.spread_px / 2.0 - 10.0, 0.0),
		Vector2(-w / 2.0, -h * 0.45)])
	draw_colored_polygon(outline, BOX_COLOR)
	draw_polyline(outline + PackedVector2Array([outline[0]]), EDGE_COLOR, 3.0)
	# The pigs still waiting, stacked in the box.
	var waiting := 0
	for i in stream.count:
		if stream.waiting(i, pour):
			waiting += 1
	# The heap shows how full it is: at most four rows fit in the box.
	var shown := ceili(float(waiting) * 16.0 / float(stream.count))
	for i in shown:
		var row := i / 4
		var col := i % 4
		var at := Vector2(-w / 2.0 + 18.0 + col * 26.0, -h * 0.5 - row * 12.0)
		_draw_pig(at)
	# The gate: two yellow flaps, open while it pours.
	var open := 1.0 if is_pouring() else 0.0
	var half := stream.spread_px / 2.0 + 10.0
	draw_line(Vector2(-half, 0.0), Vector2(-half, 0.0) + Vector2(half, 0.0).rotated(open * 1.2), GATE_COLOR, 5.0)
	draw_line(Vector2(half, 0.0), Vector2(half, 0.0) + Vector2(-half, 0.0).rotated(-open * 1.2), GATE_COLOR, 5.0)
	# The rope from the gate up to the walkway and along it to the launch.
	draw_line(Vector2(half, -4.0), Vector2(w / 2.0 + 6.0, -h), ROPE_COLOR, 2.0)
	# The pigs in the air.
	for i in stream.count:
		if stream.in_air(i, pour) and not _taken.has(_key(i)):
			_draw_pig(stream.offset(i, pour))


func _draw_pig(at: Vector2) -> void:
	var size := float(_params.get("pig_px", 18.0))
	var rect := Rect2(at - Vector2(size / 2.0, size / 4.0), Vector2(size, size / 2.0))
	draw_rect(rect, PIG_COLOR)
	draw_rect(rect, PIG_EDGE, false, 2.0)
