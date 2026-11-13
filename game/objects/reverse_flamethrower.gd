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
const DARK_COLOR := Color("#4a5058")
const TANK_COLOR := Color("#5d646d")
const RUST_COLOR := Color("#7a4a32")
const ACCENT_COLOR := Color("#7FE8FF")
const NOZZLE_HOT_COLOR := Color("#ff9a4a")
const JET_SHADER := preload("res://objects/flamethrower_jet.gdshader")
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
var _jet_rect: ColorRect


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
	_jet_rect = ColorRect.new()
	_jet_rect.name = "Jet"
	_jet_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jet_rect.size = Vector2(_reach, _jet)
	var mat := ShaderMaterial.new()
	mat.shader = JET_SHADER
	mat.set_shader_parameter("rect_size", _jet_rect.size)
	mat.set_shader_parameter("speed_px", float(Content.objects().get("fire_look", {}).get("jet_speed_px", 420)))
	_jet_rect.material = mat
	_jet_rect.visible = false
	add_child(_jet_rect)


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
	_update_jet()
	queue_redraw()


## The jet shader from the nozzle the way the item points: fire out under
## Shift, air and fire pulled in in normal time, in the item's own time.
func _update_jet() -> void:
	if _jet_rect == null:
		return
	_jet_rect.visible = firing
	if not firing:
		return
	var nozzle := Vector2(facing * SIZE.x / 2.0, -SIZE.y / 2.0)
	_jet_rect.position = nozzle + Vector2(0.0, -_jet / 2.0)
	_jet_rect.scale = Vector2(float(facing), 1.0)
	var mat := _jet_rect.material as ShaderMaterial
	mat.set_shader_parameter("time", _live_t)
	mat.set_shader_parameter("flow", 1.0 if fire_direction < 0 else -1.0)


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
	# A worn tank on the back end, a barrel with a bell nozzle to the front,
	# a grip below, the cyan time ring and its arrow (it points the way the
	# jet acts: out under Shift, in in normal time).
	var tank_centre := Vector2(-f * SIZE.x * 0.26, -SIZE.y * 0.5)
	draw_circle(tank_centre, SIZE.y * 0.5, TANK_COLOR)
	draw_rect(Rect2(tank_centre - Vector2(SIZE.y * 0.5, SIZE.y * 0.5), Vector2(SIZE.y, SIZE.y * 0.3)), TANK_COLOR.lightened(0.08))
	draw_circle(tank_centre + Vector2(-f * 4.0, 5.0), 2.5, RUST_COLOR)
	var barrel_from := tank_centre + Vector2(f * SIZE.y * 0.3, -2.0)
	var barrel_to := Vector2(f * SIZE.x * 0.38, -SIZE.y * 0.55)
	draw_line(barrel_from, barrel_to, BODY_COLOR, 6.0, true)
	var mouth := Vector2(f * SIZE.x * 0.5, -SIZE.y * 0.55)
	draw_colored_polygon(PackedVector2Array([
		barrel_to + Vector2(0.0, -3.0), mouth + Vector2(0.0, -6.0),
		mouth + Vector2(0.0, 6.0), barrel_to + Vector2(0.0, 3.0)]), DARK_COLOR)
	if firing and fire_direction < 0:
		draw_circle(mouth, 4.0, Color(NOZZLE_HOT_COLOR, 0.6 + 0.4 * sin(_live_t * 30.0)))
	draw_line(tank_centre + Vector2(f * 6.0, SIZE.y * 0.3), tank_centre + Vector2(f * 10.0, SIZE.y * 0.65), DARK_COLOR, 4.0, true)
	var ring := tank_centre + Vector2(f * SIZE.y * 0.42, -1.0)
	draw_arc(ring, 5.0, 0.0, TAU, 16, ACCENT_COLOR, 2.0, true)
	var way := f if not firing or fire_direction < 0 else -f
	var pulse := 1.0 + (0.3 * sin(_live_t * 12.0) if firing else 0.0)
	draw_colored_polygon(PackedVector2Array([
		ring + Vector2(way * 3.0 * pulse, 0.0), ring + Vector2(-way * 2.0, -2.5), ring + Vector2(-way * 2.0, 2.5)]), ACCENT_COLOR)
