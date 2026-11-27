extends Node
## Autoload. Moves between the main menu, the level list, the levels and the
## final screen (tasks 2.10, 4.2, 4.3). A passed level fades into the next one
## in the order of `data/levels.json` with its title on black; after the last
## one comes the final screen. Remembers the passed levels in `user://` (works
## in the browser too) and, with `unlock_in_order` of `data/menu.json`, opens
## only those and the one after. Esc (`pause`) pauses a running level; a lost
## focus does too. There is no key that leaves a level at once (Boris 25.11:
## a slip of the finger must not throw the run away), only the pause menu.

signal level_started(id: String)
signal list_opened
signal menu_opened
signal final_opened
signal level_finished(id: String)
## Sent just before the pause menu opens and grabs the focus (D207).
signal pause_opening

const MENU_SCENE := "res://ui/main_menu.tscn"
const LIST_SCENE := "res://ui/level_select.tscn"
const FINAL_SCENE := "res://ui/final_screen.tscn"
const PAUSE_ACTION := "pause"
const SAVE_PATH := "user://progress.json"
const SETTINGS_PATH := "user://settings.json"

## Id of the running level; empty on the menus.
var current_id := ""
## The passed levels.
var progress := LevelProgress.new()
## Where the progress is saved; tests set "" to keep the disk untouched.
var save_path := SAVE_PATH
## The player's settings (the Master volume) and where they are saved; tests
## set "" to keep the disk untouched.
var settings := GameSettings.new()
var settings_path := SETTINGS_PATH

var _fade: ScreenFade
var _pause: PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ScreenFade.new()
	_fade.name = "ScreenFade"
	add_child(_fade)
	_pause = PauseMenu.new()
	_pause.name = "PauseMenu"
	add_child(_pause)
	_pause.resume_pressed.connect(resume)
	_pause.restart_pressed.connect(restart_level)
	_pause.levels_pressed.connect(func() -> void: _pass_to(LIST_SCENE))
	_pause.menu_pressed.connect(func() -> void: _pass_to(MENU_SCENE))
	_pause.volume_changed.connect(set_volume)
	load_progress()
	load_settings()


## The `levels.json` entry with this id, or an empty dictionary.
func find_entry(id: String) -> Dictionary:
	for entry: Variant in Content.levels():
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry
	return {}


## Level ids in the order of play.
func order() -> Array:
	var ids: Array = []
	for entry: Variant in Content.levels():
		if entry is Dictionary and entry.has("id"):
			ids.append(str(entry["id"]))
	return ids


## True when the menu may start this level (`unlock_in_order`).
func is_open(id: String) -> bool:
	return progress.is_open(id, order(), bool(Content.menu().get("unlock_in_order", false)))


## The level «Start» / «Continue» opens.
func start_id() -> String:
	return progress.first_unpassed(order())


func is_paused() -> bool:
	return _pause.visible


func is_passing() -> bool:
	return _fade.is_running()


## The pause menu, for tests.
func pause_menu() -> PauseMenu:
	return _pause


## The fade, for tests.
func screen_fade() -> ScreenFade:
	return _fade


## Opens the level at once. An unknown id or a missing scene changes nothing
## and returns false.
func load_level(id: String) -> bool:
	var entry := find_entry(id)
	if entry.is_empty():
		return false
	if not _change_scene(str(entry.get("scene", ""))):
		return false
	current_id = id
	level_started.emit(id)
	return true


## Fades into the level with its title on black. False for an unknown or a
## closed level.
func start_level(id: String) -> bool:
	var entry := find_entry(id)
	if entry.is_empty() or not is_open(id) or not ResourceLoader.exists(str(entry.get("scene", ""))):
		return false
	_play(str(entry.get("title", id)), func() -> void: load_level(id))
	return true


## Back to the level list at once.
func go_to_list() -> bool:
	if not _change_scene(LIST_SCENE):
		return false
	list_opened.emit()
	return true


