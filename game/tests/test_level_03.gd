extends RefCounted
## Tests of level 03 «Interference» (task 3.3, card docs/levels/03.md, D104,
## D105): a bridge and a barricade burn from the start; the bridge burns out,
## and the hall's fire system puts the barricade out, so the recorded history
## never has a standing bridge and an open way. A lever thrown under Shift
## opens the sprinkler over the bridge while it still burns; a valve shut under
## Shift keeps the fire system from opening, and the barricade burns through.
## Both in the past make the way. Also the latch platform and the door that
## opens once (D103), which the level no longer uses.

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


func test_level_03_fire_system_takes_its_start_from_the_level() -> void:
	var room := await _load()
	var per_level: Dictionary = Content.level_for_scene(LEVEL_PATH)["objects"]
	var system: Sprinkler = room.get_node("FireSystem")
	var expected := int(round(float(per_level["fire_system"]["start_seconds"]) * 60.0))
	check(system.start_tick() == expected, "the fire system starts on frame %d, not %d" % [system.start_tick(), expected])
	check(system.powered and (room.get_node("Valve") as Lever).on, "the valve is open from the start")
	await _free(room)


func test_level_03_wood_takes_its_burn_time_from_the_level() -> void:
	var room := await _load()
	var per_level: Dictionary = Content.level_for_scene(LEVEL_PATH)["objects"]
	for id in ["bridge", "barricade"]:
		var zone: WoodZone = room.get_node(id.capitalize())
		var expected := int(round(float(per_level[id]["burn_seconds"]) * 60.0))
		check(zone.burn.burn_ticks == expected, "%s burns %d ticks, not %d" % [id, zone.burn.burn_ticks, expected])
	await _free(room)


func test_level_03_starts_with_the_bridge_burning_and_the_lever_out_of_reach() -> void:
	var room := await _load()
	var bridge: WoodZone = room.get_node("Bridge")
	var barricade: WoodZone = room.get_node("Barricade")
	check(bridge.burn.phase == WoodBurn.Phase.BURNING, "after the prelude the bridge still burns, the hero sees it fall")
	check(barricade.burn.phase == WoodBurn.Phase.BURNING, "after the prelude the barricade burns")
	check(bridge.burn.burn_ticks - bridge.burn.burn < barricade.burn.burn_ticks - barricade.burn.burn, "the bridge burns out before the barricade")
	# The lever thrown now must come too late: even a straight walk from the
	# spawn point to the lever takes longer than the bridge has left to burn,
	# with the intro and the rain's spin-up.
	var entry := Content.level_for_scene(LEVEL_PATH)
	var left := float(bridge.burn.burn_ticks - bridge.burn.burn) / 60.0
	# The way goes up the steps to the landing at the pit and back left over
	# the ledges to the lever.
	var lever: Lever = room.get_node("Lever")
	var spawn_x: float = (room.get_node("SpawnPoint") as Node2D).position.x
	var landing_x := bridge.global_rect().position.x
	var walk := (landing_x - spawn_x + landing_x - lever.position.x) / float(Content.player()["walk_speed"])
	var spin_up := float(Content.objects()["sprinkler"]["spin_up_seconds"])
	check(float(entry["intro_seconds"]) + walk + spin_up > left + 1.0, "the lever is reachable %.1f s before the bridge burns out" % (left - walk - spin_up))
	check(left >= 1.0, "the hero must see the bridge burn for a second at least, sees %.1f s" % left)
	await _free(room)


func test_level_03_history_never_has_the_bridge_whole_and_the_way_open() -> void:
	var room := await _load()
	var bridge: WoodZone = room.get_node("Bridge")
	var barricade: WoodZone = room.get_node("Barricade")
	var both := 0
	var bridge_back := false
	await _ticks(5 * 60)
	Input.action_press("rewind")
	for i in 8 * 60:
		await _ticks(1)
		bridge_back = bridge_back or bridge.burn.is_solid()
		if bridge.burn.is_solid() and not barricade.burn.is_solid():
			both += 1
	Input.action_release("rewind")
	for i in 6 * 60:
		await _ticks(1)
		if bridge.burn.is_solid() and not barricade.burn.is_solid():
			both += 1
	check(bridge_back, "under Shift the bridge comes back from the ash")
	check(both == 0, "a standing bridge and a burnt barricade together on %d ticks of the recorded history" % both)
	check(bridge.burn.phase == WoodBurn.Phase.BURNT, "released Shift replays: the bridge burns out again")
	check(barricade.burn.phase == WoodBurn.Phase.WHOLE and barricade.doused >= 0, "released Shift replays: the fire system puts the barricade out again")
	await _free(room)


