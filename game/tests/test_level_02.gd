extends RefCounted
## Tests of what level 02 «Поток» needs (task 3.1, 17.11.2026): the hero walks
## out of the doorway onto the ledge, two waters with their own drain times that
## are full at the start of the history, the float that carries him up, the button
## on the well floor whose press the replay opens the pool door with (rule «А»)
## and the way through. The solutions themselves (with and without Shift, without
## the button) are in `tests/solutions/` and run by test_solutions.gd.

const LEVEL_PATH := "res://levels/level_02.tscn"
const BUTTONS_ROOM := "res://levels/test_room_buttons.tscn"
const CELL := 64

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


# --- the core, with the real button and door -------------------------------

## The core has to keep the press in the history: a button pressed at the head,
## rewound to the very first frame and released, presses itself and opens the
## door at the same frames as the first time, without the hero.
func test_core_replays_a_press_after_a_rewind_to_the_first_frame() -> void:
	var room := await _load(BUTTONS_ROOM)
	var at: Vector2 = room.get_node("PushButton").global_position + Vector2(0, 12)
	await _press_rewind_replay(room, "PushButton", "Door", at, at)
	await _free(room)


## The same in level 02, with its own button and door and after its prelude.
func test_level_02_replay_opens_the_door_at_the_recorded_frames() -> void:
	var room := await _load(LEVEL_PATH)
	var button: PushButton = room.get_node("PushButton")
	# After the press the hero waits on the wall: left on the well floor he would
	# drown in the rising water and the room would reset with its history.
	await _press_rewind_replay(room, "PushButton", "Door", button.global_position, Vector2(1020, 6 * CELL))
	await _free(room)


func _press_rewind_replay(room: Node, button_name: String, door_name: String, hero_at: Vector2, then_at: Vector2) -> void:
	var time: RoomTime = room.get_node("RoomTime")
	var door: Door = room.get_node(door_name)
	var button: PushButton = room.get_node(button_name)
	var player: Player = room.get_node("Player")
	await _ticks(30)
	check(not button.pressed and door.open == 0, "the button starts up and the door shut")
	player.respawn(hero_at)
	time.player_interact(player.global_position)
	var press_cursor := time.cursor()
	var first := {}
	for i in 120:
		await _ticks(1)
		first[time.cursor()] = [button.pressed, door.open]
	check(button.pressed and door.open > 0, "the press must power the door")
	var head := time.cursor()
	player.respawn(then_at)
	await _rewind_to_start(time)
	check(time.cursor() == 0, "the rewind must reach the first frame, cursor %d" % time.cursor())
	check(not button.pressed and door.open == 0, "at the first frame the button is up and the door shut")
	Input.action_release("rewind")
	var replayed := 0
	var wrong := 0
	for i in head + 10:
		await _ticks(1)
		var cursor := time.cursor()
		if first.has(cursor):
			replayed += 1
			if [button.pressed, door.open] != first[cursor]:
				wrong += 1
	check(replayed > 100, "the replay must pass the recorded frames, saw %d" % replayed)
	check(wrong == 0, "%d replayed frames differ from the first run (press at frame %d)" % [wrong, press_cursor])
	check(button.pressed and door.open > 0, "after the replay the button is down and the door is open")


# --- the hero comes in -----------------------------------------------------

## He walks out of the doorway by himself and stops on the ledge: two cells of
## ground, the well right behind it (task 3.1).
func test_level_02_hero_walks_out_of_the_doorway_onto_the_ledge() -> void:
	var room := await _load(LEVEL_PATH)
	var player: Player = room.get_node("Player")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	var entrance := room.get_node("Entrance") as Node2D
	var frame := Rect2(entrance.position, entrance.get("size"))
	check(frame.has_point(spawn.global_position - Vector2(0, 10)), "the hero appears inside the doorway")
	var entry := Content.level_for_scene(LEVEL_PATH)
	var expected := int(round(float(entry["intro_seconds"]) * float(Content.time()["physics_ticks_per_second"])))
	check(player.intro_ticks_left() > 0 and player.intro_ticks_left() <= expected, "the walk-in is running at the start, %d ticks left" % player.intro_ticks_left())
	check(player.modulate.a < 1.0, "the hero fades in")
	await _ticks(expected + 20)
	check(player.intro_ticks_left() == 0 and is_equal_approx(player.modulate.a, 1.0), "after the walk-in the hero is there and free")
	var ledge_edge := float(4 * CELL)
	check(player.global_position.x > spawn.global_position.x + 40.0, "the hero walked out, x %.0f" % player.global_position.x)
	check(player.global_position.x + 22.0 < ledge_edge, "the walk-in ends on the ledge, not over the well: x %.0f, the edge is at %.0f" % [player.global_position.x, ledge_edge])
	check(absf(player.global_position.y - spawn.global_position.y) < 2.0, "the hero stands on the ledge, y %.0f" % player.global_position.y)
	room.call("restart")
	check(player.global_position.is_equal_approx(spawn.global_position) and player.intro_ticks_left() > 0, "a reset brings him out of the doorway again")
	await _free(room)


