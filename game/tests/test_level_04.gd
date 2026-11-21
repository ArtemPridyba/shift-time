extends RefCounted
## Tests of level 04 «Interference» (task 3.3, card docs/levels/04.md, D57):
## the bridge and the gate are never out and open together in the recorded
## history; a latch thrown in the past holds the bridge in a new branch while
## the gate opens on its own timer.

const PLATFORM_PATH := "res://objects/platform.tscn"
const DOOR_PATH := "res://objects/door.tscn"
const LEVEL_PATH := "res://levels/level_04.tscn"
## The latch stands here; the hero stops by it (x of her feet).
const BY_THE_LATCH_TICKS := 100

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


func test_level_04_starts_with_the_bridge_in_and_the_gate_open() -> void:
	var room := await _load()
	var bridge: MovingPlatform = room.get_node("Bridge")
	var gate: Door = room.get_node("Gate")
	check(not _bridge_out(bridge), "after the prelude the bridge is in its slot, is at %s" % [bridge.position])
	check(gate.open == Door.OPEN_MAX, "after the prelude the gate is open, is %d" % gate.open)
	await _free(room)


func test_level_04_history_never_has_the_bridge_out_and_the_gate_open() -> void:
	var room := await _load()
	var bridge: MovingPlatform = room.get_node("Bridge")
	var gate: Door = room.get_node("Gate")
	var player: Player = room.get_node("Player")
	var both := 0
	var was_out := false
	Input.action_press("rewind")
	for i in 8 * 60:
		await _ticks(1)
		was_out = was_out or _bridge_out(bridge)
		if _bridge_out(bridge) and _gate_passable(gate, player):
			both += 1
	Input.action_release("rewind")
	for i in 8 * 60:
		await _ticks(1)
		if _bridge_out(bridge) and _gate_passable(gate, player):
			both += 1
	check(was_out, "under Shift the bridge comes back out")
	check(both == 0, "bridge out and gate open together on %d ticks of the recorded history" % both)
	check(not _bridge_out(bridge) and gate.open == Door.OPEN_MAX, "released Shift replays: bridge in, gate open")
	await _free(room)


func test_level_04_latch_now_does_nothing() -> void:
	var room := await _load()
	var bridge: MovingPlatform = room.get_node("Bridge")
	var latch: Lever = room.get_node("Latch")
	await _walk_to_latch()
	await _press("interact")
	check(latch.on, "the hero by the latch throws it")
	await _ticks(3 * 60)
	var home := bridge.position_at(bridge.once_last_phase())
	check(bridge.position.distance_to(home) < 1.0, "a latch thrown now never moves the bridge, it is at %s, not %s" % [bridge.position, home])
	await _free(room)


func test_level_04_latch_in_the_past_branches_and_holds_the_bridge() -> void:
	var room := await _load()
	var bridge: MovingPlatform = room.get_node("Bridge")
	var gate: Door = room.get_node("Gate")
	await _walk_to_latch()
	Input.action_press("rewind")
	await _ticks(5 * 60)
	check(_bridge_out(bridge) and gate.open == 0, "at the start of the history the bridge is out and the gate shut")
	await _press("interact")
	Input.action_release("rewind")
	await _ticks(5 * 60)
	check(bridge.powered, "the latch holds the bridge")
	check(_bridge_out(bridge), "in the new branch the bridge stays out, is at %s" % [bridge.position])
	check(gate.open == Door.OPEN_MAX, "in the new branch the gate opens on its own timer, is %d" % gate.open)
	await _free(room)


func test_level_04_has_no_ledge_before_the_gate_and_a_wide_pit() -> void:
	var room := await _load()
	var bridge: MovingPlatform = room.get_node("Bridge")
	var gate: Door = room.get_node("Gate")
	var blocks: TileMapLayer = room.get_node("Blocks")
	var cell := blocks.tile_set.tile_size.x
	var row := int(bridge.position_at(0).y / cell)
	var left := int(bridge.rect_at(bridge.position_at(0)).position.x / cell)
	var right := int(gate.position.x / cell)
	check(left + bridge.rect_at(bridge.position_at(0)).size.x / cell == right + 1, "the bridge runs under the gate to the corridor floor")
	for x in range(left, right + 1):
		for y in range(row, blocks.get_used_rect().end.y):
			check(blocks.get_cell_source_id(Vector2i(x, y)) == -1, "the pit under the bridge is open to the bottom, block at %d,%d" % [x, y])
	var player := Content.player()
	var reach := 2.0 * float(player["jump_velocity"]) / float(player["gravity"]) * float(player["walk_speed"])
	check((right - left) * cell > reach + cell, "the pit (%d px) must be wider than a jump (%.0f px)" % [(right - left) * cell, reach])
	await _free(room)


func _bridge_out(bridge: MovingPlatform) -> bool:
	return bridge.position.distance_to(bridge.position_at(0)) < 1.0


func _gate_passable(gate: Door, player: Player) -> bool:
	return gate.travel * gate.open / Door.OPEN_MAX >= player.body_rect().size.y


func _walk_to_latch() -> void:
	Input.action_press("move_right")
	await _ticks(BY_THE_LATCH_TICKS)
	Input.action_release("move_right")
	await _ticks(20)


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
