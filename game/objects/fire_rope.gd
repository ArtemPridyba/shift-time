class_name FireRope
extends Node2D
## A recorded rope that holds something (level 03 «Нить», D177): the brake of
## a winch or the stop of a cage. A burning torch carried past its `light`
## end sets it burning, in normal time or under Shift (left of the head that
## is interference: the room branches). The fire runs along the rope from that
## end, `burn_seconds` (real seconds, like all fire) to the far end, and then
## the rope breaks: what it held lets go. Rain over the fire puts it out; the
## rope stays whole and can be lit again. Fire only goes on at the head, so
## under Shift the frames bring the fire back along the rope and a broken rope
## grows whole again.
##
## `points` is the rope in the parent's pixels (the node stays at the room's
## origin), from the end the torch lights to the far end.
##
## State recorded: { "burn": int } — -1 whole, 0..burn ticks burning, at
## `burn_ticks` broken.
##
## Temporal object contract: docs/architecture.md, section 4.1.

const ROPE_COLOR := Color("#c8b083")
const CHAR_COLOR := Color("#2a2420")
const EMBER_COLOR := Color("#ff8a3d")
const FLAME_COLOR := Color("#ffc46b")
const CLEAT_COLOR := Color("#3a3c40")

@export var object_id := "rope"
## The rope from the end the torch lights to the far end, in the parent's pixels.
@export var points := PackedVector2Array()

var burn := -1
var burn_ticks := 180
var _reach := 24.0
var _per_second := 60.0
var _clock := 0


func _init() -> void:
	var data: Dictionary = Content.objects().get("rope", {})
	_per_second = float(Content.time().get("physics_ticks_per_second", 60))
	burn_ticks = maxi(int(round(float(data.get("burn_seconds", 3)) * _per_second)), 1)
	_reach = float(data.get("reach_px", 24))


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("world_clock")
	add_to_group("torch_lightable")


## Per-level settings: `burn_seconds` overrides objects.json for this rope.
func apply_settings(settings: Dictionary) -> void:
	if settings.has("burn_seconds"):
		burn_ticks = maxi(int(round(float(settings["burn_seconds"]) * _per_second)), 1)


func capture_state() -> Dictionary:
	return {"burn": burn}


func restore_state(state: Dictionary) -> void:
	burn = int(state["burn"])
	queue_redraw()


func simulate_tick(_tick: int) -> void:
	if not is_burning():
		return
	if is_wet():
		burn = -1
	else:
		burn = mini(burn + 1, burn_ticks)
	queue_redraw()


func on_time_direction_changed(_direction: int) -> void:
	pass


func blocks_player_at(_state: Dictionary, _player_rect: Rect2) -> bool:
	return false


func on_world_tick(tick: int, _recorded: bool) -> void:
	if tick != _clock:
		_clock = tick
		if is_burning():
			queue_redraw()


func is_whole() -> bool:
	return burn < 0


func is_burning() -> bool:
	return burn >= 0 and burn < burn_ticks


func is_broken() -> bool:
	return burn >= burn_ticks


## 0 at the lit end, 1 at the far end: how far the fire has run.
func burnt_fraction() -> float:
	if burn < 0:
		return 0.0
	return clampf(float(burn) / float(burn_ticks), 0.0, 1.0)


## Where the fire is now, in the parent's pixels.
func fire_point() -> Vector2:
	return point_at(burnt_fraction())


## The point `fraction` of the way along the rope.
func point_at(fraction: float) -> Vector2:
	if points.size() < 2:
		return points[0] if points.size() == 1 else Vector2.ZERO
	var total := length()
	var want := clampf(fraction, 0.0, 1.0) * total
	for i in points.size() - 1:
		var part := points[i].distance_to(points[i + 1])
		if want <= part or i == points.size() - 2:
			return points[i].lerp(points[i + 1], clampf(want / maxf(part, 0.001), 0.0, 1.0))
		want -= part
	return points[points.size() - 1]


func length() -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


## Where a torch's flame lights the rope: around its first end, global pixels.
func light_rect() -> Rect2:
	if points.is_empty():
		return Rect2()
	var at := to_global(points[0])
	return Rect2(at, Vector2.ZERO).grow(_reach)


## The state a burning torch writes; empty when the rope is not whole.
func torch_change() -> Dictionary:
	return {"burn": 0} if is_whole() else {}


## True while rain covers the fire.
func is_wet() -> bool:
	if not is_inside_tree():
		return false
	var at := to_global(fire_point())
	for node in get_tree().get_nodes_in_group("water"):
		if node.has_method("water_global_rect"):
			var water: Rect2 = node.call("water_global_rect")
			if water.has_area() and water.has_point(at):
				return true
	return false


func _draw() -> void:
	if points.size() < 2:
		return
	draw_rect(Rect2(points[0] - Vector2(6.0, 4.0), Vector2(12.0, 8.0)), CLEAT_COLOR)
	if is_broken():
		# Two loose ends: a charred stub at the cleat, one hanging at the far end.
		var stub := points[0].lerp(points[1], minf(20.0 / maxf(points[0].distance_to(points[1]), 1.0), 1.0))
		draw_line(points[0], stub, CHAR_COLOR, 3.0)
		var last := points[points.size() - 1]
		draw_line(last, last + Vector2(0.0, 22.0), CHAR_COLOR, 3.0)
		return
	var burnt := burnt_fraction() * length()
	var walked := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var part := a.distance_to(b)
		if burnt >= walked + part:
			draw_line(a, b, CHAR_COLOR, 3.0)
		elif burnt > walked:
			var mid := a.lerp(b, (burnt - walked) / part)
			draw_line(a, mid, CHAR_COLOR, 3.0)
			draw_line(mid, b, ROPE_COLOR, 3.0)
		else:
			draw_line(a, b, ROPE_COLOR, 3.0)
		walked += part
	if is_burning():
		# The flame flickers by world time: under Shift it runs back along the
		# rope with the recorded fire.
		var t := float(_clock) / _per_second
		var at := fire_point()
		var h := 14.0 + sin(t * 23.0) * 4.0
		draw_circle(at, 6.0, EMBER_COLOR)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-6.0, 0.0), at + Vector2(sin(t * 17.0) * 3.0, -h), at + Vector2(6.0, 0.0)]), FLAME_COLOR)
