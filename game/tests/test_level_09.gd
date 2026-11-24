extends RefCounted
## Tests of level 09 «Crane» (card docs/levels/09.md): a runaway crane strikes
## two lamps, slams into its stop, and the collapse (D132) drops the girders as
## a bridge over the pit and breaks the lamps over it, so the room goes dark. The strikes come from the
## load's recorded phase (`CranePlan`): under Shift the load rides back and the
## lamps fly up, after Shift is released the same strikes play again. The
## solutions in tests/solutions/level_09*.json play the level.

const LEVEL_PATH := "res://levels/level_09.tscn"
const CELL := 64.0

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_crane_plan_strikes_the_lamps_in_order_along_its_way() -> void:
	var plan := CranePlan.from_data({"load": "l", "hook_lead_px": 10,
		"falls": [{"lamp": 0, "to_row": 5}, {"lamp": 1, "to_row": 5}, {"lamp": 2, "to_row": 5}]},
		48.0, {"fall_seconds": 0.5, "shatter_seconds": 0.5})
	# The hook rides from x 100 to x 500 in 100 ticks after a delay of 10.
	plan.aim(100.0, 500.0, 10, 100, [150.0, 300.0, 900.0])
	check(int(plan.falls[0]["hit"]) == 10 + 10, "lamp 0 is struck when the hook is 10 px short of it, hit %d" % int(plan.falls[0]["hit"]))
	check(int(plan.falls[1]["hit"]) > int(plan.falls[0]["hit"]), "lamp 1 further along is struck later")
	check(int(plan.falls[2]["hit"]) == -1, "a lamp beyond the end of the way is never struck")
	check(plan.lamp_fall(2, 500).is_empty(), "a lamp never struck has no fall")
	var before := plan.lamp_fall(0, 19)
	check(float(before["drop"]) == 0.0 and float(before["light"]) == 1.0, "before the strike the lamp hangs and shines")
	var after := plan.lamp_fall(0, 20 + plan.fall_ticks + plan.shatter_ticks)
	check(float(after["drop"]) == 1.0 and float(after["light"]) == 0.0 and float(after["shatter"]) == 1.0,
		"after fall and shatter the lamp lies dark on the floor")
	check(plan.lamp_fall(0, 0) == plan.lamp_fall(0, 0), "the same phase always gives the same fall")


func test_crane_data_is_checked() -> void:
	check(CranePlan.problems({"load": "l", "hook_lead_px": 0, "falls": [{"lamp": 0, "to_row": 1}]}, "x", 1).is_empty(),
		"good crane data has no problems")
	check(not CranePlan.problems({"load": "", "hook_lead_px": 0, "falls": [{"lamp": 0, "to_row": 1}]}, "x", 1).is_empty(),
		"a crane without its load is reported")
	check(not CranePlan.problems({"load": "l", "hook_lead_px": -1, "falls": [{"lamp": 0, "to_row": 1}]}, "x", 1).is_empty(),
		"a negative hook lead is reported")
	check(not CranePlan.problems({"load": "l", "hook_lead_px": 0, "falls": [{"lamp": 3, "to_row": 1}]}, "x", 1).is_empty(),
		"a fall of a lamp the world does not have is reported")
	check(not CranePlan.problems({"load": "l", "hook_lead_px": 0, "falls": []}, "x", 1).is_empty(),
		"a crane that strikes nothing is reported")


func test_world_darkness_and_lamp_radius_are_checked() -> void:
	var good := {"darkness": "#17171e", "lamps": [{"x": 1, "drop": 1, "radius_px": 400}]}
	check(WorldData.validate_layout(good, "x").is_empty(), "a darker room and a lamp's own radius are fine")
	check(not WorldData.validate_layout({"darkness": "dark"}, "x").is_empty(), "a darkness that is no colour is reported")
	check(not WorldData.validate_layout({"lamps": [{"x": 1, "drop": 1, "radius_px": 0}]}, "x").is_empty(),
		"a lamp radius of 0 is reported")