func test_level_03_lever_now_does_nothing() -> void:
	var room := await _load()
	var bridge: WoodZone = room.get_node("Bridge")
	var lever: Lever = room.get_node("Lever")
	var sprinkler: Sprinkler = room.get_node("Sprinkler")
	await _ticks(3 * 60)
	check(bridge.burn.phase == WoodBurn.Phase.BURNT, "the bridge has burnt out")
	await _stand_by(room, "Lever")
	await _press("interact")
	check(lever.on, "the hero by the lever throws it")
	await _ticks(2 * 60)
	check(sprinkler.is_raining(), "the lever opens the sprinkler")
	check(bridge.burn.phase == WoodBurn.Phase.BURNT, "rain on a burnt bridge brings nothing back")
	await _free(room)


func test_level_03_lever_in_the_past_puts_the_bridge_out_in_a_new_branch() -> void:
	var room := await _load()
	var bridge: WoodZone = room.get_node("Bridge")
	var barricade: WoodZone = room.get_node("Barricade")
	await _ticks(4 * 60)
	await _stand_by(room, "Lever")
	Input.action_press("rewind")
	await _ticks(8 * 60)
	check(int(room.get_node("RoomTime").call("cursor")) == 0, "Shift brings the world to the start of the history")
	check(bridge.burn.phase == WoodBurn.Phase.BURNING, "at the start of the history the bridge burns")
	await _press("interact")
	Input.action_release("rewind")
	await _ticks(2 * 60)
	check(bridge.burn.phase == WoodBurn.Phase.WHOLE and bridge.doused >= 0, "the rain puts the bridge out")
	await _ticks(3 * 60)
	check(bridge.burn.phase == WoodBurn.Phase.WHOLE, "the bridge stays in the new branch")
	check(barricade.burn.phase == WoodBurn.Phase.WHOLE and barricade.doused >= 0, "the fire system still puts the barricade out")
	await _free(room)


func test_level_03_valve_now_does_nothing() -> void:
	var room := await _load()
	var barricade: WoodZone = room.get_node("Barricade")
	var system: Sprinkler = room.get_node("FireSystem")
	await _ticks(3 * 60)
	check(barricade.burn.phase == WoodBurn.Phase.WHOLE, "the fire system has put the barricade out")
	await _stand_by(room, "Valve")
	await _press("interact")
	await _ticks(2 * 60)
	check(not system.powered and system.flow == 0, "the valve shuts the fire system")
	check(barricade.burn.phase == WoodBurn.Phase.WHOLE, "a barricade put out stays whole")
	await _free(room)


func test_level_03_lever_and_valve_in_the_past_open_the_way() -> void:
	var room := await _load()
	var bridge: WoodZone = room.get_node("Bridge")
	var barricade: WoodZone = room.get_node("Barricade")
	await _ticks(4 * 60)
	await _stand_by(room, "Lever")
	Input.action_press("rewind")
	await _ticks(8 * 60)
	await _press("interact")
	# The world stands at the start while Shift is held; the second change
	# writes into the same frame and keeps the first.
	await _stand_by(room, "Valve")
	await _press("interact")
	check((room.get_node("Lever") as Lever).on, "shutting the valve on the same frame keeps the lever thrown")
	Input.action_release("rewind")
	await _ticks(5 * 60)
	check(bridge.burn.phase == WoodBurn.Phase.WHOLE, "the bridge is put out")
	check(barricade.burn.phase == WoodBurn.Phase.BURNT, "the barricade burns through without the fire system")
	await _free(room)


