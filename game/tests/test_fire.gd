extends RefCounted
## Tests of fire and the reverse flamethrower (task 2.7): a wood zone burns
## whole → burning → burnt only at the head and comes back under Shift; water
## and the flamethrower in normal time put it out with steam that rewinds; the
## flamethrower lights wood under Shift and the wood burns out after Shift is
## released; the player in fire burns after `fire_seconds` and the room
## resets; the item lying in the room is recorded like everything but the
## player, its fire is never recorded, and letting it go never makes it jump.
## Run by test_runner.gd.

const ROOM_PATH := "res://levels/test_room_fire.tscn"
const FLOOR_Y := 768.0
const WHOLE := WoodBurn.Phase.WHOLE
const BURNING := WoodBurn.Phase.BURNING
const BURNT := WoodBurn.Phase.BURNT

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


## A recorded thing with one number, for the core tests.
class Thing extends RefCounted:
	var object_id := "thing"
	var value := 0

	func capture_state() -> Dictionary:
		return {"value": value}

	func restore_state(state: Dictionary) -> void:
		value = int(state["value"])

	func simulate_tick(_tick: int) -> void:
		value += 1


func test_wood_burns_through_burning_to_burnt() -> void:
	var wood := WoodBurn.new({"burn_seconds": 3}, {"physics_ticks_per_second": 60})
	check(wood.burn_ticks == 180, "3 s of burning must be 180 ticks")
	check(wood.tick(false) == WoodBurn.Event.NONE and wood.phase == WHOLE, "whole wood must not burn by itself")
	check(wood.ignite() and wood.phase == BURNING, "whole wood must catch fire")
	for i in 179:
		wood.tick(false)
	check(wood.phase == BURNING and wood.is_solid(), "wood must burn at least burn_seconds and stay solid while it burns")
	check(wood.tick(false) == WoodBurn.Event.BURNT_OUT and wood.phase == BURNT, "wood must burn out after burn_seconds")
	check(not wood.is_solid() and is_equal_approx(wood.charred(), 1.0), "burnt wood must be a gap")
	check(not wood.ignite() and not wood.douse(), "burnt wood can be neither lit nor put out")


func test_water_and_douse_put_the_fire_out() -> void:
	var wood := WoodBurn.new({"burn_seconds": 3}, {"physics_ticks_per_second": 60})
	check(wood.tick(true) == WoodBurn.Event.NONE, "water over whole wood changes nothing")
	wood.ignite()
	wood.tick(false)
	check(wood.tick(true) == WoodBurn.Event.DOUSED and wood.phase == WHOLE and wood.burn == 0, "water must put the fire out")
	check(not wood.douse(), "whole wood has no fire to put out")
	wood.ignite()
	check(wood.douse() and wood.phase == WHOLE, "a douse must put the fire out")
	check(wood.ignite(), "put-out wood can burn again")


func test_player_burns_after_fire_seconds_and_cools_outside() -> void:
	var scorch := Scorch.new({"fire_seconds": 3, "fire_cool_seconds": 1.5})
	for i in 5:
		check(not scorch.step(true, 0.5), "the player must not burn before fire_seconds")
	check(scorch.step(true, 0.5), "the player must burn after fire_seconds in fire")
	check(not scorch.step(true, 0.5), "burning is reported once")
	scorch.reset()
	scorch.step(true, 2.0)
	scorch.step(false, 0.5)
	check(is_equal_approx(scorch.heat, 1.0), "out of fire the heat cools at fire_seconds per fire_cool_seconds")
	scorch.step(false, 1.5)
	check(is_zero_approx(scorch.heat), "out of fire the heat cools down fully")


func test_held_item_drops_only_when_nothing_else_is_near() -> void:
	var lever := {"id": "lever", "position": Vector2(50, 0), "radius": 80.0}
	var held := {"id": "item", "position": Vector2.ZERO, "radius": 1.0e9, "fallback": true}
	check(InteractionSystem.get_nearest(Vector2.ZERO, [held, lever]) == "lever", "a lever in reach must win over dropping the item")
	check(InteractionSystem.get_nearest(Vector2(500, 0), [held, lever]) == "item", "with nothing else in reach E must drop the item")
	check(InteractionSystem.get_nearest(Vector2(500, 0), [lever]) == "", "the old rule without a fallback stays")