func test_collapse_plan_girders_fall_first_then_lamps_from_the_exit_back() -> void:
	var plan := CollapsePlan.from_data({"lamps": [2, 3, 4], "to_row": 18, "girder_first_seconds": 0.5,
		"girder_every_seconds": 0.5, "girder_fall_seconds": 0.5, "lamp_pause_seconds": 1.0,
		"lamp_every_seconds": 1.0}, 10.0, {"fall_seconds": 0.5, "shatter_seconds": 0.5}, 3)
	check(plan.girder_start(0) < plan.girder_start(1) and plan.girder_start(1) < plan.girder_start(2),
		"the girders fall one by one from the stop towards the exit")
	check(plan.girder_drop(0, -1) == 0.0 and plan.girder_drop(0, plan.girder_start(0)) == 0.0 \
		and plan.girder_drop(0, plan.girder_start(0) + plan.girder_fall) == 1.0, "a girder hangs, then lies")
	check(plan.lamp_hit(2) < plan.lamp_hit(1) and plan.lamp_hit(1) < plan.lamp_hit(0),
		"the lamps break from the exit back towards the stop")
	check(plan.lamp_hit(2) - plan.girders_landed() == plan.lamp_pause, "a pause between the last girder and the first lamp")
	check(plan.lamp_fall(7, 100).is_empty(), "a lamp the collapse never touches has no fall")
	check(float(plan.lamp_fall(2, -1)["light"]) == 1.0, "before the slam the lamps shine")
	var down := plan.lamp_fall(2, plan.last_tick())
	check(float(down["light"]) == 0.0 and float(down["shatter"]) == 1.0, "at the end every lamp lies broken")


func test_collapse_data_is_checked() -> void:
	var good := {"lamps": [0], "to_row": 18, "girder_first_seconds": 0.3, "girder_every_seconds": 0.4,
		"girder_fall_seconds": 0.5, "lamp_pause_seconds": 1, "lamp_every_seconds": 1}
	check(CollapsePlan.problems(good, "x", 1).is_empty(), "good collapse data has no problems")
	var bad_lamp := good.duplicate(true)
	bad_lamp["lamps"] = [3]
	check(not CollapsePlan.problems(bad_lamp, "x", 1).is_empty(), "a lamp the world does not have is reported")
	var bad_number := good.duplicate(true)
	bad_number["lamp_every_seconds"] = 0
	check(not CollapsePlan.problems(bad_number, "x", 1).is_empty(), "a zero time is reported")
	var crane := {"load": "l", "hook_lead_px": 0, "falls": [{"lamp": 0, "to_row": 1}], "collapse": bad_lamp}
	check(not CranePlan.problems(crane, "x", 1).is_empty(), "the crane data check covers its collapse")


func test_level_09_the_crane_slams_and_the_hall_collapses_before_her_eyes() -> void:
	var room := await _load()
	var crane := room.get_node("Crane") as Crane
	var collapse := room.get_node("Collapse") as Collapse
	var load_platform := crane.load_platform()
	var light := room.get_node("WorldLight") as WorldLight
	check(load_platform != null and load_platform.phase < load_platform.once_last_phase(), "the crane is still on its way when she walks in")
	await _ticks(2)
	for i in light.lights.size():
		check(light.lights[i].energy > 0.5, "lamp %d still shines when she walks in" % i)
	var out_at: Array[int] = [-1, -1, -1, -1, -1, -1]
	var landed_at := -1
	for t in 16 * 60:
		await _tree.physics_frame
		if landed_at < 0 and collapse.girder_lies(collapse.girders.size() - 1):
			landed_at = t
		for i in out_at.size():
			if out_at[i] < 0 and light.lights[i].energy < 0.01:
				out_at[i] = t
	for i in out_at.size():
		check(out_at[i] >= 0, "lamp %d goes out while she watches" % i)
	check(out_at[0] < out_at[1], "the hook strikes lamps 1 and 2 in turn, %s" % [out_at])
	check(landed_at > out_at[1], "the collapse starts after the slam, girders landed at %d" % landed_at)
	check(out_at[5] > landed_at and out_at[5] < out_at[4] and out_at[4] < out_at[3] and out_at[3] < out_at[2],
		"then the lamps over the pit go out from the exit back towards the stop, %s" % [out_at])
	for k in collapse.girders.size():
		check(collapse.girder_lies(k), "girder %d lies on its stub" % k)
	await _free(room)


func test_level_09_hook_strikes_before_the_slam() -> void:
	var room := await _load()
	var crane := room.get_node("Crane") as Crane
	var load_platform := crane.load_platform()
	check(crane.plan.last_phase() >= 0 and crane.plan.last_phase() <= load_platform.once_last_phase(),
		"both lamps over the crane's way have shattered before the load slams into the stop")
	await _free(room)


func test_level_09_shift_brings_everything_back_and_release_plays_it_again() -> void:
	var room := await _load()
	var light := room.get_node("WorldLight") as WorldLight
	var collapse := room.get_node("Collapse") as Collapse
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	await _ticks(14 * 60)
	Input.action_press("rewind")
	await _ticks(14 * 60)
	check(load_platform.phase == 0 and collapse.since < 0, "under Shift the load rides back to the start of history")
	for i in light.lights.size():
		check(light.lights[i].energy > 0.5, "under Shift lamp %d shines again" % i)
	Input.action_release("rewind")
	await _ticks(14 * 60)
	check(load_platform.phase == load_platform.once_last_phase(), "after release the load slams into the stop again")
	for i in light.lights.size():
		check(light.lights[i].energy < 0.01, "after release lamp %d breaks again (rule A)" % i)
	for k in collapse.girders.size():
		check(collapse.girder_lies(k), "and girder %d lies again" % k)
	await _free(room)


