extends RefCounted
## Tests of what level 02 «Поток» needs (task 3.1, 17.11.2026; reworked after
## the playtests 21.11.2026, D97, D98 and D99): the hero walks out of the doorway
## onto the ledge, the well runs into the pool (full and empty at the start of
## the history, each at its own pace), the well float carries him up to the wall
## under Shift, the pool float carries him up to the landing on the replay (rule
## «А») and the gate the full pool holds shut opens only when Shift sends the
## pool back down. Behind the gate the flooded sump (D99) lets the hero out
## only when he lets go of Shift under water, and the events of the history
## come one after another. The solutions themselves (with and without Shift,
## waiting on the wall, waiting at the gate, holding Shift in the sump) are in
## `tests/solutions/` and run by test_solutions.gd.

const LEVEL_PATH := "res://levels/level_02.tscn"
const BUTTONS_ROOM := "res://levels/test_room_buttons.tscn"
const CELL := 64
const WELL_FLOOR_ROW := 15
const POOL_FLOOR_ROW := 10
## The landing beyond the pool starts here; the gate stands in the mouth of the
## way out at GATE_COLUMN, rows 4-5.
const LANDING_COLUMN := 28
const GATE_COLUMN := 32
## The sump behind the gate: columns 33-39, floor on row 9; the sluice at the
## bottom of its far wall, column 40, rows 7-8.
const SUMP_COLUMNS := Vector2i(33, 40)
const SUMP_FLOOR_ROW := 9
const SLUICE_COLUMN := 40

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
	check(is_equal_approx(frame.size.y, 2.0 * CELL) and is_equal_approx(frame.end.y, spawn.global_position.y), "the doorway is two cells (128 px) high and stands on the ledge (D82): %s" % [frame])
	var entry := Content.level_for_scene(LEVEL_PATH)
	var expected := int(round(float(entry["intro_seconds"]) * float(Content.time()["physics_ticks_per_second"])))
	check(player.intro_ticks_left() > 0 and player.intro_ticks_left() <= expected, "the walk-in is running at the start, %d ticks left" % player.intro_ticks_left())
	check(player.modulate.a < 1.0, "the hero fades in")
	await _ticks(expected + 20)
	check(player.intro_ticks_left() == 0 and is_equal_approx(player.modulate.a, 1.0), "after the walk-in the hero is there and free")
	var ledge_edge := float(5 * CELL)
	check(player.global_position.x > spawn.global_position.x + 40.0, "the hero walked out, x %.0f" % player.global_position.x)
	check(player.global_position.x + 22.0 < ledge_edge, "the walk-in ends on the ledge, not over the well: x %.0f, the edge is at %.0f" % [player.global_position.x, ledge_edge])
	check(absf(player.global_position.y - spawn.global_position.y) < 2.0, "the hero stands on the ledge, y %.0f" % player.global_position.y)
	room.call("restart")
	check(player.global_position.is_equal_approx(spawn.global_position) and player.intro_ticks_left() > 0, "a reset brings him out of the doorway again")
	await _free(room)


# --- the water -------------------------------------------------------------

