extends RefCounted
## Tests of level 03 «Нить» (card docs/levels/03.md, D177): the torch taken
## and put back by walking past its stand, out in the rain even in the hands;
## the ropes it lights, which burn through; the winch's board that stays where
## it is once its brake rope has burnt; the cage the counterweight lifts once
## its stop rope has burnt; the level's picture and geometry. Also the objects
## of the earlier level 03 that stay in the code: the latch platform and the
## door that opens once (D103), the sprinkler with its start, sensor and pipe,
## the chain of wood zones and the oil.

const PLATFORM_PATH := "res://objects/platform.tscn"
const DOOR_PATH := "res://objects/door.tscn"
const LEVEL_PATH := "res://levels/level_03.tscn"

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_latch_holds_a_platform_only_at_its_start() -> void:
	var held: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	held.holdable = true
	held.travel = Vector2(-192, 0)
	held.apply_settings({"cycle": "once", "speed": 192, "delay_seconds": 0.5})
	var base := held.position_at(0)
	held.powered = true
	for i in 5 * 60:
		held.simulate_tick(i)
	check(held.position == base, "a latched platform stays at its start, is at %s" % [held.position])
	check(held.capture_state().get("powered", false) == true, "a holdable platform records its latch")
	held.powered = false
	for i in 5 * 60:
		held.simulate_tick(i)
	check(is_equal_approx(held.position.x, base.x - 192.0), "a released platform rides on, is at %s" % [held.position])
	held.free()

	var late: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	late.holdable = true
	late.travel = Vector2(-192, 0)
	late.apply_settings({"cycle": "once", "speed": 192, "delay_seconds": 0.5})
	for i in late.once_last_phase() - 5:
		late.simulate_tick(i)
	late.powered = true
	for i in 60:
		late.simulate_tick(i)
	check(is_equal_approx(late.position.x, late.position_at(0).x - 192.0), "the latch never holds or pulls back a platform that has left")
	late.free()

	var plain: MovingPlatform = (load(PLATFORM_PATH) as PackedScene).instantiate()
	check(not plain.capture_state().has("powered"), "a platform without a latch records no 'powered'")
	plain.free()


func test_door_opens_once_and_stays_open() -> void:
	var door: Door = (load(DOOR_PATH) as PackedScene).instantiate()
	door.apply_settings({"cycle": "opens_once", "delay_seconds": 1, "open_seconds": 1})
	var ticks := int(round(Content.world_ticks_per_second(Content.time())))
	check(door.open == 0, "a door that opens once starts closed, is %d" % door.open)
	for i in ticks:
		door.simulate_tick(i)
	check(door.open == 0, "it waits closed for delay_seconds, is %d" % door.open)
	var last := door.open
	for i in ticks + 1:
		door.simulate_tick(i)
		check(door.open >= last, "a door that opens once only opens")
		check(door.open - last <= int(Content.time()["max_state_step"]), "the door jumps %d per tick" % (door.open - last))
		last = door.open
	check(door.open == Door.OPEN_MAX, "it is open after open_seconds, is %d" % door.open)
	var state := door.capture_state()
	for i in 10 * ticks:
		door.simulate_tick(i)
	check(door.capture_state() == state, "an open door that opened once never changes again")
	door.free()


func test_sprinkler_rains_only_at_full_flow_and_is_no_tank() -> void:
	var sprinkler := Sprinkler.new()
	sprinkler.size = Vector2(256, 200)
	check(sprinkler.water_global_rect() == Rect2(), "a shut sprinkler wets nothing")
	sprinkler.powered = true
	var last := sprinkler.flow
	var ticks := 0
	while not sprinkler.is_raining() and ticks < 10 * 60:
		sprinkler.simulate_tick(ticks)
		check(sprinkler.flow - last <= int(Content.time()["max_state_step"]), "the flow jumps %d per tick" % (sprinkler.flow - last))
		check(sprinkler.is_raining() or sprinkler.water_global_rect() == Rect2(), "the rain wets only at full flow")
		last = sprinkler.flow
		ticks += 1
	var spin_up := float(Content.objects()["sprinkler"]["spin_up_seconds"]) * 60.0
	check(absf(ticks - spin_up) <= 1.0, "the rain is full after spin_up_seconds, took %d ticks" % ticks)
	check(sprinkler.water_global_rect().size == sprinkler.size, "full rain wets its whole rect")
	check(not (sprinkler as Object) is Water, "a sprinkler is not a tank: the hero never wades in it")
	sprinkler.powered = false
	for i in 10 * 60:
		sprinkler.simulate_tick(i)
	check(sprinkler.flow == 0 and sprinkler.water_global_rect() == Rect2(), "a shut sprinkler runs dry")
	sprinkler.free()