func test_level_09_a_girder_holds_her_only_while_it_lies() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	await _ticks(2)
	var shape := collapse.get_child(0).get_child(0) as CollisionShape2D
	check(shape.disabled, "a hanging girder is not solid")
	await _ticks(14 * 60)
	check(not shape.disabled, "a girder lying on its stub is solid")
	check(collapse.girder_rect(0) == collapse.girders[0], "it lies where the level put it")
	await _free(room)


func test_level_09_a_short_shift_lights_the_bridge_a_long_one_lifts_it() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var light := room.get_node("WorldLight") as WorldLight
	var player: Player = room.get_node("Player")
	await _ticks(14 * 60)
	# She stands safe on ledge B by the stop.
	player.respawn(Vector2(22.5 * CELL, 11.0 * CELL))
	await _ticks(10)
	check(light.lights[2].energy < 0.01, "the bridge is dark")
	Input.action_press("rewind")
	await _ticks(90)
	check(light.lights[2].energy > 0.5, "a short Shift brings back the lamp nearest the stop, %.2f" % light.lights[2].energy)
	for k in collapse.girders.size():
		check(collapse.girder_lies(k), "while girder %d still lies" % k)
	var last := collapse.girders.size() - 1
	var lifted := false
	for t in 8 * 60:
		await _tree.physics_frame
		if not collapse.girder_lies(last):
			lifted = true
			check(collapse.girder_lies(0), "the last girder to fall flies back up first")
			break
	check(lifted, "a long Shift lifts the girders")
	Input.action_release("rewind")
	await _free(room)


func test_level_09_a_fall_into_the_pit_starts_the_room_again() -> void:
	var room := await _load()
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	var player: Player = room.get_node("Player")
	await _ticks(6 * 60)
	check(load_platform.phase > 60, "the crane has gone on")
	player.respawn(Vector2(15.0 * CELL, 13.0 * CELL))
	await _ticks(90)
	check(player.global_position.x < 4.0 * CELL, "after the fall she is back at the start, x %.0f" % player.global_position.x)
	check(load_platform.phase < 90, "and the room starts again from its beginning, load phase %d" % load_platform.phase)
	await _free(room)


func test_level_09_layout_ledges_and_pits() -> void:
	var room := await _load()
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	var blocks := room.get_node("Blocks") as TileMapLayer
	var end := load_platform.rect_at(load_platform.position_at(load_platform.once_last_phase()))
	var start := load_platform.rect_at(load_platform.position_at(0))
	# Ledge B begins right after the parked load, level with its top.
	var ledge := Vector2i(int(end.end.x / CELL), int(end.position.y / CELL))
	check(blocks.get_cell_source_id(ledge) != -1 and blocks.get_cell_source_id(ledge - Vector2i(0, 1)) == -1,
		"the load stops flush with ledge B, level with its top")
	# Under the parked load the pit is open to the bottom of the room.
	var below := Vector2i(int(end.get_center().x / CELL), int(end.end.y / CELL))
	var used := blocks.get_used_rect()
	for y in range(below.y, used.end.y):
		check(blocks.get_cell_source_id(Vector2i(below.x, y)) == -1, "the pit under the parked load is open, row %d" % y)
	# At the start of history the load hangs one cell from pillar A, a cell higher.
	var pillar := Vector2i(int(start.position.x / CELL) - 2, int(start.position.y / CELL) + 1)
	check(blocks.get_cell_source_id(pillar) != -1 and blocks.get_cell_source_id(pillar - Vector2i(0, 1)) == -1,
		"pillar A stands a cell left of the load's start, its top a cell lower")
	# Every girder lies on a stub, and without the girders the stubs are too far apart.
	var collapse := room.get_node("Collapse") as Collapse
	for k in collapse.girders.size():
		var g := collapse.girders[k]
		var under := Vector2i(int(g.get_center().x / CELL), int(g.end.y / CELL))
		var found := false
		for x in range(int(g.position.x / CELL), int(ceil(g.end.x / CELL))):
			found = found or blocks.get_cell_source_id(Vector2i(x, under.y)) != -1
		check(found, "girder %d rests on a stub" % k)
	await _free(room)


func _load() -> Node:
	Input.action_release("rewind")
	_reset_time()
	var room: Node = (load(LEVEL_PATH) as PackedScene).instantiate()
	_tree.root.add_child(room)
	await _tree.physics_frame
	return room


func _free(room: Node) -> void:
	Input.action_release("rewind")
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
