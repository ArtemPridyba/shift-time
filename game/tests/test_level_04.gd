extends RefCounted
## Tests of level 04 «Plates» (card docs/levels/04.md, D118, D168): a time
## plate takes the direction of time. A step in normal time closes its
## shutters; a step with Shift held sends the closing into the past, so they
## open once time runs forward. Only the step counts, never standing on it.
## Then the minecart that is out of time: it rolls on under Shift while the
## world rewinds, takes the way its switches show at that moment, bumps at a
## dead end and the hoist brings it back. Its catch: pigs of iron that fly up
## out of the pit under Shift through its body stay in it (D216). The
## solutions in
## tests/solutions/level_04*.json play the level.

const LEVEL_PATH := "res://levels/level_04.tscn"


class FakeRoom:
	extends RefCounted
	var calls: Array = []

	func apply_change(id: String, state: Dictionary) -> bool:
		calls.append({"id": id, "state": state})
		return true


var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_shutter_moves_to_its_target_without_jumps() -> void:
	var shutter := Shutter.new()
	shutter.apply_settings({"start": "open"})
	check(shutter.is_open(), "a shutter set to start open is open")
	check(shutter.capture_state() == {"closed": 0, "target": 0}, "an open shutter records closed 0 and target 0")
	shutter.target = Shutter.CLOSED_MAX
	var max_step := int(Content.time()["max_state_step"])
	var last := shutter.closed
	for i in 5 * 60:
		shutter.simulate_tick(i)
		check(absi(shutter.closed - last) <= max_step, "a shutter moves at most max_state_step per tick")
		last = shutter.closed
	check(shutter.closed == Shutter.CLOSED_MAX, "a shutter reaches its target, is at %d" % shutter.closed)
	shutter.simulate_tick(0)
	check(shutter.closed == Shutter.CLOSED_MAX, "a shutter at its target stays")
	shutter.apply_settings({})
	check(shutter.closed == Shutter.CLOSED_MAX and shutter.target == Shutter.CLOSED_MAX, "a shutter starts closed by default")
	shutter.free()


func test_shutter_waits_rather_than_crushes() -> void:
	var shutter := Shutter.new()
	shutter.size = Vector2(32, 128)
	shutter.travel = Vector2(0, -128)
	shutter.position = Vector2(100, 64)
	shutter.apply_settings({"start": "open"})
	var under := Rect2(Vector2(84, 36), Vector2(44, 92))
	check(shutter.blocks_player_at({"closed": Shutter.CLOSED_MAX, "target": Shutter.CLOSED_MAX}, under),
		"a closed wall overlaps the heroine standing in its doorway")
	check(not shutter.blocks_player_at({"closed": 0, "target": 0}, under), "an open wall does not")
	shutter.free()


func test_plate_takes_the_direction_of_time() -> void:
	var plate := TimePlate.new()
	plate.object_id = "plate_x"
	plate.target_ids = PackedStringArray(["wall", "hatch"])
	var forward := plate.step_changes(1)
	check(forward.size() == 3, "a step changes the plate and each of its shutters")
	check(forward[0] == {"id": "plate_x", "state": {"mark": TimePlate.MARK_CLOSE}}, "a step in normal time shows the flag down")
	check(forward[1] == {"id": "wall", "state": {"target": Shutter.CLOSED_MAX}}, "a step in normal time closes the shutter")
	var back := plate.step_changes(-1)
	check(back[0] == {"id": "plate_x", "state": {"mark": TimePlate.MARK_OPEN}}, "a step under Shift shows the flag up")
	check(back[2] == {"id": "hatch", "state": {"target": 0}}, "a step under Shift opens the shutter")
	plate.free()


func test_plate_counts_only_the_step() -> void:
	var plate := TimePlate.new()
	plate.object_id = "plate_x"
	plate.target_ids = PackedStringArray(["wall"])
	plate.width = 192.0
	plate.position = Vector2(200, 448)
	var room := FakeRoom.new()
	var on := Rect2(Vector2(180, 448 - 92), Vector2(44, 92))
	var off := Rect2(Vector2(400, 448 - 92), Vector2(44, 92))
	var above := Rect2(Vector2(180, 300 - 92), Vector2(44, 92))
	check(plate.touches(on) and not plate.touches(off) and not plate.touches(above), "the plate feels feet on it, not beside or above it")
	plate.sense(room, 1, on)
	check(room.calls.size() == 2, "stepping on in normal time changes the plate and its shutter")
	plate.sense(room, -1, on)
	plate.sense(room, -1, on)
	check(room.calls.size() == 2, "standing on the plate and pressing Shift does nothing")
	plate.sense(room, -1, off)
	plate.sense(room, -1, on)
	check(room.calls.size() == 4 and room.calls[3]["state"] == {"target": 0}, "a new step under Shift opens the shutter")
	plate.forget_step()
	plate.sense(room, 1, on)
	check(room.calls.size() == 6, "after a reset the plate feels the next step")
	plate.free()


