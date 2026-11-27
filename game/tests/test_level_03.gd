extends RefCounted
## Tests of level 03 «Нить» (card docs/levels/03.md, D177, D178): the torch
## taken and lit again at its burner, out in the rain even in the hands; the
## fire detector that sets off the rain, and under Shift answers only once
## time runs forward; the ropes the torch lights, which burn through; the
## winch's board (and its brake, kept in the code); the cage the
## counterweight lifts once its stop rope has burnt; the level's picture,
## geometry and windows. Also the objects
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


func test_detector_powers_its_sprinkler_once_and_rearms_after_its_rain() -> void:
	var rain := Sprinkler.new()
	rain.torch_sensor = true
	rain.size = Vector2(200, 300)
	rain.apply_settings({"rain_seconds": 1.0, "spin_up_seconds": 0.25})
	_tree.root.add_child(rain)
	check(rain.is_in_group("torch_lightable"), "a detector answers a torch like a rope")
	check(rain.light_rect() == Rect2(Vector2(-100, 0), Vector2(200, 300)), "it watches the rain's span")
	check(rain.torch_change() == {"powered": true, "run": 0}, "an armed detector is set off by a burning torch")
	rain.restore_state({"powered": true, "flow": 0, "run": 0})
	check(rain.torch_change().is_empty(), "a detector already set off takes nothing more")
	var full := -1
	for tick in 140:
		rain.simulate_tick(tick)
		if full < 0 and rain.is_raining():
			full = tick
	check(full >= 0 and full <= 16, "spin_up_seconds from the level: full rain after %d ticks" % full)
	check(not rain.powered and rain.flow == 0 and rain.run == 0, "after rain_seconds it shuts and the detector is armed again")
	check(rain.torch_change() == {"powered": true, "run": 0}, "armed again, it answers the next torch")
	rain.queue_free()
	await _tree.process_frame


func test_level_03_prelude_leaves_the_picture_of_the_card() -> void:
	var room := await _load()
	await _ticks(150)
	var ramp: WinchRamp = room.get_node("Ramp")
	var torch: Torch = room.get_node("Torch")
	var lift: CounterweightCage = room.get_node("Lift")
	check(ramp.is_up(), "the winch has raised the board: the way is closed")
	check(lift.rise < 0 and is_equal_approx(lift.position.y, ramp.position.y), "the lift waits flush with the floor")
	check((room.get_node("LiftRope") as FireRope).is_whole(), "the lift's rope is whole")
	check(torch.burner and torch.mounted and torch.lit and not torch.held, "the torch burns at its burner")
	check(is_equal_approx(torch.home.y + torch.floor_offset_px, ramp.position.y), "the torch's burner stands on the lower floor")
	check(not (room.get_node("Sprinkler") as Sprinkler).powered, "the detector is armed, it does not rain")
	check((room.get_node("StopRope") as FireRope).is_whole(), "the cage's rope is whole")
	check((room.get_node("Cage") as CounterweightCage).rise < 0, "the cage waits at the bottom")
	await _free(room)


func test_level_03_past_has_the_bridge() -> void:
	var room := await _load()
	var ramp: WinchRamp = room.get_node("Ramp")
	var lift: CounterweightCage = room.get_node("Lift")
	var time: RoomTime = room.get_node("RoomTime")
	Input.action_press("rewind")
	while time.cursor() > 0:
		await _ticks(1)
	await _ticks(2)
	check(ramp.is_flat(), "at frame 0 the board lies as a bridge")
	check(lift.rise < 0, "at frame 0 the lift waits at the floor")
	Input.action_release("rewind")
	await _free(room)


func test_level_03_torch_is_taken_below_and_lit_again_at_either_burner() -> void:
	var room := await _load()
	await _ticks(150)
	var torch: Torch = room.get_node("Torch")
	var player: Player = room.get_node("Player")
	player.respawn(torch.home + Vector2(-70.0, torch.floor_offset_px))
	await _ticks(4)
	await _press_for("move_right", 24)
	check(torch.held and torch.lit, "walking past the burner with empty hands takes the burning torch")
	check(not (room.get_node("LiftRope") as FireRope).is_burning(), "taking it does not light the lift's rope")
	torch.lit = false
	await _press_for("move_left", 30)
	check(torch.held and torch.lit, "walking past the burner with the torch out lights it again")
	check(not torch.mounted, "a burner never takes the torch back")
	torch.lit = false
	await _up_with_torch(room)
	check(torch.held and torch.lit, "the second burner on the mezzanine lights it again too")
	check(not (room.get_node("Sprinkler") as Sprinkler).powered, "lit at that burner, it is out of the detector's watch")
	await _free(room)


