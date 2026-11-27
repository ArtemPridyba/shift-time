extends RefCounted
## Tests of level 06 «Поток» (card docs/levels/06.md, D187): the one-screen
## puzzle of the water rule. The sluice opens in front of her and tank A runs
## into tank B; what leaves A arrives in B. Under Shift the water runs back and
## A's float lifts her to the wall; in the past B stands empty, and the replay
## (rule «A») lifts her on B's float to the exit floor. The heights and gaps
## the solution stands on, the windows and the level's data.

const LEVEL_PATH := "res://levels/level_06.tscn"
const LEVEL_03_PATH := "res://levels/level_03.tscn"
## The flow is over well before this many ticks after the room loads.
const AFTER_FLOW := 220

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_level_06_is_one_screen_in_the_night_shop() -> void:
	var room := await _load(LEVEL_PATH)
	var size := _room_size(room)
	var other := await _load(LEVEL_03_PATH)
	var one_screen := _room_size(other)
	await _free(other)
	check(size == one_screen, "level 06 is %s px, one screen like level 03 is %s" % [size, one_screen])
	check(room.get_node_or_null("WorldBack") != null and room.get_node_or_null("WorldLight") != null and room.get_node_or_null("WorldGround") != null,
		"the room wears the Night shop kit like levels 01 and 03")
	check(not (room.get_node("Blocks") as TileMapLayer).visible, "the blockout tiles stay the collision and are hidden")
	await _free(room)


func test_level_06_the_sluice_runs_a_into_b_in_front_of_her() -> void:
	var room := await _load(LEVEL_PATH)
	var a: Water = room.get_node("TankA")
	var b: Water = room.get_node("TankB")
	var sluice: Door = room.get_node("Sluice")
	check(a.level > Water.LEVEL_MAX * 0.9 and b.level < Water.LEVEL_MAX * 0.1,
		"when the room appears A is still nearly full and B nearly empty (A %d, B %d)" % [a.level, b.level])
	check(a.powered and b.powered and sluice.powered, "the prelude has opened the sluice and runs both tanks")
	var worst := 0
	for i in AFTER_FLOW:
		await _ticks(1)
		worst = maxi(worst, absi(a.level + b.level - Water.LEVEL_MAX))
	check(worst <= a.step(), "what leaves A arrives in B on every tick (worst gap %d)" % worst)
	check(a.level == 0 and b.level == Water.LEVEL_MAX, "after the flow A is empty and B full (A %d, B %d)" % [a.level, b.level])
	check(sluice.open == Door.OPEN_MAX, "the sluice stays open")
	var float_height := (a.get_node("Float") as WaterFloat).body_size().y
	check(absf(_float_top(a) - (a.global_position.y - float_height)) < 1.0, "A's float lies on A's floor")
	check(absf(_float_top(b) - (_rim_y(b) - 24.0)) < 1.0, "B's float rides at B's brim")
	await _free(room)


func test_level_06_past_has_a_full_and_b_empty() -> void:
	var room := await _load(LEVEL_PATH)
	await _ticks(AFTER_FLOW)
	var a: Water = room.get_node("TankA")
	var b: Water = room.get_node("TankB")
	var sluice: Door = room.get_node("Sluice")
	await _rewind_to_start(room.get_node("RoomTime"))
	check(a.level == Water.LEVEL_MAX and b.level == 0, "at frame 0 A is full and B empty (A %d, B %d)" % [a.level, b.level])
	check(sluice.open == 0, "at frame 0 the sluice is shut")
	Input.action_release("rewind")
	await _free(room)


## Aha 1: the water runs back into A and its float lifts her to the wall.
func test_level_06_shift_lifts_her_on_a_float_to_the_wall() -> void:
	var room := await _load(LEVEL_PATH)
	await _ticks(AFTER_FLOW)
	var a: Water = room.get_node("TankA")
	var player: Player = room.get_node("Player")
	var on_float := Vector2(a.global_position.x + (a.get_node("Float") as Node2D).position.x, _float_top(a))
	player.respawn(on_float)
	await _ticks(10)
	await _rewind_to_start(room.get_node("RoomTime"))
	check(absf(player.position.y - _float_top(a)) < 2.0 and _float_top(a) < _wall_top(room),
		"under Shift she rides A's float up over the wall's top (she is at %.0f, the wall at %.0f)" % [player.position.y, _wall_top(room)])
	Input.action_release("rewind")
	await _ticks(AFTER_FLOW)
	check(player.position.y > _rim_y(a) + a.size.y - 40.0, "let go on the float, the replay drains A and she sinks with it to A's floor")
	await _free(room)


