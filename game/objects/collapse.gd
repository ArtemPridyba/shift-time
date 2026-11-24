class_name Collapse
extends Node2D
## The collapse of level 05 «Crane» (card docs/levels/05.md, D144), in three
## quakes (`CollapsePlan`):
## 1. at the start the hall shakes, the hanging platforms fall one by one, each
##    followed by its lamp; the last one breaks on its stub and soon crumbles
##    into the pit. Under Shift its debris flies back, it mends and rises
##    first, carrying the heroine up to the crane's ledge.
## 2. her step onto the crane shakes the hall again: the crane breaks loose and
##    rides down its sloping rail, and the lamps over it fall as it passes.
## 3. at the end of the rail the third quake: the crane sags and falls, the
##    ceiling comes down in chunks, two lamps fall among them still shining, and
##    the world slows down while she climbs the falling chunks to the exit.
##
## Every piece and the crane hold the heroine, except a lost one lying at the
## bottom of the pit and a crumbled one. Nothing crushes her: the world waits
## instead.
##
## A recorded object. State: { "clock": ticks since the room began, "ride":
## ticks since her step onto the crane, -1 before it }; both stop counting once
## everything of their acts is down, so the room may stand still (D56). The
## step is the player's action: left of the head it branches the room
## (`RoomTime.apply_change`), like a time plate's (group `plate`). Only a step
## in normal time sets the crane going. Under Shift everything goes back up,
## after Shift is released the recorded collapse plays again (rule «A»).
## Numbers: `collapse` of the level's entry in data/levels.json; the look:
## `kit_objects.collapse` and `kit_objects.crane` of data/look.json.
##
## Temporal object contract: docs/architecture.md, section 4.1.

@export var object_id := "collapse"
## Where each piece hangs, in the room's coordinates, in the order of
## `collapse.pieces`.
@export var pieces: Array[Rect2] = []
## Where each piece lies once fallen.
@export var rests: Array[Rect2] = []
## Pieces lost to the bottom of the pit: once down, they hold nobody.
@export var lost := PackedInt32Array()
## The crane's load where it waits by the ledge, and how far it rides.
@export var crane_rect := Rect2()
@export var crane_travel := Vector2.ZERO
## How far it falls into the pit at the end.
@export var crane_fall_px := 0.0
## From the load's top up to the trolley on the rail.
@export var sling_px := 200.0

var clock := 0
var ride := -1
## Set by tests or read once from the level entry.
var plan: CollapsePlan
var _look := {}
var _crane_look := {}
var _ceiling_y := 256.0
var _lamp_base: Array[Vector2] = []
var _bodies: Array[AnimatableBody2D] = []
var _crane_body: AnimatableBody2D
## Pixels of the player's feet inside a piece that are standing, not crushing:
## the kit's margin plus the most a piece moves in one tick.
var _carry_margin := 8.0
var _contact_px := 6.0


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("plate")
	_look = ObjectLook.of("collapse")
	_crane_look = ObjectLook.of("crane")
	_carry_margin = float(Content.objects().get("carry_margin_px", 8))
	_contact_px = float(Content.objects().get("time_plate", {}).get("contact_px", 6))
	_plan()
	var fastest := plan.ride_step + 2.0 * crane_fall_px / float(plan.crane_fall_ticks)
	for k in mini(pieces.size(), rests.size()):
		var way := absf(rests[k].position.y - pieces[k].position.y)
		var ticks := float(plan.pieces[k]["fall"]) if k < plan.pieces.size() else 1.0
		fastest = maxf(fastest, 2.0 * way / ticks)
	_carry_margin += ceilf(fastest)
	for rest in pieces:
		_bodies.append(_body(rest.size))
	_crane_body = _body(crane_rect.size)
	_show()


func _body(size: Vector2) -> AnimatableBody2D:
	var body := AnimatableBody2D.new()
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


