extends RefCounted
## Tests of the in-game solution replay (task И1, D203): the solution file
## reads into actions per tick, a request names levels, without a request the
## replay is idle, and the replay plays the whole chapter through LevelLoader —
## level after level as a player passes it — to the exit of each. Run by
## test_runner.gd.

const LIST_PATH := "res://ui/level_select.tscn"
## Ticks the chapter may take: every solution plus the passages between levels.
const CHAPTER_TICK_LIMIT := 60 * 60 * 6

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_a_solution_reads_into_actions_per_tick() -> void:
	var data := {"level": "level_01", "expect": "exit", "segments": [
		{"actions": ["move_right"], "ticks": 3},
		{"actions": ["rewind", "jump"], "ticks": 2},
	]}
	var script := SolutionScript.from_data(data, 1)
	check(script != null, "a good solution must load")
	if script == null:
		return
	check(script.actions_at(0).is_empty(), "the settle tick holds nothing")
	check(script.actions_at(1) == ["move_right"] and script.actions_at(3) == ["move_right"], "the first segment holds its ticks")
	check(script.actions_at(4) == ["rewind", "jump"] and script.actions_at(5) == ["rewind", "jump"], "the second segment follows")
	check(script.actions_at(6).is_empty(), "after the last segment nothing is held")
	check(script.end_tick() == 6, "the end is settle plus every tick, got %d" % script.end_tick())
	check(script.all_actions() == ["move_right", "rewind", "jump"], "every action once, got %s" % [script.all_actions()])
	check(SolutionScript.from_data([], 1) == null, "data that is not an object plays nothing")
	check(SolutionScript.from_data({"level": "level_01", "segments": []}, 1) == null, "a solution without segments plays nothing")
	check(SolutionScript.from_data({"level": "level_01", "segments": [{"actions": [], "ticks": 0}]}, 1) == null,
		"a segment without ticks plays nothing")


func test_a_request_names_levels_in_order() -> void:
	var order := ["level_01", "level_02", "level_03"]
	check(SolutionScript.levels_for("chapter", order) == ["level_01", "level_02", "level_03"], "chapter is every level")
	check(SolutionScript.levels_for("level_02", order) == ["level_02"], "one level by its id")
	check(SolutionScript.levels_for(" level_03.json , level_01,level_01 ", order) == ["level_03", "level_01"],
		"ids by commas, in the order given, once each")
	check(SolutionScript.levels_for("level_99,nothing", order).is_empty(), "unknown ids play nothing")
	check(SolutionScript.levels_for("", order).is_empty(), "an empty request plays nothing")


func test_every_level_has_a_solution_the_replay_reads() -> void:
	for id: Variant in _replay_loader().call("order"):
		check(SolutionScript.for_level(str(id)) != null, "the replay finds no solution for '%s'" % id)


func test_without_a_request_the_replay_is_idle() -> void:
	var replay := _replay()
	check(replay != null, "no /root/SolutionReplay node")
	check(str(ProjectSettings.get_setting("autoload/SolutionReplay", "")) == "*res://autoload/solution_replay.gd",
		"SolutionReplay must be an autoload")
	if replay == null:
		return
	check(not replay.call("is_running"), "without a request no replay runs")
	check(not replay.call("start", "level_99"), "a request for no known level must not start")
	check(not replay.call("is_running"), "a request for no known level must leave the replay idle")


## The export keeps the solution files, so the browser build can play them.
func test_the_web_export_keeps_the_solutions() -> void:
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "no export_presets.cfg")
	var include := str(presets.get_value("preset.0", "include_filter", ""))
	var exclude := str(presets.get_value("preset.0", "exclude_filter", ""))
	check(include.contains("tests/solutions/*.json"), "the Web preset must include tests/solutions/*.json, got '%s'" % include)
	for pattern in exclude.split(",", false):
		check(not "res://tests/solutions/level_01.json".matchn("res://" + pattern.strip_edges())
				and not "tests/solutions/level_01.json".matchn(pattern.strip_edges()),
			"the exclude filter '%s' drops the solutions" % pattern)


func test_the_replay_passes_the_whole_chapter() -> void:
	var replay := _replay()
	var loader := _replay_loader()
	if replay == null or loader == null:
		failures.append("no SolutionReplay or LevelLoader")
		return
	var saved_path := str(loader.get("save_path"))
	var order: Array = loader.call("order")
	check(replay.call("start", "chapter"), "the chapter must start")
	check(loader.get("save_path") == "", "a replay must not touch the progress save")
	for i in CHAPTER_TICK_LIMIT:
		if not replay.call("is_running"):
			break
		await _tree.physics_frame
	check(not replay.call("is_running"), "the chapter did not end in %d ticks" % CHAPTER_TICK_LIMIT)
	var results: Array = replay.get("results")
	check(results.size() == order.size(), "every level must be played, got %s" % [results])
	for result: Variant in results:
		check(bool(result["reached"]), "the replay of %s does not reach the exit (%d ticks)" % [result["level"], result["tick"]])
	replay.call("stop")
	# Back to a known place for the next suites.
	for i in 600:
		if not loader.call("is_passing"):
			break
		await _tree.process_frame
	(loader.get("progress") as LevelProgress).clear()
	loader.set("save_path", saved_path)
	loader.call("go_to_list")
	for i in 3:
		await _tree.physics_frame
	await _tree.process_frame


func _replay() -> Node:
	return _tree.root.get_node_or_null("SolutionReplay")


func _replay_loader() -> Node:
	return _tree.root.get_node_or_null("LevelLoader")