func test_sprinkler_with_a_start_holds_its_rain_until_then() -> void:
	var sprinkler := Sprinkler.new()
	sprinkler.apply_settings({"start_seconds": 1.0})
	sprinkler.powered = true
	for tick in range(1, 60):
		sprinkler.simulate_tick(tick)
	check(sprinkler.flow == 0, "a powered sprinkler stays dry before its start")
	for tick in range(60, 120):
		sprinkler.simulate_tick(tick)
	check(sprinkler.is_raining(), "after its start it rains on its own")
	sprinkler.powered = false
	for tick in range(120, 180):
		sprinkler.simulate_tick(tick)
	check(sprinkler.flow == 0, "unpowered, it shuts")
	sprinkler.free()


func test_wood_catches_from_the_zone_before_it_in_a_chain() -> void:
	var wood: Dictionary = Content.objects()["wood"]
	var first := WoodBurn.new(wood, Content.time())
	var second := WoodBurn.new(wood, Content.time())
	var spread := int(round(float(wood["spread_seconds"]) * 60.0))
	check(first.spread_ticks == spread, "spread_seconds comes from objects.json")
	check(not second.catches_from(first, false), "a whole zone before it lights nothing")
	first.ignite()
	var caught := -1
	for i in spread + 5:
		first.tick(false)
		if caught < 0 and second.catches_from(first, false):
			caught = i + 1
	check(caught == spread, "the next zone catches after spread_seconds, caught on tick %d" % caught)
	check(not second.catches_from(first, true), "a wet zone never catches")
	second.ignite()
	check(not second.catches_from(first, false), "a burning zone does not catch again")
	first.phase = WoodBurn.Phase.BURNT
	var third := WoodBurn.new(wood, Content.time())
	check(not third.catches_from(first, false), "a burnt zone has fallen and lights nothing")


func test_sprinkler_sensor_opens_it_when_its_zone_burns() -> void:
	var holder := Node2D.new()
	var zone: WoodZone = (load("res://objects/wood_zone.tscn") as PackedScene).instantiate()
	zone.object_id = "watched"
	var sprinkler := Sprinkler.new()
	sprinkler.sensor_id = "watched"
	holder.add_child(zone)
	holder.add_child(sprinkler)
	_tree.root.add_child(holder)
	sprinkler.simulate_tick(1)
	check(not sprinkler.powered, "the sensor waits while its zone is whole")
	zone.burn.ignite()
	sprinkler.simulate_tick(2)
	check(sprinkler.powered, "fire under the sensor opens the sprinkler")
	zone.burn.douse()
	sprinkler.simulate_tick(3)
	check(sprinkler.powered, "once open it stays open")
	holder.queue_free()
	await _tree.process_frame


func test_water_pipe_follows_its_sprinkler() -> void:
	var sprinkler := Sprinkler.new()
	sprinkler.name = "Source"
	var pipe := WaterPipe.new()
	pipe.source_path = NodePath("../Source")
	pipe.points = PackedVector2Array([Vector2.ZERO, Vector2(400, 0), Vector2(400, 200)])
	var holder := Node2D.new()
	holder.add_child(sprinkler)
	holder.add_child(pipe)
	_tree.root.add_child(holder)
	check(pipe.fill == 0.0 and pipe.run == 0.0, "a pipe to a shut sprinkler is empty")
	sprinkler.powered = true
	pipe.refresh()
	check(pipe.fill == 1.0 and pipe.run == 0.0, "an open line before its rain starts is full and still")
	sprinkler.flow = Sprinkler.FLOW_MAX
	pipe.refresh()
	check(pipe.run == 1.0, "water runs in the pipe while it rains")
	sprinkler.powered = false
	sprinkler.flow = Sprinkler.FLOW_MAX / 2
	pipe.refresh()
	check(is_equal_approx(pipe.fill, 0.5) and is_equal_approx(pipe.run, 0.5), "a closed line drains with its flow")
	pipe.on_world_tick(30, true)
	var at_30 := pipe.dash_offset()
	pipe.on_world_tick(31, true)
	var at_31 := pipe.dash_offset()
	pipe.on_world_tick(30, false)
	check(at_31 != at_30, "the dashes move with world time")
	check(pipe.dash_offset() == at_30, "the dashes stand where they were at the same world frame, so they run back under Shift")
	var look := Content.look_pipe()
	pipe.kind = WaterPipe.Kind.MAIN
	check(pipe.width() == float(look["main_width_px"]), "the main takes its width from look.json")
	pipe.kind = WaterPipe.Kind.FEED
	check(pipe.width() < float(look["main_width_px"]), "the feed pipe is thinner than the main")
	holder.queue_free()
	await _tree.process_frame