# --- the water -------------------------------------------------------------

## After the prelude the ledge is dry and the waters are draining or empty; at
## the start of the history both are full and the full line is over the ledge.
func test_level_02_water_and_float_after_the_prelude() -> void:
	var room := await _load(LEVEL_PATH)
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var float_body: WaterFloat = well.get_node("Float")
	var time: RoomTime = room.get_node("RoomTime")
	var player: Player = room.get_node("Player")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	check(well.surface_global_y() > spawn.global_position.y + 8.0, "the ledge is dry when the hero comes: the surface is at %.0f, the ledge at %.0f" % [well.surface_global_y(), spawn.global_position.y])
	check(well.level > 0 and well.flow == -1, "the well is still draining, level %d" % well.level)
	check(pool.level == 0, "the pool is already empty, level %d" % pool.level)
	check(not player.is_head_under_water(), "the hero does not start in water")
	var rect := well.float_rect_at(float_body, well.level)
	var surface_y := well.surface_global_y()
	check(rect.end.y > surface_y and rect.end.y < surface_y + 16.0, "the float rides the surface: its bottom %.0f, the surface %.0f" % [rect.end.y, surface_y])
	player.respawn(Vector2(1020, 6 * CELL))
	await _rewind_to_start(time)
	check(well.level == Water.LEVEL_MAX and pool.level == Water.LEVEL_MAX, "at the start of the history both waters are full: %d and %d" % [well.level, pool.level])
	check(well.surface_global_y() < spawn.global_position.y - 4.0 * CELL, "the full water stands over the hero's ledge: %.0f against %.0f" % [well.surface_global_y(), spawn.global_position.y])
	var line := float(6 * CELL)
	check(is_equal_approx(well.surface_global_y(), line) and is_equal_approx(pool.surface_global_y(), line), "the full line is one height over both tanks: %.0f and %.0f" % [well.surface_global_y(), pool.surface_global_y()])
	var top := well.float_rect_at(float_body, well.level).position.y
	check(top < line + 4.0 and top > line - 48.0, "the full float carries the hero to the top of the wall: its top at %.0f, the wall at %.0f" % [top, line])
	await _free(room)


