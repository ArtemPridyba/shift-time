extends Control
## The level list: one button per entry of `data/levels.json`, then «Back» to
## the main menu (Esc too). Mouse, arrow keys and Enter all work. With
## `unlock_in_order` of `data/menu.json` a level not open yet is greyed out;
## a passed one is marked. Starting a level goes through the LevelLoader
## autoload, with a fade and its title.

@onready var _box: VBoxContainer = $Center/Box
@onready var _list: VBoxContainer = $Center/Box/List


func _ready() -> void:
	MenuStyle.add_background(self)
	for back_name in ["Shade", "Background"]:
		var node := get_node_or_null(back_name)
		if node != null:
			move_child(node, 0)
	($Center/Box/Title as Label).add_theme_color_override("font_color", MenuStyle.accent())
	build_list()
	var back := MenuStyle.make_button("Back", MenuStyle.button_text("back", "Back"))
	back.pressed.connect(_on_back)
	_box.add_child(back)
	_box.move_child(back, _list.get_index() + 1)
	MenuStyle.focus_first(_list)


## Fills the list from `levels.json`.
func build_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var loader := _loader()
	for entry: Variant in Content.levels():
		if not entry is Dictionary or not entry.has("id"):
			continue
		var id := str(entry["id"])
		var button := MenuStyle.make_button(id, str(entry.get("title", id)))
		button.set_meta("level_id", id)
		button.pressed.connect(_on_level_pressed.bind(id))
		if loader != null:
			button.disabled = not loader.is_open(id)
			if (loader.progress as LevelProgress).is_passed(id):
				var mark := MenuStyle.make_label(MenuStyle.button_text("passed", "passed"), MenuStyle.TEXT_FONT * 3 / 4, MenuStyle.accent())
				mark.name = "Passed"
				mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				mark.offset_right = -24
				button.add_child(mark)
		_list.add_child(button)
	MenuStyle.focus_first(_list)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _on_level_pressed(id: String) -> void:
	var loader := _loader()
	if loader != null:
		loader.start_level(id)


func _on_back() -> void:
	var loader := _loader()
	if loader != null:
		loader.go_to_menu()


func _loader() -> Node:
	return get_node_or_null("/root/LevelLoader")