func test_data_check_knows_shutter_starts() -> void:
	check(Content._object_settings_problems({"wall": {"start": "open"}}, "x").is_empty(), "'start': 'open' is valid level data")
	check(not Content._object_settings_problems({"wall": {"start": "half"}}, "x").is_empty(), "an unknown shutter start is broken level data")


## A small track: a ramp to switch "s", main to a station, side to a dead end.
static func _track() -> RailTrack:
	return RailTrack.from_data([
		{"id": "ramp", "points": [Vector2(1000, 500), Vector2(900, 500), Vector2(800, 600)],
			"end": {"kind": "switch", "switch": "s", "main": "main", "side": "side"}},
		{"id": "main", "points": [Vector2(800, 600), Vector2(200, 600)], "end": {"kind": "stop", "stop": "station"}},
		{"id": "side", "points": [Vector2(800, 600), Vector2(700, 700), Vector2(600, 700)], "end": {"kind": "stop", "stop": "dead_end"}},
	])


static func _ride(leads_main: bool) -> Dictionary:
	return {"ride": CartRide.new(_track(), Content.objects()["minecart"], "ramp", 400.0), "main": leads_main}


## Ticks the ride at 60 a second until `done` says so or `limit` ticks pass;
## returns the ticks it took.
static func _run(ride: CartRide, leads_main: bool, done: Callable, limit: int) -> int:
	for i in limit:
		ride.step(1.0 / 60.0, func(_id: String) -> bool: return leads_main)
		if done.call():
			return i + 1
	return limit


func test_track_knows_its_segments_and_reports_broken_ones() -> void:
	var track := _track()
	check(track.problems().is_empty(), "a good track has no problems: %s" % ", ".join(track.problems()))
	check(is_equal_approx(track.length("main"), 600.0), "a segment's length is the length of its polyline")
	check(track.point_at("ramp", 50.0).is_equal_approx(Vector2(950, 500)), "a point along the first piece")
	check(track.direction_at("ramp", 150.0).is_equal_approx(Vector2(-1, 1).normalized()), "the direction along the second piece")
	var broken := RailTrack.from_data([
		{"id": "a", "points": [Vector2(0, 0), Vector2(10, 0)], "end": {"kind": "next", "to": "nowhere"}},
		{"id": "b", "points": [Vector2(0, 0)], "end": {"kind": "stop", "stop": "dead_end"}},
		{"id": "c", "points": [Vector2(0, 0), Vector2(5, 0)], "end": {"kind": "stop", "stop": "cliff"}},
	])
	check(broken.problems().size() == 3, "an unknown segment, too few points and an unknown stop are reported, got %s" % ", ".join(broken.problems()))


func test_cart_waits_parked_until_she_boards() -> void:
	var ride: CartRide = _ride(true)["ride"]
	_run(ride, true, func() -> bool: return false, 120)
	check(ride.mode == CartRide.Mode.PARKED and ride.distance == 0.0, "a parked cart stays at the park")
	check(ride.can_get_off(), "at the park she may get off")
	check(ride.board(), "a parked cart takes her")
	check(not ride.board(), "a cart already launched does not board again")
	check(not ride.can_get_off(), "once launched she can not get off")
	_run(ride, true, func() -> bool: return ride.mode == CartRide.Mode.ROLLING, 120)
	check(ride.mode == CartRide.Mode.ROLLING, "after the stopper drops the cart rolls")


func test_switch_picks_the_way_at_the_moment_the_cart_reaches_it() -> void:
	for main: bool in [true, false]:
		var ride: CartRide = _ride(main)["ride"]
		ride.board()
		_run(ride, main, func() -> bool: return ride.segment != "ramp", 600)
		check(ride.segment == ("main" if main else "side"), "with the blade %s the cart takes %s, took %s" % ["to main" if main else "to the side", "main" if main else "side", ride.segment])


func test_cart_stops_at_the_station_and_lets_her_off() -> void:
	var ride: CartRide = _ride(true)["ride"]
	ride.board()
	var ticks := _run(ride, true, func() -> bool: return ride.mode == CartRide.Mode.STOPPED, 1200)
	check(ride.mode == CartRide.Mode.STOPPED, "the cart comes to rest at the station")
	check(ride.position().is_equal_approx(Vector2(200, 600)), "it rests at the end of the line, at %s" % ride.position())
	check(ride.can_get_off() and ride.stop_kind() == RailTrack.STOP_STATION, "at the station she may get off")
	var seconds := float(ticks) / 60.0
	var speed := float(Content.objects()["minecart"]["speed_px"])
	check(seconds < (ride.track.length("ramp") + 600.0) / speed + 3.0, "the ride brakes into the station without crawling for long: %.1f s" % seconds)


