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
##    ceiling comes down in chunks, two lamps fall among them still shining, an
##    explosion flares up in the background, and the world slows down while she
##    climbs the falling chunks towards the exit. She slows down too, less than
##    the world (D148): this node sets the engine's time scale, which slows her
##    moves, her animation and the particles but not the ticks of the world.
##    The chunks are of different sizes and speeds and break off out of order
##    (D149): the stair of big ones ends below the exit ledge; small ones
##    tumble down across her jumps (Shift sends them back up); the lip of the
##    exit ledge breaks off and drops fast, and under Shift it flies back up
##    and lifts her to the ledge.
##
## Every piece and the crane hold the heroine, except a lost one lying at the
## bottom of the pit, a crumbled one and a tumbling chunk: that one is solid
## only above her feet, so she hits it but never stands on it. Nothing crushes
## her: the world waits instead.
##
## A recorded object. State: { "clock": ticks since the room began, "ride":
## ticks since her step onto the crane, -1 before it, "calm": the ride tick of
## her step onto the exit ledge, which ends the slow part of act 3 (D162), -1
## before it, "brake": the ride tick on which the crane was put on its brake
## (the pedal, D176), -1 before it }; the counters stop once everything of their acts is down, so
## the room may stand still (D56). Both steps are the player's actions: left
## of the head they branch the room (`RoomTime.apply_change`), like a time
## plate's (group `plate`). Only steps in normal time count. Under Shift everything goes back up,
## after Shift is released the recorded collapse plays again (rule «A»).
## The pedal (D176): when she jumps into the riding crane from a piece while
## Shift is held, the crane is hers: Shift carries it back up its rail with the
## rest of the world, and the tick she lets go of Shift it goes onto its brake
## and stays there while the world runs on (an action of hers, so it branches
## the room). A step from the crane's own floor or from a ledge does not count.
## The gate (D215): a heavy slab hangs on two chains over the exit door in the
## back wall (`door_rect`). The explosion tears its left chain (`gate` in the
## data) and it swings aside on the right one: from then the exit is open.
## It is drawn behind the crane and has no body. This node locks the level's
## exit zone (`exit_path`) like a door: `is_open`, `opened`.
## Numbers: `collapse` of the level's entry in data/levels.json; the look:
## `kit_objects.collapse` and `kit_objects.crane` of data/look.json.
##
## Temporal object contract: docs/architecture.md, section 4.1.

## Emitted when the slab over the exit door has swung aside (D215).
signal opened

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
## The floor of the exit ledge: her step onto it ends the slow part (D162).
@export var calm_rect := Rect2()
## From the load's top up to the trolley on the rail.
@export var sling_px := 200.0
## The exit door in the back wall and the slab hung over it (D215); empty: none.
@export var door_rect := Rect2()
@export var gate_rect := Rect2()
## The exit zone the gate locks.
@export var exit_path := NodePath()

var clock := 0
var ride := -1
var calm := -1
var brake := -1
## Set by tests or read once from the level entry.
var plan: CollapsePlan
var _look := {}
var _crane_look := {}
var _ceiling_y := 256.0
var _lamp_base: Array[Vector2] = []
var _bodies: Array[AnimatableBody2D] = []
var _crane_body: AnimatableBody2D
## The explosion of act 3: its light on the room and its fireball (unshaded).
var _blast_light: PointLight2D
var _blast_glow: Node2D
## Pixels of the player's feet inside a piece that are standing, not crushing:
## the kit's margin plus the most that piece (`_margins`, one per piece) or
## the crane moves in one tick.
var _carry_margin := 8.0
var _margins := PackedFloat32Array()
## Per piece: true for a tumbling chunk, which she can never stand on.
var _tumbling: Array[bool] = []
## Her feet (the bottom of her rect) as `sense` last saw them.
var _feet_y := INF
var _crane_margin := 8.0
var _contact_px := 6.0
## Live, never recorded: she stood on a piece since she last stood on the
## crane; and she jumped into the crane from one under Shift (the pedal is
## hers until she stands on a piece again).
var _from_piece := false
var _armed := false
var _was_open := false