## Everything stands on one full line, the way is as the sketch says: the ledge
## five cells under it, the well twelve deep, the pool seven, the wall two wide.
func test_level_02_geometry_follows_the_sketch() -> void:
	var room := await _load(LEVEL_PATH)
	var blocks: TileMapLayer = room.get_node("Blocks")
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	var wall_top := -1
	for row in range(1, 20):
		if blocks.get_cell_source_id(Vector2i(15, row)) != -1:
			wall_top = row
			break
	check(wall_top * CELL == int(well.tank_global_rect().position.y), "the wall top (row %d) is the full water line %.0f" % [wall_top, well.tank_global_rect().position.y])
	check(is_equal_approx(well.tank_global_rect().position.y, pool.tank_global_rect().position.y), "both tanks start at the same line")
	check(is_equal_approx(spawn.global_position.y - well.tank_global_rect().position.y, 5.0 * CELL), "the hero's ledge is 5 cells under the line")
	check(is_equal_approx(well.size.y, 12.0 * CELL), "the well is 12 cells deep, is %.0f px" % well.size.y)
	check(is_equal_approx(pool.size.y, 7.0 * CELL), "the pool is 7 cells deep, is %.0f px" % pool.size.y)
	check(blocks.get_cell_source_id(Vector2i(16, wall_top)) != -1 and blocks.get_cell_source_id(Vector2i(14, wall_top)) == -1 and blocks.get_cell_source_id(Vector2i(17, wall_top)) == -1, "the wall between them is two cells wide")
	var jump_reach := float(Content.player()["walk_speed"]) * 2.0 * float(Content.player()["jump_velocity"]) / float(Content.player()["gravity"])
	var jump_height := pow(float(Content.player()["jump_velocity"]), 2.0) / (2.0 * float(Content.player()["gravity"]))
	var float_body: WaterFloat = well.get_node("Float")
	var float_right := well.position.x + float_body.position.x + float_body.body_size().x / 2.0
	var wall_left := 15.0 * CELL
	check(wall_left - float_right < jump_reach - 48.0, "the wall is a jump from the float's edge: %.0f px apart, a jump carries %.0f" % [wall_left - float_right, jump_reach])
	check(spawn.global_position.y - float(wall_top * CELL) > jump_height + 64.0, "the wall is out of a jump from the ledge (it is %.0f above, a jump is %.0f)" % [spawn.global_position.y - float(wall_top * CELL), jump_height])
	var floor_y := well.global_position.y
	check(floor_y - spawn.global_position.y > jump_height + 64.0, "from the well floor the hero cannot climb back to the ledge without the water")
	var button: PushButton = room.get_node("PushButton")
	var reach := float(Content.objects()["button"]["interact_radius_px"])
	var stand_from := float_right + 22.0
	var stand_to := wall_left - 22.0
	check(maxf(button.global_position.x - stand_from, stand_to - button.global_position.x) < reach, "from anywhere on the floor between the float and the wall the button is in reach (%.0f px)" % reach)
	check(button.global_position.x > float_right and button.global_position.x < wall_left, "the button is right of the float, before the wall")
	var grate_x := well.position.x - well.size.x / 2.0 + well.look.outlet_inset_px
	check(grate_x < well.position.x + float_body.position.x - float_body.body_size().x / 2.0 and grate_x > 4.0 * CELL, "the grate is on the well floor left of the float, x %.0f" % grate_x)
	await _free(room)


## The level and the float do not jump between frames, on the way back through
## the prelude and on the way forward again.
func test_level_02_water_and_float_are_continuous() -> void:
	var room := await _load(LEVEL_PATH)
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var float_body: WaterFloat = well.get_node("Float")
	var time: RoomTime = room.get_node("RoomTime")
	room.get_node("Player").respawn(Vector2(1020, 6 * CELL))
	var last := [well.level, pool.level, well.float_rect_at(float_body, well.level).position.y]
	var worst := [0, 0, 0.0]
	Input.action_press("rewind")
	var guard := 0
	while time.cursor() > 0 and guard < 2000:
		await _ticks(1)
		guard += 1
		_track(well, pool, float_body, last, worst)
	Input.action_release("rewind")
	for i in 200:
		await _ticks(1)
		_track(well, pool, float_body, last, worst)
	check(worst[0] <= well.step() + 1, "the well level jumps %d per tick, its step is %d" % [worst[0], well.step()])
	check(worst[1] <= pool.step() + 1, "the pool level jumps %d per tick, its step is %d" % [worst[1], pool.step()])
	check(worst[2] <= 2.5, "the float jumps %.1f px in one tick" % worst[2])
	await _free(room)


func _track(well: Water, pool: Water, float_body: WaterFloat, last: Array, worst: Array) -> void:
	worst[0] = maxi(worst[0], absi(well.level - int(last[0])))
	worst[1] = maxi(worst[1], absi(pool.level - int(last[1])))
	var float_y := well.float_rect_at(float_body, well.level).position.y
	worst[2] = maxf(worst[2], absf(float_y - float(last[2])))
	last[0] = well.level
	last[1] = pool.level
	last[2] = float_y


