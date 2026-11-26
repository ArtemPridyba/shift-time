class_name WinchRamp
extends AnimatableBody2D
## A recorded board on a hinge, raised and lowered by a winch (level 03
## «Нить», D177). The winch plays a schedule once: `keys` from the level's
## entry (`objects.<id>.keys`), pairs [world seconds, pose], the board turning
## smoothly between them. Poses: "flat" lies across the pit as a bridge,
## "slope" leads up to the mezzanine (its tip on the mezzanine's edge),
## "up" stands upright and closes the way.
##
## The winch's brake hangs on a rope (`brake_id`, a `FireRope`). Once the rope
## has burnt through, the brake's pawl drops into the drum: the board stays at
## the angle it has now, in every frame after. Under Shift the frames bring the
## board back as it was recorded; a rope lit in the past locks the board in the
## new branch (rule «A»: before the lock the board replays what was recorded).
##
## The node sits on the hinge; the board runs along its local +x for
## `length_px`, its top face on the local x axis and the wood below it. With
## `sync_to_physics` it carries the player who stands on it, both ways.
##
## State recorded: { "clock": world ticks of the schedule played, "locked": bool }
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BOARD_COLOR := Color("#9a7550")
const RAIL_COLOR := Color("#3b3632")
const RUNG_COLOR := Color("#c39a68")
const CHAIN_COLOR := Color("#4a4e54")
const DRUM_COLOR := Color("#2e3136")
const PAWL_COLOR := Color("#d9b400")
const POSES := ["flat", "slope", "up"]

@export var object_id := "ramp"
@export var length_px := 373.0
## The rope that holds the winch's brake open.
@export var brake_id := "brake"
## The board's angle above the horizon (degrees) for each pose.
@export var slope_deg := 31.0
@export var up_deg := 90.0
## The pulley under the roof the chain runs over and the winch's drum, in the
## parent's pixels (decoration).
@export var pulley := Vector2.ZERO
@export var drum := Vector2.ZERO

var clock := 0
var locked := false
## The schedule in world ticks: [[tick, elevation degrees], ...], rising ticks.
var _keys: Array = [[0, 0.0]]
var _thickness := 14.0
var _carry_margin := 8.0
var _brake: Node = null


func _init() -> void:
	sync_to_physics = true
	_thickness = float(Content.objects().get("winch_ramp", {}).get("thickness_px", 14))
	_carry_margin = float(Content.objects().get("carry_margin_px", 8))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("world_clock")
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	var board := ConvexPolygonShape2D.new()
	board.points = _board_points()
	shape.shape = board
	_apply()


## `keys`: [[world seconds, pose], ...] (see the class comment).
func apply_settings(settings: Dictionary) -> void:
	if settings.get("keys") is Array:
		set_keys(settings["keys"] as Array)


func set_keys(keys: Array) -> void:
	var per_second := Content.world_ticks_per_second(Content.time())
	_keys.clear()
	for key: Variant in keys:
		var pair := key as Array
		_keys.append([int(round(float(pair[0]) * per_second)), pose_deg(str(pair[1]))])
	if _keys.is_empty():
		_keys.append([0, 0.0])
	_apply()


func pose_deg(pose: String) -> float:
	match pose:
		"slope":
			return slope_deg
		"up":
			return up_deg
	return 0.0


func capture_state() -> Dictionary:
	return {"clock": clock, "locked": locked}


func restore_state(state: Dictionary) -> void:
	clock = int(state["clock"])
	locked = bool(state["locked"])
	_apply()


## At the head: the winch plays on until the brake's rope has burnt through.
## The clock stops at the last key, so the room may stand still (D56).
func simulate_tick(_tick: int) -> void:
	if not locked and brake_released():
		locked = true
	if not locked:
		clock = mini(clock + 1, end_tick())
	_apply()


func on_time_direction_changed(_direction: int) -> void:
	pass


func on_world_tick(_tick: int, _recorded: bool) -> void:
	queue_redraw()


func end_tick() -> int:
	return int((_keys[_keys.size() - 1] as Array)[0])


