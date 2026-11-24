extends RefCounted
## Tests of level 05 «Crane» (card docs/levels/05.md, D139): a runaway crane's
## ram knocks the girders of the gallery off one by one from the right, each
## girder's lamp falling with it. Under Shift the girder knocked last rises
## first and lifts the heroine to the gallery; the stop lever on the operator's
## post holds the crane wherever it is. The bridge girder is lowered slowly, so
## it never lies while the girder by the post hangs, unless the crane is stopped
## between them. The solutions in tests/solutions/level_05*.json play the level.

const LEVEL_PATH := "res://levels/level_05.tscn"
const CELL := 64.0
## Girders of the level from the left: the lift by the start, two lost ones
## (the second by the post), the bridge.
const LIFT := 0
const BY_POST := 2
const BRIDGE := 3

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


func test_collapse_plan_reach_falls_and_paths() -> void:
	check(CollapsePlan.reach_phase(500.0, 100.0, 10, 100, 300.0, 0.0) == 10 + 50, "a ram riding left reaches the middle halfway")
	check(CollapsePlan.reach_phase(500.0, 100.0, 10, 100, 450.0, 0.0) < CollapsePlan.reach_phase(500.0, 100.0, 10, 100, 300.0, 0.0),
		"riding left it reaches the right girder first")
	check(CollapsePlan.reach_phase(500.0, 100.0, 10, 100, 50.0, 0.0) == -1, "a girder past the end of the rail is never knocked")
	var plan := CollapsePlan.from_data({"lamps": [0, -1], "girder_fall_seconds": [1.0, 4.0]}, 10.0,
		{"fall_seconds": 0.5, "shatter_seconds": 0.5}, {"shake_seconds": 1.0})
	check(plan.fall_of(0) == 10 and plan.fall_of(1) == 40, "each girder comes down in its own time")
	check(plan.drop(1, -1) == 0.0 and plan.drop(1, 20) == 0.5 and plan.drop(1, 40) == 1.0, "a girder hangs, comes down, lies")
	var early := plan.path(1, 12)
	check(early.x > 0.5 and early.y == 0.0, "a dragged girder first slides sideways at the rail, %s" % early)
	check(plan.path(1, 40) == Vector2.ONE, "and ends where it lies")
	check(plan.settled_tick() >= 40, "the collapse settles after the slowest girder")
	check(float(plan.lamp_fall(-1, 12.0)["light"]) == 1.0, "a lamp shines while its girder hangs")
	var down := plan.lamp_fall(plan.settled_tick(), 12.0)
	check(float(down["light"]) == 0.0 and float(down["shatter"]) == 1.0 and float(down["to_row"]) == 12.0,
		"it falls with its girder and shatters where the girder lies")
	check(plan.shake(0) == 1.0 and plan.shake(10) == 0.0, "the slam shakes the hall, then it dies away")


func test_collapse_data_is_checked() -> void:
	var good := {"lamps": [0, -1], "girder_fall_seconds": [1, 5]}
	check(CollapsePlan.problems(good, "x", 1).is_empty(), "good collapse data has no problems")
	check(CollapsePlan.problems({"lamps": [0], "girder_fall_seconds": 1}, "x", 1).is_empty(), "one fall time for all is fine")
	check(not CollapsePlan.problems({"lamps": [3], "girder_fall_seconds": 1}, "x", 1).is_empty(), "a lamp the world does not have is reported")
	check(not CollapsePlan.problems({"lamps": [0], "girder_fall_seconds": [1, 0]}, "x", 1).is_empty(), "a zero fall time is reported")
	check(not CollapsePlan.problems({"lamps": [0]}, "x", 1).is_empty(), "a missing fall time is reported")
	var crane := {"load": "l", "hook_lead_px": 0, "falls": [], "collapse": {"lamps": [5], "girder_fall_seconds": 1}}
	check(not CranePlan.problems(crane, "x", 1).is_empty(), "the crane data check covers its collapse")
	crane["collapse"] = good
	check(CranePlan.problems(crane, "x", 1).is_empty(), "a crane whose lamps fall with its girders needs no strikes of its own")


func test_level_05_the_crane_knocks_the_gallery_down_before_her_eyes() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var light := room.get_node("WorldLight") as WorldLight
	var count := collapse.girders.size()
	await _ticks(2)
	for k in count:
		check(collapse.girder_hangs(k), "girder %d hangs when she walks in" % k)
	var knocked: Array[int] = []
	var dark: Array[int] = []
	for k in count:
		knocked.append(-1)
		dark.append(-1)
	var both := false
	for t in 16 * 60:
		await _tree.physics_frame
		for k in count:
			if knocked[k] < 0 and not collapse.girder_hangs(k):
				knocked[k] = t
			if dark[k] < 0 and light.lights[collapse.plan.lamps[k]].energy < 0.01:
				dark[k] = t
		both = both or (collapse.girder_hangs(BY_POST) and collapse.girder_lies(BRIDGE))
	for k in range(1, count):
		check(knocked[k] < knocked[k - 1], "the ram knocks the girders from the right to the left, %s" % [knocked])
	for k in count:
		check(dark[k] > knocked[k], "the lamp of girder %d goes out after its girder is knocked, %s %s" % [k, knocked, dark])
		check(collapse.girder_lies(k), "girder %d has come down" % k)
	check(not both, "the bridge never lies while the girder by the post still hangs")
	check(light.lights[light.lights.size() - 1].energy > 0.5, "the lamp of the operator's post still shines")
	check(collapse.girder_holds(LIFT) and collapse.girder_holds(BRIDGE), "the lift and the bridge can be stood on")
	check(not collapse.girder_holds(1) and not collapse.girder_holds(BY_POST), "the lost girders hold nobody at the bottom of the pit")
	await _free(room)


