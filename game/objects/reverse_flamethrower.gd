class_name ReverseFlamethrower
extends CharacterBody2D
## The reverse flamethrower (task 2.7): an item the player may find in a room.
## E picks it up, holding F fires it the way the player faces, E drops it (an
## interaction point that is nearer, a lever, wins over the drop).
##
## Two halves:
## - Its body is recorded like everything but the player: lying in the room it
##   falls at the head, and under Shift it moves back along its recorded past.
##   In the player's hands it stays with the player and ignores the frames
##   (design rules: what the player holds stays with the player). Picking up
##   and dropping are the player's interference; a drop also rewrites the
##   item's earlier frames to where it was let go (`TimeWorld.rewrite_past`),
##   so under Shift it rests there instead of jumping to an old place.
## - Its fire is live (group `live`), never recorded: every tick `act()` looks
##   at the direction of time. In normal time it sucks fire in and puts out a
##   burning wood zone; under Shift it throws fire and lights a whole one. The
##   change goes through `RoomTime.live_action`, and only while the zone is not
##   yet in that state, so the effect comes once per contact; under Shift the
##   cursor moves back each tick, so the zone is lit again on every frame the
##   jet touches it, and it stays lit when Shift is released.
## A change of the direction of time stops the jet until F is pressed again:
## otherwise releasing Shift with F held would at once put out the fire it
## just lit (and pressing Shift while it sucks would light what it put out).
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BODY_COLOR := Color("#8c939c")
const TANK_COLOR := Color("#5d646d")
const ACCENT_COLOR := Color("#7FE8FF")
const FIRE_COLOR := Color("#ff8c33")
const SUCK_COLOR := Color("#c9d3da")
const SIZE := Vector2(48, 20)
## Where the item sits in the hands, from the player's feet (facing right).
const HAND := Vector2(26, -40)

@export var object_id := "flamethrower"
## The way the nozzle points while the item lies in the room.
@export_enum("Left:-1", "Right:1") var facing := 1

## In the player's hands. Live while held: the frames never take it away.
var held := false
## Pixels per second downwards while it falls.
var fall_speed := 0.0
## F held this tick and the item in the hands (live, never recorded).
var firing := false
## The direction of time the jet acted by last.
var fire_direction := 1
## The direction flipped while F was held: the jet stays off until F is let go.
var _stalled := false
var time_direction := 1

var _radius := 80.0
var _reach := 224.0
var _jet := 56.0
var _follow := 24.0
var _gravity := 2200.0
var _max_fall := 1200.0
var _per_second := 60.0
## The item's own clock for the look of the jet, in its own (live) time.
var _live_t := 0.0


func _init() -> void:
	# After the player (0): the item follows the hands where the player moved.
	process_physics_priority = 10
	var data: Dictionary = Content.objects().get("flamethrower", {})
	_radius = float(data.get("interact_radius_px", 80))
	_reach = float(data.get("reach_px", 224))
	_jet = float(data.get("jet_px", 56))
	_follow = float(data.get("follow_px", 24))
	_gravity = float(data.get("gravity", 2200))
	_max_fall = float(data.get("max_fall_speed", 1200))
	_per_second = float(Content.time().get("physics_ticks_per_second", 60))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("live")
	add_to_group("carried")


func capture_state() -> Dictionary:
	return {"position": position, "fall": fall_speed, "held": held, "facing": facing}


## In the hands the frames are ignored, unless this is the drop itself
## (`let_go` in the state, from `get_interaction_change`).
func restore_state(state: Dictionary) -> void:
	if held and not bool(state.get("let_go", false)):
		return
	held = bool(state["held"])
	position = state["position"]
	fall_speed = float(state["fall"])
	facing = -1 if int(state["facing"]) < 0 else 1
	queue_redraw()


## Falls when lying; in the hands nothing. The fall needs the physics space,
## so it waits for a real physics tick (not the prelude run in `_ready`).
func simulate_tick(_tick: int) -> void:
	if held or not is_inside_tree() or not Engine.is_in_physics_frame():
		return
	fall_speed = minf(fall_speed + _gravity / _per_second, _max_fall)
	velocity = Vector2(0.0, fall_speed)
	move_and_slide()
	if is_on_floor():
		fall_speed = 0.0
	velocity = Vector2.ZERO


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## Not solid for the player: it never crushes.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


