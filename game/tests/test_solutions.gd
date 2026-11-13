extends RefCounted
## Level solution tests (docs/architecture.md, section 8). Every file in
## `tests/solutions/` is a recorded input for one level:
##
##   { "level": "level_01", "expect": "exit",
##     "segments": [ { "actions": ["move_right", "rewind"], "ticks": 90 } ] }
##
## The runner loads the level's scene, holds the actions of each segment for
## its ticks and checks the end: `"expect": "exit"` must reach the exit,
## `"no_exit"` must not (the level cannot be passed that way, for example
## without Shift). No randomness and no real time.
##
## A new level adds `level_NN.json` and a `level_NN_no_shift.json`; the suite
## fails when a level whose id starts with `level_` has no solution.

const SOLUTIONS_DIR := "res://tests/solutions"
const EXPECT_EXIT := "exit"
const EXPECT_NO_EXIT := "no_exit"
const LEVEL_PREFIX := "level_"
## Ticks the room settles before the first segment, as after a scene change.
const SETTLE_TICKS := 2

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_solution_files_are_valid() -> void:
	var files := solution_files()
	check(not files.is_empty(), "no solution files in %s" % SOLUTIONS_DIR)
	for path in files:
		for problem in solution_problems(Content.load_json(path)):
			check(false, "%s: %s" % [path, problem])


func test_every_level_has_a_solution_and_a_no_shift_test() -> void:
	var solved := {}
	var refused := {}
	for path in solution_files():
		var data: Variant = Content.load_json(path)
		if not solution_problems(data).is_empty():
			continue
		if str(data["expect"]) == EXPECT_EXIT:
			solved[str(data["level"])] = true
		else:
			refused[str(data["level"])] = true
	for entry: Variant in Content.levels():
		var id := str((entry as Dictionary).get("id", ""))
		if not id.begins_with(LEVEL_PREFIX):
			continue
		check(solved.has(id), "level '%s' has no solution that reaches the exit" % id)
		check(refused.has(id), "level '%s' has no test that it cannot be passed without Shift" % id)


func test_solutions_end_as_expected() -> void:
	for path in solution_files():
		var data: Variant = Content.load_json(path)
		if not solution_problems(data).is_empty():
			continue
		var reached := await play(data)
		if str(data["expect"]) == EXPECT_EXIT:
			check(reached, "%s: the solution does not reach the exit" % path)
		else:
			check(not reached, "%s: these inputs must not reach the exit, but they do" % path)


func test_no_shift_files_never_hold_rewind() -> void:
	for path in solution_files():
		if not path.ends_with("_no_shift.json"):
			continue
		var data: Variant = Content.load_json(path)
		if not solution_problems(data).is_empty():
			continue
		check(str(data["expect"]) == EXPECT_NO_EXIT, "%s: a no-Shift file must expect 'no_exit'" % path)
		for segment: Variant in data["segments"]:
			check(not "rewind" in (segment["actions"] as Array), "%s: a no-Shift file holds rewind" % path)


func test_broken_solution_files_are_reported() -> void:
	var good := {"level": "level_01", "expect": EXPECT_EXIT, "segments": [{"actions": ["move_right"], "ticks": 10}]}
	check(solution_problems(good).is_empty(), "a good solution must pass: %s" % [solution_problems(good)])
	check(not solution_problems([]).is_empty(), "a solution that is not an object must be reported")
	var unknown_level := good.duplicate(true)
	unknown_level["level"] = "no_such_level"
	check(not solution_problems(unknown_level).is_empty(), "an unknown level must be reported")
	var bad_expect := good.duplicate(true)
	bad_expect["expect"] = "maybe"
	check(not solution_problems(bad_expect).is_empty(), "an unknown 'expect' must be reported")
	var bad_action := good.duplicate(true)
	bad_action["segments"] = [{"actions": ["fly"], "ticks": 10}]
	check(not solution_problems(bad_action).is_empty(), "an unknown action must be reported")
	var bad_ticks := good.duplicate(true)
	bad_ticks["segments"] = [{"actions": [], "ticks": 0}]
	check(not solution_problems(bad_ticks).is_empty(), "a segment without ticks must be reported")
	var empty := good.duplicate(true)
	empty["segments"] = []
	check(not solution_problems(empty).is_empty(), "a solution without segments must be reported")


# --- the runner -------------------------------------------------------------

## Paths of the solution files, sorted.
static func solution_files() -> PackedStringArray:
	var files := PackedStringArray()
	for name in DirAccess.get_files_at(SOLUTIONS_DIR):
		if name.ends_with(".json"):
			files.append(SOLUTIONS_DIR.path_join(name))
	files.sort()
	return files


## What is wrong with a solution file's data; empty when it is fine.
static func solution_problems(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		errors.append("expected an object")
		return errors
	for key: String in ["level", "expect", "segments"]:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	if not errors.is_empty():
		return errors
	if _level_scene(str(data["level"])).is_empty():
		errors.append("level '%s' is not in levels.json" % data["level"])
	if not str(data["expect"]) in [EXPECT_EXIT, EXPECT_NO_EXIT]:
		errors.append("'expect' must be '%s' or '%s'" % [EXPECT_EXIT, EXPECT_NO_EXIT])
	var segments: Variant = data["segments"]
	if not segments is Array or (segments as Array).is_empty():
		errors.append("'segments' must be a list with at least one segment")
		return errors
	for i in (segments as Array).size():
		var segment: Variant = segments[i]
		if not segment is Dictionary or not segment.get("actions") is Array or not Content._is_number(segment.get("ticks")):
			errors.append("segment %d: expected 'actions' (a list) and 'ticks' (a number)" % i)
			continue
		if int(segment["ticks"]) < 1:
			errors.append("segment %d: 'ticks' must be at least 1" % i)
		for action: Variant in segment["actions"]:
			if not action is String or not InputMap.has_action(action):
				errors.append("segment %d: unknown action '%s'" % [i, action])
	return errors


## Plays a solution in its level and returns true when the player reached the
## exit. Stops at the exit: what is pressed after it does not matter.
func play(data: Dictionary) -> bool:
	_release(_all_actions(data))
	_reset_time()
	var room: Node = (load(_level_scene(str(data["level"]))) as PackedScene).instantiate()
	_tree.root.add_child(room)
	for i in SETTLE_TICKS:
		await _tree.physics_frame
	var reached := false
	for segment: Variant in data["segments"]:
		var actions: Array = segment["actions"]
		for action: Variant in _all_actions(data):
			if action in actions:
				Input.action_press(action)
			else:
				Input.action_release(action)
		for i in int(segment["ticks"]):
			await _tree.physics_frame
			if bool(room.get("is_completed")):
				reached = true
				break
		if reached:
			break
	_release(_all_actions(data))
	room.queue_free()
	await _tree.process_frame
	_reset_time()
	return reached


static func _level_scene(id: String) -> String:
	for entry: Variant in Content.levels():
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return str(entry.get("scene", ""))
	return ""


static func _all_actions(data: Dictionary) -> Array:
	var all := []
	for segment: Variant in data["segments"]:
		for action: Variant in segment["actions"]:
			if not action in all:
				all.append(action)
	return all


func _release(actions: Array) -> void:
	for action: Variant in actions:
		Input.action_release(action)


func _reset_time() -> void:
	var manager := _tree.root.get_node_or_null("TimeManager")
	if manager != null:
		manager.call("reset")