func test_level_03_lit_rope_sends_the_lift_up_without_her() -> void:
	var room := await _load()
	await _ticks(150)
	var torch: Torch = room.get_node("Torch")
	var player: Player = room.get_node("Player")
	var rope: FireRope = room.get_node("LiftRope")
	var lift: CounterweightCage = room.get_node("Lift")
	var floor_y := (room.get_node("Ramp") as Node2D).position.y
	player.respawn(torch.home + Vector2(-70.0, torch.floor_offset_px))
	await _ticks(4)
	Input.action_press("move_right")
	var waited := 0
	while not rope.is_burning() and waited < 120:
		await _ticks(1)
		waited += 1
	Input.action_release("move_right")
	check(rope.is_burning(), "carried past the cleat, the burning torch lights the lift's rope")
	var lit_x := player.position.x
	var ticks := 0
	while not lift.is_up() and ticks < 200:
		await _ticks(1)
		ticks += 1
	check(lift.is_up() and ticks <= 90, "the rope burns through and the lift is up %d ticks after" % ticks)
	check(rope.is_broken(), "the rope has burnt through")
	check(absf(player.position.y - floor_y) < 2.0 and player.position.x > lift.position.x + lift.width, "she is still down on the floor by the cleat")
	check(lit_x - lift.position.x > 5.0 * 64.0, "the cleat is far from the lift (%d px)" % int(lit_x - lift.position.x))
	await _free(room)


func test_level_03_replay_burns_the_rope_again_and_lifts_her() -> void:
	var room := await _load()
	await _ticks(150)
	var torch: Torch = room.get_node("Torch")
	var player: Player = room.get_node("Player")
	var rope: FireRope = room.get_node("LiftRope")
	var lift: CounterweightCage = room.get_node("Lift")
	var deck_top := _deck_top(room.get_node("Mezzanine"))
	player.respawn(torch.home + Vector2(-70.0, torch.floor_offset_px))
	await _ticks(4)
	Input.action_press("move_right")
	while not rope.is_burning():
		await _ticks(1)
	Input.action_release("move_right")
	while not lift.is_up():
		await _ticks(1)
	Input.action_press("rewind")
	Input.action_press("move_left")
	var ticks := 0
	while player.position.x > lift.position.x and ticks < 300:
		await _ticks(1)
		ticks += 1
	Input.action_release("move_left")
	await _ticks(20)
	check(lift.rise < 0 and rope.is_whole(), "under Shift the lift came down and the rope grew whole")
	check(absf(player.position.x - lift.position.x) < lift.width / 2.0, "she stands on the lift")
	Input.action_release("rewind")
	ticks = 0
	while not lift.is_up() and ticks < 600:
		await _ticks(1)
		ticks += 1
	await _ticks(10)
	check(rope.is_broken(), "time running forward burns the rope again by itself")
	check(lift.is_up() and absf(player.position.y - deck_top.y) < 4.0, "the replay lifts her with the lift to the mezzanine")
	check(torch.held and torch.lit, "her torch still burns")
	await _free(room)


func test_level_03_detector_puts_out_the_torch_in_normal_time() -> void:
	var room := await _take_torch()
	var torch: Torch = room.get_node("Torch")
	var rain: Sprinkler = room.get_node("Sprinkler")
	await _press_for("move_right", 60)
	check(rain.powered, "a burning torch under the detector sets it off")
	check(torch.held and not torch.lit, "its rain puts the torch out before she is through")
	await _free(room)