## The pool drains in seconds of its own, faster than the hero's breath runs out:
## a hero who drops into the full pool gets wet but not drowned (task 3.1).
func test_level_02_pool_drains_faster_than_the_breath_runs_out() -> void:
	var entry := Content.level_for_scene(LEVEL_PATH)
	var settings: Dictionary = entry["objects"]
	var ticks := float(Content.time()["physics_ticks_per_second"])
	var well_seconds := _drain_seconds(settings["well"])
	var pool_seconds := _drain_seconds(settings["pool"])
	check(pool_seconds < well_seconds, "the pool (%.1f s) drains faster than the well (%.1f s)" % [pool_seconds, well_seconds])
	var breath := float(Content.player()["breath_seconds"])
	var head_clear := 1.0 - (92.0 - float(Content.player()["head_px"])) / (7.0 * CELL)
	check(pool_seconds * head_clear < breath - 0.5, "the water leaves the hero's head (%.1f s) before the breath is out (%.1f s)" % [pool_seconds * head_clear, breath])
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var player: Player = room.get_node("Player")
	var pool: Water = room.get_node("Pool")
	player.respawn(Vector2(1020, 6 * CELL))
	await _rewind_to_start(time)
	Input.action_release("rewind")
	check(pool.level == Water.LEVEL_MAX, "the pool is full at the start")
	var drowned := [false]
	player.drowned.connect(func() -> void: drowned[0] = true)
	player.respawn(Vector2(1300, 5 * CELL))
	var lowest := 1.0
	for i in int(5.0 * ticks):
		await _ticks(1)
		lowest = minf(lowest, player.breath_fraction())
	check(not drowned[0], "the hero who drops into the full pool must not drown")
	check(lowest < 0.8, "the dive costs air, it is a risk the player sees: the breath fell to %.2f only" % lowest)
	check(player.global_position.x > 1088.0 and player.global_position.y > 800.0, "he stands on the pool floor afterwards, at %s" % [player.global_position])
	await _free(room)


## Jumping into the well at once, before the water is gone, is allowed and
## survivable: a fall does not hurt, the water leaves before the air does.
func test_level_02_jumping_into_the_well_at_once_does_not_drown() -> void:
	var room := await _load(LEVEL_PATH)
	var player: Player = room.get_node("Player")
	var drowned := [false]
	player.drowned.connect(func() -> void: drowned[0] = true)
	await _ticks(24)
	Input.action_press("move_right")
	await _ticks(40)
	Input.action_release("move_right")
	var lowest := 1.0
	for i in 360:
		await _ticks(1)
		lowest = minf(lowest, player.breath_fraction())
	check(not drowned[0], "a hero who jumps into the well as soon as he can must not drown (breath fell to %.2f)" % lowest)
	check(player.global_position.y > 1100.0, "he is on the well floor, y %.0f" % player.global_position.y)
	await _free(room)


func test_level_02_waters_have_their_own_drain_times() -> void:
	var room := await _load(LEVEL_PATH)
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var ticks := float(Content.time()["physics_ticks_per_second"])
	var settings: Dictionary = Content.level_for_scene(LEVEL_PATH)["objects"]
	var well_seconds := float(Water.LEVEL_MAX) / float(well.step()) / ticks
	var pool_seconds := float(Water.LEVEL_MAX) / float(pool.step()) / ticks
	check(absf(well_seconds - float(settings["well"]["full_seconds"])) < 0.5, "the well runs empty in %.2f s, the data say %s" % [well_seconds, settings["well"]["full_seconds"]])
	check(absf(pool_seconds - float(settings["pool"]["full_seconds"])) < 0.3, "the pool runs empty in %.2f s, the data say %s" % [pool_seconds, settings["pool"]["full_seconds"]])
	check(well.look.outlet_inset_px == float(settings["well"]["outlet_inset_px"]), "the well takes its grate place from the data")
	check(well.powered and pool.powered, "both tanks start draining")
	await _free(room)


# --- the button and the door ----------------------------------------------

## Without the press the door stays shut while the room runs.
func test_level_02_door_stays_shut_without_the_button() -> void:
	var room := await _load(LEVEL_PATH)
	var door: Door = room.get_node("Door")
	var button: PushButton = room.get_node("PushButton")
	check(door.open == 0 and not door.powered, "the door is shut after the prelude")
	await _ticks(10 * 60)
	check(door.open == 0 and not button.pressed, "10 seconds later the door is still shut, open %d" % door.open)
	check(door.linked_id == "button" and "door" in button.target_ids, "the button is wired to the door")
	await _free(room)