func test_dead_end_bumps_and_the_hoist_takes_it_back_to_the_park() -> void:
	var ride: CartRide = _ride(false)["ride"]
	ride.board()
	_run(ride, false, func() -> bool: return ride.mode == CartRide.Mode.BUMPED, 1200)
	check(ride.mode == CartRide.Mode.BUMPED and ride.stop_kind() == RailTrack.STOP_DEAD_END, "at a dead end the cart hits the buffer")
	check(not ride.can_get_off(), "at a dead end she can not get off")
	var at_buffer := ride.position()
	ride.step(1.0 / 60.0, Callable())
	check(ride.shake_px() > 0.0, "it shakes after the hit")
	var max_jump := 0.0
	var last := ride.position()
	var hoisted := false
	var bounced := 0.0
	for i in 60 * 20:
		ride.step(1.0 / 60.0, Callable())
		max_jump = maxf(max_jump, ride.position().distance_to(last))
		last = ride.position()
		if ride.mode == CartRide.Mode.BUMPED:
			bounced = maxf(bounced, ride.position().x - at_buffer.x)
		hoisted = hoisted or ride.mode == CartRide.Mode.HOISTED
		if hoisted and ride.mode == CartRide.Mode.PARKED:
			break
	check(bounced > float(Content.objects()["minecart"]["bounce_px"]) * 0.5, "it bounced back from the buffer, %.0f px" % bounced)
	check(hoisted, "the hoist hooks the cart after the bump")
	check(ride.mode == CartRide.Mode.PARKED and ride.position().is_equal_approx(Vector2(1000, 500)), "the hoist brings it back to the park, at %s" % ride.position())
	check(max_jump <= 10.0, "it never jumps: the largest move in a tick was %.1f px" % max_jump)


func test_cart_is_out_of_time() -> void:
	# The ride has no direction of time at all: the same ticks give the same
	# ride whether Shift is held or not. In the level it is never recorded.
	var cart := Minecart.new()
	check(not cart.is_in_group("temporal"), "the cart is not a temporal object")
	check(not cart.has_method("capture_state"), "the cart keeps no history")
	cart.free()


func test_wheels_press_a_plate_like_a_step() -> void:
	var plate := TimePlate.new()
	plate.object_id = "plate_k"
	plate.target_ids = PackedStringArray(["z"])
	plate.width = 128.0
	plate.position = Vector2(500, 832)
	var room := FakeRoom.new()
	var away := Rect2()
	var wheels := Rect2(Vector2(440, 820), Vector2(140, 12))
	plate.sense(room, 1, away, [wheels])
	check(room.calls.size() == 2 and room.calls[1]["state"] == {"target": Shutter.CLOSED_MAX}, "wheels rolling onto the plate in normal time close its shutter")
	plate.sense(room, -1, away, [wheels])
	check(room.calls.size() == 2, "wheels standing on it count once")
	plate.sense(room, -1, away, [])
	plate.sense(room, -1, away, [wheels])
	check(room.calls.size() == 4 and room.calls[3]["state"] == {"target": 0}, "wheels rolling on under Shift send the closing into the past")
	plate.free()


func test_rail_switch_moves_its_blade_and_leads_by_it() -> void:
	var switch := RailSwitch.new()
	switch.main_when = RailSwitch.START_UP
	switch.apply_settings({"start": "down"})
	check(switch.capture_state() == {"blade": RailSwitch.DOWN, "target": RailSwitch.DOWN}, "a switch set to start down records it")
	check(not switch.leads_main(), "down leads to the side when main is up")
	switch.target = 0
	var max_step := int(Content.time()["max_state_step"])
	var last := switch.blade
	for i in 120:
		switch.simulate_tick(i)
		check(absi(switch.blade - last) <= max_step, "the blade moves at most max_state_step per tick")
		last = switch.blade
	check(switch.blade == 0 and switch.leads_main(), "the blade goes up and leads to the main line")
	switch.free()


func test_data_check_knows_the_minecart() -> void:
	var data: Dictionary = Content.load_json(Content.OBJECTS_PATH).duplicate(true)
	check(Content.validate_objects(data, Content.time()).is_empty(), "the shipped objects.json passes")
	(data["minecart"] as Dictionary).erase("speed_px")
	check(not Content.validate_objects(data, Content.time()).is_empty(), "a minecart without speed_px is broken data")
	data = Content.load_json(Content.OBJECTS_PATH).duplicate(true)
	data["minecart"]["seat_px"] = 200
	check(not Content.validate_objects(data, Content.time()).is_empty(), "a seat past the back of the cart is broken data")
	check(Content._object_settings_problems({"switch_1": {"start": "up"}}, "x").is_empty(), "'start': 'up' is valid level data")


