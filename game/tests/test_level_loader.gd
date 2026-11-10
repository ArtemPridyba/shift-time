extends RefCounted
## Tests of the level list and `LevelLoader` (task 2.10): every entry of
## `levels.json` loads and runs, a level starts by its id, an unknown id changes
## nothing, and `back_to_list` (Backspace) returns to the list. Run by
## test_runner.gd.

const LIST_PATH := "res://ui/level_select.tscn"
const TICKS := 5
const ACTIONS: Array[String] = [
	"move_left", "move_right", "jump", "interact", "rewind", "reset_level", "pause", "back_to_list",
]

var failures: Array[String] = []
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_loader_is_an_autoload_and_main_scene_is_the_list() -> void:
	var registered := str(ProjectSettings.get_setting("autoload/LevelLoader", ""))
	check(registered == "*res://autoload/level_loader.gd", "LevelLoader must be an autoload of level_loader.gd, got '%s'" % registered)
	check(_loader() != null, "no /root/LevelLoader node")
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == LIST_PATH, "the main scene must be the level list")


func test_back_action_is_backspace() -> void:
	check(InputMap.has_action("back_to_list"), "missing action 'back_to_list'")
	if not InputMap.has_action("back_to_list"):
		return
	var keys: Array = []
	for event in InputMap.action_get_events("back_to_list"):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	check(keys == [KEY_BACKSPACE], "back_to_list must be Backspace only (Esc is taken by full screen in the browser), got %s" % [keys])


func test_every_level_entry_loads_and_runs_five_ticks() -> void:
	var levels := Content.levels()
	check(not levels.is_empty(), "levels.json lists no levels")
	for entry: Variant in levels:
		var path := str((entry as Dictionary).get("scene", ""))
		var packed := load(path) as PackedScene
		check(packed != null, "scene '%s' of level '%s' does not load" % [path, (entry as Dictionary).get("id", "?")])
		if packed == null:
			continue
		var level := packed.instantiate()
		_tree.root.add_child(level)
		for i in TICKS:
			await _tree.physics_frame
		level.queue_free()
		await _tree.process_frame


func test_load_level_by_id_and_back_to_the_list() -> void:
	var loader := _loader()
	check(loader != null, "no /root/LevelLoader node")
	if loader == null:
		return
	await _reset(loader)
	check(loader.current_id == "", "no level must be running at the start")

	for entry: Variant in Content.levels():
		var id := str((entry as Dictionary)["id"])
		check(loader.load_level(id), "load_level('%s') must succeed" % id)
		await _frames(3)
		check(loader.current_id == id, "current_id must be '%s', got '%s'" % [id, loader.current_id])
		check(_scene_path() == str((entry as Dictionary)["scene"]), "'%s' did not open its scene, got '%s'" % [id, _scene_path()])
		check(loader.go_to_list(), "go_to_list() must succeed")
		await _frames(3)
		check(loader.current_id == "", "current_id must be empty on the list")
		check(_scene_path() == LIST_PATH, "go_to_list() must open the list, got '%s'" % _scene_path())
	await _reset(loader)


func test_unknown_id_changes_nothing() -> void:
	var loader := _loader()
	if loader == null:
		failures.append("no /root/LevelLoader node")
		return
	await _reset(loader)
	var first := str((Content.levels()[0] as Dictionary)["id"])
	check(loader.load_level(first), "the first level must load")
	await _frames(3)
	var before := _scene_path()
	check(not loader.load_level("no_such_level"), "an unknown id must return false")
	check(not loader.load_level(""), "an empty id must return false")
	await _frames(3)
	check(_scene_path() == before, "an unknown id must not change the scene")
	check(loader.current_id == first, "an unknown id must not change current_id")
	await _reset(loader)


func test_back_action_leaves_a_level_and_does_nothing_on_the_list() -> void:
	var loader := _loader()
	if loader == null:
		failures.append("no /root/LevelLoader node")
		return
	await _reset(loader)
	var first := str((Content.levels()[0] as Dictionary)["id"])
	check(loader.load_level(first), "the first level must load")
	await _frames(3)
	_press_back()
	await _frames(3)
	check(loader.current_id == "", "Backspace in a level must return to the list")
	check(_scene_path() == LIST_PATH, "Backspace in a level must open the list, got '%s'" % _scene_path())
	_press_back()
	await _frames(3)
	check(_scene_path() == LIST_PATH, "Backspace on the list must change nothing")
	await _reset(loader)


func test_going_back_starts_forward_time() -> void:
	var loader := _loader()
	var manager := _tree.root.get_node_or_null("TimeManager")
	if loader == null or manager == null:
		failures.append("LevelLoader and TimeManager must both be autoloads")
		return
	await _reset(loader)
	var first := str((Content.levels()[0] as Dictionary)["id"])
	loader.load_level(first)
	await _frames(3)
	Input.action_press("rewind")
	await _frames(3)
	check(manager.is_rewinding(), "Shift must rewind in the level")
	loader.go_to_list()
	check(not manager.is_rewinding(), "the list must start in forward time even with Shift held")
	Input.action_release("rewind")
	await _reset(loader)


func _loader() -> Node:
	return _tree.root.get_node_or_null("LevelLoader")


func _scene_path() -> String:
	var scene := _tree.current_scene
	return scene.scene_file_path if scene != null else ""


func _press_back() -> void:
	var event := InputEventAction.new()
	event.action = "back_to_list"
	event.pressed = true
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for i in count:
		await _tree.physics_frame
	await _tree.process_frame


## Puts the tests in a known place: all actions released, the list open.
func _reset(loader: Node) -> void:
	for action in ACTIONS:
		Input.action_release(action)
	if _scene_path() != LIST_PATH:
		loader.go_to_list()
	await _frames(3)
