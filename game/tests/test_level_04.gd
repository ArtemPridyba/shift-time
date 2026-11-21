extends RefCounted
## Tests of level 04 «Interference» (task 3.3, card docs/levels/04.md, D104):
## a bridge and a barricade burn from the start; the bridge burns out first,
## so the recorded history never has a standing bridge and an open way. A
## lever thrown under Shift opens the sprinkler over the bridge while it still
## burns, and in the new branch the bridge stays. Also the latch platform and
## the door that opens once (D103), which the level no longer uses.

const PLATFORM_PATH := "res://objects/platform.tscn"
const DOOR_PATH := "res://objects/door.tscn"
const LEVEL_PATH := "res://levels/level_04.tscn"

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


func test_level_04_wood_takes_its_burn_time_from_the_level() -> void:
	var room := await _load()
	var per_level: Dictionary = Content.level_for_scene(LEVEL_PATH)["objects"]
	for id in ["bridge", "barricade"]:
		var zone: WoodZone = room.get_node(id.capitalize())
		var expected := int(round(float(per_level[id]["burn_seconds"]) * 60.0))
		check(zone.burn.burn_ticks == expected, "%s burns %d ticks, not %d" % [id, zone.burn.burn_ticks, expected])
	await _free(room)


func test_level_04_starts_with_the_bridge_burning_and_the_lever_out_of_reach() -> void:
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
	var lever: Lever = room.get_node("Lever")
	var spawn_x: float = (room.get_node("SpawnPoint") as Node2D).position.x
	var walk := (lever.position.x - spawn_x) / float(Content.player()["walk_speed"])
	var spin_up := float(Content.objects()["sprinkler"]["spin_up_seconds"])
	check(float(entry["intro_seconds"]) + walk + spin_up > left + 1.0, "the lever is reachable %.1f s before the bridge burns out" % (left - walk - spin_up))
	check(left >= 1.0, "the hero must see the bridge burn for a second at least, sees %.1f s" % left)
	await _free(room)


func test_level_04_history_never_has_the_bridge_whole_and_the_way_open() -> void:
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
	check(bridge.burn.phase == WoodBurn.Phase.BURNT and barricade.burn.phase == WoodBurn.Phase.BURNT, "released Shift replays: both burn out again")
	await _free(room)


func test_level_04_lever_now_does_nothing() -> void:
	var room := await _load()
	var bridge: WoodZone = room.get_node("Bridge")
	var lever: Lever = room.get_node("Lever")
	var sprinkler: Sprinkler = room.get_node("Sprinkler")
	await _ticks(3 * 60)
	check(bridge.burn.phase == WoodBurn.Phase.BURNT, "the bridge has burnt out")
	await _stand_by_lever(room)
	await _press("interact")
	check(lever.on, "the hero by the lever throws it")
	await _ticks(2 * 60)
	check(sprinkler.is_raining(), "the lever opens the sprinkler")
	check(bridge.burn.phase == WoodBurn.Phase.BURNT, "rain on a burnt bridge brings nothing back")
	await _free(room)


func test_level_04_lever_in_the_past_puts_the_bridge_out_in_a_new_branch() -> void:
	var room := await _load()
	var bridge: WoodZone = room.get_node("Bridge")
	var barricade: WoodZone = room.get_node("Barricade")
	await _ticks(4 * 60)
	await _stand_by_lever(room)
	Input.action_press("rewind")
	await _ticks(8 * 60)
	check(int(room.get_node("RoomTime").call("cursor")) == 0, "Shift brings the world to the start of the history")
	check(bridge.burn.phase == WoodBurn.Phase.BURNING, "at the start of the history the bridge burns")
	await _press("interact")
	Input.action_release("rewind")
	await _ticks(2 * 60)
	check(bridge.burn.phase == WoodBurn.Phase.WHOLE and bridge.doused >= 0, "the rain puts the bridge out")
	check(barricade.burn.phase == WoodBurn.Phase.BURNING, "the rain never reaches the barricade")
	await _ticks(3 * 60)
	check(barricade.burn.phase == WoodBurn.Phase.BURNT, "the barricade burns through on its own")
	check(bridge.burn.phase == WoodBurn.Phase.WHOLE, "the bridge stays in the new branch")
	await _free(room)


func test_level_04_geometry() -> void:
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
	await _free(room)


## Puts the hero on the landing by the lever.
func _stand_by_lever(room: Node) -> void:
	var player: Player = room.get_node("Player")
	var lever: Lever = room.get_node("Lever")
	player.respawn(lever.global_position - Vector2(20.0, 0.0))
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
