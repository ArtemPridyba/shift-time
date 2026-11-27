class_name Minecart
extends Node2D
## The minecart of level 04 (card docs/levels/04.md, D168): out of time, like
## the heroine. It is never recorded and Shift never turns it back: while Shift
## is held it rolls on at the same speed while the world around it rewinds.
## The ride itself is `CartRide`; this node draws the cart, reads the switches
## it reaches, carries the heroine and lets the plates feel its wheels.
##
## The body is at the front (cargo), the operator's platform at the back (the
## heroine) with the same time device as her gauntlet, in the same time colour:
## the colour of time means "out of time", and only she and her cart have it
## (an exception to D60, D168).
##
## The heroine boards by landing on the platform of the parked cart (the
## platform is a floor only then); she gets off with a jump, at the ramp or at
## the station. Riding, she can only hold Shift.
##
## A level may ask for an intro ride (`objects.minecart.intro_ride` in its
## entry of data/levels.json, level 07, D191): at the start the empty cart
## leaves the park by itself, rides its way and comes back on the hoist, so the
## player sees where the way leads before boarding. A reset runs it again.
##
## A level may also put a barrier at the end of the walkway over the park
## (`gate_rect`, D192): a wall while the cart is away, open while it stands
## parked, so nobody steps into the empty shaft.
##
## Numbers: `minecart` in data/objects.json.

const BODY_COLOR := Color("#6b5a48")
const BODY_EDGE := Color("#2e2620")
const PLATFORM_COLOR := Color("#d9b400")
const WHEEL_COLOR := Color("#2b2e33")
const DEVICE_COLOR := Color("#7FE8FF")
const CHAIN_COLOR := Color("#5a5f66")
const STOPPER_COLOR := Color("#b8352a")

@export var object_id := "minecart"
## The rails (`Rails`), a sibling.
@export var rails_path: NodePath
## The segment whose start is the park at the top of the ramp.
@export var park_segment := "ramp"
## The barrier at the end of the walkway, in the parent's coordinates; no area
## means no barrier.
@export var gate_rect := Rect2()

var ride: CartRide
## True when the level asks for the intro ride.
var intro_ride := false

var _params := {}
var _rider: Node2D = null
var _was_touching := false
var _deck: AnimatableBody2D
var _deck_shape: CollisionShape2D
var _hoist_rail_y := 0.0
var _clock := 0.0
var _intro_pending := false
var _gate: StaticBody2D
var _gate_shape: CollisionShape2D
var _gate_bar: ColorRect


func _init() -> void:
	# After RoomTime (-50), before the player (0): she sits where the cart is
	# this tick, and the switches it meets have already moved.
	process_physics_priority = -40
	z_index = -1
	_params = Content.objects().get("minecart", {})


func _ready() -> void:
	add_to_group("minecart")
	var rails := get_node_or_null(rails_path) as Rails
	var track := rails.track() if rails != null else RailTrack.from_data([])
	_hoist_rail_y = rails.hoist_rail_y if rails != null else 0.0
	ride = CartRide.new(track, _params, park_segment, rails.hoist_y if rails != null else 0.0)
	_make_deck()
	_make_gate()
	intro_ride = _level_asks_intro()
	_intro_pending = intro_ride
	_apply()


## Back at the park with nobody on it: the room was reset.
func reset_ride() -> void:
	if _rider != null and is_instance_valid(_rider) and _rider.has_method("leave_carrier"):
		_rider.call("leave_carrier")
	_rider = null
	_was_touching = false
	_intro_pending = intro_ride
	ride.park()
	_apply()


func _physics_process(delta: float) -> void:
	_clock += delta
	if _intro_pending and _rider == null and ride.mode == CartRide.Mode.PARKED:
		# The empty cart leaves by itself: the stopper drops, nobody aboard.
		_intro_pending = false
		_launch()
	ride.step(delta, _leads_main)
	_apply()
	_catch_pigs()
	_check_boarding()
	queue_redraw()


## True while the heroine rides it.
func has_rider() -> bool:
	return _rider != null


## Where her feet go, in global pixels: the middle of the platform.
func seat_position() -> Vector2:
	return to_global(Vector2(_number("seat_px"), -_number("platform_px")))


func can_get_off() -> bool:
	return ride.can_get_off()


## She jumped off.
func get_off() -> void:
	_rider = null
	# She leaves from the platform: it boards her again only after a new landing.
	_was_touching = true


## What the camera needs while she rides: which way to look ahead.
func ride_view() -> Dictionary:
	return {"direction": ride.motion()}


