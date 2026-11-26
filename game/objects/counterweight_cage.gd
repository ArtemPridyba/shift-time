class_name CounterweightCage
extends AnimatableBody2D
## A recorded cage in a shaft with a counterweight (level 03 «Нить», D177). The
## cast-iron weight is heavier than the cage, so a stop rope (`rope_id`, a
## `FireRope`) ties the cage down at the bottom of the shaft. Once the rope has
## burnt through, the weight falls and pulls the cage up `travel_px` in
## `rise_seconds` (world seconds, like a platform, D96), easing in and out.
## Under Shift the frames bring the cage down and the weight up again; a cage
## that left without her comes back down under Shift, and the replay lifts her
## (rule «A»).
##
## The node is the middle of the cage's floor at the bottom; its top face is
## the node's y. Only the floor is solid; the bars, the cable over the pulley
## and the weight running down behind the cage are drawn.
##
## State recorded: { "rise": int } — -1 while the rope holds, else the ticks
## since it broke, up to the ride's length.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const FLOOR_COLOR := Color("#d9b400")
const BAR_COLOR := Color("#5a5040")
const CABLE_COLOR := Color("#4a4e54")
const WEIGHT_COLOR := Color("#26282c")
const WEIGHT_EDGE := Color("#4a4e54")

@export var object_id := "cage"
@export var rope_id := "stop_rope"
@export var width := 128.0
@export var travel_px := 384.0
## The pulley at the top of the shaft, from the node (decoration).
@export var pulley_from_floor := Vector2(0.0, -620.0)

var rise := -1
var _rise_ticks := 120
var _floor_px := 20.0
var _bars_px := 150.0
var _carry_margin := 8.0
var _base := Vector2.ZERO
var _rope: Node = null


func _init() -> void:
	sync_to_physics = true
	var data: Dictionary = Content.objects().get("cage", {})
	var ticks := Content.world_ticks_per_second(Content.time())
	_rise_ticks = maxi(int(round(float(data.get("rise_seconds", 2)) * ticks)), 1)
	_floor_px = float(data.get("floor_px", 20))
	_bars_px = float(data.get("bars_px", 150))
	_carry_margin = float(Content.objects().get("carry_margin_px", 8))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("world_clock")
	_base = position
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	var box := RectangleShape2D.new()
	box.size = Vector2(width, _floor_px)
	shape.shape = box
	shape.position = Vector2(0.0, _floor_px / 2.0)
	_apply()


func apply_settings(settings: Dictionary) -> void:
	if settings.has("rise_seconds"):
		_rise_ticks = maxi(int(round(float(settings["rise_seconds"]) * Content.world_ticks_per_second(Content.time()))), 1)


func capture_state() -> Dictionary:
	return {"rise": rise}


func restore_state(state: Dictionary) -> void:
	rise = int(state["rise"])
	_apply()


func simulate_tick(_tick: int) -> void:
	if rise < 0:
		if rope_broken():
			rise = 0
	else:
		rise = mini(rise + 1, _rise_ticks)
	_apply()


func on_time_direction_changed(_direction: int) -> void:
	pass


func on_world_tick(_tick: int, _recorded: bool) -> void:
	queue_redraw()


## 0 at the bottom, 1 at the top.
func risen_at(at: int) -> float:
	if at <= 0:
		return 0.0
	var f := clampf(float(at) / float(_rise_ticks), 0.0, 1.0)
	return f * f * (3.0 - 2.0 * f)


func risen() -> float:
	return risen_at(rise)


func is_up() -> bool:
	return rise >= _rise_ticks


## The floor's top face in the parent's pixels at `rise_ticks`.
func floor_y_at(rise_ticks: int) -> float:
	return _base.y - travel_px * risen_at(rise_ticks)


func floor_rect_at(rise_ticks: int) -> Rect2:
	return Rect2(Vector2(_base.x - width / 2.0, floor_y_at(rise_ticks)), Vector2(width, _floor_px))


func rope_broken() -> bool:
	var rope := _stop_rope()
	return rope != null and bool(rope.call("is_broken"))


## The floor coming down onto the player would crush her: the world waits.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var step := travel_px * 1.5 / float(_rise_ticks)
	var body := Rect2(player_rect.position, Vector2(player_rect.size.x, maxf(player_rect.size.y - _carry_margin - ceilf(step), 1.0)))
	return floor_rect_at(int(state["rise"])).intersects(body)


func _stop_rope() -> Node:
	if rope_id == "" or not is_inside_tree():
		return null
	if _rope != null and is_instance_valid(_rope):
		return _rope
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("torch_lightable"):
		if room.is_ancestor_of(node) and str(node.get("object_id")) == rope_id:
			_rope = node
			break
	return _rope


func _apply() -> void:
	position = Vector2(_base.x, floor_y_at(rise))
	queue_redraw()


func _draw() -> void:
	var half := width / 2.0
	# Bars behind her, the roof frame and the floor.
	for k in 5:
		var x := -half + 6.0 + k * (width - 12.0) / 4.0
		draw_line(Vector2(x, 0.0), Vector2(x, -_bars_px), BAR_COLOR, 3.0)
	draw_line(Vector2(-half, -_bars_px), Vector2(half, -_bars_px), BAR_COLOR, 4.0)
	draw_rect(Rect2(Vector2(-half, 0.0), Vector2(width, _floor_px)), FLOOR_COLOR)
	draw_rect(Rect2(Vector2(-half, 0.0), Vector2(width, _floor_px)), BAR_COLOR, false, 2.0)
	# The cable from the roof of the cage over the pulley down to the weight,
	# which falls as the cage rises: they pass each other in the shaft.
	var lift := travel_px * risen()
	var wheel := pulley_from_floor + Vector2(0.0, lift)
	var weight_top := Vector2(half - 14.0, wheel.y + 40.0 + lift)
	draw_line(Vector2(0.0, -_bars_px), wheel + Vector2(-12.0, 0.0), CABLE_COLOR, 3.0)
	draw_circle(wheel, 14.0, CABLE_COLOR)
	draw_line(wheel + Vector2(12.0, 0.0), Vector2(weight_top.x, weight_top.y), CABLE_COLOR, 3.0)
	var w := Rect2(weight_top + Vector2(-12.0, 0.0), Vector2(24.0, 70.0))
	draw_rect(w, WEIGHT_COLOR)
	draw_rect(w, WEIGHT_EDGE, false, 2.0)
