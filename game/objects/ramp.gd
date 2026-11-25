class_name Ramp
extends AnimatableBody2D
## A recorded ramp on a hinge (level 03, D155): a rope from a wood zone (the
## barricade) over a pulley holds it upright. When the zone has burnt, the
## rope is gone and the ramp falls about its hinge until it lies as a sloped
## bridge; under Shift the frames lift it back, and it carries the player who
## stands on it (`sync_to_physics`, as a platform). The fall counts only in
## `simulate_tick`, so it is replayed, never re-simulated.
##
## The node sits on the hinge. The board runs along its local +x for
## `length_px`; its top face is the local x axis, the wood below it, so lying
## it joins the floor at the hinge and the ledge at its tip without a step.
## The angle goes from `up_deg` (standing) to `rest_deg` (lying) as the square
## of the fall's time, like a lamp falling.
##
## The rope is decoration drawn from the watched zone's recorded state: whole
## while the zone is whole, glowing while it burns, two loose ends once it has
## burnt.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const BOARD_COLOR := Color("#9a7550")
const RAIL_COLOR := Color("#3b3632")
const RUNG_COLOR := Color("#c39a68")
const ROPE_COLOR := Color("#c8b083")
const ROPE_HOT_COLOR := Color("#ff8a3d")
const PULLEY_COLOR := Color("#3a3c40")

@export var object_id := "ramp"
## The wood zone whose fire burns the rope.
@export var watch_id := "barricade"
@export var length_px := 288.0
## Standing and lying angles of the board (degrees, Godot rotation).
@export var up_deg := -90.0
@export var rest_deg := -153.4
## Where the rope is tied and the pulley it runs over, in the parent's pixels.
@export var rope_anchor := Vector2.ZERO
@export var pulley := Vector2.ZERO

## Ticks since the rope let go; 0 while it holds.
var fall := 0
var time_direction := 1

var _fall_ticks := 48
var _thickness := 14.0
var _zone: Node = null


func _init() -> void:
	sync_to_physics = true
	var data: Dictionary = Content.objects().get("ramp", {})
	var ticks := Content.world_ticks_per_second(Content.time())
	_fall_ticks = maxi(int(round(float(data.get("fall_seconds", 0.8)) * ticks)), 1)
	_thickness = float(data.get("thickness_px", 14))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("world_clock")
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	var board := ConvexPolygonShape2D.new()
	board.points = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(length_px, 0.0),
		Vector2(length_px, -_thickness), Vector2(0.0, -_thickness)])
	shape.shape = board
	_apply()


func capture_state() -> Dictionary:
	return {"fall": fall}


func restore_state(state: Dictionary) -> void:
	fall = int(state["fall"])
	_apply()


func simulate_tick(_tick: int) -> void:
	if fall > 0 or rope_gone():
		fall = mini(fall + 1, _fall_ticks)
	_apply()


func on_time_direction_changed(direction: int) -> void:
	time_direction = direction


## The ramp swings away from where the player can stand; it never crushes.
func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func on_world_tick(_tick: int, _recorded: bool) -> void:
	queue_redraw()


## 0 standing, 1 lying.
func fallen() -> float:
	return float(fall) / float(_fall_ticks)


func is_lying() -> bool:
	return fall >= _fall_ticks


## The board's angle (radians) at fall `ticks`.
func angle_at(ticks: int) -> float:
	var f := clampf(float(ticks) / float(_fall_ticks), 0.0, 1.0)
	return deg_to_rad(lerpf(up_deg, rest_deg, f * f))


## The tip of the board in the parent's pixels, from the fall, not from the
## node: with `sync_to_physics` the server writes the rotation back a step late.
func tip() -> Vector2:
	return position + Vector2.from_angle(angle_at(fall)) * length_px


## True once the watched zone has burnt: the rope burnt with it.
func rope_gone() -> bool:
	var zone := _watched()
	return zone != null and int((zone.call("capture_state") as Dictionary)["phase"]) == WoodBurn.Phase.BURNT


func _watched() -> Node:
	if watch_id == "" or not is_inside_tree():
		return null
	if _zone != null and is_instance_valid(_zone):
		return _zone
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("flammable"):
		if room.is_ancestor_of(node) and str(node.get("object_id")) == watch_id:
			_zone = node
			break
	return _zone


func _apply() -> void:
	rotation = angle_at(fall)
	queue_redraw()


func _draw() -> void:
	# The board: two rails and rungs, its top face on the local x axis.
	draw_rect(Rect2(0.0, -_thickness, length_px, _thickness), BOARD_COLOR)
	draw_line(Vector2(0.0, -1.5), Vector2(length_px, -1.5), RAIL_COLOR, 3.0)
	draw_line(Vector2(0.0, -_thickness + 1.5), Vector2(length_px, -_thickness + 1.5), RAIL_COLOR, 3.0)
	var rungs := int(length_px / 32.0)
	for i in rungs:
		var x := 16.0 + i * 32.0
		draw_line(Vector2(x, -2.0), Vector2(x, -_thickness + 2.0), RUNG_COLOR, 4.0)
	draw_circle(Vector2.ZERO, 6.0, RAIL_COLOR)
	_draw_rope()


func _draw_rope() -> void:
	if pulley == Vector2.ZERO:
		return
	var to_local := func(p: Vector2) -> Vector2: return (p - position).rotated(-rotation)
	var wheel: Vector2 = to_local.call(pulley)
	draw_circle(wheel, 10.0, PULLEY_COLOR)
	draw_circle(wheel, 3.0, RAIL_COLOR)
	var zone := _watched()
	var phase := WoodBurn.Phase.WHOLE
	if zone != null:
		phase = int((zone.call("capture_state") as Dictionary)["phase"]) as WoodBurn.Phase
	var end := Vector2(length_px, -_thickness / 2.0)
	if phase == WoodBurn.Phase.BURNT or fall > 0:
		# Two loose ends: one hangs from the pulley, a stub from the tip.
		draw_line(wheel, wheel + (Vector2.DOWN * 40.0).rotated(-rotation), ROPE_COLOR, 3.0)
		draw_line(end, end + Vector2(-18.0, 0.0), ROPE_COLOR, 3.0)
		return
	var color := ROPE_COLOR
	if phase == WoodBurn.Phase.BURNING:
		var t := float(Time.get_ticks_msec()) / 1000.0
		color = ROPE_COLOR.lerp(ROPE_HOT_COLOR, 0.5 + 0.3 * sin(t * 9.0))
	draw_line(to_local.call(rope_anchor), wheel, color, 3.0)
	draw_line(wheel, end, ROPE_COLOR, 3.0)
