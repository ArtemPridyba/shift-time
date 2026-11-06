extends SceneTree
## UI smoke test: the game starts from its main scene, runs for a moment and
## shows a camera on the player without script errors.
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
		for i in 20:
			await process_frame
		for i in 10:
			await physics_frame
		var camera := root.get_viewport().get_camera_2d()
		_check(camera != null, "no active Camera2D in the main scene")
		var player := main.get_node_or_null("Player") as Player
		_check(player != null, "no Player in the main scene")
		if camera != null and player != null:
			_check(camera.get_parent() == player, "the camera must follow the player")
		await _check_time_label(main)
		main.queue_free()
		await process_frame

	for message in _errors.messages:
		_failed += 1
		print("FAIL SCRIPT ERROR ", message)
	print("UI smoke test: %d failed" % _failed)
	quit(1 if _failed > 0 else 0)


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