## After the prelude the ledge is dry, the well is draining and the pool filling;
## at the start of the history the well is full over the ledge and the pool
## empty, its float on the floor.
func test_level_02_water_and_float_after_the_prelude() -> void:
	var room := await _load(LEVEL_PATH)
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var float_body: WaterFloat = well.get_node("Float")
	var pool_float: WaterFloat = pool.get_node("Float")
	var time: RoomTime = room.get_node("RoomTime")
	var player: Player = room.get_node("Player")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	check(well.surface_global_y() > spawn.global_position.y + 8.0, "the ledge is dry when the hero comes: the surface is at %.0f, the ledge at %.0f" % [well.surface_global_y(), spawn.global_position.y])
	check(well.level > 0 and well.flow == -1, "the well is still draining, level %d" % well.level)
	var gate: WaterGate = room.get_node("Gate")
	check(pool.level > Water.LEVEL_MAX / 2 and pool.flow == 1 and gate.open == 0, "the hero comes to a pool still filling and a shut gate: level %d, gate %d" % [pool.level, gate.open])
	var sump: Water = room.get_node("Sump")
	var sluice: WaterGate = room.get_node("Sluice")
	check(sump.level < Water.LEVEL_MAX / 4 and sluice.powered, "behind the gate the sump has run low and the sluice is opening: level %d" % sump.level)
	check(not player.is_head_under_water(), "the hero does not start in water")
	var rect := well.float_rect_at(float_body, well.level)
	var surface_y := well.surface_global_y()
	check(rect.end.y > surface_y and rect.end.y < surface_y + 16.0, "the float rides the surface: its bottom %.0f, the surface %.0f" % [rect.end.y, surface_y])
	player.respawn(Vector2(1088, 6 * CELL))
	await _rewind_to_start(time)
	check(well.level == Water.LEVEL_MAX and pool.level == 0, "at the start of the history the well is full and the pool empty: %d and %d" % [well.level, pool.level])
	check(well.surface_global_y() < spawn.global_position.y - 4.0 * CELL, "the full water stands over the hero's ledge: %.0f against %.0f" % [well.surface_global_y(), spawn.global_position.y])
	var line := float(6 * CELL)
	check(is_equal_approx(well.surface_global_y(), line), "the full well stands on the line: %.0f" % well.surface_global_y())
	var top := well.float_rect_at(float_body, well.level).position.y
	check(top < line + 4.0 and top > line - 48.0, "the full float carries the hero to the top of the wall: its top at %.0f, the wall at %.0f" % [top, line])
	check(is_equal_approx(pool.float_rect_at(pool_float, pool.level).end.y, pool.global_position.y), "the pool float lies on the pool floor")
	check(gate.open == Door.OPEN_MAX, "at the start of the history the empty pool leaves the gate open, open %d" % gate.open)
	check(sump.level == Water.LEVEL_MAX and sluice.open == 0, "at the start of the history the sump is full and holds the sluice shut: %d, %d" % [sump.level, sluice.open])
	check(is_equal_approx(sump.surface_global_y(), line), "the full sump stands on the same line: %.0f" % sump.surface_global_y())
	pool.level = Water.LEVEL_MAX
	check(is_equal_approx(pool.surface_global_y(), line), "the full pool stands on the same line: %.0f" % pool.surface_global_y())
	await _free(room)