## Aha 2: in the past B is empty; on its float the replay lifts her to the exit.
func test_level_06_the_replay_lifts_her_on_b_float_to_the_exit_floor() -> void:
	var room := await _load(LEVEL_PATH)
	await _ticks(AFTER_FLOW)
	var b: Water = room.get_node("TankB")
	var player: Player = room.get_node("Player")
	await _rewind_to_start(room.get_node("RoomTime"))
	var on_float := Vector2(b.global_position.x + (b.get_node("Float") as Node2D).position.x, _float_top(b))
	player.respawn(on_float)
	await _ticks(10)
	Input.action_release("rewind")
	await _ticks(AFTER_FLOW)
	check(b.level == Water.LEVEL_MAX, "the replay fills B again")
	check(absf(player.position.y - (_rim_y(b) - 24.0)) < 2.0, "she rides B's float up to the brim, is at %.0f" % player.position.y)
	await _free(room)


## Standing on B's floor, not on its float, the replay's water closes over her
## head: she drowns and the room starts again.
func test_level_06_b_drowns_her_off_the_float() -> void:
	var room := await _load(LEVEL_PATH)
	await _ticks(AFTER_FLOW)
	var b: Water = room.get_node("TankB")
	var player: Player = room.get_node("Player")
	var drowned := [0]
	player.drowned.connect(func() -> void:
		drowned[0] += 1)
	await _rewind_to_start(room.get_node("RoomTime"))
	player.respawn(Vector2(b.global_position.x - b.size.x / 4.0, b.global_position.y))
	await _ticks(10)
	Input.action_release("rewind")
	var breath_seconds := float(Content.player()["breath_seconds"])
	await _ticks(AFTER_FLOW + int(breath_seconds * 60.0) + 60)
	check(drowned[0] >= 1, "under B's water off the float she drowns")
	await _free(room)


## The heights and gaps of the card: every step of the solution needs a float,
## and no float or floor is in reach without one.
func test_level_06_geometry() -> void:
	var room := await _load(LEVEL_PATH)
	var params := Content.player()
	var gravity := float(params["gravity"])
	var jump_v := float(params["jump_velocity"])
	var walk := float(params["walk_speed"])
	var jump_up := jump_v * jump_v / (2.0 * gravity)
	var a: Water = room.get_node("TankA")
	var b: Water = room.get_node("TankB")
	var float_a_full := _float_rect(a, Water.LEVEL_MAX)
	var float_a_low := _float_rect(a, 0)
	var float_b_full := _float_rect(b, Water.LEVEL_MAX)
	var float_b_low := _float_rect(b, 0)
	var start_edge := a.global_position.x - a.size.x / 2.0
	var wall_left := a.global_position.x + a.size.x / 2.0
	var wall_right := b.global_position.x - b.size.x / 2.0
	var wall_top := _wall_top(room)
	check(a.size == b.size, "A and B are as wide and as deep: what leaves A fills B to the brim")
	check(is_equal_approx(_rim_y(b), a.global_position.y), "B's brim is A's floor line: the water runs down")
	check(is_equal_approx(_rim_y(a), wall_top), "the start floor, A's brim and the wall stand on one line")
	check(float_a_full.position.x - start_edge > 2.0 * walk * jump_v / gravity + 20.0, "from the start floor A's full float is out of a jump")
	check(float_a_low.position.y - _rim_y(a) > jump_up + 20.0, "from A's float on the floor the brim is out of a jump")
	check(is_equal_approx(float_a_full.end.x, wall_left) and absf(float_a_full.position.y - wall_top) < 30.0, "A's full float meets the wall's top: one step across")
	check(float_b_low.position.y - _rim_y(b) > jump_up + 20.0, "from B's float on the floor the brim is out of a jump")
	var drop := float_b_full.position.y - wall_top
	var air := jump_v / gravity + sqrt(2.0 * (jump_up + drop) / gravity)
	check(float_b_full.position.x - wall_right > walk * air + 40.0, "from the wall B's full float is out of a jump (gap %.0f, reach %.0f)" % [float_b_full.position.x - wall_right, walk * air])
	var exit: ExitZone = room.get_node("Exit")
	var exit_floor := exit.rect().end.y
	check(is_equal_approx(float_b_full.end.x, b.global_position.x + b.size.x / 2.0) and absf(float_b_full.position.y - exit_floor) < 30.0, "B's full float meets the exit floor: one step across")
	check(exit.rect().position.x - wall_right > walk * air + 40.0, "from the wall the exit floor is out of a jump")
	check(b.size.y > (room.get_node("Player") as Player).body_rect().size.y + 60.0, "B is deeper than she is tall: its water closes over her head")
	await _free(room)


