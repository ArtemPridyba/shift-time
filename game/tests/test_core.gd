extends RefCounted
## Tests of data, input map, player movement rules and the test room.
## Every method named `test_*` is run by test_runner.gd. A test may `await`
## physics frames; it reports problems through `check`.

const ROOM_PATH := "res://levels/test_room.tscn"
const DT := 1.0 / 60.0
const ACTIONS: Array[String] = [
	"move_left", "move_right", "jump", "interact", "rewind", "reset_level", "pause",
]

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# --- data -------------------------------------------------------------------

func test_data_files_are_valid() -> void:
	for problem in Content.validate():
		check(false, problem)


func test_data_check_catches_broken_data() -> void:
	check(Content.validate_player({}).size() == Content.PLAYER_KEYS.size(), "empty player.json must report every key")
	var broken_player := Content.player()
	broken_player["gravity"] = -5
	check(not Content.validate_player(broken_player).is_empty(), "negative gravity must be reported")
	check(not Content.validate_player("text").is_empty(), "non-object player.json must be reported")

	var broken_time := Content.time()
	broken_time["default_prelude_seconds"] = float(broken_time["history_seconds"]) + 1.0
	check(not Content.validate_time(broken_time).is_empty(), "prelude longer than history must be reported")
	check(not Content.validate_time({"history_seconds": 20}).is_empty(), "missing time keys must be reported")

	var level := {"id": "a", "scene": ROOM_PATH, "prelude_seconds": 0, "title": "A"}
	check(Content.validate_levels([level], 20.0).is_empty(), "a correct level entry must pass")
	check(not Content.validate_levels([level, level], 20.0).is_empty(), "duplicate level ids must be reported")
	var missing_scene := level.duplicate()
	missing_scene["scene"] = "res://levels/nope.tscn"
	check(not Content.validate_levels([missing_scene], 20.0).is_empty(), "a missing scene must be reported")
	var long_prelude := level.duplicate()
	long_prelude["prelude_seconds"] = 21
	check(not Content.validate_levels([long_prelude], 20.0).is_empty(), "prelude above history length must be reported")


func test_physics_rate_matches_data() -> void:
	var ticks := int(Content.time()["physics_ticks_per_second"])
	check(Engine.physics_ticks_per_second == ticks, "engine runs %d ticks per second, time.json says %d" % [Engine.physics_ticks_per_second, ticks])
	check(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")) == ticks, "project setting differs from time.json")


# --- input ------------------------------------------------------------------

func test_input_map_matches_architecture() -> void:
	var expected := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"interact": [KEY_E],
		"rewind": [KEY_SHIFT],
		"reset_level": [KEY_R],
		"pause": [KEY_ESCAPE],
	}
	for action in ACTIONS:
		check(InputMap.has_action(action), "missing action '%s'" % action)
		if not InputMap.has_action(action):
			continue
		var keys: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append((event as InputEventKey).physical_keycode)
		keys.sort()
		var wanted: Array = (expected[action] as Array).duplicate()
		wanted.sort()
		check(keys == wanted, "keys of '%s' are %s, expected %s" % [action, keys, wanted])


# --- movement rules (no nodes) ----------------------------------------------

func test_jump_height_fits_the_grid() -> void:
	var motion := PlayerMotion.new(Content.player())
	var v := motion.step(Vector2.ZERO, 0.0, true, true, DT)
	var y := 0.0
	var top := 0.0
	var landed := false
	for i in 240:
		y += v.y * DT
		top = minf(top, y)
		if y >= 0.0:
			landed = true
			break
		v = motion.step(v, 0.0, false, false, DT)
	var height := -top
	check(landed, "the jump never came back to the floor")
	check(height > 128.0, "jump is %.0f px: must clear 2 cells (128 px)" % height)
	check(height < 192.0, "jump is %.0f px: must stay below 3 cells (192 px)" % height)


func test_walk_accelerates_and_stops() -> void:
	var params := Content.player()
	var motion := PlayerMotion.new(params)
	var v := Vector2.ZERO
	for i in 30:
		v = motion.step(v, 1.0, false, true, DT)
	check(is_equal_approx(v.x, float(params["walk_speed"])), "speed after 30 ticks is %f" % v.x)
	for i in 30:
		v = motion.step(v, 0.0, false, true, DT)
	check(is_zero_approx(v.x), "player must stop by friction, speed is %f" % v.x)
	for i in 30:
		v = motion.step(v, -1.0, false, true, DT)
	check(is_equal_approx(v.x, -float(params["walk_speed"])), "speed to the left is %f" % v.x)