## Everything stands on one full line, the way is as the sketch says: the ledge
## five cells under it, the well nine deep, the pool four, the wall two wide.
func test_level_02_geometry_follows_the_sketch() -> void:
	var room := await _load(LEVEL_PATH)
	var blocks: TileMapLayer = room.get_node("Blocks")
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var spawn: Marker2D = room.get_node("SpawnPoint")
	var wall_top := -1
	for row in range(1, 20):
		if blocks.get_cell_source_id(Vector2i(16, row)) != -1:
			wall_top = row
			break
	check(wall_top * CELL == int(well.tank_global_rect().position.y), "the wall top (row %d) is the full water line %.0f" % [wall_top, well.tank_global_rect().position.y])
	check(is_equal_approx(well.tank_global_rect().position.y, pool.tank_global_rect().position.y), "both tanks start at the same line")
	check(is_equal_approx(spawn.global_position.y - well.tank_global_rect().position.y, 5.0 * CELL), "the hero's ledge is 5 cells under the line")
	check(is_equal_approx(well.size.y, 9.0 * CELL), "the well is 9 cells deep, is %.0f px" % well.size.y)
	check(is_equal_approx(pool.size.y, 4.0 * CELL), "the pool is 4 cells deep, is %.0f px" % pool.size.y)
	check(blocks.get_cell_source_id(Vector2i(17, wall_top)) != -1 and blocks.get_cell_source_id(Vector2i(15, wall_top)) == -1 and blocks.get_cell_source_id(Vector2i(18, wall_top)) == -1, "the wall between them is two cells wide")
	var jump_reach := float(Content.player()["walk_speed"]) * 2.0 * float(Content.player()["jump_velocity"]) / float(Content.player()["gravity"])
	var jump_height := pow(float(Content.player()["jump_velocity"]), 2.0) / (2.0 * float(Content.player()["gravity"]))
	var float_body: WaterFloat = well.get_node("Float")
	var float_right := well.position.x + float_body.position.x + float_body.body_size().x / 2.0
	var wall_left := 16.0 * CELL
	check(wall_left - float_right < jump_reach - 48.0, "the wall is a jump from the float's edge: %.0f px apart, a jump carries %.0f" % [wall_left - float_right, jump_reach])
	check(spawn.global_position.y - float(wall_top * CELL) > jump_height + 64.0, "the wall is out of a jump from the ledge (it is %.0f above, a jump is %.0f)" % [spawn.global_position.y - float(wall_top * CELL), jump_height])
	var floor_y := well.global_position.y
	check(floor_y - spawn.global_position.y > jump_height + 64.0, "from the well floor the hero cannot climb back to the ledge without the water")
	for column in range(18, LANDING_COLUMN):
		check(blocks.get_cell_source_id(Vector2i(column, POOL_FLOOR_ROW)) != -1, "the pool floor is whole at column %d" % column)
	for column in range(5, 16):
		check(blocks.get_cell_source_id(Vector2i(column, WELL_FLOOR_ROW)) != -1 and blocks.get_cell_source_id(Vector2i(16, WELL_FLOOR_ROW - 1)) != -1, "the well is closed at the floor and on the right, column %d" % column)
	check(blocks.get_cell_source_id(Vector2i(4, 11)) != -1 and blocks.get_cell_source_id(Vector2i(5, 11)) == -1, "the ledge is the doorway and three cells of ground (columns 1-4)")
	check(blocks.get_cell_source_id(Vector2i(4, 16)) != -1, "the foot of the ledge is solid")
	var grate_x := well.position.x - well.size.x / 2.0 + well.look.outlet_inset_px
	check(grate_x < well.position.x + float_body.position.x - float_body.body_size().x / 2.0 and grate_x > 5.0 * CELL, "the grate is on the well floor left of the float, x %.0f" % grate_x)
	# Beyond the pool a dry landing on the full line, then the gate in the mouth
	# of a passage two cells high (D82), and right behind it the sump (D99).
	for column in range(LANDING_COLUMN, GATE_COLUMN + 1):
		check(blocks.get_cell_source_id(Vector2i(column, 6)) != -1 and blocks.get_cell_source_id(Vector2i(column, 5)) == -1, "the landing is dry ground on the line at column %d" % column)
		check(blocks.get_cell_source_id(Vector2i(column, 3)) != -1 or column < GATE_COLUMN, "rock above the gate's column %d" % column)
	var gate: WaterGate = room.get_node("Gate")
	var shut := gate.rect_at(0)
	check(gate.watch_id == "pool", "the gate watches the pool, not %s" % gate.watch_id)
	check(is_equal_approx(shut.end.x, float((GATE_COLUMN + 1) * CELL)), "the gate stands at the right edge of its column, no ground behind it: it ends at %.0f" % shut.end.x)
	check(is_equal_approx(shut.size.y, 2.0 * CELL) and is_equal_approx(shut.position.y, 4.0 * CELL), "the shut gate fills the passage: %s" % [shut])
	var sump: Water = room.get_node("Sump")
	var sump_rect := sump.tank_global_rect()
	check(is_equal_approx(sump_rect.position.x, float(SUMP_COLUMNS.x * CELL)) and is_equal_approx(sump_rect.end.x, float(SUMP_COLUMNS.y * CELL)), "the sump fills columns %d-%d: %s" % [SUMP_COLUMNS.x, SUMP_COLUMNS.y - 1, sump_rect])
	check(is_equal_approx(sump_rect.position.y, float(wall_top * CELL)) and is_equal_approx(sump_rect.end.y, float(SUMP_FLOOR_ROW * CELL)), "the sump runs from the line to its floor: %s" % [sump_rect])
	check(sump_rect.size.y > jump_height + 32.0, "from the sump floor the hero cannot climb back: %.0f px up, a jump is %.0f" % [sump_rect.size.y, jump_height])
	for column in range(SUMP_COLUMNS.x, SUMP_COLUMNS.y):
		check(blocks.get_cell_source_id(Vector2i(column, SUMP_FLOOR_ROW)) != -1 and blocks.get_cell_source_id(Vector2i(column, SUMP_FLOOR_ROW - 1)) == -1, "the sump floor is whole at column %d" % column)
	for row in range(1, 7):
		check(blocks.get_cell_source_id(Vector2i(SLUICE_COLUMN, row)) != -1, "the sump's far wall is solid above the sluice, row %d" % row)
	var sluice: WaterGate = room.get_node("Sluice")
	var sluice_shut := sluice.rect_at(0)
	check(sluice.watch_id == "sump", "the sluice watches the sump, not %s" % sluice.watch_id)
	check(sluice_shut.position.x >= float(SLUICE_COLUMN * CELL) - 1.0 and sluice_shut.end.x <= float((SLUICE_COLUMN + 1) * CELL) + 1.0, "the sluice stands in the far wall, x %.0f" % sluice_shut.position.x)
	check(is_equal_approx(sluice_shut.position.y, 7.0 * CELL) and is_equal_approx(sluice_shut.end.y, float(SUMP_FLOOR_ROW * CELL)), "the shut sluice fills the opening at the bottom of the sump: %s" % [sluice_shut])
	for column in [SLUICE_COLUMN + 2, SLUICE_COLUMN + 3, SLUICE_COLUMN + 4]:
		var top := -1
		for row in range(4, 10):
			if blocks.get_cell_source_id(Vector2i(column, row)) != -1:
				top = row
				break
		check(top == SUMP_FLOOR_ROW - (column - SLUICE_COLUMN - 1), "behind the sluice steps of one cell climb to the line: column %d has its top on row %d" % [column, top])
	var exit := room.get_node("Exit") as Node2D
	check(exit.global_position.x > float((SLUICE_COLUMN + 4) * CELL) and exit.global_position.y < float(wall_top * CELL), "the exit lies behind the sluice and the steps, at %s" % [exit.global_position])
	await _free(room)


