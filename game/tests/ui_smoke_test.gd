extends SceneTree
## UI smoke test: the game starts from its main scene, the level list, which
## builds one button per entry of levels.json; the first level then runs for a
## moment and shows a camera on the player without script errors.
##
##   godot --headless --path game --script res://tests/ui_smoke_test.gd

var _errors := ScriptErrors.new()
var _failed := 0


func _initialize() -> void:
	OS.add_logger(_errors)
	_run()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed += 1
		print("FAIL ", message)


func _run() -> void:
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene"))
	_check(ResourceLoader.exists(main_path), "main scene '%s' does not exist" % main_path)
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920, "viewport width must be 1920")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080, "viewport height must be 1080")
	_check(str(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items", "stretch mode must be canvas_items")

	if ResourceLoader.exists(main_path):
		var main: Node = (load(main_path) as PackedScene).instantiate()
		root.add_child(main)
		for i in 5:
			await process_frame
		_check_level_list(main)
		main.queue_free()
		await process_frame

	var levels := Content.levels()
	_check(not levels.is_empty(), "levels.json lists no levels")
	if not levels.is_empty():
		var level_path := str((levels[0] as Dictionary)["scene"])
		var level: Node = (load(level_path) as PackedScene).instantiate()
		root.add_child(level)
		for i in 20:
			await process_frame
		for i in 10:
			await physics_frame
		var camera := root.get_viewport().get_camera_2d()
		_check(camera != null, "no active Camera2D in the first level")
		var player := level.get_node_or_null("Player") as Player
		_check(player != null, "no Player in the first level")
		if camera != null and player != null:
			_check(camera.get_parent() == player, "the camera must follow the player")
		await _check_time_label(level)
		level.queue_free()
		await process_frame

	for message in _errors.messages:
		_failed += 1
		print("FAIL SCRIPT ERROR ", message)
	print("UI smoke test: %d failed" % _failed)
	quit(1 if _failed > 0 else 0)


## The list shows one focusable button per level, titled from levels.json.
func _check_level_list(main: Node) -> void:
	var list := main.get_node_or_null("Center/Box/List")
	_check(list != null, "no level list in the main scene")
	if list == null:
		return
	var levels := Content.levels()
	_check(list.get_child_count() == levels.size(), "the list has %d buttons, levels.json has %d levels" % [list.get_child_count(), levels.size()])
	for i in mini(list.get_child_count(), levels.size()):
		var button := list.get_child(i) as Button
		_check(button != null, "list item %d must be a Button" % i)
		if button == null:
			continue
		_check(button.text == str((levels[i] as Dictionary)["title"]), "button %d must show the title '%s', got '%s'" % [i, (levels[i] as Dictionary)["title"], button.text])
		_check(str(button.get_meta("level_id", "")) == str((levels[i] as Dictionary)["id"]), "button %d must carry the level id" % i)
		_check(button.focus_mode != Control.FOCUS_NONE, "button %d must be focusable for the keyboard" % i)
	if list.get_child_count() > 0:
		_check((list.get_child(0) as Control).has_focus(), "the first button must have the focus at the start")


## The temporary direction label switches with Shift, and the arrows differ as
## well as the words (the direction never reads from color alone).
func _check_time_label(main: Node) -> void:
	var layer := main.get_node_or_null("TimeDebugLabel")
	_check(layer != null and layer.get_child_count() > 0, "no time-direction label in the main scene")
	if layer == null or layer.get_child_count() == 0:
		return
	var label := layer.get_child(0) as Label
	_check(label != null, "the time-direction label must be a Label")
	if label == null:
		return
	_check(">>" in label.text and "FORWARD" in label.text, "the label must show forward time at the start, got '%s'" % label.text)
	Input.action_press("rewind")
	for i in 3:
		await physics_frame
	_check("<<" in label.text and "REWIND" in label.text, "the label must show rewind while Shift is held, got '%s'" % label.text)
	_check(not (">>" in label.text), "the rewind label must not keep the forward arrows")
	Input.action_release("rewind")
	for i in 3:
		await physics_frame
	_check(">>" in label.text and "FORWARD" in label.text, "the label must return to forward time after the release, got '%s'" % label.text)