func test_coyote_time() -> void:
	var jump_velocity := float(Content.player()["jump_velocity"])
	var fresh := PlayerMotion.new(Content.player())
	fresh.step(Vector2.ZERO, 0.0, false, true, DT)
	var v := Vector2.ZERO
	for i in 3:  # 0.05 s in the air, inside the coyote window
		v = fresh.step(v, 0.0, false, false, DT)
	v = fresh.step(v, 0.0, true, false, DT)
	check(is_equal_approx(v.y, -jump_velocity), "a jump just after leaving the floor must work")

	var late := PlayerMotion.new(Content.player())
	late.step(Vector2.ZERO, 0.0, false, true, DT)
	v = Vector2.ZERO
	for i in 10:  # 0.17 s in the air, past the coyote window
		v = late.step(v, 0.0, false, false, DT)
	v = late.step(v, 0.0, true, false, DT)
	check(v.y > 0.0, "a jump long after leaving the floor must not work")


func test_jump_buffer() -> void:
	var jump_velocity := float(Content.player()["jump_velocity"])
	var early := PlayerMotion.new(Content.player())
	var v := early.step(Vector2(0, 300), 0.0, true, false, DT)  # pressed in the air
	for i in 3:  # still falling 0.05 s later
		v = early.step(v, 0.0, false, false, DT)
	v = early.step(v, 0.0, false, true, DT)  # lands
	check(is_equal_approx(v.y, -jump_velocity), "a jump pressed just before landing must fire on landing")

	var too_early := PlayerMotion.new(Content.player())
	v = too_early.step(Vector2(0, 300), 0.0, true, false, DT)
	for i in 12:  # 0.2 s later, the press is forgotten
		v = too_early.step(v, 0.0, false, false, DT)
	v = too_early.step(v, 0.0, false, true, DT)
	check(v.y >= 0.0, "a jump pressed long before landing must not fire")


# --- test room --------------------------------------------------------------

func test_room_is_on_the_grid() -> void:
	var room := await _load_room()
	var blocks: TileMapLayer = room.get_node("Blocks")
	var cell := blocks.tile_set.tile_size
	check(cell == Vector2i(64, 64), "tile size is %s, expected 64x64" % cell)
	var rect := blocks.get_used_rect()
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	check(rect.size.x * cell.x > width, "the room (%d px) must be wider than the screen (%d px)" % [rect.size.x * cell.x, width])
	check(rect.size.y * cell.y >= height, "the room must be at least as tall as the screen")
	for used in blocks.get_used_cells():
		check(blocks.get_cell_source_id(used) == 0, "cell %s uses an unknown tile source" % used)

	var spawn: Marker2D = room.get_node("SpawnPoint")
	var spawn_cell := Vector2i(int(spawn.position.x) / cell.x, int(spawn.position.y) / cell.y)
	check(int(spawn.position.x) % cell.x == cell.x / 2, "the spawn point must be in the middle of a cell")
	check(int(spawn.position.y) % cell.y == 0, "the spawn point must be on a cell edge (the player's feet)")
	check(blocks.get_cell_source_id(spawn_cell) != -1, "the spawn must stand on a block")
	check(blocks.get_cell_source_id(spawn_cell + Vector2i.UP) == -1, "the cell above the spawn must be free")
	await _free_room(room)


func test_player_walks_and_jumps_in_room() -> void:
	var room := await _load_room()
	var player: Player = room.get_node("Player")
	await _ticks(30)
	check(player.is_on_floor(), "the player must stand on the floor after the start")
	var start := player.global_position

	Input.action_press("move_right")
	await _ticks(30)
	Input.action_release("move_right")
	check(player.global_position.x > start.x + 100.0, "the player must walk right, moved %.0f px" % (player.global_position.x - start.x))
	await _ticks(30)

	var ground_y := player.global_position.y
	var top_y := ground_y
	Input.action_press("jump")
	await _ticks(3)
	Input.action_release("jump")
	for i in 80:
		await _ticks(1)
		top_y = minf(top_y, player.global_position.y)
	check(ground_y - top_y > 100.0, "the jump must lift the player, lifted %.0f px" % (ground_y - top_y))
	check(player.is_on_floor(), "the player must land after the jump")
	check(absf(player.global_position.y - ground_y) < 1.0, "the player must land on the same height")
	await _free_room(room)


func test_rewind_key_does_not_move_player() -> void:
	var normal := await _scripted_run(false)
	var held := await _scripted_run(true)
	check(normal.distance_to(held) < 0.01, "holding rewind changed the player's path: %s vs %s" % [normal, held])
	check(normal.x > 0.0, "the scripted run must have moved the player")


# --- helpers ----------------------------------------------------------------

func _scripted_run(hold_rewind: bool) -> Vector2:
	var room := await _load_room()
	var player: Player = room.get_node("Player")
	await _ticks(20)
	if hold_rewind:
		Input.action_press("rewind")
	Input.action_press("move_right")
	await _ticks(30)
	Input.action_press("jump")
	await _ticks(3)
	Input.action_release("jump")
	await _ticks(40)
	Input.action_release("move_right")
	await _ticks(10)
	var result := player.global_position
	_release_all()
	await _free_room(room)
	return result


func _load_room() -> Node:
	_release_all()
	var room: Node = (load(ROOM_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free_room(room: Node) -> void:
	_release_all()
	room.queue_free()
	await _tree.process_frame


func _release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _ticks(count: int) -> void:
	for i in count:
		await _tree.physics_frame