func test_level_03_under_shift_the_rain_comes_after_her() -> void:
	var room := await _take_torch()
	var torch: Torch = room.get_node("Torch")
	var rain: Sprinkler = room.get_node("Sprinkler")
	var player: Player = room.get_node("Player")
	var zone := rain.light_rect()
	var seen := false
	var dry := true
	Input.action_press("rewind")
	Input.action_press("move_right")
	while player.position.x < zone.end.x + 30.0:
		await _ticks(1)
		seen = seen or rain.powered
		dry = dry and rain.flow == 0
	Input.action_release("move_right")
	Input.action_release("rewind")
	check(seen, "under Shift the detector sees her torch: its lamp lights")
	check(dry and torch.lit, "but no rain falls while the world runs back")
	await _ticks(40)
	check(rain.is_raining(), "time running forward reaches the frame she was seen in: the rain comes")
	check(torch.lit and not zone.intersects(torch.flame_rect()), "she is past it, the torch burns on")
	await _free(room)


func test_level_03_geometry() -> void:
	var room := await _load()
	var params := Content.player()
	var ramp: WinchRamp = room.get_node("Ramp")
	var deck: Node2D = room.get_node("Mezzanine")
	var deck_top := _deck_top(deck)
	var gravity := float(params["gravity"])
	var walk := float(params["walk_speed"])
	var jump_up := pow(float(params["jump_velocity"]), 2.0) / (2.0 * gravity)
	var floor_y := ramp.position.y
	check(floor_y - deck_top.y > jump_up + 20.0, "the mezzanine is out of a jump's reach from the floor")
	check(14.0 * 64.0 - ramp.position.x > 2.0 * walk * float(params["jump_velocity"]) / gravity, "the pit is wider than a jump")
	ramp.restore_state({"clock": 0, "locked": false})
	check(ramp.is_flat() and ramp.tip().x > 14.0 * 64.0 + 20.0, "lying, the board reaches the far bank")
	var lift: CounterweightCage = room.get_node("Lift")
	var lift_right := lift.position.x + lift.width / 2.0
	check(ramp.tip().x < lift.position.x - lift.width / 2.0, "the board's tip stops short of the lift")
	check(is_equal_approx(lift.floor_y_at(-1), floor_y) and is_equal_approx(lift.floor_y_at(1000000), deck_top.y), "the lift rides from the floor to the mezzanine's top")
	check(is_equal_approx(lift_right, deck_top.x), "at the top the lift meets the mezzanine's edge")
	var torch: Torch = room.get_node("Torch")
	var rope: FireRope = room.get_node("LiftRope")
	var reach := float(Content.objects()["torch"].get("reach_px", 24))
	var cleat := rope.light_rect()
	check(torch.home.x > deck_top.x and torch.home.x < cleat.position.x, "the torch's burner is under the mezzanine, between the lift and the cleat")
	check(absf(rope.points[0].y - (floor_y - 76.0)) < 30.0, "the lift rope's end hangs at the torch's height over the floor")
	check(absf(rope.points[rope.points.size() - 1].x - lift_right) < 16.0, "the rope runs to the lift")
	check(torch.home.x + 22.0 + 8.0 + reach < cleat.position.x, "taking the torch does not light the rope")
	# From the cleat she cannot run back and jump onto the lift before it is
	# out of a jump's reach: she lights the rope at the nearest, walking right,
	# and must turn; only the replay takes her up (D193).
	var lit_at := cleat.position.x - 22.0 - 8.0 - reach
	var run := (lit_at - (lift_right + 22.0)) / walk
	var burn := float(Content.level_for_scene(LEVEL_PATH)["objects"]["lift_rope"]["burn_seconds"])
	var out_of_reach := 0
	while floor_y - lift.floor_y_at(out_of_reach) <= jump_up:
		out_of_reach += 1
	var out := burn + float(out_of_reach) / 60.0
	check(run > out + 0.15, "the lift is out of a jump %.2f s after the rope is lit, she needs %.2f s to come" % [out, run])
	var rain: Sprinkler = room.get_node("Sprinkler")
	var zone := rain.light_rect()
	check(zone.end.y <= deck_top.y + 0.5, "the detector watches only over the mezzanine: the lower floor is out of it")
	var burner: GasBurner = room.get_node("Burner")
	check(is_equal_approx(burner.position.y + burner.floor_offset_px, deck_top.y), "the second burner stands on the mezzanine")
	check(zone.position.x > burner.position.x + 22.0 + 8.0 + reach + 2.0, "lighting the torch at the second burner does not set off the detector")
	check(burner.position.x - deck_top.x > 22.0, "she can stand on the deck at the burner, off the lift")
	var stop: FireRope = room.get_node("StopRope")
	check(not zone.intersects(stop.light_rect().grow(8.0)), "no rain falls on the cage's rope")
	check(stop.light_rect().position.x - (zone.end.x + reach) > 40.0, "between the rain and the rope there is room to let go of Shift")
	check(absf(stop.points[0].y - (deck_top.y - 84.0)) < 30.0, "the rope's end hangs at the torch's height over the mezzanine")
	var blocks: TileMapLayer = room.get_node("Blocks")
	check(blocks.get_cell_source_id(Vector2i(24, 12)) >= 0, "a wall closes the floor under the mezzanine before the shaft")
	var cage: CounterweightCage = room.get_node("Cage")
	check(is_equal_approx(cage.floor_y_at(1000000), 7.0 * 64.0), "the cage rises to the gallery's floor")
	await _free(room)