func test_level_06_windows_and_data() -> void:
	var entry := Content.level_for_scene(LEVEL_PATH)
	check(str(entry.get("id", "")) == "level_06" and str(entry.get("title", "")) == "06 Flow", "levels.json has level_06 «06 Flow»")
	var ids: Array = []
	for level: Variant in Content.levels():
		ids.append(str((level as Dictionary).get("id", "")))
	check(ids.find("level_06") == ids.find("level_05") + 1, "level 06 comes after level 05 in the list")
	var objects: Dictionary = entry["objects"]
	var tempo := float(Content.time()["world_tempo"])
	var a_seconds := float(objects["tank_a"]["full_seconds"])
	check(is_equal_approx(a_seconds, float(objects["tank_b"]["full_seconds"])), "A and B run at one pace")
	check(a_seconds / tempo >= 2.5, "the flow lasts long enough to read on screen (%.1f s)" % (a_seconds / tempo))
	check(not bool(objects["tank_a"].get("lifts_player", true)) and not bool(objects["tank_b"].get("lifts_player", true)), "only a float carries her, never the rising water")
	var events: Array = entry.get("prelude_events", [])
	var opened := []
	for event: Variant in events:
		opened.append(str((event as Dictionary).get("id", "")))
	check("sluice" in opened and "tank_a" in opened and "tank_b" in opened, "the prelude opens the sluice and runs both tanks")
	var problems := Content.validate_levels(Content.levels(), float(Content.time()["history_seconds"]))
	check(problems.is_empty(), "levels.json is valid with level 06: %s" % [problems])


func _float_top(water: Water) -> float:
	return _float_rect(water, water.level).position.y


func _float_rect(water: Water, level: int) -> Rect2:
	var float_body: WaterFloat = water.get_node("Float")
	return water.float_rect_at(float_body, level)


## The tank's brim (its full surface) in room pixels.
func _rim_y(water: Water) -> float:
	return water.global_position.y - water.size.y


## The top of the wall between the tanks (column 14), from the tiles.
func _wall_top(room: Node) -> float:
	var blocks: TileMapLayer = room.get_node("Blocks")
	for y in 17:
		if blocks.get_cell_source_id(Vector2i(14, y)) >= 0 and y > 2:
			return float(y * 64)
	return 0.0


func _room_size(room: Node) -> Vector2i:
	var blocks: TileMapLayer = room.get_node("Blocks")
	return blocks.get_used_rect().size * blocks.tile_set.tile_size


func _rewind_to_start(time: RoomTime) -> void:
	Input.action_press("rewind")
	var guard := 0
	while time.cursor() > 0 and guard < 2000:
		await _tree.physics_frame
		guard += 1
	await _ticks(5)


func _load(path: String) -> Node:
	Input.action_release("rewind")
	_reset_time()
	var room: Node = (load(path) as PackedScene).instantiate()
	_tree.root.add_child(room)
	# Two ticks, as the solution player settles: the bodies' positions come
	# back from the physics server a tick late.
	await _ticks(2)
	return room


func _free(room: Node) -> void:
	for action in ["rewind", "move_right", "move_left", "interact", "jump"]:
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
