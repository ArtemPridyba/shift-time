class_name PauseMenu
extends CanvasLayer
## The pause over a running level (task 4.3): Esc or a lost focus stops the
## tree and shows Continue, Restart level, Levels, Main menu. LevelLoader owns
## it and opens or closes it; the buttons call LevelLoader back.

signal resume_pressed
signal restart_pressed
signal levels_pressed
signal menu_pressed

const LAYER := 90

var _root: Control
var _box: VBoxContainer


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
	_box = MenuStyle.add_column(_root)
	_box.add_child(MenuStyle.make_label(str(Content.menu().get("pause_title", "Paused")), MenuStyle.TITLE_FONT / 2))
	_add("Resume", "resume", "Continue", resume_pressed)
	_add("Restart", "restart", "Restart level", restart_pressed)
	_add("Levels", "levels", "Levels", levels_pressed)
	_add("MainMenu", "main_menu", "Main menu", menu_pressed)


func open() -> void:
	visible = true
	MenuStyle.focus_first(_box)


func close() -> void:
	visible = false


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