## Only the pool float reaches the landing, and only from the full pool: from
## the wall top it is far more than a jump, from the empty pool the landing is
## far more than a jump above it, from the full float it is a step.
func test_level_02_only_the_full_pool_float_reaches_the_landing() -> void:
	var room := await _load(LEVEL_PATH)
	var pool: Water = room.get_node("Pool")
	var pool_float: WaterFloat = pool.get_node("Float")
	var jump_reach := float(Content.player()["walk_speed"]) * 2.0 * float(Content.player()["jump_velocity"]) / float(Content.player()["gravity"])
	var jump_height := pow(float(Content.player()["jump_velocity"]), 2.0) / (2.0 * float(Content.player()["gravity"]))
	var line := float(6 * CELL)
	var opening := float(LANDING_COLUMN * CELL)
	var full := pool.float_rect_at(pool_float, Water.LEVEL_MAX)
	var empty := pool.float_rect_at(pool_float, 0)
	check(full.position.x - 18.0 * CELL > jump_reach + 64.0, "from the wall top the pool float is out of a jump: %.0f px, a jump carries %.0f" % [full.position.x - 18.0 * CELL, jump_reach])
	check(opening - full.end.x < 48.0 and opening - full.end.x >= 0.0, "the full float stands by the landing: %.0f px apart" % (opening - full.end.x))
	check(full.position.y < line + 4.0 and full.position.y > line - 48.0, "the full float's top is level with the landing: %.0f, the line %.0f" % [full.position.y, line])
	check(empty.position.y - line > jump_height, "from the float on the empty pool floor the landing is out of a jump: %.0f px up, a jump is %.0f" % [empty.position.y - line, jump_height])
	check(pool.global_position.y - line > jump_height + 64.0, "from the pool floor the hero cannot climb out without the float")
	await _free(room)




## A gate opens when the tank it watches has run low and closes when it is
## above that level again.
func test_a_water_gate_follows_the_level_of_its_tank() -> void:
	var room := Node2D.new()
	_tree.root.add_child(room)
	var tank := Water.new()
	tank.object_id = "well"
	tank.size = Vector2(256, 768)
	tank.position = Vector2(0, 768)
	room.add_child(tank)
	var gate: WaterGate = (load("res://objects/water_gate.tscn") as PackedScene).instantiate()
	gate.apply_settings({"open_level": 500, "open_seconds": 1})
	gate.position = Vector2(400, 700)
	room.add_child(gate)
	tank.level = 501
	for i in 90:
		gate.simulate_tick(i)
	check(gate.open == 0 and not gate.powered, "one unit over the level the gate stays shut, open %d" % gate.open)
	tank.level = 500
	for i in 90:
		gate.simulate_tick(i)
	check(gate.open == Door.OPEN_MAX, "at the level the gate opens fully, open %d" % gate.open)
	tank.level = 4000
	for i in 90:
		gate.simulate_tick(i)
	check(gate.open == 0, "with the tank high again the gate closes, open %d" % gate.open)
	var state := gate.capture_state()
	check(state.has("powered") and int(state["open"]) == 0, "the gate's state is recorded like a door's")
	room.queue_free()
	await _tree.process_frame