func test_level_has_the_switches_the_hopper_and_the_cart() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var objects := {}
	for node in room.find_children("*", "", true, false):
		if node.get("object_id") != null:
			objects[str(node.get("object_id"))] = node
	check(objects.has("switch_1") and not (objects["switch_1"] as RailSwitch).leads_main(), "switch 1 starts towards dead end 1")
	check(objects.has("switch_2") and not (objects["switch_2"] as RailSwitch).leads_main(), "switch 2 starts towards dead end 2")
	var plates := room.find_children("*", "TimePlate", true, false)
	check(plates.size() == 3, "level 04 has plates 1, 2 and K, has %d" % plates.size())
	for plate: Node in plates:
		for id in (plate as TimePlate).target_ids:
			check(objects.has(id), "%s drives %s, which is in the level" % [(plate as TimePlate).object_id, id])
	check(objects.has("hopper") and (objects["hopper"] as Hopper).batch <= 1, "the hopper has poured at most once, for the intro")
	check(objects.has("shutter_z") and (objects["shutter_z"] as Shutter).bars_carts, "shutter Z stands over the rails")
	check(objects.has("wall") and (objects["wall"] as BrickWall).is_whole(), "the bricked wall stands whole")
	var rails := room.get_node_or_null("Rails") as Rails
	check(rails != null and rails.track().problems().is_empty(), "the rails of level 04 are whole: %s" % ("" if rails == null else ", ".join(rails.track().problems())))
	var cart := room.get_node_or_null("Minecart") as Minecart
	check(cart != null and cart.ride.mode == CartRide.Mode.PARKED, "the cart waits parked at the top of the ramp")
	var blocks := room.get_node("Blocks") as TileMapLayer
	check(blocks.get_used_rect().size == Vector2i(30, 17), "level 04 is one screen, 30x17 cells, is %s" % blocks.get_used_rect().size)
	room.queue_free()
	await _tree.process_frame


func test_cart_rolls_on_under_shift_while_the_world_rewinds() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var cart := room.get_node("Minecart") as Minecart
	var player := room.get_node("Player") as Player
	var room_time := room.get_node("RoomTime") as RoomTime
	for i in 120:
		await _tree.physics_frame
	await _intro_done(cart)
	# She lands on the platform: put her just above it.
	var deck := cart.platform_rect()
	player.respawn(Vector2(deck.get_center().x, deck.position.y - 2.0))
	for i in 30:
		await _tree.physics_frame
	check(player.is_riding() and cart.has_rider(), "landing on the platform she rides")
	# Switch 1 is thrown while she rides: the world has a past to rewind.
	var switch := room.get_node("Switch1") as RailSwitch
	room_time.apply_change("switch_1", {"target": RailSwitch.DOWN})
	for i in 60:
		await _tree.physics_frame
	check(switch.blade == RailSwitch.DOWN, "the thrown switch is down")
	var x_before := cart.position.x
	Input.action_press("rewind")
	for i in 60:
		await _tree.physics_frame
	var blade_after := switch.blade
	var x_after := cart.position.x
	Input.action_release("rewind")
	await _tree.physics_frame
	check(blade_after < RailSwitch.DOWN, "Shift turns the switch back (blade %d)" % blade_after)
	check(x_after < x_before - 50.0, "the cart rolls on forward under Shift (x %.0f -> %.0f)" % [x_before, x_after])
	check(player.body_rect().end.y <= cart.position.y and absf(player.position.x - cart.seat_position().x) < 1.0, "she rides on its platform")
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
	room.queue_free()
	await _tree.process_frame


func test_stream_pours_pigs_one_by_one_into_the_pit() -> void:
	var hopper := {"count": 5, "delay_seconds": 0.5, "pour_seconds": 2.0, "gravity_px": 1800, "spread_px": 40}
	var stream := StoneStream.from_data(hopper, Content.time(), 400.0)
	check(not stream.in_air(0, -1) and stream.waiting(4, -1), "a closed hopper keeps every pig")
	check(stream.waiting(0, stream.delay_ticks - 1) and stream.in_air(0, stream.delay_ticks), "the first pig leaves after the delay")
	check(stream.release_tick(1) > stream.release_tick(0), "the pigs leave one by one")
	var first := stream.offset(0, stream.delay_ticks + 5).y
	var second := stream.offset(0, stream.delay_ticks + 10).y - first
	check(second > first, "a pig falls faster and faster (%.1f, then %.1f px)" % [first, second])
	check(not stream.in_air(4, stream.end_tick()), "after end_tick every pig is in the pit")
	for i in stream.count:
		check(absf(stream.offset(i, 0).x) <= 20.0, "pig %d falls under the gate" % i)


