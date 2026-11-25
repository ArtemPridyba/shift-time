class_name ReverseJet
extends Node2D
## The jet out of a sluice when its tank's drain runs backwards (level 02,
## D161). Forward the tank drains quietly into the sluice; under Shift the
## water comes back out of it as a jet that flies straight across the tank,
## while the surface is still below the sluice. It is live: never recorded,
## it acts by the current direction of time, like the reverse flamethrower.
##
## The jet's front flies `speed_px` a second from the node (the mouth of the
## sluice) along `direction`, up to `length_px` (the bars at the far side).
## The heroine and the floats in its way stop it there: it splashes on them
## and pushes the heroine gently (`push_px_per_second`). A jet that reaches
## the end hits the lever behind the bars: through `RoomTime.live_action`
## the lever goes on and powers its targets, once, while it is still off.
## The hit is an interference: a branch of history (rule «A»).
##
## Numbers: `reverse_jet` of `data/objects.json`.

const WATER_COLOR := Color(0.74, 0.82, 0.86, 0.85)
const DROPS := 7

## The tank whose drain the jet plays backwards, by path from this node.
@export var water_path: NodePath
## The lever behind the bars, by path from this node.
@export var lever_path: NodePath
## -1 flies left, +1 right.
@export var direction := -1
## From the mouth of the sluice to the bars, pixels.
@export var length_px := 576.0

## How far the front has flown, pixels; 0 while the jet is off.
var reach := 0.0
## True on a tick when something stood in the jet's way.
var blocked := false
var _speed := 900.0
var _push := 40.0
var _thickness := 14.0
var _last_cursor := -1
var _live_tick := 0


func _init() -> void:
	var data: Dictionary = Content.objects().get("reverse_jet", {})
	_speed = float(data.get("speed_px", _speed))
	_push = float(data.get("push_px_per_second", _push))
	_thickness = float(data.get("thickness_px", _thickness))


func _ready() -> void:
	add_to_group("live")


## Called by RoomTime every tick after the world moved (group `live`).
func act(room: Node, time_direction: int) -> void:
	_live_tick += 1
	var cursor := int(room.call("cursor"))
	var moved := _last_cursor >= 0 and cursor < _last_cursor
	_last_cursor = cursor
	var tank := get_node_or_null(water_path) as Water
	if tank == null or not runs(time_direction, moved, tank.flow, tank.surface_global_y(), global_position.y):
		reach = 0.0
		blocked = false
		queue_redraw()
		return
	var ticks := float(Content.time().get("physics_ticks_per_second", 60))
	reach = minf(reach + _speed / ticks, length_px)
	var stop := _first_block(tank)
	blocked = stop < reach
	if blocked:
		reach = stop
	elif reach >= length_px:
		_hit(room)
	queue_redraw()


## Whether the jet runs: under Shift while the world moves back through a
## recorded drain (`flow` < 0), and the surface is below the mouth.
static func runs(time_direction: int, moved: bool, flow: int, surface_y: float, mouth_y: float) -> bool:
	return time_direction < 0 and moved and flow < 0 and surface_y > mouth_y


## The jet in global pixels, from the mouth to the front.
func jet_rect() -> Rect2:
	var x := global_position.x if direction > 0 else global_position.x - reach
	return Rect2(Vector2(x, global_position.y - _thickness / 2.0), Vector2(reach, _thickness))


## The distance to the first body in the way (the heroine, a float), or the
## jet's whole length; the heroine in the way is pushed along.
func _first_block(tank: Water) -> float:
	var full := Rect2(global_position + Vector2(-length_px if direction < 0 else 0.0, -_thickness / 2.0), Vector2(length_px, _thickness))
	var nearest := length_px
	var hero: CharacterBody2D = null
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and node.has_method("body_rect"):
			var body: Rect2 = node.call("body_rect")
			if body.intersects(full):
				var d := _distance_to(body)
				if d < nearest:
					nearest = d
					hero = node
	for float_body in tank.floats():
		var size := float_body.body_size()
		var body := Rect2(float_body.global_position - size / 2.0, size)
		if body.intersects(full):
			var d := _distance_to(body)
			if d < nearest:
				nearest = d
				hero = null
	if hero != null and nearest <= reach:
		var ticks := float(Content.time().get("physics_ticks_per_second", 60))
		hero.move_and_collide(Vector2(direction * _push / ticks, 0.0))
	return nearest


func _distance_to(body: Rect2) -> float:
	if direction < 0:
		return maxf(global_position.x - body.end.x, 0.0)
	return maxf(body.position.x - global_position.x, 0.0)


func _hit(room: Node) -> void:
	var lever := get_node_or_null(lever_path) as Lever
	if lever == null or lever.on:
		return
	var targets := InteractionSystem.target_list(lever.target_id, lever.target_ids)
	var changes := [{"id": lever.object_id, "state": {"on": true}}]
	changes.append_array(InteractionSystem.power_changes(targets, room.call("temporal_objects"), true))
	for change: Dictionary in changes:
		room.call("live_action", str(change["id"]), change["state"])


func _draw() -> void:
	if reach <= 0.0:
		return
	var rect := jet_rect()
	var local := Rect2(rect.position - global_position, rect.size)
	draw_rect(local, Color(WATER_COLOR, 0.55))
	draw_line(Vector2(0.0, -_thickness / 2.0), Vector2(direction * reach, -_thickness / 2.0), WATER_COLOR, 2.0)
	# Drops thrown from the front: the splash on the body or on the bars.
	var front := Vector2(direction * reach, 0.0)
	for i in DROPS:
		var phase := fposmod(float(_live_tick) / 18.0 + float(i) / DROPS, 1.0)
		var spread := (float(i) / DROPS - 0.5) * 2.0
		var at := front + Vector2(-direction * phase * 22.0, spread * 26.0 * phase - 10.0 * phase * (1.0 - phase))
		draw_circle(at, 2.5 * (1.0 - phase) + 0.8, Color(WATER_COLOR, 1.0 - phase))