## The level and the float do not jump between frames, on the way back through
## the prelude and on the way forward again.
func test_level_02_water_and_float_are_continuous() -> void:
	var room := await _load(LEVEL_PATH)
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var float_body: WaterFloat = well.get_node("Float")
	var time: RoomTime = room.get_node("RoomTime")
	room.get_node("Player").respawn(Vector2(1088, 6 * CELL))
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
	# The fastest rewind (D62) goes back `rewind_speed_max` frames a tick.
	var fast := int(Content.time()["rewind_speed_max"])
	check(worst[0] <= (well.step() + 1) * fast, "the well level jumps %d per tick, its step is %d" % [worst[0], well.step()])
	check(worst[1] <= (pool.step() + 1) * fast, "the pool level jumps %d per tick, its step is %d" % [worst[1], pool.step()])
	check(worst[2] <= 2.5 * fast, "the float jumps %.1f px in one tick" % worst[2])
	await _free(room)


func _track(well: Water, pool: Water, float_body: WaterFloat, last: Array, worst: Array) -> void:
	worst[0] = maxi(worst[0], absi(well.level - int(last[0])))
	worst[1] = maxi(worst[1], absi(pool.level - int(last[1])))
	var float_y := well.float_rect_at(float_body, well.level).position.y
	worst[2] = maxf(worst[2], absf(float_y - float(last[2])))
	last[0] = well.level
	last[1] = pool.level
	last[2] = float_y


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
	check(player.global_position.y > float(WELL_FLOOR_ROW * CELL) - 4.0, "he is on the well floor, y %.0f" % player.global_position.y)
	await _free(room)


func test_level_02_waters_have_their_own_drain_times() -> void:
	var room := await _load(LEVEL_PATH)
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	# Data seconds are seconds of the world clock (D96).
	var ticks := Content.world_ticks_per_second(Content.time())
	var settings: Dictionary = Content.level_for_scene(LEVEL_PATH)["objects"]
	var well_seconds := float(Water.LEVEL_MAX) / float(well.step()) / ticks
	var pool_seconds := float(Water.LEVEL_MAX) / float(pool.step()) / ticks
	check(absf(well_seconds - float(settings["well"]["full_seconds"])) < 0.5, "the well runs empty in %.2f s, the data say %s" % [well_seconds, settings["well"]["full_seconds"]])
	check(absf(pool_seconds - float(settings["pool"]["full_seconds"])) < 0.3, "the pool runs full in %.2f s, the data say %s" % [pool_seconds, settings["pool"]["full_seconds"]])
	check(well.look.outlet_inset_px == float(settings["well"]["outlet_inset_px"]), "the well takes its grate place from the data")
	check(pool.look.outlet_inset_px == float(settings["pool"]["outlet_inset_px"]), "the pool takes its pipe place from the data")
	check(well.powered and well.open_flow == -1 and pool.powered and pool.open_flow == 1, "the well drains and the pool fills from the first tick")
	check(pool.outlet_side == -1, "the pool's pipe comes out of the wall the well runs through")
	await _free(room)


## The well runs into the pool: while one falls the other rises, both from the
## first tick, and Shift turns both back together.
func test_level_02_the_well_runs_into_the_pool() -> void:
	var room := await _load(LEVEL_PATH)
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var time: RoomTime = room.get_node("RoomTime")
	room.get_node("Player").respawn(Vector2(1088, 6 * CELL))
	await _rewind_to_start(time)
	Input.action_release("rewind")
	var start := [well.level, pool.level]
	await _ticks(60)
	check(well.level < int(start[0]) and pool.level > int(start[1]), "a second later the well fell and the pool rose: %d -> %d, %d -> %d" % [start[0], well.level, start[1], pool.level])
	var then := [well.level, pool.level]
	Input.action_press("rewind")
	await _ticks(20)
	Input.action_release("rewind")
	check(well.level > int(then[0]) and pool.level < int(then[1]), "under Shift the well rises and the pool falls: %d -> %d, %d -> %d" % [then[0], well.level, then[1], pool.level])
	await _free(room)


