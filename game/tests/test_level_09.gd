extends RefCounted
## Tests of level 09 «Crane» (card docs/levels/09.md): a runaway crane struck
## the lamps in the prelude, so the room starts dark. The strikes come from the
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


func test_level_09_starts_dark_with_every_lamp_on_the_floor() -> void:
	var room := await _load()
	var crane := room.get_node("Crane") as Crane
	var load_platform := crane.load_platform()
	check(load_platform != null, "the crane finds its load")
	check(load_platform.phase == load_platform.once_last_phase(), "the load has stopped when she walks in")
	for i in 3:
		var fall := crane.lamp_fall(i)
		check(not fall.is_empty() and float(fall["shatter"]) == 1.0, "lamp %d lies shattered at the start" % i)
	var light := room.get_node("WorldLight") as WorldLight
	await _ticks(2)
	for i in light.lights.size():
		check(light.lights[i].energy < 0.01, "lamp %d gives no light at the start, %.2f" % [i, light.lights[i].energy])
	await _free(room)


func test_level_09_last_lamp_shatters_before_the_load_stops() -> void:
	var room := await _load()
	var crane := room.get_node("Crane") as Crane
	var load_platform := crane.load_platform()
	check(crane.plan.last_phase() >= 0 and crane.plan.last_phase() <= load_platform.once_last_phase(),
		"every lamp has shattered before the load stops: the head stands still (D56)")
	var hits: Array[int] = []
	for fall: Dictionary in crane.plan.falls:
		hits.append(int(fall["hit"]))
	check(hits[0] < hits[1] and hits[1] < hits[2], "the hook strikes lamps 1, 2, 3 in turn, %s" % [hits])
	await _free(room)


func test_level_09_shift_brings_the_light_back_and_release_plays_the_strikes_again() -> void:
	var room := await _load()
	var light := room.get_node("WorldLight") as WorldLight
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	Input.action_press("rewind")
	await _ticks(6 * 60)
	check(load_platform.phase == 0, "under Shift the load rides back to the start of history")
	for i in light.lights.size():
		check(light.lights[i].energy > 0.5, "under Shift lamp %d shines again, %.2f" % [i, light.lights[i].energy])
	Input.action_release("rewind")
	await _ticks(12 * 60)
	check(load_platform.phase == load_platform.once_last_phase(), "after release the load rides to the end again")
	for i in light.lights.size():
		check(light.lights[i].energy < 0.01, "after release lamp %d is struck again (rule A)" % i)
	await _free(room)


func test_level_09_the_parked_load_is_out_of_reach_without_the_crane() -> void:
	var room := await _load()
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	var blocks := room.get_node("Blocks") as TileMapLayer
	var end := load_platform.rect_at(load_platform.position_at(load_platform.once_last_phase()))
	var start := load_platform.rect_at(load_platform.position_at(0))
	# The exit ledge begins right after the parked load, level with its top.
	var ledge := Vector2i(int(end.end.x / CELL), int(end.position.y / CELL))
	check(blocks.get_cell_source_id(ledge) != -1 and blocks.get_cell_source_id(ledge - Vector2i(0, 1)) == -1,
		"the load stops flush with the exit ledge, level with its top")
	# Under the parked load: three empty cells down to the lower hall floor.
	var below := Vector2i(int(end.get_center().x / CELL), int(end.end.y / CELL))
	for k in 3:
		check(blocks.get_cell_source_id(below + Vector2i(0, k)) == -1, "nothing to climb under the parked load, row %d" % (below.y + k))
	check(blocks.get_cell_source_id(below + Vector2i(0, 3)) != -1, "the lower hall floor is three cells under the parked load")
	# At the start of history the load hangs one cell from pillar A, a cell higher.
	var pillar := Vector2i(int(start.position.x / CELL) - 2, int(start.position.y / CELL) + 1)
	check(blocks.get_cell_source_id(pillar) != -1 and blocks.get_cell_source_id(pillar - Vector2i(0, 1)) == -1,
		"pillar A stands a cell left of the load's start, its top a cell lower")
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
