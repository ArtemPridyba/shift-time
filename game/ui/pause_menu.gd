class_name PauseMenu
extends CanvasLayer
## The pause over a running level (task 4.3): Esc or a lost focus stops the
## tree and shows Continue, Restart level, Levels, Main menu. LevelLoader owns
## it and opens or closes it; the buttons call LevelLoader back. Beside the
## buttons: the Master volume slider (LevelLoader saves it) and the list of
## all keys, read from the actions of project.godot (`data/controls.json`).

signal resume_pressed
signal restart_pressed
signal levels_pressed
signal menu_pressed
signal volume_changed(value: float)

const LAYER := 90

const COLUMNS_GAP := 96
const ROW_FONT := 26
const SLIDER_SIZE := Vector2(360, 40)

var _root: Control
var _box: VBoxContainer
var _slider: HSlider
var _grid: GridContainer


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", COLUMNS_GAP)
	center.add_child(columns)
	_box = VBoxContainer.new()
	_box.name = "Box"
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", MenuStyle.COLUMN_GAP)
	columns.add_child(_box)
	var data := ControlsData.load_data()
	_box.add_child(MenuStyle.make_label(str(Content.menu().get("pause_title", "Paused")), MenuStyle.TITLE_FONT / 2))
	_add("Resume", "resume", "Continue", resume_pressed)
	_add("Restart", "restart", "Restart level", restart_pressed)
	_add("Levels", "levels", "Levels", levels_pressed)
	_add("MainMenu", "main_menu", "Main menu", menu_pressed)
	_add_volume(str(data.get("volume", "Volume")))
	columns.add_child(_make_controls(data))


func open() -> void:
	visible = true
	MenuStyle.focus_first(_box)


func close() -> void:
	visible = false


## Shows the saved volume without telling LevelLoader back.
func set_volume(value: float) -> void:
	_slider.set_value_no_signal(value)


## The Master volume slider, for tests.
func volume_slider() -> HSlider:
	return _slider


## The rows of the controls list as [keys, text], for tests.
func control_rows() -> Array:
	var rows: Array = []
	var cells := _grid.get_children()
	for i in range(0, cells.size() - 1, 2):
		rows.append([(cells[i] as Label).text, (cells[i + 1] as Label).text])
	return rows


## The buttons in order, for tests.
func buttons() -> Array[Button]:
	var list: Array[Button] = []
	for child in _box.get_children():
		if child is Button:
			list.append(child as Button)
	return list


func _add(button_name: String, key: String, fallback: String, pressed_signal: Signal) -> void:
	var button := MenuStyle.make_button(button_name, MenuStyle.button_text(key, fallback))
	button.pressed.connect(func() -> void: pressed_signal.emit())
	_box.add_child(button)


func _add_volume(title: String) -> void:
	var row := HBoxContainer.new()
	row.name = "VolumeRow"
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := MenuStyle.make_label(title, ROW_FONT)
	row.add_child(label)
	_slider = HSlider.new()
	_slider.name = "Volume"
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.05
	_slider.custom_minimum_size = SLIDER_SIZE
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_ALL
	_slider.value_changed.connect(func(value: float) -> void: volume_changed.emit(value))
	row.add_child(_slider)
	_box.add_child(row)


## «Controls»: a key column in the hint colour and a text column, one row
## per entry of `controls` in `data/controls.json`.
func _make_controls(data: Dictionary) -> Control:
	var panel := VBoxContainer.new()
	panel.name = "ControlsPanel"
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", MenuStyle.COLUMN_GAP)
	panel.add_child(MenuStyle.make_label(str(data.get("controls_title", "Controls")), MenuStyle.TEXT_FONT))
	_grid = GridContainer.new()
	_grid.name = "Controls"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 32)
	_grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(_grid)
	var names := data.get("key_names", {}) as Dictionary
	var hint := data.get("hint", {}) as Dictionary
	var key_color := Color.from_string(str(hint.get("color", "#e0b02a")), Color("#e0b02a"))
	for row: Variant in data.get("controls", []):
		var keys := PackedStringArray()
		var most := int((row as Dictionary).get("max_keys", 0))
		for action: Variant in (row as Dictionary).get("actions", []):
			var action_keys := KeyNames.keys(str(action), names)
			keys.append_array(action_keys.slice(0, most) if most > 0 else action_keys)
		var key_label := MenuStyle.make_label(" / ".join(keys), ROW_FONT, key_color)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_grid.add_child(key_label)
		var text := MenuStyle.make_label(str((row as Dictionary).get("text", "")), ROW_FONT)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_grid.add_child(text)
	return panel
