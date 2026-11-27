extends Control
## The main menu, the first screen of the game (task 4.3): the title over the
## dark shop, «Start» (or «Continue» once a level is passed), «Levels» and
## «Quit» (not in the browser, where a page cannot close itself), and the
## line of keys at the bottom. Texts: `data/menu.json`, `data/controls.json`.

const KEY_LINE_FONT := 26
const KEY_LINE_MARGIN := 48

var _box: VBoxContainer


func _ready() -> void:
	MenuStyle.add_background(self)
	_box = MenuStyle.add_column(self)
	var title := MenuStyle.make_label(str(Content.menu().get("title", "SHIFT TIME")), MenuStyle.TITLE_FONT, MenuStyle.accent())
	title.name = "Title"
	_box.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	_box.add_child(gap)
	var loader := _loader()
	var started := loader != null and not (loader.progress as LevelProgress).passed.is_empty()
	_add("Start", MenuStyle.button_text("continue", "Continue") if started else MenuStyle.button_text("start", "Start"), _on_start)
	_add("Levels", MenuStyle.button_text("levels", "Levels"), _on_levels)
	var quit := _add("Quit", MenuStyle.button_text("quit", "Quit"), _on_quit)
	quit.visible = not OS.has_feature("web")
	_add_key_line()
	MenuStyle.focus_first(_box)


## The line of keys at the bottom (`menu_line` of `data/controls.json`): the
## page on itch says nothing before the game starts.
func _add_key_line() -> void:
	var data := ControlsData.load_data()
	var text := KeyNames.format(str(data.get("menu_line", "")), data.get("key_names", {}) as Dictionary)
	var line := MenuStyle.make_label(text, KEY_LINE_FONT, MenuStyle.TEXT_DIM)
	line.name = "Keys"
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -KEY_LINE_MARGIN - KEY_LINE_FONT * 1.5
	line.offset_bottom = -KEY_LINE_MARGIN
	add_child(line)


func _add(button_name: String, text: String, action: Callable) -> Button:
	var button := MenuStyle.make_button(button_name, text)
	button.pressed.connect(action)
	_box.add_child(button)
	return button


func _on_start() -> void:
	var loader := _loader()
	if loader != null:
		loader.start_level(loader.start_id())


func _on_levels() -> void:
	var loader := _loader()
	if loader != null:
		loader.go_to_list()


func _on_quit() -> void:
	get_tree().quit()


func _loader() -> Node:
	return get_node_or_null("/root/LevelLoader")