func _ready() -> void:
	add_to_group("temporal")
	add_to_group("plate")
	_look = ObjectLook.of("collapse")
	_crane_look = ObjectLook.of("crane")
	_carry_margin = float(Content.objects().get("carry_margin_px", 8))
	_contact_px = float(Content.objects().get("time_plate", {}).get("contact_px", 6))
	_plan()
	_margins = _fastest()
	_crane_margin = _carry_margin + ceilf(plan.ride_step + 2.0 * crane_fall_px / float(plan.crane_fall_ticks))
	for k in pieces.size():
		_bodies.append(_body(pieces[k].size))
		_tumbling.append(k < plan.pieces.size() and str(plan.pieces[k]["kind"]) == "tumble")
	_crane_body = _body(crane_rect.size)
	var disc := KitTextures.soft_disc()
	_blast_light = PointLight2D.new()
	_blast_light.name = "BlastLight"
	_blast_light.texture = disc
	_blast_light.texture_scale = plan.blast_radius * 2.0 / float(disc.get_width())
	_blast_light.color = plan.blast_color
	_blast_light.position = plan.blast_at * WorldData.CELL
	_blast_light.energy = 0.0
	add_child(_blast_light)
	_blast_glow = Node2D.new()
	_blast_glow.name = "BlastGlow"
	_blast_glow.show_behind_parent = true
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_blast_glow.material = glow
	_blast_glow.draw.connect(_draw_blast)
	add_child(_blast_glow)
	var zone := get_node_or_null(exit_path) as ExitZone if not exit_path.is_empty() else null
	if zone != null and gate_rect.has_area():
		zone.lock_until(self)
	_was_open = is_open()
	_show()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Per piece: the kit's margin plus the most it moves in one tick, found by
## playing its act tick by tick (a fast piece moves fast only while the world
## runs at full tempo).
func _fastest() -> PackedFloat32Array:
	plan.calm = -1
	var margins := PackedFloat32Array()
	for k in mini(pieces.size(), plan.pieces.size()):
		var most := 0.0
		if int(plan.pieces[k]["act"]) == 1:
			for c in plan.clock_end:
				most = maxf(most, _rect(k, c + 1, -1).position.distance_to(_rect(k, c, -1).position))
		else:
			for r in range(plan.act3_at, plan.ride_end):
				most = maxf(most, _rect(k, plan.clock_end, r + 1).position.distance_to(_rect(k, plan.clock_end, r).position))
		margins.append(_carry_margin + ceilf(most))
	return margins


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
	return {"clock": clock, "ride": ride, "calm": calm, "brake": brake}


func restore_state(state: Dictionary) -> void:
	clock = int(state["clock"])
	ride = int(state["ride"])
	calm = int(state.get("calm", -1))
	plan.calm = calm
	brake = int(state.get("brake", -1))
	plan.brake = brake
	_show()


func simulate_tick(_tick: int) -> void:
	clock = mini(clock + 1, plan.clock_end)
	if ride >= 0:
		ride = mini(ride + 1, plan.ride_end)
	elif plan.ride_start >= 0 and clock >= plan.ride_start:
		# The crane sets off by itself (D215), as if she had stepped on.
		ride = 0
	_show()


func on_time_direction_changed(_direction: int) -> void:
	pass


## Called by RoomTime after every tick (group `plate`): her feet on the crane
## in normal time set it going, once; the pedal (D176) puts it on its brake.
func sense(room: Object, direction: int, player_rect: Rect2) -> void:
	_feet_y = player_rect.end.y if player_rect.has_area() else INF
	_show_bodies()
	var on_crane := stands_on_crane(player_rect)
	if stands_on_piece(player_rect):
		_from_piece = true
		_armed = false
	elif on_crane:
		if _from_piece and direction < 0 and ride >= plan.ride_delay and plan.pedal:
			_armed = true
		_from_piece = false
	if direction > 0 and ride < 0 and on_crane:
		room.call("apply_change", object_id, {"ride": 0})
	elif direction > 0 and _armed and on_crane and plan.can_brake(ride):
		room.call("apply_change", object_id, {"brake": ride})
	elif direction > 0 and plan.can_calm(ride) and stands_on_ledge(player_rect):
		room.call("apply_change", object_id, {"calm": ride})


func forget_step() -> void:
	_from_piece = false
	_armed = false


## True while the pedal is hers: she jumped into the riding crane from a piece
## under Shift and has stood on no piece since.
func pedal_armed() -> bool:
	return _armed