## The pool fills over a hero on its floor: the water does not lift him, it
## closes over his head and the breath runs down. On the pool float the replay
## carries him up to the way out without wetting his head.
func test_level_02_the_filling_pool_carries_the_hero_only_on_its_float() -> void:
	var room := await _load(LEVEL_PATH)
	var pool: Water = room.get_node("Pool")
	var time: RoomTime = room.get_node("RoomTime")
	var player: Player = room.get_node("Player")
	player.respawn(Vector2(1088, 6 * CELL))
	await _rewind_to_start(time)
	player.respawn(Vector2(22.0 * CELL, POOL_FLOOR_ROW * CELL))
	await _ticks(10)
	Input.action_release("rewind")
	await _ticks(240)
	check(player.global_position.y > float(POOL_FLOOR_ROW * CELL) - 4.0, "the hero stays on the pool floor while the water rises, y %.0f" % player.global_position.y)
	check(player.is_head_under_water() and player.breath_fraction() < 0.9, "the water closes over him and the breath runs down: %.2f" % player.breath_fraction())
	await _free(room)
	room = await _load(LEVEL_PATH)
	pool = room.get_node("Pool")
	time = room.get_node("RoomTime")
	player = room.get_node("Player")
	var pool_float: WaterFloat = pool.get_node("Float")
	var drowned := [false]
	player.drowned.connect(func() -> void: drowned[0] = true)
	player.respawn(Vector2(1088, 6 * CELL))
	await _rewind_to_start(time)
	var rect := pool.float_rect_at(pool_float, pool.level)
	player.respawn(Vector2(rect.get_center().x, rect.position.y))
	await _ticks(10)
	Input.action_release("rewind")
	var lowest := 1.0
	for i in 360:
		await _ticks(1)
		lowest = minf(lowest, player.breath_fraction())
	check(not drowned[0] and lowest > 0.99, "on the float the hero keeps his breath: it fell to %.2f" % lowest)
	check(player.global_position.y < float(6 * CELL), "the float carried him up to the landing, y %.0f" % player.global_position.y)
	Input.action_press("move_right")
	await _ticks(90)
	Input.action_release("move_right")
	check(not bool(room.get("is_completed")), "the full pool keeps the gate shut: the hero must not walk out")
	var gate: WaterGate = room.get_node("Gate")
	check(player.global_position.x < gate.rect_at(0).position.x and player.global_position.y < float(6 * CELL) + 1.0, "he stops on the landing before the gate, at %s" % [player.global_position])
	await _free(room)


## The same water works the other way at the end (D98): the pool that carried
## the hero up holds the gate shut, waiting on the landing keeps it shut, and
## Shift sends the pool down and lifts the gate smoothly so he walks out.
func test_level_02_the_pool_holds_the_gate_and_shift_opens_it() -> void:
	var room := await _load(LEVEL_PATH)
	var pool: Water = room.get_node("Pool")
	var gate: WaterGate = room.get_node("Gate")
	var player: Player = room.get_node("Player")
	var landing := Vector2((LANDING_COLUMN + 2) * CELL, 6 * CELL)
	player.respawn(landing)
	await _ticks(300)
	check(pool.level == Water.LEVEL_MAX and gate.open == 0, "waiting on the landing keeps the gate shut: pool %d, gate %d" % [pool.level, gate.open])
	check(not player.is_head_under_water() and absf(player.global_position.y - landing.y) < 2.0, "the landing is dry and holds the hero, at %s" % [player.global_position])
	Input.action_press("rewind")
	var last := gate.open
	var worst := 0
	var opened_at := -1
	for i in 600:
		await _ticks(1)
		worst = maxi(worst, absi(gate.open - last))
		last = gate.open
		if gate.open == Door.OPEN_MAX and opened_at < 0:
			opened_at = i
	check(opened_at >= 0, "under Shift the pool goes down and the gate opens")
	check(worst <= Door.OPEN_MAX / 20, "the gate rises smoothly, at least 20 frames from shut to open: the largest step %d" % worst)
	check(absf(player.global_position.y - landing.y) < 2.0, "the hero stays on the landing while the pool goes down, at %s" % [player.global_position])
	# With the gate up, under Shift, the way leads into the full sump (D99).
	var sump: Water = room.get_node("Sump")
	var sluice: WaterGate = room.get_node("Sluice")
	Input.action_press("move_right")
	await _ticks(120)
	check(not bool(room.get("is_completed")), "under Shift the hero does not walk out")
	check(player.global_position.x > gate.rect_at(0).end.x and player.global_position.y > float(6 * CELL) + 32.0, "past the gate he falls into the sump, at %s" % [player.global_position])
	check(sump.level == Water.LEVEL_MAX and sluice.open == 0 and player.is_head_under_water(), "under Shift the sump is full and holds the sluice shut: sump %d, sluice %d" % [sump.level, sluice.open])
	await _free(room)