func test_level_05_under_shift_the_girder_knocked_last_lifts_her() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var player: Player = room.get_node("Player")
	await _ticks(14 * 60)
	var lift := collapse.girder_rect(LIFT)
	player.respawn(Vector2(lift.get_center().x, lift.position.y))
	await _ticks(10)
	Input.action_press("rewind")
	var risen := false
	for t in 6 * 60:
		await _tree.physics_frame
		if collapse.girder_hangs(LIFT):
			risen = true
			for k in range(1, collapse.girders.size()):
				check(not collapse.girder_hangs(k), "girder %d, knocked earlier, still lies" % k)
			break
	check(risen, "the lift girder rises back to the rail")
	check(absf(player.global_position.y - collapse.girders[LIFT].position.y) < 4.0,
		"and carries her up with it, y %.0f" % player.global_position.y)
	Input.action_release("rewind")
	await _free(room)


func test_level_05_a_girder_coming_down_holds_nobody() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	while collapse.girder_hangs(BRIDGE):
		await _tree.physics_frame
	await _ticks(10)
	check(not collapse.girder_holds(BRIDGE) and not collapse.girder_lies(BRIDGE), "the bridge girder on its way down holds nobody")
	check(load_platform.phase < load_platform.once_last_phase(), "the crane rides on")
	await _free(room)


func test_level_05_the_stop_lever_holds_the_crane_and_the_girders_ahead() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	var lever := room.get_node("CraneStop") as Lever
	check(lever.target_id == load_platform.object_id, "the lever on the post stops the crane")
	while collapse.girder_hangs(BRIDGE):
		await _tree.physics_frame
	await _ticks(30)
	load_platform.powered = true
	var held := load_platform.phase
	await _ticks(8 * 60)
	check(load_platform.phase == held, "the stopped crane stands where it was, phase %d" % load_platform.phase)
	check(collapse.girder_lies(BRIDGE), "the bridge girder it knocked comes down and lies")
	for k in BRIDGE:
		check(collapse.girder_hangs(k), "girder %d ahead of the crane keeps hanging" % k)
	await _free(room)


func test_level_05_a_fall_into_the_pit_starts_the_room_again() -> void:
	var room := await _load()
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	var player: Player = room.get_node("Player")
	await _ticks(6 * 60)
	check(load_platform.phase > 60, "the crane has gone on")
	player.respawn(Vector2(11.0 * CELL, 14.0 * CELL))
	await _ticks(90)
	check(player.global_position.x < 5.0 * CELL, "after the fall she is back at the start, x %.0f" % player.global_position.x)
	check(load_platform.phase < 90, "and the room starts again from its beginning, load phase %d" % load_platform.phase)
	await _free(room)


func test_level_05_layout() -> void:
	var room := await _load()
	var collapse := room.get_node("Collapse") as Collapse
	var blocks := room.get_node("Blocks") as TileMapLayer
	var used := blocks.get_used_rect()
	var solid := func(x: float, y: float) -> bool:
		return blocks.get_cell_source_id(Vector2i(int(floor(x / CELL)), int(floor(y / CELL)))) != -1
	# The lift lies on the start floor; the lost girders inside the room.
	var lift := collapse.rests[LIFT]
	check(solid.call(lift.get_center().x, lift.end.y + 1.0), "the lift girder lies on the start floor")
	for k in collapse.lost:
		check(collapse.rests[k].end.y <= float(used.end.y) * CELL, "lost girder %d lies inside the room" % k)
	# The bridge hangs out of reach of the gallery and lies within a drop of it.
	var by_post := collapse.girders[BY_POST]
	check(collapse.girders[BRIDGE].position.x - by_post.end.x >= 3.0 * CELL, "the hanging bridge girder is out of reach of the gallery")
	var bridge := collapse.rests[BRIDGE]
	check(bridge.position.x - by_post.end.x <= 1.0 * CELL and bridge.position.x >= by_post.end.x,
		"from the end of the girder by the post she drops onto the bridge")
	check(solid.call(bridge.get_center().x, bridge.end.y + 1.0), "the bridge girder lies on its stub")
	# A slab covers the way to the exit: from the hanging bridge nobody drops to it.
	var over := collapse.girders[BRIDGE]
	check(solid.call(over.get_center().x, over.end.y + CELL * 0.75), "a slab lies under the hanging bridge girder")
	# The stop lever stands on the operator's post, next to the girder by the post.
	var lever := room.get_node("CraneStop") as Node2D
	check(solid.call(lever.position.x, lever.position.y + 1.0), "the stop lever stands on the post")
	check(lever.position.x < by_post.position.x, "on the start side of the girder by the post")
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