## True when the player's feet stand on a piece that holds her (not a tumbling
## chunk): any part of her feet over it, so the very edge counts too.
func stands_on_piece(player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	for k in pieces.size():
		if k < _tumbling.size() and _tumbling[k] or not piece_holds(k):
			continue
		var r := piece_rect(k)
		if absf(player_rect.end.y - r.position.y) <= _contact_px and player_rect.end.x > r.position.x and player_rect.position.x < r.end.x:
			return true
	return false


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


## True when the player's feet stand on the exit ledge (`calm_rect`).
func stands_on_ledge(player_rect: Rect2) -> bool:
	if not player_rect.has_area() or not calm_rect.has_area():
		return false
	var middle := player_rect.get_center().x
	return absf(player_rect.end.y - calm_rect.position.y) <= _contact_px \
		and middle > calm_rect.position.x and middle < calm_rect.end.x


## True once the slab over the exit door has swung aside (or there is none).
func is_open() -> bool:
	return not gate_rect.has_area() or _plan().gate_open(ride) >= 1.0


## True while the slow part of act 3 runs.
func slow_now() -> bool:
	return plan.slowness(ride) > 0.0


## True when a piece or the crane in `state` would overlap the player's body
## above the feet: standing on it is riding, anything deeper would crush her.
func blocks_player_at(state: Dictionary, player_rect: Rect2) -> bool:
	if not player_rect.has_area():
		return false
	var c := int(state["clock"])
	var r := int(state["ride"])
	plan.calm = int(state.get("calm", -1))
	plan.brake = int(state.get("brake", -1))
	var blocked := _blocks(c, r, player_rect)
	plan.calm = calm
	plan.brake = brake
	return blocked


func _blocks(c: int, r: int, player_rect: Rect2) -> bool:
	for k in pieces.size():
		var margin := _margins[k] if k < _margins.size() else _carry_margin
		if _holds(k, c, r) and _rect(k, c, r).intersects(_above_feet(player_rect, margin)):
			return true
	return not plan.crane_down(r) and _crane_rect_at(r).intersects(_above_feet(player_rect, _crane_margin))


## The player's body without the lowest `margin` pixels of the feet.
static func _above_feet(player_rect: Rect2, margin: float) -> Rect2:
	return Rect2(player_rect.position, Vector2(player_rect.size.x, maxf(player_rect.size.y - margin, 1.0)))


## True while piece `k` hangs where it was built.
func piece_hangs(k: int) -> bool:
	return plan.drop(k, clock, ride) <= 0.0


## True while piece `k` lies where it fell.
func piece_lies(k: int) -> bool:
	return plan.drop(k, clock, ride) >= 1.0


## True while piece `k` is solid (a tumbling chunk only above her feet, so
## nobody ever stands on it).
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
	var x := lerpf(hang.position.x, rest.position.x, plan.side(k, c, r))
	var y := lerpf(hang.position.y, rest.position.y, plan.way(k, c, r))
	return Rect2(Vector2(x, y), hang.size)


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
	_show_bodies()
	# The heroine's clock: slower while the world is slow (D148).
	var heroine := plan.heroine_scale(ride)
	if Engine.time_scale != heroine:
		Engine.time_scale = heroine
	if _blast_light != null:
		_blast_light.energy = plan.blast_energy * plan.blast_light(ride)
		_blast_glow.queue_redraw()
	var open := is_open()
	if open and not _was_open:
		opened.emit()
	_was_open = open
	if _crane_body != null:
		_crane_body.position = crane_load_rect().get_center()
		(_crane_body.get_child(0) as CollisionShape2D).set_deferred("disabled", plan.crane_down(ride))
	queue_redraw()


## Moves the bodies of the pieces. A tumbling chunk is solid only while its
## top is above her feet (D149): she hits it with her head or side and falls
## short of her jump, but it never holds her up.
func _show_bodies() -> void:
	for k in _bodies.size():
		var r := piece_rect(k)
		_bodies[k].position = r.get_center()
		var off := not piece_holds(k) or (_tumbling[k] and r.position.y >= _feet_y - _carry_margin)
		(_bodies[k].get_child(0) as CollisionShape2D).set_deferred("disabled", off)


func _draw() -> void:
	_draw_gate()
	_draw_rail()
	for k in pieces.size():
		if k >= plan.pieces.size() or int(plan.pieces[k]["act"]) != 3:
			_draw_platform(k)
		elif int(plan.pieces[k]["follow"]) >= 0:
			_draw_counterweight(k, int(plan.pieces[k]["follow"]))
		elif not _pulls(k):
			_draw_hangers(k)
			_draw_chunk(k)
	_draw_crane()


## True when another piece hangs against piece `k` over pulleys (it is drawn
## with that one).
func _pulls(k: int) -> bool:
	for p in plan.pieces:
		if int(p["follow"]) == k:
			return true
	return false


## A chunk of act 3 hung low under the roof hangs on two chains until it
## falls.
func _draw_hangers(k: int) -> void:
	var r := piece_rect(k)
	if not piece_hangs(k) or r.position.y < _ceiling_y + WorldData.CELL:
		return
	var chain := ObjectLook.color(_look, "chain", Color("#3a4048"))
	for side: float in [0.2, 0.8]:
		var x := r.position.x + r.size.x * side
		draw_line(Vector2(x, _ceiling_y), Vector2(x, r.position.y + 4.0), chain, 3.0, true)


## The counterweight of D162: the platform `k` she rides, signal yellow (D65),
## hangs on a chain that runs up over a pulley, along the roof and over a
## second pulley down to the slab `heavy`. As the slab falls the platform
## rises; the pulleys turn with the recorded way, so under Shift they turn
## back.
func _draw_counterweight(k: int, heavy: int) -> void:
	var iron := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2622"))
	var light := ObjectLook.color(ObjectLook.mech(), "iron_light", Color("#6c6c72"))
	var yellow := ObjectLook.color(ObjectLook.mech(), "yellow", Color("#d4a21e"))
	var chain := ObjectLook.color(_look, "chain", Color("#3a4048"))
	var lift := piece_rect(k)
	var slab := piece_rect(heavy)
	var wheel := ObjectLook.number(_look, "pulley_px", 22.0)
	var top := _ceiling_y + wheel + 6.0
	var over_lift := Vector2(lift.get_center().x, top)
	var over_slab := Vector2(slab.get_center().x, top)
	# The chain: from the platform up over its pulley, along the roof, over
	# the other pulley and down to the slab.
	var side := signf(over_slab.x - over_lift.x)
	draw_line(Vector2(over_lift.x + side * wheel, top), Vector2(over_lift.x + side * wheel, lift.position.y), chain, 3.0, true)
	draw_line(Vector2(over_lift.x, top - wheel), Vector2(over_slab.x, top - wheel), chain, 3.0, true)
	draw_line(Vector2(over_slab.x - side * wheel, top), Vector2(over_slab.x - side * wheel, slab.position.y), chain, 3.0, true)
	var turn := plan.way(heavy, clock, ride) * absf(lift.position.y - pieces[k].position.y + 1.0) / wheel
	for at in [over_lift, over_slab]:
		draw_line(Vector2(at.x, _ceiling_y), at, iron, 6.0)
		draw_circle(at, wheel, iron)
		draw_circle(at, wheel - 5.0, light.darkened(0.2))
		for spoke in 3:
			var dir := Vector2.from_angle(turn * side + float(spoke) * TAU / 3.0)
			draw_line(at - dir * (wheel - 6.0), at + dir * (wheel - 6.0), iron, 3.0)
		draw_circle(at, 4.0, iron)
	# The platform: a steel deck with a yellow top and stripes.
	draw_rect(lift, iron)
	draw_rect(Rect2(lift.position, Vector2(lift.size.x, 6.0)), yellow)
	for i in int(lift.size.x / 24.0):
		var x := lift.position.x + 6.0 + 24.0 * float(i)
		draw_line(Vector2(x, lift.position.y + 8.0), Vector2(x + 10.0, lift.end.y - 2.0), yellow.darkened(0.3), 4.0)
	_draw_chunk(heavy)


## The exit door in the back wall and the slab over it (D215): a dark opening
## with cold light from beyond, and the slab on two chains from the roof. Once
## the left chain tears the slab swings aside on the right one, its torn end
## dangling, and the light comes through.
func _draw_gate() -> void:
	if not door_rect.has_area():
		return
	var open := _plan().gate_open(ride)
	var frame := ObjectLook.color(ObjectLook.mech(), "iron_dark", Color("#2a2622"))
	var cold := ObjectLook.color(_look, "door_light", Color("#9fd0ff"))
	draw_rect(door_rect.grow(10.0), frame)
	draw_rect(door_rect, Color("#0b0d12"))
	var glow := door_rect
	glow.position.y += door_rect.size.y * 0.3
	glow.size.y *= 0.7
	draw_rect(glow, Color(cold, 0.12 + 0.35 * open))
	if not gate_rect.has_area():
		return
	var chain := ObjectLook.color(_look, "chain", Color("#3a4048"))
	var stone := ObjectLook.color(_look, "chunk", Color("#5a554f"))
	var right := Vector2(gate_rect.end.x - 8.0, gate_rect.position.y)
	# The slab turns about its right chain's hook as it swings aside.
	var angle := -deg_to_rad(ObjectLook.number(_look, "gate_degrees", 80.0)) * open * (2.0 - open)
	draw_line(Vector2(right.x, _ceiling_y), right, chain, 4.0, true)
	var left := Vector2(gate_rect.position.x + 8.0, gate_rect.position.y)
	if open <= 0.0:
		draw_line(Vector2(left.x, _ceiling_y), left, chain, 4.0, true)
	else:
		var torn := _ceiling_y + (left.y - _ceiling_y) * 0.45
		draw_line(Vector2(left.x, _ceiling_y), Vector2(left.x + 6.0 * sin(float(ride) * 0.2), torn), chain, 4.0, true)
	draw_set_transform(right, angle)
	var local := Rect2(gate_rect.position - right, gate_rect.size)
	draw_rect(local, stone.darkened(0.35))
	draw_rect(local.grow(-6.0), stone)
	for i in 3:
		var y := local.position.y + local.size.y * (0.25 + 0.25 * float(i))
		draw_line(Vector2(local.position.x + 8.0, y), Vector2(local.end.x - 8.0, y), stone.darkened(0.2), 2.0)
	draw_set_transform(Vector2.ZERO)


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


## The explosion of act 3 behind the falling ceiling: a fireball that swells
## and dies, and embers flying out of it, all from act 3's recorded clock, so
## under Shift it shrinks back into the wall.
func _draw_blast() -> void:
	var age := plan.blast_age(ride)
	if age < 0.0:
		return
	var light := plan.blast_light(ride)
	var at := plan.blast_at * WorldData.CELL
	var r := plan.blast_radius * 0.35 * (0.35 + 0.65 * sqrt(age))
	# Many thin layers from a dark red rim to a white core: a soft ball, no rings.
	var rim := Color("#7a1e08")
	var core := Color("#fff4d6")
	var layers := 14
	for i in layers:
		var x := float(i) / float(layers - 1)
		var c := rim.lerp(plan.blast_color, minf(x * 2.0, 1.0)).lerp(core, maxf(x * 2.0 - 1.0, 0.0))
		c.a = light * 0.12 * (0.4 + x)
		var wobble := Vector2(sin(float(i) * 2.1 + age * 3.0), cos(float(i) * 1.7)) * r * 0.05 * (1.0 - x)
		_blast_glow.draw_circle(at + wobble, r * (1.0 - 0.85 * x), c)
	var ember := Color("#ffb54a")
	ember.a = minf(1.0, light * 1.5)
	var fly := plan.blast_radius * 0.9 * age
	for i in 18:
		var angle := float(i) * TAU / 18.0 + sin(float(i) * 7.3) * 0.25
		var speed := 0.6 + 0.4 * absf(sin(float(i) * 3.7))
		var tip := at + Vector2(cos(angle), sin(angle)) * fly * speed + Vector2(0.0, age * age * 120.0)
		var tail := tip - Vector2(cos(angle), sin(angle)) * (14.0 + 18.0 * light)
		_blast_glow.draw_line(tail, tip, ember, 2.0, true)


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
	# A tumbling chunk turns about its middle (its body does not: D149).
	var turn := plan.turn(k, clock, ride)
	if turn != 0.0:
		draw_set_transform(r.get_center(), turn)
		r = Rect2(-r.size / 2.0, r.size)
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
	draw_set_transform(Vector2.ZERO)


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