## Behind the gate (D99): under Shift the sump stays full and the hero, who
## cannot climb back, drowns there; let go of Shift under water and the replay
## drains the sump before the air runs out, the sluice opens and he walks out.
func test_level_02_in_the_sump_letting_go_of_shift_saves_the_hero() -> void:
	for let_go in [false, true]:
		var room := await _load(LEVEL_PATH)
		var time: RoomTime = room.get_node("RoomTime")
		var player: Player = room.get_node("Player")
		var sump: Water = room.get_node("Sump")
		var drowned := [false]
		player.drowned.connect(func() -> void: drowned[0] = true)
		player.respawn(Vector2((LANDING_COLUMN + 2) * CELL, 6 * CELL))
		await _rewind_to_start(time)
		var dive := Vector2((SUMP_COLUMNS.x + 1) * CELL, 6 * CELL - 8)
		player.respawn(dive)
		await _ticks(90)
		check(player.is_head_under_water() and player.global_position.y > float(SUMP_FLOOR_ROW * CELL) - 4.0, "under Shift the hero sinks to the floor of the full sump, at %s" % [player.global_position])
		if let_go:
			Input.action_release("rewind")
		var lowest := 1.0
		var head_out := -1
		for i in 360:
			await _ticks(1)
			lowest = minf(lowest, player.breath_fraction())
			if head_out < 0 and not player.is_head_under_water():
				head_out = i
			if drowned[0]:
				break
		if not let_go:
			check(drowned[0], "holding Shift in the sump drowns the hero: the sump stays at %d" % sump.level)
			await _free(room)
			continue
		check(not drowned[0] and lowest > 0.3, "the replay drains the sump in time: the breath fell to %.2f" % lowest)
		check(head_out >= 0 and head_out < 180, "the head is out of the water %d ticks after letting go" % head_out)
		Input.action_press("move_right")
		for i in 240:
			await _ticks(1)
			if bool(room.get("is_completed")):
				break
			if i % 20 == 0:
				Input.action_press("jump")
			elif i % 20 == 4:
				Input.action_release("jump")
		Input.action_release("jump")
		check(bool(room.get("is_completed")), "with the sump low the sluice is up and the hero climbs out, he stopped at %s" % [player.global_position])
		await _free(room)