func test_fire_data_is_checked() -> void:
	var time_data := Content.time()
	var objects := Content.objects()
	check(Content.validate_objects(objects, time_data).is_empty(), "the shipped fire data must pass")
	var short := objects.duplicate(true)
	short["wood"]["burn_seconds"] = 2
	check(not Content.validate_objects(short, time_data).is_empty(), "burning under 3 s must be reported")
	var missing := objects.duplicate(true)
	missing.erase("flamethrower")
	check(not Content.validate_objects(missing, time_data).is_empty(), "a missing flamethrower section must be reported")
	var fast := objects.duplicate(true)
	fast["flamethrower"]["follow_px"] = 400
	check(not Content.validate_objects(fast, time_data).is_empty(), "an item jumping above max_state_step must be reported")
	var player := Content.player()
	check(Content.validate_player(player).is_empty(), "the shipped player.json must pass")
	var quick := player.duplicate(true)
	quick["fire_seconds"] = 1
	check(not Content.validate_player(quick).is_empty(), "fire_seconds under 3 s must be reported")
	var colorless := player.duplicate(true)
	colorless["fire_vignette_color"] = "hot"
	check(not Content.validate_player(colorless).is_empty(), "a broken fire_vignette_color must be reported")


func test_rewrite_past_gives_every_earlier_frame_the_present() -> void:
	var thing := Thing.new()
	var other := Thing.new()
	other.object_id = "other"
	var world := TimeWorld.new(Timeline.new(100))
	var objects := [thing, other]
	world.start(objects)
	for i in 10:
		world.tick(TimeWorld.FORWARD, objects)
	for i in 4:
		world.tick(TimeWorld.BACKWARD, objects)
	thing.value = 99
	check(world.rewrite_past(objects, "thing"), "rewrite_past must find the object")
	var head := world.timeline.head()
	var cursor := world.timeline.cursor()
	var history := []
	while world.timeline.step_back():
		pass
	for i in head + 1:
		history.append(world.timeline.current())
		world.timeline.step_forward()
	var ok := true
	for i in cursor:
		ok = ok and int(history[i]["thing"]["value"]) == 99 and int(history[i]["other"]["value"]) == i
	check(ok, "every frame left of the cursor must hold the present of that object only")
	check(int(history[cursor]["thing"]["value"]) == cursor and int(history[head]["thing"]["value"]) == head, "the cursor frame and the future stay as they were")


func test_burnt_bridge_comes_back_under_shift() -> void:
	var room: Node = await _load_room()
	var bridge: WoodZone = room.get_node("Bridge")
	check(bridge.burn.phase == BURNT, "the prelude must have burnt the bridge")
	check(_shape_off(bridge), "a burnt bridge must let the player fall")
	var phases: Array[int] = []
	var burn_went_up := false
	var last_burn := 1 << 30
	Input.action_press("rewind")
	for i in 420:
		await _tree.physics_frame
		var phase := int(bridge.burn.phase)
		if phases.is_empty() or phases[-1] != phase:
			phases.append(phase)
		if phase == BURNING:
			burn_went_up = burn_went_up or bridge.burn.burn > last_burn
			last_burn = bridge.burn.burn
	check(phases == [BURNT, BURNING, WHOLE], "under Shift the bridge must go burnt → burning → whole, got %s" % [phases])
	check(not burn_went_up, "under Shift the burning must run backwards")
	check(not _shape_off(bridge), "the restored bridge must be solid again")
	await _free_room(room)


func test_flamethrower_lights_wood_under_shift_and_it_burns_out_after_release() -> void:
	var room: Node = await _load_room()
	var wall: WoodZone = room.get_node("Wall")
	await _hold_flamethrower_near(room, wall.global_rect().position.x - 180.0)
	Input.action_press("rewind")
	Input.action_press("use_item")
	await _ticks(30)
	check(wall.burn.phase == BURNING, "the flamethrower under Shift must light the wall")
	Input.action_release("rewind")
	await _ticks(170)
	check(wall.burn.phase == BURNING, "the wall must burn at least burn_seconds after Shift is released")
	await _ticks(20)
	check(wall.burn.phase == BURNT and _shape_off(wall), "the wall must burn out after Shift is released, with F still held")
	await _free_room(room)


