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
	check(plates.size() == 2, "level 04 has plates 1 and 2, has %d" % plates.size())
	for plate: Node in plates:
		for id in (plate as TimePlate).target_ids:
			check(objects.has(id), "%s drives %s, which is in the level" % [(plate as TimePlate).object_id, id])
	check(objects.has("hopper") and (objects["hopper"] as Hopper).pour == -1, "the hopper waits closed")
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
## after boarding for `hold` ticks (-1: never); the load at the station.
func _ride_and_catch(press: int, hold: int) -> int:
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	var room_time := room.get_node("RoomTime") as RoomTime
	room_time.apply_change("switch_1", {"target": RailSwitch.DOWN})
	room_time.apply_change("switch_2", {"target": 0})
	for i in 60:
		await _tree.physics_frame
	var cart := room.get_node("Minecart") as Minecart
	var player := room.get_node("Player") as Player
	var deck := cart.platform_rect()
	player.respawn(Vector2(deck.get_center().x, deck.position.y - 2.0))
	var t := 0
	var boarded := -1
	while t < 1200 and cart.ride.mode != CartRide.Mode.STOPPED and cart.ride.mode != CartRide.Mode.BUMPED:
		await _tree.physics_frame
		t += 1
		if boarded < 0 and cart.has_rider():
			boarded = t
		if boarded >= 0 and press >= 0 and t - boarded == press:
			Input.action_press("rewind")
		if boarded >= 0 and press >= 0 and t - boarded == press + hold:
			Input.action_release("rewind")
	Input.action_release("rewind")
	var load := cart.ride.load if cart.ride.mode == CartRide.Mode.STOPPED else -1
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
	room.queue_free()
	await _tree.process_frame
	return load


func test_cart_catches_the_pigs_only_by_shift_and_the_window_is_3_seconds() -> void:
	var need := int(Content.objects()["minecart"]["break_load"])
	var none: int = await _ride_and_catch(-1, 0)
	check(none == 0, "in normal time the pigs are in the pit before the cart comes (caught %d)" % none)
	# The window of the press: 3 s apart, both ends catch enough (D216).
	var early: int = await _ride_and_catch(250, 400)
	var late: int = await _ride_and_catch(430, 400)
	check(early >= need, "Shift pressed 3 s before the late end still catches %d pigs (caught %d)" % [need, early])
	check(late >= need, "Shift pressed at the late end of the window catches %d pigs (caught %d)" % [need, late])