func test_level_03_windows() -> void:
	var entry := Content.level_for_scene(LEVEL_PATH)
	var objects: Dictionary = entry["objects"]
	var keys: Array = objects["ramp"]["keys"]
	var flat_to := 0.0
	for key: Variant in keys:
		if str((key as Array)[1]) == "flat":
			flat_to = float((key as Array)[0])
	var time := Content.time()
	var tempo := float(time["world_tempo"])
	check(flat_to / tempo >= 3.0, "the bridge lies at least 3 s in the past")
	# The lift's rope is no window: no one catches the lift, the replay does.
	# The window is the past that still has the lift down (D193).
	var gone := float(objects["lift_rope"]["burn_seconds"]) + float(objects["lift"]["rise_seconds"]) / tempo
	check(float(time["history_seconds"]) - gone >= 3.0, "after the lift has gone the past keeps it down long enough to come back")
	check(float(Content.objects()["rope"]["burn_seconds"]) >= 3.0 and not (objects.get("stop_rope", {}) as Dictionary).has("burn_seconds"), "the cage's rope burns at least 3 s: time to jump into the cage")
	var rain: Dictionary = objects["sprinkler"]
	check(float(rain["rain_seconds"]) >= 3.0, "the rain runs long enough to read")
	var walk := float(Content.player()["walk_speed"])
	check(float(rain["spin_up_seconds"]) < (22.0 - 18.5) * 64.0 / walk / 2.0, "the rain comes before she can run through it")


func _deck_top(deck: Node2D) -> Vector2:
	var box := (deck.get_child(0) as CollisionShape2D).shape as RectangleShape2D
	return deck.position - box.size / 2.0


## Puts her with the torch in her hands on the mezzanine at its burner, off
## the lift: first on the lift at the floor, so the torch follows her hands up
## out of the detector's watch.
func _up_with_torch(room: Node) -> void:
	var player: Player = room.get_node("Player")
	var lift: CounterweightCage = room.get_node("Lift")
	var burner: GasBurner = room.get_node("Burner")
	player.respawn(lift.position)
	await _ticks(12)
	player.respawn(Vector2(burner.position.x - 16.0, burner.position.y + burner.floor_offset_px))
	await _ticks(12)


## The level after its prelude, with her on the mezzanine holding the burning
## torch, just left of the detector's watch.
func _take_torch() -> Node:
	var room := await _load()
	await _ticks(150)
	var torch: Torch = room.get_node("Torch")
	var player: Player = room.get_node("Player")
	player.respawn(torch.home + Vector2(-70.0, torch.floor_offset_px))
	await _ticks(4)
	await _press_for("move_right", 12)
	await _up_with_torch(room)
	var rain: Sprinkler = room.get_node("Sprinkler")
	check(torch.held and torch.lit and not rain.powered, "she holds the burning torch left of the detector's watch")
	return room


func _press_for(action: String, ticks: int) -> void:
	Input.action_press(action)
	await _ticks(ticks)
	Input.action_release(action)
