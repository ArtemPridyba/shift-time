extends RefCounted
## Tests of the level list and `LevelLoader` (tasks 2.10, 4.2, 4.3): every
## entry of `levels.json` loads and runs, a level starts by its id, an unknown
## id changes nothing, no key leaves a level at once, Esc pauses, a passed level
## fades into the next one and the last into the final screen, and levels open
## in order when `unlock_in_order` is on. Run by test_runner.gd.

const LIST_PATH := "res://ui/level_select.tscn"
const MENU_PATH := "res://ui/main_menu.tscn"
const FINAL_PATH := "res://ui/final_screen.tscn"
const TICKS := 5
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


func test_loader_is_an_autoload_and_main_scene_is_the_list() -> void:
	var registered := str(ProjectSettings.get_setting("autoload/LevelLoader", ""))
	check(registered == "*res://autoload/level_loader.gd", "LevelLoader must be an autoload of level_loader.gd, got '%s'" % registered)
	check(_loader() != null, "no /root/LevelLoader node")
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == MENU_PATH, "the main scene must be the main menu")


func test_no_key_leaves_a_level_and_esc_pauses() -> void:
	check(not InputMap.has_action("back_to_list"), "no key may leave a level at once (Boris 25.11): drop 'back_to_list'")
	var keys: Array = []
	for event in InputMap.action_get_events("pause"):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	check(keys == [KEY_ESCAPE], "pause must be Esc, got %s" % [keys])


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


func test_esc_pauses_the_level_and_resumes_it() -> void:
	var loader := _loader()
	if loader == null:
		failures.append("no /root/LevelLoader node")
		return
	await _reset(loader)
	var first := str((Content.levels()[0] as Dictionary)["id"])
	check(loader.load_level(first), "the first level must load")
	await _frames(10)
	var room_time := _tree.current_scene.get_node_or_null("RoomTime") as RoomTime
	_press("pause")
	await _frames(3)
	check(_tree.paused, "Esc in a level must pause the tree")
	check(loader.is_paused(), "Esc must show the pause menu")
	check(loader.current_id == first, "the pause must keep the level")
	check(room_time != null, "the level has RoomTime")
	var tick := room_time.world_tick() if room_time != null else -1
	await _frames(10)
	if room_time != null:
		check(room_time.world_tick() == tick, "the world must stand still in the pause")
	var buttons: Array[Button] = (loader.pause_menu() as PauseMenu).buttons()
	check(buttons.size() == 4, "the pause has Continue, Restart, Levels, Main menu")
	Input.action_press("rewind")
	_press("pause")
	await _frames(3)
	check(not _tree.paused and not loader.is_paused(), "Esc again must resume")
	var manager := _tree.root.get_node_or_null("TimeManager")
	check(manager != null and not manager.is_rewinding(), "a Shift held through the pause must not rewind until pressed again")
	Input.action_release("rewind")
	_press("pause")
	await _frames(3)
	buttons[1].pressed.emit()
	await _frames(3)
	check(not _tree.paused, "Restart must resume")
	check(_scene_path() == str((Content.levels()[0] as Dictionary)["scene"]), "Restart must keep the level")
	await _reset(loader)


func test_a_passed_level_fades_into_the_next_and_the_last_into_the_end() -> void:
	var loader := _loader()
	if loader == null:
		failures.append("no /root/LevelLoader node")
		return
	await _reset(loader)
	var ids: Array = loader.order()
	check(ids.size() >= 2, "the order needs two levels")
	check(loader.load_level(str(ids[0])), "the first level must load")
	await _frames(3)
	check(loader.finish_level(), "finish_level must start the passage")
	check(not loader.finish_level(), "a second finish during the passage changes nothing")
	await _frames(5)
	check(_tree.paused, "the old level stands still while the screen goes black")
	check(loader.progress.is_passed(str(ids[0])), "a passed level is remembered")
	await _passage(loader)
	check(loader.current_id == str(ids[1]), "after level 1 comes level 2, got '%s'" % loader.current_id)
	check(_scene_path() == str((Content.levels()[1] as Dictionary)["scene"]), "the next level's scene must open")
	check(not _tree.paused, "the next level runs")
	check(loader.start_id() == str(ids[1]), "Continue goes to the first level not passed")
	var last := str(ids[ids.size() - 1])
	check(loader.load_level(last), "the last level must load")
	await _frames(3)
	loader.finish_level()
	await _passage(loader)
	check(_scene_path() == FINAL_PATH, "after the last level comes the final screen, got '%s'" % _scene_path())
	check(loader.current_id == "", "no level runs on the final screen")
	var text := _texts(_tree.current_scene)
	check(text.contains("Artemiy Pridyba") and text.contains("Borys Shapovalov"), "the final screen names who made the game")
	await _reset(loader)


func test_levels_open_in_order_only_when_asked() -> void:
	var progress := LevelProgress.new()
	var ids := ["a", "b", "c"]
	for id in ids:
		check(progress.is_open(id, ids, false), "without the order every level is open: '%s'" % id)
	check(progress.is_open("a", ids, true), "the first level is always open")
	check(not progress.is_open("b", ids, true), "the second is closed before the first is passed")
	progress.mark_passed("a")
	check(progress.is_open("b", ids, true), "passing a level opens the next")
	check(not progress.is_open("c", ids, true), "but not the one after")
	check(not progress.is_open("x", ids, false), "an unknown level is never open")
	check(progress.first_unpassed(ids) == "b", "Continue goes to the first level not passed")
	check(LevelProgress.next_after("c", ids) == "", "nothing follows the last level")
	var copy := LevelProgress.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	check(copy.is_passed("a") and not copy.is_passed("b"), "the progress survives saving")
	progress.mark_passed("b")
	progress.mark_passed("c")
	check(progress.first_unpassed(ids) == "a", "with every level passed Start goes to the first")


func test_menu_opens_levels_with_a_fade() -> void:
	var loader := _loader()
	if loader == null:
		failures.append("no /root/LevelLoader node")
		return
	await _reset(loader)
	check(loader.go_to_menu(), "go_to_menu() must succeed")
	await _frames(3)
	check(_scene_path() == MENU_PATH, "the main menu must open")
	var start := _tree.current_scene.get_node_or_null("Center/Box/Start") as Button
	check(start != null and start.has_focus(), "Start must be there with the focus")
	if start == null:
		return
	start.pressed.emit()
	await _frames(5)
	check(loader.screen_fade().darkness() > 0.0, "Start fades the screen out")
	await _passage(loader)
	check(loader.current_id == loader.start_id(), "Start opens the first level not passed")
	check(not loader.start_level("no_such_level"), "an unknown level never starts")
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


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


## Waits until the fade between scenes is over.
func _passage(loader: Node) -> void:
	for i in 600:
		if not loader.is_passing():
			break
		await _tree.process_frame
	await _frames(3)


## Every text of the labels under `node`.
func _texts(node: Node) -> String:
	var text := ""
	for label in node.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text


func _frames(count: int) -> void:
	for i in count:
		await _tree.physics_frame
	await _tree.process_frame


## Puts the tests in a known place: all actions released, nothing saved or
## passed, no pause, the list open.
func _reset(loader: Node) -> void:
	for action in ACTIONS:
		Input.action_release(action)
	loader.save_path = ""
	(loader.progress as LevelProgress).clear()
	loader.resume()
	if _scene_path() != LIST_PATH:
		loader.go_to_list()
	await _frames(3)