## The plan of this level, read once from the entry of the parent's scene.
func _plan() -> CollapsePlan:
	if plan != null and not _lamp_base.is_empty():
		return plan
	var room := get_parent()
	var entry := Content.level_for_scene(room.scene_file_path if room != null else "")
	if plan == null:
		plan = CollapsePlan.from_data(entry.get("collapse"), Content.world_ticks_per_second(Content.time()),
			ObjectLook.of("quake"), ObjectLook.of("collapse"))
	var layout := WorldData.layout(entry)
	var ceiling := WorldData.ceiling(layout)
	_ceiling_y = ceiling * WorldData.CELL
	_lamp_base.clear()
	var lamp_x: Array = []
	for lamp: Variant in layout.get("lamps", []):
		var at := WorldData.lamp_at(lamp, ceiling)
		_lamp_base.append(at)
		lamp_x.append(at.x)
	plan.aim(crane_rect.get_center().x, crane_travel, lamp_x)
	return plan


func capture_state() -> Dictionary:
	return {"clock": clock, "ride": ride}


func restore_state(state: Dictionary) -> void:
	clock = int(state["clock"])
	ride = int(state["ride"])
	_show()


func simulate_tick(_tick: int) -> void:
	clock = mini(clock + 1, plan.clock_end)
	if ride >= 0:
		ride = mini(ride + 1, plan.ride_end)
	_show()


func on_time_direction_changed(_direction: int) -> void:
	pass


## Called by RoomTime after every tick (group `plate`): her feet on the crane
## in normal time set it going, once.
func sense(room: Object, direction: int, player_rect: Rect2) -> void:
	if direction > 0 and ride < 0 and stands_on_crane(player_rect):
		room.call("apply_change", object_id, {"ride": 0})


func forget_step() -> void:
	pass