func test_releasing_f_before_shift_still_burns_the_wall() -> void:
	var room: Node = await _load_room()
	var wall: WoodZone = room.get_node("Wall")
	await _hold_flamethrower_near(room, wall.global_rect().position.x - 180.0)
	Input.action_press("rewind")
	Input.action_press("use_item")
	await _ticks(30)
	Input.action_release("use_item")
	await _ticks(30)
	check(wall.burn.phase == WHOLE, "rewinding on past the lighting shows the wall whole")
	Input.action_release("rewind")
	await _ticks(40)
	check(wall.burn.phase == BURNING, "the replay must light the wall again where it was lit (rule A)")
	await _ticks(200)
	check(wall.burn.phase == BURNT, "the replayed fire must burn the wall out")
	await _free_room(room)


func test_from_the_valve_the_jet_reaches_the_post_and_the_floor() -> void:
	var room: Node = await _load_room()
	var post: WoodZone = room.get_node("Post")
	var valve: Lever = room.get_node("Valve")
	var player: Player = room.get_node("Player")
	var thrower: ReverseFlamethrower = room.get_node("Flamethrower")
	await _hold_flamethrower_near(room, valve.global_position.x)
	player.set("_facing", -1.0)
	await _ticks(10)
	check(thrower.facing == -1, "the item must point the way the player faces")
	check(thrower.jet_rect().end.y > FLOOR_Y, "the jet must reach the floor in front of the player")
	Input.action_press("rewind")
	Input.action_press("use_item")
	await _ticks(10)
	check(post.burn.phase == BURNING, "from the valve, Shift and F must light the post")
	await _free_room(room)


func test_flamethrower_in_normal_time_puts_fire_out_with_steam() -> void:
	var room: Node = await _load_room()
	var wall: WoodZone = room.get_node("Wall")
	var room_time: RoomTime = room.get_node("RoomTime")
	await _hold_flamethrower_near(room, wall.global_rect().position.x - 180.0)
	room_time.live_action("wall", wall.ignite_change())
	await _ticks(30)
	check(wall.burn.phase == BURNING, "the wall must burn")
	Input.action_press("use_item")
	await _ticks(2)
	check(wall.burn.phase == WHOLE, "the flamethrower in normal time must put the fire out")
	check(wall.doused >= 0, "putting the fire out must start the steam")
	Input.action_release("use_item")
	await _ticks(30)
	check(wall.steam_age() > 0.3 and wall.steam_age() < 1.0, "the steam must rise in world time")
	await _free_room(room)


func test_water_puts_the_post_out_and_the_steam_rewinds() -> void:
	var room: Node = await _load_room()
	var post: WoodZone = room.get_node("Post")
	var valve: Lever = room.get_node("Valve")
	var room_time: RoomTime = room.get_node("RoomTime")
	room_time.live_action("post", post.ignite_change())
	await _ticks(10)
	room_time.player_interact(valve.global_position)
	var doused_at := -1
	for i in 30:
		await _tree.physics_frame
		if post.burn.phase == WHOLE:
			doused_at = i
			break
	check(doused_at >= 0, "the water must put the burning post out")
	check(post.doused >= 0, "the water putting fire out must leave steam")
	await _ticks(40)
	var age := post.steam_age()
	Input.action_press("rewind")
	await _ticks(20)
	check(post.steam_age() < age - 0.2, "under Shift the steam must sink back into the wood")
	await _ticks(25)
	check(post.burn.phase == BURNING, "rewinding past the water must show the post burning again")
	await _free_room(room)


func test_player_in_fire_burns_and_the_room_resets() -> void:
	var room: Node = await _load_room()
	var wall: WoodZone = room.get_node("Wall")
	var player: Player = room.get_node("Player")
	var thrower: ReverseFlamethrower = room.get_node("Flamethrower")
	var start := thrower.position
	await _hold_flamethrower_near(room, wall.global_rect().position.x - 30.0)
	# Shift and F keep the wall lit on every frame, the player stands in it.
	Input.action_press("rewind")
	Input.action_press("use_item")
	await _ticks(10)
	check(player.is_in_fire(), "the player next to the burning wall must be in its flames")
	await _ticks(160)
	check(player.global_position.x > 1000.0, "the player must survive under fire_seconds")
	await _ticks(30)
	check(player.global_position.x < 400.0, "after fire_seconds the player burns and starts at the spawn")
	check(not thrower.held and thrower.position.distance_to(start) < 1.0, "the reset puts the flamethrower back")
	Input.action_release("use_item")
	Input.action_release("rewind")
	await _tree.physics_frame
	check(wall.burn.phase == WHOLE, "the reset brings the room back as it was loaded")
	await _free_room(room)


