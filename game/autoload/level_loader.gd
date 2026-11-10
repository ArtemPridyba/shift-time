extends Node
## Autoload. Starts a level by its id from `data/levels.json` and returns to
## the level list. The `back_to_list` action (Backspace) leaves a level; Esc
## stays free because the browser uses it to leave full screen.

signal level_started(id: String)
signal list_opened

const LIST_SCENE := "res://ui/level_select.tscn"
const BACK_ACTION := "back_to_list"

## Id of the running level; empty while the list is open.
var current_id := ""


## The `levels.json` entry with this id, or an empty dictionary.
func find_entry(id: String) -> Dictionary:
	for entry: Variant in Content.levels():
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry
	return {}


## Starts the level. An unknown id or a missing scene changes nothing and
## returns false.
func load_level(id: String) -> bool:
	var entry := find_entry(id)
	if entry.is_empty():
		return false
	if not _change_scene(str(entry.get("scene", ""))):
		return false
	current_id = id
	level_started.emit(id)
	return true


## Back to the level list.
func go_to_list() -> bool:
	if not _change_scene(LIST_SCENE):
		return false
	current_id = ""
	list_opened.emit()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if current_id.is_empty() or not event.is_action_pressed(BACK_ACTION):
		return
	get_viewport().set_input_as_handled()
	go_to_list()


func _change_scene(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	if get_tree().change_scene_to_file(path) != OK:
		return false
	# A new scene starts in forward time, even when Shift is still held.
	var manager := get_node_or_null("/root/TimeManager")
	if manager != null:
		manager.reset()
	return true
