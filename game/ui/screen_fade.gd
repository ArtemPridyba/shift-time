class_name ScreenFade
extends CanvasLayer
## The passage between scenes (task 4.2): the screen fades to black, a title
## (the next level's) stands on black, the next scene is opened and the screen
## fades back in. Runs while the tree is paused. LevelLoader owns one.

signal finished

const LAYER := 100

var _black: ColorRect
var _title: Label
var _tween: Tween


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_black)
	_title = MenuStyle.make_label("", MenuStyle.TITLE_FONT / 2)
	_title.name = "Title"
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	add_child(_title)


func is_running() -> bool:
	return _tween != null and _tween.is_running()


## How dark the screen is now, 0 (clear) to 1 (black).
func darkness() -> float:
	return _black.color.a


## Fades out for `fade` seconds, shows `title` for `card` seconds (none when
## empty), calls `middle` (opens the next scene), fades in for `fade` seconds.
func play(title: String, fade: float, card: float, middle: Callable) -> void:
	if is_running():
		_tween.kill()
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = title
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_black, "color:a", 1.0, fade)
	if not title.is_empty():
		_tween.tween_property(_title, "modulate:a", 1.0, fade * 0.5)
		_tween.tween_interval(card)
		_tween.tween_property(_title, "modulate:a", 0.0, fade * 0.5)
	_tween.tween_callback(middle)
	_tween.tween_property(_black, "color:a", 0.0, fade)
	_tween.tween_callback(_on_done)


## Clears the screen at once (a scene opened without a passage).
func clear() -> void:
	if _tween != null:
		_tween.kill()
	_black.color.a = 0.0
	_title.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_done() -> void:
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()