## The wheels on the rails, in the parent's coordinates, for time plates under
## them (a plate's top lies on the rail); empty while hoisted.
func wheel_rect() -> Rect2:
	if not ride.on_rails():
		return Rect2()
	var half := _number("length_px") * 0.4
	return Rect2(position + Vector2(-half, -12.0), Vector2(2.0 * half, 12.0))


## The platform's top, the floor she lands on, in the parent's coordinates.
func platform_rect() -> Rect2:
	var top := position + Vector2(_number("seat_px"), -_number("platform_px"))
	var half := _number("platform_width_px") / 2.0
	return Rect2(top - Vector2(half, 0.0), Vector2(2.0 * half, 8.0))


func _leads_main(switch_id: String) -> bool:
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("rail_switch"):
		if room != null and room.is_ancestor_of(node) and str(node.get("object_id")) == switch_id:
			return bool(node.call("leads_main"))
	return true


func _apply() -> void:
	var at := ride.position()
	var shake := ride.shake_px()
	if shake > 0.0:
		at += Vector2(sin(_clock * 71.0), cos(_clock * 53.0)) * shake
	position = at
	# Local +x points to the back of the cart.
	rotation = (-ride.facing()).angle()
	var parked := ride.mode == CartRide.Mode.PARKED and _rider == null
	if _deck_shape != null:
		_deck_shape.set_deferred("disabled", not parked)
	if _gate_shape != null:
		var shut := ride.mode != CartRide.Mode.PARKED
		_gate_shape.set_deferred("disabled", not shut)
		_gate_bar.visible = shut


## True while the barrier at the end of the walkway stands closed.
func gate_closed() -> bool:
	return _gate_shape != null and ride.mode != CartRide.Mode.PARKED


## She lands on the platform of the parked cart: she rides, the stopper drops.
func _check_boarding() -> void:
	var player := _find_player()
	if player == null:
		return
	var touching := false
	if ride.mode == CartRide.Mode.PARKED and _rider == null:
		var rect: Rect2 = player.call("body_rect")
		var deck := platform_rect()
		touching = absf(rect.end.y - deck.position.y) <= _number("board_px") \
				and rect.end.x > deck.position.x and rect.position.x < deck.end.x
		if touching and not _was_touching and player.has_method("board"):
			_rider = player
			player.call("board", self)
			_launch()
	_was_touching = touching


## The stopper drops; the same pull opens the hopper's gate by its rope
## (level 04, D216).
func _launch() -> void:
	if not ride.board():
		return
	var room_time := _room_time()
	if room_time == null:
		return
	for hopper in _hoppers():
		hopper.call("open", room_time)


## Pigs in the air that are inside the body now stay in it: under Shift they
## fly up out of the pit through it (D216). Only on the rails.
func _catch_pigs() -> void:
	if not ride.on_rails():
		return
	var tub := body_rect()
	for hopper in _hoppers():
		for pig: Dictionary in hopper.call("pigs_in_air"):
			if tub.has_point(to_local(pig["position"])):
				hopper.call("take", str(pig["key"]))
				ride.load += 1


## The inside of the body, in the cart's own coordinates.
func body_rect() -> Rect2:
	var length := _number("length_px")
	var split := length / 2.0 - _number("platform_width_px")
	return Rect2(Vector2(-length / 2.0, -_number("body_px")), Vector2(split + length / 2.0, _number("body_px") - 14.0))


func _hoppers() -> Array:
	var room := get_parent()
	var result: Array = []
	for node in get_tree().get_nodes_in_group("hopper"):
		if room != null and room.is_ancestor_of(node):
			result.append(node)
	return result


func _room_time() -> Node:
	var room := get_parent()
	if room == null:
		return null
	for node in room.get_children():
		if node is RoomTime:
			return node
	return null


func _find_player() -> Node2D:
	var room := get_parent()
	for node in get_tree().get_nodes_in_group("player"):
		if room != null and room.is_ancestor_of(node) and node.has_method("body_rect"):
			return node as Node2D
	return null


## The platform is a floor only while the cart stands parked with nobody on it:
## she lands on it to board.
func _make_deck() -> void:
	_deck = AnimatableBody2D.new()
	_deck.name = "Deck"
	_deck.sync_to_physics = false
	_deck.collision_layer = 1
	_deck.collision_mask = 0
	_deck_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_number("platform_width_px"), 8.0)
	_deck_shape.shape = rect
	_deck_shape.one_way_collision = true
	_deck_shape.position = Vector2(_number("seat_px"), -_number("platform_px") + 4.0)
	_deck.add_child(_deck_shape)
	add_child(_deck)