## Back to the main menu at once.
func go_to_menu() -> bool:
	if not _change_scene(MENU_SCENE):
		return false
	menu_opened.emit()
	return true


## The screen after the last level, at once.
func go_to_final() -> bool:
	if not _change_scene(FINAL_SCENE):
		return false
	final_opened.emit()
	return true


## The running level is passed: it is remembered, and the next level (or the
## final screen after the last one) fades in.
func finish_level() -> bool:
	if current_id.is_empty() or is_passing():
		return false
	var id := current_id
	progress.mark_passed(id)
	save_progress()
	level_finished.emit(id)
	var next := LevelProgress.next_after(id, order())
	if next.is_empty():
		_play("", func() -> void: go_to_final())
	else:
		_play(str(find_entry(next).get("title", next)), func() -> void: load_level(next))
	return true


func pause() -> void:
	if current_id.is_empty() or is_passing() or is_paused():
		return
	get_tree().paused = true
	pause_opening.emit()
	_pause.open()


## Out of the pause time runs forward, and a Shift still held rewinds only
## after a new press (team decision 6.11.2026).
func resume() -> void:
	var was_paused := _pause.visible
	_pause.close()
	get_tree().paused = false
	var manager := get_node_or_null("/root/TimeManager")
	if was_paused and manager != null:
		manager.reset()


## The pause menu's «Restart level»: the room starts again as after R.
func restart_level() -> void:
	resume()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("restart"):
		scene.call("restart")


func load_progress() -> void:
	progress.clear()
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file != null:
		progress.from_dict(JSON.parse_string(file.get_as_text()))


func save_progress() -> void:
	if save_path.is_empty():
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(progress.to_dict()))


func _unhandled_input(event: InputEvent) -> void:
	if current_id.is_empty() or not event.is_action_pressed(PAUSE_ACTION):
		return
	get_viewport().set_input_as_handled()
	if is_paused():
		resume()
	else:
		pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and bool(Content.menu().get("pause_on_focus_loss", true)):
		pause()


func _pass_to(path: String) -> void:
	_play("", func() -> void:
		if _change_scene(path):
			(menu_opened if path == MENU_SCENE else list_opened).emit())


## A passage: the tree stops while the screen goes black, `middle` opens the
## next scene, and it runs again as the screen clears.
func _play(title: String, middle: Callable) -> void:
	_pause.close()
	get_tree().paused = true
	var data := Content.menu()
	var card := float(data.get("title_card_seconds", 1.5)) if not title.is_empty() else 0.0
	_fade.play(title, float(data.get("fade_seconds", 0.6)), card, middle)


func _change_scene(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	if get_tree().change_scene_to_file(path) != OK:
		return false
	if path in [MENU_SCENE, LIST_SCENE, FINAL_SCENE]:
		current_id = ""
	_pause.close()
	get_tree().paused = false
	if not is_passing():
		_fade.clear()
	# A new scene starts in forward time, even when Shift is still held.
	var manager := get_node_or_null("/root/TimeManager")
	if manager != null:
		manager.reset()
	return true


## The Master volume (0..1): to the bus at once, to the slider and to disk.
func set_volume(value: float) -> void:
	settings.set_volume(value)
	_apply_volume()
	save_settings()


func load_settings() -> void:
	var data: Variant = null
	if not settings_path.is_empty() and FileAccess.file_exists(settings_path):
		var file := FileAccess.open(settings_path, FileAccess.READ)
		if file != null:
			data = JSON.parse_string(file.get_as_text())
	settings.from_dict(data, float(ControlsData.load_data().get("default_volume", 0.8)))
	_apply_volume()


func save_settings() -> void:
	if settings_path.is_empty():
		return
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(settings.to_dict()))


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, GameSettings.volume_db(settings.volume))
	AudioServer.set_bus_mute(bus, settings.volume <= 0.001)
	_pause.set_volume(settings.volume)
