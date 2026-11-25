extends Control
## The screen after the last level (task 4.3): «Thanks for playing», who made
## the game and a button back to the main menu. Texts: `final` of
## `data/menu.json`.

var _box: VBoxContainer


func _ready() -> void:
	MenuStyle.add_background(self)
	_box = MenuStyle.add_column(self)
	var final: Dictionary = Content.menu().get("final", {})
	var heading := MenuStyle.make_label(str(final.get("heading", "Thanks for playing")), MenuStyle.TITLE_FONT * 3 / 4, MenuStyle.accent())
	heading.name = "Heading"
	_box.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	_box.add_child(gap)
	for line: Variant in final.get("lines", []):
		_box.add_child(MenuStyle.make_label(str(line), MenuStyle.TEXT_FONT))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 40)
	_box.add_child(gap2)
	var back := MenuStyle.make_button("MainMenu", MenuStyle.button_text("main_menu", "Main menu"))
	back.pressed.connect(_on_back)
	_box.add_child(back)
	back.grab_focus()


func _on_back() -> void:
	var loader := get_node_or_null("/root/LevelLoader")
	if loader != null:
		loader.go_to_menu()