## The sparks play from the world tick, so they run the other way under Shift;
## they are out once the button is pressed.
func test_level_02_button_sparks_are_decoration_that_reverses() -> void:
	var ticks := 60.0
	for i in ButtonSparks.COUNT:
		check(ButtonSparks.spark_at(i, 100, ticks) == ButtonSparks.spark_at(i, 100, ticks), "a spark depends on the tick alone")
	var moved := ButtonSparks.spark_at(0, 100, ticks) != ButtonSparks.spark_at(0, 110, ticks)
	check(moved, "the sparks move with the world tick")
	var period := int(round(ButtonSparks.PERIOD_SECONDS * ticks))
	check(ButtonSparks.spark_at(1, 40, ticks).is_equal_approx(ButtonSparks.spark_at(1, 40 + period, ticks)), "a spark repeats after one period")
	var highest := 0.0
	for tick in period:
		highest = minf(highest, ButtonSparks.spark_at(2, tick, ticks).y)
	check(highest < -20.0 and highest > -ButtonSparks.HEIGHT_PX - 1.0, "a spark jumps up, never above its height: %.1f" % highest)
	var room := await _load(LEVEL_PATH)
	var sparks: ButtonSparks = room.get_node("ButtonSparks")
	var button: PushButton = room.get_node("PushButton")
	check(sparks.is_lit(), "the sparks are lit while the button is up")
	check(sparks.position.distance_to(button.position) < 40.0, "the sparks sit on the button")
	var player: Player = room.get_node("Player")
	var time: RoomTime = room.get_node("RoomTime")
	await _ticks(5)
	player.respawn(button.global_position)
	time.player_interact(player.global_position)
	await _ticks(2)
	check(button.pressed and not sparks.is_lit(), "the sparks go out when the button is pressed")
	await _free(room)


# --- the room and the data -------------------------------------------------

func test_level_02_is_wider_than_one_screen_and_the_camera_follows() -> void:
	var room := await _load(LEVEL_PATH)
	var blocks: TileMapLayer = room.get_node("Blocks")
	var size := blocks.get_used_rect().size * blocks.tile_set.tile_size
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	check(size.x > width + width / 5 and size.x <= 3 * width, "the room is %d px wide, the screen %d: it should be wider, up to 3 screens" % [size.x, width])
	var camera: Camera2D = room.get_node("Player/Camera2D")
	check(camera.limit_right == size.x and camera.limit_left == 0, "the camera limits are %d..%d, the room is %d wide" % [camera.limit_left, camera.limit_right, size.x])
	await _free(room)


func test_water_settings_of_a_level_are_checked_in_levels_data() -> void:
	var good := {"id": "x", "scene": LEVEL_PATH, "prelude_seconds": 1, "title": "x",
		"objects": {"well": {"full_seconds": 9, "outlet_inset_px": 352}}}
	check(Content.validate_levels([good], 20.0).is_empty(), "valid water settings must pass: %s" % [Content.validate_levels([good], 20.0)])
	for bad: Variant in [{"full_seconds": 0}, {"full_seconds": "fast"}, {"outlet_inset_px": -3}, {"outlet_inset_px": "left"}]:
		var entry := good.duplicate(true)
		entry["objects"] = {"well": bad}
		check(not Content.validate_levels([entry], 20.0).is_empty(), "water settings %s must be refused" % [bad])
	var entry := Content.level_for_scene(LEVEL_PATH)
	check(float(entry["prelude_seconds"]) < float(Content.time()["history_seconds"]), "the prelude leaves room in the history for the hero's own time")


func test_water_applies_its_own_full_seconds() -> void:
	var fast: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	var slow: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	fast.apply_settings({"full_seconds": 4})
	slow.apply_settings({"full_seconds": 12, "outlet_inset_px": 200})
	check(fast.step() > slow.step() * 2, "a tank with fewer full_seconds runs faster: steps %d and %d" % [fast.step(), slow.step()])
	check(slow.look.outlet_inset_px == 200.0, "outlet_inset_px reaches the look")
	fast.free()
	slow.free()


# --- helpers ---------------------------------------------------------------

## The seconds a tank takes to run empty with these settings, as the water
## rounds them to whole level steps.
func _drain_seconds(settings: Dictionary) -> float:
	var tank: Water = (load("res://objects/water.tscn") as PackedScene).instantiate()
	tank.apply_settings(settings)
	var seconds := float(Water.LEVEL_MAX) / float(tank.step()) / float(Content.time()["physics_ticks_per_second"])
	tank.free()
	return seconds


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
	await _tree.physics_frame
	return room


func _free(room: Node) -> void:
	Input.action_release("rewind")
	Input.action_release("move_right")
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