func test_dropped_flamethrower_falls_rewinds_and_never_jumps() -> void:
	var room: Node = await _load_room()
	var thrower: ReverseFlamethrower = room.get_node("Flamethrower")
	var room_time: RoomTime = room.get_node("RoomTime")
	var player: Player = room.get_node("Player")
	await _hold_flamethrower_near(room, 1400.0)
	var keys := (thrower.capture_state() as Dictionary).keys()
	keys.sort()
	check(keys == ["facing", "fall", "held", "position"], "the item's frames hold its body only, never its fire: %s" % [keys])
	room_time.player_interact(player.global_position)
	check(not thrower.held, "E with nothing else near must drop the item")
	var drop := thrower.position
	var forward := {}
	for i in 40:
		await _tree.physics_frame
		forward[room_time.cursor()] = thrower.position
	check(thrower.position.y > drop.y + 20.0 and absf(thrower.position.y - FLOOR_Y) < 2.0, "the dropped item must fall to the floor")
	Input.action_press("rewind")
	var same := true
	var biggest := 0.0
	var last := thrower.position
	for i in 120:
		await _tree.physics_frame
		if forward.has(room_time.cursor()):
			same = same and thrower.position.is_equal_approx(forward[room_time.cursor()])
		biggest = maxf(biggest, thrower.position.distance_to(last))
		last = thrower.position
	check(same, "under Shift the item must go back through its recorded fall")
	check(thrower.position.distance_to(drop) < 1.0, "rewound past the drop, the item rests where it was let go")
	check(biggest <= float(Content.time()["max_state_step"]), "the item must never jump under Shift (step %s)" % biggest)
	await _free_room(room)


func test_drop_under_shift_keeps_the_item_still() -> void:
	var room: Node = await _load_room()
	var thrower: ReverseFlamethrower = room.get_node("Flamethrower")
	var room_time: RoomTime = room.get_node("RoomTime")
	var player: Player = room.get_node("Player")
	await _hold_flamethrower_near(room, 1400.0)
	Input.action_press("rewind")
	await _ticks(20)
	check(thrower.held, "the item stays in the hands while the world rewinds")
	room_time.player_interact(player.global_position)
	var drop := thrower.position
	await _ticks(30)
	check(thrower.position.distance_to(drop) < 1.0, "an item let go under Shift has no past and stays where it was let go")
	Input.action_release("rewind")
	await _ticks(30)
	check(thrower.position.distance_to(drop) < 1.0, "the replay keeps the item where it was let go")
	await _ticks(40)
	check(absf(thrower.position.y - FLOOR_Y) < 2.0, "after the replay the item falls")
	await _free_room(room)


## Picks the flamethrower up where it lies and walks the player to `x`; the
## item follows into the hands.
func _hold_flamethrower_near(room: Node, x: float) -> void:
	var thrower: ReverseFlamethrower = room.get_node("Flamethrower")
	var player: Player = room.get_node("Player")
	var room_time: RoomTime = room.get_node("RoomTime")
	player.global_position = Vector2(thrower.global_position.x, FLOOR_Y)
	await _tree.physics_frame
	room_time.player_interact(player.global_position)
	check(thrower.held, "E next to the flamethrower must pick it up")
	player.global_position = Vector2(x, FLOOR_Y)
	await _ticks(20)


func _shape_off(zone: WoodZone) -> bool:
	return (zone.get_node("CollisionShape2D") as CollisionShape2D).disabled


func _load_room() -> Node:
	Input.action_release("rewind")
	Input.action_release("use_item")
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free_room(room: Node) -> void:
	Input.action_release("rewind")
	Input.action_release("use_item")
	room.queue_free()
	await _tree.process_frame


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