func test_pipe_look_data_is_checked() -> void:
	var data := Content.look().duplicate(true)
	check(Content.validate_look(data).is_empty(), "look.json passes the data check")
	data["pipe"].erase("dash_speed_px")
	check(not Content.validate_look(data).is_empty(), "a missing pipe number must be reported")
	data = Content.look().duplicate(true)
	data["pipe"]["water"] = "blue-ish"
	check(not Content.validate_look(data).is_empty(), "a broken pipe colour must be reported")
	data = Content.look().duplicate(true)
	data["pipe"]["wall_px"] = 8
	check(not Content.validate_look(data).is_empty(), "walls thicker than the feed pipe must be reported")


func _press(action: String) -> void:
	Input.action_press(action)
	await _ticks(6)
	Input.action_release(action)


func _load() -> Node:
	Input.action_release("rewind")
	_reset_time()
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	# Two ticks, as the solution player settles: the bodies' positions come
	# back from the physics server a tick late.
	await _ticks(2)
	return room


func _free(room: Node) -> void:
	for action in ["rewind", "move_right", "move_left", "interact", "use_item"]:
		Input.action_release(action)
	room.queue_free()
	await _tree.process_frame
	_reset_time()


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame


func _reset_time() -> void:
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")


func test_oil_burns_on_under_rain_and_only_the_jet_puts_it_out() -> void:
	var oil := WoodBurn.new(Content.objects()["wood"], Content.time())
	oil.oil = true
	oil.ignite()
	for i in oil.burn_ticks * 2:
		check(oil.tick(i % 2 == 0) == WoodBurn.Event.NONE, "oil neither burns out nor goes out under water")
	check(oil.is_burning(), "oil burns on and on, rain or not")
	check(not oil.is_solid(), "oil on the floor is never solid")
	check(oil.douse(), "the jet in normal time puts the oil out")
	check(not oil.is_solid(), "put-out oil is not solid either")


func test_oil_slows_the_walk_like_water() -> void:
	var params := Content.player()
	var motion := PlayerMotion.new(params)
	var v := Vector2.ZERO
	var slow := Vector2.ZERO
	for i in 120:
		v = motion.step(v, 1.0, false, true, 1.0 / 60.0)
		slow = motion.step(slow, 1.0, false, true, 1.0 / 60.0, {"slow": true})
	check(is_equal_approx(v.x, float(params["walk_speed"])), "on land she walks at walk_speed")
	check(is_equal_approx(slow.x, float(params["walk_speed"]) * float(params["water_walk_factor"])), "in oil she walks as in water")
	check(slow.y == 0.0, "oil holds no one up and drags no one down on the floor")


func test_sprinkler_can_rain_from_the_first_frame_and_stop() -> void:
	var sprinkler := Sprinkler.new()
	sprinkler.powered = true
	sprinkler.start_full = true
	sprinkler.apply_settings({"stop_seconds": 1.0})
	_tree.root.add_child(sprinkler)
	check(sprinkler.is_raining(), "a sprinkler that starts full rains on the first frame")
	for tick in range(1, 60):
		sprinkler.simulate_tick(tick)
	check(sprinkler.is_raining(), "it rains until its stop")
	for tick in range(60, 120):
		sprinkler.simulate_tick(tick)
	check(sprinkler.flow == 0, "after its stop the rain runs dry, powered or not")
	sprinkler.queue_free()
	await _tree.process_frame