## True when the player's feet (a rect in the parent's coordinates) stand on
## the crane's load: their middle over it, so a toe from the ledge does not
## count.
func stands_on_crane(player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var load_rect := crane_load_rect()
	var middle := player_rect.get_center().x
	return absf(player_rect.end.y - load_rect.position.y) <= _contact_px \
		and middle > load_rect.position.x and middle < load_rect.end.x


## True when a piece or the crane in `state` would overlap the player's body
## above the feet: standing on it is riding, anything deeper would crush her.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var body := Rect2(player_rect.position, player_rect.size - Vector2(0.0, _carry_margin))
	var c := int(state["clock"])
	var r := int(state["ride"])
	for k in pieces.size():
		if _holds(k, c, r) and _rect(k, c, r).intersects(body):
			return true
	return not plan.crane_down(r) and _crane_rect_at(r).intersects(body)


## True while piece `k` hangs where it was built.
func piece_hangs(k: int) -> bool:
	return plan.drop(k, clock, ride) <= 0.0


## True while piece `k` lies where it fell.
func piece_lies(k: int) -> bool:
	return plan.drop(k, clock, ride) >= 1.0


## True while piece `k` can be stood on.
func piece_holds(k: int) -> bool:
	return _holds(k, clock, ride)


## The rect of piece `k` now, in the room's coordinates.
func piece_rect(k: int) -> Rect2:
	return _rect(k, clock, ride)


## The crane's load now (without its tilt), in the room's coordinates.
func crane_load_rect() -> Rect2:
	return _crane_rect_at(ride)


## True while the crane waits for her by the ledge.
func crane_waits() -> bool:
	return ride < plan.ride_delay


## True once the crane has reached the end of its rail (act 3 has begun).
func crane_arrived() -> bool:
	return ride >= plan.arrival()


## The fall of world lamp `lamp` now, for `WorldLight`; {} when nothing here
## drops it.
func lamp_fall(lamp: int) -> Dictionary:
	return _plan().lamp_fall(lamp, clock, ride)


## A lamp swings while the hall shakes.
func swing(lamp: int) -> float:
	var amount := shake_amount()
	if amount <= 0.0:
		return 0.0
	var t := float(plan.since_quake(clock, ride))
	return deg_to_rad(ObjectLook.number(ObjectLook.of("quake"), "swing_degrees", 7.0)) * amount * sin(t * 0.17 + float(lamp) * 0.9)


## How hard the hall shakes now: 0 to 1.
func shake_amount() -> float:
	return _plan().shake(clock, ride)


## How slow the world runs now (the look of act 3): 0 normal … 1 slowest.
func slowness() -> float:
	return _plan().slowness(ride)


func _holds(k: int, c: int, r: int) -> bool:
	return not (lost.has(k) and plan.drop(k, c, r) >= 1.0) and plan.crumble(k, c, r) <= 0.0


func _rect(k: int, c: int, r: int) -> Rect2:
	var hang := pieces[k]
	var rest := rests[k] if k < rests.size() else hang
	var way := plan.way(k, c, r)
	return Rect2(hang.position.lerp(rest.position, way), hang.size)


func _crane_rect_at(r: int) -> Rect2:
	var pose := plan.crane_pose(r, crane_travel, crane_fall_px)
	return Rect2(crane_rect.position + (pose["at"] as Vector2), crane_rect.size)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera == null:
		return
	var amount := shake_amount()
	var t := float(maxi(plan.since_quake(clock, ride), 0)) * 0.4
	var px := ObjectLook.number(_look, "shake_px", 8.0) * amount
	camera.offset = Vector2(sin(t * 3.0) * px, sin(t * 4.1 + 1.1) * px * 0.6)


func _show() -> void:
	for k in _bodies.size():
		_bodies[k].position = piece_rect(k).get_center()
		(_bodies[k].get_child(0) as CollisionShape2D).set_deferred("disabled", not piece_holds(k))
	if _crane_body != null:
		_crane_body.position = crane_load_rect().get_center()
		(_crane_body.get_child(0) as CollisionShape2D).set_deferred("disabled", plan.crane_down(ride))
	queue_redraw()


func _draw() -> void:
	_draw_rail()
	for k in pieces.size():
		if k < plan.pieces.size() and int(plan.pieces[k]["act"]) == 3:
			_draw_chunk(k)
		else:
			_draw_platform(k)
	_draw_crane()


## The sloping rail the crane rides down, under the roof.
func _draw_rail() -> void:
	var iron := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2622"))
	var light := ObjectLook.color(ObjectLook.mech(), "iron_light", Color("#6c6c72"))
	var rail_px := ObjectLook.number(_crane_look, "rail_px", 14.0)
	var over := ObjectLook.number(_crane_look, "rail_over_px", 64.0)
	var top := crane_rect.get_center() - Vector2(0.0, crane_rect.size.y / 2.0 + sling_px)
	var dir := crane_travel.normalized() if crane_travel != Vector2.ZERO else Vector2.RIGHT
	var from := top - dir * over
	var to := top + crane_travel + dir * over
	draw_line(from, to, iron, rail_px)
	draw_line(from - Vector2(0.0, rail_px / 2.0 - 1.0), to - Vector2(0.0, rail_px / 2.0 - 1.0), light, 2.0)
	# Hangers from the roof hold the rail.
	var hangers := int(from.distance_to(to) / (4.0 * WorldData.CELL)) + 1
	for i in hangers + 1:
		var at := from.lerp(to, float(i) / float(hangers))
		draw_line(Vector2(at.x, _ceiling_y), at, iron, 4.0)
	# The stop at the bottom end.
	var stop_px := ObjectLook.number(_crane_look, "stop_px", 18.0)
	var stop_at := top + crane_travel + dir * (over * 0.5)
	draw_rect(Rect2(stop_at - Vector2(stop_px / 2.0, 0.0), Vector2(stop_px, stop_px * 2.0)),
		ObjectLook.color(ObjectLook.mech(), "yellow", Color("#d4a21e")).darkened(0.35))


## A hanging platform of act 1: a rusty I-beam on two chains; the one that
## breaks lies in two halves on its stub, then crumbles: its pieces tumble
## into the pit.
func _draw_platform(k: int) -> void:
	var chain := ObjectLook.color(_look, "chain", Color("#3a4048"))
	var r := piece_rect(k)
	var hangs := piece_hangs(k)
	for side: float in [0.15, 0.85]:
		var x := r.position.x + r.size.x * side
		var to := r.position.y if hangs else _ceiling_y + ObjectLook.number(_look, "stub_px", 18.0)
		draw_line(Vector2(x, _ceiling_y), Vector2(x, to), chain, 2.0, true)
	var gone := plan.crumble(k, clock, ride)
	if gone >= 1.0:
		return
	var crack := plan.broken(k, clock, ride)
	var parts := 5 if gone > 0.0 else (2 if crack > 0.0 else 1)
	var w := r.size.x / float(parts)
	for h in parts:
		var part := Rect2(r.position + Vector2(w * float(h), 0.0), Vector2(w - (3.0 if parts > 1 else 0.0), r.size.y))
		var pivot := part.get_center()
		var turn := 0.0
		if gone > 0.0:
			# The pieces tumble down into the pit, each its own way.
			var spread := float(h) - float(parts - 1) / 2.0
			pivot += Vector2(spread * 22.0 * gone, (0.8 + 0.12 * float(h % 3)) * gone * gone * 9.0 * WorldData.CELL)
			turn = spread * 0.9 * gone + 0.4 * gone * float(h % 2)
		elif parts == 2:
			# The broken halves sag towards the gap between them.
			pivot = Vector2(part.position.x if h == 0 else part.end.x, part.end.y)
			turn = (0.12 if h == 0 else -0.12) * crack
		draw_set_transform(pivot, turn)
		_draw_beam(Rect2(part.position - (part.get_center() if gone > 0.0 else pivot), part.size))
		draw_set_transform(Vector2.ZERO)


## A piece of rusty I-beam in `local`: web, a lighter top flange, rivets.
func _draw_beam(local: Rect2) -> void:
	var iron := ObjectLook.color(ObjectLook.mech(), "iron", Color("#4c4c53"))
	var light := ObjectLook.color(ObjectLook.mech(), "iron_light", Color("#6c6c72"))
	var dark := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2a30"))
	var rust := ObjectLook.color(_look, "rust", Color("#7a3a22"))
	var flange := ObjectLook.number(_look, "flange_px", 6.0)
	draw_rect(local, dark)
	draw_rect(Rect2(local.position + Vector2(4.0, flange), Vector2(maxf(local.size.x - 8.0, 1.0), local.size.y - 2.0 * flange)), iron)
	draw_rect(Rect2(local.position, Vector2(local.size.x, flange)), light)
	draw_rect(Rect2(Vector2(local.position.x, local.end.y - flange), Vector2(local.size.x, flange)), dark.lightened(0.1))
	for i in int(local.size.x / 24.0):
		draw_circle(Vector2(local.position.x + 12.0 + 24.0 * float(i), local.position.y + flange / 2.0), 1.6, dark)
	draw_rect(Rect2(local.position + Vector2(local.size.x * 0.3, flange), Vector2(local.size.x * 0.2, 3.0)), rust)


## A chunk of the ceiling of act 3: a broken slab of concrete, each its own
## shape (from its number, so it never changes), with cracks and bent rebar.
## Its top stays nearly flat where she stands.
func _draw_chunk(k: int) -> void:
	var stone := ObjectLook.color(_look, "chunk", Color("#5a554f"))
	var dark := stone.darkened(0.45)
	var rebar := ObjectLook.color(_look, "rust", Color("#7a3a22"))
	var r := piece_rect(k)
	var rough := func(i: int, amount: float) -> float:
		return sin(float(k * 37 + i * 11) * 12.9898) * amount
	var w := r.size.x
	var h := r.size.y
	var outline := PackedVector2Array([
		r.position + Vector2(-4.0 + rough.call(0, 4.0), 3.0 + rough.call(1, 3.0)),
		r.position + Vector2(w * 0.35, rough.call(2, 2.0)),
		r.position + Vector2(w * 0.7, 1.0 + rough.call(3, 2.0)),
		r.position + Vector2(w + 5.0 + rough.call(4, 5.0), 4.0 + rough.call(5, 4.0)),
		r.position + Vector2(w + rough.call(6, 8.0), h * 0.6 + rough.call(7, 6.0)),
		r.position + Vector2(w * 0.8 + rough.call(8, 6.0), h + 6.0 + rough.call(9, 8.0)),
		r.position + Vector2(w * 0.45 + rough.call(10, 8.0), h + 14.0 + rough.call(11, 10.0)),
		r.position + Vector2(w * 0.15 + rough.call(12, 6.0), h + 4.0 + rough.call(13, 8.0)),
		r.position + Vector2(-6.0 + rough.call(14, 6.0), h * 0.5 + rough.call(15, 6.0))])
	draw_colored_polygon(outline, dark)
	var face := PackedVector2Array()
	for p in outline:
		face.append(p.lerp(r.get_center(), 0.14))
	draw_colored_polygon(face, stone)
	draw_line(outline[0] + Vector2(3.0, 0.0), outline[3] + Vector2(-3.0, 0.0), stone.lightened(0.25), 3.0)
	# Cracks over the face and rebar torn out of the edges.
	var crack := stone.darkened(0.3)
	draw_polyline(PackedVector2Array([r.position + Vector2(w * 0.4, 6.0), r.position + Vector2(w * 0.5 + rough.call(16, 6.0), h * 0.5),
		r.position + Vector2(w * 0.42 + rough.call(17, 8.0), h + 4.0)]), crack, 1.5)
	for i in 2 + (k % 2):
		var at := outline[4 + i * 2 % 5]
		draw_line(at, at + Vector2(rough.call(20 + i, 10.0), 8.0 + absf(rough.call(24 + i, 8.0))), rebar, 2.0)


## The crane: a trolley on the sloping rail, two slings, and the load the
## heroine rides, signal yellow (D65); it sags and tilts at the end.
func _draw_crane() -> void:
	var pose := plan.crane_pose(ride, crane_travel, crane_fall_px)
	var at := pose["at"] as Vector2
	var tilt := float(pose["tilt"])
	var load_rect := Rect2(crane_rect.position + at, crane_rect.size)
	var iron := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2622"))
	var yellow := ObjectLook.color(ObjectLook.mech(), "yellow", Color("#d4a21e"))
	var cable := ObjectLook.color(_crane_look, "cable_color", iron)
	var width := ObjectLook.number(_crane_look, "cable_px", 2.0)
	var inset := ObjectLook.number(_crane_look, "sling_inset_px", 10.0)
	var rail_at := crane_rect.get_center() - Vector2(0.0, crane_rect.size.y / 2.0 + sling_px) \
		+ crane_travel * plan.crane_way(ride)
	var falling := bool(pose["falling"])
	var trolley := Rect2(rail_at - Vector2(26.0, 6.0), Vector2(52.0, 24.0))
	draw_rect(trolley, iron)
	draw_circle(rail_at + Vector2(-14.0, -6.0), 7.0, iron.lightened(0.15))
	draw_circle(rail_at + Vector2(14.0, -6.0), 7.0, iron.lightened(0.15))
	var hook := rail_at + Vector2(0.0, 26.0)
	draw_line(rail_at + Vector2(0.0, 18.0), hook, cable, width + 1.0)
	var centre := load_rect.get_center()
	var ends: Array[Vector2] = []
	for side: float in [-1.0, 1.0]:
		ends.append(centre + Vector2(side * (load_rect.size.x / 2.0 - inset), -load_rect.size.y / 2.0).rotated(tilt))
	if not falling:
		for foot in ends:
			draw_line(hook, foot, cable, width, true)
	else:
		# Torn slings: one hangs from the hook, one trails from the load.
		draw_line(hook, hook + Vector2(6.0, 40.0), cable, width, true)
		draw_line(ends[1], ends[1] + Vector2(-8.0, -36.0), cable, width, true)
	draw_set_transform(centre, tilt)
	var local := Rect2(-load_rect.size / 2.0, load_rect.size)
	draw_rect(local, iron)
	draw_rect(Rect2(local.position, Vector2(local.size.x, 6.0)), yellow)
	var stripes := int(local.size.x / 24.0)
	for i in stripes:
		var x := local.position.x + 6.0 + 24.0 * float(i)
		draw_line(Vector2(x, local.position.y + 8.0), Vector2(x + 10.0, local.end.y - 2.0), yellow.darkened(0.3), 4.0)
	draw_set_transform(Vector2.ZERO)
