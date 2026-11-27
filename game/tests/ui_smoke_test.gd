extends SceneTree
## UI smoke test: the game starts from its main scene, the main menu, with
## Start and Levels; the level list builds one button per entry of levels.json; the first level then runs for a
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
		_check_main_menu(main)
		main.queue_free()
		await process_frame
	var list: Node = (load("res://ui/level_select.tscn") as PackedScene).instantiate()
	root.add_child(list)
	for i in 5:
		await process_frame
	_check_level_list(list)
	list.queue_free()
	await process_frame
	var final: Node = (load("res://ui/final_screen.tscn") as PackedScene).instantiate()
	root.add_child(final)
	for i in 5:
		await process_frame
	var back := final.get_node_or_null("Center/Box/MainMenu") as Button
	_check(back != null and back.has_focus(), "the final screen must have a focused Main menu button")
	final.queue_free()
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
		await _check_time_indicator(level)
		level.queue_free()
		await process_frame

	for message in _errors.messages:
		_failed += 1
		print("FAIL SCRIPT ERROR ", message)
	print("UI smoke test: %d failed" % _failed)
	_silence()
	quit(1 if _failed > 0 else 0)


## The main menu: the title, Start with the focus, Levels.
func _check_main_menu(main: Node) -> void:
	_check(main.get_node_or_null("Center/Box/Title") is Label, "no title on the main menu")
	var start := main.get_node_or_null("Center/Box/Start") as Button
	_check(start != null, "no Start button on the main menu")
	if start != null:
		_check(start.has_focus(), "Start must have the focus at the start")
	_check(main.get_node_or_null("Center/Box/Levels") is Button, "no Levels button on the main menu")


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


## The wrist device switches with Shift, and the arrows differ as well as the
## colors (the direction never reads from color alone).
func _check_time_indicator(main: Node) -> void:
	var hud := main.get_node_or_null("Player/TimeHud") as TimeHud
	_check(hud != null, "no time indicator (TimeHud) on the player in the first level")
	if hud == null:
		return
	_check(main.get_node_or_null("TimeDebugLabel") == null, "the temporary time label must be gone")
	_check(hud.state.glyph() == ">>", "the device must show forward arrows at the start, got '%s'" % hud.state.glyph())
	Input.action_press("rewind")
	for i in 3:
		await physics_frame
	_check(hud.state.glyph() == "<<", "the device must show rewind arrows while Shift is held, got '%s'" % hud.state.glyph())
	_check(hud.state.is_rewinding(), "the indicator must switch to rewind with Shift")
	for i in 30:
		await process_frame
	_check(hud.state.rewind_amount > 0.0, "the rewind light must come in under Shift")
	Input.action_release("rewind")
	for i in 3:
		await physics_frame
	_check(hud.state.glyph() == ">>", "the device must return to forward arrows after the release, got '%s'" % hud.state.glyph())


## Stops every sound and lets the audio thread drop them before quitting, so no
## playback is left in use at exit (the sound, D183).
func _silence() -> void:
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		for node in root.find_children("*", kind, true, false):
			node.call("stop")
	OS.delay_msec(150)