func test_rope_burns_through_and_rain_puts_it_out() -> void:
	var rope := FireRope.new()
	rope.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -200)])
	var holder := Node2D.new()
	holder.add_child(rope)
	_tree.root.add_child(holder)
	var seconds := float(Content.objects()["rope"]["burn_seconds"])
	check(rope.burn_ticks == int(round(seconds * 60.0)), "burn_seconds comes from objects.json")
	check(rope.torch_change() == {"burn": 0}, "a whole rope catches from a torch")
	rope.restore_state(rope.torch_change())
	var ticks := 0
	while not rope.is_broken() and ticks < 20 * 60:
		rope.simulate_tick(ticks)
		ticks += 1
	check(ticks == rope.burn_ticks, "the fire runs the rope in burn_seconds, took %d ticks" % ticks)
	check(rope.torch_change().is_empty(), "a broken rope catches nothing")
	check(rope.fire_point() == rope.points[1], "the fire ends at the far end")
	var rain := Sprinkler.new()
	rain.powered = true
	rain.start_full = true
	rain.size = Vector2(100, 400)
	rain.position = Vector2(0, -300)
	holder.add_child(rain)
	rope.restore_state({"burn": 10})
	rope.simulate_tick(0)
	check(rope.is_whole(), "rain over the fire puts it out; the rope stays whole")
	holder.queue_free()
	await _tree.process_frame


func test_winch_board_plays_its_keys_and_stops_when_the_brake_burns() -> void:
	var holder := Node2D.new()
	var brake := FireRope.new()
	brake.object_id = "brake"
	brake.points = PackedVector2Array([Vector2(-100, 0), Vector2(-100, -100)])
	var ramp := WinchRamp.new()
	ramp.slope_deg = 30.0
	holder.add_child(brake)
	holder.add_child(ramp)
	_tree.root.add_child(holder)
	ramp.set_keys([[0, "slope"], [1, "slope"], [2, "flat"], [3, "flat"], [4, "up"]])
	var per := Content.world_ticks_per_second(Content.time())
	check(ramp.is_slope(), "the board starts on its first key")
	var most := 0.0
	var last := ramp.tip()
	for tick in int(per * 2.5):
		ramp.simulate_tick(tick)
		most = maxf(most, ramp.tip().distance_to(last))
		last = ramp.tip()
	check(ramp.is_flat(), "between the keys it turns to the next pose")
	check(most <= float(Content.time()["max_state_step"]), "the tip moves %.1f px a tick" % most)
	brake.restore_state({"burn": brake.burn_ticks})
	ramp.simulate_tick(0)
	var held := ramp.capture_state()
	for tick in int(per * 3):
		ramp.simulate_tick(tick)
	check(ramp.locked and ramp.is_flat() and ramp.capture_state() == held, "once the brake rope has burnt the board stays where it is")
	ramp.restore_state({"clock": 0, "locked": false})
	check(ramp.is_slope() and not ramp.locked, "frames bring back the board as it was recorded")
	holder.queue_free()
	await _tree.process_frame


func test_cage_rises_when_its_stop_rope_burns_and_comes_down_in_the_frames() -> void:
	var holder := Node2D.new()
	var rope := FireRope.new()
	rope.object_id = "stop"
	rope.points = PackedVector2Array([Vector2(-200, -100), Vector2(0, 0)])
	var cage := CounterweightCage.new()
	cage.rope_id = "stop"
	cage.travel_px = 384.0
	cage.position = Vector2(0, 800)
	holder.add_child(rope)
	holder.add_child(cage)
	_tree.root.add_child(holder)
	for tick in 60:
		cage.simulate_tick(tick)
	check(cage.rise < 0 and cage.floor_y_at(cage.rise) == 800.0, "the rope holds the cage down")
	rope.restore_state({"burn": rope.burn_ticks})
	var ticks := 0
	while not cage.is_up() and ticks < 20 * 60:
		cage.simulate_tick(ticks)
		ticks += 1
	var per := Content.world_ticks_per_second(Content.time())
	var seconds := float(Content.objects()["cage"]["rise_seconds"])
	check(absf(ticks - seconds * per) <= 2.0, "the counterweight lifts the cage in rise_seconds, took %d ticks" % ticks)
	check(is_equal_approx(cage.floor_y_at(cage.rise), 800.0 - 384.0), "the cage rises its travel")
	var under := Rect2(Vector2(-22, 860.0 - 92.0), Vector2(44, 92))
	check(cage.blocks_player_at({"rise": -1}, under), "coming down onto her would crush: the world waits")
	var riding := Rect2(Vector2(-22, 800.0 - 384.0 - 92.0), Vector2(44, 92))
	check(not cage.blocks_player_at({"rise": cage.rise}, riding), "standing on its floor is riding")
	cage.restore_state({"rise": -1})
	check(cage.floor_y_at(cage.rise) == 800.0, "frames bring it back down")
	holder.queue_free()
	await _tree.process_frame