## The barrier: a body of its own outside the cart's moving transform.
func _make_gate() -> void:
	if not gate_rect.has_area():
		return
	_gate = StaticBody2D.new()
	_gate.name = "Gate"
	_gate.top_level = true
	_gate.collision_layer = 1
	_gate.collision_mask = 0
	_gate_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = gate_rect.size
	_gate_shape.shape = rect
	_gate.add_child(_gate_shape)
	_gate_bar = ColorRect.new()
	_gate_bar.color = STOPPER_COLOR
	_gate_bar.position = -gate_rect.size / 2.0
	_gate_bar.size = gate_rect.size
	_gate_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate.add_child(_gate_bar)
	add_child(_gate)
	var parent := get_parent() as Node2D
	_gate.global_position = parent.to_global(gate_rect.get_center()) if parent != null else gate_rect.get_center()


## `objects.<id>.intro_ride` of this room's entry in data/levels.json.
func _level_asks_intro() -> bool:
	var room := get_parent()
	var entry := Content.level_for_scene(room.scene_file_path if room != null else "")
	var settings: Variant = entry.get("objects", {})
	var mine: Variant = (settings as Dictionary).get(object_id, {}) if settings is Dictionary else {}
	return mine is Dictionary and bool((mine as Dictionary).get("intro_ride", false))


func _draw() -> void:
	var length := _number("length_px")
	var front := -length / 2.0
	var back := length / 2.0
	var platform_w := _number("platform_width_px")
	var split := back - platform_w
	var body_h := _number("body_px")
	var platform_h := _number("platform_px")
	# The chain of the hoist while it carries the cart.
	if ride.mode == CartRide.Mode.HOISTED:
		var top := to_local(Vector2(global_position.x, _hoist_rail_y if _hoist_rail_y < global_position.y - body_h else 0.0))
		draw_line(Vector2(front + 30.0, -body_h), top, CHAIN_COLOR, 3.0)
		draw_line(Vector2(back - 20.0, -platform_h - 80.0), top, CHAIN_COLOR, 3.0)
		draw_circle(top, 8.0, CHAIN_COLOR)
	# The body: a trapezoid tub, wider at the top.
	var tub := PackedVector2Array([
		Vector2(front, -body_h), Vector2(split, -body_h),
		Vector2(split - 8.0, -14.0), Vector2(front + 8.0, -14.0)])
	draw_colored_polygon(tub, BODY_COLOR)
	draw_polyline(tub + PackedVector2Array([tub[0]]), BODY_EDGE, 3.0)
	# The load: pigs of iron heaped in the body.
	for i in ride.load:
		var row := i / 5
		var col := i % 5
		var at := Vector2(front + 14.0 + col * 20.0 + (row % 2) * 8.0, -body_h + 18.0 - row * 9.0)
		draw_rect(Rect2(at, Vector2(18.0, 9.0)), Color("#7d6a5a"))
		draw_rect(Rect2(at, Vector2(18.0, 9.0)), BODY_EDGE, false, 2.0)
	# The operator's platform with its rail and the time device on a post.
	draw_rect(Rect2(Vector2(split, -platform_h), Vector2(platform_w, platform_h - 14.0)), PLATFORM_COLOR)
	draw_line(Vector2(back - 4.0, -platform_h), Vector2(back - 4.0, -platform_h - 56.0), BODY_EDGE, 4.0)
	var pulse := 0.6 + 0.4 * sin(_clock * 6.0)
	var device := Rect2(Vector2(back - 16.0, -platform_h - 72.0), Vector2(22.0, 16.0))
	draw_rect(device, DEVICE_COLOR * Color(1, 1, 1, pulse))
	# The arrow on the device always points forward: the cart's own time runs on.
	var mid := device.get_center()
	draw_colored_polygon(PackedVector2Array([mid + Vector2(-7, 0), mid + Vector2(3, -6), mid + Vector2(3, 6)]), BODY_EDGE)
	# Wheels, turning with the ride.
	for x: float in [front + 30.0, back - 30.0]:
		var hub := Vector2(x, -12.0)
		draw_circle(hub, 12.0, WHEEL_COLOR)
		var spoke := Vector2.RIGHT.rotated(-ride.distance / 12.0) * 10.0
		draw_line(hub - spoke, hub + spoke, PLATFORM_COLOR, 2.0)
	# The stopper at the park, dropping when she boards.
	if ride.is_held():
		var drop := ride.stopper_fraction() * 26.0
		draw_rect(Rect2(Vector2(front - 14.0, -26.0 + drop), Vector2(10.0, 26.0 - drop)), STOPPER_COLOR)


func _number(key: String) -> float:
	var value: Variant = _params.get(key, 0.0)
	return float(value) if value is float or value is int else 0.0
