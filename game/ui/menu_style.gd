class_name MenuStyle
extends RefCounted
## The shared look of the main menu, level list, pause and final screen
## (tasks 4.2, 4.3): the dark picture of the shop behind, a centred column of
## dark buttons, the focused one outlined in signal yellow (`accent` of
## `menu.json`, D221). Numbers and texts: `data/menu.json`.

const BUTTON_SIZE := Vector2(640, 76)
const BUTTON_FONT := 36
const TITLE_FONT := 96
const TEXT_FONT := 32
const COLUMN_GAP := 18
const PANEL := Color(0.05, 0.05, 0.06, 0.82)
const PANEL_HOVER := Color(0.12, 0.11, 0.12, 0.92)
const TEXT := Color(0.93, 0.9, 0.85)
const TEXT_DIM := Color(0.6, 0.58, 0.55)


## The one accent of the menus: signal yellow like the key caps (`accent` of
## menu.json, D221); the time colour stays the heroine's own (D60).
static func accent() -> Color:
	return Color.from_string(str(Content.menu().get("accent", "#e0b02a")), Color("#e0b02a"))


## The text of a menu button from `menu.json`, or `fallback`.
static func button_text(key: String, fallback: String) -> String:
	var buttons: Variant = Content.menu().get("buttons", {})
	return str((buttons as Dictionary).get(key, fallback)) if buttons is Dictionary else fallback


## The dimmed picture of the shop filling `parent` (`background`, `dim`).
static func add_background(parent: Control) -> void:
	var data := Content.menu()
	var path := str(data.get("background", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var picture := TextureRect.new()
		picture.name = "Background"
		picture.texture = load(path) as Texture2D
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		parent.add_child(picture)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, float(data.get("dim", 0.55)))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)


## A centred column (`Center/Box`) filling `parent`.
static func add_column(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", COLUMN_GAP)
	center.add_child(box)
	return box


static func make_label(text: String, font_size: int, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## A dark button; mouse hover and keyboard focus both outline it in the accent.
static func make_button(button_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", BUTTON_FONT)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM * Color(1, 1, 1, 0.6))
	button.add_theme_stylebox_override("normal", _box(PANEL, Color(0, 0, 0, 0)))
	button.add_theme_stylebox_override("hover", _box(PANEL_HOVER, accent()))
	button.add_theme_stylebox_override("pressed", _box(PANEL_HOVER, accent()))
	button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), accent()))
	button.add_theme_stylebox_override("disabled", _box(PANEL * Color(1, 1, 1, 0.5), Color(0, 0, 0, 0)))
	# The mouse moves the keyboard focus, so only one button is ever outlined.
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			button.grab_focus())
	return button


## Gives the focus to the first enabled button among `box`'s children.
static func focus_first(box: Node) -> void:
	for child in box.get_children():
		if child is Button and not (child as Button).disabled and (child as Button).visible:
			(child as Button).grab_focus()
			return


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3 if border.a > 0.0 else 0)
	box.set_corner_radius_all(4)
	box.content_margin_left = 24
	box.content_margin_right = 24
	return box