func test_level_03_prelude_leaves_the_picture_of_the_card() -> void:
	var room := await _load()
	await _ticks(150)
	var ramp: WinchRamp = room.get_node("Ramp")
	var torch: Torch = room.get_node("Torch")
	check(ramp.is_up() and not ramp.locked, "the winch has raised the board: the way is closed")
	check(not (room.get_node("Sprinkler") as Sprinkler).is_raining(), "the rain over the mezzanine has stopped")
	check(torch.mounted and torch.lit and not torch.held, "the torch burns on its stand across the pit")
	check((room.get_node("BrakeRope") as FireRope).is_whole() and (room.get_node("StopRope") as FireRope).is_whole(), "both ropes are whole")
	check((room.get_node("Cage") as CounterweightCage).rise < 0, "the cage waits at the bottom")
	await _free(room)


func test_level_03_past_has_the_slope_in_the_rain_then_the_bridge() -> void:
	var room := await _load()
	var ramp: WinchRamp = room.get_node("Ramp")
	var rain: Sprinkler = room.get_node("Sprinkler")
	var time: RoomTime = room.get_node("RoomTime")
	var flat_dry := false
	Input.action_press("rewind")
	while time.cursor() > 0:
		await _ticks(1)
		if ramp.is_flat() and not rain.is_raining():
			flat_dry = true
	await _ticks(2)
	check(flat_dry, "in the past the board lies as a bridge while the mezzanine is dry")
	check(ramp.is_slope() and rain.is_raining(), "at frame 0 the board leads up to the mezzanine and it rains there")
	check((room.get_node("Torch") as Torch).lit, "the torch burns on its stand in the whole past")
	Input.action_release("rewind")
	await _free(room)


func test_level_03_torch_is_taken_and_put_back_by_walking_past() -> void:
	var room := await _load()
	await _ticks(150)
	var torch: Torch = room.get_node("Torch")
	var player: Player = room.get_node("Player")
	player.respawn(torch.home + Vector2(-60.0, torch.floor_offset_px))
	await _ticks(4)
	Input.action_press("move_right")
	await _ticks(45)
	Input.action_release("move_right")
	check(torch.held and torch.lit, "walking past the stand with empty hands takes the torch (she is at %s, stand %s)" % [player.body_rect(), torch.stand_rect()])
	Input.action_press("move_left")
	await _ticks(70)
	Input.action_release("move_left")
	check(not torch.held and torch.mounted and torch.position == torch.home, "walking past the empty stand with the torch puts it back")
	var time: RoomTime = room.get_node("RoomTime")
	var any_held := false
	for k in range(time.world.timeline.first(), time.cursor()):
		var frame: Variant = time.world.timeline.frame_at(k)
		if frame is Dictionary and bool(((frame as Dictionary)["torch"] as Dictionary)["held"]):
			any_held = true
	check(not any_held, "put back, it takes back the frames it spent in the hands")
	await _free(room)


func test_level_03_torch_goes_out_in_the_rain_in_the_hands() -> void:
	var room := await _load()
	await _ticks(150)
	var torch: Torch = room.get_node("Torch")
	var player: Player = room.get_node("Player")
	player.respawn(torch.home + Vector2(-60.0, torch.floor_offset_px))
	await _ticks(4)
	await _press_for("move_right", 20)
	await _ticks(20)
	check(torch.held and torch.lit, "she has the burning torch")
	var time: RoomTime = room.get_node("RoomTime")
	Input.action_press("rewind")
	while time.cursor() > 0:
		await _ticks(1)
	check(torch.held and torch.lit, "dry under the mezzanine, it burns on under Shift")
	var deck: Node2D = room.get_node("Mezzanine")
	player.respawn(Vector2(deck.position.x, deck.position.y - 12.0))
	await _ticks(6)
	check(not torch.lit, "in the rain on the mezzanine it goes out in her hands")
	Input.action_release("rewind")
	await _ticks(30)
	check(not torch.lit, "nothing lights it again in the hands")
	await _free(room)