## The events come one after another (D99): the well drains first, then the
## pipe starts the pool, the gate shuts, the sump drains, the sluice opens.
## And never both at once: while the gate is open enough to walk under, the
## sump stands over the hero's head, so no timing lets him through dry.
func test_level_02_events_come_in_order_and_the_gate_never_meets_a_dry_sump() -> void:
	var room := await _load(LEVEL_PATH)
	var time: RoomTime = room.get_node("RoomTime")
	var player: Player = room.get_node("Player")
	var well: Water = room.get_node("Well")
	var pool: Water = room.get_node("Pool")
	var sump: Water = room.get_node("Sump")
	var gate: WaterGate = room.get_node("Gate")
	var sluice: WaterGate = room.get_node("Sluice")
	player.respawn(Vector2((LANDING_COLUMN + 2) * CELL, 6 * CELL))
	await _rewind_to_start(time)
	Input.action_release("rewind")
	var hero := player.body_rect().size.y
	var head_level := int(ceil((hero - float(Content.player()["head_px"]) / 2.0) / sump.size.y * Water.LEVEL_MAX))
	var passable := int(ceil(hero / gate.height * Door.OPEN_MAX))
	var first := {}
	var both := 0
	for i in 600:
		await _ticks(1)
		for event: String in ["well", "pool", "gate", "sump", "sluice"]:
			if first.has(event):
				continue
			var started := false
			match event:
				"well": started = well.level < Water.LEVEL_MAX
				"pool": started = pool.level > 0
				"gate": started = gate.open < Door.OPEN_MAX
				"sump": started = sump.level < Water.LEVEL_MAX
				"sluice": started = sluice.open > 0
			if started:
				first[event] = i
		if gate.open >= passable and sump.level < head_level:
			both += 1
	check(first.size() == 5, "every event happens in 10 s: %s" % [first])
	var order := ["well", "pool", "gate", "sump", "sluice"]
	for k in range(1, order.size()):
		check(int(first.get(order[k], -1)) > int(first.get(order[k - 1], 0)) + 12, "%s starts after %s with a pause: %s" % [order[k], order[k - 1], first])
	check(both == 0, "the gate open for the hero (%d of %d) never meets a sump under his head (%d): %d ticks" % [passable, Door.OPEN_MAX, head_level, both])
	await _free(room)


# --- the water does not carry the hero ------------------------------------

## Rising water of this level does not lift the hero (task 3.1, 17.11.2026):
## only the float does. A hero left on the well floor stays there while the
## water rises over him; on the float he goes up.
func test_level_02_rising_water_does_not_carry_the_hero_without_the_float() -> void:
	var room := await _load(LEVEL_PATH)
	var well: Water = room.get_node("Well")
	var time: RoomTime = room.get_node("RoomTime")
	var player: Player = room.get_node("Player")
	check(not well.lifts_player and not (room.get_node("Pool") as Water).lifts_player, "both waters of the level leave the player to the float")
	player.respawn(Vector2(920, WELL_FLOOR_ROW * CELL))
	await _ticks(10)
	Input.action_press("rewind")
	await _ticks(150)
	Input.action_release("rewind")
	check(well.rise_px_per_second == 0.0, "the water does not report a rise to the player")
	check(player.global_position.y > float(WELL_FLOOR_ROW * CELL) - 4.0, "the hero stays on the well floor while the water rises over him, y %.0f" % player.global_position.y)
	check(player.is_head_under_water(), "and the water closes over his head")
	await _free(room)
	room = await _load(LEVEL_PATH)
	well = room.get_node("Well")
	player = room.get_node("Player")
	var float_body: WaterFloat = well.get_node("Float")
	await _ticks(150)
	player.respawn(Vector2(well.position.x + float_body.position.x, well.float_rect_at(float_body, well.level).position.y))
	await _ticks(10)
	var before := player.global_position.y
	Input.action_press("rewind")
	await _ticks(120)
	Input.action_release("rewind")
	check(player.global_position.y < before - 50.0, "on the float the hero goes up with the water: from %.0f to %.0f" % [before, player.global_position.y])
	await _free(room)


## The sparks play from the world tick, so they run the other way under Shift.
func test_button_sparks_are_decoration_that_reverses() -> void:
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
	# No level stands on a button now (level 02 lost its button 21.11.2026); the
	# sparks stay for the next one, checked here without a room.


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
		"objects": {"well": {"full_seconds": 9, "outlet_inset_px": 352, "lifts_player": false}, "gate": {"open_level": 500, "open_seconds": 2}}}
	check(Content.validate_levels([good], 20.0).is_empty(), "valid water settings must pass: %s" % [Content.validate_levels([good], 20.0)])
	for bad: Variant in [{"full_seconds": 0}, {"full_seconds": "fast"}, {"outlet_inset_px": -3}, {"outlet_inset_px": "left"}, {"lifts_player": "no"}, {"lifts_player": 0}, {"open_level": -1}, {"open_level": "low"}, {"open_level": 10001}]:
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
