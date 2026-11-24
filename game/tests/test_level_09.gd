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


func test_level_09_lamps_fall_in_front_of_her_at_the_start() -> void:
	var room := await _load()
	var crane := room.get_node("Crane") as Crane
	var load_platform := crane.load_platform()
	var light := room.get_node("WorldLight") as WorldLight
	check(load_platform != null, "the crane finds its load")
	check(load_platform.phase < load_platform.once_last_phase(), "the crane is still on its way when she walks in")
	await _ticks(2)
	check(light.lights[2].energy > 0.5, "the last lamp still shines when she walks in, %.2f" % light.lights[2].energy)
	# The lamps go out one by one: never two of them in the same moment.
	var out_at: Array[int] = [-1, -1, -1]
	for t in 12 * 60:
		await _tree.physics_frame
		for i in 3:
			if out_at[i] < 0 and light.lights[i].energy < 0.01:
				out_at[i] = t
	for i in 3:
		check(out_at[i] >= 0, "lamp %d goes out while she watches" % i)
	check(out_at[0] < out_at[1] and out_at[1] < out_at[2], "the lamps go out one by one, ticks %s" % [out_at])
	check(out_at[2] < 10 * 60, "the room is dark within 10 s, at tick %d" % out_at[2])
	check(load_platform.phase == load_platform.once_last_phase(), "then the crane stands at the exit ledge")
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



func test_crane_plan_hook_strikes_while_it_passes_the_lamp() -> void:
	var plan := CranePlan.from_data({"load": "l", "hook_lead_px": 10, "falls": [{"lamp": 0, "to_row": 5}]},
		48.0, {"fall_seconds": 0.5, "shatter_seconds": 0.5})
	plan.aim(100.0, 500.0, 10, 100, [300.0])
	var hit := int(plan.falls[0]["hit"])
	var gone := int(plan.falls[0]["pass"])
	check(gone > hit, "the hook takes some ticks to pass the lamp, %d..%d" % [hit, gone])
	check(not plan.strikes(0, hit - 1) and plan.strikes(0, hit) and plan.strikes(0, gone) and not plan.strikes(0, gone + 1),
		"the hook is at the lamp from the strike until it has gone hook_lead_px past it")
	check(not plan.strikes(1, hit), "a lamp the crane never strikes is never at the hook")


func test_crane_winch_data_is_checked() -> void:
	var good := {"load": "l", "hook_lead_px": 0, "falls": [{"lamp": 0, "to_row": 1}],
		"winch": {"object": "w", "lamp": 0, "lift_px": 80, "lift_seconds": 1}}
	check(CranePlan.problems(good, "x", 1).is_empty(), "good winch data has no problems")
	var plan := CranePlan.from_data(good, 60.0, {})
	check(str(plan.winch["object"]) == "w" and int(plan.winch["lamp"]) == 0, "the plan reads its winch")
	for broken: Dictionary in [{"object": "", "lamp": 0, "lift_px": 80, "lift_seconds": 1},
			{"object": "w", "lamp": 1, "lift_px": 80, "lift_seconds": 1},
			{"object": "w", "lamp": 0, "lift_px": 0, "lift_seconds": 1},
			{"object": "w", "lamp": 0, "lift_px": 80}]:
		var bad := good.duplicate(true)
		bad["winch"] = broken
		check(not CranePlan.problems(bad, "x", 2).is_empty(), "broken winch data is reported: %s" % [broken])


func test_level_09_without_the_winch_the_hook_tears_the_door_power() -> void:
	var room := await _load()
	var winch := room.get_node("Winch") as Winch
	var door := room.find_child("ExitDoor", true, false) as ExitDoor
	var light := room.get_node("WorldLight") as WorldLight
	check(winch.lamp == 2, "the winch holds lamp 3")
	check(door.has_power(), "at the start the exit door has power")
	await _ticks(10 * 60)
	check(winch.torn and not door.has_power(), "the hook tears lamp 3 with the exit door's power cable")
	check(light.lights[2].energy < 0.01, "lamp 3 is dark")
	# A pull now winds up nothing: the lamp is already on the floor.
	await _stand_by(room, "WinchLever")
	await _press("interact")
	await _ticks(3 * 60)
	check(winch.powered and winch.torn and light.lights[2].energy < 0.01, "pulling the lever after the strike brings nothing back")
	await _free(room)


func test_level_09_a_pull_under_shift_keeps_lamp_3_and_the_door_power() -> void:
	var room := await _load()
	var winch := room.get_node("Winch") as Winch
	var door := room.find_child("ExitDoor", true, false) as ExitDoor
	var light := room.get_node("WorldLight") as WorldLight
	var load_platform := (room.get_node("Crane") as Crane).load_platform()
	await _ticks(8 * 60)
	await _stand_by(room, "WinchLever")
	Input.action_press("rewind")
	await _ticks(7 * 60)
	check(not winch.torn and door.has_power(), "under Shift the cable heals")
	await _press("interact")
	Input.action_release("rewind")
	await _ticks(12 * 60)
	check(load_platform.phase == load_platform.once_last_phase(), "the crane rides to the exit ledge again")
	check(winch.lift == Winch.FULL and not winch.torn, "lamp 3 is wound up into the roof and the hook passes under it")
	check(light.lights[2].energy > 0.5, "lamp 3 still shines by the exit, %.2f" % light.lights[2].energy)
	check(door.has_power(), "the exit door keeps its power")
	check(light.lights[0].energy < 0.01 and light.lights[1].energy < 0.01, "lamps 1 and 2 are struck as before")
	await _free(room)


func test_level_09_a_step_leads_from_the_lower_hall_back_to_pillar_a() -> void:
	var room := await _load()
	var blocks := room.get_node("Blocks") as TileMapLayer
	# Pillar A: cells 7-8 from row 12; the step: cell 9 of row 13, a cell lower.
	check(blocks.get_cell_source_id(Vector2i(9, 13)) != -1 and blocks.get_cell_source_id(Vector2i(9, 12)) == -1,
		"a step one cell high stands in the lower hall by pillar A")
	check(blocks.get_cell_source_id(Vector2i(8, 12)) != -1 and blocks.get_cell_source_id(Vector2i(8, 11)) == -1,
		"pillar A is one cell above the step")
	var lever := room.get_node("WinchLever") as Lever
	check(is_equal_approx(lever.position.y, 14.0 * CELL) and lever.position.x > 640.0 and lever.position.x < 1600.0,
		"the winch lever stands on the lower hall floor")
	await _free(room)


## Puts the heroine by the node `node_name`.
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