func test_hopper_records_its_pour_and_rewinds_it() -> void:
	var hopper := Hopper.new()
	_tree.root.add_child(hopper)
	var room := FakeRoom.new()
	hopper.open(room)
	check(room.calls.size() == 1 and room.calls[0]["state"] == {"pour": 0, "batch": 1}, "the launch opens a new pour through apply_change")
	hopper.restore_state({"pour": 0, "batch": 1})
	var saved := hopper.capture_state()
	var max_step := int(Content.time()["max_state_step"])
	var last := hopper.pour
	for i in hopper.stream.end_tick() + 30:
		hopper.simulate_tick(i)
		check(absi(hopper.pour - last) <= max_step, "the pour counts without jumps")
		last = hopper.pour
	check(hopper.pour == hopper.stream.end_tick() and hopper.pigs_in_air().is_empty(), "the pour stops counting once every pig is gone")
	hopper.restore_state(saved)
	for i in hopper.stream.delay_ticks + 2:
		hopper.simulate_tick(i)
	var pigs := hopper.pigs_in_air()
	check(pigs.size() == 1, "a rewound and replayed pour shows the same pigs")
	hopper.take(str(pigs[0]["key"]))
	check(hopper.pigs_in_air().is_empty(), "a pig the cart took is gone from the stream")
	hopper.restore_state(saved)
	for i in hopper.stream.delay_ticks + 2:
		hopper.simulate_tick(i)
	check(hopper.pigs_in_air().is_empty(), "it stays gone at every world time: a rewind never shows it twice")
	hopper.forget_taken()
	check(hopper.pigs_in_air().size() == 1, "a room reset gives it back")
	hopper.free()


func test_hoist_tips_the_load_and_loaded_it_rolls_slower() -> void:
	var ride := CartRide.new(_track(), Content.objects()["minecart"], "ramp", 100.0)
	ride.board()
	ride.load = 3
	for i in 240:
		ride.step(1.0 / 60.0, func(_id: String) -> bool: return true)
	var params: Dictionary = Content.objects()["minecart"]
	check(ride.speed <= float(params["loaded_speed_px"]) + 0.01, "loaded it rolls at loaded_speed_px (%.0f)" % ride.speed)
	ride._start_hoist()
	check(ride.load == 0, "the hoist tips the load into the pit")


func test_data_check_knows_the_hopper_and_the_rewind_cap() -> void:
	var data: Dictionary = Content.load_json(Content.OBJECTS_PATH).duplicate(true)
	(data["hopper"] as Dictionary).erase("pour_seconds")
	check(not Content.validate_objects(data, Content.time()).is_empty(), "a hopper without pour_seconds is broken data")
	data = Content.load_json(Content.OBJECTS_PATH).duplicate(true)
	data["minecart"]["loaded_speed_px"] = data["minecart"]["speed_px"]
	check(not Content.validate_objects(data, Content.time()).is_empty(), "a loaded cart as fast as an empty one is broken data")
	data = Content.load_json(Content.OBJECTS_PATH).duplicate(true)
	data["minecart"]["break_load"] = int(data["hopper"]["count"]) + 1
	check(not Content.validate_objects(data, Content.time()).is_empty(), "a break load above one pour is broken data")
	var entry := {"id": "level_x", "scene": "res://levels/level_04.tscn", "rewind_speed_max": 0.5}
	var problems := Content.validate_levels([entry], 20.0)
	check(not problems.is_empty(), "a rewind cap below 1 is broken data")


## Rides level 04 with both switches set and holds Shift from `press` ticks
## after boarding for `hold` ticks (-1: never); the load where it stopped.
func _ride_and_catch(press: int, hold: int) -> int:
	var end: Dictionary = await _ride_level(press, press + hold if press >= 0 else -1)
	if int(end["mode"]) != CartRide.Mode.STOPPED and int(end["load"]) >= int(Content.objects()["minecart"]["break_load"]):
		print("  ride from %d for %d ended in mode %d at x %.2f" % [press, hold, end["mode"], end["nose"]])
	return int(end["load"])


