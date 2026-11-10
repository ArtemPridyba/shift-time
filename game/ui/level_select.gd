extends Control
## The level list: one button per entry of `data/levels.json`. Mouse, arrow
## keys and Enter all work. Starting a level goes through the LevelLoader
## autoload. This is the main scene; the full menu comes in week 4.

const BUTTON_MIN_SIZE := Vector2(840, 80)
const BUTTON_FONT_SIZE := 36

@onready var _list: VBoxContainer = $Center/Box/List


func _ready() -> void:
	build_list()


## Fills the list from `levels.json` and puts the focus on the first button.
func build_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for entry: Variant in Content.levels():
		if not entry is Dictionary or not entry.has("id"):
			continue
		var id := str(entry["id"])
		var button := Button.new()
		button.name = id
		button.text = str(entry.get("title", id))
		button.custom_minimum_size = BUTTON_MIN_SIZE
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.set_meta("level_id", id)
		button.pressed.connect(_on_level_pressed.bind(id))
		_list.add_child(button)
	if _list.get_child_count() > 0:
		(_list.get_child(0) as Button).grab_focus()


func _on_level_pressed(id: String) -> void:
	var loader := get_node_or_null("/root/LevelLoader")
	if loader != null:
		loader.load_level(id)