## Lying: a pick-up point. In the hands: the drop, which counts only when no
## other interaction point is in reach (`InteractionSystem`).
func interaction_candidate() -> Dictionary:
	if held:
		return {"id": object_id, "position": global_position, "radius": 1.0e9, "fallback": true}
	return {"id": object_id, "position": global_position, "radius": _radius}


func get_interaction_change(_objects: Array) -> Array:
	if held:
		return [{"id": object_id, "rewrite_past": true,
			"state": {"held": false, "let_go": true, "fall": 0.0, "position": position, "facing": facing}}]
	return [{"id": object_id, "state": {"held": true}}]


## The room's reset: out of the hands, so the first frame can put it back.
func forget_hands() -> void:
	held = false
	firing = false
	_stalled = false


## Called by RoomTime every tick after the world moved (group `live`):
## `room` offers `live_action` and `cursor()`.
func act(room: Node, direction: int) -> void:
	var pressed := held and Input.is_action_pressed("use_item")
	if not pressed:
		_stalled = false
	elif firing and direction != fire_direction:
		_stalled = true
	fire_direction = direction
	firing = pressed and not _stalled
	if not firing:
		return
	var jet := jet_rect()
	var room_root := room.get_parent()
	for node in get_tree().get_nodes_in_group("flammable"):
		if room_root != null and not room_root.is_ancestor_of(node):
			continue
		if not node.has_method("global_rect") or not jet.intersects(node.call("global_rect")):
			continue
		var change: Dictionary
		if direction < 0:
			change = node.call("ignite_change")
		else:
			change = node.call("douse_change", int(room.call("cursor")))
		if not change.is_empty():
			room.call("live_action", str(node.get("object_id")), change)


## The jet in global pixels: from the nozzle, `reach_px` long the way it points.
func jet_rect() -> Rect2:
	var nozzle := global_position + Vector2(facing * SIZE.x / 2.0, -SIZE.y / 2.0)
	var x := nozzle.x if facing > 0 else nozzle.x - _reach
	return Rect2(Vector2(x, nozzle.y - _jet / 2.0), Vector2(_reach, _jet))


func _physics_process(_delta: float) -> void:
	if not held:
		return
	var player := _player()
	if player == null:
		return
	facing = -1 if float(player.call("facing")) < 0.0 else 1
	var target: Vector2 = player.position + Vector2(HAND.x * facing, HAND.y)
	position = position.move_toward(target, _follow)
	queue_redraw()


func _process(delta: float) -> void:
	_live_t += delta
	if firing:
		queue_redraw()


func _player() -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_parent() == parent:
			return node as Node2D
	return null


func _draw() -> void:
	var f := float(facing)
	# The tank, the barrel towards the nozzle, the cyan time mark.
	draw_rect(Rect2(Vector2(-SIZE.x / 2.0, -SIZE.y), Vector2(SIZE.x * 0.45, SIZE.y)), TANK_COLOR)
	var barrel := Rect2(Vector2(-SIZE.x * 0.05, -SIZE.y * 0.7), Vector2(SIZE.x * 0.55, SIZE.y * 0.4))
	if f < 0.0:
		barrel.position.x = -barrel.end.x
	draw_rect(barrel, BODY_COLOR)
	draw_rect(Rect2(Vector2(-SIZE.x * 0.4, -SIZE.y * 0.75), Vector2(SIZE.x * 0.3, 4.0)), ACCENT_COLOR)
	if not firing:
		return
	# The jet: under Shift fire flies out of the nozzle; in normal time air
	# and fire stream into it. Its own time, so it always reads the way it acts.
	var nozzle := Vector2(f * SIZE.x / 2.0, -SIZE.y / 2.0)
	var out := fire_direction < 0
	for i in 12:
		var along := fposmod(_live_t * 2.2 + i / 12.0, 1.0)
		var d := along if out else 1.0 - along
		var p := nozzle + Vector2(f * d * _reach, sin(_live_t * 11.0 + i) * _jet * 0.35 * d)
		var color := FIRE_COLOR if out else SUCK_COLOR
		draw_circle(p, 3.0 + 7.0 * d, Color(color, 0.85 * (1.0 - d * 0.6)))