## The board's elevation (degrees above the horizon) at schedule tick `at`.
func elevation_at(at: int) -> float:
	var first := _keys[0] as Array
	if at <= int(first[0]):
		return float(first[1])
	for i in range(1, _keys.size()):
		var a := _keys[i - 1] as Array
		var b := _keys[i] as Array
		if at <= int(b[0]):
			var span := maxi(int(b[0]) - int(a[0]), 1)
			var f := float(at - int(a[0])) / float(span)
			return lerpf(float(a[1]), float(b[1]), f * f * (3.0 - 2.0 * f))
	return float((_keys[_keys.size() - 1] as Array)[1])


func elevation() -> float:
	return elevation_at(clock)


## The tip of the board's top face in the parent's pixels, from the clock (with
## `sync_to_physics` the node's rotation comes back from the server a tick late).
func tip() -> Vector2:
	return position + Vector2.from_angle(-deg_to_rad(elevation())) * length_px


func is_flat() -> bool:
	return absf(elevation()) < 1.0


func is_slope() -> bool:
	return absf(elevation() - slope_deg) < 1.0


func is_up() -> bool:
	return absf(elevation() - up_deg) < 1.0


## True once the brake's rope has burnt through.
func brake_released() -> bool:
	var rope := _brake_rope()
	return rope != null and bool(rope.call("is_broken"))


## True when the board in `state` would overlap the player's body above the
## feet: standing on it is riding, anything deeper would crush her, so the
## world waits (section 2.3).
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var angle := -deg_to_rad(elevation_at(int(state["clock"])))
	var body := Rect2(player_rect.position, Vector2(player_rect.size.x, maxf(player_rect.size.y - _carry_margin - 6.0, 1.0)))
	var board := PackedVector2Array()
	for p in _board_points():
		board.append(position + p.rotated(angle))
	var feet := PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)])
	return not Geometry2D.intersect_polygons(board, feet).is_empty()


func _board_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, Vector2(length_px, 0.0), Vector2(length_px, _thickness), Vector2(0.0, _thickness)])


func _brake_rope() -> Node:
	if brake_id == "" or not is_inside_tree():
		return null
	if _brake != null and is_instance_valid(_brake):
		return _brake
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("torch_lightable"):
		if room.is_ancestor_of(node) and str(node.get("object_id")) == brake_id:
			_brake = node
			break
	return _brake


func _apply() -> void:
	rotation = -deg_to_rad(elevation())
	queue_redraw()


func _draw() -> void:
	# The board: two rails and rungs, its top face on the local x axis.
	draw_rect(Rect2(0.0, 0.0, length_px, _thickness), BOARD_COLOR)
	draw_line(Vector2(0.0, 1.5), Vector2(length_px, 1.5), RAIL_COLOR, 3.0)
	draw_line(Vector2(0.0, _thickness - 1.5), Vector2(length_px, _thickness - 1.5), RAIL_COLOR, 3.0)
	for i in int(length_px / 32.0):
		var x := 16.0 + i * 32.0
		draw_line(Vector2(x, 2.0), Vector2(x, _thickness - 2.0), RUNG_COLOR, 4.0)
	draw_circle(Vector2.ZERO, 7.0, RAIL_COLOR)
	if pulley == Vector2.ZERO:
		return
	# The chain from the tip over the pulley to the drum, and the drum with its
	# pawl: up while the brake's rope holds it, down in the teeth once locked.
	var to_local := func(p: Vector2) -> Vector2: return (p - position).rotated(-rotation)
	var wheel: Vector2 = to_local.call(pulley)
	var barrel: Vector2 = to_local.call(drum)
	draw_line(Vector2(length_px, 0.0), wheel, CHAIN_COLOR, 3.0)
	draw_line(wheel, barrel, CHAIN_COLOR, 3.0)
	draw_circle(wheel, 12.0, DRUM_COLOR)
	draw_circle(barrel, 22.0, DRUM_COLOR)
	var turn := elevation() / 30.0
	for k in 8:
		var a := turn + k * TAU / 8.0
		draw_line(barrel + Vector2.from_angle(a) * 14.0, barrel + Vector2.from_angle(a) * 24.0, CHAIN_COLOR, 3.0)
	var pawl := barrel + Vector2(-30.0, -18.0).rotated(-rotation)
	var tip_at := barrel + (Vector2(-18.0, -6.0) if locked else Vector2(-24.0, -30.0)).rotated(-rotation)
	draw_line(pawl, tip_at, PAWL_COLOR, 5.0)