func test_level_03_geometry() -> void:
	var room := await _load()
	var bridge: WoodZone = room.get_node("Bridge")
	var barricade: WoodZone = room.get_node("Barricade")
	var sprinkler: Sprinkler = room.get_node("Sprinkler")
	var blocks: TileMapLayer = room.get_node("Blocks")
	var cell := blocks.tile_set.tile_size.x
	var rect := bridge.global_rect()
	var left := int(rect.position.x / cell)
	var right := int(rect.end.x / cell)
	check(right - 1 == int(barricade.position.x / cell), "the bridge runs under the barricade to the corridor floor")
	for x in range(left, right):
		for y in range(int(rect.position.y / cell), blocks.get_used_rect().end.y):
			check(blocks.get_cell_source_id(Vector2i(x, y)) == -1, "the pit under the bridge is open to the bottom, block at %d,%d" % [x, y])
	var player := Content.player()
	var reach := 2.0 * float(player["jump_velocity"]) / float(player["gravity"]) * float(player["walk_speed"])
	check((right - left - 1) * cell > reach + cell, "the pit (%d px) must be wider than a jump (%.0f px)" % [(right - left - 1) * cell, reach])
	sprinkler.flow = Sprinkler.FLOW_MAX
	var rain := sprinkler.water_global_rect()
	check(rain.intersects(rect), "the rain reaches the bridge")
	check(not rain.intersects(barricade.global_rect()), "the rain never reaches the barricade")
	var system: Sprinkler = room.get_node("FireSystem")
	system.flow = Sprinkler.FLOW_MAX
	var spray := system.water_global_rect()
	check(spray.intersects(barricade.global_rect()), "the fire system reaches the barricade")
	check(not spray.intersects(rect), "the fire system never reaches the bridge")
	await _free(room)


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


## The playtest of 22.11 (D108): the two water lines read as one tangle where
## the valve's riser crossed the lever's feed pipe. The feed pipe, the main and
## the lever's rod never cross, and each line shows the water of its own
## sprinkler.
func test_level_03_water_lines_never_cross() -> void:
	var room := await _load()
	var feed: WaterPipe = room.get_node("FeedPipe")
	var main: WaterPipe = room.get_node("FireMain")
	check(feed.get_node(feed.source_path) == room.get_node("Sprinkler"), "the feed pipe shows the sprinkler over the bridge")
	check(main.get_node(main.source_path) == room.get_node("FireSystem"), "the main shows the fire system over the barricade")
	check(feed.kind != main.kind, "the two lines differ in shape")
	var rod: ColorRect = room.get_node("LeverRod")
	var rod_rect := Rect2(rod.position, rod.size)
	var feed_rects := _pipe_rects(feed)
	var main_rects := _pipe_rects(main)
	for f in feed_rects:
		for m in main_rects:
			check(not f.intersects(m), "the feed pipe %s crosses the main %s" % [f, m])
	for m in main_rects:
		check(not m.intersects(rod_rect), "the main %s crosses the lever's rod" % [m])
	var valve: Lever = room.get_node("Valve")
	var lever: Lever = room.get_node("Lever")
	check(main.points[0].distance_to(valve.position) < 64.0, "the main starts at the valve")
	check(absf(rod_rect.get_center().x - lever.position.x) < 8.0, "the rod comes down to the lever")
	await _free(room)


## The pipe's straight runs as rectangles with its width, local pixels.
func _pipe_rects(pipe: WaterPipe) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var half := pipe.width() / 2.0
	for i in pipe.points.size() - 1:
		var a := pipe.points[i]
		var b := pipe.points[i + 1]
		rects.append(Rect2(a.min(b) - Vector2(half, half), (b - a).abs() + Vector2(half, half) * 2.0))
	return rects


## Puts the hero on the ledge by the lever or the valve (node name).
func _stand_by(room: Node, node_name: String) -> void:
	var player: Player = room.get_node("Player")
	var target: Node2D = room.get_node(node_name)
	player.respawn(target.global_position - Vector2(20.0, 0.0))
	await _ticks(10)


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
	for action in ["rewind", "move_right", "interact"]:
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