## Rides level 04 after its intro with both switches set: Shift from `press`
## to `release` ticks after boarding (-1: never). Where the ride ended:
## { mode, nose (x in cells), load, wall_broke (it broke at some tick),
## wall_whole_after (whole again later, under Shift), z_closed_max }.
func _ride_level(press: int, release: int, after_end := 0) -> Dictionary:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var room_time := room.get_node("RoomTime") as RoomTime
	room_time.apply_change("switch_1", {"target": RailSwitch.DOWN})
	room_time.apply_change("switch_2", {"target": 0})
	var cart := room.get_node("Minecart") as Minecart
	var wall := room.get_node("BrickWall") as BrickWall
	for i in 60:
		await _tree.physics_frame
	await _intro_done(cart)
	var player := room.get_node("Player") as Player
	var deck := cart.platform_rect()
	player.respawn(Vector2(deck.get_center().x, deck.position.y - 2.0))
	var t := 0
	var boarded := -1
	var broke := false
	var whole_after := false
	var ended := -1
	while t < 1400 and (ended < 0 or t - ended < after_end):
		await _tree.physics_frame
		t += 1
		if boarded < 0 and cart.has_rider():
			boarded = t
		if boarded >= 0 and press >= 0 and t - boarded == press:
			Input.action_press("rewind")
		if boarded >= 0 and t - boarded == release:
			Input.action_release("rewind")
		if not wall.is_whole():
			broke = true
		elif broke:
			whole_after = true
		if ended < 0 and (cart.ride.mode == CartRide.Mode.STOPPED or cart.ride.mode == CartRide.Mode.BUMPED):
			ended = t
	Input.action_release("rewind")
	var end := {"mode": cart.ride.mode, "nose": cart.ride.nose().x / 64.0, "load": cart.ride.load,
		"wall_broke": broke, "wall_whole_after": whole_after}
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
	room.queue_free()
	await _tree.process_frame
	return end


## Waits until the intro ride (from the hoist, level 04) is back at the park.
func _intro_done(cart: Minecart) -> void:
	var guard := 0
	while cart.intro_running() and guard < 1800:
		await _tree.physics_frame
		guard += 1


func test_cart_catches_the_pigs_only_by_shift_and_the_window_is_3_seconds() -> void:
	var need := int(Content.objects()["minecart"]["break_load"])
	var none: int = await _ride_and_catch(-1, 0)
	check(none == 0, "in normal time the pigs are in the pit before the cart comes (caught %d)" % none)
	# The window of the press: 3 s apart, both ends catch enough (D216).
	# Shift is let go past shutter Z (session 2): held longer, the world would
	# rewind into the intro, where Z was down.
	var early: int = await _ride_and_catch(250, 300)
	var late: int = await _ride_and_catch(430, 120)
	check(early >= need, "Shift pressed 3 s before the late end still catches %d pigs (caught %d)" % [need, early])
	check(late >= need, "Shift pressed at the late end of the window catches %d pigs (caught %d)" % [need, late])


func test_latched_shutter_waits_its_delay_before_closing_never_before_opening() -> void:
	var shutter := Shutter.new()
	shutter.apply_settings({"start": "open", "delay_seconds": 0.5})
	var state := shutter.capture_state()
	check(state.has("aim") and state.has("hold"), "a latched shutter records its aim and its hold")
	shutter.target = Shutter.CLOSED_MAX
	var ticks := Content.world_ticks_per_second(Content.time())
	var latch := int(round(0.5 * ticks))
	for i in latch:
		shutter.simulate_tick(i)
	check(shutter.closed == 0, "during the latch a closing shutter stays open (closed %d)" % shutter.closed)
	for i in 3:
		shutter.simulate_tick(i)
	check(shutter.closed > 0, "after the latch it closes")
	var mid := shutter.capture_state()
	shutter.target = 0
	shutter.simulate_tick(0)
	check(shutter.closed < int(mid["closed"]), "an opening never waits for the latch")
	shutter.restore_state(mid)
	check(shutter.capture_state() == mid, "a latched shutter restores what it recorded")
	var plain := Shutter.new()
	plain.apply_settings({"start": "open"})
	check(plain.capture_state() == {"closed": 0, "target": 0}, "a shutter without a latch records as before")
	shutter.free()
	plain.free()


func test_shutter_z_waits_above_the_cart_and_stops_its_front() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var z := room.get_node("ShutterZ") as Shutter
	var cart := room.get_node("Minecart") as Minecart
	cart.set_physics_process(false)
	check(z.is_in_group("rail_barrier"), "shutter Z bars carts")
	check(z.is_open(), "Z starts open")
	cart.position = Vector2(z.position.x, 13.0 * 64.0)
	z.target = Shutter.CLOSED_MAX
	for i in 200:
		z.simulate_tick(i)
	check(not z.rect_at(z.closed).intersects(cart.outline_rect()), "Z closing onto the cart waits above it and her")
	check(z.closed < Shutter.CLOSED_MAX, "Z does not close while the cart is under it")
	cart.position = Vector2(z.position.x + 600.0, 13.0 * 64.0)
	for i in 200:
		z.simulate_tick(i)
	check(z.closed == Shutter.CLOSED_MAX, "Z closes once the cart is gone")
	var front := Rect2(Vector2(z.position.x - 2.0, 12.0 * 64.0), Vector2(4.0, 64.0))
	check(z.meet_cart(FakeRoom.new(), front, true) == "bounce", "a closed Z stops the front of the cart, loaded or not")
	z.restore_state({"closed": 0, "target": 0, "aim": 0, "hold": 0})
	check(z.meet_cart(FakeRoom.new(), front, true) == "", "an open Z lets it pass")
	room.queue_free()
	await _tree.process_frame