func test_level_03_geometry() -> void:
	var room := await _load()
	var params := Content.player()
	var ramp: WinchRamp = room.get_node("Ramp")
	var deck: Node2D = room.get_node("Mezzanine")
	var deck_top := Vector2(deck.position.x - ((deck.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size.x / 2.0,
		deck.position.y - ((deck.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size.y / 2.0)
	var gravity := float(params["gravity"])
	var jump_up := pow(float(params["jump_velocity"]), 2.0) / (2.0 * gravity)
	var floor_y := ramp.position.y
	check(floor_y - deck_top.y > jump_up + 20.0, "the mezzanine is out of a jump's reach from the floor")
	check(deck_top.x - ramp.position.x > 2.0 * float(params["walk_speed"]) * float(params["jump_velocity"]) / gravity, "the pit is wider than a jump")
	ramp.restore_state({"clock": 0, "locked": false})
	check(ramp.tip().distance_to(deck_top) < 2.0, "the slope's tip meets the mezzanine's edge")
	check(ramp.slope_deg < float(params["floor_max_angle_deg"]) - 5.0, "the slope is walkable")
	ramp.restore_state({"clock": int(5 * Content.world_ticks_per_second(Content.time())), "locked": false})
	check(ramp.is_flat() and ramp.tip().x > deck_top.x + 20.0, "lying, the board reaches the far bank")
	var rain := (room.get_node("Sprinkler") as Sprinkler)
	var rain_rect := Rect2(rain.global_position - Vector2(rain.size.x / 2.0, 0.0), rain.size)
	var torch: Torch = room.get_node("Torch")
	check(not rain_rect.intersects(torch.flame_rect()), "no rain falls on the torch's stand")
	var brake: FireRope = room.get_node("BrakeRope")
	check(not rain_rect.intersects(brake.light_rect()), "no rain falls on the brake rope")
	check(absf(brake.points[0].y - (floor_y - 84.0)) < 30.0, "the brake rope's end hangs at the torch's height over the floor")
	var stop: FireRope = room.get_node("StopRope")
	check(absf(stop.points[0].y - (deck_top.y - 84.0)) < 30.0, "rope 2's end hangs at the torch's height over the mezzanine")
	var cage: CounterweightCage = room.get_node("Cage")
	check(is_equal_approx(cage.floor_y_at(1000000), 7.0 * 64.0), "the cage rises to the gallery's floor")
	await _free(room)


func test_level_03_windows() -> void:
	var entry := Content.level_for_scene(LEVEL_PATH)
	var keys: Array = entry["objects"]["ramp"]["keys"]
	var slope_ends := 0.0
	var flat_from := -1.0
	var flat_to := 0.0
	for k in keys.size():
		var key := keys[k] as Array
		if str(key[1]) == "slope" and (k == 0 or str((keys[k - 1] as Array)[1]) == "slope"):
			slope_ends = float(key[0])
		if str(key[1]) == "flat":
			if flat_from < 0.0:
				flat_from = float(key[0])
			flat_to = float(key[0])
	var tempo := float(Content.time()["world_tempo"])
	check(slope_ends >= 3.0 and flat_to - flat_from >= 3.0, "the slope and the bridge each hold at least 3 s")
	var stop := float(entry["objects"]["sprinkler"]["stop_seconds"])
	check(stop > slope_ends / tempo + 0.5, "the rain stops only after the board has left the slope: the way up is never dry in the recorded past")
	check(float(entry["objects"]["brake"]["burn_seconds"]) < slope_ends / tempo, "a brake lit at frame 0 drops while the board is still sloped")


func _press_for(action: String, ticks: int) -> void:
	Input.action_press(action)
	await _ticks(ticks)
	Input.action_release(action)