func test_wall_stops_a_light_cart_and_breaks_for_a_heavy_one() -> void:
	var wall := BrickWall.new()
	wall.size = Vector2(32, 256)
	wall.position = Vector2(200, 832)
	var front := Rect2(Vector2(214, 768), Vector2(4, 64))
	var away := Rect2(Vector2(400, 768), Vector2(4, 64))
	var room := FakeRoom.new()
	check(wall.meet_cart(room, away, true) == "", "the wall meets only a front at its face")
	check(wall.meet_cart(room, front, false) == "bounce", "a light cart bounces off the whole wall")
	check(wall.is_whole() and room.calls.is_empty(), "a bounce leaves the wall whole")
	check(wall.meet_cart(room, front, true) == "break", "a heavy cart breaks through")
	check(room.calls.size() == 1 and room.calls[0]["id"] == wall.object_id and room.calls[0]["state"] == {"broken": 1},
		"the break is a change of the room (interference left of the head)")
	check(wall.meet_cart(room, front, false) == "", "a broken wall lets any cart pass")
	var max_step := int(Content.time()["max_state_step"])
	var last := wall.broken
	for i in 200:
		wall.simulate_tick(i)
		check(wall.broken - last <= max_step, "the bricks fly without jumps")
		last = wall.broken
	check(wall.broken == BrickWall.BROKEN_MAX, "the bricks come to rest")
	wall.restore_state({"broken": 0})
	check(wall.is_whole() and wall.capture_state() == {"broken": 0}, "under Shift the wall stands whole again")
	wall.free()


func test_cart_bounces_off_a_barrier_and_jolts_through_a_break() -> void:
	var at := 500.0
	for verdict: String in ["bounce", "break"]:
		var ride := CartRide.new(_track(), Content.objects()["minecart"], "ramp", 400.0)
		ride.board()
		var met := [false]
		var barrier := func(from: Vector2, to: Vector2, _load: int) -> String:
			if not met[0] and from.x >= at and to.x < at:
				met[0] = true
				return verdict
			return ""
		var shaken := false
		for i in 600:
			ride.step(1.0 / 60.0, func(_id: String) -> bool: return true, barrier)
			if verdict == "break" and met[0] and ride.mode == CartRide.Mode.ROLLING and ride.shake_px() > 0.0:
				shaken = true
			if verdict == "bounce" and ride.mode == CartRide.Mode.BUMPED:
				break
		if verdict == "bounce":
			check(ride.mode == CartRide.Mode.BUMPED, "a barrier that says bounce bumps the cart")
			check(ride.nose().x >= at - 1.0, "the bounced front stays at the barrier (at %.1f)" % ride.nose().x)
		else:
			check(shaken, "breaking through, the cart jolts and rolls on")
			check(ride.mode == CartRide.Mode.STOPPED, "after the break it reaches the station")


func test_cart_drops_from_the_hoist_onto_the_rails() -> void:
	var ride := CartRide.new(_track(), Content.objects()["minecart"], "ramp", 400.0)
	check(not ride.drop_from_hoist("nowhere", 0.0), "the hoist drops only onto the rails")
	check(ride.drop_from_hoist("main", 100.0), "a parked cart can go on the hoist")
	check(ride.mode == CartRide.Mode.HOISTED and not ride.on_rails(), "on the hoist its wheels are off the rails")
	var ticks := _run(ride, true, func() -> bool: return ride.mode != CartRide.Mode.HOISTED, 600)
	check(ticks < 600 and ride.mode == CartRide.Mode.ROLLING, "the hook lets it go onto the rails")
	check(ride.segment == "main" and absf(ride.distance - 100.0) < 5.0, "it lands where it was sent")
	_run(ride, true, func() -> bool: return ride.mode == CartRide.Mode.STOPPED, 900)
	check(ride.mode == CartRide.Mode.STOPPED, "from there it rolls on to the station")


func test_intro_rides_from_the_hoist_past_z_into_the_wall_and_back() -> void:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var cart := room.get_node("Minecart") as Minecart
	var z := room.get_node("ShutterZ") as Shutter
	var wall := room.get_node("BrickWall") as BrickWall
	var hopper := room.get_node("Hopper") as Hopper
	check(cart.intro_running() and cart.gate_closed(), "the intro runs at the start and the barrier stands")
	var poured := false
	var z_shut := false
	var bumped_at := -1.0
	var t := 0
	while cart.intro_running() and t < 1800:
		await _tree.physics_frame
		t += 1
		poured = poured or hopper.is_pouring()
		z_shut = z_shut or z.closed == Shutter.CLOSED_MAX
		if bumped_at < 0.0 and cart.ride.mode == CartRide.Mode.BUMPED:
			bumped_at = cart.ride.nose().x
	check(poured, "the hopper opens by itself in the intro")
	check(z_shut, "the empty cart presses K and Z comes down behind it")
	check(bumped_at > 0.0 and absf(bumped_at - wall.rect().end.x) < 4.0,
		"the empty cart passes Z and bumps at the wall (front at %.1f, face %.1f)" % [bumped_at, wall.rect().end.x])
	check(wall.is_whole(), "the empty cart leaves the wall whole")
	check(not cart.intro_running() and cart.ride.mode == CartRide.Mode.PARKED and not cart.gate_closed(),
		"the hoist brings it back to the park and the barrier opens")
	check(z.is_open(), "the hoist lifted Z on its way back")
	check(cart.ride.load == 0, "the intro cart caught nothing")
	await _tree.physics_frame
	var timeline := (room.get_node("RoomTime") as RoomTime).world.timeline
	check(timeline.size() <= 3, "back at the park, the room's history starts again (%d frames)" % timeline.size())
	room.queue_free()
	await _tree.process_frame


func test_level_rides_end_at_z_at_the_wall_or_at_the_station() -> void:
	var wall_x := 3.6
	var z_x := 7.8
	var none: Dictionary = await _ride_level(-1, -1)
	check(int(none["mode"]) == CartRide.Mode.BUMPED and absf(float(none["nose"]) - wall_x) < 0.1,
		"without Shift at the hopper the empty cart bounces off the wall (front at %.2f)" % none["nose"])
	var few: Dictionary = await _ride_level(445, 650)
	check(int(few["load"]) > 0 and int(few["load"]) < int(Content.objects()["minecart"]["break_load"]),
		"Shift late at the hopper catches only a few pigs (%d)" % few["load"])
	check(int(few["mode"]) == CartRide.Mode.BUMPED and absf(float(few["nose"]) - wall_x) < 0.1,
		"with too few pigs the cart bounces off the wall (front at %.2f)" % few["nose"])
	var early_release: Dictionary = await _ride_level(300, 465)
	check(int(early_release["mode"]) == CartRide.Mode.BUMPED and absf(float(early_release["nose"]) - z_x) < 0.1,
		"Shift let go before K: Z comes down before the loaded cart (front at %.2f)" % early_release["nose"])
	var held: Dictionary = await _ride_level(400, 800, 120)
	check(int(held["mode"]) == CartRide.Mode.STOPPED and bool(held["wall_broke"]),
		"Shift held through K and Z: the loaded cart breaks the wall and stops at the station")
	check(bool(held["wall_whole_after"]), "Shift still held after the break: the bricks fly back behind the cart")


func test_data_check_knows_the_wall_and_the_intro_from_the_hoist() -> void:
	var data: Dictionary = Content.load_json(Content.OBJECTS_PATH).duplicate(true)
	(data["brick_wall"] as Dictionary).erase("burst_seconds")
	check(not Content.validate_objects(data, Content.time()).is_empty(), "a wall without burst_seconds is broken data")
	data = Content.load_json(Content.OBJECTS_PATH).duplicate(true)
	(data["minecart"] as Dictionary).erase("clear_px")
	check(not Content.validate_objects(data, Content.time()).is_empty(), "a minecart without clear_px is broken data")
	var good := {"minecart": {"intro_ride": {"segment": "main_2", "distance_px": 32, "hoist_after_seconds": 3.5}}}
	check(Content._object_settings_problems(good, "x").is_empty(), "the intro from the hoist is valid level data")
	check(Content._object_settings_problems({"minecart": {"intro_ride": true}}, "x").is_empty(), "the intro from the park still is")
	for broken: Dictionary in [{"segment": "", "distance_px": 0, "hoist_after_seconds": 1},
			{"segment": "a", "distance_px": -1, "hoist_after_seconds": 1}, {"segment": "a", "distance_px": 0}]:
		check(not Content._object_settings_problems({"minecart": {"intro_ride": broken}}, "x").is_empty(),
			"a broken intro from the hoist is reported: %s" % broken)
	check(not Content._object_settings_problems({"shutter_z": {"delay_seconds": 0}}, "x").is_empty(),
		"a latch of 0 seconds is broken data")
